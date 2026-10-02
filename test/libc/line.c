/* getline and getdelim over a pipe: records with and without their delimiter, an
 * empty record, a record past the first growth, and the -1 at eof. the capacity is
 * the libc's own choice, so only that it holds the record is reported. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "say.h"

int main(void) {
 int fd[2];
 if (pipe(fd)) return 1;
 static char big[300];
 memset(big, 'q', sizeof big - 1);
 char const *text = "one\n\nthree:four:";
 if (write(fd[1], text, strlen(text)) < 0 || write(fd[1], big, strlen(big)) < 0 ||
     write(fd[1], "\ntail", 5) < 0) return 1;
 close(fd[1]);
 FILE *f = fdopen(fd[0], "r");
 if (!f) return 1;

 char *b = 0;
 size_t cap = 0;
 long n;
 n = getline(&b, &cap, f); say_n("getline.n", n); say_s("getline", b); say_n("getline.fits", cap > (size_t) n);
 n = getline(&b, &cap, f); say_n("getline.empty.n", n); say_s("getline.empty", b);
 n = getdelim(&b, &cap, ':', f); say_n("getdelim.n", n); say_s("getdelim", b);
 n = getdelim(&b, &cap, ':', f); say_n("getdelim.again.n", n); say_s("getdelim.again", b);
 n = getline(&b, &cap, f); say_n("getline.big.n", n); say_n("getline.big.fits", cap > (size_t) n);
 n = getline(&b, &cap, f); say_n("getline.nodelim.n", n); say_s("getline.nodelim", b);
 n = getline(&b, &cap, f); say_n("getline.eof", n);
 free(b);
 fclose(f);
 return 0;
}
