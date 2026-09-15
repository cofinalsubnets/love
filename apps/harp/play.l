#!/usr/bin/env -S love -l
; apps/harp/play.l -- harp's voices and its verb: a pattern (apps/harp/harp.l) is
; asked for one cycle at a time, its onsets become voices, and the voices are summed
; into PCM that goes out the horn (inle/horn.c) or into a .wav.
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
         harp-scale harp-chunk mkvoice cyc-voices mixdown pack
         twopi ln2-12 venv vnum vnoise instr vname)
(borrow (: m (cite 'harp) (? m m "apps/harp/harp.l")))
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
    (: a (((ix * 1103515245) + 12345) & 4294967295)
       b (((a ^ (a >> 16)) * 2246822507) & 4294967295)
       c (((b ^ (b >> 13)) * 3266489909) & 4294967295)
       ((((c >> 16) & 65535) * 0.000030517578125) - 1.0))

   ; --- the kit. each takes (t ix f): seconds since the onset (clamped at 0), the
   ;     absolute frame numbers, and the note's frequency. all three are trays. ---
   ; a kick is one falling sine: the phase is the integral of 46 + 88e^(-34t), in
   ; closed form, because a per-sample oscillator would need state and this does not.
   (i-bd t ix f) (sin ((t * 46.0 + 2.6 * (1.0 - exp (t * -34.0))) * tau)
                  * exp (t * -8.0))
   (i-sn t ix f) ((vnoise ix * 0.75 + sin (t * tau * 190.0) * 0.5) * exp (t * -24.0))
   (i-hh t ix f) (vnoise ix * 0.5 * exp (t * -95.0))
   (i-oh t ix f) (vnoise ix * 0.4 * exp (t * -13.0))
   ; a clap is a short chatter then a tail: the chatter is a duty cycle on t, so it
   ; is still one expression
   (i-cp t ix f) (: g (((((t * 220.0) % 1.0) < 0.45) * (t < 0.028)) + (t >= 0.028))
                    ((vnoise ix) * 0.55 * g * (exp (t * -17.0))))
   (i-rim t ix f) ((sin (t * (tau * 1650.0))) * 0.7 * (exp (t * -150.0)))
   (i-tom t ix f) ((sin ((t * 96.0 + (1.4 * (1.0 - (exp (t * -22.0))))) * tau))
                   * (exp (t * -11.0)))
   ; the pitched four, each with one attack-decay envelope
   (venv t d) ((1.0 - (exp (t * -420.0))) * (exp ((t / d) * -2.6)))
   (i-sin t ix f) (sin (t * (tau * f)))
   (i-saw t ix f) ((((t * f) % 1.0) * 2.0) - 1.0)
   (i-sqr t ix f) (((((t * f) % 1.0) < 0.5) * 2.0) - 1.0)
   (i-tri t ix f) (: u ((t * f) % 1.0)
                     v (u * 4.0)
                     (((u < 0.5) * (v - 1.0)) + ((u >= 0.5) * (3.0 - v))))
   ; name -> [default-duration pitched? shape]
   (instr nm)
    (? (nm = "bd")  [0.55 0 i-bd]   (nm = "sn")  [0.35 0 i-sn]
       (nm = "hh")  [0.09 0 i-hh]   (nm = "oh")  [0.35 0 i-oh]
       (nm = "cp")  [0.35 0 i-cp]   (nm = "rim") [0.06 0 i-rim]
       (nm = "tom") [0.45 0 i-tom]  (nm = "sin") [0.30 1 i-sin]
       (nm = "saw") [0.30 1 i-saw]  (nm = "sqr") [0.30 1 i-sqr]
       (nm = "tri") [0.30 1 i-tri]  ())

   ; --- an event's value -> a voice ------------------------------------------
   ; the value is a tablet from the control words, a bare string from `hit`, or a
   ; bare number from a note pattern with nothing wrapped round it.
   (vname v) (? (tablet? v) (peep v 's "sin") (string? v) v "sin")
   ; peep's default cannot be (): 0 is a real gain and a real note, and `nil? 0` is
   ; true here, so a missing key is asked for by a symbol nothing else can be.
   (vnum v k d) (: r (? (tablet? v) (peep v k 'none) (charm? v) (? (== k 'note) v 'none) 'none)
                   (? (== r 'none) d r))
   ; a voice is [end-frame amp-of-frames left-gain right-gain]
   (mkvoice st v rate)
    (: ins (instr (vname v))
       (? !ins ()
          (: dur (vnum v 'legato (ins 0))
             nt  (vnum v 'note (vnum v 'n 0))
             f   (261.6255653005986 * (exp ((? (ins 1) nt 0) * ln2-12)))
             amp (vnum v 'gain 1.0)
             pn  (vnum v 'pan 0.5)
             spd (vnum v 'speed 1.0)
             sh  (ins 2)
             end (st + (int ((dur * rate) / spd)) + 2)
             fn  (\ ix (: t  ((ix - st) * (spd / rate))
                          tp (t * (t > 0.0))
                          e  (? (ins 1) (venv tp dur) 1.0)
                          ((sh tp ix f) * e * (t >= 0.0) * (t < dur))))
             [end fn (amp * (1.0 - pn)) (amp * pn)])))

   ; --- mixing and packing ---------------------------------------------------
   ; every live voice is evaluated over the whole chunk and summed. the cost is one
   ; pass per voice per chunk in C, so a busy cycle is a handful of tray ops.
   ; ..and a voice panned hard adds nothing to its far side, so that side is left as it is
   (mixdown vs base n)
    (: ix ((iota n) + base)
       z  (ix * 0.0)
       (side acc y g) (g = 0.0 ? acc (acc + (y * g)))
       (go l L R) (? !(two? l) (L . R)
                     (: y ((<l 1) ix)
                        (go >l (side L y (<l 2)) (side R y (<l 3)))))
       (go vs z z))
   ; one voice at full scale reaches 0.6 of the range, so a handful may stack before
   ; the saturation bites. -g moves the whole mix under that ceiling.
   harp-scale 20000.0
   (clip g x) (: v (int (x * g))
                 (? (v > 32767) 32767 (v < -32768) -32768 (v & 65535)))
   ; ..and the same saturation over a whole tray, as arithmetic: `// 1` truncates toward
   ; zero exactly where `int` does, and the two comparisons are masks.
   (clipv g t) (: v (t * g // 1)
                  hi (v > 32767)  lo (v < -32768)
                  ((v * (1 - hi) * (1 - lo)) + (hi * 32767) + (lo * -32768)))
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
                    _ (pin c o (l & 255))         _ (pin c (o + 1) ((l >> 8) & 255))
                    _ (pin c (o + 2) (r & 255))   _ (pin c (o + 3) ((r >> 8) & 255))
                    (go (i + 1))))
       (? whole (: _ (lay c 0 2 4 (clipv g L))
                   _ (lay c 2 2 4 (clipv g R))
                   (string c))
          (string (go 0))))

   ; --- the run: cycles in, chunks out ---------------------------------------
   harp-chunk 2048
   ; a cycle's onsets, as voices, with the start frame each one lands on.
   ; THIS IS THE BOUNDARY. cycle time is a `///` rational and frame time is an
   ; integer, and qnum is the one crossing: a rational that reached the tray lane
   ; would answer () rather than promoting it, and the voice would go silent with
   ; nothing said. nothing downstream of here holds a rational.
   (cyc-voices p c c0 spc rate)
    (filter two?
            (map (\ x (mkvoice (((c - c0) * spc)
                                + (int (spc * (qnum ((evwb x) - (qi c))))))
                               (evv x) rate))
                 (filter onset? (p (qi c) (qi (c + 1))))))
   ; the write head walks the whole run in chunks. voices are pulled in a cycle at a
   ; time, just before the chunk that can hear them, and dropped when their end frame
   ; is behind the head -- so the live list is only ever what is actually sounding.
   (harp-run p c0 ncyc rate cps tail g emit)
    (: spc   (int (rate / cps))
       total ((ncyc * spc) + tail)
       (fill c vs lim) (? ((((c - c0) * spc) >= lim) || (c >= (c0 + ncyc))) (c . vs)
                          (fill (c + 1) (cat vs (cyc-voices p c c0 spc rate)) lim))
       (go base vs c)
        (? (base >= total) 1
           (: lim (? ((base + harp-chunk) < total) (base + harp-chunk) total)
              r   (fill c vs lim)
              live (filter (\ v ((v 0) >= base)) >r)
              _   (emit (pack (mixdown live base (lim - base)) (lim - base) g))
              (go lim live <r)))
       (go 0 () c0))

   ; --- the two sinks --------------------------------------------------------
   (wav-head rate n)                      ; 44 bytes of canonical PCM riff
    (: (u32 v) (string (v & 255) + string ((v >> 8) & 255)
                       + string ((v >> 16) & 255) + string ((v >> 24) & 255))
       (u16 v) (string (v & 255) + string ((v >> 8) & 255))
       d (n * 4)
       ("RIFF" + (u32 (36 + d)) + "WAVEfmt " + (u32 16) + (u16 1) + (u16 2)
        + (u32 rate) + (u32 (rate * 4)) + (u16 4) + (u16 16) + "data" + (u32 d)))
   (harp-wav p c0 ncyc rate cps tail g path)
    (: q (open path "w")
       (? !(hot? q) (: _ (say err $ "harp: cannot write " + path + "\n") 0)
          (: _ (say q (wav-head rate ((ncyc * (int (rate / cps))) + tail)))
             _ (harp-run p c0 ncyc rate cps tail g (\ s (say q s)))
             _ (close q) 1)))
   (harp-horn p c0 ncyc rate cps tail g)
    (: h (horn rate 2)
       (? (nom? h) (: _ (say err $ "harp: no horn -- " + (show h) + "\n") 0)
          (: _ (harp-run p c0 ncyc rate cps tail g (\ s (say h s)))
             _ (flush h) _ (close h) 1)))

   ; --- printing, for eyes rather than ears ----------------------------------
   (qshow t) (: p (load t) (? (1 = <>p) (show <p) (show <p + "/" + show <>p)))
   (harp-print p c0 ncyc)
    (each ^ncyc
          (\ i (: c (c0 + i)
                  _ (say out $ "cycle " + (show c) + "\n")
                  (each (p (qi c) (qi (c + 1)))
                        (\ x (say out $ "  " + (qshow (evwb x)) + " .. " + (qshow (evwe x))
                                        + (? (onset? x) "" "  (tail)")
                                        + "  " + (show (evv x)) + "\n"))))))

   ; --- the verb -------------------------------------------------------------
   harp-usage "usage: harp [-n N] [-c CPS] [-r RATE] [-g GAIN] [-o F.wav] [-p] PATTERN.."
   ; a bare argument is mini-notation for `hit`; one that opens a paren is love, read
   ; and evaluated with the harp module already spliced. several arguments stack.
   (harp-read a) (? ((0 < #a) && (40 = (a 0)))
                    (: r (sound a) (? (two? r) (ev <r) hush))
                    (hit (mini a)))
   (harp-atoi s) (: n #s
                    (go i acc) (? (i >= n) acc (go (i + 1) ((acc * 10) + ((s i) - 48))))
                    (go 0 0))
   (harp-atof s) (: r (sound s) (? (two? r) <r 0))
   (harp-main as)
    (: (go l o ps)
        (? !(two? l) (harp-fire o (lrev ps))
           (: a <l
              (? (a = "-n") (go >>l (pin o 'cycles (harp-atoi <>l)) ps)
                 (a = "-r") (go >>l (pin o 'rate (harp-atoi <>l)) ps)
                 (a = "-c") (go >>l (pin o 'cps (harp-atof <>l)) ps)
                 (a = "-f") (go >>l (pin o 'from (harp-atoi <>l)) ps)
                 (a = "-o") (go >>l (pin o 'wav <>l) ps)
                 (a = "-g") (go >>l (pin o 'gain (harp-atof <>l)) ps)
                 (a = "-p") (go >l (pin o 'print 1) ps)
                 (a = "-h" || a = "--help") (puts (harp-usage + "\n"), flush out, 0)
                 (a = "-v" || a = "--version")
                  (puts ("harp (love " + love-version + ")\n"), flush out, 0)
                 (go >l o (a . ps)))))
       (go as {'cycles 4 'rate 48000 'cps 0.5 'from 0 'print 0 'gain 1.0} ()))
   (harp-fire o ps)
    (: p    (? !(two? ps) hush
               (1 = #ps) (harp-read <ps)
               (stack (map harp-read ps)))
       rate (o 'rate)  cps (o 'cps)  ncyc (o 'cycles)  c0 (o 'from)
       tail (int (rate / 2))                       ; half a second for the last decay
       g    (harp-scale * (o 'gain))
       (? !(two? ps)
          (: _ (say err (harp-usage + "\n")) 1)
          (o 'print) (: _ (harp-print p c0 ncyc) 0)
          (peep o 'wav ()) (: _ (harp-wav p c0 ncyc rate cps tail g (o 'wav)) 0)
          (: _ (harp-horn p c0 ncyc rate cps tail g) 0))))
) ; module play

; the seat: fire only when this file is the program on the real command line.
(: s (cite 'verbs 'fire ["harp" "play.l"])
   (two? s ? (quit ((cite 'play 'harp-main) >s))))
