package lime.media;

import lime.media.AudioSource.AudioSourceBackend;
#if lime_openal
import lime.media.openal.AL;
import lime.media.openal.ALFilter;
import lime.media.openal.ALSource;
#elseif (js && html5)
import js.html.audio.BiquadFilterNode;
import js.html.audio.BiquadFilterType;
import lime.media.howlerjs.Howler;
#end

#if !lime_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end
/**

**/
class AudioFilter
{
	/**
		The type of direct filter used on the audio.

		`NONE` will make the filter to be deactivated.

		`LOWPASS` will allow for the volume of high frequency audios to be reduced.

		`HIGHPASS` will allow for the volume of low frequency audios to be reduced.

		`BANDPASS` will allow for the volume of both low and high frequency audios to be reduced individually.
	**/
	public var type(default, set):AudioFilterType = AudioFilterType.NONE;

	/**
		A variable representing a frequency in the current filtering algorithm measured, in hz.
		Ranging from 0 to 24000, in Native Platforms it's from 100 to 22500.
	**/
	public var frequency(default, set):Float = 1000;

	/**
		A variable if it declared it its disposed and not to use.
	**/
	public var disposed:Bool;

	@:noCompletion private var __appliedSources:Array<AudioSource>;
	@:noCompletion private var __filterDisconnected:Bool;
	#if lime_openal
	@:noCompletion private var __alFilter:ALFilter;
	#elseif (js && html5)
	@:noCompletion private var __biquadFilter:BiquadFilterNode;
	#end

	/**
		Creates a new `AudioFilter` instance.
	**/
	public function new()
	{
		__appliedSources = [];
		#if lime_openal
		__alFilter = AL.createFilter();
		#elseif (js && html5)
		__biquadFilter = new BiquadFilterNode(untyped Howler.ctx);
		#end
		__updateFilter();
	}

	/**
		Releases any resources used by this `AudioFilter`.
	**/
	public function dispose():Void
	{
		if (disposed) return;

		for (source in __appliedSources) if (source != null) source.filter = null;
		__appliedSources = null;

		#if lime_openal
		AL.deleteFilter(_alFilter);
		#elseif (js && html5)
		__biquadFilter.disconnect();
		__biquadFilter = null;
		#end

		disposed = true;
	}

	@:noCompletion private inline function set_type(value:AudioFilterType):AudioFilterType
	{
		if (type != value)
		{
			type = value;
			__updateFilter();
		}

		return type;
	}

	@:noCompletion private inline function set_frequency(value:Float):Float
	{
		if (frequency != value)
		{
			frequency = value;
			__updateFilter();
		}

		return frequency;
	}

	@:noCompletion private function __updateFilter():Void
	{
		#if lime_openal
		var linearValue = Math.max(Math.min((frequency - 100) / 22400, 1), 0);

		switch (type)
		{
			case LOWPASS:
				__filterDisconnected = frequency >= 22500;
				if (!__filterDisconnected)
				{
					AL.filteri(__alFilter, AL.FILTER_TYPE, AL.FILTER_LOWPASS);
					AL.filterf(__alFilter, AL.LOWPASS_GAINHF, linearValue);
				}

			case HIGHPASS:
				__filterDisconnected = frequency <= 0;
				if (!__filterDisconnected)
				{
					AL.filteri(__alFilter, AL.FILTER_TYPE, AL.FILTER_HIGHPASS);
					AL.filterf(__alFilter, AL.HIGHPASS_GAINLF, 1 - linearValue);
				}

			case BANDPASS:
				__filterDisconnected = false;
				AL.filteri(__alFilter, AL.FILTER_TYPE, AL.FILTER_BANDPASS);
				AL.filterf(__alFilter, AL.LOWPASS_GAINHF, linearValue);
				AL.filterf(__alFilter, AL.HIGHPASS_GAINLF, 1 - linearValue);

			default:
				__filterDisconnected = true;

		}

		if (__filterDisconnected)
		{
			AL.filteri(__alFilter, AL.FILTER_TYPE, AL.FILTER_NULL);
		}
		#elseif (js && html5)
		var wasFilterDisconnected = __filterDisconnected;

		switch (type)
		{
			case LOWPASS:
				__biquadFilter.type = BiquadFilterType.LOWPASS;
				__biquadFilter.frequency.value = Math.max(frequency, 0);
				__filterDisconnected = frequency >= 24000;

			case HIGHPASS:
				__biquadFilter.type = BiquadFilterType.HIGHPASS;
				__biquadFilter.frequency.value = Math.min(frequency, 24000);
				__filterDisconnected = frequency <= 0;

			case BANDPASS:
				__biquadFilter.type = BiquadFilterType.BANDPASS;
				__biquadFilter.frequency.value = Math.max(Math.min(frequency, 24000), 0);
				__filterDisconnected = false;

			default:
				__filterDisconnected = true;

		}

		if (wasFilterDisconnected && !__filterDisconnected)
		{
			for (source in __appliedSources) __sourceRefresh(source.__backend);
		}
		else if (__filterDisconnected && !wasFilterDisconnected)
		{
			for (source in __appliedSources) __sourceRemoveFilter(source.__backend);
		}
		#end
	}

	@:noCompletion private function __sourceRefresh(backend:AudioSourceBackend):Void
	{
		#if lime_openal
		AL.sourcei(backend.source, AL.DIRECT_FILTER, __alFilter);
		#elseif (js && html5)
		if (backend.audioNode == null) return;

		if (!__filterDisconnected)
		{
			backend.audioNode.disconnect();
			backend.audioNode.connect(__biquadFilter);
			__biquadFilter.connect(untyped Howler.ctx.destination);
		}
		#end
	}

	@:noCompletion private function __sourceRemoveFilter(backend:AudioSourceBackend):Void
	{
		#if lime_openal
		
		#elseif (js && html5)
		if (backend.audioNode == null) return;

		__biquadFilter.disconnect();
		backend.audioNode.disconnect();
		backend.audioNode.connect(untyped Howler.ctx.destination);
		#end
	}

	@:allow(lime.media.AudioSource)
	@:noCompletion private inline function __applySource(source:AudioSource):Void
	{
		__appliedSources.push(source);
		__sourceRefresh(source.__backend);
		source.__backend.onRefresh.add(__sourceRefresh);
	}

	@:allow(lime.media.AudioSource)
	@:noCompletion private inline function __removeSource(source:AudioSource):Void
	{
		__appliedSources.remove(source);
		__sourceRemoveFilter(source.__backend);
	}
}