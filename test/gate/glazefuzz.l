; test/gate/glazefuzz.l -- the glaze's differential fuzz: random closures in the hook's shapes,
; run plain and under LOVE_NO_GLAZE=1, stdouts byte-identical. the leaf pools carry values the
; integer lanes must decline; gfz4's ledger catches a deopt restarting over a call-out; 100 and
; bleaf reach past fixnum range. `fires=` proves work: nonzero glazed, zero plain.

; file mode's help quits on every scare: a missing read (bleaf's free names) answers the zero
; point and runs on, anything else stops the file
(heard () @ fzhelp
   (hear (a \ b \ (= a 'missing ? () (fzhelp a b)))))

; pinned cases, each top-level so the glaze takes it: a fixnum reaching a group's map or chain
; slot through a sibling, recursion past the native stack, an inner : rebinding a lambda sibling
(: (gzG h i) (i ? (peep h 0 0) (gzG h 1)) (gzF h) (gzG h 0) (puts (show [(gzF 7) (gzF -1) (gzF {0 5}) (gzF "ab")] + "\n")))
(: (gzc l i) (i ? (two? l) (gzc l 1)) (gzd l) (gzc l 0) (puts (show [(gzd 6) (gzd [1 2])] + "\n")))
(: (gzr n) (n = 0 ? 0 (1 + gzr (n - 1))) (puts (show (gzr 400000) + "\n")))
(: (gzl l) (two? l ? (1 + gzl (cup l)) 0) (puts (show (gzl ^400000) + "\n")))
(: (gzf a b) 0 (gzh y) (: gzf y (gzf 1 2)) (puts (show [(gzh 9) (gzh 'zz) (gzh (+ 1))] + "\n")))
; wrong answers: a closed form over a bound not a whole N >= 0, a deopt rerunning a
; read-then-write, a param shadowing a group fn, a folded twin arg
(: (gzs n) (: (go i s) (i < n ? (go (i + 1) (s + i)) s) (go 0 0)) (puts (show [(gzs 10) (gzs 3.5) (gzs -2) (gzs (2 ~ 1))] + "\n")))
(: (gzj n) (foldl (+) 0 (jot n)) (puts (show [(gzj 10) (gzj -3) (gzj 4.5) (gzj "ab") (gzj [1 2])] + "\n")))
(: (gzk n) (foldl (+) 0.5 (map (x \ x * x) (jot n))) (puts (show [(gzk 10) (gzk 2.5)] + "\n")))
(: (gzq n) (foldl (+) 0 (map (x \ x * x) (jot n))) (puts (show [(gzq 100) (gzq -3) (gzq 0) (gzq 2.5) (gzq "ab")] + "\n")))
(: T {0 0} (gzm n t) (n = 0 ? 1 (n * gzm (n - 1) (pin t 0 (peep t 0 0 + 1)))) r (gzm 30 T) (puts (show [r (T 0)] + "\n")))
(: (gzp a b) (a * 10 + b) (gzq x) (: (gzw gzp) (gzp 1 2) (gzw x)) (puts (show (gzq 9) + "\n")))
(: (gzt x) (x 1 2) (puts (show (gzt (0 ~ 1)) + "\n")))

(: (gfz0 i) (i + 1)                                ; call-out globals: two arithmetic,
   (gfz1 i) (i * 2)                                ; two answering what the integer lane cannot hold
   (gfz2 i) (i < 2 ? " " i)
   (gfz3 i) (i < 2 ? '(1 2) i)
   FZL {}                                  ; gfz4's ledger: a lane whose deopt
   (gfz4 i) (pin FZL 'n (1 + peep FZL 'n 0), (i + 1))        ; restarts over it diverges on the count
   _ (rng-set (wheel 20260729))                    ; fixed seed: both runs generate the same forms
   (pick l) (l (rand #l))
   ; bleaf is hostile: k/acc are frame params where bound and free elsewhere (a free read
   ; scares to stderr, stdout stays comparable)
   ileaf (_ \ pick '(x y 0 1 2 3 -1 7))
   bleaf (_ \ pick '(k acc 0 1 2 " " "Q" 'nm '(1 2) 1.5 "" 3 -6000000000000000000))   ; past fixnum, and negative so `*` on a text is () not a repeat
   fleaf (_ \ pick '(x 0.5 1.5 2.0 3 1))
   iop   (_ \ pick '(+ - * < > = // %))
   fop   (_ \ pick '(+ - *))
   gfn   (_ \ pick '(gfz0 gfz1 gfz2 gfz3 gfz4))
   ; argument order is unspecified, so every draw is its own binding, last operand first
   (xpr d lf op) (d < 1 ? (lf 0)                 ; an expression of depth d over a leaf and an operator generator
                  (: e (d - 1)
                   (rand 4 @ 0 (lf 0)
                             1 (: c (xpr e lf op) b (xpr e lf op) a (op 0) [a b c])
                             2 (: c (xpr e lf op) b (xpr e lf op) a (xpr e lf op) ['? ['< a 3] b c])
                             (: b (lf 0) a (xpr e lf op) ['+ a b]))))
   ; one shape per lane the hook offers: 9 reaches calloutinfo with every earlier lane
   ; declining, 10 calloutinfo-frame, 11 the counted loop
   (shape i)
    (i % 14 @ 0 ['\ 'x (xpr 2 ileaf iop)]                                             ; leaf
               1 ['\ 'x 'y (xpr 2 ileaf iop)]                                          ; n-ary leaf
               2 ['\ 'x (xpr 2 fleaf fop)]                                             ; float-result leaf (qualfr)
               3 ['\ 'n [': ['go 'k 'acc] ['? '(< k 1) 'acc ['go '(- k 1) (xpr 2 bleaf iop)]] '(go n 0)]]
               4 ['\ 'n [': ['go 'k 'acc] ['? '(< k 1) 'acc ['go '(- k 1) (xpr 2 bleaf iop)]] ['go 'n (bleaf 0)]]]
               5 ['\ 'n [': ['go 'k] ['? '(< k 1) (bleaf 0) ['+ (bleaf 0) ['go '(- k 1)]]] '(go n)]]
               6 ['\ 'n [': ['evn 'k] ['? '(< k 1) (bleaf 0) ['odd '(- k 1)]]          ; the group lane proper
                            ['odd 'k] ['? '(< k 1) (bleaf 0) ['+ (bleaf 0) ['evn '(- k 1)]]]
                            '(evn n)]]
               7 ['\ 'n [': ['go 'i 'a 'b] ['? '(< i n) ['go '(+ i 1) 'b (xpr 1 bleaf iop)] 'a] '(go 0 0 1)]]
               8 ['\ 'n [': ['go 'k 'acc] ['? '(< k 1) 'acc ['go '(- k 1) ['+ 'acc (xpr 1 bleaf iop)]]] '(go n 0)]]
               9 ['\ 'n [[': ['go 'i 'a] ['? '(< i n) ['go '(+ i 1) ['+ 'a [(gfn 0) 'i]]] 'a]] 0 0]]           ; call-out over a resolvable global
               10 ['\ 'f 'n [[': ['go 'i 'a] ['? '(< i n) ['go '(+ i 1) ['+ 'a '(f i)]] 'a]] 0 0]]             ; call-out with f a frame param
               11 ['\ 'n [[': ['go 'i 'a] ['? '(< i n) ['go '(+ i 1) ['+ 'a (xpr 1 bleaf iop)]] 'a]] 0 0]]          ; counted loop
               12 ['\ 'x [(iop 0) 'x (pick '(1 2)) (pick '(1 2))]]                                 ; the tower ((op x k) k): every arithmetic lane must decline
               ['\ 'x ['? '(< x 1) (bleaf 0) (xpr 2 bleaf iop)]])                                  ; branchy fall-through
   (try f i a) (i % 14 @ 1 (f a a) 10 (f gfz0 a) (f a))   ; two ints for the n-ary leaf, (f n) for the frame call-out
   n0 (peep fires () 0)
   (run i) (: s (shape i)  f (ev s)
              (puts (show i + " " + show s + " => " + show (try f i 0) + " | " + show (try f i 1) + " | " + show (try f i 4) + " | " + show (try f i 100) + " ~" + show (peep FZL 'n 0) + "\n")))
   (each ^3000 run,
    puts ("fires=" + show (peep fires () 0 - n0) + "\n")))
