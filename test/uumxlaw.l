; test/uumxlaw.l -- the laws of love's `+` and `*` dispatch, proved of test/uumx.l's table
; every proof is `idpath true` over a bounded forall; that a lane names its C function is the fuzz's.
(test (elem 'vof (names ())))

; --- the roster's shape, said once: every forall below ranges over mxnk itself,
; --- never a written count (too short a count passes green and says nothing) ---
(test
 (14 = (vof 0 'mxnk))
 (12 = (vof 0 'mxnl))
 (5 = (vof 0 'mxnb)))

; --- the band lattice: a 5x5 band matrix plus the band assignment is the whole table ---
(test
 (defq mx-add-factors-through-bands
   (paths bool
     (mxsq (lam a (lam b (nateqb (mxadd a b) (mxaddband (mxband a) (mxband b))))))
     true)
   (idpath true))
 (defq mx-mul-factors-through-bands
   (paths bool
     (mxsq (lam a (lam b (nateqb (mxmul a b) (mxmulband (mxband a) (mxband b))))))
     true)
   (idpath true)))

; --- dispatch commutes up to mirror: a symmetric lane orients itself, the
; --- positional bin_a/bin_b pair carries orientation in the name, and the table
; --- adds none of its own. mirror being an involution is half the claim ---
(test
 (defq mx-mirror-involutive
   (paths bool (mxall mxnl (lam l (nateqb (mxmirror (mxmirror l)) l))) true)
   (idpath true))
 (defq mx-add-dispatch-commutes
   (paths bool (mxsq (lam a (lam b (nateqb (mxadd a b) (mxmirror (mxadd b a)))))) true)
   (idpath true))
 (defq mx-mul-dispatch-commutes
   (paths bool (mxsq (lam a (lam b (nateqb (mxmul a b) (mxmirror (mxmul b a)))))) true)
   (idpath true)))

; --- the partition, named: the numeric band, the text band, and kmint alone ---
(test
 ; a point lands in kmint's band; mxnumeric is mx.l's mx-numk, lifted
 (defn mxiff (pi a bool (pi b bool bool))            ; uuval's beqb sorts after this file
   (lam a (lam b (orb (andb a b) (andb (negb a) (negb b))))))
 (defn mxpoint (pi k nat bool) (lam k (nateqb (mxband k) (mxband mxKMint))))
 ; exactly mx-numk is the numeric band: mx-numk, the row rosters and the quotient agree
 (defq mx-numerics-one-band
   (paths bool
     (mxall mxnk (lam k (mxiff (mxnumeric k) (nateqb (mxband k) (mxband mxKCharm)))))
     true)
   (idpath true))
 ; a symbol is a point, not text: identity under +, annihilator under *
 (defq mx-nom-is-point
   (paths nat (mxband mxKNom) (mxband mxKMint)) (idpath (mxband mxKMint)))
 ; kmint and KNom alone in the point lane: the dispatchers early-out on a point
 ; before the table, so a third kind there would escape the matrix modelled here
 (defq mx-points-alone
   (paths bool
     (mxall mxnk (lam k (mxiff (mxpoint k) (orb (nateqb k mxKMint) (nateqb k mxKNom)))))
     true)
   (idpath true)))

; --- () is the unit under + and the zero under *, in every lane at once ---
(test
 (defq mx-mint-is-the-unit
   (paths bool (mxall mxnk (lam b (nateqb (mxadd mxKMint b) mxLbin_unit))) true)
   (idpath true))
 (defq mx-mint-annihilates
   (paths bool (mxall mxnk (lam b (nateqb (mxmul mxKMint b) mxL0))) true)
   (idpath true)))

; --- the diagonal: one add/mul lane pair per band, the five bands ---
(test
 (defq mx-diag-mint-add (paths nat (mxadd mxKMint mxKMint) mxLbin_unit) (idpath mxLbin_unit))
 (defq mx-diag-mint-mul (paths nat (mxmul mxKMint mxKMint) mxL0) (idpath mxL0))
 ; kstring represents the text band
 (defq mx-diag-text-add (paths nat (mxadd mxKString mxKString) mxLadd_string) (idpath mxLadd_string))
 (defq mx-diag-text-mul (paths nat (mxmul mxKString mxKString) mxL0) (idpath mxL0))
 (defq mx-diag-num-add (paths nat (mxadd mxKCharm mxKCharm) mxLaddn) (idpath mxLaddn))
 (defq mx-diag-num-mul (paths nat (mxmul mxKCharm mxKCharm) mxLmuln) (idpath mxLmuln))
 (defq mx-diag-chain-add (paths nat (mxadd mxKChain mxKChain) mxLadd_seq) (idpath mxLadd_seq))
 ; chain*chain is the cartesian product: the list lane a semiring
 (defq mx-diag-chain-mul (paths nat (mxmul mxKChain mxKChain) mxLmul_cart) (idpath mxLmul_cart))
 (defq mx-diag-hot-add (paths nat (mxadd mxKTablet mxKTablet) mxLaddh) (idpath mxLaddh))
 (defq mx-diag-hot-mul (paths nat (mxmul mxKTablet mxKTablet) mxLmulh) (idpath mxLmulh)))

; --- named cells ---
(test
 ; mixed bands degenerate: the other operand answers whole, positionally
 (defq mx-num-str-degenerates (paths nat (mxadd mxKCharm mxKString) mxLbin_b) (idpath mxLbin_b))
 (defq mx-str-num-degenerates (paths nat (mxadd mxKString mxKCharm) mxLbin_a) (idpath mxLbin_a))
 ; a nom is a point: against text or a list it is the identity
 (defq mx-nom-str-is-unit (paths nat (mxadd mxKNom mxKString) mxLbin_unit) (idpath mxLbin_unit))
 (defq mx-nom-chain-is-unit (paths nat (mxadd mxKNom mxKChain) mxLbin_unit) (idpath mxLbin_unit))
 ; str*str is the absorbing zero; a number against either repeats it
 (defq mx-str-str-is-zero (paths nat (mxmul mxKString mxKString) mxL0) (idpath mxL0))
 (defq mx-num-str-repeats (paths nat (mxmul mxKCharm mxKString) mxLmul_rep) (idpath mxLmul_rep))
 ; a tablet or a lambda wins over all but a point (the band: mint and nom alike)
 (defq mx-tablet-dominates
   (paths bool
     (mxall mxnk (lam b (orb (mxpoint b) (nateqb (mxadd mxKTablet b) mxLaddh))))
     true)
   (idpath true))
 (defq mx-hot-dominates
   (paths bool
     (mxall mxnk (lam b (orb (mxpoint b) (nateqb (mxmul mxKHot b) mxLmulh))))
     true)
   (idpath true)))

; --- the compose cell: the lane test/uuhom.l's homcomp monoid is about, pinned here
; --- guard: uuhom's terms load earlier by sort order and must be up ---
(test (two? (peep GLOB 'homcomp 0))
        (two? (peep GLOB 'hom-assoc 0))
        (two? (peep GLOB 'idfun 0)))
(test
 (defn mxLcompose nat mxLmulh)                     ; the lane uuhom's homcomp spells
 (defq mx-compose-diag (paths nat (mxmul mxKHot mxKHot) mxLcompose) (idpath mxLcompose))
 ; the mint there is the zero; the monoid's unit idfun is a khot like any other
 (defq mx-compose-zero (paths nat (mxmul mxKHot mxKMint) mxL0) (idpath mxL0))
 ; the Church sum is the band's other, distinct lane
 (defq mx-church-add-diag (paths nat (mxadd mxKHot mxKHot) mxLaddh) (idpath mxLaddh))
 (defq mx-church-lanes-apart (paths bool (nateqb mxLaddh mxLcompose) false) (idpath false)))

; --- planted faults: each load-bearing claim's false twin must be refused, lest a
; --- vacuous forall paint the theorems above green ---
(hear (p \ e \ peep HELPC () 0 @ h (h ? (h p e) 0)))
(test
 ; the cartesian cell is not the zero
 ('accepted = (rejects (z \ defq mx-ok-cart
   (paths nat (mxmul mxKChain mxKChain) mxLmul_cart) (idpath mxLmul_cart))))
 ('rejected = (rejects (z \ defq mx-bad-cart (paths nat (mxmul mxKChain mxKChain) mxL0) (idpath mxL0))))
 ; the band assignment shifted by a kind breaks the factorization
 ('rejected = (rejects (z \ defq mx-bad-band
   (paths bool
     (mxsq (lam a (lam b (nateqb (mxadd a b) (mxaddband (mxband a) (mxband (succ b)))))))
     true)
   (idpath true))))
 ; the numeric band is mx-numk itself, not a roster slid one kind along
 ('rejected = (rejects (z \ defq mx-bad-numeric
   (paths bool
     (mxall mxnk (lam k (mxiff (mxnumeric (succ k)) (nateqb (mxband k) (mxband mxKCharm)))))
     true)
   (idpath true))))
 ; mirror is not the identity: the positional pair trades places
 ('rejected = (rejects (z \ defq mx-bad-mirror
   (paths bool (mxsq (lam a (lam b (nateqb (mxadd a b) (mxadd b a))))) true)
   (idpath true))))
 ; the compose cell is the mul lane, not the Church sum
 ('accepted = (rejects (z \ defq mx-ok-compose (paths nat (mxmul mxKHot mxKHot) mxLmulh) (idpath mxLmulh))))
 ('rejected = (rejects (z \ defq mx-bad-compose (paths nat (mxmul mxKHot mxKHot) mxLaddh) (idpath mxLaddh))))
 ; the mint annihilates there rather than uniting
 ('rejected = (rejects (z \ defq mx-bad-compose-unit (paths nat (mxmul mxKHot mxKMint) mxLmulh) (idpath mxLmulh)))))
(hear test-strict)
