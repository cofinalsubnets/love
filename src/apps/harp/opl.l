; opl -- two-operator FM instruments, as doom's GENMIDI bank lays them, played as harp's voices.
; from the YM3812 (OPL2) manual's register meanings and the doom wiki's GENMIDI layout.
;   (opl-bank b)     the 175 instruments of an op2 file ("#OPL_II#") or a wad's GENMIDI, or ()
;   (opl-voice ins n vel pan at off rate)  midi note n (a float bends), velocity 0..127, pan
;                    0..1, from frame at; let go at frame off, () while held
;   (opl-ops ins n vel pan at off rate)  that voice's operators for tones, and its end: [os end]
;   (opl-drum bank n)  the percussion instrument for midi note n, 35..81, or ()
; an instrument: {'name 'fixed 'note 'tune 'two 'vs}; 'vs one or two voices {'m 'c 'fb 'conn 'off}
(module (opl opl-bank opl-voice opl-ops opl-drum opl-freq)
(borrow 'bytes)
(borrow 'ops)
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
 ; an op2's bytes, or a wad's GENMIDI found by its directory
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
 ; the manual's times at rate 1: attack 2826 ms, 96 dB of decay or release 39281 ms; each rate
 ; halves them, key scaling lifts the rate by octave (a quarter as much with ksr off). rate 0
 ; never moves; an attack at 15 is at once
 ln2 0.6931471805599453
 (dbl r) (exp ((r - 1.0) * ln2))
 (times o n) (: oct (max2 0 (min2 7 (int n // 12 - 1))) kso (min2 15 (2 * oct + (int n % 12 >= 6 ? 1 0)))
   ks (o 'ksr ? (kso / 4.0) (kso / 16.0)) (eff r) (min2 15.0 (r + ks))
   {'ta (o 'ar = 0 ? 1e6 (eff (o 'ar) >= 15.0 ? 0.0 (2.82624 / dbl (eff (o 'ar)))))
    'dd (o 'dr = 0 ? 1e-6 (96.0 / (39.28064 / dbl (eff (o 'dr)))))
    'rd (o 'rr = 0 ? 1e-6 (96.0 / (39.28064 / dbl (eff (o 'rr)))))
    'sl (o 'sl = 15 ? 93.0 (3.0 * o 'sl)) 'egt (o 'egt)})
 ; the attack up as an amplitude, decay to sustain, held or on down at the release rate; t a
 ; number or a tray
 (held E t) (: a (E 'ta) s (E 'sl) dd (E 'dd)
   up (log (max (t / max2 a 1e-9) 1e-5) * -8.685889638065035)
   d ((t - a) * dd) on (s + (t - a - s / dd) * E 'rd)
   ((t < a) * up + (t >= a) * ((d < s) * d + (d >= s) * (E 'egt = 1 ? s on))))
 ; ..key scaling of level: 3, 1.5 or 6 dB an octave over c3
 ksl-db [0.0 3.0 1.5 6.0]
 (opl-freq n) (440.0 * exp ((n - 69.0) * ln2 / 12.0))
 mults [0.5 1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0 10.0 12.0 12.0 15.0 15.0]
 ; feedback's depth by its three bits, in cycles of the mean of the last two outputs; the
 ; modulator's whole output moves the carrier 2 cycles
 fbs [0.0 0.03125 0.0625 0.125 0.25 0.5 1.0 2.0]
 fm-depth 2.0
 ; the envelope as tones' segments, let go at to seconds (past 1e8 held), down from where it stood
 (segs E to) (: a (E 'ta) s (E 'sl) dd (E 'dd) t1 (a + s / dd)
   hs ((a > 0.0 ? [[0.0 1 0.0 (1.0 / a) 0.0]] ()) + [[a 0 0.0 dd 0.0] [t1 0 s (E 'egt = 1 ? 0.0 (E 'rd)) 0.0]])
   (to >= 1e8 ? hs (filter (q \ q 0 < to) hs + [[to 0 (held E to) (E 'rd) 0.0]])))

 ; --- a voice per instrument voice, the second detuned by the tune byte (128 none, 64 a
 ;     semitone); its end is when it has fallen 96 dB, at most 10 s after let go ---
 (opl-ops I n vel pan at off rate) (: nb (I 'fixed = 1 ? (1.0 * I 'note) (1.0 * n))
   vdb (vel <= 0 ? 200.0 (log (vel / 127.0) * -17.37177927613007))
   to (off = () ? 1e9 ((off - at) * 1.0 / rate))
   (pair j) (: V (I 'vs j) nk (nb + V 'off + (j = 1 ? ((I 'tune - 128) / 64.0) 0.0)) f (opl-freq nk) add (V 'conn = 1)
     (one o v) (: E (times o nk) k (ksl-db (o 'ksl) * max2 0.0 ((nk - 48.0) / 12.0))
                 {'f (f * mults (o 'mul)) 'wave (o 'wave) 'lvl (o 'tl * 0.75 + k + v @ d (d >= 96.0 ? 0.0 (exp (d * -0.11512925464970229))))
                  'segs (segs E to) 'vib (o 'vib ? 0.00405 0.0) 'vrate 6.1 'trem (o 'am ? 1.0 0.0) 'trate 3.7 'E E})
     [(pins (one (V 'm) (add ? vdb 0.0)) 'fb (fbs (V 'fb)) 'l (add ? 1.0 0.0))
      (pins (one (V 'c) vdb) 'mod (add ? -1 (2 * j)) 'depth fm-depth 'l 1.0)])
   os (cats (map pair ^#(I 'vs)))
   (tail o) (: E (o 'E) ((96.0 - held E to) / E 'rd))
   end (off = () ? (at + 3600 * rate) (off + int (rate * min2 10.0 (foldl max2 0.0 (map tail os))) + 2))
   [os end])
 (opl-voice I n vel pan at off rate) (opl-ops I n vel pan at off rate @ [os end] (ops-voice os at end (1.0 - pan) pan rate))
)) ; module opl
