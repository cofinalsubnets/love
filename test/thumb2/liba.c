/* __attribute__((aligned(N))) at 32 bits, mooncc side. the pad INSIDE the section
   is only half the promise: sh_addralign owes the linker the same N, or the whole
   run lands wherever the section did and every inner pad aligns nothing. these are
   ours; the harness reads the addresses back after the link, which is the only
   place the section header is observable. */
char a_crumb1 = 1;
static char a_pad = 2;
unsigned a_page[8] __attribute__((aligned(1024)));        /* the nobits lane */
char a_crumb2 = 3;
int a_mid __attribute__((aligned(64))) = 7;               /* a scalar between neighbours */
char a_pub[5] __attribute__((aligned(256))) = {9, 8};     /* initialized + exported */
const int a_ro __attribute__((aligned(128))) = 11;        /* .rodata asks too */

unsigned long a_apage(void){ return (unsigned long) a_page; }
unsigned long a_amid(void){ return (unsigned long) &a_mid; }
unsigned long a_apub(void){ return (unsigned long) a_pub; }
unsigned long a_aro(void){ return (unsigned long) &a_ro; }
int a_vals(void){ return a_crumb1 + a_pad + a_crumb2 + a_mid + a_pub[0] + a_pub[1] + a_ro; }
int a_page_rw(void){ a_page[0] = 30; a_page[7] = 12; return (int) (a_page[0] + a_page[7]); }
