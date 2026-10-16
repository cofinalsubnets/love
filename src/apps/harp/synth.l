; synth -- a keyboard to pick a tune out on: the number row plays notes out the horn
; on harp's voices, a screen says which.
;
; 1 is middle c, each key along the row a semitone up; shift an octave up, alt a
; quarter tone down (alt arrives as an escape first, read by synth-key). a key is a
; strike that rings and dies: a tty never says a key was let go.
; the horn is fed a small chunk at a time, at least an eighth of a second ahead of the
; speaker -- longer than the runtime's pauses, whose first ones synth-warm takes early.
; a backing loop (harp's pattern text) is a vi buffer in a pane under the keys; a new
; pattern takes over at a cycle's start. d plays in just intonation (drift.l, phrases.l).
; all but synth-run is pure and gated by test/host/synth.l.
;
; with --fm FILE, a last timbre plays the FM instruments of an op2 bank or a wad's GENMIDI
; (opl.l), left and right choosing which.
;
; run: love synth [--fm FILE] [LOOP]   HORN=none plays silent on a seat with no card
(module (synth synth-run synth-main synth-new synth-step synth-code synth-semis synth-name
         synth-strike synth-feed synth-frame synth-key synth-timbres synth-shifted synth-digits
         synth-chunk synth-lead synth-octaves synth-send synth-play synth-stop synth-pull
         synth-cps! synth-cps synth-cps-step synth-cps-lo synth-cps-hi synth-text synth-ex
         synth-just synth-sept synth-jdeg synth-dopts synth-drift synth-lname synth-map synth-kmodes
         synth-qwerty synth-hold synth-free synth-wstep synth-wframe synth-paint synth-window synth-trows
         synth-tims synth-tname)
(borrow 'rove)                          ; the pacer, the song's rate and its lead's ceiling
(borrow 'harp)                          ; the patterns: a cycle's events
(borrow 'play)                          ; the voices, the mix, and harp-read for the text
(borrow 'just)                          ; ratios, cents, the lattice
(borrow 'drift)                         ; the walk and its chooser
(borrow 'phrases)                       ; its books
(borrow 'posix)    ; close, for the horn
(borrow 'window)   ; -w: the qwerty rows held, in a window of its own
(borrow 'opl)      ; --fm: the FM instruments
(:
 esc (string 27)
 synth-digits "1234567890-="           ; the row, a semitone a key
 synth-shifted "!@#$%^&*()_+"           ; the same keys under shift, on a us keymap
 ; the pitched voices of harp's kit, each with how long a strike rings
 synth-timbres [["sin" 1.2] ["tri" 1.2] ["saw" 0.9] ["sqr" 0.9] ["box" 1.6] ["chime" 3.0]]
 synth-octaves 3                        ; up or down from middle c's
 synth-chunk (song-rate // 60)          ; a feed, in frames
 synth-lead (song-rate // 8)            ; the least queued ahead of the speaker
 synth-gain 11000.0
 names ["C" "C#" "D" "D#" "E" "F" "F#" "G" "G#" "A" "A#" "B"]
 synth-cps 0.5                          ; cycles a second the loop starts at
 synth-cps-step 0.05                    ; ..and what [ and ] move it by
 synth-cps-lo 0.1
 synth-cps-hi 4.0

 ; the loop rides the state: 'pat the pattern playing, 'nextp the one sent since,
 ; 'on, 'cyc the next cycle to pull and 'cstart the frame it starts on, 'due the
 ; voices pulled but not begun as [start voice], 'lmsg the loop's last word for the
 ; screen
 ; the drift rides it too: 'dr on, 'dw the walk's next state and 'dnow the one sounding,
 ; 'dprev the last choice, 'dph its name, 'trail the centers behind, and the knobs
 (synth-new o) {'fm (tablet? o ? (peep o 'fm ()) ()) 'prog 0 'oct 0 'tim 0 'vs () 'due () 'fpos 0 'last () 'lk 0 'lt 0 'dirty 1
                'pat () 'nextp () 'on 0 'cyc 0 'cstart 0 'cps synth-cps 'lmsg "" 'over 0
                'dr 0 'dw () 'dnow () 'dprev [() ()] 'dph "" 'trail () 'dbook 3
                'dlean 1.5 'dsteer 1.0 'dhome 0.1 'km 0 'hv ()}
 synth-kmodes ["fixed" "follow" "just"]

 ; --- just intonation: the row's twelve over the center, and the septimal ones alt takes
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
 ; the cycle's phrase: chosen over the center now, which then steps on
 (dcycle st) (: o (synth-dopts st) w (st 'dw) b (book (st 'dbook))
                pk (drift-pick o w (st 'dprev) (map (p \ p 1) (b 1)))
                nm ((: (go l) (? !(two? l) "" (<l 1 = pk 0) (<l 0) (go >l))) (b 1))
                ((pins st 'dprev pk 'dph nm 'dnow w 'dw (drift-step o w (pk 0))
                          'trail (take 8 (w 'pos . st 'trail)) 'dirty 1),
                 pset (pset (phrase-pat (w 'tonic) (pk 0))
                            (hit (pure (synth-tims st (st 'tim) 0 @ "fm" "sin" n n))))
                      (gain (pure 0.45))))
 ; a lattice point's name: its letter along the fifths (a third is four), then a - for
 ; each syntonic comma under the pythagorean one, a + over, and 7 or /7 for the sevenths
 (synth-lname v)
  (: b (v 0) c (v 1) d (v 2) k (b + 4 * c - 2 * d + 1)
     m (k % 7 < 0 ? (k % 7 + 7) (k % 7)) a ((k - m) // 7)
     (rep s n) (n < 1 ? "" (s + rep s (n - 1)))
     (string ("FCGDAEB" m) + rep "#" a + rep "b" (0 - a) + rep "-" c + rep "+" (0 - c)
             + rep "7" d + rep "/7" (0 - d)))
 ; the lattice round the center: three rows of thirds, seven columns of fifths, the
 ; center bracketed, its trail starred
 (synth-map st)
  (: p ((st 'dnow) 'pos)
     (cell b c) (: q [b c (p 2)] n (synth-lname q)
                   t (q = p ? ("[" + n + "]") (elem q (st 'trail) ? ("*" + n) (" " + n)))
                   (t + snip "        " 0 (8 - #t)))
     (row c) ("  " + foldl (+) "" (map (i \ cell (p 0 - 3 + i) c) ^7) + "\r\n")
     (row (p 1 + 1) + row (p 1) + row (p 1 - 1)))

 ; --- a key into a note ---------------------------------------------------------------
 ; a key is the byte, or 256 past it with alt held; a digit or its shifted mate is a
 ; note: [degree shift alt], and any other key ()
 (spot s c) (:- (go 0) (go n) (n < #s ? (s n = c ? n (go (n + 1))) -1))
 (synth-code k) (: alt (255 < k) c (alt ? (k - 256) k)
                   i (spot synth-digits c) j (spot synth-shifted c)
                   (? (0 <= i) [i 0 alt] (0 <= j) [j 1 alt] ()))
 ; semitones from middle c: up the row, the octave and one more for shift, a quarter
 ; tone down for alt
 ; the keys' mode matters only while the drift plays: follow roots the equal row on the
 ; center, just lays the ratios over it
 (synth-semis st [i sh al])
  (: km (st 'dr ? (st 'km) 0) o (12.0 * (st 'oct + sh))
     (? (km = 2) (semis (st 'dnow 'tonic * synth-jdeg [i sh al]) + o)
        (km = 1) (semis (st 'dnow 'tonic) + o + i - 0.5 * al)
        (o + i - 0.5 * al)))
 ; a note's name: the semitone under it and its octave, and the quarter tone said in cents
 (synth-name s) (: t (int s) n (s < t ? (t - 1) t)
                   o (n < 0 ? ((n - 11) // 12) (n // 12))
                   (names (n - 12 * o) + show (4 + o) + (n < s ? " +50c" "")))

 ; --- the timbres: harp's, and with a bank the FM one last, its instrument 'prog ---
 (synth-tims st) (st 'fm ? (synth-timbres + [["fm" 2.0]]) synth-timbres)
 (synth-tname st) (synth-tims st (st 'tim) 0 @ "fm" ("fm " + show (st 'prog) + " " + st 'fm (st 'prog) 'name) n n)
 (fm? st) (synth-tims st (st 'tim) 0 = "fm")
 (fmv st s at off) (opl-voice (st 'fm (st 'prog)) (60.0 + s) 100 0.5 at off song-rate)
 (prog st d) (st 'fm ? (pins st 'prog ((st 'prog + d + 175) % 175) 'dirty 1) st)
 ; --- a strike: a voice from the next frame to be written --------------------------
 (synth-strike st s) (: tm (synth-tims st (st 'tim))
                        v (fm? st ? (fmv st s (st 'fpos) (st 'fpos + int (tm 1 * song-rate)))
                                    (mkvoice (st 'fpos) {'s (tm 0) 'note s 'gain 0.8 'pan 0.5 'legato (tm 1)} song-rate))
                        (pins st 'vs (st 'vs + [v]) 'last (synth-name s) 'dirty 1))
 ; --- the loop -----------------------------------------------------------------
 ; the text sent: harp-read's reading of it, under a trap -- a bad one answers its
 ; complaint and the loop keeps what it had. an empty text is hush. sending starts
 ; the loop if it stood
 (synth-text ls) (foldl (a \ l \ a + "\n" + l) <ls >ls)
 (synth-send st text) (: t (strip text)
                         r (0 = #t ? hush
                              (trap (_ \ harp-read t) () (a \ b \ ['bad (show a + " " + show b)])))
                         (two? r ? (pins st 'lmsg <>r 'dirty 1)
                            (pins st 'nextp r 'lmsg "sent" 'dirty 1,
                             st 'on ? st (synth-play st))))
 ; play: from the next frame written, cycle 0; stop: no more pulled, what has not
 ; begun dropped, what rings rings out
 (synth-play st) (st 'on ? st (pins st 'on 1 'cyc 0 'cstart (st 'fpos) 'dirty 1))
 (synth-stop st) (pins st 'on 0 'due () 'dirty 1)
 (synth-cps! st v) (pins st 'cps (v < synth-cps-lo ? synth-cps-lo (synth-cps-hi < v ? synth-cps-hi v)) 'dirty 1)
 ; the cycles starting before frame lim, their onsets as voices from their frames, kept
 ; with their start until it comes: a voice not begun is silent but not free, its closure
 ; runs over every frame of a chunk, and a cycle is pulled whole. a pattern sent takes
 ; over at a cycle's start. cycle time is a rational and frame time an integer: qnum is
 ; the one crossing, as in play's own run
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
 ; the buffer's ex words, vi's door: answers true for one of the loop's
 (synth-ex st s w arg) (: (num t) (: v <(sound t) (charm? v ? v ()))
   (? (w = "send") (synth-send st (synth-text (s 'lines)), pin s 'msg (st 'lmsg), 1)
      (w = "play") (synth-play st, pin s 'msg "playing", 1)
      (w = "stop") (synth-stop st, pin s 'msg "stopped", 1)
      (w = "cps") (num arg @ v
                     (v ? (synth-cps! st v),
                      pin s 'msg (v ? ("cps " + show (st 'cps)) "cps N"),
                      1))
      ()))

 ; one chunk out the port: the loop's next cycles pulled in, the voices due in this
 ; chunk taken up, and the voices still ringing summed. the port is any jug
 (synth-feed st h) (: base (st 'fpos) lim (base + synth-chunk)
                      _ (synth-pull st lim)
                      now (map (p \ p 1) (filter (p \ p 0 < lim) (st 'due)))
                      live (filter (v \ v 0 >= base) (st 'vs + now))
                      held (map (p \ p 2) (st 'hv))
                      ((pins st 'vs live 'due (filter (p \ p 0 >= lim) (st 'due)) 'fpos lim),
                       say h (pack (mixdown (live + held) base synth-chunk) synth-chunk synth-gain)))

 ; --- a key: a note struck, the timbre or the octave turned, the loop played or
 ; stopped and its cps moved; q or ^c is the end ---
 (synth-step st k) (synth-code k @ c
   (? (two? c) (synth-strike st (synth-semis st c) @ s2
                  (st 'dr && st 'km = 2 ? (pins s2 'last (rshow (synth-jdeg c) + " " + synth-name (synth-semis st c))) s2))
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
      (k = 113 || k = 3) (pins st 'over 1)
      st))

 ; --- the screen: what stands, and what the row plays now, six keys to a line; so
 ; many rows, which is what the keys' pane is given on the mitty --------------------
 synth-rows 16
 (synth-frame st) (: tm [(synth-tname st)]
   (cell i) (synth-name (synth-semis st [i 0 0]) @ n
               (string (synth-digits i) + " " + n + snip "     " 0 (6 - #n)))
   (row a) ("  " + foldl (+) "" (map (i \ cell (a + i)) ^6) + "\r\n")
   (esc + "[H" + esc + "[2J"
    + "synth -- the row plays, from middle c a semitone a key\r\n\r\n"
    + "  timbre " + tm 0 + "   octave " + show (st 'oct)
    + "   last " + (string? (st 'last) ? (st 'last) "-") + "\r\n"
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
    + (st 'dr && st 'km = 2 ? "  shift: octave up   alt: septimal   tab: timbre   up/down: octave"
               "  shift: octave up   alt: quarter tone down   tab: timbre   up/down: octave")
    + (st 'fm ? "   left/right: fm instrument\r\n" "\r\n")
    + "  d: drift   k: keys   , .: steer   ; ': lean   h: home   v: book\r\n"
    + "  p: play/stop loop   e: send buffer   [ ]: cps   C-a j: buffer   q: leave"))

 ; --- the tty: a key, alt as the escape before it, arrows as the cli's numbers -------
 (synth-key p) (see p @ c
   (? (c != 27) c
      !(rest 1, cue? p) 27
      (see p @ c2
         (c2 = 91 ? (: (fin _) (see p @ f (64 <= f <= 126 ? (f @ 65 -8 66 -9 67 -10 68 -11 0) (fin ()))) (fin ()))
                    (256 + c2)))))
 ; every key waiting, a held key's repeats dropped; answers 'quit -- q, ^c or the end of
 ; the input -- or the state
 (keys st) (cue? 0 ?
              (synth-key in @ k
                 (? (k = 113 || k = 3 || k = -1) 'quit
                    (k = st 'lk && clock 0 - st 'lt < repeat-gap) (keys st)
                    (synth-step st k, pins st 'lk k 'lt (clock 0), keys st)))
              st)
 ; every timbre struck, a text read and played, the drift walked and a frame drawn, two
 ; seconds into a jug: the code the keys will reach paged in, and the first collections
 ; made, before the card is open
 (synth-warm _) (: st (synth-new ()) j (jug 0)
                   (each ^#synth-timbres (i \ (pin st 'tim i, synth-step st 49)),
                    synth-send st "n \"0 [4 7] ~ 12\" # s \"sin\" # gain 0.8",
                    each ^60 (i \ (synth-feed st j, slurp j)),
                    synth-drift st,
                    each ^60 (i \ (synth-feed st j, slurp j)),
                    synth-frame st,
                    0))
 (lead-of gap) (int (2.5 * gap * song-rate / 1000.0) @ n
                  (n < synth-lead ? synth-lead (song-lead-max < n ? song-lead-max n)))
 (synth-run o) (: _ (synth-warm ())
   st (synth-new o)
   hn (horn song-rate 2 @ h (nom? h ? () h))
   pace (pacer ())
   (feed _) (lead-of (pace! pace) @ l
               (hn ? (song-fill hn l (_ \ (synth-feed st hn))) 0))
   (go _) (feed (),
           st 'dirty ? (say out (synth-frame st), flush out, pin st 'dirty 0),
           keys st = 'quit || st 'over ? () (rest 4, go ()))
   (ttytake ['hide],
    mind go () (_ \ (hn ? (flush hn, close hn), drain-keys (), ttygive ['hide])),
    0))
 ; --- the window: a note sounds while its key is held and fades when it is let go. the
 ; keys are places, a tracker's two rows: z to / from c below middle c, q to ] from middle
 ; c, the row above each its sharps. 'hv holds [key semis voice], a voice whose end
 ; never comes; its release is a short fade from the next frame, into 'vs to ring out ---
 synth-qwerty {44 -12 31 -11 45 -10 32 -9 46 -8 47 -7 34 -6 48 -5 35 -4 49 -3 36 -2 50 -1
               51 0 38 1 52 2 39 3 53 4
               16 0 3 1 17 2 4 3 18 4 19 5 6 6 20 7 7 8 21 9 8 10 22 11 23 12 10 13 24 14
               11 15 25 16 26 17 13 18 27 19}
 (synth-hold st k s)
  (: tm (synth-tims st (st 'tim)) at (st 'fpos) d (tm 1) r (1.0 / song-rate)
     f (261.6255653005986 * exp (s * ln2-12))
     (fn sh) (ix \ (: t ((ix - at) * r) tp (t * (t > 0.0))
                (sh tp ix (vphase tp f 0.0) * (1.0 - exp (tp * -420.0))
                 * (0.5 + 0.5 * exp (tp / d * -2.6)) * (t >= 0.0))))
     ; ..an FM note is let go by its own release, so it keeps what to sound again from
     h (fm? st ? [k s (fmv st s at ()) (st 'fm (st 'prog)) at] [k s [(at + 3600 * song-rate) (fn (instr (tm 0) 2)) 0.4 0.4]])
     (pins st 'hv (h . st 'hv) 'last (synth-name s) 'dirty 1))
 (fade [e f gl gr] at rl)
  [(at + rl) (ix \ (: g ((at + rl - ix) * (1.0 / rl)) c (g * (g > 0.0))
                     (f ix * (c + (1.0 - c) * (c > 1.0))))) gl gr]
 (synth-free st k)
  (: at (st 'fpos) rl (song-rate // 12)
     (pins st 'hv (filter (p \ <p != k) (st 'hv))
              'vs (st 'vs + map (p \ #p > 3 ? (opl-voice (p 3) (60.0 + p 1) 100 0.5 (p 4) at song-rate) (fade (p 2) at rl))
                                 (filter (p \ <p = k) (st 'hv)))
              'dirty 1))
 ; a window's record: a key down sounds, or is a knob -- tab the timbre, up and down the
 ; octave, esc the end; a key up lets its note go; a held key's repeats are nothing
 (synth-wstep st r)
  (: e <r k (r 1)
     (? (e = 'close) (pins st 'over 1)
        (e = 'up) (synth-free st k)
        (e = 'size) (pins st 'dirty 1)
        (e != 'down || any (p \ <p = k) (st 'hv)) st
        (k = 1) (pins st 'over 1)
        (k = 15) (pins st 'tim ((st 'tim + 1) % #(synth-tims st)) 'dirty 1)
        (k = 333) (prog st 1)
        (k = 331) (prog st -1)
        (k = 328) (pins st 'oct (min (st 'oct + 1) synth-octaves) 'dirty 1)
        (k = 336) (pins st 'oct (max (st 'oct - 1) (0 - synth-octaves)) 'dirty 1)
        (peep synth-qwerty k () @ o (charm? o ? (synth-hold st k (12.0 * st 'oct + o)) st))))
 (synth-wframe st)
  (esc + "[H" + esc + "[2J"
   + "synth -- the qwerty rows play while they are held\r\n\r\n"
   + "  timbre " + synth-tname st + "   octave " + show (st 'oct)
   + "   last " + (string? (st 'last) ? (st 'last) "-") + "\r\n"
   + "  held " + foldl (a \ p \ " " + synth-name (p 1) + a) "" (st 'hv) + "\r\n\r\n"
   + "  z s x d c v g b h n j m , l . ; /       from c below middle c\r\n"
   + "  q 2 w 3 e r 5 t 6 y 7 u i 9 o 0 p [ = ]  from middle c\r\n\r\n"
   + "  tab: timbre   up/down: octave   " + (st 'fm ? "left/right: fm instrument   " "") + "esc: leave")
 ; rw x rh pixels of col (0xrrggbb) at x y: one row laid by doubling, poured down
 (fill p w x y rw rh col)
  (? (rw < 1 || rh < 1) 0
     (: n (rw * 4) row (cask n)
        _ (pin row 0 (col & 255), pin row 1 ((col >> 8) & 255), pin row 2 ((col >> 16) & 255))
        (dbl k) (k < n ? (pour row k row 0 (min k (n - k)), dbl (2 * k)) 0)
        (dbl 4, each ^rh (j \ pour p (((y + j) * w + x) * 4) row 0 n))))
 ; the text in console cells over the top, and under it a strip of the 32 keys' notes,
 ; z's c to ]'s g, a held one lit
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
        (: hn (horn song-rate 2 @ h (nom? h ? () h))
           pace (pacer ())
           (feed _) (lead-of (pace! pace) @ l
                       (hn ? (song-fill hn l (_ \ (synth-feed st hn))) 0))
           (go _) (feed (),
                   each (window-events win) (r \ synth-wstep st r),
                   st 'dirty ? (synth-paint st win, window-show win 0 (window-size win 1), pin st 'dirty 0),
                   st 'over ? () (rest 4, go ()))
           (mind go () (_ \ (hn ? (flush hn, close hn), window-close win)),
            0))))
 synth-usage "usage: love synth [--fm FILE] [LOOP]   (1 .. = play, shift and alt bend, tab the timbre, up and down the octave, p e [ ] the loop, q leaves)\n       love synth [--fm FILE] -w      (a window: the qwerty rows sound while held)\n       --fm: an op2 bank or a wad's GENMIDI, its instruments a last timbre, left and right choosing"
 ; --- the mitty: the keys a stage over the buffer, a vi stage on the loop's text.
 ; the keys' tick feeds the card; e sends the buffer; q ends both panes ---
 (synth-mitty br vi f o) (: _ (synth-warm ()) st (synth-new o)
   hn (horn song-rate 2 @ h (nom? h ? () h))
   pace (pacer ())
   (feed _) (lead-of (pace! pace) @ l
               (hn ? (song-fill hn l (_ \ (synth-feed st hn))) 0))
   sz (br 'hsize 0) hb (br 'mitty-up <sz <>sz)
   buf (vi 'vi-open f)
   _ (pin buf 'exmore '("send" "play" "stop" "cps"))
   face (vi 'vi-face buf {'ex (synth-ex st) 'reg (hb 'clip)})
   keys (br 'mitty-stage (w \ h \ (pin st 'dirty 0, synth-frame st))
                         (k \ (k = 101 ? (synth-send st (synth-text (buf 'lines))) (synth-step st k)))
                         (_ \ (st 'over)))
   _ (pins keys 'tick (_ \ (feed (), st 'dirty)) 'key synth-key)   ; alt on any key, the row's own reading
   text (br 'mitty-stage (face 0) (face 1) (_ \ (buf 'quit || st 'over)))
   _ (pin text 'paste (face 3))
   share (min 90 ((100 * (synth-rows + 1) + <sz - 1) // <sz))   ; the keys' rows, and one over
   (pin hb 'more (_ \ ((cite 'mooring 'hopen) ["sh"] 1 1)),
    br 'hberth hb 'stack 50 (br 'hopen-stage keys <sz <>sz),
    br 'hberth hb 'stack share (br 'hopen-stage text 1 1),
    br 'hsteer hb 'up,                  ; the keys first
    br 'hsail hb,
    hn ? (flush hn, close hn),
    0))
 ; ..--fm FILE first, its bank read whole or refused
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
