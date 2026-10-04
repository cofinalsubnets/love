// src/love/lib/webp.c
// (webp-pixels s) -> the w*h*4 rgba of a webp -- an animation's first frame, laid on its
// canvas -- | why not: 1 not a webp, 2 cut short, 3 a kind it can't read (an interframe),
// 4 a bad stream, 5 past 2^24 pixels, 6 no room. lossy (vp8, rfc 6386) with or without an
// ALPH plane, and lossless (vp8l, rfc 9649); the pixels are libwebp's WebPDecodeRGBA's.
#include "love.h"
#include "inf.h"
#include <stdint.h>
#include <string.h>

// the coefficient probabilities a frame starts from, [type][band][context][node]
static const uint8_t vp_proba0[4 * 8 * 3 * 11] = {
 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128,
 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 253, 136, 254, 255, 228, 219, 128, 128, 128, 128, 128,
 189, 129, 242, 255, 227, 213, 255, 219, 128, 128, 128, 106, 126, 227, 252, 214, 209, 255, 255, 128, 128, 128,
   1,  98, 248, 255, 236, 226, 255, 255, 128, 128, 128, 181, 133, 238, 254, 221, 234, 255, 154, 128, 128, 128,
  78, 134, 202, 247, 198, 180, 255, 219, 128, 128, 128,   1, 185, 249, 255, 243, 255, 128, 128, 128, 128, 128,
 184, 150, 247, 255, 236, 224, 128, 128, 128, 128, 128,  77, 110, 216, 255, 236, 230, 128, 128, 128, 128, 128,
   1, 101, 251, 255, 241, 255, 128, 128, 128, 128, 128, 170, 139, 241, 252, 236, 209, 255, 255, 128, 128, 128,
  37, 116, 196, 243, 228, 255, 255, 255, 128, 128, 128,   1, 204, 254, 255, 245, 255, 128, 128, 128, 128, 128,
 207, 160, 250, 255, 238, 128, 128, 128, 128, 128, 128, 102, 103, 231, 255, 211, 171, 128, 128, 128, 128, 128,
   1, 152, 252, 255, 240, 255, 128, 128, 128, 128, 128, 177, 135, 243, 255, 234, 225, 128, 128, 128, 128, 128,
  80, 129, 211, 255, 194, 224, 128, 128, 128, 128, 128,   1,   1, 255, 128, 128, 128, 128, 128, 128, 128, 128,
 246,   1, 255, 128, 128, 128, 128, 128, 128, 128, 128, 255, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128,
 198,  35, 237, 223, 193, 187, 162, 160, 145, 155,  62, 131,  45, 198, 221, 172, 176, 220, 157, 252, 221,   1,
  68,  47, 146, 208, 149, 167, 221, 162, 255, 223, 128,   1, 149, 241, 255, 221, 224, 255, 255, 128, 128, 128,
 184, 141, 234, 253, 222, 220, 255, 199, 128, 128, 128,  81,  99, 181, 242, 176, 190, 249, 202, 255, 255, 128,
   1, 129, 232, 253, 214, 197, 242, 196, 255, 255, 128,  99, 121, 210, 250, 201, 198, 255, 202, 128, 128, 128,
  23,  91, 163, 242, 170, 187, 247, 210, 255, 255, 128,   1, 200, 246, 255, 234, 255, 128, 128, 128, 128, 128,
 109, 178, 241, 255, 231, 245, 255, 255, 128, 128, 128,  44, 130, 201, 253, 205, 192, 255, 255, 128, 128, 128,
   1, 132, 239, 251, 219, 209, 255, 165, 128, 128, 128,  94, 136, 225, 251, 218, 190, 255, 255, 128, 128, 128,
  22, 100, 174, 245, 186, 161, 255, 199, 128, 128, 128,   1, 182, 249, 255, 232, 235, 128, 128, 128, 128, 128,
 124, 143, 241, 255, 227, 234, 128, 128, 128, 128, 128,  35,  77, 181, 251, 193, 211, 255, 205, 128, 128, 128,
   1, 157, 247, 255, 236, 231, 255, 255, 128, 128, 128, 121, 141, 235, 255, 225, 227, 255, 255, 128, 128, 128,
  45,  99, 188, 251, 195, 217, 255, 224, 128, 128, 128,   1,   1, 251, 255, 213, 255, 128, 128, 128, 128, 128,
 203,   1, 248, 255, 255, 128, 128, 128, 128, 128, 128, 137,   1, 177, 255, 224, 255, 128, 128, 128, 128, 128,
 253,   9, 248, 251, 207, 208, 255, 192, 128, 128, 128, 175,  13, 224, 243, 193, 185, 249, 198, 255, 255, 128,
  73,  17, 171, 221, 161, 179, 236, 167, 255, 234, 128,   1,  95, 247, 253, 212, 183, 255, 255, 128, 128, 128,
 239,  90, 244, 250, 211, 209, 255, 255, 128, 128, 128, 155,  77, 195, 248, 188, 195, 255, 255, 128, 128, 128,
   1,  24, 239, 251, 218, 219, 255, 205, 128, 128, 128, 201,  51, 219, 255, 196, 186, 128, 128, 128, 128, 128,
  69,  46, 190, 239, 201, 218, 255, 228, 128, 128, 128,   1, 191, 251, 255, 255, 128, 128, 128, 128, 128, 128,
 223, 165, 249, 255, 213, 255, 128, 128, 128, 128, 128, 141, 124, 248, 255, 255, 128, 128, 128, 128, 128, 128,
   1,  16, 248, 255, 255, 128, 128, 128, 128, 128, 128, 190,  36, 230, 255, 236, 255, 128, 128, 128, 128, 128,
 149,   1, 255, 128, 128, 128, 128, 128, 128, 128, 128,   1, 226, 255, 128, 128, 128, 128, 128, 128, 128, 128,
 247, 192, 255, 128, 128, 128, 128, 128, 128, 128, 128, 240, 128, 255, 128, 128, 128, 128, 128, 128, 128, 128,
   1, 134, 252, 255, 255, 128, 128, 128, 128, 128, 128, 213,  62, 250, 255, 255, 128, 128, 128, 128, 128, 128,
  55,  93, 255, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128,
 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128,
 202,  24, 213, 235, 186, 191, 220, 160, 240, 175, 255, 126,  38, 182, 232, 169, 184, 228, 174, 255, 187, 128,
  61,  46, 138, 219, 151, 178, 240, 170, 255, 216, 128,   1, 112, 230, 250, 199, 191, 247, 159, 255, 255, 128,
 166, 109, 228, 252, 211, 215, 255, 174, 128, 128, 128,  39,  77, 162, 232, 172, 180, 245, 178, 255, 255, 128,
   1,  52, 220, 246, 198, 199, 249, 220, 255, 255, 128, 124,  74, 191, 243, 183, 193, 250, 221, 255, 255, 128,
  24,  71, 130, 219, 154, 170, 243, 182, 255, 255, 128,   1, 182, 225, 249, 219, 240, 255, 224, 128, 128, 128,
 149, 150, 226, 252, 216, 205, 255, 171, 128, 128, 128,  28, 108, 170, 242, 183, 194, 254, 223, 255, 255, 128,
   1,  81, 230, 252, 204, 203, 255, 192, 128, 128, 128, 123, 102, 209, 247, 188, 196, 255, 233, 128, 128, 128,
  20,  95, 153, 243, 164, 173, 255, 203, 128, 128, 128,   1, 222, 248, 255, 216, 213, 128, 128, 128, 128, 128,
 168, 175, 246, 252, 235, 205, 255, 255, 128, 128, 128,  47, 116, 215, 255, 211, 212, 255, 255, 128, 128, 128,
   1, 121, 236, 253, 212, 214, 255, 255, 128, 128, 128, 141,  84, 213, 252, 201, 202, 255, 219, 128, 128, 128,
  42,  80, 160, 240, 162, 185, 255, 205, 128, 128, 128,   1,   1, 255, 128, 128, 128, 128, 128, 128, 128, 128,
 244,   1, 255, 128, 128, 128, 128, 128, 128, 128, 128, 238,   1, 255, 128, 128, 128, 128, 128, 128, 128, 128 };
// the chance each one is sent anew
static const uint8_t vp_upd[4 * 8 * 3 * 11] = {
 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 176, 246, 255, 255, 255, 255, 255, 255, 255, 255, 255,
 223, 241, 252, 255, 255, 255, 255, 255, 255, 255, 255, 249, 253, 253, 255, 255, 255, 255, 255, 255, 255, 255,
 255, 244, 252, 255, 255, 255, 255, 255, 255, 255, 255, 234, 254, 254, 255, 255, 255, 255, 255, 255, 255, 255,
 253, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 246, 254, 255, 255, 255, 255, 255, 255, 255, 255,
 239, 253, 254, 255, 255, 255, 255, 255, 255, 255, 255, 254, 255, 254, 255, 255, 255, 255, 255, 255, 255, 255,
 255, 248, 254, 255, 255, 255, 255, 255, 255, 255, 255, 251, 255, 254, 255, 255, 255, 255, 255, 255, 255, 255,
 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 253, 254, 255, 255, 255, 255, 255, 255, 255, 255,
 251, 254, 254, 255, 255, 255, 255, 255, 255, 255, 255, 254, 255, 254, 255, 255, 255, 255, 255, 255, 255, 255,
 255, 254, 253, 255, 254, 255, 255, 255, 255, 255, 255, 250, 255, 254, 255, 254, 255, 255, 255, 255, 255, 255,
 254, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
 217, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 225, 252, 241, 253, 255, 255, 254, 255, 255, 255, 255,
 234, 250, 241, 250, 253, 255, 253, 254, 255, 255, 255, 255, 254, 255, 255, 255, 255, 255, 255, 255, 255, 255,
 223, 254, 254, 255, 255, 255, 255, 255, 255, 255, 255, 238, 253, 254, 254, 255, 255, 255, 255, 255, 255, 255,
 255, 248, 254, 255, 255, 255, 255, 255, 255, 255, 255, 249, 254, 255, 255, 255, 255, 255, 255, 255, 255, 255,
 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 253, 255, 255, 255, 255, 255, 255, 255, 255, 255,
 247, 254, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
 255, 253, 254, 255, 255, 255, 255, 255, 255, 255, 255, 252, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 254, 254, 255, 255, 255, 255, 255, 255, 255, 255,
 253, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
 255, 254, 253, 255, 255, 255, 255, 255, 255, 255, 255, 250, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
 254, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
 186, 251, 250, 255, 255, 255, 255, 255, 255, 255, 255, 234, 251, 244, 254, 255, 255, 255, 255, 255, 255, 255,
 251, 251, 243, 253, 254, 255, 254, 255, 255, 255, 255, 255, 253, 254, 255, 255, 255, 255, 255, 255, 255, 255,
 236, 253, 254, 255, 255, 255, 255, 255, 255, 255, 255, 251, 253, 253, 254, 254, 255, 255, 255, 255, 255, 255,
 255, 254, 254, 255, 255, 255, 255, 255, 255, 255, 255, 254, 254, 254, 255, 255, 255, 255, 255, 255, 255, 255,
 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 254, 255, 255, 255, 255, 255, 255, 255, 255, 255,
 254, 254, 255, 255, 255, 255, 255, 255, 255, 255, 255, 254, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 254, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
 248, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 250, 254, 252, 254, 255, 255, 255, 255, 255, 255, 255,
 248, 254, 249, 253, 255, 255, 255, 255, 255, 255, 255, 255, 253, 253, 255, 255, 255, 255, 255, 255, 255, 255,
 246, 253, 253, 255, 255, 255, 255, 255, 255, 255, 255, 252, 254, 251, 254, 254, 255, 255, 255, 255, 255, 255,
 255, 254, 252, 255, 255, 255, 255, 255, 255, 255, 255, 248, 254, 253, 255, 255, 255, 255, 255, 255, 255, 255,
 253, 255, 254, 254, 255, 255, 255, 255, 255, 255, 255, 255, 251, 254, 255, 255, 255, 255, 255, 255, 255, 255,
 245, 251, 254, 255, 255, 255, 255, 255, 255, 255, 255, 253, 253, 254, 255, 255, 255, 255, 255, 255, 255, 255,
 255, 251, 253, 255, 255, 255, 255, 255, 255, 255, 255, 252, 253, 254, 255, 255, 255, 255, 255, 255, 255, 255,
 255, 254, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 252, 255, 255, 255, 255, 255, 255, 255, 255, 255,
 249, 255, 254, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 254, 255, 255, 255, 255, 255, 255, 255, 255,
 255, 255, 253, 255, 255, 255, 255, 255, 255, 255, 255, 250, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
 254, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 };
// a 4x4 block's mode tree, by the modes above and to its left
static const uint8_t vp_bmodes[10 * 10 * 9] = {
 231, 120,  48,  89, 115, 113, 120, 152, 112, 152, 179,  64, 126, 170, 118,  46,  70,  95,
 175,  69, 143,  80,  85,  82,  72, 155, 103,  56,  58,  10, 171, 218, 189,  17,  13, 152,
 114,  26,  17, 163,  44, 195,  21,  10, 173, 121,  24,  80, 195,  26,  62,  44,  64,  85,
 144,  71,  10,  38, 171, 213, 144,  34,  26, 170,  46,  55,  19, 136, 160,  33, 206,  71,
  63,  20,   8, 114, 114, 208,  12,   9, 226,  81,  40,  11,  96, 182,  84,  29,  16,  36,
 134, 183,  89, 137,  98, 101, 106, 165, 148,  72, 187, 100, 130, 157, 111,  32,  75,  80,
  66, 102, 167,  99,  74,  62,  40, 234, 128,  41,  53,   9, 178, 241, 141,  26,   8, 107,
  74,  43,  26, 146,  73, 166,  49,  23, 157,  65,  38, 105, 160,  51,  52,  31, 115, 128,
 104,  79,  12,  27, 217, 255,  87,  17,   7,  87,  68,  71,  44, 114,  51,  15, 186,  23,
  47,  41,  14, 110, 182, 183,  21,  17, 194,  66,  45,  25, 102, 197, 189,  23,  18,  22,
  88,  88, 147, 150,  42,  46,  45, 196, 205,  43,  97, 183, 117,  85,  38,  35, 179,  61,
  39,  53, 200,  87,  26,  21,  43, 232, 171,  56,  34,  51, 104, 114, 102,  29,  93,  77,
  39,  28,  85, 171,  58, 165,  90,  98,  64,  34,  22, 116, 206,  23,  34,  43, 166,  73,
 107,  54,  32,  26,  51,   1,  81,  43,  31,  68,  25, 106,  22,  64, 171,  36, 225, 114,
  34,  19,  21, 102, 132, 188,  16,  76, 124,  62,  18,  78,  95,  85,  57,  50,  48,  51,
 193, 101,  35, 159, 215, 111,  89,  46, 111,  60, 148,  31, 172, 219, 228,  21,  18, 111,
 112, 113,  77,  85, 179, 255,  38, 120, 114,  40,  42,   1, 196, 245, 209,  10,  25, 109,
  88,  43,  29, 140, 166, 213,  37,  43, 154,  61,  63,  30, 155,  67,  45,  68,   1, 209,
 100,  80,   8,  43, 154,   1,  51,  26,  71, 142,  78,  78,  16, 255, 128,  34, 197, 171,
  41,  40,   5, 102, 211, 183,   4,   1, 221,  51,  50,  17, 168, 209, 192,  23,  25,  82,
 138,  31,  36, 171,  27, 166,  38,  44, 229,  67,  87,  58, 169,  82, 115,  26,  59, 179,
  63,  59,  90, 180,  59, 166,  93,  73, 154,  40,  40,  21, 116, 143, 209,  34,  39, 175,
  47,  15,  16, 183,  34, 223,  49,  45, 183,  46,  17,  33, 183,   6,  98,  15,  32, 183,
  57,  46,  22,  24, 128,   1,  54,  17,  37,  65,  32,  73, 115,  28, 128,  23, 128, 205,
  40,   3,   9, 115,  51, 192,  18,   6, 223,  87,  37,   9, 115,  59,  77,  64,  21,  47,
 104,  55,  44, 218,   9,  54,  53, 130, 226,  64,  90,  70, 205,  40,  41,  23,  26,  57,
  54,  57, 112, 184,   5,  41,  38, 166, 213,  30,  34,  26, 133, 152, 116,  10,  32, 134,
  39,  19,  53, 221,  26, 114,  32,  73, 255,  31,   9,  65, 234,   2,  15,   1, 118,  73,
  75,  32,  12,  51, 192, 255, 160,  43,  51,  88,  31,  35,  67, 102,  85,  55, 186,  85,
  56,  21,  23, 111,  59, 205,  45,  37, 192,  55,  38,  70, 124,  73, 102,   1,  34,  98,
 125,  98,  42,  88, 104,  85, 117, 175,  82,  95,  84,  53,  89, 128, 100, 113, 101,  45,
  75,  79, 123,  47,  51, 128,  81, 171,   1,  57,  17,   5,  71, 102,  57,  53,  41,  49,
  38,  33,  13, 121,  57,  73,  26,   1,  85,  41,  10,  67, 138,  77, 110,  90,  47, 114,
 115,  21,   2,  10, 102, 255, 166,  23,   6, 101,  29,  16,  10,  85, 128, 101, 196,  26,
  57,  18,  10, 102, 102, 213,  34,  20,  43, 117,  20,  15,  36, 163, 128,  68,   1,  26,
 102,  61,  71,  37,  34,  53,  31, 243, 192,  69,  60,  71,  38,  73, 119,  28, 222,  37,
  68,  45, 128,  34,   1,  47,  11, 245, 171,  62,  17,  19,  70, 146,  85,  55,  62,  70,
  37,  43,  37, 154, 100, 163,  85, 160,   1,  63,   9,  92, 136,  28,  64,  32, 201,  85,
  75,  15,   9,   9,  64, 255, 184, 119,  16,  86,   6,  28,   5,  64, 255,  25, 248,   1,
  56,   8,  17, 132, 137, 255,  55, 116, 128,  58,  15,  20,  82, 135,  57,  26, 121,  40,
 164,  50,  31, 137, 154, 133,  25,  35, 218,  51, 103,  44, 131, 131, 123,  31,   6, 158,
  86,  40,  64, 135, 148, 224,  45, 183, 128,  22,  26,  17, 131, 240, 154,  14,   1, 209,
  45,  16,  21,  91,  64, 222,   7,   1, 197,  56,  21,  39, 155,  60, 138,  23, 102, 213,
  83,  12,  13,  54, 192, 255,  68,  47,  28,  85,  26,  85,  85, 128, 128,  32, 146, 171,
  18,  11,   7,  63, 144, 171,   4,   4, 246,  35,  27,  10, 146, 174, 171,  12,  26, 128,
 190,  80,  35,  99, 180,  80, 126,  54,  45,  85, 126,  47,  87, 176,  51,  41,  20,  32,
 101,  75, 128, 139, 118, 146, 116, 128,  85,  56,  41,  15, 176, 236,  85,  37,   9,  62,
  71,  30,  17, 119, 118, 255,  17,  18, 138, 101,  38,  60, 138,  55,  70,  43,  26, 142,
 146,  36,  19,  30, 171, 255,  97,  27,  20, 138,  45,  61,  62, 219,   1,  81, 188,  64,
  32,  41,  20, 117, 151, 142,  20,  21, 163, 112,  19,  12,  61, 195, 128,  48,   4,  24 };
static const uint8_t vp_dct[128] = {
   4,   5,   6,   7,   8,   9,  10,  10,  11,  12,  13,  14,  15,  16,  17,  17,
  18,  19,  20,  20,  21,  21,  22,  22,  23,  23,  24,  25,  25,  26,  27,  28,
  29,  30,  31,  32,  33,  34,  35,  36,  37,  37,  38,  39,  40,  41,  42,  43,
  44,  45,  46,  46,  47,  48,  49,  50,  51,  52,  53,  54,  55,  56,  57,  58,
  59,  60,  61,  62,  63,  64,  65,  66,  67,  68,  69,  70,  71,  72,  73,  74,
  75,  76,  76,  77,  78,  79,  80,  81,  82,  83,  84,  85,  86,  87,  88,  89,
  91,  93,  95,  96,  98, 100, 101, 102, 104, 106, 108, 110, 112, 114, 116, 118,
 122, 124, 126, 128, 130, 132, 134, 136, 138, 140, 143, 145, 148, 151, 154, 157 };
static const uint16_t vp_act[128] = {
   4,   5,   6,   7,   8,   9,  10,  11,  12,  13,  14,  15,  16,  17,  18,  19,
  20,  21,  22,  23,  24,  25,  26,  27,  28,  29,  30,  31,  32,  33,  34,  35,
  36,  37,  38,  39,  40,  41,  42,  43,  44,  45,  46,  47,  48,  49,  50,  51,
  52,  53,  54,  55,  56,  57,  58,  60,  62,  64,  66,  68,  70,  72,  74,  76,
  78,  80,  82,  84,  86,  88,  90,  92,  94,  96,  98, 100, 102, 104, 106, 108,
 110, 112, 114, 116, 119, 122, 125, 128, 131, 134, 137, 140, 143, 146, 149, 152,
 155, 158, 161, 164, 167, 170, 173, 177, 181, 185, 189, 193, 197, 201, 205, 209,
 213, 217, 221, 225, 229, 234, 239, 245, 249, 254, 259, 264, 269, 274, 279, 284 };
// a short distance code -> (dy << 4) | (8 - dx)
static const uint8_t wl_plane_t[120] = {
  24,   7,  23,  25,  40,   6,  39,  41,  22,  26,  38,  42,  56,   5,  55,  57,  21,  27,  54,  58,
  37,  43,  72,   4,  71,  73,  20,  28,  53,  59,  70,  74,  36,  44,  88,  69,  75,  52,  60,   3,
  87,  89,  19,  29,  86,  90,  35,  45,  68,  76,  85,  91,  51,  61, 104,   2, 103, 105,  18,  30,
 102, 106,  34,  46,  84,  92,  67,  77, 101, 107,  50,  62, 120,   1, 119, 121,  83,  93,  17,  31,
 100, 108,  66,  78, 118, 122,  33,  47, 117, 123,  49,  63,  99, 109,  82,  94,   0, 116, 124,  65,
  79,  16,  32,  98, 110,  48, 115, 125,  81,  95,  64, 114, 126,  97, 111,  80, 113, 127,  96, 112 };

static const uint8_t vp_zigzag[16] = { 0, 1, 4, 8, 5, 2, 3, 6, 9, 12, 13, 10, 7, 11, 14, 15 };
static const uint8_t vp_band[17] = { 0, 1, 2, 3, 6, 4, 5, 6, 6, 6, 6, 6, 6, 6, 6, 7, 0 };
static const uint8_t vp_cat3[] = { 173, 148, 140, 0 }, vp_cat4[] = { 176, 155, 140, 135, 0 },
 vp_cat5[] = { 180, 157, 141, 134, 130, 0 },
 vp_cat6[] = { 254, 254, 243, 230, 196, 177, 153, 140, 133, 130, 129, 0 };
static const uint8_t *const vp_cats[4] = { vp_cat3, vp_cat4, vp_cat5, vp_cat6 };
// the 4x4 mode tree, libwebp's mode order: dc tm ve he rd vr ld vl hd hu
static const int8_t vp_ytree[18] = { 0, 1, -1, 2, -2, 3, 4, 6, -3, 5, -4, -5, -6, 7, -7, 8, -8, -9 };
static const uint8_t wl_clord[19] = { 17, 18, 0, 1, 2, 3, 4, 5, 16, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 };

// ===== the allocations of one decode, all freed at its end =====
struct wp_mem { void *p[48]; int n; };
static void *wp_new(struct wp_mem *m, uintptr_t n) {
 if (m->n == 48) return NULL;
 void *p = alloc(NULL, n ? n : 1);
 if (p) m->p[m->n++] = p;
 return p; }
static void *wp_zero(struct wp_mem *m, uintptr_t n) {
 void *p = wp_new(m, n);
 return p ? memset(p, 0, n) : p; }
static void wp_drop(struct wp_mem *m, void *p) {
 for (int i = 0; i < m->n; i++)
  if (m->p[i] == p) { alloc(p, 0), m->p[i] = m->p[--m->n]; return; } }
static void wp_free(struct wp_mem *m) { while (m->n) alloc(m->p[--m->n], 0); }

static uint32_t rd16(const uint8_t *p) { return p[0] | (uint32_t) p[1] << 8; }
static uint32_t rd24(const uint8_t *p) { return rd16(p) | (uint32_t) p[2] << 16; }
static uint32_t rd32(const uint8_t *p) { return rd24(p) | (uint32_t) p[3] << 24; }
static int wp_big(uintptr_t w, uintptr_t h) { return w * h > (1u << 24); }

// ===== vp8l, the lossless image =====
struct wl_tr { unsigned type, bits, xs; uint32_t *data; };
struct wl {
 const uint8_t *s; uintptr_t n, pos; uint64_t v, used; unsigned nb;
 struct wp_mem *m; struct wl_tr tr[4]; unsigned nt, seen; };
// a code: one symbol takes no bits, otherwise the shared canonical one
struct wl_code { struct inf_code c; int one; };

static void wl_fill(struct wl *d) {
 while (d->nb <= 56) d->v |= (uint64_t) (d->pos < d->n ? d->s[d->pos] : 0) << d->nb, d->pos++, d->nb += 8; }
static uint32_t wl_bits(struct wl *d, unsigned k) {
 if (!k) return 0;
 wl_fill(d);
 uint32_t r = (uint32_t) (d->v & (((uint64_t) 1 << k) - 1));
 return d->v >>= k, d->nb -= k, d->used += k, r; }
static int wl_eos(const struct wl *d) { return d->used > (uint64_t) d->n * 8; }
static unsigned wl_sub(unsigned n, unsigned b) { return (n + (1u << b) - 1) >> b; }

// lengths -> a code over storage sym and tab; 0 when they make no whole code
static int wl_make(struct wl_code *k, const uint8_t *lens, unsigned n, uint16_t *sym,
                   uint16_t *tab, unsigned root) {
 unsigned nz = 0, last = 0, kraft = 0;
 for (unsigned i = 0; i < n; i++) if (lens[i]) nz++, last = i, kraft += 32768u >> lens[i];
 if (!nz) return 0;
 k->one = nz == 1 ? (int) last : -1;
 if (nz == 1) return 1;
 if (kraft != 32768u) return 0;
 inf_build(&k->c, lens, n, sym, tab, root);
 return 1; }
static unsigned wl_sym(struct wl *d, const struct wl_code *k) {
 if (k->one >= 0) return (unsigned) k->one;
 wl_fill(d);
 uint16_t e = k->c.tab[d->v & ((1u << k->c.root) - 1)];
 unsigned w = e ? e : (unsigned) inf_walk(&k->c, d->v), u = w & 15;   // a whole code always lands
 return d->v >>= u, d->nb -= u, d->used += u, w >> 4; }

// one code's lengths off the stream; 0 for a bad one
static int wl_lengths(struct wl *d, unsigned n, uint8_t *lens) {
 memset(lens, 0, n);
 if (wl_bits(d, 1)) {                            // one or two symbols, spelled out
  unsigned two = wl_bits(d, 1), s0 = wl_bits(d, wl_bits(d, 1) ? 8 : 1);
  if (s0 >= n) return 0;
  lens[s0] = 1;
  if (two) { unsigned s1 = wl_bits(d, 8); if (s1 >= n) return 0; lens[s1] = 1; }
  return !wl_eos(d); }
 uint8_t cl[19] = { 0 };
 uint16_t csym[19], ctab[128];
 struct wl_code cc;
 unsigned nc = wl_bits(d, 4) + 4, max = n, i, prev = 8;
 for (i = 0; i < nc; i++) cl[wl_clord[i]] = (uint8_t) wl_bits(d, 3);
 if (!wl_make(&cc, cl, 19, csym, ctab, 7)) return 0;
 if (wl_bits(d, 1)) { max = 2 + wl_bits(d, 2 + 2 * wl_bits(d, 3)); if (max > n) return 0; }
 for (i = 0; i < n && max--; ) {
  unsigned c = wl_sym(d, &cc), r;
  if (c < 16) { lens[i++] = (uint8_t) c; if (c) prev = c; continue; }
  r = c == 16 ? wl_bits(d, 2) + 3 : c == 17 ? wl_bits(d, 3) + 3 : wl_bits(d, 7) + 11;
  if (i + r > n) return 0;
  memset(lens + i, c == 16 ? (int) prev : 0, r), i += r; }
 return !wl_eos(d); }

static unsigned wl_copy(struct wl *d, unsigned sym) {
 if (sym < 4) return sym + 1;
 unsigned eb = (sym - 2) >> 1;
 return ((2 + (sym & 1)) << eb) + wl_bits(d, eb) + 1; }
static uintptr_t wl_plane(unsigned w, unsigned code) {
 if (code > 120) return code - 120;
 int c = wl_plane_t[code - 1], k = (c >> 4) * (int) w + (8 - (c & 15));
 return k >= 1 ? (uintptr_t) k : 1; }

// one entropy-coded image of w*h pixels into px: its colour cache, its codes (the main image
// alone may take a meta image picking a group of five per tile), then the pixels. 0 or why not
static int wl_image(struct wl *d, uint32_t *px, unsigned w, unsigned h, int top) {
 unsigned cbits = 0, hbits = 0, hw = 0, ng = 1, nu = 1, i, j;
 uint32_t *meta = NULL, *map, *cache = NULL;
 int r;
 if (wl_bits(d, 1)) { cbits = wl_bits(d, 4); if (cbits < 1 || cbits > 11) return 4; }
 if (top && wl_bits(d, 1)) {
  hbits = wl_bits(d, 3) + 2, hw = wl_sub(w, hbits);
  uintptr_t hn = (uintptr_t) hw * wl_sub(h, hbits);
  if (!(meta = wp_new(d->m, hn * 4))) return 6;
  if ((r = wl_image(d, meta, hw, wl_sub(h, hbits), 0))) return r;
  ng = 0;
  for (uintptr_t k = 0; k < hn; k++) if ((meta[k] = (meta[k] >> 8) & 0xffff) >= ng) ng = meta[k] + 1; }
 // a group no tile names is read and dropped: the used ones are numbered first to last
 if (!(map = wp_new(d->m, (uintptr_t) ng * 4))) return 6;
 if (meta) {
  memset(map, 0xff, (uintptr_t) ng * 4), nu = 0;
  for (uintptr_t k = 0, hn = (uintptr_t) hw * wl_sub(h, hbits); k < hn; k++)
   if (map[meta[k]] == 0xffffffffu) map[meta[k]] = nu++; }
 else map[0] = 0;
 static const unsigned base[5] = { 280, 256, 256, 256, 40 }, root[5] = { 10, 8, 8, 8, 8 };
 unsigned n0 = 280 + (cbits ? 1u << cbits : 0), per = 0;
 for (j = 0; j < 5; j++) per += (j ? base[j] : n0) + (1u << root[j]);
 struct wl_code *codes = wp_new(d->m, (uintptr_t) (nu + 1) * 5 * sizeof *codes);
 uint16_t *store = wp_new(d->m, (uintptr_t) (nu + 1) * per * 2);
 uint8_t *lens = wp_new(d->m, n0);
 if (!codes || !store || !lens) return 6;
 for (i = 0; i < ng; i++) {
  unsigned g = map[i] == 0xffffffffu ? nu : map[i];
  uint16_t *at = store + (uintptr_t) g * per;
  for (j = 0; j < 5; j++) {
   unsigned n = j ? base[j] : n0;
   if (!wl_lengths(d, n, lens) || !wl_make(&codes[5 * g + j], lens, n, at, at + n, root[j])) return 4;
   at += n + (1u << root[j]); } }
 wp_drop(d->m, lens);
 if (cbits && !(cache = wp_zero(d->m, 4u << cbits))) return 6;
 uintptr_t tot = (uintptr_t) w * h, p = 0;
 unsigned x = 0, y = 0;
#define WL_PUT(q) do { uint32_t q_ = (q); px[p++] = q_; \
  if (cache) cache[(0x1e35a7bdu * q_) >> (32 - cbits)] = q_; } while (0)
 while (p < tot) {
  const struct wl_code *g = codes + 5 * (hbits ? map[meta[(y >> hbits) * hw + (x >> hbits)]] : 0);
  unsigned c = wl_sym(d, g);
  if (c < 256) {
   unsigned rr = wl_sym(d, g + 1), b = wl_sym(d, g + 2), a = wl_sym(d, g + 3);
   WL_PUT(a << 24 | rr << 16 | c << 8 | b);
   if (++x == w) x = 0, y++; }
  else if (c < 280) {
   uintptr_t len = wl_copy(d, c - 256), dist = wl_plane(w, wl_copy(d, wl_sym(d, g + 4)));
   if (dist > p || len > tot - p) return 4;
   for (uintptr_t k = 0; k < len; k++) WL_PUT(px[p - dist]);
   x += (unsigned) (len % w), y += (unsigned) (len / w);
   if (x >= w) x -= w, y++; }
  else {
   if (!cache || c - 280 >= (1u << cbits)) return 4;
   WL_PUT(cache[c - 280]);
   if (++x == w) x = 0, y++; }
  if (wl_eos(d)) return 2; }
#undef WL_PUT
 wp_drop(d->m, codes), wp_drop(d->m, store), wp_drop(d->m, map);
 if (cache) wp_drop(d->m, cache);
 if (meta) wp_drop(d->m, meta);
 return 0; }

static uint32_t wl_add(uint32_t a, uint32_t b) {
 return (((a & 0xff00ff00u) + (b & 0xff00ff00u)) & 0xff00ff00u) | (((a & 0xff00ffu) + (b & 0xff00ffu)) & 0xff00ffu); }
static uint32_t wl_avg(uint32_t a, uint32_t b) { return (((a ^ b) & 0xfefefefeu) >> 1) + (a & b); }
static uint32_t wl_c255(int v) { return v < 0 ? 0 : v > 255 ? 255 : (uint32_t) v; }
static uint32_t wl_pred(unsigned mode, uint32_t l, const uint32_t *t) {
 uint32_t r = 0;
 int s, k;
 switch (mode) {
  case 1: return l;
  case 2: return t[0];
  case 3: return t[1];
  case 4: return t[-1];
  case 5: return wl_avg(wl_avg(l, t[1]), t[0]);
  case 6: return wl_avg(l, t[-1]);
  case 7: return wl_avg(l, t[0]);
  case 8: return wl_avg(t[-1], t[0]);
  case 9: return wl_avg(t[0], t[1]);
  case 10: return wl_avg(wl_avg(l, t[-1]), wl_avg(t[0], t[1]));
  case 11:                                       // the neighbour nearer the gradient's guess
   for (s = 0, k = 0; k < 32; k += 8) {
    int a = (int) (t[0] >> k & 255), b = (int) (l >> k & 255), c = (int) (t[-1] >> k & 255);
    s += (b > c ? b - c : c - b) - (a > c ? a - c : c - a); }
   return s <= 0 ? t[0] : l;
  case 12:
   for (k = 0; k < 32; k += 8)
    r |= wl_c255((int) (l >> k & 255) + (int) (t[0] >> k & 255) - (int) (t[-1] >> k & 255)) << k;
   return r;
  case 13: {
   uint32_t a = wl_avg(l, t[0]);
   for (k = 0; k < 32; k += 8) {
    int x = (int) (a >> k & 255);
    r |= wl_c255(x + (x - (int) (t[-1] >> k & 255)) / 2) << k; }
   return r; }
  default: return 0xff000000u; } }
static int wl_s8(uint32_t v) { return (int) (v & 255) - (int) ((v & 128) << 1); }

// the transforms undone, last read first, over px (xs wide); answers the final buffer
static uint32_t *wl_undo(struct wl *d, uint32_t *px, unsigned xs, unsigned h) {
 for (unsigned k = d->nt; k-- > 0; ) {
  struct wl_tr *t = &d->tr[k];
  unsigned w = t->xs, x, y, bw = wl_sub(w, t->bits);
  if (t->type == 0) {                            // predictor
   for (y = 0; y < h; y++)
    for (x = 0; x < w; x++) {
     uint32_t *q = px + (uintptr_t) y * w + x;
     unsigned mode = !y ? (x ? 1 : 0) : !x ? 2 : t->data[(y >> t->bits) * bw + (x >> t->bits)] >> 8 & 15;
     *q = wl_add(*q, wl_pred(mode, x ? q[-1] : 0, y ? q - w : q)); } }
  else if (t->type == 1)                         // cross colour
   for (y = 0; y < h; y++)
    for (x = 0; x < w; x++) {
     uint32_t *q = px + (uintptr_t) y * w + x, m = t->data[(y >> t->bits) * bw + (x >> t->bits)], a = *q;
     int g = wl_s8(a >> 8), r = (int) (a >> 16 & 255), b = (int) (a & 255);
     r = (r + ((wl_s8(m) * g) >> 5)) & 255;
     b = (b + ((wl_s8(m >> 8) * g) >> 5) + ((wl_s8(m >> 16) * wl_s8((uint32_t) r)) >> 5)) & 255;
     *q = (a & 0xff00ff00u) | (uint32_t) r << 16 | (uint32_t) b; }
  else if (t->type == 2)                         // subtract green
   for (uintptr_t i = 0, n = (uintptr_t) w * h; i < n; i++) {
    uint32_t a = px[i], g = a >> 8 & 255;
    px[i] = (a & 0xff00ff00u) | (((a >> 16) + g) & 255) << 16 | ((a + g) & 255); }
  else {                                         // colour indexing: unpacked into a new buffer
   uint32_t *o = wp_new(d->m, (uintptr_t) w * h * 4);
   if (!o) return NULL;
   unsigned bpp = 8 >> t->bits, cm = (1u << t->bits) - 1;
   for (y = 0; y < h; y++)
    for (x = 0; x < w; x++) {
     uint32_t v = px[(uintptr_t) y * xs + (x >> t->bits)] >> 8 & 255;
     o[(uintptr_t) y * w + x] = t->data[(v >> ((x & cm) * bpp)) & ((1u << bpp) - 1)]; }
   wp_drop(d->m, px), px = o; }
  xs = w; }
 return px; }

// a vp8l stream -> w*h argb, or why not. hdr: the 5-byte header first (a VP8L chunk), else
// the bare stream of an ALPH plane, its size the caller's
static int wl_decode(struct wp_mem *m, const uint8_t *s, uintptr_t n, unsigned w, unsigned h,
                     int hdr, uint32_t **out) {
 struct wl d;
 int r;
 memset(&d, 0, sizeof d), d.s = s, d.n = n, d.m = m;
 if (hdr) {
  if (wl_bits(&d, 8) != 0x2f) return 4;
  unsigned ww = wl_bits(&d, 14) + 1, hh = wl_bits(&d, 14) + 1;
  wl_bits(&d, 1);
  if (wl_bits(&d, 3) || wl_eos(&d)) return wl_eos(&d) ? 2 : 4;
  if (ww != w || hh != h) return 4; }
 unsigned xs = w;
 while (wl_bits(&d, 1)) {
  unsigned t = wl_bits(&d, 2);
  if (d.seen & 1u << t) return 4;
  struct wl_tr *T = &d.tr[d.nt++];
  d.seen |= 1u << t, T->type = t, T->xs = xs, T->bits = 0, T->data = NULL;
  if (t < 2) {
   T->bits = wl_bits(&d, 3) + 2;
   unsigned bw = wl_sub(xs, T->bits), bh = wl_sub(h, T->bits);
   if (!(T->data = wp_new(m, (uintptr_t) bw * bh * 4))) return 6;
   if ((r = wl_image(&d, T->data, bw, bh, 0))) return r; }
  else if (t == 3) {
   unsigned nc = wl_bits(&d, 8) + 1;
   T->bits = nc > 16 ? 0 : nc > 4 ? 1 : nc > 2 ? 2 : 3;
   xs = wl_sub(T->xs, T->bits);
   if (!(T->data = wp_zero(m, 256 * 4))) return 6;
   if ((r = wl_image(&d, T->data, nc, 1, 0))) return r;
   for (unsigned i = 1; i < nc; i++) T->data[i] = wl_add(T->data[i], T->data[i - 1]); } }
 uint32_t *px = wp_new(m, (uintptr_t) xs * h * 4);
 if (!px) return 6;
 if ((r = wl_image(&d, px, xs, h, 1))) return r;
 if (wl_eos(&d)) return 2;
 return (*out = wl_undo(&d, px, xs, h)) ? 0 : 6; }

// ===== ALPH, the alpha plane under a lossy picture =====
static int wa_decode(struct wp_mem *m, const uint8_t *s, uintptr_t n, unsigned w, unsigned h, uint8_t *a) {
 if (n < 1) return 2;
 unsigned meth = s[0] & 3, filt = s[0] >> 2 & 3, pre = s[0] >> 4 & 3, x, y;
 uintptr_t tot = (uintptr_t) w * h;
 if (meth > 1 || pre > 1 || s[0] >> 6) return 4;
 if (!meth) { if (n - 1 < tot) return 2; memcpy(a, s + 1, tot); }
 else {
  uint32_t *px;
  int r = wl_decode(m, s + 1, n - 1, w, h, 0, &px);
  if (r) return r;
  for (uintptr_t i = 0; i < tot; i++) a[i] = (uint8_t) (px[i] >> 8);
  wp_drop(m, px); }
 for (y = 0; filt && y < h; y++) {               // the filters undone in place, row by row
  uint8_t *o = a + (uintptr_t) y * w, *p = y ? o - w : NULL;
  if (!p || filt == 1) {
   unsigned pred = p ? p[0] : 0;
   for (x = 0; x < w; x++) pred = o[x] = (uint8_t) (pred + o[x]); }
  else if (filt == 2) for (x = 0; x < w; x++) o[x] = (uint8_t) (p[x] + o[x]);
  else {
   int top, tl = p[0], left = p[0];
   for (x = 0; x < w; x++) {
    int g;
    top = p[x], g = left + top - tl, g = g < 0 ? 0 : g > 255 ? 255 : g;
    left = o[x] = (uint8_t) (o[x] + g), tl = top; } } }
 return 0; }

// ===== vp8, the lossy frame =====
struct vp_br { const uint8_t *p, *e; uint64_t v; uint32_t range; int bits, eof; };
static void vp_init(struct vp_br *b, const uint8_t *p, uintptr_t n) {
 b->p = p, b->e = p + n, b->v = 0, b->range = 254, b->bits = -8, b->eof = 0; }
static int vp_bit(struct vp_br *b, unsigned prob) {
 uint32_t range = b->range, split, value;
 int bit, shift = 0;
 if (b->bits < 0) {
  if (b->p < b->e) b->v = b->v << 8 | *b->p++, b->bits += 8;
  else if (!b->eof) b->v <<= 8, b->bits += 8, b->eof = 1;
  else b->bits = 0; }
 split = (range * prob) >> 8, value = (uint32_t) (b->v >> b->bits);
 if ((bit = value > split)) range -= split, b->v -= (uint64_t) (split + 1) << b->bits;
 else range = split + 1;
 while ((range << shift) < 128) shift++;
 b->range = (range << shift) - 1, b->bits -= shift;
 return bit; }
static int vp_get(struct vp_br *b, int n) {
 int v = 0;
 while (n-- > 0) v |= vp_bit(b, 0x80) << n;
 return v; }
static int vp_sget(struct vp_br *b, int n) { int v = vp_get(b, n); return vp_bit(b, 0x80) ? -v : v; }

#define BPS 32
struct vp_f { uint8_t limit, ilevel, inner, hev; };
struct vp {
 unsigned w, h, mbw, mbh, nparts;
 int use_seg, upd_map, abs_delta, quant[4], fstr[4], segp[3];
 int simple, level, sharp, use_lfd, ref_lfd[4], mode_lfd[4], ftype, use_skip, skip_p;
 struct vp_br br, parts[8];
 struct vp_q { int y1[2], y2[2], uv[2]; } dq[4];
 uint8_t proba[4][8][3][11], intra_l[4], lnz, lnzdc;
 struct vp_f fs[4][2];
 uint8_t *Y, *U, *V, *ytop, *utop, *vtop, *intra_t, *tnz, *tnzdc;
 struct vp_f *fi;
 uintptr_t ys, uvs; };

static int vp_large(struct vp_br *b, const uint8_t *p) {
 int v;
 if (!vp_bit(b, p[3])) v = !vp_bit(b, p[4]) ? 2 : 3 + vp_bit(b, p[5]);
 else if (!vp_bit(b, p[6])) {
  if (!vp_bit(b, p[7])) v = 5 + vp_bit(b, 159);
  else v = 7 + 2 * vp_bit(b, 165), v += vp_bit(b, 145); }
 else {
  int b1 = vp_bit(b, p[8]), b0 = vp_bit(b, p[9 + b1]), cat = 2 * b1 + b0;
  v = 0;
  for (const uint8_t *t = vp_cats[cat]; *t; t++) v += v + vp_bit(b, *t);
  v += 3 + (8 << cat); }
 return v; }
// one block's tokens from n on, dequantized into out in raster order; answers where they ended
static int vp_coeffs(struct vp_br *b, uint8_t (*bands)[3][11], int ctx, const int *dq, int n, int16_t *out) {
 const uint8_t *p = bands[vp_band[n]][ctx];
 for (; n < 16; ++n) {
  if (!vp_bit(b, p[0])) return n;
  while (!vp_bit(b, p[1])) { p = bands[vp_band[++n]][0]; if (n == 16) return 16; }
  int v;
  if (!vp_bit(b, p[2])) v = 1, p = bands[vp_band[n + 1]][1];
  else v = vp_large(b, p), p = bands[vp_band[n + 1]][2];
  out[vp_zigzag[n]] = (int16_t) ((vp_bit(b, 0x80) ? -v : v) * dq[n > 0]); }
 return 16; }
static uint32_t vp_nzbits(uint32_t acc, int nz, int dc) { return acc << 2 | (nz > 3 ? 3 : nz > 1 ? 2 : (uint32_t) dc); }

static void vp_wht(const int16_t *in, int16_t *out) {
 int tmp[16], i;
 for (i = 0; i < 4; i++) {
  int a0 = in[i] + in[12 + i], a1 = in[4 + i] + in[8 + i], a2 = in[4 + i] - in[8 + i], a3 = in[i] - in[12 + i];
  tmp[i] = a0 + a1, tmp[8 + i] = a0 - a1, tmp[4 + i] = a3 + a2, tmp[12 + i] = a3 - a2; }
 for (i = 0; i < 4; i++, out += 64) {
  int dc = tmp[i * 4] + 3, a0 = dc + tmp[3 + i * 4], a1 = tmp[1 + i * 4] + tmp[2 + i * 4],
      a2 = tmp[1 + i * 4] - tmp[2 + i * 4], a3 = dc - tmp[3 + i * 4];
  out[0] = (int16_t) ((a0 + a1) >> 3), out[16] = (int16_t) ((a3 + a2) >> 3);
  out[32] = (int16_t) ((a0 - a1) >> 3), out[48] = (int16_t) ((a3 - a2) >> 3); } }
static uint8_t vp_c1(int v) { return (uint8_t) (v < 0 ? 0 : v > 255 ? 255 : v); }
#define VP_MUL1(a) ((((a) * 20091) >> 16) + (a))
#define VP_MUL2(a) (((a) * 35468) >> 16)
static void vp_idct(const int16_t *in, uint8_t *dst) {
 int c[16], *t = c, i;
 for (i = 0; i < 4; i++, t += 4, in++) {
  int a = in[0] + in[8], b = in[0] - in[8];
  int cc = VP_MUL2(in[4]) - VP_MUL1(in[12]), d = VP_MUL1(in[4]) + VP_MUL2(in[12]);
  t[0] = a + d, t[1] = b + cc, t[2] = b - cc, t[3] = a - d; }
 for (t = c, i = 0; i < 4; i++, t++, dst += BPS) {
  int dc = t[0] + 4, a = dc + t[8], b = dc - t[8];
  int cc = VP_MUL2(t[4]) - VP_MUL1(t[12]), d = VP_MUL1(t[4]) + VP_MUL2(t[12]);
  dst[0] = vp_c1(dst[0] + ((a + d) >> 3)), dst[1] = vp_c1(dst[1] + ((b + cc) >> 3));
  dst[2] = vp_c1(dst[2] + ((b - cc) >> 3)), dst[3] = vp_c1(dst[3] + ((a - d) >> 3)); } }

// ----- the intra predictions, over a BPS-wide work buffer with its borders laid -----
#define DST(x, y) dst[(x) + (y) * BPS]
#define AVG3(a, b, c) ((uint8_t) (((a) + 2 * (b) + (c) + 2) >> 2))
#define AVG2(a, b) ((uint8_t) (((a) + (b) + 1) >> 1))
static void vp_fill(uint8_t *dst, int v, int n) { for (int j = 0; j < n; j++) memset(dst + j * BPS, v, (size_t) n); }
static void vp_tm(uint8_t *dst, int n) {
 const uint8_t *top = dst - BPS;
 for (int y = 0; y < n; y++, dst += BPS)
  for (int x = 0; x < n; x++) dst[x] = vp_c1(top[x] + dst[-1] - top[-1]); }
static void vp_ve(uint8_t *dst, int n) { for (int j = 0; j < n; j++) memcpy(dst + j * BPS, dst - BPS, (size_t) n); }
static void vp_he(uint8_t *dst, int n) { for (int j = 0; j < n; j++) memset(dst + j * BPS, dst[j * BPS - 1], (size_t) n); }
// the dc of a 16 (lg 5) or 8 (lg 4) square: top and left, or the one there is, or 128
static void vp_dc(uint8_t *dst, int n, int lg, int top, int left) {
 int s = 0, j;
 for (j = 0; j < n; j++) s += (top ? dst[j - BPS] : 0) + (left ? dst[-1 + j * BPS] : 0);
 vp_fill(dst, top && left ? (s + n) >> lg : top || left ? (s + n / 2) >> (lg - 1) : 0x80, n); }
static void vp_pred16(uint8_t *dst, int mode, int n, int lg, int mbx, int mby) {
 if (mode == 0) vp_dc(dst, n, lg, mby > 0, mbx > 0);
 else if (mode == 1) vp_tm(dst, n);
 else if (mode == 2) vp_ve(dst, n);
 else vp_he(dst, n); }
static void vp_pred4(uint8_t *dst, int mode) {
 const int I = dst[-1], J = dst[-1 + BPS], K = dst[-1 + 2 * BPS], L = dst[-1 + 3 * BPS], X = dst[-1 - BPS];
 const int A = dst[-BPS], B = dst[1 - BPS], C = dst[2 - BPS], D = dst[3 - BPS];
 const int E = dst[4 - BPS], F = dst[5 - BPS], G = dst[6 - BPS], H = dst[7 - BPS];
 int i;
 switch (mode) {
  case 0: {
   unsigned dc = 4;
   for (i = 0; i < 4; i++) dc += dst[i - BPS] + dst[-1 + i * BPS];
   vp_fill(dst, (int) (dc >> 3), 4); break; }
  case 1: vp_tm(dst, 4); break;
  case 2: {
   uint8_t v[4] = { AVG3(X, A, B), AVG3(A, B, C), AVG3(B, C, D), AVG3(C, D, E) };
   for (i = 0; i < 4; i++) memcpy(dst + i * BPS, v, 4);
   break; }
  case 3:
   memset(dst, AVG3(X, I, J), 4), memset(dst + BPS, AVG3(I, J, K), 4);
   memset(dst + 2 * BPS, AVG3(J, K, L), 4), memset(dst + 3 * BPS, AVG3(K, L, L), 4); break;
  case 4:                                        // down-right
   DST(0, 3) = AVG3(J, K, L);
   DST(1, 3) = DST(0, 2) = AVG3(I, J, K);
   DST(2, 3) = DST(1, 2) = DST(0, 1) = AVG3(X, I, J);
   DST(3, 3) = DST(2, 2) = DST(1, 1) = DST(0, 0) = AVG3(A, X, I);
   DST(3, 2) = DST(2, 1) = DST(1, 0) = AVG3(B, A, X);
   DST(3, 1) = DST(2, 0) = AVG3(C, B, A);
   DST(3, 0) = AVG3(D, C, B); break;
  case 5:                                        // vertical-right
   DST(0, 0) = DST(1, 2) = AVG2(X, A);
   DST(1, 0) = DST(2, 2) = AVG2(A, B);
   DST(2, 0) = DST(3, 2) = AVG2(B, C);
   DST(3, 0) = AVG2(C, D);
   DST(0, 3) = AVG3(K, J, I);
   DST(0, 2) = AVG3(J, I, X);
   DST(0, 1) = DST(1, 3) = AVG3(I, X, A);
   DST(1, 1) = DST(2, 3) = AVG3(X, A, B);
   DST(2, 1) = DST(3, 3) = AVG3(A, B, C);
   DST(3, 1) = AVG3(B, C, D); break;
  case 6:                                        // down-left
   DST(0, 0) = AVG3(A, B, C);
   DST(1, 0) = DST(0, 1) = AVG3(B, C, D);
   DST(2, 0) = DST(1, 1) = DST(0, 2) = AVG3(C, D, E);
   DST(3, 0) = DST(2, 1) = DST(1, 2) = DST(0, 3) = AVG3(D, E, F);
   DST(3, 1) = DST(2, 2) = DST(1, 3) = AVG3(E, F, G);
   DST(3, 2) = DST(2, 3) = AVG3(F, G, H);
   DST(3, 3) = AVG3(G, H, H); break;
  case 7:                                        // vertical-left
   DST(0, 0) = AVG2(A, B);
   DST(1, 0) = DST(0, 2) = AVG2(B, C);
   DST(2, 0) = DST(1, 2) = AVG2(C, D);
   DST(3, 0) = DST(2, 2) = AVG2(D, E);
   DST(0, 1) = AVG3(A, B, C);
   DST(1, 1) = DST(0, 3) = AVG3(B, C, D);
   DST(2, 1) = DST(1, 3) = AVG3(C, D, E);
   DST(3, 1) = DST(2, 3) = AVG3(D, E, F);
   DST(3, 2) = AVG3(E, F, G);
   DST(3, 3) = AVG3(F, G, H); break;
  case 8:                                        // horizontal-down
   DST(0, 0) = DST(2, 1) = AVG2(I, X);
   DST(0, 1) = DST(2, 2) = AVG2(J, I);
   DST(0, 2) = DST(2, 3) = AVG2(K, J);
   DST(0, 3) = AVG2(L, K);
   DST(3, 0) = AVG3(A, B, C);
   DST(2, 0) = AVG3(X, A, B);
   DST(1, 0) = DST(3, 1) = AVG3(I, X, A);
   DST(1, 1) = DST(3, 2) = AVG3(J, I, X);
   DST(1, 2) = DST(3, 3) = AVG3(K, J, I);
   DST(1, 3) = AVG3(L, K, J); break;
  default:                                       // horizontal-up
   DST(0, 0) = AVG2(I, J);
   DST(2, 0) = DST(0, 1) = AVG2(J, K);
   DST(2, 1) = DST(0, 2) = AVG2(K, L);
   DST(1, 0) = AVG3(I, J, K);
   DST(3, 0) = DST(1, 1) = AVG3(J, K, L);
   DST(3, 1) = DST(1, 2) = AVG3(K, L, L);
   DST(3, 2) = DST(2, 2) = DST(0, 3) = DST(1, 3) = DST(2, 3) = DST(3, 3) = (uint8_t) L; } }
#undef DST
#undef AVG3
#undef AVG2

// ----- the headers -----
static int vp_headers(struct vp *v, const uint8_t *s, uintptr_t n) {
 uint32_t bits = rd24(s), plen = bits >> 5;
 int i, t, b, c, p;
 if (bits & 1) return 3;                         // an interframe: no picture of its own
 if ((bits >> 1 & 7) > 3 || !(bits >> 4 & 1)) return 4;
 if (s[3] != 0x9d || s[4] != 0x01 || s[5] != 0x2a) return 4;
 v->w = rd16(s + 6) & 0x3fff, v->h = rd16(s + 8) & 0x3fff;
 if (!v->w || !v->h) return 4;
 s += 10, n -= 10;
 if (plen > n) return 2;
 struct vp_br *br = &v->br;
 vp_init(br, s, plen);
 vp_get(br, 1), vp_get(br, 1);                   // colour space, clamping: one answer each
 v->abs_delta = 1, v->segp[0] = v->segp[1] = v->segp[2] = 255;
 if ((v->use_seg = vp_get(br, 1))) {
  v->upd_map = vp_get(br, 1);
  if (vp_get(br, 1)) {
   v->abs_delta = vp_get(br, 1);
   for (i = 0; i < 4; i++) v->quant[i] = vp_get(br, 1) ? vp_sget(br, 7) : 0;
   for (i = 0; i < 4; i++) v->fstr[i] = vp_get(br, 1) ? vp_sget(br, 6) : 0; }
  if (v->upd_map) for (i = 0; i < 3; i++) v->segp[i] = vp_get(br, 1) ? vp_get(br, 8) : 255; }
 v->simple = vp_get(br, 1), v->level = vp_get(br, 6), v->sharp = vp_get(br, 3);
 if ((v->use_lfd = vp_get(br, 1)) && vp_get(br, 1)) {
  for (i = 0; i < 4; i++) if (vp_get(br, 1)) v->ref_lfd[i] = vp_sget(br, 6);
  for (i = 0; i < 4; i++) if (vp_get(br, 1)) v->mode_lfd[i] = vp_sget(br, 6); }
 v->ftype = !v->level ? 0 : v->simple ? 1 : 2;
 if (br->eof) return 2;
 // the token partitions, each but the last sized ahead of them
 const uint8_t *sz = s + plen, *at, *end = s + n;
 uintptr_t left = n - plen;
 unsigned last = (1u << vp_get(br, 2)) - 1;
 v->nparts = last + 1;
 if (left < 3 * last) return 2;
 at = sz + 3 * last, left -= 3 * last;
 for (unsigned k = 0; k < last; k++, sz += 3) {
  uintptr_t ps = rd24(sz);
  if (ps > left) ps = left;
  vp_init(&v->parts[k], at, ps), at += ps, left -= ps; }
 vp_init(&v->parts[last], at, left);
 if (at >= end) return 2;
 // the quantizers
 int q0 = vp_get(br, 7), d1 = vp_get(br, 1) ? vp_sget(br, 4) : 0, d2 = vp_get(br, 1) ? vp_sget(br, 4) : 0,
     d3 = vp_get(br, 1) ? vp_sget(br, 4) : 0, d4 = vp_get(br, 1) ? vp_sget(br, 4) : 0,
     d5 = vp_get(br, 1) ? vp_sget(br, 4) : 0;
 for (i = 0; i < 4; i++) {
  int q = v->use_seg ? v->quant[i] + (v->abs_delta ? 0 : q0) : q0;
#define CLIP(x, m) ((x) < 0 ? 0 : (x) > (m) ? (m) : (x))
  v->dq[i].y1[0] = vp_dct[CLIP(q + d1, 127)], v->dq[i].y1[1] = vp_act[CLIP(q, 127)];
  v->dq[i].y2[0] = vp_dct[CLIP(q + d2, 127)] * 2;
  v->dq[i].y2[1] = vp_act[CLIP(q + d3, 127)] * 101581 >> 16;
  if (v->dq[i].y2[1] < 8) v->dq[i].y2[1] = 8;
  v->dq[i].uv[0] = vp_dct[CLIP(q + d4, 117)], v->dq[i].uv[1] = vp_act[CLIP(q + d5, 127)];
#undef CLIP
 }
 vp_get(br, 1);                                  // refresh the probabilities: no matter here
 for (t = 0, i = 0; t < 4; t++)
  for (b = 0; b < 8; b++)
   for (c = 0; c < 3; c++)
    for (p = 0; p < 11; p++, i++)
     v->proba[t][b][c][p] = (uint8_t) (vp_bit(br, vp_upd[i]) ? vp_get(br, 8) : vp_proba0[i]);
 if ((v->use_skip = vp_get(br, 1))) v->skip_p = vp_get(br, 8);
 // each segment's loop filter, plain and for 4x4 blocks
 for (i = 0; v->ftype && i < 4; i++)
  for (int i4 = 0; i4 <= 1; i4++) {
   struct vp_f *f = &v->fs[i][i4];
   int level = v->use_seg ? v->fstr[i] + (v->abs_delta ? 0 : v->level) : v->level;
   if (v->use_lfd) { level += v->ref_lfd[0]; if (i4) level += v->mode_lfd[0]; }
   level = level < 0 ? 0 : level > 63 ? 63 : level;
   f->limit = 0, f->inner = (uint8_t) i4;
   if (level > 0) {
    int il = level;
    if (v->sharp > 0) { il >>= v->sharp > 4 ? 2 : 1; if (il > 9 - v->sharp) il = 9 - v->sharp; }
    if (il < 1) il = 1;
    f->ilevel = (uint8_t) il, f->limit = (uint8_t) (2 * level + il);
    f->hev = level >= 40 ? 2 : level >= 15 ? 1 : 0; } }
 return br->eof ? 2 : 0; }

// ----- one macroblock: its modes, its tokens, its pixels -----
static int vp_mb(struct vp *v, unsigned mbx, unsigned mby, uint8_t *yuv) {
 struct vp_br *br = &v->br, *tb = &v->parts[mby & (v->nparts - 1)];
 uint8_t modes[16], *top = v->intra_t + 4 * mbx, *left = v->intra_l;
 int seg = !v->upd_map ? 0 : !vp_bit(br, v->segp[0]) ? vp_bit(br, v->segp[1]) : vp_bit(br, v->segp[2]) + 2;
 int skip = v->use_skip ? vp_bit(br, v->skip_p) : 0, i4 = !vp_bit(br, 145), x, y, uvmode;
 if (!i4) {
  int ym = vp_bit(br, 156) ? (vp_bit(br, 128) ? 1 : 3) : (vp_bit(br, 163) ? 2 : 0);
  modes[0] = (uint8_t) ym, memset(top, ym, 4), memset(left, ym, 4); }
 else
  for (y = 0; y < 4; y++) {
   int ym = left[y];
   for (x = 0; x < 4; x++) {
    const uint8_t *prob = vp_bmodes + (top[x] * 10 + ym) * 9;
    int k = vp_ytree[vp_bit(br, prob[0])];
    while (k > 0) k = vp_ytree[2 * k + vp_bit(br, prob[k])];
    ym = -k, top[x] = (uint8_t) ym; }
   memcpy(modes + 4 * y, top, 4), left[y] = (uint8_t) ym; }
 uvmode = !vp_bit(br, 142) ? 0 : !vp_bit(br, 114) ? 2 : vp_bit(br, 183) ? 1 : 3;

 int16_t co[384];
 uint32_t nzy = 0, nzuv = 0;
 memset(co, 0, sizeof co);
 if (!skip) {
  const struct vp_q *q = &v->dq[seg];
  int16_t *dst = co, first;
  uint8_t tnz, lnz, *mnz = &v->tnz[mbx], *mdc = &v->tnzdc[mbx];
  uint8_t (*ac)[3][11];
  uint32_t ot, ol;
  if (!i4) {
   int16_t dc[16] = { 0 };
   int nz = vp_coeffs(tb, v->proba[1], *mdc + v->lnzdc, q->y2, 0, dc);
   *mdc = v->lnzdc = nz > 0;
   vp_wht(dc, dst);
   first = 1, ac = v->proba[0]; }
  else first = 0, ac = v->proba[3];
  tnz = *mnz & 15, lnz = v->lnz & 15;
  for (y = 0; y < 4; y++) {
   int l = lnz & 1;
   uint32_t nc = 0;
   for (x = 0; x < 4; x++, dst += 16) {
    int nz = vp_coeffs(tb, ac, l + (tnz & 1), q->y1, first, dst);
    l = nz > first, tnz = (uint8_t) (tnz >> 1 | l << 7), nc = vp_nzbits(nc, nz, dst[0] != 0); }
   tnz >>= 4, lnz = (uint8_t) (lnz >> 1 | l << 7), nzy = nzy << 8 | nc; }
  ot = tnz, ol = lnz >> 4;
  for (int ch = 0; ch < 4; ch += 2) {
   uint32_t nc = 0;
   tnz = (uint8_t) (*mnz >> (4 + ch)), lnz = (uint8_t) (v->lnz >> (4 + ch));
   for (y = 0; y < 2; y++) {
    int l = lnz & 1;
    for (x = 0; x < 2; x++, dst += 16) {
     int nz = vp_coeffs(tb, v->proba[2], l + (tnz & 1), q->uv, 0, dst);
     l = nz > 0, tnz = (uint8_t) (tnz >> 1 | l << 3), nc = vp_nzbits(nc, nz, dst[0] != 0); }
    tnz >>= 2, lnz = (uint8_t) (lnz >> 1 | l << 5); }
   nzuv |= nc << (4 * ch), ot |= (uint32_t) (tnz << 4) << ch, ol |= (uint32_t) (lnz & 0xf0) << ch; }
  *mnz = (uint8_t) ot, v->lnz = (uint8_t) ol;
  skip = !(nzy | nzuv); }
 else {
  v->tnz[mbx] = v->lnz = 0;
  if (!i4) v->tnzdc[mbx] = v->lnzdc = 0; }
 if (v->ftype) {
  struct vp_f *f = &v->fi[(uintptr_t) mby * v->mbw + mbx];
  *f = v->fs[seg][i4], f->inner |= (uint8_t) !skip; }
 if (tb->eof) return 2;

 // the pixels: predicted off the unfiltered neighbours, the residue added
 uint8_t *yd = yuv + BPS + 8, *ud = yd + 17 * BPS, *vd = ud + 16;
 uint8_t *yt = v->ytop + 16 * mbx, *ut = v->utop + 8 * mbx, *vt = v->vtop + 8 * mbx;
 int j, n;
 if (mbx > 0) {                                  // the left samples, off the last block
  for (j = -1; j < 16; j++) memcpy(yd + j * BPS - 4, yd + j * BPS + 12, 4);
  for (j = -1; j < 8; j++) memcpy(ud + j * BPS - 4, ud + j * BPS + 4, 4), memcpy(vd + j * BPS - 4, vd + j * BPS + 4, 4); }
 if (mby > 0) memcpy(yd - BPS, yt, 16), memcpy(ud - BPS, ut, 8), memcpy(vd - BPS, vt, 8);
 if (i4) {
  uint8_t *tr = yd - BPS + 16;
  if (mby > 0) { if (mbx >= v->mbw - 1) memset(tr, yt[15], 4); else memcpy(tr, yt + 16, 4); }
  for (j = 1; j < 4; j++) memcpy(tr + 4 * j * BPS, tr, 4);
  for (n = 0; n < 16; n++) {
   uint8_t *d = yd + (n & 3) * 4 + (n >> 2) * 4 * BPS;
   vp_pred4(d, modes[n]);
   if (nzy << (2 * n) >> 30) vp_idct(co + n * 16, d); } }
 else {
  vp_pred16(yd, modes[0], 16, 5, (int) mbx, (int) mby);
  for (n = 0; nzy && n < 16; n++)
   if (nzy << (2 * n) >> 30) vp_idct(co + n * 16, yd + (n & 3) * 4 + (n >> 2) * 4 * BPS); }
 vp_pred16(ud, uvmode, 8, 4, (int) mbx, (int) mby), vp_pred16(vd, uvmode, 8, 4, (int) mbx, (int) mby);
 for (n = 0; n < 4; n++) {
  if (nzuv & 0xff) vp_idct(co + 256 + n * 16, ud + (n & 1) * 4 + (n >> 1) * 4 * BPS);
  if (nzuv >> 8 & 0xff) vp_idct(co + 320 + n * 16, vd + (n & 1) * 4 + (n >> 1) * 4 * BPS); }
 if (mby < v->mbh - 1) memcpy(yt, yd + 15 * BPS, 16), memcpy(ut, ud + 7 * BPS, 8), memcpy(vt, vd + 7 * BPS, 8);
 for (j = 0; j < 16; j++) memcpy(v->Y + (mby * 16 + (unsigned) j) * v->ys + mbx * 16, yd + j * BPS, 16);
 for (j = 0; j < 8; j++) {
  memcpy(v->U + (mby * 8 + (unsigned) j) * v->uvs + mbx * 8, ud + j * BPS, 8);
  memcpy(v->V + (mby * 8 + (unsigned) j) * v->uvs + mbx * 8, vd + j * BPS, 8); }
 return 0; }

// ----- the loop filter, over the whole frame in raster order -----
static int vp_sc1(int v) { return v < -128 ? -128 : v > 127 ? 127 : v; }
static int vp_sc2(int v) { return v < -16 ? -16 : v > 15 ? 15 : v; }
static int vp_abs(int v) { return v < 0 ? -v : v; }
static void vp_f2(uint8_t *p, int s) {
 int p1 = p[-2 * s], p0 = p[-s], q0 = p[0], q1 = p[s], a = 3 * (q0 - p0) + vp_sc1(p1 - q1);
 int a1 = vp_sc2((a + 4) >> 3), a2 = vp_sc2((a + 3) >> 3);
 p[-s] = vp_c1(p0 + a2), p[0] = vp_c1(q0 - a1); }
static void vp_f4(uint8_t *p, int s) {
 int p1 = p[-2 * s], p0 = p[-s], q0 = p[0], q1 = p[s], a = 3 * (q0 - p0);
 int a1 = vp_sc2((a + 4) >> 3), a2 = vp_sc2((a + 3) >> 3), a3 = (a1 + 1) >> 1;
 p[-2 * s] = vp_c1(p1 + a3), p[-s] = vp_c1(p0 + a2), p[0] = vp_c1(q0 - a1), p[s] = vp_c1(q1 - a3); }
static void vp_f6(uint8_t *p, int s) {
 int p2 = p[-3 * s], p1 = p[-2 * s], p0 = p[-s], q0 = p[0], q1 = p[s], q2 = p[2 * s];
 int a = vp_sc1(3 * (q0 - p0) + vp_sc1(p1 - q1));
 int a1 = (27 * a + 63) >> 7, a2 = (18 * a + 63) >> 7, a3 = (9 * a + 63) >> 7;
 p[-3 * s] = vp_c1(p2 + a3), p[-2 * s] = vp_c1(p1 + a2), p[-s] = vp_c1(p0 + a1);
 p[0] = vp_c1(q0 - a1), p[s] = vp_c1(q1 - a2), p[2 * s] = vp_c1(q2 - a3); }
static int vp_hev(const uint8_t *p, int s, int t) {
 return vp_abs(p[-2 * s] - p[-s]) > t || vp_abs(p[s] - p[0]) > t; }
static int vp_need(const uint8_t *p, int s, int t) {
 return 4 * vp_abs(p[-s] - p[0]) + vp_abs(p[-2 * s] - p[s]) <= t; }
static int vp_need2(const uint8_t *p, int s, int t, int it) {
 int p3 = p[-4 * s], p2 = p[-3 * s], p1 = p[-2 * s], p0 = p[-s], q0 = p[0], q1 = p[s], q2 = p[2 * s], q3 = p[3 * s];
 if (4 * vp_abs(p0 - q0) + vp_abs(p1 - q1) > t) return 0;
 return vp_abs(p3 - p2) <= it && vp_abs(p2 - p1) <= it && vp_abs(p1 - p0) <= it
     && vp_abs(q3 - q2) <= it && vp_abs(q2 - q1) <= it && vp_abs(q1 - q0) <= it; }
// the simple filter across an edge of 16: hs the step across it, vs along it
static void vp_simple(uint8_t *p, int hs, int vs, int t) {
 for (int i = 0; i < 16; i++, p += vs) if (vp_need(p, hs, 2 * t + 1)) vp_f2(p, hs); }
static void vp_loop(uint8_t *p, int hs, int vs, int n, int t, int it, int hev, int mb) {
 for (int t2 = 2 * t + 1; n-- > 0; p += vs)
  if (vp_need2(p, hs, t2, it)) { if (vp_hev(p, hs, hev)) vp_f2(p, hs); else if (mb) vp_f6(p, hs); else vp_f4(p, hs); } }
static void vp_filter(struct vp *v) {
 int ys = (int) v->ys, uvs = (int) v->uvs, k;
 for (unsigned my = 0; my < v->mbh; my++)
  for (unsigned mx = 0; mx < v->mbw; mx++) {
   const struct vp_f *f = &v->fi[(uintptr_t) my * v->mbw + mx];
   int lim = f->limit, il = f->ilevel, hev = f->hev;
   uint8_t *y = v->Y + my * 16 * v->ys + mx * 16, *u = v->U + my * 8 * v->uvs + mx * 8,
           *w = v->V + my * 8 * v->uvs + mx * 8;
   if (!lim) continue;
   if (v->ftype == 1) {
    if (mx > 0) vp_simple(y, 1, ys, lim + 4);
    if (f->inner) for (k = 4; k < 16; k += 4) vp_simple(y + k, 1, ys, lim);
    if (my > 0) vp_simple(y, ys, 1, lim + 4);
    if (f->inner) for (k = 4; k < 16; k += 4) vp_simple(y + k * ys, ys, 1, lim);
    continue; }
   if (mx > 0) {
    vp_loop(y, 1, ys, 16, lim + 4, il, hev, 1);
    vp_loop(u, 1, uvs, 8, lim + 4, il, hev, 1), vp_loop(w, 1, uvs, 8, lim + 4, il, hev, 1); }
   if (f->inner) {
    for (k = 4; k < 16; k += 4) vp_loop(y + k, 1, ys, 16, lim, il, hev, 0);
    vp_loop(u + 4, 1, uvs, 8, lim, il, hev, 0), vp_loop(w + 4, 1, uvs, 8, lim, il, hev, 0); }
   if (my > 0) {
    vp_loop(y, ys, 1, 16, lim + 4, il, hev, 1);
    vp_loop(u, uvs, 1, 8, lim + 4, il, hev, 1), vp_loop(w, uvs, 1, 8, lim + 4, il, hev, 1); }
   if (f->inner) {
    for (k = 4; k < 16; k += 4) vp_loop(y + k * ys, ys, 1, 16, lim, il, hev, 0);
    vp_loop(u + 4 * uvs, uvs, 1, 8, lim, il, hev, 0), vp_loop(w + 4 * uvs, uvs, 1, 8, lim, il, hev, 0); } } }

// ----- yuv 4:2:0 to rgba, the chroma upsampled as libwebp's "fancy" upsampler does -----
static int vp_mh(int v, int c) { return (v * c) >> 8; }
static uint8_t vp_c8(int v) { return (v & ~16383) == 0 ? (uint8_t) (v >> 6) : v < 0 ? 0 : 255; }
static void vp_rgb(int y, int u, int v, uint8_t *o) {
 o[0] = vp_c8(vp_mh(y, 19077) + vp_mh(v, 26149) - 14234);
 o[1] = vp_c8(vp_mh(y, 19077) - vp_mh(u, 6419) - vp_mh(v, 13320) + 8708);
 o[2] = vp_c8(vp_mh(y, 19077) + vp_mh(u, 33050) - 17685);
 o[3] = 255; }
#define VP_UV(u, v) ((uint32_t) (u) | (uint32_t) (v) << 16)
#define VP_PUT(yy, uv, o) vp_rgb(yy, (int) ((uv) & 0xff), (int) ((uv) >> 16), o)
// one pair of rows: ty over the chroma rows tu/tv (above) and cu/cv (this one); by may be NULL
static void vp_ups(const uint8_t *ty, const uint8_t *by, const uint8_t *tu, const uint8_t *tv,
                   const uint8_t *cu, const uint8_t *cv, uint8_t *to, uint8_t *bo, unsigned len) {
 unsigned x, last = (len - 1) >> 1;
 uint32_t tl = VP_UV(tu[0], tv[0]), l = VP_UV(cu[0], cv[0]);
 { uint32_t uv0 = (3 * tl + l + 0x00020002u) >> 2; VP_PUT(ty[0], uv0, to); }
 if (by) { uint32_t uv0 = (3 * l + tl + 0x00020002u) >> 2; VP_PUT(by[0], uv0, bo); }
 for (x = 1; x <= last; x++) {
  uint32_t t = VP_UV(tu[x], tv[x]), uv = VP_UV(cu[x], cv[x]);
  uint32_t avg = tl + t + l + uv + 0x00080008u, d12 = (avg + 2 * (t + l)) >> 3, d03 = (avg + 2 * (tl + uv)) >> 3;
  { uint32_t uv0 = (d12 + tl) >> 1, uv1 = (d03 + t) >> 1;
    VP_PUT(ty[2 * x - 1], uv0, to + (2 * x - 1) * 4), VP_PUT(ty[2 * x], uv1, to + 2 * x * 4); }
  if (by) {
   uint32_t uv0 = (d03 + l) >> 1, uv1 = (d12 + uv) >> 1;
   VP_PUT(by[2 * x - 1], uv0, bo + (2 * x - 1) * 4), VP_PUT(by[2 * x], uv1, bo + 2 * x * 4); }
  tl = t, l = uv; }
 if (!(len & 1)) {
  { uint32_t uv0 = (3 * tl + l + 0x00020002u) >> 2; VP_PUT(ty[len - 1], uv0, to + (len - 1) * 4); }
  if (by) { uint32_t uv0 = (3 * l + tl + 0x00020002u) >> 2; VP_PUT(by[len - 1], uv0, bo + (len - 1) * 4); } } }
#undef VP_UV
#undef VP_PUT

// a VP8 chunk's frame -> w*h rgba into o (w and h must be what the caller expects), alpha 255
static int vp_decode(struct wp_mem *m, const uint8_t *s, uintptr_t n, unsigned w, unsigned h, uint8_t *o) {
 if (n < 10) return 2;
 struct vp *v = wp_zero(m, sizeof *v);
 if (!v) return 6;
 int r = vp_headers(v, s, n);
 if (r) return r;
 if (v->w != w || v->h != h) return 4;
 v->mbw = (w + 15) >> 4, v->mbh = (h + 15) >> 4, v->ys = v->mbw * 16, v->uvs = v->mbw * 8;
 uintptr_t ny = v->ys * v->mbh * 16, nuv = v->uvs * v->mbh * 8;
 if (!(v->Y = wp_new(m, ny + 2 * nuv)) || !(v->ytop = wp_zero(m, v->mbw * 32))
     || !(v->intra_t = wp_zero(m, v->mbw * 6)) || !(v->fi = wp_zero(m, (uintptr_t) v->mbw * v->mbh * sizeof *v->fi)))
  return 6;
 v->U = v->Y + ny, v->V = v->U + nuv, v->utop = v->ytop + 16 * v->mbw, v->vtop = v->utop + 8 * v->mbw;
 v->tnz = v->intra_t + 4 * v->mbw, v->tnzdc = v->tnz + v->mbw;
 uint8_t yuv[BPS * 26], *yd = yuv + BPS + 8, *ud = yd + 17 * BPS, *vd = ud + 16;
 memset(yuv, 0, sizeof yuv);
 for (unsigned my = 0; my < v->mbh; my++) {
  memset(v->intra_l, 0, 4), v->lnz = v->lnzdc = 0;
  for (int j = 0; j < 16; j++) yd[j * BPS - 1] = 129;
  for (int j = 0; j < 8; j++) ud[j * BPS - 1] = vd[j * BPS - 1] = 129;
  if (my > 0) yd[-1 - BPS] = ud[-1 - BPS] = vd[-1 - BPS] = 129;
  else memset(yd - BPS - 1, 127, 21), memset(ud - BPS - 1, 127, 9), memset(vd - BPS - 1, 127, 9);
  for (unsigned mx = 0; mx < v->mbw; mx++) if ((r = vp_mb(v, mx, my, yuv))) return r;
  if (v->br.eof) return 2; }
 if (v->ftype) vp_filter(v);
 // rows paired as libwebp emits them: the first alone, then (1,2) (3,4) .., an even height's last alone
 uintptr_t rs = (uintptr_t) w * 4;
 vp_ups(v->Y, NULL, v->U, v->V, v->U, v->V, o, NULL, w);
 for (unsigned y = 1; y + 1 < h; y += 2) {
  const uint8_t *tu = v->U + (y >> 1) * v->uvs, *tv = v->V + (y >> 1) * v->uvs;
  vp_ups(v->Y + y * v->ys, v->Y + (y + 1) * v->ys, tu, tv, tu + v->uvs, tv + v->uvs,
         o + y * rs, o + (y + 1) * rs, w); }
 if (!(h & 1) && h > 1) {
  const uint8_t *cu = v->U + ((h - 1) >> 1) * v->uvs, *cv = v->V + ((h - 1) >> 1) * v->uvs;
  vp_ups(v->Y + (h - 1) * v->ys, NULL, cu, cv, cu, cv, o + (h - 1) * rs, NULL, w); }
 wp_drop(m, v->Y), wp_drop(m, v->ytop), wp_drop(m, v->intra_t), wp_drop(m, v->fi), wp_drop(m, v);
 return 0; }

// ===== the container =====
// one frame's chunks (an ALPH, then a VP8 or a VP8L) from p to e -> w*h rgba into o
static int wp_frame(struct wp_mem *m, const uint8_t *p, const uint8_t *e, unsigned w, unsigned h, uint8_t *o) {
 const uint8_t *alph = NULL;
 uintptr_t an = 0;
 while (p + 8 <= e) {
  uintptr_t sz = rd32(p + 4);
  const uint8_t *d = p + 8;
  if (sz > (uintptr_t) (e - d)) return 2;
  if (!memcmp(p, "ALPH", 4)) alph = d, an = sz;
  else if (!memcmp(p, "VP8 ", 4)) {
   int r = vp_decode(m, d, sz, w, h, o);
   if (r || !alph) return r;
   uint8_t *a = wp_new(m, (uintptr_t) w * h);
   if (!a) return 6;
   if ((r = wa_decode(m, alph, an, w, h, a))) return r;
   for (uintptr_t i = 0, k = (uintptr_t) w * h; i < k; i++) o[4 * i + 3] = a[i];
   return wp_drop(m, a), 0; }
  else if (!memcmp(p, "VP8L", 4)) {
   uint32_t *px;
   int r = wl_decode(m, d, sz, w, h, 1, &px);
   if (r) return r;
   for (uintptr_t i = 0, k = (uintptr_t) w * h; i < k; i++) {
    uint32_t a = px[i];
    o[4 * i] = (uint8_t) (a >> 16), o[4 * i + 1] = (uint8_t) (a >> 8), o[4 * i + 2] = (uint8_t) a, o[4 * i + 3] = (uint8_t) (a >> 24); }
   return wp_drop(m, px), 0; }
  p = d + sz + (sz & 1); }
 return 2; }

// the size off the headers, and where the first frame's chunks lie on its canvas
struct wp_info { unsigned w, h, fx, fy, fw, fh; const uint8_t *p, *e; };
static int wp_info(const uint8_t *s, uintptr_t n, struct wp_info *f) {
 if (n < 12 || memcmp(s, "RIFF", 4) || memcmp(s + 8, "WEBP", 4)) return 1;
 uintptr_t rs = rd32(s + 4);
 if (rs < 4 || rs > n - 8) return 2;
 const uint8_t *p = s + 12, *e = s + 8 + rs;
 if (p + 8 > e) return 2;
 uintptr_t sz = rd32(p + 4);
 if (sz > (uintptr_t) (e - p - 8)) return 2;
 if (!memcmp(p, "VP8 ", 4)) {
  if (sz < 10) return 2;
  f->w = rd16(p + 14) & 0x3fff, f->h = rd16(p + 16) & 0x3fff; }
 else if (!memcmp(p, "VP8L", 4)) {
  if (sz < 5) return 2;
  if (p[8] != 0x2f) return 4;
  uint32_t b = rd32(p + 9);
  f->w = (b & 0x3fff) + 1, f->h = (b >> 14 & 0x3fff) + 1; }
 else if (!memcmp(p, "VP8X", 4)) {
  if (sz < 10) return 2;
  int anim = p[8] & 2;
  f->w = rd24(p + 12) + 1, f->h = rd24(p + 15) + 1;
  f->p = p + 8 + sz + (sz & 1), f->e = e, f->fx = f->fy = 0, f->fw = f->w, f->fh = f->h;
  if (wp_big(f->w, f->h)) return 5;
  if (!anim) return 0;
  for (p = f->p; p + 8 <= e; p += 8 + sz + (sz & 1)) {   // the first ANMF
   sz = rd32(p + 4);
   if (sz > (uintptr_t) (e - p - 8)) return 2;
   if (memcmp(p, "ANMF", 4)) continue;
   if (sz < 16) return 2;
   f->fx = rd24(p + 8) * 2, f->fy = rd24(p + 11) * 2, f->fw = rd24(p + 14) + 1, f->fh = rd24(p + 17) + 1;
   if (f->fx + f->fw > f->w || f->fy + f->fh > f->h) return 4;
   f->p = p + 24, f->e = p + 8 + sz;
   return 0; }
  return 4; }
 else return 4;
 if (!f->w || !f->h) return 4;
 f->p = s + 12, f->e = e, f->fx = f->fy = 0, f->fw = f->w, f->fh = f->h;
 return wp_big(f->w, f->h) ? 5 : 0; }

// -> the canvas, or why not
static int wp_decode(struct wp_mem *m, const uint8_t *s, uintptr_t n, struct wp_info *f, uint8_t **out) {
 int r = wp_info(s, n, f);
 if (r) return r;
 uint8_t *o = wp_zero(m, (uintptr_t) f->w * f->h * 4), *fr = o;
 if (!o) return 6;
 if (f->fw != f->w || f->fh != f->h) { if (!(fr = wp_new(m, (uintptr_t) f->fw * f->fh * 4))) return 6; }
 if ((r = wp_frame(m, f->p, f->e, f->fw, f->fh, fr))) return r;
 if (fr != o)                                    // an animation's first frame, laid on a clear canvas
  for (unsigned y = 0; y < f->fh; y++)
   memcpy(o + ((uintptr_t) (f->fy + y) * f->w + f->fx) * 4, fr + (uintptr_t) y * f->fw * 4, (size_t) f->fw * 4);
 return *out = o, 0; }

love_noinline static struct g *host_webpd(struct g *g) {
 struct wp_mem m;
 struct wp_info f;
 uint8_t *o = NULL;
 if (!strp(g->sp[0])) return g->sp[0] = putcharm(1), g;
 m.n = 0;
 int why = wp_decode(&m, (const uint8_t*) txt(g->sp[0]), len(g->sp[0]), &f, &o);
 if (why) return wp_free(&m), g->sp[0] = putcharm(why), g;
 uintptr_t k = (uintptr_t) f.w * f.h * 4;
 if (!ok(g = str0(g, k))) return wp_free(&m), g;          // pushes: the rgba over s
 memcpy(txt(g->sp[0]), o, k), wp_free(&m);
 g->sp[1] = g->sp[0], g->sp += 1;
 return g; }
static lvm(lvm_webpd) LvmCall(g, host_webpd)

static union u const
  nif_webpd[] = {{lvm_cur}, {.x = putcharm(1)}, {lvm_webpd}, {lvm_ret0}};
LvNif("webp-pixels", nif_webpd, NULL);
