; score -- a tune as text, for harp: a bar to the line, and a bar out as the two mini
; strings harp plays it by.
;
; a line is NAME BEATS pairs: B4 is the b above middle c, a beat a quarter note, .5 an
; eighth; `-` is a rest, `|` also ends a bar, `;` starts a comment, and [CHORD] names
; the bar's bass -- the note after the slash if there is one, else the root. a
; `key F# C# G# D#` line is the key signature: every bare letter after it takes its
; sharp or flat, and Fn4 is a natural against it. a bar holds score-beats beats, or what
; a `beats 8` line says, in quarter-beat steps.
;
; score-parse answers the bars, each {'notes 'legs 'bass 'beats 'pitches 'line} or {'err
; 'line}; score-tune makes harp's pattern of them at a tempo, on the music box; score-check
; prints what is wrong, or with all every bar. `love harp -s FILE` plays one and
; `love harp --check FILE` reads it back. laws in test/host/score.l.
(module (score score-parse score-tune score-check score-file score-lines score-bar
         score-strings score-words score-note score-num score-pc score-chord score-key
         score-beats)
(borrow 'harp)
(? (cite 'posix) (borrow 'posix) ())
(:
 score-beats 4                          ; a bar, unless a beats line says otherwise
 (score-num t) (:- (go 0 0 0 1) (go i n f d)
   (? (i >= #t) (0 < i ? (n + f) ())
      (t i = 46) (d = 1 ? (go (i + 1) n f 10.0) ())
      (48 <= t i <= 57) (d = 1 ? (go (i + 1) (n * 10 + t i - 48) f d) (go (i + 1) n (f + (t i - 48) / d) (d * 10.0)))
      ()))
 ; a letter, a sharp, flat or natural, an octave: the semitone from middle c. a bare
 ; letter takes the key's accidental; answers [semitone chars-taken]
 pcs '(9 11 0 2 4 5 7)                  ; a b c d e f g
 (score-pc t key) (: c (t 0) u (97 <= c ? (c - 32) c)
                     acc (t 1 @ 35 1 98 -1 110 0 (peep key (u - 65) 0))
                     (65 <= u <= 71 ? [(pcs (u - 65) + acc) (1 + (t 1 @ (35 || 98 || 110) 1 0))] ()))
 (score-note t key) (: p (0 < #t ? (score-pc t key) ())
                       o (two? p ? (score-num (snip t <>p #t)) ())
                       (charm? o ? (<p + (int o - 4) * 12) ()))
 ; the key line's words into the key: letter -> accidental
 (score-key ws) (foldl (\ k w (: p (score-pc w {}) c (w 0) u (97 <= c ? (c - 32) c)
                                (two? p ? (pin k (u - 65) (<p - pcs (u - 65))) k)))
                       {} ws)
 ; [C#m7/G#]: the bass is g sharp, an octave under middle c's
 (score-chord t) (: in (snip t 1 (#t - 1))
                    (cut i) (i >= #in ? in (in i = 47 ? (snip in (i + 1) #in) (cut (i + 1))))
                    p (score-pc (cut 0) {})
                    (two? p ? (<p - 12) ()))
 (score-words s) (:- (go 0 () "") (go i ws w)
   (? (i >= #s || s i = 59) (0 < #w ? (lrev (w . ws)) (lrev ws))
      (s i = 32 || s i = 9) (go (i + 1) (0 < #w ? (w . ws) ws) "")
      (go (i + 1) ws (w + string (s i)))))
 ; one bar's words to its slots: a quarter-beat grid, each slot () or [note sixteenths]
 (score-bar ws key beats) (:- (go ws 0.0 (map (\ _ ()) ^(beats * 4)) () ())
   (go l pos sl bs err)
   (? err {'err err}
      (one? l) (: sum (int (pos * 4.0 + 0.5))
                  (? (sum != beats * 4) {'err ("adds up to " + show pos + " beats, not " + show beats)}
                     (score-strings sl bs beats)))
      (<l 0 = 91) (: b (score-chord <l) (b = () ? (go () pos sl bs ("bad chord " + <l)) (go >l pos sl b err)))
      (one? >l) (go () pos sl bs ("no beats after " + <l))
      (: n (score-note <l key) d (score-num <>l)
         k (pos * 4.0) i (int (k + 0.5))
         (? (<l != "-" && n = ()) (go () pos sl bs ("not a note: " + <l))
            (d = ()) (go () pos sl bs ("not a length: " + <>l))
            (0.001 < |(k - i)) (go () pos sl bs ("off the quarter-beat grid at " + <l))
            (d < 0.25) (go () pos sl bs ("too short at " + <l))
            ; a note past the bar lays nothing; the sum says how far over the bar ran
            (go >>l (pos + d) (n = () || i >= beats * 4 ? sl (lay sl i [n (int (d * 4.0 + 0.5))])) bs err)))))
 (lay l i v) (:- (go l 0) (go l k) (one? l ? () ((k = i ? v <l) . go >l (k + 1))))
 ; the mini strings: a word a beat, subdivided only where an onset falls between beats.
 ; the legato string carries the same shape with a sixteenth count in every slot, since
 ; pset takes its shape from the notes and a rest in the legato would drop the note
 (score-strings sl bs beats) (:
   (cell x) (two? x ? (show <x) "~")
   (dur x) (two? x ? (show <>x) "1")
   (word f b) (: a (sl (b * 4)) c (sl (b * 4 + 1)) d (sl (b * 4 + 2)) e (sl (b * 4 + 3))
                 (? (one? c && one? d && one? e) (f a)
                    (one? c && one? e) ("[" + f a + " " + f d + "]")
                    ("[" + f a + " " + f c + " " + f d + " " + f e + "]")))
   (line f) (foldl (\ acc b (acc + (0 < b ? " " "") + word f b)) "" ^beats)
   {'notes (line cell) 'legs (line dur) 'bass bs 'beats beats
    'pitches (map (x \ <x) (filter two? sl))})
 ; a list of lines to bars, a bar per line and per |, blank lines skipped, a key or a
 ; beats line setting them for the lines under it; a bar that fails carries 'err and
 ; the line it came from
 (score-lines s) (split "\n" s)
 (score-parse ls) (:
   (bare ln) (:- (go 0) (go i) (? (i >= #ln) ln (ln i = 59) (snip ln 0 i) (go (i + 1))))
   (bars-of ln i key beats) (map (t \ (: ws (score-words t) (one? ws ? () (pin (score-bar ws key beats) 'line i)))) (split "|" (bare ln)))
   ; the fold carries [bars key beats]
   (line acc i) (: ws (score-words (bare (ls i))) key (acc 1) beats (acc 2)
                   (? (two? ws && <ws = "key") [(acc 0) (score-key >ws) beats]
                      (two? ws && <ws = "beats") [(acc 0) key (: n (two? >ws ? (score-num <>ws) ()) (charm? n && 0 < n ? (int n) score-beats))]
                      [(acc 0 + bars-of (ls i) (i + 1) key beats) key beats]))
   (filter tablet? (foldl line [() {} score-beats] ^#ls 0)))
 ; the check: every complaint to the screen, and with all every bar as harp will play
 ; it; answers whether anything was bad
 (score-check ls all) (: bs (score-parse ls)
   bad (filter (b \ b 'err) bs)
   _ (each bs (b \ (? (b 'err) (puts ("line " + show (b 'line) + ": " + b 'err + "\n"))
                       all (puts ("line " + show (b 'line) + ": " + b 'notes + "   |   " + b 'legs
                                  + (b 'bass = () ? "" ("   bass " + show (b 'bass))) + "\n"))
                       ())))
   _ (all || two? bad ? (puts (show #bs + " bars, " + show #bad + " bad\n")))
   (two? bad ? 1 0))

 ; the score as harp's pattern at cps bars a second: the melody on the music box, a
 ; note's ring a little past its written length, the bass a bar long under it
 (score-tune bs cps) (:
   (secs b n) (n * 1.25 / (cps * b 'beats * 4.0))    ; n sixteenths of this bar, in seconds
   mel (slowcat (map (b \ pset (pset (note (mini (b 'notes)))
                                    (legato (pmap (n \ secs b n) (mini (b 'legs)))))
                              (hit (pure "box")))
                     bs))
   low (slowcat (map (b \ (b 'bass = () ? (mini "~")
                             (pset (pset (pset (note (pure (b 'bass))) (legato (pure (1.0 / cps))))
                                         (hit (pure "box")))
                                   (gain (pure 0.6)))))
                     bs))
   (stack [mel low]))
 (score-file p) (: q (open p "r") (? (hot? q) (: s (slurp q) (close q, score-lines s)) ())))
) ; module score
