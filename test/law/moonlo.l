; test/law/moonlo.l -- the new backend's invariants (lo.l, ra.l): each check bites a planted break,
; then holds over every fn a corpus lowers by the new path. run by test_moon, before moon.l's laws.

; a source by the new path with the checks on -> [fns checked, what broke] | 'bad
(: (lolaw src)
    (setenv "MOON_BACKEND" "new", setenv "MOON_LOLAW" "1",
     (cparse <>(clex src) @ r (okv? r ? (cgen-core <>r <>>r <>>>r <>>>>r () 'x64))) @ v
       (setenv "MOON_BACKEND" (), setenv "MOON_LOLAW" (),
        v @ (g . _) [(g 'lolawn) (g 'lolaw)] _ 'bad))
   ; a planted fn's vregs spelt n0 n1 ..
   (lv fs) (map (f \ map (x \ (nom? x && (show x @ t (1 < #t && t 0 = 110 && 48 <= t 1 <= 57)) ? (name "%\(show x)") x)) f) fs)
   g (cparse <>(clex "int main() { return 0; }") @ r <(cgen-core <>r <>>r <>>>r <>>>>r () 'x64))
   ; the corpus: calls on the stack and in registers, aggregates, varargs, the wide pair, control, asm,
   ; floats, VLAs, complex
   corpus [
    "long f(long a, long b, long c, long d, long e, long f, long g, double x) { return a + g + (long) x; }
     int main() { return f(1, 2, 3, 4, 5, 6, 7, 1.5); }"
    "struct p { long a, b; }; struct p mk(long x) { struct p r = { x, x + 1 }; return r; }
     int main() { struct p q = mk(3); return q.a + q.b; }"
    "struct b { long a[5]; }; struct b mk(void) { struct b r = { { 1, 2, 3, 4, 5 } }; return r; }
     long use(struct b x) { return x.a[4]; } int main() { return use(mk()); }"
    "int s(int n, ...) { __builtin_va_list ap; __builtin_va_start(ap, n); int t = 0;
       while (n--) t += __builtin_va_arg(ap, int); __builtin_va_end(ap); return t; }
     int main() { return s(3, 1, 2, 3); }"
    "unsigned __int128 m(unsigned __int128 a, unsigned __int128 b) { return a * b + (a >> 3) - b / 7 + (a < b); }
     __int128 n(long x, __int128 y) { return -y << 2 | x; }
     int main() { return (int) m(5, 9) + (int) n(1, 2); }"
    "int f(int x) { int s = 0; for (int i = 0; i < x; i++) { switch (i & 3) { case 0: s += i; break;
       case 1 ... 2: s -= 1; break; default: s ^= i; } } return s > 3 ? s : -s; }
     int main() { return f(9); }"
    "long f(long x) { long y; __asm__(\"lea 1(%1), %0\" : \"=r\"(y) : \"r\"(x)); return y; }
     int main() { return f(4); }"
    "long g(long x) { return x * 3; }
     long f(long n) { long a = 0, b = 1; while (n--) { long t = g(a); a = b; b = t + a; } return a + b; }
     int main() { return f(5); }"
    "double f(double a, float b, int c) { return a * b + c / (a + 1.0); }
     int main() { return (int) f(2.0, 3.0f, 4); }"
    "int f(int n) { int a[n]; for (int i = 0; i < n; i++) a[i] = i; return a[n - 1]; }
     int main() { return f(5); }"
    "_Complex double f(_Complex double a, _Complex double b) { return a * b + a / b; }
     int main() { return (int) (double) f(1.0, 2.0); }"
     ]
   (test
      ; a physical register in arithmetic, and one live across it
      (rachkp g (lv [['li 'n0 1] ['add 'n1 'r6 'n0] ['mov 'r0 'n1] ['ret]]) @ [['phys ['r6] _]] 1 _ 0)
      (rachkp g (lv [['li 'n0 1] ['mov 'r6 'n0] ['add 'n1 'n0 'n0] ['cuse 'r6] ['call 'f] ['mov 'r0 'n1] ['ret]])
         @ [['across ['r6] _]] 1 _ 0)
      ; copies to a call and from its answer
      (rachkp g (lv [['li 'n0 1] ['mov 'r6 'n0] ['cuse 'r6] ['call 'f] ['mov 'n1 'r0] ['mov 'r0 'n1] ['ret]]) = ())
      ; a def on one path only
      (rachkd g (lv [['li 'n0 1] ['cmp 'n0 0] ['br 'ne 'L] ['li 'n1 2] ['label 'L] ['add 'n2 'n1 'n0] ['mov 'r0 'n2] ['ret]])
         @ [['undef [_] _]] 1 _ 0)
      (rachkd g (lv [['li 'n0 1] ['li 'n1 2] ['cmp 'n0 0] ['br 'ne 'L] ['li 'n1 3] ['label 'L] ['add 'n2 'n1 'n0] ['mov 'r0 'n2] ['ret]]) = ())
      ; a value across a call: clobbered in r1, kept in r3
      (rachkc g (lv [['li 'n0 1] ['call 'f] ['mov 'r0 'n0] ['ret]]) {(name "%n0") 'r1} @ [['call [[_ 'r1]] _]] 1 _ 0)
      (rachkc g (lv [['li 'n0 1] ['call 'f] ['mov 'r0 'n0] ['ret]]) {(name "%n0") 'r3} = ())
      ; normalise: a copy-then-subtract of itself stays two-address; literals fold through to a load's offset
      (nmfuse (lv [['mov 'n0 'n1] ['sub 'n0 'n0 'n0]]) = lv [['mov 'n0 'n1] ['sub 'n0 'n0 'n0]])
      (nmall g (lv [['mov 'n0 'r6] ['li 'n1 2] ['li 'n2 4] ['imul 'n3 'n1 'n2] ['add 'n4 'n0 'n3] ['ld 'n5 'n4 0]
                    ['mov 'r0 'n5] ['ret]])
         = lv [['mov 'n0 'r6] ['ld 'n5 'n0 8] ['mov 'r0 'n5] ['ret]])
      ; a literal under not is one literal; an unsigned divide by 16 shifts its own copy, not its source
      (nmlit (lv [['li 'n0 3] ['not 'n0]])) = lv [['li 'n0 -4]])
      (nmall g (lv [['mov 'n0 'r6] ['li 'n1 16] ['udiv 'n2 'n0 'n1] ['add 'n3 'n2 'n0] ['mov 'r0 'n3] ['ret]])
         = lv [['mov 'n0 'r6] ['mov 'n2 'n0] ['shr 'n2 4] ['add 'n3 'n2 'n0] ['mov 'r0 'n3] ['ret]])
      (all (src \ lolaw src @ [n ()] (0 < n) _ 0) corpus)
      (+(map (src \ lolaw src @ [n _] n _ 0) corpus) >= 2 * #corpus)))
