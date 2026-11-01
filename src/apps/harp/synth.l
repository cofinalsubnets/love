; synth -- a keyboard to pick a tune out on: the qwerty rows play harp's voices out the horn,
; z to / from c below middle c, q to ] from middle c, the row above each its sharps. in a
; window a note sounds while its key is held, or while a finger is on the strip of keys; a
; tty never says a key was let go, so there a key is a strike that rings and dies. the horn
; is fed at least an eighth of a second ahead, longer than the runtime's pauses (synth-warm
; takes the first early). a backing loop (harp's pattern text) is a vi buffer under the keys.
; --fm FILE adds a last timbre from an op2 bank or a wad's GENMIDI. the mix goes through a bus
; of chorus, echo and reverb (space.c), each on its own f key. the pads (pad, glass, wash)
; swell in through a filter a slow lfo sweeps, and fade slowly once let go. f11 and f12 turn
; the volume, the horn's own, past any mixer.
; run: love synth [--fm FILE] [-w|--window] [LOOP]   HORN=none plays silent on a box with no card
(module (synth synth-run synth-main synth-new synth-step synth-name synth-key synth-tcode synth-tty
         synth-strike synth-feed synth-frame synth-wframe synth-timbres synth-knobs synth-knob
         synth-chunk synth-lead synth-octaves synth-send synth-play synth-stop synth-pull
         synth-cps! synth-cps synth-cps-step synth-cps-lo synth-cps-hi synth-text synth-ex
         synth-qwerty synth-hold synth-free synth-drone synth-latch synth-wstep synth-paint synth-window synth-trows
         synth-top synth-wlay synth-wedit synth-cell
         synth-tims synth-tname synth-space synth-wets synth-fx synth-mix synth-gain synth-ftail synth-stail synth-ceil synth-limit
         synth-vols synth-vol0
         synth-pads synth-pad)
(borrow 'rove)
(borrow 'harp)
(borrow 'play)
(borrow 'posix)
(borrow 'window)
(borrow 'opl)
(borrow 'ops)
(:
 esc (string 27)
 ; the pitched voices of harp's kit, each with how long a strike rings
 synth-timbres [["sin" 1.2] ["tri" 1.2] ["saw" 0.9] ["sqr" 0.9] ["box" 1.6] ["chime" 3.0]
                ["pad" 7.0] ["glass" 6.0] ["wash" 8.0]]
 synth-octaves 3
 synth-chunk (song-rate // 60)          ; a feed, in frames
 synth-lead (song-rate // 8)            ; the least queued ahead of the speaker
 synth-gain 11000.0
 synth-vols [0.0 0.06 0.09 0.12 0.18 0.25 0.35 0.5 0.7 1.0 1.4 2.0]   ; ~3 dB a step, 1.0 the mix as laid
 synth-vol0 9
 names ["C" "C#" "D" "D#" "E" "F" "F#" "G" "G#" "A" "A#" "B"]
 synth-cps 0.5                          ; cycles a second the loop starts at
 synth-cps-step 0.05                    ; and what pgup and pgdn move it by
 synth-cps-lo 0.1
 synth-cps-hi 4.0

 ; the loop's state: 'pat playing, 'nextp sent since, 'cyc the next cycle to pull and
 ; 'cstart its frame, 'due voices pulled but not begun as [start voice]. 'buf the loop's vi
 ; buffer, 'focus the window's pane, 'mods its held modifiers, 'tk the strip's touched key
 (synth-new o) {'fm (tablet? o ? (peep o 'fm ()) ()) 'prog 0 'oct 0 'tim 0 'vs () 'due () 'fpos 0 'last () 'lk 0 'lt 0 'dirty 1
                'pat () 'nextp () 'on 0 'cyc 0 'cstart 0 'cps synth-cps 'lmsg "" 'over 0 'hv ()
                'rev 0 'rvw 2 'echo 0 'ecw 1 'cho 0 'chw 2 'shm 0 'shw 2 'fxm () 'fxt 0 'rls {} 'latch 0 'lim () 'vol synth-vol0
                'buf () 'fc () 'focus 'keys 'mods {} 'cw 0 'tk () 'vd 0}

 (synth-name s) (: t (int s) n (s < t ? (t - 1) t)
                   o (n < 0 ? ((n - 11) // 12) (n // 12))
                   (names (n - 12 * o) + show (4 + o) + (n < s ? " +50c" "")))

 ; --- the timbres: harp's, and with a bank the FM one last ---
 (synth-tims st) (st 'fm ? (synth-timbres + [["fm" 2.0]]) synth-timbres)
 (synth-tname st) (synth-tims st (st 'tim) 0 @ "fm" ("fm " + show (st 'prog) + " " + st 'fm (st 'prog) 'name) n n)
 (fm? st) (synth-tims st (st 'tim) 0 = "fm")
 (fmv st s at off) (opl-voice (st 'fm (st 'prog)) (60.0 + s) 100 0.5 at off song-rate)
 (prog st d) (st 'fm ? (pins st 'prog ((st 'prog + d + 175) % 175) 'dirty 1) st)
 ; --- the pads: a detuned unison swelling in, through a filter a slow lfo sweeps. a note is a
 ; voice a side, each its own spread and its lfo out of step with the other's. 'n operators of
 ; 'wave 'cents apart either side, 'att seconds to swell, 'rel to fade once let go; the filter's
 ; 'cut (Hz at middle c, following the key by 'track octaves an octave), 'depth, 'lfo, 'q,
 ; 'band ---
 synth-pads {"pad"   {'wave 5 'n 7 'cents 14.0 'att 1.5 'rel 3.0 'lvl 0.11 'cut 1100.0 'track 0.5 'depth 1.2 'lfo 0.09 'q 0.8 'band 0}
             "glass" {'wave 4 'n 4 'cents 7.0 'att 0.8 'rel 2.5 'lvl 0.13 'cut 3200.0 'track 0.7 'depth 0.8 'lfo 0.06 'q 1.3 'band 0}
             "wash"  {'wave 7 'n 1 'cents 0.0 'att 2.5 'rel 4.0 'lvl 4.0 'cut 261.6255653005986 'track 1.0 'depth 0.5 'lfo 0.05 'q 5.0 'band 1}}
 ksweep (cite 'dsp 'sweep)
 ; a voice's frames through the filter, its memory carried from one chunk to the next
 (swept [end fn gl gr] o s ph)
  (: box {'next () 'st ()}
     (prm f0) (gem-tray [8] [(1.0 * song-rate) (1.0 * f0) (o 'cut * exp (o 'track * s * ln2-12)) (o 'depth) (o 'lfo) ph (o 'q) (1.0 * o 'band)])
     [end (ix \ (: f0 (peep ix 0 0)
                   (ksweep (fn ix) (box 'next = f0 ? (box 'st) ()) (prm f0) @ r
                      (pins box 'next (f0 + #ix) 'st >r, <r))))
      gl gr])
 ; the note's two voices from frame at to end; dur () holds at full once swelled
 (synth-pad nm s at end dur)
  (: o (synth-pads nm) f (261.6255653005986 * exp (s * ln2-12)) n (o 'n)
     segs [[0.0 2 (3.0 / o 'att) (dur ? (60.0 / dur) 0.0) 0.0]]
     (side k) (: sp (k ? 0.83 1.0)
                 os (map (j \ {'f (f * exp ((n < 2 ? 0.0 (o 'cents * sp * (2.0 * j / (n - 1) - 1.0))) * ln2-12 / 100.0))
                               'wave (o 'wave) 'l (o 'lvl) 'drop ((j * 0.37 + k * 0.21) % 1.0) 'kappa 3000.0 'segs segs}) ^n)
                 v (ops-voice os at end 1.0 0.0 song-rate)
                 g (k ? [0.25 1.0] [1.0 0.25])
                 (ksweep ? (swept [end (v 1) (g 0) (g 1)] o s (k * 0.41)) [end (v 1) (g 0) (g 1)]))
     [(side 0) (side 1)])
 (pad? st) (tablet? (peep synth-pads (synth-tims st (st 'tim) 0) ()))
 ; --- a strike: a voice from the next frame to be written ---
 (synth-strike st s) (: tm (synth-tims st (st 'tim)) at (st 'fpos) end (at + int (tm 1 * song-rate))
                        vs (? (fm? st) [(fmv st s at end)]
                              (pad? st) (synth-pad (tm 0) s at end (tm 1))
                              [(mkvoice at {'s (tm 0) 'note s 'gain 0.8 'pan 0.5 'legato (tm 1)} song-rate)])
                        (pins st 'vs (st 'vs + vs) 'last (synth-name s) 'dirty 1))
 ; --- the loop ---
 ; a text that fails harp-read answers its complaint and the loop keeps what it had; an
 ; empty text is hush. sending starts the loop if it stood
 (synth-text ls) (foldl (a \ l \ a + "\n" + l) <ls >ls)
 (synth-send st text) (: t (strip text)
                         r (0 = #t ? hush
                              (trap (_ \ harp-read t) () (a \ b \ ['bad (show a + " " + show b)])))
                         (two? r ? (pins st 'lmsg <>r 'dirty 1)
                            (pins st 'nextp r 'lmsg "sent" 'dirty 1,
                             st 'on ? st (synth-play st))))
 ; stop: nothing more pulled, what has not begun dropped, what rings rings out
 (synth-play st) (st 'on ? st (pins st 'on 1 'cyc 0 'cstart (st 'fpos) 'dirty 1))
 (synth-stop st) (pins st 'on 0 'due () 'dirty 1)
 (synth-cps! st v) (pins st 'cps (v < synth-cps-lo ? synth-cps-lo (synth-cps-hi < v ? synth-cps-hi v)) 'dirty 1)
 ; voices are kept with their start until it comes: one not begun is silent but its
 ; closure still runs every frame. qnum is the one crossing from rational cycle time
 (synth-pull st lim) (:- (go ()) (go _)
   (? (!(st 'on) || lim <= st 'cstart) ()
      (: _ (st 'nextp ? (pins st 'pat (st 'nextp) 'nextp ()))
         p (st 'pat) c (st 'cyc) f0 (st 'cstart) spc (int (song-rate / st 'cps))
         vs (p ? (filter two? (map (x \ (: at (f0 + int (spc * qnum (evwb x - qi c)))
                                          v (mkvoice at (evv x) song-rate)
                                        (two? v ? [at v] ())))
                                   (filter onset? (p (qi c) (qi (c + 1)))))))
         ((pins st 'due (st 'due + vs) 'cyc (c + 1) 'cstart (f0 + spc) 'dirty 1),
          go ()))))
 ; vi's ex door: true for one of the loop's words
 (synth-ex st s w arg) (: (num t) (: v <(sound t) (charm? v ? v ()))
   (? (w = "send") (synth-send st (synth-text (s 'lines)), pin s 'msg (st 'lmsg), 1)
      (w = "play") (synth-play st, pin s 'msg "playing", 1)
      (w = "stop") (synth-stop st, pin s 'msg "stopped", 1)
      (w = "cps") (num arg @ v
                     (v ? (synth-cps! st v),
                      pin s 'msg (v ? ("cps " + show (st 'cps)) "cps N"),
                      1))
      ()))
 ; --- the bus: each effect a toggle and a step of how wet. off, an effect hears nothing more
 ; but what it holds rings out; the kernel stops once nothing can still sound ---
 synth-wets [0.2 0.35 0.5 0.7 1.0]
 ; [toggle wet-step name], each a knob
 synth-fx [['rev 'rvw "reverb"] ['echo 'ecw "echo"] ['cho 'chw "chorus"] ['shm 'shw "shimmer"]]
 synth-t60 7.0
 synth-ftail (int (song-rate * (1.5 * synth-t60 + 4.0)))   ; the reverb's 90 dB, and the echo's ring
 synth-stail (4 * synth-ftail)                             ; and with the shimmer giving back
 kspace (cite 'dsp 'space)
 (fxon st) (any (f \ st (f 0) = 1) synth-fx)
 (fxprm st) (: (w k) (1.0 * synth-wets (st k))
   (gem-tray [16] [(1.0 * song-rate)
                   (1.0 * st 'cho) (w 'chw) 0.004 0.23
                   (1.0 * st 'echo) (w 'ecw) 0.42 0.55 0.35
                   (1.0 * st 'rev) (w 'rvw) synth-t60 1.6 0.45
                   (1.0 * st 'shm * w 'shw)]))
 ; a fresh bus's memory is the size the kernel first answers
 (synth-space st lr)
  (? (!kspace || (!(fxon st) && st 'fxt <= 0)) lr
     (kspace <lr >lr (st 'fxm) (fxprm st) @ r
        (? (charm? r) (pin st 'fxm (cask r), synth-space st lr)
           !(two? r) lr
           (pin st 'fxt (fxon st ? (st 'shm = 1 ? synth-stail synth-ftail) (st 'fxt - #<lr)), r))))
 ; last, a limiter: under half the clip nothing moves; past it a pile of held notes bends
 ; toward the clip, never through it
 klimit (cite 'dsp 'limit)
 synth-ceil (0.97 * 32767.0 / synth-gain)
 ; past 1.0 the ceiling comes down with the volume, so a louder horn bends sooner, never clips
 synth-lprms (map (v \ gem-tray [4] [(1.0 * song-rate) (synth-ceil / max v 1.0) 0.5 0.4]) synth-vols)
 (synth-limit st lr)
  (? !klimit lr
     (klimit <lr >lr (st 'lim) (synth-lprms (st 'vol)) @ r
        (? (charm? r) (pin st 'lim (cask r), synth-limit st lr)
           (two? r) r
           lr)))
 (fxkey st kn) (: (go l) (? (atom? l) st
                           (kn = <l 0) (pins st (<l 0) (1 - st (<l 0)) 'dirty 1)
                           (kn = <l 1) (pins st (<l 1) ((st (<l 1) + 1) % #synth-wets) 'dirty 1)
                           (go >l))
                  (go synth-fx))
 (vline st) ("   volume " + show (synth-vols (st 'vol)))
 (fxline st) ("  " + foldl (+) "" (map (f \ f 2 + " " + (st (f 0) = 1 ? (show (synth-wets (st (f 1)))) "off") + "   ") synth-fx))

 ; one chunk as floats, (left . right): the cycles pulled, the due voices taken up, all summed
 ; and through the bus and the limiter
 (synth-mix st) (: base (st 'fpos) lim (base + synth-chunk)
                   _ (synth-pull st lim)
                   now (map (p \ p 1) (filter (p \ p 0 < lim) (st 'due)))
                   live (filter (v \ v 0 >= base) (st 'vs + now))
                   held (map (p \ p 2) (st 'hv))
                   ((pins st 'vs live 'due (filter (p \ p 0 >= lim) (st 'due)) 'fpos lim),
                    synth-limit st (synth-space st (mixdown (live + held) base synth-chunk))))
 ; ..and out the port (any jug)
 (synth-feed st h) (say h (pack (synth-mix st) synth-chunk (synth-gain * synth-vols (st 'vol))))

 ; --- the keys, by where they sit (set-1 codes) in the window and the tty alike. z to / from c
 ; below middle c, q to ] from middle c, the row above each its sharps ---
 synth-qwerty {44 -12 31 -11 45 -10 32 -9 46 -8 47 -7 34 -6 48 -5 35 -4 49 -3 36 -2 50 -1
               51 0 38 1 52 2 39 3 53 4
               16 0 3 1 17 2 4 3 18 4 19 5 6 6 20 7 7 8 21 9 8 10 22 11 23 12 10 13 24 14
               11 15 25 16 26 17 13 18 27 19}
 ; the knobs: tab, the arrows, f1-f3 and f8 the bus's toggles, f5-f7 and f9 how wet, f4 the
 ; latch, f10 the loop, f11 f12 the volume, enter sends the buffer, pgup pgdn the cps
 synth-knobs {15 'tim 328 'up 336 'down 333 'next 331 'prev
              59 'rev 60 'echo 61 'cho 66 'shm 63 'rvw 64 'ecw 65 'chw 67 'shw
              62 'latch 68 'loop 87 'quieter 88 'louder 28 'send 329 'faster 337 'slower}
 (synth-knob st kn)
  (? (kn = 'tim) (pins st 'tim ((st 'tim + 1) % #(synth-tims st)) 'dirty 1)
     (kn = 'next) (prog st 1)
     (kn = 'prev) (prog st -1)
     (kn = 'up) (pins st 'oct (min (st 'oct + 1) synth-octaves) 'dirty 1)
     (kn = 'down) (pins st 'oct (max (st 'oct - 1) (0 - synth-octaves)) 'dirty 1)
     (kn = 'latch) (synth-latch st)
     (kn = 'loop) (st 'on ? (synth-stop st) (synth-play st))
     (kn = 'send) (tablet? (st 'buf) ? (synth-send st (synth-text (st 'buf 'lines))) st)
     (kn = 'faster) (synth-cps! st (st 'cps + synth-cps-step))
     (kn = 'slower) (synth-cps! st (st 'cps - synth-cps-step))
     (kn = 'quieter) (pins st 'vol (max 0 (st 'vol - 1)) 'dirty 1)
     (kn = 'louder) (pins st 'vol (min (#synth-vols - 1) (st 'vol + 1)) 'dirty 1)
     (fxkey st kn))
 ; a key down at k, the keys' own: a knob turned, else a note sounded by play
 (synth-down st k play) (peep synth-knobs k 0 @ kn
   (kn != 0 ? (synth-knob st kn)
      (peep synth-qwerty k () @ o (charm? o ? (play (12.0 * st 'oct + o)) st))))

 ; --- the tty: its bytes by where they sit, shifted or not; a key with no byte is 1000
 ; past its place ---
 synth-tty (foldl (t \ p \ pin t <p >p) {}
             (zip (chars "zsxdcvgbhnjm,l.;/q2w3er5t6y7ui9o0p[=]")
                  [44 31 45 32 46 47 34 48 35 49 36 50 51 38 52 39 53 16 3 17 4 18 19 6 20 7 21 8 22 23 10 24 11 25 26 13 27]
              + zip (chars "ZSXDCVGBHNJM<L>:?Q@W#ER%T^Y&UI(O)P{+}")
                  [44 31 45 32 46 47 34 48 35 49 36 50 51 38 52 39 53 16 3 17 4 18 19 6 20 7 21 8 22 23 10 24 11 25 26 13 27]))
 (synth-tcode b) (? (999 < b) (b - 1000) (b = 27) 1 (b = 9) 15 (b = 13 || b = 10) 28 (peep synth-tty b ()))
 ; a byte, or a key's code; esc or ^c is the end
 (synth-step st b) (: k (synth-tcode b)
   (? (b = 3 || k = 1) (pins st 'over 1)
      (synth-down st k (s \ (st 'latch ? (synth-drone st s) (synth-strike st s))))))

 ; --- the screen, the tty's and the window's; synth-rows is what the keys' pane is given on
 ; the mitty ---
 synth-rows 15
 (synth-face st how)
  (esc + "[H" + esc + "[2J"
   + (how = 'win ? "synth -- the qwerty rows play while they are held" "synth -- the qwerty rows play, a key a strike that rings and dies")
   + "\r\n\r\n"
   + "  timbre " + synth-tname st + "   octave " + show (st 'oct)
   + "   last " + (string? (st 'last) ? (st 'last) "-") + vline st + "\r\n"
   + synth-lline st + "\r\n"
   + fxline st + "\r\n"
   + "  loop " + (st 'on ? "playing" "stopped") + "   cps " + show (st 'cps)
   + "   cycle " + show (st 'cyc) + "   " + st 'lmsg + "\r\n\r\n"
   + "  z s x d c v g b h n j m , l . ; /       from c below middle c\r\n"
   + "  q 2 w 3 e r 5 t 6 y 7 u i 9 o 0 p [ = ]  from middle c\r\n\r\n"
   + "  tab: timbre   up/down: octave   " + (st 'fm ? "left/right: fm instrument   " "") + "esc: leave\r\n"
   + "  f1 f2 f3 f8: reverb echo chorus shimmer   f5 f6 f7 f9: wetter\r\n"
   + "  f4: latch   f10: the loop   f11 f12: volume   pgup pgdn: cps"
   + (tablet? (st 'buf) ? ("   enter: send\r\n  ctrl-w w: the buffer" + (how = 'tty ? ", or C-a j and C-a k" "")
                           + "; there :send :play :stop :cps N")
         ""))
 (synth-frame st) (synth-face st 'tty)
 (synth-wframe st) (synth-face st 'win)

 ; --- the tty: an escape's tail read whole, so an f key or an arrow is one key ---
 synth-ss3 {80 1059 81 1060 82 1061 83 1062 65 1328 66 1336 67 1333 68 1331}   ; ESC O P..S, A..D
 synth-lnx {65 1059 66 1060 67 1061 68 1062 69 1063}                           ; the console's ESC [ [ A..E
 synth-tilde {11 1059 12 1060 13 1061 14 1062 15 1063 17 1064 18 1065 19 1066 20 1067 21 1068
              23 1087 24 1088 5 1329 6 1337}                                   ; ESC [ N ~
 ; ESC [ a's parameters to its final: a ~ by its first number, a letter as SS3's
 (tcsi p c a) (? (c < 0) 0
                (48 <= c && c <= 63) (tcsi p (see p) (a + string c))
                (c = 126) (: (go i v) (? (i < #a && 48 <= a i && a i <= 57) (go (i + 1) (v * 10 + a i - 48)) v)
                             (peep synth-tilde (go 0 0) 0))
                (peep synth-ss3 c 0))
 (synth-key p) (see p @ c
   (? (c != 27) c
      !(rest 1, cue? p) 27
      (see p @ c2
         (? (c2 = 79) (see p @ f (peep synth-ss3 f 0))
            (c2 = 91) (see p @ c3 (c3 = 91 ? (see p @ f (peep synth-lnx f 0)) (tcsi p c3 "")))
            (unsee p c2, 27)))))
 ; every key waiting, a held key's repeats dropped -> 'quit | the state
 (keys st) (cue? 0 ?
              (synth-key in @ k
                 (? (k = -1) 'quit
                    (k = st 'lk && clock 0 - st 'lt < repeat-gap) (keys st)
                    (synth-step st k, pins st 'lk k 'lt (clock 0), st 'over ? 'quit (keys st))))
              st)
 ; a warm-up into a jug, so the code the keys reach is paged in and the first
 ; collections made before the card is open
 (synth-warm _) (: st (synth-new ()) j (jug 0)
                   (each ^#synth-timbres (i \ (pin st 'tim i, synth-step st 113)),
                    synth-send st "n \"0 [4 7] ~ 12\" # s \"sin\" # gain 0.8",
                    each ^60 (i \ (synth-feed st j, slurp j)),
                    synth-frame st,
                    0))
 ; the horn, () when there is none, and a feed that keeps it a lead ahead
 (synth-horn st) (: hn (horn song-rate 2 @ h (nom? h ? () h)) pace (pacer ())
                    [hn (_ \ (hn ? (song-keep hn pace synth-lead (_ \ (synth-feed st hn))) 0))])
 (synth-run o) (: _ (synth-warm ())
   st (synth-new o)
   hf (synth-horn st) hn <hf feed <>hf
   (go _) (feed (),
           st 'dirty ? (say out (synth-frame st), flush out, pin st 'dirty 0),
           keys st = 'quit || st 'over ? () (rest 4, go ()))
   (ttytake ['hide],
    mind go () (_ \ (hn ? (flush hn, close hn), drain-keys (), ttygive ['hide])),
    0))
 ; --- the window: a note sounds while its key is held. 'hv holds [key semis voice] with no
 ; end; a release fades it into 'vs ---
 (synth-hold st k s)
  (: tm (synth-tims st (st 'tim)) at (st 'fpos) d (tm 1)
     f (261.6255653005986 * exp (s * ln2-12))
     ; an FM note keeps what to sound its own release from
     hs (? (fm? st) [[k s (fmv st s at ()) (st 'fm (st 'prog)) at]]
           (pad? st) (map (v \ [k s v]) (synth-pad (tm 0) s at (at + 3600 * song-rate) ()))
           [[k s (ops-voice (held-ops (tm 0) f d) at (at + 3600 * song-rate) 0.4 0.4 song-rate)]])
     (pins st 'hv (hs + st 'hv) 'rls (pin (st 'rls) k (pad? st ? (synth-pads (tm 0) 'rel) (1.0 / 12)))
              'last (synth-name s) 'dirty 1))
 (fade [e f gl gr] at rl)
  [(at + rl) (ix \ (: g ((at + rl - ix) * (1.0 / rl)) c (g * (g > 0.0))
                     (f ix * (c + (1.0 - c) * (c > 1.0))))) gl gr]
 (synth-free st k)
  (: at (st 'fpos) rl (int (song-rate * peep (st 'rls) k (1.0 / 12)))
     (pins st 'hv (filter (p \ <p != k) (st 'hv))
              'vs (st 'vs + map (p \ #p > 3 ? (opl-voice (p 3) (60.0 + p 1) 100 0.5 (p 4) at song-rate) (fade (p 2) at rl))
                                 (filter (p \ <p = k) (st 'hv)))
              'dirty 1))
 ; the latch: a note struck rings until struck again, its key the semitone past the
 ; window's codes; let go, every note held fades
 (synth-drone st s) (: k (1000.0 + s) (any (p \ <p = k) (st 'hv) ? (synth-free st k) (synth-hold st k s)))
 (synth-latch st) (? (st 'latch) (foldl synth-free (pins st 'latch 0 'dirty 1) (uniq (map (p \ <p) (st 'hv))))
                     (pins st 'latch 1 'dirty 1))
 (synth-lline st) (: ns (foldl (a \ s \ " " + synth-name s + a) "" (uniq (map (p \ p 1) (st 'hv))))
   (? (st 'latch) ("  latched" + ns) (two? (st 'hv)) ("  held" + ns) ""))

 ; --- the window's panes: the keys over the loop's buffer, a horizontal split. ctrl-w w goes
 ; between them, ctrl-w j to the buffer and k to the keys, or a click on one ---
 synth-trows 14                         ; the keys' text rows, the strip under them
 synth-top 352                          ; the keys' pane, in pixels down
 synth-ink 16756784
 synth-mods {42 'shift 54 'shift 29 'ctrl 285 'ctrl 56 'alt 312 'alt}
 ; the keys vi hears that type no text, as edkey answers them
 synth-vis {1 27 28 13 284 13 14 127 15 9 328 -8 336 -9 331 -1 333 -2 327 -5 335 -6 339 -4}
 ; ..and a letter's place under ctrl, its control character
 synth-ctl (foldl (t \ p \ pin t <p >p) {}
             (zip [16 17 18 19 20 21 22 23 24 25 30 31 32 33 34 35 36 37 38 44 45 46 47 48 49 50 26]
                  (map (c \ c - 96) (chars "qwertyuiopasdfghjklzxcvbnm") + [27])))
 ; the panes laid on a window w by h: the buffer's cells under the keys
 (synth-wlay st w h)
  (: rows (max 0 ((h - synth-top) // 16)) cols (w // 8)
     (pins st 'ww w 'wh h 'vrows rows 'vcols cols 'vd 1 'dirty 1
              'scr (0 < rows ? (screen (cask (screen () rows cols)) rows cols) ())))
 ; the buffer vs under the keys, its ex door the loop's words
 (synth-wedit st vi vs w h)
  (: _ (pin vs 'exmore '("send" "play" "stop" "cps"))
     (pins st 'buf vs 'fc (vi 'vi-face vs {'ex (synth-ex st)}), synth-wlay st w h))
 (wfocus st f) (st 'fc ? (pins st 'focus f 'vd 1 'dirty 1) st)
 (wfeed st cs) (: _ (each cs ((st 'fc) 1)) (pins st 'vd 1 'over (st 'buf 'quit ? 1 (st 'over))))
 ; the strip's key at x y, its index of 32 from c an octave under middle c, else ()
 (synth-cell st w h x y)
  (: cw (w // 32) y0 (min synth-trows (h // 16) * 16 + 16) kh (min 96 ((st 'fc ? synth-top h) - y0 - 8))
     (? (x < 0 || 32 * cw <= x || y < y0 || y0 + kh <= y) () (x // cw)))
 ; a finger on the strip: down holds its key's note, a slide takes the next, up lets it go
 (wtouch st i) (: s (12.0 * st 'oct + i - 12)
   (pin st 'tk i, st 'latch ? (synth-drone st s) (synth-hold st 'touch s)))
 (wlift st) (: _ (two? (st 'hv) && !(st 'latch) ? (synth-free st 'touch)) (pin st 'tk ()))
 ; a window record: a key down sounds or turns a knob, a key up lets its note go
 (synth-wstep st r)
  (: e <r k (two? >r ? (r 1) ()) md (peep synth-mods k ()) ms (st 'mods)
     wh [(peep st 'ww 640) (peep st 'wh 400)]
     (? (e = 'close) (pins st 'over 1)
        (e = 'size) (synth-wlay st (r 1) (r 2))
        (e = 'up) (? (md != ()) (pin ms md ()) (st 'latch) st (synth-free st k))
        (e = 'press) (? (st 'fc && synth-top <= r 3) (wfocus st 'vi)
                        (: _ (wfocus st 'keys) i (synth-cell st <wh (wh 1) (r 2) (r 3))
                           (k = 1 && charm? i ? (wtouch st i) st)))
        (e = 'move) (: i (synth-cell st <wh (wh 1) (r 1) (r 2))
                       (charm? (st 'tk) && charm? i && i != st 'tk && !(st 'latch) ? (wlift st, wtouch st i) st))
        (e = 'release) (charm? (st 'tk) ? (wlift st) st)
        (e = 'paste) (st 'focus = 'vi ? ((st 'fc) 3 k, pin st 'vd 1) st)
        (e = 'text) (st 'focus = 'vi && !(ms 'ctrl) && !(ms 'alt) ? (wfeed st (chars k)) st)
        (e != 'down) st
        (md != ()) (pin ms md 1)
        (st 'cw) (: _ (pin st 'cw 0) (k @ 17 (wfocus st (st 'focus = 'vi ? 'keys 'vi)) 36 (wfocus st 'vi) 37 (wfocus st 'keys) _ st))
        (k = 17 && ms 'ctrl && st 'fc && (st 'focus = 'keys || st 'buf 'mode = 'n)) (pin st 'cw 1)
        (st 'focus = 'vi) (? (ms 'ctrl) (peep synth-ctl k () @ c (charm? c ? (wfeed st [c]) st))
                             (peep synth-vis k () @ c (charm? c ? (wfeed st [c]) st)))
        (any (p \ <p = k) (st 'hv)) (st 'latch ? (synth-free st k) st)
        (k = 1) (pins st 'over 1)
        (synth-down st k (s \ synth-hold st k s))))
 ; rw x rh pixels of col (0xrrggbb) at x y
 (fill p w x y rw rh col)
  (? (rw < 1 || rh < 1) 0
     (: n (rw * 4) row (cask n)
        _ (pin row 0 (col & 255), pin row 1 ((col >> 8) & 255), pin row 2 ((col >> 16) & 255))
        (dbl k) (k < n ? (pour row k row 0 (min k (n - k)), dbl (2 * k)) 0)
        (dbl 4, each ^rh (j \ pour p (((y + j) * w + x) * 4) row 0 n))))
 ; a pixel's line round the pane w by h at x y
 (wrim p W x y w h) (: c synth-ink
   (fill p W x y w 1 c, fill p W x (y + h - 1) w 1 c, fill p W x y 1 h c, fill p W (x + w - 1) y 1 h c))
 ; text cells over the top, under them the 32 keys' notes, a held one lit; under the keys
 ; the buffer, when there is one
 (synth-paint st win)
  (: wh (window-size win) w <wh h (wh 1) p (window-paper win)
     top (st 'fc ? (min h synth-top) h)
     c (w // 8) r (min synth-trows (h // 16))
     sc (screen (cask (screen () r c)) r c)
     _ (scribe sc (synth-wframe st))
     _ (each ^r (y \ dye sc p w y -1 0))
     _ (fill p w 0 (r * 16) w (top - r * 16) 0)
     cw (w // 32) y0 (r * 16 + 16) kh (min 96 (top - y0 - 8))
     lit (map (q \ int (q 1 - 12.0 * st 'oct)) (st 'hv))
     _ (each ^32 (i \ (: s (i - 12) sharp (elem ((s + 24) % 12) [1 3 6 8 10])
                         (fill p w (i * cw + 1) y0 (cw - 2) (sharp ? (kh * 3 // 5) kh)
                               (? (elem s lit) 16744448 sharp 3684408 13684944)))))
     (st 'fc ? (synth-vpaint st p w, st 'focus = 'keys ? (wrim p w 0 0 w top)) 0))
 ; ..vi's frame scribed, its rows laid under the keys, and a line round it when it has the keys
 (synth-vpaint st p w)
  (: rows (st 'vrows) cols (st 'vcols) scr (st 'scr) tw (8 * cols)
     (? (rows < 1) 0
        (: fr ((st 'fc) 0 cols rows)
           (? (0 < #fr || st 'vd)
              (: tb (cask (tw * rows * 16 * 4)) cur (gaze scr 0)
                 _ (scribe scr fr)
                 _ (each ^rows (y \ dye scr tb tw y (cur >= 0 && cur // cols = y ? cur -1) ()))
                 _ (each ^(rows * 16) (y \ pour p (4 * ((synth-top + y) * w)) tb (4 * y * tw) (4 * tw)))
                 (pin st 'vd 0, st 'focus = 'vi ? (wrim p w 0 synth-top tw (16 * rows))))
              0))))
 (synth-window o f)
  (: _ (synth-warm ()) st (synth-new o) vi (cite 'vi)
     win (window-open 640 (synth-top + 320) "synth")
     (? !(tablet? win) (say err ("synth: no window (" + show win + ")\n"), flush err, 1)
        (: hf (synth-horn st) hn <hf feed <>hf wh (window-size win)
           _ (tablet? vi ? (synth-wedit st vi (vi 'vi-open f) <wh (wh 1)) (synth-wlay st <wh (wh 1)))
           (go _) (feed (),
                   each (window-events win) (r \ synth-wstep st r),
                   st 'dirty || st 'vd ? (synth-paint st win, window-show win 0 (window-size win 1), pins st 'dirty 0 'vd 0),
                   st 'over ? () (rest 4, go ()))
           (mind go () (_ \ (hn ? (flush hn, close hn), window-close win)),
            0))))
 synth-usage "usage: love synth [--fm FILE] [-w|--window] [LOOP]   (z to / and q to ] play, the rows above them the sharps; tab the timbre, up and down the octave, f1 f2 f3 f8 reverb echo chorus shimmer and f5 f6 f7 f9 wetter, f4 the latch, f10 the loop, f11 f12 the volume, enter sends the buffer, pgup pgdn the cps, ctrl-w w the buffer and back, esc leaves)\n       in a window a note sounds while its key is held, or a finger on the strip of keys; on a tty a key is a strike\n       --fm: an op2 bank or a wad's GENMIDI, its instruments a last timbre, left and right choosing"
 ; --- the mitty: the keys a stage over a vi stage on the loop's text. ctrl-w then w, j or k
 ; goes between them as C-a j and k do ---
 (synth-mitty br vi f o) (: _ (synth-warm ()) st (synth-new o)
   hf (synth-horn st) hn <hf feed <>hf
   sz (br 'hsize 0) hb (br 'mitty-up <sz <>sz)
   buf (vi 'vi-open f)
   _ (pin buf 'exmore '("send" "play" "stop" "cps"))
   _ (pin st 'buf buf)
   face (vi 'vi-face buf {'ex (synth-ex st) 'reg (hb 'clip)})
   (cw d k) (pin st 'cw 0, elem k [119 d] ? (br 'hsteer hb (d = 106 ? 'down 'up)) 0)
   keys (br 'mitty-stage (w \ h \ (pin st 'dirty 0, synth-frame st))
                         (k \ (? (st 'cw) (cw 106 k) (k = 23) (pin st 'cw 1) (synth-step st k)))
                         (_ \ (st 'over)))
   _ (pins keys 'tick (_ \ (feed (), st 'dirty)) 'key synth-key)   ; an f key whole
   text (br 'mitty-stage (face 0)
                         (k \ (? (st 'cw) (cw 107 k) (k = 23 && buf 'mode = 'n) (pin st 'cw 1) (face 1 k)))
                         (_ \ (buf 'quit || st 'over)))
   _ (pin text 'paste (face 3))
   share (min 90 ((100 * (synth-rows + 1) + <sz - 1) // <sz))   ; the keys' rows, and one over
   (pin hb 'more (_ \ ((cite 'mooring 'hopen) ["sh"] 1 1)),
    br 'hberth hb 'stack 50 (br 'hopen-stage keys <sz <>sz),
    br 'hberth hb 'stack share (br 'hopen-stage text 1 1),
    br 'hsteer hb 'up,
    br 'hsail hb,
    hn ? (flush hn, close hn),
    0))
 ; --fm FILE first, its bank read whole or refused; -w or --window anywhere after
 (synth-main as) (: br (cite 'mitty) vi (cite 'vi)
   fw (two? as && <as = "--fm") f (fw && two? >as ? <>as "")
   fm (fw ? (uread f @ r (opl-bank (two? r ? (r 1) ""))) ())
   rs0 (fw ? (two? >as ? >>as ()) as) o {'fm fm}
   wn (any (a \ elem a ["-w" "--window"]) rs0)
   rs (filter (a \ !(elem a ["-w" "--window"])) rs0)
   (? (fw && atom? fm) (say err ("synth: " + f + ": no FM bank (an op2 file, or a wad with GENMIDI)\n"), flush err, 1)
      (1 < #rs) (say err ("synth: " + synth-usage + "\n"), flush err, 2)
      wn (synth-window o (two? rs ? <rs ""))
      (tablet? br && tablet? vi) (synth-mitty br vi (two? rs ? <rs "") o)
      (synth-run o)))
 _ (pins (cite 'verbs 'tab) 'synth (udoor 'synth synth-main synth-usage 1 1)))
) ; module synth
