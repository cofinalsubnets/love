// ucd.h -- the unicode floor's doors (ucd.c): one copy of the classes, case maps, column widths
// and emoji runs, read by love's 'text, quay and this libc
#ifndef UCD_H
#define UCD_H
#include <stdint.h>
enum { ucd_alpha, ucd_upper, ucd_lower, ucd_print, ucd_space, ucd_blank, ucd_cntrl, ucd_vs, ucd_xp };
int __ucd_in(int t, uint32_t c);          // is c in table t, one of the enum's
int __ucd_width(uint32_t c);              // c's columns: 0 1 or 2, -1 for a control, 0 for NUL
uint32_t __ucd_map(int up, uint32_t c);   // c's simple upper (up) or lower case, c where none
uint32_t __ucd_moved(uint32_t c);         // the first character from c on a case map moves
#endif
