/* the small headers kernel host programs reach for: endian.h's conversions, byteswap.h, the
 * whole PRI family through printf, sysexits, O_LARGEFILE, and err.h's four voices -- read back
 * from stderr with the program's name cut off, since the two builds are named apart */
#define _GNU_SOURCE
#include <endian.h>
#include <byteswap.h>
#include <inttypes.h>
#include <sysexits.h>
#include <fcntl.h>
#include <err.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include "say.h"

#define P(m, v) do { char b[64]; snprintf(b, sizeof b, "%" m, v); say_s(#m, b); } while (0)

int main(void) {
  say_n("bswap_16", bswap_16(0x1234)); say_n("bswap_32", (long) bswap_32(0x12345678u));
  say_n("bswap_64.hi", (long) (bswap_64(0x0102030405060708ull) >> 32));
  say_n("htobe32", (long) htobe32(0xa1b2c3d4u)); say_n("be16toh", be16toh(0x0102));
  say_n("le32toh", (long) le32toh(0xa1b2c3d4u)); say_n("htole64", (long) htole64(7));
  say_n("BYTE_ORDER", BYTE_ORDER == LITTLE_ENDIAN); say_n("__BYTE_ORDER", __BYTE_ORDER);
  P(PRId8, (int8_t) -5); P(PRIx8, (uint8_t) 0xab); P(PRIu16, (uint16_t) 65535); P(PRIX16, (uint16_t) 0xbeef);
  P(PRIi32, (int32_t) -7); P(PRIo32, (uint32_t) 8); P(PRIx32, (uint32_t) 0xdeadbeef); P(PRId64, (int64_t) -1 << 40);
  P(PRIu64, UINT64_MAX); P(PRIx64, (uint64_t) 0xfeedfacecafebeefull); P(PRIX64, (uint64_t) 0xabcdef);
  P(PRIdLEAST8, (int_least8_t) 3); P(PRIuLEAST32, (uint_least32_t) 9); P(PRIxLEAST64, (uint_least64_t) 255);
  P(PRIdFAST16, (int_fast16_t) -2); P(PRIuFAST32, (uint_fast32_t) 77); P(PRIxFAST64, (uint_fast64_t) 4096);
  P(PRIdMAX, INTMAX_MIN); P(PRIuMAX, UINTMAX_MAX); P(PRIxPTR, (uintptr_t) 0x1000); P(PRIdPTR, (intptr_t) -1);
  say_n("EX_OK", EX_OK); say_n("EX_USAGE", EX_USAGE); say_n("EX_DATAERR", EX_DATAERR); say_n("EX_NOINPUT", EX_NOINPUT);
  say_n("EX_SOFTWARE", EX_SOFTWARE); say_n("EX_IOERR", EX_IOERR); say_n("EX_CONFIG", EX_CONFIG); say_n("EX__MAX", EX__MAX);
  say_n("O_LARGEFILE", O_LARGEFILE);
  /* err.h: stderr to a file, the four voices, then each line past its "name: " */
  fflush(stderr);
  FILE *t = tmpfile(); int keep = dup(2); dup2(fileno(t), 2);
  warnx("plain %d", 1);
  errno = ENOENT; warn("with %s", "errno");
  errno = EACCES; warn(NULL);
  warnx(NULL);
  fflush(stderr); dup2(keep, 2); close(keep);
  rewind(t); char line[128];
  while (fgets(line, sizeof line, t)) {
    char *c = strchr(line, ':'); line[strlen(line) - 1] = 0;
    say_s("warn", c ? c + 1 : line); }
  return 0; }
