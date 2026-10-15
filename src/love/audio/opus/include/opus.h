/* Copyright (c) 2010-2012 IETF Trust, Xiph.Org Foundation, Skype Limited. All rights reserved.
   Written by Jean-Marc Valin and Koen Vos */
/*

   This file is extracted from RFC6716. Please see that RFC for additional
   information.

   Redistribution and use in source and binary forms, with or without
   modification, are permitted provided that the following conditions
   are met:

   - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

   - Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.

   - Neither the name of Internet Society, IETF or IETF Trust, nor the
   names of specific contributors, may be used to endorse or promote
   products derived from this software without specific prior written
   permission.

   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
   ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
   A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER
   OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
   EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
   PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

/**
 * @file opus.h
 * @brief Opus reference implementation API
 */

#ifndef OPUS_H
#define OPUS_H

#include "opus_types.h"
#include "opus_defines.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @mainpage Opus
 *
 * The Opus codec is designed for interactive speech and audio transmission over the Internet.
 * It is designed by the IETF Codec Working Group and incorporates technology from
 * Skype's SILK codec and Xiph.Org's CELT codec.
 *
 * The Opus codec is designed to handle a wide range of interactive audio applications,
 * including Voice over IP, videoconferencing, in-game chat, and even remote live music
 * performances. It can scale from low bit-rate narrowband speech to very high quality
 * stereo music. Its main features are:

 * @li Sampling rates from 8 to 48 kHz
 * @li Bit-rates from 6 kb/s 510 kb/s
 * @li Support for both constant bit-rate (CBR) and variable bit-rate (VBR)
 * @li Audio bandwidth from narrowband to full-band
 * @li Support for speech and music
 * @li Support for mono and stereo
 * @li Frame sizes from 2.5 ms to 60 ms
 * @li Good loss robustness and packet loss concealment (PLC)
 * @li Floating point and fixed-point implementation
 *
 * Documentation sections:
 * @li @ref opusdecoder
 * @li @ref repacketizer
 * @li @ref libinfo
 */

/** @defgroup opusdecoder Opus Decoder
  * @{
  *
  *
  * The decoding process also starts with creating a decoder
  * state. This can be done with:
  * @code
  * int          error;
  * OpusDecoder *dec;
  * dec = opus_decoder_create(Fs, channels, &error);
  * @endcode
  * where
  * @li Fs is the sampling rate and must be 8000, 12000, 16000, 24000, or 48000
  * @li channels is the number of channels (1 or 2)
  * @li error will hold the error code in case or failure (or OPUS_OK on success)
  * @li the return value is a newly created decoder state to be used for decoding
  *
  * While opus_decoder_create() allocates memory for the state, it's also possible
  * to initialize pre-allocated memory:
  * @code
  * int          size;
  * int          error;
  * OpusDecoder *dec;
  * size = opus_decoder_get_size(channels);
  * dec = malloc(size);
  * error = opus_decoder_init(dec, Fs, channels);
  * @endcode
  * where opus_decoder_get_size() returns the required size for the decoder state. Note that
  * future versions of this code may change the size, so no assuptions should be made about it.
  *
  * The decoder state is always continuous in memory and only a shallow copy is sufficient
  * to copy it (e.g. memcpy())
  *
  * To decode a frame, opus_decode() or opus_decode_float() must be called with a packet of compressed audio data:
  * @code
  * frame_size = opus_decode(enc, packet, len, decoded, max_size);
  * @endcode
  * where
  *
  * @li packet is the byte array containing the compressed data
  * @li len is the exact number of bytes contained in the packet
  * @li decoded is the decoded audio data in opus_int16 (or float for opus_decode_float())
  * @li max_size is the max duration of the frame in samples (per channel) that can fit into the decoded_frame array
  *
  * opus_decode() and opus_decode_frame() return the number of samples ()per channel) decoded from the packet.
  * If that value is negative, then an error has occured. This can occur if the packet is corrupted or if the audio
  * buffer is too small to hold the decoded audio.

*/

/** Opus decoder state.
  * This contains the complete state of an Opus decoder.
  * It is position independent and can be freely copied.
  * @see opus_decoder_create,opus_decoder_init
  */
typedef struct OpusDecoder OpusDecoder;

/** Gets the size of an OpusDecoder structure.
  * @param [in] channels <tt>int</tt>: Number of channels
  * @returns size
  */
OPUS_EXPORT int opus_decoder_get_size(int channels);

/** Allocates and initializes a decoder state.
  * @param [in] Fs <tt>opus_int32</tt>: Sampling rate of input signal (Hz)
  * @param [in] channels <tt>int</tt>: Number of channels (1/2) in input signal
  * @param [out] error <tt>int*</tt>: OPUS_OK Success or @ref errorcodes
  */
OPUS_EXPORT OpusDecoder *opus_decoder_create(
    opus_int32 Fs,
    int channels,
    int *error
);

/** Initializes a previously allocated decoder state.
  * The state must be the size returned by opus_decoder_get_size.
  * This is intended for applications which use their own allocator instead of malloc. @see opus_decoder_create,opus_decoder_get_size
  * To reset a previously initialized state use the OPUS_RESET_STATE CTL.
  * @param [in] st <tt>OpusDecoder*</tt>: Decoder state.
  * @param [in] Fs <tt>opus_int32</tt>: Sampling rate of input signal (Hz)
  * @param [in] channels <tt>int</tt>: Number of channels (1/2) in input signal
  * @retval OPUS_OK Success or @ref errorcodes
  */
OPUS_EXPORT int opus_decoder_init(
    OpusDecoder *st,
    opus_int32 Fs,
    int channels
);

/** Decode an Opus frame
  * @param [in] st <tt>OpusDecoder*</tt>: Decoder state
  * @param [in] data <tt>char*</tt>: Input payload. Use a NULL pointer to indicate packet loss
  * @param [in] len <tt>int</tt>: Number of bytes in payload*
  * @param [out] pcm <tt>opus_int16*</tt>: Output signal (interleaved if 2 channels). length
  *  is frame_size*channels*sizeof(opus_int16)
  * @param [in] frame_size Number of samples per channel of available space in *pcm,
  *  if less than the maximum frame size (120ms) some frames can not be decoded
  * @param [in] decode_fec <tt>int</tt>: Flag (0/1) to request that any in-band forward error correction data be
  *  decoded. If no such data is available the frame is decoded as if it were lost.
  * @returns Number of decoded samples or @ref errorcodes
  */
OPUS_EXPORT int opus_decode(
    OpusDecoder *st,
    const unsigned char *data,
    int len,
    opus_int16 *pcm,
    int frame_size,
    int decode_fec
);

/** Decode an opus frame with floating point output
  * @param [in] st <tt>OpusDecoder*</tt>: Decoder state
  * @param [in] data <tt>char*</tt>: Input payload. Use a NULL pointer to indicate packet loss
  * @param [in] len <tt>int</tt>: Number of bytes in payload
  * @param [out] pcm <tt>float*</tt>: Output signal (interleaved if 2 channels). length
  *  is frame_size*channels*sizeof(float)
  * @param [in] frame_size Number of samples per channel of available space in *pcm,
  *  if less than the maximum frame size (120ms) some frames can not be decoded
  * @param [in] decode_fec <tt>int</tt>: Flag (0/1) to request that any in-band forward error correction data be
  *  decoded. If no such data is available the frame is decoded as if it were lost.
  * @returns Number of decoded samples or @ref errorcodes
  */
OPUS_EXPORT int opus_decode_float(
    OpusDecoder *st,
    const unsigned char *data,
    int len,
    float *pcm,
    int frame_size,
    int decode_fec
);

/** Perform a CTL function on an Opus decoder.
  *
  * Generally the request and subsequent arguments are generated
  * by a convenience macro.
  * @see genericctls
  */
OPUS_EXPORT int opus_decoder_ctl(OpusDecoder *st, int request, ...);

/** Frees an OpusDecoder allocated by opus_decoder_create.
  * @param[in] st <tt>OpusDecoder*</tt>: State to be freed.
  */
OPUS_EXPORT void opus_decoder_destroy(OpusDecoder *st);

/** Parse an opus packet into one or more frames.
  * Opus_decode will perform this operation internally so most applications do
  * not need to use this function.
  * This function does not copy the frames, the returned pointers are pointers into
  * the input packet.
  * @param [in] data <tt>char*</tt>: Opus packet to be parsed
  * @param [in] len <tt>int</tt>: size of data
  * @param [out] out_toc <tt>char*</tt>: TOC pointer
  * @param [out] frames <tt>char*[48]</tt> encapsulated frames
  * @param [out] size <tt>short[48]</tt> sizes of the encapsulated frames
  * @param [out] payload_offset <tt>int*</tt>: returns the position of the payload within the packet (in bytes)
  * @returns number of frames
  */
OPUS_EXPORT int opus_packet_parse(
   const unsigned char *data,
   int len,
   unsigned char *out_toc,
   const unsigned char *frames[48],
   short size[48],
   int *payload_offset
);

/** Gets the bandwidth of an Opus packet.
  * @param [in] data <tt>char*</tt>: Opus packet
  * @retval OPUS_BANDWIDTH_NARROWBAND Narrowband (4kHz bandpass)
  * @retval OPUS_BANDWIDTH_MEDIUMBAND Mediumband (6kHz bandpass)
  * @retval OPUS_BANDWIDTH_WIDEBAND Wideband (8kHz bandpass)
  * @retval OPUS_BANDWIDTH_SUPERWIDEBAND Superwideband (12kHz bandpass)
  * @retval OPUS_BANDWIDTH_FULLBAND Fullband (20kHz bandpass)
  * @retval OPUS_INVALID_PACKET The compressed data passed is corrupted or of an unsupported type
  */
OPUS_EXPORT int opus_packet_get_bandwidth(const unsigned char *data);

/** Gets the number of samples per frame from an Opus packet.
  * @param [in] data <tt>char*</tt>: Opus packet
  * @param [in] Fs <tt>opus_int32</tt>: Sampling rate in Hz
  * @returns Number of samples per frame
  * @retval OPUS_INVALID_PACKET The compressed data passed is corrupted or of an unsupported type
  */
OPUS_EXPORT int opus_packet_get_samples_per_frame(const unsigned char *data, opus_int32 Fs);

/** Gets the number of channels from an Opus packet.
  * @param [in] data <tt>char*</tt>: Opus packet
  * @returns Number of channels
  * @retval OPUS_INVALID_PACKET The compressed data passed is corrupted or of an unsupported type
  */
OPUS_EXPORT int opus_packet_get_nb_channels(const unsigned char *data);

/** Gets the number of frames in an Opus packet.
  * @param [in] packet <tt>char*</tt>: Opus packet
  * @param [in] len <tt>int</tt>: Length of packet
  * @returns Number of frames
  * @retval OPUS_INVALID_PACKET The compressed data passed is corrupted or of an unsupported type
  */
OPUS_EXPORT int opus_packet_get_nb_frames(const unsigned char packet[], int len);

/** Gets the number of samples of an Opus packet.
  * @param [in] dec <tt>OpusDecoder*</tt>: Decoder state
  * @param [in] packet <tt>char*</tt>: Opus packet
  * @param [in] len <tt>int</tt>: Length of packet
  * @returns Number of samples
  * @retval OPUS_INVALID_PACKET The compressed data passed is corrupted or of an unsupported type
  */
OPUS_EXPORT int opus_decoder_get_nb_samples(const OpusDecoder *dec, const unsigned char packet[], int len);
/**@}*/

/** @defgroup repacketizer Repacketizer
  * @{
  *
  * The repacketizer can be used to merge multiple Opus packets into a single packet
  * or alternatively to split Opus packets that have previously been merged.
  *
  */

typedef struct OpusRepacketizer OpusRepacketizer;

OPUS_EXPORT int opus_repacketizer_get_size(void);

OPUS_EXPORT OpusRepacketizer *opus_repacketizer_init(OpusRepacketizer *rp);

OPUS_EXPORT OpusRepacketizer *opus_repacketizer_create(void);

OPUS_EXPORT void opus_repacketizer_destroy(OpusRepacketizer *rp);

OPUS_EXPORT int opus_repacketizer_cat(OpusRepacketizer *rp, const unsigned char *data, int len);

OPUS_EXPORT opus_int32 opus_repacketizer_out_range(OpusRepacketizer *rp, int begin, int end, unsigned char *data, int maxlen);

OPUS_EXPORT int opus_repacketizer_get_nb_frames(OpusRepacketizer *rp);

OPUS_EXPORT opus_int32 opus_repacketizer_out(OpusRepacketizer *rp, unsigned char *data, int maxlen);

/**@}*/

#ifdef __cplusplus
}
#endif

#endif /* OPUS_H */
