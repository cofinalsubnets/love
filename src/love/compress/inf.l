; src/love/compress/inf.l -- inflate's functions as data, with two readers: the C, through clay, and
; the obligations it owes, as uu theorems for test/uuinfvc.l. `make mx` lays both, test_clay diffs.
;
; a spec's integers are nat, so an operation stands for its C only under what it owes: + and << that
; the value fits, - that it does not wrap, a[i] that i is in, a | b that a's low bits are clear and b
; under them. a loop owes its invariants at entry and around, and that its measure falls. a width is
; `inf-pow w` for any w past the type's, never 2^31 written out, which the eager kernel would fold.
(:
   _ (borrow "src/apps/moon/clay.l")

   (lk v k) (atom? v ? () (<<v == k ? >(<v) (lk >v k)))
   (has? v k) (atom? v ? 0 (<<v == k ? 1 (has? >v k)))
   (sub v t) (? (name? t) (has? v t ? (lk v t) t)
                (two? t) ((sub v <t) . (sub v >t))
                t)
   (fit t) ['inf-lt t '(inf-pow w)]

   ; --- a spec's expressions, as a term and as what they owe -----------------------------------
   (tm sp v e)
    (? (charm? e) e
       (name? e) (has? v e ? (lk v e) (quit-on "inf: \(e) read before it is set"))
       (e @ ('+ a b) ['add (tm sp v a) (tm sp v b)]
            ('- a b) ['natminus (tm sp v a) (tm sp v b)]
            ('at A i) [A (tm sp v i)]
            ('bit i) ['bit (tm sp v i)]
            ('shl a k) (k = 4 ? ['inf-by16 (tm sp v a)] (tm sp v a @ t ['add t t]))
            ('or a b k) ['add (tm sp v a) (tm sp v b)]
            ('cast x) (tm sp v x)))
   (quit-on s) (puts "\(s)\n", quit 1)
   (ob sp v e)
    (: (T x) (tm sp v x)
       (O x) (ob sp v x)
     (? (atom? e) ()
        (e @ ('+ a b) (O a + O b + [(fit (T e))])
             ('- a b) (O a + O b + [['inf-le (T b) (T a)]])
             ('at A i) (O i + [['inf-lt (T i) (lk (sp 'arrays) A @ a (a 1))]])
             ('bit i) (O i + [['inf-lt (T i) 64]])
             ('shl a k) (O a + [(fit (T e))])
             ('or a b k) (O a + O b + [['paths 'nat ['inf-mod (k = 4 ? 16 2) (T a)] 0]
                                       ['inf-lt (T b) (k = 4 ? 16 2)]
                                       (fit (T e))])
             ('cast x) (O x + [(fit (T x))]))))
   ; a condition: what it owes, and what its arms may assume. a - b < c means a < c + b
   (cond-ob sp v c) (c @ ('ltsub a b d) (ob sp v a + ob sp v b + ob sp v d
                                         + [(fit (tm sp v a)) (fit (tm sp v b))])
                         ('lt a b) (ob sp v a + ob sp v b))
   (cond-tt sp v c) (c @ ('ltsub a b d) ['inf-lt (tm sp v a) ['add (tm sp v d) (tm sp v b)]]
                         ('lt a b) ['inf-lt (tm sp v a) (tm sp v b)])
   (cond-ff sp v c) (c @ ('ltsub a b d) ['inf-le ['add (tm sp v d) (tm sp v b)] (tm sp v a)]
                         ('lt a b) ['inf-le (tm sp v b) (tm sp v a)])

   ; --- the walk: a statement's obligations, each with the binders in force, in order -----------
   ; a vc is (label goal . binders); binders is ((name . type) ..), latest first
   (uniq l) (foldl (a \ x \ elem x a ? a (a + [x])) () l)
   (vcs lab gs hy) (map (g \ [lab g hy]) (uniq gs))
   (run sp ss v hy k)
    (atom? ss ? (k v hy)
     (<ss @ (L 'set x e)
             (vcs (show L) (ob sp v e + [(fit (tm sp v e))]) hy
              + run sp >ss ((x . tm sp v e) . v) hy k)
            (L 'if g c th)
             (vcs (show L) (cond-ob sp v c) hy
              + run sp th v ((g . cond-tt sp v c) . hy) (\ _ _ (quit-on "inf: an arm must return"))
              + run sp >ss v ((g . cond-ff sp v c) . hy) k)
            (L 'ret e) (vcs (show L) (ob sp v e) hy)
            (L 'retneg _) ()
            (L 'for x from to invs body)
             (: names (map (a \ <a) v)
                carried (x . names)
                ; the loop's head: every carried name a fresh nat, the cleared ones gone
                head (map (n \ (n . n)) carried)
                bind (map (n \ (n . 'nat)) (rev carried))
                hinv (rev (map (i \ (<i . <>i)) invs))
                hy2 (hinv + (bind + hy))
                guard ['inf-lt x to]
                entry (map (i \ (sub ((x . tm sp v from) . v) <>i)) invs)
                (back v2 h2)
                 (: stepped ((x . ['succ x]) . v2)
                    (vcs "\(L)b" ([(fit ['succ x])] + map (i \ (sub stepped <>i)) invs
                            + [['inf-lt ['natminus to ['succ x]] ['natminus to x]]]) h2))
                (vcs "\(L)e" entry hy
                 + run sp body head ((L . guard) . hy2) back
                 + run sp >ss head ((L . ['inf-le to x]) . hy2) k))))
   ; each vc numbered within its label, in its order
   (number l)
    (: (go l prev i)
        (atom? l ? ()
         (<l @ [L g h] (: j (L = prev ? (i + 1) 1)
                        (["\(L)-\(j)" g h] . go >l L j))))
       (go l () 0))
   ; a declaration with an initial value starts the walk holding it
   (start sp) (foldl (v \ d \ foldl (v \ x \ two? >x ? ((<x . <>x) . v) v) v >d) () (sp 'decls))
   (spec-vcs sp)
    (number (run sp (sp 'body) (start sp) (rev (map (a \ (<a . <>a)) (sp 'requires)))
                 (\ _ _ ())))

   ; --- the theorems: a goal under its binders, its proof under the same lambdas -----------------
   (close-pi hy g) (foldl (t \ b \ ['pi <b >b t]) g hy)
   (close-lam hy t) (foldl (t \ b \ ['lam <b t]) t hy)
   ; a proof may name a spec's macros, which may name each other
   (expand ms t) (sub ms t @ u (u = t ? t (expand ms u)))
   (vc-text sp)
    (map (c \ (: lab <c goal (c 1) hy (c 2)
                 pf (expand (sp 'macros) (peep (sp 'proofs) lab ()))
                 "; \(lab)\n (defq inf-vc-\(sp 'short)-\(lab) \(show (close-pi hy goal))\n   \(show (close-lam hy pf)))\n"))
         (spec-vcs sp))
   ; a vc the proofs do not answer, for the author; a proof no vc asks for
   (vc-open sp) (filter (c \ !(peep (sp 'proofs) <c ())) (spec-vcs sp))
   (vc-stale sp) (: ls (map (c \ <c) (spec-vcs sp))
                  (filter (k \ !(elem k ls)) (sort (keys (sp 'proofs)))))

   ; --- the C, through clay ---------------------------------------------------------------------
   (cl sp e)
    (: (C x) (cl sp x)
     (? (charm? e) ['num e]
        (name? e) ['var (string e)]
        (e @ ('+ a b) ['bin '+ (C a) (C b)]
             ('- a b) ['bin '- (C a) (C b)]
             ('at A i) (lk (sp 'arrays) A @ a
                        ['deref ['bin '+ ['dot ['deref ['var "c"]] (a 0)] (C i)]])
             ('bit i) ['cast 'int ['bin '& ['bin 'shr ['var "bb"] (C i)] ['num 1]]]
             ('shl a k) ['bin 'shl (C a) ['num k]]
             ('or a b k) ['bin '| (C a) (C b)]
             ('cast x) ['cast 'int (C x)])))
   (cl-cond sp c) (c @ ('ltsub a b d) ['bin 'lt ['bin '- (cl sp a) (cl sp b)] (cl sp d)]
                       ('lt a b) ['bin 'lt (cl sp a) (cl sp b)])
   ; x = x op e goes as x op= e
   (cl-set sp x e)
    (: X ['var (string x)]
     (two? e && elem <e '(+ or shl) && e 1 == x
      ? (e @ ('or _ b _) ['expr ['rmw '| X (cl sp b)]]
             ('+ _ b) ['expr ['rmw '+ X (cl sp b)]]
             ('shl _ k) ['expr ['rmw 'shl X ['num k]]])
        ['expr ['asn X (cl sp e)]]))
   (cl-stmt sp s)
    (s @ (L 'set x e) (cl-set sp x e)
         (L 'if g c th) ['if (cl-cond sp c) (cl-stmt sp <th) ()]
         (L 'ret e) ['ret (cl sp e)]
         (L 'retneg n) ['ret ['un 'neg ['num n]]]
         (L 'for x from to invs body)
          ['for ['expr ['asn ['var (string x)] (cl sp from)]]
                ['bin 'lt ['var (string x)] ['num to]]
                ['post ['var (string x)] 1]
                ['blk (map (cl-stmt sp) body)]])
   (cl-fn sp)
    ['fn (sp 'name) (sp 'params)
         ['blk (map (d \ ['decl (map (x \ [(string <x) <d (two? >x ? ['num <>x] ())]) >d)]) (sp 'decls)
                + map (cl-stmt sp) (sp 'body))]
         (sp 'ret) (sp 'attrs)]

   ; --- inf_walk, prefix.h ----------------------------------------------------------------------
   ; a code past the table, read a bit at a time. Cn and Sy are c->cnt and c->sym, bit is what bb
   ; holds. it holds for any counts adding to at most the symbols, whatever bb says
   walk
    {'name "inf_walk" 'short "walk"
     'attrs '("static" "inline")
     'ret 'int
     'params '(("c" (ptr (const (struct "inf_code")))) ("bb" (named "uint64_t")))
     'decls '((int (code 0) (first 0) (index 0) (cnt)) (uint (l)))
     'arrays '((Cn "cnt" 16) (Sy "sym" n))
     'requires
      '((Cn (pi i nat nat)) (Sy (pi i nat nat)) (bit (pi i nat nat)) (n nat) (h nat) (w nat)
        (b1 (pi i nat (inf-le (bit i) 1)))
        (hc (pi i nat (inf-lt (Cn i) (inf-pow h))))
        (hs (pi i nat (inf-lt (Sy i) (inf-pow h))))
        (gh (inf-le h 16))
        (gw (inf-le 31 w))
        (gn (inf-lt n (inf-pow w)))
        (gs (inf-le (inf-sum Cn 15 1) n)))
     'body
      '((w1 for l 1 16
         ((i1 (inf-le 1 l))
          (i2 (inf-le first code))
          (i3 (inf-le (add code 2) (inf-pow l)))
          (i4 (paths nat (inf-mod 2 code) 0))
          (i5 (inf-le (add index (inf-sum Cn (natminus 16 l) l)) n)))
         ((s1 set code (or code (bit (- l 1)) 1))
          (s2 set cnt (at Cn l))
          (s3 if g3 (ltsub code cnt first)
              ((s4 ret (or (shl (cast (at Sy (+ index (- code first)))) 4) (cast l) 4))))
          (s5 set index (+ index cnt))
          (s6 set first (shl (+ first cnt) 1))
          (s7 set code (shl code 1))))
        (r1 retneg 1))
     'macros
      '((Bi (bit (natminus l 1)))
        (C1 (add code Bi))
        (D1 (add C1 C1))
        (F1 (add first (Cn l)))
        (Ix (add index (natminus C1 first)))
        (S1 (Sy Ix))
        (Lw (inf-lew l w w1 gw))
        (Hw (istransnatleh h 16 w gh (istransnatleh 16 31 w (idpath false) gw)))
        (Cl (inf-wor code Bi (inf-pow l) (b1 (natminus l 1)) i3))
        (Cf (inf-powfit C1 l w Cl Lw))
        (Nf (inf-powfit (Cn l) h w (hc l) Hw))
        (Fc (istransnatleh first code C1 i2 (inf-leaddr code Bi)))
        (Nx (inf-sumhead Cn 16 l index n w1 i5))
        (In (inf-lttrans Ix (add index (Cn l)) n
              (inf-ltaddl index (natminus C1 first) (Cn l) (inf-subshort first C1 (Cn l) Fc g3))
              Nx))
        (Sh (inf-wsh code Bi (inf-pow l) (b1 (natminus l 1)) i3))
        (Df (inf-powfit D1 (succ l) w
              (inf-lttrans D1 (add D1 2) (inf-pow (succ l)) (inf-lt2 D1) Sh)
              (istransnatleh (succ l) 16 w (inf-ltsu l 16 w1) (istransnatleh 16 31 w (idpath false) gw))))
        (Eo (inf-by16or S1 l h w (hs Ix) w1 gh gw)))
     'proofs
      {"w1e-1" '(idpath false)
       "w1e-2" '(idpath false)
       "w1e-3" '(idpath false)
       "w1e-4" '(idpath 0)
       "w1e-5" 'gs
       "s1-1" 'i1
       "s1-2" '(inf-lelt (natminus l 1) l 64 (inf-suble l 1) (inf-lttrans l 16 64 w1 (idpath false)))
       "s1-3" 'i4
       "s1-4" '(inf-lelts Bi 1 (b1 (natminus l 1)))
       "s1-5" 'Cf
       "s2-1" 'w1
       "s2-2" 'Nf
       "s3-1" 'Cf
       "s3-2" 'Nf
       "s4-1" 'Fc
       "s4-2" '(inf-lttrans Ix n (inf-pow w) In (inf-ltle n (inf-pow w) gn))
       "s4-3" 'In
       "s4-4" '(inf-powfit S1 h w (hs Ix) Hw)
       "s4-5" '(inf-lelt (inf-by16 S1) (add (inf-by16 S1) l) (inf-pow w) (inf-leaddr (inf-by16 S1) l) Eo)
       "s4-6" '(inf-lttrans l 16 (inf-pow w) w1 (inf-powle 4 w (istransnatleh 4 31 w (idpath false) gw)))
       "s4-7" '(inf-by16low S1)
       "s4-8" 'w1
       "s4-9" 'Eo
       "s5-1" '(inf-lelt (add index (Cn l)) n (inf-pow w) Nx gn)
       "s6-1" '(inf-lelt F1 C1 (inf-pow w) g3 Cf)
       "s6-2" '(inf-lelt (add F1 F1) D1 (inf-pow w) (inf-dbl F1 C1 g3) Df)
       "s7-1" 'Df
       "w1b-1" '(inf-lelt (succ l) 16 (inf-pow w) (inf-ltsu l 16 w1)
                  (inf-lttrans 16 32 (inf-pow w) (idpath true)
                    (inf-powle 5 w (istransnatleh 5 31 w (idpath false) gw))))
       "w1b-2" '(idpath false)
       "w1b-3" '(inf-dbl F1 C1 g3)
       "w1b-4" 'Sh
       "w1b-5" '(inf-moddbl C1)
       "w1b-6" '(inf-sumnext Cn 16 l index n w1 i5)
       "w1b-7" '(inf-subfall 16 l w1)}}

   inf-specs [walk]
   ; test/uuinfvc.l
   inf-vc (cats ["; test/uuinfvc.l -- laid by src/love/compress/inf.l, `make mx`. edit that file.\n(test\n"
                 (cats (map (s \ cats (vc-text s)) inf-specs)) " )\n"])
   inf-h (cats ["// inf_gen.h -- laid by src/love/compress/inf.l, `make mx`. edit that file.\n"
                (cats (map (s \ clay-show (cl-fn s)) inf-specs))])
   inf-ok (all (s \ clay-ok? (cl-fn s) = 1 && atom? (vc-open s) && atom? (vc-stale s)) inf-specs))
