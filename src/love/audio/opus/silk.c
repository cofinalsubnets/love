// rfc 6716 reference code; see opus/COPYING
#undef MAX_PULSES                      // celt's, before silk's own
#define SILK_MAX_ORDER_LPC            16
#include <float.h>
#define silk_int32_MAX   0x7FFFFFFF
#define silk_int32_MIN   ((opus_int32)0x80000000)
#define silk_int16_MAX   0x7FFF
#define silk_int16_MIN   ((opus_int16)0x8000)
#  define silk_assert(COND)

#define SILK_RESAMPLER_MAX_FIR_ORDER                 36
#define SILK_RESAMPLER_MAX_IIR_ORDER                 6
typedef struct _silk_resampler_state_struct{
    opus_int32       sIIR[ SILK_RESAMPLER_MAX_IIR_ORDER ];
    opus_int32       sFIR[ SILK_RESAMPLER_MAX_FIR_ORDER ];
    opus_int16       delayBuf[ 48 ];
    opus_int         resampler_function;
    opus_int         batchSize;
    opus_int32       invRatio_Q16;
    opus_int         FIR_Order;
    opus_int         FIR_Fracs;
    opus_int         Fs_in_kHz;
    opus_int         Fs_out_kHz;
    opus_int         inputDelay;
    const opus_int16 *Coefs;
} silk_resampler_state_struct;

#define silk_SMULWB(a32, b32)            ((((a32) >> 16) * (opus_int32)((opus_int16)(b32))) + ((((a32) & 0x0000FFFF) * (opus_int32)((opus_int16)(b32))) >> 16))
#define silk_SMLAWB(a32, b32, c32)       ((a32) + ((((b32) >> 16) * (opus_int32)((opus_int16)(c32))) + ((((b32) & 0x0000FFFF) * (opus_int32)((opus_int16)(c32))) >> 16)))
#define silk_SMULBB(a32, b32)            ((opus_int32)((opus_int16)(a32)) * (opus_int32)((opus_int16)(b32)))
#define silk_SMLABB(a32, b32, c32)       ((a32) + ((opus_int32)((opus_int16)(b32))) * (opus_int32)((opus_int16)(c32)))
#define silk_SMULWW(a32, b32)            silk_MLA(silk_SMULWB((a32), (b32)), (a32), silk_RSHIFT_ROUND((b32), 16))
#define silk_SMLAWW(a32, b32, c32)       silk_MLA(silk_SMLAWB((a32), (b32), (c32)), (b32), silk_RSHIFT_ROUND((c32), 16))
#define silk_SUB_SAT32(a, b)             ((((a)-(b)) & 0x80000000) == 0 ?                                        \
                                        (( (a) & ((b)^0x80000000) & 0x80000000) ? silk_int32_MIN : (a)-(b)) :    \
                                        ((((a)^0x80000000) & (b)  & 0x80000000) ? silk_int32_MAX : (a)-(b)) )
static inline opus_int32 silk_CLZ16(opus_int16 in16)
{
    opus_int32 out32 = 0;
    if( in16 == 0 ) {
        return 16;
    }
    if( in16 & 0xFF00 ) {
        if( in16 & 0xF000 ) {
            in16 >>= 12;
        } else {
            out32 += 4;
            in16 >>= 8;
        }
    } else {
        if( in16 & 0xFFF0 ) {
            out32 += 8;
            in16 >>= 4;
        } else {
            out32 += 12;
        }
    }
    if( in16 & 0xC ) {
        if( in16 & 0x8 )
            return out32 + 0;
        else
            return out32 + 1;
    } else {
        if( in16 & 0xE )
            return out32 + 2;
        else
            return out32 + 3;
    }
}
static inline opus_int32 silk_CLZ32(opus_int32 in32)
{
    if( in32 & 0xFFFF0000 ) {
        return silk_CLZ16((opus_int16)(in32 >> 16));
    } else {
        return silk_CLZ16((opus_int16)in32) + 16;
    }
}
#define matrix_ptr(Matrix_base_adr, row, column, N)         *(Matrix_base_adr + ((row)*(N)+(column)))

opus_int silk_resampler_init(
    silk_resampler_state_struct *S,
    opus_int32                  Fs_Hz_in,
    opus_int32                  Fs_Hz_out,
    opus_int                    forEnc
);
opus_int silk_resampler(
    silk_resampler_state_struct *S,
    opus_int16                  out[],
    const opus_int16            in[],
    opus_int32                  inLen
);
void silk_LPC_analysis_filter(
    opus_int16                  *out,
    const opus_int16            *in,
    const opus_int16            *B,
    const opus_int32            len,
    const opus_int32            d
);
void silk_bwexpander(
    opus_int16                  *ar,
    const opus_int              d,
    opus_int32                  chirp_Q16
);
void silk_bwexpander_32(
    opus_int32                  *ar,
    const opus_int              d,
    opus_int32                  chirp_Q16
);
opus_int32 silk_LPC_inverse_pred_gain(
    const opus_int16            *A_Q12,
    const opus_int              order
);
opus_int32 silk_log2lin(
    const opus_int32            inLog_Q7
);
void silk_sum_sqr_shift(
    opus_int32                  *energy,
    opus_int                    *shift,
    const opus_int16            *x,
    opus_int                    len
);
void silk_decode_pitch(
    opus_int16                  lagIndex,
    opus_int8                   contourIndex,
    opus_int                    pitch_lags[],
    const opus_int              Fs_kHz,
    const opus_int              nb_subfr
);
void silk_NLSF2A(
    opus_int16                  *a_Q12,
    const opus_int16            *NLSF,
    const opus_int              d
);
void silk_insertion_sort_increasing_all_values_int16(
     opus_int16                 *a,
     const opus_int             L
);
void silk_NLSF_stabilize(
          opus_int16            *NLSF_Q15,
    const opus_int16            *NDeltaMin_Q15,
    const opus_int              L
);
void silk_NLSF_VQ_weights_laroia(
    opus_int16                  *pNLSFW_Q_OUT,
    const opus_int16            *pNLSF_Q15,
    const opus_int              D
);
static inline opus_int32 silk_ROR32( opus_int32 a32, opus_int rot )
{
    opus_uint32 x = (opus_uint32) a32;
    opus_uint32 r = (opus_uint32) rot;
    opus_uint32 m = (opus_uint32) -rot;
    if( rot == 0 ) {
        return a32;
    } else if( rot < 0 ) {
        return (opus_int32) ((x << m) | (x >> (32 - m)));
    } else {
        return (opus_int32) ((x << (32 - r)) | (x >> r));
    }
}
#define silk_DWORD_ALIGN
#define silk_memcpy(dest, src, size)        memcpy((dest), (src), (size))
#define silk_memset(dest, src, size)        memset((dest), (src), (size))
#define silk_memmove(dest, src, size)       memmove((dest), (src), (size))
#define silk_MUL(a32, b32)                  ((a32) * (b32))
#define silk_MLA(a32, b32, c32)             silk_ADD32((a32),((b32) * (c32)))
#define silk_SMULL(a32, b32)                ((opus_int64)(a32) *  (b32))
#define silk_ADD32_ovflw(a, b)              ((opus_int32)((opus_uint32)(a) + (opus_uint32)(b)))
#define silk_SUB32_ovflw(a, b)              ((opus_int32)((opus_uint32)(a) - (opus_uint32)(b)))
#define silk_MLA_ovflw(a32, b32, c32)       silk_ADD32_ovflw((a32), (opus_uint32)(b32) * (opus_uint32)(c32))
#define silk_SMLABB_ovflw(a32, b32, c32)    (silk_ADD32_ovflw((a32) , ((opus_int32)((opus_int16)(b32))) * (opus_int32)((opus_int16)(c32))))
#define silk_DIV32_16(a32, b16)             ((opus_int32)((a32) / (b16)))
#define silk_DIV32(a32, b32)                ((opus_int32)((a32) / (b32)))
#define silk_ADD16(a, b)                    ((a) + (b))
#define silk_ADD32(a, b)                    ((a) + (b))
#define silk_SUB16(a, b)                    ((a) - (b))
#define silk_SUB32(a, b)                    ((a) - (b))
#define silk_SAT16(a)                       ((a) > silk_int16_MAX ? silk_int16_MAX :      \
                                            ((a) < silk_int16_MIN ? silk_int16_MIN : (a)))
#define silk_ADD_SAT16(a, b)                (opus_int16)silk_SAT16( silk_ADD32( (opus_int32)(a), (b) ) )
#define silk_LSHIFT32(a, shift)             ((opus_int32)((opus_uint32)(a)<<(shift)))
#define silk_LSHIFT(a, shift)               silk_LSHIFT32(a, shift)
#define silk_RSHIFT32(a, shift)             ((a)>>(shift))
#define silk_RSHIFT64(a, shift)             ((a)>>(shift))
#define silk_RSHIFT(a, shift)               silk_RSHIFT32(a, shift)
#define silk_LSHIFT_SAT32(a, shift)         (silk_LSHIFT32( silk_LIMIT( (a), silk_RSHIFT32( silk_int32_MIN, (shift) ), \
                                                    silk_RSHIFT32( silk_int32_MAX, (shift) ) ), (shift) ))
#define silk_LSHIFT_ovflw(a, shift)         ((opus_int32)((opus_uint32)(a) << (shift)))
#define silk_RSHIFT_uint(a, shift)          ((a) >> (shift))
#define silk_ADD_LSHIFT(a, b, shift)        ((a) + silk_LSHIFT((b), (shift)))
#define silk_ADD_LSHIFT32(a, b, shift)      silk_ADD32((a), silk_LSHIFT32((b), (shift)))
#define silk_ADD_RSHIFT(a, b, shift)        ((a) + silk_RSHIFT((b), (shift)))
#define silk_ADD_RSHIFT_uint(a, b, shift)   ((a) + silk_RSHIFT_uint((b), (shift)))
#define silk_RSHIFT_ROUND(a, shift)         ((shift) == 1 ? ((a) >> 1) + ((a) & 1) : (((a) >> ((shift) - 1)) + 1) >> 1)
#define silk_RSHIFT_ROUND64(a, shift)       ((shift) == 1 ? ((a) >> 1) + ((a) & 1) : (((a) >> ((shift) - 1)) + 1) >> 1)
#define silk_min(a, b)                      (((a) < (b)) ? (a) : (b))
#define silk_max(a, b)                      (((a) > (b)) ? (a) : (b))
#define SILK_FIX_CONST( C, Q )              ((opus_int32)((C) * ((opus_int64)1 << (Q)) + 0.5))
static inline opus_int silk_min_int(opus_int a, opus_int b)
{
    return (((a) < (b)) ? (a) : (b));
}
static inline opus_int32 silk_min_32(opus_int32 a, opus_int32 b)
{
    return (((a) < (b)) ? (a) : (b));
}
static inline opus_int silk_max_int(opus_int a, opus_int b)
{
    return (((a) > (b)) ? (a) : (b));
}
static inline opus_int16 silk_max_16(opus_int16 a, opus_int16 b)
{
    return (((a) > (b)) ? (a) : (b));
}
static inline opus_int32 silk_max_32(opus_int32 a, opus_int32 b)
{
    return (((a) > (b)) ? (a) : (b));
}
#define silk_LIMIT( a, limit1, limit2)      ((limit1) > (limit2) ? ((a) > (limit1) ? (limit1) : ((a) < (limit2) ? (limit2) : (a))) \
                                                                 : ((a) > (limit2) ? (limit2) : ((a) < (limit1) ? (limit1) : (a))))
#define silk_LIMIT_int                      silk_LIMIT
#define silk_LIMIT_32                       silk_LIMIT
#define silk_abs(a)                         (((a) >  0)  ? (a) : -(a))
#define silk_RAND(seed)                     (silk_MLA_ovflw(907633515, (seed), 196314165))
#define silk_SMMUL(a32, b32)                (opus_int32)silk_RSHIFT64(silk_SMULL((a32), (b32)), 32)
static inline void silk_CLZ_FRAC(
    opus_int32 in,
    opus_int32 *lz,
    opus_int32 *frac_Q7
)
{
    opus_int32 lzeros = silk_CLZ32(in);
    * lz = lzeros;
    * frac_Q7 = silk_ROR32(in, 24 - lzeros) & 0x7f;
}
static inline opus_int32 silk_SQRT_APPROX( opus_int32 x )
{
    opus_int32 y, lz, frac_Q7;
    if( x <= 0 ) {
        return 0;
    }
    silk_CLZ_FRAC(x, &lz, &frac_Q7);
    if( lz & 1 ) {
        y = 32768;
    } else {
        y = 46214;
    }
    y >>= silk_RSHIFT(lz, 1);
    y = silk_SMLAWB(y, y, silk_SMULBB(213, frac_Q7));
    return y;
}
static inline opus_int32 silk_DIV32_varQ(
    const opus_int32     a32,
    const opus_int32     b32,
    const opus_int       Qres
)
{
    opus_int   a_headrm, b_headrm, lshift;
    opus_int32 b32_inv, a32_nrm, b32_nrm, result;
    silk_assert( b32 != 0 );
    silk_assert( Qres >= 0 );
    a_headrm = silk_CLZ32( silk_abs(a32) ) - 1;
    a32_nrm = silk_LSHIFT(a32, a_headrm);
    b_headrm = silk_CLZ32( silk_abs(b32) ) - 1;
    b32_nrm = silk_LSHIFT(b32, b_headrm);
    b32_inv = silk_DIV32_16( silk_int32_MAX >> 2, silk_RSHIFT(b32_nrm, 16) );
    result = silk_SMULWB(a32_nrm, b32_inv);
    a32_nrm = silk_SUB32_ovflw(a32_nrm, silk_LSHIFT_ovflw( silk_SMMUL(b32_nrm, result), 3 ));
    result = silk_SMLAWB(result, a32_nrm, b32_inv);
    lshift = 29 + a_headrm - b_headrm - Qres;
    if( lshift < 0 ) {
        return silk_LSHIFT_SAT32(result, -lshift);
    } else {
        if( lshift < 32){
            return silk_RSHIFT(result, lshift);
        } else {
            return 0;
        }
    }
}
static inline opus_int32 silk_INVERSE32_varQ(
    const opus_int32     b32,
    const opus_int       Qres
)
{
    opus_int   b_headrm, lshift;
    opus_int32 b32_inv, b32_nrm, err_Q32, result;
    silk_assert( b32 != 0 );
    silk_assert( Qres > 0 );
    b_headrm = silk_CLZ32( silk_abs(b32) ) - 1;
    b32_nrm = silk_LSHIFT(b32, b_headrm);
    b32_inv = silk_DIV32_16( silk_int32_MAX >> 2, silk_RSHIFT(b32_nrm, 16) );
    result = silk_LSHIFT(b32_inv, 16);
    err_Q32 = silk_LSHIFT( (1<<29) - silk_SMULWB(b32_nrm, b32_inv), 3 );
    result = silk_SMLAWW(result, err_Q32, b32_inv);
    lshift = 61 - b_headrm - Qres;
    if( lshift <= 0 ) {
        return silk_LSHIFT_SAT32(result, -lshift);
    } else {
        if( lshift < 32){
            return silk_RSHIFT(result, lshift);
        }else{
            return 0;
        }
    }
}


#define SILK_NO_ERROR                               0
#define SILK_DEC_INVALID_SAMPLING_FREQUENCY         -200
#define SILK_DEC_INVALID_FRAME_SIZE                 -203

#define DECODER_NUM_CHANNELS                    2
#define MAX_FRAMES_PER_PACKET                   3
#define MAX_FS_KHZ                              16
#define MAX_API_FS_KHZ                          48
#define TYPE_NO_VOICE_ACTIVITY                  0
#define TYPE_VOICED                             2
#define CODE_INDEPENDENTLY                      0
#define CODE_INDEPENDENTLY_NO_LTP_SCALING       1
#define CODE_CONDITIONALLY                      2
#define STEREO_QUANT_TAB_SIZE                   16
#define STEREO_QUANT_SUB_STEPS                  5
#define STEREO_INTERP_LEN_MS                    8
#define PITCH_EST_MIN_LAG_MS                    2
#define PITCH_EST_MAX_LAG_MS                    18
#define MAX_NB_SUBFR                            4
#define LTP_MEM_LENGTH_MS                       20
#define SUB_FRAME_LENGTH_MS                     5
#define MAX_SUB_FRAME_LENGTH                    ( SUB_FRAME_LENGTH_MS * MAX_FS_KHZ )
#define MAX_FRAME_LENGTH_MS                     ( SUB_FRAME_LENGTH_MS * MAX_NB_SUBFR )
#define MAX_FRAME_LENGTH                        ( MAX_FRAME_LENGTH_MS * MAX_FS_KHZ )
#define MIN_QGAIN_DB                            2
#define MAX_QGAIN_DB                            88
#define N_LEVELS_QGAIN                          64
#define MAX_DELTA_GAIN_QUANT                    36
#define MIN_DELTA_GAIN_QUANT                    -4
#define OFFSET_VL_Q10                           32
#define OFFSET_VH_Q10                           100
#define OFFSET_UVL_Q10                          100
#define OFFSET_UVH_Q10                          240
#define QUANT_LEVEL_ADJUST_Q10                  80
#define MAX_LPC_STABILIZE_ITERATIONS            16
#define MAX_PREDICTION_POWER_GAIN               1e4f
#define MAX_LPC_ORDER                           16
#define MIN_LPC_ORDER                           10
#define LTP_ORDER                               5
#define NB_LTP_CBKS                             3
#define MAX_SHAPE_LPC_ORDER                     16
#define DECISION_DELAY                          32
#define SHELL_CODEC_FRAME_LENGTH                16
#define LOG2_SHELL_CODEC_FRAME_LENGTH           4
#define MAX_NB_SHELL_BLOCKS                     ( MAX_FRAME_LENGTH / SHELL_CODEC_FRAME_LENGTH )
#define N_RATE_LEVELS                           10
#define MAX_PULSES                              16
# define NSQ_LPC_BUF_LENGTH                     DECISION_DELAY
#define VAD_N_BANDS                             4
#define LSF_COS_TAB_SZ_FIX                      128
#define NLSF_W_Q                                2
#define NLSF_QUANT_MAX_AMPLITUDE                4
#define NLSF_QUANT_LEVEL_ADJ                    0.1
#define BWE_AFTER_LOSS_Q16                      63570
#define CNG_BUF_MASK_MAX                        255
#define CNG_GAIN_SMTH_Q16                       4634
#define CNG_NLSF_SMTH_Q16                       16348

typedef struct {
    opus_int16                  xq[           2 * MAX_FRAME_LENGTH ];
    opus_int32                  sLTP_shp_Q14[ 2 * MAX_FRAME_LENGTH ];
    opus_int32                  sLPC_Q14[ MAX_SUB_FRAME_LENGTH + NSQ_LPC_BUF_LENGTH ];
    opus_int32                  sAR2_Q14[ MAX_SHAPE_LPC_ORDER ];
    opus_int32                  sLF_AR_shp_Q14;
    opus_int                    lagPrev;
    opus_int                    sLTP_buf_idx;
    opus_int                    sLTP_shp_buf_idx;
    opus_int32                  rand_seed;
    opus_int32                  prev_gain_Q16;
    opus_int                    rewhite_flag;
} silk_nsq_state;
typedef struct {
    opus_int32                  AnaState[ 2 ];
    opus_int32                  AnaState1[ 2 ];
    opus_int32                  AnaState2[ 2 ];
    opus_int32                  XnrgSubfr[ VAD_N_BANDS ];
    opus_int32                  NrgRatioSmth_Q8[ VAD_N_BANDS ];
    opus_int16                  HPstate;
    opus_int32                  NL[ VAD_N_BANDS ];
    opus_int32                  inv_NL[ VAD_N_BANDS ];
    opus_int32                  NoiseLevelBias[ VAD_N_BANDS ];
    opus_int32                  counter;
} silk_VAD_state;
typedef struct {
    opus_int32                   In_LP_State[ 2 ];
    opus_int32                   transition_frame_no;
    opus_int                     mode;
} silk_LP_state;
typedef struct {
    const opus_int16             nVectors;
    const opus_int16             order;
    const opus_int16             quantStepSize_Q16;
    const opus_int16             invQuantStepSize_Q6;
    const opus_uint8             *CB1_NLSF_Q8;
    const opus_uint8             *CB1_iCDF;
    const opus_uint8             *pred_Q8;
    const opus_uint8             *ec_sel;
    const opus_uint8             *ec_iCDF;
    const opus_uint8             *ec_Rates_Q5;
    const opus_int16             *deltaMin_Q15;
} silk_NLSF_CB_struct;
typedef struct {
    opus_int16                   pred_prev_Q13[ 2 ];
    opus_int16                   sMid[ 2 ];
    opus_int16                   sSide[ 2 ];
    opus_int32                   mid_side_amp_Q0[ 4 ];
    opus_int16                   smth_width_Q14;
    opus_int16                   width_prev_Q14;
    opus_int16                   silent_side_len;
    opus_int8                    predIx[ MAX_FRAMES_PER_PACKET ][ 2 ][ 3 ];
    opus_int8                    mid_only_flags[ MAX_FRAMES_PER_PACKET ];
} stereo_enc_state;
typedef struct {
    opus_int16                   pred_prev_Q13[ 2 ];
    opus_int16                   sMid[ 2 ];
    opus_int16                   sSide[ 2 ];
} stereo_dec_state;
typedef struct {
    opus_int8                    GainsIndices[ MAX_NB_SUBFR ];
    opus_int8                    LTPIndex[ MAX_NB_SUBFR ];
    opus_int8                    NLSFIndices[ MAX_LPC_ORDER + 1 ];
    opus_int16                   lagIndex;
    opus_int8                    contourIndex;
    opus_int8                    signalType;
    opus_int8                    quantOffsetType;
    opus_int8                    NLSFInterpCoef_Q2;
    opus_int8                    PERIndex;
    opus_int8                    LTP_scaleIndex;
    opus_int8                    Seed;
} SideInfoIndices;
typedef struct {
    opus_int32                   In_HP_State[ 2 ];
    opus_int32                   variable_HP_smth1_Q15;
    opus_int32                   variable_HP_smth2_Q15;
    silk_LP_state                sLP;
    silk_VAD_state               sVAD;
    silk_nsq_state               sNSQ;
    opus_int16                   prev_NLSFq_Q15[ MAX_LPC_ORDER ];
    opus_int                     speech_activity_Q8;
    opus_int                     allow_bandwidth_switch;
    opus_int8                    LBRRprevLastGainIndex;
    opus_int8                    prevSignalType;
    opus_int                     prevLag;
    opus_int                     pitch_LPC_win_length;
    opus_int                     max_pitch_lag;
    opus_int32                   API_fs_Hz;
    opus_int32                   prev_API_fs_Hz;
    opus_int                     maxInternal_fs_Hz;
    opus_int                     minInternal_fs_Hz;
    opus_int                     desiredInternal_fs_Hz;
    opus_int                     fs_kHz;
    opus_int                     nb_subfr;
    opus_int                     frame_length;
    opus_int                     subfr_length;
    opus_int                     ltp_mem_length;
    opus_int                     la_pitch;
    opus_int                     la_shape;
    opus_int                     shapeWinLength;
    opus_int32                   TargetRate_bps;
    opus_int                     PacketSize_ms;
    opus_int                     PacketLoss_perc;
    opus_int32                   frameCounter;
    opus_int                     Complexity;
    opus_int                     nStatesDelayedDecision;
    opus_int                     useInterpolatedNLSFs;
    opus_int                     shapingLPCOrder;
    opus_int                     predictLPCOrder;
    opus_int                     pitchEstimationComplexity;
    opus_int                     pitchEstimationLPCOrder;
    opus_int32                   pitchEstimationThreshold_Q16;
    opus_int                     LTPQuantLowComplexity;
    opus_int                     mu_LTP_Q9;
    opus_int                     NLSF_MSVQ_Survivors;
    opus_int                     first_frame_after_reset;
    opus_int                     controlled_since_last_payload;
    opus_int                     warping_Q16;
    opus_int                     useCBR;
    opus_int                     prefillFlag;
    const opus_uint8             *pitch_lag_low_bits_iCDF;
    const opus_uint8             *pitch_contour_iCDF;
    const silk_NLSF_CB_struct    *psNLSF_CB;
    opus_int                     input_quality_bands_Q15[ VAD_N_BANDS ];
    opus_int                     input_tilt_Q15;
    opus_int                     SNR_dB_Q7;
    opus_int8                    VAD_flags[ MAX_FRAMES_PER_PACKET ];
    opus_int8                    LBRR_flag;
    opus_int                     LBRR_flags[ MAX_FRAMES_PER_PACKET ];
    SideInfoIndices              indices;
    opus_int8                    pulses[ MAX_FRAME_LENGTH ];
    opus_int16                   inputBuf[ MAX_FRAME_LENGTH + 2 ];
    opus_int                     inputBufIx;
    opus_int                     nFramesPerPacket;
    opus_int                     nFramesEncoded;
    opus_int                     nChannelsAPI;
    opus_int                     nChannelsInternal;
    opus_int                     channelNb;
    opus_int                     frames_since_onset;
    opus_int                     ec_prevSignalType;
    opus_int16                   ec_prevLagIndex;
    silk_resampler_state_struct resampler_state;
    opus_int                     useDTX;
    opus_int                     inDTX;
    opus_int                     noSpeechCounter;
    opus_int                     useInBandFEC;
    opus_int                     LBRR_enabled;
    opus_int                     LBRR_GainIncreases;
    SideInfoIndices              indices_LBRR[ MAX_FRAMES_PER_PACKET ];
    opus_int8                    pulses_LBRR[ MAX_FRAMES_PER_PACKET ][ MAX_FRAME_LENGTH ];
} silk_encoder_state;
typedef struct {
    opus_int32                  pitchL_Q8;
    opus_int16                  LTPCoef_Q14[ LTP_ORDER ];
    opus_int16                  prevLPC_Q12[ MAX_LPC_ORDER ];
    opus_int                    last_frame_lost;
    opus_int32                  rand_seed;
    opus_int16                  randScale_Q14;
    opus_int32                  conc_energy;
    opus_int                    conc_energy_shift;
    opus_int16                  prevLTP_scale_Q14;
    opus_int32                  prevGain_Q16[ 2 ];
    opus_int                    fs_kHz;
    opus_int                    nb_subfr;
    opus_int                    subfr_length;
} silk_PLC_struct;
typedef struct {
    opus_int32                  CNG_exc_buf_Q14[ MAX_FRAME_LENGTH ];
    opus_int16                  CNG_smth_NLSF_Q15[ MAX_LPC_ORDER ];
    opus_int32                  CNG_synth_state[ MAX_LPC_ORDER ];
    opus_int32                  CNG_smth_Gain_Q16;
    opus_int32                  rand_seed;
    opus_int                    fs_kHz;
} silk_CNG_struct;
typedef struct {
    opus_int32                  prev_gain_Q16;
    opus_int32                  exc_Q14[ MAX_FRAME_LENGTH ];
    opus_int32                  sLPC_Q14_buf[ MAX_LPC_ORDER ];
    opus_int16                  outBuf[ MAX_FRAME_LENGTH + 2 * MAX_SUB_FRAME_LENGTH ];
    opus_int                    lagPrev;
    opus_int8                   LastGainIndex;
    opus_int                    fs_kHz;
    opus_int32                  fs_API_hz;
    opus_int                    nb_subfr;
    opus_int                    frame_length;
    opus_int                    subfr_length;
    opus_int                    ltp_mem_length;
    opus_int                    LPC_order;
    opus_int16                  prevNLSF_Q15[ MAX_LPC_ORDER ];
    opus_int                    first_frame_after_reset;
    const opus_uint8            *pitch_lag_low_bits_iCDF;
    const opus_uint8            *pitch_contour_iCDF;
    opus_int                    nFramesDecoded;
    opus_int                    nFramesPerPacket;
    opus_int                    ec_prevSignalType;
    opus_int16                  ec_prevLagIndex;
    opus_int                    VAD_flags[ MAX_FRAMES_PER_PACKET ];
    opus_int                    LBRR_flag;
    opus_int                    LBRR_flags[ MAX_FRAMES_PER_PACKET ];
    silk_resampler_state_struct resampler_state;
    const silk_NLSF_CB_struct   *psNLSF_CB;
    SideInfoIndices             indices;
    silk_CNG_struct             sCNG;
    opus_int                    lossCnt;
    opus_int                    prevSignalType;
    silk_PLC_struct sPLC;
} silk_decoder_state;
typedef struct {
    opus_int                    pitchL[ MAX_NB_SUBFR ];
    opus_int32                  Gains_Q16[ MAX_NB_SUBFR ];
    silk_DWORD_ALIGN opus_int16 PredCoef_Q12[ 2 ][ MAX_LPC_ORDER ];
    opus_int16                  LTPCoef_Q14[ LTP_ORDER * MAX_NB_SUBFR ];
    opus_int                    LTP_scale_Q14;
} silk_decoder_control;

extern const opus_uint8  silk_gain_iCDF[ 3 ][ N_LEVELS_QGAIN / 8 ];
extern const opus_uint8  silk_delta_gain_iCDF[ MAX_DELTA_GAIN_QUANT - MIN_DELTA_GAIN_QUANT + 1 ];
extern const opus_uint8  silk_pitch_lag_iCDF[ 2 * ( PITCH_EST_MAX_LAG_MS - PITCH_EST_MIN_LAG_MS ) ];
extern const opus_uint8  silk_pitch_delta_iCDF[ 21 ];
extern const opus_uint8  silk_pitch_contour_iCDF[ 34 ];
extern const opus_uint8  silk_pitch_contour_NB_iCDF[ 11 ];
extern const opus_uint8  silk_pitch_contour_10_ms_iCDF[ 12 ];
extern const opus_uint8  silk_pitch_contour_10_ms_NB_iCDF[ 3 ];
extern const opus_uint8  silk_pulses_per_block_iCDF[ N_RATE_LEVELS ][ MAX_PULSES + 2 ];
extern const opus_uint8  silk_rate_levels_iCDF[ 2 ][ N_RATE_LEVELS - 1 ];
extern const opus_uint8  silk_shell_code_table0[ 152 ];
extern const opus_uint8  silk_shell_code_table1[ 152 ];
extern const opus_uint8  silk_shell_code_table2[ 152 ];
extern const opus_uint8  silk_shell_code_table3[ 152 ];
extern const opus_uint8  silk_shell_code_table_offsets[ MAX_PULSES + 1 ];
extern const opus_uint8  silk_lsb_iCDF[ 2 ];
extern const opus_uint8  silk_sign_iCDF[ 42 ];
extern const opus_uint8  silk_uniform3_iCDF[ 3 ];
extern const opus_uint8  silk_uniform4_iCDF[ 4 ];
extern const opus_uint8  silk_uniform5_iCDF[ 5 ];
extern const opus_uint8  silk_uniform6_iCDF[ 6 ];
extern const opus_uint8  silk_uniform8_iCDF[ 8 ];
extern const opus_uint8  silk_NLSF_EXT_iCDF[ 7 ];
extern const opus_uint8  silk_LTP_per_index_iCDF[ 3 ];
extern const opus_uint8  * const silk_LTP_gain_iCDF_ptrs[ NB_LTP_CBKS ];
extern const opus_int8   * const silk_LTP_vq_ptrs_Q7[ NB_LTP_CBKS ];
extern const opus_uint8  silk_LTPscale_iCDF[ 3 ];
extern const opus_int16  silk_LTPScales_table_Q14[ 3 ];
extern const opus_uint8  silk_type_offset_VAD_iCDF[ 4 ];
extern const opus_uint8  silk_type_offset_no_VAD_iCDF[ 2 ];
extern const opus_int16  silk_stereo_pred_quant_Q13[ STEREO_QUANT_TAB_SIZE ];
extern const opus_uint8  silk_stereo_pred_joint_iCDF[ 25 ];
extern const opus_uint8  silk_stereo_only_code_mid_iCDF[ 2 ];
extern const opus_uint8  * const silk_LBRR_flags_iCDF_ptr[ 2 ];
extern const opus_uint8  silk_NLSF_interpolation_factor_iCDF[ 5 ];
extern const silk_NLSF_CB_struct silk_NLSF_CB_WB;
extern const silk_NLSF_CB_struct silk_NLSF_CB_NB_MB;
extern const opus_int16  silk_Quantization_Offsets_Q10[ 2 ][ 2 ];
extern const opus_int16  silk_LSFCosTab_FIX_Q12[ LSF_COS_TAB_SZ_FIX + 1 ];

#define BWE_COEF                        0.99
#define V_PITCH_GAIN_START_MIN_Q14      11469
#define V_PITCH_GAIN_START_MAX_Q14      15565
#define MAX_PITCH_LAG_MS                18
#define RAND_BUF_SIZE                   128
#define RAND_BUF_MASK                   ( RAND_BUF_SIZE - 1 )
#define LOG2_INV_LPC_GAIN_HIGH_THRES    3
#define LOG2_INV_LPC_GAIN_LOW_THRES     8
#define PITCH_DRIFT_FAC_Q16             655
void silk_PLC_Reset(
    silk_decoder_state                  *psDec
);
void silk_PLC(
    silk_decoder_state                  *psDec,
    silk_decoder_control                *psDecCtrl,
    opus_int16                          frame[],
    opus_int                            lost
);
void silk_PLC_glue_frames(
    silk_decoder_state                  *psDec,
    opus_int16                          frame[],
    opus_int                            length
);

#define FLAG_DECODE_NORMAL                      0
#define FLAG_PACKET_LOST                        1
#define FLAG_DECODE_LBRR                        2
typedef struct {
    opus_int32 nChannelsAPI;
    opus_int32 nChannelsInternal;
    opus_int32 API_sampleRate;
    opus_int32 maxInternalSampleRate;
    opus_int32 minInternalSampleRate;
    opus_int32 desiredInternalSampleRate;
    opus_int payloadSize_ms;
    opus_int32 bitRate;
    opus_int packetLossPercentage;
    opus_int complexity;
    opus_int useInBandFEC;
    opus_int useDTX;
    opus_int useCBR;
    opus_int maxBits;
    opus_int toMono;
    opus_int opusCanSwitch;
    opus_int32 internalSampleRate;
    opus_int allowBandwidthSwitch;
    opus_int inWBmodeWithoutVariableLP;
    opus_int stereoWidth_Q14;
    opus_int switchReady;
} silk_EncControlStruct;
typedef struct {
    opus_int32 nChannelsAPI;
    opus_int32 nChannelsInternal;
    opus_int32 API_sampleRate;
    opus_int32 internalSampleRate;
    opus_int payloadSize_ms;
    opus_int prevPitchLag;
} silk_DecControlStruct;

void silk_stereo_MS_to_LR(
    stereo_dec_state            *state,
    opus_int16                  x1[],
    opus_int16                  x2[],
    const opus_int32            pred_Q13[],
    opus_int                    fs_kHz,
    opus_int                    frame_length
);
void silk_stereo_decode_pred(
    ec_dec                      *psRangeDec,
    opus_int32                  pred_Q13[]
);
void silk_stereo_decode_mid_only(
    ec_dec                      *psRangeDec,
    opus_int                    *decode_only_mid
);
void silk_decode_signs(
    ec_dec                      *psRangeDec,
    opus_int                    pulses[],
    opus_int                    length,
    const opus_int              signalType,
    const opus_int              quantOffsetType,
    const opus_int              sum_pulses[ MAX_NB_SHELL_BLOCKS ]
);
void silk_shell_decoder(
    opus_int                    *pulses0,
    ec_dec                      *psRangeDec,
    const opus_int              pulses4
);
void silk_gains_dequant(
    opus_int32                  gain_Q16[ MAX_NB_SUBFR ],
    const opus_int8             ind[ MAX_NB_SUBFR ],
    opus_int8                   *prev_ind,
    const opus_int              conditional,
    const opus_int              nb_subfr
);
void silk_NLSF_unpack(
          opus_int16            ec_ix[],
          opus_uint8            pred_Q8[],
    const silk_NLSF_CB_struct   *psNLSF_CB,
    const opus_int              CB1_index
);
void silk_NLSF_decode(
          opus_int16            *pNLSF_Q15,
          opus_int8             *NLSFIndices,
    const silk_NLSF_CB_struct   *psNLSF_CB
);
opus_int silk_init_decoder(
    silk_decoder_state          *psDec
);
opus_int silk_decoder_set_fs(
    silk_decoder_state          *psDec,
    opus_int                    fs_kHz,
    opus_int                    fs_API_Hz
);
opus_int silk_decode_frame(
    silk_decoder_state          *psDec,
    ec_dec                      *psRangeDec,
    opus_int16                  pOut[],
    opus_int32                  *pN,
    opus_int                    lostFlag,
    opus_int                    condCoding
);
void silk_decode_indices(
    silk_decoder_state          *psDec,
    ec_dec                      *psRangeDec,
    opus_int                    FrameIndex,
    opus_int                    decode_LBRR,
    opus_int                    condCoding
);
void silk_decode_parameters(
    silk_decoder_state          *psDec,
    silk_decoder_control        *psDecCtrl,
    opus_int                    condCoding
);
void silk_decode_core(
    silk_decoder_state          *psDec,
    silk_decoder_control        *psDecCtrl,
    opus_int16                  xq[],
    const opus_int              pulses[ MAX_FRAME_LENGTH ]
);
void silk_decode_pulses(
    ec_dec                      *psRangeDec,
    opus_int                    pulses[],
    const opus_int              signalType,
    const opus_int              quantOffsetType,
    const opus_int              frame_length
);
void silk_CNG_Reset(
    silk_decoder_state          *psDec
);
void silk_CNG(
    silk_decoder_state          *psDec,
    silk_decoder_control        *psDecCtrl,
    opus_int16                  frame[],
    opus_int                    length
);

static inline void silk_CNG_exc(
    opus_int32                       residual_Q10[],
    opus_int32                       exc_buf_Q14[],
    opus_int32                       Gain_Q16,
    opus_int                         length,
    opus_int32                       *rand_seed
)
{
    opus_int32 seed;
    opus_int   i, idx, exc_mask;
    exc_mask = CNG_BUF_MASK_MAX;
    while( exc_mask > length ) {
        exc_mask = silk_RSHIFT( exc_mask, 1 );
    }
    seed = *rand_seed;
    for( i = 0; i < length; i++ ) {
        seed = silk_RAND( seed );
        idx = (opus_int)( silk_RSHIFT( seed, 24 ) & exc_mask );
        silk_assert( idx >= 0 );
        silk_assert( idx <= CNG_BUF_MASK_MAX );
        residual_Q10[ i ] = (opus_int16)silk_SAT16( silk_SMULWW( exc_buf_Q14[ idx ], Gain_Q16 >> 4 ) );
    }
    *rand_seed = seed;
}
void silk_CNG_Reset(
    silk_decoder_state          *psDec
)
{
    opus_int i, NLSF_step_Q15, NLSF_acc_Q15;
    NLSF_step_Q15 = silk_DIV32_16( silk_int16_MAX, psDec->LPC_order + 1 );
    NLSF_acc_Q15 = 0;
    for( i = 0; i < psDec->LPC_order; i++ ) {
        NLSF_acc_Q15 += NLSF_step_Q15;
        psDec->sCNG.CNG_smth_NLSF_Q15[ i ] = NLSF_acc_Q15;
    }
    psDec->sCNG.CNG_smth_Gain_Q16 = 0;
    psDec->sCNG.rand_seed = 3176576;
}
void silk_CNG(
    silk_decoder_state          *psDec,
    silk_decoder_control        *psDecCtrl,
    opus_int16                  frame[],
    opus_int                    length
)
{
    opus_int   i, subfr;
    opus_int32 sum_Q6, max_Gain_Q16;
    opus_int16 A_Q12[ MAX_LPC_ORDER ];
    opus_int32 CNG_sig_Q10[ MAX_FRAME_LENGTH + MAX_LPC_ORDER ];
    silk_CNG_struct *psCNG = &psDec->sCNG;
    if( psDec->fs_kHz != psCNG->fs_kHz ) {
        silk_CNG_Reset( psDec );
        psCNG->fs_kHz = psDec->fs_kHz;
    }
    if( psDec->lossCnt == 0 && psDec->prevSignalType == TYPE_NO_VOICE_ACTIVITY ) {
        for( i = 0; i < psDec->LPC_order; i++ ) {
            psCNG->CNG_smth_NLSF_Q15[ i ] += silk_SMULWB( psDec->prevNLSF_Q15[ i ] - psCNG->CNG_smth_NLSF_Q15[ i ], CNG_NLSF_SMTH_Q16 );
        }
        max_Gain_Q16 = 0;
        subfr        = 0;
        for( i = 0; i < psDec->nb_subfr; i++ ) {
            if( psDecCtrl->Gains_Q16[ i ] > max_Gain_Q16 ) {
                max_Gain_Q16 = psDecCtrl->Gains_Q16[ i ];
                subfr        = i;
            }
        }
        silk_memmove( &psCNG->CNG_exc_buf_Q14[ psDec->subfr_length ], psCNG->CNG_exc_buf_Q14, ( psDec->nb_subfr - 1 ) * psDec->subfr_length * sizeof( opus_int32 ) );
        silk_memcpy(   psCNG->CNG_exc_buf_Q14, &psDec->exc_Q14[ subfr * psDec->subfr_length ], psDec->subfr_length * sizeof( opus_int32 ) );
        for( i = 0; i < psDec->nb_subfr; i++ ) {
            psCNG->CNG_smth_Gain_Q16 += silk_SMULWB( psDecCtrl->Gains_Q16[ i ] - psCNG->CNG_smth_Gain_Q16, CNG_GAIN_SMTH_Q16 );
        }
    }
    if( psDec->lossCnt ) {
        silk_CNG_exc( CNG_sig_Q10 + MAX_LPC_ORDER, psCNG->CNG_exc_buf_Q14, psCNG->CNG_smth_Gain_Q16, length, &psCNG->rand_seed );
        silk_NLSF2A( A_Q12, psCNG->CNG_smth_NLSF_Q15, psDec->LPC_order );
        silk_memcpy( CNG_sig_Q10, psCNG->CNG_synth_state, MAX_LPC_ORDER * sizeof( opus_int32 ) );
        for( i = 0; i < length; i++ ) {
            silk_assert( psDec->LPC_order == 10 || psDec->LPC_order == 16 );
            sum_Q6 = silk_RSHIFT( psDec->LPC_order, 1 );
            sum_Q6 = silk_SMLAWB( sum_Q6, CNG_sig_Q10[ MAX_LPC_ORDER + i -  1 ], A_Q12[ 0 ] );
            sum_Q6 = silk_SMLAWB( sum_Q6, CNG_sig_Q10[ MAX_LPC_ORDER + i -  2 ], A_Q12[ 1 ] );
            sum_Q6 = silk_SMLAWB( sum_Q6, CNG_sig_Q10[ MAX_LPC_ORDER + i -  3 ], A_Q12[ 2 ] );
            sum_Q6 = silk_SMLAWB( sum_Q6, CNG_sig_Q10[ MAX_LPC_ORDER + i -  4 ], A_Q12[ 3 ] );
            sum_Q6 = silk_SMLAWB( sum_Q6, CNG_sig_Q10[ MAX_LPC_ORDER + i -  5 ], A_Q12[ 4 ] );
            sum_Q6 = silk_SMLAWB( sum_Q6, CNG_sig_Q10[ MAX_LPC_ORDER + i -  6 ], A_Q12[ 5 ] );
            sum_Q6 = silk_SMLAWB( sum_Q6, CNG_sig_Q10[ MAX_LPC_ORDER + i -  7 ], A_Q12[ 6 ] );
            sum_Q6 = silk_SMLAWB( sum_Q6, CNG_sig_Q10[ MAX_LPC_ORDER + i -  8 ], A_Q12[ 7 ] );
            sum_Q6 = silk_SMLAWB( sum_Q6, CNG_sig_Q10[ MAX_LPC_ORDER + i -  9 ], A_Q12[ 8 ] );
            sum_Q6 = silk_SMLAWB( sum_Q6, CNG_sig_Q10[ MAX_LPC_ORDER + i - 10 ], A_Q12[ 9 ] );
            if( psDec->LPC_order == 16 ) {
                sum_Q6 = silk_SMLAWB( sum_Q6, CNG_sig_Q10[ MAX_LPC_ORDER + i - 11 ], A_Q12[ 10 ] );
                sum_Q6 = silk_SMLAWB( sum_Q6, CNG_sig_Q10[ MAX_LPC_ORDER + i - 12 ], A_Q12[ 11 ] );
                sum_Q6 = silk_SMLAWB( sum_Q6, CNG_sig_Q10[ MAX_LPC_ORDER + i - 13 ], A_Q12[ 12 ] );
                sum_Q6 = silk_SMLAWB( sum_Q6, CNG_sig_Q10[ MAX_LPC_ORDER + i - 14 ], A_Q12[ 13 ] );
                sum_Q6 = silk_SMLAWB( sum_Q6, CNG_sig_Q10[ MAX_LPC_ORDER + i - 15 ], A_Q12[ 14 ] );
                sum_Q6 = silk_SMLAWB( sum_Q6, CNG_sig_Q10[ MAX_LPC_ORDER + i - 16 ], A_Q12[ 15 ] );
            }
            CNG_sig_Q10[ MAX_LPC_ORDER + i ] = silk_ADD_LSHIFT( CNG_sig_Q10[ MAX_LPC_ORDER + i ], sum_Q6, 4 );
            frame[ i ] = silk_ADD_SAT16( frame[ i ], silk_RSHIFT_ROUND( sum_Q6, 6 ) );
        }
        silk_memcpy( psCNG->CNG_synth_state, &CNG_sig_Q10[ length ], MAX_LPC_ORDER * sizeof( opus_int32 ) );
    } else {
        silk_memset( psCNG->CNG_synth_state, 0, psDec->LPC_order *  sizeof( opus_int32 ) );
    }
}

void silk_LPC_analysis_filter(
    opus_int16                  *out,
    const opus_int16            *in,
    const opus_int16            *B,
    const opus_int32            len,
    const opus_int32            d
)
{
    opus_int         ix, j;
    opus_int32       out32_Q12, out32;
    const opus_int16 *in_ptr;
    silk_assert( d >= 6 );
    silk_assert( (d & 1) == 0 );
    silk_assert( d <= len );
    for( ix = d; ix < len; ix++ ) {
        in_ptr = &in[ ix - 1 ];
        out32_Q12 = silk_SMULBB( in_ptr[  0 ], B[ 0 ] );
        out32_Q12 = silk_SMLABB_ovflw( out32_Q12, in_ptr[ -1 ], B[ 1 ] );
        out32_Q12 = silk_SMLABB_ovflw( out32_Q12, in_ptr[ -2 ], B[ 2 ] );
        out32_Q12 = silk_SMLABB_ovflw( out32_Q12, in_ptr[ -3 ], B[ 3 ] );
        out32_Q12 = silk_SMLABB_ovflw( out32_Q12, in_ptr[ -4 ], B[ 4 ] );
        out32_Q12 = silk_SMLABB_ovflw( out32_Q12, in_ptr[ -5 ], B[ 5 ] );
        for( j = 6; j < d; j += 2 ) {
            out32_Q12 = silk_SMLABB_ovflw( out32_Q12, in_ptr[ -j     ], B[ j     ] );
            out32_Q12 = silk_SMLABB_ovflw( out32_Q12, in_ptr[ -j - 1 ], B[ j + 1 ] );
        }
        out32_Q12 = silk_SUB32_ovflw( silk_LSHIFT( (opus_int32)in_ptr[ 1 ], 12 ), out32_Q12 );
        out32 = silk_RSHIFT_ROUND( out32_Q12, 12 );
        out[ ix ] = (opus_int16)silk_SAT16( out32 );
    }
    silk_memset( out, 0, d * sizeof( opus_int16 ) );
}

#define QA                          24
#define A_LIMIT                     SILK_FIX_CONST( 0.99975, QA )
#define MUL32_FRAC_Q(a32, b32, Q)   ((opus_int32)(silk_RSHIFT_ROUND64(silk_SMULL(a32, b32), Q)))
static opus_int32 LPC_inverse_pred_gain_QA(
    opus_int32           A_QA[ 2 ][ SILK_MAX_ORDER_LPC ],
    const opus_int       order
)
{
    opus_int   k, n, mult2Q;
    opus_int32 invGain_Q30, rc_Q31, rc_mult1_Q30, rc_mult2, tmp_QA;
    opus_int32 *Aold_QA, *Anew_QA;
    Anew_QA = A_QA[ order & 1 ];
    invGain_Q30 = 1 << 30;
    for( k = order - 1; k > 0; k-- ) {
        if( ( Anew_QA[ k ] > A_LIMIT ) || ( Anew_QA[ k ] < -A_LIMIT ) ) {
            return 0;
        }
        rc_Q31 = -silk_LSHIFT( Anew_QA[ k ], 31 - QA );
        rc_mult1_Q30 = ( (opus_int32)1 << 30 ) - silk_SMMUL( rc_Q31, rc_Q31 );
        silk_assert( rc_mult1_Q30 > ( 1 << 15 ) );
        silk_assert( rc_mult1_Q30 <= ( 1 << 30 ) );
        mult2Q = 32 - silk_CLZ32( silk_abs( rc_mult1_Q30 ) );
        rc_mult2 = silk_INVERSE32_varQ( rc_mult1_Q30, mult2Q + 30 );
        invGain_Q30 = silk_LSHIFT( silk_SMMUL( invGain_Q30, rc_mult1_Q30 ), 2 );
        silk_assert( invGain_Q30 >= 0           );
        silk_assert( invGain_Q30 <= ( 1 << 30 ) );
        Aold_QA = Anew_QA;
        Anew_QA = A_QA[ k & 1 ];
        for( n = 0; n < k; n++ ) {
            opus_int64 tmp64;
            tmp_QA = silk_SUB_SAT32( Aold_QA[ n ], MUL32_FRAC_Q( Aold_QA[ k - n - 1 ], rc_Q31, 31 ) );
            tmp64 = silk_RSHIFT_ROUND64( silk_SMULL( tmp_QA, rc_mult2 ), mult2Q);
            if( tmp64 > silk_int32_MAX || tmp64 < silk_int32_MIN ) {
               return 0;
            }
            Anew_QA[ n ] = ( opus_int32 )tmp64;
        }
    }
    if( ( Anew_QA[ 0 ] > A_LIMIT ) || ( Anew_QA[ 0 ] < -A_LIMIT ) ) {
        return 0;
    }
    rc_Q31 = -silk_LSHIFT( Anew_QA[ 0 ], 31 - QA );
    rc_mult1_Q30 = ( (opus_int32)1 << 30 ) - silk_SMMUL( rc_Q31, rc_Q31 );
    invGain_Q30 = silk_LSHIFT( silk_SMMUL( invGain_Q30, rc_mult1_Q30 ), 2 );
    silk_assert( invGain_Q30 >= 0     );
    silk_assert( invGain_Q30 <= 1<<30 );
    return invGain_Q30;
}
opus_int32 silk_LPC_inverse_pred_gain(
    const opus_int16            *A_Q12,
    const opus_int              order
)
{
    opus_int   k;
    opus_int32 Atmp_QA[ 2 ][ SILK_MAX_ORDER_LPC ];
    opus_int32 *Anew_QA;
    opus_int32 DC_resp = 0;
    Anew_QA = Atmp_QA[ order & 1 ];
    for( k = 0; k < order; k++ ) {
        DC_resp += (opus_int32)A_Q12[ k ];
        Anew_QA[ k ] = silk_LSHIFT32( (opus_int32)A_Q12[ k ], QA - 12 );
    }
    if( DC_resp >= 4096 ) {
        return 0;
    }
    return LPC_inverse_pred_gain_QA( Atmp_QA, order );
}

#undef QA                              // silk_LPC_inverse_pred_gain's, before silk_NLSF2A's own
#define QA      16
static inline void silk_NLSF2A_find_poly(
    opus_int32          *out,
    const opus_int32    *cLSF,
    opus_int            dd
)
{
    opus_int   k, n;
    opus_int32 ftmp;
    out[0] = silk_LSHIFT( 1, QA );
    out[1] = -cLSF[0];
    for( k = 1; k < dd; k++ ) {
        ftmp = cLSF[2*k];
        out[k+1] = silk_LSHIFT( out[k-1], 1 ) - (opus_int32)silk_RSHIFT_ROUND64( silk_SMULL( ftmp, out[k] ), QA );
        for( n = k; n > 1; n-- ) {
            out[n] += out[n-2] - (opus_int32)silk_RSHIFT_ROUND64( silk_SMULL( ftmp, out[n-1] ), QA );
        }
        out[1] -= ftmp;
    }
}
void silk_NLSF2A(
    opus_int16                  *a_Q12,
    const opus_int16            *NLSF,
    const opus_int              d
)
{
    static const unsigned char ordering16[16] = {
      0, 15, 8, 7, 4, 11, 12, 3, 2, 13, 10, 5, 6, 9, 14, 1
    };
    static const unsigned char ordering10[10] = {
      0, 9, 6, 3, 4, 5, 8, 1, 2, 7
    };
    const unsigned char *ordering;
    opus_int   k, i, dd;
    opus_int32 cos_LSF_QA[ SILK_MAX_ORDER_LPC ] = { 0 };
    opus_int32 P[ SILK_MAX_ORDER_LPC / 2 + 1 ], Q[ SILK_MAX_ORDER_LPC / 2 + 1 ];
    opus_int32 Ptmp, Qtmp, f_int, f_frac, cos_val, delta;
    opus_int32 a32_QA1[ SILK_MAX_ORDER_LPC ];
    opus_int32 maxabs, absval, idx=0, sc_Q16;
    silk_assert( LSF_COS_TAB_SZ_FIX == 128 );
    silk_assert( d==10||d==16 );
    ordering = d == 16 ? ordering16 : ordering10;
    for( k = 0; k < d; k++ ) {
        silk_assert(NLSF[k] >= 0 );
        f_int = silk_RSHIFT( NLSF[k], 15 - 7 );
        f_frac = NLSF[k] - silk_LSHIFT( f_int, 15 - 7 );
        silk_assert(f_int >= 0);
        silk_assert(f_int < LSF_COS_TAB_SZ_FIX );
        cos_val = silk_LSFCosTab_FIX_Q12[ f_int ];
        delta   = silk_LSFCosTab_FIX_Q12[ f_int + 1 ] - cos_val;
        cos_LSF_QA[ordering[k]] = silk_RSHIFT_ROUND( silk_LSHIFT( cos_val, 8 ) + silk_MUL( delta, f_frac ), 20 - QA );
    }
    dd = silk_RSHIFT( d, 1 );
    silk_NLSF2A_find_poly( P, &cos_LSF_QA[ 0 ], dd );
    silk_NLSF2A_find_poly( Q, &cos_LSF_QA[ 1 ], dd );
    for( k = 0; k < dd; k++ ) {
        Ptmp = P[ k+1 ] + P[ k ];
        Qtmp = Q[ k+1 ] - Q[ k ];
        a32_QA1[ k ]     = -Qtmp - Ptmp;
        a32_QA1[ d-k-1 ] =  Qtmp - Ptmp;
    }
    for( i = 0; i < 10; i++ ) {
        maxabs = 0;
        for( k = 0; k < d; k++ ) {
            absval = silk_abs( a32_QA1[k] );
            if( absval > maxabs ) {
                maxabs = absval;
                idx    = k;
            }
        }
        maxabs = silk_RSHIFT_ROUND( maxabs, QA + 1 - 12 );
        if( maxabs > silk_int16_MAX ) {
            maxabs = silk_min( maxabs, 163838 );
            sc_Q16 = SILK_FIX_CONST( 0.999, 16 ) - silk_DIV32( silk_LSHIFT( maxabs - silk_int16_MAX, 14 ),
                                        silk_RSHIFT32( silk_MUL( maxabs, idx + 1), 2 ) );
            silk_bwexpander_32( a32_QA1, d, sc_Q16 );
        } else {
            break;
        }
    }
    if( i == 10 ) {
        for( k = 0; k < d; k++ ) {
            a_Q12[ k ] = (opus_int16)silk_SAT16( silk_RSHIFT_ROUND( a32_QA1[ k ], QA + 1 - 12 ) );
            a32_QA1[ k ] = silk_LSHIFT( (opus_int32)a_Q12[ k ], QA + 1 - 12 );
        }
    } else {
        for( k = 0; k < d; k++ ) {
            a_Q12[ k ] = (opus_int16)silk_RSHIFT_ROUND( a32_QA1[ k ], QA + 1 - 12 );
        }
    }
    for( i = 0; i < MAX_LPC_STABILIZE_ITERATIONS; i++ ) {
        if( silk_LPC_inverse_pred_gain( a_Q12, d ) < SILK_FIX_CONST( 1.0 / MAX_PREDICTION_POWER_GAIN, 30 ) ) {
            silk_bwexpander_32( a32_QA1, d, 65536 - silk_LSHIFT( 2, i ) );
            for( k = 0; k < d; k++ ) {
                a_Q12[ k ] = (opus_int16)silk_RSHIFT_ROUND( a32_QA1[ k ], QA + 1 - 12 );
            }
        } else {
            break;
        }
    }
}

void silk_NLSF_VQ_weights_laroia(
    opus_int16                  *pNLSFW_Q_OUT,
    const opus_int16            *pNLSF_Q15,
    const opus_int              D
)
{
    opus_int   k;
    opus_int32 tmp1_int, tmp2_int;
    silk_assert( D > 0 );
    silk_assert( ( D & 1 ) == 0 );
    tmp1_int = silk_max_int( pNLSF_Q15[ 0 ], 1 );
    tmp1_int = silk_DIV32_16( 1 << ( 15 + NLSF_W_Q ), tmp1_int );
    tmp2_int = silk_max_int( pNLSF_Q15[ 1 ] - pNLSF_Q15[ 0 ], 1 );
    tmp2_int = silk_DIV32_16( 1 << ( 15 + NLSF_W_Q ), tmp2_int );
    pNLSFW_Q_OUT[ 0 ] = (opus_int16)silk_min_int( tmp1_int + tmp2_int, silk_int16_MAX );
    silk_assert( pNLSFW_Q_OUT[ 0 ] > 0 );
    for( k = 1; k < D - 1; k += 2 ) {
        tmp1_int = silk_max_int( pNLSF_Q15[ k + 1 ] - pNLSF_Q15[ k ], 1 );
        tmp1_int = silk_DIV32_16( 1 << ( 15 + NLSF_W_Q ), tmp1_int );
        pNLSFW_Q_OUT[ k ] = (opus_int16)silk_min_int( tmp1_int + tmp2_int, silk_int16_MAX );
        silk_assert( pNLSFW_Q_OUT[ k ] > 0 );
        tmp2_int = silk_max_int( pNLSF_Q15[ k + 2 ] - pNLSF_Q15[ k + 1 ], 1 );
        tmp2_int = silk_DIV32_16( 1 << ( 15 + NLSF_W_Q ), tmp2_int );
        pNLSFW_Q_OUT[ k + 1 ] = (opus_int16)silk_min_int( tmp1_int + tmp2_int, silk_int16_MAX );
        silk_assert( pNLSFW_Q_OUT[ k + 1 ] > 0 );
    }
    tmp1_int = silk_max_int( ( 1 << 15 ) - pNLSF_Q15[ D - 1 ], 1 );
    tmp1_int = silk_DIV32_16( 1 << ( 15 + NLSF_W_Q ), tmp1_int );
    pNLSFW_Q_OUT[ D - 1 ] = (opus_int16)silk_min_int( tmp1_int + tmp2_int, silk_int16_MAX );
    silk_assert( pNLSFW_Q_OUT[ D - 1 ] > 0 );
}

static inline void silk_NLSF_residual_dequant(
          opus_int16         x_Q10[],
    const opus_int8          indices[],
    const opus_uint8         pred_coef_Q8[],
    const opus_int           quant_step_size_Q16,
    const opus_int16         order
)
{
    opus_int     i, out_Q10, pred_Q10;
    out_Q10 = 0;
    for( i = order-1; i >= 0; i-- ) {
        pred_Q10 = silk_RSHIFT( silk_SMULBB( out_Q10, (opus_int16)pred_coef_Q8[ i ] ), 8 );
        out_Q10  = silk_LSHIFT( indices[ i ], 10 );
        if( out_Q10 > 0 ) {
            out_Q10 = silk_SUB16( out_Q10, SILK_FIX_CONST( NLSF_QUANT_LEVEL_ADJ, 10 ) );
        } else if( out_Q10 < 0 ) {
            out_Q10 = silk_ADD16( out_Q10, SILK_FIX_CONST( NLSF_QUANT_LEVEL_ADJ, 10 ) );
        }
        out_Q10  = silk_SMLAWB( pred_Q10, out_Q10, quant_step_size_Q16 );
        x_Q10[ i ] = out_Q10;
    }
}
void silk_NLSF_decode(
          opus_int16            *pNLSF_Q15,
          opus_int8             *NLSFIndices,
    const silk_NLSF_CB_struct   *psNLSF_CB
)
{
    opus_int         i;
    opus_uint8       pred_Q8[  MAX_LPC_ORDER ];
    opus_int16       ec_ix[    MAX_LPC_ORDER ];
    opus_int16       res_Q10[  MAX_LPC_ORDER ];
    opus_int16       W_tmp_QW[ MAX_LPC_ORDER ];
    opus_int32       W_tmp_Q9, NLSF_Q15_tmp;
    const opus_uint8 *pCB_element;
    pCB_element = &psNLSF_CB->CB1_NLSF_Q8[ NLSFIndices[ 0 ] * psNLSF_CB->order ];
    for( i = 0; i < psNLSF_CB->order; i++ ) {
        pNLSF_Q15[ i ] = silk_LSHIFT( (opus_int16)pCB_element[ i ], 7 );
    }
    silk_NLSF_unpack( ec_ix, pred_Q8, psNLSF_CB, NLSFIndices[ 0 ] );
    silk_NLSF_residual_dequant( res_Q10, &NLSFIndices[ 1 ], pred_Q8, psNLSF_CB->quantStepSize_Q16, psNLSF_CB->order );
    silk_NLSF_VQ_weights_laroia( W_tmp_QW, pNLSF_Q15, psNLSF_CB->order );
    for( i = 0; i < psNLSF_CB->order; i++ ) {
        W_tmp_Q9 = silk_SQRT_APPROX( silk_LSHIFT( (opus_int32)W_tmp_QW[ i ], 18 - NLSF_W_Q ) );
        NLSF_Q15_tmp = silk_ADD32( pNLSF_Q15[ i ], silk_DIV32_16( silk_LSHIFT( (opus_int32)res_Q10[ i ], 14 ), W_tmp_Q9 ) );
        pNLSF_Q15[ i ] = (opus_int16)silk_LIMIT( NLSF_Q15_tmp, 0, 32767 );
    }
    silk_NLSF_stabilize( pNLSF_Q15, psNLSF_CB->deltaMin_Q15, psNLSF_CB->order );
}

#define MAX_LOOPS        20
void silk_NLSF_stabilize(
          opus_int16            *NLSF_Q15,
    const opus_int16            *NDeltaMin_Q15,
    const opus_int              L
)
{
    opus_int   i, I=0, k, loops;
    opus_int16 center_freq_Q15;
    opus_int32 diff_Q15, min_diff_Q15, min_center_Q15, max_center_Q15;
    silk_assert( NDeltaMin_Q15[L] >= 1 );
    for( loops = 0; loops < MAX_LOOPS; loops++ ) {
        min_diff_Q15 = NLSF_Q15[0] - NDeltaMin_Q15[0];
        I = 0;
        for( i = 1; i <= L-1; i++ ) {
            diff_Q15 = NLSF_Q15[i] - ( NLSF_Q15[i-1] + NDeltaMin_Q15[i] );
            if( diff_Q15 < min_diff_Q15 ) {
                min_diff_Q15 = diff_Q15;
                I = i;
            }
        }
        diff_Q15 = ( 1 << 15 ) - ( NLSF_Q15[L-1] + NDeltaMin_Q15[L] );
        if( diff_Q15 < min_diff_Q15 ) {
            min_diff_Q15 = diff_Q15;
            I = L;
        }
        if( min_diff_Q15 >= 0 ) {
            return;
        }
        if( I == 0 ) {
            NLSF_Q15[0] = NDeltaMin_Q15[0];
        } else if( I == L) {
            NLSF_Q15[L-1] = ( 1 << 15 ) - NDeltaMin_Q15[L];
        } else {
            min_center_Q15 = 0;
            for( k = 0; k < I; k++ ) {
                min_center_Q15 += NDeltaMin_Q15[k];
            }
            min_center_Q15 += silk_RSHIFT( NDeltaMin_Q15[I], 1 );
            max_center_Q15 = 1 << 15;
            for( k = L; k > I; k-- ) {
                max_center_Q15 -= NDeltaMin_Q15[k];
            }
            max_center_Q15 -= silk_RSHIFT( NDeltaMin_Q15[I], 1 );
            center_freq_Q15 = (opus_int16)silk_LIMIT_32( silk_RSHIFT_ROUND( (opus_int32)NLSF_Q15[I-1] + (opus_int32)NLSF_Q15[I], 1 ),
                min_center_Q15, max_center_Q15 );
            NLSF_Q15[I-1] = center_freq_Q15 - silk_RSHIFT( NDeltaMin_Q15[I], 1 );
            NLSF_Q15[I] = NLSF_Q15[I-1] + NDeltaMin_Q15[I];
        }
    }
    if( loops == MAX_LOOPS )
    {
        silk_insertion_sort_increasing_all_values_int16( &NLSF_Q15[0], L );
        NLSF_Q15[0] = silk_max_int( NLSF_Q15[0], NDeltaMin_Q15[0] );
        for( i = 1; i < L; i++ )
            NLSF_Q15[i] = silk_max_int( NLSF_Q15[i], silk_ADD_SAT16( NLSF_Q15[i-1], NDeltaMin_Q15[i] ) );
        NLSF_Q15[L-1] = silk_min_int( NLSF_Q15[L-1], (1<<15) - NDeltaMin_Q15[L] );
        for( i = L-2; i >= 0; i-- )
            NLSF_Q15[i] = silk_min_int( NLSF_Q15[i], NLSF_Q15[i+1] - NDeltaMin_Q15[i+1] );
    }
}

void silk_NLSF_unpack(
          opus_int16            ec_ix[],
          opus_uint8            pred_Q8[],
    const silk_NLSF_CB_struct   *psNLSF_CB,
    const opus_int              CB1_index
)
{
    opus_int   i;
    opus_uint8 entry;
    const opus_uint8 *ec_sel_ptr;
    ec_sel_ptr = &psNLSF_CB->ec_sel[ CB1_index * psNLSF_CB->order / 2 ];
    for( i = 0; i < psNLSF_CB->order; i += 2 ) {
        entry = *ec_sel_ptr++;
        ec_ix  [ i     ] = silk_SMULBB( silk_RSHIFT( entry, 1 ) & 7, 2 * NLSF_QUANT_MAX_AMPLITUDE + 1 );
        pred_Q8[ i     ] = psNLSF_CB->pred_Q8[ i + ( entry & 1 ) * ( psNLSF_CB->order - 1 ) ];
        ec_ix  [ i + 1 ] = silk_SMULBB( silk_RSHIFT( entry, 5 ) & 7, 2 * NLSF_QUANT_MAX_AMPLITUDE + 1 );
        pred_Q8[ i + 1 ] = psNLSF_CB->pred_Q8[ i + ( silk_RSHIFT( entry, 4 ) & 1 ) * ( psNLSF_CB->order - 1 ) + 1 ];
    }
}

#define NB_ATT 2
static const opus_int16 HARM_ATT_Q15[NB_ATT]              = { 32440, 31130 };
static const opus_int16 PLC_RAND_ATTENUATE_V_Q15[NB_ATT]  = { 31130, 26214 };
static const opus_int16 PLC_RAND_ATTENUATE_UV_Q15[NB_ATT] = { 32440, 29491 };
static inline void silk_PLC_update(
    silk_decoder_state                  *psDec,
    silk_decoder_control                *psDecCtrl
);
static inline void silk_PLC_conceal(
    silk_decoder_state                  *psDec,
    silk_decoder_control                *psDecCtrl,
    opus_int16                          signal[]
);
void silk_PLC_Reset(
    silk_decoder_state                  *psDec
)
{
    psDec->sPLC.pitchL_Q8 = silk_LSHIFT( psDec->frame_length, 8 - 1 );
    psDec->sPLC.prevGain_Q16[ 0 ] = SILK_FIX_CONST( 1, 16 );
    psDec->sPLC.prevGain_Q16[ 1 ] = SILK_FIX_CONST( 1, 16 );
    psDec->sPLC.subfr_length = 20;
    psDec->sPLC.nb_subfr = 2;
}
void silk_PLC(
    silk_decoder_state                  *psDec,
    silk_decoder_control                *psDecCtrl,
    opus_int16                          frame[],
    opus_int                            lost
)
{
    if( psDec->fs_kHz != psDec->sPLC.fs_kHz ) {
        silk_PLC_Reset( psDec );
        psDec->sPLC.fs_kHz = psDec->fs_kHz;
    }
    if( lost ) {
        silk_PLC_conceal( psDec, psDecCtrl, frame );
        psDec->lossCnt++;
    } else {
        silk_PLC_update( psDec, psDecCtrl );
    }
}
static inline void silk_PLC_update(
    silk_decoder_state                  *psDec,
    silk_decoder_control                *psDecCtrl
)
{
    opus_int32 LTP_Gain_Q14, temp_LTP_Gain_Q14;
    opus_int   i, j;
    silk_PLC_struct *psPLC;
    psPLC = &psDec->sPLC;
    psDec->prevSignalType = psDec->indices.signalType;
    LTP_Gain_Q14 = 0;
    if( psDec->indices.signalType == TYPE_VOICED ) {
        for( j = 0; j * psDec->subfr_length < psDecCtrl->pitchL[ psDec->nb_subfr - 1 ]; j++ ) {
            if( j == psDec->nb_subfr ) {
                break;
            }
            temp_LTP_Gain_Q14 = 0;
            for( i = 0; i < LTP_ORDER; i++ ) {
                temp_LTP_Gain_Q14 += psDecCtrl->LTPCoef_Q14[ ( psDec->nb_subfr - 1 - j ) * LTP_ORDER  + i ];
            }
            if( temp_LTP_Gain_Q14 > LTP_Gain_Q14 ) {
                LTP_Gain_Q14 = temp_LTP_Gain_Q14;
                silk_memcpy( psPLC->LTPCoef_Q14,
                    &psDecCtrl->LTPCoef_Q14[ silk_SMULBB( psDec->nb_subfr - 1 - j, LTP_ORDER ) ],
                    LTP_ORDER * sizeof( opus_int16 ) );
                psPLC->pitchL_Q8 = silk_LSHIFT( psDecCtrl->pitchL[ psDec->nb_subfr - 1 - j ], 8 );
            }
        }
        silk_memset( psPLC->LTPCoef_Q14, 0, LTP_ORDER * sizeof( opus_int16 ) );
        psPLC->LTPCoef_Q14[ LTP_ORDER / 2 ] = LTP_Gain_Q14;
        if( LTP_Gain_Q14 < V_PITCH_GAIN_START_MIN_Q14 ) {
            opus_int   scale_Q10;
            opus_int32 tmp;
            tmp = silk_LSHIFT( V_PITCH_GAIN_START_MIN_Q14, 10 );
            scale_Q10 = silk_DIV32( tmp, silk_max( LTP_Gain_Q14, 1 ) );
            for( i = 0; i < LTP_ORDER; i++ ) {
                psPLC->LTPCoef_Q14[ i ] = silk_RSHIFT( silk_SMULBB( psPLC->LTPCoef_Q14[ i ], scale_Q10 ), 10 );
            }
        } else if( LTP_Gain_Q14 > V_PITCH_GAIN_START_MAX_Q14 ) {
            opus_int   scale_Q14;
            opus_int32 tmp;
            tmp = silk_LSHIFT( V_PITCH_GAIN_START_MAX_Q14, 14 );
            scale_Q14 = silk_DIV32( tmp, silk_max( LTP_Gain_Q14, 1 ) );
            for( i = 0; i < LTP_ORDER; i++ ) {
                psPLC->LTPCoef_Q14[ i ] = silk_RSHIFT( silk_SMULBB( psPLC->LTPCoef_Q14[ i ], scale_Q14 ), 14 );
            }
        }
    } else {
        psPLC->pitchL_Q8 = silk_LSHIFT( silk_SMULBB( psDec->fs_kHz, 18 ), 8 );
        silk_memset( psPLC->LTPCoef_Q14, 0, LTP_ORDER * sizeof( opus_int16 ));
    }
    silk_memcpy( psPLC->prevLPC_Q12, psDecCtrl->PredCoef_Q12[ 1 ], psDec->LPC_order * sizeof( opus_int16 ) );
    psPLC->prevLTP_scale_Q14 = psDecCtrl->LTP_scale_Q14;
    silk_memcpy( psPLC->prevGain_Q16, &psDecCtrl->Gains_Q16[ psDec->nb_subfr - 2 ], 2 * sizeof( opus_int32 ) );
    psPLC->subfr_length = psDec->subfr_length;
    psPLC->nb_subfr = psDec->nb_subfr;
}
static inline void silk_PLC_conceal(
    silk_decoder_state                  *psDec,
    silk_decoder_control                *psDecCtrl,
    opus_int16                          frame[]
)
{
    opus_int   i, j, k;
    opus_int   lag, idx, sLTP_buf_idx, shift1, shift2;
    opus_int32 rand_seed, harm_Gain_Q15, rand_Gain_Q15, inv_gain_Q30;
    opus_int32 energy1, energy2, *rand_ptr, *pred_lag_ptr;
    opus_int32 LPC_pred_Q10, LTP_pred_Q12;
    opus_int16 rand_scale_Q14;
    opus_int16 *B_Q14, *exc_buf_ptr;
    opus_int32 *sLPC_Q14_ptr;
    opus_int16 exc_buf[ 2 * MAX_SUB_FRAME_LENGTH ];
    opus_int16 A_Q12[ MAX_LPC_ORDER ];
    opus_int16 sLTP[ MAX_FRAME_LENGTH ];
    opus_int32 sLTP_Q14[ 2 * MAX_FRAME_LENGTH ];
    silk_PLC_struct *psPLC = &psDec->sPLC;
    opus_int32 prevGain_Q10[2];
    prevGain_Q10[0] = silk_RSHIFT( psPLC->prevGain_Q16[ 0 ], 6);
    prevGain_Q10[1] = silk_RSHIFT( psPLC->prevGain_Q16[ 1 ], 6);
    if( psDec->first_frame_after_reset ) {
       silk_memset( psPLC->prevLPC_Q12, 0, sizeof( psPLC->prevLPC_Q12 ) );
    }
    exc_buf_ptr = exc_buf;
    for( k = 0; k < 2; k++ ) {
        for( i = 0; i < psPLC->subfr_length; i++ ) {
            exc_buf_ptr[ i ] = (opus_int16)silk_SAT16( silk_RSHIFT(
                silk_SMULWW( psDec->exc_Q14[ i + ( k + psPLC->nb_subfr - 2 ) * psPLC->subfr_length ], prevGain_Q10[ k ] ), 8 ) );
        }
        exc_buf_ptr += psPLC->subfr_length;
    }
    silk_sum_sqr_shift( &energy1, &shift1, exc_buf,                         psPLC->subfr_length );
    silk_sum_sqr_shift( &energy2, &shift2, &exc_buf[ psPLC->subfr_length ], psPLC->subfr_length );
    if( silk_RSHIFT( energy1, shift2 ) < silk_RSHIFT( energy2, shift1 ) ) {
        rand_ptr = &psDec->exc_Q14[ silk_max_int( 0, ( psPLC->nb_subfr - 1 ) * psPLC->subfr_length - RAND_BUF_SIZE ) ];
    } else {
        rand_ptr = &psDec->exc_Q14[ silk_max_int( 0, psPLC->nb_subfr * psPLC->subfr_length - RAND_BUF_SIZE ) ];
    }
    B_Q14          = psPLC->LTPCoef_Q14;
    rand_scale_Q14 = psPLC->randScale_Q14;
    harm_Gain_Q15 = HARM_ATT_Q15[ silk_min_int( NB_ATT - 1, psDec->lossCnt ) ];
    if( psDec->prevSignalType == TYPE_VOICED ) {
        rand_Gain_Q15 = PLC_RAND_ATTENUATE_V_Q15[  silk_min_int( NB_ATT - 1, psDec->lossCnt ) ];
    } else {
        rand_Gain_Q15 = PLC_RAND_ATTENUATE_UV_Q15[ silk_min_int( NB_ATT - 1, psDec->lossCnt ) ];
    }
    silk_bwexpander( psPLC->prevLPC_Q12, psDec->LPC_order, SILK_FIX_CONST( BWE_COEF, 16 ) );
    silk_memcpy( A_Q12, psPLC->prevLPC_Q12, psDec->LPC_order * sizeof( opus_int16 ) );
    if( psDec->lossCnt == 0 ) {
        rand_scale_Q14 = 1 << 14;
        if( psDec->prevSignalType == TYPE_VOICED ) {
            for( i = 0; i < LTP_ORDER; i++ ) {
                rand_scale_Q14 -= B_Q14[ i ];
            }
            rand_scale_Q14 = silk_max_16( 3277, rand_scale_Q14 );
            rand_scale_Q14 = (opus_int16)silk_RSHIFT( silk_SMULBB( rand_scale_Q14, psPLC->prevLTP_scale_Q14 ), 14 );
        } else {
            opus_int32 invGain_Q30, down_scale_Q30;
            invGain_Q30 = silk_LPC_inverse_pred_gain( psPLC->prevLPC_Q12, psDec->LPC_order );
            down_scale_Q30 = silk_min_32( silk_RSHIFT( 1 << 30, LOG2_INV_LPC_GAIN_HIGH_THRES ), invGain_Q30 );
            down_scale_Q30 = silk_max_32( silk_RSHIFT( 1 << 30, LOG2_INV_LPC_GAIN_LOW_THRES ), down_scale_Q30 );
            down_scale_Q30 = silk_LSHIFT( down_scale_Q30, LOG2_INV_LPC_GAIN_HIGH_THRES );
            rand_Gain_Q15 = silk_RSHIFT( silk_SMULWB( down_scale_Q30, rand_Gain_Q15 ), 14 );
        }
    }
    rand_seed    = psPLC->rand_seed;
    lag          = silk_RSHIFT_ROUND( psPLC->pitchL_Q8, 8 );
    sLTP_buf_idx = psDec->ltp_mem_length;
    idx = psDec->ltp_mem_length - lag - psDec->LPC_order - LTP_ORDER / 2;
    silk_assert( idx > 0 );
    silk_LPC_analysis_filter( &sLTP[ idx ], &psDec->outBuf[ idx ], A_Q12, psDec->ltp_mem_length - idx, psDec->LPC_order );
    inv_gain_Q30 = silk_INVERSE32_varQ( psPLC->prevGain_Q16[ 1 ], 46 );
    inv_gain_Q30 = silk_min( inv_gain_Q30, silk_int32_MAX >> 1 );
    for( i = idx + psDec->LPC_order; i < psDec->ltp_mem_length; i++ ) {
        sLTP_Q14[ i ] = silk_SMULWB( inv_gain_Q30, sLTP[ i ] );
    }
    for( k = 0; k < psDec->nb_subfr; k++ ) {
        pred_lag_ptr = &sLTP_Q14[ sLTP_buf_idx - lag + LTP_ORDER / 2 ];
        for( i = 0; i < psDec->subfr_length; i++ ) {
            LTP_pred_Q12 = 2;
            LTP_pred_Q12 = silk_SMLAWB( LTP_pred_Q12, pred_lag_ptr[  0 ], B_Q14[ 0 ] );
            LTP_pred_Q12 = silk_SMLAWB( LTP_pred_Q12, pred_lag_ptr[ -1 ], B_Q14[ 1 ] );
            LTP_pred_Q12 = silk_SMLAWB( LTP_pred_Q12, pred_lag_ptr[ -2 ], B_Q14[ 2 ] );
            LTP_pred_Q12 = silk_SMLAWB( LTP_pred_Q12, pred_lag_ptr[ -3 ], B_Q14[ 3 ] );
            LTP_pred_Q12 = silk_SMLAWB( LTP_pred_Q12, pred_lag_ptr[ -4 ], B_Q14[ 4 ] );
            pred_lag_ptr++;
            rand_seed = silk_RAND( rand_seed );
            idx = silk_RSHIFT( rand_seed, 25 ) & RAND_BUF_MASK;
            sLTP_Q14[ sLTP_buf_idx ] = silk_LSHIFT32( silk_SMLAWB( LTP_pred_Q12, rand_ptr[ idx ], rand_scale_Q14 ), 2 );
            sLTP_buf_idx++;
        }
        for( j = 0; j < LTP_ORDER; j++ ) {
            B_Q14[ j ] = silk_RSHIFT( silk_SMULBB( harm_Gain_Q15, B_Q14[ j ] ), 15 );
        }
        rand_scale_Q14 = silk_RSHIFT( silk_SMULBB( rand_scale_Q14, rand_Gain_Q15 ), 15 );
        psPLC->pitchL_Q8 = silk_SMLAWB( psPLC->pitchL_Q8, psPLC->pitchL_Q8, PITCH_DRIFT_FAC_Q16 );
        psPLC->pitchL_Q8 = silk_min_32( psPLC->pitchL_Q8, silk_LSHIFT( silk_SMULBB( MAX_PITCH_LAG_MS, psDec->fs_kHz ), 8 ) );
        lag = silk_RSHIFT_ROUND( psPLC->pitchL_Q8, 8 );
    }
    sLPC_Q14_ptr = &sLTP_Q14[ psDec->ltp_mem_length - MAX_LPC_ORDER ];
    silk_memcpy( sLPC_Q14_ptr, psDec->sLPC_Q14_buf, MAX_LPC_ORDER * sizeof( opus_int32 ) );
    silk_assert( psDec->LPC_order >= 10 );
    for( i = 0; i < psDec->frame_length; i++ ) {
        LPC_pred_Q10 = silk_RSHIFT( psDec->LPC_order, 1 );
        LPC_pred_Q10 = silk_SMLAWB( LPC_pred_Q10, sLPC_Q14_ptr[ MAX_LPC_ORDER + i -  1 ], A_Q12[ 0 ] );
        LPC_pred_Q10 = silk_SMLAWB( LPC_pred_Q10, sLPC_Q14_ptr[ MAX_LPC_ORDER + i -  2 ], A_Q12[ 1 ] );
        LPC_pred_Q10 = silk_SMLAWB( LPC_pred_Q10, sLPC_Q14_ptr[ MAX_LPC_ORDER + i -  3 ], A_Q12[ 2 ] );
        LPC_pred_Q10 = silk_SMLAWB( LPC_pred_Q10, sLPC_Q14_ptr[ MAX_LPC_ORDER + i -  4 ], A_Q12[ 3 ] );
        LPC_pred_Q10 = silk_SMLAWB( LPC_pred_Q10, sLPC_Q14_ptr[ MAX_LPC_ORDER + i -  5 ], A_Q12[ 4 ] );
        LPC_pred_Q10 = silk_SMLAWB( LPC_pred_Q10, sLPC_Q14_ptr[ MAX_LPC_ORDER + i -  6 ], A_Q12[ 5 ] );
        LPC_pred_Q10 = silk_SMLAWB( LPC_pred_Q10, sLPC_Q14_ptr[ MAX_LPC_ORDER + i -  7 ], A_Q12[ 6 ] );
        LPC_pred_Q10 = silk_SMLAWB( LPC_pred_Q10, sLPC_Q14_ptr[ MAX_LPC_ORDER + i -  8 ], A_Q12[ 7 ] );
        LPC_pred_Q10 = silk_SMLAWB( LPC_pred_Q10, sLPC_Q14_ptr[ MAX_LPC_ORDER + i -  9 ], A_Q12[ 8 ] );
        LPC_pred_Q10 = silk_SMLAWB( LPC_pred_Q10, sLPC_Q14_ptr[ MAX_LPC_ORDER + i - 10 ], A_Q12[ 9 ] );
        for( j = 10; j < psDec->LPC_order; j++ ) {
            LPC_pred_Q10 = silk_SMLAWB( LPC_pred_Q10, sLPC_Q14_ptr[ MAX_LPC_ORDER + i - j - 1 ], A_Q12[ j ] );
        }
        sLPC_Q14_ptr[ MAX_LPC_ORDER + i ] = silk_ADD_LSHIFT32( sLPC_Q14_ptr[ MAX_LPC_ORDER + i ], LPC_pred_Q10, 4 );
        frame[ i ] = (opus_int16)silk_SAT16( silk_SAT16( silk_RSHIFT_ROUND( silk_SMULWW( sLPC_Q14_ptr[ MAX_LPC_ORDER + i ], prevGain_Q10[ 1 ] ), 8 ) ) );
    }
    silk_memcpy( psDec->sLPC_Q14_buf, &sLPC_Q14_ptr[ psDec->frame_length ], MAX_LPC_ORDER * sizeof( opus_int32 ) );
    psPLC->rand_seed     = rand_seed;
    psPLC->randScale_Q14 = rand_scale_Q14;
    for( i = 0; i < MAX_NB_SUBFR; i++ ) {
        psDecCtrl->pitchL[ i ] = lag;
    }
}
void silk_PLC_glue_frames(
    silk_decoder_state                  *psDec,
    opus_int16                          frame[],
    opus_int                            length
)
{
    opus_int   i, energy_shift;
    opus_int32 energy;
    silk_PLC_struct *psPLC;
    psPLC = &psDec->sPLC;
    if( psDec->lossCnt ) {
        silk_sum_sqr_shift( &psPLC->conc_energy, &psPLC->conc_energy_shift, frame, length );
        psPLC->last_frame_lost = 1;
    } else {
        if( psDec->sPLC.last_frame_lost ) {
            silk_sum_sqr_shift( &energy, &energy_shift, frame, length );
            if( energy_shift > psPLC->conc_energy_shift ) {
                psPLC->conc_energy = silk_RSHIFT( psPLC->conc_energy, energy_shift - psPLC->conc_energy_shift );
            } else if( energy_shift < psPLC->conc_energy_shift ) {
                energy = silk_RSHIFT( energy, psPLC->conc_energy_shift - energy_shift );
            }
            if( energy > psPLC->conc_energy ) {
                opus_int32 frac_Q24, LZ;
                opus_int32 gain_Q16, slope_Q16;
                LZ = silk_CLZ32( psPLC->conc_energy );
                LZ = LZ - 1;
                psPLC->conc_energy = silk_LSHIFT( psPLC->conc_energy, LZ );
                energy = silk_RSHIFT( energy, silk_max_32( 24 - LZ, 0 ) );
                frac_Q24 = silk_DIV32( psPLC->conc_energy, silk_max( energy, 1 ) );
                gain_Q16 = silk_LSHIFT( silk_SQRT_APPROX( frac_Q24 ), 4 );
                slope_Q16 = silk_DIV32_16( ( 1 << 16 ) - gain_Q16, length );
                slope_Q16 = silk_LSHIFT( slope_Q16, 2 );
                for( i = 0; i < length; i++ ) {
                    frame[ i ] = silk_SMULWB( gain_Q16, frame[ i ] );
                    gain_Q16 += slope_Q16;
                    if( gain_Q16 > 1 << 16 ) {
                        break;
                    }
                }
            }
        }
        psPLC->last_frame_lost = 0;
    }
}

void silk_bwexpander(
    opus_int16                  *ar,
    const opus_int              d,
    opus_int32                  chirp_Q16
)
{
    opus_int   i;
    opus_int32 chirp_minus_one_Q16 = chirp_Q16 - 65536;
    for( i = 0; i < d - 1; i++ ) {
        ar[ i ]    = (opus_int16)silk_RSHIFT_ROUND( silk_MUL( chirp_Q16, ar[ i ]             ), 16 );
        chirp_Q16 +=            silk_RSHIFT_ROUND( silk_MUL( chirp_Q16, chirp_minus_one_Q16 ), 16 );
    }
    ar[ d - 1 ] = (opus_int16)silk_RSHIFT_ROUND( silk_MUL( chirp_Q16, ar[ d - 1 ] ), 16 );
}

void silk_bwexpander_32(
    opus_int32                  *ar,
    const opus_int              d,
    opus_int32                  chirp_Q16
)
{
    opus_int   i;
    opus_int32 chirp_minus_one_Q16 = chirp_Q16 - 65536;
    for( i = 0; i < d - 1; i++ ) {
        ar[ i ]    = silk_SMULWW( chirp_Q16, ar[ i ] );
        chirp_Q16 += silk_RSHIFT_ROUND( silk_MUL( chirp_Q16, chirp_minus_one_Q16 ), 16 );
    }
    ar[ d - 1 ] = silk_SMULWW( chirp_Q16, ar[ d - 1 ] );
}

#define silk_dec_map(a)                  ( silk_LSHIFT( (a),  1 ) - 1 )
void silk_decode_signs(
    ec_dec                      *psRangeDec,
    opus_int                    pulses[],
    opus_int                    length,
    const opus_int              signalType,
    const opus_int              quantOffsetType,
    const opus_int              sum_pulses[ MAX_NB_SHELL_BLOCKS ]
)
{
    opus_int         i, j, p;
    opus_uint8       icdf[ 2 ];
    opus_int         *q_ptr;
    const opus_uint8 *icdf_ptr;
    icdf[ 1 ] = 0;
    q_ptr = pulses;
    i = silk_SMULBB( 7, silk_ADD_LSHIFT( quantOffsetType, signalType, 1 ) );
    icdf_ptr = &silk_sign_iCDF[ i ];
    length = silk_RSHIFT( length + SHELL_CODEC_FRAME_LENGTH/2, LOG2_SHELL_CODEC_FRAME_LENGTH );
    for( i = 0; i < length; i++ ) {
        p = sum_pulses[ i ];
        if( p > 0 ) {
            icdf[ 0 ] = icdf_ptr[ silk_min( p & 0x1F, 6 ) ];
            for( j = 0; j < SHELL_CODEC_FRAME_LENGTH; j++ ) {
                if( q_ptr[ j ] > 0 ) {
#if 0
                    if( ec_dec_icdf( psRangeDec, icdf, 8 ) == 0 ) {
                        q_ptr[ j ] = -q_ptr[ j ];
                    }
#else
                    q_ptr[ j ] *= silk_dec_map( ec_dec_icdf( psRangeDec, icdf, 8 ) );
#endif
                }
            }
        }
        q_ptr += SHELL_CODEC_FRAME_LENGTH;
    }
}

#define SILK_MAX_FRAMES_PER_PACKET  3
typedef struct {
    opus_int    VADFlag;
    opus_int    VADFlags[ SILK_MAX_FRAMES_PER_PACKET ];
    opus_int    inbandFECFlag;
} silk_TOC_struct;
opus_int silk_Get_Decoder_Size(
    opus_int                        *decSizeBytes
);
opus_int silk_InitDecoder(
    void                            *decState
);
opus_int silk_Decode(
    void*                           decState,
    silk_DecControlStruct*          decControl,
    opus_int                        lostFlag,
    opus_int                        newPacketFlag,
    ec_dec                          *psRangeDec,
    opus_int16                      *samplesOut,
    opus_int32                      *nSamplesOut
);

typedef struct {
    silk_decoder_state          channel_state[ DECODER_NUM_CHANNELS ];
    stereo_dec_state                sStereo;
    opus_int                         nChannelsAPI;
    opus_int                         nChannelsInternal;
    opus_int                         prev_decode_only_middle;
} silk_decoder;
opus_int silk_Get_Decoder_Size(
    opus_int                        *decSizeBytes
)
{
    opus_int ret = SILK_NO_ERROR;
    *decSizeBytes = sizeof( silk_decoder );
    return ret;
}
opus_int silk_InitDecoder(
    void                            *decState
)
{
    opus_int n, ret = SILK_NO_ERROR;
    silk_decoder_state *channel_state = ((silk_decoder *)decState)->channel_state;
    for( n = 0; n < DECODER_NUM_CHANNELS; n++ ) {
        ret  = silk_init_decoder( &channel_state[ n ] );
    }
    silk_memset(&((silk_decoder *)decState)->sStereo, 0,
                sizeof(((silk_decoder *)decState)->sStereo));
    ((silk_decoder *)decState)->prev_decode_only_middle = 0;
    return ret;
}
opus_int silk_Decode(
    void*                           decState,
    silk_DecControlStruct*          decControl,
    opus_int                        lostFlag,
    opus_int                        newPacketFlag,
    ec_dec                          *psRangeDec,
    opus_int16                      *samplesOut,
    opus_int32                      *nSamplesOut
)
{
    opus_int   i, n, decode_only_middle = 0, ret = SILK_NO_ERROR;
    opus_int32 nSamplesOutDec, LBRR_symbol;
    opus_int16 samplesOut1_tmp[ 2 ][ MAX_FS_KHZ * MAX_FRAME_LENGTH_MS + 2 ];
    opus_int16 samplesOut2_tmp[ MAX_API_FS_KHZ * MAX_FRAME_LENGTH_MS ];
    opus_int32 MS_pred_Q13[ 2 ] = { 0 };
    opus_int16 *resample_out_ptr;
    silk_decoder *psDec = ( silk_decoder * )decState;
    silk_decoder_state *channel_state = psDec->channel_state;
    opus_int has_side;
    opus_int stereo_to_mono;
    if( newPacketFlag ) {
        for( n = 0; n < decControl->nChannelsInternal; n++ ) {
            channel_state[ n ].nFramesDecoded = 0;
        }
    }
    if( decControl->nChannelsInternal > psDec->nChannelsInternal ) {
        ret += silk_init_decoder( &channel_state[ 1 ] );
    }
    stereo_to_mono = decControl->nChannelsInternal == 1 && psDec->nChannelsInternal == 2 &&
                     ( decControl->internalSampleRate == 1000*channel_state[ 0 ].fs_kHz );
    if( channel_state[ 0 ].nFramesDecoded == 0 ) {
        for( n = 0; n < decControl->nChannelsInternal; n++ ) {
            opus_int fs_kHz_dec;
            if( decControl->payloadSize_ms == 0 ) {
                channel_state[ n ].nFramesPerPacket = 1;
                channel_state[ n ].nb_subfr = 2;
            } else if( decControl->payloadSize_ms == 10 ) {
                channel_state[ n ].nFramesPerPacket = 1;
                channel_state[ n ].nb_subfr = 2;
            } else if( decControl->payloadSize_ms == 20 ) {
                channel_state[ n ].nFramesPerPacket = 1;
                channel_state[ n ].nb_subfr = 4;
            } else if( decControl->payloadSize_ms == 40 ) {
                channel_state[ n ].nFramesPerPacket = 2;
                channel_state[ n ].nb_subfr = 4;
            } else if( decControl->payloadSize_ms == 60 ) {
                channel_state[ n ].nFramesPerPacket = 3;
                channel_state[ n ].nb_subfr = 4;
            } else {
                silk_assert( 0 );
                return SILK_DEC_INVALID_FRAME_SIZE;
            }
            fs_kHz_dec = ( decControl->internalSampleRate >> 10 ) + 1;
            if( fs_kHz_dec != 8 && fs_kHz_dec != 12 && fs_kHz_dec != 16 ) {
                silk_assert( 0 );
                return SILK_DEC_INVALID_SAMPLING_FREQUENCY;
            }
            ret += silk_decoder_set_fs( &channel_state[ n ], fs_kHz_dec, decControl->API_sampleRate );
        }
    }
    if( decControl->nChannelsAPI == 2 && decControl->nChannelsInternal == 2 && ( psDec->nChannelsAPI == 1 || psDec->nChannelsInternal == 1 ) ) {
        silk_memset( psDec->sStereo.pred_prev_Q13, 0, sizeof( psDec->sStereo.pred_prev_Q13 ) );
        silk_memset( psDec->sStereo.sSide, 0, sizeof( psDec->sStereo.sSide ) );
        silk_memcpy( &channel_state[ 1 ].resampler_state, &channel_state[ 0 ].resampler_state, sizeof( silk_resampler_state_struct ) );
    }
    psDec->nChannelsAPI      = decControl->nChannelsAPI;
    psDec->nChannelsInternal = decControl->nChannelsInternal;
    if( decControl->API_sampleRate > MAX_API_FS_KHZ * 1000 || decControl->API_sampleRate < 8000 ) {
        ret = SILK_DEC_INVALID_SAMPLING_FREQUENCY;
        return( ret );
    }
    if( lostFlag != FLAG_PACKET_LOST && channel_state[ 0 ].nFramesDecoded == 0 ) {
        for( n = 0; n < decControl->nChannelsInternal; n++ ) {
            for( i = 0; i < channel_state[ n ].nFramesPerPacket; i++ ) {
                channel_state[ n ].VAD_flags[ i ] = ec_dec_bit_logp(psRangeDec, 1);
            }
            channel_state[ n ].LBRR_flag = ec_dec_bit_logp(psRangeDec, 1);
        }
        for( n = 0; n < decControl->nChannelsInternal; n++ ) {
            silk_memset( channel_state[ n ].LBRR_flags, 0, sizeof( channel_state[ n ].LBRR_flags ) );
            if( channel_state[ n ].LBRR_flag ) {
                if( channel_state[ n ].nFramesPerPacket == 1 ) {
                    channel_state[ n ].LBRR_flags[ 0 ] = 1;
                } else {
                    LBRR_symbol = ec_dec_icdf( psRangeDec, silk_LBRR_flags_iCDF_ptr[ channel_state[ n ].nFramesPerPacket - 2 ], 8 ) + 1;
                    for( i = 0; i < channel_state[ n ].nFramesPerPacket; i++ ) {
                        channel_state[ n ].LBRR_flags[ i ] = silk_RSHIFT( LBRR_symbol, i ) & 1;
                    }
                }
            }
        }
        if( lostFlag == FLAG_DECODE_NORMAL ) {
            for( i = 0; i < channel_state[ 0 ].nFramesPerPacket; i++ ) {
                for( n = 0; n < decControl->nChannelsInternal; n++ ) {
                    if( channel_state[ n ].LBRR_flags[ i ] ) {
                        opus_int pulses[ MAX_FRAME_LENGTH ];
                        opus_int condCoding;
                        if( decControl->nChannelsInternal == 2 && n == 0 ) {
                            silk_stereo_decode_pred( psRangeDec, MS_pred_Q13 );
                            if( channel_state[ 1 ].LBRR_flags[ i ] == 0 ) {
                                silk_stereo_decode_mid_only( psRangeDec, &decode_only_middle );
                            }
                        }
                        if( i > 0 && channel_state[ n ].LBRR_flags[ i - 1 ] ) {
                            condCoding = CODE_CONDITIONALLY;
                        } else {
                            condCoding = CODE_INDEPENDENTLY;
                        }
                        silk_decode_indices( &channel_state[ n ], psRangeDec, i, 1, condCoding );
                        silk_decode_pulses( psRangeDec, pulses, channel_state[ n ].indices.signalType,
                            channel_state[ n ].indices.quantOffsetType, channel_state[ n ].frame_length );
                    }
                }
            }
        }
    }
    if( decControl->nChannelsInternal == 2 ) {
        if(   lostFlag == FLAG_DECODE_NORMAL ||
            ( lostFlag == FLAG_DECODE_LBRR && channel_state[ 0 ].LBRR_flags[ channel_state[ 0 ].nFramesDecoded ] == 1 ) )
        {
            silk_stereo_decode_pred( psRangeDec, MS_pred_Q13 );
            if( ( lostFlag == FLAG_DECODE_NORMAL && channel_state[ 1 ].VAD_flags[ channel_state[ 0 ].nFramesDecoded ] == 0 ) ||
                ( lostFlag == FLAG_DECODE_LBRR && channel_state[ 1 ].LBRR_flags[ channel_state[ 0 ].nFramesDecoded ] == 0 ) )
            {
                silk_stereo_decode_mid_only( psRangeDec, &decode_only_middle );
            } else {
                decode_only_middle = 0;
            }
        } else {
            for( n = 0; n < 2; n++ ) {
                MS_pred_Q13[ n ] = psDec->sStereo.pred_prev_Q13[ n ];
            }
        }
    }
    if( decControl->nChannelsInternal == 2 && decode_only_middle == 0 && psDec->prev_decode_only_middle == 1 ) {
        silk_memset( psDec->channel_state[ 1 ].outBuf, 0, sizeof(psDec->channel_state[ 1 ].outBuf) );
        silk_memset( psDec->channel_state[ 1 ].sLPC_Q14_buf, 0, sizeof(psDec->channel_state[ 1 ].sLPC_Q14_buf) );
        psDec->channel_state[ 1 ].lagPrev        = 100;
        psDec->channel_state[ 1 ].LastGainIndex  = 10;
        psDec->channel_state[ 1 ].prevSignalType = TYPE_NO_VOICE_ACTIVITY;
        psDec->channel_state[ 1 ].first_frame_after_reset = 1;
    }
    if( lostFlag == FLAG_DECODE_NORMAL ) {
        has_side = !decode_only_middle;
    } else {
        has_side = !psDec->prev_decode_only_middle
              || (decControl->nChannelsInternal == 2 && lostFlag == FLAG_DECODE_LBRR && channel_state[1].LBRR_flags[ channel_state[1].nFramesDecoded ] == 1 );
    }
    for( n = 0; n < decControl->nChannelsInternal; n++ ) {
        if( n == 0 || has_side ) {
            opus_int FrameIndex;
            opus_int condCoding;
            FrameIndex = channel_state[ 0 ].nFramesDecoded - n;
            if( FrameIndex <= 0 ) {
                condCoding = CODE_INDEPENDENTLY;
            } else if( lostFlag == FLAG_DECODE_LBRR ) {
                condCoding = channel_state[ n ].LBRR_flags[ FrameIndex - 1 ] ? CODE_CONDITIONALLY : CODE_INDEPENDENTLY;
            } else if( n > 0 && psDec->prev_decode_only_middle ) {
                condCoding = CODE_INDEPENDENTLY_NO_LTP_SCALING;
            } else {
                condCoding = CODE_CONDITIONALLY;
            }
            ret += silk_decode_frame( &channel_state[ n ], psRangeDec, &samplesOut1_tmp[ n ][ 2 ], &nSamplesOutDec, lostFlag, condCoding);
        } else {
            silk_memset( &samplesOut1_tmp[ n ][ 2 ], 0, nSamplesOutDec * sizeof( opus_int16 ) );
        }
        channel_state[ n ].nFramesDecoded++;
    }
    if( decControl->nChannelsAPI == 2 && decControl->nChannelsInternal == 2 ) {
        silk_stereo_MS_to_LR( &psDec->sStereo, samplesOut1_tmp[ 0 ], samplesOut1_tmp[ 1 ], MS_pred_Q13, channel_state[ 0 ].fs_kHz, nSamplesOutDec );
    } else {
        silk_memcpy( samplesOut1_tmp[ 0 ], psDec->sStereo.sMid, 2 * sizeof( opus_int16 ) );
        silk_memcpy( psDec->sStereo.sMid, &samplesOut1_tmp[ 0 ][ nSamplesOutDec ], 2 * sizeof( opus_int16 ) );
    }
    *nSamplesOut = silk_DIV32( nSamplesOutDec * decControl->API_sampleRate, silk_SMULBB( channel_state[ 0 ].fs_kHz, 1000 ) );
    if( decControl->nChannelsAPI == 2 ) {
        resample_out_ptr = samplesOut2_tmp;
    } else {
        resample_out_ptr = samplesOut;
    }
    for( n = 0; n < silk_min( decControl->nChannelsAPI, decControl->nChannelsInternal ); n++ ) {
        ret += silk_resampler( &channel_state[ n ].resampler_state, resample_out_ptr, &samplesOut1_tmp[ n ][ 1 ], nSamplesOutDec );
        if( decControl->nChannelsAPI == 2 ) {
            for( i = 0; i < *nSamplesOut; i++ ) {
                samplesOut[ n + 2 * i ] = resample_out_ptr[ i ];
            }
        }
    }
    if( decControl->nChannelsAPI == 2 && decControl->nChannelsInternal == 1 ) {
        if ( stereo_to_mono ){
            ret += silk_resampler( &channel_state[ 1 ].resampler_state, resample_out_ptr, &samplesOut1_tmp[ 0 ][ 1 ], nSamplesOutDec );
            for( i = 0; i < *nSamplesOut; i++ ) {
                samplesOut[ 1 + 2 * i ] = resample_out_ptr[ i ];
            }
        } else {
            for( i = 0; i < *nSamplesOut; i++ ) {
                samplesOut[ 1 + 2 * i ] = samplesOut[ 0 + 2 * i ];
            }
        }
    }
    if( channel_state[ 0 ].prevSignalType == TYPE_VOICED ) {
        int mult_tab[ 3 ] = { 6, 4, 3 };
        decControl->prevPitchLag = channel_state[ 0 ].lagPrev * mult_tab[ ( channel_state[ 0 ].fs_kHz - 8 ) >> 2 ];
    } else {
        decControl->prevPitchLag = 0;
    }
    if( lostFlag == FLAG_PACKET_LOST ) {
       for ( i = 0; i < psDec->nChannelsInternal; i++ )
          psDec->channel_state[ i ].LastGainIndex = 10;
    } else {
       psDec->prev_decode_only_middle = decode_only_middle;
    }
    return ret;
}

void silk_decode_core(
    silk_decoder_state          *psDec,
    silk_decoder_control        *psDecCtrl,
    opus_int16                  xq[],
    const opus_int              pulses[ MAX_FRAME_LENGTH ]
)
{
    opus_int   i, k, lag = 0, start_idx, sLTP_buf_idx, NLSF_interpolation_flag, signalType;
    opus_int16 *A_Q12, *B_Q14, *pxq, A_Q12_tmp[ MAX_LPC_ORDER ];
    opus_int16 sLTP[ MAX_FRAME_LENGTH ];
    opus_int32 sLTP_Q15[ 2 * MAX_FRAME_LENGTH ];
    opus_int32 LTP_pred_Q13, LPC_pred_Q10, Gain_Q10, inv_gain_Q31, gain_adj_Q16, rand_seed, offset_Q10;
    opus_int32 *pred_lag_ptr, *pexc_Q14, *pres_Q14;
    opus_int32 res_Q14[ MAX_SUB_FRAME_LENGTH ];
    opus_int32 sLPC_Q14[ MAX_SUB_FRAME_LENGTH + MAX_LPC_ORDER ];
    silk_assert( psDec->prev_gain_Q16 != 0 );
    offset_Q10 = silk_Quantization_Offsets_Q10[ psDec->indices.signalType >> 1 ][ psDec->indices.quantOffsetType ];
    if( psDec->indices.NLSFInterpCoef_Q2 < 1 << 2 ) {
        NLSF_interpolation_flag = 1;
    } else {
        NLSF_interpolation_flag = 0;
    }
    rand_seed = psDec->indices.Seed;
    for( i = 0; i < psDec->frame_length; i++ ) {
        rand_seed = silk_RAND( rand_seed );
        psDec->exc_Q14[ i ] = silk_LSHIFT( (opus_int32)pulses[ i ], 14 );
        if( psDec->exc_Q14[ i ] > 0 ) {
            psDec->exc_Q14[ i ] -= QUANT_LEVEL_ADJUST_Q10 << 4;
        } else
        if( psDec->exc_Q14[ i ] < 0 ) {
            psDec->exc_Q14[ i ] += QUANT_LEVEL_ADJUST_Q10 << 4;
        }
        psDec->exc_Q14[ i ] += offset_Q10 << 4;
        if( rand_seed < 0 ) {
           psDec->exc_Q14[ i ] = -psDec->exc_Q14[ i ];
        }
        rand_seed = silk_ADD32_ovflw( rand_seed, pulses[ i ] );
    }
    silk_memcpy( sLPC_Q14, psDec->sLPC_Q14_buf, MAX_LPC_ORDER * sizeof( opus_int32 ) );
    pexc_Q14 = psDec->exc_Q14;
    pxq      = xq;
    sLTP_buf_idx = psDec->ltp_mem_length;
    for( k = 0; k < psDec->nb_subfr; k++ ) {
        pres_Q14 = res_Q14;
        A_Q12 = psDecCtrl->PredCoef_Q12[ k >> 1 ];
        silk_memcpy( A_Q12_tmp, A_Q12, psDec->LPC_order * sizeof( opus_int16 ) );
        B_Q14        = &psDecCtrl->LTPCoef_Q14[ k * LTP_ORDER ];
        signalType   = psDec->indices.signalType;
        Gain_Q10     = silk_RSHIFT( psDecCtrl->Gains_Q16[ k ], 6 );
        inv_gain_Q31 = silk_INVERSE32_varQ( psDecCtrl->Gains_Q16[ k ], 47 );
        if( psDecCtrl->Gains_Q16[ k ] != psDec->prev_gain_Q16 ) {
            gain_adj_Q16 =  silk_DIV32_varQ( psDec->prev_gain_Q16, psDecCtrl->Gains_Q16[ k ], 16 );
            for( i = 0; i < MAX_LPC_ORDER; i++ ) {
                sLPC_Q14[ i ] = silk_SMULWW( gain_adj_Q16, sLPC_Q14[ i ] );
            }
        } else {
            gain_adj_Q16 = 1 << 16;
        }
        silk_assert( inv_gain_Q31 != 0 );
        psDec->prev_gain_Q16 = psDecCtrl->Gains_Q16[ k ];
        if( psDec->lossCnt && psDec->prevSignalType == TYPE_VOICED &&
            psDec->indices.signalType != TYPE_VOICED && k < MAX_NB_SUBFR/2 ) {
            silk_memset( B_Q14, 0, LTP_ORDER * sizeof( opus_int16 ) );
            B_Q14[ LTP_ORDER/2 ] = SILK_FIX_CONST( 0.25, 14 );
            signalType = TYPE_VOICED;
            psDecCtrl->pitchL[ k ] = psDec->lagPrev;
        }
        if( signalType == TYPE_VOICED ) {
            lag = psDecCtrl->pitchL[ k ];
            if( k == 0 || ( k == 2 && NLSF_interpolation_flag ) ) {
                start_idx = psDec->ltp_mem_length - lag - psDec->LPC_order - LTP_ORDER / 2;
                silk_assert( start_idx > 0 );
                if( k == 2 ) {
                    silk_memcpy( &psDec->outBuf[ psDec->ltp_mem_length ], xq, 2 * psDec->subfr_length * sizeof( opus_int16 ) );
                }
                silk_LPC_analysis_filter( &sLTP[ start_idx ], &psDec->outBuf[ start_idx + k * psDec->subfr_length ],
                    A_Q12, psDec->ltp_mem_length - start_idx, psDec->LPC_order );
                if( k == 0 ) {
                    inv_gain_Q31 = silk_LSHIFT( silk_SMULWB( inv_gain_Q31, psDecCtrl->LTP_scale_Q14 ), 2 );
                }
                for( i = 0; i < lag + LTP_ORDER/2; i++ ) {
                    sLTP_Q15[ sLTP_buf_idx - i - 1 ] = silk_SMULWB( inv_gain_Q31, sLTP[ psDec->ltp_mem_length - i - 1 ] );
                }
            } else {
                if( gain_adj_Q16 != 1 << 16 ) {
                    for( i = 0; i < lag + LTP_ORDER/2; i++ ) {
                        sLTP_Q15[ sLTP_buf_idx - i - 1 ] = silk_SMULWW( gain_adj_Q16, sLTP_Q15[ sLTP_buf_idx - i - 1 ] );
                    }
                }
            }
        }
        if( signalType == TYPE_VOICED ) {
            pred_lag_ptr = &sLTP_Q15[ sLTP_buf_idx - lag + LTP_ORDER / 2 ];
            for( i = 0; i < psDec->subfr_length; i++ ) {
                LTP_pred_Q13 = 2;
                LTP_pred_Q13 = silk_SMLAWB( LTP_pred_Q13, pred_lag_ptr[  0 ], B_Q14[ 0 ] );
                LTP_pred_Q13 = silk_SMLAWB( LTP_pred_Q13, pred_lag_ptr[ -1 ], B_Q14[ 1 ] );
                LTP_pred_Q13 = silk_SMLAWB( LTP_pred_Q13, pred_lag_ptr[ -2 ], B_Q14[ 2 ] );
                LTP_pred_Q13 = silk_SMLAWB( LTP_pred_Q13, pred_lag_ptr[ -3 ], B_Q14[ 3 ] );
                LTP_pred_Q13 = silk_SMLAWB( LTP_pred_Q13, pred_lag_ptr[ -4 ], B_Q14[ 4 ] );
                pred_lag_ptr++;
                pres_Q14[ i ] = silk_ADD_LSHIFT32( pexc_Q14[ i ], LTP_pred_Q13, 1 );
                sLTP_Q15[ sLTP_buf_idx ] = silk_LSHIFT( pres_Q14[ i ], 1 );
                sLTP_buf_idx++;
            }
        } else {
            pres_Q14 = pexc_Q14;
        }
        for( i = 0; i < psDec->subfr_length; i++ ) {
            silk_assert( psDec->LPC_order == 10 || psDec->LPC_order == 16 );
            LPC_pred_Q10 = silk_RSHIFT( psDec->LPC_order, 1 );
            LPC_pred_Q10 = silk_SMLAWB( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i -  1 ], A_Q12_tmp[ 0 ] );
            LPC_pred_Q10 = silk_SMLAWB( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i -  2 ], A_Q12_tmp[ 1 ] );
            LPC_pred_Q10 = silk_SMLAWB( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i -  3 ], A_Q12_tmp[ 2 ] );
            LPC_pred_Q10 = silk_SMLAWB( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i -  4 ], A_Q12_tmp[ 3 ] );
            LPC_pred_Q10 = silk_SMLAWB( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i -  5 ], A_Q12_tmp[ 4 ] );
            LPC_pred_Q10 = silk_SMLAWB( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i -  6 ], A_Q12_tmp[ 5 ] );
            LPC_pred_Q10 = silk_SMLAWB( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i -  7 ], A_Q12_tmp[ 6 ] );
            LPC_pred_Q10 = silk_SMLAWB( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i -  8 ], A_Q12_tmp[ 7 ] );
            LPC_pred_Q10 = silk_SMLAWB( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i -  9 ], A_Q12_tmp[ 8 ] );
            LPC_pred_Q10 = silk_SMLAWB( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i - 10 ], A_Q12_tmp[ 9 ] );
            if( psDec->LPC_order == 16 ) {
                LPC_pred_Q10 = silk_SMLAWB( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i - 11 ], A_Q12_tmp[ 10 ] );
                LPC_pred_Q10 = silk_SMLAWB( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i - 12 ], A_Q12_tmp[ 11 ] );
                LPC_pred_Q10 = silk_SMLAWB( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i - 13 ], A_Q12_tmp[ 12 ] );
                LPC_pred_Q10 = silk_SMLAWB( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i - 14 ], A_Q12_tmp[ 13 ] );
                LPC_pred_Q10 = silk_SMLAWB( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i - 15 ], A_Q12_tmp[ 14 ] );
                LPC_pred_Q10 = silk_SMLAWB( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i - 16 ], A_Q12_tmp[ 15 ] );
            }
            sLPC_Q14[ MAX_LPC_ORDER + i ] = silk_ADD_LSHIFT32( pres_Q14[ i ], LPC_pred_Q10, 4 );
            pxq[ i ] = (opus_int16)silk_SAT16( silk_RSHIFT_ROUND( silk_SMULWW( sLPC_Q14[ MAX_LPC_ORDER + i ], Gain_Q10 ), 8 ) );
        }
        silk_memcpy( sLPC_Q14, &sLPC_Q14[ psDec->subfr_length ], MAX_LPC_ORDER * sizeof( opus_int32 ) );
        pexc_Q14 += psDec->subfr_length;
        pxq      += psDec->subfr_length;
    }
    silk_memcpy( psDec->sLPC_Q14_buf, sLPC_Q14, MAX_LPC_ORDER * sizeof( opus_int32 ) );
}

opus_int silk_decode_frame(
    silk_decoder_state          *psDec,
    ec_dec                      *psRangeDec,
    opus_int16                  pOut[],
    opus_int32                  *pN,
    opus_int                    lostFlag,
    opus_int                    condCoding
)
{
    silk_decoder_control sDecCtrl;
    opus_int         L, mv_len, ret = 0;
    opus_int         pulses[ MAX_FRAME_LENGTH ];
    L = psDec->frame_length;
    sDecCtrl.LTP_scale_Q14 = 0;
    silk_assert( L > 0 && L <= MAX_FRAME_LENGTH );
    if(   lostFlag == FLAG_DECODE_NORMAL ||
        ( lostFlag == FLAG_DECODE_LBRR && psDec->LBRR_flags[ psDec->nFramesDecoded ] == 1 ) )
    {
        silk_decode_indices( psDec, psRangeDec, psDec->nFramesDecoded, lostFlag, condCoding );
        silk_decode_pulses( psRangeDec, pulses, psDec->indices.signalType,
                psDec->indices.quantOffsetType, psDec->frame_length );
        silk_decode_parameters( psDec, &sDecCtrl, condCoding );
        L = psDec->frame_length;
        silk_decode_core( psDec, &sDecCtrl, pOut, pulses );
        silk_PLC( psDec, &sDecCtrl, pOut, 0 );
        psDec->lossCnt = 0;
        psDec->prevSignalType = psDec->indices.signalType;
        silk_assert( psDec->prevSignalType >= 0 && psDec->prevSignalType <= 2 );
        psDec->first_frame_after_reset = 0;
    } else {
        silk_PLC( psDec, &sDecCtrl, pOut, 1 );
    }
    silk_assert( psDec->ltp_mem_length >= psDec->frame_length );
    mv_len = psDec->ltp_mem_length - psDec->frame_length;
    silk_memmove( psDec->outBuf, &psDec->outBuf[ psDec->frame_length ], mv_len * sizeof(opus_int16) );
    silk_memcpy( &psDec->outBuf[ mv_len ], pOut, psDec->frame_length * sizeof( opus_int16 ) );
    silk_PLC_glue_frames( psDec, pOut, L );
    silk_CNG( psDec, &sDecCtrl, pOut, L );
    psDec->lagPrev = sDecCtrl.pitchL[ psDec->nb_subfr - 1 ];
    *pN = L;
    return ret;
}

void silk_decode_indices(
    silk_decoder_state          *psDec,
    ec_dec                      *psRangeDec,
    opus_int                    FrameIndex,
    opus_int                    decode_LBRR,
    opus_int                    condCoding
)
{
    opus_int   i, k, Ix;
    opus_int   decode_absolute_lagIndex, delta_lagIndex;
    opus_int16 ec_ix[ MAX_LPC_ORDER ];
    opus_uint8 pred_Q8[ MAX_LPC_ORDER ];
    if( decode_LBRR || psDec->VAD_flags[ FrameIndex ] ) {
        Ix = ec_dec_icdf( psRangeDec, silk_type_offset_VAD_iCDF, 8 ) + 2;
    } else {
        Ix = ec_dec_icdf( psRangeDec, silk_type_offset_no_VAD_iCDF, 8 );
    }
    psDec->indices.signalType      = (opus_int8)silk_RSHIFT( Ix, 1 );
    psDec->indices.quantOffsetType = (opus_int8)( Ix & 1 );
    if( condCoding == CODE_CONDITIONALLY ) {
        psDec->indices.GainsIndices[ 0 ] = (opus_int8)ec_dec_icdf( psRangeDec, silk_delta_gain_iCDF, 8 );
    } else {
        psDec->indices.GainsIndices[ 0 ]  = (opus_int8)silk_LSHIFT( ec_dec_icdf( psRangeDec, silk_gain_iCDF[ psDec->indices.signalType ], 8 ), 3 );
        psDec->indices.GainsIndices[ 0 ] += (opus_int8)ec_dec_icdf( psRangeDec, silk_uniform8_iCDF, 8 );
    }
    for( i = 1; i < psDec->nb_subfr; i++ ) {
        psDec->indices.GainsIndices[ i ] = (opus_int8)ec_dec_icdf( psRangeDec, silk_delta_gain_iCDF, 8 );
    }
    psDec->indices.NLSFIndices[ 0 ] = (opus_int8)ec_dec_icdf( psRangeDec, &psDec->psNLSF_CB->CB1_iCDF[ ( psDec->indices.signalType >> 1 ) * psDec->psNLSF_CB->nVectors ], 8 );
    silk_NLSF_unpack( ec_ix, pred_Q8, psDec->psNLSF_CB, psDec->indices.NLSFIndices[ 0 ] );
    silk_assert( psDec->psNLSF_CB->order == psDec->LPC_order );
    for( i = 0; i < psDec->psNLSF_CB->order; i++ ) {
        Ix = ec_dec_icdf( psRangeDec, &psDec->psNLSF_CB->ec_iCDF[ ec_ix[ i ] ], 8 );
        if( Ix == 0 ) {
            Ix -= ec_dec_icdf( psRangeDec, silk_NLSF_EXT_iCDF, 8 );
        } else if( Ix == 2 * NLSF_QUANT_MAX_AMPLITUDE ) {
            Ix += ec_dec_icdf( psRangeDec, silk_NLSF_EXT_iCDF, 8 );
        }
        psDec->indices.NLSFIndices[ i+1 ] = (opus_int8)( Ix - NLSF_QUANT_MAX_AMPLITUDE );
    }
    if( psDec->nb_subfr == MAX_NB_SUBFR ) {
        psDec->indices.NLSFInterpCoef_Q2 = (opus_int8)ec_dec_icdf( psRangeDec, silk_NLSF_interpolation_factor_iCDF, 8 );
    } else {
        psDec->indices.NLSFInterpCoef_Q2 = 4;
    }
    if( psDec->indices.signalType == TYPE_VOICED )
    {
        decode_absolute_lagIndex = 1;
        if( condCoding == CODE_CONDITIONALLY && psDec->ec_prevSignalType == TYPE_VOICED ) {
            delta_lagIndex = (opus_int16)ec_dec_icdf( psRangeDec, silk_pitch_delta_iCDF, 8 );
            if( delta_lagIndex > 0 ) {
                delta_lagIndex = delta_lagIndex - 9;
                psDec->indices.lagIndex = (opus_int16)( psDec->ec_prevLagIndex + delta_lagIndex );
                decode_absolute_lagIndex = 0;
            }
        }
        if( decode_absolute_lagIndex ) {
            psDec->indices.lagIndex  = (opus_int16)ec_dec_icdf( psRangeDec, silk_pitch_lag_iCDF, 8 ) * silk_RSHIFT( psDec->fs_kHz, 1 );
            psDec->indices.lagIndex += (opus_int16)ec_dec_icdf( psRangeDec, psDec->pitch_lag_low_bits_iCDF, 8 );
        }
        psDec->ec_prevLagIndex = psDec->indices.lagIndex;
        psDec->indices.contourIndex = (opus_int8)ec_dec_icdf( psRangeDec, psDec->pitch_contour_iCDF, 8 );
        psDec->indices.PERIndex = (opus_int8)ec_dec_icdf( psRangeDec, silk_LTP_per_index_iCDF, 8 );
        for( k = 0; k < psDec->nb_subfr; k++ ) {
            psDec->indices.LTPIndex[ k ] = (opus_int8)ec_dec_icdf( psRangeDec, silk_LTP_gain_iCDF_ptrs[ psDec->indices.PERIndex ], 8 );
        }
        if( condCoding == CODE_INDEPENDENTLY ) {
            psDec->indices.LTP_scaleIndex = (opus_int8)ec_dec_icdf( psRangeDec, silk_LTPscale_iCDF, 8 );
        } else {
            psDec->indices.LTP_scaleIndex = 0;
        }
    }
    psDec->ec_prevSignalType = psDec->indices.signalType;
    psDec->indices.Seed = (opus_int8)ec_dec_icdf( psRangeDec, silk_uniform4_iCDF, 8 );
}

void silk_decode_parameters(
    silk_decoder_state          *psDec,
    silk_decoder_control        *psDecCtrl,
    opus_int                    condCoding
)
{
    opus_int   i, k, Ix;
    opus_int16 pNLSF_Q15[ MAX_LPC_ORDER ], pNLSF0_Q15[ MAX_LPC_ORDER ];
    const opus_int8 *cbk_ptr_Q7;
    silk_gains_dequant( psDecCtrl->Gains_Q16, psDec->indices.GainsIndices,
        &psDec->LastGainIndex, condCoding == CODE_CONDITIONALLY, psDec->nb_subfr );
    silk_NLSF_decode( pNLSF_Q15, psDec->indices.NLSFIndices, psDec->psNLSF_CB );
    silk_NLSF2A( psDecCtrl->PredCoef_Q12[ 1 ], pNLSF_Q15, psDec->LPC_order );
    if( psDec->first_frame_after_reset == 1 ) {
        psDec->indices.NLSFInterpCoef_Q2 = 4;
    }
    if( psDec->indices.NLSFInterpCoef_Q2 < 4 ) {
        for( i = 0; i < psDec->LPC_order; i++ ) {
            pNLSF0_Q15[ i ] = psDec->prevNLSF_Q15[ i ] + silk_RSHIFT( silk_MUL( psDec->indices.NLSFInterpCoef_Q2,
                pNLSF_Q15[ i ] - psDec->prevNLSF_Q15[ i ] ), 2 );
        }
        silk_NLSF2A( psDecCtrl->PredCoef_Q12[ 0 ], pNLSF0_Q15, psDec->LPC_order );
    } else {
        silk_memcpy( psDecCtrl->PredCoef_Q12[ 0 ], psDecCtrl->PredCoef_Q12[ 1 ], psDec->LPC_order * sizeof( opus_int16 ) );
    }
    silk_memcpy( psDec->prevNLSF_Q15, pNLSF_Q15, psDec->LPC_order * sizeof( opus_int16 ) );
    if( psDec->lossCnt ) {
        silk_bwexpander( psDecCtrl->PredCoef_Q12[ 0 ], psDec->LPC_order, BWE_AFTER_LOSS_Q16 );
        silk_bwexpander( psDecCtrl->PredCoef_Q12[ 1 ], psDec->LPC_order, BWE_AFTER_LOSS_Q16 );
    }
    if( psDec->indices.signalType == TYPE_VOICED ) {
        silk_decode_pitch( psDec->indices.lagIndex, psDec->indices.contourIndex, psDecCtrl->pitchL, psDec->fs_kHz, psDec->nb_subfr );
        cbk_ptr_Q7 = silk_LTP_vq_ptrs_Q7[ psDec->indices.PERIndex ];
        for( k = 0; k < psDec->nb_subfr; k++ ) {
            Ix = psDec->indices.LTPIndex[ k ];
            for( i = 0; i < LTP_ORDER; i++ ) {
                psDecCtrl->LTPCoef_Q14[ k * LTP_ORDER + i ] = silk_LSHIFT( cbk_ptr_Q7[ Ix * LTP_ORDER + i ], 7 );
            }
        }
        Ix = psDec->indices.LTP_scaleIndex;
        psDecCtrl->LTP_scale_Q14 = silk_LTPScales_table_Q14[ Ix ];
    } else {
        silk_memset( psDecCtrl->pitchL,      0,             psDec->nb_subfr * sizeof( opus_int   ) );
        silk_memset( psDecCtrl->LTPCoef_Q14, 0, LTP_ORDER * psDec->nb_subfr * sizeof( opus_int16 ) );
        psDec->indices.PERIndex  = 0;
        psDecCtrl->LTP_scale_Q14 = 0;
    }
}

#define PE_MAX_NB_SUBFR             4
#define PE_MAX_LAG_MS               18
#define PE_MIN_LAG_MS               2
#define PE_NB_CBKS_STAGE2_EXT       11
#define PE_NB_CBKS_STAGE3_MAX       34
#define PE_NB_CBKS_STAGE3_10MS      12
#define PE_NB_CBKS_STAGE2_10MS      3
extern const opus_int8 silk_CB_lags_stage2[ PE_MAX_NB_SUBFR ][ PE_NB_CBKS_STAGE2_EXT ];
extern const opus_int8 silk_CB_lags_stage3[ PE_MAX_NB_SUBFR ][ PE_NB_CBKS_STAGE3_MAX ];
extern const opus_int8 silk_CB_lags_stage2_10_ms[ PE_MAX_NB_SUBFR >> 1][ 3 ];
extern const opus_int8 silk_CB_lags_stage3_10_ms[ PE_MAX_NB_SUBFR >> 1 ][ 12 ];

void silk_decode_pitch(
    opus_int16                  lagIndex,
    opus_int8                   contourIndex,
    opus_int                    pitch_lags[],
    const opus_int              Fs_kHz,
    const opus_int              nb_subfr
)
{
    opus_int   lag, k, min_lag, max_lag, cbk_size;
    const opus_int8 *Lag_CB_ptr;
    if( Fs_kHz == 8 ) {
        if( nb_subfr == PE_MAX_NB_SUBFR ) {
            Lag_CB_ptr = &silk_CB_lags_stage2[ 0 ][ 0 ];
            cbk_size   = PE_NB_CBKS_STAGE2_EXT;
        } else {
            silk_assert( nb_subfr == PE_MAX_NB_SUBFR >> 1 );
            Lag_CB_ptr = &silk_CB_lags_stage2_10_ms[ 0 ][ 0 ];
            cbk_size   = PE_NB_CBKS_STAGE2_10MS;
        }
    } else {
        if( nb_subfr == PE_MAX_NB_SUBFR ) {
            Lag_CB_ptr = &silk_CB_lags_stage3[ 0 ][ 0 ];
            cbk_size   = PE_NB_CBKS_STAGE3_MAX;
        } else {
            silk_assert( nb_subfr == PE_MAX_NB_SUBFR >> 1 );
            Lag_CB_ptr = &silk_CB_lags_stage3_10_ms[ 0 ][ 0 ];
            cbk_size   = PE_NB_CBKS_STAGE3_10MS;
        }
    }
    min_lag = silk_SMULBB( PE_MIN_LAG_MS, Fs_kHz );
    max_lag = silk_SMULBB( PE_MAX_LAG_MS, Fs_kHz );
    lag = min_lag + lagIndex;
    for( k = 0; k < nb_subfr; k++ ) {
        pitch_lags[ k ] = lag + matrix_ptr( Lag_CB_ptr, k, contourIndex, cbk_size );
        pitch_lags[ k ] = silk_LIMIT( pitch_lags[ k ], min_lag, max_lag );
    }
}

void silk_decode_pulses(
    ec_dec                      *psRangeDec,
    opus_int                    pulses[],
    const opus_int              signalType,
    const opus_int              quantOffsetType,
    const opus_int              frame_length
)
{
    opus_int   i, j, k, iter, abs_q, nLS, RateLevelIndex;
    opus_int   sum_pulses[ MAX_NB_SHELL_BLOCKS ], nLshifts[ MAX_NB_SHELL_BLOCKS ];
    opus_int   *pulses_ptr;
    const opus_uint8 *cdf_ptr;
    RateLevelIndex = ec_dec_icdf( psRangeDec, silk_rate_levels_iCDF[ signalType >> 1 ], 8 );
    silk_assert( 1 << LOG2_SHELL_CODEC_FRAME_LENGTH == SHELL_CODEC_FRAME_LENGTH );
    iter = silk_RSHIFT( frame_length, LOG2_SHELL_CODEC_FRAME_LENGTH );
    if( iter * SHELL_CODEC_FRAME_LENGTH < frame_length ) {
        silk_assert( frame_length == 12 * 10 );
        iter++;
    }
    cdf_ptr = silk_pulses_per_block_iCDF[ RateLevelIndex ];
    for( i = 0; i < iter; i++ ) {
        nLshifts[ i ] = 0;
        sum_pulses[ i ] = ec_dec_icdf( psRangeDec, cdf_ptr, 8 );
        while( sum_pulses[ i ] == MAX_PULSES + 1 ) {
            nLshifts[ i ]++;
            sum_pulses[ i ] = ec_dec_icdf( psRangeDec,
                    silk_pulses_per_block_iCDF[ N_RATE_LEVELS - 1] + ( nLshifts[ i ] == 10 ), 8 );
        }
    }
    for( i = 0; i < iter; i++ ) {
        if( sum_pulses[ i ] > 0 ) {
            silk_shell_decoder( &pulses[ silk_SMULBB( i, SHELL_CODEC_FRAME_LENGTH ) ], psRangeDec, sum_pulses[ i ] );
        } else {
            silk_memset( &pulses[ silk_SMULBB( i, SHELL_CODEC_FRAME_LENGTH ) ], 0, SHELL_CODEC_FRAME_LENGTH * sizeof( opus_int ) );
        }
    }
    for( i = 0; i < iter; i++ ) {
        if( nLshifts[ i ] > 0 ) {
            nLS = nLshifts[ i ];
            pulses_ptr = &pulses[ silk_SMULBB( i, SHELL_CODEC_FRAME_LENGTH ) ];
            for( k = 0; k < SHELL_CODEC_FRAME_LENGTH; k++ ) {
                abs_q = pulses_ptr[ k ];
                for( j = 0; j < nLS; j++ ) {
                    abs_q = silk_LSHIFT( abs_q, 1 );
                    abs_q += ec_dec_icdf( psRangeDec, silk_lsb_iCDF, 8 );
                }
                pulses_ptr[ k ] = abs_q;
            }
            sum_pulses[ i ] |= nLS << 5;
        }
    }
    silk_decode_signs( psRangeDec, pulses, frame_length, signalType, quantOffsetType, sum_pulses );
}

opus_int silk_decoder_set_fs(
    silk_decoder_state          *psDec,
    opus_int                    fs_kHz,
    opus_int                    fs_API_Hz
)
{
    opus_int frame_length, ret = 0;
    silk_assert( fs_kHz == 8 || fs_kHz == 12 || fs_kHz == 16 );
    silk_assert( psDec->nb_subfr == MAX_NB_SUBFR || psDec->nb_subfr == MAX_NB_SUBFR/2 );
    psDec->subfr_length = silk_SMULBB( SUB_FRAME_LENGTH_MS, fs_kHz );
    frame_length = silk_SMULBB( psDec->nb_subfr, psDec->subfr_length );
    if( psDec->fs_kHz != fs_kHz || psDec->fs_API_hz != fs_API_Hz ) {
        ret += silk_resampler_init( &psDec->resampler_state, silk_SMULBB( fs_kHz, 1000 ), fs_API_Hz, 0 );
        psDec->fs_API_hz = fs_API_Hz;
    }
    if( psDec->fs_kHz != fs_kHz || frame_length != psDec->frame_length ) {
        if( fs_kHz == 8 ) {
            if( psDec->nb_subfr == MAX_NB_SUBFR ) {
                psDec->pitch_contour_iCDF = silk_pitch_contour_NB_iCDF;
            } else {
                psDec->pitch_contour_iCDF = silk_pitch_contour_10_ms_NB_iCDF;
            }
        } else {
            if( psDec->nb_subfr == MAX_NB_SUBFR ) {
                psDec->pitch_contour_iCDF = silk_pitch_contour_iCDF;
            } else {
                psDec->pitch_contour_iCDF = silk_pitch_contour_10_ms_iCDF;
            }
        }
        if( psDec->fs_kHz != fs_kHz ) {
            psDec->ltp_mem_length = silk_SMULBB( LTP_MEM_LENGTH_MS, fs_kHz );
            if( fs_kHz == 8 || fs_kHz == 12 ) {
                psDec->LPC_order = MIN_LPC_ORDER;
                psDec->psNLSF_CB = &silk_NLSF_CB_NB_MB;
            } else {
                psDec->LPC_order = MAX_LPC_ORDER;
                psDec->psNLSF_CB = &silk_NLSF_CB_WB;
            }
            if( fs_kHz == 16 ) {
                psDec->pitch_lag_low_bits_iCDF = silk_uniform8_iCDF;
            } else if( fs_kHz == 12 ) {
                psDec->pitch_lag_low_bits_iCDF = silk_uniform6_iCDF;
            } else if( fs_kHz == 8 ) {
                psDec->pitch_lag_low_bits_iCDF = silk_uniform4_iCDF;
            } else {
                silk_assert( 0 );
            }
            psDec->first_frame_after_reset = 1;
            psDec->lagPrev                 = 100;
            psDec->LastGainIndex           = 10;
            psDec->prevSignalType          = TYPE_NO_VOICE_ACTIVITY;
            silk_memset( psDec->outBuf, 0, sizeof(psDec->outBuf));
            silk_memset( psDec->sLPC_Q14_buf, 0, sizeof(psDec->sLPC_Q14_buf) );
        }
        psDec->fs_kHz       = fs_kHz;
        psDec->frame_length = frame_length;
    }
    silk_assert( psDec->frame_length > 0 && psDec->frame_length <= MAX_FRAME_LENGTH );
    return ret;
}

#define OFFSET                  ( ( MIN_QGAIN_DB * 128 ) / 6 + 16 * 128 )
#define INV_SCALE_Q16           ( ( 65536 * ( ( ( MAX_QGAIN_DB - MIN_QGAIN_DB ) * 128 ) / 6 ) ) / ( N_LEVELS_QGAIN - 1 ) )
void silk_gains_dequant(
    opus_int32                  gain_Q16[ MAX_NB_SUBFR ],
    const opus_int8             ind[ MAX_NB_SUBFR ],
    opus_int8                   *prev_ind,
    const opus_int              conditional,
    const opus_int              nb_subfr
)
{
    opus_int   k, ind_tmp, double_step_size_threshold;
    for( k = 0; k < nb_subfr; k++ ) {
        if( k == 0 && conditional == 0 ) {
            *prev_ind = silk_max_int( ind[ k ], *prev_ind - 16 );
        } else {
            ind_tmp = ind[ k ] + MIN_DELTA_GAIN_QUANT;
            double_step_size_threshold = 2 * MAX_DELTA_GAIN_QUANT - N_LEVELS_QGAIN + *prev_ind;
            if( ind_tmp > double_step_size_threshold ) {
                *prev_ind += silk_LSHIFT( ind_tmp, 1 ) - double_step_size_threshold;
            } else {
                *prev_ind += ind_tmp;
            }
        }
        *prev_ind = silk_LIMIT_int( *prev_ind, 0, N_LEVELS_QGAIN - 1 );
        gain_Q16[ k ] = silk_log2lin( silk_min_32( silk_SMULWB( INV_SCALE_Q16, *prev_ind ) + OFFSET, 3967 ) );
    }
}

opus_int silk_init_decoder(
    silk_decoder_state          *psDec
)
{
    silk_memset( psDec, 0, sizeof( silk_decoder_state ) );
    psDec->first_frame_after_reset = 1;
    psDec->prev_gain_Q16 = 65536;
    silk_CNG_Reset( psDec );
    silk_PLC_Reset( psDec );
    return(0);
}

opus_int32 silk_log2lin(
    const opus_int32            inLog_Q7
)
{
    opus_int32 out, frac_Q7;
    if( inLog_Q7 < 0 ) {
        return 0;
    }
    out = silk_LSHIFT( 1, silk_RSHIFT( inLog_Q7, 7 ) );
    frac_Q7 = inLog_Q7 & 0x7F;
    if( inLog_Q7 < 2048 ) {
        out = silk_ADD_RSHIFT( out, silk_MUL( out, silk_SMLAWB( frac_Q7, silk_SMULBB( frac_Q7, 128 - frac_Q7 ), -174 ) ), 7 );
    } else {
        out = silk_MLA( out, silk_RSHIFT( out, 7 ), silk_SMLAWB( frac_Q7, silk_SMULBB( frac_Q7, 128 - frac_Q7 ), -174 ) );
    }
    return out;
}

const opus_int8 silk_CB_lags_stage2_10_ms[ PE_MAX_NB_SUBFR >> 1][ PE_NB_CBKS_STAGE2_10MS ] =
{
    {0, 1, 0},
    {0, 0, 1}
};
const opus_int8 silk_CB_lags_stage3_10_ms[ PE_MAX_NB_SUBFR >> 1 ][ PE_NB_CBKS_STAGE3_10MS ] =
{
    { 0, 0, 1,-1, 1,-1, 2,-2, 2,-2, 3,-3},
    { 0, 1, 0, 1,-1, 2,-1, 2,-2, 3,-2, 3}
};
const opus_int8 silk_CB_lags_stage2[ PE_MAX_NB_SUBFR ][ PE_NB_CBKS_STAGE2_EXT ] =
{
    {0, 2,-1,-1,-1, 0, 0, 1, 1, 0, 1},
    {0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0},
    {0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0},
    {0,-1, 2, 1, 0, 1, 1, 0, 0,-1,-1}
};
const opus_int8 silk_CB_lags_stage3[ PE_MAX_NB_SUBFR ][ PE_NB_CBKS_STAGE3_MAX ] =
{
    {0, 0, 1,-1, 0, 1,-1, 0,-1, 1,-2, 2,-2,-2, 2,-3, 2, 3,-3,-4, 3,-4, 4, 4,-5, 5,-6,-5, 6,-7, 6, 5, 8,-9},
    {0, 0, 1, 0, 0, 0, 0, 0, 0, 0,-1, 1, 0, 0, 1,-1, 0, 1,-1,-1, 1,-1, 2, 1,-1, 2,-2,-2, 2,-2, 2, 2, 3,-3},
    {0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 1,-1, 1, 0, 0, 2, 1,-1, 2,-1,-1, 2,-1, 2, 2,-1, 3,-2,-2,-2, 3},
    {0, 1, 0, 0, 1, 0, 1,-1, 2,-1, 2,-1, 2, 3,-2, 3,-2,-2, 4, 4,-3, 5,-3,-4, 6,-4, 6, 5,-5, 8,-6,-5,-7, 9}
};

#define RESAMPLER_DOWN_ORDER_FIR0               18
#define RESAMPLER_DOWN_ORDER_FIR1               24
#define RESAMPLER_DOWN_ORDER_FIR2               36
#define RESAMPLER_ORDER_FIR_12                  8
extern const opus_int16 silk_resampler_up2_hq_0[ 3 ];
extern const opus_int16 silk_resampler_up2_hq_1[ 3 ];
extern const opus_int16 silk_Resampler_3_4_COEFS[ 2 + 3 * RESAMPLER_DOWN_ORDER_FIR0 / 2 ];
extern const opus_int16 silk_Resampler_2_3_COEFS[ 2 + 2 * RESAMPLER_DOWN_ORDER_FIR0 / 2 ];
extern const opus_int16 silk_Resampler_1_2_COEFS[ 2 +     RESAMPLER_DOWN_ORDER_FIR1 / 2 ];
extern const opus_int16 silk_Resampler_1_3_COEFS[ 2 +     RESAMPLER_DOWN_ORDER_FIR2 / 2 ];
extern const opus_int16 silk_Resampler_1_4_COEFS[ 2 +     RESAMPLER_DOWN_ORDER_FIR2 / 2 ];
extern const opus_int16 silk_Resampler_1_6_COEFS[ 2 +     RESAMPLER_DOWN_ORDER_FIR2 / 2 ];
extern const opus_int16 silk_resampler_frac_FIR_12[ 12 ][ RESAMPLER_ORDER_FIR_12 / 2 ];

#define RESAMPLER_MAX_BATCH_SIZE_MS             10
#define RESAMPLER_MAX_FS_KHZ                    48
#define RESAMPLER_MAX_BATCH_SIZE_IN             ( RESAMPLER_MAX_BATCH_SIZE_MS * RESAMPLER_MAX_FS_KHZ )
void silk_resampler_private_IIR_FIR(
    void                            *SS,
    opus_int16                      out[],
    const opus_int16                in[],
    opus_int32                      inLen
);
void silk_resampler_private_down_FIR(
    void                            *SS,
    opus_int16                      out[],
    const opus_int16                in[],
    opus_int32                      inLen
);
void silk_resampler_private_up2_HQ_wrapper(
    void                            *SS,
    opus_int16                      *out,
    const opus_int16                *in,
    opus_int32                      len
);
void silk_resampler_private_up2_HQ(
    opus_int32                      *S,
    opus_int16                      *out,
    const opus_int16                *in,
    opus_int32                      len
);
void silk_resampler_private_AR2(
    opus_int32                      S[],
    opus_int32                      out_Q8[],
    const opus_int16                in[],
    const opus_int16                A_Q14[],
    opus_int32                      len
);

static const opus_int8 delay_matrix_enc[ 5 ][ 3 ] = {
    {  6,  0,  3 },
    {  0,  7,  3 },
    {  0,  1, 10 },
    {  0,  2,  6 },
    { 18, 10, 12 }
};
static const opus_int8 delay_matrix_dec[ 3 ][ 5 ] = {
    {  4,  0,  2,  0,  0 },
    {  0,  9,  4,  7,  4 },
    {  0,  3, 12,  7,  7 }
};
#define rateID(R) ( ( ( ((R)>>12) - ((R)>16000) ) >> ((R)>24000) ) - 1 )
#define USE_silk_resampler_copy                     (0)
#define USE_silk_resampler_private_up2_HQ_wrapper   (1)
#define USE_silk_resampler_private_IIR_FIR          (2)
#define USE_silk_resampler_private_down_FIR         (3)
opus_int silk_resampler_init(
    silk_resampler_state_struct *S,
    opus_int32                  Fs_Hz_in,
    opus_int32                  Fs_Hz_out,
    opus_int                    forEnc
)
{
    opus_int up2x;
    silk_memset( S, 0, sizeof( silk_resampler_state_struct ) );
    if( forEnc ) {
        if( ( Fs_Hz_in  != 8000 && Fs_Hz_in  != 12000 && Fs_Hz_in  != 16000 && Fs_Hz_in  != 24000 && Fs_Hz_in  != 48000 ) ||
            ( Fs_Hz_out != 8000 && Fs_Hz_out != 12000 && Fs_Hz_out != 16000 ) ) {
            silk_assert( 0 );
            return -1;
        }
        S->inputDelay = delay_matrix_enc[ rateID( Fs_Hz_in ) ][ rateID( Fs_Hz_out ) ];
    } else {
        if( ( Fs_Hz_in  != 8000 && Fs_Hz_in  != 12000 && Fs_Hz_in  != 16000 ) ||
            ( Fs_Hz_out != 8000 && Fs_Hz_out != 12000 && Fs_Hz_out != 16000 && Fs_Hz_out != 24000 && Fs_Hz_out != 48000 ) ) {
            silk_assert( 0 );
            return -1;
        }
        S->inputDelay = delay_matrix_dec[ rateID( Fs_Hz_in ) ][ rateID( Fs_Hz_out ) ];
    }
    S->Fs_in_kHz  = silk_DIV32_16( Fs_Hz_in,  1000 );
    S->Fs_out_kHz = silk_DIV32_16( Fs_Hz_out, 1000 );
    S->batchSize = S->Fs_in_kHz * RESAMPLER_MAX_BATCH_SIZE_MS;
    up2x = 0;
    if( Fs_Hz_out > Fs_Hz_in ) {
        if( Fs_Hz_out == silk_MUL( Fs_Hz_in, 2 ) ) {
            S->resampler_function = USE_silk_resampler_private_up2_HQ_wrapper;
        } else {
            S->resampler_function = USE_silk_resampler_private_IIR_FIR;
            up2x = 1;
        }
    } else if ( Fs_Hz_out < Fs_Hz_in ) {
         S->resampler_function = USE_silk_resampler_private_down_FIR;
        if( silk_MUL( Fs_Hz_out, 4 ) == silk_MUL( Fs_Hz_in, 3 ) ) {
            S->FIR_Fracs = 3;
            S->FIR_Order = RESAMPLER_DOWN_ORDER_FIR0;
            S->Coefs = silk_Resampler_3_4_COEFS;
        } else if( silk_MUL( Fs_Hz_out, 3 ) == silk_MUL( Fs_Hz_in, 2 ) ) {
            S->FIR_Fracs = 2;
            S->FIR_Order = RESAMPLER_DOWN_ORDER_FIR0;
            S->Coefs = silk_Resampler_2_3_COEFS;
        } else if( silk_MUL( Fs_Hz_out, 2 ) == Fs_Hz_in ) {
            S->FIR_Fracs = 1;
            S->FIR_Order = RESAMPLER_DOWN_ORDER_FIR1;
            S->Coefs = silk_Resampler_1_2_COEFS;
        } else if( silk_MUL( Fs_Hz_out, 3 ) == Fs_Hz_in ) {
            S->FIR_Fracs = 1;
            S->FIR_Order = RESAMPLER_DOWN_ORDER_FIR2;
            S->Coefs = silk_Resampler_1_3_COEFS;
        } else if( silk_MUL( Fs_Hz_out, 4 ) == Fs_Hz_in ) {
            S->FIR_Fracs = 1;
            S->FIR_Order = RESAMPLER_DOWN_ORDER_FIR2;
            S->Coefs = silk_Resampler_1_4_COEFS;
        } else if( silk_MUL( Fs_Hz_out, 6 ) == Fs_Hz_in ) {
            S->FIR_Fracs = 1;
            S->FIR_Order = RESAMPLER_DOWN_ORDER_FIR2;
            S->Coefs = silk_Resampler_1_6_COEFS;
        } else {
            silk_assert( 0 );
            return -1;
        }
    } else {
        S->resampler_function = USE_silk_resampler_copy;
    }
    S->invRatio_Q16 = silk_LSHIFT32( silk_DIV32( silk_LSHIFT32( Fs_Hz_in, 14 + up2x ), Fs_Hz_out ), 2 );
    while( silk_SMULWW( S->invRatio_Q16, Fs_Hz_out ) < silk_LSHIFT32( Fs_Hz_in, up2x ) ) {
        S->invRatio_Q16++;
    }
    return 0;
}
opus_int silk_resampler(
    silk_resampler_state_struct *S,
    opus_int16                  out[],
    const opus_int16            in[],
    opus_int32                  inLen
)
{
    opus_int nSamples;
    silk_assert( inLen >= S->Fs_in_kHz );
    silk_assert( S->inputDelay <= S->Fs_in_kHz );
    nSamples = S->Fs_in_kHz - S->inputDelay;
    silk_memcpy( &S->delayBuf[ S->inputDelay ], in, nSamples * sizeof( opus_int16 ) );
    switch( S->resampler_function ) {
        case USE_silk_resampler_private_up2_HQ_wrapper:
            silk_resampler_private_up2_HQ_wrapper( S, out, S->delayBuf, S->Fs_in_kHz );
            silk_resampler_private_up2_HQ_wrapper( S, &out[ S->Fs_out_kHz ], &in[ nSamples ], inLen - S->Fs_in_kHz );
            break;
        case USE_silk_resampler_private_IIR_FIR:
            silk_resampler_private_IIR_FIR( S, out, S->delayBuf, S->Fs_in_kHz );
            silk_resampler_private_IIR_FIR( S, &out[ S->Fs_out_kHz ], &in[ nSamples ], inLen - S->Fs_in_kHz );
            break;
        case USE_silk_resampler_private_down_FIR:
            silk_resampler_private_down_FIR( S, out, S->delayBuf, S->Fs_in_kHz );
            silk_resampler_private_down_FIR( S, &out[ S->Fs_out_kHz ], &in[ nSamples ], inLen - S->Fs_in_kHz );
            break;
        default:
            silk_memcpy( out, S->delayBuf, S->Fs_in_kHz * sizeof( opus_int16 ) );
            silk_memcpy( &out[ S->Fs_out_kHz ], &in[ nSamples ], ( inLen - S->Fs_in_kHz ) * sizeof( opus_int16 ) );
    }
    silk_memcpy( S->delayBuf, &in[ inLen - S->inputDelay ], S->inputDelay * sizeof( opus_int16 ) );
    return 0;
}

void silk_resampler_private_AR2(
    opus_int32                      S[],
    opus_int32                      out_Q8[],
    const opus_int16                in[],
    const opus_int16                A_Q14[],
    opus_int32                      len
)
{
    opus_int32    k;
    opus_int32    out32;
    for( k = 0; k < len; k++ ) {
        out32       = silk_ADD_LSHIFT32( S[ 0 ], (opus_int32)in[ k ], 8 );
        out_Q8[ k ] = out32;
        out32       = silk_LSHIFT( out32, 2 );
        S[ 0 ]      = silk_SMLAWB( S[ 1 ], out32, A_Q14[ 0 ] );
        S[ 1 ]      = silk_SMULWB( out32, A_Q14[ 1 ] );
    }
}

static inline opus_int16 *silk_resampler_private_IIR_FIR_INTERPOL(
    opus_int16  *out,
    opus_int16  *buf,
    opus_int32  max_index_Q16,
    opus_int32  index_increment_Q16
)
{
    opus_int32 index_Q16, res_Q15;
    opus_int16 *buf_ptr;
    opus_int32 table_index;
    for( index_Q16 = 0; index_Q16 < max_index_Q16; index_Q16 += index_increment_Q16 ) {
        table_index = silk_SMULWB( index_Q16 & 0xFFFF, 12 );
        buf_ptr = &buf[ index_Q16 >> 16 ];
        res_Q15 = silk_SMULBB(          buf_ptr[ 0 ], silk_resampler_frac_FIR_12[      table_index ][ 0 ] );
        res_Q15 = silk_SMLABB( res_Q15, buf_ptr[ 1 ], silk_resampler_frac_FIR_12[      table_index ][ 1 ] );
        res_Q15 = silk_SMLABB( res_Q15, buf_ptr[ 2 ], silk_resampler_frac_FIR_12[      table_index ][ 2 ] );
        res_Q15 = silk_SMLABB( res_Q15, buf_ptr[ 3 ], silk_resampler_frac_FIR_12[      table_index ][ 3 ] );
        res_Q15 = silk_SMLABB( res_Q15, buf_ptr[ 4 ], silk_resampler_frac_FIR_12[ 11 - table_index ][ 3 ] );
        res_Q15 = silk_SMLABB( res_Q15, buf_ptr[ 5 ], silk_resampler_frac_FIR_12[ 11 - table_index ][ 2 ] );
        res_Q15 = silk_SMLABB( res_Q15, buf_ptr[ 6 ], silk_resampler_frac_FIR_12[ 11 - table_index ][ 1 ] );
        res_Q15 = silk_SMLABB( res_Q15, buf_ptr[ 7 ], silk_resampler_frac_FIR_12[ 11 - table_index ][ 0 ] );
        *out++ = (opus_int16)silk_SAT16( silk_RSHIFT_ROUND( res_Q15, 15 ) );
    }
    return out;
}
void silk_resampler_private_IIR_FIR(
    void                            *SS,
    opus_int16                      out[],
    const opus_int16                in[],
    opus_int32                      inLen
)
{
    silk_resampler_state_struct *S = (silk_resampler_state_struct *)SS;
    opus_int32 nSamplesIn;
    opus_int32 max_index_Q16, index_increment_Q16;
    opus_int16 buf[ 2*RESAMPLER_MAX_BATCH_SIZE_IN + RESAMPLER_ORDER_FIR_12 ];
    silk_memcpy( buf, S->sFIR, RESAMPLER_ORDER_FIR_12 * sizeof( opus_int16 ) );
    index_increment_Q16 = S->invRatio_Q16;
    while( 1 ) {
        nSamplesIn = silk_min( inLen, S->batchSize );
        silk_resampler_private_up2_HQ( S->sIIR, &buf[ RESAMPLER_ORDER_FIR_12 ], in, nSamplesIn );
        max_index_Q16 = silk_LSHIFT32( nSamplesIn, 16 + 1 );
        out = silk_resampler_private_IIR_FIR_INTERPOL( out, buf, max_index_Q16, index_increment_Q16 );
        in += nSamplesIn;
        inLen -= nSamplesIn;
        if( inLen > 0 ) {
            silk_memmove( buf, &buf[ nSamplesIn << 1 ], RESAMPLER_ORDER_FIR_12 * sizeof( opus_int16 ) );
        } else {
            break;
        }
    }
    silk_memcpy( S->sFIR, &buf[ nSamplesIn << 1 ], RESAMPLER_ORDER_FIR_12 * sizeof( opus_int16 ) );
}

static inline opus_int16 *silk_resampler_private_down_FIR_INTERPOL(
    opus_int16          *out,
    opus_int32          *buf,
    const opus_int16    *FIR_Coefs,
    opus_int            FIR_Order,
    opus_int            FIR_Fracs,
    opus_int32          max_index_Q16,
    opus_int32          index_increment_Q16
)
{
    opus_int32 index_Q16, res_Q6;
    opus_int32 *buf_ptr;
    opus_int32 interpol_ind;
    const opus_int16 *interpol_ptr;
    switch( FIR_Order ) {
        case RESAMPLER_DOWN_ORDER_FIR0:
            for( index_Q16 = 0; index_Q16 < max_index_Q16; index_Q16 += index_increment_Q16 ) {
                buf_ptr = buf + silk_RSHIFT( index_Q16, 16 );
                interpol_ind = silk_SMULWB( index_Q16 & 0xFFFF, FIR_Fracs );
                interpol_ptr = &FIR_Coefs[ RESAMPLER_DOWN_ORDER_FIR0 / 2 * interpol_ind ];
                res_Q6 = silk_SMULWB(         buf_ptr[ 0 ], interpol_ptr[ 0 ] );
                res_Q6 = silk_SMLAWB( res_Q6, buf_ptr[ 1 ], interpol_ptr[ 1 ] );
                res_Q6 = silk_SMLAWB( res_Q6, buf_ptr[ 2 ], interpol_ptr[ 2 ] );
                res_Q6 = silk_SMLAWB( res_Q6, buf_ptr[ 3 ], interpol_ptr[ 3 ] );
                res_Q6 = silk_SMLAWB( res_Q6, buf_ptr[ 4 ], interpol_ptr[ 4 ] );
                res_Q6 = silk_SMLAWB( res_Q6, buf_ptr[ 5 ], interpol_ptr[ 5 ] );
                res_Q6 = silk_SMLAWB( res_Q6, buf_ptr[ 6 ], interpol_ptr[ 6 ] );
                res_Q6 = silk_SMLAWB( res_Q6, buf_ptr[ 7 ], interpol_ptr[ 7 ] );
                res_Q6 = silk_SMLAWB( res_Q6, buf_ptr[ 8 ], interpol_ptr[ 8 ] );
                interpol_ptr = &FIR_Coefs[ RESAMPLER_DOWN_ORDER_FIR0 / 2 * ( FIR_Fracs - 1 - interpol_ind ) ];
                res_Q6 = silk_SMLAWB( res_Q6, buf_ptr[ 17 ], interpol_ptr[ 0 ] );
                res_Q6 = silk_SMLAWB( res_Q6, buf_ptr[ 16 ], interpol_ptr[ 1 ] );
                res_Q6 = silk_SMLAWB( res_Q6, buf_ptr[ 15 ], interpol_ptr[ 2 ] );
                res_Q6 = silk_SMLAWB( res_Q6, buf_ptr[ 14 ], interpol_ptr[ 3 ] );
                res_Q6 = silk_SMLAWB( res_Q6, buf_ptr[ 13 ], interpol_ptr[ 4 ] );
                res_Q6 = silk_SMLAWB( res_Q6, buf_ptr[ 12 ], interpol_ptr[ 5 ] );
                res_Q6 = silk_SMLAWB( res_Q6, buf_ptr[ 11 ], interpol_ptr[ 6 ] );
                res_Q6 = silk_SMLAWB( res_Q6, buf_ptr[ 10 ], interpol_ptr[ 7 ] );
                res_Q6 = silk_SMLAWB( res_Q6, buf_ptr[  9 ], interpol_ptr[ 8 ] );
                *out++ = (opus_int16)silk_SAT16( silk_RSHIFT_ROUND( res_Q6, 6 ) );
            }
            break;
        case RESAMPLER_DOWN_ORDER_FIR1:
            for( index_Q16 = 0; index_Q16 < max_index_Q16; index_Q16 += index_increment_Q16 ) {
                buf_ptr = buf + silk_RSHIFT( index_Q16, 16 );
                res_Q6 = silk_SMULWB(         silk_ADD32( buf_ptr[  0 ], buf_ptr[ 23 ] ), FIR_Coefs[  0 ] );
                res_Q6 = silk_SMLAWB( res_Q6, silk_ADD32( buf_ptr[  1 ], buf_ptr[ 22 ] ), FIR_Coefs[  1 ] );
                res_Q6 = silk_SMLAWB( res_Q6, silk_ADD32( buf_ptr[  2 ], buf_ptr[ 21 ] ), FIR_Coefs[  2 ] );
                res_Q6 = silk_SMLAWB( res_Q6, silk_ADD32( buf_ptr[  3 ], buf_ptr[ 20 ] ), FIR_Coefs[  3 ] );
                res_Q6 = silk_SMLAWB( res_Q6, silk_ADD32( buf_ptr[  4 ], buf_ptr[ 19 ] ), FIR_Coefs[  4 ] );
                res_Q6 = silk_SMLAWB( res_Q6, silk_ADD32( buf_ptr[  5 ], buf_ptr[ 18 ] ), FIR_Coefs[  5 ] );
                res_Q6 = silk_SMLAWB( res_Q6, silk_ADD32( buf_ptr[  6 ], buf_ptr[ 17 ] ), FIR_Coefs[  6 ] );
                res_Q6 = silk_SMLAWB( res_Q6, silk_ADD32( buf_ptr[  7 ], buf_ptr[ 16 ] ), FIR_Coefs[  7 ] );
                res_Q6 = silk_SMLAWB( res_Q6, silk_ADD32( buf_ptr[  8 ], buf_ptr[ 15 ] ), FIR_Coefs[  8 ] );
                res_Q6 = silk_SMLAWB( res_Q6, silk_ADD32( buf_ptr[  9 ], buf_ptr[ 14 ] ), FIR_Coefs[  9 ] );
                res_Q6 = silk_SMLAWB( res_Q6, silk_ADD32( buf_ptr[ 10 ], buf_ptr[ 13 ] ), FIR_Coefs[ 10 ] );
                res_Q6 = silk_SMLAWB( res_Q6, silk_ADD32( buf_ptr[ 11 ], buf_ptr[ 12 ] ), FIR_Coefs[ 11 ] );
                *out++ = (opus_int16)silk_SAT16( silk_RSHIFT_ROUND( res_Q6, 6 ) );
            }
            break;
        case RESAMPLER_DOWN_ORDER_FIR2:
            for( index_Q16 = 0; index_Q16 < max_index_Q16; index_Q16 += index_increment_Q16 ) {
                buf_ptr = buf + silk_RSHIFT( index_Q16, 16 );
                res_Q6 = silk_SMULWB(         silk_ADD32( buf_ptr[  0 ], buf_ptr[ 35 ] ), FIR_Coefs[  0 ] );
                res_Q6 = silk_SMLAWB( res_Q6, silk_ADD32( buf_ptr[  1 ], buf_ptr[ 34 ] ), FIR_Coefs[  1 ] );
                res_Q6 = silk_SMLAWB( res_Q6, silk_ADD32( buf_ptr[  2 ], buf_ptr[ 33 ] ), FIR_Coefs[  2 ] );
                res_Q6 = silk_SMLAWB( res_Q6, silk_ADD32( buf_ptr[  3 ], buf_ptr[ 32 ] ), FIR_Coefs[  3 ] );
                res_Q6 = silk_SMLAWB( res_Q6, silk_ADD32( buf_ptr[  4 ], buf_ptr[ 31 ] ), FIR_Coefs[  4 ] );
                res_Q6 = silk_SMLAWB( res_Q6, silk_ADD32( buf_ptr[  5 ], buf_ptr[ 30 ] ), FIR_Coefs[  5 ] );
                res_Q6 = silk_SMLAWB( res_Q6, silk_ADD32( buf_ptr[  6 ], buf_ptr[ 29 ] ), FIR_Coefs[  6 ] );
                res_Q6 = silk_SMLAWB( res_Q6, silk_ADD32( buf_ptr[  7 ], buf_ptr[ 28 ] ), FIR_Coefs[  7 ] );
                res_Q6 = silk_SMLAWB( res_Q6, silk_ADD32( buf_ptr[  8 ], buf_ptr[ 27 ] ), FIR_Coefs[  8 ] );
                res_Q6 = silk_SMLAWB( res_Q6, silk_ADD32( buf_ptr[  9 ], buf_ptr[ 26 ] ), FIR_Coefs[  9 ] );
                res_Q6 = silk_SMLAWB( res_Q6, silk_ADD32( buf_ptr[ 10 ], buf_ptr[ 25 ] ), FIR_Coefs[ 10 ] );
                res_Q6 = silk_SMLAWB( res_Q6, silk_ADD32( buf_ptr[ 11 ], buf_ptr[ 24 ] ), FIR_Coefs[ 11 ] );
                res_Q6 = silk_SMLAWB( res_Q6, silk_ADD32( buf_ptr[ 12 ], buf_ptr[ 23 ] ), FIR_Coefs[ 12 ] );
                res_Q6 = silk_SMLAWB( res_Q6, silk_ADD32( buf_ptr[ 13 ], buf_ptr[ 22 ] ), FIR_Coefs[ 13 ] );
                res_Q6 = silk_SMLAWB( res_Q6, silk_ADD32( buf_ptr[ 14 ], buf_ptr[ 21 ] ), FIR_Coefs[ 14 ] );
                res_Q6 = silk_SMLAWB( res_Q6, silk_ADD32( buf_ptr[ 15 ], buf_ptr[ 20 ] ), FIR_Coefs[ 15 ] );
                res_Q6 = silk_SMLAWB( res_Q6, silk_ADD32( buf_ptr[ 16 ], buf_ptr[ 19 ] ), FIR_Coefs[ 16 ] );
                res_Q6 = silk_SMLAWB( res_Q6, silk_ADD32( buf_ptr[ 17 ], buf_ptr[ 18 ] ), FIR_Coefs[ 17 ] );
                *out++ = (opus_int16)silk_SAT16( silk_RSHIFT_ROUND( res_Q6, 6 ) );
            }
            break;
        default:
            silk_assert( 0 );
    }
    return out;
}
void silk_resampler_private_down_FIR(
    void                            *SS,
    opus_int16                      out[],
    const opus_int16                in[],
    opus_int32                      inLen
)
{
    silk_resampler_state_struct *S = (silk_resampler_state_struct *)SS;
    opus_int32 nSamplesIn;
    opus_int32 max_index_Q16, index_increment_Q16;
    opus_int32 buf[ RESAMPLER_MAX_BATCH_SIZE_IN + SILK_RESAMPLER_MAX_FIR_ORDER ];
    const opus_int16 *FIR_Coefs;
    silk_memcpy( buf, S->sFIR, S->FIR_Order * sizeof( opus_int32 ) );
    FIR_Coefs = &S->Coefs[ 2 ];
    index_increment_Q16 = S->invRatio_Q16;
    while( 1 ) {
        nSamplesIn = silk_min( inLen, S->batchSize );
        silk_resampler_private_AR2( S->sIIR, &buf[ S->FIR_Order ], in, S->Coefs, nSamplesIn );
        max_index_Q16 = silk_LSHIFT32( nSamplesIn, 16 );
        out = silk_resampler_private_down_FIR_INTERPOL( out, buf, FIR_Coefs, S->FIR_Order,
            S->FIR_Fracs, max_index_Q16, index_increment_Q16 );
        in += nSamplesIn;
        inLen -= nSamplesIn;
        if( inLen > 1 ) {
            silk_memcpy( buf, &buf[ nSamplesIn ], S->FIR_Order * sizeof( opus_int32 ) );
        } else {
            break;
        }
    }
    silk_memcpy( S->sFIR, &buf[ nSamplesIn ], S->FIR_Order * sizeof( opus_int32 ) );
}

void silk_resampler_private_up2_HQ(
    opus_int32                      *S,
    opus_int16                      *out,
    const opus_int16                *in,
    opus_int32                      len
)
{
    opus_int32 k;
    opus_int32 in32, out32_1, out32_2, Y, X;
    silk_assert( silk_resampler_up2_hq_0[ 0 ] > 0 );
    silk_assert( silk_resampler_up2_hq_0[ 1 ] > 0 );
    silk_assert( silk_resampler_up2_hq_0[ 2 ] < 0 );
    silk_assert( silk_resampler_up2_hq_1[ 0 ] > 0 );
    silk_assert( silk_resampler_up2_hq_1[ 1 ] > 0 );
    silk_assert( silk_resampler_up2_hq_1[ 2 ] < 0 );
    for( k = 0; k < len; k++ ) {
        in32 = silk_LSHIFT( (opus_int32)in[ k ], 10 );
        Y       = silk_SUB32( in32, S[ 0 ] );
        X       = silk_SMULWB( Y, silk_resampler_up2_hq_0[ 0 ] );
        out32_1 = silk_ADD32( S[ 0 ], X );
        S[ 0 ]  = silk_ADD32( in32, X );
        Y       = silk_SUB32( out32_1, S[ 1 ] );
        X       = silk_SMULWB( Y, silk_resampler_up2_hq_0[ 1 ] );
        out32_2 = silk_ADD32( S[ 1 ], X );
        S[ 1 ]  = silk_ADD32( out32_1, X );
        Y       = silk_SUB32( out32_2, S[ 2 ] );
        X       = silk_SMLAWB( Y, Y, silk_resampler_up2_hq_0[ 2 ] );
        out32_1 = silk_ADD32( S[ 2 ], X );
        S[ 2 ]  = silk_ADD32( out32_2, X );
        out[ 2 * k ] = (opus_int16)silk_SAT16( silk_RSHIFT_ROUND( out32_1, 10 ) );
        Y       = silk_SUB32( in32, S[ 3 ] );
        X       = silk_SMULWB( Y, silk_resampler_up2_hq_1[ 0 ] );
        out32_1 = silk_ADD32( S[ 3 ], X );
        S[ 3 ]  = silk_ADD32( in32, X );
        Y       = silk_SUB32( out32_1, S[ 4 ] );
        X       = silk_SMULWB( Y, silk_resampler_up2_hq_1[ 1 ] );
        out32_2 = silk_ADD32( S[ 4 ], X );
        S[ 4 ]  = silk_ADD32( out32_1, X );
        Y       = silk_SUB32( out32_2, S[ 5 ] );
        X       = silk_SMLAWB( Y, Y, silk_resampler_up2_hq_1[ 2 ] );
        out32_1 = silk_ADD32( S[ 5 ], X );
        S[ 5 ]  = silk_ADD32( out32_2, X );
        out[ 2 * k + 1 ] = (opus_int16)silk_SAT16( silk_RSHIFT_ROUND( out32_1, 10 ) );
    }
}
void silk_resampler_private_up2_HQ_wrapper(
    void                            *SS,
    opus_int16                      *out,
    const opus_int16                *in,
    opus_int32                      len
)
{
    silk_resampler_state_struct *S = (silk_resampler_state_struct *)SS;
    silk_resampler_private_up2_HQ( S->sIIR, out, in, len );
}

const opus_int16 silk_resampler_up2_hq_0[ 3 ] = { 1746, 14986, 39083 - 65536 };
const opus_int16 silk_resampler_up2_hq_1[ 3 ] = { 6854, 25769, 55542 - 65536 };
silk_DWORD_ALIGN const opus_int16 silk_Resampler_3_4_COEFS[ 2 + 3 * RESAMPLER_DOWN_ORDER_FIR0 / 2 ] = {
	-20694, -13867,
	   -49,     64,     17,   -157,    353,   -496,    163,  11047,  22205,
	   -39,      6,     91,   -170,    186,     23,   -896,   6336,  19928,
	   -19,    -36,    102,    -89,    -24,    328,   -951,   2568,  15909,
};
silk_DWORD_ALIGN const opus_int16 silk_Resampler_2_3_COEFS[ 2 + 2 * RESAMPLER_DOWN_ORDER_FIR0 / 2 ] = {
	-14457, -14019,
	    64,    128,   -122,     36,    310,   -768,    584,   9267,  17733,
	    12,    128,     18,   -142,    288,   -117,   -865,   4123,  14459,
};
silk_DWORD_ALIGN const opus_int16 silk_Resampler_1_2_COEFS[ 2 + RESAMPLER_DOWN_ORDER_FIR1 / 2 ] = {
	   616, -14323,
	   -10,     39,     58,    -46,    -84,    120,    184,   -315,   -541,   1284,   5380,   9024,
};
silk_DWORD_ALIGN const opus_int16 silk_Resampler_1_3_COEFS[ 2 + RESAMPLER_DOWN_ORDER_FIR2 / 2 ] = {
	 16102, -15162,
	   -13,      0,     20,     26,      5,    -31,    -43,     -4,     65,     90,      7,   -157,   -248,    -44,    593,   1583,   2612,   3271,
};
silk_DWORD_ALIGN const opus_int16 silk_Resampler_1_4_COEFS[ 2 + RESAMPLER_DOWN_ORDER_FIR2 / 2 ] = {
	 22500, -15099,
	     3,    -14,    -20,    -15,      2,     25,     37,     25,    -16,    -71,   -107,    -79,     50,    292,    623,    982,   1288,   1464,
};
silk_DWORD_ALIGN const opus_int16 silk_Resampler_1_6_COEFS[ 2 + RESAMPLER_DOWN_ORDER_FIR2 / 2 ] = {
	 27540, -15257,
	    17,     12,      8,      1,    -10,    -22,    -30,    -32,    -22,      3,     44,    100,    168,    243,    317,    381,    429,    455,
};
silk_DWORD_ALIGN const opus_int16 silk_resampler_frac_FIR_12[ 12 ][ RESAMPLER_ORDER_FIR_12 / 2 ] = {
	{  189,  -600,   617, 30567 },
	{  117,  -159, -1070, 29704 },
	{   52,   221, -2392, 28276 },
	{   -4,   529, -3350, 26341 },
	{  -48,   758, -3956, 23973 },
	{  -80,   905, -4235, 21254 },
	{  -99,   972, -4222, 18278 },
	{ -107,   967, -3957, 15143 },
	{ -103,   896, -3487, 11950 },
	{  -91,   773, -2865,  8798 },
	{  -71,   611, -2143,  5784 },
	{  -46,   425, -1375,  2996 },
};

static inline void decode_split(
    opus_int                    *p_child1,
    opus_int                    *p_child2,
    ec_dec                      *psRangeDec,
    const opus_int              p,
    const opus_uint8            *shell_table
)
{
    if( p > 0 ) {
        p_child1[ 0 ] = ec_dec_icdf( psRangeDec, &shell_table[ silk_shell_code_table_offsets[ p ] ], 8 );
        p_child2[ 0 ] = p - p_child1[ 0 ];
    } else {
        p_child1[ 0 ] = 0;
        p_child2[ 0 ] = 0;
    }
}
void silk_shell_decoder(
    opus_int                    *pulses0,
    ec_dec                      *psRangeDec,
    const opus_int              pulses4
)
{
    opus_int pulses3[ 2 ], pulses2[ 4 ], pulses1[ 8 ];
    silk_assert( SHELL_CODEC_FRAME_LENGTH == 16 );
    decode_split( &pulses3[  0 ], &pulses3[  1 ], psRangeDec, pulses4,      silk_shell_code_table3 );
    decode_split( &pulses2[  0 ], &pulses2[  1 ], psRangeDec, pulses3[ 0 ], silk_shell_code_table2 );
    decode_split( &pulses1[  0 ], &pulses1[  1 ], psRangeDec, pulses2[ 0 ], silk_shell_code_table1 );
    decode_split( &pulses0[  0 ], &pulses0[  1 ], psRangeDec, pulses1[ 0 ], silk_shell_code_table0 );
    decode_split( &pulses0[  2 ], &pulses0[  3 ], psRangeDec, pulses1[ 1 ], silk_shell_code_table0 );
    decode_split( &pulses1[  2 ], &pulses1[  3 ], psRangeDec, pulses2[ 1 ], silk_shell_code_table1 );
    decode_split( &pulses0[  4 ], &pulses0[  5 ], psRangeDec, pulses1[ 2 ], silk_shell_code_table0 );
    decode_split( &pulses0[  6 ], &pulses0[  7 ], psRangeDec, pulses1[ 3 ], silk_shell_code_table0 );
    decode_split( &pulses2[  2 ], &pulses2[  3 ], psRangeDec, pulses3[ 1 ], silk_shell_code_table2 );
    decode_split( &pulses1[  4 ], &pulses1[  5 ], psRangeDec, pulses2[ 2 ], silk_shell_code_table1 );
    decode_split( &pulses0[  8 ], &pulses0[  9 ], psRangeDec, pulses1[ 4 ], silk_shell_code_table0 );
    decode_split( &pulses0[ 10 ], &pulses0[ 11 ], psRangeDec, pulses1[ 5 ], silk_shell_code_table0 );
    decode_split( &pulses1[  6 ], &pulses1[  7 ], psRangeDec, pulses2[ 3 ], silk_shell_code_table1 );
    decode_split( &pulses0[ 12 ], &pulses0[ 13 ], psRangeDec, pulses1[ 6 ], silk_shell_code_table0 );
    decode_split( &pulses0[ 14 ], &pulses0[ 15 ], psRangeDec, pulses1[ 7 ], silk_shell_code_table0 );
}

void silk_insertion_sort_increasing_all_values_int16(
     opus_int16                 *a,
     const opus_int             L
)
{
    opus_int    value;
    opus_int    i, j;
    silk_assert( L >  0 );
    for( i = 1; i < L; i++ ) {
        value = a[ i ];
        for( j = i - 1; ( j >= 0 ) && ( value < a[ j ] ); j-- ) {
            a[ j + 1 ] = a[ j ];
        }
        a[ j + 1 ] = value;
    }
}

void silk_stereo_MS_to_LR(
    stereo_dec_state            *state,
    opus_int16                  x1[],
    opus_int16                  x2[],
    const opus_int32            pred_Q13[],
    opus_int                    fs_kHz,
    opus_int                    frame_length
)
{
    opus_int   n, denom_Q16, delta0_Q13, delta1_Q13;
    opus_int32 sum, diff, pred0_Q13, pred1_Q13;
    silk_memcpy( x1, state->sMid,  2 * sizeof( opus_int16 ) );
    silk_memcpy( x2, state->sSide, 2 * sizeof( opus_int16 ) );
    silk_memcpy( state->sMid,  &x1[ frame_length ], 2 * sizeof( opus_int16 ) );
    silk_memcpy( state->sSide, &x2[ frame_length ], 2 * sizeof( opus_int16 ) );
    pred0_Q13  = state->pred_prev_Q13[ 0 ];
    pred1_Q13  = state->pred_prev_Q13[ 1 ];
    denom_Q16  = silk_DIV32_16( 1 << 16, STEREO_INTERP_LEN_MS * fs_kHz );
    delta0_Q13 = silk_RSHIFT_ROUND( silk_SMULBB( pred_Q13[ 0 ] - state->pred_prev_Q13[ 0 ], denom_Q16 ), 16 );
    delta1_Q13 = silk_RSHIFT_ROUND( silk_SMULBB( pred_Q13[ 1 ] - state->pred_prev_Q13[ 1 ], denom_Q16 ), 16 );
    for( n = 0; n < STEREO_INTERP_LEN_MS * fs_kHz; n++ ) {
        pred0_Q13 += delta0_Q13;
        pred1_Q13 += delta1_Q13;
        sum = silk_LSHIFT( silk_ADD_LSHIFT( x1[ n ] + x1[ n + 2 ], x1[ n + 1 ], 1 ), 9 );
        sum = silk_SMLAWB( silk_LSHIFT( (opus_int32)x2[ n + 1 ], 8 ), sum, pred0_Q13 );
        sum = silk_SMLAWB( sum, silk_LSHIFT( (opus_int32)x1[ n + 1 ], 11 ), pred1_Q13 );
        x2[ n + 1 ] = (opus_int16)silk_SAT16( silk_RSHIFT_ROUND( sum, 8 ) );
    }
    pred0_Q13 = pred_Q13[ 0 ];
    pred1_Q13 = pred_Q13[ 1 ];
    for( n = STEREO_INTERP_LEN_MS * fs_kHz; n < frame_length; n++ ) {
        sum = silk_LSHIFT( silk_ADD_LSHIFT( x1[ n ] + x1[ n + 2 ], x1[ n + 1 ], 1 ), 9 );
        sum = silk_SMLAWB( silk_LSHIFT( (opus_int32)x2[ n + 1 ], 8 ), sum, pred0_Q13 );
        sum = silk_SMLAWB( sum, silk_LSHIFT( (opus_int32)x1[ n + 1 ], 11 ), pred1_Q13 );
        x2[ n + 1 ] = (opus_int16)silk_SAT16( silk_RSHIFT_ROUND( sum, 8 ) );
    }
    state->pred_prev_Q13[ 0 ] = pred_Q13[ 0 ];
    state->pred_prev_Q13[ 1 ] = pred_Q13[ 1 ];
    for( n = 0; n < frame_length; n++ ) {
        sum  = x1[ n + 1 ] + (opus_int32)x2[ n + 1 ];
        diff = x1[ n + 1 ] - (opus_int32)x2[ n + 1 ];
        x1[ n + 1 ] = (opus_int16)silk_SAT16( sum );
        x2[ n + 1 ] = (opus_int16)silk_SAT16( diff );
    }
}

void silk_stereo_decode_pred(
    ec_dec                      *psRangeDec,
    opus_int32                  pred_Q13[]
)
{
    opus_int   n, ix[ 2 ][ 3 ];
    opus_int32 low_Q13, step_Q13;
    n = ec_dec_icdf( psRangeDec, silk_stereo_pred_joint_iCDF, 8 );
    ix[ 0 ][ 2 ] = silk_DIV32_16( n, 5 );
    ix[ 1 ][ 2 ] = n - 5 * ix[ 0 ][ 2 ];
    for( n = 0; n < 2; n++ ) {
        ix[ n ][ 0 ] = ec_dec_icdf( psRangeDec, silk_uniform3_iCDF, 8 );
        ix[ n ][ 1 ] = ec_dec_icdf( psRangeDec, silk_uniform5_iCDF, 8 );
    }
    for( n = 0; n < 2; n++ ) {
        ix[ n ][ 0 ] += 3 * ix[ n ][ 2 ];
        low_Q13 = silk_stereo_pred_quant_Q13[ ix[ n ][ 0 ] ];
        step_Q13 = silk_SMULWB( silk_stereo_pred_quant_Q13[ ix[ n ][ 0 ] + 1 ] - low_Q13,
            SILK_FIX_CONST( 0.5 / STEREO_QUANT_SUB_STEPS, 16 ) );
        pred_Q13[ n ] = silk_SMLABB( low_Q13, step_Q13, 2 * ix[ n ][ 1 ] + 1 );
    }
    pred_Q13[ 0 ] -= pred_Q13[ 1 ];
}
void silk_stereo_decode_mid_only(
    ec_dec                      *psRangeDec,
    opus_int                    *decode_only_mid
)
{
    *decode_only_mid = ec_dec_icdf( psRangeDec, silk_stereo_only_code_mid_iCDF, 8 );
}

void silk_sum_sqr_shift(
    opus_int32                  *energy,
    opus_int                    *shift,
    const opus_int16            *x,
    opus_int                    len
)
{
    opus_int   i, shft;
    opus_int32 nrg_tmp, nrg;
    nrg  = 0;
    shft = 0;
    len--;
    for( i = 0; i < len; i += 2 ) {
        nrg = silk_SMLABB_ovflw( nrg, x[ i ], x[ i ] );
        nrg = silk_SMLABB_ovflw( nrg, x[ i + 1 ], x[ i + 1 ] );
        if( nrg < 0 ) {
            nrg = (opus_int32)silk_RSHIFT_uint( (opus_uint32)nrg, 2 );
            shft = 2;
            break;
        }
    }
    for( ; i < len; i += 2 ) {
        nrg_tmp = silk_SMULBB( x[ i ], x[ i ] );
        nrg_tmp = silk_SMLABB_ovflw( nrg_tmp, x[ i + 1 ], x[ i + 1 ] );
        nrg = (opus_int32)silk_ADD_RSHIFT_uint( nrg, (opus_uint32)nrg_tmp, shft );
        if( nrg < 0 ) {
            nrg = (opus_int32)silk_RSHIFT_uint( (opus_uint32)nrg, 2 );
            shft += 2;
        }
    }
    if( i == len ) {
        nrg_tmp = silk_SMULBB( x[ i ], x[ i ] );
        nrg = (opus_int32)silk_ADD_RSHIFT_uint( nrg, nrg_tmp, shft );
    }
    if( nrg & 0xC0000000 ) {
        nrg = silk_RSHIFT_uint( (opus_uint32)nrg, 2 );
        shft += 2;
    }
    *shift  = shft;
    *energy = nrg;
}

const opus_int16 silk_LSFCosTab_FIX_Q12[ LSF_COS_TAB_SZ_FIX + 1 ] = {
            8192,             8190,             8182,             8170,
            8152,             8130,             8104,             8072,
            8034,             7994,             7946,             7896,
            7840,             7778,             7714,             7644,
            7568,             7490,             7406,             7318,
            7226,             7128,             7026,             6922,
            6812,             6698,             6580,             6458,
            6332,             6204,             6070,             5934,
            5792,             5648,             5502,             5352,
            5198,             5040,             4880,             4718,
            4552,             4382,             4212,             4038,
            3862,             3684,             3502,             3320,
            3136,             2948,             2760,             2570,
            2378,             2186,             1990,             1794,
            1598,             1400,             1202,             1002,
             802,              602,              402,              202,
               0,             -202,             -402,             -602,
            -802,            -1002,            -1202,            -1400,
           -1598,            -1794,            -1990,            -2186,
           -2378,            -2570,            -2760,            -2948,
           -3136,            -3320,            -3502,            -3684,
           -3862,            -4038,            -4212,            -4382,
           -4552,            -4718,            -4880,            -5040,
           -5198,            -5352,            -5502,            -5648,
           -5792,            -5934,            -6070,            -6204,
           -6332,            -6458,            -6580,            -6698,
           -6812,            -6922,            -7026,            -7128,
           -7226,            -7318,            -7406,            -7490,
           -7568,            -7644,            -7714,            -7778,
           -7840,            -7896,            -7946,            -7994,
           -8034,            -8072,            -8104,            -8130,
           -8152,            -8170,            -8182,            -8190,
           -8192
};

const opus_uint8 silk_LTP_per_index_iCDF[3] = {
       179,     99,      0
};
const opus_uint8 silk_LTP_gain_iCDF_0[8] = {
        71,     56,     43,     30,     21,     12,      6,      0
};
const opus_uint8 silk_LTP_gain_iCDF_1[16] = {
       199,    165,    144,    124,    109,     96,     84,     71,
        61,     51,     42,     32,     23,     15,      8,      0
};
const opus_uint8 silk_LTP_gain_iCDF_2[32] = {
       241,    225,    211,    199,    187,    175,    164,    153,
       142,    132,    123,    114,    105,     96,     88,     80,
        72,     64,     57,     50,     44,     38,     33,     29,
        24,     20,     16,     12,      9,      5,      2,      0
};
const opus_uint8 * const silk_LTP_gain_iCDF_ptrs[NB_LTP_CBKS] = {
    silk_LTP_gain_iCDF_0,
    silk_LTP_gain_iCDF_1,
    silk_LTP_gain_iCDF_2
};
const opus_int8 silk_LTP_gain_vq_0[8][5] =
{
{
         4,      6,     24,      7,      5
},
{
         0,      0,      2,      0,      0
},
{
        12,     28,     41,     13,     -4
},
{
        -9,     15,     42,     25,     14
},
{
         1,     -2,     62,     41,     -9
},
{
       -10,     37,     65,     -4,      3
},
{
        -6,      4,     66,      7,     -8
},
{
        16,     14,     38,     -3,     33
}
};
const opus_int8 silk_LTP_gain_vq_1[16][5] =
{
{
        13,     22,     39,     23,     12
},
{
        -1,     36,     64,     27,     -6
},
{
        -7,     10,     55,     43,     17
},
{
         1,      1,      8,      1,      1
},
{
         6,    -11,     74,     53,     -9
},
{
       -12,     55,     76,    -12,      8
},
{
        -3,      3,     93,     27,     -4
},
{
        26,     39,     59,      3,     -8
},
{
         2,      0,     77,     11,      9
},
{
        -8,     22,     44,     -6,      7
},
{
        40,      9,     26,      3,      9
},
{
        -7,     20,    101,     -7,      4
},
{
         3,     -8,     42,     26,      0
},
{
       -15,     33,     68,      2,     23
},
{
        -2,     55,     46,     -2,     15
},
{
         3,     -1,     21,     16,     41
}
};
const opus_int8 silk_LTP_gain_vq_2[32][5] =
{
{
        -6,     27,     61,     39,      5
},
{
       -11,     42,     88,      4,      1
},
{
        -2,     60,     65,      6,     -4
},
{
        -1,     -5,     73,     56,      1
},
{
        -9,     19,     94,     29,     -9
},
{
         0,     12,     99,      6,      4
},
{
         8,    -19,    102,     46,    -13
},
{
         3,      2,     13,      3,      2
},
{
         9,    -21,     84,     72,    -18
},
{
       -11,     46,    104,    -22,      8
},
{
        18,     38,     48,     23,      0
},
{
       -16,     70,     83,    -21,     11
},
{
         5,    -11,    117,     22,     -8
},
{
        -6,     23,    117,    -12,      3
},
{
         3,     -8,     95,     28,      4
},
{
       -10,     15,     77,     60,    -15
},
{
        -1,      4,    124,      2,     -4
},
{
         3,     38,     84,     24,    -25
},
{
         2,     13,     42,     13,     31
},
{
        21,     -4,     56,     46,     -1
},
{
        -1,     35,     79,    -13,     19
},
{
        -7,     65,     88,     -9,    -14
},
{
        20,      4,     81,     49,    -29
},
{
        20,      0,     75,      3,    -17
},
{
         5,     -9,     44,     92,     -8
},
{
         1,     -3,     22,     69,     31
},
{
        -6,     95,     41,    -12,      5
},
{
        39,     67,     16,     -4,      1
},
{
         0,     -6,    120,     55,    -36
},
{
       -13,     44,    122,      4,    -24
},
{
        81,      5,     11,      3,      7
},
{
         2,      0,      9,     10,     88
}
};
const opus_int8 * const silk_LTP_vq_ptrs_Q7[NB_LTP_CBKS] = {
    (opus_int8 *)silk_LTP_gain_vq_0,
    (opus_int8 *)silk_LTP_gain_vq_1,
    (opus_int8 *)silk_LTP_gain_vq_2
};

const opus_uint8 silk_NLSF_CB1_NB_MB_Q8[ 320 ] = {
        12,     35,     60,     83,    108,    132,    157,    180,
       206,    228,     15,     32,     55,     77,    101,    125,
       151,    175,    201,    225,     19,     42,     66,     89,
       114,    137,    162,    184,    209,    230,     12,     25,
        50,     72,     97,    120,    147,    172,    200,    223,
        26,     44,     69,     90,    114,    135,    159,    180,
       205,    225,     13,     22,     53,     80,    106,    130,
       156,    180,    205,    228,     15,     25,     44,     64,
        90,    115,    142,    168,    196,    222,     19,     24,
        62,     82,    100,    120,    145,    168,    190,    214,
        22,     31,     50,     79,    103,    120,    151,    170,
       203,    227,     21,     29,     45,     65,    106,    124,
       150,    171,    196,    224,     30,     49,     75,     97,
       121,    142,    165,    186,    209,    229,     19,     25,
        52,     70,     93,    116,    143,    166,    192,    219,
        26,     34,     62,     75,     97,    118,    145,    167,
       194,    217,     25,     33,     56,     70,     91,    113,
       143,    165,    196,    223,     21,     34,     51,     72,
        97,    117,    145,    171,    196,    222,     20,     29,
        50,     67,     90,    117,    144,    168,    197,    221,
        22,     31,     48,     66,     95,    117,    146,    168,
       196,    222,     24,     33,     51,     77,    116,    134,
       158,    180,    200,    224,     21,     28,     70,     87,
       106,    124,    149,    170,    194,    217,     26,     33,
        53,     64,     83,    117,    152,    173,    204,    225,
        27,     34,     65,     95,    108,    129,    155,    174,
       210,    225,     20,     26,     72,     99,    113,    131,
       154,    176,    200,    219,     34,     43,     61,     78,
        93,    114,    155,    177,    205,    229,     23,     29,
        54,     97,    124,    138,    163,    179,    209,    229,
        30,     38,     56,     89,    118,    129,    158,    178,
       200,    231,     21,     29,     49,     63,     85,    111,
       142,    163,    193,    222,     27,     48,     77,    103,
       133,    158,    179,    196,    215,    232,     29,     47,
        74,     99,    124,    151,    176,    198,    220,    237,
        33,     42,     61,     76,     93,    121,    155,    174,
       207,    225,     29,     53,     87,    112,    136,    154,
       170,    188,    208,    227,     24,     30,     52,     84,
       131,    150,    166,    186,    203,    229,     37,     48,
        64,     84,    104,    118,    156,    177,    201,    230
};
const opus_uint8 silk_NLSF_CB1_iCDF_NB_MB[ 64 ] = {
       212,    178,    148,    129,    108,     96,     85,     82,
        79,     77,     61,     59,     57,     56,     51,     49,
        48,     45,     42,     41,     40,     38,     36,     34,
        31,     30,     21,     12,     10,      3,      1,      0,
       255,    245,    244,    236,    233,    225,    217,    203,
       190,    176,    175,    161,    149,    136,    125,    114,
       102,     91,     81,     71,     60,     52,     43,     35,
        28,     20,     19,     18,     12,     11,      5,      0
};
const opus_uint8 silk_NLSF_CB2_SELECT_NB_MB[ 160 ] = {
        16,      0,      0,      0,      0,     99,     66,     36,
        36,     34,     36,     34,     34,     34,     34,     83,
        69,     36,     52,     34,    116,    102,     70,     68,
        68,    176,    102,     68,     68,     34,     65,     85,
        68,     84,     36,    116,    141,    152,    139,    170,
       132,    187,    184,    216,    137,    132,    249,    168,
       185,    139,    104,    102,    100,     68,     68,    178,
       218,    185,    185,    170,    244,    216,    187,    187,
       170,    244,    187,    187,    219,    138,    103,    155,
       184,    185,    137,    116,    183,    155,    152,    136,
       132,    217,    184,    184,    170,    164,    217,    171,
       155,    139,    244,    169,    184,    185,    170,    164,
       216,    223,    218,    138,    214,    143,    188,    218,
       168,    244,    141,    136,    155,    170,    168,    138,
       220,    219,    139,    164,    219,    202,    216,    137,
       168,    186,    246,    185,    139,    116,    185,    219,
       185,    138,    100,    100,    134,    100,    102,     34,
        68,     68,    100,     68,    168,    203,    221,    218,
       168,    167,    154,    136,    104,     70,    164,    246,
       171,    137,    139,    137,    155,    218,    219,    139
};
const opus_uint8 silk_NLSF_CB2_iCDF_NB_MB[ 72 ] = {
       255,    254,    253,    238,     14,      3,      2,      1,
         0,    255,    254,    252,    218,     35,      3,      2,
         1,      0,    255,    254,    250,    208,     59,      4,
         2,      1,      0,    255,    254,    246,    194,     71,
        10,      2,      1,      0,    255,    252,    236,    183,
        82,      8,      2,      1,      0,    255,    252,    235,
       180,     90,     17,      2,      1,      0,    255,    248,
       224,    171,     97,     30,      4,      1,      0,    255,
       254,    236,    173,     95,     37,      7,      1,      0
};
const opus_uint8 silk_NLSF_CB2_BITS_NB_MB_Q5[ 72 ] = {
       255,    255,    255,    131,      6,    145,    255,    255,
       255,    255,    255,    236,     93,     15,     96,    255,
       255,    255,    255,    255,    194,     83,     25,     71,
       221,    255,    255,    255,    255,    162,     73,     34,
        66,    162,    255,    255,    255,    210,    126,     73,
        43,     57,    173,    255,    255,    255,    201,    125,
        71,     48,     58,    130,    255,    255,    255,    166,
       110,     73,     57,     62,    104,    210,    255,    255,
       251,    123,     65,     55,     68,    100,    171,    255
};
const opus_uint8 silk_NLSF_PRED_NB_MB_Q8[ 18 ] = {
       179,    138,    140,    148,    151,    149,    153,    151,
       163,    116,     67,     82,     59,     92,     72,    100,
        89,     92
};
const opus_int16 silk_NLSF_DELTA_MIN_NB_MB_Q15[ 11 ] = {
       250,      3,      6,      3,      3,      3,      4,      3,
         3,      3,    461
};
const silk_NLSF_CB_struct silk_NLSF_CB_NB_MB =
{
    32,
    10,
    SILK_FIX_CONST( 0.18, 16 ),
    SILK_FIX_CONST( 1.0 / 0.18, 6 ),
    silk_NLSF_CB1_NB_MB_Q8,
    silk_NLSF_CB1_iCDF_NB_MB,
    silk_NLSF_PRED_NB_MB_Q8,
    silk_NLSF_CB2_SELECT_NB_MB,
    silk_NLSF_CB2_iCDF_NB_MB,
    silk_NLSF_CB2_BITS_NB_MB_Q5,
    silk_NLSF_DELTA_MIN_NB_MB_Q15,
};

const opus_uint8 silk_NLSF_CB1_WB_Q8[ 512 ] = {
         7,     23,     38,     54,     69,     85,    100,    116,
       131,    147,    162,    178,    193,    208,    223,    239,
        13,     25,     41,     55,     69,     83,     98,    112,
       127,    142,    157,    171,    187,    203,    220,    236,
        15,     21,     34,     51,     61,     78,     92,    106,
       126,    136,    152,    167,    185,    205,    225,    240,
        10,     21,     36,     50,     63,     79,     95,    110,
       126,    141,    157,    173,    189,    205,    221,    237,
        17,     20,     37,     51,     59,     78,     89,    107,
       123,    134,    150,    164,    184,    205,    224,    240,
        10,     15,     32,     51,     67,     81,     96,    112,
       129,    142,    158,    173,    189,    204,    220,    236,
         8,     21,     37,     51,     65,     79,     98,    113,
       126,    138,    155,    168,    179,    192,    209,    218,
        12,     15,     34,     55,     63,     78,     87,    108,
       118,    131,    148,    167,    185,    203,    219,    236,
        16,     19,     32,     36,     56,     79,     91,    108,
       118,    136,    154,    171,    186,    204,    220,    237,
        11,     28,     43,     58,     74,     89,    105,    120,
       135,    150,    165,    180,    196,    211,    226,    241,
         6,     16,     33,     46,     60,     75,     92,    107,
       123,    137,    156,    169,    185,    199,    214,    225,
        11,     19,     30,     44,     57,     74,     89,    105,
       121,    135,    152,    169,    186,    202,    218,    234,
        12,     19,     29,     46,     57,     71,     88,    100,
       120,    132,    148,    165,    182,    199,    216,    233,
        17,     23,     35,     46,     56,     77,     92,    106,
       123,    134,    152,    167,    185,    204,    222,    237,
        14,     17,     45,     53,     63,     75,     89,    107,
       115,    132,    151,    171,    188,    206,    221,    240,
         9,     16,     29,     40,     56,     71,     88,    103,
       119,    137,    154,    171,    189,    205,    222,    237,
        16,     19,     36,     48,     57,     76,     87,    105,
       118,    132,    150,    167,    185,    202,    218,    236,
        12,     17,     29,     54,     71,     81,     94,    104,
       126,    136,    149,    164,    182,    201,    221,    237,
        15,     28,     47,     62,     79,     97,    115,    129,
       142,    155,    168,    180,    194,    208,    223,    238,
         8,     14,     30,     45,     62,     78,     94,    111,
       127,    143,    159,    175,    192,    207,    223,    239,
        17,     30,     49,     62,     79,     92,    107,    119,
       132,    145,    160,    174,    190,    204,    220,    235,
        14,     19,     36,     45,     61,     76,     91,    108,
       121,    138,    154,    172,    189,    205,    222,    238,
        12,     18,     31,     45,     60,     76,     91,    107,
       123,    138,    154,    171,    187,    204,    221,    236,
        13,     17,     31,     43,     53,     70,     83,    103,
       114,    131,    149,    167,    185,    203,    220,    237,
        17,     22,     35,     42,     58,     78,     93,    110,
       125,    139,    155,    170,    188,    206,    224,    240,
         8,     15,     34,     50,     67,     83,     99,    115,
       131,    146,    162,    178,    193,    209,    224,    239,
        13,     16,     41,     66,     73,     86,     95,    111,
       128,    137,    150,    163,    183,    206,    225,    241,
        17,     25,     37,     52,     63,     75,     92,    102,
       119,    132,    144,    160,    175,    191,    212,    231,
        19,     31,     49,     65,     83,    100,    117,    133,
       147,    161,    174,    187,    200,    213,    227,    242,
        18,     31,     52,     68,     88,    103,    117,    126,
       138,    149,    163,    177,    192,    207,    223,    239,
        16,     29,     47,     61,     76,     90,    106,    119,
       133,    147,    161,    176,    193,    209,    224,    240,
        15,     21,     35,     50,     61,     73,     86,     97,
       110,    119,    129,    141,    175,    198,    218,    237
};
const opus_uint8 silk_NLSF_CB1_iCDF_WB[ 64 ] = {
       225,    204,    201,    184,    183,    175,    158,    154,
       153,    135,    119,    115,    113,    110,    109,     99,
        98,     95,     79,     68,     52,     50,     48,     45,
        43,     32,     31,     27,     18,     10,      3,      0,
       255,    251,    235,    230,    212,    201,    196,    182,
       167,    166,    163,    151,    138,    124,    110,    104,
        90,     78,     76,     70,     69,     57,     45,     34,
        24,     21,     11,      6,      5,      4,      3,      0
};
const opus_uint8 silk_NLSF_CB2_SELECT_WB[ 256 ] = {
         0,      0,      0,      0,      0,      0,      0,      1,
       100,    102,    102,     68,     68,     36,     34,     96,
       164,    107,    158,    185,    180,    185,    139,    102,
        64,     66,     36,     34,     34,      0,      1,     32,
       208,    139,    141,    191,    152,    185,    155,    104,
        96,    171,    104,    166,    102,    102,    102,    132,
         1,      0,      0,      0,      0,     16,     16,      0,
        80,    109,     78,    107,    185,    139,    103,    101,
       208,    212,    141,    139,    173,    153,    123,    103,
        36,      0,      0,      0,      0,      0,      0,      1,
        48,      0,      0,      0,      0,      0,      0,     32,
        68,    135,    123,    119,    119,    103,     69,     98,
        68,    103,    120,    118,    118,    102,     71,     98,
       134,    136,    157,    184,    182,    153,    139,    134,
       208,    168,    248,     75,    189,    143,    121,    107,
        32,     49,     34,     34,     34,      0,     17,      2,
       210,    235,    139,    123,    185,    137,    105,    134,
        98,    135,    104,    182,    100,    183,    171,    134,
       100,     70,     68,     70,     66,     66,     34,    131,
        64,    166,    102,     68,     36,      2,      1,      0,
       134,    166,    102,     68,     34,     34,     66,    132,
       212,    246,    158,    139,    107,    107,     87,    102,
       100,    219,    125,    122,    137,    118,    103,    132,
       114,    135,    137,    105,    171,    106,     50,     34,
       164,    214,    141,    143,    185,    151,    121,    103,
       192,     34,      0,      0,      0,      0,      0,      1,
       208,    109,     74,    187,    134,    249,    159,    137,
       102,    110,    154,    118,     87,    101,    119,    101,
         0,      2,      0,     36,     36,     66,     68,     35,
        96,    164,    102,    100,     36,      0,      2,     33,
       167,    138,    174,    102,    100,     84,      2,      2,
       100,    107,    120,    119,     36,    197,     24,      0
};
const opus_uint8 silk_NLSF_CB2_iCDF_WB[ 72 ] = {
       255,    254,    253,    244,     12,      3,      2,      1,
         0,    255,    254,    252,    224,     38,      3,      2,
         1,      0,    255,    254,    251,    209,     57,      4,
         2,      1,      0,    255,    254,    244,    195,     69,
         4,      2,      1,      0,    255,    251,    232,    184,
        84,      7,      2,      1,      0,    255,    254,    240,
       186,     86,     14,      2,      1,      0,    255,    254,
       239,    178,     91,     30,      5,      1,      0,    255,
       248,    227,    177,    100,     19,      2,      1,      0
};
const opus_uint8 silk_NLSF_CB2_BITS_WB_Q5[ 72 ] = {
       255,    255,    255,    156,      4,    154,    255,    255,
       255,    255,    255,    227,    102,     15,     92,    255,
       255,    255,    255,    255,    213,     83,     24,     72,
       236,    255,    255,    255,    255,    150,     76,     33,
        63,    214,    255,    255,    255,    190,    121,     77,
        43,     55,    185,    255,    255,    255,    245,    137,
        71,     43,     59,    139,    255,    255,    255,    255,
       131,     66,     50,     66,    107,    194,    255,    255,
       166,    116,     76,     55,     53,    125,    255,    255
};
const opus_uint8 silk_NLSF_PRED_WB_Q8[ 30 ] = {
       175,    148,    160,    176,    178,    173,    174,    164,
       177,    174,    196,    182,    198,    192,    182,     68,
        62,     66,     60,     72,    117,     85,     90,    118,
       136,    151,    142,    160,    142,    155
};
const opus_int16 silk_NLSF_DELTA_MIN_WB_Q15[ 17 ] = {
       100,      3,     40,      3,      3,      3,      5,     14,
        14,     10,     11,      3,      8,      9,      7,      3,
       347
};
const silk_NLSF_CB_struct silk_NLSF_CB_WB =
{
    32,
    16,
    SILK_FIX_CONST( 0.15, 16 ),
    SILK_FIX_CONST( 1.0 / 0.15, 6 ),
    silk_NLSF_CB1_WB_Q8,
    silk_NLSF_CB1_iCDF_WB,
    silk_NLSF_PRED_WB_Q8,
    silk_NLSF_CB2_SELECT_WB,
    silk_NLSF_CB2_iCDF_WB,
    silk_NLSF_CB2_BITS_WB_Q5,
    silk_NLSF_DELTA_MIN_WB_Q15,
};

const opus_uint8 silk_gain_iCDF[ 3 ][ N_LEVELS_QGAIN / 8 ] =
{
{
       224,    112,     44,     15,      3,      2,      1,      0
},
{
       254,    237,    192,    132,     70,     23,      4,      0
},
{
       255,    252,    226,    155,     61,     11,      2,      0
}
};
const opus_uint8 silk_delta_gain_iCDF[ MAX_DELTA_GAIN_QUANT - MIN_DELTA_GAIN_QUANT + 1 ] = {
       250,    245,    234,    203,     71,     50,     42,     38,
        35,     33,     31,     29,     28,     27,     26,     25,
        24,     23,     22,     21,     20,     19,     18,     17,
        16,     15,     14,     13,     12,     11,     10,      9,
         8,      7,      6,      5,      4,      3,      2,      1,
         0
};

const opus_int16 silk_stereo_pred_quant_Q13[ STEREO_QUANT_TAB_SIZE ] = {
    -13732, -10050, -8266, -7526, -6500, -5000, -2950,  -820,
       820,   2950,  5000,  6500,  7526,  8266, 10050, 13732
};
const opus_uint8  silk_stereo_pred_joint_iCDF[ 25 ] = {
    249, 247, 246, 245, 244,
    234, 210, 202, 201, 200,
    197, 174,  82,  59,  56,
     55,  54,  46,  22,  12,
     11,  10,   9,   7,   0
};
const opus_uint8  silk_stereo_only_code_mid_iCDF[ 2 ] = { 64, 0 };
const opus_uint8 silk_LBRR_flags_2_iCDF[ 3 ] = { 203, 150, 0 };
const opus_uint8 silk_LBRR_flags_3_iCDF[ 7 ] = { 215, 195, 166, 125, 110, 82, 0 };
const opus_uint8 * const silk_LBRR_flags_iCDF_ptr[ 2 ] = {
    silk_LBRR_flags_2_iCDF,
    silk_LBRR_flags_3_iCDF
};
const opus_uint8 silk_lsb_iCDF[ 2 ] = { 120, 0 };
const opus_uint8 silk_LTPscale_iCDF[ 3 ] = { 128, 64, 0 };
const opus_uint8 silk_type_offset_VAD_iCDF[ 4 ] = {
       232,    158,    10,      0
};
const opus_uint8 silk_type_offset_no_VAD_iCDF[ 2 ] = {
       230,      0
};
const opus_uint8 silk_NLSF_interpolation_factor_iCDF[ 5 ] = { 243, 221, 192, 181, 0 };
const opus_int16  silk_Quantization_Offsets_Q10[ 2 ][ 2 ] = {
    { OFFSET_UVL_Q10, OFFSET_UVH_Q10 }, { OFFSET_VL_Q10, OFFSET_VH_Q10 }
};
const opus_int16 silk_LTPScales_table_Q14[ 3 ] = { 15565, 12288, 8192 };
const opus_uint8 silk_uniform3_iCDF[ 3 ] = { 171, 85, 0 };
const opus_uint8 silk_uniform4_iCDF[ 4 ] = { 192, 128, 64, 0 };
const opus_uint8 silk_uniform5_iCDF[ 5 ] = { 205, 154, 102, 51, 0 };
const opus_uint8 silk_uniform6_iCDF[ 6 ] = { 213, 171, 128, 85, 43, 0 };
const opus_uint8 silk_uniform8_iCDF[ 8 ] = { 224, 192, 160, 128, 96, 64, 32, 0 };
const opus_uint8 silk_NLSF_EXT_iCDF[ 7 ] = { 100, 40, 16, 7, 3, 1, 0 };

const opus_uint8 silk_pitch_lag_iCDF[ 2 * ( PITCH_EST_MAX_LAG_MS - PITCH_EST_MIN_LAG_MS ) ] = {
       253,    250,    244,    233,    212,    182,    150,    131,
       120,    110,     98,     85,     72,     60,     49,     40,
        32,     25,     19,     15,     13,     11,      9,      8,
         7,      6,      5,      4,      3,      2,      1,      0
};
const opus_uint8 silk_pitch_delta_iCDF[21] = {
       210,    208,    206,    203,    199,    193,    183,    168,
       142,    104,     74,     52,     37,     27,     20,     14,
        10,      6,      4,      2,      0
};
const opus_uint8 silk_pitch_contour_iCDF[34] = {
       223,    201,    183,    167,    152,    138,    124,    111,
        98,     88,     79,     70,     62,     56,     50,     44,
        39,     35,     31,     27,     24,     21,     18,     16,
        14,     12,     10,      8,      6,      4,      3,      2,
         1,      0
};
const opus_uint8 silk_pitch_contour_NB_iCDF[11] = {
       188,    176,    155,    138,    119,     97,     67,     43,
        26,     10,      0
};
const opus_uint8 silk_pitch_contour_10_ms_iCDF[12] = {
       165,    119,     80,     61,     47,     35,     27,     20,
        14,      9,      4,      0
};
const opus_uint8 silk_pitch_contour_10_ms_NB_iCDF[3] = {
       113,     63,      0
};

const opus_uint8 silk_pulses_per_block_iCDF[ 10 ][ 18 ] = {
{
       125,     51,     26,     18,     15,     12,     11,     10,
         9,      8,      7,      6,      5,      4,      3,      2,
         1,      0
},
{
       198,    105,     45,     22,     15,     12,     11,     10,
         9,      8,      7,      6,      5,      4,      3,      2,
         1,      0
},
{
       213,    162,    116,     83,     59,     43,     32,     24,
        18,     15,     12,      9,      7,      6,      5,      3,
         2,      0
},
{
       239,    187,    116,     59,     28,     16,     11,     10,
         9,      8,      7,      6,      5,      4,      3,      2,
         1,      0
},
{
       250,    229,    188,    135,     86,     51,     30,     19,
        13,     10,      8,      6,      5,      4,      3,      2,
         1,      0
},
{
       249,    235,    213,    185,    156,    128,    103,     83,
        66,     53,     42,     33,     26,     21,     17,     13,
        10,      0
},
{
       254,    249,    235,    206,    164,    118,     77,     46,
        27,     16,     10,      7,      5,      4,      3,      2,
         1,      0
},
{
       255,    253,    249,    239,    220,    191,    156,    119,
        85,     57,     37,     23,     15,     10,      6,      4,
         2,      0
},
{
       255,    253,    251,    246,    237,    223,    203,    179,
       152,    124,     98,     75,     55,     40,     29,     21,
        15,      0
},
{
       255,    254,    253,    247,    220,    162,    106,     67,
        42,     28,     18,     12,      9,      6,      4,      3,
         2,      0
}
};
const opus_uint8 silk_rate_levels_iCDF[ 2 ][ 9 ] =
{
{
       241,    190,    178,    132,     87,     74,     41,     14,
         0
},
{
       223,    193,    157,    140,    106,     57,     39,     18,
         0
}
};
const opus_uint8 silk_shell_code_table0[ 152 ] = {
       128,      0,    214,     42,      0,    235,    128,     21,
         0,    244,    184,     72,     11,      0,    248,    214,
       128,     42,      7,      0,    248,    225,    170,     80,
        25,      5,      0,    251,    236,    198,    126,     54,
        18,      3,      0,    250,    238,    211,    159,     82,
        35,     15,      5,      0,    250,    231,    203,    168,
       128,     88,     53,     25,      6,      0,    252,    238,
       216,    185,    148,    108,     71,     40,     18,      4,
         0,    253,    243,    225,    199,    166,    128,     90,
        57,     31,     13,      3,      0,    254,    246,    233,
       212,    183,    147,    109,     73,     44,     23,     10,
         2,      0,    255,    250,    240,    223,    198,    166,
       128,     90,     58,     33,     16,      6,      1,      0,
       255,    251,    244,    231,    210,    181,    146,    110,
        75,     46,     25,     12,      5,      1,      0,    255,
       253,    248,    238,    221,    196,    164,    128,     92,
        60,     35,     18,      8,      3,      1,      0,    255,
       253,    249,    242,    229,    208,    180,    146,    110,
        76,     48,     27,     14,      7,      3,      1,      0
};
const opus_uint8 silk_shell_code_table1[ 152 ] = {
       129,      0,    207,     50,      0,    236,    129,     20,
         0,    245,    185,     72,     10,      0,    249,    213,
       129,     42,      6,      0,    250,    226,    169,     87,
        27,      4,      0,    251,    233,    194,    130,     62,
        20,      4,      0,    250,    236,    207,    160,     99,
        47,     17,      3,      0,    255,    240,    217,    182,
       131,     81,     41,     11,      1,      0,    255,    254,
       233,    201,    159,    107,     61,     20,      2,      1,
         0,    255,    249,    233,    206,    170,    128,     86,
        50,     23,      7,      1,      0,    255,    250,    238,
       217,    186,    148,    108,     70,     39,     18,      6,
         1,      0,    255,    252,    243,    226,    200,    166,
       128,     90,     56,     30,     13,      4,      1,      0,
       255,    252,    245,    231,    209,    180,    146,    110,
        76,     47,     25,     11,      4,      1,      0,    255,
       253,    248,    237,    219,    194,    163,    128,     93,
        62,     37,     19,      8,      3,      1,      0,    255,
       254,    250,    241,    226,    205,    177,    145,    111,
        79,     51,     30,     15,      6,      2,      1,      0
};
const opus_uint8 silk_shell_code_table2[ 152 ] = {
       129,      0,    203,     54,      0,    234,    129,     23,
         0,    245,    184,     73,     10,      0,    250,    215,
       129,     41,      5,      0,    252,    232,    173,     86,
        24,      3,      0,    253,    240,    200,    129,     56,
        15,      2,      0,    253,    244,    217,    164,     94,
        38,     10,      1,      0,    253,    245,    226,    189,
       132,     71,     27,      7,      1,      0,    253,    246,
       231,    203,    159,    105,     56,     23,      6,      1,
         0,    255,    248,    235,    213,    179,    133,     85,
        47,     19,      5,      1,      0,    255,    254,    243,
       221,    194,    159,    117,     70,     37,     12,      2,
         1,      0,    255,    254,    248,    234,    208,    171,
       128,     85,     48,     22,      8,      2,      1,      0,
       255,    254,    250,    240,    220,    189,    149,    107,
        67,     36,     16,      6,      2,      1,      0,    255,
       254,    251,    243,    227,    201,    166,    128,     90,
        55,     29,     13,      5,      2,      1,      0,    255,
       254,    252,    246,    234,    213,    183,    147,    109,
        73,     43,     22,     10,      4,      2,      1,      0
};
const opus_uint8 silk_shell_code_table3[ 152 ] = {
       130,      0,    200,     58,      0,    231,    130,     26,
         0,    244,    184,     76,     12,      0,    249,    214,
       130,     43,      6,      0,    252,    232,    173,     87,
        24,      3,      0,    253,    241,    203,    131,     56,
        14,      2,      0,    254,    246,    221,    167,     94,
        35,      8,      1,      0,    254,    249,    232,    193,
       130,     65,     23,      5,      1,      0,    255,    251,
       239,    211,    162,     99,     45,     15,      4,      1,
         0,    255,    251,    243,    223,    186,    131,     74,
        33,     11,      3,      1,      0,    255,    252,    245,
       230,    202,    158,    105,     57,     24,      8,      2,
         1,      0,    255,    253,    247,    235,    214,    179,
       132,     84,     44,     19,      7,      2,      1,      0,
       255,    254,    250,    240,    223,    196,    159,    112,
        69,     36,     15,      6,      2,      1,      0,    255,
       254,    253,    245,    231,    209,    176,    136,     93,
        55,     27,     11,      3,      2,      1,      0,    255,
       254,    253,    252,    239,    221,    194,    158,    117,
        76,     42,     18,      4,      3,      2,      1,      0
};
const opus_uint8 silk_shell_code_table_offsets[ 17 ] = {
         0,      0,      2,      5,      9,     14,     20,     27,
        35,     44,     54,     65,     77,     90,    104,    119,
       135
};
const opus_uint8 silk_sign_iCDF[ 42 ] = {
       254,     49,     67,     77,     82,     93,     99,
       198,     11,     18,     24,     31,     36,     45,
       255,     46,     66,     78,     87,     94,    104,
       208,     14,     21,     32,     42,     51,     66,
       255,     94,    104,    109,    112,    115,    118,
       248,     53,     69,     80,     88,     95,    102
};

