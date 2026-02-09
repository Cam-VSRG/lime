package lime.media;

#if (haxe_ver >= 4.0) enum #else @:enum #end abstract AudioFilterType(String) from String to String
{
	var NONE = "none";
	var LOWPASS = "lowpass";
	var HIGHPASS = "highpass";
	var BANDPASS = "bandpass";
}
