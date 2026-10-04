; test/host/mitty.l -- the mitty emulator's moor over a real pty: pty -> parser -> grid, replies
; riding home, exit status. interactive berthing stays a live probe.
; not in the corpus: the screen nifs are not in love0. run: cat test/00-init.l test/host/mitty.l | out/love

(borrow "src/apps/mitty/mitty.l")
(borrow "src/apps/mitty/wharf.l")
(borrow "src/apps/mitty/limn.l")
(borrow 'bytes)

(: (mkscr r c) (screen (cask (screen () r c)) r c)
   (chat s i) (2097151 & glass s i 0)             ; a cell's codepoint
   (rowtx s r) (gaze s 2 @ c
                (foldl (a \ i \ (a + (chat s (r * c + i) @ ch (0 = ch ? " " (utf8 ch)))))
                       "" (jot c))))

; --- a child's plain output lands on the grid, colours and all ---
(: md (tether ["sh" "-c" "printf 'hi\\033[31mred'; exit 3"])
 _ (test (two? md))
 s (mkscr 5 20)
 bx {s}
 _ (moor bx >md ())
 _ (test
    ("hired" = snip (rowtx s 0) 0 5)
    (0 = glass s 1 1)                  ; the h: the default pen
    (1 << 24 | 1 = glass s 2 1))     ; the r: red, index 1
 st (waitfor <md)
 (test (two? st) (3 = <st),       ; the status pair came home
  close >md))

; --- the pty's onlcr: a child's bare \n arrives as \r\n, so columns behave ---
(: md (tether ["sh" "-c" "printf 'a\\nb'"])
 s (mkscr 5 20)
 bx {s}
 (moor bx >md (),
  test (97 = chat s 0)
       (98 = chat s 20),               ; b at row 1 column 0, not under the a
  waitfor <md,
  close >md))

; --- the dialogue lane: a dsr answer rides home and the child reads it ---
; the child asks where the cursor is, drinks the 6-byte "\e[1;1R" answer off
; its own stdin, then says it back through cat -v -- proof the moor forwards
; replies to the pty, and in order. stty raw -echo, as any real full-screen
; guest would: a cooked slave holds input until a newline (the answer has none)
; and would echo it back onto the grid besides.
; the child says what it read rather than discarding it. it used to be
; `head -c 6 >/dev/null`, which passed just as happily while moor wrote the
; answer backwards -- a reply is a byte stream, and a test that never looks at
; the bytes cannot tell "\e[1;1R" from "R1;1[\e".
(: md (tether ["sh" "-c" "stty raw -echo; printf '\\033[6n'; head -c 6 | cat -v"])
 s (mkscr 5 20)
 bx {s}
 (moor bx >md (),
  test ("^[[1;1R" = snip (rowtx s 0) 0 7),
  waitfor <md,
  close >md))

; --- a full-screen guest: clear, address, paint, leave ---
(: md (tether ["sh" "-c" "printf '\\033[2J\\033[3;5Hdeep\\033[7msea'"])
 s (mkscr 6 20)
 bx {s}
 (moor bx >md (),
  test ("    deepsea" = snip (rowtx s 2) 0 11)
       (4 = glass s (2 * 20 + 8) 0 >> 24), ; the s of sea: reverse video
  waitfor <md,
  close >md))

; --- the utf-8 round trip, all the way through the painter: a guest says
; ─ and é; the grid holds their codepoints; full mitty (painter and all, on
; its own pty) says them back out as the same utf-8 ---
(: (find h n i) (i + #n < #h + 1 ? (n = snip h i (i + #n) ? 1 (find h n (i + 1))) 0)
 ; (the octal escapes ride through TWO love readers before sh: hence \\\\)
 md (tether ["out/love" "-l" "src/apps/mitty/mitty.l"
           "-e" "(: _ (borrow 'mitty) (mitty [\"sh\" \"-c\" \"printf 'x\\\\342\\\\224\\\\200y\\\\303\\\\251z'; sleep 1\"]))"])
 outb (slurp >md)
 st (: (wf p) (gather p @ g2 (two? g2 ? g2 (rest 2, wf p))) (wf <md))
 (test (two? st)
       (find outb "x\xe2\x94\x80y" 0)       ; the ─ came back out as utf-8
       (find outb "\xc3\xa9z" 0),        ; ... and the é
  close >md))

; --- the mitty: many panes on one wharf ---------------------------------
; the multiplexing half. mitty's own entry needs a tty (raw/tty) and blocks
; until the last child leaves, so these drive the mitty directly -- the same
; pieces mitty wires up, minus the terminal. a pane is (box master pid).
(: (sub? h n i) (i + #n < #h + 1 ? (n = snip h i (i + #n) ? 1 (sub? h n (i + 1))) 0)
   ; mitty's own opening, with the tty parts left out
   (mkhb r c argv)
    (: p0 (hopen argv r c)
       panes {}
       _ (pin panes 1 p0)
       hb {}
       (pin hb 'plan 1, pin hb 'focus 1, pin hb 'next 2,
        pin hb 'rows r, pin hb 'cols c,
        pin hb 'panes panes, pin hb 'more (_ \ (hopen argv 1 1)),
        pin hb 'dirt {1}, pin hb 'jobs (), pin hb 'lay (),
        hrelay hb,
        hb))
   (scrof hb id) (peep (hbox (hpane hb id)) () 0)

 ; --- one pane is the whole wharf, and its frame starts at the home cell ---
 hb (mkhb 10 20 ["sh" "-c" "printf hi"])
 _ (moor (hbox (hpane hb 1)) (hmas (hpane hb 1)) ())
 f (hframe hb)
 _ (test
    ('((1 0 0 10 20)) = hb 'lay)
    (20 = gaze (scrof hb 1) 2)
    (sub? f "\e[1;1H" 0)                  ; row 0 of the only pane
    (sub? f "hi" 0))
 _ (waitfor (hpid (hpane hb 1)))
 _ (close (hmas (hpane hb 1)))

 ; --- a split re-opens both screens to their new rectangles ----------------
 ; 21 columns divide 10 + bar + 10, and every pty is told what it now has.
 hb2 (mkhb 10 21 ["sh" "-c" "sleep 30"])
 _ (hsplit hb2 'beside)
 ; both pids, before hshut drops the panes that hold them
 p1 (hpid (hpane hb2 1)) p2 (hpid (hpane hb2 2))
 lay (hb2 'lay)
 _ (test
    (2 = #lay)
    (10 = wharf-cols <lay) (10 = wharf-cols <>lay)
    (0 = wharf-col <lay)   (11 = wharf-col <>lay)
    (2 = hb2 'focus)                    ; the new pane takes the focus
    (10 = gaze (scrof hb2 1) 2)         ; pane 1 was re-opened, not left at 21
    (10 = gaze (scrof hb2 2) 2)
    (10 = gaze (scrof hb2 1) 1))        ; the undivided axis is untouched

 ; --- the frame composites: each pane addressed at its own origin, plus a bar
 f2 (hframe hb2)
 (test (sub? f2 "\e[1;1H" 0)                 ; pane 1's first row
       (sub? f2 "\e[1;11H" 0)                ; the bar's own column
       (sub? f2 limn-down 0)                     ; ... drawn with it
       ; anchor on a row the cursor never addresses: it lands on pane 2's origin
       ; too, so "\e[1;12H" alone passes even with the pane painter ignoring it
       (sub? f2 "\e[2;12H" 0)                ; pane 2's second row, one past the bar
       (sub? f2 "\e[10;12H" 0)               ; ... and its last
       (sub? f2 "\e[10;1H" 0),            ; pane 1's last row, at the wharf's edge

  ; --- steering moves the focus and nothing else ---------------------------
  hsteer hb2 'left,
  test (1 = hb2 'focus),
  hsteer hb2 'up,
  test (1 = hb2 'focus),              ; the wall: a no-op, not a condition
  hsteer hb2 'right,
  test (2 = hb2 'focus),

  ; --- shutting promotes the sibling over the bar they shared --------------
  hshut hb2 2,
  test (1 = hb2 'plan)
       (1 = hb2 'focus)                    ; the focus follows the survivor
       ('((1 0 0 10 21)) = hb2 'lay)
       (21 = gaze (scrof hb2 1) 2),     ; and it took the bar's column too
  hshut hb2 1,
  test (() = hb2 'plan)                    ; the empty wharf ends mitty's swim
       (() = wharf-panes (hb2 'plan))
       (() = hb2 'focus),
  waitfor p1, waitfor p2,                 ; hshut hangs their ptys up; reap, or they outlive the file
  map (t \ (landed? t ? (catch t) (freeze t))) (hb2 'jobs)))

; --- the stage door: a stage of this process berths like a child ----------
; its frame lands on its own grid at the pane's size, a key is a step and a repaint,
; a split re-shows it at its new width, a tick door paints when it says so, and the
; step that is its last shuts the pane
(: (sub? h n i) (i + #n < #h + 1 ? (n = snip h i (i + #n) ? 1 (sub? h n (i + 1))) 0)
   (scrof hb id) (peep (hbox (hpane hb id)) () 0)
   keys {} ticks {}
   sg (mitty-stage (w \ h \ ("\e[H\e[2J" + show w + "x" + show h + " k" + show (peep keys () 0) + " t" + show (peep ticks () 0)))
                   (c \ (pin keys () c))
                   (_ \ (113 = peep keys () 0)))
   ; the mitty's opening with a stage as its first pane, the tty parts left out
   (mkhb r c sg argv)
    (: p0 (hopen-stage sg r c)
       panes {}
       _ (pin panes 1 p0)
       hb {}
       (pin hb 'plan 1, pin hb 'focus 1, pin hb 'next 2,
        pin hb 'rows r, pin hb 'cols c,
        pin hb 'panes panes, pin hb 'more (_ \ (hopen argv 1 1)),
        pin hb 'dirt {1}, pin hb 'jobs (), pin hb 'lay (),
        hrelay hb,
        hb))
   hb (mkhb 10 21 sg ["sh" "-c" "sleep 30"])
   _ (test
      !(hpty? (hpane hb 1))
      (sub? (rowtx (scrof hb 1) 0) "21x10 k0 t0" 0)   ; the frame, at the pane's size
      (sub? (hframe hb) "21x10" 0))                   ; ... and out through the painter
   _ (pin (hb 'dirt) () 0)
   _ (hfeed hb 97)
   _ (test
      (97 = peep keys () 0)                          ; the key was a step
      (sub? (rowtx (scrof hb 1) 0) "21x10 k97" 0)      ; ... and a repaint
      (1 = peep (hb 'dirt) () 0))                    ; ... that cued the painter
   ; a split beside: the child takes the new half, the stage is re-shown in its own
   _ (hsplit hb 'beside)
   p2 (hpid (hpane hb 2))
   (test (2 = #(hb 'lay))
         (hpty? (hpane hb 2))
         (10 = gaze (scrof hb 1) 2)
         (sub? (rowtx (scrof hb 1) 0) "10x10 k97" 0),
    hshut hb 2,
    waitfor p2,
    test (sub? (rowtx (scrof hb 1) 0) "21x10 k97" 0),     ; the bar's column back too
    ; the tick door: no on a no, a repaint on a yes
    pin sg 'tick (_ \ (1 + peep ticks () 0 @ n (pin ticks () n, (0 = n % 2)))),
    pin (hb 'dirt) () 0,
    htick hb,
    test (1 = peep ticks () 0) (0 = peep (hb 'dirt) () 0) (sub? (rowtx (scrof hb 1) 0) " t0" 0),
    htick hb,
    test (2 = peep ticks () 0) (1 = peep (hb 'dirt) () 0) (sub? (rowtx (scrof hb 1) 0) " t2" 0),
    ; the last step: the pane is shut, and the wharf is empty
    hfeed hb 113,
    test (() = hb 'plan)
         (() = hpane hb 1)
         (() = hb 'focus),
    map (t \ (landed? t ? (catch t) (freeze t))) (hb 'jobs)))

; --- the clip: copy mode is a vi buffer of the focused pane's screen, a yank in it
; --- is the mitty's register, and a paste is the text typed at a child or handed
; --- to a stage's paste door; a child is copied in a headless mitty with its
; --- output moored first, and a stage's door in another
(: (sub? h n i) (i + #n < #h + 1 ? (n = snip h i (i + #n) ? 1 (sub? h n (i + 1))) 0)
   (mkhb r c p0 argv)
    (: panes {}
       _ (pin panes 1 p0)
       hb {}
       (pin hb 'plan 1, pin hb 'focus 1, pin hb 'next 2,
        pin hb 'rows r, pin hb 'cols c,
        pin hb 'panes panes, pin hb 'more (_ \ (hopen argv 1 1)),
        pin hb 'dirt {1}, pin hb 'jobs (), pin hb 'lay (), pin hb 'clip {},
        hrelay hb,
        hb))
   ; a child said its piece and left; its pane keeps the screen
   hb (mkhb 10 20 (hopen ["sh" "-c" "printf 'hi there\\nsecond'"] 10 20) ["sh" "-c" "sleep 30"])
   _ (moor (hbox (hpane hb 1)) (hmas (hpane hb 1)) ())
   _ (waitfor (hpid (hpane hb 1)))
   rows (hscreen-text (hpane hb 1))
   t0 (hclip-text hb)
   st (hcopy hb)                            ; C-a [: the copy buffer, focused, above
   _ (hfeed hb 121, hfeed hb 121)           ; yy in it: the mitty's register
   clip (peep (hb 'clip) () ())
   t1 (hclip-text hb)
   _ (hfeed hb 106, hfeed hb 121, hfeed hb 119)         ; j yw: a word, charwise
   t2 (hclip-text hb)
   _ (test
      ("hi there" = <rows) ("second" = <>rows) (10 = #rows)
      ("" = t0)
      (tablet? st) ("hi there" = <(st 'lines)) (2 = #(hb 'lay)) (2 = hb 'focus)
      ('lin = <clip) ("hi there\n" = t1)
      ("second" = t2))
   ; a paste into a child: typed at it, and the pty's echo lands it on the grid
   hb2 (mkhb 10 21 (hopen ["sh" "-c" "sleep 30"] 10 21) ["sh" "-c" "sleep 30"])
   _ (hmoor hb2 1)
   _ (pin (hb2 'clip) () ['chr "pasted"])
   _ (hpaste hb2)
   _ (rest 400)
   p2 (hpid (hpane hb2 1))
   rows2 (hscreen-text (hpane hb2 1))
   _ (hshut hb2 1)
   _ (waitfor p2)
   ; a paste into a stage: its door takes the register's value
   got {}
   sg (mitty-stage (w \ h \ "\e[Hstage") (c \ 0) (_ \ 0))
   _ (pin sg 'paste (v \ (pin got () v)))
   hb3 (mkhb 10 20 (hopen-stage sg 10 20) ["sh" "-c" "sleep 30"])
   (pin (hb3 'clip) () ['lin ["a" "b"]],
    hpaste hb3,
    test (sub? <rows2 "pasted" 0)
         ('lin = <(got ())) (["a" "b"] = <>(got ())),
    map (t \ (landed? t ? (catch t) (freeze t))) (hb2 'jobs)))

; --- a stage on a real pane, over a real pty: its frame comes out through the
; painter, and its keys come in through edkey -- q is its last, and mitty ends ---
(: (sub? h n i) (i + #n < #h + 1 ? (n = snip h i (i + #n) ? 1 (sub? h n (i + 1))) 0)
 md (tether ["out/love" "-l" "src/apps/mitty/mitty.l"
             "-e" "(: _ (borrow 'mitty) b {} (mitty (mitty-stage (\\ w h (\"\\e[Hstage \" + show w)) (\\ c (pin b () c)) (\\ _ (= 113 (peep b () 0))))))"])
 _ (test (two? md))
 m >md
 _ (rest 1200)
 _ (put m 113, flush m)                   ; q: the stage's last key
 outb (slurp m)
 (test (sub? outb "stage 80" 0)              ; the frame, painted at the wharf's width
       (sub? outb "\e[?1049l" 0),         ; ... and mitty left
  (: (wf p) (gather p @ g2 (two? g2 ? g2 (rest 2, wf p))) (wf <md)),
  close m))

; --- C-a v, on a real pane, over a real pty -------------------------------
; the prefix intercept is the one piece the mitty laws above cannot reach: it
; lives in the key pump, and a key has to arrive to exercise it. so mitty runs
; on its own pty and the split is typed -- two bytes onto the master -- and the
; bar it draws comes back out in the frames. a fresh pty reports 0x0, so mitty
; falls back to 24x80 and the geometry here is deterministic: 39 + bar + 40.
(: (sub? h n i) (i + #n < #h + 1 ? (n = snip h i (i + #n) ? 1 (sub? h n (i + 1))) 0)
 md (tether ["out/love" "-l" "src/apps/mitty/mitty.l"
             "-e" "(: _ (borrow 'mitty) (mitty [\"sh\" \"-c\" \"sleep 5\"]))"])
 _ (test (two? md))
 m >md
 _ (rest 1200)                            ; let mitty come up and moor its first child
 ; the order is the content: "v C-a" is not the prefix, so the two puts are sequenced
 _ (put m 1, put m 118, flush m)           ; C-a v: split beside
 outb (slurp m)                           ; ... until both children leave and mitty ends
 (test (sub? outb "\e[1;40H" 0)              ; the bar's column, 39 zero-based
       (sub? outb limn-down 0)                   ; ... drawn with the box glyph
       (sub? outb "\e[2;41H" 0),          ; the new pane's second row, past the bar
  (: (wf p) (gather p @ g2 (two? g2 ? g2 (rest 2, wf p))) (wf <md)),
  close m))

; --- the outer terminal's sequences, on a real pane over a real pty: the child scrolls
; TOPMARK away and shift+PgUp brings it back; the child asks for the mouse and a
; bracketed paste, mitty asks the outer terminal for the mouse in turn, and a click and
; a paste sent as the outer terminal sends them reach the child as it asked -- it says
; them back through cat -v. the child's script rides BK, past three layers of quoting ---
(: (sub? h n i) (i + #n < #h + 1 ? (n = snip h i (i + #n) ? 1 (sub? h n (i + 1))) 0)
 _ (setenv "BK" ("printf 'TOPMARK" + cats (map (_ \ "\\n") (jot 30)) + "'; stty raw -echo; "
                 + "printf '\\033[?1000h\\033[?1006h\\033[?2004h'; r=$(dd bs=1 count=33 2>/dev/null); "
                 + "printf '%s' \"$r\" | cat -v; sleep 1"))
 md (tether ["out/love" "-l" "src/apps/mitty/mitty.l"
             "-e" "(: _ (borrow 'mitty) (mitty [\"sh\" \"-c\" \"eval \\\"$BK\\\"\"]))"])
 _ (test (two? md))
 m >md
 _ (rest 1200)
 _ (say m "\e[5;2~") _ (flush m)                  ; shift+PgUp
 _ (rest 400)
 _ (say m "\e[<0;3;2M\e[<0;3;2m\e[200~p\nq\e[201~") _ (flush m)   ; a click at row 2 col 3, a paste
 outb (slurp m)
 (test (sub? outb "TOPMARK" 0)                        ; the history, in view
       (sub? outb "\e[?1000h" 0)                      ; the child's mouse wish, passed out
       (sub? outb "^[[<0;3;2M^[[<0;3;2m^[[200~p^Mq^[[201~" 0), ; ... and the click and paste, passed in
  (: (wf p) (gather p @ g2 (two? g2 ? g2 (rest 2, wf p))) (wf <md)),
  close m))

; --- the pictures themselves: the test answers mitty's kitty query as a kitty terminal
; would, and a sixel the child draws goes out as kitty's own a=t and a=p; cleared away and
; swept by the next, it is freed there ---
(: (sub? h n i) (i + #n < #h + 1 ? (n = snip h i (i + #n) ? 1 (sub? h n (i + 1))) 0)
   (count h n i k) (i + #n < #h + 1 ? (count h n (i + 1) (n = snip h i (i + #n) ? (k + 1) k)) k)
 _ (setenv "BK" ("sleep 1; printf '\\033P0;1;0q#0;2;100;0;0#0!10~-#0!10~\\033\\\\'; sleep 1; "
                 + "printf '\\033[5;1Hzz'; sleep 1; printf '\\033[2J\\033[H\\033P0;1;0q#0;2;0;100;0#0!7~\\033\\\\'; sleep 2"))
 md (tether ["out/love" "-l" "src/apps/mitty/mitty.l"
             "-e" "(: _ (borrow 'mitty) (mitty [\"sh\" \"-c\" \"eval \\\"$BK\\\"\"]))"])
 _ (test (two? md))
 m >md
 _ (rest 500)
 _ (say m "\e_Gi=31;OK\e\\") _ (flush m)             ; yes, kitty
 outb (slurp m)
 (test (sub? outb "\e_Gi=31,s=1,v=1,a=q" 0)                ; mitty asked
       (1 = count outb "\e_Ga=t,f=32,s=10,v=12," 0 0)      ; the picture, sent once while shown
       (sub? outb "\e_Ga=p,i=" 0)                          ; and placed
       (sub? outb "\e_Ga=t,f=32,s=7,v=6," 0)               ; the next, sent
       (sub? outb "\e_Ga=d,d=I,i=" 0)                      ; the first, freed once swept
       (sub? outb "\e_Ga=d,d=A" 0),                     ; and freed on the way out
  (: (wf p) (gather p @ g2 (two? g2 ? g2 (rest 2, wf p))) (wf <md)),
  close m))

; --- ..and as sixels, to a terminal whose DA says 4 and whose cell is 12x24: laid once,
; and not again when the child writes elsewhere ---
(: (sub? h n i) (i + #n < #h + 1 ? (n = snip h i (i + #n) ? 1 (sub? h n (i + 1))) 0)
   (count h n i k) (i + #n < #h + 1 ? (count h n (i + 1) (n = snip h i (i + #n) ? (k + 1) k)) k)
 _ (setenv "BS" "sleep 1; printf '\\033P0;1;0q#0;2;100;0;0#0!10~-#0!10~\\033\\\\'; sleep 1; printf '\\033[5;1Hzz'; sleep 1")
 md (tether ["out/love" "-l" "src/apps/mitty/mitty.l"
             "-e" "(: _ (borrow 'mitty) (mitty [\"sh\" \"-c\" \"eval \\\"$BS\\\"\"]))"])
 _ (test (two? md))
 m >md
 _ (rest 500)
 _ (say m "\e[6;24;12t\e[?62;4;22c") _ (flush m)       ; no kitty: a cell 12x24, and sixels
 outb (slurp m)
 (test (sub? outb "\e[16t\e[c" 0)                         ; mitty asked
       (1 = count outb "\eP0;0;0q\"1;1;" 0 0)             ; the picture, laid once
       (sub? outb "#180;2;100;0;0" 0)
       (sub? outb "zz" 0)                                  ; though the frames went on
       !(sub? outb "\e_Ga=" 0),
  (: (wf p) (gather p @ g2 (two? g2 ? g2 (rest 2, wf p))) (wf <md)),
  close m))

; --- faces: each its own plan over one table of panes; one made on demand, put away and
; brought back, a pane shut on a face not shown, and an emptied face handing over the glass
(: (dsg tag) (mitty-stage (\ w h tag) (\ c 0) (\ _ 0))
   n {0}
   hb (mitty-up 10 20)
   _ (pin hb 'more (_ \ (pin n () (peep n () 0 + 1), hopen-stage (dsg ("pane" + show (peep n () 0))) 1 1)))
   _ (hberth hb 'stack 50 (hb 'more ()))
   _ (hsplit hb 'beside)
   _ (test (0 = hb 'face) ([1 2] = wharf-panes (hb 'plan)) (2 = hb 'focus))
   _ (hfresh hb)
   _ (test (1 = hb 'face) ([3] = wharf-panes (hb 'plan)) ([0] = hfaces hb))
   _ (hgo hb 5)
   _ (test (5 = hb 'face) ([0 1] = hfaces hb) ([4] = wharf-panes (hb 'plan)))
   _ (hcycle hb 1)                                  ; past the last, round to face 0
   _ (test (0 = hb 'face) (2 = hb 'focus) ([1 5] = hfaces hb) (2 = #(hb 'lay)))
   _ (hshut hb 3)                                   ; face 1's only pane: face 1 is gone
   _ (test ([5] = hfaces hb) ([1 2] = wharf-panes (hb 'plan)))
   _ (hshut hb 1)
   _ (hshut hb 2)                                   ; face 0 emptied: face 5 takes the glass
   (test (5 = hb 'face) (() = hfaces hb) ([4] = wharf-panes (hb 'plan)) (4 = hb 'focus)))

; --- the clip goes out through osc 52 once when it changes, and mitty is a verb ---
(: (sub? h n i) (i + #n < #h + 1 ? (n = snip h i (i + #n) ? 1 (sub? h n (i + 1))) 0)
   hb (mitty-up 4 10)
   _ (hberth hb 'stack 50 (hopen-stage (mitty-stage (\ w h "x") (\ c 0) (\ _ 0)) 1 1))
   _ (test (["" "Zg==" "Zm8=" "Zm9v" "YQpi/w=="] = map (s \ b64e s 1) ["" "f" "fo" "foo" "a\nb\xff"])
           !(sub? (hframe hb) "\e]52" 0))
   _ (pin (hb 'clip) () ['chr "hi"])
   (test (sub? (hframe hb) "\e]52;c;aGk=\a" 0)
         !(sub? (hframe hb) "\e]52" 0)
         !(() = peep (cite 'verbs 'tab) 'mitty ())))

; --- hands: a model's tools on the mitty -- the panes listed on every face, a child typed
; into (a newline is Enter) and read back once quiet, its own pane refused, one opened with
; the keyboard left where it was, focus across faces, and a pane shut ---
(: (sub? h n i) (i + #n < #h + 1 ? (n = snip h i (i + #n) ? 1 (sub? h n (i + 1))) 0)
   hb (mitty-up 12 40)
   own {-1}
   hh (hhands hb own)
   _ (pin hb 'more (_ \ hopen ["sh" "-c" "stty -echo; cat"] 1 1))
   _ (hberth hb 'stack 50 (hb 'more ()))                    ; 1: cat
   _ (pin own () (hb 'next))
   _ (hberth hb 'beside 50 (hopen-stage (mitty-stage (\ w h "me") (\ c 0) (\ _ 0)) 1 1))   ; 2: the model
   _ (hfresh hb)                                            ; 3: cat, on face 1
   l (hh 'panes ())
   _ (rest 300)
   t (hh 'type "1" "hello\n")
   r (hh 'read "1")
   mine (hh 'type "2" "x")
   o (hh 'open ())
   f0 (hb 'focus)
   _ (hh 'focus "1")
   (test <l (sub? (l 1) "1  window 0  a program" 0) (sub? (l 1) "2  window 0  a stage" 0)
         (sub? (l 1) "(you)" 0) (sub? (l 1) "3  window 1" 0)
         <t (sub? (t 1) "hello" 0)
         (sub? (r 1) "hello" 0)
         !(<mine)
         !(<(hh 'read "9")) !(<(hh 'read "x1"))
         ("pane 4" = o 1) (3 = f0)                           ; opened on face 1, the keyboard still on 3
         (0 = hb 'face) (1 = hb 'focus),
    hh 'shut "3",
    test (() = hpane hb 3) !(<(hh 'shut "2")),
    map (n \ hshut hb n) [1 4],
    map (t \ (landed? t ? (catch t) (freeze t))) (hb 'jobs)))

; --- the bar: the bottom row, the panes laid above it; the faces with the shown one lit and
; what has the keyboard; a click on a face's label shows that face; names off argv ---
(: (sub? h n i) (i + #n < #h + 1 ? (n = snip h i (i + #n) ? 1 (sub? h n (i + 1))) 0)
   hb (mitty-up 10 40)
   _ (pins hb 'bar 1 'barx (_ \ "XTRA"))
   _ (pin hb 'more (_ \ hopen-stage (mitty-stage (\ w h "s") (\ c 0) (\ _ 0)) 1 1))
   _ (hberth hb 'stack 50 (hopen-stage (pin (mitty-stage (\ w h "s") (\ c 0) (\ _ 0)) 'name "TOPPANE") 1 1))
   _ (hfresh hb)
   _ (hfresh hb)                                     ; faces 0 1 2, 2 shown
   _ (hbartick hb)
   l (hbarline hb)
   f (hframe hb)
   b (<(filter (x \ wharf-id x = hb 'focus) (hb 'lay)))
   _ (hmouse hb 0 2 10 0)                            ; a press on " 0 ", columns 0-2
   (test (9 = hlr hb) (9 = wharf-rows b)               ; the panes stop above the bar
         (sub? l " 0  1 " 0) (sub? l "\e[1;7m 2 " 0)
         (sub? l "stage" 0) (sub? l "XTRA" 0)
         (sub? f "\e[10;1H" 0)                         ; painted on the last row
         (0 = hbarface hb 0) (1 = hbarface hb 4) (() = hbarface hb 30)
         (0 = hb 'face) (sub? (hbarline hb) "TOPPANE" 0)
         ("lush" = hname-of ["/x/out/love" "lush"]) ("vi" = hname-of ["/usr/bin/vi" "f"]) ("love" = hname-of ["love"])))

; --- the picker: typed at, it narrows; enter makes it what its item opens, in its own
; place; an item answering no pane, or esc, closes it ---
(: (stg nm) (pin (mitty-stage (\ w h nm) (\ c 0) (\ _ 0)) 'name nm)
   hb (mitty-up 12 40)
   _ (hberth hb 'stack 50 (hopen-stage (stg "base") 1 1))
   went {0}
   items [["alpha" (_ \ hopen-stage (stg "ALPHA") 1 1)]
          ["beta" (_ \ hopen-stage (stg "BETA") 1 1)]
          ["gone" (_ \ (pin went () 1, ()))]]
   _ (hberth hb 'beside 50 (hpicker hb "open" items))         ; 2, with the keyboard
   f0 (hscreen-text (hpane hb 2))
   _ (map (hfeed hb) [101 116])                              ; "et": beta alone
   f1 (hscreen-text (hpane hb 2))
   _ (hfeed hb 13)
   n2 (hname (hpane hb 2))
   fc (hb 'focus)
   _ (hberth hb 'beside 50 (hpicker hb "open" items))         ; 3
   _ (map (hfeed hb) [-9 -9 10])                              ; down twice: gone
   p3 (hpane hb 3)
   _ (hberth hb 'beside 50 (hpicker hb "open" items))         ; 4
   _ (hfeed hb 27)
   (j ls) (foldl (a \ l \ a + l + "\n") "" ls)
   (test (hsub? (j f0) "alpha") (hsub? (j f0) "gone")
         !(hsub? (j f1) "alpha") (hsub? (j f1) "beta")
         ("BETA" = n2) (2 = fc)                          ; in its own place, still focused
         (1 = peep went () 0) (() = p3)
         (() = hpane hb 4)
         ([1 2] = sort (wharf-panes (hb 'plan)))))

; --- the mouse on a bar: a press takes hold, a drag moves it and the panes with it, a
; release lets go; with 'mouse on, drags are asked for even of a pane that wants none ---
(: (stg nm) (mitty-stage (\ w h nm) (\ c 0) (\ _ 0))
   hb (mitty-up 10 40)
   _ (pin hb 'mouse 1)
   _ (hberth hb 'stack 50 (hopen-stage (stg "a") 1 1))
   _ (hberth hb 'beside 50 (hopen-stage (stg "b") 1 1))
   b0 (wharf-bars (hb 'plan) 10 40)
   _ (hmouse hb 0 20 3 0)                                     ; press on the bar, col 19
   g (hb 'drag)
   _ (hmouse hb 32 11 3 0)                                    ; drag to col 10
   _ (hmouse hb 0 11 3 1)                                     ; let go
   b1 (wharf-bars (hb 'plan) 10 40)
   _ (hmouse hb 32 30 3 0)                                    ; motion, nothing held
   (test ('((down 0 19 10)) = b0)
         ([2 19 'down] = g)
         ('((down 0 10 10)) = b1)
         ('((down 0 10 10)) = wharf-bars (hb 'plan) 10 40)
         (() = hb 'drag)
         (10 = wharf-cols <(hb 'lay))
         ("\e[?1002h" = hmice hb 0)))

; --- the shell's bar text: the hive's live cards only, and a queue's rows and head ---
(: d ("out/.mitty-bar-" + show (getpid 0))
   _ (hark ["sh" "-c" ("rm -rf " + d + "; mkdir -p " + d + "/hive/live " + d + "/hive/dead; "
                       + "printf 'pid " + show (getpid 0) + "\\nstate idle\\n' > " + d + "/hive/live/card; "
                       + "printf 'pid 999999\\n' > " + d + "/hive/dead/card; "
                       + "git init -q " + d + "/repo; cd " + d + "/repo; "
                       + "h=$(printf '# header\\nleader x\\n7 alice feat - - waiting  # n\\n8 bob b2 - - waiting\\n' | git hash-object -w --stdin); "
                       + "git update-ref refs/queue/main $h")])
   _ (setenv "BEE_HIVE" (d + "/hive"))
   _ (setenv "GIT_DIR" (d + "/repo/.git"))
   hv (mitty-hive 0)
   qs (mitty-queues 0)
   bx (mitty-barx 0)
   x1 (bx ())
   _ (setenv "BEE_HIVE" (d + "/none"))
   x2 (bx ())                                                ; within ten seconds: as it was
   _ (setenv "BEE_HIVE" "")
   _ (setenv "GIT_DIR" "")
   _ (hark ["rm" "-rf" d])
   (test (1 = hv)
         (["main 2 rows, alice waiting"] = qs)
         ("hive 1 · main 2 rows, alice waiting" = x1)
         (x1 = x2)))

; --- idle: the saver takes the glass after its minutes (C-a z winds them past), the
; mitty's frames wait under it, and the key that wakes it is its own and owes a frame ---
(: (sub? h n i) (i + #n < #h + 1 ? (n = snip h i (i + #n) ? 1 (sub? h n (i + 1))) 0)
   hb (mitty-up 10 40)
   _ (hberth hb 'stack 50 (hopen-stage (mitty-stage (\ w h "x") (\ c 0) (\ _ 0)) 1 1))
   _ (pin hb 'saver ((cite 'saver 'saver-watch) "life" 5))
   f0 (hidle hb)
   k0 (hwake hb)                                    ; a key with no saver up: activity only
   f1 (hidle hb)
   on1 (hidle? hb)
   _ (hsleep hb)
   f2 (hidle hb)
   on2 (hidle? hb)
   _ (pin (hb 'dirt) () 0)
   k1 (hwake hb)
   f3 (hidle hb)
   (test ("" = f0) (0 = k0) ("" = f1) !on1
         (sub? f2 "\e[?25l" 0) on2
         (1 = k1) (1 = peep (hb 'dirt) () 0)
         (sub? f3 "\e[?25h" 0) !(hidle? hb)
         (() = (cite 'saver 'saver-watch "nosuch" 5) 'on)
         (0 = hsleep (pins (mitty-up 4 10) 'saver ((cite 'saver 'saver-watch) "nosuch" 5)))))

; --- quiet: the saver's clock runs only while every pane on the shown face is a bare shell, at its
; prompt with no job in front, and with no pane at all; a stage or a program holds it off
(: (wound hb) (: w ((cite 'saver 'saver-watch) "life" 5) _ (pin hb 'saver w) _ (pin w 'last (clock 0 - 3600000))
                 _ (hidle hb) (hidle? hb))
   (closed hb) (map (id \ hshut hb id) (wharf-panes (hb 'plan)))
   e (mitty-up 10 40)
   st (mitty-up 10 40) _ (hberth st 'stack 50 (hopen-stage (mitty-stage (\ w h "x") (\ c 0) (\ _ 0)) 1 1))
   ca (mitty-up 10 40) _ (hberth ca 'stack 50 (hopen ["cat"] 10 40))
   sh (mitty-up 10 40) _ (hberth sh 'stack 50 (hopen ["sh"] 10 40))
   (settled n) (? (hquiet? sh || n <= 0) (hquiet? sh) (: _ (rest 50) (settled (n - 1))))
   q3 (settled 40)
   r (: s1 (hquiet? e) s2 (hquiet? st) s3 (hquiet? ca) [s1 s2 s3])
   on (map (h \ (wound h ? 1 0)) [e st ca sh])
   _ (map closed [st ca sh])
   (test (r 0) !(r 1) !(r 2) q3
         (on = [1 0 0 1])))

; --- the server: a mitty on a socket outlives its clients. a client says its size, types,
; and leaves; the next sees what the first left on the screen; the last pane's exit ends
; the server, its socket with it ---

; --- a pane never attaches to the mitty it is in: MITTY names that one, and asking for it
; again is refused, with nothing attached and nothing started
(: d ("out/.mitty-in-" + show (getpid 0))
   _ (setenv "MITTY_RUN" d)
   _ (setenv "MITTY" (mitty-sock "zz"))
   r (mitty-main ["-n" "zz"])
   _ (setenv "MITTY" "") _ (setenv "MITTY_RUN" "")
   (test (1 = r) !(two? (stat (d + "/zz.sock")))))

(: (sub? h n i) (i + #n < #h + 1 ? (n = snip h i (i + #n) ? 1 (sub? h n (i + 1))) 0)
   d ("out/.mitty-srv-" + show (getpid 0))
   _ (hark ["rm" "-rf" d])
   _ (setenv "MITTY_RUN" d)
   path (d + "/s.sock")
   md (tether ["out/love" "mitty" "--serve" "s"])
   ; what the server says for ms milliseconds, or until it closes
   (rd s ms) (: (go acc t) (? (t <= 0) acc
                               (cue? s) (see s @ b (b < 0 ? acc (go (acc + string b) t)))
                               (: _ (rest 50) (go acc (t - 50))))
                (go "" ms))
   (up n) (? (n = 0) () (: s (connect ['unix path]) (hot? s ? s (: _ (rest 50) (up (n - 1))))))
   s1 (up 60)
   _ (say s1 (mitty-size 12 50), flush s1)
   o1 (rd s1 1500)
   _ (say s1 "echo HAR''BOUR\r", flush s1)
   o1b (rd s1 1500)
   _ (close s1)                                              ; a client leaves
   _ (rest 300)
   s2 (up 20)
   _ (say s2 (mitty-size 12 50), flush s2)
   o2 (rd s2 1500)
   _ (say s2 "exit\r", flush s2)
   o3 (rd s2 4000)
   _ (rest 300)
   gone !(two? (stat path))
   _ (setenv "MITTY_RUN" "")
   _ (hark ["rm" "-rf" d])
   (test (hot? s1) (sub? o1 "\e[?1049h" 0)                   ; greeted
         (sub? o1b "HARBOUR" 0)
         (hot? s2) (sub? o2 "HARBOUR" 0)                     ; the screen kept
         (sub? o3 "\e[?1049l" 0)                             ; given back as it was
         gone,
    (: (wf p) (gather p @ g2 (two? g2 ? g2 (rest 20, wf p))) (wf <md)),
    close >md))

(test_fin ())
(puts "mitty: ok")
