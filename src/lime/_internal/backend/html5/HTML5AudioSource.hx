package lime._internal.backend.html5;

import lime.app.Event;
import lime.math.Vector4;
import lime.media.AudioSource;

#if lime_howlerjs
import js.html.audio.AudioNode;
import js.html.audio.AnalyserNode;
import js.html.audio.ChannelSplitterNode;
import js.html.audio.MediaElementAudioSourceNode;
import js.html.MediaElement;
import js.lib.Float32Array;
import lime.media.howlerjs.Howl;
import lime.media.howlerjs.Howler;
#end

@:access(lime.media.AudioBuffer)
class HTML5AudioSource
{
	public static function playSources(sources:Array<AudioSource>):Void
	{
		for (source in sources) source.play();
	}

	public static function pauseSources(sources:Array<AudioSource>):Void
	{
		for (source in sources) source.pause();
	}

	public static function stopSources(sources:Array<AudioSource>):Void
	{
		for (source in sources) source.stop();
	}

	public var parent:AudioSource;

	private var completed:Bool;
	private var gain:Float;
	private var length:Float;
	private var loopTime:Float;
	private var loops:Int;
	private var pauseTime:Float;
	private var peaks:Array<Float>;
	private var pitch:Float;
	private var position:Vector4;
	#if lime_howlerjs
	public var onRefresh = new Event<HTML5AudioSource->Void>();
	public var id:Int;

	public var howl:Howl;
	public var howlSound:Dynamic;
	public var audioNode:AudioNode;

	private var playing:Bool;
	private var analyserLeft:AnalyserNode;
	private var analyserRight:AnalyserNode;
	private var channelSplitter:ChannelSplitterNode;
	private var channelSplitterNode:AudioNode;
	private var dataArrayLeft:Float32Array;
	private var dataArrayRight:Float32Array;
	private var mins:Array<Float>;
	private var maxs:Array<Float>;
	private var timerID:Int;
	#end

	public function new(parent:AudioSource)
	{
		this.parent = parent;
		gain = 1;
		pitch = 1;
		#if lime_howlerjs
		id = -1;
		timerID = -1;
		#end
	}

	public function dispose():Void
	{
		#if lime_howlerjs
		dataArrayLeft = null;
		dataArrayRight = null;
		mins = null;
		maxs = null;
		#end
	}

	public function load():Void
	{
		#if lime_howlerjs
		if (parent.buffer != null) howl = parent.buffer.__srcHowl;
		if (howl != null)
		{
			howl.load();
			if (!loadAudio())
			{
				var source = this;
				howl.on("load", function()
				{
					if (source.playing) source.play();
				});
			}
		}
		id = -1;
		#end
	}

	public function unload():Void
	{
		// Howl sounds are automatically unloaded if it has stopped.
		#if lime_howlerjs
		disposeNode();
		howl = null;
		id = -1;
		#end
		length = 0;
		loopTime = 0;
		pauseTime = 0;
	}

	public function play():Void
	{
		#if lime_howlerjs
		if (howl == null || (id != -1 && howl.playing(id))) return;

		playing = true;
		completed = false;

		if (!loadAudio()) return;

		id = howl.play();
		refreshNode();
		resetTimer(Std.int((length - pauseTime - parent.offset) / howl.rate(id)));
		#end
	}

	private function disposeNode():Void
	{
		#if lime_howlerjs
		howlSound = null;
		audioNode = null;

		if (channelSplitter != null) channelSplitter.disconnect();
		if (analyserLeft != null) analyserLeft.disconnect();
		if (analyserRight != null) analyserRight.disconnect();

		channelSplitter = null;
		analyserLeft = null;
		analyserRight = null;
		#end
	}

	private function refreshNode():Void
	{
		#if lime_howlerjs
		disposeNode();

		howlSound = untyped howl._soundById(id);
		var node = untyped howlSound._node;

		if ((node is MediaElement))
		{
			lime.utils.Log.warn("HTML5 Element Audios are not fully supported! (and buggy) Expect unexpected behaviour.");
		}
		else
		{
			if (untyped howlSound._panner) audioNode = untyped howlSound._panner;
			else audioNode = untyped node;
		}

		updateLoop();
		howl.volume(gain, id);
		howl.seek((pauseTime + parent.offset) / 1000, id);

		onRefresh.dispatch(this);
		#end
	}

	private function loadAudio():Bool
	{
		if (length != 0) return true;

		length = howl.duration() * 1000;
		return length != 0;
	}

	public function pause():Void
	{
		#if lime_howlerjs
		if (howlSound != null)
		{
			pauseTime = howl.seek(id) * 1000;
			howl.pause(id);
		}
		else
		{
			pauseTime = 0;
		}
		playing = false;
		stopTimer();
		#end
	}

	public function stop():Void
	{
		pauseTime = 0;

		#if lime_howlerjs
		if (howlSound != null)
		{
			howl.stop(id);
		}
		playing = false;
		stopTimer();
		#end
	}

	public function prepare(value:Float):Void
	{
		pauseTime = value + parent.offset;
		if (pauseTime < 0 || !Math.isFinite(pauseTime)) pauseTime = 0;

		#if lime_howlerjs
		if (howlSound != null)
		{
			howl.stop(id);
			howl.seek(pauseTime / 1000, id);
		}
		playing = false;
		stopTimer();
		#end
	}

	// Event Handlers
	private inline function stopTimer():Void
	{
		#if lime_howlerjs
		if (timerID != -1)
		{
			untyped clearInterval(timerID);
			timerID = -1;
		}
		#end
	}

	private inline function resetTimer(ms:Int):Void
	{
		#if lime_howlerjs
		stopTimer();

		var me = this;
		timerID = untyped setInterval(function() me.complete(), ms);
		#end
	}

	private function complete()
	{
		#if lime_howlerjs
		if (loops > 0)
		{
			var wasLooping = howl.loop(id);
			loops--;
			updateLoop();
			if (wasLooping)
			{
				resetTimer(Std.int((length - (howl.seek(id) * 1000) - parent.offset) / howl.rate(id)));
			}
			else
			{
				resetTimer(Std.int((length - loopTime - parent.offset) / howl.rate(id)));
				howl.seek((loopTime + parent.offset) / 1000, id);
				howl.play(id);
			}
			pauseTime = loopTime;
		}
		else
		{
			howl.stop(id);

			stopTimer();
			playing = false;
			completed = true;
			pauseTime = 0;
		}

		parent.onComplete.dispatch();
		#end
	}

	// Get & Set Methods
	public function getCurrentTime():Float
	{
		#if lime_howlerjs
		var loaded = howlSound != null;
		if (completed || loaded && playing && !howl.playing(id))
		{
			return length - parent.offset;
		}
		else if (loaded)
		{
			return howl.seek(id) * 1000 - parent.offset;
		}
		#end

		return pauseTime - parent.offset;
	}

	public function setCurrentTime(value:Float):Float
	{
		pauseTime = value + parent.offset;
		if (pauseTime < 0 || !Math.isFinite(pauseTime)) pauseTime = 0;

		#if lime_howlerjs
		if (howlSound != null)
		{
			howl.seek(pauseTime / 1000, id);
			if (howl.playing(id))
			{
				if (pauseTime >= length && !completed)
				{
					completed = true;
					resetTimer(0);
				}
				else resetTimer(Std.int((length - pauseTime - parent.offset) / howl.rate(id)));
			}
		}
		#end

		return value;
	}

	public function getGain():Float
	{
		return gain;
	}

	public function setGain(value:Float):Float
	{
		#if lime_howlerjs
		if (howlSound != null)
		{
			howl.volume(value, id);
		}
		#end
		return gain = value;
	}

	public function getLatency():Float
	{
		return 0;
	}

	public function getLength():Float
	{
		if (length == 0)
		{
			length = howl.duration() * 1000;
			if (length == 0) return 0;
		}

		if (length <= parent.offset) return 0;
		return length - parent.offset;
	}

	public function setLength(value:Float):Float
	{
		length = value + parent.offset;

		#if lime_howlerjs
		if (howl != null)
		{
			var duration = howl.duration() * 1000;
			if (duration != 0 && (length <= 0 || length >= duration)) length = duration;
			if (id != -1 && howl.playing(id)) resetTimer(Std.int((length - howl.seek(id) * 1000) / howl.rate(id)));
		}
		#end
		updateLoop();

		return value;
	}

	public function getLoopTime():Float
	{
		if (loopTime <= parent.offset) return 0;
		return loopTime - parent.offset;
	}

	public function setLoopTime(value:Float):Float
	{
		loopTime = value + parent.offset;

		#if lime_howlerjs
		if (howl != null)
		{
			if (loopTime < 0) loopTime = 0;
			else
			{
				var duration = howl.duration() * 1000;
				if (loopTime >= duration) loopTime = duration;
			}
		}
		#end
		updateLoop();
		return value;
	}

	public function getLoops():Int
	{
		return loops;
	}

	public function setLoops(value:Int):Int
	{
		loops = value;
		updateLoop();
		return value;
	}

	private function updateLoop()
	{
		#if lime_howlerjs
		if (howlSound != null)
		{
			// Use the internal variables to set the loops.
			untyped howlSound._start = loopTime / 1000;
			untyped howlSound._stop = length / 1000;
			howl.loop(loops > 0, id);
		}
		#end
	}

	public function getPan():Float
	{
		if (position == null) position = new Vector4();
		return position.x;
	}

	public function setPan(value:Float):Float
	{
		if (position == null) position = new Vector4();
		position.setTo(value, 0, -Math.sqrt(1 - value * value));

		#if lime_howlerjs
		if (howl != null && id != -1)
		{
			//howl.pos(0, 0, 0, id);
			howl.stereo(value, id);
		}
		#end
		return value;
	}

	public function getPitch():Float
	{
		return pitch;
	}

	public function setPitch(value:Float):Float
	{
		#if lime_howlerjs
		if (howlSound != null)
		{
			howl.rate(value, id);
			resetTimer(Std.int((length - howl.seek(id) * 1000) / howl.rate(id)));
		}
		#end
		return pitch = value;
	}

	public function getPlaying():Bool
	{
		#if lime_howlerjs
		if (howlSound != null) return playing && howl.playing(id);
		#end
		return false;
	}

	public function getPosition():Vector4
	{
		if (position == null) position = new Vector4();
		return position;
	}

	public function setPosition(value:Vector4):Vector4
	{
		if (position == null) position = new Vector4();
		position.setTo(value.x, value.y, value.z);

		/*#if lime_howlerjs
		if (howl != null && id != -1)
		{
			howl.pos(position.x, position.y, position.z, id);
		}
		#end*/

		return position;
	}

	public function getPeaks(offsetMs:Float):Array<Float>
	{
		if (peaks == null) peaks = [0, 0];

		#if lime_howlerjs
		var previousChannelSplitterNode = channelSplitterNode;
		if (howlSound != null && (untyped howlSound._node))
		{
			if (untyped howlSound._node.bufferSource) channelSplitterNode = untyped howlSound._node.bufferSource;
			else channelSplitterNode = null;
		}
		else channelSplitterNode = null;

		if (channelSplitterNode == null)
		{
			for (i in 0...2) peaks[i] = 0;
			return peaks;
		}
		else if (channelSplitter == null)
		{
			channelSplitter = new ChannelSplitterNode(untyped audioNode.context, {numberOfOutputs: 2});
			analyserLeft = new AnalyserNode(untyped audioNode.context);
			analyserRight = new AnalyserNode(untyped audioNode.context);
			analyserLeft.fftSize = analyserRight.fftSize = 2048;
			analyserLeft.maxDecibels = analyserRight.maxDecibels = 0;
			analyserLeft.minDecibels = analyserRight.minDecibels = -120;
			channelSplitter.connect(analyserLeft, 0);
			channelSplitter.connect(analyserRight, 1);
			channelSplitterNode.connect(channelSplitter);
		}
		else if (previousChannelSplitterNode != channelSplitterNode)
		{
			//if (untyped previousChannelSplitterNode) previousChannelSplitterNode.disconnect(channelSplitter);
			if (channelSplitterNode != null) channelSplitterNode.connect(channelSplitter);
		}

		if (dataArrayLeft == null) dataArrayLeft = new Float32Array(2048);
		if (dataArrayRight == null) dataArrayRight = new Float32Array(2048);

		if (mins == null)
		{
			mins = [for (i in 0...2) -1];
			maxs = [for (i in 0...2) -1];
		}
		else
		{
			for (i in 0...2) maxs[i] = mins[i] = -1;
		}

		analyserLeft.getFloatTimeDomainData(dataArrayLeft);
		analyserRight.getFloatTimeDomainData(dataArrayRight);

		for (v in dataArrayLeft) ((v > maxs[0]) ? (maxs[0] = v) : (if (-v > mins[0]) (mins[0] = -v)));
		for (v in dataArrayRight) ((v > maxs[1]) ? (maxs[1] = v) : (if (-v > mins[1]) (mins[1] = -v)));

		for (i in 0...2) peaks[i] = (maxs[i] + mins[i]) * 0.5;
		#end
		return peaks;
	}
}
