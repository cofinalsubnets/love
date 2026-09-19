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
   two (score-parse '("B4 1 - 3 | C4 2 [G/D] D4 2" "" "; a comment"))
   bad (score-parse '("B4 1 G4 1" "H4 1 - 3" "B4 1 - 2.9 C4 .1" "B4 x - 3" "[Xm] - 4" "B4 1.5 [Em] G4 2.5 ; and a word"))
   keyed (score-parse '("key F# C# G# D#" "F4 1 C4 1 G4 1 D4 1" "key" "F4 1 C4 1 G4 1 D4 1"))
   long (score-parse '("beats 8" "C4 2 B4 2 E4 4" "beats 4" "E4 4"))
 (test (0 < #bs) (all (b \ !(b 'err)) bs)                                          ; the shipped tune parses clean, whatever it is:
                                                                                  ; it is placeholder data, so its bars are not pinned here.
                                                                                  ; notes, legs, bass, chords and the key line are all pinned
                                                                                  ; below against fixtures this file owns
       (score-note "C4" {} = 0) (score-note "B3" {} = -1) (score-note "F#4" {} = 6) (score-note "Bb4" {} = 10) (score-note "e5" {} = 16)
       (score-note "H4" {} = ()) (score-note "4" {} = ())
       (score-note "F4" {5 1} = 6) (score-note "Fn4" {5 1} = 5) (score-note "Fb4" {5 1} = 4) (score-note "G4" {5 1} = 7)
       (keyed 0 'notes = "6 1 8 3") (keyed 1 'notes = "5 0 7 2")
       (#long = 2) (long 0 'notes = "0 ~ 11 ~ 4 ~ ~ ~") (long 0 'beats = 8) (long 1 'notes = "4 ~ ~ ~") (long 1 'beats = 4)
       (score-num ".5" = 0.5) (score-num "1.5" = 1.5) (score-num "2" = 2) (score-num "x" = ())
       (#two = 2) (two 0 'notes = "11 ~ ~ ~") (two 0 'line = 1) (two 1 'bass = -10) (two 1 'notes = "0 ~ 2 ~")
       (#bad = 6) (all (i \ (bad i) 'err) ^5) !(bad 5 'err) (bad 5 'legs = "6 [1 10] 1 1") (bad 5 'notes = "11 [~ 7] ~ ~")))

(test_fin (),
 puts "score: ok -- the tune reads, every slip is named by its line, and the key and beats lines land\n")
