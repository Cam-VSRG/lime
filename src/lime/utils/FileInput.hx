package lime.utils;

#if (sys && !doc_gen)
import sys.io.FileInput as HaxeFileInput;
#end

class FileInput #if (sys && !doc_gen) extends HaxeFileInput #end
{
	private var __handle:Dynamic;

	function new(handle:Dynamic):Void
	{
		__handle = handle;
	}

	public override function readByte():Int {
		return try {
			NativeCFFI.lime_file_input_read_byte(__handle);
		}
	}
}