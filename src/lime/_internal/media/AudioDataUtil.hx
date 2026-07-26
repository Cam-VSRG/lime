package lime._internal.media;

import haxe.io.Bytes;

import lime._internal.backend.native.NativeCFFI;
import lime.media.AudioDataFormat;

@:access(lime._internal.backend.native.NativeCFFI)
class AudioDataUtil
{
	public static function readNormalized(data:Bytes, offset:Int, format:AudioDataFormat):Float
	{
		#if (lime_cffi && !macro)
		return NativeCFFI.lime_audio_data_util_read_normalized(data, offset, cast format);
		#else
		// TODO
		return 0;
		#end
	}

	public static function writeNormalized(data:Bytes, offset:Int, format:AudioDataFormat, signal:Float)
	{
		#if (lime_cffi && !macro)
		NativeCFFI.lime_audio_data_util_write_normalized(data, offset, cast format, signal);
		#else
		// TODO
		#end
	}

	public static function copyAudioData(source:Bytes, srcOffset:Int, srcFormat:AudioDataFormat, destination:Bytes, destOffset:Int, destFormat:AudioDataFormat, frames:Int, channels:Int)
	{
		#if (lime_cffi && !macro)
		NativeCFFI.lime_audio_data_util_copy_audio_data(source, srcOffset, cast srcFormat, destination, destOffset, cast destFormat, frames, channels);
		#else
		// TODO
		#end
	}
}