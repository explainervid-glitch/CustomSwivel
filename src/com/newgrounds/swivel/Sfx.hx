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
import flash.filesystem.File;
import flash.media.Sound;
import flash.net.URLRequest;

/**
 * Plays UI sound effects from `assets/audio/<name>.mp3`, so they can be
 * swapped without recompiling.
 *
 * The original sounds were compiled into assets/SwivelFonts.swf as symbols,
 * which meant changing them required Adobe Animate and the source .fla.
 *
 * MP3 only -- the Flash runtime cannot decode WAV.
 */
class Sfx {
	/** Set false to mute all UI sound effects. */
	public static var enabled : Bool = true;

	// Sounds are cached so a file is only read from disk once, and held so
	// the channel is not garbage collected mid-playback.
	private static var _cache : Map<String, Sound> = new Map();

	/**
	 * Plays `assets/audio/<name>.mp3`.
	 * Returns false if the file is missing or unplayable, so the caller can
	 * fall back to an embedded sound.
	 */
	public static function play(name : String) : Bool {
		if(!enabled) return false;

		var sound = _cache.get(name);
		if(sound != null) {
			sound.play();
			return true;
		}

		var file = resolve(name);
		if(file == null) return false;

		try {
			sound = new Sound();
			sound.addEventListener(flash.events.IOErrorEvent.IO_ERROR, function(_) {
				Logger.log("SwivelLog", 'Could not decode ${file.nativePath} -- is it really an MP3?\n');
				_cache.remove(name);
			});
			sound.load( new URLRequest(file.url) );
			_cache.set(name, sound);
			sound.play();
			return true;
		} catch(error : Dynamic) {
			Logger.log("SwivelLog", 'Could not play ${file.nativePath}: ${Std.string(error)}\n');
			return false;
		}
	}

	/**
	 * Looks next to the executable first, then in the application directory,
	 * so a packaged build and a development run both work.
	 */
	private static function resolve(name : String) : Null<File> {
		var candidates = [
			try File.applicationDirectory.resolvePath('assets/audio/$name.mp3') catch(e:Dynamic) null,
			try new File(File.applicationDirectory.nativePath).resolvePath('../assets/audio/$name.mp3') catch(e:Dynamic) null
		];

		for(file in candidates) {
			if(file != null && file.exists && !file.isDirectory) return file;
		}
		return null;
	}
}
