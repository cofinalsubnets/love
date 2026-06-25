; random numbers (xoshiro256++ seeded by SplitMix64).
; - state is a rank-1 word-int tuple of length 4 (256 bits), riding the tuple machinery.
; - C holds no state: the primitives are rng-seed plus the pure functional
;   stream rand-next / randf-next (the input state is copied, never mutated).
; - the global stream is prel lisp over hidden rng state: rng-get reads it
;   (lazily clock-seeding on first use); rng-set validates + installs; rand /
;   randf draw through rand-next / randf-next and store the successor state.
; - (rand n) -> [0,n); n <= 0 -> a full-width non-negative fixnum. (randf _) ->
;   [0,1). A given seed reproduces the same sequence on every target.

(: (gfirst seed) (: _ (rng-set (rng-seed seed)) (rand 0))   ; 1st global draw after seeding
   (gseq3 seed)  (: _ (rng-set (rng-seed seed))             ; first 3 global draws
                    a (rand 0) b (rand 0) c (rand 0) `(a b c))
   (ffirst seed) (cap (rand-next (rng-seed seed))))          ; 1st functional draw
; the RNG state holds 256 bits whatever the word: a rank-1 length-4 array whose
; limbs are 64-bit -- a Z (word-int) array on a 64-bit word, a C (8-byte) array
; on a 32-bit one. The draw is canonicalized to a fixed 62 bits (a fixnum on a
; 64-bit word, a bignum on a 32-bit one), so a seed reproduces the SAME sequence
; on every target -- the only platform-visible difference is the state's tier.
(assert
 ; --- state-tuple structure: rank-1, length 4, 64-bit limbs (Z array, or C on
 ; a 32-bit word where C is the 8-byte-wide kind -- the 256-bit payload either way) ---
 (= 4 (tally (rng-seed 1)))
 (= 1 (rank (rng-seed 1)))
 (= (tier (rng-seed 0)) (tier (rng-seed 1)))  ; a seed's limb type is stable...
 (? word (= star-tray (tier (rng-seed 1))) 1)      ; ...a Z (word-int) array on a 64-bit word (a C array on wasm)
 (= 4 (tally (rng-get 0)))                  ; the global is a valid state tuple too

 ; --- determinism: same seed -> same sequence (global and functional) ---
 (= (gseq3 42) (gseq3 42))
 (= (ffirst 7) (ffirst 7))
 (= (gfirst 100) (gfirst 100))

 ; --- different seeds give different streams ---
 !(= (gfirst 1) (gfirst 2))
 !(= (ffirst 1) (ffirst 2))

 ; --- functional purity: rand-next does not mutate its input state ---
 (: st (rng-seed 7) a (cap (rand-next st)) b (cap (rand-next st)) (= a b))
 ; ...and chaining the returned state advances the stream
 (: st (rng-seed 7) p (rand-next st) q (rand-next (cup p)) !(= (cap p) (cap q)))
 (: st (rng-seed 7) p (rand-next st) (= 4 (tally (cup p))))   ; st' is a state tuple

 ; --- rng-get / rng-set snapshot + restore reproduces a draw ---
 (: _ (rng-set (rng-seed 55)) g0 (rng-get 0)
    x (rand 0) _ (rng-set g0) y (rand 0) (= x y))
 ; rng-get is a copy: mutating the global later doesn't change the snapshot
 (: _ (rng-set (rng-seed 55)) g0 (rng-get 0) _ (rand 0)
    (= (gfirst 55) (cap (rand-next g0))) )

 ; --- bounded draws stay in [0,n); full-width draws are non-negative ---
 (< (rand 10) 10)  (<= 0 (rand 10))
 (< (rand 2) 2)    (<= 0 (rand 0))
 (<= 0 (rand -5))                          ; n <= 0 -> full-width non-negative

 ; --- randf in [0,1), and is a float ---
 (: u (randf 0) (< u 1))
 (: u (randf 0) (<= 0 u))
 (gem? (randf 0))
 (: p (randf-next (rng-seed 3)) (< (cap p) 1))
 (: p (randf-next (rng-seed 3)) (<= 0 (cap p)))
 (: p (randf-next (rng-seed 3)) (= 4 (tally (cup p))))

 ; --- invalid state -> nil (rng-set / functional draws validate) ---
 (nil? (rng-set 5))
 (nil? (rng-set (star-tray '(3) 0)))           ; wrong length
 (nil? (rng-set (gem-tray '(4) 0)))           ; wrong element type
 (nil? (rand-next 5))
 (nil? (randf-next 0))

 ; --- randint (prel): bounded functional draw, pure in its state ---
 (: r (randint (rng-seed 9) 6) (<= 0 (cap r)))
 (: r (randint (rng-seed 9) 6) (< (cap r) 6))
 (: r (randint (rng-seed 9) 6) (= 4 (tally (cup r))))
 (: st (rng-seed 9) (= (cap (randint st 6)) (cap (randint st 6))))   ; purity

 ; --- cross-target reproducibility pins (the same on host, kernel, and wasm) ---
 (= (gseq3 42) '(1186220554705070239 1269524112903976849 4314585860703317388))
 (= 978559313737459048 (ffirst 12345)))
