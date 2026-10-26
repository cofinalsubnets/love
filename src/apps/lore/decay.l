; decay -- a disintegration loop: a short orchestral phrase from a die, strings on four
; chords, a bass under them and a horn's line over them, played round and round, another
; of its moments worn away to silence each time round, none coming back.
;   (decay-new sd)          the loop from seed sd: its phrase and where it wears
;   (decay-at d t)          its samples at the seconds t since it began, a tray, about -1..1
(module (decay decay-new decay-at)
(borrow 'view)                          ; min2, max2
(:
 rate 22050                             ; the phrase's samples a second
 chord-s 2.4                            ; a chord's seconds, four to the phrase
 wear-k 200                             ; where it wears, slots a second
 gaps 900                               ; the moments worn away, one more each time round
 ; ..a die: a number 0 to 1 for each k from seed sd
 (die sd k) (: h (sin (sd * 12.9898 + k * 78.233 + 0.31) * 43758.5453) (h - floor h))
 (hz m) (440.0 * 2.0 ** ((m - 69) / 12.0))
 ; ..a note's envelope over t seconds from its start: up over a, held to d, gone over r
 (env t a d r) (: up (min 1.0 (t / a)) dn (max 0.0 (min 1.0 (1.0 - (t - d) / r))) (up * up * (3.0 - 2.0 * up) * dn * dn))
 ; ..the voices, each a tray of samples for a note of f hertz held d seconds, its tail
 ; after: sung by partials, its pitch wavering once it has spoken
 (tones f d r a ws vr vd ph) (: n (int ((d + r) * rate)) t (iota n / (1.0 * rate))
   w (min 1.0 (t / vd)) p (f * t + w * f * vr / 5.3 * sin (tau * 5.3 * t + ph) / tau)
   (env t a d r * foldl (\ y k (y + ws k * sin (tau * (k + 1) * p + k * ph))) (t * 0.0) ^#ws))
 (strings f d) (: ws (map (k \ 0.55 / (k + 1.0) ** 1.3) ^7)
   (tones (f * 1.003) d 0.9 0.45 ws 0.005 0.6 0.0 + tones (f * 0.997) d 0.9 0.5 ws 0.006 0.7 1.7))
 (bass f d) (tones f d 0.7 0.2 (map (k \ 0.8 / (k + 1.0) ** 1.6) ^5) 0.003 0.5 0.4)
 (horn f d) (tones f d 0.25 0.09 [0.7 0.5 0.34 0.2 0.11 0.06] 0.007 0.35 0.9)
 ; ..samples y laid onto buf from sample s, round past its end to its start
 (lay buf s y) (: i ((s + iota #y) % #buf) (pin buf i (peep buf i 0.0 + y)))
 ; ..the phrase: a key, major or minor, four chords of it; the strings on each chord's three
 ; notes in the middle, the bass on its root, the horn walking its scale over them, mostly
 ; on the chord; a hall's echoes after, and all of it as loud as it may be
 (phrase sd) (: key (48 + int (12.0 * die sd 1)) minor (die sd 2 < 0.45)
   sc (minor ? [0 2 3 5 7 8 10] [0 2 4 5 7 9 11])
   ps (minor ? [[0 5 2 6] [0 3 4 0] [0 6 5 4] [0 5 3 4] [5 6 0 4] [0 3 6 2]]
               [[0 5 3 4] [0 3 4 0] [0 4 5 3] [5 3 0 4] [0 2 3 4] [3 4 0 4]])
   pr (ps (int (#ps * die sd 3)))
   (deg i) (sc (i % 7) + 12 * (i // 7))
   (mid m) (55 + ((m - 55) % 12 + 12) % 12)
   N (int (4.0 * chord-s * rate))
   chords (cats (map (c \ (: d (pr c) s (int (c * chord-s * rate))
                            ([[s (bass (hz (key + deg d - 12)) chord-s)]] + map (j \ [s (strings (hz (mid (key + deg (d + j)))) chord-s)]) [0 2 4])))
                     ^4))
   ; ..the horn: each chord's time cut by a rhythm, each note a step or two from the last
   rh [[1.2 1.2] [1.8 0.6] [0.6 0.6 1.2] [2.4] [1.2 0.6 0.6] [0.9 0.3 1.2]]
   line (foldl (\ q c (: d (pr c) r (rh (int (#rh * die sd (10 + c)))) t0 (c * chord-s)
                      (foldl (\ q j (: k (100 + 10 * c + j) on (j = 0 || die sd (k + 5) < 0.5)
                                       ch (map (o \ d + o) [0 2 4 7]) near (foldl (\ a x (abs (x - q 0) < abs (a - q 0) ? x a)) <ch ch)
                                       step (q 0 + int (5.0 * die sd k) - 2) m (max2 (d + 2) (min2 (d + 11) (on ? near step)))
                                       t (t0 + foldl (\ a i (a + r i)) 0.0 ^j)
                                       [m (q 1 + [[(int (t * rate)) (horn (hz (key + 12 + deg m)) (r j - 0.06))]])]))
                             q ^#r)))
               [(pr 0 + 7) ()] ^4)
   buf (foldl (\ b e (lay b (e 0) (e 1))) (iota N * 0.0) (chords + line 1))
   echo [[0.031 0.32] [0.047 0.28] [0.071 0.25] [0.097 0.22] [0.131 0.18] [0.173 0.15] [0.229 0.12] [0.283 0.1] [0.37 0.08] [0.47 0.06]]
   I (iota N) wet (foldl (\ y e (y + e 1 * peep buf ((I - int (e 0 * rate) + N) % N) 0.0)) (buf * 1.0) echo)
   pk (max2 (amax wet) (0.0 - amin wet))
   (wet * (0.9 / max2 1e-6 pk)))
 ; ..where it wears: each slot the time round it first falls silent, a gap more each
 ; time round from the second, short most often, some a good part of a second
 (wear sd L) (: n (int (L * wear-k)) w (iota n * 0.0 + 1e9)
   (foldl (\ w g (: b (1 + int (g + die sd (2000 + g))) s (int (n * die sd (3000 + g)))
                    m (1 + int (wear-k * (0.03 + 0.4 * die sd (4000 + g) * die sd (4000 + g)))) i ((s + iota m) % n)
                    (pin w i (min (peep w i 0.0) (1.0 * b)))))
          w ^gaps))
 (decay-new sd) (: p (phrase sd) L (#p / (1.0 * rate)) {'pcm p 'len L 'wear (wear sd L)})
 ; ..the phrase at t, each sample between its two, silenced where the time round has worn,
 ; eased across a slot at a gap's edges
 (decay-at d t) (: L (d 'len) p (d 'pcm) w (d 'wear) N #p n #w k (floor (t / L)) u (t - k * L)
   s (u * rate) i (floor s) f (s - i) y (peep p (i % N) 0.0 * (1.0 - f) + peep p ((i + 1) % N) 0.0 * f)
   c (u * wear-k) j (floor c) g (c - j) a (peep w (j % n) 0.0 > k) b (peep w ((j + 1) % n) 0.0 > k)
   (y * (a + (b - a) * g)))
)) ; module decay
