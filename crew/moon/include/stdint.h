#ifndef _AI_STDINT_H
#define _AI_STDINT_H
/* freestanding stdint for cc (rung 3, stage 7c-ii). the unsigned types are real
 * now -- cc has `unsigned` (zero-extend loads, logical >>, unsigned cmp/div). */
typedef signed char        int8_t;
typedef short              int16_t;
typedef int                int32_t;
typedef long               int64_t;
typedef unsigned char      uint8_t;
typedef unsigned short     uint16_t;
typedef unsigned int       uint32_t;
typedef unsigned long      uint64_t;
typedef long               intptr_t;
typedef unsigned long      uintptr_t;
typedef long               intmax_t;
typedef unsigned long      uintmax_t;
#define INT8_MAX    127
#define INT16_MAX   32767
#define INT32_MAX   2147483647
#define INT64_MAX   9223372036854775807
#define INT8_MIN    (-128)
#define INT16_MIN   (-32768)
#define INT32_MIN   (-2147483648)
#define INT64_MIN   (-9223372036854775807 - 1)
#define UINT8_MAX   255
#define UINT16_MAX  65535
#define UINT32_MAX  4294967295
#define UINT64_MAX  18446744073709551615
#define INTPTR_MAX  9223372036854775807
#define INTPTR_MIN  (-9223372036854775807 - 1)
#define UINTPTR_MAX 18446744073709551615
#define SIZE_MAX    18446744073709551615
#endif
