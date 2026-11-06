; src/love/compress/vc.l -- a codec's functions as data, with two readers: the C, through clay, and
; the obligations it owes, as uu theorems. a spec file (inf.l, bz.l) borrows this and clay; `make mx`
; lays both, test_clay diffs.
;
; a spec's integers are nat, so an operation stands for its C only under what it owes: + and << that
; the value fits, - that it does not wrap, a[i] that i is in, a | b that a's low bits are clear and b
; under them. a loop owes its invariants at entry and around, and that its measure falls. a width is
; `inf-pow w` for any w past the type's, never 2^31 written out, which the eager kernel would fold.
; an array is a function; a write is inf-upd, and memset is inf-zero.
(:
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
             ('le16 A i) (O i + [['inf-le ['add (T i) 2] (lk (sp 'arrays) A @ a (a 1))]])
             ; a word's, wrapping, whose values no law reads
             ('u32 x) (O x)
             ('and64 a b) (O a + O b)
             ('m64 k) (O k + [['inf-lt (T k) 64]])
             ('wadd a b) (O a + O b)
             ('wsub a b) (O a + O b)
             ('wmul a b) (O a + O b)
             ('bnot x) (O x))))
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
                         ('over a b) (ob sp v a + ob sp v b)
                         ('over16 a) (ob sp v a)
                         ('room _) ()
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
                         ('over _ _) 'unit
                         ('over16 _) 'unit
                         ('room _) 'unit
                         ('tru) 'unit)
   (cond-ff sp v c) (c @ ('ltsub a b d) ['inf-le ['add (tm sp v d) (tm sp v b)] (tm sp v a)]
                         ('lt a b) ['inf-le (tm sp v b) (tm sp v a)]
                         ('le a b) ['inf-lt (tm sp v b) (tm sp v a)]
                         ('nz a) ['paths 'nat (tm sp v a) 0]
                         ('z a) ['inf-lt 0 (tm sp v a)]
                         ('ne _ _) 'unit
                         ('eq _ _) 'unit
                         ('wide _) 'unit
                         ('widec _) 'unit
                         ('over a b) ['inf-lt ['add (tm sp v a) (tm sp v b)] ['inf-pow (tm sp v 'w)]]
                         ('over16 a) ['inf-lt ['inf-by16 (tm sp v a)] ['inf-pow (tm sp v 'w)]]
                         ('room _) 'unit)

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
                        (_ 'havw x _ _) [x]
                        (_ 'gset x _) [x]
                        (_ 'join _ _ th el _) (writes sp th + writes sp el)
                        (_ 'call f _ _ os) (written (callee sp f) os)
                        (_ 'try x f _ _ os) (x . written (callee sp f) os)
                        (_ 'tryr x f _ _ os _) (x . written (callee sp f) os)
                        (_ 'calx x f _ _ os) (x . written (callee sp f) os)
                        (_ 'new x o _ _) [x o]
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
   (call sp L f inst os res stop v hy cont)
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
       ; a negative answer goes straight up: the caller's stop stands on the callee's
       hn (rev (map (e \ (intern "\(L)\(<e)" . callsub post <>e)) (f 'stops)))
       _ (stop && stops? sp && !(stops? f) ? (quit-on "inf: \(sp 'short) passes up a stop \(f 'short) does not state") 0)
     (vcs (show L) (map (r \ callsub pre <>r) owed) hy
      + (stop && stops? sp ? (vcs "\(L)s" (map (e \ sub v2 <>e) (sp 'stops)) (hn + bs + hy)) ())
      + cxed sp (hs + bs + hy) (\ h (cont v2 h))))
   (stops? sp) (peep sp 'stops 0 != 0)
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
            ; a word holds what fits a word
            (L 'havw x e g)
             (: y (fresh L x)
              (vcs (show L) (ob sp v e) hy
               + run sp >ss ((x . y) . v) ((g . ['inf-lt y ['inf-pow (tm sp v 'w)]]) . ((y . 'nat) . hy)) k))
            (L 'ghost x e g) (run sp >ss ((x . x) . v) ((g . ['paths 'nat x (sub v e)]) . ((x . 'nat) . hy)) k)
            (L 'poke A i e) (vcs (show L) (ob sp v i + [['inf-lt (tm sp v i) (bound sp v A)]] + ob sp v e) hy
                             + run sp >ss v hy k)
            (L 'pokew A i e) (vcs (show L) (ob sp v i + [['inf-le ['add (tm sp v i) 8] (lk (sp 'arrays) A @ a (a 1))]] + ob sp v e) hy
                              + run sp >ss v hy k)
            (L 'mcopy A i B j n) (vcs (show L) (mv-ob sp v A i B j n) hy + run sp >ss v hy k)
            (L 'mmove A i B j n) (vcs (show L) (mv-ob sp v A i B j n) hy + run sp >ss v hy k)
            (L 'dstore _ _) (run sp >ss v hy k)
            ; a pointer into an array: one element, inside
            (L 'ptr _ A i) (vcs (show L) (ob sp v i + [['inf-lt (tm sp v i) (bound sp v A)]]) hy + run sp >ss v hy k)
            ; a pointer into an array: its view stands inside
            (L 'view _ A i n)
             (vcs (show L) (ob sp v i + ob sp v n + [['inf-le ['add (tm sp v i) (tm sp v n)] (bound sp v A)]]) hy
              + run sp >ss v hy k)
            ; alloc answers NULL or e bytes, and here the bytes are a fresh name's
            (L 'new x o e g)
             (: y (fresh L x) z (fresh L o)
              (vcs (show L) (ob sp v e) hy
               + run sp >ss ((x . y) . ((o . z) . v))
                     ((g . ['pi 'g ['inf-lt 0 y] ['paths 'nat z (tm sp v e)]]) . ((z . 'nat) . ((y . 'nat) . hy))) k))
            (L 'free _) (run sp >ss v hy k)
            (L 'call f as inst os) (call sp L (callee sp f) inst os () 0 v hy (\ v2 h2 (run sp >ss v2 h2 k)))
            (L 'try x f as inst os)
             (: y (fresh L x)
              (call sp L (callee sp f) inst os y 1 v hy
               (\ v2 h2 (run sp >ss ((x . y) . v2) h2 k))))
            (L 'tryr x f as inst os _)
             (: y (fresh L x)
              (call sp L (callee sp f) inst os y 1 v hy
               (\ v2 h2 (run sp >ss ((x . y) . v2) h2 k))))
            (L 'calx x f as inst os)
             (: y (fresh L x)
              (call sp L (callee sp f) inst os y 0 v hy
               (\ v2 h2 (run sp >ss ((x . y) . v2) h2 k))))
            (L 'ret e) (vcs (show L) (ob sp v e + ensured sp ((tm-res sp v e) . v)) hy)
            (L 'retneg _) (vcs (show L) (map (e \ sub v <>e) (sp 'stops)) hy)
            (L 'for x from to invs body) (loop sp L x from to () invs body >ss v hy k)
            (L 'forby x from to by invs body) (loop sp L x from to by invs body >ss v hy k)
            (quit-on "inf: \(sp 'short) has a statement the walk cannot read: \(show <ss)")))
   (callee sp f) (<(filter (c \ c 'name = f) (sp 'calls)))
   (bound sp v X) (sub v (lk (sp 'arrays) X @ a (a 1)))
   (mv-ob sp v A i B j n)
    (ob sp v i + ob sp v j + ob sp v n
     + [['inf-le ['add (tm sp v i) (tm sp v n)] (bound sp v A)]
        ['inf-le ['add (tm sp v j) (tm sp v n)] (bound sp v B)]])
   (ensured sp v) (map (e \ sub v <>e) (sp 'ensures))
   (tm-res sp v e) ('res . tm sp v e)
   ; each vc numbered within its label, in its order; a path run twice keeps counting
   (number l)
    (: t {}
       (go l)
        (atom? l ? ()
         (<l @ ['cx _ _ _] (<l . go >l)
               [L g h] (: j (1 + peep t L 0) _ (pin t L j)
                        (["\(L)-\(j)" g h L j] . go >l))))
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
       ; a feed's limit: named, since a literal 2^30 in a statement would unfold
       plim (has? (sp 'requires) 'lim ? ['inf-pow 'lim] ())
       ; a <= b through what is held: a stated step, x - y <= x, x <= x + y, up the powers
       (ups a) (cats (map (b \ >b @ ['inf-le x y] (x = a ? [[y <b]] ()) ['inf-lt x y] (x = a ? ([[y ['inf-ltle x y <b]]] + (lit? y && 0 < y ? [[(y - 1) ['inf-ltsle x (y - 1) <b]]] ())) ()) ()) bs)
                + (lit? a && a <= 512 ? [[['inf-pow 9] '(idpath false)]] ())
                + (a @ ['natminus x y] [[x ['inf-suble x y]]]
                       ['succ x] (cats (map (b \ >b @ ['inf-lt u y] (u = x ? [[y ['inf-ltsu x y <b]]] ()) ()) bs))
                       ['add 0 x] [[x ['inf-refl x]]]
                       ['add 1 x] (cats (map (b \ >b @ ['inf-lt u y] (u = x ? [[y ['inf-ltsu x y <b]]] ()) ()) bs))
                       ['add x d] (cats (map (b \ >b @ ['inf-lt u y] (u = x && d = 1 ? [[y ['inf-lt1 x y <b]]] ())
                                                        ['inf-le u y] (u = x && lit? y && lit? d ? [[(y + d) ['inf-addr x y d <b]]] ())
                                                        ()) bs))
                       ['inf-pow k] (cats (map (b \ >b @ ['inf-le x y] (x = k ? [[['inf-pow y] ['inf-powle k y <b]]] ()) ()) bs)
                                     + (lit? k && k <= 19 && plim
                                        ? [[plim ['inf-powle k 'lim ['inf-letrans k 19 'lim '(idpath false) 'hl]]]] ()))
                       ['inf-mod p x] (lit? p && 0 < p
                                       ? ([[(p - 1) ['inf-ltsle a (p - 1) ['inf-modlt (p - 1) x]]]]
                                          + (p = 8 ? [[x ['inf-modle8 x]]] ()))
                                       ())
                       ())
                + (lit? a ? (cats (map (b \ >b @ ['inf-le c y] (lit? c && a <= c && c != y ? [[y ['inf-letrans a c y '(idpath false) <b]]] ())
                                                  ['inf-lt c y] (lit? c && a <= c ? [[y ['inf-letrans a c y '(idpath false) ['inf-ltle c y <b]]]] ())
                                                  ()) bs)) ()))
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
               (a @ ['inf-pow k] (lit? k && k < 32)) ['inf-wpow w (a 1) gw '(idpath true)]
               (a @ ['inf-pow k] (chain k 31 4)) ['inf-wpow w (a 1) gw ['inf-lelts (a 1) 31 (chain (a 1) 31 4)]]
               (chain a 1024 4) ['inf-lelt a 1024 ['inf-pow w] (chain a 1024 4) ['bz-w1k w gw]]
               (plim && chain a plim 4)
                ['inf-lelt a plim ['inf-pow w] (chain a plim 4) ['inf-wpow w 'lim gw ['inf-lttrans 'lim 31 32 'hm '(idpath false)]]]
               (plim && a @ ['add x y] (chain x plim 4 && chain y plim 4))
                ['inf-fitlim w 'lim (a 1) (a 2) gw 'hm (chain (a 1) plim 4) (chain (a 2) plim 4)]
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
          ('inf-lt ('natminus t ('succ x)) ('natminus t x)) (held ['inf-lt x t] @ p (p ? ['inf-subfall t x p] ()))
          ('inf-lt ('natminus t ('add x 1)) ('natminus t x)) (held ['inf-lt x t] @ p (p ? ['inf-subfall1 t x p] ()))
          ('inf-lt a b)
           (? (lit? a && lit? b) (a < b ? '(idpath true) ())
              (held g) (held g)
              (lit? b && 0 < b && chain a (b - 1) 4) ['inf-lelts a (b - 1) (chain a (b - 1) 4)]
              (a == 0 && chain 1 b 4) ['bz-pos b (chain 1 b 4)]
              (a @ ['natminus x y] (lit? b && chain y x 4 && chain x b 4 && auto sp hy ['inf-lt 0 y]))
               ['bz-sublt (a 1) (a 2) b (auto sp hy ['inf-lt 0 (a 2)]) (chain (a 2) (a 1) 4) (chain (a 1) b 4)]
              (: (go l) (atom? l ? ()
                         (: t >(<l)
                            r (t @ ['inf-lt u x] (x = b ? (chain a u 4) ()) ())
                            q (t @ ['inf-lt u x] (u = a ? (chain x b 4) ()) ())
                            (r ? ['inf-lelt a (t 1) b r <<l]
                             (q ? ['inf-lttrans a (t 2) b <<l q] (go >l)))))
               (go bs)))
          (held g)))
   (proof-of sp c) (peep (sp 'proofs) <c () @ p (p ? p (auto sp (c 2) (c 1))))
   ; a proof may name a spec's macros, which may name each other
   (expand ms t) (sub ms t @ u (u = t ? t (expand ms u)))
   ; one label's vcs in a row, under one context and binders, are one defvcs
   (vc-run a b) (vc? b && a 3 = b 3 && b 4 = a 4 + 1 && cx-of (a 2) = cx-of (b 2) && added (a 2) = added (b 2))
   (vc-goal sp c) "  \(show (c 1)) \(show (expand (sp 'macros) (proof-of sp c @ p (p ? p 'tt))))\n"
   (vc-rest sp c l) (two? l && vc-run c <l ? (vc-goal sp <l . vc-rest sp <l >l) (" )\n" . vc-lay sp l))
   (vc-lay sp l)
    (atom? l ? ()
     (: c <l
      (vc? c
       ? (" (defvcs inf-vc-\(sp 'short)-\(c 3) \(c 4) \(cx-of (c 2)) \(show (cats (map (b \ [<b >b]) (rev (added (c 2))))))\n"
          . vc-goal sp c . vc-rest sp c >l)
       (cx-text c . vc-lay sp >l))))
   (vc-text sp) (vc-lay sp (spec-all sp))
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
                      ('d n) ['dot ['deref ['var "d"]] n]
                      ('v n) ['var n]))
   ; a name the struct holds, or a local
   (cv sp x) (? (elem x (sp 'fields)) ['dot ['deref ['var "r"]] (string x)]
                (elem x (sp 'sfields)) ['dot ['deref ['var "s"]] (string x)]
                (elem x (sp 'wfields)) ['dot ['deref ['var "w"]] (string x)]
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
             ('u32 x) ['cast '(named "uint32_t") (C x)]
             ('and64 a b) ['bin '& (C a) (C b)]
             ('m64 k) ['bin '- ['bin 'shl ['cast '(named "uint64_t") ['num 1]] (C k)] ['num 1]]
             ('wadd a b) ['bin '+ (C a) (C b)]
             ('wsub a b) ['bin '- (C a) (C b)]
             ('wmul a b) ['bin '* (C a) (C b)]
             ('bnot x) ['un 'bnot (C x)]
             ('dg f) ['dot ['deref ['var "d"]] f]
             ('sg f) ['dot ['deref ['var "s"]] f]
             ('wg f) ['dot ['deref ['var "w"]] f]
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
                       ('over a b) ['bin 'lt ['bin '- ['cast '(named "uintptr_t") ['un 'neg ['num 1]]] (cl sp b)] (cl sp a)]
                       ('over16 a) ['bin 'lt ['bin 'shr ['cast '(named "uintptr_t") ['un 'neg ['num 1]]] ['num 4]] (cl sp a)]
                       ('room x) ['bin 'ne (cl sp x) ['un 'neg ['num 2]]]
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
                        (L 'calx x f as _ _) [[L 'set-call x f as]]
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
         (L 'havw x e _) (cl-set sp x e)
         (L 'dstore f e) ['expr ['asn ['dot ['deref ['var "d"]] f] (cl sp e)]]
         (L 'ptr x A i) ['expr ['asn ['var (string x)] ['bin '+ (base sp A) (cl sp i)]]]
         (L 'dec x e) (cl-set sp x e)
         (L 'poke A i e) ['expr ['asn ['deref ['bin '+ (base sp A) (cl sp i)]] (cl sp e)]]
         (L 'pokew A i e) ['expr ['call ['var "ST64"] [['bin '+ (base sp A) (cl sp i)] (cl sp e)]]]
         (L 'mcopy A i B j n) ['expr ['call ['var "memcpy"] [['bin '+ (base sp A) (cl sp i)] ['bin '+ (base sp B) (cl sp j)] (cl sp n)]]]
         (L 'mmove A i B j n) ['expr ['call ['var "memmove"] [['bin '+ (base sp A) (cl sp i)] ['bin '+ (base sp B) (cl sp j)] (cl sp n)]]]
         (L 'view f A i _) ['expr ['asn ['dot ['deref ['var "r"]] f] ['bin '+ (base sp A) (cl sp i)]]]
         (L 'new x _ e _) ['expr ['asn (cv sp x) ['call ['var "alloc"] [['num 0] (cl sp e)]]]]
         (L 'free x) ['expr ['call ['var "alloc"] [(cv sp x) ['num 0]]]]
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
         (sp 'ret) (sp 'attrs)])
