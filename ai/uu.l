; ai/uu.l -- the uu kernel's HOME: MLTT with the UniMath Preamble's seven
; inductives (empty unit bool coprod nat paths total2), bidirectional checking,
; NbE conversion (de bruijn levels as fresh vars, sigma- and pi-eta),
; type-in-type -- the universe stance of the reference
; (UniMath/Foundations/Init.v: Unset Universe Checking). an axiom is a book
; entry with a type and no value: a sanctioned missing. names follow UniMath so
; the port reads literally.
;
; terms are quoted lists: UU nat bool unit empty zero tt true false <fixnum>
;   (pi x A B) (lam x b) (total2 x A B) (tpair a b) (pr1 w) (pr2 w) (succ n)
;   (coprod A B) (ii1 a) (ii2 b) (paths A a b) (idpath a) (the T t)
;   (nat_rect P z s n) (bool_rect P t f b) (unit_rect P u x)
;   (coprod_rect P f g v) (empty_rect P e) (paths_rect P pr e)
;   (let x a b) -- definitional: x binds the VALUE of a, transparent to conv
; and any other list is an application spine. (f) == f here too.
;
; BAKED post.l-style on every corpus target (host + ai0 + the inle kernel +
; wasm), and swept at the tail into the ONE `uu` book (the holo/glaze module
; pattern) -- the surface is (uu 'vof), (uu 'defn), (uu 'chk), (uu 'lof), and every
; internal stays a probe away. the UniMath theorem corpus rides in test/uu.l
; (and the test/uu*.l ladder over it), binding this surface at its head.
(: uu-mark (names ()))

; --- the kernel: values, evaluation, conversion, checking ---
(: GLOB (tablet 0) HELPC (tablet 0)
   SRC (tablet 0) CMEM (tablet 0) BRIDGE (tablet 0)

   (tagv v) (? (two? v) (cap v) v)
   (e2 l) (cap (cup l))
   (e3 l) (cap (cup (cup l)))
   (e4 l) (cap (cup (cup (cup l))))
   (e5 l) (cap (cup (cup (cup (cup l))))))

(: (vsucc v) (? (charm? v) (v + 1) `('succ v))

   (capp cl v) (vof (link `((e3 cl) v) (e2 cl)) (e4 cl))

   (vapp f a) (? (id? (tagv f) 'lam) (capp (e2 f) a) `('na f a))

   (dop1 v) (? (id? (tagv v) 'chain) (e2 v) `('np1 v))
   (dop2 v) (? (id? (tagv v) 'chain) (e3 v) `('np2 v))

   (donr P z s m)
   (? (charm? m) (: (go k acc) (? (k = m) acc (go (k + 1) (vapp (vapp s k) acc)))
                  (go 0 z))
      (id? (tagv m) 'succ) (vapp (vapp s (e2 m)) (donr P z s (e2 m)))
      `('nnr P z s m))

   (dobr P x y v) (? (id? v 'true) x (id? v 'false) y `('nbr P x y v))
   (dour P x v) (? (id? v 'tt) x `('nur P x v))
   (docr P f g v) (? (id? (tagv v) 'i1) (vapp f (e2 v))
                     (id? (tagv v) 'i2) (vapp g (e2 v))
                     `('ncr P f g v))
   (doer P v) `('ner P v)
   (dojr P r ev) (? (id? (tagv ev) 'refl) r `('njr P r ev))

   (vof-sym en x)
   ; found-tests are STRUCTURAL (two?): a `?` on the (name value) pair NETS
   ; the value -- a DAG-shared value walks as a TREE, and one lookup of a
   ; big bound value costs seconds (the gka tower: 4.5s -> 0ms).
   (: e (assoc x en)
      (? (two? e) (e2 e)
         (: g (peep GLOB x 0)
            (? (two? g) (e2 g) (scare 'uu-unbound x)))))

   (vof en t)
   (? (charm? t) t
      (nom? t) (? (member? t '(UU nat bool unit empty tt true false)) t
                  (id? t 'zero) 0
                  (vof-sym en t))
      (: h (cap t)
         (? (two? h) (vof-spine en (vof en h) (cup t))
            (id? h 'UU)     (? (= (e2 t) 0) 'UU `('U (e2 t)))         ; (UU level) -> a sort value (UU0 stays the symbol UU; level may be an expr, Stage 2)
            (id? h 'lam)    `('lam `('clo en (e2 t) (e3 t)))
            (id? h 'pi)     `('pi  (vof en (e3 t)) `('clo en (e2 t) (e4 t)))
            (id? h 'total2) `('sig (vof en (e3 t)) `('clo en (e2 t) (e4 t)))
            (id? h 'tpair)  `('chain (vof en (e2 t)) (vof en (e3 t)))
            (id? h 'pr1)    (dop1 (vof en (e2 t)))
            (id? h 'pr2)    (dop2 (vof en (e2 t)))
            (id? h 'succ)   (vsucc (vof en (e2 t)))
            (id? h 'coprod) `('coprod (vof en (e2 t)) (vof en (e3 t)))
            (id? h 'ii1)    `('i1 (vof en (e2 t)))
            (id? h 'ii2)    `('i2 (vof en (e2 t)))
            (id? h 'paths)  `('paths (vof en (e2 t)) (vof en (e3 t)) (vof en (e4 t)))
            (id? h 'idpath) `('refl (vof en (e2 t)))
            (id? h 'the)    (vof en (e3 t))
            (id? h 'let)    (vof (link `((e2 t) (vof en (e3 t))) en) (e4 t))
            (id? h 'nat_rect)    (donr (vof en (e2 t)) (vof en (e3 t)) (vof en (e4 t)) (vof en (e5 t)))
            (id? h 'bool_rect)   (dobr (vof en (e2 t)) (vof en (e3 t)) (vof en (e4 t)) (vof en (e5 t)))
            (id? h 'unit_rect)   (dour (vof en (e2 t)) (vof en (e3 t)) (vof en (e4 t)))
            (id? h 'coprod_rect) (docr (vof en (e2 t)) (vof en (e3 t)) (vof en (e4 t)) (vof en (e5 t)))
            (id? h 'empty_rect)  (doer (vof en (e2 t)) (vof en (e3 t)))
            (id? h 'paths_rect)  (dojr (vof en (e2 t)) (vof en (e3 t)) (vof en (e4 t)))
            (vof-spine en (vof en h) (cup t)))))

   ; empty-list tests are STRUCTURAL (two?): a ai list of zeros NETS zero,
   ; so !as would call (add n 0)'s final argument list (0) empty -- the net law.
   (vof-spine en f as)
   (? !(two? as) f (vof-spine en (vapp f (vof en (cap as))) (cup as)))

   (conv d a b)
   (? (id? a b) 1                    ; the same heap object converts to itself:
      (&& (charm? a) (charm? b)) (a = b) ; O(1) across the shared neutral towers
      (&& (nom? a) (nom? b)) (id? a b)
      (|| (id? (tagv a) 'lam) (id? (tagv b) 'lam))
      (: fr `('nv d) (conv (d + 1) (vapp a fr) (vapp b fr)))
      (&& (id? (tagv a) 'chain) (two? b) !(id? (cap b) 'chain))
      (&& (conv d (e2 a) (dop1 b)) (conv d (e3 a) (dop2 b)))
      (&& (id? (tagv b) 'chain) (two? a) !(id? (cap a) 'chain))
      (&& (conv d (dop1 a) (e2 b)) (conv d (dop2 a) (e3 b)))
      (&& (id? (tagv a) 'pi) (id? (tagv b) 'pi))
      (&& (conv d (e2 a) (e2 b))
          (: fr `('nv d) (conv (d + 1) (capp (e3 a) fr) (capp (e3 b) fr))))
      (&& (id? (tagv a) 'sig) (id? (tagv b) 'sig))
      (&& (conv d (e2 a) (e2 b))
          (: fr `('nv d) (conv (d + 1) (capp (e3 a) fr) (capp (e3 b) fr))))
      (&& (two? a) (two? b) (id? (cap a) (cap b))) (conv-args d (cup a) (cup b))
      0)

   (conv-args d as bs)
   (? (&& !(two? as) !(two? bs)) 1
      (|| !(two? as) !(two? bs)) 0
      (&& (conv d (cap as) (cap bs)) (conv-args d (cup as) (cup bs))))

   (inf-sym cx x)
   (? (id? x 'UU) 'UU
      (member? x '(nat bool unit empty)) 'UU
      (id? x 'zero) 'nat
      (id? x 'tt) 'unit
      (member? x '(true false)) 'bool
      (: e (assoc x cx)
         (? (two? e) (e2 e)
            (: g (peep GLOB x 0)
               (? (two? g) (cap g) (scare 'uu-unbound x))))))

   (inf-spine cx en d f as)
   (? !(two? as) f
      (id? (tagv f) 'pi)
      (: a (cap as)
         _ (chk cx en d a (e2 f))
         (inf-spine cx en d (capp (e3 f) (vof en a)) (cup as)))
      (scare 'uu-not-a-pi as))

   (chk cx en d t T)
   (? (&& (two? t) (id? (cap t) 'lam))
      (? (id? (tagv T) 'pi)
         (: x (e2 t) fr `('nv d)
            (chk (link `(x (e2 T)) cx) (link `(x fr) en) (d + 1)
                 (e3 t) (capp (e3 T) fr)))
         (scare 'uu-lam-needs-pi t))
      (&& (two? t) (id? (cap t) 'tpair))
      (? (id? (tagv T) 'sig)
         (: _ (chk cx en d (e2 t) (e2 T))
            (chk cx en d (e3 t) (capp (e3 T) (vof en (e2 t)))))
         (scare 'uu-tpair-needs-total2 t))
      (&& (two? t) (id? (cap t) 'ii1))
      (? (id? (tagv T) 'coprod) (chk cx en d (e2 t) (e2 T)) (scare 'uu-ii1-needs-coprod t))
      (&& (two? t) (id? (cap t) 'ii2))
      (? (id? (tagv T) 'coprod) (chk cx en d (e2 t) (e3 T)) (scare 'uu-ii2-needs-coprod t))
      (&& (two? t) (id? (cap t) 'idpath))
      (? (id? (tagv T) 'paths)
         (: _ (chk cx en d (e2 t) (e2 T))
            v (vof en (e2 t))
            (? (&& (conv d v (e3 T)) (conv d v (e4 T))) 1 (scare 'uu-idpath-mismatch t)))
         (scare 'uu-idpath-needs-paths t))
      (&& (two? t) (id? (cap t) 'let))
      (: x (e2 t)
         Av (inf cx en d (e3 t))
         va (vof en (e3 t))
         (chk (link `(x Av) cx) (link `(x va) en) d (e4 t) T))
      (: Ti (inf cx en d t)
         (? (conv d T Ti) 1 (scare 'uu-type-mismatch t))))

   (inf cx en d t)
   (? (charm? t) 'nat
      (nom? t) (inf-sym cx t)
      (: h (cap t)
         (? (two? h) (inf-spine cx en d (inf cx en d h) (cup t))
            (id? h 'pi)
            (: x (e2 t)
               _ (chk cx en d (e3 t) 'UU)
               fr `('nv d)
               _ (chk (link `(x (vof en (e3 t))) cx) (link `(x fr) en) (d + 1) (e4 t) 'UU)
               'UU)
            (id? h 'total2)
            (: x (e2 t)
               _ (chk cx en d (e3 t) 'UU)
               fr `('nv d)
               _ (chk (link `(x (vof en (e3 t))) cx) (link `(x fr) en) (d + 1) (e4 t) 'UU)
               'UU)
            (id? h 'coprod)
            (: _ (chk cx en d (e2 t) 'UU) _ (chk cx en d (e3 t) 'UU) 'UU)
            (id? h 'paths)
            (: _ (chk cx en d (e2 t) 'UU)
               Av (vof en (e2 t))
               _ (chk cx en d (e3 t) Av)
               _ (chk cx en d (e4 t) Av)
               'UU)
            (id? h 'succ) (: _ (chk cx en d (e2 t) 'nat) 'nat)
            (id? h 'idpath)
            (: Av (inf cx en d (e2 t)) v (vof en (e2 t)) `('paths Av v v))
            (id? h 'pr1)
            (: S (inf cx en d (e2 t))
               (? (id? (tagv S) 'sig) (e2 S) (scare 'uu-pr1-needs-total2 t)))
            (id? h 'pr2)
            (: S (inf cx en d (e2 t))
               (? (id? (tagv S) 'sig) (capp (e3 S) (dop1 (vof en (e2 t))))
                  (scare 'uu-pr2-needs-total2 t)))
            (id? h 'the)
            (: _ (chk cx en d (e2 t) 'UU)
               Tv (vof en (e2 t))
               _ (chk cx en d (e3 t) Tv)
               Tv)
            (id? h 'let)
            (: x (e2 t)
               Av (inf cx en d (e3 t))
               va (vof en (e3 t))
               (inf (link `(x Av) cx) (link `(x va) en) d (e4 t)))
            (id? h 'nat_rect)
            (: P (e2 t)
               _ (chk cx en d (e5 t) 'nat)
               _ (chk cx en d P (vof 0 '(pi x nat UU)))
               Pv (vof en P)
               _ (chk cx en d (e3 t) (vapp Pv 0))
               _ (chk cx en d (e4 t)
                      (vof `(`('P Pv)) '(pi k nat (pi r (P k) (P (succ k))))))
               (vapp Pv (vof en (e5 t))))
            (id? h 'bool_rect)
            (: P (e2 t)
               _ (chk cx en d (e5 t) 'bool)
               _ (chk cx en d P (vof 0 '(pi x bool UU)))
               Pv (vof en P)
               _ (chk cx en d (e3 t) (vapp Pv 'true))
               _ (chk cx en d (e4 t) (vapp Pv 'false))
               (vapp Pv (vof en (e5 t))))
            (id? h 'unit_rect)
            (: P (e2 t)
               _ (chk cx en d (e4 t) 'unit)
               _ (chk cx en d P (vof 0 '(pi x unit UU)))
               Pv (vof en P)
               _ (chk cx en d (e3 t) (vapp Pv 'tt))
               (vapp Pv (vof en (e4 t))))
            (id? h 'empty_rect)
            (: P (e2 t)
               _ (chk cx en d (e3 t) 'empty)
               _ (chk cx en d P (vof 0 '(pi x empty UU)))
               (vapp (vof en P) (vof en (e3 t))))
            (id? h 'coprod_rect)
            (: S (inf cx en d (e5 t))
               (? (id? (tagv S) 'coprod)
                  (: A (e2 S) B (e3 S) P (e2 t)
                     _ (chk cx en d P
                            (vof `(`('A A) `('B B)) '(pi x (coprod A B) UU)))
                     Pv (vof en P)
                     _ (chk cx en d (e3 t)
                            (vof `(`('A A) `('P Pv)) '(pi a A (P (ii1 a)))))
                     _ (chk cx en d (e4 t)
                            (vof `(`('B B) `('P Pv)) '(pi b B (P (ii2 b)))))
                     (vapp Pv (vof en (e5 t))))
                  (scare 'uu-coprod_rect t)))
            (id? h 'paths_rect)
            (: E (inf cx en d (e4 t))
               (? (id? (tagv E) 'paths)
                  (: A (e2 E) av (e3 E) bv (e4 E) P (e2 t)
                     _ (chk cx en d P
                            (vof `(`('A A) `('a av)) '(pi b A (pi e (paths A a b) UU))))
                     Pv (vof en P)
                     _ (chk cx en d (e3 t) (vapp (vapp Pv av) `('refl av)))
                     (vapp (vapp Pv bv) (vof en (e4 t))))
                  (scare 'uu-paths_rect t)))
            (member? h '(lam tpair ii1 ii2)) (scare 'uu-cannot-infer t)
            (inf-spine cx en d (inf-sym cx h) (cup t))))))

; --- drivers: a definition is checked then pinned; an axiom is a book entry
; --- with a type and no value (its value is its own neutral name); rejects
; --- runs a thunk expecting the kernel to refuse (the help cell escapes).
(: (defn nm T t)
   (: _ (chk 0 0 0 T 'UU)
      Tv (vof 0 T)
      _ (chk 0 0 0 t Tv)
      _ (pin GLOB nm `(Tv (vof 0 t)))
      _ (pin SRC nm (link t ()))
      nm)
   (axm nm T)
   (: _ (chk 0 0 0 T 'UU)
      _ (pin GLOB nm `((vof 0 T) `('nv nm)))
      nm)
   ; the Qed driver: CHECKED like defn, then sealed -- pinned with its own
   ; neutral as value, so applying the proof never evaluates it. Coq's
   ; Qed/Defined distinction, here because strict NbE would otherwise build
   ; the proof's whole beta-normal form at every use.
   (defq nm T t)
   (: _ (chk 0 0 0 T 'UU)
      Tv (vof 0 T)
      _ (chk 0 0 0 t Tv)
      _ (pin GLOB nm `(Tv `('nv nm)))
      nm)
   (rejects th)
   (: r (call-cc (\ k (: _ (pin HELPC () (\ s a b (k 'rejected)))
                         v (th 0)
                         'accepted)))
      _ (pin HELPC () 0)
      r))

; --- uu2l: the uu-to-l leg. uu2coq and uu2lean re-CERTIFY the corpus in two
; --- foreign kernels; uu2l runs it HOME -- a CLOSED term compiles to an ai
; --- form whose value IS vof's answer (charms for nats, ('chain a b) for
; --- pairs), at compiled-ai speed; lof (l-of, vof's fast twin) evaluates one.
; --- UNTRUSTED by design: chk/conv never touch it, so a uu2l bug can miss a
; --- demo, never fake a theorem -- and the corpus asserts (vof t = lof t)
; --- differentially wherever both lanes are tractable. generated code has NO
; --- free names: the runtime kit and every global embed as live literals
; --- under the quote sigil, so nothing a uu binder spells can capture.
; --- BRIDGE maps standard names to native ai (add is +, the eager-NbE O(n)
; --- niszero is (= m 0)) -- each bridge rides the SAME differential gate.
; --- defn feeds SRC; a defq/axm name compiles to its own neutral, exactly
; --- the sealed book value.
(: Q (cap '(\ x))
   C (cap '(: x 1 2))
   (qlit v) (link Q (link v ()))

   (kchain a b) `('chain a b)
   (kp1 v) (? (two? v) (? (id? (cap v) 'chain) (e2 v) `('np1 v)) `('np1 v))
   (kp2 v) (? (two? v) (? (id? (cap v) 'chain) (e3 v) `('np2 v)) `('np2 v))
   (ksucc v) (v + 1)
   (ki1 a) `('i1 a)
   (ki2 a) `('i2 a)
   (krefl a) `('refl a)
   (knrec s z n) (: (go k acc) (? (k = n) acc (go (k + 1) (s k acc))) (go 0 z))
   (kbrec x y b) (? (id? b 'true) x y)
   (kcrec f g v) (? (id? (cap v) 'i1) (f (e2 v)) (g (e2 v)))
   (kseq e r) r

   (bound? x bs) (? !(two? bs) 0 (? (id? x (cap bs)) 1 (bound? x (cup bs))))

   (uglo nm)
   (: c (peep CMEM nm 0)
      (? (two? c) (e2 c)
         (: b (peep BRIDGE nm 0)
            (? (two? b) (e2 b)
               (: sc (peep SRC nm 0)
                  (? (two? sc) (: v (ev (u2 (cap sc) ()))
                           _ (pin CMEM nm `('hit v))
                           v)
                     `('nv nm)))))))

   (u2app t bs)
   (: (walk as) (? !(two? as) () (link (u2 (cap as) bs) (walk (cup as))))
      (link (u2 (cap t) bs) (walk (cup t))))

   (u2 t bs)
   (? (charm? t) t
      (nom? t)
      (? (id? t 'zero) 0
         (member? t '(UU nat bool unit empty tt true false)) (qlit t)
         (bound? t bs) t
         (qlit (uglo t)))
      (: h (cap t)
         (? (two? h) (u2app t bs)
            (id? h 'lam) (link Q (link (e2 t) (link (u2 (e3 t) (link (e2 t) bs)) ())))
            (id? h 'let) (link C (link (e2 t) (link (u2 (e3 t) bs)
                           (link (u2 (e4 t) (link (e2 t) bs)) ()))))
            (id? h 'the) (u2 (e3 t) bs)
            (member? h '(pi total2 coprod paths)) (qlit `('ty h))
            (id? h 'tpair) `((qlit kchain) (u2 (e2 t) bs) (u2 (e3 t) bs))
            (id? h 'pr1)   `((qlit kp1) (u2 (e2 t) bs))
            (id? h 'pr2)   `((qlit kp2) (u2 (e2 t) bs))
            (id? h 'succ)  `((qlit ksucc) (u2 (e2 t) bs))
            (id? h 'ii1)   `((qlit ki1) (u2 (e2 t) bs))
            (id? h 'ii2)   `((qlit ki2) (u2 (e2 t) bs))
            (id? h 'idpath) `((qlit krefl) (u2 (e2 t) bs))
            (id? h 'nat_rect)    `((qlit knrec) (u2 (e4 t) bs) (u2 (e3 t) bs) (u2 (e5 t) bs))
            (id? h 'bool_rect)   `((qlit kbrec) (u2 (e3 t) bs) (u2 (e4 t) bs) (u2 (e5 t) bs))
            (id? h 'unit_rect)   `((qlit kseq) (u2 (e4 t) bs) (u2 (e3 t) bs))
            (id? h 'coprod_rect) `((qlit kcrec) (u2 (e3 t) bs) (u2 (e4 t) bs) (u2 (e5 t) bs))
            (id? h 'paths_rect)  `((qlit kseq) (u2 (e4 t) bs) (u2 (e3 t) bs))
            (id? h 'empty_rect)  `((qlit kseq) (u2 (e3 t) bs) (qlit 'ner))
            (u2app t bs))))

   (uu2l t) (u2 t ())
   (lof t) (ev (u2 t ()))
   (bridge nm f) (: _ (pin BRIDGE nm `('hit f)) nm))

; --- the arity door. defn/defq/axm are fully curried, so a paren slip that
; --- hands one too few operands is not an error -- it is a truthy CLOSURE one
; --- curry away from running, an assert paints it green, and NOTHING pins
; --- (the (f)==f trap at proof grain; too many operands feed the returned nom
; --- and vanish the same way). the macros guard CALL position: exactly the
; --- right operand count, or the form scares carrying itself. the expansion
; --- heads (1 defn) -- the identity's head is no macro, so no re-expansion --
; --- and the functions keep their names, so the baked book still serves them
; --- ((uu 'defn) is boot/overlay.l's door, and book calls bypass the macro).
(: _ (:: 'defn (\ l (? (= 3 (tally l)) (link '(1 defn) l) `('scare `('\ 'uu-defn-arity) `('\ l)))))
   _ (:: 'defq (\ l (? (= 3 (tally l)) (link '(1 defq) l) `('scare `('\ 'uu-defq-arity) `('\ l)))))
   _ (:: 'axm  (\ l (? (= 2 (tally l)) (link '(1 axm)  l) `('scare `('\ 'uu-axm-arity)  `('\ l)))))
   0)

; --- the module boundary: every name the span above leaked since `uu-mark`
; --- sweeps off the global book into ONE book pinned under `uu`. The span
; --- defines only NEW names (probed: 55, zero rebinds of pre-existing
; --- globals), so the book grows by exactly one name: `uu`.
(: seen (: t (tablet 0) _ (each uu-mark (\ k (pin t k 1))) t)
   uum (tablet 0)
   _ (each (names ())
      (\ k (? (peep seen k 0) 0
              (: v (peep book k 0) _ (pull book k 0) (pin uum k v)))))
   _ (pull book 'uu-mark 0)
   _ (pull uum 'uu-mark 0)
   _ (pin book 'uu (\ k (? (id? k 'keys) (keys uum) (peep uum k 0))))  ; lookup-only closure: uum private,
   0)                                                                  ;   unpoisonable; (uu 'keys) introspects
