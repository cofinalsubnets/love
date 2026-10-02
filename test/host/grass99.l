; test/host/grass99.l -- leaves of grass simulator 1999, headless: grass's week stood up in
; three dimensions -- the rows of the frame, noon and night, a lean, the pens in range with
; the field wilting, a console that keeps its last column -- and the sequel's tune reads.
; not in the corpus: a crew module. run: cat test/00-init.l test/host/grass99.l | out/love

(borrow 'grass)    ; the week the sequel runs
(borrow 'grass99)
(borrow 'meadow)   ; the field's pens
(borrow 'score)    ; the tune's reader

(: (count s n) (:- (go 0 0) (go i k) (i + #n <= #s ? (go (i + 1) (k + (n = snip s i (i + #n)))) k))
   (mkscr r c) (screen (cask (screen () r c)) r c)
   (chat s i) (2097151 & glass s i 0)
   (sane c) (all (k \ aall (0.0 <= c k) && aall (c k <= 1.0)) ^3)
   g (grass-new 23 80 (wheel 12)) me (g 'me)
   _ (each (g 'bs) (b \ pins b 'wf 1.0 'hy 80.0))
   _ (pins g 'tdays '(58.0 58.0 58.0 58.0 58.0 58.0 58.0) 'covers '(0.5 0.5 0.5 0.5 0.5 0.5 0.5))
   _ (pin g 'h 12.0) noon (grass99-frame g)
   _ (pins me 'th 0.8 'ht 4.0) leant (grass99-frame g)
   _ (pin g 'h 1.0) night (grass99-frame g)
   _ (each (g 'bs) (b \ pin b 'hy 15.0))
   dry (sane (meadow-pens (g 'mv) g (meadow-sky g)))
   _ (pin g 'h 12.0) dryday (sane (meadow-pens (g 'mv) g (meadow-sky g)))
   s (mkscr 24 80)
   bars (score-parse score99)
   ; the song's voice: a note through the tuner sounds, in range, and the same frames the same
   v ((cite 'play 'mkvoice) 0 {'s "cher" 'note 7 'legato 0.6} 48000)
   y (v 1 (iota 28800)) y2 (v 1 (iota 28800))
   sung (0.1 < amax y && amax y < 1.0 && aall (y = y2))
   (scribe s night,
    test (count noon "\r\n" = 23) (count night "\r\n" = 23) !(noon = night) !(noon = leant)
         dry dryday
         (chat s 79 != 0) (chat s (22 * 80 + 79) != 0)     ; the hud's last cell, the meadow's last row
         (8 = #bars) !(any (b \ b 'err) bars) sung (grass99-look 'voice = "cher")))

(test_fin (),
 puts "grass99: ok -- the week stands up in three dimensions, day and night, its pens in range as the field dries, and its tune reads\n")
