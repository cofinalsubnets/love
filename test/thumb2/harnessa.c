/* the gcc side: every aligned(N) global our object declared lands on N after the
   link, and its bytes survive the pad. addresses come back through calls so
   nothing here is folded. */
unsigned long a_apage(void); unsigned long a_amid(void);
unsigned long a_apub(void); unsigned long a_aro(void);
int a_vals(void); int a_page_rw(void);
int run(void){
 int ok = 0;
#define CK(x) do{ ok++; if(!(x)) return 100+ok; }while(0)
 CK((a_apage() & 1023) == 0);
 CK((a_amid()  &   63) == 0);
 CK((a_apub()  &  255) == 0);
 CK((a_aro()   &  127) == 0);
 CK(a_vals() == 1 + 2 + 3 + 7 + 9 + 8 + 11);
 CK(a_page_rw() == 42);
 return 6;
}
