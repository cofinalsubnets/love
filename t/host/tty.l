; --- t/host/tty.l: the tty app runners, on a real terminal ---
; the engines gate headless -- t/host/rove.l the crawl, t/host/story.l the fiction,
; a/ink.l's shimmer into a jug -- and each of those files says the same thing about
; what it leaves out: the RUNNER, the loop that asks the terminal its size, puts the
; app on the alternate screen, reads keys and steps ashore. that lane wants a
; terminal, so it gets one. `tether` spawns the verb on a pty, we type at the master
; and scribe what came back onto a quay screen -- the same struct cb the app would be
; painting on anywhere, which is what lets a law here be about the grid and not about
; a byte count.
;
;   cat t/00-init.l t/host/tty.l | b/love
;
; not in the t/*.l corpus: tether and the screen nifs live in i/*.c, which love0 does
; not link.
;
; TWO RULES, both learned here:
;
; THE SIZE IS SET FROM INSIDE THE CHILD. a fresh pty is 0x0 and the parent's
; settty races the child's first `tty` -- rove reads its size ONCE and falls
; back to 22x80, so a lost race is a quiet 22-row deck and a gate that reddens one run
; in fifty. `stty` on the child's own tty before the exec cannot race.
;
; NO ESCAPE KEY, EVER. the stage tells a lone ESC from a sequence by a short rest, so
; an ESC with a key hard behind it reads as alt-<key> -- and alt-q is not quit. that
; run never lands and `slurp` waits on a child that is still playing. a hung gate is
; worse than a red one, so every sequence here ends in a quit the app cannot misread.
(: (waitfor pid) (: s (gather pid) (? (two? s) s (nom? s) s (do (rest 2) (waitfor pid))))
   (has? h n) (: k (tally n) m (tally h)
                 (go i) (? ((m - k) < i) 0 (n = snip h i (i + k)) 1 (go (i + 1)))
                 (go 0))
   (blank? t) (foldl (\ a ch (&& a (ch = 32))) 1 t)
   (count h n) (: k (tally n) m (tally h)
                  (go i c) (? ((m - k) < i) c
                              (n = snip h i (i + k)) (go (i + k) (c + 1))
                              (go (i + 1) c))
                  (go 0 0))
   ; the stream up to the last alt-screen leave. quay honours 1049, so scribing a
   ; whole run would lay the empty primary screen back over the app's last frame --
   ; what is wanted is the grid as the app left it, not as the terminal got it back.
   (held h) (: n (tally h) k 8
               (go i best) (? (n < (i + k)) best
                            ("\e[?1049l" = snip h i (i + k)) (go (i + 1) i)
                            (go (i + 1) best))
               (: b (go 0 -1) (? (b < 0) h (snip h 0 b))))
   (mkscr r c) (screen (cask (screen () r c)) r c)
   (chat s i) (& 255 (glass s i))
   (cbg s i) (& 255 (>> (glass s i) 16))
   (rowtx s r) (: c (gaze s 2)
                  (foldl (\ a i (+ a (string (: ch (chat s (+ (* r c) i)) (? (= 0 ch) 32 ch)))))
                         "" (jot c)))
   ; the crawl's deck is seeded off the clock, so where @ stands is nobody's law --
   ; that it stands somewhere is
   (at s) (: c (gaze s 2) r (gaze s 1)
             (go i) (? ((r * c) <= i) () (64 = chat s i) ((i // c) . (i % c)) (go (i + 1)))
             (go 0))
   (spawn cmd r c)
    (tether ["sh" "-c" ("stty rows " + show r + " columns " + show c + " -echo; exec " + cmd)])
   ; spawn at r x c, type, read to the end, and lay the held grid: [stream screen]
   (run cmd keys r c)
    (: t (spawn cmd r c)
       _ (test (two? t))
       m >t
       _ (say m keys)
       txt (slurp m)
       _ (waitfor <t)
       s (mkscr r c)
       _ (scribe s (held txt))
       [txt s])

; --- rove: the crawl takes the terminal's size, and a key is a turn ---
; the bar is the LAST row, which is the geometry law -- but only away from 80x24. a
; sizeless rove falls back to a 22-row deck, which with the note and the bar is 24
; lines exactly, so the same grid comes out whether the tty was read or missed and
; the law at 24 rows is vacuous. 20x70 is nobody's fallback.
 a (run "b/love rove" "q" 20 70)
 _ (test
    (has? <a "\e[?1049h")                                   ; the alternate screen
    ("the hold is dark" = snip (rowtx <>a 0) 0 16)           ; the note, no turn taken
    ("deck 1/" = snip (rowtx <>a 19) 0 7)                    ; the bar, on row 19 of 20
    (at <>a)                                                 ; and you stand on the deck
    (has? <a "ashore with"))                                 ; q steps ashore

; --- ..and a turn spends the note. the boot message stands until the first one, so a
;     blank row 0 is the crawl saying it read a key -- nothing else here can say it
 b (run "b/love rove" "hjklq" 20 70)
 _ (test
    (blank? (rowtx <>b 0))
    ("deck 1/" = snip (rowtx <>b 19) 0 7)
    (at <>b))

; --- ..and an arrow's three bytes are ONE key. read as a bare ESC they would be quit
;     (rove's own second quit key), the h behind them unread and the note still on row
;     0 -- so a spent note is exactly the law that the CSI was decoded
 c (run "b/love rove" "\e[Chq" 20 70)
 _ (test (blank? (rowtx <>c 0)) (has? <c "ashore with"))

; --- ink: the shimmer paints while no key waits ---
; which is why its key cannot be typed up front -- ink asks `cue?` BEFORE its first
; frame, so a waiting key ends it having drawn nothing. read until a painted cell is
; on the wire, then type: the app says when, and no timer is involved.
 t (spawn "b/love -l a/ink.l -e '(ink ())'" 12 40)
 m >t
 seen (: (upto acc) (? (has? acc "\e[48;5;") acc
                       (: ch (see m) (? (= ch -1) acc (upto (acc + string ch)))))
         (upto ""))
 _ (say m " ")
 itx (seen + slurp m)
 _ (waitfor <t)
 is (: s (mkscr 12 40) _ (scribe s (held itx)) s)
 _ (test
    (has? itx "\e[?1049h") (has? itx "\e[?25l")              ; alt screen, cursor away
    (has? itx "\e[?1049l") (has? itx "\e[?25h")              ; ..and both put back
    ; the ocean is one SGR background per cell, so a frame is exactly r*c of them --
    ; and r is the size it was told LESS the last row, which ink spares so that the
    ; terminal never scrolls. 11*40, however many frames landed. the grid cannot say
    ; this: a sizeless ink paints 23x80, which at 40 columns wraps two screen rows to
    ; the ink row and leaves the same last row dry.
    (0 < count itx "\e[48;5;")
    (0 = (count itx "\e[48;5;") % 440)
    (0 < cbg is 0)                                           ; ..and it really is painted
    (0 = cbg is 440))                                        ; with the last row spared

; --- the story: a level file is a fixed map, so this one place IS a law ---
 d (run "b/love story" ":q\r" 14 60)
 _ (test
    (has? <d "the lighthouse")                               ; the status line names it
    ((8 . 6) = at <>d))                                      ; you stand where the level puts you
 e (run "b/love story" "k:q\r" 14 60)
 _ (test ((7 . 6) = at <>e))                                 ; ..and k is one row north
 _ (test_fin ())
 (puts "tty: ok"))
