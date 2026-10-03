; test/host/grass99.l -- grass simulator 1999, headless: grass's week stood up in
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
   ; the sun and the moon: the sun up at noon and warm at its middle, gone at midnight; the
   ; moon somewhere in the sky across the week, its phase a fraction of its round
   _ (pins g 'h 12.0 'covers '(0.0 0.0 0.0 0.0 0.0 0.0 0.0))         ; clear: no cloud over the sun
   bn (meadow-bodies (g 'mv) g) cn (meadow-pens (g 'mv) g (meadow-sky g))
   sun (bn 0) si (two? sun ? (int (sun 1) * 80 + int (sun 0)) -1)
   warm (0 <= si && peep (cn 2) si 1.0 + 0.15 < peep (cn 0) si 0.0)
   _ (pin g 'h 24.0) bm (meadow-bodies (g 'mv) g)
   seen (any (h \ (pin g 'h h, meadow-bodies (g 'mv) g 1 @ m two? m)) (map (k \ 6.0 + k * 3.0) ^56))
   ph (bn 2)
   s (mkscr 24 80)
   bars (score-parse score99)
   (scribe s night,
    test (count noon "\r\n" = 23) (count night "\r\n" = 23) !(noon = night) !(noon = leant)
         dry dryday
         (two? sun) warm !(two? (bm 0)) seen (0.0 <= ph < 1.0)
         (chat s 79 != 0) (chat s (22 * 80 + 79) != 0)     ; the hud's last cell, the meadow's last row
         (2 = #bars) !(any (b \ b 'err) bars)))

(test_fin (),
 puts "grass99: ok -- the week stands up in three dimensions, day and night, its pens in range as the field dries, and its tune reads\n")
