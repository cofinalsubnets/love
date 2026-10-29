; synth -- a keyboard to pick a tune out on: the number row plays harp's voices out the horn.
; 1 is middle c, each key a semitone up; shift an octave up, alt a quarter tone down. a key
; is a strike that rings and dies: a tty never says a key was let go. the horn is fed at
; least an eighth of a second ahead, longer than the runtime's pauses (synth-warm takes the
; first early). a backing loop (harp's pattern text) is a vi buffer under the keys; d plays
; in just intonation. --fm FILE adds a last timbre from an op2 bank or a wad's GENMIDI. the
; mix goes through a bus of chorus, echo and reverb (space.c), each on its own key. the pads
; (pad, glass, wash) swell in through a filter a slow lfo sweeps, and fade slowly once let go.
; { and } (f11 f12 in the window) turn the volume, the horn's own, past any mixer.
; run: love synth [--fm FILE] [LOOP]   HORN=none plays silent on a seat with no card
(module (synth synth-run synth-main synth-new synth-step synth-code synth-semis synth-name
         synth-strike synth-feed synth-frame synth-key synth-timbres synth-shifted synth-digits
         synth-chunk synth-lead synth-octaves synth-send synth-play synth-stop synth-pull
         synth-cps! synth-cps synth-cps-step synth-cps-lo synth-cps-hi synth-text synth-ex
         synth-just synth-sept synth-jdeg synth-dopts synth-drift synth-lname synth-map synth-kmodes
         synth-qwerty synth-hold synth-free synth-drone synth-latch synth-wstep synth-wframe synth-paint synth-window synth-trows
         synth-tims synth-tname synth-space synth-wets synth-fx synth-mix synth-gain synth-ftail synth-stail synth-ceil synth-limit
         synth-vols synth-vol0
         synth-pads synth-pad)
(borrow 'rove)
(borrow 'harp)
(borrow 'play)
(borrow 'just)
(borrow 'drift)
(borrow 'phrases)
(borrow 'posix)
(borrow 'window)
(borrow 'opl)
(borrow 'ops)
(:
 esc (string 27)
 synth-digits "1234567890-="
 synth-shifted "!@#$%^&*()_+"
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
 synth-cps-step 0.05                    ; and what [ and ] move it by
 synth-cps-lo 0.1
 synth-cps-hi 4.0

 ; the loop's state: 'pat playing, 'nextp sent since, 'cyc the next cycle to pull and
 ; 'cstart its frame, 'due voices pulled but not begun as [start voice]. the drift's:
 ; 'dw the walk's next state, 'dnow the one sounding, 'dprev the last choice
 (synth-new o) {'fm (tablet? o ? (peep o 'fm ()) ()) 'prog 0 'oct 0 'tim 0 'vs () 'due () 'fpos 0 'last () 'lk 0 'lt 0 'dirty 1
                'pat () 'nextp () 'on 0 'cyc 0 'cstart 0 'cps synth-cps 'lmsg "" 'over 0
                'dr 0 'dw () 'dnow () 'dprev [() ()] 'dph "" 'trail () 'dbook 3
                'dlean 1.5 'dsteer 1.0 'dhome 0.1 'km 0 'hv ()
                'rev 0 'rvw 2 'echo 0 'ecw 1 'cho 0 'chw 2 'shm 0 'shw 2 'fxm () 'fxt 0 'rls {} 'latch 0 'lim () 'vol synth-vol0}
 synth-kmodes ["fixed" "follow" "just"]

 ; --- just intonation: the row's twelve over the center, and alt's septimal ones
 synth-just [1 (16 /// 15) (9 /// 8) (6 /// 5) (5 /// 4) (4 /// 3) (45 /// 32) (3 /// 2)
             (8 /// 5) (5 /// 3) (9 /// 5) (15 /// 8)]
 synth-sept {2 (8 /// 7) 3 (7 /// 6) 4 (9 /// 7) 6 (7 /// 5) 9 (12 /// 7) 10 (7 /// 4)}
 (synth-jdeg [i sh al]) (al ? (peep synth-sept i (synth-just i)) (synth-just i))
 (synth-dopts st) {'lean (st 'dlean) 'home (st 'dhome) 'steer (st 'dsteer)
                   'cost 0.1 'wc 1.0 'fresh 2.0}
 ; on: a walk from home, playing from the next frame; off: the loop stops
 (rshow r) (jparts r @ p (<>p = 1 ? (show <p) (show <p + "/" + show <>p)))
 (synth-drift st) (st 'dr ? (pins st 'dr 0 'lmsg "" 'dirty 1, synth-stop st)
                     (drift-new (synth-dopts st) @ w
                        (pins st 'dr 1 'dw w 'dnow w 'dprev [() ()] 'trail () 'on 0 'dirty 1,
                         synth-play st)))
 (dcycle st) (: o (synth-dopts st) w (st 'dw) b (book (st 'dbook))
                pk (drift-pick o w (st 'dprev) (map (p \ p 1) (b 1)))
                nm ((: (go l) (? !(two? l) "" (<l 1 = pk 0) (<l 0) (go >l))) (b 1))
                ((pins st 'dprev pk 'dph nm 'dnow w 'dw (drift-step o w (pk 0))
                          'trail (take 8 (w 'pos . st 'trail)) 'dirty 1),
                 pset (pset (phrase-pat (w 'tonic) (pk 0))
                            (hit (pure (synth-tims st (st 'tim) 0 @ "fm" "sin" n n))))
                      (gain (pure 0.45))))
 ; a lattice point's name: its letter along the fifths, - or + per syntonic comma, 7 or /7
 (synth-lname v)
  (: b (v 0) c (v 1) d (v 2) k (b + 4 * c - 2 * d + 1)
     m (k % 7 < 0 ? (k % 7 + 7) (k % 7)) a ((k - m) // 7)
     (rep s n) (n < 1 ? "" (s + rep s (n - 1)))
     (string ("FCGDAEB" m) + rep "#" a + rep "b" (0 - a) + rep "-" c + rep "+" (0 - c)
             + rep "7" d + rep "/7" (0 - d)))
 ; the lattice round the center: rows of thirds, columns of fifths, center bracketed, trail starred
 (synth-map st)
  (: p ((st 'dnow) 'pos)
     (cell b c) (: q [b c (p 2)] n (synth-lname q)
                   t (q = p ? ("[" + n + "]") (elem q (st 'trail) ? ("*" + n) (" " + n)))
                   (t + snip "        " 0 (8 - #t)))
     (row c) ("  " + foldl (+) "" (map (i \ cell (p 0 - 3 + i) c) ^7) + "\r\n")
     (row (p 1 + 1) + row (p 1) + row (p 1 - 1)))

 ; --- a key into a note ---
 ; a key is the byte, or 256 past it with alt; a note is [degree shift alt], else ()
 (spot s c) (:- (go 0) (go n) (n < #s ? (s n = c ? n (go (n + 1))) -1))
 (synth-code k) (: alt (255 < k) c (alt ? (k - 256) k)
                   i (spot synth-digits c) j (spot synth-shifted c)
                   (? (0 <= i) [i 0 alt] (0 <= j) [j 1 alt] ()))
 ; semitones from middle c. while the drift plays, follow roots the equal row on the
 ; center and just lays the ratios over it
 (synth-semis st [i sh al])
  (: km (st 'dr ? (st 'km) 0) o (12.0 * (st 'oct + sh))
     (? (km = 2) (semis (st 'dnow 'tonic * synth-jdeg [i sh al]) + o)
        (km = 1) (semis (st 'dnow 'tonic) + o + i - 0.5 * al)
        (o + i - 0.5 * al)))
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
         p (st 'dr ? (dcycle st) (st 'pat)) c (st 'cyc) f0 (st 'cstart) spc (int (song-rate / st 'cps))
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
 ; [toggle wet-step name], with the toggling key and the stepping one
 synth-fx [['rev 'rvw "reverb" 114 82] ['echo 'ecw "echo" 111 79] ['cho 'chw "chorus" 99 67]
           ['shm 'shw "shimmer" 115 83]]
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
 (fxkey st k) (: (go l) (? (atom? l) ()
                          (k = <l 3) (pins st (<l 0) (1 - st (<l 0)) 'dirty 1)
                          (k = <l 4) (pins st (<l 1) ((st (<l 1) + 1) % #synth-wets) 'dirty 1)
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

 ; --- a key; q or ^c is the end ---
 (synth-step st k) (synth-code k @ c
   (? (two? c) (? (st 'latch) (synth-drone st (synth-semis st c))
                  (synth-strike st (synth-semis st c) @ s2
                     (st 'dr && st 'km = 2 ? (pins s2 'last (rshow (synth-jdeg c) + " " + synth-name (synth-semis st c))) s2)))
      (k = 9) (pins st 'tim ((st 'tim + 1) % #(synth-tims st)) 'dirty 1)
      (k = -10) (prog st 1)
      (k = -11) (prog st -1)
      (k = -8) (pins st 'oct (min (st 'oct + 1) synth-octaves) 'dirty 1)
      (k = -9) (pins st 'oct (max (st 'oct - 1) (0 - synth-octaves)) 'dirty 1)
      (k = 112) (st 'on ? (synth-stop st) (synth-play st))
      (k = 91) (synth-cps! st (st 'cps - synth-cps-step))
      (k = 93) (synth-cps! st (st 'cps + synth-cps-step))
      (k = 100) (synth-drift st)
      (k = 44) (pins st 'dsteer (max -2.0 (st 'dsteer - 0.25)) 'dirty 1)
      (k = 46) (pins st 'dsteer (min 2.0 (st 'dsteer + 0.25)) 'dirty 1)
      (k = 59) (pins st 'dlean (max -4.0 (st 'dlean - 0.5)) 'dirty 1)
      (k = 39) (pins st 'dlean (min 4.0 (st 'dlean + 0.5)) 'dirty 1)
      (k = 104) (pins st 'dhome (st 'dhome @ 0.0 0.1 0.1 0.3 0.0) 'dirty 1)
      (k = 107) (pins st 'km ((st 'km + 1) % #synth-kmodes) 'dirty 1)
      (k = 118) (pins st 'dbook ((st 'dbook + 1) % #phrase-books) 'dirty 1)
      (k = 108) (synth-latch st)
      (k = 123) (pins st 'vol (max 0 (st 'vol - 1)) 'dirty 1)
      (k = 125) (pins st 'vol (min (#synth-vols - 1) (st 'vol + 1)) 'dirty 1)
      (k = 113 || k = 3) (pins st 'over 1)
      (fxkey st k @ () st r r)))

 ; --- the screen; synth-rows is what the keys' pane is given on the mitty ---
 synth-rows 18
 (synth-frame st) (: tm [(synth-tname st)]
   (cell i) (synth-name (synth-semis st [i 0 0]) @ n
               (string (synth-digits i) + " " + n + snip "     " 0 (6 - #n)))
   (row a) ("  " + foldl (+) "" (map (i \ cell (a + i)) ^6) + "\r\n")
   (esc + "[H" + esc + "[2J"
    + "synth -- the row plays, from middle c a semitone a key\r\n\r\n"
    + "  timbre " + tm 0 + "   octave " + show (st 'oct)
    + "   last " + (string? (st 'last) ? (st 'last) "-") + vline st + synth-lline st + "\r\n"
    + row 0 + row 6 + "\r\n"
    + "  loop " + (st 'on ? "playing" "stopped") + "   cps " + show (st 'cps)
    + "   cycle " + show (st 'cyc) + "   " + st 'lmsg + "\r\n"
    + (st 'dr ? (st 'dnow @ w
                   ("  drift " + book (st 'dbook) 0 + "   phrase " + st 'dph
                    + "   center " + synth-lname (w 'pos) + " " + rshow (w 'tonic)
                    + " " + show (int (drift-cents w)) + "c\r\n"
                    + "  lean " + show (st 'dlean) + "   steer " + show (st 'dsteer)
                    + "   home " + show (st 'dhome) + "   keys " + synth-kmodes (st 'km) + "\r\n" + synth-map st))
                "  drift off\r\n")
    + fxline st + "\r\n"
    + (st 'dr && st 'km = 2 ? "  shift: octave up   alt: septimal   tab: timbre"
               "  shift: octave up   alt: quarter tone down   tab: timbre")
    + (st 'fm ? "   left/right: fm instrument\r\n" "\r\n")
    + "  up/down: octave   r o c s: the bus, shifted wetter   l: latch   { }: volume\r\n"
    + "  d: drift   k: keys   , .: steer   ; ': lean   h: home   v: book\r\n"
    + "  p: play/stop   e: send buffer   [ ]: cps   C-a j: buffer   q: leave"))

 ; --- the tty: alt as the escape before a key, arrows as the cli's numbers ---
 (synth-key p) (see p @ c
   (? (c != 27) c
      !(rest 1, cue? p) 27
      (see p @ c2
         (c2 = 91 ? (: (fin _) (see p @ f (64 <= f <= 126 ? (f @ 65 -8 66 -9 67 -10 68 -11 0) (fin ()))) (fin ()))
                    (256 + c2)))))
 ; every key waiting, a held key's repeats dropped -> 'quit | the state
 (keys st) (cue? 0 ?
              (synth-key in @ k
                 (? (k = 113 || k = 3 || k = -1) 'quit
                    (k = st 'lk && clock 0 - st 'lt < repeat-gap) (keys st)
                    (synth-step st k, pins st 'lk k 'lt (clock 0), keys st)))
              st)
 ; a warm-up into a jug, so the code the keys reach is paged in and the first
 ; collections made before the card is open
 (synth-warm _) (: st (synth-new ()) j (jug 0)
                   (each ^#synth-timbres (i \ (pin st 'tim i, synth-step st 49)),
                    synth-send st "n \"0 [4 7] ~ 12\" # s \"sin\" # gain 0.8",
                    each ^60 (i \ (synth-feed st j, slurp j)),
                    synth-drift st,
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
 ; --- the window: a note sounds while its key is held. z to / from c below middle c, q to ]
 ; from middle c, the row above each its sharps. 'hv holds [key semis voice] with no end;
 ; a release fades it into 'vs ---
 synth-qwerty {44 -12 31 -11 45 -10 32 -9 46 -8 47 -7 34 -6 48 -5 35 -4 49 -3 36 -2 50 -1
               51 0 38 1 52 2 39 3 53 4
               16 0 3 1 17 2 4 3 18 4 19 5 6 6 20 7 7 8 21 9 8 10 22 11 23 12 10 13 24 14
               11 15 25 16 26 17 13 18 27 19}
 synth-wknobs {15 9 333 -10 331 -11 328 -8 336 -9    ; tab and the arrows: the keys' knobs
               59 114 60 111 61 99 63 82 64 79 65 67    ; f1-f3 the bus's toggles, f5-f7 how wet
               66 115 67 83                             ; f8 the shimmer, f9 how deep
               62 108                                   ; f4 the latch
               87 123 88 125}                           ; f11 f12 the volume
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
 (synth-lline st) (st 'latch ? ("   latched" + foldl (a \ s \ " " + synth-name s + a) "" (uniq (map (p \ p 1) (st 'hv)))) "")
 ; a window record: a key down sounds or turns a knob, a key up lets its note go
 (synth-wstep st r)
  (: e <r k (r 1)
     (? (e = 'close) (pins st 'over 1)
        (e = 'up) (st 'latch ? st (synth-free st k))
        (e = 'size) (pins st 'dirty 1)
        (e != 'down) st
        (any (p \ <p = k) (st 'hv)) (st 'latch ? (synth-free st k) st)
        (k = 1) (pins st 'over 1)
        (peep synth-wknobs k () @ c
           (charm? c ? (synth-step st c)
              (peep synth-qwerty k () @ o (charm? o ? (synth-hold st k (12.0 * st 'oct + o)) st))))))
 (synth-wframe st)
  (esc + "[H" + esc + "[2J"
   + "synth -- the qwerty rows play while they are held\r\n\r\n"
   + "  timbre " + synth-tname st + "   octave " + show (st 'oct)
   + "   last " + (string? (st 'last) ? (st 'last) "-") + vline st + "\r\n"
   + (st 'latch ? "  latched" "  held") + foldl (a \ s \ " " + synth-name s + a) "" (uniq (map (p \ p 1) (st 'hv))) + "\r\n"
   + fxline st + "\r\n\r\n"
   + "  z s x d c v g b h n j m , l . ; /       from c below middle c\r\n"
   + "  q 2 w 3 e r 5 t 6 y 7 u i 9 o 0 p [ = ]  from middle c\r\n\r\n"
   + "  tab: timbre   up/down: octave   " + (st 'fm ? "left/right: fm instrument   " "") + "esc: leave\r\n"
   + "  f1 f2 f3 f8: reverb echo chorus shimmer   f5 f6 f7 f9: wetter   f4: latch   f11 f12: volume")
 ; rw x rh pixels of col (0xrrggbb) at x y
 (fill p w x y rw rh col)
  (? (rw < 1 || rh < 1) 0
     (: n (rw * 4) row (cask n)
        _ (pin row 0 (col & 255), pin row 1 ((col >> 8) & 255), pin row 2 ((col >> 16) & 255))
        (dbl k) (k < n ? (pour row k row 0 (min k (n - k)), dbl (2 * k)) 0)
        (dbl 4, each ^rh (j \ pour p (((y + j) * w + x) * 4) row 0 n))))
 ; text cells over the top, under it the 32 keys' notes, a held one lit
 synth-trows 12
 (synth-paint st win)
  (: wh (window-size win) w <wh h (wh 1) p (window-paper win)
     c (w // 8) r (min synth-trows (h // 16))
     sc (screen (cask (screen () r c)) r c)
     _ (scribe sc (synth-wframe st))
     _ (each ^r (y \ dye sc p w y -1 0))
     _ (fill p w 0 (r * 16) w (h - r * 16) 0)
     cw (w // 32) y0 (r * 16 + 16) kh (min 96 (h - y0 - 8))
     lit (map (q \ synth-qwerty <q) (st 'hv))
     (each ^32 (i \ (: s (i - 12) sharp (elem ((s + 24) % 12) [1 3 6 8 10])
                       (fill p w (i * cw + 1) y0 (cw - 2) (sharp ? (kh * 3 // 5) kh)
                             (? (elem s lit) 16744448 sharp 3684408 13684944))))))
 (synth-window o)
  (: _ (synth-warm ()) st (synth-new o)
     win (window-open 640 400 "synth")
     (? !(tablet? win) (say err ("synth: no window (" + show win + ")\n"), flush err, 1)
        (: hf (synth-horn st) hn <hf feed <>hf
           (go _) (feed (),
                   each (window-events win) (r \ synth-wstep st r),
                   st 'dirty ? (synth-paint st win, window-show win 0 (window-size win 1), pin st 'dirty 0),
                   st 'over ? () (rest 4, go ()))
           (mind go () (_ \ (hn ? (flush hn, close hn), window-close win)),
            0))))
 synth-usage "usage: love synth [--fm FILE] [LOOP]   (1 .. = play, shift and alt bend, tab the timbre, up and down the octave, p e [ ] the loop, r o c s reverb echo chorus shimmer, l the latch, { } the volume, q leaves)\n       love synth [--fm FILE] -w      (a window: the qwerty rows sound while held)\n       --fm: an op2 bank or a wad's GENMIDI, its instruments a last timbre, left and right choosing"
 ; --- the mitty: the keys a stage over a vi stage on the loop's text ---
 (synth-mitty br vi f o) (: _ (synth-warm ()) st (synth-new o)
   hf (synth-horn st) hn <hf feed <>hf
   sz (br 'hsize 0) hb (br 'mitty-up <sz <>sz)
   buf (vi 'vi-open f)
   _ (pin buf 'exmore '("send" "play" "stop" "cps"))
   face (vi 'vi-face buf {'ex (synth-ex st) 'reg (hb 'clip)})
   keys (br 'mitty-stage (w \ h \ (pin st 'dirty 0, synth-frame st))
                         (k \ (k = 101 ? (synth-send st (synth-text (buf 'lines))) (synth-step st k)))
                         (_ \ (st 'over)))
   _ (pins keys 'tick (_ \ (feed (), st 'dirty)) 'key synth-key)   ; alt on any key
   text (br 'mitty-stage (face 0) (face 1) (_ \ (buf 'quit || st 'over)))
   _ (pin text 'paste (face 3))
   share (min 90 ((100 * (synth-rows + 1) + <sz - 1) // <sz))   ; the keys' rows, and one over
   (pin hb 'more (_ \ ((cite 'mooring 'hopen) ["sh"] 1 1)),
    br 'hberth hb 'stack 50 (br 'hopen-stage keys <sz <>sz),
    br 'hberth hb 'stack share (br 'hopen-stage text 1 1),
    br 'hsteer hb 'up,
    br 'hsail hb,
    hn ? (flush hn, close hn),
    0))
 ; --fm FILE first, its bank read whole or refused
 (synth-main as) (: br (cite 'mitty) vi (cite 'vi)
   fw (two? as && <as = "--fm") f (fw && two? >as ? <>as "")
   fm (fw ? (uread f @ r (opl-bank (two? r ? (r 1) ""))) ())
   rs (fw ? (two? >as ? >>as ()) as) o {'fm fm}
   (? (fw && atom? fm) (say err ("synth: " + f + ": no FM bank (an op2 file, or a wad with GENMIDI)\n"), flush err, 1)
      (rs = ["-w"]) (synth-window o)
      (1 < #rs) (say err ("synth: " + synth-usage + "\n"), flush err, 2)
      (tablet? br && tablet? vi) (synth-mitty br vi (two? rs ? <rs "") o)
      (synth-run o)))
 _ (pins (cite 'verbs 'tab) 'synth (udoor 'synth synth-main synth-usage 1 1)))
) ; module synth
