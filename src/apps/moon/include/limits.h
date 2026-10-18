#ifndef _LOVE_LIMITS_H
#define _LOVE_LIMITS_H
/* PATH_MAX and NAME_MAX live here too, as on linux */
#define CHAR_BIT   8
#define MB_LEN_MAX 16
#define SCHAR_MIN  (-128)
#define SCHAR_MAX  127
#define UCHAR_MAX  255
#ifdef __CHAR_UNSIGNED__  /* plain char's sign is the abi's */
#define CHAR_MIN   0
#define CHAR_MAX   UCHAR_MAX
#else
#define CHAR_MIN   (-128)
#define CHAR_MAX   127
#endif
#define SHRT_MIN   (-32768)
#define SHRT_MAX   32767
#define USHRT_MAX  65535
#define INT_MIN    (-2147483647 - 1)
#define INT_MAX    2147483647
#define UINT_MAX   4294967295U
#if defined(__arm__) || defined(__i386__)
/* the 32-bit targets: long is 4 bytes, long long the 8-byte pair */
#define LONG_MIN   (-2147483647L - 1)
#define LONG_MAX   2147483647L
#define ULONG_MAX  4294967295UL
#define LLONG_MIN  (-9223372036854775807LL - 1)
#define LLONG_MAX  9223372036854775807LL
#define ULLONG_MAX 18446744073709551615ULL
#else
#define LONG_MIN   (-9223372036854775807L - 1)
#define LONG_MAX   9223372036854775807L
#define ULONG_MAX  18446744073709551615UL
#define LLONG_MIN  (-9223372036854775807LL - 1)
#define LLONG_MAX  9223372036854775807LL
#define ULLONG_MAX 18446744073709551615ULL
#endif
#define PATH_MAX   4096
#define NAME_MAX   255
/* posix's guaranteed minima */
#define _POSIX_ARG_MAX     4096
#define _POSIX_OPEN_MAX    20
#define _POSIX_NAME_MAX    14
#define _POSIX_PATH_MAX    256
#define _POSIX_LINK_MAX    8
#define _POSIX_PIPE_BUF    512
#define _POSIX_CHILD_MAX   25
#define _POSIX_SSIZE_MAX   32767
#define _POSIX_STREAM_MAX  8
#define _POSIX_TZNAME_MAX  6
#define ARG_MAX            2097152
#define OPEN_MAX           1024
#define LINK_MAX           127
#define PIPE_BUF           4096
#endif
