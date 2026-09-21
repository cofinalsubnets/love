; synth -- a keyboard to pick a tune out on, for someone with no piano: the number row
; plays notes out the horn on harp's voices, a screen says which.
;
; 1 is middle c and each number key on from it a whole tone higher; shift raises the
; note a semitone, alt lowers it a quarter tone, and both together raise it a quarter
; tone. tab takes the next timbre, the up and down arrows an octave, q leaves. a key
; is a strike: the note rings and dies on its own, since a tty tells of keys pressed
; and never of keys let go, and a held key's repeats are dropped as the games drop them.
;
; the horn is fed a small chunk at a time, a short lead ahead of the speaker, paced by
; the loop's gap (rove's pacer), so a strike sounds a few hundredths of a second on.
;
; the shifted row is the keymap's: what shift makes of the digits is the terminal's to
; say, and synth-shifted is the us row. alt reaches the terminal as an escape before
; the key, the way the cli's edkey reads it for the letters.
;
; the keys, the notes and the feed are pure -- synth-new, synth-step, synth-code,
; synth-semis, synth-name and synth-feed into any port -- gated by test/host/synth.l;
; only synth-run ties the tty and the horn.
;
; run: love synth     1 .. 0 play, shift and alt bend, tab is the timbre, up and down
;                     the octave, q leaves. HORN=none plays silent on a seat with no card
(module (synth synth-run synth-main synth-new synth-step synth-code synth-semis synth-name
         synth-strike synth-feed synth-frame synth-key synth-timbres synth-shifted synth-digits
         synth-chunk synth-lead synth-octaves)
(borrow 'rove)                          ; the pacer, the song's rate and its lead's ceiling
(borrow 'play)                          ; the voices, the mix
(? (cite 'posix) (borrow 'posix) ())    ; close, for the horn
(:
 esc (string 27)
 synth-digits "1234567890"
 synth-shifted "!@#$%^&*()"             ; the same keys under shift, on a us keymap
 ; the pitched voices of harp's kit, each with how long a strike rings
 synth-timbres [["sin" 1.2] ["tri" 1.2] ["saw" 0.9] ["sqr" 0.9] ["box" 1.6] ["chime" 3.0]]
 synth-octaves 3                        ; up or down from middle c's
 synth-chunk (song-rate // 60)          ; a feed, in frames
 synth-lead (song-rate // 16)           ; the least queued ahead of the speaker
 synth-gain 11000.0
 names ["C" "C#" "D" "D#" "E" "F" "F#" "G" "G#" "A" "A#" "B"]

 (synth-new _) {'oct 0 'tim 0 'vs () 'fpos 0 'last () 'lk 0 'lt 0 'dirty 1}

 ; --- a key into a note ---------------------------------------------------------------
 ; a key is the byte, or 256 past it with alt held; a digit or its shifted mate is a
 ; note: [degree shift alt], and any other key ()
 (spot s c) (:- (go 0) (go n) (n < #s ? (s n = c ? n (go (n + 1))) -1))
 (synth-code k) (: alt (255 < k) c (alt ? (k - 256) k)
                   i (spot synth-digits c) j (spot synth-shifted c)
                   (? (0 <= i) [i 0 alt] (0 <= j) [j 1 alt] ()))
 ; semitones from middle c: whole tones up the row, the octave, a semitone for shift and
 ; a quarter tone down for alt -- so both together is a quarter tone up
 (synth-semis st [i sh al]) (12.0 * st 'oct + 2.0 * i + sh - 0.5 * al)
 ; a note's name: the semitone under it and its octave, and the quarter tone said in cents
 (synth-name s) (: t (int s) n (s < t ? (t - 1) t)
                   o (n < 0 ? ((n - 11) // 12) (n // 12))
                   (names (n - 12 * o) + show (4 + o) + (n < s ? " +50c" "")))

 ; --- a strike: a voice from the next frame to be written --------------------------
 (synth-strike st s) (: tm (synth-timbres (st 'tim))
                        v (mkvoice (st 'fpos) {'s (tm 0) 'note s 'gain 0.8 'pan 0.5 'legato (tm 1)} song-rate)
                        (pins st 'vs (st 'vs + [v]) 'last (synth-name s) 'dirty 1))
 ; one chunk out the port: the voices still ringing, summed. the port is any jug
 (synth-feed st h) (: base (st 'fpos)
                      live (filter (v \ v 0 >= base) (st 'vs))
                      _ (pins st 'vs live 'fpos (base + synth-chunk))
                      (say h (pack (mixdown live base synth-chunk) synth-chunk synth-gain)))

 ; --- a key: a note struck, the timbre or the octave turned ------------------------
 (synth-step st k) (: c (synth-code k)
   (? (two? c) (synth-strike st (synth-semis st c))
      (k = 9) (pins st 'tim ((st 'tim + 1) % #synth-timbres) 'dirty 1)
      (k = -8) (pins st 'oct (min (st 'oct + 1) synth-octaves) 'dirty 1)
      (k = -9) (pins st 'oct (max (st 'oct - 1) (0 - synth-octaves)) 'dirty 1)
      st))

 ; --- the screen: what stands, and what the row plays now ---------------------------
 (synth-frame st) (: tm (synth-timbres (st 'tim))
   (row i) (: n (synth-name (synth-semis st [i 0 0]))
              (string (synth-digits i) + " " + n + "   "))
   (esc + "[H" + esc + "[2J"
    + "synth -- the number row plays, from middle c a whole tone a key\r\n\r\n"
    + "  timbre " + tm 0 + "   octave " + show (st 'oct)
    + "   last " + (string? (st 'last) ? (st 'last) "-") + "\r\n\r\n"
    + "  " + foldl (+) "" (map row ^10) + "\r\n\r\n"
    + "  shift a semitone up   alt a quarter tone down   both a quarter tone up\r\n"
    + "  tab the next timbre   up and down the octave    q leaves\r\n"))

 ; --- the tty: a key, alt as the escape before it, arrows as the cli's numbers -------
 (synth-key p) (: c (see p)
   (? (c != 27) c
      !(rest 1, cue? p) 27
      (: c2 (see p)
         (c2 = 91 ? (: (fin _) (: f (see p) (64 <= f <= 126 ? (f @ 65 -8 66 -9 0) (fin ()))) (fin ()))
                    (256 + c2)))))
 ; every key waiting, a held key's repeats dropped; answers 'quit -- q, ^c or the end of
 ; the input -- or the state
 (keys st) (? (cue? 0)
              (: k (synth-key in)
                 (? (k = 113 || k = 3 || k = -1) 'quit
                    (k = st 'lk && (clock 0 - st 'lt) < repeat-gap) (keys st)
                    (synth-step st k, pins st 'lk k 'lt (clock 0), keys st)))
              st)
 (lead-of gap) (: n (int (2.5 * gap * song-rate / 1000.0))
                  (n < synth-lead ? synth-lead (song-lead-max < n ? song-lead-max n)))
 (synth-run _) (: _ (raw 1)
   _ (say out (esc + "[?1049h" + esc + "[?25l"))
   st (synth-new ())
   hn (: h (horn song-rate 2) (? (nom? h) () h))
   pace (pacer ())
   (feed _) (: l (lead-of (pace! pace))
               (fill _) (? (hn && horn-lag hn < l) (synth-feed st hn, fill ()))
               (fill ()))
   (go _) (: _ (feed ())
             _ (? (st 'dirty) (say out (synth-frame st), flush out, pin st 'dirty 0))
             (keys st = 'quit ? () (rest 4, go ())))
   _ (go ())
   _ (say out (esc + "[0m" + esc + "[?25h" + esc + "[?1049l"), flush out)
   _ (hn ? (flush hn, close hn))
   _ (drain-keys ())
   _ (raw 0)
   0)
 synth-usage "usage: love synth   (1 .. 0 play, shift and alt bend, tab the timbre, up and down the octave, q leaves)"
 (synth-main as) (as @ () (synth-run ())
                       (say err ("synth: " + synth-usage + "\n"), flush err, 2))
 _ (pins (cite 'verbs 'tab) 'synth (udoor 'synth synth-main synth-usage 1 1)))
) ; module synth
