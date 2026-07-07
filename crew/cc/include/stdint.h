#ifndef _AI_STDINT_H
#define _AI_STDINT_H
/* freestanding stdint for cc (rung 3, stage 7c). cc has no unsigned yet, so the
 * uintN_t names ride SIGNED bases of the right width -- correct FOR THIS cc,
 * which treats every integer as signed; 7c-ii swaps in real `unsigned`. */
typedef char          int8_t;
typedef short         int16_t;
typedef int           int32_t;
typedef long          int64_t;
typedef char          uint8_t;
typedef short         uint16_t;
typedef int           uint32_t;
typedef long          uint64_t;
typedef long          intptr_t;
typedef long          uintptr_t;
typedef long          intmax_t;
typedef long          uintmax_t;
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
