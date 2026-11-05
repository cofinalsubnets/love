// src/love/audio/silk.c -- opus's silk layer (rfc 6716 4.2, as rfc 8251 amends it), decoded: a
// 10 or 20 ms frame of linear prediction read from the range decoder, its losses concealed,
// its stereo unmixed, resampled to 48 khz. integers only, so every build decodes the same
// samples; the tables are the format's own, as rfc 6716's reference code holds them.
// door: sk_reset, sk_decode (silk.h)
#include "silk.h"
#include <string.h>

// the range decoder's inverse cdfs
static const uint8_t sk_type_vad[4] = {232,158,10,0};
static const uint8_t sk_type_novad[2] = {230,0};
static const uint8_t sk_gain_icdf[3][8] = {
 {224,112,44,15,3,2,1,0},
 {254,237,192,132,70,23,4,0},
 {255,252,226,155,61,11,2,0}};
static const uint8_t sk_dgain_icdf[41] = {
 250,245,234,203,71,50,42,38,35,33,31,29,28,27,26,25,24,23,22,21,20,19,18,17,16,15,14,13,12,11,10,9,
 8,7,6,5,4,3,2,1,0};
static const uint8_t sk_lbrr2[3] = {203,150,0};
static const uint8_t sk_lbrr3[7] = {215,195,166,125,110,82,0};
static const uint8_t sk_joint[25] = {
 249,247,246,245,244,234,210,202,201,200,197,174,82,59,56,55,54,46,22,12,11,10,9,7,0};
static const uint8_t sk_midonly[2] = {64,0};
static const uint8_t sk_uni3[3] = {171,85,0};
static const uint8_t sk_uni4[4] = {192,128,64,0};
static const uint8_t sk_uni5[5] = {205,154,102,51,0};
static const uint8_t sk_uni6[6] = {213,171,128,85,43,0};
static const uint8_t sk_uni8[8] = {224,192,160,128,96,64,32,0};
static const uint8_t sk_ext[7] = {100,40,16,7,3,1,0};
static const uint8_t sk_interp[5] = {243,221,192,181,0};
static const uint8_t sk_lag_hi[32] = {
 253,250,244,233,212,182,150,131,120,110,98,85,72,60,49,40,32,25,19,15,13,11,9,8,7,6,5,4,3,2,1,0};
static const uint8_t sk_lag_delta[21] = {
 210,208,206,203,199,193,183,168,142,104,74,52,37,27,20,14,10,6,4,2,0};
static const uint8_t sk_contour_wb[34] = {
 223,201,183,167,152,138,124,111,98,88,79,70,62,56,50,44,39,35,31,27,24,21,18,16,14,12,10,8,6,4,3,2,
 1,0};
static const uint8_t sk_contour_nb[11] = {188,176,155,138,119,97,67,43,26,10,0};
static const uint8_t sk_contour_wb10[12] = {165,119,80,61,47,35,27,20,14,9,4,0};
static const uint8_t sk_contour_nb10[3] = {113,63,0};
static const uint8_t sk_per[3] = {179,99,0};
static const uint8_t sk_ltp0[8] = {71,56,43,30,21,12,6,0};
static const uint8_t sk_ltp1[16] = {199,165,144,124,109,96,84,71,61,51,42,32,23,15,8,0};
static const uint8_t sk_ltp2[32] = {
 241,225,211,199,187,175,164,153,142,132,123,114,105,96,88,80,72,64,57,50,44,38,33,29,24,20,16,12,9,
 5,2,0};
static const uint8_t sk_scale_icdf[3] = {128,64,0};
static const uint8_t sk_rate[2][9] = {
 {241,190,178,132,87,74,41,14,0},
 {223,193,157,140,106,57,39,18,0}};
static const uint8_t sk_count[10][18] = {
 {125,51,26,18,15,12,11,10,9,8,7,6,5,4,3,2,1,0},
 {198,105,45,22,15,12,11,10,9,8,7,6,5,4,3,2,1,0},
 {213,162,116,83,59,43,32,24,18,15,12,9,7,6,5,3,2,0},
 {239,187,116,59,28,16,11,10,9,8,7,6,5,4,3,2,1,0},
 {250,229,188,135,86,51,30,19,13,10,8,6,5,4,3,2,1,0},
 {249,235,213,185,156,128,103,83,66,53,42,33,26,21,17,13,10,0},
 {254,249,235,206,164,118,77,46,27,16,10,7,5,4,3,2,1,0},
 {255,253,249,239,220,191,156,119,85,57,37,23,15,10,6,4,2,0},
 {255,253,251,246,237,223,203,179,152,124,98,75,55,40,29,21,15,0},
 {255,254,253,247,220,162,106,67,42,28,18,12,9,6,4,3,2,0}};
static const uint8_t sk_shell0[152] = {
 128,0,214,42,0,235,128,21,0,244,184,72,11,0,248,214,128,42,7,0,248,225,170,80,25,5,0,251,236,198,
 126,54,18,3,0,250,238,211,159,82,35,15,5,0,250,231,203,168,128,88,53,25,6,0,252,238,216,185,148,
 108,71,40,18,4,0,253,243,225,199,166,128,90,57,31,13,3,0,254,246,233,212,183,147,109,73,44,23,10,2,
 0,255,250,240,223,198,166,128,90,58,33,16,6,1,0,255,251,244,231,210,181,146,110,75,46,25,12,5,1,0,
 255,253,248,238,221,196,164,128,92,60,35,18,8,3,1,0,255,253,249,242,229,208,180,146,110,76,48,27,
 14,7,3,1,0};
static const uint8_t sk_shell1[152] = {
 129,0,207,50,0,236,129,20,0,245,185,72,10,0,249,213,129,42,6,0,250,226,169,87,27,4,0,251,233,194,
 130,62,20,4,0,250,236,207,160,99,47,17,3,0,255,240,217,182,131,81,41,11,1,0,255,254,233,201,159,
 107,61,20,2,1,0,255,249,233,206,170,128,86,50,23,7,1,0,255,250,238,217,186,148,108,70,39,18,6,1,0,
 255,252,243,226,200,166,128,90,56,30,13,4,1,0,255,252,245,231,209,180,146,110,76,47,25,11,4,1,0,
 255,253,248,237,219,194,163,128,93,62,37,19,8,3,1,0,255,254,250,241,226,205,177,145,111,79,51,30,
 15,6,2,1,0};
static const uint8_t sk_shell2[152] = {
 129,0,203,54,0,234,129,23,0,245,184,73,10,0,250,215,129,41,5,0,252,232,173,86,24,3,0,253,240,200,
 129,56,15,2,0,253,244,217,164,94,38,10,1,0,253,245,226,189,132,71,27,7,1,0,253,246,231,203,159,105,
 56,23,6,1,0,255,248,235,213,179,133,85,47,19,5,1,0,255,254,243,221,194,159,117,70,37,12,2,1,0,255,
 254,248,234,208,171,128,85,48,22,8,2,1,0,255,254,250,240,220,189,149,107,67,36,16,6,2,1,0,255,254,
 251,243,227,201,166,128,90,55,29,13,5,2,1,0,255,254,252,246,234,213,183,147,109,73,43,22,10,4,2,1,0};
static const uint8_t sk_shell3[152] = {
 130,0,200,58,0,231,130,26,0,244,184,76,12,0,249,214,130,43,6,0,252,232,173,87,24,3,0,253,241,203,
 131,56,14,2,0,254,246,221,167,94,35,8,1,0,254,249,232,193,130,65,23,5,1,0,255,251,239,211,162,99,
 45,15,4,1,0,255,251,243,223,186,131,74,33,11,3,1,0,255,252,245,230,202,158,105,57,24,8,2,1,0,255,
 253,247,235,214,179,132,84,44,19,7,2,1,0,255,254,250,240,223,196,159,112,69,36,15,6,2,1,0,255,254,
 253,245,231,209,176,136,93,55,27,11,3,2,1,0,255,254,253,252,239,221,194,158,117,76,42,18,4,3,2,1,0};
static const uint8_t sk_shell_at[17] = {0,0,2,5,9,14,20,27,35,44,54,65,77,90,104,119,135};
static const uint8_t sk_lsb[2] = {120,0};
static const uint8_t sk_sign[6][7] = {
 {254,49,67,77,82,93,99},
 {198,11,18,24,31,36,45},
 {255,46,66,78,87,94,104},
 {208,14,21,32,42,51,66},
 {255,94,104,109,112,115,118},
 {248,53,69,80,88,95,102}};

// lsf codebooks: narrow and medium band (order 10), then wide (order 16)
static const uint8_t sk_nb_cb[320] = {
 12,35,60,83,108,132,157,180,206,228,15,32,55,77,101,125,151,175,201,225,19,42,66,89,114,137,162,
 184,209,230,12,25,50,72,97,120,147,172,200,223,26,44,69,90,114,135,159,180,205,225,13,22,53,80,106,
 130,156,180,205,228,15,25,44,64,90,115,142,168,196,222,19,24,62,82,100,120,145,168,190,214,22,31,
 50,79,103,120,151,170,203,227,21,29,45,65,106,124,150,171,196,224,30,49,75,97,121,142,165,186,209,
 229,19,25,52,70,93,116,143,166,192,219,26,34,62,75,97,118,145,167,194,217,25,33,56,70,91,113,143,
 165,196,223,21,34,51,72,97,117,145,171,196,222,20,29,50,67,90,117,144,168,197,221,22,31,48,66,95,
 117,146,168,196,222,24,33,51,77,116,134,158,180,200,224,21,28,70,87,106,124,149,170,194,217,26,33,
 53,64,83,117,152,173,204,225,27,34,65,95,108,129,155,174,210,225,20,26,72,99,113,131,154,176,200,
 219,34,43,61,78,93,114,155,177,205,229,23,29,54,97,124,138,163,179,209,229,30,38,56,89,118,129,158,
 178,200,231,21,29,49,63,85,111,142,163,193,222,27,48,77,103,133,158,179,196,215,232,29,47,74,99,
 124,151,176,198,220,237,33,42,61,76,93,121,155,174,207,225,29,53,87,112,136,154,170,188,208,227,24,
 30,52,84,131,150,166,186,203,229,37,48,64,84,104,118,156,177,201,230};
static const uint8_t sk_nb_icdf[64] = {
 212,178,148,129,108,96,85,82,79,77,61,59,57,56,51,49,48,45,42,41,40,38,36,34,31,30,21,12,10,3,1,0,
 255,245,244,236,233,225,217,203,190,176,175,161,149,136,125,114,102,91,81,71,60,52,43,35,28,20,19,
 18,12,11,5,0};
static const uint8_t sk_nb_sel[160] = {
 16,0,0,0,0,99,66,36,36,34,36,34,34,34,34,83,69,36,52,34,116,102,70,68,68,176,102,68,68,34,65,85,68,
 84,36,116,141,152,139,170,132,187,184,216,137,132,249,168,185,139,104,102,100,68,68,178,218,185,
 185,170,244,216,187,187,170,244,187,187,219,138,103,155,184,185,137,116,183,155,152,136,132,217,
 184,184,170,164,217,171,155,139,244,169,184,185,170,164,216,223,218,138,214,143,188,218,168,244,
 141,136,155,170,168,138,220,219,139,164,219,202,216,137,168,186,246,185,139,116,185,219,185,138,
 100,100,134,100,102,34,68,68,100,68,168,203,221,218,168,167,154,136,104,70,164,246,171,137,139,137,
 155,218,219,139};
static const uint8_t sk_nb_ec[72] = {
 255,254,253,238,14,3,2,1,0,255,254,252,218,35,3,2,1,0,255,254,250,208,59,4,2,1,0,255,254,246,194,
 71,10,2,1,0,255,252,236,183,82,8,2,1,0,255,252,235,180,90,17,2,1,0,255,248,224,171,97,30,4,1,0,255,
 254,236,173,95,37,7,1,0};
static const uint8_t sk_nb_pred[18] = {
 179,138,140,148,151,149,153,151,163,116,67,82,59,92,72,100,89,92};
static const int16_t sk_nb_dmin[11] = {250,3,6,3,3,3,4,3,3,3,461};
static const uint8_t sk_wb_cb[512] = {
 7,23,38,54,69,85,100,116,131,147,162,178,193,208,223,239,13,25,41,55,69,83,98,112,127,142,157,171,
 187,203,220,236,15,21,34,51,61,78,92,106,126,136,152,167,185,205,225,240,10,21,36,50,63,79,95,110,
 126,141,157,173,189,205,221,237,17,20,37,51,59,78,89,107,123,134,150,164,184,205,224,240,10,15,32,
 51,67,81,96,112,129,142,158,173,189,204,220,236,8,21,37,51,65,79,98,113,126,138,155,168,179,192,
 209,218,12,15,34,55,63,78,87,108,118,131,148,167,185,203,219,236,16,19,32,36,56,79,91,108,118,136,
 154,171,186,204,220,237,11,28,43,58,74,89,105,120,135,150,165,180,196,211,226,241,6,16,33,46,60,75,
 92,107,123,137,156,169,185,199,214,225,11,19,30,44,57,74,89,105,121,135,152,169,186,202,218,234,12,
 19,29,46,57,71,88,100,120,132,148,165,182,199,216,233,17,23,35,46,56,77,92,106,123,134,152,167,185,
 204,222,237,14,17,45,53,63,75,89,107,115,132,151,171,188,206,221,240,9,16,29,40,56,71,88,103,119,
 137,154,171,189,205,222,237,16,19,36,48,57,76,87,105,118,132,150,167,185,202,218,236,12,17,29,54,
 71,81,94,104,126,136,149,164,182,201,221,237,15,28,47,62,79,97,115,129,142,155,168,180,194,208,223,
 238,8,14,30,45,62,78,94,111,127,143,159,175,192,207,223,239,17,30,49,62,79,92,107,119,132,145,160,
 174,190,204,220,235,14,19,36,45,61,76,91,108,121,138,154,172,189,205,222,238,12,18,31,45,60,76,91,
 107,123,138,154,171,187,204,221,236,13,17,31,43,53,70,83,103,114,131,149,167,185,203,220,237,17,22,
 35,42,58,78,93,110,125,139,155,170,188,206,224,240,8,15,34,50,67,83,99,115,131,146,162,178,193,209,
 224,239,13,16,41,66,73,86,95,111,128,137,150,163,183,206,225,241,17,25,37,52,63,75,92,102,119,132,
 144,160,175,191,212,231,19,31,49,65,83,100,117,133,147,161,174,187,200,213,227,242,18,31,52,68,88,
 103,117,126,138,149,163,177,192,207,223,239,16,29,47,61,76,90,106,119,133,147,161,176,193,209,224,
 240,15,21,35,50,61,73,86,97,110,119,129,141,175,198,218,237};
static const uint8_t sk_wb_icdf[64] = {
 225,204,201,184,183,175,158,154,153,135,119,115,113,110,109,99,98,95,79,68,52,50,48,45,43,32,31,27,
 18,10,3,0,255,251,235,230,212,201,196,182,167,166,163,151,138,124,110,104,90,78,76,70,69,57,45,34,
 24,21,11,6,5,4,3,0};
static const uint8_t sk_wb_sel[256] = {
 0,0,0,0,0,0,0,1,100,102,102,68,68,36,34,96,164,107,158,185,180,185,139,102,64,66,36,34,34,0,1,32,
 208,139,141,191,152,185,155,104,96,171,104,166,102,102,102,132,1,0,0,0,0,16,16,0,80,109,78,107,185,
 139,103,101,208,212,141,139,173,153,123,103,36,0,0,0,0,0,0,1,48,0,0,0,0,0,0,32,68,135,123,119,119,
 103,69,98,68,103,120,118,118,102,71,98,134,136,157,184,182,153,139,134,208,168,248,75,189,143,121,
 107,32,49,34,34,34,0,17,2,210,235,139,123,185,137,105,134,98,135,104,182,100,183,171,134,100,70,68,
 70,66,66,34,131,64,166,102,68,36,2,1,0,134,166,102,68,34,34,66,132,212,246,158,139,107,107,87,102,
 100,219,125,122,137,118,103,132,114,135,137,105,171,106,50,34,164,214,141,143,185,151,121,103,192,
 34,0,0,0,0,0,1,208,109,74,187,134,249,159,137,102,110,154,118,87,101,119,101,0,2,0,36,36,66,68,35,
 96,164,102,100,36,0,2,33,167,138,174,102,100,84,2,2,100,107,120,119,36,197,24,0};
static const uint8_t sk_wb_ec[72] = {
 255,254,253,244,12,3,2,1,0,255,254,252,224,38,3,2,1,0,255,254,251,209,57,4,2,1,0,255,254,244,195,
 69,4,2,1,0,255,251,232,184,84,7,2,1,0,255,254,240,186,86,14,2,1,0,255,254,239,178,91,30,5,1,0,255,
 248,227,177,100,19,2,1,0};
static const uint8_t sk_wb_pred[30] = {
 175,148,160,176,178,173,174,164,177,174,196,182,198,192,182,68,62,66,60,72,117,85,90,118,136,151,
 142,160,142,155};
static const int16_t sk_wb_dmin[17] = {100,3,40,3,3,3,5,14,14,10,11,3,8,9,7,3,347};
static const int16_t sk_cos[129] = {
 8192,8190,8182,8170,8152,8130,8104,8072,8034,7994,7946,7896,7840,7778,7714,7644,7568,7490,7406,
 7318,7226,7128,7026,6922,6812,6698,6580,6458,6332,6204,6070,5934,5792,5648,5502,5352,5198,5040,
 4880,4718,4552,4382,4212,4038,3862,3684,3502,3320,3136,2948,2760,2570,2378,2186,1990,1794,1598,
 1400,1202,1002,802,602,402,202,0,-202,-402,-602,-802,-1002,-1202,-1400,-1598,-1794,-1990,-2186,
 -2378,-2570,-2760,-2948,-3136,-3320,-3502,-3684,-3862,-4038,-4212,-4382,-4552,-4718,-4880,-5040,
 -5198,-5352,-5502,-5648,-5792,-5934,-6070,-6204,-6332,-6458,-6580,-6698,-6812,-6922,-7026,-7128,
 -7226,-7318,-7406,-7490,-7568,-7644,-7714,-7778,-7840,-7896,-7946,-7994,-8034,-8072,-8104,-8130,
 -8152,-8170,-8182,-8190,-8192};

// pitch contours, ltp filters, stereo weights
static const int8_t sk_lags_nb[44] = {
 0,2,-1,-1,-1,0,0,1,1,0,1,0,1,0,0,0,0,0,1,0,0,0,0,0,1,0,0,0,1,0,0,0,0,0,-1,2,1,0,1,1,0,0,-1,-1};
static const int8_t sk_lags_wb[136] = {
 0,0,1,-1,0,1,-1,0,-1,1,-2,2,-2,-2,2,-3,2,3,-3,-4,3,-4,4,4,-5,5,-6,-5,6,-7,6,5,8,-9,0,0,1,0,0,0,0,0,
 0,0,-1,1,0,0,1,-1,0,1,-1,-1,1,-1,2,1,-1,2,-2,-2,2,-2,2,2,3,-3,0,1,0,0,0,0,0,0,1,0,1,0,0,1,-1,1,0,0,
 2,1,-1,2,-1,-1,2,-1,2,2,-1,3,-2,-2,-2,3,0,1,0,0,1,0,1,-1,2,-1,2,-1,2,3,-2,3,-2,-2,4,4,-3,5,-3,-4,6,
 -4,6,5,-5,8,-6,-5,-7,9};
static const int8_t sk_lags_nb10[6] = {0,1,0,0,0,1};
static const int8_t sk_lags_wb10[24] = {0,0,1,-1,1,-1,2,-2,2,-2,3,-3,0,1,0,1,-1,2,-1,2,-2,3,-2,3};
static const int8_t sk_vq0[40] = {
 4,6,24,7,5,0,0,2,0,0,12,28,41,13,-4,-9,15,42,25,14,1,-2,62,41,-9,-10,37,65,-4,3,-6,4,66,7,-8,16,14,
 38,-3,33};
static const int8_t sk_vq1[80] = {
 13,22,39,23,12,-1,36,64,27,-6,-7,10,55,43,17,1,1,8,1,1,6,-11,74,53,-9,-12,55,76,-12,8,-3,3,93,27,
 -4,26,39,59,3,-8,2,0,77,11,9,-8,22,44,-6,7,40,9,26,3,9,-7,20,101,-7,4,3,-8,42,26,0,-15,33,68,2,23,
 -2,55,46,-2,15,3,-1,21,16,41};
static const int8_t sk_vq2[160] = {
 -6,27,61,39,5,-11,42,88,4,1,-2,60,65,6,-4,-1,-5,73,56,1,-9,19,94,29,-9,0,12,99,6,4,8,-19,102,46,
 -13,3,2,13,3,2,9,-21,84,72,-18,-11,46,104,-22,8,18,38,48,23,0,-16,70,83,-21,11,5,-11,117,22,-8,-6,
 23,117,-12,3,3,-8,95,28,4,-10,15,77,60,-15,-1,4,124,2,-4,3,38,84,24,-25,2,13,42,13,31,21,-4,56,46,
 -1,-1,35,79,-13,19,-7,65,88,-9,-14,20,4,81,49,-29,20,0,75,3,-17,5,-9,44,92,-8,1,-3,22,69,31,-6,95,
 41,-12,5,39,67,16,-4,1,0,-6,120,55,-36,-13,44,122,4,-24,81,5,11,3,7,2,0,9,10,88};
static const int16_t sk_stereo[16] = {
 -13732,-10050,-8266,-7526,-6500,-5000,-2950,-820,820,2950,5000,6500,7526,8266,10050,13732};

// the resampler: two allpass chains doubling the rate, then a 12-phase interpolator
static const int16_t sk_up2[3] = {1746,14986,-26453};
static const int16_t sk_up2b[3] = {6854,25769,-9994};
static const int16_t sk_frac[48] = {
 189,-600,617,30567,117,-159,-1070,29704,52,221,-2392,28276,-4,529,-3350,26341,-48,758,-3956,23973,
 -80,905,-4235,21254,-99,972,-4222,18278,-107,967,-3957,15143,-103,896,-3487,11950,-91,773,-2865,
 8798,-71,611,-2143,5784,-46,425,-1375,2996};

struct sk_cb { int order, step;           // step: the residual quantizer's, q16
 const uint8_t *cb, *icdf, *sel, *ec, *pred; const int16_t *dmin; };
static const struct sk_cb sk_nb = { 10, 11796, sk_nb_cb, sk_nb_icdf, sk_nb_sel, sk_nb_ec, sk_nb_pred, sk_nb_dmin };
static const struct sk_cb sk_wb = { 16, 9830, sk_wb_cb, sk_wb_icdf, sk_wb_sel, sk_wb_ec, sk_wb_pred, sk_wb_dmin };
static const uint8_t *const sk_ltp_icdf[3] = { sk_ltp0, sk_ltp1, sk_ltp2 };
static const int8_t *const sk_vq[3] = { sk_vq0, sk_vq1, sk_vq2 };
static const int16_t sk_offset[2][2] = { { 100, 240 }, { 32, 100 } };   // by voicing, then type
static const int16_t sk_ltp_scale[3] = { 15565, 12288, 8192 };

// one frame's decoded filters
struct sk_ctl { int pitch[4]; int32_t gain[4]; int16_t a[2][16], b[20]; int scale; };

// fixed point: q16 products, rounding shifts, wrapping sums, saturation
static int32_t wq(int32_t a, int32_t b) { return (int32_t) ((int64_t) a * b >> 16); }
static int32_t hi32(int32_t a, int32_t b) { return (int32_t) ((int64_t) a * b >> 32); }
static int32_t rnd(int32_t a, int s) { return ((a >> (s - 1)) + 1) >> 1; }
static int64_t rnd64(int64_t a, int s) { return ((a >> (s - 1)) + 1) >> 1; }
static int32_t add(int32_t a, int32_t b) { return (int32_t) ((uint32_t) a + (uint32_t) b); }
static int32_t shl(int32_t a, int s) { return (int32_t) ((uint32_t) a << s); }
static int16_t sat(int32_t a) { return (int16_t) (a > 32767 ? 32767 : a < -32768 ? -32768 : a); }
static int32_t imin(int32_t a, int32_t b) { return a < b ? a : b; }
static int32_t imax(int32_t a, int32_t b) { return a > b ? a : b; }
static int32_t lim(int32_t a, int32_t l, int32_t h) {   // bounds in either order
 return l > h ? (a > l ? l : a < h ? h : a) : a > h ? h : a < l ? l : a; }
static uint32_t uabs(int32_t a) { return a > 0 ? (uint32_t) a : 0u - (uint32_t) a; }
static int clz(uint32_t x) { int n = 0; if (!x) return 32; while (!(x >> 31)) x <<= 1, n++; return n; }
static int32_t next(int32_t s) { return (int32_t) (907633515u + (uint32_t) s * 196314165u); }

static int32_t lsat(int32_t a, int s) { return shl(lim(a, INT32_MIN >> s, INT32_MAX >> s), s); }

// a / b in q, from a 16-bit reciprocal and one correction step
static int32_t divq(int32_t a, int32_t b, int q) {
 int ah = clz(uabs(a)) - 1, bh = clz(uabs(b)) - 1;
 int32_t an = shl(a, ah), bn = shl(b, bh), bi = (INT32_MAX >> 2) / (bn >> 16);
 int32_t r = wq(an, (int16_t) bi);
 an = add(an, -shl(hi32(bn, r), 3));
 r += wq(an, (int16_t) bi);
 int s = 29 + ah - bh - q;
 return s < 0 ? lsat(r, -s) : s < 32 ? r >> s : 0; }

// 1 / b in q
static int32_t invq(int32_t b, int q) {
 int bh = clz(uabs(b)) - 1;
 int32_t bn = shl(b, bh), bi = (INT32_MAX >> 2) / (bn >> 16);
 int32_t e = shl((1 << 29) - wq(bn, (int16_t) bi), 3), r = add(shl(bi, 16), wq(e, bi));
 int s = 61 - bh - q;
 return s <= 0 ? lsat(r, -s) : s < 32 ? r >> s : 0; }

// the 7 bits under x's leading one
static int32_t frac7(uint32_t x, int lz) { return (int32_t) ((lz <= 24 ? x >> (24 - lz) : x << (lz - 24)) & 127); }

static int32_t sqrta(int32_t x) {
 if (x <= 0) return 0;
 int lz = clz((uint32_t) x);
 int32_t y = (lz & 1 ? 32768 : 46214) >> (lz >> 1);
 return y + wq(y, 213 * frac7((uint32_t) x, lz)); }

// 2^(x/128), x in q7
static int32_t log2lin(int32_t x) {
 if (x < 0) return 0;
 int32_t o = 1 << (x >> 7), f = x & 127, t = f + wq(f * (128 - f), -174);
 return x < 2048 ? o + (o * t >> 7) : o + (o >> 7) * t; }

// a block's energy, shifted right by *sh to fit
static void energy(int32_t *e, int *sh, const int16_t *x, int n) {
 int32_t s = 0;
 int i, k = 0;
 n--;
 for (i = 0; i < n; i += 2) {
  s = add(s, x[i] * x[i]), s = add(s, x[i + 1] * x[i + 1]);
  if (s < 0) { s = (int32_t) ((uint32_t) s >> 2), k = 2; break; } }
 for (; i < n; i += 2) {
  uint32_t t = (uint32_t) (x[i] * x[i]) + (uint32_t) (x[i + 1] * x[i + 1]);
  s = (int32_t) ((uint32_t) s + (t >> k));
  if (s < 0) s = (int32_t) ((uint32_t) s >> 2), k += 2; }
 if (i == n) s = (int32_t) ((uint32_t) s + ((uint32_t) (x[i] * x[i]) >> k));
 if (s & 0xc0000000) s = (int32_t) ((uint32_t) s >> 2), k += 2;
 *e = s, *sh = k; }

// bandwidth expansion: tap i scaled by c^(i+1), c in q16
static void bwx(int16_t *a, int d, int32_t c) {
 int32_t m = c - 65536;
 for (int i = 0; i < d - 1; i++) a[i] = (int16_t) rnd(c * a[i], 16), c += rnd(c * m, 16);
 a[d - 1] = (int16_t) rnd(c * a[d - 1], 16); }

static void bwx32(int32_t *a, int d, int32_t c) {
 int32_t m = c - 65536;
 for (int i = 0; i < d - 1; i++) a[i] = wq(c, a[i]), c += rnd(c * m, 16);
 a[d - 1] = wq(c, a[d - 1]); }

// the filter's inverse prediction gain in q30 by the step-down recursion, 0 when unstable
static int32_t pred_gain(const int16_t *a, int d) {
 int32_t t[2][16], *an = t[d & 1], g = 1 << 30, dc = 0;
 const int32_t top = 16773022;                           // 0.99975 in q24
 for (int k = 0; k < d; k++) dc += a[k], an[k] = shl(a[k], 12);
 if (dc >= 4096) return 0;
 for (int k = d - 1; k > 0; k--) {
  if (an[k] > top || an[k] < -top) return 0;
  int32_t rc = -shl(an[k], 7), m1 = (1 << 30) - hi32(rc, rc), *ao = an;
  int q = 32 - clz(uabs(m1));
  int32_t m2 = invq(m1, q + 30);
  g = shl(hi32(g, m1), 2);
  an = t[k & 1];
  for (int n = 0; n < k; n++) {
   int64_t x = (int64_t) ao[n] - rnd64((int64_t) ao[k - n - 1] * rc, 31);
   x = x > INT32_MAX ? INT32_MAX : x < INT32_MIN ? INT32_MIN : x;
   x = rnd64(x * m2, q);
   if (x > INT32_MAX || x < INT32_MIN) return 0;
   an[n] = (int32_t) x; } }
 if (an[0] > top || an[0] < -top) return 0;
 int32_t rc = -shl(an[0], 7);
 return shl(hi32(g, (1 << 30) - hi32(rc, rc)), 2); }

// a polynomial from every other cosine, q16
static void lsf_poly(int32_t *o, const int32_t *c, int dd) {
 o[0] = 1 << 16, o[1] = -c[0];
 for (int k = 1; k < dd; k++) {
  int32_t f = c[2 * k];
  o[k + 1] = shl(o[k - 1], 1) - (int32_t) rnd64((int64_t) f * o[k], 16);
  for (int n = k; n > 1; n--) o[n] += o[n - 2] - (int32_t) rnd64((int64_t) f * o[n - 1], 16);
  o[1] -= f; } }

// line spectral frequencies (q15) to a stable q12 filter
static void lsf2a(int16_t *a, const int16_t *f, int d) {
 static const uint8_t ord16[16] = { 0, 15, 8, 7, 4, 11, 12, 3, 2, 13, 10, 5, 6, 9, 14, 1 };
 static const uint8_t ord10[10] = { 0, 9, 6, 3, 4, 5, 8, 1, 2, 7 };
 const uint8_t *ord = d == 16 ? ord16 : ord10;
 int32_t c[16], p[9], q[9], a32[16];
 int dd = d >> 1, i, k;
 for (k = 0; k < d; k++) {
  int fi = f[k] >> 8, ff = f[k] - (fi << 8);
  c[ord[k]] = rnd((sk_cos[fi] * 256) + (sk_cos[fi + 1] - sk_cos[fi]) * ff, 4); }
 lsf_poly(p, c, dd), lsf_poly(q, c + 1, dd);
 for (k = 0; k < dd; k++) {
  int32_t pt = p[k + 1] + p[k], qt = q[k + 1] - q[k];
  a32[k] = -qt - pt, a32[d - k - 1] = qt - pt; }
 for (i = 0; i < 10; i++) {                              // bring the taps into 16 bits
  int32_t mx = 0; int at = 0;
  for (k = 0; k < d; k++) if ((int32_t) uabs(a32[k]) > mx) mx = (int32_t) uabs(a32[k]), at = k;
  mx = rnd(mx, 5);
  if (mx <= 32767) break;
  mx = imin(mx, 163838);
  bwx32(a32, d, 65470 - shl(mx - 32767, 14) / ((mx * (at + 1)) >> 2)); }
 for (k = 0; k < d; k++)
  if (i == 10) a[k] = sat(rnd(a32[k], 5)), a32[k] = shl(a[k], 5);
  else a[k] = (int16_t) rnd(a32[k], 5);
 for (i = 0; i < 16 && pred_gain(a, d) < 107374; i++) {  // 1e-4 in q30: stable enough
  bwx32(a32, d, 65536 - (2 << i));
  for (k = 0; k < d; k++) a[k] = (int16_t) rnd(a32[k], 5); } }

// a codebook vector's residual contexts and predictor weights
static void lsf_unpack(int16_t *ec, uint8_t *pr, const struct sk_cb *cb, int v) {
 const uint8_t *s = cb->sel + v * cb->order / 2;
 for (int i = 0; i < cb->order; i += 2, s++) {
  ec[i] = (int16_t) ((*s >> 1 & 7) * 9), pr[i] = cb->pred[i + (*s & 1) * (cb->order - 1)];
  ec[i + 1] = (int16_t) ((*s >> 5 & 7) * 9), pr[i + 1] = cb->pred[i + (*s >> 4 & 1) * (cb->order - 1) + 1]; } }

// keep the frequencies ordered and at least dm apart
static void lsf_stable(int16_t *x, const int16_t *dm, int n) {
 for (int it = 0; it < 20; it++) {
  int32_t md = x[0] - dm[0], dd;
  int at = 0;
  for (int i = 1; i < n; i++) if ((dd = x[i] - (x[i - 1] + dm[i])) < md) md = dd, at = i;
  if ((dd = 32768 - (x[n - 1] + dm[n])) < md) md = dd, at = n;
  if (md >= 0) return;
  if (at == 0) x[0] = dm[0];
  else if (at == n) x[n - 1] = (int16_t) (32768 - dm[n]);
  else {
   int32_t lo = 0, hi = 32768;
   for (int k = 0; k < at; k++) lo += dm[k];
   for (int k = n; k > at; k--) hi -= dm[k];
   lo += dm[at] >> 1, hi -= dm[at] >> 1;
   int16_t c = (int16_t) lim(rnd(x[at - 1] + x[at], 1), lo, hi);
   x[at - 1] = (int16_t) (c - (dm[at] >> 1)), x[at] = (int16_t) (x[at - 1] + dm[at]); } }
 for (int i = 1; i < n; i++) {                           // no luck: sort, then push apart
  int16_t v = x[i]; int j;
  for (j = i - 1; j >= 0 && v < x[j]; j--) x[j + 1] = x[j];
  x[j + 1] = v; }
 x[0] = (int16_t) imax(x[0], dm[0]);
 for (int i = 1; i < n; i++) x[i] = (int16_t) imax(x[i], sat(x[i - 1] + dm[i]));
 x[n - 1] = (int16_t) imin(x[n - 1], 32768 - dm[n]);
 for (int i = n - 2; i >= 0; i--) x[i] = (int16_t) imin(x[i], x[i + 1] - dm[i + 1]); }

// the coded indices to frequencies: a codebook vector plus a predicted, weighted residual
static void lsf_decode(int16_t *f, const int8_t *ix, const struct sk_cb *cb) {
 int d = cb->order, i;
 int16_t ec[16], res[16], w[16];
 uint8_t pr[16];
 for (i = 0; i < d; i++) f[i] = (int16_t) (cb->cb[ix[0] * d + i] << 7);
 lsf_unpack(ec, pr, cb, ix[0]);
 int32_t o = 0;
 for (i = d - 1; i >= 0; i--) {
  int32_t p = (int16_t) o * pr[i] >> 8;
  o = ix[i + 1] * 1024;
  o += o > 0 ? -102 : o < 0 ? 102 : 0;
  res[i] = (int16_t) (o = p + wq(o, cb->step)); }
 int32_t a = (1 << 17) / imax(f[0], 1), b = (1 << 17) / imax(f[1] - f[0], 1);   // laroia's weights
 w[0] = (int16_t) imin(a + b, 32767);
 for (i = 1; i < d - 1; i += 2) {
  a = (1 << 17) / imax(f[i + 1] - f[i], 1), w[i] = (int16_t) imin(a + b, 32767);
  b = (1 << 17) / imax(f[i + 2] - f[i + 1], 1), w[i + 1] = (int16_t) imin(a + b, 32767); }
 a = (1 << 17) / imax(32768 - f[d - 1], 1), w[d - 1] = (int16_t) imin(a + b, 32767);
 for (i = 0; i < d; i++) f[i] = (int16_t) lim(f[i] + shl(res[i], 14) / sqrta(shl(w[i], 16)), 0, 32767);
 lsf_stable(f, cb->dmin, d); }

// the whitening filter: o[i] = x[i] - prediction, the first d left zero
static void lpc_res(int16_t *o, const int16_t *x, const int16_t *b, int n, int d) {
 for (int i = d; i < n; i++) {
  uint32_t s = 0;
  for (int j = 0; j < d; j++) s += (uint32_t) (x[i - 1 - j] * b[j]);
  o[i] = sat(rnd((int32_t) (((uint32_t) x[i] << 12) - s), 12)); }
 memset(o, 0, (size_t) d * 2); }

// one step of the synthesis filter over q14 history h (h[-1] the latest), in q10
static int32_t lpc_step(const int32_t *h, const int16_t *a, int d) {
 int32_t s = d >> 1;
 for (int j = 0; j < d; j++) s = add(s, wq(h[-1 - j], a[j]));
 return s; }

// the long-term predictor's 5 taps around h[0]
static int32_t ltp_step(const int32_t *h, const int16_t *b) {
 int32_t s = 2;
 for (int j = 0; j < 5; j++) s = add(s, wq(h[-j], b[j]));
 return s; }

static const struct sk_cb *sk_book(const struct sk_ch *c) { return c->khz == 16 ? &sk_wb : &sk_nb; }

// a frame's side information
static void read_indices(struct sk_ch *c, struct rdec *d, int fi, int lbrr, int cond) {
 struct sk_idx *x = &c->ix;
 const struct sk_cb *cb = sk_book(c);
 int t = lbrr || c->vad[fi] ? rd_icdf(d, sk_type_vad, 8) + 2 : rd_icdf(d, sk_type_novad, 8), i;
 x->type = t >> 1, x->offset = t & 1;
 if (cond == 2) x->gain[0] = (int8_t) rd_icdf(d, sk_dgain_icdf, 8);
 else {
  x->gain[0] = (int8_t) (rd_icdf(d, sk_gain_icdf[x->type], 8) << 3);
  x->gain[0] += (int8_t) rd_icdf(d, sk_uni8, 8); }
 for (i = 1; i < c->nsub; i++) x->gain[i] = (int8_t) rd_icdf(d, sk_dgain_icdf, 8);
 x->lsf[0] = (int8_t) rd_icdf(d, cb->icdf + (x->type >> 1) * 32, 8);
 int16_t ec[16]; uint8_t pr[16];
 lsf_unpack(ec, pr, cb, x->lsf[0]);
 for (i = 0; i < cb->order; i++) {
  int v = rd_icdf(d, cb->ec + ec[i], 8);
  if (v == 0) v -= rd_icdf(d, sk_ext, 8);
  else if (v == 8) v += rd_icdf(d, sk_ext, 8);
  x->lsf[i + 1] = (int8_t) (v - 4); }
 x->interp = c->nsub == 4 ? rd_icdf(d, sk_interp, 8) : 4;
 if (x->type == 2) {
  int abs = 1;
  if (cond == 2 && c->ec_type == 2) {
   int dl = rd_icdf(d, sk_lag_delta, 8);
   if (dl > 0) x->lag = (int16_t) (c->ec_lag + dl - 9), abs = 0; }
  if (abs) {
   x->lag = rd_icdf(d, sk_lag_hi, 8) * (c->khz >> 1);
   x->lag += rd_icdf(d, c->khz == 16 ? sk_uni8 : c->khz == 12 ? sk_uni6 : sk_uni4, 8); }
  c->ec_lag = x->lag;
  x->contour = rd_icdf(d, c->khz == 8 ? (c->nsub == 4 ? sk_contour_nb : sk_contour_nb10)
                                      : (c->nsub == 4 ? sk_contour_wb : sk_contour_wb10), 8);
  x->per = rd_icdf(d, sk_per, 8);
  for (i = 0; i < c->nsub; i++) x->ltp[i] = (int8_t) rd_icdf(d, sk_ltp_icdf[x->per], 8);
  x->scale = cond == 0 ? rd_icdf(d, sk_scale_icdf, 8) : 0; }
 c->ec_type = x->type;
 x->seed = rd_icdf(d, sk_uni4, 8); }

// split a block's pulses in halves down to single samples, each left half first
static void shell(struct rdec *d, int *p, int t, int sum) {
 static const uint8_t *const tab[4] = { sk_shell0, sk_shell1, sk_shell2, sk_shell3 };
 int l = sum > 0 ? rd_icdf(d, tab[t] + sk_shell_at[sum], 8) : 0;
 if (t) shell(d, p, t - 1, l), shell(d, p + (1 << t), t - 1, sum - l);
 else p[0] = l, p[1] = sum - l; }

// the excitation's pulses: counts per 16-sample block, their places, low bits, signs
static void read_pulses(struct rdec *d, int *p, int type, int off, int n) {
 int sum[20], sh[20], nb = (n + 15) >> 4, i, j, k;
 int r = rd_icdf(d, sk_rate[type >> 1], 8);
 for (i = 0; i < nb; i++) {
  sh[i] = 0, sum[i] = rd_icdf(d, sk_count[r], 8);
  while (sum[i] == 17) sh[i]++, sum[i] = rd_icdf(d, sk_count[9] + (sh[i] == 10), 8); }
 for (i = 0; i < nb; i++)
  if (sum[i] > 0) shell(d, p + 16 * i, 3, sum[i]);
  else memset(p + 16 * i, 0, 16 * sizeof *p);
 for (i = 0; i < nb; i++)
  if (sh[i] > 0) {
   for (k = 0; k < 16; k++) {
    int a = p[16 * i + k];
    for (j = 0; j < sh[i]; j++) a = 2 * a + rd_icdf(d, sk_lsb, 8);
    p[16 * i + k] = a; }
   sum[i] |= sh[i] << 5; }
 uint8_t ic[2] = { 0, 0 };
 for (i = 0; i < nb; i++)
  if (sum[i] > 0) {
   ic[0] = sk_sign[off + 2 * type][imin(sum[i] & 31, 6)];
   for (j = 0; j < 16; j++) if (p[16 * i + j] > 0) p[16 * i + j] *= 2 * rd_icdf(d, ic, 8) - 1; } }

// indices to filters: gains, both halves' lpc, pitch lags and ltp taps
static void params(struct sk_ch *c, struct sk_ctl *k, int cond) {
 struct sk_idx *x = &c->ix;
 int ns = c->nsub, d = c->order, i, j;
 for (i = 0; i < ns; i++) {
  if (!i && cond != 2) c->last_gain = imax(x->gain[0], c->last_gain - 16);
  else {
   int t = x->gain[i] - 4, th = 8 + c->last_gain;
   c->last_gain += t > th ? 2 * t - th : t; }
  c->last_gain = lim(c->last_gain, 0, 63);
  k->gain[i] = log2lin(imin(wq(1907825, c->last_gain) + 2090, 3967)); }
 int16_t f[16], f0[16];
 lsf_decode(f, x->lsf, sk_book(c));
 lsf2a(k->a[1], f, d);
 if (c->first) x->interp = 4;
 if (x->interp < 4) {
  for (i = 0; i < d; i++) f0[i] = (int16_t) (c->prev_lsf[i] + (x->interp * (f[i] - c->prev_lsf[i]) >> 2));
  lsf2a(k->a[0], f0, d); }
 else memcpy(k->a[0], k->a[1], (size_t) d * 2);
 memcpy(c->prev_lsf, f, (size_t) d * 2);
 if (c->loss) bwx(k->a[0], d, 63570), bwx(k->a[1], d, 63570);
 if (x->type == 2) {
  int lo = 2 * c->khz, hi = 18 * c->khz, w;
  const int8_t *cb = c->khz == 8 ? (ns == 4 ? (w = 11, sk_lags_nb) : (w = 3, sk_lags_nb10))
                                 : (ns == 4 ? (w = 34, sk_lags_wb) : (w = 12, sk_lags_wb10));
  for (i = 0; i < ns; i++) k->pitch[i] = lim(lo + x->lag + cb[i * w + x->contour], lo, hi);
  for (i = 0; i < ns; i++)
   for (j = 0; j < 5; j++) k->b[5 * i + j] = (int16_t) (sk_vq[x->per][x->ltp[i] * 5 + j] * 128);
  k->scale = sk_ltp_scale[x->scale]; }
 else x->per = 0, k->scale = 0; }

// excitation through the long- and short-term synthesis filters, a subframe at a time
static void synth(struct sk_ch *c, struct sk_ctl *k, int16_t *xq, const int *p) {
 int ltp = 20 * c->khz, sl = 5 * c->khz, d = c->order, lag = 0, at = ltp, s, i;
 int16_t w[320];
 int32_t st[640], h[96], rs[80], *ex = c->exc, seed = c->ix.seed;
 int32_t off = sk_offset[c->ix.type >> 1][c->ix.offset] << 4;
 for (i = 0; i < c->flen; i++) {
  int32_t e = shl(p[i], 14);
  e += e > 0 ? -1280 : e < 0 ? 1280 : 0;
  e += off, seed = next(seed);
  ex[i] = seed < 0 ? -e : e;
  seed = add(seed, p[i]); }
 memcpy(h, c->lpc, sizeof c->lpc);
 for (s = 0; s < c->nsub; s++, ex += sl) {
  const int16_t *a = k->a[s >> 1];
  int16_t *b = k->b + 5 * s, *o = xq + s * sl;
  int type = c->ix.type;
  int32_t g = k->gain[s] >> 6, inv = invq(k->gain[s], 47), adj = 65536, *r = ex;
  if (k->gain[s] != c->prev_gain) {
   adj = divq(c->prev_gain, k->gain[s], 16);
   for (i = 0; i < 16; i++) h[i] = wq(adj, h[i]); }
  c->prev_gain = k->gain[s];
  if (c->loss && c->prev_type == 2 && type != 2 && s < 2) {   // after a voiced loss: a weak pitch
   memset(b, 0, 10), b[2] = 4096, type = 2, k->pitch[s] = c->lag_prev; }
  if (type == 2) {
   lag = k->pitch[s];
   if (s == 0 || (s == 2 && c->ix.interp < 4)) {             // rebuild the residual history
    int b0 = ltp - lag - d - 2;
    if (s == 2) memcpy(c->out + ltp, xq, (size_t) sl * 4);
    lpc_res(w + b0, c->out + b0 + s * sl, a, ltp - b0, d);
    if (s == 0) inv = shl(wq(inv, k->scale), 2);
    for (i = 0; i < lag + 2; i++) st[at - i - 1] = wq(inv, w[ltp - i - 1]); }
   else if (adj != 65536) for (i = 0; i < lag + 2; i++) st[at - i - 1] = wq(adj, st[at - i - 1]);
   int32_t *pl = st + at - lag + 2;
   for (i = 0; i < sl; i++) rs[i] = add(ex[i], shl(ltp_step(pl + i, b), 1)), st[at++] = shl(rs[i], 1);
   r = rs; }
  for (i = 0; i < sl; i++)
   h[16 + i] = add(r[i], shl(lpc_step(h + 16 + i, a, d), 4)), o[i] = sat(rnd(wq(h[16 + i], g), 8));
  memcpy(h, h + sl, sizeof c->lpc); }
 memcpy(c->lpc, h, sizeof c->lpc); }

static void plc_reset(struct sk_ch *c) {
 struct sk_plc *p = &c->plc;
 p->pitch = c->flen << 7, p->gain[0] = p->gain[1] = 65536, p->slen = 20, p->nsub = 2; }

// a good frame: keep its strongest pitch, its filter and gains for concealment
static void plc_update(struct sk_ch *c, struct sk_ctl *k) {
 struct sk_plc *p = &c->plc;
 int ns = c->nsub, sl = 5 * c->khz;
 int32_t g = 0;
 c->prev_type = c->ix.type;
 memset(p->ltp, 0, sizeof p->ltp);
 if (c->ix.type == 2) {
  for (int j = 0; j < ns && j * sl < k->pitch[ns - 1]; j++) {
   int32_t t = 0;
   for (int i = 0; i < 5; i++) t += k->b[(ns - 1 - j) * 5 + i];
   if (t > g) g = t, p->pitch = k->pitch[ns - 1 - j] << 8; }
  p->ltp[2] = (int16_t) g;
  if (g < 11469) p->ltp[2] = (int16_t) (p->ltp[2] * (int16_t) ((11469 << 10) / imax(g, 1)) >> 10);
  else if (g > 15565) p->ltp[2] = (int16_t) (p->ltp[2] * (int16_t) ((15565 << 14) / imax(g, 1)) >> 14); }
 else p->pitch = (18 * c->khz) << 8;
 memcpy(p->lpc, k->a[1], (size_t) c->order * 2);
 p->ltp_scale = (int16_t) k->scale;
 p->gain[0] = k->gain[ns - 2], p->gain[1] = k->gain[ns - 1];
 p->slen = sl, p->nsub = ns; }

// a lost frame: the last pitch period repeated and fading, noise from the last excitation
static void plc_conceal(struct sk_ch *c, struct sk_ctl *k, int16_t *o) {
 static const int16_t harm[2] = { 32440, 31130 }, rv[2] = { 31130, 26214 }, ru[2] = { 32440, 29491 };
 struct sk_plc *p = &c->plc;
 int ltp = 20 * c->khz, sl = 5 * c->khz, d = c->order, l = imin(1, c->loss), i, j, s;
 int32_t g10[2] = { p->gain[0] >> 6, p->gain[1] >> 6 }, e1, e2, st[640], *rp;
 int16_t ex[160], w[320], a[16], *b = p->ltp, sc = p->scale;
 int s1, s2;
 if (c->first) memset(p->lpc, 0, sizeof p->lpc);
 for (j = 0; j < 2; j++)
  for (i = 0; i < p->slen; i++) ex[j * p->slen + i] = sat(wq(c->exc[i + (j + p->nsub - 2) * p->slen], g10[j]) >> 8);
 energy(&e1, &s1, ex, p->slen), energy(&e2, &s2, ex + p->slen, p->slen);
 rp = c->exc + imax(0, ((e1 >> s2) < (e2 >> s1) ? p->nsub - 1 : p->nsub) * p->slen - 128);
 int32_t hg = harm[l], rg = c->prev_type == 2 ? rv[l] : ru[l];
 bwx(p->lpc, d, 64881);
 memcpy(a, p->lpc, (size_t) d * 2);
 if (!c->loss) {
  sc = 16384;
  if (c->prev_type == 2) {
   for (i = 0; i < 5; i++) sc = (int16_t) (sc - b[i]);
   sc = (int16_t) imax(3277, sc);
   sc = (int16_t) (sc * p->ltp_scale >> 14); }
  else {
   int32_t ds = imax(1 << 22, imin(1 << 27, pred_gain(p->lpc, d))) << 3;
   rg = wq(ds, rg) >> 14; } }
 int32_t seed = p->seed, lag = rnd(p->pitch, 8), at = ltp, b0 = ltp - lag - d - 2;
 lpc_res(w + b0, c->out + b0, a, ltp - b0, d);
 int32_t inv = imin(invq(p->gain[1], 46), INT32_MAX >> 1);
 for (i = b0 + d; i < ltp; i++) st[i] = wq(inv, w[i]);
 for (s = 0; s < c->nsub; s++) {
  int32_t *pl = st + at - lag + 2;
  for (i = 0; i < sl; i++) {
   seed = next(seed);
   st[at++] = shl(add(ltp_step(pl + i, b), wq(rp[seed >> 25 & 127], sc)), 2); }
  for (j = 0; j < 5; j++) b[j] = (int16_t) (hg * b[j] >> 15);
  sc = (int16_t) (sc * rg >> 15);
  p->pitch = imin(p->pitch + wq(p->pitch, 655), (18 * c->khz) << 8);
  lag = rnd(p->pitch, 8); }
 int32_t *h = st + ltp - 16;
 memcpy(h, c->lpc, sizeof c->lpc);
 for (i = 0; i < c->flen; i++)
  h[16 + i] = add(h[16 + i], shl(lpc_step(h + 16 + i, a, d), 4)), o[i] = sat(rnd(wq(h[16 + i], g10[1]), 8));
 memcpy(c->lpc, h + c->flen, sizeof c->lpc);
 p->seed = seed, p->scale = sc;
 for (i = 0; i < 4; i++) k->pitch[i] = lag; }

// the first good frame after a loss fades in from the concealment's energy
static void plc_glue(struct sk_ch *c, int16_t *o, int n) {
 struct sk_plc *p = &c->plc;
 if (c->loss) { energy(&p->energy, &p->shift, o, n), p->lost = 1; return; }
 if (p->lost) {
  int32_t e; int sh;
  energy(&e, &sh, o, n);
  if (sh > p->shift) p->energy >>= sh - p->shift;
  else if (sh < p->shift) e >>= p->shift - sh;
  if (e > p->energy) {
   int lz = clz((uint32_t) p->energy) - 1;
   p->energy = shl(p->energy, lz), e >>= imax(24 - lz, 0);
   int32_t g = shl(sqrta(p->energy / imax(e, 1)), 4), step = shl((65536 - g) / n, 2);
   for (int i = 0; i < n; i++) {
    o[i] = (int16_t) wq(g, o[i]);
    if ((g += step) > 65536) break; } } }
 p->lost = 0; }

static void cng_reset(struct sk_ch *c) {
 int32_t step = 32767 / (c->order + 1), acc = 0;
 for (int i = 0; i < c->order; i++) c->cng.lsf[i] = (int16_t) (acc += step);
 c->cng.gain = 0, c->cng.seed = 3176576; }

// comfort noise: learn the background from quiet frames, add it under concealment
static void cng(struct sk_ch *c, struct sk_ctl *k, int16_t *o, int n) {
 struct sk_cng *g = &c->cng;
 int d = c->order, sl = 5 * c->khz, i;
 if (c->khz != g->khz) cng_reset(c), g->khz = c->khz;
 if (!c->loss && !c->prev_type) {
  int at = 0; int32_t mx = 0;
  for (i = 0; i < d; i++) g->lsf[i] = (int16_t) (g->lsf[i] + wq(c->prev_lsf[i] - g->lsf[i], 16348));
  for (i = 0; i < c->nsub; i++) if (k->gain[i] > mx) mx = k->gain[i], at = i;
  memmove(g->exc + sl, g->exc, (size_t) (c->nsub - 1) * sl * 4);
  memcpy(g->exc, c->exc + at * sl, (size_t) sl * 4);
  for (i = 0; i < c->nsub; i++) g->gain += wq(k->gain[i] - g->gain, 4634); }
 if (!c->loss) { memset(g->syn, 0, (size_t) d * 4); return; }
 int32_t x[336], mask = 255, seed = g->seed;
 int16_t a[16];
 while (mask > n) mask >>= 1;
 for (i = 0; i < n; i++) seed = next(seed), x[16 + i] = sat(wq(g->exc[seed >> 24 & mask], g->gain >> 4));
 g->seed = seed;
 lsf2a(a, g->lsf, d);
 memcpy(x, g->syn, sizeof g->syn);
 for (i = 0; i < n; i++) {
  int32_t t = lpc_step(x + 16 + i, a, d);
  x[16 + i] = add(x[16 + i], shl(t, 4)), o[i] = sat(o[i] + rnd(t, 6)); }
 memcpy(g->syn, x + n, sizeof g->syn); }

// one channel's frame, decoded or concealed, into o; -> its length
static int frame(struct sk_ch *c, struct rdec *d, int16_t *o, int lost, int cond) {
 struct sk_ctl k;
 int n = c->flen, ltp = 20 * c->khz;
 memset(&k, 0, sizeof k);
 if (c->khz != c->plc.khz) plc_reset(c), c->plc.khz = c->khz;
 if (!lost) {
  int p[320];
  read_indices(c, d, c->frames, 0, cond);
  read_pulses(d, p, c->ix.type, c->ix.offset, n);
  params(c, &k, cond);
  synth(c, &k, o, p);
  plc_update(c, &k);
  c->loss = 0, c->prev_type = c->ix.type, c->first = 0; }
 else plc_conceal(c, &k, o), c->loss++;
 memmove(c->out, c->out + n, (size_t) (ltp - n) * 2);
 memcpy(c->out + ltp - n, o, (size_t) n * 2);
 plc_glue(c, o, n);
 cng(c, &k, o, n);
 c->lag_prev = k.pitch[c->nsub - 1];
 return n; }

static void rs_init(struct sk_rs *r, int khz) {
 int32_t in = khz * 1000, v = shl((in << 15) / 48000, 2);
 memset(r, 0, sizeof *r);
 r->khz = khz, r->lag = khz == 16 ? 7 : khz == 12 ? 4 : 0;
 while (wq(v, 48000) < in << 1) v++;
 r->step = v; }

// three allpass sections, one phase of the 2x upsampler
static int32_t allpass(int32_t *s, int32_t x, const int16_t *c) {
 int32_t t = wq(x - s[0], c[0]), u = s[0] + t, v;
 s[0] = x + t;
 t = wq(u - s[1], c[1]), v = s[1] + t, s[1] = u + t;
 t = v - s[2], t += wq(t, c[2]), u = s[2] + t, s[2] = v + t;
 return u; }

static void rs_up(struct sk_rs *r, int16_t *o, const int16_t *x, int n) {
 int16_t b[328];
 memcpy(b, r->fir, sizeof r->fir);
 for (;;) {
  int m = imin(n, 10 * r->khz);
  for (int i = 0; i < m; i++) {
   int32_t v = shl(x[i], 10);
   b[8 + 2 * i] = sat(rnd(allpass(r->iir, v, sk_up2), 10));
   b[9 + 2 * i] = sat(rnd(allpass(r->iir + 3, v, sk_up2b), 10)); }
  for (int32_t at = 0; at < m << 17; at += r->step) {
   int ph = (at & 0xffff) * 12 >> 16;                   // the phase; its mirror takes the far taps
   const int16_t *y = b + (at >> 16), *f = sk_frac + 4 * ph, *g = sk_frac + 4 * (11 - ph);
   int32_t s = y[0] * f[0] + y[1] * f[1] + y[2] * f[2] + y[3] * f[3];
   s += y[4] * g[3] + y[5] * g[2] + y[6] * g[1] + y[7] * g[0];
   *o++ = sat(rnd(s, 15)); }
  x += m, n -= m;
  if (n <= 0) { memcpy(r->fir, b + 2 * m, sizeof r->fir); return; }
  memmove(b, b + 2 * m, sizeof r->fir); } }

// n samples at r->khz to n * 48 / khz at 48 khz, the first few held back a call
static void rs_run(struct sk_rs *r, int16_t *o, const int16_t *x, int n) {
 int k = r->khz, m = k - r->lag;
 memcpy(r->dly + r->lag, x, (size_t) m * 2);
 rs_up(r, o, r->dly, k);
 rs_up(r, o + 48, x + m, n - k);
 memcpy(r->dly, x + n - r->lag, (size_t) r->lag * 2); }

// a new internal rate or frame length; a new rate starts the channel over
static void set_rate(struct sk_ch *c, int khz) {
 int n = c->nsub * 5 * khz;
 if (c->khz != khz) {
  rs_init(&c->rs, khz);
  c->order = khz == 16 ? 16 : 10, c->first = 1, c->lag_prev = 100, c->last_gain = 10, c->prev_type = 0;
  memset(c->out, 0, sizeof c->out), memset(c->lpc, 0, sizeof c->lpc); }
 c->khz = khz, c->flen = n; }

static void ch_reset(struct sk_ch *c) {
 memset(c, 0, sizeof *c);
 c->first = 1, c->prev_gain = 65536;
 cng_reset(c), plc_reset(c); }

void sk_reset(struct silk *s) {
 ch_reset(&s->ch[0]), ch_reset(&s->ch[1]);
 memset(s->pred, 0, sizeof s->pred), memset(s->mid, 0, sizeof s->mid), memset(s->side, 0, sizeof s->side);
 s->mid_only = 0; }

// the stereo weights, q13
static void read_pred(struct rdec *d, int32_t *w) {
 int n = rd_icdf(d, sk_joint, 8), ix[2][3];
 ix[0][2] = n / 5, ix[1][2] = n - 5 * ix[0][2];
 for (n = 0; n < 2; n++) ix[n][0] = rd_icdf(d, sk_uni3, 8), ix[n][1] = rd_icdf(d, sk_uni5, 8);
 for (n = 0; n < 2; n++) {
  int q = ix[n][0] + 3 * ix[n][2];
  int32_t lo = sk_stereo[q], step = wq(sk_stereo[q + 1] - lo, 6554);
  w[n] = lo + (int16_t) step * (2 * ix[n][1] + 1); }
 w[0] -= w[1]; }

// mid and side to left and right, the weights eased in over 8 ms; x1, x2 lead with 2 held samples
static void unmix(struct silk *s, int16_t *x1, int16_t *x2, const int32_t *w, int khz, int n) {
 int m = 8 * khz, i;
 int32_t den = 65536 / m, p0 = s->pred[0], p1 = s->pred[1];
 int32_t d0 = rnd((int16_t) (w[0] - p0) * (int16_t) den, 16), d1 = rnd((int16_t) (w[1] - p1) * (int16_t) den, 16);
 memcpy(x1, s->mid, 4), memcpy(x2, s->side, 4);
 memcpy(s->mid, x1 + n, 4), memcpy(s->side, x2 + n, 4);
 for (i = 0; i < n; i++) {
  if (i < m) p0 += d0, p1 += d1;
  else p0 = w[0], p1 = w[1];
  int32_t t = shl(x1[i] + x1[i + 2] + shl(x1[i + 1], 1), 9);
  t = shl(x2[i + 1], 8) + wq(t, (int16_t) p0);
  t += wq(shl(x1[i + 1], 11), (int16_t) p1);
  x2[i + 1] = sat(rnd(t, 8)); }
 s->pred[0] = (int16_t) w[0], s->pred[1] = (int16_t) w[1];
 for (i = 1; i <= n; i++) {
  int32_t a = x1[i], b = x2[i];
  x1[i] = sat(a + b), x2[i] = sat(a - b); } }

int sk_decode(struct silk *s, struct rdec *d, int lost, int first, int khz, int sch, int och,
              int ms, int16_t *out, int *n) {
 struct sk_ch *c = s->ch;
 int16_t x[2][322], y[960];
 int32_t w[2] = { 0, 0 };
 int mid = 0, len = 0, i, j;
 if (first) for (i = 0; i < sch; i++) c[i].frames = 0;
 if (sch > s->nint) ch_reset(&c[1]);
 int mono = sch == 1 && s->nint == 2 && khz == c[0].khz;
 if (!c[0].frames)
  for (i = 0; i < sch; i++) {
   if (ms != 10 && ms != 20 && ms != 40 && ms != 60) return 1;
   c[i].nframes = ms < 40 ? 1 : ms / 20, c[i].nsub = ms == 10 ? 2 : 4;
   if (khz != 8 && khz != 12 && khz != 16) return 2;
   set_rate(&c[i], khz); }
 if (och == 2 && sch == 2 && (s->api == 1 || s->nint == 1)) {
  memset(s->pred, 0, sizeof s->pred), memset(s->side, 0, sizeof s->side);
  c[1].rs = c[0].rs; }
 s->api = och, s->nint = sch;
 if (!lost && !c[0].frames) {                    // the packet's header: vad and lbrr flags
  for (i = 0; i < sch; i++) {
   for (j = 0; j < c[i].nframes; j++) c[i].vad[j] = rd_logp(d, 1);
   c[i].lbrr = rd_logp(d, 1); }
  for (i = 0; i < sch; i++) {
   memset(c[i].lbrr_f, 0, sizeof c[i].lbrr_f);
   if (!c[i].lbrr) continue;
   if (c[i].nframes == 1) c[i].lbrr_f[0] = 1;
   else {
    int v = rd_icdf(d, c[i].nframes == 2 ? sk_lbrr2 : sk_lbrr3, 8) + 1;
    for (j = 0; j < c[i].nframes; j++) c[i].lbrr_f[j] = v >> j & 1; } }
  for (j = 0; j < c[0].nframes; j++)             // redundant frames: read past, unused
   for (i = 0; i < sch; i++)
    if (c[i].lbrr_f[j]) {
     int p[320];
     if (sch == 2 && i == 0) {
      read_pred(d, w);
      if (!c[1].lbrr_f[j]) mid = rd_icdf(d, sk_midonly, 8); }
     read_indices(&c[i], d, j, 1, j > 0 && c[i].lbrr_f[j - 1] ? 2 : 0);
     read_pulses(d, p, c[i].ix.type, c[i].ix.offset, c[i].flen); } }
 if (sch == 2) {
  if (!lost) {
   read_pred(d, w);
   mid = c[1].vad[c[0].frames] ? 0 : rd_icdf(d, sk_midonly, 8); }
  else w[0] = s->pred[0], w[1] = s->pred[1]; }
 if (sch == 2 && !mid && s->mid_only) {          // the side returns: start it over
  memset(c[1].out, 0, sizeof c[1].out), memset(c[1].lpc, 0, sizeof c[1].lpc);
  c[1].lag_prev = 100, c[1].last_gain = 10, c[1].prev_type = 0, c[1].first = 1; }
 int side = lost ? !s->mid_only : !mid;
 for (i = 0; i < sch; i++) {
  if (i == 0 || side) {
   int fi = c[0].frames - i;
   len = frame(&c[i], d, x[i] + 2, lost, fi <= 0 ? 0 : i > 0 && s->mid_only ? 1 : 2); }
  else memset(x[i] + 2, 0, (size_t) len * 2);
  c[i].frames++; }
 if (och == 2 && sch == 2) unmix(s, x[0], x[1], w, c[0].khz, len);
 else memcpy(x[0], s->mid, 4), memcpy(s->mid, x[0] + len, 4);
 int m = len * 48 / c[0].khz;
 for (i = 0; i < och && i < sch; i++) {
  rs_run(&c[i].rs, och == 2 ? y : out, x[i] + 1, len);
  if (och == 2) for (j = 0; j < m; j++) out[i + 2 * j] = y[j]; }
 if (och == 2 && sch == 1) {
  if (mono) rs_run(&c[1].rs, y, x[0] + 1, len);
  for (j = 0; j < m; j++) out[1 + 2 * j] = mono ? y[j] : out[2 * j]; }
 if (lost) for (i = 0; i < s->nint; i++) c[i].last_gain = 10;
 else s->mid_only = mid;
 *n = m;
 return 0; }
