#pragma once

#include <media/AudioDataFormat.h>

namespace lime
{

	class AudioDataUtil
	{
	  public:
		static int GetDataFormatByteDepth(AudioDataFormat format);
		static double ReadNormalized(const void *ptr, AudioDataFormat format);
		static void WriteNormalized(void *ptr, AudioDataFormat format, double signal);
		static void CopyAudioData(const void *source, AudioDataFormat srcFormat, void *destination, AudioDataFormat destFormat, size_t frames, int channels);
	};

} // namespace lime
