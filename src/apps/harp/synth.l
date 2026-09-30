; synth -- a keyboard to pick a tune out on, for someone with no piano: the number row
; plays notes out the horn on harp's voices, a screen says which.
;
; 1 is middle c and each key on from it along the row -- the digits, then - and = --
; a semitone higher, twelve keys to the octave; shift plays the note an octave up and
; alt lowers it a quarter tone. tab takes the next timbre, the up and down arrows move
; the octave, q leaves. a key is a strike: the note rings and dies on its own, since a
; tty tells of keys pressed and never of keys let go, and a held key's repeats are
; dropped as the games drop them.
;
; the horn is fed a small chunk at a time, paced by the loop's gap (rove's pacer), at
; least an eighth of a second ahead of the speaker: longer than the runtime's pauses (a
; collection, a section of the image paged in on first use), whose first ones
; synth-warm takes before the card opens. the filler is rove's song-fill, which stops
; when the card stops taking, so a loop heavier than the seat can mix gaps rather than
; holds the keys.
;
; the shifted row is the keymap's: what shift makes of the digits is the terminal's to
; say, and synth-shifted is the us row. alt reaches the terminal as an escape before
; the key, read by the synth's own synth-key, which makes alt of any key where the
; cli's edkey makes it of the letters alone; on the harbour the keys' stage hands berth
; that reader through its 'key door.
;
; a backing loop to play over: harp's patterns, in the text `love harp` takes -- a mini
; string, or a love form over harp's names in parentheses -- pulled a cycle at a time
; into the same voices the strikes ring in, so one mix goes out the card. the text is
; a vi buffer in a pane under the keys, on berth's harbour: e in the keys' pane sends
; the buffer, and :send :play :stop and :cps N are the buffer's own ex words. a new
; pattern takes over at a cycle's start, so a change never drops the beat; a torn or
; bad one is said and the loop kept. on a seat with no harbour the keys run alone.
;
; d plays in just intonation instead (src/apps/harp/drift.l): the loop becomes a walk
; of phrases from a book (src/apps/harp/phrases.l) over a center that drifts on the
; lattice, one phrase a cycle. k turns what the row plays under it: fixed, the equal
; row from middle c as ever; follow, the same equal row rooted on the center now
; sounding, so the keys modulate as the walk moves; just, the twelve of 5-limit over
; that center -- alt taking the septimal one where there is one -- pure against the
; walk. , and . turn the walk's steer, ; and ' its lean, h its pull home, v the book;
; the screen draws the lattice round the center, its trail behind it.
;
; the keys, the notes, the loop and the feed are pure -- synth-new, synth-step,
; synth-code, synth-semis, synth-name, synth-send, synth-play, synth-stop, synth-pull
; and synth-feed into any port -- gated by test/host/synth.l; only synth-run ties the
; tty and the horn.
;
; run: love synth [LOOP]   1 .. = play, shift and alt bend, tab is the timbre, up and
;                         down the octave, p plays or stops the loop, e sends the
;                         buffer, [ and ] the cps, q leaves. the buffer opens on LOOP
;                         and :w keeps it. d the drift, k the keys under it,
;                         , . ; ' h v its knobs.
;                         HORN=none plays silent on a seat with no card
(module (synth synth-run synth-main synth-new synth-step synth-code synth-semis synth-name
         synth-strike synth-feed synth-frame synth-key synth-timbres synth-shifted synth-digits
         synth-chunk synth-lead synth-octaves synth-send synth-play synth-stop synth-pull
         synth-cps! synth-cps synth-cps-step synth-cps-lo synth-cps-hi synth-text synth-ex
         synth-just synth-sept synth-jdeg synth-dopts synth-drift synth-lname synth-map synth-kmodes)
(borrow 'rove)                          ; the pacer, the song's rate and its lead's ceiling
(borrow 'harp)                          ; the patterns: a cycle's events
(borrow 'play)                          ; the voices, the mix, and harp-read for the text
(borrow 'just)                          ; ratios, cents, the lattice
(borrow 'drift)                         ; the walk and its chooser
(borrow 'phrases)                       ; its books
(borrow 'posix)    ; close, for the horn
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
 (synth-new _) {'oct 0 'tim 0 'vs () 'due () 'fpos 0 'last () 'lk 0 'lt 0 'dirty 1
                'pat () 'nextp () 'on 0 'cyc 0 'cstart 0 'cps synth-cps 'lmsg "" 'over 0
                'dr 0 'dw () 'dnow () 'dprev [() ()] 'dph "" 'trail () 'dbook 3
                'dlean 1.5 'dsteer 1.0 'dhome 0.1 'km 0}
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
                            (hit (pure (synth-timbres (st 'tim) 0))))
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

 ; --- a strike: a voice from the next frame to be written --------------------------
 (synth-strike st s) (: tm (synth-timbres (st 'tim))
                        v (mkvoice (st 'fpos) {'s (tm 0) 'note s 'gain 0.8 'pan 0.5 'legato (tm 1)} song-rate)
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
                      ((pins st 'vs live 'due (filter (p \ p 0 >= lim) (st 'due)) 'fpos lim),
                       say h (pack (mixdown live base synth-chunk) synth-chunk synth-gain)))

 ; --- a key: a note struck, the timbre or the octave turned, the loop played or
 ; stopped and its cps moved; q or ^c is the end ---
 (synth-step st k) (synth-code k @ c
   (? (two? c) (synth-strike st (synth-semis st c) @ s2
                  (st 'dr && st 'km = 2 ? (pins s2 'last (rshow (synth-jdeg c) + " " + synth-name (synth-semis st c))) s2))
      (k = 9) (pins st 'tim ((st 'tim + 1) % #synth-timbres) 'dirty 1)
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
 ; many rows, which is what the keys' pane is given on the harbour --------------------
 synth-rows 16
 (synth-frame st) (: tm (synth-timbres (st 'tim))
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
    + (st 'dr && st 'km = 2 ? "  shift: octave up   alt: septimal   tab: timbre   up/down: octave\r\n"
               "  shift: octave up   alt: quarter tone down   tab: timbre   up/down: octave\r\n")
    + "  d: drift   k: keys   , .: steer   ; ': lean   h: home   v: book\r\n"
    + "  p: play/stop loop   e: send buffer   [ ]: cps   C-a j: buffer   q: leave"))

 ; --- the tty: a key, alt as the escape before it, arrows as the cli's numbers -------
 (synth-key p) (see p @ c
   (? (c != 27) c
      !(rest 1, cue? p) 27
      (see p @ c2
         (c2 = 91 ? (: (fin _) (see p @ f (64 <= f <= 126 ? (f @ 65 -8 66 -9 0) (fin ()))) (fin ()))
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
 (synth-run _) (: _ (synth-warm ())
   _ (raw 1)
   _ (say out (esc + "[?1049h" + esc + "[?25l"))
   st (synth-new ())
   hn (horn song-rate 2 @ h (nom? h ? () h))
   pace (pacer ())
   (feed _) (lead-of (pace! pace) @ l
               (hn ? (song-fill hn l (_ \ (synth-feed st hn))) 0))
   (go _) (feed (),
           st 'dirty ? (say out (synth-frame st), flush out, pin st 'dirty 0),
           keys st = 'quit || st 'over ? () (rest 4, go ()))
   (go (),
    (say out (esc + "[0m" + esc + "[?25h" + esc + "[?1049l"), flush out),
    hn ? (flush hn, close hn),
    drain-keys (),
    raw 0,
    0))
 synth-usage "usage: love synth [LOOP]   (1 .. = play, shift and alt bend, tab the timbre, up and down the octave, p e [ ] the loop, q leaves)"
 ; --- the harbour: the keys a stage over the buffer, a vi stage on the loop's text.
 ; the keys' tick feeds the card; e sends the buffer; q ends both panes ---
 (synth-berth br vi f) (: _ (synth-warm ()) st (synth-new ())
   hn (horn song-rate 2 @ h (nom? h ? () h))
   pace (pacer ())
   (feed _) (lead-of (pace! pace) @ l
               (hn ? (song-fill hn l (_ \ (synth-feed st hn))) 0))
   sz (br 'hsize 0) hb (br 'harbour <sz <>sz)
   buf (vi 'vi-open f)
   _ (pin buf 'exmore '("send" "play" "stop" "cps"))
   face (vi 'vi-face buf {'ex (synth-ex st) 'reg (hb 'clip)})
   keys (br 'berth-stage (w \ h \ (pin st 'dirty 0, synth-frame st))
                         (k \ (k = 101 ? (synth-send st (synth-text (buf 'lines))) (synth-step st k)))
                         (_ \ (st 'over)))
   _ (pins keys 'tick (_ \ (feed (), st 'dirty)) 'key synth-key)   ; alt on any key, the row's own reading
   text (br 'berth-stage (face 0) (face 1) (_ \ (buf 'quit || st 'over)))
   _ (pin text 'paste (face 3))
   share (min 90 ((100 * (synth-rows + 1) + <sz - 1) // <sz))   ; the keys' rows, and one over
   (pin hb 'more (_ \ (br 'hopen ["sh"] 1 1)),
    br 'hberth hb 'stack 50 (br 'hopen-stage keys <sz <>sz),
    br 'hberth hb 'stack share (br 'hopen-stage text 1 1),
    br 'hsteer hb 'up,                  ; the keys first
    br 'hsail hb,
    hn ? (flush hn, close hn),
    0))
 (synth-main as) (: br (cite 'berth) vi (cite 'vi)
   (? (1 < #as) (say err ("synth: " + synth-usage + "\n"), flush err, 2)
      (tablet? br && tablet? vi) (synth-berth br vi (two? as ? <as ""))
      (synth-run ())))
 _ (pins (cite 'verbs 'tab) 'synth (udoor 'synth synth-main synth-usage 1 1)))
) ; module synth
