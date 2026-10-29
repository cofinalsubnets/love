; mus -- doom's MUS scores, played on opl.l's FM instruments. read from the doom wiki's format page:
; a header ("MUS" 26, the score's length and start, channel counts, the instruments it uses),
; then events, each a byte of [last type channel] and its data, a delay after any marked last,
; in ticks of 1/140 s. channel 15 is percussion.
;   (mus-read b)      a score's events [tick channel kind a b] and its length in ticks, or ()
;   (mus-new sc bank rate)  a player of score sc on bank's instruments at rate, looping
;   (mus-feed p n)    its next n frames, (left . right) trays of floats about 0
;   (mus-track m)     the music lump a map plays, by the doom wiki's table, or ()
(module (mus mus-read mus-new mus-feed mus-track mus-voices)
(borrow 'bytes)                         ; rdle
(borrow 'opl)
(:
 ; --- the score: every event read once, its tick from the delays before it ---
 (mus-read b) (? (!(string? b) || #b < 16 || snip b 0 4 != "MUS\x1a") ()
   (: len (rdle b 4 2) st (rdle b 6 2) end (min #b (st + len))
      (delay p d) (p >= end ? [p d] (b p @ x (x < 128 ? [(p + 1) (d * 128 + x)] (delay (p + 1) (d * 128 + x - 128)))))
      ; ..one event at p: [event next-p], () at the score's end
      (one p t) (? (p >= end) ()
         (: e (b p) ty (e >> 4 & 7) ch (e & 15) q (p + 1) (at k) (q + k < end ? (b (q + k)) 0)
            (ty @ 0 [[t ch 'off (at 0 & 127) 0] (q + 1)]
                  1 (at 0 @ x (x < 128 ? [[t ch 'on x -1] (q + 1)] [[t ch 'on (x & 127) (at 1)] (q + 2)]))
                  2 [[t ch 'bend (at 0) 0] (q + 1)]
                  3 [[t ch 'sys (at 0) 0] (q + 1)]
                  4 [[t ch 'ctl (at 0) (at 1)] (q + 2)]
                  5 [() q]
                  _ ())))
      (go p t acc) (one p t @ () [(rev acc) t]
                         [ev q] (: last (b p >= 128) acc2 (ev = () ? acc (ev . acc))
                                   (last ? (delay q 0 @ [q2 d] (go q2 (t + d) acc2)) (go q t acc2))))
      ((go st 0 ()) @ [evs n] (two? evs ? {'evs evs 'ticks n} ()))))
 ; --- the player: channels' instrument, volume, pan and bend; the notes sounding, each [channel
 ;     note voice instrument at key velocity pan], and the released ones ringing out ---
 (chan _) {'prog 0 'vol 127 'pan 64 'bend 0.0 'vel 127}
 (mus-new sc bank rate) {'sc sc 'bank bank 'rate rate 'evs (sc 'evs) 'base 0 'fpos 0
                         'ch (map chan ^16) 'on () 'tails () 'fpt (rate / 140.0)}
 ; ..a note's instrument: percussion by its note, else the channel's program
 (ins p c n) (c = 15 ? (opl-drum (p 'bank) n) (p 'bank (min 127 (p 'ch c 'prog))))
 (velo C v) (v * C 'vol // 127)
 (start p e at) (: c (e 1) n (e 3) C (p 'ch c) _ (e 4 >= 0 ? (pin C 'vel (e 4)) 0) I (ins p c n)
   _ (release p c n at)
   (tablet? I ? (: k (1.0 * n + C 'bend) v (velo C (C 'vel)) pn (C 'pan / 127.0)
                (pin p 'on ([c n (opl-voice I k v pn at () (p 'rate)) I at k v pn] . p 'on))) 0))
 ; ..let go: the same voice again with its release, from frame at
 (release p c n at) (: hit (filter (s \ s 0 = c && (n < 0 || s 1 = n)) (p 'on))
   (two? hit ? (pins p 'on (filter (s \ !(s 0 = c && (n < 0 || s 1 = n))) (p 'on))
                      'tails (map (s \ opl-voice (s 3) (s 5) (s 6) (s 7) (s 4) at (p 'rate)) hit + p 'tails)) 0))
 (apply p e at) (: c (e 1) C (p 'ch c)
   (e 2 @ 'on (start p e at) 'off (release p c (e 3) at)
          'bend (pin C 'bend ((e 3 - 128) / 64.0))
          'sys (e 3 = 10 || e 3 = 11 ? (release p c -1 at) (e 3 = 14 ? (pins C 'vol 127 'pan 64 'bend 0.0) 0))
          'ctl (e 3 @ 0 (pin C 'prog (e 4)) 3 (pin C 'vol (e 4)) 4 (pin C 'pan (e 4)) _ 0)
          _ 0))
 ; ..the events before frame lim, each at its own frame; at the end the score starts again
 (run p lim) (: evs (p 'evs)
   (? (atom? evs) (: nb (p 'base + int (p 'sc 'ticks * p 'fpt)) (nb >= lim || p 'sc 'ticks = 0 ? 0 (: _ (pins p 'evs (p 'sc 'evs) 'base nb) (run p lim))))
      (: e <evs at (p 'base + int (e 0 * p 'fpt))
         (at >= lim ? 0 (apply p e at, pin p 'evs >evs, run p lim)))))
 ; ..at most 16 voices: the oldest let-go ones are the first to stop
 (firsts l k) (k = 0 || atom? l ? () (<l . firsts >l (k - 1)))
 (mus-feed p n) (: base (p 'fpos) _ (run p (base + n))
   tails (firsts (filter (v \ v 0 >= base) (p 'tails)) (max 0 (16 - #(p 'on))))
   _ (pins p 'tails tails 'fpos (base + n))
   (cite 'play 'mixdown (map (s \ s 2) (p 'on) + tails) base n))
 (mus-voices p) (#(p 'on) + #(p 'tails))
 ; --- which lump a map plays: an episode's map its own, doom 2's by their names in order ---
 d2 ["RUNNIN" "STALKS" "COUNTD" "BETWEE" "DOOM" "THE_DA" "SHAWN" "DDTBLU" "IN_CIT" "DEAD" "STLKS2"
     "THEDA2" "DOOM2" "DDTBL2" "RUNNI2" "DEAD2" "STLKS3" "ROMERO" "SHAWN2" "MESSAG" "COUNT2"
     "DDTBL3" "AMPIE" "THEDA3" "ADRIAN" "MESSG2" "ROMER2" "TENSE" "SHAWN3" "OPENIN" "EVIL" "ULTIMA"]
 e4 ["E3M4" "E3M2" "E3M3" "E1M5" "E2M7" "E2M4" "E2M6" "E2M5" "E1M9"]
 (mus-track m) (? (#m = 4 && m 0 = 69 && m 2 = 77) (m 1 @ 52 "D_\(e4 (m 3 - 49))" "D_\(m)")
                  (#m = 5 && snip m 0 3 = "MAP") (: k ((m 3 - 48) * 10 + m 4 - 49) (0 <= k && k < 32 ? "D_\(d2 k)"))
                  ())
)) ; module mus
