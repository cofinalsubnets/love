; --- test/host/score.l: a tune as text, read back as harp's bars ---
; not in the test/*.l corpus (it loads a crew module). the reader is pure: the built-in
; score of grass parses clean, every kind of slip is named by its line, a key line
; sharpens the bare letters and a beats line lengthens the bar, and the strings come
; out shaped the way harp plays them.
;   cat test/00-init.l test/host/score.l | out/love

(borrow 'score)
(borrow 'grass)   ; for its score, the placeholder tune

; --- the reader ---
(: bs (score-parse score)
   b1 (bs 0) b2 (bs 1)
   two (score-parse '("B4 1 - 3 | C4 2 [G/D] D4 2" "" "; a comment"))
   bad (score-parse '("B4 1 G4 1" "H4 1 - 3" "B4 1 - 2.9 C4 .1" "B4 x - 3" "[Xm] - 4" "B4 1.5 [Em] G4 2.5 ; and a word"))
   keyed (score-parse '("key F# C# G# D#" "F4 1 C4 1 G4 1 D4 1" "key" "F4 1 C4 1 G4 1 D4 1"))
   long (score-parse '("beats 8" "C4 2 B4 2 E4 4" "beats 4" "E4 4"))
 (test (#bs = 8) (all (b \ !(b 'err)) bs)
       (b1 'notes = "11 9 7 4") (b1 'legs = "4 4 4 4") (b1 'bass = -8)
       (b2 'notes = "7 [9 7] 4 ~") (b2 'legs = "4 [2 2] 4 1")
       (score-note "C4" {} = 0) (score-note "B3" {} = -1) (score-note "F#4" {} = 6) (score-note "Bb4" {} = 10) (score-note "e5" {} = 16)
       (score-note "H4" {} = ()) (score-note "4" {} = ())
       (score-note "F4" {5 1} = 6) (score-note "Fn4" {5 1} = 5) (score-note "Fb4" {5 1} = 4) (score-note "G4" {5 1} = 7)
       (keyed 0 'notes = "6 1 8 3") (keyed 1 'notes = "5 0 7 2")
       (#long = 2) (long 0 'notes = "0 ~ 11 ~ 4 ~ ~ ~") (long 0 'beats = 8) (long 1 'notes = "4 ~ ~ ~") (long 1 'beats = 4)
       (score-num ".5" = 0.5) (score-num "1.5" = 1.5) (score-num "2" = 2) (score-num "x" = ())
       (#two = 2) (two 0 'notes = "11 ~ ~ ~") (two 0 'line = 1) (two 1 'bass = -10) (two 1 'notes = "0 ~ 2 ~")
       (#bad = 6) (all (i \ (bad i) 'err) ^5) !(bad 5 'err) (bad 5 'legs = "6 [1 10] 1 1") (bad 5 'notes = "11 [~ 7] ~ ~")))

