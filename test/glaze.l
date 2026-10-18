; the glaze, arch-neutral: the install seam's guards and the decline laws.
; claims go by key: a bare `nif` is off the book and would answer 1
(: G (cite 'glaze)
   (? G (: N (G 'nif)
           (test (lit? N)
                   !(N 5 0 1) !(N 'x 0 1) !(N () 0 1) !(N "" 0 1)))
      0))

; --- the group lane declines what it cannot emit ---
; it holds only a frame param or an integer leaf, and declines silently
(: (scar-sp n)   (: (go k acc) (k < 1 ? acc (go (k - 1) (acc + " "))) (go n ""))    ; string built by +
   (scar-dash z) (: (g j) (j < 1 ? "" ("-" + g (j - 1))) (g #z))                     ; ..the argument-applying twin
   (scar-lit n)  (: (go k acc) (k < 1 ? acc (go (k - 1) "Q")) (go n 0))               ; a bare string constant
   (scar-link n) (: (go k acc) (k < 1 ? acc (go (k - 1) (acc . 1))) (go n 0))       ; a cons
   _ (test
      ("   " = scar-sp 3)
      ("--" = scar-dash "ab")
      ("Q" = scar-lit 2)
      ((((0 . 1) . 1) . 1) = scar-link 3))
   0)

; --- the constant fold passes a pair whose own params spell the constant's name ---
; through `ev`, since only a bare top-level letrec meets the fold
(test
    (3  = (ev '(: (x f) f  f 2  (x 3))))
    (7  = (ev '(: (x f y) (+ f y)  f 2  (x 3 4))))
    (3  = (ev '(: f 2  (x f) f  (x 3))))
    (3  = (ev '(: x (\ f f)  f 2  (x 3))))
    (11 = (ev '(: f 2  (g f) (+ f 1)  (g 10))))
    (7  = (ev '(: tw (\ h (h 1))  (g tw) (tw (\ y (+ y 5)))  (g (\ k 7)))))   ; dehof's lamc fold holds the same law
    (12 = (ev '(: m 7  (g x) (+ x m)  (g 5)))))                                ; ..and an unshadowed const still folds

; --- the named-let lift's inline respects the fn's own params ---
; a param of the fn, or of a lambda in it, spelling an inlined value's name binds it there
(test
    (3 = (ev '(: (f n) (: k 0  (g k) k  (g n))  (f 3))))
    (1 = (ev '(: (f n) (: k 0  (g k x) ((\ i (? (< i k) 1 2)) x)  (g n 1))  (f 3))))
    (4 = (ev '(: (f n) (: k 0  (g x) ((\ k (+ k x)) 1)  (g n))  (f 3))))
    (5 = (ev '(: (f n) (: m 2  (g x) (+ x m)  (g n))  (f 3)))))                  ; ..and an unshadowed value still inlines

; --- a hoisted loop's captures, and a helper's own params, past a same-named let value ---
; plift passes a hoisted loop's let values by name; a helper param spelling one must not
; be passed in its place, nor shadowed by the weave's by-name captures
(test
    (4 = (ev '(: (p n vs) (: k #vs  (helper x i) (? (< i 1) (+ x k) (helper x (- i 1)))
                              (along k x) (helper (+ x k) 2)  (along n 1))  (p 3 []))))
    (3 = (ev '(: (p n vs) (: k #vs  (helper x i) (? (< i 1) (+ x k) (helper x (- i 1)))
                              (along k x) (: (step i) (? (< i k) (step (+ i 1)) (helper i 1)) (step x))
                              (caller y) (along y 0)  (caller n))  (p 3 [])))))

; --- the desugar declines a word an enclosing letrec rebinds ---
; each local answers 7; the bodies compute, or a fold would beat the desugar to them
(: (one? e)  (charm? e ? 7 9)
   (nil? e)  (charm? e ? 7 9)
   (atom? e) (charm? e ? 7 9)
   (!= a b)  (charm? a ? 7 9)
   (!== a b) (charm? a ? 7 9)
   (c1 r) (two? r && (one? <r))
   (c2 r) (two? r && (nil? <r))
   (c3 r) (two? r && (atom? <r))
   (c4 r) (two? r && (!= <r <r))
   (c5 r) (two? r && (!== <r <r))
   q [0 "x"]
   _ (test (7 = c1 q) (7 = c2 q) (7 = c3 q) (7 = c4 q) (7 = c5 q))
   0)
; ..and canon respells a synonym as its canonical word only where no binder took that word:
; a local atom? leaves one? the global's, a local two? leaves link? the global's
(: (atom? e) (charm? e ? 7 9)
   (c r) (one? r)
   _ (test (1 = c ()) (0 = c [1]))
   0)
(: (two? e) (charm? e ? 7 9)
   (c r) (link? r)
   _ (test (1 = c [1]) (0 = c ()))
   0)
; ..and `list`, in a letrec of its own: a local spelling owns that scope's [..] too
(: (list a) (charm? a ? 7 9)
   (c6 r) (two? r && (list <r))
   q (. 0 (. "x" ()))
   _ (test (7 = c6 q))
   0)

; --- a head the amble reads by name is that head only while no letrec rebinds it ---
; each local answers 7, each loop runs past the amble's threshold, and each driver
; avoids the ops its own group shadows
(: (+ a b) (charm? a ? 7 9)   (- a b) (charm? a ? 7 9)   (* a b) (charm? a ? 7 9)
   (// a b) (charm? a ? 7 9)  (% a b) (charm? a ? 7 9)
   (go l acc) (two? l ? (go >l [(+ <l <l) (- <l <l) (* <l <l) (// <l <l) (% <l <l)]) acc)
   _ (test (all (x \ x = 7) (go ^40 0)))
   0)
(: (& a b) (charm? a ? 7 9)   (| a b) (charm? a ? 7 9)   (^ a b) (charm? a ? 7 9)
   (go l acc) (two? l ? (go >l [(& <l <l) (| <l <l) (^ <l <l)]) acc)
   _ (test (all (x \ x = 7) (go ^40 0)))
   0)
(: (< a b) (charm? a ? 7 9)   (<= a b) (charm? a ? 7 9)  (> a b) (charm? a ? 7 9)
   (>= a b) (charm? a ? 7 9)  (= a b) (charm? a ? 7 9)   (== a b) (charm? a ? 7 9)
   (go l acc) (two? l ? (go >l [(< <l <l) (<= <l <l) (> <l <l) (>= <l <l) (= <l <l) (== <l <l)]) acc)
   _ (test (all (x \ 7 == x) (go ^40 0)))
   0)
; ..and the heads the loop above needs for itself, driven by arithmetic instead
(: (two? a) (charm? a ? 7 9)  (cap a) (charm? a ? 7 9)   (cup a) (charm? a ? 7 9)
   (. a b) (charm? a ? 7 9)   (|| a b) (charm? a ? 7 9)  (tally a) (charm? a ? 7 9)
   (go n acc) (n <= 0 ? acc (go (n - 1) [(two? n) (cap n) (cup n) (. n n) (|| n n) (tally n)]))
   _ (test (all (x \ x = 7) (go 40 0)))
   0)

; --- every word in aopnames has a row below or is wordless: an unclassified addition goes red ---
(: G (cite 'glaze)
   (? G (: gw (G 'gopword)
           named [[two? 'two?] [cap 'cap] [cup 'cup] [(.) '.] [(==) '==] [peep 'peep] [tally 'tally] [long? 'long?]
                  [(+) '+] [(-) '-] [(*) '*] [(//) '//] [(%) '%] [(&) '&] [(|) '|] [(^) '^]
                  [(<) '<] [(<=) '<=] [(>) '>] [(>=) '>=] [(=) '=] [atom? 'atom?] [nil? 'nil?]]
           wordless '(list && || one? != !== mpeep)
           _ (test
              (all (r \ (<>r = gw <r)) named)                                 ; a value answers its word
              ('zz = gw 'zz)                                                   ; a nom is its own word
              (sort ((map (r \ <>r) named) + wordless) = sort (G 'aopnames))) ; and the two halves ARE the roster
           0)
      0))
; and a head as a nom or a value gives the same answer
(: plus (+)
   (mk h) [': ['f 'n 'acc]
              ['? ['= 'n 0] 'acc ['f ['- 'n 1] [h 'acc 'n]]]
              ['f 10 0]]
   _ (test (55 = ev (mk '+)) (55 = ev (mk plus)) (ev (mk '+) = ev (mk plus)))
   0)
; an integer leaf is a 64-bit immediate, so a big in a body declines the lane
(: (f _) 18446744073709551615
   (g _) 18446744073709551616
   (m x) (x % 18446744073709551616)
   _ (test (f 0 = 18446744073709551615) (g 0 = 18446744073709551616) (m -5 = -5))
   0)
; a polynomial fold over jot closes to its form: a sum of squares, as the interpreter's
(: dq '(: (s n) (foldl (+) 0 (map (\ x (* x x)) (jot n))) (s 100))
   _ (test (328350 = ev dq))
   0)
; (t 'k) in an ambled body probes a tablet inline: hit, miss, a key of the other kind,
; a grown table, and a non-tablet callee all answer as the interpreter does
(: ks ['a 'b 'c 'link 'type 'width 'height 'depth 'glue 'font 'char 'sub 'id 'x 'y 'z 'shift 'list]
   (gz-reads l acc) (? (atom? l) (rev acc) (: t <l (gz-reads >l ([(t 'a) (t 'link) (t 'z) (t 'id)] . acc))))
   (gz-mk n) (: t {} _ (map (k \ pin t (ks (k % #ks)) (k * 7)) ^n) _ (pin t 3 'three) t)
   got (gz-reads (map gz-mk [0 1 8 18 40] + [(k \ [k 1]) "s" [1 2]]) ())
   _ (test (got = [[() () () ()] [0 () () ()] [0 21 () ()] [0 21 105 84] [252 273 231 210]
                   [['a 1] ['link 1] ['z 1] ['id 1]] ["sa" "slink" "sz" "sid"] [() () () ()]]))
   0)
; a loop hoisted out of a fn is found by a later value binding; one answered as a value is
; partially applied to its captures
(: (gzo-f x) (x + 1)
   (gzo-s n) (: gzo-f (\ x (x * 10)) (h y acc) (? (y = 0) acc (h (y - 1) (acc + gzo-f y))) (h n 0))
   (gzo-v n) (: (h y acc) (? (y = 0) acc (h (y - 1) (acc + y + n))) h)
   _ (test (gzo-s 4 = 100) (gzo-v 0 4 0 = 10) (gzo-v 2 4 0 = 18))
   0)
; a helper above the sibling it calls compiles once every sibling is built, into the cell
; its callers hold: a float deopts, and it keys a tablet the same. glaze-hook.l reads gzfm
(module (gzfm gzfm-sum gzfm-walk)
 (:
  (gzfm-sum l acc) (? (two? l) (gzfm-sum >l (acc + gzfm-sq <l)) acc)
  (gzfm-walk l n) (? (two? l) (gzfm-walk >l (n + gzfm-len <l)) n)
  (gzfm-sq x) (x * x)
  (gzfm-len s) (? (string? s) (tally s) (gzfm-sum s 0))))
(: gzfm-s (cite 'gzfm 'gzfm-sum)  gzfm-w (cite 'gzfm 'gzfm-walk)  gzfm-t {gzfm-s 1}
   _ (test (gzfm-s [1 2 3] 0 = 14) (gzfm-s [1.5] 0 = 2.25) ((gzfm-t gzfm-s) = 1)
           (gzfm-w ["ab" [1 2] "c"] 0 = 8))
   0)
; a 3-arg peep predicate beside a pin on the same tablet answers the tablet, either order, in a loop
(: (gzpp-put t k v) (? (peep t k 0) t (pin t k v))
   (gzpp-swap t k v) (? (peep t k 0) (pin t k v) t)
   (gzpp-fill i t) (? (i = 300) t (gzpp-fill (i + 1) (gzpp-put t (i % 7) i)))
   _ (test (show (gzpp-put {} 5 9) = "{5 9}") (show (gzpp-put {5 1} 5 9) = "{5 1}")
           (show (gzpp-swap {} 5 9) = "{}") (show (gzpp-swap {5 1} 5 9) = "{5 9}")
           (sort (keys (gzpp-fill 0 {})) = [0 1 2 3 4 5 6]) (gzpp-fill 0 {} 0 = 7))
   0)
; (long? k x) inlines as k chain checks, and a two? or long? above an access makes its
; cap and cup bare loads
(: (gzl-1 x) (long? 1 >x)   (gzl-2 x) (long? 2 x)   (gzl-3 x) (long? 3 >x)
   (gzl-f x) (two? x && long? 3 >x && () == >>>>x && <>>x)
   ins ['(1) '(1 2) '(1 2 3) '(1 2 3 4) () 5 'a "ab"]
   _ (test (map gzl-1 ins = [0 1 1 1 0 0 0 0])
           (map gzl-2 ins = [0 1 1 1 0 0 0 0])
           (map gzl-3 ins = [0 0 0 1 0 0 0 0])
           (map gzl-f ins = [0 0 0 3 0 0 0 0]))
   0)
; the swallow records each pair of a form binding a name twice but those that name or read it:
; dupnames finds the names a `:` itself rebinds
(: G (cite 'glaze)
   (? G (: gzdn (G 'dupnames)
           (test (gzdn '(: a 1  (f x) (: b 1  b 2  b)  a 2  g '(: c 1  c 2)) = '(a a))
                 (gzdn '(: _ 1  _ 2  (f x) x) = ())))
      0))
