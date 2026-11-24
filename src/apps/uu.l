; uu -- MLTT with the UniMath Preamble's seven inductives (empty unit bool coprod nat paths
; total2), bidirectional checking, NbE conversion (de bruijn levels as fresh vars, sigma- and
; pi-eta), cumulative universes, each definition polymorphic in its own. an axiom is a book
; entry with a type and no value.
; names follow UniMath.
;
; terms are quoted lists: UU nat bool unit empty zero tt true false <fixnum>
;   (pi x A B) (lam x b) (total2 x A B) (tpair a b) (pr1 w) (pr2 w) (succ n)
;   (coprod A B) (ii1 a) (ii2 b) (paths a a b) (idpath a) (the T t)
;   (nat_rect P z s n) (bool_rect P t f b) (unit_rect P u x)
;   (coprod_rect P f g v) (empty_rect P e) (paths_rect P pr e)
;   (let x a b) -- definitional: x binds the value of a, transparent to conv
; and any other list is an application spine. (f) == f here too.
; the defn/defq/axm macros live in this module's macro table.

; --- the kernel: values, evaluation, conversion, checking ---
(module '(uu axm bridge capp chk conv defcx defind defn defq defvc defvcs GLOB HELPC indsig kof lof rejects sugar ucommit ucompact ufresh ule ulive ureset univ vcs-of vof)
(: GLOB {} HELPC {} SRC {} CMEM {} BRIDGE {} CX {} IND {} UST {} UPOT {} UOUT {} UORG {} UPOLY {})

(: (vsucc v) (charm? v ? (v + 1) ['succ v])

   ; a uu closure ('clo f) carries a love function, so applying one is an application, not a
   ; re-walk of syntax. only capp opens one. a lambda's, pi's or sigma's carries a third, a cell
   ; saying how f reads its argument: 1 never, 2 only under a lambda or a branch, 0 at once
   (capp cl v) (<>cl v)
   (vapp f a) (f @ ['lam cl] (capp cl a) ['na f a])
   (dop1 v) (v @ ['chain a _] a ['np1 v])
   (dop2 v) (v @ ['chain _ b] b ['np2 v])
   (donr P z s m) (charm? m ?
    (: (go k acc) (k = m ? acc (go (k + 1) (vapp (vapp s k) acc))) (go 0 z))
    (m @ ['succ n] (vapp (vapp s n) (donr P z s n)) ['nnr P z s m]))
   ; a step that never reads its recursive result needs none computed, a case and no fold:
   ; a double recursion, natgtb or natminus, costs a sum of its literals and not their binomial
   (dosr P z s m) (charm? m ? (m = 0 ? z (vapp (vapp s (m - 1)) 0))
    (m @ ['succ n] (vapp (vapp s n) 0) ['nnr P z s m]))
   (reads? x t) (t == x || two? t && (reads? x <t || reads? x >t))
   (stepless? s) (s @ ['lam _ ['lam u b]] !(reads? u b) 0)
   (dobr P x y v) (v @ 'true x  'false y  ['nbr P x y v])
   (dour P x v) (v @ 'tt x ['nur P x v])
   (docr P f g v) (v @ ['i1 a] (vapp f a) ['i2 b] (vapp g b) ['ncr P f g v])
   (doer P v) ['ner P v]
   (dojr P r ev) (ev @ ['refl _] r ['njr P r ev])
   ; a flag is worked out the first time it is asked for, once for every closure a compile makes
   (kcell f) {1 f}
   (kof q) (q 2 @ c (c == () ? 0 (peep c 0 () @ k (k != () ? k (: v ((c 1) 0) (pin c 0 v, v))))))
   (strict? x t) (? (t == x) 1
                    (two? t) (t @ ['lam _ _] 0
                                 ['pi _ A _] (strict? x A)
                                 ['total2 _ A _] (strict? x A)
                                 ['bool_rect P _ _ w] (strict? x P || strict? x w)
                                 (any (u \ strict? x u) t))
                    0)
   ; a recursor's hypothesis: skipped when the method never reads it, a memo cell when it reads it
   ; only under a lambda or a branch, else computed. a lookup runs the cell
   (lzy th) ['lz {0 th}]
   (lzm m th) (m @ ['lam q] (kof q @ 1 0 2 (lzy th) (th 0)) (th 0))
   (frc v) (two? v && <v == 'lz ? (v 1 @ c (peep c 1 0 ? (c 0) (: x ((c 0) 0) (pin c 0 x, pin c 1 1, x)))) v)
   (vof-sym en x) (frc (assq x en @ (_ y) y (GLOB x @ (_ y) y (scare 'uu-unbound x))))

   ; --- comp: a term walked once into a love function of the env. vof-sym stays inside the
   ; (\ en ..): a later defn must be visible to a term compiled earlier.
   ; arms run most frequent first (lam and succ are half); they are exclusive, so order is free.
   (comp t)
   (? (charm? t) (en \ t)
      (nom? t) (? (memq t '(UU nat bool unit empty tt true false)) (en \ t)
                  (t = 'zero) (en \ 0)
                  (en \ vof-sym en t))
      ; a spine's list head matches no tag, so it falls through to the else
      (t @
         ['lam x b]             (: cb (comp b) k (kcell (_ \ reads? x b ? (strict? x b ? 0 2) 1))
                                 (en \ ['lam ['clo (v \ cb ([x v] . en)) k]]))
         ['succ a]              (comp a @ ca (en \ vsucc (ca en)))
         ['pi x A B]            (: cA (comp A) cB (comp B) k (kcell (_ \ reads? x B ? 0 1))
                                 (en \ ['pi (cA en) ['clo (v \ cB ([x v] . en)) k]]))
         ['paths A a b]         (: cA (comp A) ca (comp a) cb (comp b)
                                 (en \ ['paths (cA en) (ca en) (cb en)]))
         ['nat_rect P z s n]    (: cP (comp P) cz (comp z) cs (comp s) cn (comp n)
                                   go (stepless? s ? dosr donr)
                                 (en \ go (cP en) (cz en) (cs en) (cn en)))
         ['tpair a b]           (: ca (comp a) cb (comp b) (en \ ['chain (ca en) (cb en)]))
         ['idpath a]            (comp a @ ca (en \ ['refl (ca en)]))
         ['paths_rect P r e]    (: cP (comp P) cr (comp r) ce (comp e)
                                 (en \ dojr (cP en) (cr en) (ce en)))
         ['bool_rect P x y w]   (: cP (comp P) cx (comp x) cy (comp y) cw (comp w)   ; only the branch taken
                                 (en \ (cw en @ v (v @ 'true (cx en) 'false (cy en) ['nbr (cP en) (cx en) (cy en) v]))))
         ['coprod A B]          (: cA (comp A) cB (comp B) (en \ ['coprod (cA en) (cB en)]))
         ['coprod_rect P f g w] (: cP (comp P) cf (comp f) cg (comp g) cw (comp w)
                                 (en \ docr (cP en) (cf en) (cg en) (cw en)))
         ['empty_rect P e]      (: cP (comp P) ce (comp e) (en \ doer (cP en) (ce en)))
         ['unit_rect P u x]     (: cP (comp P) cu (comp u) cx (comp x)
                                 (en \ dour (cP en) (cu en) (cx en)))
         ['UU ['lp i n]]        (en \ ['U (assq 'uu-lvls en @ (_ L) (L i @ ['lv k m] ['lv k (m + n)]) (scare 'uu-level-unbound i))])
         ['UU 0]                (en \ 'UU)
         ['UU l]                (en \ ['U l])
         ['the T u]             (comp u)                    ; the ascription is the term
         ['let x a b]           (: ca (comp a) cb (comp b) (en \ cb ([x (ca en)] . en)))
         ['total2 x A B]        (: cA (comp A) cB (comp B) k (kcell (_ \ reads? x B ? 0 1))
                                 (en \ ['sig (cA en) ['clo (v \ cB ([x v] . en)) k]]))
         ['pr1 w]               (comp w @ ca (en \ dop1 (ca en)))
         ['pr2 w]               (comp w @ ca (en \ dop2 (ca en)))
         ['ii1 a]               (comp a @ ca (en \ ['i1 (ca en)]))
         ['ii2 b]               (comp b @ ca (en \ ['i2 (ca en)]))
         (: cf (comp <t) cas (map comp >t) (en \ spine en (cf en) cas))))

   (spine en f cas) (cas @ (a . u) (spine en (vapp f (a en)) u) f)

   vof (flip comp)                               ; compile, then run

   ; --- universes: on unless (univ 0), which gives UU : UU. each bare UU a level var, a level a fixnum or
   ; ('lv k n), var k plus n. a constraint x+a <= y+b is an edge x -> y of weight a-b in one
   ; graph, 'z the zero; a definition's edges wait in UST 'p until it commits
   (univ on) (: was (peep UST 'on 1) (pin UST 'on on, was))
   (uon? _) (peep UST 'on 1)
   (univ? v) (v == 'UU || two? v && <v == 'U)
   (ulvl v) (v == 'UU ? 0 <>v)
   (umk l) (l == 0 ? 'UU ['U l])
   (lsucc l) (charm? l ? (l + 1) ['lv <>l (<>>l + 1)])
   (unode l) (charm? l ? ['z l] [<>l <>>l])
   (ufresh _)
    (: k (peep UST 'n 0)
     (pin UST 'n (k + 1), pin UPOT k 0, pin UORG k (peep UST 'cur 0), pin UOUT 'z ([k 0] . peep UOUT 'z ()), ['lv k 0]))
   (ule a b)
    (? (charm? a && charm? b) (a <= b)
       (a = b) 1
       (: x (unode a) y (unode b)
        (pin UST 'p ([<x <y (x 1 - y 1)] . peep UST 'p ()), 1)))
   (ueq a b) (ule a b && ule b a)
   (umax i j) (? (i = j || j == 0) i (i == 0) j (charm? i && charm? j) (i < j ? j i)
                 (ufresh 0 @ k (ule i k, ule j k, k)))
   ; an edge x -> y raises y's potential past x's by w, and on through y's edges; raising x
   ; itself closes a positive cycle. log undoes a commit that does
   (uedge x y w log)
    (: (pot v) (peep UPOT v 0)
       par (peep log 2 {})
       (raise st) (st @ ([v p f] . u)
                   (? (pot v >= p) (raise u)
                      (v = x) (pin log 3 f, 0)
                      (pin log 0 ([v (pot v)] . peep log 0 ()), pin UPOT v p, pin par v f,
                       raise (foldl (\ a e ([<e (p + e 1) v] . a)) u (peep UOUT v ()))))
                   1)
     (pin log 2 par,
      pin log 1 ([x (peep UOUT x ())] . peep log 1 ()),
      pin UOUT x ([y w] . peep UOUT x ()),
      raise [[y (pot x + w) x]]))
   ; the cycle a refused commit closed, each var with the definition that made it
   (ucycle log)
    (: par (peep log 2 {}) (go v seen) (two? (memq v seen) || v == () ? seen (go (peep par v ()) (v . seen)))
     (map (v \ [v (peep UORG v 'z)]) (go (peep log 3 ()) ())))
   (ucommit nm)
    (: es (peep UST 'p ()) log {}
       ok (all (e \ uedge <e (e 1) (e 2) log) (rev es))
     (pin UST 'p (),
      ok ? es (: cy (ucycle log)
              (each (peep log 0 ()) (e \ pin UPOT <e (e 1)),
               each (peep log 1 ()) (e \ pin UOUT <e (e 1)),
               scare 'uu-universe-inconsistency [nm cy]))))
   ; a commit's vars that nothing keeps go: each path through them from a var that stays
   ; becomes one edge of its longest weight, so the graph on the rest implies just what it did
   (ulive _) #(keys UPOT)                        ; the level vars still held
   (ucompact keep es)
    (: n0 (peep UST 'n0 0) n (peep UST 'n 0)
       (dead? k) (charm? k && n0 <= k && !(two? (memq k keep)))
       (out x) (peep UOUT x ())
       (dmax t k w) (: o (peep t k ()) (o == () || o < w ? (pin t k w) t))
       ; longest weights into the dead region along es0, then out of it to the vars that stay
       (reach es0) (: R {} S {}
                     (go st) (st @ ([d w] . u)
                              (: o (peep R d ())
                               (o != () && w <= o ? (go u)
                                (pin R d w, go (foldl (\ a e (dead? <e ? ([<e (w + e 1)] . a) a)) u (out d)))))
                              1)
                   (go (filter (e \ dead? <e) es0),
                    each (keys R) (d \ each (out d) (e \ dead? <e ? () (dmax S <e (R d + e 1)))),
                    S))
       ; x's edges since ureset, and the list it had then: only the new ones can reach a dead var
       (since x t) (: (go l a) (? (l == t) [a l] (two? l) (go >l (<l . a)) [a ()]) (go (out x) ()))
       ; every var has 'z -> it at 0, so a bridge from 'z counts only above 0
       (bridge x) (: pr (since x (x == 'z ? (peep UST 'z0 ()) ()))
                     S (reach <pr)
                     vs (filter (v \ v != x && (x != 'z || S v > 0)) (keys S))
                     kept (filter (e \ !(dead? <e)) <pr + pr 1)
                     have (two? vs ? (foldl (\ t e (dmax t <e (e 1))) {} kept) {})
                   (pin UOUT x (foldl (\ a v (: w (S v) (peep have v () != () && w <= have v ? a ([v w] . a))))
                                      kept vs)))
       xs (foldl (\ a e (!(dead? <e) && dead? (e 1) && !(two? (memq <e a)) ? (<e . a) a)) ['z] es)
     (each xs bridge,
      each (filter dead? (ujot n0 n)) (k \ (pull UPOT k (), pull UORG k (), pull UOUT k ()))))
   (ureset nm) (pin UST 'p (), pin UST 'cur nm, pin UST 'n0 (peep UST 'n 0), pin UST 'z0 (peep UOUT 'z ()))
   ; --- polymorphism: a definition's own levels in its type are made fresh at each cite, its
   ; constraints carried as the longest paths its edges imply between them and the rest
   (uvars t acc) (? (two? t) (t @ ['UU ['lv k _]] (two? (memq k acc) ? acc (k . acc)) (foldl (flip uvars) acc t)) acc)
   (uidx k V) (: (go i u) (u @ (v . w) (v = k ? i (go (i + 1) w)) ()) (go 0 V))
   (lvrepl t V) (? (two? t) (t @ ['UU ['lv k n]] (uidx k V @ i (i == () ? t ['UU ['lp i n]])) (map (x \ lvrepl x V) t)) t)
   (ujot a b) (a < b ? (a . ujot (a + 1) b) ())
   (upoly nm T es)
    (: n0 (peep UST 'n0 0) (own? k) (charm? k && n0 <= k)
       V (filter own? (uvars T ()))
       E (es + map (k \ ['z k 0]) (ujot n0 (peep UST 'n 0)))
       (bound? v) (!(own? v) || two? (memq v V))
       S (foldl (\ a e (foldl (\ b v (bound? v && !(two? (memq v b)) ? (v . b) b)) a [<e (e 1)])) V E)
       ; longest paths from u over the definition's edges; no positive cycle survived its commit
       (from u) (: D {} _ (pin D u 0)
                   (relax _) (foldl (\ ch e (: dx (peep D <e ()) dy (peep D (e 1) ())
                                     (dx != () && (dy == () || dy < dx + e 2) ? (pin D (e 1) (dx + e 2), 1) ch))) 0 E)
                   (loop _) (relax 0 ? (loop 0) 0)
                 (loop 0, D))
       cons (catmap (u \ (: D (from u)
                          (catmap (v \ (v != u && (two? (memq u V) || two? (memq v V)) && peep D v () != () ? [[u v (D v)]] ())) S))) S)
     (two? V ? (pin UPOLY nm [V (comp (lvrepl T V)) cons]) 0))
   (uinst p)
    (p @ [V cT cons]
     (: F (map (_ \ <>(ufresh 0)) V)
        (ren v) (uidx v V @ i (i == () ? v (F i)))
      (pin UST 'p (foldl (\ a e ([(ren <e) (ren (e 1)) (e 2)] . a)) (peep UST 'p ()) cons),
       cT [['uu-lvls (map (f \ ['lv f 0]) F)]])))
   (ulab t) (? (t == 'UU) ['UU (ufresh 0)] (two? t ? (<t == 'UU ? t (map ulab t)) t))
   ; a motive's universe: any, a fresh var
   (uany _) (uon? 0 ? ['U (ufresh 0)] 'UU)
   ; a type: its level
   (usort cx en d A) (inf cx en d A @ T (univ? T ? (ulvl T) (scare 'uu-not-a-type A)))
   ; a <= b: universes climb, a pi's codomain with them
   (cumul d a b)
   (? (a == b) 1
      (univ? a && univ? b) (ule (ulvl a) (ulvl b))
      (two? a && two? b && <a == 'pi && <b == 'pi)
       (conv d <>a <>b && (['nv d] @ fr (cumul (d + 1) (capp <>>a fr) (capp <>>b fr))))
      (conv d a b))

   ; `==`, not `=`: `=` walks closures, exponential over shared environments. a `?`, not a
   ; pattern, which would build [a b] per call
   (conv d a b)
   (? (a == b) 1
      (atom? a || atom? b) (univ? a && univ? b && ueq (ulvl a) (ulvl b))
      (<a == 'U || <b == 'U) (univ? a && univ? b && ueq (ulvl a) (ulvl b))
      (<a = 'lam || <b = 'lam)
       (['nv d] @ fr (conv (d + 1) (vapp a fr) (vapp b fr)))
      (<a = 'chain && <b != 'chain)
       (conv d <>a (dop1 b) && conv d <>>a (dop2 b))
      (<b = 'chain && <a != 'chain)
       (conv d (dop1 a) <>b && conv d (dop2 a) <>>b)
      (<a = 'pi && <b = 'pi)
       (conv d <>a <>b && (['nv d] @ fr (conv (d + 1) (capp <>>a fr) (capp <>>b fr))))
      (<a = 'sig && <b = 'sig)
       (conv d <>a <>b && (['nv d] @ fr (conv (d + 1) (capp <>>a fr) (capp <>>b fr))))
      (<a = <b)
       (conv-args d >a >b))

   (conv-args d as bs)
   (atom? as && atom? bs || two? as && two? bs && conv d <as <bs && conv-args d >as >bs)

   (inf-sym cx x)
   (x @ 'UU (uon? 0 ? ['U 1] 'UU)
        ('nat || 'bool || 'unit || 'empty) 'UU
        'zero 'nat
        'tt 'unit
        ('true || 'false) 'bool
        (assq x cx @ (_ T) T (GLOB x @ (g . _) (UPOLY x @ p (two? p ? (uinst p) g)) (scare 'uu-unbound x))))

   ; a codomain that never reads its binder is laid without the argument's value
   (carg q en a) (kof q == 1 ? 0 (vof en a))
   (inf-spine cx en d f as)
   (as @ (a . u) (f @ ('pi A q) (chk cx en d a A, inf-spine cx en d (capp q (carg q en a)) u)
                   (scare 'uu-not-a-pi as)) f)

   ; each arm matches the term, then the type; the inner else is the mismatch
   (chk cx en d t T)
   (t @
      ['lam x b]   (T @ ('pi A q) (['nv d] @ fr
                                     (chk ([x A] . cx) ([x fr] . en) (d + 1) b (capp q fr)))
                        (scare 'uu-lam-needs-pi t))
      ['tpair a b] (T @ ['sig A q] (chk cx en d a A,
                                    chk cx en d b (capp q (carg q en a)))
                        (scare 'uu-tpair-needs-total2 t))
      ['ii1 a]     (T @ ['coprod A _] (chk cx en d a A) (scare 'uu-ii1-needs-coprod t))
      ['ii2 b]     (T @ ['coprod _ B] (chk cx en d b B) (scare 'uu-ii2-needs-coprod t))
      ['idpath a]  (T @ ['paths A av bv]
                          (: v (chk cx en d a A, vof en a)
                           (conv d v av && conv d v bv || scare 'uu-idpath-mismatch t))
                        (scare 'uu-idpath-needs-paths t))
      ['let x a b] (: Av (inf cx en d a)
                      va (vof en a)
                    (chk ([x Av] . cx) ([x va] . en) d b T))
      (inf cx en d t @ Ti
         (cumul d Ti T || scare 'uu-type-mismatch t)))

   ; the else is the spine; a tag at the wrong length reaches it too and scares unbound
   (inf cx en d t)
   (? (charm? t) 'nat
      (nom? t) (inf-sym cx t)
      (t @
         [('pi || 'total2) x A B]
          (: i (usort cx en d A) fr ['nv d]
           (umk (umax i (usort ([x (vof en A)] . cx) ([x fr] . en) (d + 1) B))))
         ['coprod A B] (umk (umax (usort cx en d A) (usort cx en d B)))
         ['paths A a b]
          (: l (usort cx en d A) Av (vof en A)
           (chk cx en d a Av, chk cx en d b Av, umk l))
         ['UU l] (umk (lsucc l))
         ['succ n] (chk cx en d n 'nat, 'nat)
         ['idpath a]
          (: Av (inf cx en d a) v (vof en a) ['paths Av v v])
         ['pr1 w]
          (inf cx en d w @ ['sig A _] A (scare 'uu-pr1-needs-total2 t))
         ['pr2 w]
          (inf cx en d w @ ['sig _ q] (capp q (dop1 (vof en w))) (scare 'uu-pr2-needs-total2 t))
         ['the T u]
          (: Tv (usort cx en d T, vof en T) (chk cx en d u Tv, Tv))
         ['let x a b]
          (: Av (inf cx en d a) va (vof en a) (inf ([x Av] . cx) ([x va] . en) d b))
         ['nat_rect P z s n]
          (: Pv (chk cx en d n 'nat,
                 chk cx en d P ['pi 'nat ['clo (uany 0 @ U (_ \ U))]],
                 vof en P)
           (chk cx en d z (vapp Pv 0),
            chk cx en d s (vof [['P Pv]] '(pi k nat (pi r (P k) (P (succ k))))),
            vapp Pv (vof en n)))
         ['bool_rect P x y w]
          (: Pv (chk cx en d w 'bool,
                 chk cx en d P ['pi 'bool ['clo (uany 0 @ U (_ \ U))]],
                 vof en P)
           (chk cx en d x (vapp Pv 'true),
            chk cx en d y (vapp Pv 'false),
            vapp Pv (vof en w)))
         ['unit_rect P u w]
          (: Pv (chk cx en d w 'unit,
                 chk cx en d P ['pi 'unit ['clo (uany 0 @ U (_ \ U))]],
                 vof en P)
           (chk cx en d u (vapp Pv 'tt),
            vapp Pv (vof en w)))
         ['empty_rect P e]
          (chk cx en d e 'empty,
           chk cx en d P ['pi 'empty ['clo (uany 0 @ U (_ \ U))]],
           vapp (vof en P) (vof en e))
         ['coprod_rect P f g w]
          (inf cx en d w @
           ['coprod A B]
            (: Pv (chk cx en d P (vof [['A A] ['B B] ['K (uany 0)]] '(pi x (coprod A B) K)),
                   vof en P)
             (chk cx en d f (vof [['A A] ['P Pv]] '(pi a A (P (ii1 a)))),
              chk cx en d g (vof [['B B] ['P Pv]] '(pi b B (P (ii2 b)))),
              vapp Pv (vof en w)))
           (scare 'uu-coprod_rect t))
         ['paths_rect P r e]
          (inf cx en d e @
           ['paths A av bv]
            (: Pv (chk cx en d P (vof [['A A] ['a av] ['K (uany 0)]] '(pi b A (pi e (paths A a b) K))),
                   vof en P)
             (chk cx en d r (vapp (vapp Pv av) ['refl av]),
              vapp (vapp Pv bv) (vof en e)))
           (scare 'uu-paths_rect t))
         (('lam || 'tpair || 'ii1 || 'ii2) . _) (scare 'uu-cannot-infer t)
         (inf-spine cx en d (inf cx en d <t) >t))))

; --- drivers: defn checks then pins; an axiom's value is its own neutral name; rejects runs a
; sugar, gone before the kernel sees a term: (pi x A y B C) and (lam x y b) nest, and a context
; defcx names binds its telescope, (under cx C) as pis and (given cx b) as lams. the exporters read it too
(: (cx-of c) (CX c @ b (two? b ? b (scare 'uu-no-context c)))
   (pis r) (r @ [b] (sugar b) (x . A . u) ['pi x (sugar A) (pis u)])
   (lams r) (r @ [b] (sugar b) (x . u) ['lam x (lams u)])
   (cx-pis bs b) (bs @ ([x A] . u) ['pi x A (cx-pis u b)] (sugar b))
   (cx-lams bs b) (bs @ ([x _] . u) ['lam x (cx-lams u b)] (sugar b))
   (sugar t)
    (atom? t ? t
     (t @ ('pi . r) (pis r)
          ('lam . r) (lams r)
          ['under c b] (cx-pis (cx-of c) b)
          ['given c b] (cx-lams (cx-of c) b)
          (map sugar t)))
   ; (defcx name [parent] (x A) ..): a parent's binders first
   (defcx nm r)
    (: own (x \ [<x (sugar (x 1))])
     (pin CX nm (name? <r ? (cx-of <r + map own >r) (map own r)), nm)))

; thunk expecting the kernel to refuse
; a name is pinned once, asked before anything is laid: a value is read when a closure runs, so
; a second would change what a sealed type says
; a statement and its term have their bare UUs made level vars; the source keeps them bare
(: (gnew nm) (? (IND nm != ()) (scare 'uu-defind-owns nm)
                (peep GLOB nm () != ()) (scare 'uu-taken nm)
                (ureset nm))
   (ulabs t) (uon? 0 ? (ulab t) t)
   (defn nm T0 t0)
   (: _ (gnew nm) t (sugar t0) T (ulabs (sugar T0)) u (ulabs t) Tv (usort 0 0 0 T, vof 0 T)
    (chk 0 0 0 u Tv,
     upoly nm T (ucommit nm),
     pin GLOB nm [Tv (vof 0 u)],
     pin SRC nm [t],
     nm))
   (axm nm T0)
   (: _ (gnew nm) T (ulabs (sugar T0))
    (usort 0 0 0 T,
     upoly nm T (ucommit nm),
     pin GLOB nm [(vof 0 T) ['nv nm]],
     nm))
   ; Qed: checked like defn, then sealed with its own neutral as value, so applying the proof
   ; never builds its beta-normal form
   (defq nm T0 t0)
   (: _ (gnew nm) T (ulabs (sugar T0)) u (ulabs (sugar t0)) Tv (usort 0 0 0 T, vof 0 T)
    (chk 0 0 0 u Tv,
     upoly nm T (ucommit nm),
     pin GLOB nm [Tv ['nv nm]],
     nm))
   ; an obligation no one cites: checked, its type not kept. the mark tells the exporters it
   ; ran, and a cite of it is unbound
   (defvc nm T0 t0)
   (: _ (gnew nm) T (ulabs (sugar T0)) u (ulabs (sugar t0)) Tv (usort 0 0 0 T, vof 0 T)
    (chk 0 0 0 u Tv,
     ucompact () (ucommit nm),
     pin GLOB nm 1,
     nm))
   ; a run under one context and binders: (defvcs nm i cx (x A ..) goal proof ..) is nm-i, nm-i+1 ..
   (vcs-of l)
    (l @ (nm . i . c . bs . r)
     (: (names b) (two? b ? (<b . names >>b) ())
        (go i r) (two? r ? ([(intern "\(nm)-\(i)") ['under c ('pi . bs + [<r])] ['given c ('lam . names bs + [(r 1)])]] . go (i + 1) >>r) ())
      (go i r)))
   (defvcs l) (map (e \ defvc <e (e 1) (e 2)) (vcs-of l))
   (rejects th)
   (: r (call-cc (k \ (pin HELPC () (\ a b (k 'rejected)), th 0, 'accepted)))
    (pin HELPC () 0, r))

   ; k operands gathered, then g of them: as kernel lambdas, and as love ones for uu2l
   (kcur k acc g) (k = 0 ? (g (rev acc)) ['lam ['clo (v \ kcur (k - 1) (v . acc) g)]])
   (lcur k acc g) (k = 0 ? (g (rev acc)) (v \ lcur (k - 1) (v . acc) g))
   (pairup a b) (two? a ? ([<a <b] . pairup >a >b) ())
   ; a recursor's operands are params, motive, methods, indices, target. ct holds each
   ; constructor's [c k fields], a field [y 0] or, when recursive, [y [zs js]]: its pis and
   ; the indices it lands at. a hypothesis follows its field
   (rect-of xs nc ct stuck ap lm dec ixv lz)
   (: (full vs)
      (: np #xs pv (take np vs) P (vs np) ms (take nc (drop (np + 1) vs))
         (ihz zs js en a ys) (zs @ (z . u) (lm (v \ ihz u js ([z v] . en) a (ys + [v])))
                              (full (pv + [P] + ms + map (ixv en) js + [(foldl ap a ys)])))
         (go m en fs as) (fs @ ([y s] . fu)
                          (: a <as m1 (ap m a)
                           (go (s == 0 ? m1 (ap m1 (lz m1 (_ \ ihz <s (s 1) en a ())))) ([y a] . en) fu >as))
                          m)
       (dec (vs (#vs - 1)) @ (c . as)
        (assq c ct @ [_ k fs] (#as = np + #fs ? (go (ms k) (pairup xs pv) fs (drop np as)) (stuck vs))
         (stuck vs))
        (stuck vs)))
    full)
   (kdec v) (: (u v acc) (v @ ['na f a] (u f (a . acc)) ['nv c] (c . acc) ()) (u v ()))

   ; (defind nm (x A ..) (i I ..) (c (y B ..) (nm x .. j ..)) ..): a family over params x and
   ; indices i; constructor c takes fields y and lands at indices j. nm and each c are names
   ; with no value, and nm_rect computes on a c. a field names nm only strictly positively, as
   ; (pi z C .. (nm x .. j ..)) with nm in no C or j, and no binder takes nm's or a param's name.
   ; indsig lays the declaration out for defind and the exporters: its telescopes, each
   ; constructor's method [c m fields ihs tel], nm_rect's type, and what is wrong with it if any
   (indsig nm ps0 is0 cs0)
   (: (pairs r) (r @ (x . A . u) ([x (sugar A)] . pairs u) ())
      ps (pairs ps0) is (pairs is0)
      cs (map (c \ [<c (pairs (c 1)) (sugar (c 2))]) cs0)
      np #ps ni #is nc #cs
      xs (map cap ps) iv (map cap is) cn (map cap cs)
      rnm (intern "\(nm)_rect")
      (sp h as) (two? as ? (two? h ? (h + as) (h . as)) h)
      (occ? t) (reads? nm t)
      (tapp t) (t == nm ? () (two? t && <t == nm ? >t 'no))
      (fam? A) (tapp A @ as (as != 'no && #as = np + ni && take np as = xs && !(occ? (drop np as))))
      (strict? A) (A @ ['pi _ C D] (!(occ? C) && strict? D) (fam? A))
      (spec A) (occ? A ? (A @ ['pi z _ D] (spec D @ [zs js] [(z . zs) js]) [() (drop np (tapp A))]) 0)
      (bnds t) (two? t ? ((two? (memq <t '(pi lam total2 let)) ? [(t 1)] ()) + bndl t) ())
      (bndl l) (foldl (\ a u (a + bnds u)) () l)
      (dup? l) (two? l && (two? (memq <l >l) || dup? >l))
      (syms t) (two? t ? (syms <t + syms >t) (nom? t ? [t] ()))
      used (syms [nm ps0 is0 cs0])
      (fr b) (: s (intern b) (two? (memq s used) ? (fr (b + "'")) s))
      Pn (fr "P") tn (fr "t")
      hd (sp nm xs) hi (sp hd iv)
      (ihT B y zs) (B @ ['pi z C D] ['pi z C (ihT D y (zs + [z]))] (sp Pn (drop np (tapp B) + [(sp y zs)])))
      (tel fs) (foldl (\ a f (a + [f] + (occ? (f 1) ? [[(fr "ih\(#a)") (ihT (f 1) <f ())]] ()))) () fs)
      ms (map (c \ c @ [c0 fs R]
               (: t (tel fs)
                [c0 (fr "m\(c0)") (map cap fs) (filter (b \ !(two? (memq b (map cap fs)))) (map cap t)) t
                 (cx-pis t (sp Pn (drop np (tapp R) + [(sp (sp c0 xs) (map cap fs))])))])) cs)
      famT (cx-pis ps (cx-pis is 'UU))
      rectT (cx-pis ps ['pi Pn (cx-pis is ['pi tn hi 'UU])
                        (cx-pis (map (m \ [(m 1) (m 5)]) ms)
                         (cx-pis is ['pi tn hi (sp Pn (iv + [tn]))]))])
      seen (iv + foldl (\ a c (a + map cap (c 1) + bndl (map (f \ f 1) (c 1)) + bnds (c 2))) (bndl (map (i \ i 1) is)) cs)
      bad (? (any (x \ GLOB x !== ()) (nm . (rnm . cn))) 'uu-defind-taken
             (dup? (nm . (rnm . cn)) || any (x \ two? (memq x (nm . (rnm . (xs + cn))))) seen) 'uu-defind-shadows
             (occ? [ps is] || !(all (c \ fam? (c 2)) cs)) 'uu-defind-index
             !(all (c \ all (f \ !(occ? (f 1)) || strict? (f 1)) (c 1)) cs) 'uu-defind-positivity
             ())
     {'ps ps 'is is 'cs cs 'xs xs 'iv iv 'rnm rnm 'Pn Pn 'tn tn 'ms ms 'famT famT 'rectT rectT 'bad bad
      'ct (map (k \ cs k @ [c fs _] [c k (map (f \ [<f (spec (f 1))]) fs)]) ^nc)})
   ; a family's fields live no higher than it: each field's sort at most the family's level
   (fields-le cx en d T k np f)
    (T @ ['pi x A B] (: l (usort cx en d A) fr ['nv d]
                      (k < np || ule l f, fields-le ([x (vof en A)] . cx) ([x fr] . en) (d + 1) B (k + 1) np f))
         1)
   (last-sort T) (T @ ['pi _ _ B] (last-sort B) ['UU l] l 0)
   (defind nm ps0 is0 cs0)
   (: g (indsig nm ps0 is0 cs0)
      xs (g 'xs) ps (g 'ps) cs (g 'cs) rnm (g 'rnm) ct (g 'ct)
      np #xs ni #(g 'is) nc #cs
      K (np + nc + ni + 2)
      _ (ureset nm)
      fT (ulabs (g 'famT)) f (last-sort fT)
      cTs (map (c \ c @ [c fs R] [c (ulabs (cx-pis ps (cx-pis fs R))) fs]) cs)
      rT (ulabs (g 'rectT))
      (pinax x T v) (pin GLOB x [(vof 0 T) v])
    (g 'bad != () ? (scare (g 'bad) nm)
     (each (nm . (rnm . map cap cs)) (x \ pin IND x 1),
      usort 0 0 0 fT,
      pinax nm fT ['nv nm],
      each cTs (c \ (usort 0 0 0 (c 1), fields-le 0 0 0 (c 1) 0 np f, pinax <c (c 1) ['nv <c])),
      usort 0 0 0 rT,
      ucommit nm,
      pin BRIDGE nm ['hit (lcur (np + ni) () (_ \ ['ty nm]))],
      each cTs (c \ c @ [c _ fs] (pin BRIDGE c ['hit (lcur (np + #fs) () (as \ ('in . (c . as))))])),
      pinax rnm rT (kcur K () (rect-of xs nc ct (vs \ foldl (\ f a ['na f a]) ['nv rnm] vs) vapp (f \ ['lam ['clo f]]) kdec vof lzm)),
      pin BRIDGE rnm ['hit (lcur K () (rect-of xs nc ct (vs \ ['nrec rnm]) (\ f a (f a)) (f \ f) (v \ v @ ('in . r) r ()) (en \ j \ 0) (m \ t \ t 0)))],
      nm))))

; --- uu2l: a closed term to a love form whose value is vof's answer (charms for nats,
; ('chain a b) for pairs); lof evaluates one. untrusted: chk/conv never use it, so a bug
; cannot fake a theorem. globals embed as quoted literals, so no uu binder can capture them.
; bridge maps names to native love; a defq or axm name compiles to its own neutral.
(: (qlit v) ['\ v]
   (kchain a b) ['chain a b]
   (kp1 v) (v @ ['chain a _] a ['np1 v])
   (kp2 v) (v @ ['chain _ b] b ['np2 v])
   (ksucc v) (v + 1)
   (ki1 a) ['i1 a]
   (ki2 a) ['i2 a]
   (krefl a) ['refl a]
   (knrec s z n) (foldl (flip s) z ^n)
   (kbrec x y b) (b @ 'true x y)
   (kcrec f g v) (v @ ['i1 a] (f a) ['i2 b] (g b))
   (kseq e r) r

   (uglo nm)
   (CMEM nm @ (_ v) v
    (BRIDGE nm @ (_ v) v
     (SRC nm @ (src) (ev (u2 src ()) @ v (pin CMEM nm ['hit v], v))
               ['nv nm])))

   (u2app t bs) (map (a \ u2 a bs) t)

   ; the eliminators reorder their operands to the k- helpers'
   (u2 t bs)
   (? (charm? t) t
      (nom? t)
      (? (t = 'zero) 0
         (memq t '(UU nat bool unit empty tt true false)) (qlit t)
         (memq t bs) t
         (qlit (uglo t)))
      (t @
         ['lam x b]   ['\ x (u2 b (x . bs))]
         ['let x a b] [': x (u2 a bs) (u2 b (x . bs))]
         ['the T u]   (u2 u bs)
         (('pi || 'total2 || 'coprod || 'paths) . _) (qlit ['ty <t])
         ['tpair a b] [kchain (u2 a bs) (u2 b bs)]
         ['pr1 w]     [kp1 (u2 w bs)]
         ['pr2 w]     [kp2 (u2 w bs)]
         ['succ n]    [ksucc (u2 n bs)]
         ['ii1 a]     [ki1 (u2 a bs)]
         ['ii2 b]     [ki2 (u2 b bs)]
         ['idpath a]  [krefl (u2 a bs)]
         ['nat_rect _ z s n]     [knrec (u2 s bs) (u2 z bs) (u2 n bs)]
         ['bool_rect _ x y w]    [kbrec (u2 x bs) (u2 y bs) (u2 w bs)]
         ['unit_rect _ u w]      [kseq (u2 w bs) (u2 u bs)]
         ['coprod_rect _ f g w]  [kcrec (u2 f bs) (u2 g bs) (u2 w bs)]
         ['paths_rect _ r e]     [kseq (u2 e bs) (u2 r bs)]
         ['empty_rect _ e]       [kseq (u2 e bs) (qlit 'ner)]
         (u2app t bs)))

   (uu2l t) (u2 t ())
   (lof t) (ev (u2 t ()))
   (bridge nm f) (pin BRIDGE nm ['hit f], nm))

; --- arity guards: curried defn/defq/axm given too few operands would answer a truthy
; closure and pin nothing. the macros scare on a wrong count in call position.
(: q (map qlit)
 (:: 'defn (l \ l @ [_ _ _] (defn . q l) (scare 'uu-defn-arity l)),
  :: 'defq (l \ l @ [_ _ _] (defq . q l) (scare 'uu-defq-arity l)),
  :: 'defvc (l \ l @ [_ _ _] (defvc . q l) (scare 'uu-defq-arity l)),
  :: 'defvcs (l \ #l > 3 && #l % 2 = 0 ? [defvcs (qlit l)] (scare 'uu-defq-arity l)),
  :: 'axm  (l \ l @ [_ _]   (axm  . q l) (scare 'uu-axm-arity  l)),
  :: 'defind (l \ #l > 2 ? [defind (qlit <l) (qlit (l 1)) (qlit (l 2)) (qlit (drop 3 l))] (scare 'uu-defind-arity l)),
  :: 'defcx (l \ [defcx (qlit <l) (qlit >l)])))

) ; module uu
