; === the generic-op DISPATCH MATRICES, walked cell by cell ====================
; ll's generic dyadic ops are NxN handler matrices indexed by the kind lattice
; (ll.h enum q): KFix | KTuple(rank-0 box: float/complex/wide-int) | KBig |
; KArrZ KArrR KArrC KArrO (the array tower) | KString KSym | KTwo(pair) | KLam.
; A monadic op is that matrix's diagonal. Three matrices are explicit tables in
; ll.c -- g_add_mx (+), g_mul_mx (*), g_apply_mx (apply); the rest (- / mod
; < <= = >= >) are lane handlers that refine the same lattice internally. This
; file pins EVERY cell with an assertion, so the coverage is auditable in one
; place -- and so a dispatch regression (e.g. a data-sentinel stride desync that
; mis-routes whole apply rows) fails loudly here. The coarse {NUM ARR LIST STR
; USYM ISYM} category grids live in test/symadd.l (+) and test/seqmul.l (*); this
; file adds the FINE within-category cells (fix vs box/float/complex vs bignum;
; the four array tiers) and the apply matrix, which had no systematic test.

; one representative value per kind (the KTuple box has three reps that route to
; one matrix cell but fan out by representation inside the lane).
(: mx-fix 5                              ; KFix
   mx-flo 2.5                            ; KTuple, float box
   mx-cpx ~(2 3)                        ; KTuple, complex scalar (Cp)
   mx-box (<< 1 62)                      ; KTuple, wide-int box (boxp)
   mx-big (100 2)                     ; KBig
   mx-az  @(10 20)                       ; KArrZ (int array)
   mx-ar  @(1.5 2.5)                     ; KArrR (float array)
   mx-ac  (array 2 ~(1 2) ~(3 4))      ; KArrC (packed complex array)
   mx-ao  (array 2 (100 2) 5)         ; KArrO (object array)
   mx-str "ab"                           ; KString
   mx-sym 'ef                            ; KSym (interned)
   mx-usy $cd                            ; KSym (uninterned)
   mx-lst '(1 2)                         ; KTwo (pair / list)
   mx-fn  (+ 1)                          ; KLam (nif partial application)
   mx-map (pin (pin (hashn 0) 1 10) 2 20)) ; KLam (a map is a lookup-lambda)

; ============================================================================
; APPLY matrix: g_apply_mx[applied data kind = g_typ(v)][arg kind = g_kind(x)]
; ============================================================================
; Each data kind's sentinel tail-jumps through this. The arg-kind dimension is
; uniform today (a hook for later), so we vary it to pin that. Non-data applies
; (fixnum numeral, lambda/nif, map, opaque handle) take their own paths.
(assert
 ; --- row KTwo: a pair IS its own Church eliminator, (p f) == (f (A p) (B p)).
 ;     This row had no test before -- a sentinel mis-route would silently break
 ;     it (and it shares the failure mode that bit string/sym apply). ---
 (= '(1 (2)) ('(1 2) (\ a b (L a b))))        ; f sees car=1, cdr='(2)
 (= '(1 (2 3)) ('(1 2 3) (\ a b (L a b))))    ; longer cdr passed whole
 (= '(1 2) ((X 1 2) (\ a b (L a b))))         ; improper pair: cdr=2 (a fixnum), raw
 (= '(1 2) ('(1 2) (+)))                        ; arg = a nif: (+ 1 '(2)) = (1 2)
 (= '(1 2 3) ('(1 2 3) (+)))                    ; (+ 1 '(2 3))
 (nilp ('(1) (\ a b b)))                      ; cdr of (1) is nil -> 0

 ; --- row KString: applying a string indexes a byte (1 if oob/non-numeric) ---
 (= 97 ("ab" 0))   (= 98 ("ab" 1))            ; arg = fixnum
 (= 1 ("ab" 9))    (= 1 ("ab" -1))            ; oob -> 1 (matches "" == k**0)
 (= 1 ("ab" 'x))                              ; arg = symbol (non-number) -> 1
 (= 255 ((string 255) 0))                     ; byte is unsigned 0..255
 (= 1 ("" 5))                                 ; the empty string indexes to 1

 ; --- row KSym: applying a symbol indexes its name (== indexing the name str) ---
 (= 97 ('abc 0))   (= 99 ('abc 2))            ; interned: name bytes
 (= 1 ('abc 9))    (= 1 ('abc 'x))            ; oob / non-number -> 1
 (= 1 ((nom 0) 5))                         ; anonymous: no name -> act as 0

 ; --- row KTuple: a rank-0 box / array is a Church numeral (operand ** operator,
 ;     or operator-fold over a function). Full tower coverage in functions.l. ---
 (= 9 (2.0 3))                                ; float operator: 3 ** 2.0 = 9
 (= 8 (3 2.0))                                ; float operand: 2.0 ** 3 = 8
 (= 13 ((2.5 (+ 1)) 10))                      ; float operator on a fn: ($ 2.5)=3 comps
 (= 15 ((~(3 4) (+ 1)) 10))                  ; complex operator on a fn: ($ ~(3 4))=5 comps
 (aall (= @(4 9 16) (2 @(2 3 4))))            ; array operand: elementwise ** broadcast

 ; --- row KBig: a bignum is also a Church numeral, but its magnitude is always
 ;     astronomical (>= 2^62), so (bignum x) cannot terminate in a finite test.
 ;     The row exists (-> data_num_apply, same as KTuple) but is not exercised. ---

 ; --- non-matrix apply paths --------------------------------------------------
 (= 8 (3 2))   (= 5 (1 5))   (= 1 (0 'anything))   ; KFix numeral (odd-tag path)
 (= 36 ((\ x (* x x)) 6))                     ; KLam: a lambda applies directly
 (= 7 (((+) 3) 4))                            ; KLam: a nif / partial application
 (= 10 (mx-map 1))   (= 20 (mx-map 2))        ; KLam: a map looks its key up
 (nilp (mx-map 9))                            ; ...missing key -> nil
 (= 1 ((bufnew 4) 'x)))                       ; opaque handle (buf) behaves as 0

; ============================================================================
; `+` matrix (g_add_mx): the FINE within-category cells symadd.l folds together
; ============================================================================
; addn lane (numeric tower & arrays): the matrix routes here for any arith x
; arith pair; the lane then refines by representation. Each rep pairing:
(assert
 ; --- scalar tower: fix / float / wide-int box / bignum / complex, every mix ---
 (= 7 (+ 5 2))                                ; fix + fix (overflow-free fast path)
 (= 7.5 (+ 5 2.5))   (= 7.5 (+ 2.5 5))        ; fix + float (both orders)
 (= 5.0 (+ 2.5 2.5))                          ; float + float
 (= (63 2) (+ (<< 1 62) (<< 1 62)))        ; box + box -> 2^63 overflows i64 -> bignum
 (bigp (+ (<< 1 62) (<< 1 62)))
 (boxp (+ (<< 1 62) 1))                        ; box + fix stays a box (still > fixnum range)
 (= (+ (<< 1 62) 1) (+ 1 (<< 1 62)))          ; ...and commutes
 (= (+ 1 (100 2)) (+ (100 2) 1))        ; big + fix == fix + big (commutes)
 (= (* 2 (100 2)) (+ (100 2) (100 2))) ; big + big
 (flop (+ (100 2) 0.5))                    ; big + float -> float (widens)
 (= ~(4 6) (+ ~(1 2) ~(3 4)))              ; complex + complex
 (= ~(7 3) (+ 5 ~(2 3)))                    ; fix + complex (real -> (5,0))
 (= ~(4.0 3.0) (+ 1.5 ~(2.5 3)))            ; float + complex
 (comp (+ (<< 1 62) ~(0 1)))                   ; box + complex -> complex
 (comp (+ (100 2) ~(0 1)))                  ; big + complex -> complex (widens)

 ; --- array tower: each tier with a matching array and with a scalar broadcast ---
 (aall (= @(11 22) (+ @(10 20) @(1 2))))      ; Z + Z
 (= f64 (atype (+ @(10 20) @(1.5 2.5))))      ; Z + R -> widens to R
 (aall (= @(11.5 22.5) (+ @(10 20) @(1.5 2.5))))
 (aall (= @(3.0 5.0) (+ @(1.5 2.5) @(1.5 2.5)))) ; R + R
 (= ~(2 4) (peek (+ mx-ac mx-ac) 0 0))        ; C + C (packed complex)
 (= o (atype (+ mx-ao mx-ao)))                ; O + O stays exact/object
 (= (* 2 (100 2)) (peek (+ mx-ao mx-ao) 0 0))
 (aall (= @(12 22) (+ @(10 20) 2)))           ; Z + scalar (broadcast, no widen)
 (= ~(11 2) (peek (+ ~(10 0) mx-ac) 0 0))    ; C array + complex scalar
 (= ~(11 2) (peek (+ @(10 20) mx-ac) 0 0))    ; R/Z array + C array (real promotes)
 (nilp (+ @(1 2) @(1 2 3)))                   ; non-conforming shapes -> nil

 ; --- add_string lane: text x text, and a number as one byte ---
 (= "abcd" (+ "ab" "cd"))                     ; str + str
 (= "abC" (+ "ab" 67))   (= "Cab" (+ 67 "ab")) ; str + num (byte at the written end)
 (= "abef" (+ "ab" 'ef))                      ; str + isym -> demote to str
 (= 'efef (+ 'ef 'ef))                        ; isym + isym -> interned sym
 (strp (+ 'ef "ab"))                          ; isym + str -> str

 ; --- the arith<->seq SEAM (KArrO|KString) is ARRAY x text only -> nil. A SCALAR
 ;     number (incl. a bignum) instead joins text as one byte -> a string. ---
 (nilp (+ @(1 2) "ab"))   (nilp (+ "ab" @(1 2)))   (nilp (+ @(1 2) 'ef))
 (strp (+ mx-big "ab"))                       ; bignum is a scalar -> a byte, not nil

 ; --- add_seq lane: a list anywhere (pair wins over text & number) ---
 (= '(1 2 3 4) (+ '(1 2) '(3 4)))             ; list + list
 (= '(5 1 2) (+ 5 '(1 2)))   (= '(1 2 5) (+ '(1 2) 5))   ; num <-> list
 (= '("ab" 1 2) (+ "ab" '(1 2)))              ; str <-> list (str is one element)
 (= 3 (sat (+ @(1 2) '(7 8))))                ; array <-> list (array is one element)

 ; --- addl lane: a lambda operand anywhere -> CHURCH-NUMERAL add (not pointwise):
 ;     (m + n) a x == m a (n a x), so the result is a function awaiting (f x).
 ;     "1" + "1" == "2": apply (+ 1) twice to 0. ---
 (= 2 (((+ (\ f x (f x)) (\ f x (f x))) (+ 1)) 0))
 (lamp (+ inc 2))   (lamp (+ 2 inc))          ; num + fn (either order) -> a function
 (lamp (+ inc inc)))                          ; fn + fn -> a function

; ============================================================================
; `*` matrix (g_mul_mx): the multiplicative analog (semiring product of `+`)
; ============================================================================
; muln (arith), mul_rep (seq x count), g_vm_0 (seq x seq -> nil), mull (compose).
(assert
 ; --- muln: scalar tower + arrays ---
 (= 6 (* 2 3))                                ; fix * fix
 (= 7.5 (* 3 2.5))                            ; fix * float
 (= (124 2) (* (<< 1 62) (<< 1 62)))       ; box * box -> bignum (overflows the box)
 (= (200 2) (* (100 2) (100 2)))     ; big * big
 (= -1 (* i i))                               ; complex * complex (i^2, bridges to real)
 (= ~(-5 10) (* ~(1 2) ~(3 4)))            ; Gaussian product
 (= ~(4 6) (* 2 ~(2 3)))                    ; fix * complex
 (aall (= @(20 60) (* @(10 30) 2)))           ; Z array * scalar
 (= ~(2 4) (peek (* ~(2 0) mx-ac) 0 0))      ; complex scalar * C array
 (= o (atype (* mx-ao mx-ao)))                ; O * O exact
 (= (80 2)                                 ; 2^40 * 2^40, exact (an i64 array would wrap)
    (peek (* (arrl o '(2) (L (40 2) (40 2))) (arrl o '(2) (L (40 2) (40 2)))) 0 0))

 ; --- mul_rep: a sequence times a scalar count (int(abs c)) -> n copies joined ---
 (= "ababab" (* "ab" 3))   (= "ababab" (* 3 "ab"))   ; str (commutes)
 (= "abab" (* "ab" -2))    (= "abab" (* "ab" 2.9))   ; |count|, floored
 (= 'xyxy (* 'xy 2))                          ; sym keeps its rank
 (= '(1 2 1 2) (* '(1 2) 2))                  ; list
 (= "" (* "ab" 0))   (nilp (* '(1 2) 0))      ; 0 copies: empty str / empty list

 ; --- count must be a number: an array / non-number count -> nil ---
 (nilp (* "ab" @(1 2)))   (nilp (* @(1 2) "ab"))

 ; --- g_vm_0: sequence * sequence is undefined -> nil ---
 (nilp (* "ab" "cd"))   (nilp (* 'a 'b))   (nilp (* '(1) '(2)))

 ; --- mull: a lambda operand anywhere -> composition (Church mul) ---
 (= 36 ((* (\ x (* x x)) (\ x (+ x 1))) 5))   ; sq(inc 5) = sq 6 = 36
 (= 26 ((* (\ x (+ x 1)) 2) 5))               ; (inc (2 5)) = inc 25 = 26 (numeral then inc)
 (= 10 ((* mx-map (\ x (- x 1))) 2)))         ; a map composes too: m(2-1) = m 1 = 10

; ============================================================================
; the other dyadic generic ops (lane handlers, not explicit tables): -, /, mod,
; comparisons, =. Same lattice; these had no consolidated matrix test.
; ============================================================================
(assert
 ; --- subtraction `-` is NUMERIC ONLY (text/list/lambda operands -> nil) ---
 (= 3 (- 5 2))   (= 2.5 (- 5 2.5))            ; fix/float tower
 (= (100 2) (- (+ (100 2) 5) 5))        ; bignum
 (= ~(-2 -2) (- ~(1 2) ~(3 4)))            ; complex
 (aall (= @(9 18) (- @(10 20) @(1 2))))       ; array elementwise
 (nilp (- "a" "b"))   (nilp (- '(1) '(2)))    ; non-numeric -> nil

 ; --- division: `/` true (float on inexact), `//` truncating; array broadcast; complex defined ---
 (= 2.5 (/ 5 2))   (= 2 (// 5 2))   (= 2.5 (/ 5 2.0))   ; / promotes, // truncates
 (= 32 (/ (100 2) (95 2)))              ; bignum exact (2^5) stays integer
 (flop (/ 1 0))                               ; /0 -> IEEE inf (float)
 (aall (= @(5 10) (/ @(10 20) 2)))            ; array / scalar
 (nilp (/ "a" 2))                             ; non-numeric -> nil

 ; --- modulo `mod` (fmod on floats); UNDEFINED on complex (-> nil) ---
 (= 1 (mod 5 2))   (= 1.0 (mod 7.0 2.0))
 (= 2 (mod (100 2) 7))                     ; bignum mod fixnum
 (nilp (mod ~(1 2) 2))                       ; complex -> nil
 (nilp (mod "a" 2))                           ; non-numeric -> nil

 ; === ordered comparison (< <= > >=): a TOTAL ORDER over all values. Cross-kind =
 ; the enum q type lattice (the order the matrix DIAGONAL encodes), fixnum/number
 ; low -> lambda high: number < string < symbol < pair < lambda. Within a kind:
 ; numbers by value, text/sym lexicographic, pairs recursive, lambdas by repr hash.
 ; An array operand is the exception -> elementwise mask (never the scalar order).
 ; `> >=` are `< <=` with operands reversed (a > b == b < a).
 ; --- within NUMBER: the whole tower orders by value (reps interleave) ---
 (< 1 2)   (< 1 1.5)   (< 1.5 2)                       ; fix / float
 (< (<< 1 62) (* 3 (<< 1 62)))                         ; box < box
 (< 5 (100 2))   (< (<< 1 62) (100 2))           ; fix/box < bignum (magnitude-exact)
 (< (100 2) (101 2))                             ; bignum < bignum
 ; --- complex: lexicographic (re, im); a real r is (r, 0) ---
 (< i 1)   (< ~(1 9) ~(2 0))   (< ~(2 1) ~(2 2))   ; re decides, then im
 !(< ~(2 2) ~(2 2))   (<= ~(2 2) ~(2 2))        ; equal complexes
 ; --- within STRING / SYMBOL: lexicographic, a prefix sorts first ---
 (< "abc" "abd")   (< "ab" "abc")   !(< "abc" "abc")
 (< 'aa 'ab)   (< 'ab 'abc)
 ; --- within PAIR: recursive lexicographic; a shorter prefix sorts first ---
 (< '(1 2) '(1 3))   (< '(1) '(1 2))   (< '(1 2) '(2))
 !(< '(1 2) '(1 2))   (<= '(1 2) '(1 2))
 ; --- CROSS-kind = the type lattice (number < string < symbol < pair < lambda) ---
 (< 1 "a")   (< "a" 'a)   (< 'a '(0))   (< '(0) inc)
 (< 1.5 "")   (< (100 2) 'z)   (< ~(1 1) "x")      ; ANY number < ANY string
 !(< "a" 1)   !(< '(0) 'z)                        ; ...and the reverses are false (pair > sym)
 ; --- LAMBDA is the top class; within it, ordered by representation hash ---
 (< 5 inc)   (> inc '(0))   (< "z" inc)                ; everything sorts below a lambda
 !(< inc inc)   (<= inc inc)   (>= inc inc)         ; reflexive: a lambda equals itself
 (= (? (< inc dec) 1 0) (? (> dec inc) 1 0))           ; antisymmetric: a < b iff b > a
 (|| (<= inc dec) (>= inc dec))                        ; total: some order holds between distinct fns
 ; --- all four orderings agree (<= >= include equality; > is the strict reverse) ---
 (<= 3 3)   (>= 3 3)   !(< 3 3)   !(> 3 3)   (> 5 3)   (>= 5 3)
 (<= "ab" "ab")   (> 'b 'a)   (>= '(1) '(1))
 ; --- array operand: comparison is ELEMENTWISE (a 0/1 mask), not the scalar order ---
 (aall (< @(1 2) 10))   (= i8 (atype (< @(1 2) 10)))   ; the mask is an i8 array
 (= 1 (peek (< @(1 5) @(3 2)) 0 0))   (= 0 (peek (< @(1 5) @(3 2)) 1 0))
 (aall (<= @(1 2) @(1 2)))   (aall (>= @(2 2) @(1 2)))
 (nilp (< @(1 2) "x"))                                 ; array vs non-number -> nil
 (nilp (< mx-ac mx-ac))                                ; a complex array is unordered -> nil
 ; --- NaN is unordered: every ordering of it is false ---
 (nilp (< (/ 0 0) (/ 0 0)))   (nilp (<= (/ 0 0) (/ 0 0)))   (nilp (> (/ 0 0) 1))

 ; --- equality `=`: bridges the numeric tower, elementwise over arrays, else eql ---
 (= 3 3.0)                                    ; fix = float (promotion)
 (= (<< 1 62) (<< 1 62))                      ; box = box
 !(= (<< 1 62) 0)                          ; ...never = a fixnum
 (= (100 2) (100 2))                    ; bignum = bignum
 (= ~(2 0) 2)                                ; complex bridges a real (im 0)
 !(= ~(2 1) 2)                            ; ...but not when im != 0
 (aall (= @(1 2) @(1 2)))                     ; array = array -> mask
 (= 1 (peek (= @(1 9) @(1 8)) 0 0))            ; elementwise: first elem equal
 (= 0 (peek (= @(1 9) @(1 8)) 1 0))
 (= 'ef 'ef)   !(= 'ef 'gh)                ; symbol identity
 (= "ab" "ab")                                ; string structural eq
 (= '(1 2) '(1 2))                            ; list structural eq
 !(= "ab" 'ab))                            ; cross-kind -> not equal
