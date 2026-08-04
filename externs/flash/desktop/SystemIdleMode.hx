package flash.desktop;

// Overrides the copy in the `air` haxelib, which still uses @:fakeEnum --
// removed in Haxe 4 in favour of `extern enum abstract`.
@:native("flash.desktop.SystemIdleMode")
extern enum abstract SystemIdleMode(String) {
	var KEEP_AWAKE;
	var NORMAL;
}
