; test/uuel.l -- uu's elaborator: motives, endpoints and type arguments found from the goal.
; outside the kernel: it hands plain defq a term, so its bugs can only be refused.
; (elq 'nm 'T 't) proves T by t, and pins the term it made for the exporters to read.
;   (lam x b)  (tpair a b) (ii1 a) (ii2 b)   checked against the goal, as the kernel does
;   (f a _ b)  a spine; _ is an argument found by unifying with the goal or a later argument
;   (rev (h ..) t)   t proves the goal with h back under it, h applied after
;   (ind l n c)      induction on a list; c binds x, t, ih
;   (cases w f g)    a coprod; (ifb c f g) a bool, f and g binding c's value as a path
;   (rw e h)         h proves the goal with e's right end read as its left
;   (sym p) (trans p q) (cong f p) rfl (absurd e)

(: el-chk (uu 'chk) el-sugar (uu 'sugar) ELT {} ELM {}
   (el-cat a b) (a @ (x . u) (x . el-cat u b) b)
   (el-app f a) (vof [['f f] ['a a]] '(f a))
   (el-fresh d) (intern ("ez" + show d))
   ; a level reads as the binder that holds it, else as a binder the readback made
   (el-nm en k) (en @ ((x v) . u) (v @ ['nv j] (j = k ? x (el-nm u k)) (el-nm u k)) (el-fresh k))

   ; --- readback; s is [value name], a scrutinee to abstract ---
   (el-rb en s d v)
   (? (two? s && two? v && conv d v <s) (s 1)
      (atom? v) v
      (: R (x \ el-rb en s d x)
         (under c) (el-rb en s (d + 1) (c ['nv d]))
       (v @
        ['nv k] (charm? k ? (el-nm en k) (peep ELM k 0 @ m (two? m ? (R <m) k)))
        ['lam c] ['lam (el-fresh d) (under (capp c))]
        ['pi A q] ['pi (el-fresh d) (R A) (under (capp q))]
        ['sig A q] ['total2 (el-fresh d) (R A) (under (capp q))]
        ['coprod A B] ['coprod (R A) (R B)]
        ['paths A a b] ['paths (R A) (R a) (R b)]
        ['succ n] ['succ (R n)]
        ['chain a b] ['tpair (R a) (R b)]
        ['i1 a] ['ii1 (R a)]
        ['i2 b] ['ii2 (R b)]
        ['refl a] ['idpath (R a)]
        ['na f a] [(R f) (R a)]
        ['np1 w] ['pr1 (R w)]
        ['np2 w] ['pr2 (R w)]
        ['nnr P z c m] ['nat_rect (R P) (R z) (R c) (R m)]
        ['nbr P x y w] ['bool_rect (R P) (R x) (R y) (R w)]
        ['nur P x w] ['unit_rect (R P) (R x) (R w)]
        ['ncr P f g w] ['coprod_rect (R P) (R f) (R g) (R w)]
        ['ner P w] ['empty_rect (R P) (R w)]
        ['njr P r e] ['paths_rect (R P) (R r) (R e)]
        ['U l] ['UU l]
        (scare 'el-readback v))))

   ; the goal with s read as a fresh binder: the motive of an eliminator of s
   (el-motive en d G s)
   (: z (el-fresh d) ['lam z (el-rb en [s z] (d + 1) G)])

   ; --- the type of an elaborated term ---
   (el-ty cx en d t)
   (: T (x \ el-ty cx en d x) V (vof en)
    (? (charm? t) 'nat
       (nom? t) (t @ ('UU || 'nat || 'bool || 'unit || 'empty) 'UU
                     'zero 'nat
                     'tt 'unit
                     ('true || 'false) 'bool
                     (assq t cx @ (_ A) A (GLOB t @ (g . _) g (scare 'uu-unbound t))))
       (t @
        ['pr1 w] (T w @ ['sig A _] A (scare 'el-pr1 t))
        ['pr2 w] (T w @ ['sig _ q] (capp q (V ['pr1 w])) (scare 'el-pr2 t))
        ['succ _] 'nat
        ['the A _] (V A)
        ['idpath a] (V a @ v ['paths (T a) v v])
        ['let x a b] (el-ty ([x (T a)] . cx) ([x (V a)] . en) d b)
        ['nat_rect P _ _ w] (el-app (V P) (V w))
        ['bool_rect P _ _ w] (el-app (V P) (V w))
        ['unit_rect P _ w] (el-app (V P) (V w))
        ['coprod_rect P _ _ w] (el-app (V P) (V w))
        ['empty_rect P w] (el-app (V P) (V w))
        (('pi || 'total2 || 'paths || 'coprod) . _) 'UU
        (: (go f as) (as @ (a . u) (f @ ['pi _ q] (go (capp q (V a)) u) (scare 'el-not-a-pi t)) f)
         (go (T <t) >t)))))

   ; --- metavariables: neutrals with a name, solved in ELM ---
   (el-meta? v) (v @ ['nv k] (nom? k && peep ELM k 1 = 0) 0)
   (el-res v) (v @ ['nv k] (nom? k ? (peep ELM k 0 @ m (two? m ? (el-res <m) v)) v) v)
   (el-solve v w) (v @ ['nv k] (pin ELM k [w], 1) 0)
   (el-same? x y) (x @ ['nv k] (y @ ['nv j] (k = j) 0) 0)
   (el-uni d a b)
   (: x (el-res a) y (el-res b)
    (? (el-same? x y) 1
       (el-meta? x) (el-solve x y)
       (el-meta? y) (el-solve y x)
       (two? x && two? y && <x == <y)
        (<x = 'clo ? (el-uni (d + 1) (<>x ['nv d]) (<>y ['nv d]))
          (: (go u w) (two? u && two? w ? (el-uni d <u <w, go >u >w) 0) (go >x >y)))
       0))
   (el-open? t) (? (nom? t) (peep ELM t 1 = 0)
                   (two? t) (el-open? <t || el-open? >t)
                   0)

   ; --- a spine: every argument a metavariable, then the goal, then each argument as its type
   ; --- is known, and one that needs a goal waits for a later argument to give it ---
   (el-spine cx en d t G)
   (: h (el-inf cx en d <t) Ht (el-ty cx en d h) as >t
      ms (map (_ \ (intern ("em" + show (el-tick 0))) @ k (pin ELM k 0, ['nv k])) as)
      (at T vs) (vs @ (v . u) (T @ ['pi A q] (u @ () [A (capp q v)] (at (capp q v) u))
                                 (scare 'el-not-a-pi t)) T)
      (dom i) (: (go T vs j) (T @ ['pi A q] (j = i ? A (go (capp q <vs) >vs (j + 1))) (scare 'el-not-a-pi t))
               (go Ht ms 0))
      (res _) (: (go T vs) (vs @ (v . u) (T @ ['pi _ q] (go (capp q v) u) (scare 'el-not-a-pi t)) T)
             (go Ht ms))
      Zen (el-cat (map (m \ [(m 1) m]) ms) en)
      Z (v \ vof Zen (el-rb en 0 d v))
      ts {}
      (hole? a) (a = '_)
      (needs-goal? a) (two? a && memq <a '(lam tpair ii1 ii2 rev ind cases ifb rw rfl absurd))
      (try i a)
      (: D (Z (dom i)) open (el-open? (el-rb en 0 d D))
       (? (two? (peep ts i 0)) 0
          (hole? a) 0
          (open && (needs-goal? a || a = 'rfl)) 0
          open (: b (el-inf cx en d a) (pin ts i [b], el-uni d D (el-ty cx en d b), el-solve (ms i) (vof en b), 1))
          (: b (el cx en d a D) (pin ts i [b], el-solve (ms i) (vof en b), 1))))
      (pass _) (: (go i u n) (u @ (a . w) (go (i + 1) w (n + (try i a))) n) (go 0 as 0))
      (loop _) (pass 0 > 0 ? (loop 0) 0)
      (arg i a) (peep ts i 0 @ b (two? b ? <b (hole? a ?
                   (el-res (ms i) @ v (el-open? (el-rb en 0 d v) ? (scare 'el-hole [t i]) (el-rb en 0 d v)))
                   (scare 'el-stuck [t i]))))
      (terms _) (: (go i u) (u @ (a . w) ((arg i a) . go (i + 1) w) ()) (go 0 as))
     (G == 0 ? 0 (el-uni d (res 0) G), loop 0, h . terms 0))

   (el-inf cx en d t) (two? t && !(memq <t '(pi total2 paths coprod succ pr1 pr2 the idpath let nat_rect bool_rect unit_rect coprod_rect empty_rect paths_rect)) ? (el cx en d t 0) t)

   ; --- check against the goal ---
   (el cx en d t G)
   (: R (x \ el-rb en 0 d x)
      A (x \ el-inf cx en d x)
      Ty (x \ el-ty cx en d x)
      Sp (x \ el-spine cx en d x G)
      V (vof en)
    (t @
     ['lam x b] (G @ ['pi A1 q] (['nv d] @ fr ['lam x (el ([x A1] . cx) ([x fr] . en) (d + 1) b (capp q fr))])
                     (scare 'el-lam-needs-pi t))
     ['tpair a b] (G @ ['sig A1 q] (el cx en d a A1 @ a2 ['tpair a2 (el cx en d b (capp q (V a2)))])
                       (scare 'el-tpair t))
     ['ii1 a] (G @ ['coprod A1 _] ['ii1 (el cx en d a A1)] (scare 'el-ii1 t))
     ['ii2 b] (G @ ['coprod _ B1] ['ii2 (el cx en d b B1)] (scare 'el-ii2 t))
     'rfl (G @ ['paths _ a _] ['idpath (R a)] (scare 'el-rfl t))
     ['absurd e] ['fromempty (R G) (el cx en d e 'empty)]
     ['sym p] (Sp ['pathsinv0 '_ '_ '_ p])
     ['trans p q] (Sp ['pathscomp0 '_ '_ '_ '_ p q])
     ['cong f p] (Sp ['maponpaths '_ '_ f '_ '_ p])
     ['rw e h] (: e2 (A e)
                (Ty e2 @ ['paths A1 x y]
                 (: M (el-motive en d G y) Mv (V M)
                  ['transportf (R A1) M (R x) (R y) e2 (el cx en d h (el-app Mv x))])
                 (scare 'el-rw t)))
     ['rev hs b]
      (: (wrap u) (u @ (h . w) ['pi h (R (assq h cx 1)) (wrap w)] (R G))
       (: Gt (wrap hs) (. (el cx en d b (V Gt)) hs)))
     ['ind l n c]
      (: l2 (A l)
       (Ty l2 @ ['sig _ q]
        (capp q 1 @ ['sig A1 _]
         (Sp ['grec (R A1) ['el-raw (el-motive en d G (V l2))] n c l2])
         (scare 'el-ind t))
        (scare 'el-ind t)))
     ['cases w f g]
      (: w2 (A w)
       (Ty w2 @ ['coprod A1 B1]
        (: M (el-motive en d G (V w2)) Mv (V M)
           e2 [['A A1] ['B B1] ['M Mv]]
         ['coprod_rect M (el cx en d f (vof e2 '(pi a A (M (ii1 a)))))
                         (el cx en d g (vof e2 '(pi b B (M (ii2 b))))) w2])
        (scare 'el-cases t)))
     ['ifb c f g]
      (: c2 (A c)
       (Sp ['gdest c2 ['el-raw (el-motive en d G (V c2))] f g]))
     ['el-raw u] u
     (? (atom? t) t
        (memq <t '(pi total2 paths coprod succ pr1 pr2 the idpath let nat_rect bool_rect unit_rect coprod_rect empty_rect paths_rect)) t
        (Sp t))))

   (elq nm T0 t0)
   (: T (el-sugar T0) G (el-chk 0 0 0 T 'UU, vof 0 T)
      t (el 0 0 0 (el-sugar t0) G)
    (pin ELT nm t, ev ['defq nm T t])))
(: el-count {})
(: (el-tick _) (: n (peep el-count 0 0) (pin el-count 0 (n + 1), n)))
