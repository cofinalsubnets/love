#!/usr/bin/env -S love -l
; apps/harp/play.l -- harp's voices and its verb: a pattern (apps/harp/harp.l) is
; asked for one cycle at a time, its onsets become voices, and the voices are summed
; into PCM that goes out the horn (love/horn.c) or into a .wav.
;
;   love apps/harp/play.l [-n CYCLES] [-c CPS] [-r RATE] [-g GAIN] [-o FILE] [-p] PATTERN..
;
;   harp -n 4 'bd sn'                 four cycles out the card
;   harp -o beat.wav 'bd*2 [~ sn]'    the same, into a file, no card needed
;   harp -p 'bd(3,8)'                 print the events, play nothing
;   harp '(jux rev (hit (mini "bd sn hh cp")))'   a parenthesised arg is love
;   HORN=none harp 'bd sn'            the timed sink: right speed, no sound
;
; A VOICE IS A FUNCTION FROM A TRAY OF FRAME NUMBERS TO A TRAY OF AMPLITUDES, and
; that is the whole synthesis engine. love's trays are vectorised in C -- sin, exp,
; %, the comparisons and the bit ops all run elementwise -- so an oscillator is one
; expression over `iota`, with no per-sample love loop anywhere. it also means a
; voice needs no state and no slicing: a note that starts mid-chunk is gated by
; `(t >= 0)`, which is a tray, so the same closure is correct in every chunk it
; touches and is simply dropped once its end frame is behind the write head.
; the module where it is already registered (a baked artifact, or a cat'd corpus),
; and this tree's file where it is not -- so the verb runs from either.
; the voice layer is a MODULE: this file rides the crew roster, and a roster file
; is catted into the global scope -- so a splice at its top level (harp's rev and
; every, here) would shadow the prel for everything compiled after it. a module
; enters its own layer, and the borrow below is confined to it.
(module '(play harp-main harp-usage harp-wav harp-horn harp-print harp-read harp-run
         harp-scale harp-chunk mkvoice cyc-voices mixdown pack song-out
         twopi ln2-12 venv vnum vnoise vphase instr vname mkvoice)
(borrow (: m (cite 'harp) (? m m "apps/harp/harp.l")))
(borrow 'bytes)
(:
   ; the fs doors by VALUE, off their module: a module layer does not see the
   ; session's posix splice, and a seat carrying none (inle/wasm) holds () here --
   ; which only the two paths that want a file ever ask for.
   open (cite 'posix 'open) close (cite 'posix 'close)
   twopi tau
   ln2-12 0.05776226504666211               ; ln 2 / 12, one semitone
   ; white noise off the frame number: the same frame always draws the same sample,
   ; so a re-render is identical and a voice may be evaluated in any chunk.
   (vnoise ix)
    (: a ((ix * 1103515245 + 12345) & 4294967295)
       b (((a ^ (a >> 16)) * 2246822507) & 4294967295)
       c (((b ^ (b >> 13)) * 3266489909) & 4294967295)
       ((((c >> 16) & 65535) * 0.000030517578125) - 1.0))

   ; --- the kit. each takes (t ix ph): seconds since the onset (clamped at 0), the
   ;     absolute frame numbers, and the note's phase in cycles -- t times the
   ;     frequency for a held note, the integral of a moving one for a slide, so a
   ;     shape never sees a frequency and every pitched one glides. all three are
   ;     trays. ---
   ; a kick is one falling sine: the phase is the integral of 46 + 88e^(-34t), in
   ; closed form, because a per-sample oscillator would need state and this does not.
   (i-bd t ix ph) (sin ((t * 46.0 + 2.6 * (1.0 - exp (t * -34.0))) * tau)
                  * exp (t * -8.0))
   (i-sn t ix ph) ((vnoise ix * 0.75 + sin (t * tau * 190.0) * 0.5) * exp (t * -24.0))
   (i-hh t ix ph) (vnoise ix * 0.5 * exp (t * -95.0))
   (i-oh t ix ph) (vnoise ix * 0.4 * exp (t * -13.0))
   ; a clap is a short chatter then a tail: the chatter is a duty cycle on t, so it
   ; is still one expression
   (i-cp t ix ph) (: g (((t * 220.0 % 1.0 < 0.45) * (t < 0.028)) + (t >= 0.028))
                    (vnoise ix * 0.55 * g * (exp (t * -17.0))))
   (i-rim t ix ph) (sin (t * tau * 1650.0) * 0.7 * exp (t * -150.0))
   (i-tom t ix ph) (sin ((t * 96.0 + (1.4 * (1.0 - (exp (t * -22.0))))) * tau)
                   * exp (t * -11.0))
   ; the pitched four, each with one attack-decay envelope
   (venv t d) ((1.0 - exp (t * -420.0)) * exp (t / d * -2.6))
   (i-sin t ix ph) (sin (ph * tau))
   (i-saw t ix ph) (((ph % 1.0) * 2.0) - 1.0)
   (i-sqr t ix ph) (((ph % 1.0 < 0.5) * 2.0) - 1.0)
   (i-tri t ix ph) (: u (ph % 1.0)
                     v (u * 4.0)
                     ((u < 0.5) * (v - 1.0) + (u >= 0.5) * (3.0 - v)))
   ; a music box's tine, an octave up: the note, a partial an octave and a fifth over
   ; it that dies fast, a bright one that dies faster
   (i-box t ix ph) (: w (ph * tau * 2.0)
                     (sin w + 0.3 * sin (w * 3.0) * exp (t * -6.0) + 0.15 * sin (w * 5.8) * exp (t * -9.0)))
   ; a wind chime's tube, two octaves up: inharmonic partials over a long ring
   (i-chime t ix ph) (: w (ph * tau * 4.0)
                       (sin w + 0.5 * sin (w * 2.76) * exp (t * -2.0) + 0.25 * sin (w * 5.4) * exp (t * -4.0)))
   ; name -> [default-duration pitched? shape]
   (instr nm) (nm @
    "bd"  [0.55 0 i-bd]   "sn"  [0.35 0 i-sn]   "hh"  [0.09 0 i-hh]
    "oh"  [0.35 0 i-oh]   "cp"  [0.35 0 i-cp]   "rim" [0.06 0 i-rim]
    "tom" [0.45 0 i-tom]  "sin" [0.30 1 i-sin]  "saw" [0.30 1 i-saw] 
    "sqr" [0.30 1 i-sqr]
    "tri" [0.30 1 i-tri]  "box" [1.20 1 i-box]  "chime" [3.0 1 i-chime])

   ; --- an event's value -> a voice ------------------------------------------
   ; the value is a tablet from the control words, a bare string from `hit`, or a
   ; bare number from a note pattern with nothing wrapped round it.
   (vname v) (? (tablet? v) (peep v 's "sin") (string? v) v "sin")
   ; peep's default cannot be (): 0 is a real gain and a real note, and `nil? 0` is
   ; true here, so a missing key is asked for by a symbol nothing else can be.
   (vnum v k d) (: r (? (tablet? v) (peep v k 'none) (charm? v) (k @ 'note v 'none) 'none)
                 (r @ 'none d r))
   ; the phase in cycles at t of a note at f gliding at k nepers a second: the
   ; integral of f e^(kt), and f t when it holds. k is what a slide comes to
   (vphase t f k) (k = 0.0 ? (t * f) (f * (exp (t * k) - 1.0) / k))
   ; a voice is [end-frame amp-of-frames left-gain right-gain]
   (mkvoice st v rate)
    (: ins (instr (vname v))
       (? !ins ()
          (: dur (vnum v 'legato (ins 0))
             nt  (vnum v 'note (vnum v 'n 0))
             f   (261.6255653005986 * exp ((ins 1 ? nt 0) * ln2-12))
             amp (vnum v 'gain 1.0)
             pn  (vnum v 'pan 0.5)
             spd (vnum v 'speed 1.0)
             k   (1.0 * vnum v 'slide 0 * ln2-12 / dur)   ; the slide's rate: its semitones over the note
             sh  (ins 2)
             end (st + int (dur * rate / spd) + 2)
             fn  (\ ix (: t  ((ix - st) * (spd / rate))
                          tp (t * (t > 0.0))
                          e  (? (ins 1) (venv tp dur) 1.0)
                          (sh tp ix (vphase tp f k) * e * (t >= 0.0) * (t < dur))))
             [end fn (amp * (1.0 - pn)) (amp * pn)])))

   ; --- mixing and packing ---------------------------------------------------
   ; every live voice is evaluated over the whole chunk and summed. the cost is one
   ; pass per voice per chunk in C, so a busy cycle is a handful of tray ops.
   ; ..and a voice panned hard adds nothing to its far side, so that side is left as it is
   (mixdown vs base n)
    (: ix (iota n + base)
       z  (ix * 0.0)
       (side acc y g) (g = 0.0 ? acc (acc + (y * g)))
       (go l L R) (l @- (L . R)
                   ([_ f yl yr] . u) (: y (f ix)          ; the wave, once: it is a C pass
                                        (go u (side L y yl) (side R y yr))))
       (go vs z z))
   ; one voice at full scale reaches 0.6 of the range, so a handful may stack before
   ; the saturation bites. -g moves the whole mix under that ceiling.
   harp-scale 20000.0
   (clip g x) (int (x * g) @ v (? (v > 32767) 32767 (v < -32768) -32768 (v & 65535)))
   ; ..and the same saturation over a whole tray, as arithmetic: `// 1` truncates toward
   ; zero exactly where `int` does, and the two comparisons are masks.
   (clipv g t) (: v (t * g // 1)
                  hi (v > 32767)  lo (v < -32768)
                  (v * (1 - hi) * (1 - lo) + hi * 32767 + lo * -32768))
   ; two trays of floats out as interleaved 16-bit little-endian frames, which is what
   ; the horn's write path wants. guts' pinv lays a whole channel in one call: its stride
   ; is the frame and its width the sample, so THE INTERLEAVE IS THE CALL. the byte loop
   ; below is the same answer a dispatch at a time -- it is what a seat with no host glob
   ; runs, and what the fast path is read against (test/law/harp.l asks them of each other).
   (pack lr n g)
    (: L <lr  R >lr  c (cask (n * 4))
       lay (cite 'guts 'pinv)
       whole (lay && tray? L && tray? R && #L = n && #R = n)
       (go i) (? (i >= n) c
                 (: l (clip g (peep L i 0))  r (clip g (peep R i 0))  o (i * 4)
                    _ (pins c o      (l & 255) (o + 1) ((l >> 8) & 255)
                             (o + 2) (r & 255) (o + 3) ((r >> 8) & 255))
                    (go (i + 1))))
       (? whole (lay c 0 2 4 (clipv g L),
                 lay c 2 2 4 (clipv g R),
                 string c)
          (string (go 0))))
   ; a song's next n frames out its port 'h at gain g: its voices 'vs, [start voice] each,
   ; let go once finished and summed once begun, and its frames written 'fpos moved on
   (song-out s n g) (: base (s 'fpos)
                       live (filter (p \ p 1 0 >= base) (s 'vs))
                       now (filter (p \ p 0 < base + n) live)
                       _ (pins s 'vs live 'fpos (base + n))
                       (say (s 'h) (pack (mixdown (map (p \ p 1) now) base n) n g)))

   ; --- the run: cycles in, chunks out ---------------------------------------
   harp-chunk 2048
   ; a cycle's onsets, as voices, with the start frame each one lands on.
   ; THIS IS THE BOUNDARY. cycle time is a `///` rational and frame time is an
   ; integer, and qnum is the one crossing: a rational that reached the tray lane
   ; would answer () rather than promoting it, and the voice would go silent with
   ; nothing said. nothing downstream of here holds a rational.
   (cyc-voices p c c0 spc rate)
    (filter two?
            (map (x \ mkvoice ((c - c0) * spc + int (spc * qnum (evwb x - qi c)))
                              (evv x) rate)
                 (filter onset? (p (qi c) (qi (c + 1))))))
   ; the write head walks the whole run in chunks. voices are pulled in a cycle at a
   ; time, just before the chunk that can hear them, and dropped when their end frame
   ; is behind the head -- so the live list is only ever what is actually sounding.
   (harp-run p c0 ncyc rate cps tail g emit)
    (: spc   (int (rate / cps))
       total (ncyc * spc + tail)
       (fill c vs lim) (? ((c - c0) * spc >= lim || c >= c0 + ncyc) (c . vs)
                          (fill (c + 1) (vs + cyc-voices p c c0 spc rate) lim))
       (go base vs c)
        (base >= total ? 1
         (: lim (base + harp-chunk < total ? (base + harp-chunk) total)
            r   (fill c vs lim)
            live (filter (v \ v 0 >= base) >r)
            _   (emit (pack (mixdown live base (lim - base)) (lim - base) g))
            (go lim live <r)))
       (go 0 () c0))

   ; --- the two sinks --------------------------------------------------------
   (wav-head rate n)                      ; 44 bytes of canonical PCM riff
    (: d (n * 4)
       ("RIFF" + wrle (36 + d) 4 + "WAVEfmt " + wrle 16 4 + wrle 1 2 + wrle 2 2
        + wrle rate 4 + wrle (rate * 4) 4 + wrle 4 2 + wrle 16 2 + "data" + wrle d 4))
   (harp-wav p c0 ncyc rate cps tail g path)
    (: q (open path "w")
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
   (qshow t) (: p (qparts t) (? (1 = <>p) (show <p) (show <p + "/" + show <>p)))
   (harp-print p c0 ncyc)
    (each ^ncyc
          (\ i (: c (c0 + i)
                  _ (say out $ "cycle " + (show c) + "\n")
                  (each (p (qi c) (qi (c + 1)))
                        (\ x (say out $ "  " + (qshow (evwb x)) + " .. " + (qshow (evwe x))
                                        + (? (onset? x) "" "  (tail)")
                                        + "  " + (show (evv x)) + "\n"))))))

   ; --- the verb -------------------------------------------------------------
   harp-usage "usage: harp [-n N] [-c CPS] [-r RATE] [-g GAIN] [-o F.wav] [-p] [-s SCORE] PATTERN..
       harp --check SCORE"
   ; a bare argument is mini-notation for `hit`; one that opens a paren is love, read
   ; and evaluated with the harp module already spliced; -s is a score file
   ; (apps/harp/score.l), its bars the cycles unless -n says. several arguments stack.
   ; a parenthesised text is love over harp's names: ev runs in the global scope, where
   ; harp is not, so harp is spliced there first -- once, and before the text is read,
   ; since a name folds into a form at its compile and the prel already owns rand, sine
   ; and rev. blanks and comment lines before the paren are passed over, so a loop file
   ; may open with a word about itself
   (harp-lead a) (:- (go 0) n #a
                  (go i) (? (i >= n) i
                            (32 >= a i) (go (i + 1))
                            (59 = a i) (: (eol j) (j < n && 10 != a j ? (eol (j + 1)) j) (go (eol i)))
                            i))
   spliced (tablet 0)
   (harp-splice _) (? (peep spliced 0 0) ()
                      (pin spliced 0 1, ev (<(sound "(borrow 'harp)"))))
   (harp-read a) (: i (harp-lead a)
                    (i < #a && 40 = a i ? (harp-splice (), sound a @ (f . _) (ev f) hush)
                                          (hit (mini a))))
   (harp-atoi s) (:- (go 0 0) n #s
                  (go i acc) (? (i >= n) acc (go (i + 1) ((acc * 10) + ((s i) - 48)))))
   (harp-atof s) (sound s @ (r . _) r 0)
   (harp-main as)
    (: (go l o ps)
        (atom? l ? (harp-fire o (lrev ps))
         (<l @
               "-n" (go >>l (pin o 'cycles (harp-atoi <>l)) ps)
               "-r" (go >>l (pin o 'rate (harp-atoi <>l)) ps)
               "-c" (go >>l (pin o 'cps (harp-atof <>l)) ps)
               "-f" (go >>l (pin o 'from (harp-atoi <>l)) ps)
               "-o" (go >>l (pin o 'wav <>l) ps)
               "-g" (go >>l (pin o 'gain (harp-atof <>l)) ps)
               "-p" (go >l (pin o 'print 1) ps)
               "-s" (go >>l (pin o 'scores (<>l . peep o 'scores ())) ps)
               "--check" (: ls ((cite 'score 'score-file) <>l)
                            (? ls ((cite 'score 'score-check) ls 1)
                               (say err ("harp: cannot read " + <>l + "\n"), 1)))
               ("-h" || "--help") (puts (harp-usage + "\n"), flush out, 0)
               ("-v" || "--version")
                (puts ("harp (love " + love-version + ")\n"), flush out, 0)
               a (go >l o (a . ps))))
       (go as {'rate 48000 'cps 0.5 'from 0 'print 0 'gain 1.0} ()))
   (harp-fire o ps)
    (: sc   (cite 'score)
       ; a score's bars, every file's; a bad bar has been named and stops the run
       bars (foldl (\ acc f (: ls (sc 'score-file f)
                              (? (acc = 'bad) 'bad
                                 !ls (say err ("harp: cannot read " + f + "\n"), 'bad)
                                 (sc 'score-check ls 0) 'bad
                                 (acc + filter (b \ !(b 'err)) (sc 'score-parse ls)))))
                   () (peep o 'scores ()))
       cps  (o 'cps)
       ps2  (bars = 'bad ? () (ps + (two? bars ? [(sc 'score-tune bars cps)] ())))
       p    (? !(two? ps2) hush
               (1 = #ps2) (: x <ps2 (string? x ? (harp-read x) x))
               (stack (map (x \ (string? x ? (harp-read x) x)) ps2)))
       rate (o 'rate)  c0 (o 'from)
       ncyc (peep o 'cycles (two? bars ? #bars 4))
       tail (int (rate / 2))                       ; half a second for the last decay
       g    (harp-scale * (o 'gain))
       (? (bars = 'bad) 1
          !(two? ps2) (say err (harp-usage + "\n"), 1)
          (o 'print) (harp-print p c0 ncyc, 0)
          (peep o 'wav ()) (harp-wav p c0 ncyc rate cps tail g (o 'wav), 0)
          (harp-horn p c0 ncyc rate cps tail g, 0)))
   ; ..and as a verb of the artifact: `love harp`
   _ (pins (cite 'verbs 'tab) 'harp (udoor 'harp harp-main harp-usage 0 0)))
) ; module play

; the seat: fire only when this file is the program on the real command line.
(: s (cite 'verbs 'fire ["harp" "play.l"])
   (two? s ? (quit (cite 'play 'harp-main >s))))
