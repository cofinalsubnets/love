/* a loop holding a statement expression takes no split: its locals and reads sit outside the
 * ticks a split is laid by, so a split c met obstack_1grow's __o in c's own register. m4 1.4's
 * format, reduced from its preprocessed source (the shape is what triggers it: keep it as found) */
typedef unsigned long size_t;
int sprintf(char*, char const*, ...);
void abort(void);
size_t strlen(char const*);
int strcmp(char const*, char const*);
int isdigit(int);
struct _obstack_chunk
{
};
struct obstack
{
char *object_base;
char *next_free;
char *chunk_limit;
unsigned alloc_failed:1;
};
void *memcpy(void*, void const*, size_t);
int atoi(char const*);
double atof(char const*);
typedef struct token_data token_data;
enum token_data_type
{
TOKEN_TEXT,
};
struct token_data
{
enum token_data_type type;
union
{
struct
{
char *text;
}
u_t;
}
u;
};
struct symbol
{
};
void _obstack_newchunk (struct obstack *h, int length);
void
format (struct obstack *obs, int argc, token_data **argv)
{
char *fmt;
const char *fstart;
int c;
int width = -1;
int prec = -1;
char lflag = 0;
char hflag = 0;
char str[256];
enum {INT, UINT, LONG, ULONG, DOUBLE, STR} datatype = UINT;
fmt = ((argc== 0) ? "" : (--argc, argv++, ((argv[-1])->u.u_t.text)));
for (;;)
{
while ((c = *fmt++) != '%')
{
if (c == 0)
return;
__extension__ ({ struct obstack *__o = (obs); if (__o->next_free + 1 > __o->chunk_limit) _obstack_newchunk (__o, 1); if (!__o->alloc_failed) *(__o->next_free)++ = (c); (void) 0; });
}
fstart = fmt - 1;
if (*fmt == '%')
{
continue;
{
}
}
if (*fmt == '*')
{
width = ((argc== 0) ? 0 : (--argc, argv++, atoi (((argv[-1])->u.u_t.text))));
}
{
do
{
fmt++;
}
while (isdigit (*fmt));
}
{
{
{
}
}
}
if (lflag || hflag)
fmt++;
switch (*fmt++)
{
case 'd':
{
datatype = UINT;
}
break;
case 'f':
datatype = DOUBLE;
}
c = *fmt;
*fmt = '\0';
switch(datatype)
{
case UINT:
sprintf (str, fstart, ((argc== 0) ? 0 : (--argc, argv++, (unsigned int) atoi (((argv[-1])->u.u_t.text)))));
break;
case DOUBLE:
if (width != -1 && prec != -1)
sprintf (str, fstart, width, prec, ((argc== 0) ? 0 : (--argc, argv++, atof (((argv[-1])->u.u_t.text)))));
else if (width != -1)
sprintf (str, fstart, width, ((argc== 0) ? 0 : (--argc, argv++, atof (((argv[-1])->u.u_t.text)))));
else if (prec != -1)
sprintf (str, fstart, prec, ((argc== 0) ? 0 : (--argc, argv++, atof (((argv[-1])->u.u_t.text)))));
else
sprintf (str, fstart, ((argc== 0) ? 0 : (--argc, argv++, atof (((argv[-1])->u.u_t.text)))));
break;
sprintf (str, fstart, width, ((argc== 0) ? "" : (--argc, argv++, ((argv[-1])->u.u_t.text))));
}
*fmt = c;
__extension__ ({ struct obstack *__o = (obs); int __len = (strlen (str)); if (__o->next_free + __len > __o->chunk_limit) _obstack_newchunk (__o, __len); if (!__o->alloc_failed) { memcpy ((__o->next_free), ((char *) (str)), (__len)); __o->next_free += __len; } (void) 0; });
}
}
static char fh_buf[4096];
void _obstack_newchunk (struct obstack *h, int length) { abort (); }
int main (void) {
  static struct obstack ob;
  static token_data td[4];
  static token_data *av[4];
  static char tx[4][32] = { "%05d %.2f %e", "7", "3.14159", "12345.678" };
  for (int i = 0; i < 4; i++) { td[i].type = TOKEN_TEXT; td[i].u.u_t.text = tx[i]; av[i] = &td[i]; }
  ob.object_base = ob.next_free = fh_buf; ob.chunk_limit = fh_buf + sizeof fh_buf;
  format (&ob, 4, av);
  return strcmp (fh_buf, "00007 3.14 1.234568e+04") == 0; }
