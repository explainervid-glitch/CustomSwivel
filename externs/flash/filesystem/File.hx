package flash.filesystem;

import flash.net.FileReference;
import flash.desktop.Icon;

extern class File extends FileReference {
	public static var applicationDirectory(default, null): File;
	public static var applicationStorageDirectory(default, null): File;
	public static var desktopDirectory(default, null): File;
	public static var documentsDirectory(default, null): File;
	public static var userDirectory(default, null): File;
	public static var lineEnding(default, null): String;
	public static var separator(default, null): String;
	public static var systemCharset(default, null): String;
	public static function createTempDirectory(): File;
	public static function createTempFile(): File;
	public static function getRootDirectories(): Array<File>;
	
	public var exists(default, null): Bool;
	public var icon(default, null): Icon;
	public var isDirectory(default, null): Bool;
	public var isHidden(default, null): Bool;
	public var isPackage(default, null): Bool;
	public var isSymbolicLink(default, null): Bool;
	public var nativePath(default, default): String;
	public var parent(default, null): File;
	public var url(default, default): String;
	
	public function new(?path: String): Void;
	public function browseForDirectory(title: String): Void;
	public function browseForOpen(title: String, ?typeFilter: Array<flash.net.FileFilter>): Void;
	public function browseForOpenMultiple(title: String, ?typeFilter: Array<flash.net.FileFilter>): Void;
	public function browseForSave(title: String): Void;
	public override function cancel(): Void;
	public function canonicalize(): Void;
	public function clone(): File;
	public function copyTo(newLocation: FileReference, ?overwrite: Bool): Void;
	public function copyToAsync(newLocation: FileReference, ?overwrite: Bool): Void;
	public function createDirectory(): Void;
	public function deleteDirectory(?deleteDirectoryContents: Bool): Void;
	public function deleteDirectoryAsync(?deleteDirectoryContents: Bool): Void;
	public function deleteFile(): Void;
	public function deleteFileAsync(): Void;
	public function getDirectoryListing(): Array<File>;
	public function getDirectoryListingAsync(): Void;
	public function getRelativePath(ref: FileReference, ?useDotDot: Bool): String;
	public function moveTo(newLocation: FileReference, ?overwrite: Bool): Void;
	public function moveToAsync(newLocation: FileReference, ?overwrite: Bool): Void;
	public function moveToTrash(): Void;
	public function moveToTrashAsync(): Void;
	public function resolvePath(path: String): File;
	public function openWithDefaultApplication(): Void;
}
