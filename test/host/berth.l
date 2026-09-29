; --- test/host/berth.l: the berth emulator's moor, end to end over a real pty ---
; not in the test/*.l corpus (screen/scribe/tether live in love/*.c; love0 links
; none of them). loads the berth library off disk with reads, berths real
; children, and reads the grid back through the glass:
;
;   cat test/00-init.l test/host/berth.l | out/love
;
; interactive berthing (raw tty, keys, repaint) stays a live probe -- this
; verifies the moor: pty -> parser -> grid, replies riding home, exit status.

(borrow "apps/berth/berth.l")
(borrow "apps/berth/wharf.l")
(borrow "apps/berth/limn.l")

(: (mkscr r c) (screen (cask (screen () r c)) r c)
   (chat s i) (2097151 & glass s i 0)             ; a cell's codepoint
   (rowtx s r) (: c (gaze s 2)
                (foldl (\ a i (a + (: ch (chat s ((r * c) + i)) (0 = ch ? " " (utf8 ch)))))
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
    ((1 << 24 | 1) = glass s 2 1))     ; the r: red, index 1
 st (waitfor <md)
 _ (test (two? st) (3 = <st))     ; the status pair came home
 (close >md))

; --- the pty's onlcr: a child's bare \n arrives as \r\n, so columns behave ---
(: md (tether ["sh" "-c" "printf 'a\\nb'"])
 s (mkscr 5 20)
 bx {s}
 _ (moor bx >md ())
 _ (test
    (97 = chat s 0)
    (98 = chat s 20))                  ; b at row 1 column 0, not under the a
 _ (waitfor <md)
 (close >md))

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
 _ (moor bx >md ())
 _ (test ("^[[1;1R" = snip (rowtx s 0) 0 7))
 _ (waitfor <md)
 (close >md))

; --- a full-screen guest: clear, address, paint, leave ---
(: md (tether ["sh" "-c" "printf '\\033[2J\\033[3;5Hdeep\\033[7msea'"])
 s (mkscr 6 20)
 bx {s}
 _ (moor bx >md ())
 _ (test
    ("    deepsea" = snip (rowtx s 2) 0 11)
    (4 = (glass s ((2 * 20) + 8) 0 >> 24)))   ; the s of sea: reverse video
 _ (waitfor <md)
 (close >md))

; --- the utf-8 round trip, all the way through the painter: a guest says
; ─ and é; the grid holds their codepoints; full berth (painter and all, on
; its own pty) says them back out as the same utf-8 ---
(: (find h n i) ((i + #n) < (#h + 1) ? (n = snip h i (i + #n) ? 1 (find h n (i + 1))) 0)
 ; (the octal escapes ride through TWO love readers before sh: hence \\\\)
 md (tether ["out/love" "-l" "apps/berth/berth.l"
           "-e" "(: _ (borrow 'berth) (berth [\"sh\" \"-c\" \"printf 'x\\\\342\\\\224\\\\200y\\\\303\\\\251z'; sleep 1\"]))"])
 outb (slurp >md)
 st (: (wf p) (: g2 (gather p) (two? g2 ? g2 (rest 2, wf p))) (wf <md))
 _ (test
    (two? st)
    (find outb "x\xe2\x94\x80y" 0)       ; the ─ came back out as utf-8
    (find outb "\xc3\xa9z" 0))           ; ... and the é
 (close >md))

; --- the harbour: many berths on one wharf ---------------------------------
; the multiplexing half. berth's own entry needs a tty (raw/tty) and blocks
; until the last child leaves, so these drive the harbour directly -- the same
; pieces berth wires up, minus the terminal. a pane is (box master pid).
(: (sub? h n i) ((i + #n) < (#h + 1) ? (n = snip h i (i + #n) ? 1 (sub? h n (i + 1))) 0)
   ; berth's own opening, with the tty parts left out
   (mkhb r c argv)
    (: p0 (hopen argv r c)
       panes {}
       _ (pin panes 1 p0)
       hb {}
       _ (pin hb 'plan 1) _ (pin hb 'focus 1) _ (pin hb 'next 2)
       _ (pin hb 'rows r) _ (pin hb 'cols c)
       _ (pin hb 'panes panes) _ (pin hb 'more (\ _ (hopen argv 1 1)))
       _ (pin hb 'dirt {1}) _ (pin hb 'jobs ()) _ (pin hb 'lay ())
       _ (hrelay hb)
       hb)
   (scrof hb id) (peep (hbox (hpane hb id)) () 0)

 ; --- one berth is the whole wharf, and its frame starts at the home cell ---
 hb (mkhb 10 20 ["sh" "-c" "printf hi"])
 _ (moor (hbox (hpane hb 1)) (hmas (hpane hb 1)) ())
 f (hframe hb)
 _ (test
    ('((1 0 0 10 20)) = (hb 'lay))
    (20 = (gaze (scrof hb 1) 2))
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
    (10 = (wharf-cols <lay)) (10 = (wharf-cols <>lay))
    (0 = (wharf-col <lay))   (11 = (wharf-col <>lay))
    (2 = (hb2 'focus))                    ; the new berth takes the focus
    (10 = (gaze (scrof hb2 1) 2))         ; pane 1 was re-opened, not left at 21
    (10 = (gaze (scrof hb2 2) 2))
    (10 = (gaze (scrof hb2 1) 1)))        ; the undivided axis is untouched

 ; --- the frame composites: each pane addressed at its own origin, plus a bar
 f2 (hframe hb2)
 _ (test
    (sub? f2 "\e[1;1H" 0)                 ; pane 1's first row
    (sub? f2 "\e[1;11H" 0)                ; the bar's own column
    (sub? f2 limn-down 0)                     ; ... drawn with it
    ; anchor on a row the cursor never addresses: it lands on pane 2's origin
    ; too, so "\e[1;12H" alone passes even with the pane painter ignoring it
    (sub? f2 "\e[2;12H" 0)                ; pane 2's second row, one past the bar
    (sub? f2 "\e[10;12H" 0)               ; ... and its last
    (sub? f2 "\e[10;1H" 0))               ; pane 1's last row, at the wharf's edge

 ; --- steering moves the focus and nothing else ---------------------------
 _ (hsteer hb2 'left)
 _ (test (1 = (hb2 'focus)))
 _ (hsteer hb2 'up)
 _ (test (1 = (hb2 'focus)))            ; the wall: a no-op, not a condition
 _ (hsteer hb2 'right)
 _ (test (2 = (hb2 'focus)))

 ; --- shutting promotes the sibling over the bar they shared --------------
 _ (hshut hb2 2)
 _ (test
    (1 = (hb2 'plan))
    (1 = (hb2 'focus))                    ; the focus follows the survivor
    ('((1 0 0 10 21)) = (hb2 'lay))
    (21 = (gaze (scrof hb2 1) 2)))        ; and it took the bar's column too
 _ (hshut hb2 1)
 _ (test
    (() = (hb2 'plan))                    ; the empty wharf ends berth's swim
    (() = (wharf-berths (hb2 'plan)))
    (() = (hb2 'focus)))
 _ (waitfor p1) _ (waitfor p2)            ; hshut hangs their ptys up; reap, or they outlive the file
 (map (\ t (landed? t ? (catch t) (freeze t))) (hb2 'jobs)))

; --- the stage door: a stage of this process berths like a child ----------
; its frame lands on its own grid at the pane's size, a key is a step and a repaint,
; a split re-shows it at its new width, a tick door paints when it says so, and the
; step that is its last shuts the pane
(: (sub? h n i) ((i + #n) < (#h + 1) ? (n = snip h i (i + #n) ? 1 (sub? h n (i + 1))) 0)
   (scrof hb id) (peep (hbox (hpane hb id)) () 0)
   keys {} ticks {}
   sg (berth-stage (\ w h ("\e[H\e[2J" + show w + "x" + show h + " k" + show (peep keys () 0) + " t" + show (peep ticks () 0)))
                   (\ c (pin keys () c))
                   (\ _ (113 = peep keys () 0)))
   ; the harbour's opening with a stage as its first berth, the tty parts left out
   (mkhb r c sg argv)
    (: p0 (hopen-stage sg r c)
       panes {}
       _ (pin panes 1 p0)
       hb {}
       _ (pin hb 'plan 1) _ (pin hb 'focus 1) _ (pin hb 'next 2)
       _ (pin hb 'rows r) _ (pin hb 'cols c)
       _ (pin hb 'panes panes) _ (pin hb 'more (\ _ (hopen argv 1 1)))
       _ (pin hb 'dirt {1}) _ (pin hb 'jobs ()) _ (pin hb 'lay ())
       _ (hrelay hb)
       hb)
   hb (mkhb 10 21 sg ["sh" "-c" "sleep 30"])
   _ (test
      (!(hpty? (hpane hb 1)))
      (sub? (rowtx (scrof hb 1) 0) "21x10 k0 t0" 0)   ; the frame, at the pane's size
      (sub? (hframe hb) "21x10" 0))                   ; ... and out through the painter
   _ (pin (hb 'dirt) () 0)
   _ (hfeed hb 97)
   _ (test
      (97 = (peep keys () 0))                          ; the key was a step
      (sub? (rowtx (scrof hb 1) 0) "21x10 k97" 0)      ; ... and a repaint
      (1 = (peep (hb 'dirt) () 0)))                    ; ... that cued the painter
   ; a split beside: the child takes the new half, the stage is re-shown in its own
   _ (hsplit hb 'beside)
   p2 (hpid (hpane hb 2))
   _ (test
      (2 = #(hb 'lay))
      (hpty? (hpane hb 2))
      (10 = (gaze (scrof hb 1) 2))
      (sub? (rowtx (scrof hb 1) 0) "10x10 k97" 0))
   _ (hshut hb 2)
   _ (waitfor p2)
   _ (test (sub? (rowtx (scrof hb 1) 0) "21x10 k97" 0))   ; the bar's column back too
   ; the tick door: no on a no, a repaint on a yes
   _ (pin sg 'tick (\ _ (: n (1 + peep ticks () 0) _ (pin ticks () n) (0 = n % 2))))
   _ (pin (hb 'dirt) () 0)
   _ (htick hb)
   _ (test (1 = (peep ticks () 0)) (0 = (peep (hb 'dirt) () 0)) (sub? (rowtx (scrof hb 1) 0) " t0" 0))
   _ (htick hb)
   _ (test (2 = (peep ticks () 0)) (1 = (peep (hb 'dirt) () 0)) (sub? (rowtx (scrof hb 1) 0) " t2" 0))
   ; the last step: the pane is shut, and the wharf is empty
   _ (hfeed hb 113)
   _ (test
      (() = (hb 'plan))
      (() = (hpane hb 1))
      (() = (hb 'focus)))
   (map (\ t (landed? t ? (catch t) (freeze t))) (hb 'jobs)))

; --- the clip: copy mode is a vi buffer of the focused pane's screen, a yank in it
; --- is the harbour's register, and a paste is the text typed at a child or handed
; --- to a stage's paste door; a child is copied in a headless harbour with its
; --- output moored first, and a stage's door in another
(: (sub? h n i) ((i + #n) < (#h + 1) ? (n = snip h i (i + #n) ? 1 (sub? h n (i + 1))) 0)
   (mkhb r c p0 argv)
    (: panes {}
       _ (pin panes 1 p0)
       hb {}
       _ (pin hb 'plan 1) _ (pin hb 'focus 1) _ (pin hb 'next 2)
       _ (pin hb 'rows r) _ (pin hb 'cols c)
       _ (pin hb 'panes panes) _ (pin hb 'more (\ _ (hopen argv 1 1)))
       _ (pin hb 'dirt {1}) _ (pin hb 'jobs ()) _ (pin hb 'lay ()) _ (pin hb 'clip {})
       _ (hrelay hb)
       hb)
   ; a child said its piece and left; its pane keeps the screen
   hb (mkhb 10 20 (hopen ["sh" "-c" "printf 'hi there\\nsecond'"] 10 20) ["sh" "-c" "sleep 30"])
   _ (moor (hbox (hpane hb 1)) (hmas (hpane hb 1)) ())
   _ (waitfor (hpid (hpane hb 1)))
   rows (hscreen-text (hpane hb 1))
   t0 (hclip-text hb)
   st (hcopy hb)                            ; C-a [: the copy buffer, focused, above
   _ (hfeed hb 121) _ (hfeed hb 121)        ; yy in it: the harbour's register
   clip (peep (hb 'clip) () ())
   t1 (hclip-text hb)
   _ (hfeed hb 106) _ (hfeed hb 121) _ (hfeed hb 119)   ; j yw: a word, charwise
   t2 (hclip-text hb)
   _ (test
      ("hi there" = <rows) ("second" = <>rows) (10 = #rows)
      ("" = t0)
      (tablet? st) ("hi there" = <(st 'lines)) (2 = #(hb 'lay)) (2 = (hb 'focus))
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
   sg (berth-stage (\ w h "\e[Hstage") (\ c 0) (\ _ 0))
   _ (pin sg 'paste (\ v (pin got () v)))
   hb3 (mkhb 10 20 (hopen-stage sg 10 20) ["sh" "-c" "sleep 30"])
   _ (pin (hb3 'clip) () ['lin ["a" "b"]])
   _ (hpaste hb3)
   _ (test
      (sub? <rows2 "pasted" 0)
      ('lin = <(peep got () ())) (["a" "b"] = <>(peep got () ())))
   (map (\ t (landed? t ? (catch t) (freeze t))) (hb2 'jobs)))

; --- a stage on a real berth, over a real pty: its frame comes out through the
; painter, and its keys come in through edkey -- q is its last, and berth ends ---
(: (sub? h n i) ((i + #n) < (#h + 1) ? (n = snip h i (i + #n) ? 1 (sub? h n (i + 1))) 0)
 md (tether ["out/love" "-l" "apps/berth/berth.l"
             "-e" "(: _ (borrow 'berth) b {} (berth (berth-stage (\\ w h (\"\\e[Hstage \" + show w)) (\\ c (pin b () c)) (\\ _ (= 113 (peep b () 0))))))"])
 _ (test (two? md))
 m >md
 _ (rest 1200)
 _ (put m 113) _ (flush m)                ; q: the stage's last key
 outb (slurp m)
 _ (test
    (sub? outb "stage 80" 0)              ; the frame, painted at the wharf's width
    (sub? outb "\e[?1049l" 0))            ; ... and berth left
 _ (: (wf p) (: g2 (gather p) (two? g2 ? g2 (rest 2, wf p))) (wf <md))
 (close m))

; --- C-a v, on a real berth, over a real pty -------------------------------
; the prefix intercept is the one piece the harbour laws above cannot reach: it
; lives in the key pump, and a key has to arrive to exercise it. so berth runs
; on its own pty and the split is typed -- two bytes onto the master -- and the
; bar it draws comes back out in the frames. a fresh pty reports 0x0, so berth
; falls back to 24x80 and the geometry here is deterministic: 39 + bar + 40.
(: (sub? h n i) ((i + #n) < (#h + 1) ? (n = snip h i (i + #n) ? 1 (sub? h n (i + 1))) 0)
 md (tether ["out/love" "-l" "apps/berth/berth.l"
             "-e" "(: _ (borrow 'berth) (berth [\"sh\" \"-c\" \"sleep 5\"]))"])
 _ (test (two? md))
 m >md
 _ (rest 1200)                            ; let berth come up and moor its first child
 ; the order is the content: "v C-a" is not the prefix, so the two puts are sequenced
 _ (put m 1) _ (put m 118) _ (flush m)     ; C-a v: split beside
 outb (slurp m)                           ; ... until both children leave and berth ends
 _ (test
    (sub? outb "\e[1;40H" 0)              ; the bar's column, 39 zero-based
    (sub? outb limn-down 0)                   ; ... drawn with the box glyph
    (sub? outb "\e[2;41H" 0))             ; the new pane's second row, past the bar
 _ (: (wf p) (: g2 (gather p) (two? g2 ? g2 (rest 2, wf p))) (wf <md))
 (close m))

; --- the outer terminal's sequences, on a real berth over a real pty: the child scrolls
; TOPMARK away and shift+PgUp brings it back; the child asks for the mouse and a
; bracketed paste, berth asks the outer terminal for the mouse in turn, and a click and
; a paste sent as the outer terminal sends them reach the child as it asked -- it says
; them back through cat -v. the child's script rides BK, past three layers of quoting ---
(: (sub? h n i) ((i + #n) < (#h + 1) ? (n = snip h i (i + #n) ? 1 (sub? h n (i + 1))) 0)
 _ (setenv "BK" ("printf 'TOPMARK" + cats (map (\ _ "\\n") (jot 30)) + "'; stty raw -echo; "
                 + "printf '\\033[?1000h\\033[?1006h\\033[?2004h'; r=$(dd bs=1 count=33 2>/dev/null); "
                 + "printf '%s' \"$r\" | cat -v; sleep 1"))
 md (tether ["out/love" "-l" "apps/berth/berth.l"
             "-e" "(: _ (borrow 'berth) (berth [\"sh\" \"-c\" \"eval \\\"$BK\\\"\"]))"])
 _ (test (two? md))
 m >md
 _ (rest 1200)
 _ (say m "\e[5;2~") _ (flush m)                  ; shift+PgUp
 _ (rest 400)
 _ (say m "\e[<0;3;2M\e[<0;3;2m\e[200~p\nq\e[201~") _ (flush m)   ; a click at row 2 col 3, a paste
 outb (slurp m)
 _ (test
    (sub? outb "TOPMARK" 0)                        ; the history, in view
    (sub? outb "\e[?1000h" 0)                      ; the child's mouse wish, passed out
    (sub? outb "^[[<0;3;2M^[[<0;3;2m^[[200~p^Mq^[[201~" 0))   ; ... and the click and paste, passed in
 _ (: (wf p) (: g2 (gather p) (two? g2 ? g2 (rest 2, wf p))) (wf <md))
 (close m))

; --- the pictures themselves: the test answers berth's kitty query as a kitty terminal
; would, and a sixel the child draws goes out as kitty's own a=t and a=p ---
(: (sub? h n i) ((i + #n) < (#h + 1) ? (n = snip h i (i + #n) ? 1 (sub? h n (i + 1))) 0)
 _ (setenv "BK" "sleep 1; printf '\\033P0;1;0q#0;2;100;0;0#0!10~-#0!10~\\033\\\\'; sleep 2")
 md (tether ["out/love" "-l" "apps/berth/berth.l"
             "-e" "(: _ (borrow 'berth) (berth [\"sh\" \"-c\" \"eval \\\"$BK\\\"\"]))"])
 _ (test (two? md))
 m >md
 _ (rest 500)
 _ (say m "\e_Gi=31;OK\e\\") _ (flush m)             ; yes, kitty
 outb (slurp m)
 _ (test
    (sub? outb "\e_Gi=31,s=1,v=1,a=q" 0)                ; berth asked
    (sub? outb "\e_Ga=t,f=32,s=10,v=12," 0)             ; the picture, sent
    (sub? outb "\e_Ga=p,i=" 0)                          ; and placed
    (sub? outb "\e_Ga=d,d=A" 0))                        ; and freed on the way out
 _ (: (wf p) (: g2 (gather p) (two? g2 ? g2 (rest 2, wf p))) (wf <md))
 (close m))

; --- ..and as sixels, to a terminal whose DA says 4 and whose cell is 12x24: laid once,
; and not again when the child writes elsewhere ---
(: (sub? h n i) ((i + #n) < (#h + 1) ? (n = snip h i (i + #n) ? 1 (sub? h n (i + 1))) 0)
   (count h n i k) (? ((i + #n) < (#h + 1)) (count h n (i + 1) (n = snip h i (i + #n) ? (k + 1) k)) k)
 _ (setenv "BS" "sleep 1; printf '\\033P0;1;0q#0;2;100;0;0#0!10~-#0!10~\\033\\\\'; sleep 1; printf '\\033[5;1Hzz'; sleep 1")
 md (tether ["out/love" "-l" "apps/berth/berth.l"
             "-e" "(: _ (borrow 'berth) (berth [\"sh\" \"-c\" \"eval \\\"$BS\\\"\"]))"])
 _ (test (two? md))
 m >md
 _ (rest 500)
 _ (say m "\e[6;24;12t\e[?62;4;22c") _ (flush m)       ; no kitty: a cell 12x24, and sixels
 outb (slurp m)
 _ (test
    (sub? outb "\e[16t\e[c" 0)                         ; berth asked
    (1 = count outb "\eP0;0;0q\"1;1;" 0 0)             ; the picture, laid once
    (sub? outb "#180;2;100;0;0" 0)
    (sub? outb "zz" 0)                                  ; though the frames went on
    !(sub? outb "\e_Ga=" 0))
 _ (: (wf p) (: g2 (gather p) (two? g2 ? g2 (rest 2, wf p))) (wf <md))
 (close m))

(test_fin ())
(puts "berth: ok")
