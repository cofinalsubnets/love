; random numbers (xoshiro256++ seeded by SplitMix64).
; - state is a rank-1 word-int tuple of length 4 (256 bits), riding the tuple machinery.
; - C holds no state: the primitives are rng-seed plus the pure functional
;   stream rand-next / randf-next (the input state is copied, never mutated).
; - the global stream is prelude lisp over dict['rng-state]: rng-get reads it
;   (lazily clock-seeding on first use); rng-set validates + installs; rand /
;   randf draw through rand-next / randf-next and store the successor state.
; - (rand n) -> [0,n); n <= 0 -> a full-width non-negative fixnum. (randf _) ->
;   [0,1). A given seed reproduces the same sequence on every target.

(: (gfirst seed) (: _ (rng-set (rng-seed seed)) (rand 0))   ; 1st global draw after seeding
   (gseq3 seed)  (: _ (rng-set (rng-seed seed))             ; first 3 global draws
                    a (rand 0) b (rand 0) c (rand 0) (L a b c))
   (ffirst seed) (A (rand-next (rng-seed seed))))          ; 1st functional draw
(assert
 ; --- state-tuple structure: rank-1 word-int (Z) tuple, length 4 (C-typed on 32-bit,
 ; where C is the 8-byte-wide kind, so the 256-bit payload survives either way) ---
 (= 4 (alen (rng-seed 1)))
 (= 1 (arank (rng-seed 1)))
 (= z (atype (rng-seed 1)))
 (= 4 (alen (rng-get 0)))                  ; the global is a valid state tuple too

 ; --- determinism: same seed -> same sequence (global and functional) ---
 (= (gseq3 42) (gseq3 42))
 (= (ffirst 7) (ffirst 7))
 (= (gfirst 100) (gfirst 100))

 ; --- different seeds give different streams ---
 !(= (gfirst 1) (gfirst 2))
 !(= (ffirst 1) (ffirst 2))

 ; --- functional purity: rand-next does not mutate its input state ---
 (: st (rng-seed 7) a (A (rand-next st)) b (A (rand-next st)) (= a b))
 ; ...and chaining the returned state advances the stream
 (: st (rng-seed 7) p (rand-next st) q (rand-next (B p)) !(= (A p) (A q)))
 (: st (rng-seed 7) p (rand-next st) (= 4 (alen (B p))))   ; st' is a state tuple

 ; --- rng-get / rng-set snapshot + restore reproduces a draw ---
 (: _ (rng-set (rng-seed 55)) g0 (rng-get 0)
    x (rand 0) _ (rng-set g0) y (rand 0) (= x y))
 ; rng-get is a copy: mutating the global later doesn't change the snapshot
 (: _ (rng-set (rng-seed 55)) g0 (rng-get 0) _ (rand 0)
    (= (gfirst 55) (A (rand-next g0))) )

 ; --- bounded draws stay in [0,n); full-width draws are non-negative ---
 (< (rand 10) 10)  (<= 0 (rand 10))
 (< (rand 2) 2)    (<= 0 (rand 0))
 (<= 0 (rand -5))                          ; n <= 0 -> full-width non-negative

 ; --- randf in [0,1), and is a float ---
 (: u (randf 0) (< u 1))
 (: u (randf 0) (<= 0 u))
 (flop (randf 0))
 (: p (randf-next (rng-seed 3)) (< (A p) 1))
 (: p (randf-next (rng-seed 3)) (<= 0 (A p)))
 (: p (randf-next (rng-seed 3)) (= 4 (alen (B p))))

 ; --- invalid state -> nil (rng-set / functional draws validate) ---
 (nilp (rng-set 5))
 (nilp (rng-set (arr z '(3) 0)))           ; wrong length
 (nilp (rng-set (arr r '(4) 0)))           ; wrong element type
 (nilp (rand-next 5))
 (nilp (randf-next 0))

 ; --- randint (prelude): bounded functional draw, pure in its state ---
 (: r (randint (rng-seed 9) 6) (<= 0 (A r)))
 (: r (randint (rng-seed 9) 6) (< (A r) 6))
 (: r (randint (rng-seed 9) 6) (= 4 (alen (B r))))
 (: st (rng-seed 9) (= (A (randint st 6)) (A (randint st 6))))   ; purity

 ; --- cross-target reproducibility pins (64-bit host values) ---
 (= (gseq3 42) '(1186220554705070239 1269524112903976849 4314585860703317388))
 (= 978559313737459048 (ffirst 12345)))
