/* Copyright (c) 2007-2012 IETF Trust, CSIRO, Xiph.Org Foundation. All rights reserved.
   Written by Jean-Marc Valin */
/**
   @file pitch.c
   @brief Pitch analysis
 */

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

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include "pitch.h"
#include "os_support.h"
#include "modes.h"
#include "stack_alloc.h"
#include "mathops.h"
#include "celt_lpc.h"

static void find_best_pitch(opus_val32 *xcorr, opus_val16 *y, int len,
                            int max_pitch, int *best_pitch
#ifdef FIXED_POINT
                            , int yshift, opus_val32 maxcorr
#endif
                            )
{
   int i, j;
   opus_val32 Syy=1;
   opus_val16 best_num[2];
   opus_val32 best_den[2];
#ifdef FIXED_POINT
   int xshift;

   xshift = celt_ilog2(maxcorr)-14;
#endif

   best_num[0] = -1;
   best_num[1] = -1;
   best_den[0] = 0;
   best_den[1] = 0;
   best_pitch[0] = 0;
   best_pitch[1] = 1;
   for (j=0;j<len;j++)
      Syy = MAC16_16(Syy, y[j],y[j]);
   for (i=0;i<max_pitch;i++)
   {
      if (xcorr[i]>0)
      {
         opus_val16 num;
         opus_val32 xcorr16;
         xcorr16 = EXTRACT16(VSHR32(xcorr[i], xshift));
         num = MULT16_16_Q15(xcorr16,xcorr16);
         if (MULT16_32_Q15(num,best_den[1]) > MULT16_32_Q15(best_num[1],Syy))
         {
            if (MULT16_32_Q15(num,best_den[0]) > MULT16_32_Q15(best_num[0],Syy))
            {
               best_num[1] = best_num[0];
               best_den[1] = best_den[0];
               best_pitch[1] = best_pitch[0];
               best_num[0] = num;
               best_den[0] = Syy;
               best_pitch[0] = i;
            } else {
               best_num[1] = num;
               best_den[1] = Syy;
               best_pitch[1] = i;
            }
         }
      }
      Syy += SHR32(MULT16_16(y[i+len],y[i+len]),yshift) - SHR32(MULT16_16(y[i],y[i]),yshift);
      Syy = MAX32(1, Syy);
   }
}

void pitch_downsample(celt_sig * restrict x[], opus_val16 * restrict x_lp,
      int len, int C)
{
   int i;
   opus_val32 ac[5];
   opus_val16 tmp=Q15ONE;
   opus_val16 lpc[4], mem[4]={0,0,0,0};
   for (i=1;i<len>>1;i++)
      x_lp[i] = SHR32(HALF32(HALF32(x[0][(2*i-1)]+x[0][(2*i+1)])+x[0][2*i]), SIG_SHIFT+3);
   x_lp[0] = SHR32(HALF32(HALF32(x[0][1])+x[0][0]), SIG_SHIFT+3);
   if (C==2)
   {
      for (i=1;i<len>>1;i++)
         x_lp[i] += SHR32(HALF32(HALF32(x[1][(2*i-1)]+x[1][(2*i+1)])+x[1][2*i]), SIG_SHIFT+3);
      x_lp[0] += SHR32(HALF32(HALF32(x[1][1])+x[1][0]), SIG_SHIFT+3);
   }

   _celt_autocorr(x_lp, ac, NULL, 0,
                  4, len>>1);

   /* Noise floor -40 dB */
#ifdef FIXED_POINT
   ac[0] += SHR32(ac[0],13);
#else
   ac[0] *= 1.0001f;
#endif
   /* Lag windowing */
   for (i=1;i<=4;i++)
   {
      /*ac[i] *= exp(-.5*(2*M_PI*.002*i)*(2*M_PI*.002*i));*/
#ifdef FIXED_POINT
      ac[i] -= MULT16_32_Q15(2*i*i, ac[i]);
#else
      ac[i] -= ac[i]*(.008f*i)*(.008f*i);
#endif
   }

   _celt_lpc(lpc, ac, 4);
   for (i=0;i<4;i++)
   {
      tmp = MULT16_16_Q15(QCONST16(.9f,15), tmp);
      lpc[i] = MULT16_16_Q15(lpc[i], tmp);
   }
   celt_fir(x_lp, lpc, x_lp, len>>1, 4, mem);

   mem[0]=0;
   lpc[0]=QCONST16(.8f,12);
   celt_fir(x_lp, lpc, x_lp, len>>1, 1, mem);

}

void pitch_search(const opus_val16 * restrict x_lp, opus_val16 * restrict y,
                  int len, int max_pitch, int *pitch)
{
   int i, j;
   int lag;
   int best_pitch[2]={0,0};
   VARDECL(opus_val16, x_lp4);
   VARDECL(opus_val16, y_lp4);
   VARDECL(opus_val32, xcorr);
#ifdef FIXED_POINT
   opus_val32 maxcorr=1;
   int shift=0;
#endif
   int offset;

   SAVE_STACK;

   celt_assert(len>0);
   celt_assert(max_pitch>0);
   lag = len+max_pitch;

   ALLOC(x_lp4, len>>2, opus_val16);
   ALLOC(y_lp4, lag>>2, opus_val16);
   ALLOC(xcorr, max_pitch>>1, opus_val32);

   /* Downsample by 2 again */
   for (j=0;j<len>>2;j++)
      x_lp4[j] = x_lp[2*j];
   for (j=0;j<lag>>2;j++)
      y_lp4[j] = y[2*j];

#ifdef FIXED_POINT
   shift = celt_ilog2(MAX16(1, MAX16(celt_maxabs16(x_lp4, len>>2), celt_maxabs16(y_lp4, lag>>2))))-11;
   if (shift>0)
   {
      for (j=0;j<len>>2;j++)
         x_lp4[j] = SHR16(x_lp4[j], shift);
      for (j=0;j<lag>>2;j++)
         y_lp4[j] = SHR16(y_lp4[j], shift);
      /* Use double the shift for a MAC */
      shift *= 2;
   } else {
      shift = 0;
   }
#endif

   /* Coarse search with 4x decimation */

   for (i=0;i<max_pitch>>2;i++)
   {
      opus_val32 sum = 0;
      for (j=0;j<len>>2;j++)
         sum = MAC16_16(sum, x_lp4[j],y_lp4[i+j]);
      xcorr[i] = MAX32(-1, sum);
#ifdef FIXED_POINT
      maxcorr = MAX32(maxcorr, sum);
#endif
   }
   find_best_pitch(xcorr, y_lp4, len>>2, max_pitch>>2, best_pitch
#ifdef FIXED_POINT
                   , 0, maxcorr
#endif
                   );

   /* Finer search with 2x decimation */
#ifdef FIXED_POINT
   maxcorr=1;
#endif
   for (i=0;i<max_pitch>>1;i++)
   {
      opus_val32 sum=0;
      xcorr[i] = 0;
      if (abs(i-2*best_pitch[0])>2 && abs(i-2*best_pitch[1])>2)
         continue;
      for (j=0;j<len>>1;j++)
         sum += SHR32(MULT16_16(x_lp[j],y[i+j]), shift);
      xcorr[i] = MAX32(-1, sum);
#ifdef FIXED_POINT
      maxcorr = MAX32(maxcorr, sum);
#endif
   }
   find_best_pitch(xcorr, y, len>>1, max_pitch>>1, best_pitch
#ifdef FIXED_POINT
                   , shift, maxcorr
#endif
                   );

   /* Refine by pseudo-interpolation */
   if (best_pitch[0]>0 && best_pitch[0]<(max_pitch>>1)-1)
   {
      opus_val32 a, b, c;
      a = xcorr[best_pitch[0]-1];
      b = xcorr[best_pitch[0]];
      c = xcorr[best_pitch[0]+1];
      if ((c-a) > MULT16_32_Q15(QCONST16(.7f,15),b-a))
         offset = 1;
      else if ((a-c) > MULT16_32_Q15(QCONST16(.7f,15),b-c))
         offset = -1;
      else
         offset = 0;
   } else {
      offset = 0;
   }
   *pitch = 2*best_pitch[0]-offset;

   RESTORE_STACK;
}

static const int second_check[16] = {0, 0, 3, 2, 3, 2, 5, 2, 3, 2, 3, 2, 5, 2, 3, 2};
