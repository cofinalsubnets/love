; --- t/host/tty.l: the tty app runners, on a real terminal ---
; the engines gate headless -- t/host/rove.l the climb, t/host/story.l the fiction,
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
; settty races the child's first `tty` -- the climb reads its size ONCE and falls
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
   ; the climb's floor is seeded off the clock, so where @ stands is nobody's law --
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

; --- tower: the climb takes the terminal's size, and a key is a turn ---
; the bar is the LAST row, which is the geometry law -- but only away from 80x24. a
; sizeless climb falls back to a 22-row floor, which with the note and the bar is 24
; lines exactly, so the same grid comes out whether the tty was read or missed and
; the law at 24 rows is vacuous. 20x70 is nobody's fallback.
 a (run "b/love tower" "q" 20 70)
 _ (test
    (has? <a "\e[?1049h")                                   ; the alternate screen
    ("the tower stands" = snip (rowtx <>a 0) 0 16)           ; the note, no turn taken
    ("the garden" = snip (rowtx <>a 19) 0 10)                ; the bar, on row 19 of 20
    (at <>a)                                                 ; and you stand on the floor
    (has? <a "you leave the tower"))                         ; q leaves

; --- ..and a turn spends the note. the boot message stands until the first one, so a
;     blank row 0 is the climb saying it read a key -- nothing else here can say it
 b (run "b/love tower" "hjklq" 20 70)
 _ (test
    (blank? (rowtx <>b 0))
    ("the garden" = snip (rowtx <>b 19) 0 10)
    (at <>b))

; --- ..and an arrow's three bytes are ONE key. read as a bare ESC they would be quit
;     (the climb's own second quit key), the h behind them unread and the note still on
;     row 0 -- so a spent note is exactly the law that the CSI was decoded
 c (run "b/love tower" "\e[Chq" 20 70)
 _ (test (blank? (rowtx <>c 0)) (has? <c "you leave the tower"))

; --- ink: the shimmer paints while no key waits ---
; which is why its key cannot be typed up front -- ink asks `cue?` BEFORE its first
; frame, so a waiting key ends it having drawn nothing. read until a painted cell is
; on the wire, then type: the app says when, and no timer is involved.
 t (spawn "b/love ink" 12 40)
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

; --- what was typed at the game is not typed at the shell ---
; raw mode does not echo, so keys the game never reads sit in the terminal's queue and
; are read by whatever comes next -- a prompt takes them as a line typed at it. the tower
; reads exactly one key a turn, so a burst behind the quit is a burst left over: z takes
; the sign down, q leaves, and the four behind them are the ones that must not survive.
; the reader after it is non-blocking (min 0 time), so it answers whether or not there
; is anything there, which is the whole question.
 dr (: t (tether ["sh" "-c" ("stty rows 20 columns 70 -echo; b/love tower; "
                             + "stty -icanon min 0 time 3; cat")])
       m >t
       ; the keys wait for raw mode: typed before it, the tty ECHOES them back and the
       ; leftovers cannot be told from the echo of the ones that were read
       _ (rest 500)
       _ (say m "zqzzzz")
       (slurp m))
 _ (test (has? dr "you leave the tower")                    ; it did play and did leave
         !(has? dr "zzzz"))                                 ; ..and ate what was behind it

; --- slop takes what the tower hands it: a token, a purse, and a sign saying so ---
; the walk holds the sign until a key comes -- but it will not HEAR one for half a
; second, because the keys behind the circle's last ring are sitting in the queue when
; the box goes up and are not an answer to it. so the keys cannot be typed up front
; here: wait for the box on the wire, type one INTO the deaf half second, and only
; then the two that take it down and leave.
;
; and the frame count is what convicts it: every frame is one cursor-home. eaten, the
; box is ONE frame and the key that ends it buys one more -- the screen stood still for
; the whole of the wait. heard, the walk is swimming through all of it, and the frames
; it lays down while nobody is reading the pty fill the thing and stand at five.
 sgt (spawn "b/love slop phone 38" 14 64)
 sgm >sgt
 sgseen (: (upto acc) (? (has? acc "one journey yet remains") acc
                         (: ch (see sgm) (? (= ch -1) acc (upto (acc + string ch)))))
           (upto ""))
 _ (say sgm "z")                                            ; typed into the deaf half
 _ (rest 800)
 _ (say sgm "\rq")                                          ; ..and these are heard
 sgtx (sgseen + slurp sgm)
 _ (waitfor <sgt)
 _ (test
    (has? sgtx "what you carry")                            ; the box, titled
    (has? sgtx "phone")                                     ; ..naming what came up
    (has? sgtx "38 pennies")
    (has? sgtx "one journey yet remains")
    (4 > count sgtx "\e[H"))                                ; ..and it stood while deaf
 sn (run "b/love slop" "q" 14 64)
 _ (test !(has? <sn "one journey yet remains"))

; --- slop: the shimmer with a player under it, and only forward moves him ---
; slop paints before it reads, and then keeps painting whether a key comes or not, so
; the same rule as ink applies: wait for the wire to show a painted cell, then type.
; at 12x40 the map is 11 rows of open field: the shore is nineteen world rows off and
; nothing of it is on the screen, so unlike ink there is no painted cell to wait for --
; wait for the road's own pen instead. the climb line is row 7 and a square out here is
; one press.
 st (spawn "b/love slop" 12 40)
 sm >st
 sseen (: (upto acc) (? (has? acc "\e[38;5;94m") acc
                        (: ch (see sm) (? (= ch -1) acc (upto (acc + string ch)))))
          (upto ""))
 _ (say sm "k")                                             ; gap 19, cost 1: one square
 _ (rest 200)
 _ (say sm "jlq")                                           ; back, sideways, then ashore
 stx (sseen + slurp sm)
 _ (waitfor <st)
 ss (: s (mkscr 12 40) _ (scribe s (held stx)) s)
 _ (test
    (has? stx "\e[?1049h") (has? stx "\e[?1049l")            ; on the alternate screen
    !(has? stx "\e[48;5;")                                   ; no slop: the walk starts in a field
    !(has? stx "\e[38;5;180m")                               ; and no sand either
    (0 = cbg ss 0)                                           ; which the grid says too
    ((9 . 23) = at ss)                                       ; one square up, and on the road
    (46 = chat ss (9 * 40 + 24))                             ; the road is three columns wide
    (has? (rowtx ss 11) "you turn back")                     ; the bar, on the last row of 12
    (has? stx "you turn back, 1 press in"))                  ; j and l spent nothing

; --- the story: a level file is a fixed map, so this one place IS a law ---
 d (run "b/love story" ":q\r" 14 60)
 _ (test
    (has? <d "the lighthouse")                               ; the status line names it
    ((8 . 6) = at <>d))                                      ; you stand where the level puts you
 e (run "b/love story" "k:q\r" 14 60)
 _ (test ((7 . 6) = at <>e))                                 ; ..and k is one row north
 _ (test_fin ())
 (puts "tty: ok"))
