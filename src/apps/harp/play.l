#!/usr/bin/env -S love -l
; src/apps/harp/play.l -- harp's voices and verb: a pattern's onsets, a cycle at a time,
; become voices summed into PCM, out the horn or into a .wav.
;
;   love src/apps/harp/play.l [-n CYCLES] [-c CPS] [-r RATE] [-g GAIN] [-o FILE] [-p] PATTERN..
;
;   harp -n 4 'bd sn'                 four cycles out the card
;   harp -o beat.wav 'bd*2 [~ sn]'    the same, into a file, no card needed
;   harp -p 'bd(3,8)'                 print the events, play nothing
;   harp '(jux rev (hit (mini "bd sn hh cp")))'   a parenthesised arg is love
;   HORN=none harp 'bd sn'            the timed sink: right speed, no sound
;
; a voice maps a tray of frame numbers to a tray of amplitudes; a note starting mid-chunk
; is gated by `(t >= 0)`. a module, so harp's names do not shadow the prel at top level.
(module '(play harp-main harp-usage harp-wav harp-horn harp-print harp-read harp-run
         harp-scale harp-chunk mkvoice cyc-voices mixdown pack song-out
         twopi ln2-12 venv vnum vnoise vphase instr vname mkvoice held-ops)
(borrow ((cite 'harp) @ m (m ? m "src/apps/harp/harp.l")))
(borrow 'bytes)
(borrow 'ops)                           ; the voices' operators, run by tones
(:
   ; the fs doors by value: a module layer does not see the posix splice; () where there is none
   open (cite 'posix 'open) close (cite 'posix 'close)
   twopi tau
   ln2-12 0.05776226504666211               ; ln 2 / 12, one semitone
   ; white noise off the frame number, so any chunk renders the same sample
   (vnoise ix)
    (: a (ix * 1103515245 + 12345 & 4294967295)
       b ((a ^ a >> 16) * 2246822507 & 4294967295)
       c ((b ^ b >> 13) * 3266489909 & 4294967295)
       ((c >> 16 & 65535) * 0.000030517578125 - 1.0))
   ; ..smoothed: the noise at every kth frame eased between, so the lower k the brighter; sd
   ; keeps one band's draws apart from another's
   (vsmooth ix k sd) (: a (ix // k) u ((ix - a * k) * (1.0 / k)) e (u * u * (3.0 - 2.0 * u))
                        n0 (vnoise (a + sd))
                        (n0 + (vnoise (a + sd + 1) - n0) * e))

   ; --- the kit. each takes trays (t ix ph): seconds since onset (clamped at 0), absolute
   ;     frames, and the phase in cycles, so a shape never sees a frequency. ---
   ; a kick is one falling sine, its phase the closed-form integral of 46 + 88e^(-34t)
   (i-bd t ix ph) (sin ((t * 46.0 + 2.6 * (1.0 - exp (t * -34.0))) * tau)
                  * exp (t * -8.0))
   (i-sn t ix ph) ((vnoise ix * 0.75 + sin (t * tau * 190.0) * 0.5) * exp (t * -24.0))
   (i-hh t ix ph) (vnoise ix * 0.5 * exp (t * -95.0))
   (i-oh t ix ph) (vnoise ix * 0.4 * exp (t * -13.0))
   ; a clap: a short chatter (a duty cycle on t) then a tail
   (i-cp t ix ph) ((t * 220.0 % 1.0 < 0.45) * (t < 0.028) + (t >= 0.028) @ g
                    (vnoise ix * 0.55 * g * exp (t * -17.0)))
   (i-rim t ix ph) (sin (t * tau * 1650.0) * 0.7 * exp (t * -150.0))
   (i-tom t ix ph) (sin ((t * 96.0 + 1.4 * (1.0 - exp (t * -22.0))) * tau)
                   * exp (t * -11.0))
   ; the pitched four, each with one attack-decay envelope
   (venv t d) ((1.0 - exp (t * -420.0)) * exp (t / d * -2.6))
   (i-sin t ix ph) (sin (ph * tau))
   (i-saw t ix ph) (ph % 1.0 * 2.0 - 1.0)
   (i-sqr t ix ph) ((ph % 1.0 < 0.5) * 2.0 - 1.0)
   (i-tri t ix ph) (: u (ph % 1.0)
                     v (u * 4.0)
                     ((u < 0.5) * (v - 1.0) + (u >= 0.5) * (3.0 - v)))
   ; a music box's tine, an octave up, with two fast-dying partials
   (i-box t ix ph) (ph * tau * 2.0 @ w
                     (sin w + 0.3 * sin (w * 3.0) * exp (t * -6.0) + 0.15 * sin (w * 5.8) * exp (t * -9.0)))
   ; a wind chime's tube, two octaves up: inharmonic partials over a long ring
   (i-chime t ix ph) (ph * tau * 4.0 @ w
                       (sin w + 0.5 * sin (w * 2.76) * exp (t * -2.0) + 0.25 * sin (w * 5.4) * exp (t * -4.0)))
   ; wind: smoothed noise in three bands, low to high, each swelling on slow sines of its own
   ; (seconds tens to a few), and a thin whistle an octave over the note wandering on the gusts
   (i-wind t ix ph) (: g1 (0.5 + 0.5 * sin (t * 0.37 + 0.4)) g2 (0.5 + 0.5 * sin (t * 0.23 + 2.1))
                       g3 (0.5 + 0.5 * sin (t * 1.7 + 4.0) * sin (t * 0.61))
                       (vsmooth ix 32 0 * (0.5 + 0.3 * g1) + vsmooth ix 10 7919 * 0.45 * g2
                        + vsmooth ix 4 104729 * 0.25 * g2 * g3
                        + 0.05 * g1 * g2 * sin (ph * tau * 2.0 + 2.5 * sin (t * 0.9))))
   ; a swell over the whole note, from nothing and back: for what has no attack
   (vswell t d) (sin (t / d * tau * 0.5) @ u (u * u))
   ; name -> [default-duration pitched? shape]; pitched 2 swells over the note instead
   (instr nm) (nm @
    "bd"  [0.55 0 i-bd]   "sn"  [0.35 0 i-sn]   "hh"  [0.09 0 i-hh]
    "oh"  [0.35 0 i-oh]   "cp"  [0.35 0 i-cp]   "rim" [0.06 0 i-rim]
    "tom" [0.45 0 i-tom]  "sin" [0.30 1 i-sin]  "saw" [0.30 1 i-saw] 
    "sqr" [0.30 1 i-sqr]
    "tri" [0.30 1 i-tri]  "box" [1.20 1 i-box]  "chime" [3.0 1 i-chime]
    "wind" [12.0 2 i-wind])

   ; --- an event's value -> a voice ------------------------------------------
   ; the value is a tablet of control words, a string from `hit`, or a bare note number
   (vname v) (? (tablet? v) (peep v 's "sin") (string? v) v "sin")
   ; 'none, not (): 0 is a real gain and note, and `nil? 0` is true
   (vnum v k d) ((? (tablet? v) (peep v k 'none) (charm? v) (k @ 'note v 'none) 'none) @ r
                 (r @ 'none d r))
   ; the phase in cycles at t of a note at f gliding at k nepers/s: the integral of f e^(kt)
   (vphase t f k) (k = 0.0 ? (t * f) (f * (exp (t * k) - 1.0) / k))
   ; --- the kit again as ops.l operators: each pitched timbre its partials [ratio level decay
   ;     wave], each drum its operators; the clap stays the shape above ---
   partials {"sin" [[1.0 1.0 0.0 0]] "saw" [[1.0 1.0 0.0 5]] "sqr" [[1.0 1.0 0.0 6]] "tri" [[1.0 1.0 0.0 4]]
             "box" [[2.0 1.0 0.0 0] [6.0 0.3 6.0 0] [11.6 0.15 9.0 0]]
             "chime" [[4.0 1.0 0.0 0] [11.04 0.5 2.0 0] [21.6 0.25 4.0 0]]}
   kit {"bd" [{'f 46.0 'drop 2.6 'kappa 34.0 'd 8.0}] "sn" [{'wave 7 'lvl 0.75 'd 24.0} {'f 190.0 'lvl 0.5 'd 24.0}]
        "hh" [{'wave 7 'lvl 0.5 'd 95.0}] "oh" [{'wave 7 'lvl 0.4 'd 13.0}] "rim" [{'f 1650.0 'lvl 0.7 'd 150.0}]
        "tom" [{'f 96.0 'drop 1.4 'kappa 22.0 'd 11.0}]}
   ; a held note's operators: venv's rise, half the level held and half dying over d
   (held-ops nm f d) (cats (map (p \ [{'f (f * p 0) 'wave (p 3) 'l (0.5 * p 1) 'segs [[0.0 2 420.0 (p 2 * ops-db) 0.0]]}
                                      {'f (f * p 0) 'wave (p 3) 'l (0.5 * p 1) 'segs [[0.0 2 420.0 ((2.6 / d + p 2) * ops-db) 0.0]]}])
                               (peep partials nm ())))
   ; a voice is [end-frame amp-of-frames left-gain right-gain]
   (mkvoice st v rate)
    (instr (vname v) @ ins
       (!ins ? ()
          (: dur (vnum v 'legato (ins 0))
             nt  (vnum v 'note (vnum v 'n 0))
             f   (261.6255653005986 * exp ((ins 1 ? nt 0) * ln2-12))
             amp (vnum v 'gain 1.0)
             pn  (vnum v 'pan 0.5)
             spd (vnum v 'speed 1.0)
             k   (1.0 * vnum v 'slide 0 * ln2-12 / dur)   ; the slide's rate: its semitones over the note
             sh  (ins 2)
             end (st + int (dur * rate / spd) + 2)
             fn  (ix \ (: t  ((ix - st) * (spd / rate))
                          tp (t * (t > 0.0))
                          e  (ins 1 @ 0 1.0 2 (vswell tp dur) (venv tp dur))
                          (sh tp ix (vphase tp f k) * e * (t >= 0.0) * (t < dur))))
             ; as operators where the kit has them: speed scales every rate
             nm (vname v) pr (peep partials nm ()) dk (peep kit nm ())
             gate [[(dur / spd) 1 0.0 0.0 0.0]]
             os (? (two? pr) (map (p \ {'f (f * p 0 * spd) 'slide (k * spd) 'wave (p 3) 'l (p 1)
                                         'segs ([[0.0 2 (420.0 * spd) ((2.6 / dur + p 2) * spd * ops-db) 0.0]] + gate)}) pr)
                   (two? dk) (map (o \ {'f (peep o 'f 0.0 * spd) 'drop (peep o 'drop 0.0) 'kappa (peep o 'kappa 0.0 * spd)
                                         'wave (peep o 'wave 0) 'l (peep o 'lvl 1.0) 'segs ([[0.0 0 0.0 (o 'd * spd * ops-db) 0.0]] + gate)}) dk)
                   ())
             (two? os ? (ops-voice os st end (amp * (1.0 - pn)) (amp * pn) rate) [end fn (amp * (1.0 - pn)) (amp * pn)]))))

   ; --- mixing and packing ---------------------------------------------------
   ; every live voice is evaluated over the whole chunk and summed; a hard-panned voice
   ; skips its far side.
   (mixdown vs base n)
    (: ix (iota n + base)
       z  (ix * 0.0)
       (side acc y g) (g = 0.0 ? acc (acc + y * g))
       (go l L R) (l @- (L . R)
                   ([_ f yl yr] . u) (f ix @ y            ; the wave, once: it is a C pass
                                        (go u (side L y yl) (side R y yr))))
       (go vs z z))
   ; one voice at full scale reaches 0.6 of the range; -g moves the mix under that ceiling
   harp-scale 20000.0
   (clip g x) (int (x * g) @ v (? (v > 32767) 32767 (v < -32768) -32768 (v & 65535)))
   ; the same saturation over a tray, left for pinv to truncate toward zero as `int` does
   (clipv g t) (min 32767.0 (max -32768.0 (t * g)))
   ; two float trays out as interleaved 16-bit le frames. pinv lays a channel per call (stride the
   ; frame, width the sample); the byte loop is the fallback, and test/law/harp.l checks one against the other.
   (pack lr n g)
    (: L <lr  R >lr  c (cask (n * 4))
       lay (cite 'guts 'pinv)
       whole (lay && tray? L && tray? R && #L = n && #R = n)
       (go _) (each ^n (i \ (: l (clip g (peep L i 0))  r (clip g (peep R i 0))  o (i * 4)
                               (pins c o      (l & 255) (o + 1) (l >> 8 & 255)
                                       (o + 2) (r & 255) (o + 3) (r >> 8 & 255)))),
               c)
       (whole ? (lay c 0 2 4 (clipv g L),
                 lay c 2 2 4 (clipv g R),
                 string c)
          (string (go 0))))
   ; a song's next n frames out its port 'h at gain g; finished voices dropped, 'fpos moved on
   (song-out s n g) (: base (s 'fpos)
                       live (filter (p \ p 1 0 >= base) (s 'vs))
                       now (filter (p \ p 0 < base + n) live)
                       (pins s 'vs live 'fpos (base + n),
                        say (s 'h) (pack (mixdown (map (p \ p 1) now) base n) n g)))

   ; --- the run: cycles in, chunks out ---------------------------------------
   harp-chunk 2048
   ; a cycle's onsets as voices with their start frames. the one crossing from `///` cycle time
   ; to integer frames is qnum: nothing downstream of here holds a rational.
   (cyc-voices p c c0 spc rate)
    (filter two?
            (map (x \ mkvoice ((c - c0) * spc + int (spc * qnum (evwb x - qi c)))
                              (evv x) rate)
                 (filter onset? (p (qi c) (qi (c + 1))))))
   ; the write head walks the run in chunks; a cycle's voices join just before the chunk that
   ; hears them and drop once behind the head.
   (harp-run p c0 ncyc rate cps tail g emit)
    (: spc   (int (rate / cps))
       total (ncyc * spc + tail)
       (fill c vs lim) ((c - c0) * spc >= lim || c >= c0 + ncyc ? (c . vs)
                          (fill (c + 1) (vs + cyc-voices p c c0 spc rate) lim))
       (go base vs c)
        (base >= total ? 1
         (: lim (base + harp-chunk < total ? (base + harp-chunk) total)
            r   (fill c vs lim)
            live (filter (v \ v 0 >= base) >r)
            (emit (pack (mixdown live base (lim - base)) (lim - base) g),
             go lim live <r)))
       (go 0 () c0))

   ; --- the two sinks --------------------------------------------------------
   (wav-head rate n)                      ; 44 bytes of canonical PCM riff
    (n * 4 @ d
       ("RIFF" + wrle (36 + d) 4 + "WAVEfmt " + wrle 16 4 + wrle 1 2 + wrle 2 2
        + wrle rate 4 + wrle (rate * 4) 4 + wrle 4 2 + wrle 16 2 + "data" + wrle d 4))
   (harp-wav p c0 ncyc rate cps tail g path)
    (open path "w" @ q
       (? !(hot? q) (say err $ "harp: cannot write " + path + "\n", 0)
          (say q $ wav-head rate (ncyc * int (rate / cps) + tail),
           harp-run p c0 ncyc rate cps tail g (say q),
           close q,
           1)))
   (harp-horn p c0 ncyc rate cps tail g)
    (horn rate 2 @ h
     (nom? h ? (say err $ "harp: no horn -- " + show h + "\n", 0)
      (harp-run p c0 ncyc rate cps tail g (say h),
       flush h,
       close h,
        1)))

   ; --- printing, for eyes rather than ears ----------------------------------
   (qshow t) (qparts t @ p (1 = <>p ? (show <p) (show <p + "/" + show <>p)))
   (harp-print p c0 ncyc)
    (each ^ncyc
     (i \ c0 + i @ c
      (say out "cycle \(c)\n",
       each (p (qi c) (qi (c + 1)))
       (x \ say out "  \(qshow (evwb x)) .. \(qshow (evwe x))\(onset? x ? "" "  (tail)")  \(evv x)\n"))))

   ; --- the verb -------------------------------------------------------------
   harp-usage "usage: harp [-n N] [-c CPS] [-r RATE] [-g GAIN] [-o F.wav] [-p] [-s SCORE] PATTERN..
       harp --check SCORE"
   ; a bare argument is mini-notation for `hit`; one opening a paren is love, read after
   ; harp is spliced into the global scope (once, before reading, since names fold at compile).
   ; leading blanks and comment lines are skipped. -s is a score file. several arguments stack.
   (harp-lead a) (:- (go 0) n #a
                  (go i) (? (i >= n) i
                            (32 >= a i) (go (i + 1))
                            (59 = a i) (: (eol j) (j < n && 10 != a j ? (eol (j + 1)) j) (go (eol i)))
                            i))
   spliced {}
   (harp-splice _) (peep spliced 0 0 ? ()
                      (pin spliced 0 1, ev <(sound "(borrow 'harp)")))
   (harp-read a) (harp-lead a @ i
                    (i < #a && 40 = a i ? (harp-splice (), sound a @ (f . _) (ev f) hush)
                                          (hit (mini a))))
   (harp-atoi s) (foldl (\ acc i (acc * 10 + (s i - 48))) 0 ^#s)
   (harp-atof s) (sound s @ (r . _) r 0)
   (harp-main as)
    (: (go l o ps)
        (atom? l ? (harp-fire o (lrev ps))
         (<l @ "-n" (go >>l (pin o 'cycles (harp-atoi <>l)) ps)
               "-r" (go >>l (pin o 'rate (harp-atoi <>l)) ps)
               "-c" (go >>l (pin o 'cps (harp-atof <>l)) ps)
               "-f" (go >>l (pin o 'from (harp-atoi <>l)) ps)
               "-o" (go >>l (pin o 'wav <>l) ps)
               "-g" (go >>l (pin o 'gain (harp-atof <>l)) ps)
               "-p" (go >l (pin o 'print 1) ps)
               "-s" (go >>l (pin o 'scores (<>l . peep o 'scores ())) ps)
               "--check" ((cite 'score 'score-file <>l) @ ls
                            (ls ? (cite 'score 'score-check ls 1)
                               (say err ("harp: cannot read " + <>l + "\n"), 1)))
               ("-h" || "--help") (puts (harp-usage + "\n"), flush out, 0)
               ("-v" || "--version")
                (puts (uvers "harp" + "\n"), flush out, 0)
               a (go >l o (a . ps))))
       (go as {'rate 48000 'cps 0.5 'from 0 'print 0 'gain 1.0} ()))
   (harp-fire o ps)
    (: sc   (cite 'score)
       ; a score's bars, every file's; a bad bar has been named and stops the run
       bars (foldl (acc \ f \ (sc 'score-file f @ ls
                                (? (acc = 'bad) 'bad
                                   !ls (say err ("harp: cannot read " + f + "\n"), 'bad)
                                   (sc 'score-check ls 0) 'bad
                                   (acc + filter (b \ !(b 'err)) (sc 'score-parse ls)))))
                   () (o 'scores))
       cps  (o 'cps)
       ps2  (bars @ 'bad () (ps + (two? bars ? [(sc 'score-tune bars cps)] ())))
       p    (? !(two? ps2) hush
               (1 = #ps2) (<ps2 @ x (string? x ? (harp-read x) x))
               (stack (map (x \ (string? x ? (harp-read x) x)) ps2)))
       rate (o 'rate)  c0 (o 'from)
       ncyc (peep o 'cycles (two? bars ? #bars 4))
       tail (int (rate / 2))                       ; half a second for the last decay
       g    (harp-scale * o 'gain)
       (? (bars = 'bad) 1
          !(two? ps2) (say err (harp-usage + "\n"), 1)
          (o 'print) (harp-print p c0 ncyc, 0)
          (o 'wav) (harp-wav p c0 ncyc rate cps tail g (o 'wav), 0)
          (harp-horn p c0 ncyc rate cps tail g, 0)))
   ; ..and as a verb of the artifact: `love harp`
   _ (pins (cite 'verbs 'tab) 'harp (udoor 'harp harp-main harp-usage 0 0)))
) ; module play

; fire only when this file is the program on the real command line.
(: s (cite 'verbs 'fire ["harp" "play.l"])
   (two? s ? (quit (cite 'play 'harp-main >s))))
