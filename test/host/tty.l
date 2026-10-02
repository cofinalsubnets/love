; test/host/tty.l -- the tty app runners on a real terminal: `tether` spawns the verb on a pty,
; we type at the master and scribe what comes back onto a quay screen, so a law is about the grid.
; the size is set by `stty` inside the child: a fresh pty is 0x0 and a parent's settty races the
; child's first read. no escape key ever: ESC then a key reads as alt-key, and a child that never
; quits is killed at the deadline so its law reads red.
; not in the corpus: tether is not in love0. run: cat test/00-init.l test/host/tty.l | out/love
(borrow 'synth)   ; the keyboard's own naming of a note, for the alt law
(: reaped {}                                           ; pids waitfor has had back
   deadline 20000                                              ; ms a child may take
   (waitfor pid) (gather pid @ s
                    (two? s || nom? s ? (pin reaped pid 1, s) (do (rest 2) (waitfor pid))))
   ; the child's whole session goes at the deadline (tether's child leads one), so the
   ; read at the master ends and the waitfor after it lands
   (watch pid t0) (? (peep reaped pid 0) 0
                     (deadline < clock t0) (still (0 - pid) 9)
                     (rest 50, watch pid t0))
   (guard t) ((two? t ? (twirl (_ \ watch <t (clock 0)) 0) 0), t)
   (has? h n) (: k #n m #h
                 (go i) (? (m - k < i) 0 (n = snip h i (i + k)) 1 (go (i + 1)))
                 (go 0))
   ; the wire read until a phrase has passed, as the text so far: a read at a time, the
   ; phrase sought only where the new bytes could finish it. a byte at a time costs a
   ; frame half a second, which is longer than the deafest box stays deaf
   (wire p n) (: (go acc) (see p @ ch
                             (ch = -1 ? acc
                                (: acc2 (acc + string ch + chug p)
                                   from (max 0 (#acc - #n))
                                   (0 <= findsub (snip acc2 from #acc2) n ? acc2 (go acc2)))))
                 (go ""))
   (blank? t) (foldl (a \ ch \ (a && ch = 32)) 1 t)
   (count h n) (: k #n m #h
                  (go i c) (? (m - k < i) c
                              (n = snip h i (i + k)) (go (i + k) (c + 1))
                              (go (i + 1) c))
                  (go 0 0))
   ; the stream up to the last alt-screen leave. quay honours 1049, so scribing a
   ; whole run would lay the empty primary screen back over the app's last frame --
   ; what is wanted is the grid as the app left it, not as the terminal got it back.
   (held h) (: n #h k 8
               (go i best) (? (n < i + k) best
                            ("\e[?1049l" = snip h i (i + k)) (go (i + 1) i)
                            (go (i + 1) best))
               (go 0 -1 @ b (b < 0 ? h (snip h 0 b))))
   (mkscr r c) (screen (cask (screen () r c)) r c)
   (chat s i) (2097151 & glass s i 0)
   (cbg s i) (glass s i 2 @ k (k >> 24 = 1 ? (k & 255) 0))   ; a bg index, 0 for the default
   (rowtx s r) (gaze s 2 @ c
                  (foldl (a \ i \ (a + (chat s (r * c + i) @ ch (0 = ch ? " " (utf8 ch)))))
                         "" (jot c)))
   ; the climb's floor is seeded off the clock, so where @ stands is nobody's law --
   ; that it stands somewhere is
   (at s) (: c (gaze s 2) r (gaze s 1)
             (go i) (? (r * c <= i) () (64 = chat s i) ((i // c) . (i % c)) (go (i + 1)))
             (go 0))
   (spawn cmd r c)
    (guard (tether ["sh" "-c" ("stty rows " + show r + " columns " + show c + " -echo; exec " + cmd)]))
   ; spawn at r x c, type, read to the end, and lay the held grid: [stream screen]
   (run cmd keys r c)
    (: t (spawn cmd r c)
       _ (test (two? t))
       m >t
       _ (say m keys)
       txt (slurp m)
       _ (waitfor <t)
       s (mkscr r c)
       (scribe s (held txt),
        [txt s]))

; --- tower: the climb takes the terminal's size, and a key is a turn ---
; the bar is the last row, which is the geometry law -- but only away from 80x24. a
; sizeless climb falls back to a 22-row floor, which with the note and the bar is 24
; lines exactly, so the same grid comes out whether the tty was read or missed and
; the law at 24 rows is vacuous. 20x70 is nobody's fallback.
 a (run "out/love lore tower" "q" 20 70)
 _ (test
    (has? <a "\e[?1049h")                                   ; the alternate screen
    ("finally, the tower" = snip (rowtx <>a 0) 0 18)         ; the note, no turn taken
    ("the garden" = snip (rowtx <>a 19) 0 10)                ; the bar, on row 19 of 20
    (has? <a "you leave the tower"))                         ; q leaves
 ; (the opening sign covers most of the floor, so where you stand is asked of the
 ; run below, once a key has taken the sign down)

; --- ..and a turn spends the note. the boot message stands until the first one, so a
;     blank row 0 is the climb saying it read a key -- nothing else here can say it
 b (run "out/love lore tower" "hjklq" 20 70)
 _ (test
    (blank? (rowtx <>b 0))
    ("the garden" = snip (rowtx <>b 19) 0 10)
    (at <>b))

; --- ..and an arrow's three bytes are one key. read as a bare ESC they would be quit
;     (the climb's own second quit key), the h behind them unread and the note still on
;     row 0 -- so a spent note is exactly the law that the csi was decoded
 c (run "out/love lore tower" "\e[Chq" 20 70)
 _ (test (blank? (rowtx <>c 0)) (has? <c "you leave the tower"))

; --- what was typed at the game is not typed at the shell ---
; raw mode does not echo, so keys the game never reads sit in the terminal's queue and
; are read by whatever comes next -- a prompt takes them as a line typed at it. the tower
; reads exactly one key a turn, so a burst behind the quit is a burst left over: z takes
; the sign down, q leaves, and the four behind them are the ones that must not survive.
; the reader after it is non-blocking (min 0 time), so it answers whether or not there
; is anything there, which is the whole question.
 dr (: t (guard (tether ["sh" "-c" ("stty rows 20 columns 70 -echo; out/love lore tower; "
                                    + "stty -icanon min 0 time 3; cat")]))
       m >t
       ; the keys wait for raw mode: typed before it, the tty echoes them back and the
       ; leftovers cannot be told from the echo of the ones that were read
       _ (rest 500)
       _ (say m "zqzzzz")
       txt (slurp m)
       (waitfor <t,
        txt))
 _ (test (has? dr "you leave the tower")                    ; it did play and did leave
         !(has? dr "zzzz"))                                 ; ..and ate what was behind it

; --- slop takes what the tower hands it: a token, a purse, and a sign saying so ---
; the walk holds the sign until a key comes -- but it will not hear one for half a
; second, because the keys behind the circle's last ring are sitting in the queue when
; the box goes up and are not an answer to it. so the keys cannot be typed up front
; here: wait for the box on the wire, type one into the deaf half second, and only
; then the two that take it down and leave.
;
; and the frame count is what convicts it: every frame is one cursor-home. eaten, the
; box is one frame and the key that ends it buys one more -- the screen stood still for
; the whole of the wait. heard, the walk is swimming through all of it, and the frames
; it lays down while nobody is reading the pty fill the thing and stand at five.
 sgt (spawn "out/love lore slop phone 38" 14 64)
 sgm >sgt
 sgseen (wire sgm "-- any key --")
 _ (say sgm "z")                                            ; typed into the deaf half
 _ (rest 800)
 _ (say sgm "\rq")                                          ; ..and these are heard
 sgtx (sgseen + slurp sgm)
 _ (waitfor <sgt)
 _ (test
    (has? sgtx "is this still the tower?")                 ; the box, titled
    (has? sgtx "phone")                                     ; ..naming what came up
    (has? sgtx "38 pennies")
    (has? sgtx "forward remains")                           ; ..the line, wrapped at 64
    (4 > count sgtx "\e[H"))                                ; ..and it stood while deaf
 sn (run "out/love lore slop" "q" 14 64)
 _ (test !(has? <sn "forward remains"))

; --- slop: the shimmer with a player under it, and only forward moves him ---
; slop paints before it reads, and then keeps painting whether a key comes or not, so
; the same rule as ink applies: wait for the wire to show a painted cell, then type.
; at 12x40 the map is 11 rows of open field: the shore is nineteen world rows off and
; nothing of it is on the screen, so unlike ink there is no painted cell to wait for --
; wait for the road's own pen instead. the climb line is row 7 and a square out here is
; one press.
 st (spawn "out/love lore slop" 12 40)
 sm >st
 sseen (wire sm "\e[38;5;94m")
 _ (say sm "k")                                             ; gap 19, cost 1: one square
 _ (rest 200)
 _ (say sm "jlq")                                           ; back, sideways, then ashore
 stx (sseen + slurp sm)
 _ (waitfor <st)
 ss (mkscr 12 40 @ s (scribe s (held stx), s))
 _ (test
    (has? stx "\e[?1049h") (has? stx "\e[?1049l")            ; on the alternate screen
    !(has? stx "\e[48;5;")                                   ; no slop: the walk starts in a field
    !(has? stx "\e[38;5;180m")                               ; and no sand either
    (0 = cbg ss 0)                                           ; which the grid says too
    ((9 . 23) = at ss)                                       ; one square up, and on the road
    (46 = chat ss (9 * 40 + 24))                             ; the road is three columns wide
    (has? (rowtx ss 11) "you turn back")                     ; the bar, on the last row of 12
    (has? stx "you turn back, 1 press in\r\n"))              ; j and l spent nothing -- and the
                                                            ; line ends, so a prompt after it
                                                            ; starts a row of its own

; --- the story: a level file is a fixed map, so this one place is a law ---
 d (run "out/love lore story" ":q\r" 14 60)
 _ (test
    (has? <d "the lighthouse")                               ; the status line names it
    ((8 . 6) = at <>d))                                      ; you stand where the level puts you
 e (run "out/love lore story" "k:q\r" 14 60)
 _ (test ((7 . 6) = at <>e))                                 ; ..and k is one row north
; --- the synth: alt is an escape before the key, and the two arrive in one write -- the
; --- quarter tone is struck, not an escape dropped and then a plain note. the key goes
; --- in once the legend's first cell is on the wire, so the tty is raw and the keys'
; --- pane painted by then, and q a breath after it, so the key's answer has been
; --- painted; the mitty puts the keys over a buffer, so the rows are what holds the
; --- whole of the keys' frame. a screen that never shows the answer fails the law
 sq (synth-new ())
 c4 (synth-digits 0 . synth-name (synth-semis sq [0 0 0]))  ; the first key and its note, as the legend cells them
 an (synth-name (synth-semis sq [0 0 1]))
 sy (spawn "env HORN=none out/love synth" 16 70)
 sm >sy
 a1 (wire sm (string <c4 + " " + >c4))
 _ (say sm "\e1", flush sm)
 _ (rest 300)
 _ (say sm "q", flush sm)
 a2 (slurp sm)
 _ (waitfor <sy)
 _ (test !(has? a1 an) (has? a2 an))                       ; not on the legend, on the screen after the key
; --- the shaft: a first frame of half blocks comes, and q ends it ---
 (blocks m acc k n) ((k < n ? (see m) -1) @ c
                       (c < 0 ? acc
                        (: acc2 (acc + string c) l #acc2
                           (blocks m acc2 (k + (3 <= l && "▀" = snip acc2 (l - 3) l)) n))))
 sh (spawn "env HORN=none out/love lore shaft" 12 70)
 shm >sh
 b1 (blocks shm "" 0 840)
 ((say shm "q", flush shm),
  slurp shm,
  waitfor <sh,
  test (840 <= #b1 // 3),                                   ; a frame's worth of half blocks came
  ; the courtyard, likewise: its maps laid, a frame of half blocks, and q ends it
  (: cs (spawn "env HORN=none out/love lore tree" 12 70) csm >cs
     b2 (blocks csm "" 0 840)
     ((say csm "q", flush csm), slurp csm, waitfor <cs, test (840 <= #b2 // 3))),
  test_fin (),
  puts "tty: ok"))
