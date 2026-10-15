; opl -- two-operator FM instruments, as doom's GENMIDI bank lays them, played as harp's voices.
; written from the YM3812 (OPL2) application manual's register meanings and the doom wiki's
; GENMIDI layout; every sample a closed form of time, so a voice is play's [end fn left right],
; fn over a tray of frame numbers, and one chunk is a handful of tray passes.
;   (opl-bank b)     the 175 instruments of an op2 file's bytes ("#OPL_II#") or of a wad's
;                    GENMIDI lump, or () where b holds neither
;   (opl-voice ins n vel pan at off rate)  instrument ins sounding midi note n (a float bends),
;                    velocity 0..127, pan 0..1, from frame at; let go at frame off, () while held
;   (opl-drum bank n)  the percussion instrument for midi note n, 35..81, or ()
;   an instrument: {'name 'fixed 'note 'tune 'two 'vs}; 'vs one or two voices {'m 'c 'fb 'conn 'off},
;   'm and 'c operators {'am 'vib 'egt 'ksr 'mul 'ar 'dr 'sl 'rr 'wave 'ksl 'tl}
(module (opl opl-bank opl-voice opl-drum opl-freq)
(borrow 'bytes)                         ; rdle
(:
 (max2 a b) (a < b ? b a)
 (min2 a b) (a < b ? a b)
 ; --- the bank: a header of 8, 175 instruments of 36 bytes, then their names, 32 each ---
 (op b o) (: r (b o) {'am (r >> 7 & 1) 'vib (r >> 6 & 1) 'egt (r >> 5 & 1) 'ksr (r >> 4 & 1) 'mul (r & 15)
                      'ar (b (o + 1) >> 4) 'dr (b (o + 1) & 15) 'sl (b (o + 2) >> 4) 'rr (b (o + 2) & 15)
                      'wave (b (o + 3) & 3) 'ksl (b (o + 4) @ k (k > 3 ? (k >> 6) k)) 'tl (b (o + 5) & 63)})
 (voice b o) {'m (op b o) 'fb (b (o + 6) >> 1 & 7) 'conn (b (o + 6) & 1) 'c (op b (o + 7))
              'off (rdle b (o + 14) 2 @ v (v < 32768 ? v (v - 65536)))}
 (cname b o) (: (go k) (k < 32 && b (o + k) != 0 ? (go (k + 1)) k) (snip b o (o + go 0)))
 (ins b i) (: o (8 + 36 * i) fl (rdle b o 2)
   {'name (cname b (8 + 36 * 175 + 32 * i)) 'fixed (fl & 1) 'two (fl >> 2 & 1) 'tune (b (o + 2)) 'note (b (o + 3))
    'vs ((fl >> 2 & 1) ? [(voice b (o + 4)) (voice b (o + 20))] [(voice b (o + 4))])})
 ; ..an op2's bytes, or a wad's GENMIDI found by its directory
 (genmidi b) (? (snip b 0 8 = "#OPL_II#") b
                (elem (snip b 0 4) ["IWAD" "PWAD"])
                (: n (rdle b 4 4) d (rdle b 8 4)
                   (go i) (? (i >= n) ()
                             (: e (d + 16 * i) (snip b (e + 8) (e + 15) = "GENMIDI" ? (snip b (rdle b e 4) (rdle b e 4 + rdle b (e + 4) 4)) (go (i + 1)))))
                   (go 0))
                ())
 (opl-bank b) (: g (string? b && #b > 12 ? (genmidi b) ())
   (string? g && #g >= 8 + 68 * 175 ? (map (i \ ins g i) ^175) ()))
 (opl-drum bank n) (35 <= n && n <= 81 ? (bank (128 + n - 35)) ())

 ; --- an operator's level: the envelope in dB of attenuation, 0 loud, 96 gone ---
 ; ..the manual's times at rate 1: attack 2826 ms, a decay or release over 96 dB 39281 ms; each
 ;   rate halves them, and key scaling lifts the rate by the note's octave, a quarter as much
 ;   with ksr off. rate 0 never moves; an attack at 15 is at once
 ln2 0.6931471805599453
 (dbl r) (exp ((r - 1.0) * ln2))
 (times o n) (: oct (max2 0 (min2 7 (int n // 12 - 1))) kso (min2 15 (2 * oct + (int n % 12 >= 6 ? 1 0)))
   ks (o 'ksr ? (kso / 4.0) (kso / 16.0)) (eff r) (min2 15.0 (r + ks))
   {'ta (o 'ar = 0 ? 1e6 (eff (o 'ar) >= 15.0 ? 0.0 (2.82624 / dbl (eff (o 'ar)))))
    'dd (o 'dr = 0 ? 1e-6 (96.0 / (39.28064 / dbl (eff (o 'dr)))))
    'rd (o 'rr = 0 ? 1e-6 (96.0 / (39.28064 / dbl (eff (o 'rr)))))
    'sl (o 'sl = 15 ? 93.0 (3.0 * o 'sl)) 'egt (o 'egt)})
 ; ..held: the attack up as an amplitude, the decay down to the sustain level, held there, or on
 ;   down at the release rate where the patch does not sustain; t a number or a tray
 (held E t) (: a (E 'ta) s (E 'sl) dd (E 'dd)
   up (log (max (t / max2 a 1e-9) 1e-5) * -8.685889638065035)
   d ((t - a) * dd) on (s + (t - a - s / dd) * E 'rd)
   ((t < a) * up + (t >= a) * ((d < s) * d + (d >= s) * (E 'egt = 1 ? s on))))
 ; ..and let go at off seconds: from where it stood, down at the release rate
 (env E t off) (: h (held E off) ((t <= off) * held E t + (t > off) * (h + (t - off) * E 'rd)))
 ; ..key scaling of level: 3, 1.5 or 6 dB an octave over c3; tremolo 1 dB at 3.7 Hz
 ksl-db [0.0 3.0 1.5 6.0]
 (amp o E n t off vdb) (: k (ksl-db (o 'ksl) * max2 0.0 ((n - 48.0) / 12.0))
   am (o 'am ? (0.5 - 0.5 * cos (t * 23.247785636564613)) 0.0)
   db (max (env E t off) 0.0 + (o 'tl * 0.75 + k + vdb) + am)
   ((db < 95.9) * exp (db * -0.11512925464970229)))

 ; --- the sound: a wave of the phase in cycles, one of the chip's four ---
 (wave x k) (: s (sin (x * 6.283185307179586))
   (k @ 0 s 1 (s * (s > 0.0)) 2 (s * ((s > 0.0) * 2.0 - 1.0))
        _ (s * ((s > 0.0) * 2.0 - 1.0) * ((x - floor x) % 0.5 < 0.25))))
 (opl-freq n) (440.0 * exp ((n - 69.0) * ln2 / 12.0))
 mults [0.5 1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0 10.0 12.0 12.0 15.0 15.0]
 ; ..vibrato 7 cents at 6.1 Hz, as the phase it adds; feedback's depth by its three bits, from
 ;   none to 4 pi, in cycles; the modulator's whole output moves the carrier 2 cycles
 (phase o f t) (: g (f * mults (o 'mul))
   (g * t + (o 'vib ? (g * 0.00405 / 38.33 * (1.0 - cos (t * 38.32743037961115))) 0.0)))
 fbs [0.0 0.03125 0.0625 0.125 0.25 0.5 1.0 2.0]
 fm-depth 2.0
 ; ..one voice of an instrument at note n: the modulator fed back on itself, settled by a few
 ;   passes, into the carrier's phase, or beside it where the two are added
 (part V n vdb t off Em Ec) (: m (V 'm) c (V 'c) f (opl-freq n)
   Am (amp m Em n t off (V 'conn = 1 ? vdb 0.0)) Ac (amp c Ec n t off vdb)
   pm (phase m f t) pc (phase c f t) b (fbs (V 'fb))
   (fed y k) (k = 0 || b = 0.0 ? y (fed (Am * wave (pm + b * y) (m 'wave)) (k - 1)))
   y (fed (Am * wave pm (m 'wave)) 3)
   (V 'conn = 1 ? (y + Ac * wave pc (c 'wave)) (Ac * wave (pc + fm-depth * y) (c 'wave))))

 ; --- a voice: each of the instrument's one or two, its note moved by the voice's offset, the
 ;     second detuned by the tune byte (128 none, 64 a semitone); its end once let go is when
 ;     what is heard has fallen 96 dB, at most 10 s on ---
 (opl-voice I n vel pan at off rate) (: nb (I 'fixed = 1 ? (1.0 * I 'note) (1.0 * n))
   vdb (vel <= 0 ? 200.0 (log (vel / 127.0) * -17.37177927613007))
   ps (map (k \ (: V (I 'vs k) nk (nb + V 'off + (k = 1 ? ((I 'tune - 128) / 64.0) 0.0))
                  [V nk (times (V 'm) nk) (times (V 'c) nk)]))
           ^#(I 'vs))
   to (off = () ? 1e9 ((off - at) * 1.0 / rate))
   (tail p) (: E (p 3) ((96.0 - held E to) / E 'rd))
   end (off = () ? (at + 3600 * rate) (off + int (rate * min2 10.0 (foldl max2 0.0 (map tail ps))) + 2))
   fn (ix \ (: t ((ix - at) * (1.0 / rate)) tp (t * (t > 0.0))
              (foldl (\ acc p (acc + part (p 0) (p 1) vdb tp to (p 2) (p 3))) (tp * 0.0) ps * (t >= 0.0))))
   [end fn (1.0 - pan) pan])
)) ; module opl
