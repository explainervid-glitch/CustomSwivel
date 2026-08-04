/*
 * Swivel
 * Copyright (C) 2012-2017, Newgrounds.com, Inc.
 * https://github.com/Herschel/Swivel
 *
 * Swivel is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Swivel is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Swivel.  If not, see <http://www.gnu.org/licenses/>.
 */

package com.newgrounds.swivel;
import com.huey.utils.Logger;
import flash.events.ProgressEvent;
import flash.events.ServerSocketConnectEvent;
import flash.net.ServerSocket;
import flash.net.Socket;

/**
 * A minimal HTTP server on the loopback interface, so the Adobe Animate
 * "Send to Swivel" panel can hand over a freshly published SWF.
 *
 * HTTP rather than a raw socket because Adobe's CEP host in Animate provides
 * `fetch()` but **not** Node.js -- a panel cannot open a TCP socket, but it
 * can make HTTP requests.
 *
 * Bound to 127.0.0.1 only: this listens for local programs, never for the
 * network.
 *
 *   GET  /ping     ->  {"ok":true,"app":"Swivel","version":"..."}
 *   POST /add      ->  {"ok":true,"message":"Added scene.swf"}
 *                      body is the absolute path, Content-Type: text/plain
 *   POST /convert  ->  {"ok":true,"message":"Converting..."}
 *                      Tells Swivel to start converting with current settings.
 *   GET  /progress ->  {"ok":true,"progress":0.42,"task":"EncodeSwf",
 *                      "message":"Encoding SWF to video...","complete":false}
 *
 * `text/plain` keeps the request CORS-"simple", so the browser engine issues
 * no preflight. Every response carries Access-Control-Allow-Origin: *, which
 * is required because a CEP panel's origin is not http://127.0.0.1.
 */
class AnimateBridge {
	inline public static var DEFAULT_PORT : Int = 47800;
	inline private static var LOOPBACK : String = "127.0.0.1";
	inline private static var MAX_REQUEST : Int = 65536;

	/**
	 * Called with an absolute path when a client asks Swivel to add an SWF.
	 * Return null on success, or a message explaining the refusal.
	 */
	public var onAddFile : String -> Null<String>;

	/**
	 * Called when a client asks Swivel to begin converting.
	 * Return null on success, or a message explaining the refusal.
	 */
	public var onConvert : Void -> Null<String>;

	/**
	 * Called when a client polls for conversion progress.
	 * Should return { progress : Float, task : String, message : String, complete : Bool }.
	 */
	public var onProgress : Void -> Null<{ progress : Float, task : String, message : String, complete : Bool }>;

	/** Reported by /ping, purely so the panel can show what it connected to. */
	public var appVersion : String = "";

	public var port(default, null) : Int;
	public var listening(get, never) : Bool;
	private function get_listening() : Bool return _server != null && _server.listening;

	private var _server : ServerSocket;
	private var _buffers : Map<Socket, String>;

	public function new(?port : Int) {
		this.port = if(port != null) port else DEFAULT_PORT;
		_buffers = new Map();
	}

	/** Returns false if the port is unavailable or sockets are unsupported. */
	public function start() : Bool {
		if(listening) return true;

		if(!ServerSocket.isSupported) {
			Logger.log("SwivelLog", "AnimateBridge: ServerSocket unsupported on this runtime.\n");
			return false;
		}

		try {
			_server = new ServerSocket();
			_server.addEventListener(ServerSocketConnectEvent.CONNECT, connectHandler);
			_server.bind(port, LOOPBACK);
			_server.listen();
			Logger.log("SwivelLog", 'AnimateBridge: listening on http://$LOOPBACK:$port\n');
			return true;
		} catch(error : Dynamic) {
			// Most likely another Swivel instance already holds the port.
			Logger.log("SwivelLog", 'AnimateBridge: could not listen on $port: ${Std.string(error)}\n');
			_server = null;
			return false;
		}
	}

	public function stop() : Void {
		for(client in _buffers.keys()) closeClient(client);
		_buffers = new Map();

		if(_server != null) {
			try _server.close() catch(error : Dynamic) {}
			_server = null;
		}
	}

	private function connectHandler(e : ServerSocketConnectEvent) : Void {
		var client = e.socket;
		_buffers.set(client, "");

		client.addEventListener(ProgressEvent.SOCKET_DATA, function(_) readFrom(client));
		client.addEventListener(flash.events.Event.CLOSE, function(_) closeClient(client));
		client.addEventListener(flash.events.IOErrorEvent.IO_ERROR, function(_) closeClient(client));
	}

	private function readFrom(client : Socket) : Void {
		var chunk = try client.readUTFBytes(client.bytesAvailable)
			catch(error : Dynamic) { closeClient(client); return; };

		var buffer = (_buffers.exists(client) ? _buffers.get(client) : "") + chunk;

		if(buffer.length > MAX_REQUEST) {
			respond(client, 413, '{"ok":false,"message":"Request too large"}');
			return;
		}
		_buffers.set(client, buffer);

		// Wait for the full headers before doing anything.
		var headerEnd = buffer.indexOf("\r\n\r\n");
		var separatorLength = 4;
		if(headerEnd < 0) {
			headerEnd = buffer.indexOf("\n\n");
			separatorLength = 2;
			if(headerEnd < 0) return;
		}

		var head = buffer.substr(0, headerEnd);
		var body = buffer.substr(headerEnd + separatorLength);

		// ...and for the whole body, if one was announced.
		var expected = contentLength(head);
		if(body.length < expected) return;

		handleRequest(client, head, body.substr(0, expected));
	}

	private function handleRequest(client : Socket, head : String, body : String) : Void {
		var requestLine = head.split("\n")[0];
		var parts = StringTools.trim(requestLine).split(" ");
		var method = if(parts.length > 0) parts[0].toUpperCase() else "";
		var path   = if(parts.length > 1) parts[1] else "/";

		var question = path.indexOf("?");
		if(question >= 0) path = path.substr(0, question);

		switch(method + " " + path) {
			case "OPTIONS /add", "OPTIONS /ping", "OPTIONS /convert", "OPTIONS /progress":
				respond(client, 200, "");

			case "GET /ping":
				respond(client, 200, '{"ok":true,"app":"Swivel","version":"' + escape(appVersion) + '"}');

			case "POST /add":
				var swfPath = StringTools.trim(body);

				if(swfPath == "") {
					respond(client, 400, '{"ok":false,"message":"No path given"}');
				} else if(onAddFile == null) {
					respond(client, 503, '{"ok":false,"message":"Swivel is not ready to accept files"}');
				} else {
					var problem = onAddFile(swfPath);
					if(problem == null)
						respond(client, 200, '{"ok":true,"message":"Added ' + escape(fileName(swfPath)) + '"}');
					else
						respond(client, 409, '{"ok":false,"message":"' + escape(problem) + '"}');
				}

			case "POST /convert":
				if(onConvert == null) {
					respond(client, 503, '{"ok":false,"message":"Swivel is not ready to convert"}');
				} else {
					var problem = onConvert();
					if(problem == null)
						respond(client, 200, '{"ok":true,"message":"Converting..."}');
					else
						respond(client, 409, '{"ok":false,"message":"' + escape(problem) + '"}');
				}

			case "GET /progress":
				if(onProgress == null) {
					respond(client, 503, '{"ok":false,"message":"Swivel is not ready to report progress"}');
				} else {
					var info = onProgress();
					if(info == null) {
						respond(client, 200, '{"ok":true,"progress":0,"task":"","message":"","complete":false}');
					} else {
						respond(client, 200, '{"ok":true,"progress":' + info.progress + ',"task":"' + escape(info.task) + '","message":"' + escape(info.message) + '","complete":' + (info.complete ? 'true' : 'false') + '}');
					}
				}

			default:
				respond(client, 404, '{"ok":false,"message":"Unknown endpoint"}');
		}
	}

	private function respond(client : Socket, status : Int, json : String) : Void {
		var reason = switch(status) {
			case 200: "OK";
			case 400: "Bad Request";
			case 404: "Not Found";
			case 409: "Conflict";
			case 413: "Payload Too Large";
			case 503: "Service Unavailable";
			default:  "OK";
		}

		var response = new StringBuf();
		response.add('HTTP/1.1 $status $reason\r\n');
		response.add("Content-Type: application/json\r\n");
		// A CEP panel's page origin is not 127.0.0.1, so this is required.
		response.add("Access-Control-Allow-Origin: *\r\n");
		response.add("Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n");
		response.add("Access-Control-Allow-Headers: Content-Type\r\n");
		response.add("Cache-Control: no-store\r\n");
		response.add('Content-Length: ${json.length}\r\n');
		response.add("Connection: close\r\n\r\n");
		response.add(json);

		if(json != "") Logger.log("SwivelLog", 'AnimateBridge: $status $json\n');

		try {
			client.writeUTFBytes(response.toString());
			client.flush();
		} catch(error : Dynamic) {}

		closeClient(client);
	}

	private function closeClient(client : Socket) : Void {
		_buffers.remove(client);
		try if(client.connected) client.close() catch(error : Dynamic) {}
	}

	private static function contentLength(head : String) : Int {
		for(line in head.split("\n")) {
			var colon = line.indexOf(":");
			if(colon < 0) continue;
			if(StringTools.trim(line.substr(0, colon)).toLowerCase() != "content-length") continue;

			var value = Std.parseInt(StringTools.trim(line.substr(colon + 1)));
			return if(value == null || value < 0) 0 else value;
		}
		return 0;
	}

	private static function escape(text : String) : String {
		var out = StringTools.replace(text, "\\", "\\\\");
		out = StringTools.replace(out, "\"", "\\\"");
		out = StringTools.replace(out, "\r", " ");
		out = StringTools.replace(out, "\n", " ");
		out = StringTools.replace(out, "\t", " ");
		return out;
	}

	private static function fileName(path : String) : String {
		var slash = path.length - 1;
		while(slash >= 0 && path.charAt(slash) != "\\" && path.charAt(slash) != "/") slash--;
		return path.substr(slash + 1);
	}
}
