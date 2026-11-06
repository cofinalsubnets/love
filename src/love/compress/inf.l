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
             ('u16 x) (T x)
             ('u8 x) (T x)
             ('mask x k) ['inf-mod ['inf-pow (T k)] (T x)]
             ('low x m) ['inf-mod (m + 1) (T x)]
             ('div8 x) ['inf-div8 (T x)]
             ('or56 x) ['add 56 ['inf-mod 8 (T x)]])))
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
             ('u16 x) (O x + [['inf-lt (T x) (sp 'u16)]])
             ('u8 x) (O x + [['inf-lt (T x) 256]])
             ('mask x k) (O x + O k + [['inf-lt (T k) 32]])
             ('low x _) (O x)
             ('div8 x) (O x)
             ('or56 x) (O x + [['inf-le (T x) 63]])
             ; the bit buffer's, whose values no law reads: only what they owe
             ('ld64 A i) (O i + [['inf-le ['add (T i) 8] (lk (sp 'arrays) A @ a (a 1))]])
             ('w64 x) (O x)
             ('shl64 a k) (O a + O k + [['inf-lt (T k) 64]])
             ('shr64 a k) (O a + O k + [['inf-lt (T k) 64]])
             ('bor64 a b) (O a + O b)
             ('bxor a b) (O a + O b)
             ('rep8 x) (O x)
             ('le16 A i) (O i + [['inf-le ['add (T i) 2] (lk (sp 'arrays) A @ a (a 1))]]))))
   ; a condition: what it owes, and what its arms may assume. a - b < c means a < c + b
   (cond-ob sp v c) (c @ ('ltsub a b d) (ob sp v a + ob sp v b + ob sp v d
                                         + [(fit (tm sp v a)) (fit (tm sp v b))])
                         ('lt a b) (ob sp v a + ob sp v b)
                         ('le a b) (ob sp v a + ob sp v b)
                         ('nz a) (ob sp v a)
                         ('z a) (ob sp v a)
                         ('ne a b) (ob sp v a + ob sp v b)
                         ('eq a b) (ob sp v a + ob sp v b)
                         ('wide d) (ob sp v d)
                         ('widec d) (ob sp v d)
                         ('tru) ())
   (cond-tt sp v c) (c @ ('ltsub a b d) ['inf-lt (tm sp v a) ['add (tm sp v d) (tm sp v b)]]
                         ('lt a b) ['inf-lt (tm sp v a) (tm sp v b)]
                         ('le a b) ['inf-le (tm sp v a) (tm sp v b)]
                         ('nz a) ['inf-lt 0 (tm sp v a)]
                         ('z a) ['paths 'nat (tm sp v a) 0]
                         ('ne _ _) 'unit
                         ('eq _ _) 'unit
                         ('wide d) ['inf-le 8 (tm sp v d)]
                         ('widec _) 'unit
                         ('tru) 'unit)
   (cond-ff sp v c) (c @ ('ltsub a b d) ['inf-le ['add (tm sp v d) (tm sp v b)] (tm sp v a)]
                         ('lt a b) ['inf-le (tm sp v b) (tm sp v a)]
                         ('le a b) ['inf-lt (tm sp v b) (tm sp v a)]
                         ('nz a) ['paths 'nat (tm sp v a) 0]
                         ('z a) ['inf-lt 0 (tm sp v a)]
                         ('ne _ _) 'unit
                         ('eq _ _) 'unit
                         ('wide _) 'unit
                         ('widec _) 'unit)

   ; --- the walk: a statement's obligations, each with the binders in force, in order -----------
   ; a vc is (label goal . binders); binders is ((name . type) ..), latest first
   (uniq l) (foldl (a \ x \ elem x a ? a (a + [x])) () l)
   (vcs lab gs hy) (map (g \ [lab g hy]) (uniq gs))
   ; what a body writes, whatever the path
   (writes sp ss)
    (cats (map (s \ s @ (_ 'set x _) [x]
                        (_ 'dec x _) [x]
                        (_ 'aset A _ _) [A]
                        (_ 'clear A _) [A]
                        (_ 'if _ _ th) (writes sp th)
                        (_ 'ife _ _ th el) (writes sp th + writes sp el)
                        (_ 'while _ _ _ b) (writes sp b)
                        (_ 'havoc x _) [x]
                        (_ 'gset x _) [x]
                        (_ 'join _ _ th el _) (writes sp th + writes sp el)
                        (_ 'call f _ _ os) (written (callee sp f) os)
                        (_ 'try x f _ _ os) (x . written (callee sp f) os)
                        (_ 'tryr x f _ _ os _) (x . written (callee sp f) os)
                        (_ 'for x _ _ _ b) (x . writes sp b)
                        (_ 'forby x _ _ _ _ b) (x . writes sp b)
                        ())
               ss))
   (written f os) (map (a \ <a) (f 'state) + map (a \ <>a) os)
   (mentions? x t) (t == x || two? t && (mentions? x <t || mentions? x >t))
   (loop sp L x from to by invs body rest v hy k)
    (: w (writes sp body)
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
   ; a loop with no counter: its condition holds in the body, and the measure falls around it.
   ; a break leaves with what stands there, no condition learned
   (wloop sp L c m invs body rest v hy k)
    (: w (writes sp body)
       (ty n) (has? (sp 'arrays) n ? '(pi j nat nat) 'nat)
       names (uniq (map (a \ <a) v))
       carried (filter (n \ elem n w) names)
       kept (filter (a \ !(elem <a carried)) v)
       _ (map (a \ any (n \ mentions? n >a) carried ? (quit-on "inf: \(L) rebinds a name \(<a) holds") 0) kept)
       head (map (n \ (n . n)) carried + kept)
       bind (map (n \ (n . ty n)) (rev carried))
       hinv (rev (map (i \ (<i . sub head <>i)) invs))
       nm "\(cx-of hy)-\(L)"
       hy3 (('cx . nm) . (hinv + (bind + hy)))
       M (sub head m)
       entry (map (i \ (sub v <>i)) invs)
       (back v2 h2) (vcs "\(L)b" (map (i \ (sub v2 <>i)) invs + [['inf-lt (sub v2 m) M]]) h2)
       (after v2 h2) (run sp rest v2 h2 k)
       up (sp 'brk)
       _ (pin sp 'brk after)
       inner (run sp body head ((L . cond-tt sp head c) . hy3) back)
       _ (pin sp 'brk up)
     (vcs "\(L)e" entry hy
      + [['cx nm (cx-of hy) (rev (hinv + bind + added hy))]]
      + vcs "\(L)h" (cond-ob sp head c) hy3
      + inner
      + (c = '(tru) ? () (run sp rest head ((L . cond-ff sp head c) . hy3) k))))
   ; a call owes what its callee requires, for these arguments; what it writes comes back fresh,
   ; under what it ensures. a binder of the callee's may not catch an argument
   (binders t) (two? t ? ((<t == 'pi || <t == 'lam) ? (alts >t + binders >t) (binders <t + binders >t)) ())
   (alts l) (two? l && two? >l ? (<l . alts >>l) ())
   (callsub m t)
    (: _ (map (b \ any (a \ mentions? b >a) m ? (quit-on "inf: \(b) would catch an argument") 0) (binders t))
     (sub m t))
   (fresh L x) (intern "\(x)\(L)")
   ; what a call or a join adds stands in a context of its own, so what follows does not spell it again
   (cxed sp hy k)
    (atom? (added hy) ? (k hy)
     (: n (1 + peep sp 'cxn 0) _ (pin sp 'cxn n)
        nm "inf-\(sp 'short)-c\(n)"
      (['cx nm (cx-of hy) (rev (added hy))] . k (('cx . nm) . hy))))
   (call sp L f inst os res v hy cont)
    (: st (f 'state)
       args (map (a \ two? a ? (<a . sub v <>a) (a . sub v a)) inst)
       pre (map (a \ (<>a . lk v <a)) st + args)
       data (map (a \ <a) pre)
       owed (filter (r \ !(elem <r data)) (f 'requires))
       after (map (a \ (<a . fresh L <a)) st + map (a \ (<a . fresh L <>a)) os)
       post (after + (res = () ? () [('res . res)]) + pre)
       v2 (map (a \ (<a . fresh L <a)) st + map (a \ (<>a . fresh L <>a)) os + v)
       bs ((res = () ? () [(res . 'nat)]) + rev (map (a \ (>a . (has? (f 'arrays) <a ? '(pi j nat nat) 'nat))) after))
       hs (rev (map (e \ (intern "\(L)\(<e)" . callsub post <>e)) (f 'ensures)))
     (vcs (show L) (map (r \ callsub pre <>r) owed) hy
      + cxed sp (hs + bs + hy) (\ h (cont v2 h))))
   (run sp ss v hy k)
    (atom? ss ? (k v hy)
     (<ss @ (L 'set x e)
             (vcs (show L) (ob sp v e + [(fit (tm sp v e))]) hy
              + run sp >ss ((x . tm sp v e) . v) hy k)
            ; x - y does not wrap, and fits where x did
            (L 'dec x e)
             (vcs (show L) (ob sp v e) hy + run sp >ss ((x . tm sp v e) . v) hy k)
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
            (L 'ife g c th el)
             (: (on v2 h2) (run sp >ss v2 h2 k)
              (vcs (show L) (cond-ob sp v c) hy
               + run sp th v ((g . cond-tt sp v c) . hy) on
               + run sp el v ((g . cond-ff sp v c) . hy) on))
            ; two arms meet once: what either writes comes back fresh, under what both establish
            (L 'join g c th el invs)
             (: w (uniq (filter (n \ has? v n || any (i \ mentions? n <>i) invs) (writes sp th + writes sp el)))
                _ (map (a \ any (n \ mentions? n >a) w ? (quit-on "inf: \(L) rebinds a name \(<a) holds") 0) (filter (a \ !(elem <a w)) v))
                v3 (map (n \ (n . fresh L n)) w + v)
                (ty n) (has? (sp 'arrays) n ? '(pi j nat nat) 'nat)
                bs (rev (map (n \ (fresh L n . ty n)) w))
                hs (rev (map (i \ (<i . sub v3 <>i)) invs))
                (meet v2 h2) (vcs "\(L)j" (map (i \ sub v2 <>i) invs) h2)
              (vcs (show L) (cond-ob sp v c) hy
               + run sp th v ((g . cond-tt sp v c) . hy) meet
               + run sp el v ((g . cond-ff sp v c) . hy) meet
               + cxed sp (hs + bs + hy) (\ h (run sp >ss v3 h k))))
            (L 'store _ _) (run sp >ss v hy k)
            (L 'gset x e) (run sp >ss ((x . sub v e) . v) hy k)
            (L 'while c m invs body) (wloop sp L c m invs body >ss v hy k)
            (L 'brk) ((sp 'brk) v hy)
            (L 'havoc x e)
             (: y (fresh L x)
              (vcs (show L) (ob sp v e) hy + run sp >ss ((x . y) . v) ((y . 'nat) . hy) k))
            (L 'ghost x e g) (run sp >ss ((x . x) . v) ((g . ['paths 'nat x (sub v e)]) . ((x . 'nat) . hy)) k)
            (L 'poke A i e) (vcs (show L) (ob sp v i + [['inf-lt (tm sp v i) (lk (sp 'arrays) A @ a (a 1))]] + ob sp v e) hy
                             + run sp >ss v hy k)
            (L 'pokew A i e) (vcs (show L) (ob sp v i + [['inf-le ['add (tm sp v i) 8] (lk (sp 'arrays) A @ a (a 1))]] + ob sp v e) hy
                              + run sp >ss v hy k)
            (L 'mcopy A i B j n)
             (: bound (\ X (lk (sp 'arrays) X @ a (a 1)))
              (vcs (show L) (ob sp v i + ob sp v j + ob sp v n
                             + [['inf-le ['add (tm sp v i) (tm sp v n)] (bound A)]
                                ['inf-le ['add (tm sp v j) (tm sp v n)] (bound B)]]) hy
               + run sp >ss v hy k))
            (L 'call f as inst os) (call sp L (callee sp f) inst os () v hy (\ v2 h2 (run sp >ss v2 h2 k)))
            (L 'try x f as inst os)
             (: y (fresh L x)
              (call sp L (callee sp f) inst os y v hy
               (\ v2 h2 (run sp >ss ((x . y) . v2) h2 k))))
            (L 'tryr x f as inst os _)
             (: y (fresh L x)
              (call sp L (callee sp f) inst os y v hy
               (\ v2 h2 (run sp >ss ((x . y) . v2) h2 k))))
            (L 'ret e) (vcs (show L) (ob sp v e + ensured sp ((tm-res sp v e) . v)) hy)
            (L 'retneg _) ()
            (L 'for x from to invs body) (loop sp L x from to () invs body >ss v hy k)
            (L 'forby x from to by invs body) (loop sp L x from to by invs body >ss v hy k)
            (quit-on "inf: \(sp 'short) has a statement the walk cannot read: \(show <ss)")))
   (callee sp f) (<(filter (c \ c 'name = f) (sp 'calls)))
   (ensured sp v) (map (e \ sub v <>e) (sp 'ensures))
   (tm-res sp v e) ('res . tm sp v e)
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
    (foldl (v \ d \ foldl (v \ x \ two? >x && !(two? <>x && <<>x == 'raw) ? ((<x . <>x) . v) v) v >d)
           (map (a \ (<a . <>a)) (sp 'state) + map (a \ (<a . <a)) (sp 'arrays + sp 'requires)) (sp 'decls))
   (spec-all sp)
    (: top "inf-\(sp 'short)" rq (map (a \ (<a . <>a)) (sp 'requires))
       _ (pin sp 'cxn 0)
     (['cx top () rq] . number (run sp (sp 'body) (start sp) [('cx . top)] (\ v hy (vcs "end" (ensured sp v) hy)))))
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
   ; what needs no author: a hypothesis as it stands, one a step weaker, x <= x, or a closed comparison.
   ; the kernel checks these like any other
   (lit? t) (charm? t && 0 <= t)
   ; a term with its pi binders numbered, so two that differ only in those compare equal
   (canon t)
    (: (bind l i) (atom? >l ? [canon <l]
                   (: x (intern "_\(i)") (canon (l 1) . x . bind (sub [(<l . x)] >>l) (i + 1))))
     (two? t ? (<t == 'pi ? ('pi . bind >t 0) (map canon t)) t))
   (auto sp hy g)
    (: bs (filter (b \ <b != 'cx) hy + map (r \ (<r . <>r)) (sp 'requires))
       (held t) (: c (canon t) (filter (b \ canon >b = c) bs @ m (two? m ? <<m ())))
       ; a <= b through what is held: a stated step, x - y <= x, x <= x + y
       (ups a) (cats (map (b \ >b @ ['inf-le x y] (x = a ? [[y <b]] ()) ['inf-lt x y] (x = a ? [[y ['inf-ltle x y <b]]] ()) ()) bs)
                + (a @ ['natminus x y] [[x ['inf-suble x y]]]
                       ['inf-mod p x] (lit? p && 0 < p
                                       ? ([[(p - 1) ['inf-ltsle a (p - 1) ['inf-modlt (p - 1) x]]]]
                                          + (p = 8 ? [[x ['inf-modle8 x]]] ()))
                                       ())
                       ()))
       (chain a b d)
        (? (a = b) ['inf-refl a]
           (d < 1) ()
           (held ['inf-le a b]) (held ['inf-le a b])
           (lit? a && lit? b) (a <= b ? '(idpath false) ())
           (: viaadd (b @ ['add x y] (chain a x (d - 1) @ p (p ? ['inf-letrans a x b p ['inf-leaddr x y]] ())) ())
              (go l) (atom? l ? ()
                      (: e <l m <e
                         r (m = a ? () (chain m b (d - 1)))
                         (r ? ['inf-letrans a m b (e 1) r] (go >l))))
              (viaadd ? viaadd (go (ups a)))))
     (g @ ('inf-le a b)
           (? (a == 0) '(idpath false)
              (lit? a && lit? b) (a <= b ? '(idpath false) ())
              (chain a b 4))
          ('inf-lt a ('inf-pow w))
           (: gw (held ['inf-le 32 w])
            (? (held g) (held g)
               !gw ()
               (lit? a) (a <= 63 ? ['inf-wlit a w gw '(idpath false)] ())
               (chain a 63 4) ['inf-wlit a w gw (chain a 63 4)]
               ; under anything that fits
               (: (go l) (atom? l ? ()
                          (: t >(<l)
                             r (t @ ['inf-lt u ['inf-pow x]] (x = w ? (chain a u 4) ()) ())
                             (r ? ['inf-lelt a (t 1) (t 2) r <<l] (go >l))))
                (go bs))))
          ('inf-bits-inv c ip ('add cons k) ('natminus bc k2))
           (: i (held ['inf-bits-inv c ip cons bc])
              p (k = k2 ? (chain k bc 3) ())
            (i && p ? ['inf-take c ip cons bc k p i] (held g)))
          ('inf-lt a b)
           (? (lit? a && lit? b) (a < b ? '(idpath true) ())
              (held g) (held g)
              (lit? b && 0 < b) (chain a (b - 1) 4 @ p (p ? ['inf-lelts a (b - 1) p] ()))
              ())
          (held g)))
   (proof-of sp c) (peep (sp 'proofs) <c () @ p (p ? p (auto sp (c 2) (c 1))))
   ; a proof may name a spec's macros, which may name each other
   (expand ms t) (sub ms t @ u (u = t ? t (expand ms u)))
   (vc-text sp)
    (map (c \ (vc? c ?
                 (: lab <c goal (c 1) hy (c 2) cx (cx-of hy)
                    pf (expand (sp 'macros) (proof-of sp c @ p (p ? p 'tt)))
                    "; \(lab)\n (defvc inf-vc-\(sp 'short)-\(lab) (under \(cx) \(show (close-pi hy goal)))\n   (given \(cx) \(show (close-lam hy pf))))\n")
                 (cx-text c)))
         (spec-all sp))
   ; a vc the proofs do not answer, for the author; a proof no vc asks for
   (vc-open sp) (filter (c \ !(proof-of sp c)) (spec-vcs sp))
   (vc-stale sp) (: ls (map (c \ <c) (spec-vcs sp))
                  (filter (k \ !(elem k ls)) (sort (keys (sp 'proofs)))))

   ; --- the C, through clay ---------------------------------------------------------------------
   (base sp A) (lk (sp 'arrays) A @ a
                (<a @ ('f n) ['dot ['deref ['var "c"]] n]
                      ('r n) ['dot ['deref ['var "r"]] n]
                      ('s n) ['dot ['deref ['var "s"]] n]
                      ('t n) ['dot ['deref ['dot ['deref ['var "r"]] "t"]] n]
                      ('v n) ['var n]))
   ; a name the struct holds, or a local
   (cv sp x) (? (elem x (sp 'fields)) ['dot ['deref ['var "r"]] (string x)]
                (elem x (sp 'sfields)) ['dot ['deref ['var "s"]] (string x)]
                ['var (string x)])
   (cl sp e)
    (: (C x) (cl sp x)
     (? (charm? e) ['num e]
        (name? e) (cv sp e)
        (e @ ('+ a b) ['bin '+ (C a) (C b)]
             ('- a b) ['bin '- (C a) (C b)]
             ('at A i) ['deref ['bin '+ (base sp A) (C i)]]
             ('bit i) ['cast 'int ['bin '& ['bin 'shr ['var "bb"] (C i)] ['num 1]]]
             ('sbit x b) ['bin '& ['bin 'shr (C x) (C b)] ['num 1]]
             ('pow k) ['bin 'shl ['cast 'uint ['num 1]] (C k)]
             ('shl a k) ['bin 'shl (C a) ['num k]]
             ('or a b k) ['bin '| (C a) (C b)]
             ('cast x) ['cast 'int (C x)]
             ('u16 x) ['cast '(named "uint16_t") (C x)]
             ('u8 x) ['cast '(named "uint8_t") (C x)]
             ('mask x k) ['bin '& (C x) ['bin '- ['bin 'shl ['cast 'uint ['num 1]] (C k)] ['num 1]]]
             ('low x m) ['bin '& (C x) ['num m]]
             ('div8 x) ['bin 'shr (C x) ['num 3]]
             ('or56 x) ['bin '| (C x) ['num 56]]
             ('ld64 A i) ['call ['var "LD64"] [['bin '+ (base sp A) (C i)]]]
             ('w64 x) ['cast '(named "uint64_t") (C x)]
             ('shl64 a k) ['bin 'shl (C a) (C k)]
             ('shr64 a k) ['bin 'shr (C a) (C k)]
             ('bor64 a b) ['bin '| (C a) (C b)]
             ('bxor a b) ['bin '^ (C a) (C b)]
             ('rep8 x) ['bin '* ['cast '(named "uint64_t") ['num 72340172838076673]] ['cast '(named "uint64_t") (C x)]]
             ('le16 A i) ['bin '| ['deref ['bin '+ (base sp A) (C i)]]
                               ['bin 'shl ['cast 'uint ['deref ['bin '+ (base sp A) ['bin '+ (C i) ['num 1]]]]] ['num 8]]]
             ('tf n) ['dot ['deref ['dot ['deref ['var "r"]] "t"]] n]
             ('taddr n) ['addr ['dot ['deref ['dot ['deref ['var "r"]] "t"]] n]]
             ('raw x) x)))
   (cl-cond sp c) (c @ ('ltsub a b d) ['bin 'lt ['bin '- (cl sp a) (cl sp b)] (cl sp d)]
                       ('lt a b) ['bin 'lt (cl sp a) (cl sp b)]
                       ('le a b) ['bin 'le (cl sp a) (cl sp b)]
                       ('nz a) (cl sp a)
                       ('z a) ['un 'not (cl sp a)]
                       ('ne a b) ['bin 'ne (cl sp a) (cl sp b)]
                       ('eq a b) ['bin 'eq (cl sp a) (cl sp b)]
                       ('wide d) ['land ['var "wideld"] ['bin 'le ['num 8] (cl sp d)]]
                       ('widec d) ['land ['var "wideld"] ['bin 'eq (cl sp d) ['num 1]]]
                       ('tru) ['num 1])
   ; x = x op e goes as x op= e
   (cl-set sp x e)
    (: X (cv sp x)
     (two? e && elem <e '(+ or shl bor64 shr64 or56) && e 1 == x
      ? (e @ ('or _ b _) ['expr ['rmw '| X (cl sp b)]]
             ('bor64 _ b) ['expr ['rmw '| X (cl sp b)]]
             ('shr64 _ k) ['expr ['rmw 'shr X (cl sp k)]]
             ('or56 _) ['expr ['rmw '| X ['num 56]]]
             ('+ _ 1) ['expr ['post X 1]]
             ('+ _ b) ['expr ['rmw '+ X (cl sp b)]]
             ('shl _ k) ['expr ['rmw 'shl X ['num k]]])
        ['expr ['asn X (cl sp e)]]))
   (said ss)
    (cats (map (s \ s @ (_ 'have _ _) ()
                        (_ 'ghost _ _ _) ()
                        (_ 'gset _ _) ()
                        (L 'try x f as _ _) [[L 'set-call x f as] [L 'if-neg x]]
                        (L 'tryr x f as _ _ c) [[L 'set-call x f as] [L 'if-negr x c]]
                        [s])
               ss))
   (cl-body sp ss) (said ss @ [s] (cl-stmt sp s) u ['blk (map (cl-stmt sp) u)])
   (cl-blk sp ss) ['blk (map (cl-stmt sp) (said ss))]
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
         (L 'join g c th el _) ['if (cl-cond sp c) (cl-blk sp th) (el == () ? () (cl-blk sp el))]
         (L 'ife g c th el) ['if (cl-cond sp c) (cl-blk sp th) (cl-blk sp el)]
         (L 'while c m invs b) ['while (cl-cond sp c) (cl-blk sp b)]
         (L 'brk) ['brk]
         (L 'store f e) ['expr ['asn ['dot ['deref ['var "r"]] f] (cl sp e)]]
         (L 'havoc x e) (cl-set sp x e)
         (L 'dec x e) (cl-set sp x e)
         (L 'poke A i e) ['expr ['asn ['deref ['bin '+ (base sp A) (cl sp i)]] (cl sp e)]]
         (L 'pokew A i e) ['expr ['call ['var "ST64"] [['bin '+ (base sp A) (cl sp i)] (cl sp e)]]]
         (L 'mcopy A i B j n) ['expr ['call ['var "memcpy"] [['bin '+ (base sp A) (cl sp i)] ['bin '+ (base sp B) (cl sp j)] (cl sp n)]]]
         (L 'call f as _ _) ['expr ['call ['var f] (map (cl sp) as)]]
         (L 'set-call x f as) ['expr ['asn (cv sp x) ['call ['var f] (map (cl sp) as)]]]
         (L 'if-neg x) ['if ['bin 'lt (cv sp x) ['num 0]] ['ret (cv sp x)] ()]
         (L 'if-negr x c) ['if ['bin 'lt (cv sp x) ['num 0]] ['ret ['un 'neg ['num c]]] ()]
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
     'ensures '((e1 (inf-lt res (inf-pow w))))
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
     'ensures
      '((e1 (pi z nat (inf-lt (Cn z) u)))
        (e2 (pi z nat (inf-lt (Sy z) u)))
        (e3 (inf-le (inf-sum Cn 15 1) nsym)))
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
       "w4b-5" '(inf-subfall 16 l w4)
       "end-1" '(inf-cphi Cp Ln nsym u hk (inf-lelt 0 nsym u (idpath false) Nu) Nu)
       "end-2" '(lam z (inf-lttrans (Sy z) q u (e3 z) (inf-letrans q (inf-by16 q) u (inf-leby16 q) gu)))
       "end-3" '(hb 15)}}

   ; --- the bit reader, inflate.h ---------------------------------------------------------------
   ; n bytes at in; ip read so far, bc of them buffered in bb and cons consumed. a call leaves the
   ; reader sound: nothing past n, nothing lost, and consumption only grows
   rd-req
    '((In (pi k nat nat)) (n nat) (w nat) (carry nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat)
      (gw (inf-le 32 w))
      (gn (inf-lt (add n 8) (inf-pow w)))
      (gi (inf-le ip0 n))
      (gs (inf-le bc0 63))
      (ga (inf-bits-inv carry ip0 cons0 bc0)))
   rd-state '((ip ip0) (bc bc0) (bb bb0) (cons cons0))
   rd-ens
    '((e1 (inf-le ip n))
      (e3 (inf-le bc 63))
      (e4 (inf-bits-inv carry ip cons bc))
      (e5 (inf-le cons0 cons)))
   ; a stream read at one go: nothing came before its bytes
   (one-go l) (sub [('carry . 0)] (filter (r \ <r != 'carry) l))
   rd-fields '(ip bc bb n)
   rd-params '(("r" (ptr (struct "inf_rd"))))
   rd-arrays '((In (r "in") n))
   rd-arg '((raw (var "r")))
   rd-macs
    '((Nw (inf-lelt n (add n 8) (inf-pow w) (inf-leaddr n 8) gn)))

   fill
    {'name "inf_fill" 'short "fill"
     'attrs '("static" "inline")
     'ret 'void
     'params rd-params 'fields rd-fields 'state rd-state 'arrays rd-arrays 'requires rd-req
     'decls ()
     'ensures rd-ens
     'body
      '((i1 ife g1 (le (+ ip 8) n)
         ((a1 havoc bb (bor64 bb (shl64 (ld64 In ip) bc)))
          (a2 set ip (+ ip (- 7 (div8 bc))))
          (a3 set bc (or56 bc)))
         ((w1 while (lt ip n) (natminus n ip)
           ((j1 (inf-le ip n))
            (j3 (inf-le bc 63))
            (j4 (inf-bits-inv carry ip cons bc)))
           ((b1 if g2 (lt 55 bc) ((b0 brk)))
            (b2 havoc bb (bor64 bb (shl64 (w64 (at In ip)) bc)))
            (b3 set ip (+ ip 1))
            (b4 set bc (+ bc 8)))))))
     'macros
      (rd-macs +
       '((B6 gs)
         (D7 (natminus 7 (inf-div8 bc0)))
         (Ip (add ip0 D7))
         (Il (inf-addl ip0 D7 8 (inf-letrans D7 7 8 (inf-suble 7 (inf-div8 bc0)) (idpath false))))
         (M6 (inf-addl 56 (inf-mod 8 bc0) 8 (inf-ltle (inf-mod 8 bc0) 8 (inf-modlt 7 bc0))))
         (B8 (inf-addr bc 55 8 g2))
          (I1 (add ip 1))))
     'proofs
      {"i1-1" '(inf-lelt (add ip0 8) (add n 8) (inf-pow w) (inf-addr ip0 n 8 gi) gn)
       "a1-1" 'g1
       "a1-2" '(inf-lelts bc0 63 B6)
       "a2-1" '(inf-div8le bc0 B6)
       "a2-2" '(inf-lelt Ip n (inf-pow w) (inf-letrans Ip (add ip0 8) n Il g1) Nw)
       "a3-2" '(inf-wlit (add 56 (inf-mod 8 bc0)) w gw (inf-or56 bc0))
       "end-1" '(inf-letrans Ip (add ip0 8) n Il g1)
       "end-2" '(inf-or56 bc0)
       "end-3" '(inf-fillw carry ip0 cons0 bc0 B6 ga)
       "end-4" '(inf-refl cons0)
       "w1e-1" 'gi
       "w1e-3" 'ga
       "end-5" 'j1
       "end-7" 'j4
       "end-8" '(inf-refl cons0)
       "b2-1" 'w1
       "b2-2" '(inf-lelt bc 55 64 g2 (idpath true))
       "b3-1" '(inf-lelt I1 n (inf-pow w) (inf-lt1 ip n w1) Nw)
       "b4-1" '(inf-wlit (add bc 8) w gw B8)
       "w1b-1" '(inf-lt1 ip n w1)
       "w1b-2" 'B8
       "w1b-3" '(inf-fill1b carry ip cons0 bc j4)
       "w1b-4" '(inf-subfall1 n ip w1)
       "end-9" 'j1
       "end-11" 'j4
       "end-12" '(inf-refl cons0)}}

   ; TAKE: k bits, or -1 short of them. the fill first, wanted or not, reads no further than the
   ; next call's would
   take
    {'name "inf_take" 'short "take"
     'attrs '("static" "inline")
     'ret 'int
     'params (rd-params + '(("k" uint))) 'fields rd-fields 'state rd-state 'arrays rd-arrays
     'requires (rd-req + '((k nat) (gk (inf-le k 13))))
     'decls '((int (v)))
     'ensures (rd-ens + '((e6 (inf-le (add cons0 k) cons)) (e7 (inf-lt res (inf-pow k)))))
     'calls [fill]
     'body
      '((c1 call "inf_fill" ((raw (var "r"))) (In n w carry) ())
        (i1 if g1 (lt bc k) ((r1 retneg 1)))
        (d1 set v (mask bb k))
        (d2 havoc bb (shr64 bb k))
        (d3 set bc (- bc k))
        (d4 gset cons (add cons k))
        (r2 ret v))
     'macros
      '((K3 (inf-lttrans k 16 32 (inf-lelts k 15 (inf-letrans k 13 15 gk (idpath false))) (idpath false)))
        (Ma (inf-mod (inf-pow k) bbc1))
        (Bc (natminus bcc1 k))
        (Co (add consc1 k)))
     'proofs
      {"c1-1" 'gw "c1-2" 'gn "c1-3" 'gi "c1-5" 'ga
       "d1-1" 'K3
       "d1-2" '(inf-powfit Ma k w (inf-masklt bbc1 k) (inf-letrans k 13 w gk (inf-letrans 13 32 w (idpath false) gw)))
       "d2-1" '(inf-lttrans k 16 64 (inf-lelts k 15 (inf-letrans k 13 15 gk (idpath false))) (idpath false))
       "d3-1" 'g1
       "d3-2" '(inf-wlit Bc w gw (inf-letrans Bc bcc1 63 (inf-suble bcc1 k) c1e3))
       "r2-1" 'c1e1
       "r2-2" '(inf-sub63 bcc1 k c1e3)
       "r2-3" '(inf-take carry ipc1 consc1 bcc1 k g1 c1e4)
       "r2-4" '(inf-letrans cons0 consc1 Co c1e5 (inf-leaddr consc1 k))
       "r2-5" '(inf-addr cons0 consc1 k c1e5)
       "r2-6" '(inf-masklt bbc1 k)}}

   ; SYM: a symbol off the code: the table where it reaches, the walk where it does not. e and sy are
   ; whatever the table holds: nothing here rests on them, and the caller checks sy
   sym
    {'name "inf_sym" 'short "sym"
     'attrs '("static" "inline")
     'ret 'int
     'params (rd-params + '(("c" (ptr (const (struct "inf_code")))) ("t" (ptr (const (named "uint16_t")))) ("root" uint)))
     'fields rd-fields 'state rd-state
     'arrays (rd-arrays + '((Tb (v "t") (inf-pow root))))
     'requires
      (rd-req +
       '((Cn (pi i nat nat)) (Sy (pi i nat nat)) (Tb (pi i nat nat)) (m nat) (h nat) (root nat)
         (hc (pi i nat (inf-lt (Cn i) (inf-pow h))))
         (hs (pi i nat (inf-lt (Sy i) (inf-pow h))))
         (gh (inf-le h 16))
         (gm (inf-lt m (inf-pow w)))
         (gt (inf-le (inf-sum Cn 15 1) m))
         (gr (inf-le root 15))))
     'decls '((int (e) (x) (sy)) (uint (u)))
     'ensures rd-ens
     'calls [fill walk]
     'body
      '((c1 call "inf_fill" ((raw (var "r"))) (In n w carry) ())
        (d1 havoc e (at Tb (mask bb root)))
        (i1 join g1 (z e)
         ((w0 try x "inf_walk" ((raw (var "c")) bb) (Cn Sy (bit (inf-sb bb)) (n m) h w) ())
          (s1 havoc e x))
         ()
         ())
        (d2 havoc sy (shr64 e 4))
        (d3 set u (low e 15))
        (i2 if g2 (lt bc u) ((r1 retneg 1)))
        (d4 havoc bb (shr64 bb u))
        (d5 set bc (- bc u))
        (d6 gset cons (add cons u))
        (r2 ret sy))
     'macros
      '((Rw (inf-lttrans root 16 32 (inf-lelts root 15 gr) (idpath false)))
        (U1 (inf-mod 16 ei1))
        (Ul (inf-ltsle U1 15 (inf-modlt 15 ei1)))
        (Bc (natminus bcc1 U1)))
     'proofs
      {"c1-1" 'gw "c1-2" 'gn "c1-3" 'gi "c1-5" 'ga
       "d1-1" 'Rw
       "d1-2" '(inf-masklt bbc1 root)
       "w0-1" '(lam i (inf-ltsle (inf-sb bbc1 i) 1 (inf-modlt 1 (inf-shr bbc1 i))))
       "w0-2" 'hc
       "w0-3" 'hs
       "w0-4" 'gh
       "w0-5" '(inf-letrans 31 32 w (idpath false) gw)
       "w0-6" 'gm
       "w0-7" 'gt
       "d2-1" '(idpath true)
       "d3-1" '(inf-wlit U1 w gw (inf-letrans U1 15 63 Ul (idpath false)))
       "d4-1" '(inf-lelt U1 15 64 Ul (idpath true))
       "d5-1" 'g2
       "d5-2" '(inf-wlit Bc w gw (inf-letrans Bc bcc1 63 (inf-suble bcc1 U1) c1e3))
       "r2-1" 'c1e1
       "r2-2" '(inf-sub63 bcc1 U1 c1e3)
       "r2-3" '(inf-take carry ipc1 consc1 bcc1 U1 g2 c1e4)
       "r2-4" '(inf-letrans cons0 consc1 (add consc1 U1) c1e5 (inf-leaddr consc1 U1))}}

   ; --- a block's parts, and the whole -----------------------------------------------------------
   ; the tables hold what inflate.h declares; a code is its counts, symbols and table.
   co-state
    '((Lc Lc0) (Ls Ls0) (Lt Lt0) (Dc Dc0) (Ds Ds0) (Dt Dt0) (lm lm0) (dm dm0))
   co-req
    '((Lc0 (pi k nat nat)) (Ls0 (pi k nat nat)) (Lt0 (pi k nat nat))
      (Dc0 (pi k nat nat)) (Ds0 (pi k nat nat)) (Dt0 (pi k nat nat)) (lm0 nat) (dm0 nat)
      (q nat) (h nat) (LROOT nat) (DROOT nat) (CROOT nat)
      (gh (inf-le h 16))
      (gq (inf-le (inf-by16 q) (inf-pow h)))
      (gq2 (inf-lt 320 q))
      (gk (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w))))
      (gl (inf-le LROOT 15)) (gd (inf-le DROOT 15)) (gc (inf-le CROOT 15)))
   co-ens
    '((c1 (pi k nat (inf-lt (Lc k) (inf-pow h))))
      (c2 (pi k nat (inf-lt (Ls k) (inf-pow h))))
      (c3 (inf-le (inf-sum Lc 15 1) lm))
      (c4 (inf-le lm 288))
      (c5 (pi k nat (inf-lt (Dc k) (inf-pow h))))
      (c6 (pi k nat (inf-lt (Ds k) (inf-pow h))))
      (c7 (inf-le (inf-sum Dc 15 1) dm))
      (c8 (inf-le dm 32)))
   co-arrays
    '((Lc (t "lit") 16) (Ls (t "lsym") lm) (Lt (t "ltab") (inf-pow LROOT))
      (Dc (t "dst") 16) (Ds (t "dsym") dm) (Dt (t "dtab") (inf-pow DROOT)))
   ot-req
    '((out nat) (oc nat) (cap nat) (nd nat) (op0 nat)
      (go (pi g (inf-lt 0 out) (paths nat oc cap)))
      (gcap (inf-lt (add cap 8) (inf-pow w)))
      (gop (inf-le op0 cap))
      (gnd (inf-lt (add cap nd) (inf-pow w))))
   ot-ens '((e8 (inf-le op cap)) (e9 (inf-le op0 op)))
   ot-arrays '((Ot (r "out") oc) (Dd (r "dic") nd))
   ot-fields (rd-fields + '(out op cap nd))

   stored
    {'name "inf_stored" 'short "stored"
     'attrs '("static" "inline")
     'ret 'int
     'params rd-params 'fields ot-fields
     'state (rd-state + '((op op0)))
     'arrays (rd-arrays + ot-arrays)
     'requires (one-go (rd-req + ot-req))
     'decls '((uint (dr) (ln) (x16) (nl)) ((named "uintptr_t") (pos)))
     'ensures (one-go (rd-ens + ot-ens))
     'body
      '((d1 set dr (low bc 7))
        (d2 havoc bb (shr64 bb dr))
        (d3 set bc (- bc dr))
        (d4 gset cons (add cons dr))
        (d5 set pos (- ip (div8 bc)))
        (i1 if g1 (lt n (+ pos 4)) ((r1 retneg 1)))
        (d6 havoc x16 (le16 In pos))
        (d7 havoc ln (low x16 65535))
        (d8 havoc nl (le16 In (+ pos 2)))
        (i2 if g2 (ne (low (bxor ln 65535) 65535) nl) ((r2 retneg 1)))
        (i3 if g3 (lt (- n (+ pos 4)) ln) ((r3 retneg 1)))
        (i4 if g4 (lt (- cap op) ln) ((r4 retneg 2)))
        (i5 join g5 (nz out) ((m1 mcopy Ot op In (+ pos 4) ln)) () ())
        (d9 set op (+ op ln))
        (d10 set ip (+ (+ pos 4) ln))
        (d11 havoc bb 0)
        (d12 set bc 0)
        (d13 gset cons (inf-by8 ip))
        (r5 ret 0))
     'macros
      (rd-macs +
       '((D8 (inf-mod 8 bc0))
         (Bd (natminus bc0 D8))
         (Dl (inf-ltle D8 8 (inf-modlt 7 bc0)))
         (Ble (inf-letrans Bd bc0 63 (inf-suble bc0 D8) gs))
         (Q (inf-div8 Bd))
         (Pos (natminus ip0 Q))
         (P4 (add Pos 4))
         (Cc (add cons0 D8))
         (Pv (inf-dropinv ip0 cons0 bc0 ga))
         (Qi (inf-pos ip0 Cc Q Pv))
         (Pn (inf-letrans Pos ip0 n (inf-suble ip0 Q) gi))
         (Fp4 (inf-nfit Pos 4 n w Pn (idpath false) gn))
         (Ln lnd7)
         (Rm (inf-roomle op0 cap Ln g4 gop))
         (Nd (inf-roomle P4 n Ln g3 g1))
         (New (add P4 Ln))
         (Cw (inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap))))
     'proofs
      {"d1-1" '(inf-wlit D8 w gw (inf-letrans D8 8 63 Dl (idpath false)))
       "d2-1" '(inf-lttrans D8 8 64 (inf-modlt 7 bc0) (idpath false))
       "d3-1" '(inf-modle8 bc0)
       "d3-2" '(inf-wlit Bd w gw Ble)
       "d5-1" 'Qi
       "d5-2" '(inf-lelt Pos n (inf-pow w) Pn Nw)
       "i1-1" 'Fp4
       "d6-1" '(inf-letrans (add Pos 2) P4 n (inf-addl Pos 2 4 (idpath false)) g1)
       "d8-1" '(inf-nfit Pos 2 n w Pn (idpath false) gn)
       "d8-2" '(inf-letr P4 (add (add Pos 2) 2) n (pathsinv0 nat (add (add Pos 2) 2) P4 (natplusassoc Pos 2 2)) g1)
       "i3-1" 'Fp4
       "m1-1" 'Fp4
       "m1-2" '(inf-letl (add op0 Ln) cap oc (pathsinv0 nat oc cap (go g5)) Rm)
       "m1-3" 'Nd
       "d9-1" '(inf-lelt (add op0 Ln) cap (inf-pow w) Rm Cw)
       "d10-1" 'Fp4
       "d10-2" '(inf-lelt New n (inf-pow w) Nd Nw)
       "d12-1" '(inf-powpos w)
       "r5-1" 'Nd
       "r5-2" '(idpath false)
       "r5-3" '(pathsinv0 nat (add (inf-by8 New) 0) (inf-by8 New) (natplusr0 (inf-by8 New)))
       "r5-4" '(inf-storedc ip0 cons0 D8 Q 4 Ln Pv)
       "r5-5" 'Rm
       "r5-6" '(inf-leaddr op0 Ln)}}

   ; one code's lens are read from lz[from..]
   fixed
    {'name "inf_fixed" 'short "fixed"
     'attrs '("static" "inline")
     'ret 'void
     'params rd-params 'fields '(t)
     'state co-state
     'arrays (co-arrays + '((Lz (v "lens") 320)))
     'requires ('((w nat) (u nat) (gw (inf-le 32 w))) + co-req)
     'decls '(((arr (named "uint8_t") 320) (lens)) (uint (i) (v)))
     'ensures co-ens
     'calls [build]
     'body
      '((c0 clear Lz (szof (var "lens")))
        (w1 for i 0 288
         ((a1 (inf-le i 288))
          (a2 (pi k nat (inf-le (Lz k) 15))))
         ((s0 set v 8)
          (j1 join g1 (le 144 i) ((s1 set v 9)) () ((b1 (inf-le v 15))))
          (j2 join g2 (le 256 i) ((s2 set v 7)) () ((b2 (inf-le v 15))))
          (j3 join g3 (le 280 i) ((s3 set v 8)) () ((b3 (inf-le v 15))))
          (s4 aset Lz i v)))
        (c1 call "inf_build" ((taddr "lit") (raw (var "lens")) 288 (tf "lsym") (tf "ltab") LROOT)
            ((Ln Lz) (nsym 288) (root LROOT) q (u (inf-pow h)) w) ((Cn Lc) (Sy Ls) (Tb Lt)))
        (d1 gset lm 288)
        (w2 for i 0 30
         ((a3 (inf-le i 30))
          (a4 (pi k nat (inf-le (Lz k) 15))))
         ((s5 aset Lz i 5)))
        (c2 call "inf_build" ((taddr "dst") (raw (var "lens")) 30 (tf "dsym") (tf "dtab") DROOT)
            ((Ln Lz) (nsym 30) (root DROOT) q (u (inf-pow h)) w) ((Cn Dc) (Sy Ds) (Tb Dt)))
        (d2 gset dm 30))
     'macros
      '((Pw (inf-powle h w (inf-letrans h 16 w gh (inf-letrans 16 32 w (idpath false) gw))))
        (Q2 (inf-lttrans 288 320 q (idpath true) (inf-ltle 320 q gq2)))
        (Q3 (inf-lttrans 30 320 q (idpath true) (inf-ltle 320 q gq2))))
     'proofs
      {"w1e-2" '(lam k (idpath false))
       "s4-1" '(inf-lttrans i 288 320 w1 (idpath false))
       "s4-2" '(inf-wlit vj3 w gw (inf-letrans vj3 15 63 b3 (idpath false)))
       "w1b-1" '(inf-lelt (succ i) 288 (inf-pow w) (inf-ltsu i 288 w1) (inf-wfit288 w gw))
       "w1b-2" '(inf-ltsu i 288 w1)
       "w1b-3" '(inf-updle Lz i vj3 15 a2 b3)
       "w1b-4" '(inf-subfall 288 i w1)
       "c1-1" '(lam k g (a2 k))
       "c1-2" 'Q2
       "c1-4" 'Pw
       "s5-1" '(inf-lttrans i 30 320 w2 (idpath false))
       "w2b-1" '(inf-wlit (succ i) w gw (inf-letrans (succ i) 30 63 (inf-ltsu i 30 w2) (idpath false)))
       "w2b-2" '(inf-ltsu i 30 w2)
       "w2b-3" '(inf-updle Lz i 5 15 a4 (idpath false))
       "w2b-4" '(inf-subfall 30 i w2)
       "c2-1" '(lam k g (a4 k))
       "c2-2" 'Q3
       "c2-4" 'Pw
       "end-1" 'c1e1 "end-2" 'c1e2 "end-3" 'c1e3
       "end-5" 'c2e1 "end-6" 'c2e2 "end-7" 'c2e3}}

   dyn
    {'name "inf_dyn" 'short "dyn"
     'attrs '("static" "inline")
     'ret 'int
     'params rd-params 'fields (rd-fields + '(t))
     'state (rd-state + co-state)
     'arrays (rd-arrays + co-arrays + '((Lz (v "lens") 320) (Cl (v "cl") 19) (Ob (v "gz_clord") 19)
                                        (Cs (t "csym") 19) (Ct (t "ctab") (inf-pow CROOT))))
     'requires (rd-req + co-req + '((Ob (pi k nat nat)) (Cs0 (pi k nat nat)) (Ct0 (pi k nat nat)) (Cc0 (pi k nat nat))
                                    (hord (pi k nat g (inf-lt k 19) (inf-lt (Ob k) 19)))))
     'decls '(((arr (named "uint8_t") 320) (lens)) ((arr (named "uint8_t") 19) (cl))
              (uint (hlit) (hdist) (hclen) (tot) (prev 0) (i) (k) (rr) (v)) (int (x) (sy)))
     'ensures (rd-ens + co-ens)
     'calls [fill take sym build]
     'body
      '((t1 try x "inf_take" ((raw (var "r")) 5) (In n w carry (k 5)) ())
        (s1 set hlit (+ x 257))
        (t2 try x "inf_take" ((raw (var "r")) 5) (In n w carry (k 5)) ())
        (s2 set hdist (+ x 1))
        (t3 try x "inf_take" ((raw (var "r")) 4) (In n w carry (k 4)) ())
        (s3 set hclen (+ x 4))
        (c1 clear Cl (szof (var "cl")))
        (w1 for i 0 hclen
         ((a1 (inf-le i hclen))
          (a2 (pi k nat (inf-le (Cl k) 15)))
          (a3 (inf-le hclen 19))
          (r1 (inf-le ip n)) (r3 (inf-le bc 63)) (r4 (inf-bits-inv carry ip cons bc)) (r5 (inf-le cons0 cons)))
         ((t4 try x "inf_take" ((raw (var "r")) 3) (In n w carry (k 3)) ())
          (s4 aset Cl (at Ob i) x)))
        (c2 call "inf_build" ((taddr "cl") (raw (var "cl")) 19 (tf "csym") (tf "ctab") CROOT)
            ((Ln Cl) (nsym 19) (root CROOT) q (u (inf-pow h)) w) ((Cn Cc) (Sy Cs) (Tb Ct)))
        (c3 clear Lz (szof (var "lens")))
        (s5 set tot (+ hlit hdist))
        (s5b set i 0)
        (w2 while (lt i tot) (natminus tot i)
         ((b1 (inf-le prev 15))
          (b2 (pi j nat (inf-le (Lz j) 15)))
          (r1 (inf-le ip n)) (r3 (inf-le bc 63)) (r4 (inf-bits-inv carry ip cons bc)) (r5 (inf-le cons0 cons)))
         ((t5 try sy "inf_sym" ((raw (var "r")) (taddr "cl") (tf "ctab") CROOT)
              (In n w carry (Cn Cc) (Sy Cs) (Tb Ct) (m 19) h (root CROOT)) ())
          (j1 join g1 (lt sy 16)
           ((s6 set rr 1) (s7 set v sy))
           ((i1 if g2 (lt 18 sy) ((r1 retneg 1)))
            (j2 join g3 (le sy 16)
             ((t6 try x "inf_take" ((raw (var "r")) 2) (In n w carry (k 2)) ())
              (s8 set rr (+ x 3)) (s9 set v prev))
             ((j3 join g4 (le sy 17)
               ((t7 try x "inf_take" ((raw (var "r")) 3) (In n w carry (k 3)) ())
                (s10 set rr (+ x 3)))
               ((t8 try x "inf_take" ((raw (var "r")) 7) (In n w carry (k 7)) ())
                (s11 set rr (+ x 11)))
               ((f1 (inf-lt 0 rr)) (f2 (inf-le rr 138)) (r1 (inf-le ip n)) (r3 (inf-le bc 63)) (r4 (inf-bits-inv carry ip cons bc)) (r5 (inf-le cons0 cons))))
              (s12 set v 0))
             ((f3 (inf-lt 0 rr)) (f4 (inf-le rr 138)) (f5 (inf-le v 15)) (r1 (inf-le ip n)) (r3 (inf-le bc 63)) (r4 (inf-bits-inv carry ip cons bc)) (r5 (inf-le cons0 cons)))))
           ((f6 (inf-lt 0 rr)) (f7 (inf-le rr 138)) (f8 (inf-le v 15)) (r1 (inf-le ip n)) (r3 (inf-le bc 63)) (r4 (inf-bits-inv carry ip cons bc)) (r5 (inf-le cons0 cons))))
          (w3 for k 0 rr
           ((c1 (inf-le k rr))
            (c2 (pi j nat (inf-le (Lz j) 15))))
           ((i2 if g5 (lt (+ i k) 320) ((s13 aset Lz (+ i k) v)))))
          (s14 set i (+ i rr))
          (s15 set prev v)))
        (c4 call "inf_build" ((taddr "lit") (raw (var "lens")) hlit (tf "lsym") (tf "ltab") LROOT)
            ((Ln Lz) (nsym hlit) (root LROOT) q (u (inf-pow h)) w) ((Cn Lc) (Sy Ls) (Tb Lt)))
        (d1 gset lm hlit)
        (c5 call "inf_build" ((taddr "dst") (raw (bin + (var "lens") (var "hlit"))) hdist (tf "dsym") (tf "dtab") DROOT)
            ((Ln (inf-shift Lz hlit)) (nsym hdist) (root DROOT) q (u (inf-pow h)) w) ((Cn Dc) (Sy Ds) (Tb Dt)))
        (d2 gset dm hdist)
        (r2 ret 0))
     'macros
      '((Pw (inf-powle h w (inf-letrans h 16 w gh (inf-letrans 16 32 w (idpath false) gw))))
        (H (add xt1 257))
        (Hd (add xt2 1))
        (Hc (add xt3 4))
        (Hl (inf-addr xt1 31 257 (inf-ltsle xt1 31 t1e7)))
        (Hm (inf-addr xt2 31 1 (inf-ltsle xt2 31 t2e7)))
        (Hn (inf-addr xt3 15 4 (inf-ltsle xt3 15 t3e7)))
        (C3 (inf-letrans cons0 const2 const3 (inf-letrans cons0 const1 const2 t1e5 t2e5) t3e5))
        (W9 (inf-wnine w gw))
        (W3 (inf-lelt 320 512 (inf-pow w) (idpath false) W9))
        (W4 (inf-lelt 458 512 (inf-pow w) (idpath false) W9))
        (W1 (inf-lelt 138 512 (inf-pow w) (idpath false) W9))
        (T3 (inf-add2 H 288 Hd 32 Hl Hm))
        (Ti (inf-letrans i (add H Hd) 320 (inf-ltle i (add H Hd) w2) T3))
        (Ik (inf-add2 i 320 k 138 Ti (inf-letrans k rrj1 138 (inf-ltle k rrj1 w3) f7)))
        (Rk (inf-letrans (succ k) rrj1 138 (inf-ltsu k rrj1 w3) f7))
        (X6 (inf-addr xt6 3 3 (inf-ltsle xt6 3 t6e7)))
        (X7 (inf-addr xt7 7 3 (inf-ltsle xt7 7 t7e7)))
        (X8 (inf-addr xt8 127 11 (inf-ltsle xt8 127 t8e7)))
        (Xq (inf-ltle 320 q gq2)))
     'proofs
      {"s1-1" '(inf-lelt H 288 (inf-pow w) Hl (inf-wfit288 w gw))
       "s2-1" '(inf-wlit Hd w gw (inf-letrans Hd 32 63 Hm (idpath false)))
       "s3-1" '(inf-wlit Hc w gw (inf-letrans Hc 19 63 Hn (idpath false)))
       "w1e-2" '(lam k (idpath false))
       "w1e-3" 'Hn
       "w1e-7" 'C3
       "s4-1" '(inf-lttrans i Hc 19 w1 a3)
       "s4-2" '(hord i (inf-lttrans i Hc 19 w1 a3))
       "s4-3" '(inf-lttrans xt4 8 (inf-pow w) t4e7 (inf-powle 3 w (inf-letrans 3 32 w (idpath false) gw)))
       "w1b-1" '(inf-wlit (succ i) w gw (inf-letrans (succ i) 19 63 (inf-ltsu i 19 (inf-lttrans i Hc 19 w1 a3)) (idpath false)))
       "w1b-2" '(inf-ltsu i Hc w1)
       "w1b-3" '(inf-updle Cl (Ob i) xt4 15 a2 (inf-letrans xt4 8 15 (inf-ltle xt4 8 t4e7) (idpath false)))
       "w1b-8" '(inf-letrans cons0 cons const4 r5 t4e5)
       "w1b-9" '(inf-subfall Hc i w1)
       "c2-1" '(lam k g (a2 k))
       "c2-2" '(inf-lttrans 19 320 q (idpath true) Xq)
       "c2-4" 'Pw
       "s5-1" '(inf-lelt (add H Hd) 320 (inf-pow w) T3 W3)
       "w2e-2" '(lam j (idpath false))
       "t5-6" 'c2e1
       "t5-7" 'c2e2
       "s7-1" '(inf-wlit syt5 w gw (inf-letrans syt5 16 63 (inf-ltle syt5 16 g1) (idpath false)))
       "j1j-3" '(inf-ltsle syt5 15 g1)
       "j1j-7" '(inf-letrans cons0 cons const5 r5 t5e5)
       "s8-1" '(inf-wlit (add xt6 3) w gw (inf-letrans (add xt6 3) 6 63 X6 (idpath false)))
       "s9-1" '(inf-wlit prev w gw (inf-letrans prev 15 63 b1 (idpath false)))
       "j2j-1" '(inf-pos3 xt6 3 (idpath true))
       "j2j-2" '(inf-letrans (add xt6 3) 6 138 X6 (idpath false))
       "j2j-7" '(inf-letrans cons0 const5 const6 (inf-letrans cons0 cons const5 r5 t5e5) t6e5)
       "s10-1" '(inf-wlit (add xt7 3) w gw (inf-letrans (add xt7 3) 10 63 X7 (idpath false)))
       "j3j-1" '(inf-pos3 xt7 3 (idpath true))
       "j3j-2" '(inf-letrans (add xt7 3) 10 138 X7 (idpath false))
       "j3j-6" '(inf-letrans cons0 const5 const7 (inf-letrans cons0 cons const5 r5 t5e5) t7e5)
       "s11-1" '(inf-lelt (add xt8 11) 512 (inf-pow w) (inf-letrans (add xt8 11) 138 512 X8 (idpath false)) (inf-lttrans 512 1024 (inf-pow w) (idpath true) (inf-powle 10 w (inf-letrans 10 32 w (idpath false) gw))))
       "j3j-7" '(inf-pos3 xt8 11 (idpath true))
       "j3j-8" 'X8
       "j3j-12" '(inf-letrans cons0 const5 const8 (inf-letrans cons0 cons const5 r5 t5e5) t8e5)
       "i2-1" '(inf-lelt (add i k) 458 (inf-pow w) Ik W4)
       "s13-1" '(inf-lelt (add i k) 458 (inf-pow w) Ik W4)
       "s13-3" '(inf-wlit vj1 w gw (inf-letrans vj1 15 63 f8 (idpath false)))
       "w3b-1" '(inf-lelt (succ k) 138 (inf-pow w) Rk W1)
       "w3b-2" '(inf-ltsu k rrj1 w3)
       "w3b-3" '(inf-updle Lz (add i k) vj1 15 c2 f8)
       "w3b-4" '(inf-subfall rrj1 k w3)
       "w3b-5" '(inf-lelt (succ k) 138 (inf-pow w) Rk W1)
       "w3b-6" '(inf-ltsu k rrj1 w3)
       "w3b-8" '(inf-subfall rrj1 k w3)
       "s14-1" '(inf-lelt (add i rrj1) 458 (inf-pow w) (inf-add2 i 320 rrj1 138 Ti f7) W4)
       "s15-1" '(inf-wlit vj1 w gw (inf-letrans vj1 15 63 f8 (idpath false)))
       "w2b-7" '(inf-subby i (add H Hd) rrj1 w2 f6)
       "c4-1" '(lam k g (b2 k))
       "c4-2" '(inf-lelt H 288 q Hl (inf-lttrans 288 320 q (idpath true) Xq))
       "c4-4" 'Pw
       "c5-1" '(lam k g (b2 (add H k)))
       "c5-2" '(inf-lelt Hd 32 q Hm (inf-lttrans 32 320 q (idpath true) Xq))
       "c5-4" 'Pw
       "r2-5" 'c4e1 "r2-6" 'c4e2 "r2-7" 'c4e3 "r2-8" 'Hl
       "r2-9" 'c5e1 "r2-10" 'c5e2 "r2-11" 'c5e3 "r2-12" 'Hm}}

   ; a match's bytes: out, or the dictionary behind it
   copy
    {'name "inf_copy" 'short "copy"
     'attrs '("static" "inline")
     'ret 'void
     'params (rd-params + '(("l" (named "uintptr_t")) ("d" (named "uintptr_t"))))
     'fields '(out op cap nd)
     'arrays ot-arrays
     'requires
      '((w nat) (l nat) (d nat) (op nat) (out nat) (oc nat) (cap nat) (nd nat)
        (gw (inf-le 32 w))
        (gd (inf-lt d (inf-pow w)))
        (ga (inf-le d (add op nd)))
        (gb (inf-le (add op l) cap))
        (gz (inf-lt 0 out))
        (go (pi g (inf-lt 0 out) (paths nat oc cap)))
        (gcap (inf-lt (add cap 8) (inf-pow w))))
     'decls '(((named "uintptr_t") (k 0) (m)))
     'ensures ()
     'body
      '((i1 ife g1 (lt op d)
         ((s1 set m l)
          (j1 join g2 (lt (- d op) l) ((s2 set m (- d op))) () ((f1 (paths nat m (inf-h d op l)))))
          (m1 mcopy Ot op Dd (- nd (- d op)) m)
          (w1 for k m l
           ((a1 (inf-le m k)))
           ((p1 poke Ot (+ op k) (at Ot (- (+ op k) d))))))
         ((j2 join g3 (wide d)
           ((w2 while (le (+ k 8) l) (natminus l k)
             ((a2 (inf-le k l)))
             ((p2 pokew Ot (+ op k) (ld64 Ot (- (+ op k) d)))
              (s3 set k (+ k 8)))))
           ()
           ((f3 (inf-le k l))))
          (w3 while (lt k l) (natminus l k)
           ((a3 (inf-le k l)))
           ((p3 poke Ot (+ op k) (at Ot (- (+ op k) d)))
            (s4 set k (+ k 1)))))))
     'macros
      '((Cw (inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap))
        (Go (inf-letl (add op l) cap oc (pathsinv0 nat oc cap (go gz)) gb))
        (Lw (inf-lelt l cap (inf-pow w) (inf-letrans l (add op l) cap (inf-leaddl l op) gb) Cw))
        (Hm (pathsinv0 nat mj1 (inf-h d op l) f1))
        (Hl (inf-letr (inf-h d op l) mj1 l Hm (inf-hlel d op l)))
        (Hd (inf-letr (inf-h d op l) mj1 (natminus d op) Hm (inf-hle d op l)))
        (Dop (inf-letrans d op (add op k) g1 (inf-leaddr op k))))
     'proofs
      {"s1-1" 'Lw
       "s2-2" '(inf-lelt (natminus d op) d (inf-pow w) (inf-suble d op) gd)
       "j1j-1" '(inf-htt d op l g2)
       "j1j-2" '(inf-hff d op l g2)
       "m1-2" '(inf-dnowrap d op nd ga)
       "m1-3" '(inf-letrans (add op mj1) (add op l) oc (inf-addl op mj1 l Hl) Go)
       "m1-4" '(inf-letr (add (natminus nd (natminus d op)) (inf-h d op l)) (add (natminus nd (natminus d op)) mj1) nd
                 (maponpaths nat nat (lam z (add (natminus nd (natminus d op)) z)) (inf-h d op l) mj1 Hm)
                 (inf-dr d op l nd ga))
       "p1-1" '(inf-lelt (add op k) cap (inf-pow w) (inf-letrans (add op k) (add op l) cap (inf-ltle (add op k) (add op l) (inf-ltaddl op k l w1)) gb) Cw)
       "p1-2" '(inf-cw op k l oc w1 Go)
       "p1-3" '(inf-dknowrap d op l k (inf-ltle op d g1) (inf-letr mj1 (inf-h d op l) k f1 a1) w1)
       "p1-4" '(inf-lelt (natminus (add op k) d) (add op k) oc (inf-suble (add op k) d) (inf-cw op k l oc w1 Go))
       "w1b-1" '(inf-lelt (succ k) l (inf-pow w) (inf-ltsu k l w1) Lw)
       "w1b-2" '(inf-letrans mj1 k (succ k) a1 (inf-ltle k (succ k) (inf-ltself k)))
       "w1b-3" '(inf-subfall l k w1)
       "w2h-1" '(inf-nfit k 8 cap w (inf-letrans k l cap a2 (inf-letrans l (add op l) cap (inf-leaddl l op) gb)) (idpath false) gcap)
       "p2-1" '(inf-lelt (add op k) (add op l) (inf-pow w) (inf-addl op k l (inf-letrans k (add k 8) l (inf-leaddr k 8) w2))
                 (inf-lelt (add op l) cap (inf-pow w) gb Cw))
       "p2-2" '(inf-letrans (add (add op k) 8) (add op l) oc
                 (inf-letr (add op (add k 8)) (add (add op k) 8) (add op l)
                   (pathsinv0 nat (add (add op k) 8) (add op (add k 8)) (natplusassoc op k 8))
                   (inf-addl op (add k 8) l w2))
                 Go)
       "p2-3" 'Dop
       "p2-4" '(inf-letrans (add (natminus (add op k) d) 8) (add (add op k) 8) oc
                 (inf-addr (natminus (add op k) d) (add op k) 8 (inf-suble (add op k) d))
                 (inf-letrans (add (add op k) 8) (add op l) oc
                   (inf-letr (add op (add k 8)) (add (add op k) 8) (add op l)
                     (pathsinv0 nat (add (add op k) 8) (add op (add k 8)) (natplusassoc op k 8))
                     (inf-addl op (add k 8) l w2))
                   Go))
       "s3-1" '(inf-nfit k 8 cap w (inf-letrans k l cap a2 (inf-letrans l (add op l) cap (inf-leaddl l op) gb)) (idpath false) gcap)
       "w2b-2" '(inf-subby k l 8 (inf-lttrans k (add k 8) l (inf-ltaddpos k 8 (idpath true)) w2) (idpath true))
       "p3-1" '(inf-lelt (add op k) cap (inf-pow w) (inf-letrans (add op k) (add op l) cap (inf-ltle (add op k) (add op l) (inf-ltaddl op k l w3)) gb) Cw)
       "p3-2" '(inf-cw op k l oc w3 Go)
       "p3-3" 'Dop
       "p3-4" '(inf-lelt (natminus (add op k) d) (add op k) oc (inf-suble (add op k) d) (inf-cw op k l oc w3 Go))
       "s4-1" '(inf-lelt (add k 1) l (inf-pow w) (inf-lt1 k l w3) Lw)
       "w3b-1" '(inf-lt1 k l w3)
       "w3b-2" '(inf-subfall1 l k w3)}}

   ; the fast lane: topped up below 15 bits, and to 48 before a pair. with 266 bytes of room a copy may
   ; overrun in whole words. a code past its root (the distance's peeked before the length is taken)
   ; leaves the lane, so it makes no call. 1 block end, 0 short of margin, -1 malformed
   fast
    {'name "inf_fast_run" 'short "fast"
     'attrs '("static")
     'ret 'int
     'params rd-params 'fields '(n cap nd)
     'state (rd-state + '((op op0)))
     'arrays '((In (v "in") n) (Ot (v "out") oc) (Dd (v "dic") nd)
               (Lt (v "lt") (inf-pow LROOT)) (Dt (v "dt") (inf-pow DROOT))
               (Lb (v "gz_lbase") 29) (Le (v "gz_lext") 29) (Db (v "gz_dbase") 30) (De (v "gz_dext") 30))
     'requires
      (rd-req + ot-req +
       '((gcf (inf-lt (add cap 266) (inf-pow w)))
         (Lt (pi k nat nat)) (Dt (pi k nat nat)) (Lb (pi k nat nat)) (Le (pi k nat nat)) (Db (pi k nat nat)) (De (pi k nat nat))
         (h nat) (LROOT nat) (DROOT nat)
         (gl (inf-le LROOT 15)) (gd (inf-le DROOT 15)) (gh (inf-le h 16)) (gz (inf-lt 0 out))
         (hle (pi k nat g (inf-lt k 29) (inf-le (Le k) 5)))
         (hlb (pi k nat g (inf-lt k 29) (inf-le (add (Lb k) (inf-pow (Le k))) 259)))
         (hlc (pi k nat g (inf-lt k 29) (inf-le 3 (Lb k))))
         (hde (pi k nat g (inf-lt k 30) (inf-le (De k) 13)))
         (hdb (pi k nat g (inf-lt k 30) (inf-le (add (Db k) (inf-pow (De k))) (inf-pow h))))))
     'decls
      '(((ptr (const (named "uint8_t"))) (in (raw (dot (deref (var "r")) "in"))) (dic (raw (dot (deref (var "r")) "dic"))))
        ((ptr (named "uint8_t")) (out (raw (dot (deref (var "r")) "out"))))
        ((ptr (const (named "uint16_t"))) (lt (raw (dot (deref (dot (deref (var "r")) "t")) "ltab")))
                                          (dt (raw (dot (deref (dot (deref (var "r")) "t")) "dtab"))))
        ((named "uint64_t") (bb (raw (dot (deref (var "r")) "bb"))))
        ((named "uintptr_t") (ip (raw (dot (deref (var "r")) "ip"))) (op (raw (dot (deref (var "r")) "op")))
                             (bc (raw (dot (deref (var "r")) "bc"))) (e) (f) (sy) (x) (l) (d) (k) (dd) (y))
        (int (ans 0)))
     'ensures (rd-ens + ot-ens)
     'body
      '((w1 while (le (+ op 266) cap) (natminus cap op)
         ((j1 (inf-le ip n)) (j3 (inf-le bc 63))
          (j4 (inf-bits-inv carry ip cons bc)) (j5 (inf-le cons0 cons)) (j6 (inf-le op0 op)) (j7 (inf-le op cap)))
         ((i1 join g1 (lt bc 15)
           ((i2 if g2 (lt n (+ ip 8)) ((b1 brk)))
            (f1 havoc bb (bor64 bb (shl64 (ld64 In ip) bc)))
            (f2 set ip (+ ip (- 7 (div8 bc))))
            (f3 set bc (or56 bc)))
           ()
           ((h1 (inf-le ip n)) (h3 (inf-le bc 63)) (h4 (inf-bits-inv carry ip cons bc)) (h5 (inf-le 15 bc))))
          (d1 havoc e (at Lt (mask bb LROOT)))
          (i3 if g3 (z e) ((b2 brk)))
          (d2 havoc sy (shr64 e 4))
          (i4 ife g4 (lt sy 256)
           ((d3 havoc bb (shr64 bb (low e 15)))
            (d4 set bc (- bc (low e 15)))
            (d5 gset cons (add cons (inf-mod 16 e)))
            (p1 poke Ot op (u8 sy))
            (s1 set op (+ op 1)))
           ((i5 if g5 (le sy 256)
             ((d6 havoc bb (shr64 bb (low e 15)))
              (d7 set bc (- bc (low e 15)))
              (d8 gset cons (add cons (inf-mod 16 e)))
              (s2 set ans 1)
              (b3 brk)))
            (i6 if g6 (lt 285 sy) ((r1 retneg 1)))
            (i7 join g7 (lt bc 48)
             ((i8 if g8 (lt n (+ ip 8)) ((b4 brk)))
              (f4 havoc bb (bor64 bb (shl64 (ld64 In ip) bc)))
              (f5 set ip (+ ip (- 7 (div8 bc))))
              (f6 set bc (or56 bc)))
             ()
             ((m1 (inf-le ip n)) (m3 (inf-le bc 63)) (m4 (inf-bits-inv carry ip cons bc)) (m5 (inf-le 48 bc))))
            (d9 set x (at Le (- sy 257)))
            (d10 havoc y (shr64 bb (+ (low e 15) x)))
            (d11 havoc f (at Dt (mask y DROOT)))
            (i9 if g9 (z f) ((b5 brk)))
            (d12 havoc bb (shr64 bb (low e 15)))
            (d13 set bc (- bc (low e 15)))
            (d14 gset cons (add cons (inf-mod 16 e)))
            (d15 set l (+ (at Lb (- sy 257)) (mask bb x)))
            (d16 havoc bb (shr64 bb x))
            (d17 set bc (- bc x))
            (d18 gset cons (add cons x))
            (d19 havoc bb (shr64 bb (low f 15)))
            (d20 set bc (- bc (low f 15)))
            (d21 gset cons (add cons (inf-mod 16 f)))
            (d22 havoc sy (shr64 f 4))
            (i10 if g10 (lt 29 sy) ((r2 retneg 1)))
            (d23 set x (at De sy))
            (d24 set d (+ (at Db sy) (mask bb x)))
            (d25 havoc bb (shr64 bb x))
            (d26 set bc (- bc x))
            (d27 gset cons (add cons x))
            (i11 join g11 (lt op d)
             ((i12 if g12 (lt (+ op nd) d) ((r3 retneg 1)))
              (s3 set dd l)
              (j8 join g13 (lt (- d op) l) ((s4 set dd (- d op))) () ((f7 (paths nat dd (inf-h d op l)))))
              (m6 mcopy Ot op Dd (- nd (- d op)) dd)
              (w2 for k dd l
               ((a1 (inf-le dd k)))
               ((p2 poke Ot (+ op k) (at Ot (- (+ op k) d))))))
             ((s5 set k 0)
              (j9 join g14 (wide d)
               ((w3 while (lt k l) (natminus l k)
                 ((a2 (inf-le k (add l 7))))
                 ((p3 pokew Ot (+ op k) (ld64 Ot (- (+ op k) d)))
                  (s6 set k (+ k 8)))))
               ((j10 join g15 (widec d)
                 ((w4 while (lt k l) (natminus l k)
                   ((a3 (inf-le k (add l 7))))
                   ((p4 pokew Ot (+ op k) (rep8 (at Ot (- op d))))
                    (s7 set k (+ k 8)))))
                 ((w5 while (lt k l) (natminus l k)
                   ((a4 (inf-le k l)))
                   ((p5 poke Ot (+ op k) (at Ot (- (+ op k) d)))
                    (s8 set k (+ k 1)))))
                 ()))
               ()))
             ())
            (s9 set op (+ op l))))))
        (e1 store "ip" ip) (e2 store "op" op) (e3 store "bb" bb) (e4 store "bc" bc)
        (r4 ret ans))
     'macros
      (rd-macs +
       '((Cw (inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap))
         (CO (inf-letl cap cap oc (pathsinv0 nat oc cap (go gz)) (inf-refl cap)))
         (W9 (inf-wnine w gw))
         (W258 (inf-lelt 258 512 (inf-pow w) (idpath false) W9))
         (W266 (inf-lelt 266 512 (inf-pow w) (idpath false) W9))
         (Opc (inf-lttrans op (add op 266) cap (inf-ltaddpos op 266 (idpath true)) w1))
         (Op0 (inf-lttrans op cap oc Opc CO))
         ; the top-ups
         (B1 (inf-letrans bc 15 63 (inf-ltle bc 15 g1) (idpath false)))
         (D1 (natminus 7 (inf-div8 bc)))
         (I1 (add ip D1))
         (M1 (inf-addl 56 (inf-mod 8 bc) 8 (inf-ltle (inf-mod 8 bc) 8 (inf-modlt 7 bc))))
         (L1 (inf-letrans I1 (add ip 8) n (inf-addl ip D1 8 (inf-letrans D1 7 8 (inf-suble 7 (inf-div8 bc)) (idpath false))) g2))
         (B2 (inf-letrans bci1 48 63 (inf-ltle bci1 48 g7) (idpath false)))
         (D2 (natminus 7 (inf-div8 bci1)))
         (I2 (add ipi1 D2))
         (M2 (inf-addl 56 (inf-mod 8 bci1) 8 (inf-ltle (inf-mod 8 bci1) 8 (inf-modlt 7 bci1))))
         (L2 (inf-letrans I2 (add ipi1 8) n (inf-addl ipi1 D2 8 (inf-letrans D2 7 8 (inf-suble 7 (inf-div8 bci1)) (idpath false))) g8))
         ; the symbol and what it takes
         (Ea (inf-mod 16 ed1))
         (Ez (inf-modlt 15 ed1))
         (E5 (inf-ltsle Ea 15 Ez))
         (E6 (inf-lttrans Ea 16 64 Ez (idpath false)))
         (Eb (inf-letrans Ea 15 bci1 E5 h5))
         (Ec (natminus bci1 Ea))
         (Ix (natminus syd2 257))
         (I7 (inf-ltsu 256 syd2 g5))
         (I9 (inf-lidx syd2 g6))
         (Xl (Le Ix))
         (X5 (hle Ix I9))
         (Fa (inf-mod 16 fd11))
         (Fz (inf-modlt 15 fd11))
         (F5 (inf-ltsle Fa 15 Fz))
         (Xd (De syd22))
         (S3 (inf-lelts syd22 29 g10))
         (X3 (hde syd22 S3))
         (C1 (natminus bci7 Ea))
         (C2 (natminus C1 Xl))
         (C3 (natminus C2 Fa))
         (C4 (natminus C3 Xd))
         (G1 (inf-letrans Ea 15 bci7 E5 (inf-letrans 15 48 bci7 (idpath false) m5)))
         (G2 (inf-fastb1 Ea Xl bci7 E5 X5 m5))
         (G3 (inf-fastb2 Ea Xl Fa bci7 E5 X5 F5 m5))
         (G4 (inf-fastb3 Ea Xl Fa Xd bci7 E5 X5 F5 X3 m5))
         (T1 (add cons Ea))
         (T2 (add T1 Xl))
         (T3 (add T2 Fa))
         (T4 (add T3 Xd))
         ; the copy
         (La (add (Lb Ix) (inf-mod (inf-pow Xl) bbd12)))
         (Lz (inf-baseadd (Lb Ix) Xl bbd12 259 (hlb Ix I9)))
         (L8 (inf-ltsle La 258 Lz))
         (Lw (inf-lelt La 258 (inf-pow w) L8 W258))
         (Lp (inf-lttrans 0 3 La (idpath true) (inf-letrans 3 (Lb Ix) La (hlc Ix I9) (inf-leaddr (Lb Ix) (inf-mod (inf-pow Xl) bbd12)))))
         (Gb (inf-letrans (add op La) (add op 266) cap (inf-addl op La 266 (inf-letrans La 258 266 L8 (idpath false))) w1))
         (Gc (inf-letrans (add op La) cap oc Gb CO))
         (Da (add (Db syd22) (inf-mod (inf-pow Xd) bbd19)))
         (Dz (inf-baseadd (Db syd22) Xd bbd19 (inf-pow h) (hdb syd22 S3)))
         (Dw (inf-powfit Da h w Dz (inf-letrans h 16 w gh (inf-letrans 16 32 w (idpath false) gw))))
         (Dop (inf-letrans Da op (add op k) g11 (inf-leaddr op k)))
         (Hm (pathsinv0 nat ddj8 (inf-h Da op La) f7))
         (Hl (inf-letr (inf-h Da op La) ddj8 La Hm (inf-hlel Da op La)))
         (Pa (inf-lelt (add op La) cap (inf-pow w) Gb Cw))
         (W3 (inf-letl (add (add op k) 8) cap oc (pathsinv0 nat oc cap (go gz))
               (inf-fastw op La (add op k) cap (inf-ltaddl op k La w3) L8 w1)))
         (W4 (inf-letl (add (add op k) 8) cap oc (pathsinv0 nat oc cap (go gz))
               (inf-fastw op La (add op k) cap (inf-ltaddl op k La w4) L8 w1)))))
     'proofs
      {"w1h-1" '(inf-lelt (add op 266) (add cap 266) (inf-pow w) (inf-addr op cap 266 j7) gcf)
       "i2-1" '(inf-lelt (add ip 8) (add n 8) (inf-pow w) (inf-addr ip n 8 j1) gn)
       "f1-2" '(inf-lttrans bc 15 64 g1 (idpath false))
       "f2-1" '(inf-div8le bc B1)
       "f2-2" '(inf-lelt I1 n (inf-pow w) L1 Nw)
       "f3-2" '(inf-wlit (add 56 (inf-mod 8 bc)) w gw (inf-or56 bc))
       "i1j-1" 'L1
       "i1j-2" '(inf-or56 bc)
       "i1j-3" '(inf-fillw carry ip cons bc B1 j4)
       "i1j-4" '(inf-letrans 15 56 (add 56 (inf-mod 8 bc)) (idpath false) (inf-leaddr 56 (inf-mod 8 bc)))
       "d1-1" '(inf-lelt LROOT 15 32 gl (idpath true))
       "d1-2" '(inf-masklt bbi1 LROOT)
       "d3-1" 'E6
       "d4-1" 'Eb
       "d4-2" '(inf-wlit Ec w gw (inf-letrans Ec bci1 63 (inf-suble bci1 Ea) h3))
       "p1-1" 'Op0
       "s1-1" '(inf-lelt (add op 1) cap (inf-pow w) (inf-lt1 op cap Opc) Cw)
       "w1b-2" '(inf-sub63 bci1 Ea h3)
       "w1b-3" '(inf-take carry ipi1 cons bci1 Ea Eb h4)
       "w1b-4" '(inf-letrans cons0 cons T1 j5 (inf-leaddr cons Ea))
       "w1b-5" '(inf-letrans op0 op (add op 1) j6 (inf-leaddr op 1))
       "w1b-6" '(inf-lt1 op cap Opc)
       "w1b-7" '(inf-subfall1 cap op Opc)
       "d6-1" 'E6
       "d7-1" 'Eb
       "d7-2" '(inf-wlit Ec w gw (inf-letrans Ec bci1 63 (inf-suble bci1 Ea) h3))
       "r4-14" '(inf-sub63 bci1 Ea h3)
       "r4-15" '(inf-take carry ipi1 cons bci1 Ea Eb h4)
       "r4-16" '(inf-letrans cons0 cons T1 j5 (inf-leaddr cons Ea))
       "i8-1" '(inf-lelt (add ipi1 8) (add n 8) (inf-pow w) (inf-addr ipi1 n 8 h1) gn)
       "f4-2" '(inf-lttrans bci1 48 64 g7 (idpath false))
       "f5-1" '(inf-div8le bci1 B2)
       "f5-2" '(inf-lelt I2 n (inf-pow w) L2 Nw)
       "f6-2" '(inf-wlit (add 56 (inf-mod 8 bci1)) w gw (inf-or56 bci1))
       "i7j-1" 'L2
       "i7j-2" '(inf-or56 bci1)
       "i7j-3" '(inf-fillw carry ipi1 cons bci1 B2 h4)
       "i7j-4" '(inf-letrans 48 56 (add 56 (inf-mod 8 bci1)) (idpath false) (inf-leaddr 56 (inf-mod 8 bci1)))
       "d9-1" 'I7
       "d9-2" 'I9
       "d9-3" '(inf-wlit Xl w gw (inf-letrans Xl 5 63 X5 (idpath false)))
       "d10-1" '(inf-wlit (add Ea Xl) w gw (inf-letrans (add Ea Xl) 20 63 (inf-add2 Ea 15 Xl 5 E5 X5) (idpath false)))
       "d10-2" '(inf-lelt (add Ea Xl) 20 64 (inf-add2 Ea 15 Xl 5 E5 X5) (idpath true))
       "d11-1" '(inf-lelt DROOT 15 32 gd (idpath true))
       "d11-2" '(inf-masklt yd10 DROOT)
       "d12-1" 'E6
       "d13-1" 'G1
       "d13-2" '(inf-wlit C1 w gw (inf-letrans C1 bci7 63 (inf-suble bci7 Ea) m3))
       "d15-1" 'I7
       "d15-2" 'I9
       "d15-3" '(inf-lelt Xl 5 32 X5 (idpath true))
       "d15-4" 'Lw
       "d16-1" '(inf-lelt Xl 5 64 X5 (idpath true))
       "d17-1" 'G2
       "d17-2" '(inf-wlit C2 w gw (inf-letrans C2 C1 63 (inf-suble C1 Xl) (inf-letrans C1 bci7 63 (inf-suble bci7 Ea) m3)))
       "d19-1" '(inf-lttrans Fa 16 64 Fz (idpath false))
       "d20-1" 'G3
       "d20-2" '(inf-wlit C3 w gw (inf-letrans C3 C2 63 (inf-suble C2 Fa) (inf-letrans C2 C1 63 (inf-suble C1 Xl) (inf-letrans C1 bci7 63 (inf-suble bci7 Ea) m3))))
       "d23-1" 'S3
       "d23-2" '(inf-wlit Xd w gw (inf-letrans Xd 13 63 X3 (idpath false)))
       "d24-1" 'S3
       "d24-2" '(inf-lelt Xd 13 32 X3 (idpath true))
       "d24-3" 'Dw
       "d25-1" '(inf-lelt Xd 13 64 X3 (idpath true))
       "d26-1" 'G4
       "d26-2" '(inf-wlit C4 w gw (inf-letrans C4 C3 63 (inf-suble C3 Xd) (inf-letrans C3 C2 63 (inf-suble C2 Fa) (inf-letrans C2 C1 63 (inf-suble C1 Xl) (inf-letrans C1 bci7 63 (inf-suble bci7 Ea) m3)))))
       "i12-1" '(inf-lelt (add op nd) (add cap nd) (inf-pow w) (inf-addr op cap nd j7) gnd)
       "s3-1" 'Lw
       "s4-2" '(inf-lelt (natminus Da op) Da (inf-pow w) (inf-suble Da op) Dw)
       "j8j-1" '(inf-htt Da op La g13)
       "j8j-2" '(inf-hff Da op La g13)
       "m6-2" '(inf-dnowrap Da op nd g12)
       "m6-3" '(inf-letrans (add op ddj8) (add op La) oc (inf-addl op ddj8 La Hl) Gc)
       "m6-4" '(inf-letr (add (natminus nd (natminus Da op)) (inf-h Da op La)) (add (natminus nd (natminus Da op)) ddj8) nd
                 (maponpaths nat nat (lam z (add (natminus nd (natminus Da op)) z)) (inf-h Da op La) ddj8 Hm)
                 (inf-dr Da op La nd g12))
       "p2-1" '(inf-lelt (add op k) cap (inf-pow w) (inf-letrans (add op k) (add op La) cap (inf-ltle (add op k) (add op La) (inf-ltaddl op k La w2)) Gb) Cw)
       "p2-2" '(inf-cw op k La oc w2 Gc)
       "p2-3" '(inf-dknowrap Da op La k (inf-ltle op Da g11) (inf-letr ddj8 (inf-h Da op La) k f7 a1) w2)
       "p2-4" '(inf-lelt (natminus (add op k) Da) (add op k) oc (inf-suble (add op k) Da) (inf-cw op k La oc w2 Gc))
       "w2b-1" '(inf-lelt (succ k) La (inf-pow w) (inf-ltsu k La w2) Lw)
       "w2b-2" '(inf-letrans ddj8 k (succ k) a1 (inf-ltle k (succ k) (inf-ltself k)))
       "w2b-3" '(inf-subfall La k w2)
       "p3-1" '(inf-lelt (add op k) cap (inf-pow w) (inf-letrans (add op k) (add op La) cap (inf-ltle (add op k) (add op La) (inf-ltaddl op k La w3)) Gb) Cw)
       "p3-2" 'W3
       "p3-3" 'Dop
       "p3-4" '(inf-letrans (add (natminus (add op k) Da) 8) (add (add op k) 8) oc (inf-addr (natminus (add op k) Da) (add op k) 8 (inf-suble (add op k) Da)) W3)
       "s6-1" '(inf-lelt (add k 8) 266 (inf-pow w) (inf-addr k 258 8 (inf-letrans k La 258 (inf-ltle k La w3) L8)) W266)
       "w3b-1" '(inf-step8 k La w3)
       "w3b-2" '(inf-subby k La 8 w3 (idpath true))
       "p4-1" '(inf-lelt (add op k) cap (inf-pow w) (inf-letrans (add op k) (add op La) cap (inf-ltle (add op k) (add op La) (inf-ltaddl op k La w4)) Gb) Cw)
       "p4-2" 'W4
       "p4-4" '(inf-lelt (natminus op Da) op oc (inf-suble op Da) Op0)
       "s7-1" '(inf-lelt (add k 8) 266 (inf-pow w) (inf-addr k 258 8 (inf-letrans k La 258 (inf-ltle k La w4) L8)) W266)
       "w4b-1" '(inf-step8 k La w4)
       "w4b-2" '(inf-subby k La 8 w4 (idpath true))
       "p5-1" '(inf-lelt (add op k) cap (inf-pow w) (inf-letrans (add op k) (add op La) cap (inf-ltle (add op k) (add op La) (inf-ltaddl op k La w5)) Gb) Cw)
       "p5-2" '(inf-cw op k La oc w5 Gc)
       "p5-3" 'Dop
       "p5-4" '(inf-lelt (natminus (add op k) Da) (add op k) oc (inf-suble (add op k) Da) (inf-cw op k La oc w5 Gc))
       "s8-1" '(inf-lelt (add k 1) La (inf-pow w) (inf-lt1 k La w5) Lw)
       "w5b-1" '(inf-lt1 k La w5)
       "w5b-2" '(inf-subfall1 La k w5)
       "s9-1" 'Pa
       "w1b-9" '(inf-letrans C4 C3 63 (inf-suble C3 Xd) (inf-letrans C3 C2 63 (inf-suble C2 Fa) (inf-letrans C2 C1 63 (inf-suble C1 Xl) (inf-letrans C1 bci7 63 (inf-suble bci7 Ea) m3))))
       "w1b-10" '(inf-take carry ipi7 T3 C3 Xd G4 (inf-take carry ipi7 T2 C2 Fa G3 (inf-take carry ipi7 T1 C1 Xl G2 (inf-take carry ipi7 cons bci7 Ea G1 m4))))
       "w1b-11" '(inf-letrans cons0 T3 T4 (inf-letrans cons0 T2 T3 (inf-letrans cons0 T1 T2 (inf-letrans cons0 cons T1 j5 (inf-leaddr cons Ea)) (inf-leaddr T1 Xl)) (inf-leaddr T2 Fa)) (inf-leaddr T3 Xd))
       "w1b-12" '(inf-letrans op0 op (add op La) j6 (inf-leaddr op La))
       "w1b-13" 'Gb
       "w1b-14" '(inf-subby op cap La Opc Lp)}}

   ; a block's symbols, to its end: each one lowers the room left, so the loop ends whatever the tables say
   block
    {'name "inf_block" 'short "block"
     'attrs '("static" "inline")
     'ret 'int
     'params rd-params 'fields (ot-fields + '(t))
     'state (rd-state + '((op op0)))
     'arrays (rd-arrays + ot-arrays + co-arrays +
              '((Lb (v "gz_lbase") 29) (Le (v "gz_lext") 29) (Db (v "gz_dbase") 30) (De (v "gz_dext") 30)))
     'requires
      (rd-req + ot-req +
       '((gcf (inf-lt (add cap 266) (inf-pow w)))
         (Lc (pi k nat nat)) (Ls (pi k nat nat)) (Lt (pi k nat nat)) (Dc (pi k nat nat)) (Ds (pi k nat nat)) (Dt (pi k nat nat))
         (lm nat) (dm nat)
         (Lb (pi k nat nat)) (Le (pi k nat nat)) (Db (pi k nat nat)) (De (pi k nat nat))
         (h nat) (LROOT nat) (DROOT nat)
         (gl (inf-le LROOT 15)) (gd (inf-le DROOT 15)) (gh (inf-le h 16))
         (c1 (pi k nat (inf-lt (Lc k) (inf-pow h))))
         (c2 (pi k nat (inf-lt (Ls k) (inf-pow h))))
         (c3 (inf-le (inf-sum Lc 15 1) lm))
         (c4 (inf-le lm 288))
         (c5 (pi k nat (inf-lt (Dc k) (inf-pow h))))
         (c6 (pi k nat (inf-lt (Ds k) (inf-pow h))))
         (c7 (inf-le (inf-sum Dc 15 1) dm))
         (c8 (inf-le dm 32))
         (hle (pi k nat g (inf-lt k 29) (inf-le (Le k) 5)))
         (hlb (pi k nat g (inf-lt k 29) (inf-le (add (Lb k) (inf-pow (Le k))) 259)))
         (hlc (pi k nat g (inf-lt k 29) (inf-le 3 (Lb k))))
         (hde (pi k nat g (inf-lt k 30) (inf-le (De k) 13)))
         (hdb (pi k nat g (inf-lt k 30) (inf-le (add (Db k) (inf-pow (De k))) (inf-pow h))))))
     'decls '((int (x) (y) (sy) (sd)) ((named "uintptr_t") (l) (d)))
     'ensures (rd-ens + ot-ens)
     'calls [fill take sym copy fast]
     'body
      '((w1 while (tru) (natminus cap op)
         ((j1 (inf-le ip n)) (j3 (inf-le bc 63))
          (j4 (inf-bits-inv carry ip cons bc)) (j5 (inf-le cons0 cons)) (j6 (inf-le op0 op)) (j7 (inf-le op cap)))
         ((g0 ghost o0 op eo)
          (i1 join g1 (nz out)
           ((i2 if g2 (le (+ ip 8) n)
             ((i3 if g3 (le (+ op 266) cap)
               ((t1 try x "inf_fast_run" ((raw (var "r")))
                 (In n w carry out oc cap nd Lt Dt Lb Le Db De h LROOT DROOT) ())
                (i4 if g4 (nz x) ((b1 brk))))))))
           ()
           ((k1 (inf-le ip n)) (k3 (inf-le bc 63))
            (k4 (inf-bits-inv carry ip cons bc)) (k5 (inf-le cons0 cons)) (k6 (inf-le o0 op)) (k7 (inf-le op cap))))
          (t2 try sy "inf_sym" ((raw (var "r")) (taddr "lit") (tf "ltab") LROOT)
              (In n w carry (Cn Lc) (Sy Ls) (Tb Lt) (m lm) h (root LROOT)) ())
          (i5 ife g5 (lt sy 256)
           ((i6 if g6 (le cap op) ((r1 retneg 2)))
            (i7 join g7 (nz out) ((p1 poke Ot op (u8 sy))) () ())
            (s1 set op (+ op 1)))
           ((i8 if g8 (le sy 256) ((b2 brk)))
            (i9 if g9 (lt 285 sy) ((r2 retneg 1)))
            (s2 set l (at Lb (- sy 257)))
            (t3 try x "inf_take" ((raw (var "r")) (at Le (- sy 257))) (In n w carry (k (Le (natminus sy 257)))) ())
            (s3 set l (+ l x))
            (t4 try sd "inf_sym" ((raw (var "r")) (taddr "dst") (tf "dtab") DROOT)
                (In n w carry (Cn Dc) (Sy Ds) (Tb Dt) (m dm) h (root DROOT)) ())
            (i10 if g10 (lt 29 sd) ((r3 retneg 1)))
            (s4 set d (at Db sd))
            (t5 try y "inf_take" ((raw (var "r")) (at De sd)) (In n w carry (k (De sd))) ())
            (s5 set d (+ d y))
            (i11 if g11 (lt (+ op nd) d) ((r4 retneg 1)))
            (i12 if g12 (lt (- cap op) l) ((r5 retneg 2)))
            (i13 join g13 (nz out)
             ((c1 call "inf_copy" ((raw (var "r")) l d) (w l d op out oc cap nd) ()))
             () ())
            (s6 set op (+ op l))))))
        (r6 ret 0))
     'macros
      '((Cw (inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap))
        (W9 (inf-wnine w gw))
        (Oo (inf-letr op o0 op (pathsinv0 nat o0 op eo) (inf-refl op)))
        (Ok (inf-letr o0 op opi1 eo k6))
        (Op6 (inf-letrans op0 op opi1 j6 Ok))
        (Ii (natminus syt2 257))
        (L9 (inf-lidx syt2 g9))
        (Xl (Le Ii))
        (Hh (hlb Ii L9))
        (La (add (Lb Ii) xt3))
        (Lz (inf-basele (Lb Ii) Xl xt3 259 t3e7 Hh))
        (Lp (inf-lttrans 0 3 La (idpath true) (inf-letrans 3 (Lb Ii) La (hlc Ii L9) (inf-leaddr (Lb Ii) xt3))))
        (S3 (inf-lelts sdt4 29 g10))
        (Xd (De sdt4))
        (Hw (inf-powle h w (inf-letrans h 16 w gh (inf-letrans 16 32 w (idpath false) gw))))
        (Da (add (Db sdt4) yt5))
        (Dw (inf-lttrans Da (inf-pow h) (inf-pow w) (inf-basele (Db sdt4) Xd yt5 (inf-pow h) t5e7 (hdb sdt4 S3)) Hw))
        (Rm (inf-roomle opi1 cap La g12 k7))
        (Ol (inf-lttrans opi1 (add opi1 La) cap (inf-ltaddpos opi1 La Lp) Rm)))
     'proofs
      {"i2-1" '(inf-lelt (add ip 8) (add n 8) (inf-pow w) (inf-addr ip n 8 j1) gn)
       "i3-1" '(inf-lelt (add op 266) (add cap 266) (inf-pow w) (inf-addr op cap 266 j7) gcf)
       "r6-4" '(inf-letrans cons0 cons const1 j5 t1e5)
       "r6-6" '(inf-letrans op0 op opt1 j6 t1e9)
       "i1j-4" '(inf-letrans cons0 cons const1 j5 t1e5)
       "i1j-5" '(inf-letrans o0 op opt1 Oo t1e9)
       "i1j-11" 'Oo
       "i1j-17" 'Oo
       "i1j-23" 'Oo
       "t2-6" 'c1
       "t2-7" 'c2
       "t2-9" '(inf-lelt lm 288 (inf-pow w) c4 (inf-wfit288 w gw))
       "p1-1" '(inf-lttrans opi1 cap oc g6 (inf-letl cap cap oc (pathsinv0 nat oc cap (go g7)) (inf-refl cap)))
       "s1-1" '(inf-lelt (add opi1 1) cap (inf-pow w) (inf-lt1 opi1 cap g6) Cw)
       "w1b-4" '(inf-letrans cons0 consi1 const2 k5 t2e5)
       "w1b-5" '(inf-letrans op0 opi1 (add opi1 1) Op6 (inf-leaddr opi1 1))
       "w1b-6" '(inf-lt1 opi1 cap g6)
       "w1b-7" '(inf-subfrom op opi1 cap 1 Ok g6 (idpath true))
       "r6-10" '(inf-letrans cons0 consi1 const2 k5 t2e5)
       "r6-12" 'Op6
       "s2-1" '(inf-ltsu 256 syt2 g8)
       "s2-2" 'L9
       "s2-3" '(inf-lelt (Lb Ii) 259 (inf-pow w) (inf-letrans (Lb Ii) (add (Lb Ii) (inf-pow Xl)) 259 (inf-leaddr (Lb Ii) (inf-pow Xl)) Hh)
                 (inf-lelt 259 512 (inf-pow w) (idpath false) W9))
       "t3-6" '(inf-letrans Xl 5 13 (hle Ii L9) (idpath false))
       "s3-1" '(inf-lttrans La 259 (inf-pow w) Lz (inf-ltle 259 (inf-pow w) (inf-lelt 259 512 (inf-pow w) (idpath false) W9)))
       "t4-6" 'c5
       "t4-7" 'c6
       "t4-9" '(inf-wlit dm w gw (inf-letrans dm 32 63 c8 (idpath false)))
       "s4-1" 'S3
       "s4-2" '(inf-lttrans (Db sdt4) (inf-pow h) (inf-pow w)
                 (inf-lttrans (Db sdt4) (add (Db sdt4) (inf-pow Xd)) (inf-pow h) (inf-ltaddpos (Db sdt4) (inf-pow Xd) (inf-powpos Xd)) (hdb sdt4 S3)) Hw)
       "t5-6" '(hde sdt4 S3)
       "s5-1" 'Dw
       "i11-1" '(inf-lelt (add opi1 nd) (add cap nd) (inf-pow w) (inf-addr opi1 cap nd k7) gnd)
       "c1-2" 'Dw
       "c1-4" 'Rm
       "s6-1" '(inf-lelt (add opi1 La) cap (inf-pow w) Rm Cw)
       "w1b-11" '(inf-letrans cons0 const4 const5 (inf-letrans cons0 const3 const4 (inf-letrans cons0 const2 const3 (inf-letrans cons0 consi1 const2 k5 t2e5) t3e5) t4e5) t5e5)
       "w1b-12" '(inf-letrans op0 opi1 (add opi1 La) Op6 (inf-leaddr opi1 La))
       "w1b-13" 'Rm
       "w1b-14" '(inf-subfrom op opi1 cap La Ok Ol Lp)}}

   ; the blocks: each takes at least its three header bits, so the loop ends
   go
    {'name "inf_go" 'short "go"
     'attrs '("static")
     'ret '(named "int64_t")
     'params rd-params 'fields (ot-fields + '(t))
     'state (rd-state + '((op op0)) + co-state)
     'arrays (rd-arrays + ot-arrays + co-arrays)
     'requires
      (one-go (rd-req + ot-req + co-req) +
       '((gcf (inf-lt (add cap 266) (inf-pow w)))
         (Ob (pi k nat nat)) (Cs0 (pi k nat nat)) (Ct0 (pi k nat nat)) (Cc0 (pi k nat nat))
         (hord (pi k nat g (inf-lt k 19) (inf-lt (Ob k) 19)))
         (Lb (pi k nat nat)) (Le (pi k nat nat)) (Db (pi k nat nat)) (De (pi k nat nat))
         (hle (pi k nat g (inf-lt k 29) (inf-le (Le k) 5)))
         (hlb (pi k nat g (inf-lt k 29) (inf-le (add (Lb k) (inf-pow (Le k))) 259)))
         (hlc (pi k nat g (inf-lt k 29) (inf-le 3 (Lb k))))
         (hde (pi k nat g (inf-lt k 30) (inf-le (De k) 13)))
         (hdb (pi k nat g (inf-lt k 30) (inf-le (add (Db k) (inf-pow (De k))) (inf-pow h))))))
     'decls '((int (x) (last 0) (typ)))
     'ensures ()
     'calls [take stored fixed dyn block]
     'body
      '((w1 while (z last) (natminus (inf-by8 n) cons)
         ((j1 (inf-le ip n)) (j3 (inf-le bc 63))
          (j4 (inf-bits-inv 0 ip cons bc)) (j7 (inf-le op cap)))
         ((g0 ghost c0 cons ec)
          (t1 try last "inf_take" ((raw (var "r")) 1) (In n w (carry 0) (k 1)) ())
          (t2 try typ "inf_take" ((raw (var "r")) 2) (In n w (carry 0) (k 2)) ())
          (i1 ife g1 (z typ)
           ((t3 try x "inf_stored" ((raw (var "r"))) (In n w out oc cap nd) ()))
           ((i2 if g2 (le 3 typ) ((r1 retneg 1)))
            (i3 join g3 (le typ 1)
             ((c1 call "inf_fixed" ((raw (var "r"))) (w (u (inf-pow h)) q h LROOT DROOT CROOT) ()))
             ((t4 try x "inf_dyn" ((raw (var "r"))) (In n w (carry 0) q h LROOT DROOT CROOT Ob Cs0 Ct0 Cc0) ()))
             ((k1 (inf-le ip n)) (k3 (inf-le bc 63))
              (k4 (inf-bits-inv 0 ip cons bc)) (k5 (inf-le const2 cons))
              (c1 (pi k nat (inf-lt (Lc k) (inf-pow h))))
              (c2 (pi k nat (inf-lt (Ls k) (inf-pow h))))
              (c3 (inf-le (inf-sum Lc 15 1) lm))
              (c4 (inf-le lm 288))
              (c5 (pi k nat (inf-lt (Dc k) (inf-pow h))))
              (c6 (pi k nat (inf-lt (Ds k) (inf-pow h))))
              (c7 (inf-le (inf-sum Dc 15 1) dm))
              (c8 (inf-le dm 32))))
            (t5 try x "inf_block" ((raw (var "r")))
                (In n w (carry 0) out oc cap nd Lc Ls Lt Dc Ds Dt lm dm Lb Le Db De h LROOT DROOT) ())))))
        (r2 ret op))
     'macros
      '((T1 (inf-ltaddpos cons 1 (idpath true))))
     'proofs
      {"w1b-5" '(inf-consfall 0 ipt3 const3 bct3 n cons t3e4 t3e1
                  (inf-lttrans cons (add cons 1) const3 T1 (inf-letrans (add cons 1) const2 const3 (inf-letrans (add cons 1) const1 const2 t1e6 t2e5) t3e5)))
       "w1b-10" '(inf-consfall 0 ipt5 const5 bct5 n cons t5e4 t5e1
                   (inf-lttrans cons (add cons 1) const5 T1
                     (inf-letrans (add cons 1) consi3 const5 (inf-letrans (add cons 1) const2 consi3 (inf-letrans (add cons 1) const1 const2 t1e6 t2e5) k5) t5e5)))}}

   ; --- the stream: the same reader, stopped and started. a function answers 0 having moved on, -1 short
   ; of input, -2 short of room, -3 malformed; each stop leaves what the next call needs in s. the
   ; output is the wrapper's to grow, so nothing here allocates. modes, 0 to 7: head, stored's length,
   ; stored, table, code lengths' lengths, lengths, symbols, done
   ms-fields '(mode last rem hlit hdist hclen i prev stage sy len dist)
   ms-params (rd-params + '(("s" (ptr (struct "inf_ms")))))
   (ms-state l) (map (x \ [x (intern "\(x)0")]) l)
   (ms-req l) (map (x \ [(intern "\(x)0") 'nat]) l)
   ; the invariant a stop keeps, read back on the next call
   st-rd '((r1 (inf-le ip n)) (r3 (inf-le bc 63)) (r4 (inf-bits-inv carry ip cons bc)) (r5 (inf-le cons0 cons)))
   st-op '((o1 (inf-le op0 op)) (o2 (inf-le op cap)))
   (st-drop L k e)
    [[(intern "\(L)a") 'havoc 'bb ['shr64 'bb k]]
     [(intern "\(L)b") 'set 'bc ['- 'bc k]]
     [(intern "\(L)c") 'gset 'cons ['add 'cons e]]]
   (st-end L) [[L 'ife (intern "g\(L)") '(nz last)
                [[(intern "\(L)a") 'havoc 'mode 7]]
                [[(intern "\(L)b") 'havoc 'mode 0]]]]
   sym-req (sym 'requires)
   ; the codes as a stop left them
   co-inv0 (sub [('Lc . 'Lc0) ('Ls . 'Ls0) ('Dc . 'Dc0) ('Ds . 'Ds0) ('lm . 'lm0) ('dm . 'dm0)] co-ens)
   ; what a code's build asks, and what it leaves: the lengths' lengths' code, stop to stop
   st-co-req (filter (r \ !(elem <r '(Lc0 Ls0 Lt0 Dc0 Ds0 Dt0 lm0 dm0))) co-req)
   st-cc '((d1 (pi k nat (inf-lt (Cc k) (inf-pow h))))
           (d2 (pi k nat (inf-lt (Cs k) (inf-pow h))))
           (d3 (inf-le (inf-sum Cc 15 1) 19)))
   st-cc0 ('((Cc (pi k nat nat)) (Cs (pi k nat nat)) (Ct (pi k nat nat))) + st-cc)
   st-cl '((b1 (inf-le prev 15)) (b2 (pi j nat (inf-le (Lz j) 15))))

   ; a symbol, once it can be whole: 15 bits, or the input over
   sy1
    {'name "inf_sy1" 'short "sy1"
     'attrs '("static" "inline")
     'ret 'int
     'params (sym 'params) 'fields rd-fields 'state rd-state 'arrays (sym 'arrays)
     'requires sym-req
     'decls '((int (x)))
     'ensures rd-ens
     'calls [fill sym]
     'body
      '((c1 call "inf_fill" ((raw (var "r"))) (In n w carry) ())
        (i1 join g1 (lt bc 15) ((i2 if g2 (nz n) ((r1 retneg 1)))) () ())
        (t1 tryr x "inf_sym" ((raw (var "r")) (raw (var "c")) (raw (var "t")) root) (In n w carry Cn Sy Tb m h root) () 3)
        (r2 ret x))
     'macros () 'proofs {}}

   ; a block's head, three bits whole
   sthead
    {'name "inf_sthead" 'short "sthead"
     'attrs '("static" "inline")
     'ret 'int
     'params ms-params 'fields rd-fields 'sfields ms-fields
     'state (rd-state + co-state + ms-state '(last mode stage))
     'arrays (rd-arrays + co-arrays)
     'requires (rd-req + co-req + ms-req '(last mode stage) + co-inv0)
     'decls '((int (x)) (uint (typ) (dr)))
     'ensures (rd-ens + co-ens + '((e6 (inf-le (add cons0 3) cons))))
     'calls [take fixed]
     'body
      ['(t1 try x "inf_take" ((raw (var "r")) 3) (In n w carry (k 3)) ())
       '(d1 havoc last (low x 1))
       '(d2 havoc typ (shr64 x 1))
       ['i1 'ife 'g1 '(z typ)
        (['(d3 set dr (low bc 7))] + st-drop 'd4 'dr 'dr + ['(d5 havoc mode 1)])
        ['(i2 if g2 (le 3 typ) ((r1 retneg 3)))
         '(i3 ife g3 (le typ 1)
           ((c1 call "inf_fixed" ((raw (var "r"))) (w (u (inf-pow h)) q h LROOT DROOT CROOT) ())
            (d6 havoc mode 6)
            (d7 havoc stage 0))
           ((d8 havoc mode 3)))]]
       '(r2 ret 0)]
     'macros ()
     'proofs {"d4b-1" '(inf-modle8 bct1)}}

   ; a stored block's two lengths, whole
   stlen
    {'name "inf_stlen" 'short "stlen"
     'attrs '("static" "inline")
     'ret 'int
     'params ms-params 'fields rd-fields 'sfields ms-fields
     'state (rd-state + ms-state '(rem mode))
     'arrays rd-arrays
     'requires (rd-req + ms-req '(rem mode))
     'decls '((uint (ln) (nl)) ((named "uint64_t") (y)))
     'ensures rd-ens
     'calls [fill]
     'body
      (['(c1 call "inf_fill" ((raw (var "r"))) (In n w carry) ())
        '(i1 if g1 (lt bc 32) ((r1 retneg 1)))
        '(d1 havoc ln (mask bb 16))
        '(d2 havoc y (shr64 bb 16))
        '(d3 havoc nl (mask y 16))
        '(i2 if g2 (ne (low (bxor ln 65535) 65535) nl) ((r2 retneg 3)))]
       + st-drop 'd4 32 32
       + ['(d5 havoc rem ln) '(d6 havoc mode 2) '(r3 ret 0)])
     'macros () 'proofs {}}

   ; the table's three counts, whole, and the lengths' lengths cleared
   sttab
    {'name "inf_sttab" 'short "sttab"
     'attrs '("static" "inline")
     'ret 'int
     'params ms-params 'fields rd-fields 'sfields ms-fields
     'state (rd-state + '((Cl Cl0)) + ms-state '(hlit hdist hclen i mode))
     'arrays (rd-arrays + '((Cl (s "cl") 19)))
     'requires (rd-req + '((Cl0 (pi k nat nat))) + ms-req '(hlit hdist hclen i mode))
     'decls '(((named "uint64_t") (y)))
     'ensures (rd-ens + '((a2 (pi k nat (inf-le (Cl k) 15)))))
     'calls [fill]
     'body
      (['(c1 call "inf_fill" ((raw (var "r"))) (In n w carry) ())
        '(i1 if g1 (lt bc 14) ((r1 retneg 1)))
        '(d1 havoc hlit (+ (mask bb 5) 257))
        '(d2 havoc y (shr64 bb 5))
        '(d3 havoc hdist (+ (mask y 5) 1))
        '(d4 havoc y (shr64 bb 10))
        '(d5 havoc hclen (+ (mask y 4) 4))]
       + st-drop 'd6 14 14
       + ['(c2 clear Cl (szof (dot (deref (var "s")) "cl")))
          '(d7 havoc i 0) '(d8 havoc mode 4) '(r2 ret 0)])
     'macros
      '((M1 (inf-mod (inf-pow 5) bbc1))
        (M2 (inf-mod (inf-pow 5) yd2))
        (M3 (inf-mod (inf-pow 4) yd4)))
     'proofs
      {"d1-2" '(inf-lelt (add M1 257) 288 (inf-pow w) (inf-addr M1 31 257 (inf-ltsle M1 31 (inf-masklt bbc1 5))) (inf-wfit288 w gw))
       "d3-2" '(inf-wlit (add M2 1) w gw (inf-letrans (add M2 1) 32 63 (inf-addr M2 31 1 (inf-ltsle M2 31 (inf-masklt yd2 5))) (idpath false)))
       "d5-2" '(inf-wlit (add M3 4) w gw (inf-letrans (add M3 4) 19 63 (inf-addr M3 15 4 (inf-ltsle M3 15 (inf-masklt yd4 4))) (idpath false)))
       "r2-5" '(lam k (idpath false))}}

   ; the lengths' lengths, and their code built
   stcl
    {'name "inf_stcl" 'short "stcl"
     'attrs '("static" "inline")
     'ret 'int
     'params ms-params 'fields (rd-fields + '(t)) 'sfields ms-fields
     'state (rd-state + '((Cl Cl0) (Lz Lz0) (Cs Cs0) (Ct Ct0) (Cc Cc0)) + ms-state '(i prev stage mode))
     'arrays (rd-arrays + '((Cl (s "cl") 19) (Lz (s "lens") 320) (Ob (v "gz_clord") 19)
                            (Cc (t "cl") 16) (Cs (t "csym") 19) (Ct (t "ctab") (inf-pow CROOT))))
     'requires
      (rd-req + st-co-req
       + '((Cl0 (pi k nat nat)) (Lz0 (pi k nat nat)) (Cs0 (pi k nat nat)) (Ct0 (pi k nat nat)) (Cc0 (pi k nat nat))
           (Ob (pi k nat nat)) (hclen nat)
           (hord (pi k nat g (inf-lt k 19) (inf-lt (Ob k) 19)))
           (a2 (pi k nat (inf-le (Cl0 k) 15))))
       + ms-req '(i prev stage mode))
     'decls '((int (x)))
     'ensures
      (rd-ens + st-cc
       + '((b1 (inf-le prev 15))
           (b2 (pi j nat (inf-le (Lz j) 15)))
           (a2 (pi k nat (inf-le (Cl k) 15)))))
     'calls [take build]
     'body
      '((i0 if g0 (lt 19 hclen) ((r0 retneg 3)))
        (w1 while (lt i hclen) (natminus hclen i)
         ((a2 (pi k nat (inf-le (Cl k) 15)))
          (r1 (inf-le ip n)) (r3 (inf-le bc 63)) (r4 (inf-bits-inv carry ip cons bc)) (r5 (inf-le cons0 cons)))
         ((t1 try x "inf_take" ((raw (var "r")) 3) (In n w carry (k 3)) ())
          (s1 aset Cl (at Ob i) x)
          (s2 set i (+ i 1))))
        (c1 call "inf_build" ((taddr "cl") (raw (dot (deref (var "s")) "cl")) 19 (tf "csym") (tf "ctab") CROOT)
            ((Ln Cl) (nsym 19) (root CROOT) q (u (inf-pow h)) w) ((Cn Cc) (Sy Cs) (Tb Ct)))
        (c2 clear Lz (szof (dot (deref (var "s")) "lens")))
        (d1 havoc i 0)
        (d2 set prev 0)
        (d3 havoc stage 0)
        (d4 havoc mode 5)
        (r2 ret 0))
     'macros
      '((Hi (inf-lttrans i hclen 19 w1 g0))
        (Pw (inf-powle h w (inf-letrans h 16 w gh (inf-letrans 16 32 w (idpath false) gw)))))
     'proofs
      {"s1-1" 'Hi
       "s1-2" '(hord i Hi)
       "s1-3" '(inf-lttrans xt1 8 (inf-pow w) t1e7 (inf-powle 3 w (inf-letrans 3 32 w (idpath false) gw)))
       "s2-1" '(inf-wlit (add i 1) w gw (inf-letrans (add i 1) 19 63 (inf-lt1 i 19 Hi) (idpath false)))
       "w1b-1" '(inf-updle Cl (Ob i) xt1 15 a2 (inf-letrans xt1 8 15 (inf-ltle xt1 8 t1e7) (idpath false)))
       "w1b-6" '(inf-subfall1 hclen i w1)
       "c1-1" '(lam k g (a2 k))
       "c1-2" '(inf-lttrans 19 320 q (idpath true) (inf-ltle 320 q gq2))
       "c1-4" 'Pw
       "r2-9" '(lam j (idpath false))}}

   ; the code lengths: a run may overshoot, and its write is clamped. a stop between a symbol and its
   ; extra bits resumes on stage
   stln
    {'name "inf_stln" 'short "stln"
     'attrs '("static" "inline")
     'ret 'int
     'params ms-params 'fields (rd-fields + '(t)) 'sfields ms-fields
     'state (rd-state + co-state + '((Lz Lz0)) + ms-state '(i prev stage sy mode))
     'arrays (rd-arrays + co-arrays + '((Lz (s "lens") 320) (Cs (t "csym") 19) (Ct (t "ctab") (inf-pow CROOT))))
     'requires
      (rd-req + co-req + st-cc0
       + '((Lz0 (pi k nat nat)) (hlit nat) (hdist nat)
           (b2 (pi j nat (inf-le (Lz0 j) 15))))
       + ms-req '(i prev stage sy mode) + co-inv0)
     'decls '((int (x)) (uint (tot) (rr) (v) (k)))
     'ensures (rd-ens + co-ens + st-cl)
     'calls [take sy1 build]
     'body
      ['(i0 if g0 (lt 288 hlit) ((r0 retneg 3)))
       '(i00 if g00 (lt 32 hdist) ((r00 retneg 3)))
       '(i01 if g01 (lt 15 prev) ((r01 retneg 3)))
       '(s0 set tot (+ hlit hdist))
       ['w1 'while '(lt i tot) '(natminus tot i)
        (['(b1 (inf-le prev 15)) '(b2 (pi j nat (inf-le (Lz j) 15)))] + st-rd)
        [['j0 'join 'g2 '(z stage)
          '((t1 try x "inf_sy1" ((raw (var "r")) (taddr "cl") (tf "ctab") CROOT)
                (In n w carry (Cn Cc) (Sy Cs) (Tb Ct) (m 19) h (root CROOT)) ())
            (d1 havoc sy x)
            (d2 havoc stage 1))
          ()
          st-rd]
         ['j1 'join 'g3 '(lt sy 16)
          '((s1 set rr 1) (s2 set v sy))
          ['(i1 if g4 (lt 18 sy) ((r1 retneg 3)))
           ['j2 'join 'g5 '(le sy 16)
            '((t2 try x "inf_take" ((raw (var "r")) 2) (In n w carry (k 2)) ())
              (s3 set rr (+ x 3))
              (s4 set v prev))
            [['j3 'join 'g6 '(le sy 17)
              '((t3 try x "inf_take" ((raw (var "r")) 3) (In n w carry (k 3)) ())
                (s5 set rr (+ x 3)))
              '((t4 try x "inf_take" ((raw (var "r")) 7) (In n w carry (k 7)) ())
                (s6 set rr (+ x 11)))
              ('((f1 (inf-lt 0 rr)) (f2 (inf-le rr 138))) + st-rd)]
             '(s7 set v 0)]
            ('((f3 (inf-lt 0 rr)) (f4 (inf-le rr 138)) (f5 (inf-le v 15))) + st-rd)]]
          ('((f6 (inf-lt 0 rr)) (f7 (inf-le rr 138)) (f8 (inf-le v 15))) + st-rd)]
         '(w3 for k 0 rr
           ((c1 (inf-le k rr))
            (c2 (pi j nat (inf-le (Lz j) 15))))
           ((i2 if g7 (lt (+ i k) 320) ((s8 aset Lz (+ i k) v)))))
         '(s9 set i (+ i rr))
         '(s10 set prev v)
         '(d3 havoc stage 0)]]
       '(c4 call "inf_build" ((taddr "lit") (raw (dot (deref (var "s")) "lens")) hlit (tf "lsym") (tf "ltab") LROOT)
            ((Ln Lz) (nsym hlit) (root LROOT) q (u (inf-pow h)) w) ((Cn Lc) (Sy Ls) (Tb Lt)))
       '(d4 gset lm hlit)
       '(c5 call "inf_build" ((taddr "dst") (raw (bin + (dot (deref (var "s")) "lens") (dot (deref (var "s")) "hlit"))) hdist (tf "dsym") (tf "dtab") DROOT)
            ((Ln (inf-shift Lz hlit)) (nsym hdist) (root DROOT) q (u (inf-pow h)) w) ((Cn Dc) (Sy Ds) (Tb Dt)))
       '(d5 gset dm hdist)
       '(d6 havoc mode 6)
       '(d7 havoc stage 0)
       '(r2 ret 0)]
     'macros
      '((Pw (inf-powle h w (inf-letrans h 16 w gh (inf-letrans 16 32 w (idpath false) gw))))
        (W9 (inf-wnine w gw))
        (W3 (inf-lelt 320 512 (inf-pow w) (idpath false) W9))
        (W4 (inf-lelt 458 512 (inf-pow w) (idpath false) W9))
        (W1 (inf-lelt 138 512 (inf-pow w) (idpath false) W9))
        (T3 (inf-add2 hlit 288 hdist 32 g0 g00))
        (Ti (inf-letrans i (add hlit hdist) 320 (inf-ltle i (add hlit hdist) w1) T3))
        (Ik (inf-add2 i 320 k 138 Ti (inf-letrans k rrj1 138 (inf-ltle k rrj1 w3) f7)))
        (Rk (inf-letrans (succ k) rrj1 138 (inf-ltsu k rrj1 w3) f7))
        (X2 (inf-addr xt2 3 3 (inf-ltsle xt2 3 t2e7)))
        (X3 (inf-addr xt3 7 3 (inf-ltsle xt3 7 t3e7)))
        (X4 (inf-addr xt4 127 11 (inf-ltsle xt4 127 t4e7)))
        (Xq (inf-ltle 320 q gq2)))
     'proofs
      {"s0-1" '(inf-lelt (add hlit hdist) 320 (inf-pow w) T3 W3)
       "j1j-3" '(inf-ltsle syj0 15 g3)
       "s3-1" '(inf-wlit (add xt2 3) w gw (inf-letrans (add xt2 3) 6 63 X2 (idpath false)))
       "j2j-1" '(inf-pos3 xt2 3 (idpath true))
       "j2j-2" '(inf-letrans (add xt2 3) 6 138 X2 (idpath false))
       "s5-1" '(inf-wlit (add xt3 3) w gw (inf-letrans (add xt3 3) 10 63 X3 (idpath false)))
       "j3j-1" '(inf-pos3 xt3 3 (idpath true))
       "j3j-2" '(inf-letrans (add xt3 3) 10 138 X3 (idpath false))
       "s6-1" '(inf-lelt (add xt4 11) 512 (inf-pow w) (inf-letrans (add xt4 11) 138 512 X4 (idpath false)) (inf-lttrans 512 1024 (inf-pow w) (idpath true) (inf-powle 10 w (inf-letrans 10 32 w (idpath false) gw))))
       "j3j-7" '(inf-pos3 xt4 11 (idpath true))
       "j3j-8" 'X4
       "i2-1" '(inf-lelt (add i k) 458 (inf-pow w) Ik W4)
       "s8-1" '(inf-lelt (add i k) 458 (inf-pow w) Ik W4)
       "w3b-1" '(inf-lelt (succ k) 138 (inf-pow w) Rk W1)
       "w3b-2" '(inf-ltsu k rrj1 w3)
       "w3b-3" '(inf-updle Lz (add i k) vj1 15 c2 f8)
       "w3b-4" '(inf-subfall rrj1 k w3)
       "w3b-5" '(inf-lelt (succ k) 138 (inf-pow w) Rk W1)
       "w3b-6" '(inf-ltsu k rrj1 w3)
       "w3b-8" '(inf-subfall rrj1 k w3)
       "s9-1" '(inf-lelt (add i rrj1) 458 (inf-pow w) (inf-add2 i 320 rrj1 138 Ti f7) W4)
       "w1b-7" '(inf-subby i (add hlit hdist) rrj1 w1 f6)
       "c4-1" '(lam k g (b2 k))
       "c4-2" '(inf-lelt hlit 288 q g0 (inf-lttrans 288 320 q (idpath true) Xq))
       "c4-4" 'Pw
       "c5-1" '(lam k g (b2 (add hlit k)))
       "c5-2" '(inf-lelt hdist 32 q g00 (inf-lttrans 32 320 q (idpath true) Xq))
       "c5-4" 'Pw}}

   ; stored's bytes: what the buffer holds first, then straight from the input. what bb holds past bc is
   ; a byte ip has not passed, so it goes before ip does
   ststo
    {'name "inf_ststo" 'short "ststo"
     'attrs '("static" "inline")
     'ret 'int
     'params ms-params 'fields ot-fields 'sfields ms-fields
     'state (rd-state + '((op op0)) + ms-state '(rem mode))
     'arrays (rd-arrays + ot-arrays)
     'requires (rd-req + ot-req + '((gz (inf-lt 0 out)) (last nat)) + ms-req '(rem mode))
     'decls '(((named "uintptr_t") (k)))
     'ensures (rd-ens + ot-ens)
     'body
      (['(j0 join g0 (nz rem)
          ((w1 while (nz rem) rem
            ((r1 (inf-le ip n)) (r3 (inf-le bc 63)) (r4 (inf-bits-inv carry ip cons bc)) (r5 (inf-le cons0 cons))
             (o1 (inf-le op0 op)) (o2 (inf-le op cap)))
            ((i1 if g1 (lt bc 8) ((b1 brk)))
             (i2 if g2 (le cap op) ((r6 retneg 2)))
             (p1 poke Ot op (u8 (low bb 255)))
             (s1 set op (+ op 1))
             (d1a havoc bb (shr64 bb 8))
             (d1b set bc (- bc 8))
             (d1c gset cons (add cons 8))
             (s2 dec rem (- rem 1)))))
          ()
          ((r1 (inf-le ip n)) (r3 (inf-le bc 63)) (r4 (inf-bits-inv carry ip cons bc)) (r5 (inf-le cons0 cons))
           (o1 (inf-le op0 op)) (o2 (inf-le op cap))))
        '(j1 join g3 (nz rem)
          ((d2 havoc bb 0)
           (s3 set k (- n ip))
           (j2 join g4 (lt rem k) ((s4 set k rem)) ()
            ((f1 (inf-le k rem)) (f2 (inf-le k (natminus n ip)))))
           (j3 join g5 (lt (- cap op) k) ((s5 set k (- cap op))) ()
            ((f3 (inf-le k rem)) (f4 (inf-le k (natminus n ip))) (f5 (inf-le k (natminus cap op)))))
           (m1 mcopy Ot op In ip k)
           (s6 set op (+ op k))
           (s7 set ip (+ ip k))
           (d3 gset cons (add cons (inf-by8 k)))
           (s8 dec rem (- rem k))
           (i3 if g6 (nz rem)
            ((i4 if g7 (lt ip n) ((r7 retneg 2)))
             (r8 retneg 1))))
          ()
          ((r1 (inf-le ip n)) (r3 (inf-le bc 63)) (r4 (inf-bits-inv carry ip cons bc)) (r5 (inf-le cons0 cons))
           (o1 (inf-le op0 op)) (o2 (inf-le op cap))))]
       + st-end 'e1 + ['(r9 ret 0)])
     'macros
      '((Cw (inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap))
        (Co (inf-letl cap cap oc (pathsinv0 nat oc cap (go gz)) (inf-refl cap)))
        (Nw (inf-lelt n (add n 8) (inf-pow w) (inf-leaddr n 8) gn))
        (Rm (inf-roomle opj0 cap kj3 f5 o2))
        (Rn (inf-roomle ip0 n kj3 f4 gi))
        (Op1 (inf-lt1 op cap g2)))
     'proofs
      {"p1-1" '(inf-lttrans op cap oc g2 Co)
       "s1-1" '(inf-lelt (add op 1) cap (inf-pow w) Op1 Cw)
       "s2-1" '(inf-ltsu 0 rem w1)
       "w1b-6" 'Op1
       "w1b-7" '(inf-dec1 rem w1)
       "m1-1" '(inf-letl (add opj0 kj3) cap oc (pathsinv0 nat oc cap (go gz)) Rm)
       "m1-2" 'Rn
       "s6-1" '(inf-lelt (add opj0 kj3) cap (inf-pow w) Rm Cw)
       "s7-1" '(inf-lelt (add ip0 kj3) n (inf-pow w) Rn Nw)
       "j1j-1" 'Rn
       "j1j-3" '(inf-advb carry ip0 consj0 bcj0 kj3 r4)
       "j1j-6" 'Rm}}

   ; a block's symbols. the fast lane is the one-shot's; past it, one symbol at a time, and each stage
   ; says what is already taken. a stage read back answers for its own values: the literal, the length
   ; code, the distance code and the length are looked at where they are used. the room lowers each
   ; way round, so the loop ends
   stsy
    {'name "inf_stsy" 'short "stsy"
     'attrs '("static" "inline")
     'ret 'int
     'params ms-params 'fields (ot-fields + '(t)) 'sfields ms-fields
     'state (rd-state + '((op op0)) + ms-state '(mode stage sy len dist))
     'arrays (block 'arrays)
     'requires (block 'requires + '((gz (inf-lt 0 out)) (last nat)) + ms-req '(mode stage sy len dist))
     'decls '((int (x) (y)) ((named "uintptr_t") (l) (d)))
     'ensures (rd-ens + ot-ens)
     'calls [take sy1 copy fast]
     'body
      ['(w1 while (tru) (natminus cap op)
         ((r1 (inf-le ip n)) (r3 (inf-le bc 63)) (r4 (inf-bits-inv carry ip cons bc)) (r5 (inf-le cons0 cons))
          (o1 (inf-le op0 op)) (o2 (inf-le op cap)))
         ((g0 ghost o0 op eo)
          (i0 join g0 (z stage)
           ((i1 join g1 (le (+ ip 8) n)
             ((i3 if g3 (le (+ op 266) cap)
               ((t1 tryr x "inf_fast_run" ((raw (var "r")))
                 (In n w carry out oc cap nd Lt Dt Lb Le Db De h LROOT DROOT) () 3)
                (i4 if g4 (nz x)
                 ((e1 ife ge1 (nz last) ((e1a havoc mode 7)) ((e1b havoc mode 0)))
                  (r0 ret 0))))))
             ()
             ((k1 (inf-le ip n)) (k3 (inf-le bc 63)) (k4 (inf-bits-inv carry ip cons bc)) (k5 (inf-le cons0 cons))
              (k6 (inf-le o0 op)) (k7 (inf-le op cap))))
            (t2 try x "inf_sy1" ((raw (var "r")) (taddr "lit") (tf "ltab") LROOT)
                (In n w carry (Cn Lc) (Sy Ls) (Tb Lt) (m lm) h (root LROOT)) ())
            (d1 havoc sy x)
            (i5 ife g5 (lt x 256)
             ((d2 havoc stage 4))
             ((i6 if g6 (le x 256)
               ((e2 ife ge2 (nz last) ((e2a havoc mode 7)) ((e2b havoc mode 0)))
                (r1 ret 0)))
              (d3 havoc stage 1))))
           ()
           ((k1 (inf-le ip n)) (k3 (inf-le bc 63)) (k4 (inf-bits-inv carry ip cons bc)) (k5 (inf-le cons0 cons))
            (k6 (inf-le o0 op)) (k7 (inf-le op cap))))
          (i7 ife g7 (eq stage 4)
           ((i8 if g8 (le cap op) ((r2 retneg 2)))
            (i9 if g9 (lt 255 sy) ((r3 retneg 3)))
            (p1 poke Ot op (u8 sy))
            (s1 set op (+ op 1))
            (d4 havoc stage 0))
           ((j1 join g10 (eq stage 1)
             ((i10 if g11 (lt sy 257) ((r4 retneg 3)))
              (i11 if g12 (lt 285 sy) ((r5 retneg 3)))
              (s2 set l (at Lb (- sy 257)))
              (t3 try y "inf_take" ((raw (var "r")) (at Le (- sy 257))) (In n w carry (k (Le (natminus sy 257)))) ())
              (d5 havoc len (+ l y))
              (d6 havoc stage 2))
             ()
             ((m1 (inf-le ip n)) (m3 (inf-le bc 63)) (m4 (inf-bits-inv carry ip cons bc)) (m5 (inf-le cons0 cons))))
            (j2 join g13 (eq stage 2)
             ((t4 try x "inf_sy1" ((raw (var "r")) (taddr "dst") (tf "dtab") DROOT)
                  (In n w carry (Cn Dc) (Sy Ds) (Tb Dt) (m dm) h (root DROOT)) ())
              (d7 havoc sy x)
              (d8 havoc stage 3))
             ()
             ((n1 (inf-le ip n)) (n3 (inf-le bc 63)) (n4 (inf-bits-inv carry ip cons bc)) (n5 (inf-le cons0 cons))))
            (j3 join g14 (eq stage 3)
             ((i12 if g15 (lt 29 sy) ((r6 retneg 3)))
              (s3 set d (at Db sy))
              (t5 try y "inf_take" ((raw (var "r")) (at De sy)) (In n w carry (k (De sy))) ())
              (d9 havoc dist (+ d y))
              (d10 havoc stage 5))
             ()
             ((q1 (inf-le ip n)) (q3 (inf-le bc 63)) (q4 (inf-bits-inv carry ip cons bc)) (q5 (inf-le cons0 cons))))
            (i13 if g16 (lt (pow 15) dist) ((r7 retneg 3)))
            (i14 if g17 (lt (+ op nd) dist) ((r8 retneg 3)))
            (i15 if g18 (z len) ((r9 retneg 3)))
            (i16 if g19 (lt (- cap op) len) ((r10 retneg 2)))
            (c1 call "inf_copy" ((raw (var "r")) (raw (dot (deref (var "s")) "len")) (raw (dot (deref (var "s")) "dist"))) (w (l len) (d dist) op out oc cap nd) ())
            (s4 set op (+ op len))
            (d11 havoc stage 0)))))]
     'macros
      '((Cw (inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap))
        (W9 (inf-wnine w gw))
        (W5 (inf-lelt 259 512 (inf-pow w) (idpath false) W9))
        (Oo (inf-letr op o0 op (pathsinv0 nat o0 op eo) (inf-refl op)))
        (Ok1 (inf-letr o0 op opi1 eo k6))
        (Ok (inf-letr o0 op opi0 eo k6))
        (Oz (inf-letrans op0 op opi0 o1 Ok))
        (Ii (natminus syi0 257))
        (L9 (inf-lidx syi0 g12))
        (Xl (Le Ii))
        (Hh (hlb Ii L9))
        (La (add (Lb Ii) yt3))
        (Lz (inf-basele (Lb Ii) Xl yt3 259 t3e7 Hh))
        (S3 (inf-lelts syj2 29 g15))
        (Xd (De syj2))
        (Hw (inf-powle h w (inf-letrans h 16 w gh (inf-letrans 16 32 w (idpath false) gw))))
        (Da (add (Db syj2) yt5))
        (Dw (inf-lttrans Da (inf-pow h) (inf-pow w) (inf-basele (Db syj2) Xd yt5 (inf-pow h) t5e7 (hdb syj2 S3)) Hw))
        (P15 (inf-powlt 15 w (inf-lttrans 15 16 w (idpath true) (inf-letrans 16 32 w (idpath false) gw))))
        (Rm (inf-roomle opi0 cap lenj1 g19 k7))
        (Ol (inf-lttrans opi0 (add opi0 lenj1) cap (inf-ltaddpos opi0 lenj1 g18) Rm))
        (Lt8 (inf-letl cap cap oc (pathsinv0 nat oc cap (go gz)) (inf-refl cap))))
     'proofs
      {"i1-1" '(inf-lelt (add ip 8) (add n 8) (inf-pow w) (inf-addr ip n 8 r1) gn)
       "i3-1" '(inf-lelt (add op 266) (add cap 266) (inf-pow w) (inf-addr op cap 266 o2) gcf)
       "i1j-5" '(inf-letrans o0 op opt1 Oo t1e9)
       "i1j-11" 'Oo
       "i1j-17" 'Oo
       "t2-9" '(inf-lelt lm 288 (inf-pow w) c4 (inf-wfit288 w gw))
       "r1-6" '(inf-letrans op0 op opi1 o1 Ok1)
       "r1-12" '(inf-letrans op0 op opi1 o1 Ok1)
       "i0j-17" 'Oo
       "p1-1" '(inf-lttrans opi0 cap oc g8 Lt8)
       "s1-1" '(inf-lelt (add opi0 1) cap (inf-pow w) (inf-lt1 opi0 cap g8) Cw)
       "w1b-5" '(inf-letrans op0 opi0 (add opi0 1) Oz (inf-leaddr opi0 1))
       "w1b-6" '(inf-lt1 opi0 cap g8)
       "w1b-7" '(inf-subfrom op opi0 cap 1 Ok g8 (idpath true))
       "s2-2" 'L9
       "s2-3" '(inf-lelt (Lb Ii) 259 (inf-pow w) (inf-letrans (Lb Ii) (add (Lb Ii) (inf-pow Xl)) 259 (inf-leaddr (Lb Ii) (inf-pow Xl)) Hh) W5)
       "t3-6" '(inf-letrans Xl 5 13 (hle Ii L9) (idpath false))
       "d5-1" '(inf-lttrans La 259 (inf-pow w) Lz (inf-ltle 259 (inf-pow w) W5))
       "s3-2" '(inf-lttrans (Db syj2) (inf-pow h) (inf-pow w)
                 (inf-lttrans (Db syj2) (add (Db syj2) (inf-pow Xd)) (inf-pow h) (inf-ltaddpos (Db syj2) (inf-pow Xd) (inf-powpos Xd)) (hdb syj2 S3)) Hw)
       "t5-6" '(hde syj2 S3)
       "d9-1" 'Dw
       "i13-2" 'P15
       "i14-1" '(inf-lelt (add opi0 nd) (add cap nd) (inf-pow w) (inf-addr opi0 cap nd k7) gnd)
       "c1-2" '(inf-lelt distj3 (inf-pow 15) (inf-pow w) g16 P15)
       "c1-4" 'Rm
       "s4-1" '(inf-lelt (add opi0 lenj1) cap (inf-pow w) Rm Cw)
       "w1b-12" '(inf-letrans op0 opi0 (add opi0 lenj1) Oz (inf-leaddr opi0 lenj1))
       "w1b-13" 'Rm
       "w1b-14" '(inf-subfrom op opi0 cap lenj1 Ok Ol g18)}}

   ; what a stop keeps, whole
   st-names '(last rem hclen i prev stage sy len dist mode hlit hdist)
   st-all (rd-state + '((op op0)) + co-state + '((Cl Cl0) (Lz Lz0) (Cs Cs0) (Ct Ct0) (Cc Cc0)) + ms-state st-names)
   st-arrays (block 'arrays + '((Cl (s "cl") 19) (Lz (s "lens") 320) (Ob (v "gz_clord") 19)
                                (Cc (t "cl") 16) (Cs (t "csym") 19) (Ct (t "ctab") (inf-pow CROOT))))
   st-req
    (rd-req + ot-req + co-req +
     '((gcf (inf-lt (add cap 266) (inf-pow w))) (gz (inf-lt 0 out))
       (Cl0 (pi k nat nat)) (Lz0 (pi k nat nat)) (Cs0 (pi k nat nat)) (Ct0 (pi k nat nat)) (Cc0 (pi k nat nat))
       (Ob (pi k nat nat))
       (hord (pi k nat g (inf-lt k 19) (inf-lt (Ob k) 19)))
       (Lb (pi k nat nat)) (Le (pi k nat nat)) (Db (pi k nat nat)) (De (pi k nat nat))
       (hle (pi k nat g (inf-lt k 29) (inf-le (Le k) 5)))
       (hlb (pi k nat g (inf-lt k 29) (inf-le (add (Lb k) (inf-pow (Le k))) 259)))
       (hlc (pi k nat g (inf-lt k 29) (inf-le 3 (Lb k))))
       (hde (pi k nat g (inf-lt k 30) (inf-le (De k) 13)))
       (hdb (pi k nat g (inf-lt k 30) (inf-le (add (Db k) (inf-pow (De k))) (inf-pow h)))))
     + ms-req st-names + co-inv0
     + sub [('Cc . 'Cc0) ('Cs . 'Cs0) ('prev . 'prev0) ('Lz . 'Lz0) ('Cl . 'Cl0)]
           (st-cc + st-cl + '((a2 (pi k nat (inf-le (Cl k) 15))))))
   st-ens (rd-ens + ot-ens + co-ens + st-cc + st-cl + '((a2 (pi k nat (inf-le (Cl k) 15)))))
   st-inst '(In n w carry out oc cap nd q h LROOT DROOT CROOT Ob Lb Le Db De)
   ; every mode but the head, in stream order: each arm moves on or stops, so a run reaches the next head
   strest
    {'name "inf_strest" 'short "strest"
     'attrs '("static" "inline")
     'ret 'int
     'params ms-params 'fields (ot-fields + '(t)) 'sfields ms-fields
     'state st-all
     'arrays st-arrays
     'requires st-req
     'decls '((int (x)))
     'ensures st-ens
     'calls [stlen ststo sttab stcl stln stsy]
     'body
      [['j1 'join 'g1 '(eq mode 1)
        '((t1 try x "inf_stlen" ((raw (var "r")) (raw (var "s"))) (In n w carry) ()))
        () st-rd]
       ['j2 'join 'g2 '(eq mode 2)
        '((t2 try x "inf_ststo" ((raw (var "r")) (raw (var "s"))) (In n w carry out oc cap nd last) ()))
        () (st-rd + st-op)]
       ['j3 'join 'g3 '(eq mode 3)
        '((t3 try x "inf_sttab" ((raw (var "r")) (raw (var "s"))) (In n w carry) ()))
        () (st-rd + '((a2 (pi k nat (inf-le (Cl k) 15)))))]
       ['j4 'join 'g4 '(eq mode 4)
        '((t4 try x "inf_stcl" ((raw (var "r")) (raw (var "s")))
              (In n w carry q h LROOT DROOT CROOT Ob hclen) ()))
        () (st-rd + st-cc + st-cl + '((a2 (pi k nat (inf-le (Cl k) 15)))))]
       ['j5 'join 'g5 '(eq mode 5)
        '((t5 try x "inf_stln" ((raw (var "r")) (raw (var "s")))
              (In n w carry q h LROOT DROOT CROOT Cc Cs Ct hlit hdist) ()))
        () (st-rd + co-ens + st-cl)]
       ['j6 'join 'g6 '(eq mode 6)
        '((t6 try x "inf_stsy" ((raw (var "r")) (raw (var "s")))
              (In n w carry out oc cap nd Lc Ls Lt Dc Ds Dt lm dm Lb Le Db De h LROOT DROOT last) ()))
        () (st-rd + st-op)]
       '(r1 ret 0)]
     'macros () 'proofs {}}

   ; one call, to the end of the stream or the first stop: 1 ended. each head takes three bits, so the
   ; loop ends
   ststep
    {'name "inf_ststep" 'short "ststep"
     'attrs '("static")
     'ret 'int
     'params ms-params 'fields (ot-fields + '(t)) 'sfields ms-fields
     'state st-all
     'arrays st-arrays
     'requires st-req
     'decls '((int (x)))
     'ensures st-ens
     'calls [sthead strest]
     'body
      [['t1 'try 'x "inf_strest" '((raw (var "r")) (raw (var "s"))) st-inst ()]
       ['w1 'while '(z mode) '(natminus (add carry (inf-by8 n)) cons)
        (st-rd + st-op + co-ens + st-cc + st-cl + '((a2 (pi k nat (inf-le (Cl k) 15)))))
        ['(g0 ghost c0 cons ec)
         '(t2 try x "inf_sthead" ((raw (var "r")) (raw (var "s"))) (In n w carry q h LROOT DROOT CROOT) ())
         ['t3 'try 'x "inf_strest" '((raw (var "r")) (raw (var "s"))) st-inst ()]]]
       '(r1 ret 1)]
     'macros ()
     'proofs
      {"w1b-21" '(inf-consfall carry ipt3 const3 bct3 n cons t3e4 t3e1
                  (inf-lttrans cons (add cons 3) const3 (inf-ltaddpos cons 3 (idpath true))
                    (inf-letrans (add cons 3) const2 const3 t2e6 t3e5)))}}

   ; --- the constants, one list for the C and the uu -----------------------------------------------
   inf-tables
    '(("gz_lbase" "uint16_t" inf-tlb (3 4 5 6 7 8 9 10 11 13 15 17 19 23 27 31 35 43 51 59 67 83 99 115 131 163 195 227 258))
      ("gz_lext" "uint8_t" inf-tle (0 0 0 0 0 0 0 0 1 1 1 1 2 2 2 2 3 3 3 3 4 4 4 4 5 5 5 5 0))
      ("gz_dbase" "uint16_t" inf-tdb (1 2 3 4 5 7 9 13 17 25 33 49 65 97 129 193 257 385 513 769 1025 1537 2049 3073 4097 6145 8193 12289 16385 24577))
      ("gz_dext" "uint8_t" inf-tde (0 0 0 0 1 1 2 2 3 3 4 4 5 5 6 6 7 7 8 8 9 9 10 10 11 11 12 12 13 13))
      ("gz_clord" "uint8_t" inf-tob (16 17 18 0 8 7 9 6 10 5 11 4 12 3 13 2 14 1 15)))
   inf-roots '((LROOT 12) (DROOT 9) (CROOT 7))
   (commas l) (two? >l ? "\(show <l), \(commas >l)" (show <l))
   (table-c t) (t @ [nm ty _ vs] "static const \(ty) \(nm)[\(show #vs)] = { \(commas vs) };\n")
   (table-terms i vs)
    (atom? >vs ? ['inf-tv i <vs 'k] ['add ['inf-tv i <vs 'k] (table-terms (i + 1) >vs)])
   (table-uu t) (t @ [_ _ u vs] " (defn \(show u) (pi k nat nat) (lam k \(show (table-terms 0 vs))))\n")
   (root-c r) "#define \(show <r) \(show <>r)\n"
   inf-rh-head
    """
    // one block's decode tables, 10 KB on inf_run's frame (see inf_rund): the kernel's 64 KiB boot
    // stack inflates with it
    struct inf_tabs {
     uint16_t ltab[1 << LROOT], dtab[1 << DROOT], ctab[1 << CROOT], lsym[288], dsym[32], csym[19];
     struct inf_code lit, dst, cl; };
    // a stream being read, and where its bytes go: bc bits of bb buffered, ip read so far;
    // dic the preset dictionary behind the output, nd 0 for none
    struct inf_rd {
     const uint8_t *in, *dic;
     uint8_t *out;
     struct inf_tabs *t;
     uintptr_t n, ip, op, cap, nd;
     uint64_t bb;
     unsigned bc; };
    """
   inf-rh-nl "\n"
   inf-sh-head
    """
    // what a stop keeps of a block in the reading: the mode and where in it
    struct inf_ms {
     unsigned mode, last, rem, hlit, hdist, hclen, i, prev, stage, sy, len, dist;
     uint8_t lens[320], cl[19]; };
    """

   ; what no spec reads: inf_rundt, in inflate.h, hands inf_go a reader at zero
   top
    {'name "inf_rundt" 'short "top"
     'ret 'int 'params () 'fields ()
     'state co-state
     'arrays ()
     'requires
      '((In (pi k nat nat)) (n nat) (w nat) (out nat) (oc nat) (cap nat) (nd nat)
        (Lc0 (pi k nat nat)) (Ls0 (pi k nat nat)) (Lt0 (pi k nat nat))
        (Dc0 (pi k nat nat)) (Ds0 (pi k nat nat)) (Dt0 (pi k nat nat)) (lm0 nat) (dm0 nat)
        (Cs0 (pi k nat nat)) (Ct0 (pi k nat nat)) (Cc0 (pi k nat nat))
        (gw (inf-le 32 w))
        (gn (inf-lt (add n 8) (inf-pow w)))
        (go (pi g (inf-lt 0 out) (paths nat oc cap)))
        (gcap (inf-lt (add cap 8) (inf-pow w)))
        (gcf (inf-lt (add cap 266) (inf-pow w)))
        (gnd (inf-lt (add cap nd) (inf-pow w))))
     'decls '((int (ip 0) (bc 0) (bb 0) (cons 0) (op 0)))
     'ensures ()
     'calls [go]
     'body
      [['c1 'call "inf_go" ()
        ('(In n w out oc cap nd Cs0 Ct0 Cc0 (Ob inf-tob) (Lb inf-tlb) (Le inf-tle) (Db inf-tdb) (De inf-tde)
           (h 16) (q (inf-pow 12))) + inf-roots)
        ()]]
     'macros ()
     'proofs
      {"c1-4" '(idpath false)
       "c1-5" '(idpath 0)
       "c1-11" 'inf-topq
       "c1-12" '(idpath true)
       "c1-13" '(inf-topk w gw)
       "c1-18" '(lam k g (inf-lelts (inf-tob k) 18 (inf-anyno (lam j (natgtb (inf-tob j) 18)) 19 (idpath false) k g)))
       "c1-19" '(inf-anyno (lam j (natgtb (inf-tle j) 5)) 29 (idpath false))
       "c1-20" '(inf-anyno (lam j (natgtb (add (inf-tlb j) (inf-pow (inf-tle j))) 259)) 29 (idpath false))
       "c1-21" '(inf-anyno (lam j (natgtb 3 (inf-tlb j))) 29 (idpath false))
       "c1-22" '(inf-anyno (lam j (natgtb (inf-tde j) 13)) 30 (idpath false))
       "c1-23" '(inf-anyno (lam j (natgtb (add (inf-tdb j) (inf-pow (inf-tde j))) (inf-pow 16))) 30 (idpath false))}}

   ; what no spec reads: a feed. the state a stream starts in, zeroes, is one inf_ststep takes; and what
   ; any stop left it takes again, over new bytes and a new output, ip and op at zero, the carry
   ; whatever was consumed and buffered by then
   st-tabs ['(Ob inf-tob) '(Lb inf-tlb) '(Le inf-tle) '(Db inf-tdb) '(De inf-tde) '(h 16) '(q (inf-pow 12))]
   st-feed-req
    '((In (pi k nat nat)) (n nat) (w nat) (out nat) (oc nat) (cap nat) (nd nat)
      (gw (inf-le 32 w))
      (gn (inf-lt (add n 8) (inf-pow w)))
      (go (pi g (inf-lt 0 out) (paths nat oc cap)))
      (gcap (inf-lt (add cap 8) (inf-pow w)))
      (gcf (inf-lt (add cap 266) (inf-pow w)))
      (gnd (inf-lt (add cap nd) (inf-pow w)))
      (gz (inf-lt 0 out)))
   st0
    {'name "inf_feed0" 'short "st0"
     'ret 'int 'params () 'fields ()
     'state ()
     'arrays ()
     'requires st-feed-req
     'decls [['int '(ip 0) '(bc 0) '(bb 0) '(cons 0) '(op 0) '(lm 0) '(dm 0)
              '(Lc inf-zero) '(Ls inf-zero) '(Lt inf-zero) '(Dc inf-zero) '(Ds inf-zero) '(Dt inf-zero)
              '(Cl inf-zero) '(Lz inf-zero) '(Cs inf-zero) '(Ct inf-zero) '(Cc inf-zero)
              '(last 0) '(rem 0) '(hclen 0) '(i 0) '(prev 0) '(stage 0) '(sy 0) '(len 0) '(dist 0) '(mode 0) '(hlit 0) '(hdist 0)]]
     'ensures ()
     'calls [ststep]
     'body [['c1 'call "inf_ststep" () ('(In n w (carry 0) out oc cap nd) + st-tabs + inf-roots) ()]]
     'macros ()
     'proofs
      {"c1-5" '(idpath 0)
       "c1-11" 'inf-topq
       "c1-12" '(idpath true)
       "c1-13" '(inf-topk w gw)
       "c1-19" '(lam k g (inf-lelts (inf-tob k) 18 (inf-anyno (lam j (natgtb (inf-tob j) 18)) 19 (idpath false) k g)))
       "c1-20" '(inf-anyno (lam j (natgtb (inf-tle j) 5)) 29 (idpath false))
       "c1-21" '(inf-anyno (lam j (natgtb (add (inf-tlb j) (inf-pow (inf-tle j))) 259)) 29 (idpath false))
       "c1-22" '(inf-anyno (lam j (natgtb 3 (inf-tlb j))) 29 (idpath false))
       "c1-23" '(inf-anyno (lam j (natgtb (inf-tde j) 13)) 30 (idpath false))
       "c1-24" '(inf-anyno (lam j (natgtb (add (inf-tdb j) (inf-pow (inf-tde j))) (inf-pow 16))) 30 (idpath false))
       "c1-25" '(lam k (inf-powpos 16))
       "c1-26" '(idpath false)
       "c1-29" '(idpath false)
       "c1-31" '(lam j (idpath false))
       "c1-32" '(lam k (idpath false))}}
   stn
    {'name "inf_feedn" 'short "stn"
     'ret 'int 'params () 'fields ()
     'state (filter (a \ !(elem <a '(ip op))) st-all)
     'arrays ()
     'requires (filter (r \ !(elem <r '(carry ip0 op0 gi ga gop))) st-req)
     'decls '((int (ip 0) (op 0)))
     'ensures ()
     'calls [ststep]
     'body [['c1 'call "inf_ststep" () ('(In n w (carry (add cons0 bc0)) out oc cap nd q h LROOT DROOT CROOT Ob Lb Le Db De)) ()]]
     'macros ()
     'proofs {"c1-5" '(natplusr0 (add cons0 bc0))}}

   ; what the theorem assumes, and who answers for it. a row leaves when its caller is proved
   inf-ledger
    '(("gw" "the word is 32 bits or more" "every target")
      ("gn" "n + 8 fits a word: the input is in memory, not at the top of it" "every caller")
      ("go" "out nonzero holds cap bytes" "every caller")
      ("gcap gcf" "cap + 266 fits a word" "every caller")
      ("gnd" "cap + nd fits a word" "every caller")
      ("caller" "(inflate s n): a string's length, cap the hint or INF_MAX, out a string or NULL" "gz.c")
      ("caller" "inflate_raw: the efi slot's image, cap its stated size" "uefi/slot.c")
      ("caller" "inflate_raw: a carried tree entry" "archive/srctree.c")
      ("caller" "inflate_raw: a carried text" "cats.c")
      ("caller" "inflate_raw, inflate_dict: an image's dictionary and pages" "love.c")
      ("caller" "inflate_raw: an idat, cap its filtered size" "quay/png.c")
      ("caller" "inflate_raw: a layer's run" "snap.c")
      ("state" "inflate-feed's state is zeroes or what the last step left: a port no love can write, its size and magic checked" "gz.c")
      ("caller" "inflate-feed: a string's length, cap at most INF_MAX and grown only past op, out from alloc" "gz.c")
      ("caller" "inflate-feed: dic is hist's last nd bytes, and nd at most what hist holds" "gz.c")
      ("link" "struct inf_tabs and lens hold what co-arrays and dyn's arrays say; the same file, unchecked" "inf.l")
      ("link" "a spec's operation means its C: two readers of one form, compared by test_gz" "inf.l"))
   (ledger-text l) (cats (map (r \ r @ [a b c] "; \(a): \(b) -- \(c)\n") l))

   inf-specs [walk build fill take sym stored copy fixed dyn fast block go sy1 sthead stlen sttab stcl stln ststo stsy strest ststep]
   inf-run-specs [fill take sym stored fixed dyn copy fast block go]
   inf-rh (cats ["// inf_run_gen.h -- laid by src/love/compress/inf.l, `make mx`. edit that file.\n"
                 (cats (map table-c inf-tables))
                 "// table roots: a longer code walks bits, so these trade 2^root fill writes against walks\n"
                 (cats (map root-c inf-roots))
                 inf-rh-head inf-rh-nl
                 (cats (map (s \ clay-show (cl-fn s)) inf-run-specs))])
   inf-st-specs [sy1 sthead stlen ststo sttab stcl stln stsy strest ststep]
   inf-sh (cats ["// inf_st_gen.h -- laid by src/love/compress/inf.l, `make mx`. edit that file.\n"
                 inf-sh-head inf-rh-nl
                 (cats (map (s \ clay-show (cl-fn s)) inf-st-specs))])
   ; test/uuinfvc.l
   inf-vc (cats ["; test/uuinfvc.l -- laid by src/love/compress/inf.l, `make mx`. edit that file.\n"
                 "; the ledger: what the theorems of inf_rundt and inf_feedn leave open, each with who answers for it\n"
                 (ledger-text inf-ledger)
                 "(test\n"
                 (cats (map table-uu inf-tables))
                 (cats (map (s \ cats (vc-text s)) (inf-specs + [top st0 stn]))) " )\n"])
   inf-h (cats ["// inf_gen.h -- laid by src/love/compress/inf.l, `make mx`. edit that file.\n"
                (cats (map (s \ clay-show (cl-fn s)) [walk build]))])
   inf-ok (all (s \ clay-ok? (cl-fn s) = 1 && atom? (vc-open s) && atom? (vc-stale s)) inf-specs
           && all (s \ atom? (vc-open s) && atom? (vc-stale s)) [top st0 stn]))
