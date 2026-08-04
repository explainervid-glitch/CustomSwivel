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
import com.huey.ui.Component;
import flash.display.Loader;
import flash.display.MovieClip;
import flash.display.Sprite;
import flash.events.IOErrorEvent;
import flash.events.MouseEvent;
import flash.filesystem.File;
import flash.Lib;
import flash.net.URLRequest;
import flash.system.LoaderContext;

/**
 * The intro animation.
 *
 * Plays `assets/intro.swf` if one is present, so the intro can be redrawn in
 * Animate and dropped in without recompiling. Falls back to the SplashAnim
 * symbol compiled into assets/SwivelFonts.swf, which has no .fla in this repo
 * and so cannot otherwise be edited.
 *
 * Either way it removes itself when its timeline ends; Swivel also enforces a
 * timeout, so a looping or stalled intro cannot sit over the UI forever.
 */
class SplashScreen extends Component {
	inline public static var CUSTOM_INTRO_PATH : String = "assets/intro.swf";

	private var _holder : Sprite;
	private var _anim : MovieClip;
	private var _loader : Loader;

	public function new() {
		_holder = new Sprite();
		_holder.addEventListener(flash.events.Event.ADDED_TO_STAGE, addedToStageHandler, true);
		super(_holder);

		var custom = findCustomIntro();
		if(custom != null) loadCustomIntro(custom);
		else useEmbeddedIntro();
	}

	/** Looks beside the executable, then in the application directory. */
	private static function findCustomIntro() : Null<File> {
		var candidates = [
			try File.applicationDirectory.resolvePath(CUSTOM_INTRO_PATH) catch(e:Dynamic) null,
			try new File(File.applicationDirectory.nativePath).resolvePath('../$CUSTOM_INTRO_PATH') catch(e:Dynamic) null
		];

		for(file in candidates) {
			if(file != null && file.exists && !file.isDirectory) return file;
		}
		return null;
	}

	private function loadCustomIntro(file : File) : Void {
		_loader = new Loader();

		_loader.contentLoaderInfo.addEventListener(flash.events.Event.COMPLETE, function(_) {
			_holder.addChild(_loader);

			// A timeline-based SWF can tell us when it is finished. Anything
			// else just relies on Swivel's splash timeout.
			var clip = try cast(_loader.content, MovieClip) catch(error : Dynamic) null;
			if(clip != null) {
				_anim = clip;
				_anim.addEventListener(flash.events.Event.ENTER_FRAME, enterFrameHandler);
			}
		});

		_loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, function(_) useEmbeddedIntro());

		// The intro ships inside the application directory, so it is our own
		// asset rather than untrusted content; allowing code lets an Animate
		// export with a document class play normally.
		var context = new LoaderContext();
		context.allowCodeImport = true;
		context.applicationDomain = flash.system.ApplicationDomain.currentDomain;

		try _loader.load(new URLRequest(file.url), context)
		catch(error : Dynamic) useEmbeddedIntro();
	}

	private function useEmbeddedIntro() : Void {
		if(_anim != null) return;

		_anim = new SplashAnim();
		_anim.addEventListener(flash.events.Event.ENTER_FRAME, enterFrameHandler);
		_holder.addChild(_anim);
	}

	private function enterFrameHandler(e) {
		if (_anim.currentFrame == _anim.totalFrames) {
			_anim.stop();
			_anim.removeEventListener(flash.events.Event.ENTER_FRAME, enterFrameHandler);
			if (parent != null) parent.remove(this);
		}
	}

	private function addedToStageHandler(e) {
		var url =
		switch(e.target.name) {
			case "swivelButton":	"http://www.newgrounds.com/swivel";
			case "ngButton":		"http://www.newgrounds.com";
			case "haxeButton":		"http://www.haxe.org";
			case "ffmpegButton":	"http://www.ffmpeg.org";
			default:				null;
		}
		if (url != null) {
			e.target.addEventListener(MouseEvent.CLICK, function(e) Lib.getURL(new URLRequest(url)) );
		}
	}

}
