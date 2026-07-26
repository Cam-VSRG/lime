#include <media/utils/AudioDataUtil.h>
#include <math.h>
#include <stdint.h>
#include <string.h>

#if LIME_DR_LIBS
#include <dr_wav.h>
#endif

namespace lime
{

	int AudioDataUtil::GetDataFormatByteDepth(AudioDataFormat format)
	{
		switch (format)
		{
			case AudioDataFormat::U8: return 1;
			case AudioDataFormat::S16: return 2;
			case AudioDataFormat::S24: return 3;
			case AudioDataFormat::S32: return 4;
			case AudioDataFormat::F32: return 4;
		}
		return 0;
	}

	double AudioDataUtil::ReadNormalized(const void *ptr, AudioDataFormat format)
	{
		switch (format)
		{
			case AudioDataFormat::U8:
				// 0.00784313725490196078 turns 0..255 to 0.0..2.0; stolen from dr_wav drwav_u8_to_f32
				return (double)(*(const uint8_t*)ptr) * 0.00784313725490196078 - 1.0;

			case AudioDataFormat::S16:
				// 0.000030517578125 turns -32768..32767 to -1.0..1.0; again stolen from dr_wav drwav_s16_to_f32
				return (double)(*(const int16_t*)ptr) * 0.000030517578125;

			case AudioDataFormat::S24:
			{
				// stolen from dr_wav drwav_s24_to_f32
				const uint8_t* p = (const uint8_t*)ptr;
				uint32_t a = (uint32_t)(p[0]) << 8;
				uint32_t b = (uint32_t)(p[1]) << 16;
				uint32_t c = (uint32_t)(p[2]) << 24;

				return (double)((int32_t)(a | b | c) >> 8) * 0.00000011920928955078125;
			}

			case AudioDataFormat::S32:
				return (double)(*(const int32_t*)ptr) / 2147483648.0;

			case AudioDataFormat::F32:
				return (double)(*(const float*)ptr);
		}

		return 0.0;
	}


	void AudioDataUtil::WriteNormalized(void *ptr, AudioDataFormat format, double signal)
	{
		switch (format)
		{
			case AudioDataFormat::U8:
			{
				*((uint8_t*)ptr) = (uint8_t)(((signal < -1) ? -1 : ((signal > 1) ? 1 : signal)) * 127.5 + 127.5 + (signal < 0.0 ? -0.5 : 0.5));
				break;
			}

			case AudioDataFormat::S16:
			{
				double v = signal * 32768.0 + (signal < 0.0 ? -0.5 : 0.5);
				*((int16_t*)ptr) = (int16_t)((v > 32767.0) ? 32767.0 : ((v < -32768.0) ? -32768.0 : v));
				break;
			}

			case AudioDataFormat::S24:
			{
				double v = signal * 8388608.0 + (signal < 0.0 ? -0.5 : 0.5);
				int32_t iv = (int32_t)((v > 8388607.0) ? 8388607.0 : ((v < -8388608.0) ? -8388608.0 : v));
				uint8_t* p = (uint8_t*)ptr;
				p[0] = (uint8_t)(iv & 0xFF);
				p[1] = (uint8_t)((iv >> 8) & 0xFF);
				p[2] = (uint8_t)((iv >> 16) & 0xFF);
				break;
			}

			case AudioDataFormat::S32:
			{
				double v = signal * 2147483648.0 + (signal < 0.0 ? -0.5 : 0.5);
				*((int32_t*	)ptr) = (int32_t)((v > 2147483647.0) ? 2147483647.0 : ((v < -2147483648.0) ? -2147483648.0 : v));
				break;
			}

			case AudioDataFormat::F32:
				// No need to clamp
				*((float*)ptr) = (float)signal;
				break;
		}
	}

	void AudioDataUtil::CopyAudioData(const void *source, AudioDataFormat srcFormat, void *destination, AudioDataFormat destFormat, size_t frames, int channels)
	{
		if (!source || !destination || frames <= 0 || channels <= 0) return;

		size_t count = frames * (size_t)channels;

		if (srcFormat == destFormat)
		{
			memcpy(destination, source, count * (size_t)AudioDataUtil::GetDataFormatByteDepth(srcFormat));
			return;
		}

		#if LIME_DR_LIBS
		// Use dr_wav low-level converters if possible for faster instructions.
		switch (destFormat)
		{
			case AudioDataFormat::S16:
				switch (srcFormat)
				{
					case AudioDataFormat::U8: drwav_u8_to_s16((drwav_int16*)destination, (const drwav_uint8*)source, count); return;
					case AudioDataFormat::S24: drwav_s24_to_s16((drwav_int16*)destination, (const drwav_uint8*)source, count); return;
					case AudioDataFormat::S32: drwav_s32_to_s16((drwav_int16*)destination, (const drwav_int32*)source, count); return;
					case AudioDataFormat::F32: drwav_f32_to_s16((drwav_int16*)destination, (const float*)source, count); return;
					default: break;
				}
				break;

			case AudioDataFormat::F32:
				switch (srcFormat)
				{
					case AudioDataFormat::U8: drwav_u8_to_f32((float*)destination, (const drwav_uint8*)source, count); return;
					case AudioDataFormat::S16: drwav_s16_to_f32((float*)destination, (const drwav_int16*)source, count); return;
					case AudioDataFormat::S24: drwav_s24_to_f32((float*)destination, (const drwav_uint8*)source, count); return;
					case AudioDataFormat::S32: drwav_s32_to_f32((float*)destination, (const drwav_int32*)source, count); return;
					default: break;
				}
				break;

			case AudioDataFormat::S32:
				switch (srcFormat)
				{
					case AudioDataFormat::U8: drwav_u8_to_s32((drwav_int32*)destination, (const drwav_uint8*)source, count); return;
					case AudioDataFormat::S16: drwav_s16_to_s32((drwav_int32*)destination, (const drwav_int16*)source, count); return;
					case AudioDataFormat::S24: drwav_s24_to_s32((drwav_int32*)destination, (const drwav_uint8*)source, count); return;
					case AudioDataFormat::F32: drwav_f32_to_s32((drwav_int32*)destination, (const float*)source, count); return;
					default: break;
				}
				break;
 
			default:
				// U8 or S24 destination - dr_wav has no converter for these, fall through to the generic path below.
				break;
		}
		#endif

		// Generic Implementation
		uint8_t* pIn = (uint8_t*)source;
		uint8_t* pOut = (uint8_t*)destination;
		size_t inByteDepth = (size_t)AudioDataUtil::GetDataFormatByteDepth(srcFormat);
		size_t outByteDepth = (size_t)AudioDataUtil::GetDataFormatByteDepth(destFormat);

		for (size_t i = 0; i < count; ++i)
		{
			AudioDataUtil::WriteNormalized(pOut, destFormat, AudioDataUtil::ReadNormalized(pIn, srcFormat));
			pOut += outByteDepth;
			pIn += inByteDepth;
		}
	}

} // namespace lime
