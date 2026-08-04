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
import com.huey.ui.Container;
import com.huey.ui.Label;
import com.huey.ui.Rectangle;

/**
 * A transient message strip. Used to surface problems that previously failed
 * silently -- most importantly SWFs that cannot be parsed.
 */
class Toast extends Container {
	inline private static var WIDTH : Float = 700;
	inline private static var HEIGHT : Float = 44;

	private var _label : Label;
	private var _background : Rectangle;
	private var _timer : haxe.Timer;

	public function new() {
		super();

		_background = new Rectangle(0xee1d2417, WIDTH, HEIGHT);
		add(_background);

		_label = new Label("");
		_label.font = "AdvoCut";
		_label.size = 10;
		_label.color = 0xffffff;
		_label.wordWrap = true;
		_label.width = WIDTH - 24;
		_label.x = 12;
		_label.y = 8;
		add(_label);

		visible = false;
	}

	/** Show `message` for `seconds`, replacing anything already on screen. */
	public function show(message : String, ?seconds : Float = 6) : Void {
		cancelTimer();

		_label.text = message;
		_label.color = 0xffffff;
		visible = true;

		_timer = haxe.Timer.delay(hide, Std.int(seconds * 1000));
	}

	/** As `show`, but tinted to read as a failure rather than a notice. */
	public function showError(message : String, ?seconds : Float = 10) : Void {
		show(message, seconds);
		_label.color = 0xffb3b3;
	}

	public function hide() : Void {
		cancelTimer();
		visible = false;
	}

	private function cancelTimer() : Void {
		if (_timer != null) {
			_timer.stop();
			_timer = null;
		}
	}
}
