// rfc 6716 reference code; see opus/COPYING
#include <math.h>
#if (defined(__STDC__) && __STDC__ && __STDC_VERSION__ >= 199901L) || (defined(__GNUC__) && (defined(_STDINT_H) || defined(_STDINT_H_)) || defined (HAVE_STDINT_H))
#include <stdint.h>
   typedef int16_t opus_int16;
   typedef uint16_t opus_uint16;
   typedef int32_t opus_int32;
   typedef uint32_t opus_uint32;
#elif (defined(__APPLE__) && defined(__MACH__))
#include <sys/types.h>
   typedef int16_t opus_int16;
   typedef u_int16_t opus_uint16;
   typedef int32_t opus_int32;
   typedef u_int32_t opus_uint32;
#else
   typedef short opus_int16;
   typedef unsigned short opus_uint16;
   typedef int opus_int32;
   typedef unsigned int opus_uint32;
#endif
#define opus_int         int
#define opus_int64       long long
#define opus_int8        signed char
#define opus_uint8       unsigned char

# if !defined(__GNUC_PREREQ)
#   define __GNUC_PREREQ(_maj,_min) \
 ((__GNUC__<<16)+__GNUC_MINOR__>=((_maj)<<16)+(_min))
# endif
#define CELT_SIG_SCALE 32768.f
#define celt_assert(cond)
#define celt_assert2(cond, message)
#define IMUL32(a,b) ((a)*(b))
#define MIN16(a,b) ((a) < (b) ? (a) : (b))
#define MAX16(a,b) ((a) > (b) ? (a) : (b))
#define MIN32(a,b) ((a) < (b) ? (a) : (b))
#define MAX32(a,b) ((a) > (b) ? (a) : (b))
#define IMIN(a,b) ((a) < (b) ? (a) : (b))
#define IMAX(a,b) ((a) > (b) ? (a) : (b))
#define UADD32(a,b) ((a)+(b))
#define USUB32(a,b) ((a)-(b))
typedef float opus_val16;
typedef float opus_val32;
typedef float celt_sig;
typedef float celt_norm;
typedef float celt_ener;
#define Q15ONE 1.0f
#define NORM_SCALING 1.f
#define EPSILON 1e-15f
#define Q15_ONE ((opus_val16)1.f)
#define QCONST16(x,bits) (x)
#define QCONST32(x,bits) (x)
#define EXTRACT16(x) (x)
#define EXTEND32(x) (x)
#define SHR16(a,shift) (a)
#define SHL16(a,shift) (a)
#define SHR32(a,shift) (a)
#define SHL32(a,shift) (a)
#define PSHR32(a,shift) (a)
#define VSHR32(a,shift) (a)
#define SHR(a,shift)    (a)
#define ROUND16(a,shift)  (a)
#define HALF16(x)       (.5f*(x))
#define HALF32(x)       (.5f*(x))
#define ADD16(a,b) ((a)+(b))
#define SUB16(a,b) ((a)-(b))
#define ADD32(a,b) ((a)+(b))
#define MULT16_16(a,b)     ((opus_val32)(a)*(opus_val32)(b))
#define MAC16_16(c,a,b)     ((c)+(opus_val32)(a)*(opus_val32)(b))
#define MULT16_32_Q15(a,b)     ((a)*(b))
#define MULT32_32_Q31(a,b)     ((a)*(b))
#define MULT16_16_Q15(a,b)     ((a)*(b))
#define MULT16_16_P15(a,b)     ((a)*(b))
#define SCALEOUT(a)     ((a)*(1/CELT_SIG_SCALE))
#ifndef GLOBAL_STACK_SIZE
#define GLOBAL_STACK_SIZE 100000
#endif

#define OPUS_OK                0
#define OPUS_BAD_ARG          -1
#define OPUS_BUFFER_TOO_SMALL -2
#define OPUS_INTERNAL_ERROR   -3
#define OPUS_INVALID_PACKET   -4
#define OPUS_UNIMPLEMENTED    -5
#define OPUS_ALLOC_FAIL       -7
# define OPUS_EXPORT __attribute__ ((visibility ("default")))
#define OPUS_GET_FINAL_RANGE_REQUEST         4031
#define __opus_check_int(x) (((void)((x) == (opus_int32)0)), (opus_int32)(x))
#define __opus_check_uint_ptr(ptr) ((ptr) + ((ptr) - (opus_uint32*)(ptr)))
#define OPUS_BANDWIDTH_NARROWBAND            1101
#define OPUS_BANDWIDTH_MEDIUMBAND            1102
#define OPUS_BANDWIDTH_WIDEBAND              1103
#define OPUS_BANDWIDTH_SUPERWIDEBAND         1104
#define OPUS_BANDWIDTH_FULLBAND              1105
#define OPUS_RESET_STATE 4028
#define OPUS_GET_FINAL_RANGE(x) OPUS_GET_FINAL_RANGE_REQUEST, __opus_check_uint_ptr(x)

#define OPUS_CUSTOM_EXPORT
#define OPUS_CUSTOM_EXPORT_STATIC static inline
typedef struct OpusCustomDecoder OpusCustomDecoder;
typedef struct OpusCustomMode OpusCustomMode;
OPUS_CUSTOM_EXPORT OpusCustomMode *opus_custom_mode_create(opus_int32 Fs, int frame_size, int *error);
OPUS_CUSTOM_EXPORT_STATIC int opus_custom_decoder_get_size(const OpusCustomMode *mode, int channels);
OPUS_CUSTOM_EXPORT_STATIC int opus_custom_decoder_init(OpusCustomDecoder *st, const OpusCustomMode *mode, int channels);
OPUS_CUSTOM_EXPORT int opus_custom_decoder_ctl(OpusCustomDecoder * restrict st, int request, ...);

#include <limits.h>
#include <stddef.h>
#define EC_MINI(_a,_b)      ((_a)+(((_b)-(_a))&-((_b)<(_a))))
#if   __GNUC_PREREQ(3,4)
#  define EC_CLZ0    ((int)sizeof(unsigned)*CHAR_BIT)
#  define EC_CLZ(_x) (__builtin_clz(_x))
#endif
#if defined(EC_CLZ)
#define EC_ILOG(_x) (EC_CLZ0-EC_CLZ(_x))
#else
int ec_ilog(opus_uint32 _v);
#define EC_ILOG(_x) (ec_ilog(_x))
#endif

typedef opus_uint32           ec_window;
typedef struct ec_ctx         ec_ctx;
typedef struct ec_ctx         ec_enc;
typedef struct ec_ctx         ec_dec;
#define EC_WINDOW_SIZE ((int)sizeof(ec_window)*CHAR_BIT)
#define EC_UINT_BITS   (8)
#define BITRES 3
struct ec_ctx{
   unsigned char *buf;
   opus_uint32    storage;
   opus_uint32    end_offs;
   ec_window      end_window;
   int            nend_bits;
   int            nbits_total;
   opus_uint32    offs;
   opus_uint32    rng;
   opus_uint32    val;
   opus_uint32    ext;
   int            rem;
   int            error;
};
static inline int ec_get_error(ec_ctx *_this){
  return _this->error;
}
static inline int ec_tell(ec_ctx *_this){
  return _this->nbits_total-EC_ILOG(_this->rng);
}
opus_uint32 ec_tell_frac(ec_ctx *_this);

void ec_dec_init(ec_dec *_this,unsigned char *_buf,opus_uint32 _storage);
unsigned ec_decode(ec_dec *_this,unsigned _ft);
unsigned ec_decode_bin(ec_dec *_this,unsigned _bits);
void ec_dec_update(ec_dec *_this,unsigned _fl,unsigned _fh,unsigned _ft);
int ec_dec_bit_logp(ec_dec *_this,unsigned _logp);
int ec_dec_icdf(ec_dec *_this,const unsigned char *_icdf,unsigned _ftb);
opus_uint32 ec_dec_uint(ec_dec *_this,opus_uint32 _ft);
opus_uint32 ec_dec_bits(ec_dec *_this,unsigned _ftb);

#define CELTDecoder OpusCustomDecoder
#define CELTMode OpusCustomMode
#define _celt_check_mode_ptr_ptr(ptr) ((ptr) + ((ptr) - (const CELTMode**)(ptr)))
#define CELT_SET_CHANNELS_REQUEST    10008
#define CELT_SET_CHANNELS(x) CELT_SET_CHANNELS_REQUEST, __opus_check_int(x)
#define CELT_SET_START_BAND_REQUEST    10010
#define CELT_SET_START_BAND(x) CELT_SET_START_BAND_REQUEST, __opus_check_int(x)
#define CELT_SET_END_BAND_REQUEST    10012
#define CELT_SET_END_BAND(x) CELT_SET_END_BAND_REQUEST, __opus_check_int(x)
#define CELT_GET_MODE_REQUEST    10015
#define CELT_GET_MODE(x) CELT_GET_MODE_REQUEST, _celt_check_mode_ptr_ptr(x)
#define CELT_SET_SIGNALLING_REQUEST    10016
#define CELT_SET_SIGNALLING(x) CELT_SET_SIGNALLING_REQUEST, __opus_check_int(x)
int celt_decoder_get_size(int channels);
int celt_decoder_init(CELTDecoder *st, opus_int32 sampling_rate, int channels);
int celt_decode_with_ec(OpusCustomDecoder * restrict st, const unsigned char *data, int len, opus_val16 * restrict pcm, int frame_size, ec_dec *dec);
#define celt_decoder_ctl opus_custom_decoder_ctl

#include <stdlib.h>
# ifndef kiss_fft_scalar
#   define kiss_fft_scalar float
#   define kiss_twiddle_scalar float
# endif
typedef struct {
    kiss_fft_scalar r;
    kiss_fft_scalar i;
}kiss_fft_cpx;
typedef struct {
   kiss_twiddle_scalar r;
   kiss_twiddle_scalar i;
}kiss_twiddle_cpx;
#define MAXFACTORS 8
typedef struct kiss_fft_state{
    int nfft;
    kiss_fft_scalar scale;
    int shift;
    opus_int16 factors[2*MAXFACTORS];
    const opus_int16 *bitrev;
    const kiss_twiddle_cpx *twiddles;
} kiss_fft_state;
void opus_ifft(const kiss_fft_state *cfg,const kiss_fft_cpx *fin,kiss_fft_cpx *fout);

typedef struct {
   int n;
   int maxshift;
   const kiss_fft_state *kfft[4];
   const kiss_twiddle_scalar * restrict trig;
} mdct_lookup;
void clt_mdct_backward(const mdct_lookup *l, kiss_fft_scalar *in, kiss_fft_scalar *out,
      const opus_val16 * restrict window, int overlap, int shift, int stride);

#define MAX_PERIOD 1024
#ifndef OVERLAP
#define OVERLAP(mode) ((mode)->overlap)
#endif
typedef struct {
   int size;
   const opus_int16 *index;
   const unsigned char *bits;
   const unsigned char *caps;
} PulseCache;
struct OpusCustomMode {
   opus_int32 Fs;
   int          overlap;
   int          nbEBands;
   int          effEBands;
   opus_val16    preemph[4];
   const opus_int16   *eBands;
   int         maxLM;
   int         nbShortMdcts;
   int         shortMdctSize;
   int          nbAllocVectors;
   const unsigned char   *allocVectors;
   const opus_int16 *logN;
   const opus_val16 *window;
   mdct_lookup mdct;
   PulseCache cache;
};

#define LOG_MAX_PSEUDO 6
#define MAX_PULSES 128
#define MAX_FINE_BITS 8
#define FINE_OFFSET 21
#define QTHETA_OFFSET 4
#define QTHETA_OFFSET_TWOPHASE 16
char *global_stack=0;
#define ALIGN(stack, size) ((stack) += ((size) - (long)(stack)) & ((size) - 1))
#define PUSH(stack, size, type) (ALIGN((stack),sizeof(type)/sizeof(char)),(stack)+=(size)*(sizeof(type)/sizeof(char)),(type*)((stack)-(size)*(sizeof(type)/sizeof(char))))
#define RESTORE_STACK (global_stack = _saved_stack)
#define ALLOC_STACK char *_saved_stack; (global_stack = (global_stack==0) ? opus_alloc_scratch(GLOBAL_STACK_SIZE) : global_stack); _saved_stack = global_stack;
#include <string.h>
#include <stdio.h>
#define OPUS_COPY(dst, src, n) (memcpy((dst), (src), (n)*sizeof(*(dst)) + 0*((dst)-(src)) ))
#define OPUS_MOVE(dst, src, n) (memmove((dst), (src), (n)*sizeof(*(dst)) + 0*((dst)-(src)) ))
#define OPUS_CLEAR(dst, n) (memset((dst), 0, (n)*sizeof(*(dst))))

#define VARDECL(type, var) type *var
#define ALLOC(var, size, type) var = PUSH(global_stack, size, type)
#define SAVE_STACK char *_saved_stack = global_stack;

void decode_pulses(int *_y, int N, int K, ec_dec *dec);

static inline int get_pulses(int i)
{
   return i<8 ? i : (8 + (i&7)) << ((i>>3)-1);
}
static inline int bits2pulses(const CELTMode *m, int band, int LM, int bits)
{
   int i;
   int lo, hi;
   const unsigned char *cache;
   LM++;
   cache = m->cache.bits + m->cache.index[LM*m->nbEBands+band];
   lo = 0;
   hi = cache[0];
   bits--;
   for (i=0;i<LOG_MAX_PSEUDO;i++)
   {
      int mid = (lo+hi+1)>>1;
      if (cache[mid] >= bits)
         hi = mid;
      else
         lo = mid;
   }
   if (bits- (lo == 0 ? -1 : cache[lo]) <= cache[hi]-bits)
      return lo;
   else
      return hi;
}
static inline int pulses2bits(const CELTMode *m, int band, int LM, int pulses)
{
   const unsigned char *cache;
   LM++;
   cache = m->cache.bits + m->cache.index[LM*m->nbEBands+band];
   return pulses == 0 ? 0 : cache[pulses]+1;
}
int compute_allocation(const CELTMode *m, int start, int end, const int *offsets, const int *cap, int alloc_trim, int *intensity, int *dual_stero,
      opus_int32 total, opus_int32 *balance, int *pulses, int *ebits, int *fine_priority, int C, int LM, ec_ctx *ec, int prev);

void denormalise_bands(const CELTMode *m, const celt_norm * restrict X, celt_sig * restrict freq, const celt_ener *bandE, int end, int C, int M);
#define SPREAD_NONE       (0)
#define SPREAD_NORMAL     (2)
#define SPREAD_AGGRESSIVE (3)
void haar1(celt_norm *X, int N0, int stride);
void quant_all_bands(const CELTMode *m, int start, int end,
      celt_norm * X, celt_norm * Y, unsigned char *collapse_masks, const celt_ener *bandE, int *pulses,
      int time_domain, int fold, int dual_stereo, int intensity, int *tf_res,
      opus_int32 total_bits, opus_int32 balance, ec_ctx *ec, int M, int codedBands, opus_uint32 *seed);
void anti_collapse(const CELTMode *m, celt_norm *X_, unsigned char *collapse_masks, int LM, int C, int size,
      int start, int end, opus_val16 *logE, opus_val16 *prev1logE,
      opus_val16 *prev2logE, int *pulses, opus_uint32 seed);
opus_uint32 celt_lcg_rand(opus_uint32 seed);

unsigned alg_unquant(celt_norm *X, int N, int K, int spread, int B,
      ec_dec *dec, opus_val16 gain);
void renormalise_vector(celt_norm *X, int N, opus_val16 gain);

#define FRAC_MUL16(a,b) ((16384+((opus_int32)(opus_int16)(a)*(opus_int16)(b)))>>15)
unsigned isqrt32(opus_uint32 _val);
#define PI 3.141592653f
#define celt_sqrt(x) ((float)sqrt(x))
#define celt_rsqrt(x) (1.f/celt_sqrt(x))
#define celt_rsqrt_norm(x) (celt_rsqrt(x))
#define celt_cos_norm(x) ((float)cos((.5f*PI)*(x)))
#define celt_div(a,b) ((a)/(b))
#define frac_div32(a,b) ((float)(a)/(b))
#define celt_exp2(x) ((float)exp(0.6931471805599453094*(x)))

opus_uint32 celt_lcg_rand(opus_uint32 seed)
{
   return 1664525 * seed + 1013904223;
}
static opus_int16 bitexact_cos(opus_int16 x)
{
   opus_int32 tmp;
   opus_int16 x2;
   tmp = (4096+((opus_int32)(x)*(x)))>>13;
   celt_assert(tmp<=32767);
   x2 = tmp;
   x2 = (32767-x2) + FRAC_MUL16(x2, (-7651 + FRAC_MUL16(x2, (8277 + FRAC_MUL16(-626, x2)))));
   celt_assert(x2<=32766);
   return 1+x2;
}
static int bitexact_log2tan(int isin,int icos)
{
   int lc;
   int ls;
   lc=EC_ILOG(icos);
   ls=EC_ILOG(isin);
   icos<<=15-lc;
   isin<<=15-ls;
   return (ls-lc)*(1<<11)
         +FRAC_MUL16(isin, FRAC_MUL16(isin, -2597) + 7932)
         -FRAC_MUL16(icos, FRAC_MUL16(icos, -2597) + 7932);
}
void denormalise_bands(const CELTMode *m, const celt_norm * restrict X, celt_sig * restrict freq, const celt_ener *bandE, int end, int C, int M)
{
   int i, c, N;
   const opus_int16 *eBands = m->eBands;
   N = M*m->shortMdctSize;
   celt_assert2(C<=2, "denormalise_bands() not implemented for >2 channels");
   c=0; do {
      celt_sig * restrict f;
      const celt_norm * restrict x;
      f = freq+c*N;
      x = X+c*N;
      for (i=0;i<end;i++)
      {
         int j, band_end;
         opus_val32 g = SHR32(bandE[i+c*m->nbEBands],1);
         j=M*eBands[i];
         band_end = M*eBands[i+1];
         do {
            *f++ = SHL32(MULT16_32_Q15(*x, g),2);
            x++;
         } while (++j<band_end);
      }
      for (i=M*eBands[end];i<N;i++)
         *f++ = 0;
   } while (++c<C);
}
void anti_collapse(const CELTMode *m, celt_norm *X_, unsigned char *collapse_masks, int LM, int C, int size,
      int start, int end, opus_val16 *logE, opus_val16 *prev1logE,
      opus_val16 *prev2logE, int *pulses, opus_uint32 seed)
{
   int c, i, j, k;
   for (i=start;i<end;i++)
   {
      int N0;
      opus_val16 thresh, sqrt_1;
      int depth;
      N0 = m->eBands[i+1]-m->eBands[i];
      depth = (1+pulses[i])/((m->eBands[i+1]-m->eBands[i])<<LM);
      thresh = .5f*celt_exp2(-.125f*depth);
      sqrt_1 = celt_rsqrt(N0<<LM);
      c=0; do
      {
         celt_norm *X;
         opus_val16 prev1;
         opus_val16 prev2;
         opus_val32 Ediff;
         opus_val16 r;
         int renormalize=0;
         prev1 = prev1logE[c*m->nbEBands+i];
         prev2 = prev2logE[c*m->nbEBands+i];
         if (C==1)
         {
            prev1 = MAX16(prev1,prev1logE[m->nbEBands+i]);
            prev2 = MAX16(prev2,prev2logE[m->nbEBands+i]);
         }
         Ediff = EXTEND32(logE[c*m->nbEBands+i])-EXTEND32(MIN16(prev1,prev2));
         Ediff = MAX16(0, Ediff);
         r = 2.f*celt_exp2(-Ediff);
         if (LM==3)
            r *= 1.41421356f;
         r = MIN16(thresh, r);
         r = r*sqrt_1;
         X = X_+c*size+(m->eBands[i]<<LM);
         for (k=0;k<1<<LM;k++)
         {
            if (!(collapse_masks[i*C+c]&1<<k))
            {
               for (j=0;j<N0;j++)
               {
                  seed = celt_lcg_rand(seed);
                  X[(j<<LM)+k] = (seed&0x8000 ? r : -r);
               }
               renormalize = 1;
            }
         }
         if (renormalize)
            renormalise_vector(X, N0<<LM, Q15ONE);
      } while (++c<C);
   }
}
static void stereo_merge(celt_norm *X, celt_norm *Y, opus_val16 mid, int N)
{
   int j;
   opus_val32 xp=0, side=0;
   opus_val32 El, Er;
   opus_val16 mid2;
   opus_val32 t, lgain, rgain;
   for (j=0;j<N;j++)
   {
      xp = MAC16_16(xp, X[j], Y[j]);
      side = MAC16_16(side, Y[j], Y[j]);
   }
   xp = MULT16_32_Q15(mid, xp);
   mid2 = SHR32(mid, 1);
   El = MULT16_16(mid2, mid2) + side - 2*xp;
   Er = MULT16_16(mid2, mid2) + side + 2*xp;
   if (Er < QCONST32(6e-4f, 28) || El < QCONST32(6e-4f, 28))
   {
      for (j=0;j<N;j++)
         Y[j] = X[j];
      return;
   }
   t = VSHR32(El, (kl-7)<<1);
   lgain = celt_rsqrt_norm(t);
   t = VSHR32(Er, (kr-7)<<1);
   rgain = celt_rsqrt_norm(t);
   for (j=0;j<N;j++)
   {
      celt_norm r, l;
      l = MULT16_16_Q15(mid, X[j]);
      r = Y[j];
      X[j] = EXTRACT16(PSHR32(MULT16_16(lgain, SUB16(l,r)), kl+1));
      Y[j] = EXTRACT16(PSHR32(MULT16_16(rgain, ADD16(l,r)), kr+1));
   }
}
static const int ordery_table[] = {
       1,  0,
       3,  0,  2,  1,
       7,  0,  4,  3,  6,  1,  5,  2,
      15,  0,  8,  7, 12,  3, 11,  4, 14,  1,  9,  6, 13,  2, 10,  5,
};
static void deinterleave_hadamard(celt_norm *X, int N0, int stride, int hadamard)
{
   int i,j;
   VARDECL(celt_norm, tmp);
   int N;
   SAVE_STACK;
   N = N0*stride;
   ALLOC(tmp, N, celt_norm);
   celt_assert(stride>0);
   if (hadamard)
   {
      const int *ordery = ordery_table+stride-2;
      for (i=0;i<stride;i++)
      {
         for (j=0;j<N0;j++)
            tmp[ordery[i]*N0+j] = X[j*stride+i];
      }
   } else {
      for (i=0;i<stride;i++)
         for (j=0;j<N0;j++)
            tmp[i*N0+j] = X[j*stride+i];
   }
   for (j=0;j<N;j++)
      X[j] = tmp[j];
   RESTORE_STACK;
}
static void interleave_hadamard(celt_norm *X, int N0, int stride, int hadamard)
{
   int i,j;
   VARDECL(celt_norm, tmp);
   int N;
   SAVE_STACK;
   N = N0*stride;
   ALLOC(tmp, N, celt_norm);
   if (hadamard)
   {
      const int *ordery = ordery_table+stride-2;
      for (i=0;i<stride;i++)
         for (j=0;j<N0;j++)
            tmp[j*stride+i] = X[ordery[i]*N0+j];
   } else {
      for (i=0;i<stride;i++)
         for (j=0;j<N0;j++)
            tmp[j*stride+i] = X[i*N0+j];
   }
   for (j=0;j<N;j++)
      X[j] = tmp[j];
   RESTORE_STACK;
}
void haar1(celt_norm *X, int N0, int stride)
{
   int i, j;
   N0 >>= 1;
   for (i=0;i<stride;i++)
      for (j=0;j<N0;j++)
      {
         celt_norm tmp1, tmp2;
         tmp1 = MULT16_16_Q15(QCONST16(.70710678f,15), X[stride*2*j+i]);
         tmp2 = MULT16_16_Q15(QCONST16(.70710678f,15), X[stride*(2*j+1)+i]);
         X[stride*2*j+i] = tmp1 + tmp2;
         X[stride*(2*j+1)+i] = tmp1 - tmp2;
      }
}
static int compute_qn(int N, int b, int offset, int pulse_cap, int stereo)
{
   static const opus_int16 exp2_table8[8] =
      {16384, 17866, 19483, 21247, 23170, 25267, 27554, 30048};
   int qn, qb;
   int N2 = 2*N-1;
   if (stereo && N==2)
      N2--;
   qb = IMIN(b-pulse_cap-(4<<BITRES), (b+N2*offset)/N2);
   qb = IMIN(8<<BITRES, qb);
   if (qb<(1<<BITRES>>1)) {
      qn = 1;
   } else {
      qn = exp2_table8[qb&0x7]>>(14-(qb>>BITRES));
      qn = (qn+1)>>1<<1;
   }
   celt_assert(qn <= 256);
   return qn;
}
static unsigned quant_band(const CELTMode *m, int i, celt_norm *X, celt_norm *Y,
      int N, int b, int spread, int B, int intensity, int tf_change, celt_norm *lowband, ec_ctx *ec,
      opus_int32 *remaining_bits, int LM, celt_norm *lowband_out, const celt_ener *bandE, int level,
      opus_uint32 *seed, opus_val16 gain, celt_norm *lowband_scratch, int fill)
{
   const unsigned char *cache;
   int q;
   int curr_bits;
   int stereo, split;
   int imid=0, iside=0;
   int N0=N;
   int N_B=N;
   int N_B0;
   int B0=B;
   int time_divide=0;
   int recombine=0;
   int inv = 0;
   opus_val16 mid=0, side=0;
   int longBlocks;
   unsigned cm=0;
   longBlocks = B0==1;
   N_B /= B;
   N_B0 = N_B;
   split = stereo = Y != NULL;
   if (N==1)
   {
      int c;
      celt_norm *x = X;
      c=0; do {
         int sign=0;
         if (*remaining_bits>=1<<BITRES)
         {
            sign = ec_dec_bits(ec, 1);
            *remaining_bits -= 1<<BITRES;
            b-=1<<BITRES;
         }
         x[0] = sign ? -NORM_SCALING : NORM_SCALING;
         x = Y;
      } while (++c<1+stereo);
      if (lowband_out)
         lowband_out[0] = SHR16(X[0],4);
      return 1;
   }
   if (!stereo && level == 0)
   {
      int k;
      if (tf_change>0)
         recombine = tf_change;
      if (lowband && (recombine || ((N_B&1) == 0 && tf_change<0) || B0>1))
      {
         int j;
         for (j=0;j<N;j++)
            lowband_scratch[j] = lowband[j];
         lowband = lowband_scratch;
      }
      for (k=0;k<recombine;k++)
      {
         static const unsigned char bit_interleave_table[16]={
           0,1,1,1,2,3,3,3,2,3,3,3,2,3,3,3
         };
         if (lowband)
            haar1(lowband, N>>k, 1<<k);
         fill = bit_interleave_table[fill&0xF]|bit_interleave_table[fill>>4]<<2;
      }
      B>>=recombine;
      N_B<<=recombine;
      while ((N_B&1) == 0 && tf_change<0)
      {
         if (lowband)
            haar1(lowband, N_B, B);
         fill |= fill<<B;
         B <<= 1;
         N_B >>= 1;
         time_divide++;
         tf_change++;
      }
      B0=B;
      N_B0 = N_B;
      if (B0>1)
      {
         if (lowband)
            deinterleave_hadamard(lowband, N_B>>recombine, B0<<recombine, longBlocks);
      }
   }
   cache = m->cache.bits + m->cache.index[(LM+1)*m->nbEBands+i];
   if (!stereo && LM != -1 && b > cache[cache[0]]+12 && N>2)
   {
      N >>= 1;
      Y = X+N;
      split = 1;
      LM -= 1;
      if (B==1)
         fill = (fill&1)|(fill<<1);
      B = (B+1)>>1;
   }
   if (split)
   {
      int qn;
      int itheta=0;
      int mbits, sbits, delta;
      int qalloc;
      int pulse_cap;
      int offset;
      int orig_fill;
      opus_int32 tell;
      pulse_cap = m->logN[i]+LM*(1<<BITRES);
      offset = (pulse_cap>>1) - (stereo&&N==2 ? QTHETA_OFFSET_TWOPHASE : QTHETA_OFFSET);
      qn = compute_qn(N, b, offset, pulse_cap, stereo);
      if (stereo && i>=intensity)
         qn = 1;
      tell = ec_tell_frac(ec);
      if (qn!=1)
      {
         if (stereo && N>2)
         {
            int p0 = 3;
            int x = itheta;
            int x0 = qn/2;
            int ft = p0*(x0+1) + x0;
            int fs;
            fs=ec_decode(ec,ft);
            if (fs<(x0+1)*p0)
               x=fs/p0;
            else
               x=x0+1+(fs-(x0+1)*p0);
            ec_dec_update(ec,x<=x0?p0*x:(x-1-x0)+(x0+1)*p0,x<=x0?p0*(x+1):(x-x0)+(x0+1)*p0,ft);
            itheta = x;
         } else if (B0>1 || stereo) {
            itheta = ec_dec_uint(ec, qn+1);
         } else {
            int fs=1, ft;
            ft = ((qn>>1)+1)*((qn>>1)+1);
            int fl=0;
            int fm;
            fm = ec_decode(ec, ft);
            if (fm < ((qn>>1)*((qn>>1) + 1)>>1))
            {
               itheta = (isqrt32(8*(opus_uint32)fm + 1) - 1)>>1;
               fs = itheta + 1;
               fl = itheta*(itheta + 1)>>1;
            }
            else
            {
               itheta = (2*(qn + 1)
                - isqrt32(8*(opus_uint32)(ft - fm - 1) + 1))>>1;
               fs = qn + 1 - itheta;
               fl = ft - ((qn + 1 - itheta)*(qn + 2 - itheta)>>1);
            }
            ec_dec_update(ec, fl, fl+fs, ft);
         }
         itheta = (opus_int32)itheta*16384/qn;
      } else if (stereo) {
         if (b>2<<BITRES && *remaining_bits > 2<<BITRES)
         {
            inv = ec_dec_bit_logp(ec, 2);
         } else
            inv = 0;
         itheta = 0;
      }
      qalloc = ec_tell_frac(ec) - tell;
      b -= qalloc;
      orig_fill = fill;
      if (itheta == 0)
      {
         imid = 32767;
         iside = 0;
         fill &= (1<<B)-1;
         delta = -16384;
      } else if (itheta == 16384)
      {
         imid = 0;
         iside = 32767;
         fill &= ((1<<B)-1)<<B;
         delta = 16384;
      } else {
         imid = bitexact_cos(itheta);
         iside = bitexact_cos(16384-itheta);
         delta = FRAC_MUL16((N-1)<<7,bitexact_log2tan(iside,imid));
      }
      mid = (1.f/32768)*imid;
      side = (1.f/32768)*iside;
      if (N==2 && stereo)
      {
         int c;
         int sign=0;
         celt_norm *x2, *y2;
         mbits = b;
         sbits = 0;
         if (itheta != 0 && itheta != 16384)
            sbits = 1<<BITRES;
         mbits -= sbits;
         c = itheta > 8192;
         *remaining_bits -= qalloc+sbits;
         x2 = c ? Y : X;
         y2 = c ? X : Y;
         if (sbits)
         {
            sign = ec_dec_bits(ec, 1);
         }
         sign = 1-2*sign;
         cm = quant_band(m, i, x2, NULL, N, mbits, spread, B, intensity, tf_change, lowband, ec, remaining_bits, LM, lowband_out, NULL, level, seed, gain, lowband_scratch, orig_fill);
         y2[0] = -sign*x2[1];
         y2[1] = sign*x2[0];
         {
            celt_norm tmp;
            X[0] = MULT16_16_Q15(mid, X[0]);
            X[1] = MULT16_16_Q15(mid, X[1]);
            Y[0] = MULT16_16_Q15(side, Y[0]);
            Y[1] = MULT16_16_Q15(side, Y[1]);
            tmp = X[0];
            X[0] = SUB16(tmp,Y[0]);
            Y[0] = ADD16(tmp,Y[0]);
            tmp = X[1];
            X[1] = SUB16(tmp,Y[1]);
            Y[1] = ADD16(tmp,Y[1]);
         }
      } else {
         celt_norm *next_lowband2=NULL;
         celt_norm *next_lowband_out1=NULL;
         int next_level=0;
         opus_int32 rebalance;
         if (B0>1 && !stereo && (itheta&0x3fff))
         {
            if (itheta > 8192)
               delta -= delta>>(4-LM);
            else
               delta = IMIN(0, delta + (N<<BITRES>>(5-LM)));
         }
         mbits = IMAX(0, IMIN(b, (b-delta)/2));
         sbits = b-mbits;
         *remaining_bits -= qalloc;
         if (lowband && !stereo)
            next_lowband2 = lowband+N;
         if (stereo)
            next_lowband_out1 = lowband_out;
         else
            next_level = level+1;
         rebalance = *remaining_bits;
         if (mbits >= sbits)
         {
            cm = quant_band(m, i, X, NULL, N, mbits, spread, B, intensity, tf_change,
                  lowband, ec, remaining_bits, LM, next_lowband_out1,
                  NULL, next_level, seed, stereo ? Q15ONE : MULT16_16_P15(gain,mid), lowband_scratch, fill);
            rebalance = mbits - (rebalance-*remaining_bits);
            if (rebalance > 3<<BITRES && itheta!=0)
               sbits += rebalance - (3<<BITRES);
            cm |= quant_band(m, i, Y, NULL, N, sbits, spread, B, intensity, tf_change,
                  next_lowband2, ec, remaining_bits, LM, NULL,
                  NULL, next_level, seed, MULT16_16_P15(gain,side), NULL, fill>>B)<<((B0>>1)&(stereo-1));
         } else {
            cm = quant_band(m, i, Y, NULL, N, sbits, spread, B, intensity, tf_change,
                  next_lowband2, ec, remaining_bits, LM, NULL,
                  NULL, next_level, seed, MULT16_16_P15(gain,side), NULL, fill>>B)<<((B0>>1)&(stereo-1));
            rebalance = sbits - (rebalance-*remaining_bits);
            if (rebalance > 3<<BITRES && itheta!=16384)
               mbits += rebalance - (3<<BITRES);
            cm |= quant_band(m, i, X, NULL, N, mbits, spread, B, intensity, tf_change,
                  lowband, ec, remaining_bits, LM, next_lowband_out1,
                  NULL, next_level, seed, stereo ? Q15ONE : MULT16_16_P15(gain,mid), lowband_scratch, fill);
         }
      }
   } else {
      q = bits2pulses(m, i, LM, b);
      curr_bits = pulses2bits(m, i, LM, q);
      *remaining_bits -= curr_bits;
      while (*remaining_bits < 0 && q > 0)
      {
         *remaining_bits += curr_bits;
         q--;
         curr_bits = pulses2bits(m, i, LM, q);
         *remaining_bits -= curr_bits;
      }
      if (q!=0)
      {
         int K = get_pulses(q);
         cm = alg_unquant(X, N, K, spread, B, ec, gain);
      } else {
         int j;
         unsigned cm_mask;
         cm_mask = (unsigned)(1UL<<B)-1;
         fill &= cm_mask;
         if (!fill)
         {
            for (j=0;j<N;j++)
               X[j] = 0;
         } else {
            if (lowband == NULL)
            {
               for (j=0;j<N;j++)
               {
                  *seed = celt_lcg_rand(*seed);
                  X[j] = (celt_norm)((opus_int32)*seed>>20);
               }
               cm = cm_mask;
            } else {
               for (j=0;j<N;j++)
               {
                  opus_val16 tmp;
                  *seed = celt_lcg_rand(*seed);
                  tmp = QCONST16(1.0f/256, 10);
                  tmp = (*seed)&0x8000 ? tmp : -tmp;
                  X[j] = lowband[j]+tmp;
               }
               cm = fill;
            }
            renormalise_vector(X, N, gain);
         }
      }
   }
   {
      if (stereo)
      {
         if (N!=2)
            stereo_merge(X, Y, mid, N);
         if (inv)
         {
            int j;
            for (j=0;j<N;j++)
               Y[j] = -Y[j];
         }
      } else if (level == 0)
      {
         int k;
         if (B0>1)
            interleave_hadamard(X, N_B>>recombine, B0<<recombine, longBlocks);
         N_B = N_B0;
         B = B0;
         for (k=0;k<time_divide;k++)
         {
            B >>= 1;
            N_B <<= 1;
            cm |= cm>>B;
            haar1(X, N_B, B);
         }
         for (k=0;k<recombine;k++)
         {
            static const unsigned char bit_deinterleave_table[16]={
              0x00,0x03,0x0C,0x0F,0x30,0x33,0x3C,0x3F,
              0xC0,0xC3,0xCC,0xCF,0xF0,0xF3,0xFC,0xFF
            };
            cm = bit_deinterleave_table[cm];
            haar1(X, N0>>k, 1<<k);
         }
         B<<=recombine;
         if (lowband_out)
         {
            int j;
            opus_val16 n;
            n = celt_sqrt(SHL32(EXTEND32(N0),22));
            for (j=0;j<N0;j++)
               lowband_out[j] = MULT16_16_Q15(n,X[j]);
         }
         cm &= (1<<B)-1;
      }
   }
   return cm;
}
void quant_all_bands(const CELTMode *m, int start, int end,
      celt_norm *X_, celt_norm *Y_, unsigned char *collapse_masks, const celt_ener *bandE, int *pulses,
      int shortBlocks, int spread, int dual_stereo, int intensity, int *tf_res,
      opus_int32 total_bits, opus_int32 balance, ec_ctx *ec, int LM, int codedBands, opus_uint32 *seed)
{
   int i;
   opus_int32 remaining_bits;
   const opus_int16 * restrict eBands = m->eBands;
   celt_norm * restrict norm, * restrict norm2;
   VARDECL(celt_norm, _norm);
   VARDECL(celt_norm, lowband_scratch);
   int B;
   int M;
   int lowband_offset;
   int update_lowband = 1;
   int C = Y_ != NULL ? 2 : 1;
   SAVE_STACK;
   M = 1<<LM;
   B = shortBlocks ? M : 1;
   ALLOC(_norm, C*M*eBands[m->nbEBands], celt_norm);
   ALLOC(lowband_scratch, M*(eBands[m->nbEBands]-eBands[m->nbEBands-1]), celt_norm);
   norm = _norm;
   norm2 = norm + M*eBands[m->nbEBands];
   lowband_offset = 0;
   for (i=start;i<end;i++)
   {
      opus_int32 tell;
      int b;
      int N;
      opus_int32 curr_balance;
      int effective_lowband=-1;
      celt_norm * restrict X, * restrict Y;
      int tf_change=0;
      unsigned x_cm;
      unsigned y_cm;
      X = X_+M*eBands[i];
      if (Y_!=NULL)
         Y = Y_+M*eBands[i];
      else
         Y = NULL;
      N = M*eBands[i+1]-M*eBands[i];
      tell = ec_tell_frac(ec);
      if (i != start)
         balance -= tell;
      remaining_bits = total_bits-tell-1;
      if (i <= codedBands-1)
      {
         curr_balance = balance / IMIN(3, codedBands-i);
         b = IMAX(0, IMIN(16383, IMIN(remaining_bits+1,pulses[i]+curr_balance)));
      } else {
         b = 0;
      }
      if ((M*eBands[i]-N >= M*eBands[start] || i==start+1) && (update_lowband || lowband_offset==0))
            lowband_offset = i;
      if (i == start+1)
      {
         int n1, n2;
         int offset;
         n1 = M*(eBands[start+1]-eBands[start]);
         n2 = M*(eBands[start+2]-eBands[start+1]);
         offset = M*eBands[start];
         OPUS_COPY(&norm[offset+n1], &norm[offset+2*n1 - n2], n2-n1);
         if (C==2)
            OPUS_COPY(&norm2[offset+n1], &norm2[offset+2*n1 - n2], n2-n1);
      }
      tf_change = tf_res[i];
      if (i>=m->effEBands)
      {
         X=norm;
         if (Y_!=NULL)
            Y = norm;
      }
      if (lowband_offset != 0 && (spread!=SPREAD_AGGRESSIVE || B>1 || tf_change<0))
      {
         int fold_start;
         int fold_end;
         int fold_i;
         effective_lowband = IMAX(M*eBands[start], M*eBands[lowband_offset]-N);
         fold_start = lowband_offset;
         while(M*eBands[--fold_start] > effective_lowband);
         fold_end = lowband_offset-1;
         while(++fold_end < i && M*eBands[fold_end] < effective_lowband+N);
         x_cm = y_cm = 0;
         fold_i = fold_start; do {
           x_cm |= collapse_masks[fold_i*C+0];
           y_cm |= collapse_masks[fold_i*C+C-1];
         } while (++fold_i<fold_end);
      }
      else
         x_cm = y_cm = (1<<B)-1;
      if (dual_stereo && i==intensity)
      {
         int j;
         dual_stereo = 0;
         for (j=M*eBands[start];j<M*eBands[i];j++)
            norm[j] = HALF32(norm[j]+norm2[j]);
      }
      if (dual_stereo)
      {
         x_cm = quant_band(m, i, X, NULL, N, b/2, spread, B, intensity, tf_change,
               effective_lowband != -1 ? norm+effective_lowband : NULL, ec, &remaining_bits, LM,
               norm+M*eBands[i], bandE, 0, seed, Q15ONE, lowband_scratch, x_cm);
         y_cm = quant_band(m, i, Y, NULL, N, b/2, spread, B, intensity, tf_change,
               effective_lowband != -1 ? norm2+effective_lowband : NULL, ec, &remaining_bits, LM,
               norm2+M*eBands[i], bandE, 0, seed, Q15ONE, lowband_scratch, y_cm);
      } else {
         x_cm = quant_band(m, i, X, Y, N, b, spread, B, intensity, tf_change,
               effective_lowband != -1 ? norm+effective_lowband : NULL, ec, &remaining_bits, LM,
               norm+M*eBands[i], bandE, 0, seed, Q15ONE, lowband_scratch, x_cm|y_cm);
         y_cm = x_cm;
      }
      collapse_masks[i*C+0] = (unsigned char)x_cm;
      collapse_masks[i*C+C-1] = (unsigned char)y_cm;
      balance += pulses[i] + tell;
      update_lowband = b>(N<<BITRES);
   }
   RESTORE_STACK;
}

void pitch_downsample(celt_sig * restrict x[], opus_val16 * restrict x_lp,
      int len, int C);
void pitch_search(const opus_val16 * restrict x_lp, opus_val16 * restrict y,
                  int len, int max_pitch, int *pitch);

void log2Amp(const CELTMode *m, int start, int end,
      celt_ener *eBands, const opus_val16 *oldEBands, int C);
void unquant_coarse_energy(const CELTMode *m, int start, int end, opus_val16 *oldEBands, int intra, ec_dec *dec, int C, int LM);
void unquant_fine_energy(const CELTMode *m, int start, int end, opus_val16 *oldEBands, int *fine_quant, ec_dec *dec, int C);
void unquant_energy_finalise(const CELTMode *m, int start, int end, opus_val16 *oldEBands, int *fine_quant, int *fine_priority, int bits_left, ec_dec *dec, int C);

#include <stdarg.h>
#define LPC_ORDER 24
void _celt_lpc(opus_val16 *_lpc, const opus_val32 *ac, int p);
void celt_fir(const opus_val16 *x,
         const opus_val16 *num,
         opus_val16 *y,
         int N,
         int ord,
         opus_val16 *mem);
void celt_iir(const opus_val32 *x,
         const opus_val16 *den,
         opus_val32 *y,
         int N,
         int ord,
         opus_val16 *mem);
void _celt_autocorr(const opus_val16 *x, opus_val32 *ac, const opus_val16 *window, int overlap, int lag, int n);

#define OPUS_CUSTOM_NOSTATIC static inline
static const unsigned char trim_icdf[11] = {126, 124, 119, 109, 87, 41, 19, 9, 4, 2, 0};
static const unsigned char spread_icdf[4] = {25, 23, 2, 0};
static const unsigned char tapset_icdf[3]={2,1,0};
#define COMBFILTER_MINPERIOD 15
static int resampling_factor(opus_int32 rate)
{
   int ret;
   switch (rate)
   {
   case 48000:
      ret = 1;
      break;
   case 24000:
      ret = 2;
      break;
   case 16000:
      ret = 3;
      break;
   case 12000:
      ret = 4;
      break;
   case 8000:
      ret = 6;
      break;
   default:
      celt_assert(0);
      ret = 0;
      break;
   }
   return ret;
}
static inline opus_val16 SIG2WORD16(celt_sig x)
{
   return (opus_val16)x;
}
static void compute_inv_mdcts(const CELTMode *mode, int shortBlocks, celt_sig *X,
      celt_sig * restrict out_mem[],
      celt_sig * restrict overlap_mem[], int C, int LM)
{
   int c;
   const int N = mode->shortMdctSize<<LM;
   const int overlap = OVERLAP(mode);
   VARDECL(opus_val32, x);
   SAVE_STACK;
   ALLOC(x, N+overlap, opus_val32);
   c=0; do {
      int j;
      int b;
      int N2 = N;
      int B = 1;
      if (shortBlocks)
      {
         N2 = mode->shortMdctSize;
         B = shortBlocks;
      }
      OPUS_CLEAR(x, overlap);
      for (b=0;b<B;b++)
      {
         clt_mdct_backward(&mode->mdct, &X[b+c*N2*B], x+N2*b, mode->window, overlap, shortBlocks ? mode->maxLM : mode->maxLM-LM, B);
      }
      for (j=0;j<overlap;j++)
         out_mem[c][j] = x[j] + overlap_mem[c][j];
      for (;j<N;j++)
         out_mem[c][j] = x[j];
      for (j=0;j<overlap;j++)
         overlap_mem[c][j] = x[N+j];
   } while (++c<C);
   RESTORE_STACK;
}
static void deemphasis(celt_sig *in[], opus_val16 *pcm, int N, int C, int downsample, const opus_val16 *coef, celt_sig *mem)
{
   int c;
   int count=0;
   c=0; do {
      int j;
      celt_sig * restrict x;
      opus_val16  * restrict y;
      celt_sig m = mem[c];
      x =in[c];
      y = pcm+c;
      for (j=0;j<N;j++)
      {
         celt_sig tmp = *x + m;
         m = MULT16_32_Q15(coef[0], tmp)
           - MULT16_32_Q15(coef[1], *x);
         tmp = SHL32(MULT16_32_Q15(coef[3], tmp), 2);
         x++;
         if (count==0)
            *y = SCALEOUT(SIG2WORD16(tmp));
         if (++count==downsample)
         {
            y+=C;
            count=0;
         }
      }
      mem[c] = m;
   } while (++c<C);
}
static void comb_filter(opus_val32 *y, opus_val32 *x, int T0, int T1, int N,
      opus_val16 g0, opus_val16 g1, int tapset0, int tapset1,
      const opus_val16 *window, int overlap)
{
   int i;
   opus_val16 g00, g01, g02, g10, g11, g12;
   static const opus_val16 gains[3][3] = {
         {QCONST16(0.3066406250f, 15), QCONST16(0.2170410156f, 15), QCONST16(0.1296386719f, 15)},
         {QCONST16(0.4638671875f, 15), QCONST16(0.2680664062f, 15), QCONST16(0.f, 15)},
         {QCONST16(0.7998046875f, 15), QCONST16(0.1000976562f, 15), QCONST16(0.f, 15)}};
   g00 = MULT16_16_Q15(g0, gains[tapset0][0]);
   g01 = MULT16_16_Q15(g0, gains[tapset0][1]);
   g02 = MULT16_16_Q15(g0, gains[tapset0][2]);
   g10 = MULT16_16_Q15(g1, gains[tapset1][0]);
   g11 = MULT16_16_Q15(g1, gains[tapset1][1]);
   g12 = MULT16_16_Q15(g1, gains[tapset1][2]);
   for (i=0;i<overlap;i++)
   {
      opus_val16 f;
      f = MULT16_16_Q15(window[i],window[i]);
      y[i] = x[i]
               + MULT16_32_Q15(MULT16_16_Q15((Q15ONE-f),g00),x[i-T0])
               + MULT16_32_Q15(MULT16_16_Q15((Q15ONE-f),g01),x[i-T0-1])
               + MULT16_32_Q15(MULT16_16_Q15((Q15ONE-f),g01),x[i-T0+1])
               + MULT16_32_Q15(MULT16_16_Q15((Q15ONE-f),g02),x[i-T0-2])
               + MULT16_32_Q15(MULT16_16_Q15((Q15ONE-f),g02),x[i-T0+2])
               + MULT16_32_Q15(MULT16_16_Q15(f,g10),x[i-T1])
               + MULT16_32_Q15(MULT16_16_Q15(f,g11),x[i-T1-1])
               + MULT16_32_Q15(MULT16_16_Q15(f,g11),x[i-T1+1])
               + MULT16_32_Q15(MULT16_16_Q15(f,g12),x[i-T1-2])
               + MULT16_32_Q15(MULT16_16_Q15(f,g12),x[i-T1+2]);
   }
   for (i=overlap;i<N;i++)
      y[i] = x[i]
               + MULT16_32_Q15(g10,x[i-T1])
               + MULT16_32_Q15(g11,x[i-T1-1])
               + MULT16_32_Q15(g11,x[i-T1+1])
               + MULT16_32_Q15(g12,x[i-T1-2])
               + MULT16_32_Q15(g12,x[i-T1+2]);
}
static const signed char tf_select_table[4][8] = {
      {0, -1, 0, -1,    0,-1, 0,-1},
      {0, -1, 0, -2,    1, 0, 1,-1},
      {0, -2, 0, -3,    2, 0, 1,-1},
      {0, -2, 0, -3,    3, 0, 1,-1},
};
static void tf_decode(int start, int end, int isTransient, int *tf_res, int LM, ec_dec *dec)
{
   int i, curr, tf_select;
   int tf_select_rsv;
   int tf_changed;
   int logp;
   opus_uint32 budget;
   opus_uint32 tell;
   budget = dec->storage*8;
   tell = ec_tell(dec);
   logp = isTransient ? 2 : 4;
   tf_select_rsv = LM>0 && tell+logp+1<=budget;
   budget -= tf_select_rsv;
   tf_changed = curr = 0;
   for (i=start;i<end;i++)
   {
      if (tell+logp<=budget)
      {
         curr ^= ec_dec_bit_logp(dec, logp);
         tell = ec_tell(dec);
         tf_changed |= curr;
      }
      tf_res[i] = curr;
      logp = isTransient ? 4 : 5;
   }
   tf_select = 0;
   if (tf_select_rsv &&
     tf_select_table[LM][4*isTransient+0+tf_changed] !=
     tf_select_table[LM][4*isTransient+2+tf_changed])
   {
      tf_select = ec_dec_bit_logp(dec, 1);
   }
   for (i=start;i<end;i++)
   {
      tf_res[i] = tf_select_table[LM][4*isTransient+2*tf_select+tf_res[i]];
   }
}
static void init_caps(const CELTMode *m,int *cap,int LM,int C)
{
   int i;
   for (i=0;i<m->nbEBands;i++)
   {
      int N;
      N=(m->eBands[i+1]-m->eBands[i])<<LM;
      cap[i] = (m->cache.caps[m->nbEBands*(2*LM+C-1)+i]+64)*C*N>>2;
   }
}
#define DECODE_BUFFER_SIZE 2048
struct OpusCustomDecoder {
   const OpusCustomMode *mode;
   int overlap;
   int channels;
   int stream_channels;
   int downsample;
   int start, end;
   int signalling;
#define DECODER_RESET_START rng
   opus_uint32 rng;
   int error;
   int last_pitch_index;
   int loss_count;
   int postfilter_period;
   int postfilter_period_old;
   opus_val16 postfilter_gain;
   opus_val16 postfilter_gain_old;
   int postfilter_tapset;
   int postfilter_tapset_old;
   celt_sig preemph_memD[2];
   celt_sig _decode_mem[1];
};
int celt_decoder_get_size(int channels)
{
   const CELTMode *mode = opus_custom_mode_create(48000, 960, NULL);
   return opus_custom_decoder_get_size(mode, channels);
}
OPUS_CUSTOM_NOSTATIC int opus_custom_decoder_get_size(const CELTMode *mode, int channels)
{
   int size = sizeof(struct CELTDecoder)
            + (channels*(DECODE_BUFFER_SIZE+mode->overlap)-1)*sizeof(celt_sig)
            + channels*LPC_ORDER*sizeof(opus_val16)
            + 4*2*mode->nbEBands*sizeof(opus_val16);
   return size;
}
int celt_decoder_init(CELTDecoder *st, opus_int32 sampling_rate, int channels)
{
   int ret;
   ret = opus_custom_decoder_init(st, opus_custom_mode_create(48000, 960, NULL), channels);
   if (ret != OPUS_OK)
      return ret;
   st->downsample = resampling_factor(sampling_rate);
   if (st->downsample==0)
      return OPUS_BAD_ARG;
   else
      return OPUS_OK;
}
OPUS_CUSTOM_NOSTATIC int opus_custom_decoder_init(CELTDecoder *st, const CELTMode *mode, int channels)
{
   if (channels < 0 || channels > 2)
      return OPUS_BAD_ARG;
   if (st==NULL)
      return OPUS_ALLOC_FAIL;
   OPUS_CLEAR((char*)st, opus_custom_decoder_get_size(mode, channels));
   st->mode = mode;
   st->overlap = mode->overlap;
   st->stream_channels = st->channels = channels;
   st->downsample = 1;
   st->start = 0;
   st->end = st->mode->effEBands;
   st->signalling = 1;
   st->loss_count = 0;
   opus_custom_decoder_ctl(st, OPUS_RESET_STATE);
   return OPUS_OK;
}
static void celt_decode_lost(CELTDecoder * restrict st, opus_val16 * restrict pcm, int N, int LM)
{
   int c;
   int pitch_index;
   int overlap = st->mode->overlap;
   opus_val16 fade = Q15ONE;
   int i, len;
   const int C = st->channels;
   int offset;
   celt_sig *out_mem[2];
   celt_sig *decode_mem[2];
   celt_sig *overlap_mem[2];
   opus_val16 *lpc;
   opus_val32 *out_syn[2];
   opus_val16 *oldBandE, *oldLogE, *oldLogE2, *backgroundLogE;
   SAVE_STACK;
   c=0; do {
      decode_mem[c] = st->_decode_mem + c*(DECODE_BUFFER_SIZE+st->overlap);
      out_mem[c] = decode_mem[c]+DECODE_BUFFER_SIZE-MAX_PERIOD;
      overlap_mem[c] = decode_mem[c]+DECODE_BUFFER_SIZE;
   } while (++c<C);
   lpc = (opus_val16*)(st->_decode_mem+(DECODE_BUFFER_SIZE+st->overlap)*C);
   oldBandE = lpc+C*LPC_ORDER;
   oldLogE = oldBandE + 2*st->mode->nbEBands;
   oldLogE2 = oldLogE + 2*st->mode->nbEBands;
   backgroundLogE = oldLogE2  + 2*st->mode->nbEBands;
   out_syn[0] = out_mem[0]+MAX_PERIOD-N;
   if (C==2)
      out_syn[1] = out_mem[1]+MAX_PERIOD-N;
   len = N+st->mode->overlap;
   if (st->loss_count >= 5 || st->start!=0)
   {
      VARDECL(celt_sig, freq);
      VARDECL(celt_norm, X);
      VARDECL(celt_ener, bandE);
      opus_uint32 seed;
      int effEnd;
      effEnd = st->end;
      if (effEnd > st->mode->effEBands)
         effEnd = st->mode->effEBands;
      ALLOC(freq, C*N, celt_sig);
      ALLOC(X, C*N, celt_norm);
      ALLOC(bandE, st->mode->nbEBands*C, celt_ener);
      if (st->loss_count >= 5)
         log2Amp(st->mode, st->start, st->end, bandE, backgroundLogE, C);
      else {
         opus_val16 decay = st->loss_count==0 ? QCONST16(1.5f, DB_SHIFT) : QCONST16(.5f, DB_SHIFT);
         c=0; do
         {
            for (i=st->start;i<st->end;i++)
               oldBandE[c*st->mode->nbEBands+i] -= decay;
         } while (++c<C);
         log2Amp(st->mode, st->start, st->end, bandE, oldBandE, C);
      }
      seed = st->rng;
      for (c=0;c<C;c++)
      {
         for (i=0;i<(st->mode->eBands[st->start]<<LM);i++)
            X[c*N+i] = 0;
         for (i=st->start;i<st->mode->effEBands;i++)
         {
            int j;
            int boffs;
            int blen;
            boffs = N*c+(st->mode->eBands[i]<<LM);
            blen = (st->mode->eBands[i+1]-st->mode->eBands[i])<<LM;
            for (j=0;j<blen;j++)
            {
               seed = celt_lcg_rand(seed);
               X[boffs+j] = (celt_norm)((opus_int32)seed>>20);
            }
            renormalise_vector(X+boffs, blen, Q15ONE);
         }
         for (i=(st->mode->eBands[st->end]<<LM);i<N;i++)
            X[c*N+i] = 0;
      }
      st->rng = seed;
      denormalise_bands(st->mode, X, freq, bandE, st->mode->effEBands, C, 1<<LM);
      c=0; do
         for (i=0;i<st->mode->eBands[st->start]<<LM;i++)
            freq[c*N+i] = 0;
      while (++c<C);
      c=0; do {
         int bound = st->mode->eBands[effEnd]<<LM;
         if (st->downsample!=1)
            bound = IMIN(bound, N/st->downsample);
         for (i=bound;i<N;i++)
            freq[c*N+i] = 0;
      } while (++c<C);
      compute_inv_mdcts(st->mode, 0, freq, out_syn, overlap_mem, C, LM);
   } else {
      if (st->loss_count == 0)
      {
         opus_val16 pitch_buf[DECODE_BUFFER_SIZE>>1];
         int poffset = 720;
         pitch_downsample(decode_mem, pitch_buf, DECODE_BUFFER_SIZE, C);
         pitch_search(pitch_buf+((poffset)>>1), pitch_buf, DECODE_BUFFER_SIZE-poffset,
               poffset-100, &pitch_index);
         pitch_index = poffset-pitch_index;
         st->last_pitch_index = pitch_index;
      } else {
         pitch_index = st->last_pitch_index;
         fade = QCONST16(.8f,15);
      }
      c=0; do {
         VARDECL(opus_val32, e);
         opus_val16 exc[MAX_PERIOD];
         opus_val32 ac[LPC_ORDER+1];
         opus_val16 decay = 1;
         opus_val32 S1=0;
         opus_val16 mem[LPC_ORDER]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
         ALLOC(e, MAX_PERIOD+2*st->mode->overlap, opus_val32);
         offset = MAX_PERIOD-pitch_index;
         for (i=0;i<MAX_PERIOD;i++)
            exc[i] = ROUND16(out_mem[c][i], SIG_SHIFT);
         if (st->loss_count == 0)
         {
            _celt_autocorr(exc, ac, st->mode->window, st->mode->overlap,
                  LPC_ORDER, MAX_PERIOD);
            ac[0] *= 1.0001f;
            for (i=1;i<=LPC_ORDER;i++)
            {
               ac[i] -= ac[i]*(.008f*i)*(.008f*i);
            }
            _celt_lpc(lpc+c*LPC_ORDER, ac, LPC_ORDER);
         }
         for (i=0;i<LPC_ORDER;i++)
            mem[i] = ROUND16(out_mem[c][MAX_PERIOD-1-i], SIG_SHIFT);
         celt_fir(exc, lpc+c*LPC_ORDER, exc, MAX_PERIOD, LPC_ORDER, mem);
         {
            opus_val32 E1=1, E2=1;
            int period;
            if (pitch_index <= MAX_PERIOD/2)
               period = pitch_index;
            else
               period = MAX_PERIOD/2;
            for (i=0;i<period;i++)
            {
               E1 += SHR32(MULT16_16(exc[MAX_PERIOD-period+i],exc[MAX_PERIOD-period+i]),8);
               E2 += SHR32(MULT16_16(exc[MAX_PERIOD-2*period+i],exc[MAX_PERIOD-2*period+i]),8);
            }
            if (E1 > E2)
               E1 = E2;
            decay = celt_sqrt(frac_div32(SHR(E1,1),E2));
         }
         for (i=0;i<len+st->mode->overlap;i++)
         {
            opus_val16 tmp;
            if (offset+i >= MAX_PERIOD)
            {
               offset -= pitch_index;
               decay = MULT16_16_Q15(decay, decay);
            }
            e[i] = SHL32(EXTEND32(MULT16_16_Q15(decay, exc[offset+i])), SIG_SHIFT);
            tmp = ROUND16(out_mem[c][offset+i],SIG_SHIFT);
            S1 += SHR32(MULT16_16(tmp,tmp),8);
         }
         for (i=0;i<LPC_ORDER;i++)
            mem[i] = ROUND16(out_mem[c][MAX_PERIOD-1-i], SIG_SHIFT);
         for (i=0;i<len+st->mode->overlap;i++)
            e[i] = MULT16_32_Q15(fade, e[i]);
         celt_iir(e, lpc+c*LPC_ORDER, e, len+st->mode->overlap, LPC_ORDER, mem);
         {
            opus_val32 S2=0;
            for (i=0;i<len+overlap;i++)
            {
               opus_val16 tmp = ROUND16(e[i],SIG_SHIFT);
               S2 += SHR32(MULT16_16(tmp,tmp),8);
            }
               if (!(S1 > 0.2f*S2))
               {
                  for (i=0;i<len+overlap;i++)
                     e[i] = 0;
               } else if (S1 < S2)
               {
                  opus_val16 ratio = celt_sqrt(frac_div32(SHR32(S1,1)+1,S2+1));
                  for (i=0;i<len+overlap;i++)
                     e[i] = MULT16_32_Q15(ratio, e[i]);
               }
         }
         comb_filter(out_mem[c]+MAX_PERIOD, out_mem[c]+MAX_PERIOD, st->postfilter_period, st->postfilter_period, st->overlap,
               st->postfilter_gain, st->postfilter_gain, st->postfilter_tapset, st->postfilter_tapset,
               NULL, 0);
         for (i=0;i<MAX_PERIOD+st->mode->overlap-N;i++)
            out_mem[c][i] = out_mem[c][N+i];
         for (i=0;i<overlap/2;i++)
         {
            opus_val32 tmp;
            tmp = MULT16_32_Q15(st->mode->window[i],           e[N+overlap-1-i]) +
                  MULT16_32_Q15(st->mode->window[overlap-i-1], e[N+i          ]);
            out_mem[c][MAX_PERIOD+i] = MULT16_32_Q15(st->mode->window[overlap-i-1], tmp);
            out_mem[c][MAX_PERIOD+overlap-i-1] = MULT16_32_Q15(st->mode->window[i], tmp);
         }
         for (i=0;i<N;i++)
            out_mem[c][MAX_PERIOD-N+i] = e[i];
         comb_filter(e, out_mem[c]+MAX_PERIOD, st->postfilter_period, st->postfilter_period, st->overlap,
               -st->postfilter_gain, -st->postfilter_gain, st->postfilter_tapset, st->postfilter_tapset,
               NULL, 0);
         for (i=0;i<overlap;i++)
            out_mem[c][MAX_PERIOD+i] = e[i];
      } while (++c<C);
   }
   deemphasis(out_syn, pcm, N, C, st->downsample, st->mode->preemph, st->preemph_memD);
   st->loss_count++;
   RESTORE_STACK;
}
int celt_decode_with_ec(CELTDecoder * restrict st, const unsigned char *data, int len, opus_val16 * restrict pcm, int frame_size, ec_dec *dec)
{
   int c, i, N;
   int spread_decision;
   opus_int32 bits;
   ec_dec _dec;
   VARDECL(celt_sig, freq);
   VARDECL(celt_norm, X);
   VARDECL(celt_ener, bandE);
   VARDECL(int, fine_quant);
   VARDECL(int, pulses);
   VARDECL(int, cap);
   VARDECL(int, offsets);
   VARDECL(int, fine_priority);
   VARDECL(int, tf_res);
   VARDECL(unsigned char, collapse_masks);
   celt_sig *out_mem[2];
   celt_sig *decode_mem[2];
   celt_sig *overlap_mem[2];
   celt_sig *out_syn[2];
   opus_val16 *lpc;
   opus_val16 *oldBandE, *oldLogE, *oldLogE2, *backgroundLogE;
   int shortBlocks;
   int isTransient;
   int intra_ener;
   const int CC = st->channels;
   int LM, M;
   int effEnd;
   int codedBands;
   int alloc_trim;
   int postfilter_pitch;
   opus_val16 postfilter_gain;
   int intensity=0;
   int dual_stereo=0;
   opus_int32 total_bits;
   opus_int32 balance;
   opus_int32 tell;
   int dynalloc_logp;
   int postfilter_tapset;
   int anti_collapse_rsv;
   int anti_collapse_on=0;
   int silence;
   int C = st->stream_channels;
   ALLOC_STACK;
   frame_size *= st->downsample;
   c=0; do {
      decode_mem[c] = st->_decode_mem + c*(DECODE_BUFFER_SIZE+st->overlap);
      out_mem[c] = decode_mem[c]+DECODE_BUFFER_SIZE-MAX_PERIOD;
      overlap_mem[c] = decode_mem[c]+DECODE_BUFFER_SIZE;
   } while (++c<CC);
   lpc = (opus_val16*)(st->_decode_mem+(DECODE_BUFFER_SIZE+st->overlap)*CC);
   oldBandE = lpc+CC*LPC_ORDER;
   oldLogE = oldBandE + 2*st->mode->nbEBands;
   oldLogE2 = oldLogE + 2*st->mode->nbEBands;
   backgroundLogE = oldLogE2  + 2*st->mode->nbEBands;
   {
      for (LM=0;LM<=st->mode->maxLM;LM++)
         if (st->mode->shortMdctSize<<LM==frame_size)
            break;
      if (LM>st->mode->maxLM)
         return OPUS_BAD_ARG;
   }
   M=1<<LM;
   if (len<0 || len>1275 || pcm==NULL)
      return OPUS_BAD_ARG;
   N = M*st->mode->shortMdctSize;
   effEnd = st->end;
   if (effEnd > st->mode->effEBands)
      effEnd = st->mode->effEBands;
   ALLOC(freq, IMAX(CC,C)*N, celt_sig);
   ALLOC(X, C*N, celt_norm);
   ALLOC(bandE, st->mode->nbEBands*C, celt_ener);
   c=0; do
      for (i=0;i<M*st->mode->eBands[st->start];i++)
         X[c*N+i] = 0;
   while (++c<C);
   c=0; do
      for (i=M*st->mode->eBands[effEnd];i<N;i++)
         X[c*N+i] = 0;
   while (++c<C);
   if (data == NULL || len<=1)
   {
      celt_decode_lost(st, pcm, N, LM);
      RESTORE_STACK;
      return frame_size/st->downsample;
   }
   if (dec == NULL)
   {
      ec_dec_init(&_dec,(unsigned char*)data,len);
      dec = &_dec;
   }
   if (C==1)
   {
      for (i=0;i<st->mode->nbEBands;i++)
         oldBandE[i]=MAX16(oldBandE[i],oldBandE[st->mode->nbEBands+i]);
   }
   total_bits = len*8;
   tell = ec_tell(dec);
   if (tell >= total_bits)
      silence = 1;
   else if (tell==1)
      silence = ec_dec_bit_logp(dec, 15);
   else
      silence = 0;
   if (silence)
   {
      tell = len*8;
      dec->nbits_total+=tell-ec_tell(dec);
   }
   postfilter_gain = 0;
   postfilter_pitch = 0;
   postfilter_tapset = 0;
   if (st->start==0 && tell+16 <= total_bits)
   {
      if(ec_dec_bit_logp(dec, 1))
      {
         int qg, octave;
         octave = ec_dec_uint(dec, 6);
         postfilter_pitch = (16<<octave)+ec_dec_bits(dec, 4+octave)-1;
         qg = ec_dec_bits(dec, 3);
         if (ec_tell(dec)+2<=total_bits)
            postfilter_tapset = ec_dec_icdf(dec, tapset_icdf, 2);
         postfilter_gain = QCONST16(.09375f,15)*(qg+1);
      }
      tell = ec_tell(dec);
   }
   if (LM > 0 && tell+3 <= total_bits)
   {
      isTransient = ec_dec_bit_logp(dec, 3);
      tell = ec_tell(dec);
   }
   else
      isTransient = 0;
   if (isTransient)
      shortBlocks = M;
   else
      shortBlocks = 0;
   intra_ener = tell+3<=total_bits ? ec_dec_bit_logp(dec, 3) : 0;
   unquant_coarse_energy(st->mode, st->start, st->end, oldBandE,
         intra_ener, dec, C, LM);
   ALLOC(tf_res, st->mode->nbEBands, int);
   tf_decode(st->start, st->end, isTransient, tf_res, LM, dec);
   tell = ec_tell(dec);
   spread_decision = SPREAD_NORMAL;
   if (tell+4 <= total_bits)
      spread_decision = ec_dec_icdf(dec, spread_icdf, 5);
   ALLOC(pulses, st->mode->nbEBands, int);
   ALLOC(cap, st->mode->nbEBands, int);
   ALLOC(offsets, st->mode->nbEBands, int);
   ALLOC(fine_priority, st->mode->nbEBands, int);
   init_caps(st->mode,cap,LM,C);
   dynalloc_logp = 6;
   total_bits<<=BITRES;
   tell = ec_tell_frac(dec);
   for (i=st->start;i<st->end;i++)
   {
      int width, quanta;
      int dynalloc_loop_logp;
      int boost;
      width = C*(st->mode->eBands[i+1]-st->mode->eBands[i])<<LM;
      quanta = IMIN(width<<BITRES, IMAX(6<<BITRES, width));
      dynalloc_loop_logp = dynalloc_logp;
      boost = 0;
      while (tell+(dynalloc_loop_logp<<BITRES) < total_bits && boost < cap[i])
      {
         int flag;
         flag = ec_dec_bit_logp(dec, dynalloc_loop_logp);
         tell = ec_tell_frac(dec);
         if (!flag)
            break;
         boost += quanta;
         total_bits -= quanta;
         dynalloc_loop_logp = 1;
      }
      offsets[i] = boost;
      if (boost>0)
         dynalloc_logp = IMAX(2, dynalloc_logp-1);
   }
   ALLOC(fine_quant, st->mode->nbEBands, int);
   alloc_trim = tell+(6<<BITRES) <= total_bits ?
         ec_dec_icdf(dec, trim_icdf, 7) : 5;
   bits = (((opus_int32)len*8)<<BITRES) - ec_tell_frac(dec) - 1;
   anti_collapse_rsv = isTransient&&LM>=2&&bits>=((LM+2)<<BITRES) ? (1<<BITRES) : 0;
   bits -= anti_collapse_rsv;
   codedBands = compute_allocation(st->mode, st->start, st->end, offsets, cap,
         alloc_trim, &intensity, &dual_stereo, bits, &balance, pulses,
         fine_quant, fine_priority, C, LM, dec, 0);
   unquant_fine_energy(st->mode, st->start, st->end, oldBandE, fine_quant, dec, C);
   ALLOC(collapse_masks, C*st->mode->nbEBands, unsigned char);
   quant_all_bands(st->mode, st->start, st->end, X, C==2 ? X+N : NULL, collapse_masks,
         NULL, pulses, shortBlocks, spread_decision, dual_stereo, intensity, tf_res,
         len*(8<<BITRES)-anti_collapse_rsv, balance, dec, LM, codedBands, &st->rng);
   if (anti_collapse_rsv > 0)
   {
      anti_collapse_on = ec_dec_bits(dec, 1);
   }
   unquant_energy_finalise(st->mode, st->start, st->end, oldBandE,
         fine_quant, fine_priority, len*8-ec_tell(dec), dec, C);
   if (anti_collapse_on)
      anti_collapse(st->mode, X, collapse_masks, LM, C, N,
            st->start, st->end, oldBandE, oldLogE, oldLogE2, pulses, st->rng);
   log2Amp(st->mode, st->start, st->end, bandE, oldBandE, C);
   if (silence)
   {
      for (i=0;i<C*st->mode->nbEBands;i++)
      {
         bandE[i] = 0;
         oldBandE[i] = -QCONST16(28.f,DB_SHIFT);
      }
   }
   denormalise_bands(st->mode, X, freq, bandE, effEnd, C, M);
   OPUS_MOVE(decode_mem[0], decode_mem[0]+N, DECODE_BUFFER_SIZE-N);
   if (CC==2)
      OPUS_MOVE(decode_mem[1], decode_mem[1]+N, DECODE_BUFFER_SIZE-N);
   c=0; do
      for (i=0;i<M*st->mode->eBands[st->start];i++)
         freq[c*N+i] = 0;
   while (++c<C);
   c=0; do {
      int bound = M*st->mode->eBands[effEnd];
      if (st->downsample!=1)
         bound = IMIN(bound, N/st->downsample);
      for (i=bound;i<N;i++)
         freq[c*N+i] = 0;
   } while (++c<C);
   out_syn[0] = out_mem[0]+MAX_PERIOD-N;
   if (CC==2)
      out_syn[1] = out_mem[1]+MAX_PERIOD-N;
   if (CC==2&&C==1)
   {
      for (i=0;i<N;i++)
         freq[N+i] = freq[i];
   }
   if (CC==1&&C==2)
   {
      for (i=0;i<N;i++)
         freq[i] = HALF32(ADD32(freq[i],freq[N+i]));
   }
   compute_inv_mdcts(st->mode, shortBlocks, freq, out_syn, overlap_mem, CC, LM);
   c=0; do {
      st->postfilter_period=IMAX(st->postfilter_period, COMBFILTER_MINPERIOD);
      st->postfilter_period_old=IMAX(st->postfilter_period_old, COMBFILTER_MINPERIOD);
      comb_filter(out_syn[c], out_syn[c], st->postfilter_period_old, st->postfilter_period, st->mode->shortMdctSize,
            st->postfilter_gain_old, st->postfilter_gain, st->postfilter_tapset_old, st->postfilter_tapset,
            st->mode->window, st->overlap);
      if (LM!=0)
         comb_filter(out_syn[c]+st->mode->shortMdctSize, out_syn[c]+st->mode->shortMdctSize, st->postfilter_period, postfilter_pitch, N-st->mode->shortMdctSize,
               st->postfilter_gain, postfilter_gain, st->postfilter_tapset, postfilter_tapset,
               st->mode->window, st->mode->overlap);
   } while (++c<CC);
   st->postfilter_period_old = st->postfilter_period;
   st->postfilter_gain_old = st->postfilter_gain;
   st->postfilter_tapset_old = st->postfilter_tapset;
   st->postfilter_period = postfilter_pitch;
   st->postfilter_gain = postfilter_gain;
   st->postfilter_tapset = postfilter_tapset;
   if (LM!=0)
   {
      st->postfilter_period_old = st->postfilter_period;
      st->postfilter_gain_old = st->postfilter_gain;
      st->postfilter_tapset_old = st->postfilter_tapset;
   }
   if (C==1) {
      for (i=0;i<st->mode->nbEBands;i++)
         oldBandE[st->mode->nbEBands+i]=oldBandE[i];
   }
   if (!isTransient)
   {
      for (i=0;i<2*st->mode->nbEBands;i++)
         oldLogE2[i] = oldLogE[i];
      for (i=0;i<2*st->mode->nbEBands;i++)
         oldLogE[i] = oldBandE[i];
      for (i=0;i<2*st->mode->nbEBands;i++)
         backgroundLogE[i] = MIN16(backgroundLogE[i] + M*QCONST16(0.001f,DB_SHIFT), oldBandE[i]);
   } else {
      for (i=0;i<2*st->mode->nbEBands;i++)
         oldLogE[i] = MIN16(oldLogE[i], oldBandE[i]);
   }
   c=0; do
   {
      for (i=0;i<st->start;i++)
      {
         oldBandE[c*st->mode->nbEBands+i]=0;
         oldLogE[c*st->mode->nbEBands+i]=oldLogE2[c*st->mode->nbEBands+i]=-QCONST16(28.f,DB_SHIFT);
      }
      for (i=st->end;i<st->mode->nbEBands;i++)
      {
         oldBandE[c*st->mode->nbEBands+i]=0;
         oldLogE[c*st->mode->nbEBands+i]=oldLogE2[c*st->mode->nbEBands+i]=-QCONST16(28.f,DB_SHIFT);
      }
   } while (++c<2);
   st->rng = dec->rng;
   deemphasis(out_syn, pcm, N, CC, st->downsample, st->mode->preemph, st->preemph_memD);
   st->loss_count = 0;
   RESTORE_STACK;
   if (ec_tell(dec) > 8*len)
      return OPUS_INTERNAL_ERROR;
   if(ec_get_error(dec))
      st->error = 1;
   return frame_size/st->downsample;
}
int opus_custom_decoder_ctl(CELTDecoder * restrict st, int request, ...)
{
   va_list ap;
   va_start(ap, request);
   switch (request)
   {
      case CELT_SET_START_BAND_REQUEST:
      {
         opus_int32 value = va_arg(ap, opus_int32);
         if (value<0 || value>=st->mode->nbEBands)
            goto bad_arg;
         st->start = value;
      }
      break;
      case CELT_SET_END_BAND_REQUEST:
      {
         opus_int32 value = va_arg(ap, opus_int32);
         if (value<1 || value>st->mode->nbEBands)
            goto bad_arg;
         st->end = value;
      }
      break;
      case CELT_SET_CHANNELS_REQUEST:
      {
         opus_int32 value = va_arg(ap, opus_int32);
         if (value<1 || value>2)
            goto bad_arg;
         st->stream_channels = value;
      }
      break;
      case OPUS_RESET_STATE:
      {
         int i;
         opus_val16 *lpc, *oldBandE, *oldLogE, *oldLogE2;
         lpc = (opus_val16*)(st->_decode_mem+(DECODE_BUFFER_SIZE+st->overlap)*st->channels);
         oldBandE = lpc+st->channels*LPC_ORDER;
         oldLogE = oldBandE + 2*st->mode->nbEBands;
         oldLogE2 = oldLogE + 2*st->mode->nbEBands;
         OPUS_CLEAR((char*)&st->DECODER_RESET_START,
               opus_custom_decoder_get_size(st->mode, st->channels)-
               ((char*)&st->DECODER_RESET_START - (char*)st));
         for (i=0;i<2*st->mode->nbEBands;i++)
            oldLogE[i]=oldLogE2[i]=-QCONST16(28.f,DB_SHIFT);
      }
      break;
      case CELT_GET_MODE_REQUEST:
      {
         const CELTMode ** value = va_arg(ap, const CELTMode**);
         if (value==0)
            goto bad_arg;
         *value=st->mode;
      }
      break;
      case CELT_SET_SIGNALLING_REQUEST:
      {
         opus_int32 value = va_arg(ap, opus_int32);
         st->signalling = value;
      }
      break;
      case OPUS_GET_FINAL_RANGE_REQUEST:
      {
         opus_uint32 * value = va_arg(ap, opus_uint32 *);
         if (value==0)
            goto bad_arg;
         *value=st->rng;
      }
      break;
      default:
         goto bad_request;
   }
   va_end(ap);
   return OPUS_OK;
bad_arg:
   va_end(ap);
   return OPUS_BAD_ARG;
bad_request:
      va_end(ap);
  return OPUS_UNIMPLEMENTED;
}

void _celt_lpc(
      opus_val16       *_lpc,
const opus_val32 *ac,
int          p
)
{
   int i, j;
   opus_val32 r;
   opus_val32 error = ac[0];
   float *lpc = _lpc;
   for (i = 0; i < p; i++)
      lpc[i] = 0;
   if (ac[0] != 0)
   {
      for (i = 0; i < p; i++) {
         opus_val32 rr = 0;
         for (j = 0; j < i; j++)
            rr += MULT32_32_Q31(lpc[j],ac[i - j]);
         rr += SHR32(ac[i + 1],3);
         r = -frac_div32(SHL32(rr,3), error);
         lpc[i] = SHR32(r,3);
         for (j = 0; j < (i+1)>>1; j++)
         {
            opus_val32 tmp1, tmp2;
            tmp1 = lpc[j];
            tmp2 = lpc[i-1-j];
            lpc[j]     = tmp1 + MULT32_32_Q31(r,tmp2);
            lpc[i-1-j] = tmp2 + MULT32_32_Q31(r,tmp1);
         }
         error = error - MULT32_32_Q31(MULT32_32_Q31(r,r),error);
         if (error<.001f*ac[0])
            break;
      }
   }
}
void celt_fir(const opus_val16 *x,
         const opus_val16 *num,
         opus_val16 *y,
         int N,
         int ord,
         opus_val16 *mem)
{
   int i,j;
   for (i=0;i<N;i++)
   {
      opus_val32 sum = SHL32(EXTEND32(x[i]), SIG_SHIFT);
      for (j=0;j<ord;j++)
      {
         sum += MULT16_16(num[j],mem[j]);
      }
      for (j=ord-1;j>=1;j--)
      {
         mem[j]=mem[j-1];
      }
      mem[0] = x[i];
      y[i] = ROUND16(sum, SIG_SHIFT);
   }
}
void celt_iir(const opus_val32 *x,
         const opus_val16 *den,
         opus_val32 *y,
         int N,
         int ord,
         opus_val16 *mem)
{
   int i,j;
   for (i=0;i<N;i++)
   {
      opus_val32 sum = x[i];
      for (j=0;j<ord;j++)
      {
         sum -= MULT16_16(den[j],mem[j]);
      }
      for (j=ord-1;j>=1;j--)
      {
         mem[j]=mem[j-1];
      }
      mem[0] = ROUND16(sum,SIG_SHIFT);
      y[i] = sum;
   }
}
void _celt_autocorr(
                   const opus_val16 *x,
                   opus_val32       *ac,
                   const opus_val16       *window,
                   int          overlap,
                   int          lag,
                   int          n
                  )
{
   opus_val32 d;
   int i;
   VARDECL(opus_val16, xx);
   SAVE_STACK;
   ALLOC(xx, n, opus_val16);
   celt_assert(n>0);
   celt_assert(overlap>=0);
   for (i=0;i<n;i++)
      xx[i] = x[i];
   for (i=0;i<overlap;i++)
   {
      xx[i] = MULT16_16_Q15(x[i],window[i]);
      xx[n-i-1] = MULT16_16_Q15(x[n-i-1],window[i]);
   }
   while (lag>=0)
   {
      for (i = lag, d = 0; i < n; i++)
         d += xx[i] * xx[i-lag];
      ac[lag] = d;
      lag--;
   }
   ac[0] += 10;
   RESTORE_STACK;
}

#define MASK32 (0xFFFFFFFF)
static const opus_uint32 INV_TABLE[53]={
  0x00000001,0xAAAAAAAB,0xCCCCCCCD,0xB6DB6DB7,
  0x38E38E39,0xBA2E8BA3,0xC4EC4EC5,0xEEEEEEEF,
  0xF0F0F0F1,0x286BCA1B,0x3CF3CF3D,0xE9BD37A7,
  0xC28F5C29,0x684BDA13,0x4F72C235,0xBDEF7BDF,
  0x3E0F83E1,0x8AF8AF8B,0x914C1BAD,0x96F96F97,
  0xC18F9C19,0x2FA0BE83,0xA4FA4FA5,0x677D46CF,
  0x1A1F58D1,0xFAFAFAFB,0x8C13521D,0x586FB587,
  0xB823EE09,0xA08AD8F3,0xC10C9715,0xBEFBEFBF,
  0xC0FC0FC1,0x07A44C6B,0xA33F128D,0xE327A977,
  0xC7E3F1F9,0x962FC963,0x3F2B3885,0x613716AF,
  0x781948B1,0x2B2E43DB,0xFCFCFCFD,0x6FD0EB67,
  0xFA3F47E9,0xD2FD2FD3,0x3F4FD3F5,0xD4E25B9F,
  0x5F02A3A1,0xBF5A814B,0x7C32B16D,0xD3431B57,
  0xD8FD8FD9,
};
static inline opus_uint32 imusdiv32odd(opus_uint32 _a,opus_uint32 _b,
 opus_uint32 _c,int _d){
  celt_assert(_d<=52);
  return (_a*_b-_c)*INV_TABLE[_d]&MASK32;
}
static inline opus_uint32 imusdiv32even(opus_uint32 _a,opus_uint32 _b,
 opus_uint32 _c,int _d){
  opus_uint32 inv;
  int           mask;
  int           shift;
  int           one;
  celt_assert(_d>0);
  celt_assert(_d<=54);
  shift=EC_ILOG(_d^(_d-1));
  inv=INV_TABLE[(_d-1)>>shift];
  shift--;
  one=1<<shift;
  mask=one-1;
  return (_a*(_b>>shift)-(_c>>shift)+
   ((_a*(_b&mask)+one-(_c&mask))>>shift)-1)*inv&MASK32;
}
static inline unsigned ucwrs2(unsigned _k){
  celt_assert(_k>0);
  return _k+(_k-1);
}
static inline opus_uint32 ncwrs2(int _k){
  celt_assert(_k>0);
  return 4*(opus_uint32)_k;
}
static inline opus_uint32 ucwrs3(unsigned _k){
  celt_assert(_k>0);
  return (2*(opus_uint32)_k-2)*_k+1;
}
static inline opus_uint32 ncwrs3(int _k){
  celt_assert(_k>0);
  return 2*(2*(unsigned)_k*(opus_uint32)_k+1);
}
static inline opus_uint32 ucwrs4(int _k){
  celt_assert(_k>0);
  return imusdiv32odd(2*_k,(2*_k-3)*(opus_uint32)_k+4,3,1);
}
static inline opus_uint32 ncwrs4(int _k){
  celt_assert(_k>0);
  return ((_k*(opus_uint32)_k+2)*_k)/3<<3;
}
static inline void unext(opus_uint32 *_ui,unsigned _len,opus_uint32 _ui0){
  opus_uint32 ui1;
  unsigned      j;
  j=1; do {
    ui1=UADD32(UADD32(_ui[j],_ui[j-1]),_ui0);
    _ui[j-1]=_ui0;
    _ui0=ui1;
  } while (++j<_len);
  _ui[j-1]=_ui0;
}
static inline void uprev(opus_uint32 *_ui,unsigned _n,opus_uint32 _ui0){
  opus_uint32 ui1;
  unsigned      j;
  j=1; do {
    ui1=USUB32(USUB32(_ui[j],_ui[j-1]),_ui0);
    _ui[j-1]=_ui0;
    _ui0=ui1;
  } while (++j<_n);
  _ui[j-1]=_ui0;
}
static opus_uint32 ncwrs_urow(unsigned _n,unsigned _k,opus_uint32 *_u){
  opus_uint32 um2;
  unsigned      len;
  unsigned      k;
  len=_k+2;
  celt_assert(len>=3);
  _u[0]=0;
  _u[1]=um2=1;
  if(_n<=6)
 {
    celt_assert(_n>=2);
    celt_assert(_k>0);
    k=2;
    do _u[k]=(k<<1)-1;
    while(++k<len);
    for(k=2;k<_n;k++)unext(_u+1,_k+1,1);
  }
  else{
    opus_uint32 um1;
    opus_uint32 n2m1;
    _u[2]=n2m1=um1=(_n<<1)-1;
    for(k=3;k<len;k++){
      _u[k]=um2=imusdiv32even(n2m1,um1,um2,k-1)+um2;
      if(++k>=len)break;
      _u[k]=um1=imusdiv32odd(n2m1,um2,um1,(k-1)>>1)+um1;
    }
  }
  return _u[_k]+_u[_k+1];
}
static inline void cwrsi1(int _k,opus_uint32 _i,int *_y){
  int s;
  s=-(int)_i;
  _y[0]=(_k+s)^s;
}
static inline void cwrsi2(int _k,opus_uint32 _i,int *_y){
  opus_uint32 p;
  int           s;
  int           yj;
  p=ucwrs2(_k+1U);
  s=-(_i>=p);
  _i-=p&s;
  yj=_k;
  _k=(_i+1)>>1;
  p=_k?ucwrs2(_k):0;
  _i-=p;
  yj-=_k;
  _y[0]=(yj+s)^s;
  cwrsi1(_k,_i,_y+1);
}
static void cwrsi3(int _k,opus_uint32 _i,int *_y){
  opus_uint32 p;
  int           s;
  int           yj;
  p=ucwrs3(_k+1U);
  s=-(_i>=p);
  _i-=p&s;
  yj=_k;
  _k=_i>0?(isqrt32(2*_i-1)+1)>>1:0;
  p=_k?ucwrs3(_k):0;
  _i-=p;
  yj-=_k;
  _y[0]=(yj+s)^s;
  cwrsi2(_k,_i,_y+1);
}
static void cwrsi4(int _k,opus_uint32 _i,int *_y){
  opus_uint32 p;
  int           s;
  int           yj;
  int           kl;
  int           kr;
  p=ucwrs4(_k+1);
  s=-(_i>=p);
  _i-=p&s;
  yj=_k;
  kl=0;
  kr=_k;
  for(;;){
    _k=(kl+kr)>>1;
    p=_k?ucwrs4(_k):0;
    if(p<_i){
      if(_k>=kr)break;
      kl=_k+1;
    }
    else if(p>_i)kr=_k-1;
    else break;
  }
  _i-=p;
  yj-=_k;
  _y[0]=(yj+s)^s;
  cwrsi3(_k,_i,_y+1);
}
static void cwrsi(int _n,int _k,opus_uint32 _i,int *_y,opus_uint32 *_u){
  int j;
  celt_assert(_n>0);
  j=0;
  do{
    opus_uint32 p;
    int           s;
    int           yj;
    p=_u[_k+1];
    s=-(_i>=p);
    _i-=p&s;
    yj=_k;
    p=_u[_k];
    while(p>_i)p=_u[--_k];
    _i-=p;
    yj-=_k;
    _y[j]=(yj+s)^s;
    uprev(_u,_k+2,0);
  }
  while(++j<_n);
}
void decode_pulses(int *_y,int _n,int _k,ec_dec *_dec)
{
  celt_assert(_k>0);
   switch(_n){
    case 2:cwrsi2(_k,ec_dec_uint(_dec,ncwrs2(_k)),_y);break;
    case 3:cwrsi3(_k,ec_dec_uint(_dec,ncwrs3(_k)),_y);break;
    case 4:cwrsi4(_k,ec_dec_uint(_dec,ncwrs4(_k)),_y);break;
    default:
    {
      VARDECL(opus_uint32,u);
      SAVE_STACK;
      ALLOC(u,_k+2U,opus_uint32);
      cwrsi(_n,_k,ec_dec_uint(_dec,ncwrs_urow(_n,_k,u)),_y,u);
      RESTORE_STACK;
    }
    break;
  }
}

#if !defined(EC_CLZ)
int ec_ilog(opus_uint32 _v){
  int ret;
  int m;
  ret=!!_v;
  m=!!(_v&0xFFFF0000)<<4;
  _v>>=m;
  ret|=m;
  m=!!(_v&0xFF00)<<3;
  _v>>=m;
  ret|=m;
  m=!!(_v&0xF0)<<2;
  _v>>=m;
  ret|=m;
  m=!!(_v&0xC)<<1;
  _v>>=m;
  ret|=m;
  ret+=!!(_v&0x2);
  return ret;
}
#endif
opus_uint32 ec_tell_frac(ec_ctx *_this){
  opus_uint32 nbits;
  opus_uint32 r;
  int         l;
  int         i;
  nbits=_this->nbits_total<<BITRES;
  l=EC_ILOG(_this->rng);
  r=_this->rng>>(l-16);
  for(i=BITRES;i-->0;){
    int b;
    r=r*r>>15;
    b=(int)(r>>16);
    l=l<<1|b;
    r>>=b;
  }
  return nbits-l;
}

#define EC_SYM_BITS   (8)
#define EC_CODE_BITS  (32)
#define EC_SYM_MAX    ((1U<<EC_SYM_BITS)-1)
#define EC_CODE_TOP   (((opus_uint32)1U)<<(EC_CODE_BITS-1))
#define EC_CODE_BOT   (EC_CODE_TOP>>EC_SYM_BITS)
#define EC_CODE_EXTRA ((EC_CODE_BITS-2)%EC_SYM_BITS+1)

static int ec_read_byte(ec_dec *_this){
  return _this->offs<_this->storage?_this->buf[_this->offs++]:0;
}
static int ec_read_byte_from_end(ec_dec *_this){
  return _this->end_offs<_this->storage?
   _this->buf[_this->storage-++(_this->end_offs)]:0;
}
static void ec_dec_normalize(ec_dec *_this){
  while(_this->rng<=EC_CODE_BOT){
    int sym;
    _this->nbits_total+=EC_SYM_BITS;
    _this->rng<<=EC_SYM_BITS;
    sym=_this->rem;
    _this->rem=ec_read_byte(_this);
    sym=(sym<<EC_SYM_BITS|_this->rem)>>(EC_SYM_BITS-EC_CODE_EXTRA);
    _this->val=((_this->val<<EC_SYM_BITS)+(EC_SYM_MAX&~sym))&(EC_CODE_TOP-1);
  }
}
void ec_dec_init(ec_dec *_this,unsigned char *_buf,opus_uint32 _storage){
  _this->buf=_buf;
  _this->storage=_storage;
  _this->end_offs=0;
  _this->end_window=0;
  _this->nend_bits=0;
  _this->nbits_total=EC_CODE_BITS+1
   -((EC_CODE_BITS-EC_CODE_EXTRA)/EC_SYM_BITS)*EC_SYM_BITS;
  _this->offs=0;
  _this->rng=1U<<EC_CODE_EXTRA;
  _this->rem=ec_read_byte(_this);
  _this->val=_this->rng-1-(_this->rem>>(EC_SYM_BITS-EC_CODE_EXTRA));
  _this->error=0;
  ec_dec_normalize(_this);
}
unsigned ec_decode(ec_dec *_this,unsigned _ft){
  unsigned s;
  _this->ext=_this->rng/_ft;
  s=(unsigned)(_this->val/_this->ext);
  return _ft-EC_MINI(s+1,_ft);
}
unsigned ec_decode_bin(ec_dec *_this,unsigned _bits){
   unsigned s;
   _this->ext=_this->rng>>_bits;
   s=(unsigned)(_this->val/_this->ext);
   return (1U<<_bits)-EC_MINI(s+1U,1U<<_bits);
}
void ec_dec_update(ec_dec *_this,unsigned _fl,unsigned _fh,unsigned _ft){
  opus_uint32 s;
  s=IMUL32(_this->ext,_ft-_fh);
  _this->val-=s;
  _this->rng=_fl>0?IMUL32(_this->ext,_fh-_fl):_this->rng-s;
  ec_dec_normalize(_this);
}
int ec_dec_bit_logp(ec_dec *_this,unsigned _logp){
  opus_uint32 r;
  opus_uint32 d;
  opus_uint32 s;
  int         ret;
  r=_this->rng;
  d=_this->val;
  s=r>>_logp;
  ret=d<s;
  if(!ret)_this->val=d-s;
  _this->rng=ret?s:r-s;
  ec_dec_normalize(_this);
  return ret;
}
int ec_dec_icdf(ec_dec *_this,const unsigned char *_icdf,unsigned _ftb){
  opus_uint32 r;
  opus_uint32 d;
  opus_uint32 s;
  opus_uint32 t;
  int         ret;
  s=_this->rng;
  d=_this->val;
  r=s>>_ftb;
  ret=-1;
  do{
    t=s;
    s=IMUL32(r,_icdf[++ret]);
  }
  while(d<s);
  _this->val=d-s;
  _this->rng=t-s;
  ec_dec_normalize(_this);
  return ret;
}
opus_uint32 ec_dec_uint(ec_dec *_this,opus_uint32 _ft){
  unsigned ft;
  unsigned s;
  int      ftb;
  celt_assert(_ft>1);
  _ft--;
  ftb=EC_ILOG(_ft);
  if(ftb>EC_UINT_BITS){
    opus_uint32 t;
    ftb-=EC_UINT_BITS;
    ft=(unsigned)(_ft>>ftb)+1;
    s=ec_decode(_this,ft);
    ec_dec_update(_this,s,s+1,ft);
    t=(opus_uint32)s<<ftb|ec_dec_bits(_this,ftb);
    if(t<=_ft)return t;
    _this->error=1;
    return _ft;
  }
  else{
    _ft++;
    s=ec_decode(_this,(unsigned)_ft);
    ec_dec_update(_this,s,s+1,(unsigned)_ft);
    return s;
  }
}
opus_uint32 ec_dec_bits(ec_dec *_this,unsigned _bits){
  ec_window   window;
  int         available;
  opus_uint32 ret;
  window=_this->end_window;
  available=_this->nend_bits;
  if((unsigned)available<_bits){
    do{
      window|=(ec_window)ec_read_byte_from_end(_this)<<available;
      available+=EC_SYM_BITS;
    }
    while(available<=EC_WINDOW_SIZE-EC_SYM_BITS);
  }
  ret=(opus_uint32)window&(((opus_uint32)1<<_bits)-1U);
  window>>=_bits;
  available-=_bits;
  _this->end_window=window;
  _this->nend_bits=available;
  _this->nbits_total+=_bits;
  return ret;
}

#   define S_MUL(a,b) ( (a)*(b) )
#define C_MULC(m,a,b) \
    do{ (m).r = (a).r*(b).r + (a).i*(b).i;\
        (m).i = (a).i*(b).r - (a).r*(b).i; }while(0)
#   define C_MULBYSCALAR( c, s ) \
    do{ (c).r *= (s);\
        (c).i *= (s); }while(0)
#ifndef CHECK_OVERFLOW_OP
#  define CHECK_OVERFLOW_OP(a,op,b)
#endif
#ifndef C_ADD
#define  C_ADD( res, a,b)\
    do { \
            CHECK_OVERFLOW_OP((a).r,+,(b).r)\
            CHECK_OVERFLOW_OP((a).i,+,(b).i)\
            (res).r=(a).r+(b).r;  (res).i=(a).i+(b).i; \
    }while(0)
#define  C_SUB( res, a,b)\
    do { \
            CHECK_OVERFLOW_OP((a).r,-,(b).r)\
            CHECK_OVERFLOW_OP((a).i,-,(b).i)\
            (res).r=(a).r-(b).r;  (res).i=(a).i-(b).i; \
    }while(0)
#define C_ADDTO( res , a)\
    do { \
            CHECK_OVERFLOW_OP((res).r,+,(a).r)\
            CHECK_OVERFLOW_OP((res).i,+,(a).i)\
            (res).r += (a).r;  (res).i += (a).i;\
    }while(0)
#endif
#  define HALF_OF(x) ((x)*.5f)

static void ki_bfly2(
                     kiss_fft_cpx * Fout,
                     const size_t fstride,
                     const kiss_fft_state *st,
                     int m,
                     int N,
                     int mm
                    )
{
   kiss_fft_cpx * Fout2;
   const kiss_twiddle_cpx * tw1;
   kiss_fft_cpx t;
   int i,j;
   kiss_fft_cpx * Fout_beg = Fout;
   for (i=0;i<N;i++)
   {
      Fout = Fout_beg + i*mm;
      Fout2 = Fout + m;
      tw1 = st->twiddles;
      for(j=0;j<m;j++)
      {
         C_MULC (t,  *Fout2 , *tw1);
         tw1 += fstride;
         C_SUB( *Fout2 ,  *Fout , t );
         C_ADDTO( *Fout ,  t );
         ++Fout2;
         ++Fout;
      }
   }
}
static void ki_bfly4(
                     kiss_fft_cpx * Fout,
                     const size_t fstride,
                     const kiss_fft_state *st,
                     int m,
                     int N,
                     int mm
                    )
{
   const kiss_twiddle_cpx *tw1,*tw2,*tw3;
   kiss_fft_cpx scratch[6];
   const size_t m2=2*m;
   const size_t m3=3*m;
   int i, j;
   kiss_fft_cpx * Fout_beg = Fout;
   for (i=0;i<N;i++)
   {
      Fout = Fout_beg + i*mm;
      tw3 = tw2 = tw1 = st->twiddles;
      for (j=0;j<m;j++)
      {
         C_MULC(scratch[0],Fout[m] , *tw1 );
         C_MULC(scratch[1],Fout[m2] , *tw2 );
         C_MULC(scratch[2],Fout[m3] , *tw3 );
         C_SUB( scratch[5] , *Fout, scratch[1] );
         C_ADDTO(*Fout, scratch[1]);
         C_ADD( scratch[3] , scratch[0] , scratch[2] );
         C_SUB( scratch[4] , scratch[0] , scratch[2] );
         C_SUB( Fout[m2], *Fout, scratch[3] );
         tw1 += fstride;
         tw2 += fstride*2;
         tw3 += fstride*3;
         C_ADDTO( *Fout , scratch[3] );
         Fout[m].r = scratch[5].r - scratch[4].i;
         Fout[m].i = scratch[5].i + scratch[4].r;
         Fout[m3].r = scratch[5].r + scratch[4].i;
         Fout[m3].i = scratch[5].i - scratch[4].r;
         ++Fout;
      }
   }
}
static void ki_bfly3(
                     kiss_fft_cpx * Fout,
                     const size_t fstride,
                     const kiss_fft_state *st,
                     int m,
                     int N,
                     int mm
                    )
{
   int i, k;
   const size_t m2 = 2*m;
   const kiss_twiddle_cpx *tw1,*tw2;
   kiss_fft_cpx scratch[5];
   kiss_twiddle_cpx epi3;
   kiss_fft_cpx * Fout_beg = Fout;
   epi3 = st->twiddles[fstride*m];
   for (i=0;i<N;i++)
   {
      Fout = Fout_beg + i*mm;
      tw1=tw2=st->twiddles;
      k=m;
      do{
         C_MULC(scratch[1],Fout[m] , *tw1);
         C_MULC(scratch[2],Fout[m2] , *tw2);
         C_ADD(scratch[3],scratch[1],scratch[2]);
         C_SUB(scratch[0],scratch[1],scratch[2]);
         tw1 += fstride;
         tw2 += fstride*2;
         Fout[m].r = Fout->r - HALF_OF(scratch[3].r);
         Fout[m].i = Fout->i - HALF_OF(scratch[3].i);
         C_MULBYSCALAR( scratch[0] , -epi3.i );
         C_ADDTO(*Fout,scratch[3]);
         Fout[m2].r = Fout[m].r + scratch[0].i;
         Fout[m2].i = Fout[m].i - scratch[0].r;
         Fout[m].r -= scratch[0].i;
         Fout[m].i += scratch[0].r;
         ++Fout;
      }while(--k);
   }
}
static void ki_bfly5(
                     kiss_fft_cpx * Fout,
                     const size_t fstride,
                     const kiss_fft_state *st,
                     int m,
                     int N,
                     int mm
                    )
{
   kiss_fft_cpx *Fout0,*Fout1,*Fout2,*Fout3,*Fout4;
   int i, u;
   kiss_fft_cpx scratch[13];
   const kiss_twiddle_cpx * twiddles = st->twiddles;
   const kiss_twiddle_cpx *tw;
   kiss_twiddle_cpx ya,yb;
   kiss_fft_cpx * Fout_beg = Fout;
   ya = twiddles[fstride*m];
   yb = twiddles[fstride*2*m];
   tw=st->twiddles;
   for (i=0;i<N;i++)
   {
      Fout = Fout_beg + i*mm;
      Fout0=Fout;
      Fout1=Fout0+m;
      Fout2=Fout0+2*m;
      Fout3=Fout0+3*m;
      Fout4=Fout0+4*m;
      for ( u=0; u<m; ++u ) {
         scratch[0] = *Fout0;
         C_MULC(scratch[1] ,*Fout1, tw[u*fstride]);
         C_MULC(scratch[2] ,*Fout2, tw[2*u*fstride]);
         C_MULC(scratch[3] ,*Fout3, tw[3*u*fstride]);
         C_MULC(scratch[4] ,*Fout4, tw[4*u*fstride]);
         C_ADD( scratch[7],scratch[1],scratch[4]);
         C_SUB( scratch[10],scratch[1],scratch[4]);
         C_ADD( scratch[8],scratch[2],scratch[3]);
         C_SUB( scratch[9],scratch[2],scratch[3]);
         Fout0->r += scratch[7].r + scratch[8].r;
         Fout0->i += scratch[7].i + scratch[8].i;
         scratch[5].r = scratch[0].r + S_MUL(scratch[7].r,ya.r) + S_MUL(scratch[8].r,yb.r);
         scratch[5].i = scratch[0].i + S_MUL(scratch[7].i,ya.r) + S_MUL(scratch[8].i,yb.r);
         scratch[6].r = -S_MUL(scratch[10].i,ya.i) - S_MUL(scratch[9].i,yb.i);
         scratch[6].i =  S_MUL(scratch[10].r,ya.i) + S_MUL(scratch[9].r,yb.i);
         C_SUB(*Fout1,scratch[5],scratch[6]);
         C_ADD(*Fout4,scratch[5],scratch[6]);
         scratch[11].r = scratch[0].r + S_MUL(scratch[7].r,yb.r) + S_MUL(scratch[8].r,ya.r);
         scratch[11].i = scratch[0].i + S_MUL(scratch[7].i,yb.r) + S_MUL(scratch[8].i,ya.r);
         scratch[12].r =  S_MUL(scratch[10].i,yb.i) - S_MUL(scratch[9].i,ya.i);
         scratch[12].i = -S_MUL(scratch[10].r,yb.i) + S_MUL(scratch[9].r,ya.i);
         C_ADD(*Fout2,scratch[11],scratch[12]);
         C_SUB(*Fout3,scratch[11],scratch[12]);
         ++Fout0;++Fout1;++Fout2;++Fout3;++Fout4;
      }
   }
}
void opus_ifft(const kiss_fft_state *st,const kiss_fft_cpx *fin,kiss_fft_cpx *fout)
{
   int m2, m;
   int p;
   int L;
   int fstride[MAXFACTORS];
   int i;
   int shift;
   shift = st->shift>0 ? st->shift : 0;
   celt_assert2 (fin != fout, "In-place FFT not supported");
   for (i=0;i<st->nfft;i++)
      fout[st->bitrev[i]] = fin[i];
   fstride[0] = 1;
   L=0;
   do {
      p = st->factors[2*L];
      m = st->factors[2*L+1];
      fstride[L+1] = fstride[L]*p;
      L++;
   } while(m!=1);
   m = st->factors[2*L-1];
   for (i=L-1;i>=0;i--)
   {
      if (i!=0)
         m2 = st->factors[2*i-1];
      else
         m2 = 1;
      switch (st->factors[2*i])
      {
      case 2:
         ki_bfly2(fout,fstride[i]<<shift,st,m, fstride[i], m2);
         break;
      case 4:
         ki_bfly4(fout,fstride[i]<<shift,st,m, fstride[i], m2);
         break;
      case 3:
         ki_bfly3(fout,fstride[i]<<shift,st,m, fstride[i], m2);
         break;
      case 5:
         ki_bfly5(fout,fstride[i]<<shift,st,m, fstride[i], m2);
         break;
      }
      m = m2;
   }
}

int ec_laplace_decode(ec_dec *dec, unsigned fs, int decay);

#define LAPLACE_LOG_MINP (0)
#define LAPLACE_MINP (1<<LAPLACE_LOG_MINP)
#define LAPLACE_NMIN (16)
static unsigned ec_laplace_get_freq1(unsigned fs0, int decay)
{
   unsigned ft;
   ft = 32768 - LAPLACE_MINP*(2*LAPLACE_NMIN) - fs0;
   return ft*(16384-decay)>>15;
}
int ec_laplace_decode(ec_dec *dec, unsigned fs, int decay)
{
   int val=0;
   unsigned fl;
   unsigned fm;
   fm = ec_decode_bin(dec, 15);
   fl = 0;
   if (fm >= fs)
   {
      val++;
      fl = fs;
      fs = ec_laplace_get_freq1(fs, decay)+LAPLACE_MINP;
      while(fs > LAPLACE_MINP && fm >= fl+2*fs)
      {
         fs *= 2;
         fl += fs;
         fs = ((fs-2*LAPLACE_MINP)*(opus_int32)decay)>>15;
         fs += LAPLACE_MINP;
         val++;
      }
      if (fs <= LAPLACE_MINP)
      {
         int di;
         di = (fm-fl)>>(LAPLACE_LOG_MINP+1);
         val += di;
         fl += 2*di*LAPLACE_MINP;
      }
      if (fm < fl+fs)
         val = -val;
      else
         fl += fs;
   }
   celt_assert(fl<32768);
   celt_assert(fs>0);
   celt_assert(fl<=fm);
   celt_assert(fm<IMIN(fl+fs,32768));
   ec_dec_update(dec, fl, IMIN(fl+fs,32768), 32768);
   return val;
}

unsigned isqrt32(opus_uint32 _val){
  unsigned b;
  unsigned g;
  int      bshift;
  g=0;
  bshift=(EC_ILOG(_val)-1)>>1;
  b=1U<<bshift;
  do{
    opus_uint32 t;
    t=(((opus_uint32)g<<1)+b)<<bshift;
    if(t<=_val){
      g+=b;
      _val-=t;
    }
    b>>=1;
    bshift--;
  }
  while(bshift>=0);
  return g;
}

void clt_mdct_backward(const mdct_lookup *l, kiss_fft_scalar *in, kiss_fft_scalar * restrict out,
      const opus_val16 * restrict window, int overlap, int shift, int stride)
{
   int i;
   int N, N2, N4;
   kiss_twiddle_scalar sine;
   VARDECL(kiss_fft_scalar, f);
   VARDECL(kiss_fft_scalar, f2);
   SAVE_STACK;
   N = l->n;
   N >>= shift;
   N2 = N>>1;
   N4 = N>>2;
   ALLOC(f, N2, kiss_fft_scalar);
   ALLOC(f2, N2, kiss_fft_scalar);
   sine = (kiss_twiddle_scalar)2*PI*(.125f)/N;
   {
      const kiss_fft_scalar * restrict xp1 = in;
      const kiss_fft_scalar * restrict xp2 = in+stride*(N2-1);
      kiss_fft_scalar * restrict yp = f2;
      const kiss_twiddle_scalar *t = &l->trig[0];
      for(i=0;i<N4;i++)
      {
         kiss_fft_scalar yr, yi;
         yr = -S_MUL(*xp2, t[i<<shift]) + S_MUL(*xp1,t[(N4-i)<<shift]);
         yi =  -S_MUL(*xp2, t[(N4-i)<<shift]) - S_MUL(*xp1,t[i<<shift]);
         *yp++ = yr - S_MUL(yi,sine);
         *yp++ = yi + S_MUL(yr,sine);
         xp1+=2*stride;
         xp2-=2*stride;
      }
   }
   opus_ifft(l->kfft[shift], (kiss_fft_cpx *)f2, (kiss_fft_cpx *)f);
   {
      kiss_fft_scalar * restrict fp = f;
      const kiss_twiddle_scalar *t = &l->trig[0];
      for(i=0;i<N4;i++)
      {
         kiss_fft_scalar re, im, yr, yi;
         re = fp[0];
         im = fp[1];
         yr = S_MUL(re,t[i<<shift]) - S_MUL(im,t[(N4-i)<<shift]);
         yi = S_MUL(im,t[i<<shift]) + S_MUL(re,t[(N4-i)<<shift]);
         *fp++ = yr - S_MUL(yi,sine);
         *fp++ = yi + S_MUL(yr,sine);
      }
   }
   {
      const kiss_fft_scalar * restrict fp1 = f;
      const kiss_fft_scalar * restrict fp2 = f+N2-1;
      kiss_fft_scalar * restrict yp = f2;
      for(i = 0; i < N4; i++)
      {
         *yp++ =-*fp1;
         *yp++ = *fp2;
         fp1 += 2;
         fp2 -= 2;
      }
   }
   out -= (N2-overlap)>>1;
   {
      kiss_fft_scalar * restrict fp1 = f2+N4-1;
      kiss_fft_scalar * restrict xp1 = out+N2-1;
      kiss_fft_scalar * restrict yp1 = out+N4-overlap/2;
      const opus_val16 * restrict wp1 = window;
      const opus_val16 * restrict wp2 = window+overlap-1;
      for(i = 0; i< N4-overlap/2; i++)
      {
         *xp1 = *fp1;
         xp1--;
         fp1--;
      }
      for(; i < N4; i++)
      {
         kiss_fft_scalar x1;
         x1 = *fp1--;
         *yp1++ +=-MULT16_32_Q15(*wp1, x1);
         *xp1-- += MULT16_32_Q15(*wp2, x1);
         wp1++;
         wp2--;
      }
   }
   {
      kiss_fft_scalar * restrict fp2 = f2+N4;
      kiss_fft_scalar * restrict xp2 = out+N2;
      kiss_fft_scalar * restrict yp2 = out+N-1-(N4-overlap/2);
      const opus_val16 * restrict wp1 = window;
      const opus_val16 * restrict wp2 = window+overlap-1;
      for(i = 0; i< N4-overlap/2; i++)
      {
         *xp2 = *fp2;
         xp2++;
         fp2++;
      }
      for(; i < N4; i++)
      {
         kiss_fft_scalar x2;
         x2 = *fp2++;
         *yp2--  = MULT16_32_Q15(*wp1, x2);
         *xp2++  = MULT16_32_Q15(*wp2, x2);
         wp1++;
         wp2--;
      }
   }
   RESTORE_STACK;
}

static const opus_int16 eband5ms[] = {
  0,  1,  2,  3,  4,  5,  6,  7,  8, 10, 12, 14, 16, 20, 24, 28, 34, 40, 48, 60, 78, 100
};
static const unsigned char band_allocation[] = {
  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
 90, 80, 75, 69, 63, 56, 49, 40, 34, 29, 20, 18, 10,  0,  0,  0,  0,  0,  0,  0,  0,
110,100, 90, 84, 78, 71, 65, 58, 51, 45, 39, 32, 26, 20, 12,  0,  0,  0,  0,  0,  0,
118,110,103, 93, 86, 80, 75, 70, 65, 59, 53, 47, 40, 31, 23, 15,  4,  0,  0,  0,  0,
126,119,112,104, 95, 89, 83, 78, 72, 66, 60, 54, 47, 39, 32, 25, 17, 12,  1,  0,  0,
134,127,120,114,103, 97, 91, 85, 78, 72, 66, 60, 54, 47, 41, 35, 29, 23, 16, 10,  1,
144,137,130,124,113,107,101, 95, 88, 82, 76, 70, 64, 57, 51, 45, 39, 33, 26, 15,  1,
152,145,138,132,123,117,111,105, 98, 92, 86, 80, 74, 67, 61, 55, 49, 43, 36, 20,  1,
162,155,148,142,133,127,121,115,108,102, 96, 90, 84, 77, 71, 65, 59, 53, 46, 30,  1,
172,165,158,152,143,137,131,125,118,112,106,100, 94, 87, 81, 75, 69, 63, 56, 45, 20,
200,200,200,200,200,200,200,200,198,193,188,183,178,173,168,163,158,153,148,129,104,
};
#ifndef DEF_WINDOW120
#define DEF_WINDOW120
static const opus_val16 window120[120] = {
6.7286966e-05f, 0.00060551348f, 0.0016815970f, 0.0032947962f, 0.0054439943f,
0.0081276923f, 0.011344001f, 0.015090633f, 0.019364886f, 0.024163635f,
0.029483315f, 0.035319905f, 0.041668911f, 0.048525347f, 0.055883718f,
0.063737999f, 0.072081616f, 0.080907428f, 0.090207705f, 0.099974111f,
0.11019769f, 0.12086883f, 0.13197729f, 0.14351214f, 0.15546177f,
0.16781389f, 0.18055550f, 0.19367290f, 0.20715171f, 0.22097682f,
0.23513243f, 0.24960208f, 0.26436860f, 0.27941419f, 0.29472040f,
0.31026818f, 0.32603788f, 0.34200931f, 0.35816177f, 0.37447407f,
0.39092462f, 0.40749142f, 0.42415215f, 0.44088423f, 0.45766484f,
0.47447104f, 0.49127978f, 0.50806798f, 0.52481261f, 0.54149077f,
0.55807973f, 0.57455701f, 0.59090049f, 0.60708841f, 0.62309951f,
0.63891306f, 0.65450896f, 0.66986776f, 0.68497077f, 0.69980010f,
0.71433873f, 0.72857055f, 0.74248043f, 0.75605424f, 0.76927895f,
0.78214257f, 0.79463430f, 0.80674445f, 0.81846456f, 0.82978733f,
0.84070669f, 0.85121779f, 0.86131698f, 0.87100183f, 0.88027111f,
0.88912479f, 0.89756398f, 0.90559094f, 0.91320904f, 0.92042270f,
0.92723738f, 0.93365955f, 0.93969656f, 0.94535671f, 0.95064907f,
0.95558353f, 0.96017067f, 0.96442171f, 0.96834849f, 0.97196334f,
0.97527906f, 0.97830883f, 0.98106616f, 0.98356480f, 0.98581869f,
0.98784191f, 0.98964856f, 0.99125274f, 0.99266849f, 0.99390969f,
0.99499004f, 0.99592297f, 0.99672162f, 0.99739874f, 0.99796667f,
0.99843728f, 0.99882195f, 0.99913147f, 0.99937606f, 0.99956527f,
0.99970802f, 0.99981248f, 0.99988613f, 0.99993565f, 0.99996697f,
0.99998518f, 0.99999457f, 0.99999859f, 0.99999982f, 1.0000000f,
};
#endif
#ifndef DEF_LOGN400
#define DEF_LOGN400
static const opus_int16 logN400[21] = {
0, 0, 0, 0, 0, 0, 0, 0, 8, 8, 8, 8, 16, 16, 16, 21, 21, 24, 29, 34, 36, };
#endif
#ifndef DEF_PULSE_CACHE50
#define DEF_PULSE_CACHE50
static const opus_int16 cache_index50[105] = {
-1, -1, -1, -1, -1, -1, -1, -1, 0, 0, 0, 0, 41, 41, 41,
82, 82, 123, 164, 200, 222, 0, 0, 0, 0, 0, 0, 0, 0, 41,
41, 41, 41, 123, 123, 123, 164, 164, 240, 266, 283, 295, 41, 41, 41,
41, 41, 41, 41, 41, 123, 123, 123, 123, 240, 240, 240, 266, 266, 305,
318, 328, 336, 123, 123, 123, 123, 123, 123, 123, 123, 240, 240, 240, 240,
305, 305, 305, 318, 318, 343, 351, 358, 364, 240, 240, 240, 240, 240, 240,
240, 240, 305, 305, 305, 305, 343, 343, 343, 351, 351, 370, 376, 382, 387,
};
static const unsigned char cache_bits50[392] = {
40, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 40, 15, 23, 28,
31, 34, 36, 38, 39, 41, 42, 43, 44, 45, 46, 47, 47, 49, 50,
51, 52, 53, 54, 55, 55, 57, 58, 59, 60, 61, 62, 63, 63, 65,
66, 67, 68, 69, 70, 71, 71, 40, 20, 33, 41, 48, 53, 57, 61,
64, 66, 69, 71, 73, 75, 76, 78, 80, 82, 85, 87, 89, 91, 92,
94, 96, 98, 101, 103, 105, 107, 108, 110, 112, 114, 117, 119, 121, 123,
124, 126, 128, 40, 23, 39, 51, 60, 67, 73, 79, 83, 87, 91, 94,
97, 100, 102, 105, 107, 111, 115, 118, 121, 124, 126, 129, 131, 135, 139,
142, 145, 148, 150, 153, 155, 159, 163, 166, 169, 172, 174, 177, 179, 35,
28, 49, 65, 78, 89, 99, 107, 114, 120, 126, 132, 136, 141, 145, 149,
153, 159, 165, 171, 176, 180, 185, 189, 192, 199, 205, 211, 216, 220, 225,
229, 232, 239, 245, 251, 21, 33, 58, 79, 97, 112, 125, 137, 148, 157,
166, 174, 182, 189, 195, 201, 207, 217, 227, 235, 243, 251, 17, 35, 63,
86, 106, 123, 139, 152, 165, 177, 187, 197, 206, 214, 222, 230, 237, 250,
25, 31, 55, 75, 91, 105, 117, 128, 138, 146, 154, 161, 168, 174, 180,
185, 190, 200, 208, 215, 222, 229, 235, 240, 245, 255, 16, 36, 65, 89,
110, 128, 144, 159, 173, 185, 196, 207, 217, 226, 234, 242, 250, 11, 41,
74, 103, 128, 151, 172, 191, 209, 225, 241, 255, 9, 43, 79, 110, 138,
163, 186, 207, 227, 246, 12, 39, 71, 99, 123, 144, 164, 182, 198, 214,
228, 241, 253, 9, 44, 81, 113, 142, 168, 192, 214, 235, 255, 7, 49,
90, 127, 160, 191, 220, 247, 6, 51, 95, 134, 170, 203, 234, 7, 47,
87, 123, 155, 184, 212, 237, 6, 52, 97, 137, 174, 208, 240, 5, 57,
106, 151, 192, 231, 5, 59, 111, 158, 202, 243, 5, 55, 103, 147, 187,
224, 5, 60, 113, 161, 206, 248, 4, 65, 122, 175, 224, 4, 67, 127,
182, 234, };
static const unsigned char cache_caps50[168] = {
224, 224, 224, 224, 224, 224, 224, 224, 160, 160, 160, 160, 185, 185, 185,
178, 178, 168, 134, 61, 37, 224, 224, 224, 224, 224, 224, 224, 224, 240,
240, 240, 240, 207, 207, 207, 198, 198, 183, 144, 66, 40, 160, 160, 160,
160, 160, 160, 160, 160, 185, 185, 185, 185, 193, 193, 193, 183, 183, 172,
138, 64, 38, 240, 240, 240, 240, 240, 240, 240, 240, 207, 207, 207, 207,
204, 204, 204, 193, 193, 180, 143, 66, 40, 185, 185, 185, 185, 185, 185,
185, 185, 193, 193, 193, 193, 193, 193, 193, 183, 183, 172, 138, 65, 39,
207, 207, 207, 207, 207, 207, 207, 207, 204, 204, 204, 204, 201, 201, 201,
188, 188, 176, 141, 66, 40, 193, 193, 193, 193, 193, 193, 193, 193, 193,
193, 193, 193, 194, 194, 194, 184, 184, 173, 139, 65, 39, 204, 204, 204,
204, 204, 204, 204, 204, 201, 201, 201, 201, 198, 198, 198, 187, 187, 175,
140, 66, 40, };
#endif
#ifndef FFT_TWIDDLES48000_960
#define FFT_TWIDDLES48000_960
static const kiss_twiddle_cpx fft_twiddles48000_960[480] = {
{1.0000000f, -0.0000000f}, {0.99991433f, -0.013089596f},
{0.99965732f, -0.026176948f}, {0.99922904f, -0.039259816f},
{0.99862953f, -0.052335956f}, {0.99785892f, -0.065403129f},
{0.99691733f, -0.078459096f}, {0.99580493f, -0.091501619f},
{0.99452190f, -0.10452846f}, {0.99306846f, -0.11753740f},
{0.99144486f, -0.13052619f}, {0.98965139f, -0.14349262f},
{0.98768834f, -0.15643447f}, {0.98555606f, -0.16934950f},
{0.98325491f, -0.18223553f}, {0.98078528f, -0.19509032f},
{0.97814760f, -0.20791169f}, {0.97534232f, -0.22069744f},
{0.97236992f, -0.23344536f}, {0.96923091f, -0.24615329f},
{0.96592583f, -0.25881905f}, {0.96245524f, -0.27144045f},
{0.95881973f, -0.28401534f}, {0.95501994f, -0.29654157f},
{0.95105652f, -0.30901699f}, {0.94693013f, -0.32143947f},
{0.94264149f, -0.33380686f}, {0.93819134f, -0.34611706f},
{0.93358043f, -0.35836795f}, {0.92880955f, -0.37055744f},
{0.92387953f, -0.38268343f}, {0.91879121f, -0.39474386f},
{0.91354546f, -0.40673664f}, {0.90814317f, -0.41865974f},
{0.90258528f, -0.43051110f}, {0.89687274f, -0.44228869f},
{0.89100652f, -0.45399050f}, {0.88498764f, -0.46561452f},
{0.87881711f, -0.47715876f}, {0.87249601f, -0.48862124f},
{0.86602540f, -0.50000000f}, {0.85940641f, -0.51129309f},
{0.85264016f, -0.52249856f}, {0.84572782f, -0.53361452f},
{0.83867057f, -0.54463904f}, {0.83146961f, -0.55557023f},
{0.82412619f, -0.56640624f}, {0.81664156f, -0.57714519f},
{0.80901699f, -0.58778525f}, {0.80125381f, -0.59832460f},
{0.79335334f, -0.60876143f}, {0.78531693f, -0.61909395f},
{0.77714596f, -0.62932039f}, {0.76884183f, -0.63943900f},
{0.76040597f, -0.64944805f}, {0.75183981f, -0.65934582f},
{0.74314483f, -0.66913061f}, {0.73432251f, -0.67880075f},
{0.72537437f, -0.68835458f}, {0.71630194f, -0.69779046f},
{0.70710678f, -0.70710678f}, {0.69779046f, -0.71630194f},
{0.68835458f, -0.72537437f}, {0.67880075f, -0.73432251f},
{0.66913061f, -0.74314483f}, {0.65934582f, -0.75183981f},
{0.64944805f, -0.76040597f}, {0.63943900f, -0.76884183f},
{0.62932039f, -0.77714596f}, {0.61909395f, -0.78531693f},
{0.60876143f, -0.79335334f}, {0.59832460f, -0.80125381f},
{0.58778525f, -0.80901699f}, {0.57714519f, -0.81664156f},
{0.56640624f, -0.82412619f}, {0.55557023f, -0.83146961f},
{0.54463904f, -0.83867057f}, {0.53361452f, -0.84572782f},
{0.52249856f, -0.85264016f}, {0.51129309f, -0.85940641f},
{0.50000000f, -0.86602540f}, {0.48862124f, -0.87249601f},
{0.47715876f, -0.87881711f}, {0.46561452f, -0.88498764f},
{0.45399050f, -0.89100652f}, {0.44228869f, -0.89687274f},
{0.43051110f, -0.90258528f}, {0.41865974f, -0.90814317f},
{0.40673664f, -0.91354546f}, {0.39474386f, -0.91879121f},
{0.38268343f, -0.92387953f}, {0.37055744f, -0.92880955f},
{0.35836795f, -0.93358043f}, {0.34611706f, -0.93819134f},
{0.33380686f, -0.94264149f}, {0.32143947f, -0.94693013f},
{0.30901699f, -0.95105652f}, {0.29654157f, -0.95501994f},
{0.28401534f, -0.95881973f}, {0.27144045f, -0.96245524f},
{0.25881905f, -0.96592583f}, {0.24615329f, -0.96923091f},
{0.23344536f, -0.97236992f}, {0.22069744f, -0.97534232f},
{0.20791169f, -0.97814760f}, {0.19509032f, -0.98078528f},
{0.18223553f, -0.98325491f}, {0.16934950f, -0.98555606f},
{0.15643447f, -0.98768834f}, {0.14349262f, -0.98965139f},
{0.13052619f, -0.99144486f}, {0.11753740f, -0.99306846f},
{0.10452846f, -0.99452190f}, {0.091501619f, -0.99580493f},
{0.078459096f, -0.99691733f}, {0.065403129f, -0.99785892f},
{0.052335956f, -0.99862953f}, {0.039259816f, -0.99922904f},
{0.026176948f, -0.99965732f}, {0.013089596f, -0.99991433f},
{6.1230318e-17f, -1.0000000f}, {-0.013089596f, -0.99991433f},
{-0.026176948f, -0.99965732f}, {-0.039259816f, -0.99922904f},
{-0.052335956f, -0.99862953f}, {-0.065403129f, -0.99785892f},
{-0.078459096f, -0.99691733f}, {-0.091501619f, -0.99580493f},
{-0.10452846f, -0.99452190f}, {-0.11753740f, -0.99306846f},
{-0.13052619f, -0.99144486f}, {-0.14349262f, -0.98965139f},
{-0.15643447f, -0.98768834f}, {-0.16934950f, -0.98555606f},
{-0.18223553f, -0.98325491f}, {-0.19509032f, -0.98078528f},
{-0.20791169f, -0.97814760f}, {-0.22069744f, -0.97534232f},
{-0.23344536f, -0.97236992f}, {-0.24615329f, -0.96923091f},
{-0.25881905f, -0.96592583f}, {-0.27144045f, -0.96245524f},
{-0.28401534f, -0.95881973f}, {-0.29654157f, -0.95501994f},
{-0.30901699f, -0.95105652f}, {-0.32143947f, -0.94693013f},
{-0.33380686f, -0.94264149f}, {-0.34611706f, -0.93819134f},
{-0.35836795f, -0.93358043f}, {-0.37055744f, -0.92880955f},
{-0.38268343f, -0.92387953f}, {-0.39474386f, -0.91879121f},
{-0.40673664f, -0.91354546f}, {-0.41865974f, -0.90814317f},
{-0.43051110f, -0.90258528f}, {-0.44228869f, -0.89687274f},
{-0.45399050f, -0.89100652f}, {-0.46561452f, -0.88498764f},
{-0.47715876f, -0.87881711f}, {-0.48862124f, -0.87249601f},
{-0.50000000f, -0.86602540f}, {-0.51129309f, -0.85940641f},
{-0.52249856f, -0.85264016f}, {-0.53361452f, -0.84572782f},
{-0.54463904f, -0.83867057f}, {-0.55557023f, -0.83146961f},
{-0.56640624f, -0.82412619f}, {-0.57714519f, -0.81664156f},
{-0.58778525f, -0.80901699f}, {-0.59832460f, -0.80125381f},
{-0.60876143f, -0.79335334f}, {-0.61909395f, -0.78531693f},
{-0.62932039f, -0.77714596f}, {-0.63943900f, -0.76884183f},
{-0.64944805f, -0.76040597f}, {-0.65934582f, -0.75183981f},
{-0.66913061f, -0.74314483f}, {-0.67880075f, -0.73432251f},
{-0.68835458f, -0.72537437f}, {-0.69779046f, -0.71630194f},
{-0.70710678f, -0.70710678f}, {-0.71630194f, -0.69779046f},
{-0.72537437f, -0.68835458f}, {-0.73432251f, -0.67880075f},
{-0.74314483f, -0.66913061f}, {-0.75183981f, -0.65934582f},
{-0.76040597f, -0.64944805f}, {-0.76884183f, -0.63943900f},
{-0.77714596f, -0.62932039f}, {-0.78531693f, -0.61909395f},
{-0.79335334f, -0.60876143f}, {-0.80125381f, -0.59832460f},
{-0.80901699f, -0.58778525f}, {-0.81664156f, -0.57714519f},
{-0.82412619f, -0.56640624f}, {-0.83146961f, -0.55557023f},
{-0.83867057f, -0.54463904f}, {-0.84572782f, -0.53361452f},
{-0.85264016f, -0.52249856f}, {-0.85940641f, -0.51129309f},
{-0.86602540f, -0.50000000f}, {-0.87249601f, -0.48862124f},
{-0.87881711f, -0.47715876f}, {-0.88498764f, -0.46561452f},
{-0.89100652f, -0.45399050f}, {-0.89687274f, -0.44228869f},
{-0.90258528f, -0.43051110f}, {-0.90814317f, -0.41865974f},
{-0.91354546f, -0.40673664f}, {-0.91879121f, -0.39474386f},
{-0.92387953f, -0.38268343f}, {-0.92880955f, -0.37055744f},
{-0.93358043f, -0.35836795f}, {-0.93819134f, -0.34611706f},
{-0.94264149f, -0.33380686f}, {-0.94693013f, -0.32143947f},
{-0.95105652f, -0.30901699f}, {-0.95501994f, -0.29654157f},
{-0.95881973f, -0.28401534f}, {-0.96245524f, -0.27144045f},
{-0.96592583f, -0.25881905f}, {-0.96923091f, -0.24615329f},
{-0.97236992f, -0.23344536f}, {-0.97534232f, -0.22069744f},
{-0.97814760f, -0.20791169f}, {-0.98078528f, -0.19509032f},
{-0.98325491f, -0.18223553f}, {-0.98555606f, -0.16934950f},
{-0.98768834f, -0.15643447f}, {-0.98965139f, -0.14349262f},
{-0.99144486f, -0.13052619f}, {-0.99306846f, -0.11753740f},
{-0.99452190f, -0.10452846f}, {-0.99580493f, -0.091501619f},
{-0.99691733f, -0.078459096f}, {-0.99785892f, -0.065403129f},
{-0.99862953f, -0.052335956f}, {-0.99922904f, -0.039259816f},
{-0.99965732f, -0.026176948f}, {-0.99991433f, -0.013089596f},
{-1.0000000f, -1.2246064e-16f}, {-0.99991433f, 0.013089596f},
{-0.99965732f, 0.026176948f}, {-0.99922904f, 0.039259816f},
{-0.99862953f, 0.052335956f}, {-0.99785892f, 0.065403129f},
{-0.99691733f, 0.078459096f}, {-0.99580493f, 0.091501619f},
{-0.99452190f, 0.10452846f}, {-0.99306846f, 0.11753740f},
{-0.99144486f, 0.13052619f}, {-0.98965139f, 0.14349262f},
{-0.98768834f, 0.15643447f}, {-0.98555606f, 0.16934950f},
{-0.98325491f, 0.18223553f}, {-0.98078528f, 0.19509032f},
{-0.97814760f, 0.20791169f}, {-0.97534232f, 0.22069744f},
{-0.97236992f, 0.23344536f}, {-0.96923091f, 0.24615329f},
{-0.96592583f, 0.25881905f}, {-0.96245524f, 0.27144045f},
{-0.95881973f, 0.28401534f}, {-0.95501994f, 0.29654157f},
{-0.95105652f, 0.30901699f}, {-0.94693013f, 0.32143947f},
{-0.94264149f, 0.33380686f}, {-0.93819134f, 0.34611706f},
{-0.93358043f, 0.35836795f}, {-0.92880955f, 0.37055744f},
{-0.92387953f, 0.38268343f}, {-0.91879121f, 0.39474386f},
{-0.91354546f, 0.40673664f}, {-0.90814317f, 0.41865974f},
{-0.90258528f, 0.43051110f}, {-0.89687274f, 0.44228869f},
{-0.89100652f, 0.45399050f}, {-0.88498764f, 0.46561452f},
{-0.87881711f, 0.47715876f}, {-0.87249601f, 0.48862124f},
{-0.86602540f, 0.50000000f}, {-0.85940641f, 0.51129309f},
{-0.85264016f, 0.52249856f}, {-0.84572782f, 0.53361452f},
{-0.83867057f, 0.54463904f}, {-0.83146961f, 0.55557023f},
{-0.82412619f, 0.56640624f}, {-0.81664156f, 0.57714519f},
{-0.80901699f, 0.58778525f}, {-0.80125381f, 0.59832460f},
{-0.79335334f, 0.60876143f}, {-0.78531693f, 0.61909395f},
{-0.77714596f, 0.62932039f}, {-0.76884183f, 0.63943900f},
{-0.76040597f, 0.64944805f}, {-0.75183981f, 0.65934582f},
{-0.74314483f, 0.66913061f}, {-0.73432251f, 0.67880075f},
{-0.72537437f, 0.68835458f}, {-0.71630194f, 0.69779046f},
{-0.70710678f, 0.70710678f}, {-0.69779046f, 0.71630194f},
{-0.68835458f, 0.72537437f}, {-0.67880075f, 0.73432251f},
{-0.66913061f, 0.74314483f}, {-0.65934582f, 0.75183981f},
{-0.64944805f, 0.76040597f}, {-0.63943900f, 0.76884183f},
{-0.62932039f, 0.77714596f}, {-0.61909395f, 0.78531693f},
{-0.60876143f, 0.79335334f}, {-0.59832460f, 0.80125381f},
{-0.58778525f, 0.80901699f}, {-0.57714519f, 0.81664156f},
{-0.56640624f, 0.82412619f}, {-0.55557023f, 0.83146961f},
{-0.54463904f, 0.83867057f}, {-0.53361452f, 0.84572782f},
{-0.52249856f, 0.85264016f}, {-0.51129309f, 0.85940641f},
{-0.50000000f, 0.86602540f}, {-0.48862124f, 0.87249601f},
{-0.47715876f, 0.87881711f}, {-0.46561452f, 0.88498764f},
{-0.45399050f, 0.89100652f}, {-0.44228869f, 0.89687274f},
{-0.43051110f, 0.90258528f}, {-0.41865974f, 0.90814317f},
{-0.40673664f, 0.91354546f}, {-0.39474386f, 0.91879121f},
{-0.38268343f, 0.92387953f}, {-0.37055744f, 0.92880955f},
{-0.35836795f, 0.93358043f}, {-0.34611706f, 0.93819134f},
{-0.33380686f, 0.94264149f}, {-0.32143947f, 0.94693013f},
{-0.30901699f, 0.95105652f}, {-0.29654157f, 0.95501994f},
{-0.28401534f, 0.95881973f}, {-0.27144045f, 0.96245524f},
{-0.25881905f, 0.96592583f}, {-0.24615329f, 0.96923091f},
{-0.23344536f, 0.97236992f}, {-0.22069744f, 0.97534232f},
{-0.20791169f, 0.97814760f}, {-0.19509032f, 0.98078528f},
{-0.18223553f, 0.98325491f}, {-0.16934950f, 0.98555606f},
{-0.15643447f, 0.98768834f}, {-0.14349262f, 0.98965139f},
{-0.13052619f, 0.99144486f}, {-0.11753740f, 0.99306846f},
{-0.10452846f, 0.99452190f}, {-0.091501619f, 0.99580493f},
{-0.078459096f, 0.99691733f}, {-0.065403129f, 0.99785892f},
{-0.052335956f, 0.99862953f}, {-0.039259816f, 0.99922904f},
{-0.026176948f, 0.99965732f}, {-0.013089596f, 0.99991433f},
{-1.8369095e-16f, 1.0000000f}, {0.013089596f, 0.99991433f},
{0.026176948f, 0.99965732f}, {0.039259816f, 0.99922904f},
{0.052335956f, 0.99862953f}, {0.065403129f, 0.99785892f},
{0.078459096f, 0.99691733f}, {0.091501619f, 0.99580493f},
{0.10452846f, 0.99452190f}, {0.11753740f, 0.99306846f},
{0.13052619f, 0.99144486f}, {0.14349262f, 0.98965139f},
{0.15643447f, 0.98768834f}, {0.16934950f, 0.98555606f},
{0.18223553f, 0.98325491f}, {0.19509032f, 0.98078528f},
{0.20791169f, 0.97814760f}, {0.22069744f, 0.97534232f},
{0.23344536f, 0.97236992f}, {0.24615329f, 0.96923091f},
{0.25881905f, 0.96592583f}, {0.27144045f, 0.96245524f},
{0.28401534f, 0.95881973f}, {0.29654157f, 0.95501994f},
{0.30901699f, 0.95105652f}, {0.32143947f, 0.94693013f},
{0.33380686f, 0.94264149f}, {0.34611706f, 0.93819134f},
{0.35836795f, 0.93358043f}, {0.37055744f, 0.92880955f},
{0.38268343f, 0.92387953f}, {0.39474386f, 0.91879121f},
{0.40673664f, 0.91354546f}, {0.41865974f, 0.90814317f},
{0.43051110f, 0.90258528f}, {0.44228869f, 0.89687274f},
{0.45399050f, 0.89100652f}, {0.46561452f, 0.88498764f},
{0.47715876f, 0.87881711f}, {0.48862124f, 0.87249601f},
{0.50000000f, 0.86602540f}, {0.51129309f, 0.85940641f},
{0.52249856f, 0.85264016f}, {0.53361452f, 0.84572782f},
{0.54463904f, 0.83867057f}, {0.55557023f, 0.83146961f},
{0.56640624f, 0.82412619f}, {0.57714519f, 0.81664156f},
{0.58778525f, 0.80901699f}, {0.59832460f, 0.80125381f},
{0.60876143f, 0.79335334f}, {0.61909395f, 0.78531693f},
{0.62932039f, 0.77714596f}, {0.63943900f, 0.76884183f},
{0.64944805f, 0.76040597f}, {0.65934582f, 0.75183981f},
{0.66913061f, 0.74314483f}, {0.67880075f, 0.73432251f},
{0.68835458f, 0.72537437f}, {0.69779046f, 0.71630194f},
{0.70710678f, 0.70710678f}, {0.71630194f, 0.69779046f},
{0.72537437f, 0.68835458f}, {0.73432251f, 0.67880075f},
{0.74314483f, 0.66913061f}, {0.75183981f, 0.65934582f},
{0.76040597f, 0.64944805f}, {0.76884183f, 0.63943900f},
{0.77714596f, 0.62932039f}, {0.78531693f, 0.61909395f},
{0.79335334f, 0.60876143f}, {0.80125381f, 0.59832460f},
{0.80901699f, 0.58778525f}, {0.81664156f, 0.57714519f},
{0.82412619f, 0.56640624f}, {0.83146961f, 0.55557023f},
{0.83867057f, 0.54463904f}, {0.84572782f, 0.53361452f},
{0.85264016f, 0.52249856f}, {0.85940641f, 0.51129309f},
{0.86602540f, 0.50000000f}, {0.87249601f, 0.48862124f},
{0.87881711f, 0.47715876f}, {0.88498764f, 0.46561452f},
{0.89100652f, 0.45399050f}, {0.89687274f, 0.44228869f},
{0.90258528f, 0.43051110f}, {0.90814317f, 0.41865974f},
{0.91354546f, 0.40673664f}, {0.91879121f, 0.39474386f},
{0.92387953f, 0.38268343f}, {0.92880955f, 0.37055744f},
{0.93358043f, 0.35836795f}, {0.93819134f, 0.34611706f},
{0.94264149f, 0.33380686f}, {0.94693013f, 0.32143947f},
{0.95105652f, 0.30901699f}, {0.95501994f, 0.29654157f},
{0.95881973f, 0.28401534f}, {0.96245524f, 0.27144045f},
{0.96592583f, 0.25881905f}, {0.96923091f, 0.24615329f},
{0.97236992f, 0.23344536f}, {0.97534232f, 0.22069744f},
{0.97814760f, 0.20791169f}, {0.98078528f, 0.19509032f},
{0.98325491f, 0.18223553f}, {0.98555606f, 0.16934950f},
{0.98768834f, 0.15643447f}, {0.98965139f, 0.14349262f},
{0.99144486f, 0.13052619f}, {0.99306846f, 0.11753740f},
{0.99452190f, 0.10452846f}, {0.99580493f, 0.091501619f},
{0.99691733f, 0.078459096f}, {0.99785892f, 0.065403129f},
{0.99862953f, 0.052335956f}, {0.99922904f, 0.039259816f},
{0.99965732f, 0.026176948f}, {0.99991433f, 0.013089596f},
};
#ifndef FFT_BITREV480
#define FFT_BITREV480
static const opus_int16 fft_bitrev480[480] = {
0, 120, 240, 360, 30, 150, 270, 390, 60, 180, 300, 420, 90, 210, 330,
450, 15, 135, 255, 375, 45, 165, 285, 405, 75, 195, 315, 435, 105, 225,
345, 465, 5, 125, 245, 365, 35, 155, 275, 395, 65, 185, 305, 425, 95,
215, 335, 455, 20, 140, 260, 380, 50, 170, 290, 410, 80, 200, 320, 440,
110, 230, 350, 470, 10, 130, 250, 370, 40, 160, 280, 400, 70, 190, 310,
430, 100, 220, 340, 460, 25, 145, 265, 385, 55, 175, 295, 415, 85, 205,
325, 445, 115, 235, 355, 475, 1, 121, 241, 361, 31, 151, 271, 391, 61,
181, 301, 421, 91, 211, 331, 451, 16, 136, 256, 376, 46, 166, 286, 406,
76, 196, 316, 436, 106, 226, 346, 466, 6, 126, 246, 366, 36, 156, 276,
396, 66, 186, 306, 426, 96, 216, 336, 456, 21, 141, 261, 381, 51, 171,
291, 411, 81, 201, 321, 441, 111, 231, 351, 471, 11, 131, 251, 371, 41,
161, 281, 401, 71, 191, 311, 431, 101, 221, 341, 461, 26, 146, 266, 386,
56, 176, 296, 416, 86, 206, 326, 446, 116, 236, 356, 476, 2, 122, 242,
362, 32, 152, 272, 392, 62, 182, 302, 422, 92, 212, 332, 452, 17, 137,
257, 377, 47, 167, 287, 407, 77, 197, 317, 437, 107, 227, 347, 467, 7,
127, 247, 367, 37, 157, 277, 397, 67, 187, 307, 427, 97, 217, 337, 457,
22, 142, 262, 382, 52, 172, 292, 412, 82, 202, 322, 442, 112, 232, 352,
472, 12, 132, 252, 372, 42, 162, 282, 402, 72, 192, 312, 432, 102, 222,
342, 462, 27, 147, 267, 387, 57, 177, 297, 417, 87, 207, 327, 447, 117,
237, 357, 477, 3, 123, 243, 363, 33, 153, 273, 393, 63, 183, 303, 423,
93, 213, 333, 453, 18, 138, 258, 378, 48, 168, 288, 408, 78, 198, 318,
438, 108, 228, 348, 468, 8, 128, 248, 368, 38, 158, 278, 398, 68, 188,
308, 428, 98, 218, 338, 458, 23, 143, 263, 383, 53, 173, 293, 413, 83,
203, 323, 443, 113, 233, 353, 473, 13, 133, 253, 373, 43, 163, 283, 403,
73, 193, 313, 433, 103, 223, 343, 463, 28, 148, 268, 388, 58, 178, 298,
418, 88, 208, 328, 448, 118, 238, 358, 478, 4, 124, 244, 364, 34, 154,
274, 394, 64, 184, 304, 424, 94, 214, 334, 454, 19, 139, 259, 379, 49,
169, 289, 409, 79, 199, 319, 439, 109, 229, 349, 469, 9, 129, 249, 369,
39, 159, 279, 399, 69, 189, 309, 429, 99, 219, 339, 459, 24, 144, 264,
384, 54, 174, 294, 414, 84, 204, 324, 444, 114, 234, 354, 474, 14, 134,
254, 374, 44, 164, 284, 404, 74, 194, 314, 434, 104, 224, 344, 464, 29,
149, 269, 389, 59, 179, 299, 419, 89, 209, 329, 449, 119, 239, 359, 479,
};
#endif
#ifndef FFT_BITREV240
#define FFT_BITREV240
static const opus_int16 fft_bitrev240[240] = {
0, 60, 120, 180, 15, 75, 135, 195, 30, 90, 150, 210, 45, 105, 165,
225, 5, 65, 125, 185, 20, 80, 140, 200, 35, 95, 155, 215, 50, 110,
170, 230, 10, 70, 130, 190, 25, 85, 145, 205, 40, 100, 160, 220, 55,
115, 175, 235, 1, 61, 121, 181, 16, 76, 136, 196, 31, 91, 151, 211,
46, 106, 166, 226, 6, 66, 126, 186, 21, 81, 141, 201, 36, 96, 156,
216, 51, 111, 171, 231, 11, 71, 131, 191, 26, 86, 146, 206, 41, 101,
161, 221, 56, 116, 176, 236, 2, 62, 122, 182, 17, 77, 137, 197, 32,
92, 152, 212, 47, 107, 167, 227, 7, 67, 127, 187, 22, 82, 142, 202,
37, 97, 157, 217, 52, 112, 172, 232, 12, 72, 132, 192, 27, 87, 147,
207, 42, 102, 162, 222, 57, 117, 177, 237, 3, 63, 123, 183, 18, 78,
138, 198, 33, 93, 153, 213, 48, 108, 168, 228, 8, 68, 128, 188, 23,
83, 143, 203, 38, 98, 158, 218, 53, 113, 173, 233, 13, 73, 133, 193,
28, 88, 148, 208, 43, 103, 163, 223, 58, 118, 178, 238, 4, 64, 124,
184, 19, 79, 139, 199, 34, 94, 154, 214, 49, 109, 169, 229, 9, 69,
129, 189, 24, 84, 144, 204, 39, 99, 159, 219, 54, 114, 174, 234, 14,
74, 134, 194, 29, 89, 149, 209, 44, 104, 164, 224, 59, 119, 179, 239,
};
#endif
#ifndef FFT_BITREV120
#define FFT_BITREV120
static const opus_int16 fft_bitrev120[120] = {
0, 30, 60, 90, 15, 45, 75, 105, 5, 35, 65, 95, 20, 50, 80,
110, 10, 40, 70, 100, 25, 55, 85, 115, 1, 31, 61, 91, 16, 46,
76, 106, 6, 36, 66, 96, 21, 51, 81, 111, 11, 41, 71, 101, 26,
56, 86, 116, 2, 32, 62, 92, 17, 47, 77, 107, 7, 37, 67, 97,
22, 52, 82, 112, 12, 42, 72, 102, 27, 57, 87, 117, 3, 33, 63,
93, 18, 48, 78, 108, 8, 38, 68, 98, 23, 53, 83, 113, 13, 43,
73, 103, 28, 58, 88, 118, 4, 34, 64, 94, 19, 49, 79, 109, 9,
39, 69, 99, 24, 54, 84, 114, 14, 44, 74, 104, 29, 59, 89, 119,
};
#endif
#ifndef FFT_BITREV60
#define FFT_BITREV60
static const opus_int16 fft_bitrev60[60] = {
0, 15, 30, 45, 5, 20, 35, 50, 10, 25, 40, 55, 1, 16, 31,
46, 6, 21, 36, 51, 11, 26, 41, 56, 2, 17, 32, 47, 7, 22,
37, 52, 12, 27, 42, 57, 3, 18, 33, 48, 8, 23, 38, 53, 13,
28, 43, 58, 4, 19, 34, 49, 9, 24, 39, 54, 14, 29, 44, 59,
};
#endif
#ifndef FFT_STATE48000_960_0
#define FFT_STATE48000_960_0
static const kiss_fft_state fft_state48000_960_0 = {
480,
0.002083333f,
-1,
{4, 120, 4, 30, 2, 15, 3, 5, 5, 1, 0, 0, 0, 0, 0, 0, },
fft_bitrev480,
fft_twiddles48000_960,
};
#endif
#ifndef FFT_STATE48000_960_1
#define FFT_STATE48000_960_1
static const kiss_fft_state fft_state48000_960_1 = {
240,
0.004166667f,
1,
{4, 60, 4, 15, 3, 5, 5, 1, 0, 0, 0, 0, 0, 0, 0, 0, },
fft_bitrev240,
fft_twiddles48000_960,
};
#endif
#ifndef FFT_STATE48000_960_2
#define FFT_STATE48000_960_2
static const kiss_fft_state fft_state48000_960_2 = {
120,
0.008333333f,
2,
{4, 30, 2, 15, 3, 5, 5, 1, 0, 0, 0, 0, 0, 0, 0, 0, },
fft_bitrev120,
fft_twiddles48000_960,
};
#endif
#ifndef FFT_STATE48000_960_3
#define FFT_STATE48000_960_3
static const kiss_fft_state fft_state48000_960_3 = {
60,
0.016666667f,
3,
{4, 15, 3, 5, 5, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, },
fft_bitrev60,
fft_twiddles48000_960,
};
#endif
#endif
#ifndef MDCT_TWIDDLES960
#define MDCT_TWIDDLES960
static const opus_val16 mdct_twiddles960[481] = {
1.0000000f, 0.99999465f, 0.99997858f, 0.99995181f, 0.99991433f,
0.99986614f, 0.99980724f, 0.99973764f, 0.99965732f, 0.99956631f,
0.99946459f, 0.99935216f, 0.99922904f, 0.99909521f, 0.99895068f,
0.99879546f, 0.99862953f, 0.99845292f, 0.99826561f, 0.99806761f,
0.99785892f, 0.99763955f, 0.99740949f, 0.99716875f, 0.99691733f,
0.99665524f, 0.99638247f, 0.99609903f, 0.99580493f, 0.99550016f,
0.99518473f, 0.99485864f, 0.99452190f, 0.99417450f, 0.99381646f,
0.99344778f, 0.99306846f, 0.99267850f, 0.99227791f, 0.99186670f,
0.99144486f, 0.99101241f, 0.99056934f, 0.99011566f, 0.98965139f,
0.98917651f, 0.98869104f, 0.98819498f, 0.98768834f, 0.98717112f,
0.98664333f, 0.98610497f, 0.98555606f, 0.98499659f, 0.98442657f,
0.98384600f, 0.98325491f, 0.98265328f, 0.98204113f, 0.98141846f,
0.98078528f, 0.98014159f, 0.97948742f, 0.97882275f, 0.97814760f,
0.97746197f, 0.97676588f, 0.97605933f, 0.97534232f, 0.97461487f,
0.97387698f, 0.97312866f, 0.97236992f, 0.97160077f, 0.97082121f,
0.97003125f, 0.96923091f, 0.96842019f, 0.96759909f, 0.96676764f,
0.96592582f, 0.96507367f, 0.96421118f, 0.96333837f, 0.96245523f,
0.96156180f, 0.96065806f, 0.95974403f, 0.95881973f, 0.95788517f,
0.95694034f, 0.95598526f, 0.95501995f, 0.95404440f, 0.95305864f,
0.95206267f, 0.95105651f, 0.95004016f, 0.94901364f, 0.94797697f,
0.94693013f, 0.94587315f, 0.94480604f, 0.94372882f, 0.94264149f,
0.94154406f, 0.94043656f, 0.93931897f, 0.93819133f, 0.93705365f,
0.93590592f, 0.93474818f, 0.93358042f, 0.93240268f, 0.93121493f,
0.93001722f, 0.92880955f, 0.92759193f, 0.92636438f, 0.92512690f,
0.92387953f, 0.92262225f, 0.92135509f, 0.92007809f, 0.91879121f,
0.91749449f, 0.91618795f, 0.91487161f, 0.91354545f, 0.91220952f,
0.91086382f, 0.90950836f, 0.90814316f, 0.90676824f, 0.90538363f,
0.90398929f, 0.90258528f, 0.90117161f, 0.89974828f, 0.89831532f,
0.89687273f, 0.89542055f, 0.89395877f, 0.89248742f, 0.89100652f,
0.88951606f, 0.88801610f, 0.88650661f, 0.88498764f, 0.88345918f,
0.88192125f, 0.88037390f, 0.87881711f, 0.87725090f, 0.87567531f,
0.87409035f, 0.87249599f, 0.87089232f, 0.86927933f, 0.86765699f,
0.86602540f, 0.86438453f, 0.86273437f, 0.86107503f, 0.85940641f,
0.85772862f, 0.85604161f, 0.85434547f, 0.85264014f, 0.85092572f,
0.84920218f, 0.84746955f, 0.84572781f, 0.84397704f, 0.84221721f,
0.84044838f, 0.83867056f, 0.83688375f, 0.83508799f, 0.83328325f,
0.83146961f, 0.82964704f, 0.82781562f, 0.82597530f, 0.82412620f,
0.82226820f, 0.82040144f, 0.81852589f, 0.81664154f, 0.81474847f,
0.81284665f, 0.81093620f, 0.80901698f, 0.80708914f, 0.80515262f,
0.80320752f, 0.80125378f, 0.79929149f, 0.79732067f, 0.79534125f,
0.79335335f, 0.79135691f, 0.78935204f, 0.78733867f, 0.78531691f,
0.78328674f, 0.78124818f, 0.77920122f, 0.77714595f, 0.77508232f,
0.77301043f, 0.77093026f, 0.76884183f, 0.76674517f, 0.76464026f,
0.76252720f, 0.76040593f, 0.75827656f, 0.75613907f, 0.75399349f,
0.75183978f, 0.74967807f, 0.74750833f, 0.74533054f, 0.74314481f,
0.74095112f, 0.73874950f, 0.73653993f, 0.73432251f, 0.73209718f,
0.72986405f, 0.72762307f, 0.72537438f, 0.72311787f, 0.72085359f,
0.71858162f, 0.71630192f, 0.71401459f, 0.71171956f, 0.70941701f,
0.70710677f, 0.70478900f, 0.70246363f, 0.70013079f, 0.69779041f,
0.69544260f, 0.69308738f, 0.69072466f, 0.68835458f, 0.68597709f,
0.68359229f, 0.68120013f, 0.67880072f, 0.67639404f, 0.67398011f,
0.67155892f, 0.66913059f, 0.66669509f, 0.66425240f, 0.66180265f,
0.65934581f, 0.65688191f, 0.65441092f, 0.65193298f, 0.64944801f,
0.64695613f, 0.64445727f, 0.64195160f, 0.63943902f, 0.63691954f,
0.63439328f, 0.63186019f, 0.62932037f, 0.62677377f, 0.62422055f,
0.62166055f, 0.61909394f, 0.61652065f, 0.61394081f, 0.61135435f,
0.60876139f, 0.60616195f, 0.60355593f, 0.60094349f, 0.59832457f,
0.59569929f, 0.59306758f, 0.59042957f, 0.58778523f, 0.58513460f,
0.58247766f, 0.57981452f, 0.57714518f, 0.57446961f, 0.57178793f,
0.56910013f, 0.56640624f, 0.56370623f, 0.56100023f, 0.55828818f,
0.55557020f, 0.55284627f, 0.55011641f, 0.54738067f, 0.54463901f,
0.54189157f, 0.53913828f, 0.53637921f, 0.53361450f, 0.53084398f,
0.52806787f, 0.52528601f, 0.52249852f, 0.51970543f, 0.51690688f,
0.51410279f, 0.51129310f, 0.50847793f, 0.50565732f, 0.50283139f,
0.49999997f, 0.49716321f, 0.49432122f, 0.49147383f, 0.48862118f,
0.48576340f, 0.48290042f, 0.48003216f, 0.47715876f, 0.47428025f,
0.47139677f, 0.46850813f, 0.46561448f, 0.46271584f, 0.45981235f,
0.45690383f, 0.45399042f, 0.45107214f, 0.44814915f, 0.44522124f,
0.44228868f, 0.43935137f, 0.43640926f, 0.43346247f, 0.43051104f,
0.42755511f, 0.42459449f, 0.42162932f, 0.41865964f, 0.41568558f,
0.41270697f, 0.40972393f, 0.40673661f, 0.40374494f, 0.40074884f,
0.39774844f, 0.39474390f, 0.39173501f, 0.38872193f, 0.38570469f,
0.38268343f, 0.37965796f, 0.37662842f, 0.37359496f, 0.37055739f,
0.36751585f, 0.36447038f, 0.36142122f, 0.35836797f, 0.35531089f,
0.35225000f, 0.34918544f, 0.34611704f, 0.34304493f, 0.33996926f,
0.33688983f, 0.33380680f, 0.33072019f, 0.32763015f, 0.32453650f,
0.32143936f, 0.31833890f, 0.31523503f, 0.31212767f, 0.30901696f,
0.30590306f, 0.30278577f, 0.29966524f, 0.29654150f, 0.29341470f,
0.29028464f, 0.28715147f, 0.28401522f, 0.28087605f, 0.27773376f,
0.27458861f, 0.27144052f, 0.26828940f, 0.26513541f, 0.26197859f,
0.25881907f, 0.25565666f, 0.25249152f, 0.24932367f, 0.24615327f,
0.24298012f, 0.23980436f, 0.23662604f, 0.23344530f, 0.23026206f,
0.22707623f, 0.22388809f, 0.22069744f, 0.21750443f, 0.21430908f,
0.21111156f, 0.20791165f, 0.20470953f, 0.20150520f, 0.19829884f,
0.19509024f, 0.19187955f, 0.18866692f, 0.18545227f, 0.18223552f,
0.17901681f, 0.17579631f, 0.17257380f, 0.16934945f, 0.16612328f,
0.16289546f, 0.15966577f, 0.15643437f, 0.15320141f, 0.14996669f,
0.14673037f, 0.14349260f, 0.14025329f, 0.13701235f, 0.13376995f,
0.13052612f, 0.12728101f, 0.12403442f, 0.12078650f, 0.11753740f,
0.11428693f, 0.11103523f, 0.10778234f, 0.10452842f, 0.10127326f,
0.098017137f, 0.094759842f, 0.091501652f, 0.088242363f, 0.084982129f,
0.081721103f, 0.078459084f, 0.075196224f, 0.071932560f, 0.068668243f,
0.065403073f, 0.062137201f, 0.058870665f, 0.055603617f, 0.052335974f,
0.049067651f, 0.045798921f, 0.042529582f, 0.039259788f, 0.035989573f,
0.032719092f, 0.029448142f, 0.026176876f, 0.022905329f, 0.019633657f,
0.016361655f, 0.013089478f, 0.0098171604f, 0.0065449764f, 0.0032724839f,
-4.3711390e-08f, };
#endif
static const CELTMode mode48000_960_120 = {
48000,
120,
21,
21,
{0.85000610f, 0.0000000f, 1.0000000f, 1.0000000f, },
eband5ms,
3,
8,
120,
11,
band_allocation,
logN400,
window120,
{1920, 3, {&fft_state48000_960_0, &fft_state48000_960_1, &fft_state48000_960_2, &fft_state48000_960_3, }, mdct_twiddles960},
{392, cache_index50, cache_bits50, cache_caps50},
};
#define TOTAL_MODES 1
static const CELTMode * const static_mode_list[TOTAL_MODES] = {
&mode48000_960_120,
};

CELTMode *opus_custom_mode_create(opus_int32 Fs, int frame_size, int *error)
{
   int i;
   for (i=0;i<TOTAL_MODES;i++)
   {
      int j;
      for (j=0;j<4;j++)
      {
         if (Fs == static_mode_list[i]->Fs &&
               (frame_size<<j) == static_mode_list[i]->shortMdctSize*static_mode_list[i]->nbShortMdcts)
         {
            if (error)
               *error = OPUS_OK;
            return (CELTMode*)static_mode_list[i];
         }
      }
   }
   if (error)
      *error = OPUS_BAD_ARG;
   return NULL;
}

static void find_best_pitch(opus_val32 *xcorr, opus_val16 *y, int len,
                            int max_pitch, int *best_pitch
                            )
{
   int i, j;
   opus_val32 Syy=1;
   opus_val16 best_num[2];
   opus_val32 best_den[2];
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
   ac[0] *= 1.0001f;
   for (i=1;i<=4;i++)
   {
      ac[i] -= ac[i]*(.008f*i)*(.008f*i);
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
   int offset;
   SAVE_STACK;
   celt_assert(len>0);
   celt_assert(max_pitch>0);
   lag = len+max_pitch;
   ALLOC(x_lp4, len>>2, opus_val16);
   ALLOC(y_lp4, lag>>2, opus_val16);
   ALLOC(xcorr, max_pitch>>1, opus_val32);
   for (j=0;j<len>>2;j++)
      x_lp4[j] = x_lp[2*j];
   for (j=0;j<lag>>2;j++)
      y_lp4[j] = y[2*j];
   for (i=0;i<max_pitch>>2;i++)
   {
      opus_val32 sum = 0;
      for (j=0;j<len>>2;j++)
         sum = MAC16_16(sum, x_lp4[j],y_lp4[i+j]);
      xcorr[i] = MAX32(-1, sum);
   }
   find_best_pitch(xcorr, y_lp4, len>>2, max_pitch>>2, best_pitch
                   );
   for (i=0;i<max_pitch>>1;i++)
   {
      opus_val32 sum=0;
      xcorr[i] = 0;
      if (abs(i-2*best_pitch[0])>2 && abs(i-2*best_pitch[1])>2)
         continue;
      for (j=0;j<len>>1;j++)
         sum += SHR32(MULT16_16(x_lp[j],y[i+j]), shift);
      xcorr[i] = MAX32(-1, sum);
   }
   find_best_pitch(xcorr, y, len>>1, max_pitch>>1, best_pitch
                   );
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

static const opus_val16 eMeans[25] = {
      6.437500f, 6.250000f, 5.750000f, 5.312500f, 5.062500f,
      4.812500f, 4.500000f, 4.375000f, 4.875000f, 4.687500f,
      4.562500f, 4.437500f, 4.875000f, 4.625000f, 4.312500f,
      4.500000f, 4.375000f, 4.625000f, 4.750000f, 4.437500f,
      3.750000f, 3.750000f, 3.750000f, 3.750000f, 3.750000f
};
static const opus_val16 pred_coef[4] = {29440/32768., 26112/32768., 21248/32768., 16384/32768.};
static const opus_val16 beta_coef[4] = {30147/32768., 22282/32768., 12124/32768., 6554/32768.};
static const opus_val16 beta_intra = 4915/32768.;
static const unsigned char e_prob_model[4][2][42] = {
   {
      {
          72, 127,  65, 129,  66, 128,  65, 128,  64, 128,  62, 128,  64, 128,
          64, 128,  92,  78,  92,  79,  92,  78,  90,  79, 116,  41, 115,  40,
         114,  40, 132,  26, 132,  26, 145,  17, 161,  12, 176,  10, 177,  11
      },
      {
          24, 179,  48, 138,  54, 135,  54, 132,  53, 134,  56, 133,  55, 132,
          55, 132,  61, 114,  70,  96,  74,  88,  75,  88,  87,  74,  89,  66,
          91,  67, 100,  59, 108,  50, 120,  40, 122,  37,  97,  43,  78,  50
      }
   },
   {
      {
          83,  78,  84,  81,  88,  75,  86,  74,  87,  71,  90,  73,  93,  74,
          93,  74, 109,  40, 114,  36, 117,  34, 117,  34, 143,  17, 145,  18,
         146,  19, 162,  12, 165,  10, 178,   7, 189,   6, 190,   8, 177,   9
      },
      {
          23, 178,  54, 115,  63, 102,  66,  98,  69,  99,  74,  89,  71,  91,
          73,  91,  78,  89,  86,  80,  92,  66,  93,  64, 102,  59, 103,  60,
         104,  60, 117,  52, 123,  44, 138,  35, 133,  31,  97,  38,  77,  45
      }
   },
   {
      {
          61,  90,  93,  60, 105,  42, 107,  41, 110,  45, 116,  38, 113,  38,
         112,  38, 124,  26, 132,  27, 136,  19, 140,  20, 155,  14, 159,  16,
         158,  18, 170,  13, 177,  10, 187,   8, 192,   6, 175,   9, 159,  10
      },
      {
          21, 178,  59, 110,  71,  86,  75,  85,  84,  83,  91,  66,  88,  73,
          87,  72,  92,  75,  98,  72, 105,  58, 107,  54, 115,  52, 114,  55,
         112,  56, 129,  51, 132,  40, 150,  33, 140,  29,  98,  35,  77,  42
      }
   },
   {
      {
          42, 121,  96,  66, 108,  43, 111,  40, 117,  44, 123,  32, 120,  36,
         119,  33, 127,  33, 134,  34, 139,  21, 147,  23, 152,  20, 158,  25,
         154,  26, 166,  21, 173,  16, 184,  13, 184,  10, 150,  13, 139,  15
      },
      {
          22, 178,  63, 114,  74,  82,  84,  83,  92,  82, 103,  62,  96,  72,
          96,  67, 101,  73, 107,  72, 113,  55, 118,  52, 125,  52, 118,  52,
         117,  55, 135,  49, 137,  39, 157,  32, 145,  29,  97,  33,  77,  40
      }
   }
};
static const unsigned char small_energy_icdf[3]={2,1,0};
void unquant_coarse_energy(const CELTMode *m, int start, int end, opus_val16 *oldEBands, int intra, ec_dec *dec, int C, int LM)
{
   const unsigned char *prob_model = e_prob_model[LM][intra];
   int i, c;
   opus_val32 prev[2] = {0, 0};
   opus_val16 coef;
   opus_val16 beta;
   opus_int32 budget;
   opus_int32 tell;
   if (intra)
   {
      coef = 0;
      beta = beta_intra;
   } else {
      beta = beta_coef[LM];
      coef = pred_coef[LM];
   }
   budget = dec->storage*8;
   for (i=start;i<end;i++)
   {
      c=0;
      do {
         int qi;
         opus_val32 q;
         opus_val32 tmp;
         celt_assert(c<2);
         tell = ec_tell(dec);
         if(budget-tell>=15)
         {
            int pi;
            pi = 2*IMIN(i,20);
            qi = ec_laplace_decode(dec,
                  prob_model[pi]<<7, prob_model[pi+1]<<6);
         }
         else if(budget-tell>=2)
         {
            qi = ec_dec_icdf(dec, small_energy_icdf, 2);
            qi = (qi>>1)^-(qi&1);
         }
         else if(budget-tell>=1)
         {
            qi = -ec_dec_bit_logp(dec, 1);
         }
         else
            qi = -1;
         q = (opus_val32)SHL32(EXTEND32(qi),DB_SHIFT);
         oldEBands[i+c*m->nbEBands] = MAX16(-QCONST16(9.f,DB_SHIFT), oldEBands[i+c*m->nbEBands]);
         tmp = PSHR32(MULT16_16(coef,oldEBands[i+c*m->nbEBands]),8) + prev[c] + SHL32(q,7);
         oldEBands[i+c*m->nbEBands] = PSHR32(tmp, 7);
         prev[c] = prev[c] + SHL32(q,7) - MULT16_16(beta,PSHR32(q,8));
      } while (++c < C);
   }
}
void unquant_fine_energy(const CELTMode *m, int start, int end, opus_val16 *oldEBands, int *fine_quant, ec_dec *dec, int C)
{
   int i, c;
   for (i=start;i<end;i++)
   {
      if (fine_quant[i] <= 0)
         continue;
      c=0;
      do {
         int q2;
         opus_val16 offset;
         q2 = ec_dec_bits(dec, fine_quant[i]);
         offset = (q2+.5f)*(1<<(14-fine_quant[i]))*(1.f/16384) - .5f;
         oldEBands[i+c*m->nbEBands] += offset;
      } while (++c < C);
   }
}
void unquant_energy_finalise(const CELTMode *m, int start, int end, opus_val16 *oldEBands, int *fine_quant,  int *fine_priority, int bits_left, ec_dec *dec, int C)
{
   int i, prio, c;
   for (prio=0;prio<2;prio++)
   {
      for (i=start;i<end && bits_left>=C ;i++)
      {
         if (fine_quant[i] >= MAX_FINE_BITS || fine_priority[i]!=prio)
            continue;
         c=0;
         do {
            int q2;
            opus_val16 offset;
            q2 = ec_dec_bits(dec, 1);
            offset = (q2-.5f)*(1<<(14-fine_quant[i]-1))*(1.f/16384);
            oldEBands[i+c*m->nbEBands] += offset;
            bits_left--;
         } while (++c < C);
      }
   }
}
void log2Amp(const CELTMode *m, int start, int end,
      celt_ener *eBands, const opus_val16 *oldEBands, int C)
{
   int c, i;
   c=0;
   do {
      for (i=0;i<start;i++)
         eBands[i+c*m->nbEBands] = 0;
      for (;i<end;i++)
      {
         opus_val16 lg = ADD16(oldEBands[i+c*m->nbEBands],
                         SHL16((opus_val16)eMeans[i],6));
         lg = MIN32(QCONST32(32.f, 16), lg);
         eBands[i+c*m->nbEBands] = PSHR32(celt_exp2(lg),4);
      }
      for (;i<m->nbEBands;i++)
         eBands[i+c*m->nbEBands] = 0;
   } while (++c < C);
}

static const unsigned char LOG2_FRAC_TABLE[24]={
   0,
   8,13,
  16,19,21,23,
  24,26,27,28,29,30,31,32,
  32,33,34,34,35,36,36,37,37
};
#define ALLOC_STEPS 6
static inline int interp_bits2pulses(const CELTMode *m, int start, int end, int skip_start,
      const int *bits1, const int *bits2, const int *thresh, const int *cap, opus_int32 total, opus_int32 *_balance,
      int skip_rsv, int *intensity, int intensity_rsv, int *dual_stereo, int dual_stereo_rsv, int *bits,
      int *ebits, int *fine_priority, int C, int LM, ec_ctx *ec, int prev)
{
   opus_int32 psum;
   int lo, hi;
   int i, j;
   int logM;
   int stereo;
   int codedBands=-1;
   int alloc_floor;
   opus_int32 left, percoeff;
   int done;
   int balance;
   SAVE_STACK;
   alloc_floor = C<<BITRES;
   stereo = C>1;
   logM = LM<<BITRES;
   lo = 0;
   hi = 1<<ALLOC_STEPS;
   for (i=0;i<ALLOC_STEPS;i++)
   {
      int mid = (lo+hi)>>1;
      psum = 0;
      done = 0;
      for (j=end;j-->start;)
      {
         int tmp = bits1[j] + (mid*(opus_int32)bits2[j]>>ALLOC_STEPS);
         if (tmp >= thresh[j] || done)
         {
            done = 1;
            psum += IMIN(tmp, cap[j]);
         } else {
            if (tmp >= alloc_floor)
               psum += alloc_floor;
         }
      }
      if (psum > total)
         hi = mid;
      else
         lo = mid;
   }
   psum = 0;
   done = 0;
   for (j=end;j-->start;)
   {
      int tmp = bits1[j] + (lo*bits2[j]>>ALLOC_STEPS);
      if (tmp < thresh[j] && !done)
      {
         if (tmp >= alloc_floor)
            tmp = alloc_floor;
         else
            tmp = 0;
      } else
         done = 1;
      tmp = IMIN(tmp, cap[j]);
      bits[j] = tmp;
      psum += tmp;
   }
   for (codedBands=end;;codedBands--)
   {
      int band_width;
      int band_bits;
      int rem;
      j = codedBands-1;
      if (j<=skip_start)
      {
         total += skip_rsv;
         break;
      }
      left = total-psum;
      percoeff = left/(m->eBands[codedBands]-m->eBands[start]);
      left -= (m->eBands[codedBands]-m->eBands[start])*percoeff;
      rem = IMAX(left-(m->eBands[j]-m->eBands[start]),0);
      band_width = m->eBands[codedBands]-m->eBands[j];
      band_bits = (int)(bits[j] + percoeff*band_width + rem);
      if (band_bits >= IMAX(thresh[j], alloc_floor+(1<<BITRES)))
      {
         if (ec_dec_bit_logp(ec, 1)) {
            break;
         }
         psum += 1<<BITRES;
         band_bits -= 1<<BITRES;
      }
      psum -= bits[j]+intensity_rsv;
      if (intensity_rsv > 0)
         intensity_rsv = LOG2_FRAC_TABLE[j-start];
      psum += intensity_rsv;
      if (band_bits >= alloc_floor)
      {
         psum += alloc_floor;
         bits[j] = alloc_floor;
      } else {
         bits[j] = 0;
      }
   }
   celt_assert(codedBands > start);
   if (intensity_rsv > 0)
   {
      *intensity = start+ec_dec_uint(ec, codedBands+1-start);
   }
   else
      *intensity = 0;
   if (*intensity <= start)
   {
      total += dual_stereo_rsv;
      dual_stereo_rsv = 0;
   }
   if (dual_stereo_rsv > 0)
   {
      *dual_stereo = ec_dec_bit_logp(ec, 1);
   }
   else
      *dual_stereo = 0;
   left = total-psum;
   percoeff = left/(m->eBands[codedBands]-m->eBands[start]);
   left -= (m->eBands[codedBands]-m->eBands[start])*percoeff;
   for (j=start;j<codedBands;j++)
      bits[j] += ((int)percoeff*(m->eBands[j+1]-m->eBands[j]));
   for (j=start;j<codedBands;j++)
   {
      int tmp = (int)IMIN(left, m->eBands[j+1]-m->eBands[j]);
      bits[j] += tmp;
      left -= tmp;
   }
   balance = 0;
   for (j=start;j<codedBands;j++)
   {
      int N0, N, den;
      int offset;
      int NClogN;
      int excess;
      celt_assert(bits[j] >= 0);
      N0 = m->eBands[j+1]-m->eBands[j];
      N=N0<<LM;
      bits[j] += balance;
      if (N>1)
      {
         excess = IMAX(bits[j]-cap[j],0);
         bits[j] -= excess;
         den=(C*N+ ((C==2 && N>2 && !*dual_stereo && j<*intensity) ? 1 : 0));
         NClogN = den*(m->logN[j] + logM);
         offset = (NClogN>>1)-den*FINE_OFFSET;
         if (N==2)
            offset += den<<BITRES>>2;
         if (bits[j] + offset < den*2<<BITRES)
            offset += NClogN>>2;
         else if (bits[j] + offset < den*3<<BITRES)
            offset += NClogN>>3;
         ebits[j] = IMAX(0, (bits[j] + offset + (den<<(BITRES-1))) / (den<<BITRES));
         if (C*ebits[j] > (bits[j]>>BITRES))
            ebits[j] = bits[j] >> stereo >> BITRES;
         ebits[j] = IMIN(ebits[j], MAX_FINE_BITS);
         fine_priority[j] = ebits[j]*(den<<BITRES) >= bits[j]+offset;
         bits[j] -= C*ebits[j]<<BITRES;
      } else {
         excess = IMAX(0,bits[j]-(C<<BITRES));
         bits[j] -= excess;
         ebits[j] = 0;
         fine_priority[j] = 1;
      }
      if(excess > 0)
      {
         int extra_fine;
         int extra_bits;
         extra_fine = IMIN(excess>>(stereo+BITRES),MAX_FINE_BITS-ebits[j]);
         ebits[j] += extra_fine;
         extra_bits = extra_fine*C<<BITRES;
         fine_priority[j] = extra_bits >= excess-balance;
         excess -= extra_bits;
      }
      balance = excess;
      celt_assert(bits[j] >= 0);
      celt_assert(ebits[j] >= 0);
   }
   *_balance = balance;
   for (;j<end;j++)
   {
      ebits[j] = bits[j] >> stereo >> BITRES;
      celt_assert(C*ebits[j]<<BITRES == bits[j]);
      bits[j] = 0;
      fine_priority[j] = ebits[j]<1;
   }
   RESTORE_STACK;
   return codedBands;
}
int compute_allocation(const CELTMode *m, int start, int end, const int *offsets, const int *cap, int alloc_trim, int *intensity, int *dual_stereo,
      opus_int32 total, opus_int32 *balance, int *pulses, int *ebits, int *fine_priority, int C, int LM, ec_ctx *ec, int prev)
{
   int lo, hi, len, j;
   int codedBands;
   int skip_start;
   int skip_rsv;
   int intensity_rsv;
   int dual_stereo_rsv;
   VARDECL(int, bits1);
   VARDECL(int, bits2);
   VARDECL(int, thresh);
   VARDECL(int, trim_offset);
   SAVE_STACK;
   total = IMAX(total, 0);
   len = m->nbEBands;
   skip_start = start;
   skip_rsv = total >= 1<<BITRES ? 1<<BITRES : 0;
   total -= skip_rsv;
   intensity_rsv = dual_stereo_rsv = 0;
   if (C==2)
   {
      intensity_rsv = LOG2_FRAC_TABLE[end-start];
      if (intensity_rsv>total)
         intensity_rsv = 0;
      else
      {
         total -= intensity_rsv;
         dual_stereo_rsv = total>=1<<BITRES ? 1<<BITRES : 0;
         total -= dual_stereo_rsv;
      }
   }
   ALLOC(bits1, len, int);
   ALLOC(bits2, len, int);
   ALLOC(thresh, len, int);
   ALLOC(trim_offset, len, int);
   for (j=start;j<end;j++)
   {
      thresh[j] = IMAX((C)<<BITRES, (3*(m->eBands[j+1]-m->eBands[j])<<LM<<BITRES)>>4);
      trim_offset[j] = C*(m->eBands[j+1]-m->eBands[j])*(alloc_trim-5-LM)*(end-j-1)
            *(1<<(LM+BITRES))>>6;
      if ((m->eBands[j+1]-m->eBands[j])<<LM==1)
         trim_offset[j] -= C<<BITRES;
   }
   lo = 1;
   hi = m->nbAllocVectors - 1;
   do
   {
      int done = 0;
      int psum = 0;
      int mid = (lo+hi) >> 1;
      for (j=end;j-->start;)
      {
         int bitsj;
         int N = m->eBands[j+1]-m->eBands[j];
         bitsj = C*N*m->allocVectors[mid*len+j]<<LM>>2;
         if (bitsj > 0)
            bitsj = IMAX(0, bitsj + trim_offset[j]);
         bitsj += offsets[j];
         if (bitsj >= thresh[j] || done)
         {
            done = 1;
            psum += IMIN(bitsj, cap[j]);
         } else {
            if (bitsj >= C<<BITRES)
               psum += C<<BITRES;
         }
      }
      if (psum > total)
         hi = mid - 1;
      else
         lo = mid + 1;
   }
   while (lo <= hi);
   hi = lo--;
   for (j=start;j<end;j++)
   {
      int bits1j, bits2j;
      int N = m->eBands[j+1]-m->eBands[j];
      bits1j = C*N*m->allocVectors[lo*len+j]<<LM>>2;
      bits2j = hi>=m->nbAllocVectors ?
            cap[j] : C*N*m->allocVectors[hi*len+j]<<LM>>2;
      if (bits1j > 0)
         bits1j = IMAX(0, bits1j + trim_offset[j]);
      if (bits2j > 0)
         bits2j = IMAX(0, bits2j + trim_offset[j]);
      if (lo > 0)
         bits1j += offsets[j];
      bits2j += offsets[j];
      if (offsets[j]>0)
         skip_start = j;
      bits2j = IMAX(0,bits2j-bits1j);
      bits1[j] = bits1j;
      bits2[j] = bits2j;
   }
   codedBands = interp_bits2pulses(m, start, end, skip_start, bits1, bits2, thresh, cap,
         total, balance, skip_rsv, intensity, intensity_rsv, dual_stereo, dual_stereo_rsv,
         pulses, ebits, fine_priority, C, LM, ec, prev);
   RESTORE_STACK;
   return codedBands;
}

static void exp_rotation1(celt_norm *X, int len, int stride, opus_val16 c, opus_val16 s)
{
   int i;
   celt_norm *Xptr;
   Xptr = X;
   for (i=0;i<len-stride;i++)
   {
      celt_norm x1, x2;
      x1 = Xptr[0];
      x2 = Xptr[stride];
      Xptr[stride] = EXTRACT16(SHR32(MULT16_16(c,x2) + MULT16_16(s,x1), 15));
      *Xptr++      = EXTRACT16(SHR32(MULT16_16(c,x1) - MULT16_16(s,x2), 15));
   }
   Xptr = &X[len-2*stride-1];
   for (i=len-2*stride-1;i>=0;i--)
   {
      celt_norm x1, x2;
      x1 = Xptr[0];
      x2 = Xptr[stride];
      Xptr[stride] = EXTRACT16(SHR32(MULT16_16(c,x2) + MULT16_16(s,x1), 15));
      *Xptr--      = EXTRACT16(SHR32(MULT16_16(c,x1) - MULT16_16(s,x2), 15));
   }
}
static void exp_rotation(celt_norm *X, int len, int dir, int stride, int K, int spread)
{
   static const int SPREAD_FACTOR[3]={15,10,5};
   int i;
   opus_val16 c, s;
   opus_val16 gain, theta;
   int stride2=0;
   int factor;
   if (2*K>=len || spread==SPREAD_NONE)
      return;
   factor = SPREAD_FACTOR[spread-1];
   gain = celt_div((opus_val32)MULT16_16(Q15_ONE,len),(opus_val32)(len+factor*K));
   theta = HALF16(MULT16_16_Q15(gain,gain));
   c = celt_cos_norm(EXTEND32(theta));
   s = celt_cos_norm(EXTEND32(SUB16(Q15ONE,theta)));
   if (len>=8*stride)
   {
      stride2 = 1;
      while ((stride2*stride2+stride2)*stride + (stride>>2) < len)
         stride2++;
   }
   len /= stride;
   for (i=0;i<stride;i++)
   {
      if (dir < 0)
      {
         if (stride2)
            exp_rotation1(X+i*len, len, stride2, s, c);
         exp_rotation1(X+i*len, len, 1, c, s);
      } else {
         exp_rotation1(X+i*len, len, 1, c, -s);
         if (stride2)
            exp_rotation1(X+i*len, len, stride2, s, -c);
      }
   }
}
static void normalise_residual(int * restrict iy, celt_norm * restrict X,
      int N, opus_val32 Ryy, opus_val16 gain)
{
   int i;
   opus_val32 t;
   opus_val16 g;
   t = VSHR32(Ryy, 2*(k-7));
   g = MULT16_16_P15(celt_rsqrt_norm(t),gain);
   i=0;
   do
      X[i] = EXTRACT16(PSHR32(MULT16_16(g, iy[i]), k+1));
   while (++i < N);
}
static unsigned extract_collapse_mask(int *iy, int N, int B)
{
   unsigned collapse_mask;
   int N0;
   int i;
   if (B<=1)
      return 1;
   N0 = N/B;
   collapse_mask = 0;
   i=0; do {
      int j;
      j=0; do {
         collapse_mask |= (iy[i*N0+j]!=0)<<i;
      } while (++j<N0);
   } while (++i<B);
   return collapse_mask;
}
unsigned alg_unquant(celt_norm *X, int N, int K, int spread, int B,
      ec_dec *dec, opus_val16 gain)
{
   int i;
   opus_val32 Ryy;
   unsigned collapse_mask;
   VARDECL(int, iy);
   SAVE_STACK;
   celt_assert2(K>0, "alg_unquant() needs at least one pulse");
   celt_assert2(N>1, "alg_unquant() needs at least two dimensions");
   ALLOC(iy, N, int);
   decode_pulses(iy, N, K, dec);
   Ryy = 0;
   i=0;
   do {
      Ryy = MAC16_16(Ryy, iy[i], iy[i]);
   } while (++i < N);
   normalise_residual(iy, X, N, Ryy, gain);
   exp_rotation(X, N, -1, B, K, spread);
   collapse_mask = extract_collapse_mask(iy, N, B);
   RESTORE_STACK;
   return collapse_mask;
}
void renormalise_vector(celt_norm *X, int N, opus_val16 gain)
{
   int i;
   opus_val32 E = EPSILON;
   opus_val16 g;
   opus_val32 t;
   celt_norm *xptr = X;
   for (i=0;i<N;i++)
   {
      E = MAC16_16(E, *xptr, *xptr);
      xptr++;
   }
   t = VSHR32(E, 2*(k-7));
   g = MULT16_16_P15(celt_rsqrt_norm(t),gain);
   xptr = X;
   for (i=0;i<N;i++)
   {
      *xptr = EXTRACT16(PSHR32(MULT16_16(g, *xptr), k+1));
      xptr++;
   }
}

