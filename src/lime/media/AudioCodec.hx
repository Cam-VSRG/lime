package lime.media;

enum abstract AudioCodec(Int)
{
	var OGG = 0;
	var OPUS = 1;
	var FLAC = 2;
	var MP3 = 3;
	var WAV = 4;

	public static function getCodecs():Array<AudioCodec>
	{
		return [OGG, OPUS, FLAC, MP3, WAV];
	}

	public function toString():String
	{
		return switch (cast this)
		{
			case OGG: "OGG";
			case OPUS: "OPUS";
			case FLAC: "FLAC";
			case MP3: "MP3";
			case WAV: "WAV";
			default: throw "Invalid AudioCodec enum";
		}
	}

	public static function fromString(codec:String):AudioCodec
	{
		return switch (codec.toUpperCase())
		{
			case "OGG": OGG;
			case "OPUS": OPUS;
			case "FLAC": FLAC;
			case "MP3": MP3;
			case "WAV": WAV;
			default: throw "Invalid string AudioCodec enum";
		}
	}
}
