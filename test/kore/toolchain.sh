#!/bin/sh
# test/kore/toolchain.sh -- as, ar, ld, objcopy, nm, size, strip, ranlib, x86-64 only
. "$(dirname "$0")/common.sh"

if [ "$(uname -m)" = x86_64 ]; then
  printf '(li r0 60) (li r6 7) (sys)\n' > "$ho/.kore-as.l"
  korerun as x64 "$ho/.kore-as.l" "$ho/.kore-as.elf" > /dev/null 2>&1 || fail "kore as"
  chmod +x "$ho/.kore-as.elf"; "$ho/.kore-as.elf"; r=$?
  [ $r -eq 7 ] || fail "kore as run (exit $r)"
fi
# ar: binutils' deterministic archives to the byte, and `ar t` alike. ld: crt0+main+f bound
# byte-identical to mooncc's own link, and the exe answers 35 + 7 = 42
if [ "$(uname -m)" = x86_64 ]; then
  printf 'int f(void){return 35;}\n' > "$ho/.kore-arf.c"
  printf 'int f(void);\nint main(void){return f()+7;}\n' > "$ho/.kore-arm.c"
  moonc -c "$ho/.kore-arf.c" "$ho/.kore-arf.o" >/dev/null 2>&1 || fail "kore ar: mooncc -c f.c"
  moonc -c "$ho/.kore-arm.c" "$ho/.kore-arm.o" >/dev/null 2>&1 || fail "kore ar: mooncc -c main.c"
  if command -v ar >/dev/null 2>&1; then
    rm -f "$ho/.kore-gnu.a" "$ho/.kore-our.a"
    ar rcsD "$ho/.kore-gnu.a" "$ho/.kore-arf.o" "$ho/.kore-arm.o"
    korerun ar rcs "$ho/.kore-our.a" "$ho/.kore-arf.o" "$ho/.kore-arm.o" || fail "kore ar rcs"
    cmp -s "$ho/.kore-gnu.a" "$ho/.kore-our.a" || fail "kore ar vs GNU (archive bytes)"
    ar t "$ho/.kore-gnu.a" > "$g"; korerun ar t "$ho/.kore-our.a" > "$o"; same "ar t"
    # a name past 15 bytes goes to "//", padded inside its size
    cp "$ho/.kore-arf.o" "$ho/.kore-long-name-f.o"
    rm -f "$ho/.kore-gnul.a" "$ho/.kore-ourl.a"
    ar rcsD "$ho/.kore-gnul.a" "$ho/.kore-long-name-f.o"
    korerun ar rcs "$ho/.kore-ourl.a" "$ho/.kore-long-name-f.o" || fail "kore ar rcs (long name)"
    cmp -s "$ho/.kore-gnul.a" "$ho/.kore-ourl.a" || fail "kore ar vs GNU (long name)"
  fi
  # thin archives as kbuild asks llvm-ar for them, to the byte: built-in.a nested and
  # flattened, a lib.a indexed, vmlinux.a's head object moved first, an empty one
  if command -v llvm-ar >/dev/null 2>&1; then
    ma=$(cd "$(dirname "$m")" && pwd)/$(basename "$m")
    for w in llvm kore; do
      d="$ho/.kore-thin-$w"; rm -rf "$d"; mkdir -p "$d/sub/deep"
      cp "$ho/.kore-arf.o" "$d/sub/deep/f.o"; cp "$ho/.kore-arm.o" "$d/sub/m.o"; cp "$ho/.kore-arm.o" "$d/z.o"
      if [ $w = llvm ]; then A="llvm-ar"; else A="env LOVE_NO_IMAGE= $ma ar"; fi
      ( cd "$d" && $A cDPrST sub/deep/built-in.a sub/deep/f.o && $A cDPrST sub/built-in.a sub/deep/built-in.a sub/m.o \
        && $A cDPrST built-in.a sub/built-in.a && $A cDPrST empty.a && $A cDPrsT lib.a z.o sub/deep/f.o \
        && $A cDPrST vmlinux.a built-in.a lib.a && $A mPiT sub/deep/f.o vmlinux.a sub/m.o ) || fail "kore ar thin ($w)"
    done
    for a in sub/deep/built-in.a sub/built-in.a built-in.a empty.a lib.a vmlinux.a; do
      cmp -s "$ho/.kore-thin-llvm/$a" "$ho/.kore-thin-kore/$a" || fail "kore ar thin vs llvm-ar ($a)"
    done
    ( cd "$ho/.kore-thin-kore" && LOVE_NO_IMAGE= "$ma" ar t vmlinux.a ) > "$o"
    ( cd "$ho/.kore-thin-llvm" && llvm-ar t vmlinux.a ) > "$g"; same "ar t (thin)"
  fi
  "$m" -l "$ho/.mooncc-cat.l" -e '(: _ (borrow (name "holo")) _ (borrow (name "moon")) (write-bytes "'"$ho"'/.kore-crt0.o" (objelf (intern "x64") crt0 () (quote ("__love_start")) () (quote ("__love_start")) () () () () ())))' >/dev/null 2>&1
  [ -s "$ho/.kore-crt0.o" ] || fail "kore ld: crt0 lay"
  moonc "$ho/.kore-arm.o" "$ho/.kore-arf.o" -o "$ho/.kore-mc.elf" >/dev/null 2>&1 || fail "kore ld: mooncc link"
  korerun ld "$ho/.kore-crt0.o" "$ho/.kore-arm.o" "$ho/.kore-arf.o" -o "$ho/.kore-ld.elf" || fail "kore ld"
  # byte-identical, .comment included: both doors drive the one linker
  cmp -s "$ho/.kore-mc.elf" "$ho/.kore-ld.elf" || fail "kore ld vs mooncc link (bytes)"
  "$ho/.kore-ld.elf"; r=$?
  [ $r -eq 42 ] || fail "kore ld run (exit $r)"
  # -r: two objects as one, as ld.lld -r lays them; linked on, it runs the same
  korerun ld -r "$ho/.kore-arm.o" "$ho/.kore-arf.o" -o "$ho/.kore-r.o" || fail "kore ld -r"
  if command -v ld.lld > /dev/null 2>&1; then
    ld.lld -r "$ho/.kore-arm.o" "$ho/.kore-arf.o" -o "$ho/.kore-lr.o"
    cmp -s "$ho/.kore-lr.o" "$ho/.kore-r.o" || fail "kore ld -r vs ld.lld -r (bytes)"
  fi
  korerun ld "$ho/.kore-crt0.o" "$ho/.kore-r.o" -o "$ho/.kore-ldr.elf" || fail "kore ld of an ld -r object"
  "$ho/.kore-ldr.elf"; r=$?
  [ $r -eq 42 ] || fail "kore ld -r run (exit $r)"
  # lld's dialect as kbuild probes it: --version names LLD for ld-version.sh, and a flag
  # the linker does not carry out fails its ld-option probe
  korerun ld --version > "$o" 2>&1; grep -q " LLD [0-9.]*-compatible$" "$o" || fail "kore ld --version: $(cat "$o")"
  korerun ld -EL -maarch64elf -z norelro --pack-dyn-relocs=relr -v > /dev/null 2>&1 || fail "kore ld: a carried flag refused"
  korerun ld -EL -maarch64elf --no-warn-rwx-segments -v > /dev/null 2>&1 && fail "kore ld: an unsupported flag passed"
  # the archive as a link input binds the same exe byte for byte: members come in by need
  # through the ranlib index, past one nothing calls
  printf 'int unused(void){return 99;}\n' > "$ho/.kore-arz.c"
  moonc -c "$ho/.kore-arz.c" "$ho/.kore-arz.o" >/dev/null 2>&1 || fail "kore ar: mooncc -c unused.c"
  rm -f "$ho/.kore-arl.a"
  korerun ar rcs "$ho/.kore-arl.a" "$ho/.kore-arf.o" "$ho/.kore-arz.o" || fail "kore ar rcs (library)"
  moonc "$ho/.kore-arm.o" "$ho/.kore-arl.a" -o "$ho/.kore-ara.elf" >/dev/null 2>&1 || fail "kore ld: archive input"
  cmp -s "$ho/.kore-mc.elf" "$ho/.kore-ara.elf" || fail "kore ld archive vs .o link (bytes -- an unneeded member rode in?)"
  "$ho/.kore-ara.elf"; r=$?
  [ $r -eq 42 ] || fail "kore ld archive run (exit $r)"
  # objcopy: the dispatch and its arguments; byte equality is test_objcopy's
  korerun objcopy -O binary "$ho/.kore-ld.elf" "$ho/.kore-oc.bin" || fail "kore objcopy -O binary"
  korerun objcopy -O ihex "$ho/.kore-ld.elf" "$ho/.kore-oc.hex" || fail "kore objcopy -O ihex"
  [ -s "$ho/.kore-oc.bin" ] && [ -s "$ho/.kore-oc.hex" ] || fail "kore objcopy wrote nothing"
  grep -q '^:00000001' "$ho/.kore-oc.hex" || fail "kore objcopy: no ihex end record"
  korerun objcopy -O srec "$ho/.kore-ld.elf" "$ho/.kore-oc.x" 2>/dev/null \
    && fail "kore objcopy took an unknown format"
  # nm against LC_ALL=C nm (byte order, not a locale's). the exe is listed on purpose: it
  # goes through ld-syms, not ld-read, which is ET_REL only
  if command -v nm >/dev/null 2>&1; then
    for f in .kore-arm.o .kore-arf.o .kore-ld.elf; do
      LC_ALL=C nm "$ho/$f" > "$g" 2>/dev/null
      korerun nm "$ho/$f" > "$o" || fail "kore nm $f"
      same "nm $f"
    done
  fi
  korerun nm -u "$ho/.kore-arm.o" > "$o" || fail "kore nm -u"
  [ "$(cat "$o")" = "                 U f" ] || fail "kore nm -u (want the one undefined nom)"
  korerun nm -g "$ho/.kore-arf.o" > "$o" || fail "kore nm -g"
  grep -q ' T f$' "$o" || fail "kore nm -g (want T f)"
  korerun nm "$ho/.kore-arf.o" "$ho/.kore-arm.o" > "$o" || fail "kore nm (two files)"
  grep -q '\.kore-arm\.o:$' "$o" || fail "kore nm: no per-file header past one file"
  korerun nm "$ho/.kore-arf.c" >/dev/null 2>&1 && fail "kore nm read a non-ELF"
  # size: berkeley sums over objects, an exe and an archive, and status 3 for a non-object.
  # strip: the exe still runs, without its symtab, keeping binutils' sections. ranlib: an
  # index-less archive (ar S) gains the index mooncc's link reads
  if command -v size >/dev/null 2>&1; then
    size "$ho/.kore-arm.o" "$ho/.kore-ld.elf" "$ho/.kore-our.a" > "$g" 2>&1
    korerun size "$ho/.kore-arm.o" "$ho/.kore-ld.elf" "$ho/.kore-our.a" > "$o" 2>&1; same "size"
    size -t "$ho/.kore-arm.o" "$ho/.kore-arf.o" > "$g"; korerun size -t "$ho/.kore-arm.o" "$ho/.kore-arf.o" > "$o"; same "size -t"
  fi
  korerun size "$ho/.kore-arf.c" 2>/dev/null; r=$?; [ $r -eq 3 ] || fail "kore size of a non-object is 3 (got $r)"
  cp "$ho/.kore-ld.elf" "$ho/.kore-st.elf"
  korerun strip "$ho/.kore-st.elf" || fail "kore strip"
  "$ho/.kore-st.elf"; r=$?; [ $r -eq 42 ] || fail "kore strip: the stripped exe runs (exit $r)"
  korerun nm "$ho/.kore-st.elf" 2>&1 | grep -q 'no symbols' || fail "kore strip: no symbol table left"
  if command -v strip >/dev/null 2>&1 && command -v readelf >/dev/null 2>&1; then
    cp "$ho/.kore-ld.elf" "$ho/.kore-gst.elf"; strip "$ho/.kore-gst.elf"
    readelf -SW "$ho/.kore-gst.elf" | sed -n 's/^ *\[ *[0-9]*\] *\([^ ]*\).*/\1/p' | LC_ALL=C sort > "$g"
    readelf -SW "$ho/.kore-st.elf" | sed -n 's/^ *\[ *[0-9]*\] *\([^ ]*\).*/\1/p' | LC_ALL=C sort > "$o"; same "strip (the sections kept)"
  fi
  if command -v ar >/dev/null 2>&1; then
    rm -f "$ho/.kore-rl.a"; ar rcS "$ho/.kore-rl.a" "$ho/.kore-arf.o"
    korerun ranlib "$ho/.kore-rl.a" || fail "kore ranlib"
    moonc "$ho/.kore-arm.o" "$ho/.kore-rl.a" -o "$ho/.kore-rl.elf" >/dev/null 2>&1 || fail "kore ranlib: mooncc links through the index"
    "$ho/.kore-rl.elf"; r=$?; [ $r -eq 42 ] || fail "kore ranlib: the linked exe (exit $r)"
  fi
fi
# readelf: binutils' headers, sections, segments and symbols, 80 columns and wide, over every
# target mooncc lays
if command -v readelf >/dev/null 2>&1; then
  printf 'int x = 3;\nstatic int y;\nint f(void) { return x + y; }\nint main(void) { return f(); }\n' > "$ho/.kore-re.c"
  fs="$m"
  for t in x64 a64 rv64 thumb2; do
    moonc -t $t -c "$ho/.kore-re.c" -o "$ho/.kore-re-$t.o" >/dev/null 2>&1 && fs="$fs $ho/.kore-re-$t.o"
    [ $t = thumb2 ] || { moonc -t $t "$ho/.kore-re.c" -o "$ho/.kore-re-$t.elf" >/dev/null 2>&1 && fs="$fs $ho/.kore-re-$t.elf"; }
  done
  for f in $fs; do
    for op in -h -S "-S -W" -l "-l -W" -s "-s -W" -e; do
      # shellcheck disable=SC2086
      LC_ALL=C readelf $op "$f" > "$g" 2>&1; korerun readelf $op "$f" > "$o" 2>&1; same "readelf $op $f"
    done
  done
  LC_ALL=C readelf -h "$ho/.kore-re-x64.o" "$ho/.kore-re-a64.o" > "$g" 2>&1
  korerun readelf -h "$ho/.kore-re-x64.o" "$ho/.kore-re-a64.o" > "$o" 2>&1; same "readelf over two files"
fi
# with no nest and no tree, mooncc takes its toolchain off the binary's own source slice:
# a stdio hello compiles, links and runs from a scratch dir
if [ "$(uname -m)" = x86_64 ]; then
  N=$ho/.kore-nonest; rm -rf "$N"; mkdir -p "$N"
  printf '#include <stdio.h>\nint main(void){printf("carried\\n");return 0;}\n' > "$N/h.c"
  ( cd "$N" && "$K" cc h.c -o h ) > "$o" 2>&1 || { cat "$o"; fail "love cc off the carried source"; }
  [ "$("$N/h")" = carried ] || fail "love cc off the carried source: the program"
fi
# lex's C back end, as kbuild asks for it: start conditions, ^, trailing context, <<EOF>>,
# yyless and input(), compiled by mooncc and run; the same as flex's scanner when there is one
L=$ho/.kore-lex; rm -rf "$L"; mkdir -p "$L"
cat > "$L/t.l" <<'SPEC'
%option noyywrap nounput yylineno
%x STR
%s V1
DIG	[0-9]
%{
#include <stdio.h>

%}
%%
<*>"#"[^\n]*		printf("<c>");
^"%v1"			{ BEGIN(V1); printf("<v1>"); }
<V1>{DIG}+		printf("<n1:%s>", yytext);
"ab"|"cd"		|
"ef"			printf("<pair:%s>", yytext);
"xyz"			{ yyless(1); printf("<x>"); }
"/*"			{ int c, p = 0; while ((c = input()) && !(p == '*' && c == '/')) p = c; printf("<cm>"); }
{DIG}+/"px"		printf("<px:%s>", yytext);
{DIG}+			printf("<n:%s>", yytext);
[[:alpha:]_][[:alnum:]_]*	printf("<id:%s>", yytext);
\"			{ BEGIN(STR); printf("<s"); }
<STR>{
  \\.			printf("%c", yytext[1]);
  \"			{ BEGIN(INITIAL); printf(">"); }
  [^\\"\n]+		printf("%s", yytext);
  \n			printf("\\n");
  <<EOF>>		{ printf("<eof-in-str>"); return 0; }
}
\n			printf("\n%d:", yylineno);
[ \t]+			;
.			printf("<%c>", yytext[0]);
<<EOF>>			{ printf("<eof>"); return 0; }
%%
int main(void) { yylex(); printf("\n"); return 0; }
SPEC
printf 'abc 12px 34 _a1 "q\\"x" ab cd ef xyz\n/* a\n*/ b #note\n%%v1 56 # c\n%%v1x 7\n  "open\nmore' > "$L/in"
korerun lex -o "$L/l.c" "$L/t.l" || fail "kore lex -o"
moonc "$L/l.c" "$L/l" > /dev/null 2>&1 || fail "kore lex: mooncc the scanner"
"$L/l" < "$L/in" > "$o"
printf '%s' '<id:abc><px:12><id:px><n:34><id:_a1><sq"x><pair:ab><pair:cd><pair:ef><x><id:yz>
2:<cm><id:b><c>
4:<v1><n1:56><c>
5:<v1><id:x><n1:7>
6:<sopen\nmore<eof-in-str>
' > "$g"; same "lex C scanner (the answer)"
if command -v flex >/dev/null 2>&1; then
  flex -o "$L/f.c" "$L/t.l" 2>/dev/null && moonc "$L/f.c" "$L/f" > /dev/null 2>&1 || fail "flex's scanner"
  "$L/f" < "$L/in" > "$g"; same "lex C scanner vs flex"
fi
# yacc's C back end, as kbuild asks for it: %union and <tag>s, %locations and @n, precedence
# and %prec, error with yyerrok, YYERROR, %destructor on what recovery and an abort let go
Y=$ho/.kore-yacc; rm -rf "$Y"; mkdir -p "$Y"
cat > "$Y/t.y" <<'SPEC'
%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int yylex(void);
void yyerror(const char *s);
%}
%locations
%union { long n; char *s; }
%token <n> NUM
%token <s> NAME
%type <n> e line
%left '+' '-'
%left '*' '/'
%right '^'
%nonassoc UMINUS
%destructor { printf("[drop %s]", $$); free($$); } <s>
%%
input :
      | input line { printf("= %ld @%d.%d-%d.%d\n", $2, @2.first_line, @2.first_column, @2.last_line, @2.last_column); }
      ;
line : e '\n' { $$ = $1; }
     | NAME '=' e '\n' { printf("%s:", $1); free($1); $$ = $3; }
     | error '\n' { yyerrok; $$ = -1; }
     ;
e : NUM
  | e '+' e { $$ = $1 + $3; }
  | e '-' e { $$ = $1 - $3; }
  | e '*' e { $$ = $1 * $3; }
  | e '/' e { if (!$3) { yyerror("div0"); YYERROR; } $$ = $1 / $3; }
  | e '^' e { long r = 1; for (long i = 0; i < $3; i++) r *= $1; $$ = r; }
  | '-' e %prec UMINUS { $$ = -$2; }
  | '(' e ')' { $$ = $2; }
  ;
%%
static int ln = 1, col = 1;
int yylex(void)
{
  int c;
  while ((c = getchar()) == ' ') col++;
  yylloc.first_line = yylloc.last_line = ln;
  yylloc.first_column = yylloc.last_column = col;
  if (c == EOF) return 0;
  if (c >= '0' && c <= '9') {
    long v = 0;
    for (; c >= '0' && c <= '9'; c = getchar()) v = 10 * v + c - '0', col++;
    ungetc(c, stdin);
    yylval.n = v, yylloc.last_column = col - 1;
    return NUM;
  }
  if (c >= 'a' && c <= 'z') {
    char b[64]; int n = 0;
    for (; c >= 'a' && c <= 'z' && n < 63; c = getchar()) b[n++] = c, col++;
    ungetc(c, stdin);
    b[n] = 0, yylval.s = strdup(b), yylloc.last_column = col - 1;
    return NAME;
  }
  if (c == '\n') ln++, col = 1; else col++;
  return c;
}
void yyerror(const char *s) { printf("err %s at %d.%d\n", s, yylloc.first_line, yylloc.first_column); }
int main(void) { int r = yyparse(); printf("rc %d nerrs %d\n", r, yynerrs); return 0; }
SPEC
printf '1+2*3\nx = 2^3^2\n-(4-1)*2\n1+*2\nfoo bar baz\n8/0\n(1\n7 - -2\n' > "$Y/in"
korerun yacc -o "$Y/l.c" --defines="$Y/l.h" -t -l "$Y/t.y" || fail "kore yacc -o"
moonc "$Y/l.c" "$Y/l" > /dev/null 2>&1 || fail "kore yacc: mooncc the parser"
{ "$Y/l" < "$Y/in"; printf foo | "$Y/l"; } > "$o"
printf '%s' '= 7 @1.1-1.6
x:= 512 @2.1-2.10
= -6 @3.1-3.9
err syntax error at 4.3
= -1 @4.1-4.5
err syntax error at 5.5
[drop foo][drop bar][drop baz]= -1 @5.1-5.12
err div0 at 6.4
= -1 @6.1-6.4
err syntax error at 7.3
= -1 @7.1-7.3
= 9 @8.1-8.7
rc 0 nerrs 4
err syntax error at 1.4
[drop foo]rc 1 nerrs 1
' > "$g"; same "yacc C parser (the answer)"
if command -v bison >/dev/null 2>&1; then
  bison -o "$Y/b.c" --defines="$Y/b.h" -t -l "$Y/t.y" 2>/dev/null && moonc "$Y/b.c" "$Y/b" > /dev/null 2>&1 || fail "bison's parser"
  { "$Y/b" < "$Y/in"; printf foo | "$Y/b"; } > "$g"; same "yacc C parser vs bison"
fi
echo "kore: diff (GNU-identical) + argv0 symlink + as + ar + ld + objcopy + nm + size + strip + ranlib + readelf + lex + yacc ok"
