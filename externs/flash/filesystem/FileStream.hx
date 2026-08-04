package flash.filesystem;

import flash.utils.ByteArray;

extern class FileStream extends flash.events.EventDispatcher {
	public var bytesAvailable(default, null): UInt;
	public var endian(default, default): flash.utils.Endian;
	public var objectEncoding(default, default): UInt;
	public var position(default, default): Float;
	public var readAhead(default, default): Float;
	
	public function new(): Void;
	public function close(): Void;
	public function open(file: File, mode: String): Void;
	public function openAsync(file: File, fileMode: String): Void;
	public function readBoolean(): Bool;
	public function readByte(): Int;
	public function readBytes(bytes: ByteArray, ?offset: UInt, ?length: UInt): Void;
	public function readDouble(): Float;
	public function readFloat(): Float;
	public function readInt(): Int;
	public function readMultiByte(length: UInt, charSet: String): String;
	public function readObject(): Dynamic;
	public function readShort(): Int;
	public function readUnsignedByte(): UInt;
	public function readUnsignedInt(): UInt;
	public function readUnsignedShort(): UInt;
	public function readUTF(): String;
	public function readUTFBytes(length: UInt): String;
	public function truncate(): Void;
	public function writeBoolean(value: Bool): Void;
	public function writeByte(value: Int): Void;
	public function writeBytes(bytes: ByteArray, ?offset: UInt, ?length: UInt): Void;
	public function writeDouble(value: Float): Void;
	public function writeFloat(value: Float): Void;
	public function writeInt(value: Int): Void;
	public function writeMultiByte(value: String, charSet: String): Void;
	public function writeObject(object: Dynamic): Void;
	public function writeShort(value: Int): Void;
	public function writeUnsignedInt(value: UInt): Void;
	public function writeUTF(value: String): Void;
	public function writeUTFBytes(value: String): Void;
}
