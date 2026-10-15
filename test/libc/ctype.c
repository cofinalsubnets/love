/* the ctype thirteen over the whole domain: each predicate prints 256 '0'/'1', so a
 * drift names the function and the byte. the c locale: 0..127 agree by construction,
 * 128..255 catches a signed-char index or a leaking high half. tolower/toupper print
 * values: every non-letter passes through unchanged. */
#include <ctype.h>
#include "say.h"

static void mask(char const *nm, int (*f)(int)) {
 char row[257];
 for (int c = 0; c < 256; c++) row[c] = f(c) ? '1' : '0';
 row[256] = 0;
 say_s(nm, row); }

static void mapping(char const *nm, int (*f)(int)) {
 /* the fixed points collapse to a single mark; only the moved bytes are
    spelled out, so a drift reads as a short diff rather than 256 numbers */
 for (int c = 0, r; c < 256; c++)
  if ((r = f(c)) != c) say_n(nm, c), say_n(nm, r); }

int main(void) {
 mask("isupper", isupper);
 mask("islower", islower);
 mask("isalpha", isalpha);
 mask("isdigit", isdigit);
 mask("isalnum", isalnum);
 mask("isxdigit", isxdigit);
 mask("isspace", isspace);
 mask("isprint", isprint);
 mask("iscntrl", iscntrl);
 mask("ispunct", ispunct);
 mask("isgraph", isgraph);

 mapping("tolower", tolower);
 mapping("toupper", toupper);

 /* the partition laws: every byte is one of print/cntrl or neither (128..255 is neither),
    and graph = print minus space. answers go through !! first: a predicate's true is
    implementation-defined (glibc answers its mask bit). */
 int bad = 0;
 for (int c = 0; c < 256; c++) {
  if (isprint(c) && iscntrl(c)) bad++;
  if (isgraph(c) && !isprint(c)) bad++;
  if (!!isalnum(c) != (!!isalpha(c) || !!isdigit(c))) bad++;
  if (!!isalpha(c) != (!!isupper(c) || !!islower(c))) bad++;
  if (ispunct(c) && isalnum(c)) bad++; }
 say_n("partitions.violations", bad); 

 return 0; }
