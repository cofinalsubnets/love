; src/love/compress/inf.l -- inflate's functions as data, with two readers: the C, through clay, and
; the obligations it owes, as uu theorems for test/uuinfvc.l. `make mx` lays both, test_clay diffs.
;
; a spec's integers are nat, so an operation stands for its C only under what it owes: + and << that
; the value fits, - that it does not wrap, a[i] that i is in, a | b that a's low bits are clear and b
; under them. a loop owes its invariants at entry and around, and that its measure falls. a width is
; `inf-pow w` for any w past the type's, never 2^31 written out, which the eager kernel would fold.
; an array is a function; a write is inf-upd, and memset is inf-zero.
(:
   _ (borrow "src/apps/moon/clay.l")

   (lk v k) (atom? v ? () (<<v == k ? >(<v) (lk >v k)))
   (has? v k) (atom? v ? 0 (<<v == k ? 1 (has? >v k)))
   (sub v t) (? (name? t) (has? v t ? (lk v t) t)
                (two? t) ((sub v <t) . (sub v >t))
                t)
   (fit t) ['inf-lt t '(inf-pow w)]
   (quit-on s) (puts "\(s)\n", quit 1)

   ; --- a spec's expressions, as a term and as what they owe -----------------------------------
   (tm sp v e)
    (: (T x) (tm sp v x)
     (? (charm? e) e
        (name? e) (has? v e ? (lk v e) (quit-on "inf: \(e) read before it is set"))
        (e @ ('+ a b) ['add (T a) (T b)]
             ('- a b) ['natminus (T a) (T b)]
             ('at A i) [(has? v A ? (lk v A) A) (T i)]
             ('bit i) ['bit (T i)]
             ('sbit x b) ['inf-sb (T x) (T b)]
             ('pow k) ['inf-pow (T k)]
             ('shl a 1) (T a @ t ['add t t])
             ('shl a 4) ['inf-by16 (T a)]
             ('or a b k) ['add (T a) (T b)]
             ('cast x) (T x)
             ('u16 x) (T x))))
   (ob sp v e)
    (: (T x) (tm sp v x)
       (O x) (ob sp v x)
     (? (atom? e) ()
        (e @ ('+ a b) (O a + O b + [(fit (T e))])
             ('- a b) (O a + O b + [['inf-le (T b) (T a)]])
             ('at A i) (O i + [['inf-lt (T i) (lk (sp 'arrays) A @ a (a 1))]])
             ('bit i) (O i + [['inf-lt (T i) 64]])
             ('sbit x b) (O x + O b + [['inf-lt (T b) 32]])
             ('pow k) (O k + [['inf-lt (T k) 32] (fit (T e))])
             ('shl a k) (O a + [(fit (T e))])
             ('or a b k) (O a + O b + [['paths 'nat ['inf-mod (k = 4 ? 16 2) (T a)] 0]
                                       ['inf-lt (T b) (k = 4 ? 16 2)]
                                       (fit (T e))])
             ('cast x) (O x + [(fit (T x))])
             ('u16 x) (O x + [['inf-lt (T x) (sp 'u16)]]))))
   ; a condition: what it owes, and what its arms may assume. a - b < c means a < c + b
   (cond-ob sp v c) (c @ ('ltsub a b d) (ob sp v a + ob sp v b + ob sp v d
                                         + [(fit (tm sp v a)) (fit (tm sp v b))])
                         ('lt a b) (ob sp v a + ob sp v b)
                         ('le a b) (ob sp v a + ob sp v b)
                         ('nz a) (ob sp v a)
                         ('z a) (ob sp v a))
   (cond-tt sp v c) (c @ ('ltsub a b d) ['inf-lt (tm sp v a) ['add (tm sp v d) (tm sp v b)]]
                         ('lt a b) ['inf-lt (tm sp v a) (tm sp v b)]
                         ('le a b) ['inf-le (tm sp v a) (tm sp v b)]
                         ('nz a) ['inf-lt 0 (tm sp v a)]
                         ('z a) ['paths 'nat (tm sp v a) 0])
   (cond-ff sp v c) (c @ ('ltsub a b d) ['inf-le ['add (tm sp v d) (tm sp v b)] (tm sp v a)]
                         ('lt a b) ['inf-le (tm sp v b) (tm sp v a)]
                         ('le a b) ['inf-lt (tm sp v b) (tm sp v a)]
                         ('nz a) ['paths 'nat (tm sp v a) 0]
                         ('z a) ['inf-lt 0 (tm sp v a)])

   ; --- the walk: a statement's obligations, each with the binders in force, in order -----------
   ; a vc is (label goal . binders); binders is ((name . type) ..), latest first
   (uniq l) (foldl (a \ x \ elem x a ? a (a + [x])) () l)
   (vcs lab gs hy) (map (g \ [lab g hy]) (uniq gs))
   ; what a body writes, whatever the path
   (writes ss)
    (cats (map (s \ s @ (_ 'set x _) [x]
                        (_ 'aset A _ _) [A]
                        (_ 'clear A _) [A]
                        (_ 'if _ _ th) (writes th)
                        (_ 'for x _ _ _ b) (x . writes b)
                        (_ 'forby x _ _ _ _ b) (x . writes b)
                        ())
               ss))
   (mentions? x t) (t == x || two? t && (mentions? x <t || mentions? x >t))
   (loop sp L x from to by invs body rest v hy k)
    (: w (writes body)
       (ty n) (has? (sp 'arrays) n ? '(pi j nat nat) 'nat)
       names (uniq (map (a \ <a) v))
       carried (x . filter (n \ n != x && elem n w) names)
       ; the loop's head: what it writes a fresh name, the rest as they stand
       kept (filter (a \ !(elem <a carried)) v)
       _ (map (a \ any (n \ mentions? n >a) carried ? (quit-on "inf: \(L) rebinds a name \(<a) holds") 0) kept)
       head (map (n \ (n . n)) carried + kept)
       bind (map (n \ (n . ty n)) (rev carried))
       hinv (rev (map (i \ (<i . sub head <>i)) invs))
       nm "\(cx-of hy)-\(L)"
       hy3 (('cx . nm) . (hinv + (bind + hy)))
       TO (tm sp head to)
       entry (map (i \ (sub ((x . tm sp v from) . v) <>i)) invs)
       (back v2 h2)
        (: step (by = () ? ['succ x] ['add x (tm sp v2 by)])
           stepped ((x . step) . v2)
           _ (tm sp stepped to = TO ? 0 (quit-on "inf: \(L)'s bound moves"))
           (vcs "\(L)b" ((by = () ? () (ob sp v2 by)) + [(fit step)]
                         + map (i \ (sub stepped <>i)) invs
                         + [['inf-lt ['natminus TO step] ['natminus TO x]]]) h2))
     (vcs "\(L)e" (ob sp v from + entry) hy
      + [['cx nm (cx-of hy) (rev (hinv + bind + added hy))]]
      + vcs "\(L)h" (ob sp head to) hy3
      + run sp body head ((L . ['inf-lt x TO]) . hy3) back
      + run sp rest head ((L . ['inf-le TO x]) . hy3) k))
   (run sp ss v hy k)
    (atom? ss ? (k v hy)
     (<ss @ (L 'set x e)
             (vcs (show L) (ob sp v e + [(fit (tm sp v e))]) hy
              + run sp >ss ((x . tm sp v e) . v) hy k)
            (L 'let _ ds)
             (: (go ds v)
                 (atom? ds ? (run sp >ss v hy k)
                  (<ds @ [x e] (vcs (show L) (ob sp v e + [(fit (tm sp v e))]) hy
                                + go >ds ((x . tm sp v e) . v))
                         _ (go >ds v)))
                (go ds v))
            (L 'aset A i e)
             (: a (lk (sp 'arrays) A) T (\ x (tm sp v x))
                cap (two? >>a ? ['inf-lt (T e) (a 2)] (fit (T e)))
                (vcs (show L) (ob sp v i + [['inf-lt (T i) (a 1)]] + ob sp v e + [cap]) hy
                 + run sp >ss ((A . ['inf-upd (lk v A) (T i) (T e)]) . v) hy k))
            (L 'clear A _) (run sp >ss ((A . 'inf-zero) . v) hy k)
            (L 'have g p) (: q (sub v p) (vcs (show L) [q] hy + run sp >ss v ((g . q) . hy) k))
            (L 'field _ _) (run sp >ss v hy k)
            (L 'if g c th)
             (vcs (show L) (cond-ob sp v c) hy
              + run sp th v ((g . cond-tt sp v c) . hy) (\ v2 h2 (run sp >ss v2 h2 k))
              + run sp >ss v ((g . cond-ff sp v c) . hy) k)
            (L 'ret e) (vcs (show L) (ob sp v e) hy)
            (L 'retneg _) ()
            (L 'for x from to invs body) (loop sp L x from to () invs body >ss v hy k)
            (L 'forby x from to by invs body) (loop sp L x from to by invs body >ss v hy k)))
   ; each vc numbered within its label, in its order; a path run twice keeps counting
   (number l)
    (: t {}
       (go l)
        (atom? l ? ()
         (<l @ ['cx _ _ _] (<l . go >l)
               [L g h] (: j (1 + peep t L 0) _ (pin t L j)
                        (["\(L)-\(j)" g h] . go >l))))
       (go l))
   ; a declaration with an initial value starts the walk holding it; an array or a parameter, itself
   (start sp)
    (foldl (v \ d \ foldl (v \ x \ two? >x ? ((<x . <>x) . v) v) v >d)
           (map (a \ (<a . <a)) (sp 'arrays + sp 'requires)) (sp 'decls))
   (spec-all sp)
    (: top "inf-\(sp 'short)" rq (map (a \ (<a . <>a)) (sp 'requires))
     (['cx top () rq] . number (run sp (sp 'body) (start sp) [('cx . top)] (\ _ _ ()))))
   (vc? c) (<c != 'cx)
   (spec-vcs sp) (filter vc? (spec-all sp))

   ; --- the theorems: a goal under its binders, its proof under the same lambdas -----------------
   ; a vc stands under its loop's context, with pis and lams for what it adds
   (cx-of hy) (<<hy = 'cx ? >(<hy) (cx-of >hy))
   (added hy) (<<hy = 'cx ? () (<hy . added >hy))
   (close-pi hy g) (added hy @ e (atom? e ? g ('pi . cats (map (b \ [<b >b]) (rev e)) + [g])))
   (close-lam hy t) (added hy @ e (atom? e ? t ('lam . map (b \ <b) (rev e) + [t])))
   (cx-text c)
    (c @ ['cx nm up bs] " (defcx \(nm)\(up = () ? "" " \(up)") \(cats (map (b \ "(\(<b) \(show >b)) ") bs)))\n")
   ; a proof may name a spec's macros, which may name each other
   (expand ms t) (sub ms t @ u (u = t ? t (expand ms u)))
   (vc-text sp)
    (map (c \ (vc? c ?
                 (: lab <c goal (c 1) hy (c 2) cx (cx-of hy)
                    pf (expand (sp 'macros) (peep (sp 'proofs) lab 'tt))
                    "; \(lab)\n (defvc inf-vc-\(sp 'short)-\(lab) (under \(cx) \(show (close-pi hy goal)))\n   (given \(cx) \(show (close-lam hy pf))))\n")
                 (cx-text c)))
         (spec-all sp))
   ; a vc the proofs do not answer, for the author; a proof no vc asks for
   (vc-open sp) (filter (c \ !(peep (sp 'proofs) <c ())) (spec-vcs sp))
   (vc-stale sp) (: ls (map (c \ <c) (spec-vcs sp))
                  (filter (k \ !(elem k ls)) (sort (keys (sp 'proofs)))))

   ; --- the C, through clay ---------------------------------------------------------------------
   (base sp A) (lk (sp 'arrays) A @ a
                (<a @ ('f n) ['dot ['deref ['var "c"]] n]
                      ('v n) ['var n]))
   (cl sp e)
    (: (C x) (cl sp x)
     (? (charm? e) ['num e]
        (name? e) ['var (string e)]
        (e @ ('+ a b) ['bin '+ (C a) (C b)]
             ('- a b) ['bin '- (C a) (C b)]
             ('at A i) ['deref ['bin '+ (base sp A) (C i)]]
             ('bit i) ['cast 'int ['bin '& ['bin 'shr ['var "bb"] (C i)] ['num 1]]]
             ('sbit x b) ['bin '& ['bin 'shr (C x) (C b)] ['num 1]]
             ('pow k) ['bin 'shl ['cast 'uint ['num 1]] (C k)]
             ('shl a k) ['bin 'shl (C a) ['num k]]
             ('or a b k) ['bin '| (C a) (C b)]
             ('cast x) ['cast 'int (C x)]
             ('u16 x) ['cast '(named "uint16_t") (C x)])))
   (cl-cond sp c) (c @ ('ltsub a b d) ['bin 'lt ['bin '- (cl sp a) (cl sp b)] (cl sp d)]
                       ('lt a b) ['bin 'lt (cl sp a) (cl sp b)]
                       ('le a b) ['bin 'le (cl sp a) (cl sp b)]
                       ('nz a) (cl sp a)
                       ('z a) ['un 'not (cl sp a)])
   ; x = x op e goes as x op= e
   (cl-set sp x e)
    (: X ['var (string x)]
     (two? e && elem <e '(+ or shl) && e 1 == x
      ? (e @ ('or _ b _) ['expr ['rmw '| X (cl sp b)]]
             ('+ _ 1) ['expr ['post X 1]]
             ('+ _ b) ['expr ['rmw '+ X (cl sp b)]]
             ('shl _ k) ['expr ['rmw 'shl X ['num k]]])
        ['expr ['asn X (cl sp e)]]))
   (said ss) (filter (s \ s 1 != 'have) ss)
   (cl-body sp ss) (said ss @ [s] (cl-stmt sp s) u ['blk (map (cl-stmt sp) u)])
   (cl-for sp x from to step body)
    (: X ['var (string x)]
     ['for ['expr ['asn X (cl sp from)]] ['bin 'lt X (cl sp to)] step (cl-body sp body)])
   (cl-decl sp ty ds) ['decl (map (x \ [(string <x) ty (two? >x ? (cl sp <>x) ())]) ds)]
   (cl-stmt sp s)
    (s @ (L 'set x e) (cl-set sp x e)
         (L 'let ty ds) (cl-decl sp ty ds)
         (L 'aset A i e)
          (: lhs ['deref ['bin '+ (base sp A) (cl sp i)]]
           (e = ['+ ['at A i] 1] ? ['expr ['post lhs 1]] ['expr ['asn lhs (cl sp e)]]))
         (L 'clear A sz) ['expr ['call ['var "memset"] [(base sp A) ['num 0] sz]]]
         (L 'field f e) ['expr ['asn ['dot ['deref ['var "c"]] f] (cl sp e)]]
         (L 'if g c th) ['if (cl-cond sp c) (cl-body sp th) ()]
         (L 'ret e) ['ret (cl sp e)]
         (L 'retneg n) ['ret ['un 'neg ['num n]]]
         (L 'for x from to invs body) (cl-for sp x from to ['post ['var (string x)] 1] body)
         (L 'forby x from to by invs body) (cl-for sp x from to ['rmw '+ ['var (string x)] (cl sp by)] body))
   (cl-fn sp)
    ['fn (sp 'name) (sp 'params)
         ['blk (map (d \ cl-decl sp <d >d) (sp 'decls) + map (cl-stmt sp) (said (sp 'body)))]
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
     'arrays '((Cn (f "cnt") 16) (Sy (f "sym") n))
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

   ; --- inf_build, prefix.h -----------------------------------------------------------------------
   ; the counts, the offsets, the symbols in code order, and the table. what the caller owes: n symbols
   ; under q, each length at most 15, sym of n and tab of 2^root. it holds over-subscribed or not
   build
    {'name "inf_build" 'short "build"
     'attrs '("static" "inline")
     'ret 'void
     'params '(("c" (ptr (struct "inf_code"))) ("lens" (ptr (const (named "uint8_t")))) ("nsym" uint)
               ("sym" (ptr (named "uint16_t"))) ("tab" (ptr (named "uint16_t"))) ("root" uint))
     'decls '(((arr uint 16) (ofs)) (uint (l) (i) (code 0) (idx 0)))
     'arrays '((Cn (f "cnt") 16 u) (Of (v "ofs") 16) (Sy (v "sym") nsym u) (Tb (v "tab") (inf-pow root) u)
               (Ln (v "lens") nsym))
     'u16 'u
     'requires
      '((Ln (pi k nat nat)) (nsym nat) (root nat) (q nat) (u nat) (w nat)
        (hl (pi k nat g (inf-lt k nsym) (inf-le (Ln k) 15)))
        (gn (inf-lt nsym q))
        (gu (inf-le (inf-by16 q) u))
        (gv (inf-le u (inf-pow w)))
        (gr (inf-le root 15))
        (gw (inf-le 32 w))
        (gc (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w)))))
     'body
      '((d0 let uint ((size (pow root))))
        (c1 clear Cn (szof (dot (deref (var "c")) "cnt")))
        (c2 clear Of (szof (var "ofs")))
        (c3 clear Sy (bin * (cast (named "size_t") (var "nsym")) (szof (deref (var "sym")))))
        (c4 clear Tb (bin * (cast (named "size_t") (var "size")) (szof (deref (var "tab")))))
        (w1 for i 0 nsym
         ((a1 (inf-le i nsym))
          (a2 (pi k nat (paths nat (Cn k) (inf-count Ln k i)))))
         ((s1 aset Cn (at Ln i) (+ (at Cn (at Ln i)) 1))))
        (c5 aset Cn 0 0)
        (ka have hk (pi k nat g (inf-le 1 k) (paths nat (Cn k) (inf-count Ln k nsym))))
        (kb have hs (pi o nat (paths nat (inf-sum Cn o 1) (inf-sum (lam v (inf-count Ln v nsym)) o 1))))
        (kc have hb (pi o nat (inf-le (inf-sum Cn o 1) nsym)))
        (w2 for l 1 15
         ((b1 (inf-le 1 l))
          (b2 (inf-le l 15))
          (b3 (pi o nat g (inf-lt o l) (paths nat (Of (succ o)) (inf-sum Cn o 1)))))
         ((s2 aset Of (+ l 1) (+ (at Of l) (at Cn l)))))
        (w3 for i 0 nsym
         ((e1 (inf-le i nsym))
          (e2 (pi o nat g (inf-lt o 15)
                (paths nat (Of (succ o)) (add (inf-sum Cn o 1) (inf-count Ln (succ o) i)))))
          (e3 (pi k nat (inf-lt (Sy k) q))))
         ((s3 if g3 (nz (at Ln i))
              ((s4 aset Sy (at Of (at Ln i)) (u16 i))
               (s5 aset Of (at Ln i) (+ (at Of (at Ln i)) 1))))))
        (f1 field "sym" sym)
        (f2 field "tab" tab)
        (f3 field "root" root)
        (w4 for l 1 16
         ((h1 (inf-le 1 l))
          (h2 (inf-le (add idx (inf-sum Cn (natminus 16 l) l)) nsym))
          (h3 (inf-le (add code code) (inf-dk idx l))))
         ((w5 for i 0 (at Cn l)
           ((j1 (inf-le i (Cn l)))
            (j2 (inf-le (add (add idx (natminus (Cn l) i)) (inf-sum Cn (natminus 16 (succ l)) (succ l))) nsym))
            (j3 (inf-le (add code code) (inf-dk idx l))))
           ((d1 let uint ((s (at Sy idx)) (rev 0) (b) (j)))
            (s6 set idx (+ idx 1))
            (s7 if g7 (le l root)
                ((w6 for b 0 l
                  ((m1 (inf-le b l))
                   (m2 (inf-lt rev (inf-pow b))))
                  ((s8 set rev (or (shl rev 1) (sbit code b) 1))))
                 (w7 forby j rev size (pow l)
                  ()
                  ((s9 if g9 (z (at Tb j))
                       ((s10 aset Tb j (u16 (or (shl s 4) l 4)))))))))
            (s11 set code (+ code 1))))
          (s12 set code (shl code 1)))))
     'macros
      '((W15 (istransnatleh 15 32 w (idpath false) gw))
        (W16 (istransnatleh 16 32 w (idpath false) gw))
        (Qw (inf-ltle q (inf-pow w) (gc 0 (idpath false))))
        (Nw (inf-lttrans nsym q (inf-pow w) gn Qw))
        (Nu (inf-lttrans nsym q u gn (inf-letrans q (inf-by16 q) u (inf-leby16 q) gu)))
        (Rw (inf-lelt root 15 w gr (inf-lttrans 15 16 w (idpath true) W16)))
        (Cp (inf-upd Cn 0 0))
        (Cl (Cp l))
        (Sa (inf-sum Cp o 1))
        (Sn (inf-sum (lam v (inf-count Ln v nsym)) o 1))
        (Rr (inf-sum Cp (natminus 16 (succ l)) (succ l)))
        (Li (Ln i))
        (Cc (Cn Li))
        (Cx (inf-letr (inf-count Ln Li i) Cc i (pathsinv0 nat Cc (inf-count Ln Li i) (a2 Li)) (inf-cntle Ln Li i)))
        (Cy (inf-lt1 Cc nsym (inf-lelt Cc i nsym Cx w1)))
        (Oi (inf-ofs Ln Cp Of nsym i w3 e2 hs Li (idpath Li) g3 (hl i w3)))
        (Ci (inf-count Ln (succ o) i))
        (Cs (inf-count Ln (succ o) (succ i)))
        (Dn (inf-idxin idx Cl i Rr nsym w5 j2))
        (LE (inf-ltsle l 15 w4))
        (BL (inf-ltsu b l w6))
        (Bw (inf-letrans (succ b) 15 w (inf-letrans (succ b) l 15 BL LE) W15))
        (Sb (inf-sb code b))
        (Bt (inf-modlt 1 (inf-shr code b)))
        (Ry (inf-revstep rev (inf-pow b) Sb m2 Bt))
        (Sx (Sy idx))
        (Ee (add (inf-by16 Sx) l))
        (En (inf-entry Sx l q (e3 idx) w4))
        (Ew (inf-lttrans Ee (inf-by16 q) (inf-pow w) En (inf-letrans (inf-by16 q) u (inf-pow w) gu gv)))
        (Lw (inf-lttrans l 16 w w4 W16))
        (Jf (inf-powfit (add j (inf-pow l)) (succ root) w (inf-tabstep j l root w7 g7) (inf-ltsu root w Rw)))
        (Jm (inf-subby j (inf-pow root) (inf-pow l) w7 (inf-powpos l)))
        (C1 (add code 1))
        (I1 (add idx 1))
        (Dc (inf-code2 code idx l h1 j3))
        (Dq (inf-lelt (inf-dk I1 l) (inf-dk q l) (inf-pow w)
              (inf-dkmono I1 q l (inf-letrans I1 nsym q (inf-lt1 idx nsym Dn) (inf-ltle nsym q gn)))
              (gc l LE)))
        (Cf (inf-lelt C1 (inf-dk I1 l) (inf-pow w) (inf-letrans C1 (add C1 C1) (inf-dk I1 l) (inf-leaddr C1 C1) Dc) Dq))
        (Cb (inf-letr (inf-count Ln l nsym) Cl nsym (pathsinv0 nat Cl (inf-count Ln l nsym) (hk l h1)) (inf-cntle Ln l nsym)))
        (Is (inf-lelt (succ i) nsym (inf-pow w) (inf-letrans (succ i) Cl nsym (inf-ltsu i Cl w5) Cb) Nw))
        (Ii (inf-ltsu i Cl w5))
        (Ix (inf-idxstep idx Cl i Rr nsym w5 j2))
        (Im (inf-subfall Cl i w5))
        (Iq (inf-letrans idx nsym q
              (inf-letrans idx (add idx Rr) nsym (inf-leaddr idx Rr) (inf-idxout idx (natminus Cl i) Rr nsym j2))
              (inf-ltle nsym q gn))))
     'proofs
      {"d0-1" '(inf-lelt root 15 32 gr (idpath true))
       "d0-2" '(inf-powlt root w Rw)
       "w1e-1" '(idpath false)
       "w1e-2" '(lam k (idpath 0))
       "s1-1" 'w1
       "s1-2" '(inf-lelts Li 15 (hl i w1))
       "s1-3" '(inf-lelt (add Cc 1) nsym (inf-pow w) Cy Nw)
       "s1-4" '(inf-lelt (add Cc 1) nsym u Cy Nu)
       "w1b-1" '(inf-lelt (succ i) nsym (inf-pow w) (inf-ltsu i nsym w1) Nw)
       "w1b-2" '(inf-ltsu i nsym w1)
       "w1b-3" '(lam k (inf-cntstep Ln Cn i a2 k))
       "w1b-4" '(inf-subfall nsym i w1)
       "c5-1" '(idpath true)
       "c5-2" '(inf-lelt 0 nsym u (idpath false) Nu)
       "ka-1" '(lam k g (inf-hk Cn Ln i nsym a1 w1 a2 k g))
       "kb-1" '(lam o (inf-sumcong Cp (lam v (inf-count Ln v nsym)) hk o 1 (idpath false)))
       "kc-1" '(lam o (inf-letr Sn Sa nsym (pathsinv0 nat Sa Sn (hs o)) (inf-sumcount Ln o 1 nsym)))
       "w2e-1" '(idpath false)
       "w2e-2" '(idpath false)
       "w2e-3" '(lam o g (inf-o1 Cp o g))
       "s2-1" '(inf-small (add l 1) w (inf-letrans (add l 1) 15 w (inf-lt1 l 15 w2) W15))
       "s2-2" '(inf-lelts (add l 1) 15 (inf-lt1 l 15 w2))
       "s2-3" '(inf-lttrans l 15 16 w2 (idpath false))
       "s2-4" '(inf-lelt (add (Of l) Cl) nsym (inf-pow w)
                 (inf-letr (inf-sum Cp l 1) (add (Of l) Cl) nsym
                   (pathsinv0 nat (add (Of l) Cl) (inf-sum Cp l 1) (inf-sumlast Cp Of l b1 b3)) (hb l))
                 Nw)
       "w2b-1" '(inf-small (succ l) w (inf-letrans (succ l) 15 w (inf-ltsu l 15 w2) W15))
       "w2b-2" '(idpath false)
       "w2b-3" '(inf-ltsu l 15 w2)
       "w2b-4" '(lam o g (inf-ofstep Cp Of l b1 b3 o g))
       "w2b-5" '(inf-subfall 15 l w2)
       "w3e-1" '(idpath false)
       "w3e-2" '(lam o g (pathscomp0 nat (Of (succ o)) Sa (add Sa 0) (b3 o (inf-lttrans o 15 l g w2))
                  (pathsinv0 nat (add Sa 0) Sa (natplusr0 Sa))))
       "w3e-3" '(lam k (inf-lelt 0 nsym q (idpath false) gn))
       "s3-1" 'w3
       "s4-1" 'w3
       "s4-2" '(inf-lelts Li 15 (hl i w3))
       "s4-3" 'Oi
       "s4-4" '(inf-lttrans i nsym u w3 (inf-ltle nsym u Nu))
       "s5-1" 'w3
       "s5-2" '(inf-lelts Li 15 (hl i w3))
       "s5-3" '(inf-lelt (add (Of Li) 1) nsym (inf-pow w) (inf-lt1 (Of Li) nsym Oi) Nw)
       "w3b-1" '(inf-lelt (succ i) nsym (inf-pow w) (inf-ltsu i nsym w3) Nw)
       "w3b-2" '(inf-ltsu i nsym w3)
       "w3b-3" '(lam o g (inf-fillstep Of Ln i Sa o (e2 o g)))
       "w3b-4" '(lam k (inf-uplt Sy (Of Li) i q e3 (inf-lttrans i nsym q w3 (inf-ltle nsym q gn)) k))
       "w3b-5" '(inf-subfall nsym i w3)
       "w3b-6" '(inf-lelt (succ i) nsym (inf-pow w) (inf-ltsu i nsym w3) Nw)
       "w3b-7" '(inf-ltsu i nsym w3)
       "w3b-8" '(lam o g (pathscomp0 nat (Of (succ o)) (add Sa Ci) (add Sa Cs) (e2 o g)
                  (maponpaths nat nat (lam z (add Sa z)) Ci Cs (pathsinv0 nat Cs Ci (inf-fillzero Ln i o g3)))))
       "w3b-9" 'e3
       "w3b-10" '(inf-subfall nsym i w3)
       "w4e-1" '(idpath false)
       "w4e-2" '(hb 15)
       "w4e-3" '(idpath false)
       "w5e-1" '(idpath false)
       "w5e-2" '(inf-idxenter Cp l idx nsym w4 h2)
       "w5e-3" 'h3
       "w5h-1" 'w4
       "d1-1" 'Dn
       "d1-2" '(inf-lttrans Sx q (inf-pow w) (e3 idx) Qw)
       "d1-3" '(inf-powpos w)
       "s6-1" '(inf-lelt I1 nsym (inf-pow w) (inf-lt1 idx nsym Dn) Nw)
       "w6e-1" '(idpath false)
       "w6e-2" '(idpath true)
       "s8-1" '(inf-powfit (add rev rev) (succ b) w (inf-dblfit rev (inf-pow b) m2) Bw)
       "s8-2" '(inf-lttrans b l 32 w6 (inf-ltle l 32 (inf-lttrans l 16 32 w4 (idpath false))))
       "s8-3" '(inf-moddbl rev)
       "s8-4" 'Bt
       "s8-5" '(inf-powfit (add (add rev rev) Sb) (succ b) w Ry Bw)
       "w6b-1" '(inf-small (succ b) w Bw)
       "w6b-2" 'BL
       "w6b-3" 'Ry
       "w6b-4" '(inf-subfall l b w6)
       "s9-1" 'w7
       "s10-1" 'w7
       "s10-2" '(inf-lelt (inf-by16 Sx) Ee (inf-pow w) (inf-leaddr (inf-by16 Sx) l) Ew)
       "s10-3" '(inf-by16low Sx)
       "s10-4" 'w4
       "s10-5" 'Ew
       "s10-6" '(inf-lttrans Ee (inf-by16 q) u En gu)
       "w7b-1" '(inf-lttrans l 16 32 w4 (idpath false))
       "w7b-2" '(inf-powlt l w Lw)
       "w7b-3" 'Jf
       "w7b-4" 'Jm
       "w7b-5" '(inf-lttrans l 16 32 w4 (idpath false))
       "w7b-6" '(inf-powlt l w Lw)
       "w7b-7" 'Jf
       "w7b-8" 'Jm
       "s11-1" 'Cf
       "w5b-1" 'Is
       "w5b-2" 'Ii
       "w5b-3" 'Ix
       "w5b-4" 'Dc
       "w5b-5" 'Im
       "s11-2" 'Cf
       "w5b-6" 'Is
       "w5b-7" 'Ii
       "w5b-8" 'Ix
       "w5b-9" 'Dc
       "w5b-10" 'Im
       "s12-1" '(inf-lelt (add code code) (inf-dk idx l) (inf-pow w) j3
                  (inf-lelt (inf-dk idx l) (inf-dk q l) (inf-pow w) (inf-dkmono idx q l Iq) (gc l LE)))
       "w4b-1" '(inf-small (succ l) w (inf-letrans (succ l) 16 w (inf-ltsu l 16 w4) W16))
       "w4b-2" '(idpath false)
       "w4b-3" '(inf-idxout idx (natminus Cl i) Rr nsym j2)
       "w4b-4" '(inf-dbl (add code code) (inf-dk idx l) j3)
       "w4b-5" '(inf-subfall 16 l w4)}}

   inf-specs [walk build]
   ; test/uuinfvc.l
   inf-vc (cats ["; test/uuinfvc.l -- laid by src/love/compress/inf.l, `make mx`. edit that file.\n(test\n"
                 (cats (map (s \ cats (vc-text s)) inf-specs)) " )\n"])
   inf-h (cats ["// inf_gen.h -- laid by src/love/compress/inf.l, `make mx`. edit that file.\n"
                (cats (map (s \ clay-show (cl-fn s)) inf-specs))])
   inf-ok (all (s \ clay-ok? (cl-fn s) = 1 && atom? (vc-open s) && atom? (vc-stale s)) inf-specs))
