#ifndef _LOVE_STDINT_H
#define _LOVE_STDINT_H
typedef signed char        int8_t;
typedef short              int16_t;
typedef int                int32_t;
typedef unsigned char      uint8_t;
typedef unsigned short     uint16_t;
typedef unsigned int       uint32_t;
#define INT8_MAX    127
#define INT16_MAX   32767
#define INT32_MAX   2147483647
#define INT8_MIN    (-128)
#define INT16_MIN   (-32768)
#define INT32_MIN   (-2147483647 - 1)
#define UINT8_MAX   255
#define UINT16_MAX  65535
#define UINT32_MAX  4294967295U
#if defined(__arm__) || defined(__i386__)
/* the 32-bit targets: long is 4 bytes, long long the 8-byte pair */
typedef long long          int64_t;
typedef unsigned long long uint64_t;
typedef long               intptr_t;
typedef unsigned long      uintptr_t;
typedef long long          intmax_t;
typedef unsigned long long uintmax_t;
#define INT64_MAX   9223372036854775807
#define INT64_MIN   (-9223372036854775807 - 1)
#define UINT64_MAX  18446744073709551615ULL
#define INTPTR_MAX  2147483647
#define INTPTR_MIN  (-2147483647 - 1)
#define UINTPTR_MAX 4294967295U
#define SIZE_MAX    4294967295U
#else
typedef long               int64_t;
typedef unsigned long      uint64_t;
typedef long               intptr_t;
typedef unsigned long      uintptr_t;
typedef long               intmax_t;
typedef unsigned long      uintmax_t;
#define INT64_MAX   9223372036854775807
#define INT64_MIN   (-9223372036854775807 - 1)
#define UINT64_MAX  18446744073709551615ULL
#define INTPTR_MAX  9223372036854775807
#define INTPTR_MIN  (-9223372036854775807 - 1)
#define UINTPTR_MAX 18446744073709551615UL
#define SIZE_MAX    18446744073709551615UL
#endif

/* glibc's widths, which are abi: least is exact, fast8 a char, fast16/32 the machine word */
typedef int8_t   int_least8_t;   typedef uint8_t   uint_least8_t;
typedef int16_t  int_least16_t;  typedef uint16_t  uint_least16_t;
typedef int32_t  int_least32_t;  typedef uint32_t  uint_least32_t;
typedef int64_t  int_least64_t;  typedef uint64_t  uint_least64_t;
typedef signed char int_fast8_t; typedef unsigned char uint_fast8_t;
#if defined(__arm__) || defined(__i386__)
typedef int      int_fast16_t;   typedef unsigned int  uint_fast16_t;
typedef int      int_fast32_t;   typedef unsigned int  uint_fast32_t;
#else
typedef long     int_fast16_t;   typedef unsigned long uint_fast16_t;
typedef long     int_fast32_t;   typedef unsigned long uint_fast32_t;
#endif
typedef int64_t  int_fast64_t;   typedef uint64_t  uint_fast64_t;
#define INT_LEAST8_MAX   INT8_MAX
#define INT_LEAST16_MAX  INT16_MAX
#define INT_LEAST32_MAX  INT32_MAX
#define INT_LEAST64_MAX  INT64_MAX
#define INT_LEAST8_MIN   INT8_MIN
#define INT_LEAST16_MIN  INT16_MIN
#define INT_LEAST32_MIN  INT32_MIN
#define INT_LEAST64_MIN  INT64_MIN
#define UINT_LEAST8_MAX  UINT8_MAX
#define UINT_LEAST16_MAX UINT16_MAX
#define UINT_LEAST32_MAX UINT32_MAX
#define UINT_LEAST64_MAX UINT64_MAX
#define INT_FAST8_MAX    INT8_MAX
#define INT_FAST8_MIN    INT8_MIN
#define UINT_FAST8_MAX   UINT8_MAX
#if defined(__arm__) || defined(__i386__)
#define INT_FAST16_MAX   INT32_MAX
#define INT_FAST16_MIN   INT32_MIN
#define UINT_FAST16_MAX  UINT32_MAX
#define INT_FAST32_MAX   INT32_MAX
#define INT_FAST32_MIN   INT32_MIN
#define UINT_FAST32_MAX  UINT32_MAX
#else
#define INT_FAST16_MAX   INT64_MAX
#define INT_FAST16_MIN   INT64_MIN
#define UINT_FAST16_MAX  UINT64_MAX
#define INT_FAST32_MAX   INT64_MAX
#define INT_FAST32_MIN   INT64_MIN
#define UINT_FAST32_MAX  UINT64_MAX
#endif
#define INT_FAST64_MAX   INT64_MAX
#define INT_FAST64_MIN   INT64_MIN
#define UINT_FAST64_MAX  UINT64_MAX
#define INTMAX_MAX       INT64_MAX
#define INTMAX_MIN       INT64_MIN
#define UINTMAX_MAX      UINT64_MAX
#define PTRDIFF_MAX      INTPTR_MAX
#define PTRDIFF_MIN      INTPTR_MIN
#define INT8_C(c)   c
#define INT16_C(c)  c
#define INT32_C(c)  c
#define UINT8_C(c)  c
#define UINT16_C(c) c
#define UINT32_C(c) c ## U
#if defined(__arm__) || defined(__i386__)
#define INT64_C(c)  c ## LL
#define UINT64_C(c) c ## ULL
#else
#define INT64_C(c)  c ## L
#define UINT64_C(c) c ## UL
#endif
#define INTMAX_C(c)  INT64_C(c)
#define UINTMAX_C(c) UINT64_C(c)
#endif
