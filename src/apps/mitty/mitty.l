; mitty -- quay's terminal multiplexer: where programs tie up.
;
; each child rides its own pty (tether); its bytes pour through a quay cb screen (the
; kernel console's vt parser, hosted by src/love/cb.c) and the grids repaint the outer
; terminal. the panes come from wharf.l (plan tree -> rectangles), the paint from limn.l
; (grid -> escapes); neither knows a pty, so the kernel console uses them too.
;
; C-a is the prefix, intercepted in the key pump below every guest: s/v split, h j k l
; steer, x shut, [ copy mode (the pane's screen as a vi buffer), ] paste, C-a a literal;
; c a fresh face, n p the next and last, 0-9 a face by number (made when missing), z the
; saver ('saver) now; a key
; the caller pins in 'keys opens the pane its thunk answers, beside (love mitty's b, a model).
; the clip is the mitty's one register, vi's shape, shared by every vi buffer on it,
; and sent out to the outer terminal's clipboard (osc 52) when it changes.
; a guest may be a stage of this process -- cli's triple (show w h) (step k) (over? _) --
; berthed like a child; a door 'key reads its keys, a door 'tick asks for a frame.
;
; run: out/love -e "(: _ (borrow 'mitty) (mitty [\"sh\"]))", or `love mitty` for lush in it.
; host-only (screen/tether/tty ride src/love/*.c): never in the corpus; test/host/mitty.l
; smokes it over a real pty. a module, so a guest that berths itself (vi's splits) cites it.
(module '(mitty mitty mitty-stage mitty-up hberth hsail hopen hopen-stage moor waitfor
          hbox hmas hpid hstage hpty? hpane hsoil hrelay hframe hmoor hsplit hsteer hshut
          hfeed hkey oars hsize htide htick hswim hquick? hcopy hpaste hclip-text hscreen-text
          hseq hmouse hpeer hpasted hfaces hgo hcycle hfresh hb64 hsub? hswap hpicker mitty-launch mitty-switch mitty-hive mitty-queues mitty-barx mitty-saver hwake hidle hidle? hsleep hquiet? hin hout hlive? hgreet hbye hattach hdetach mitty-lush mitty-here mitty-serve mitty-attach mitty-sock mitty-dir mitty-ls mitty-size hname hname-of hlr hbarat hdrag hmice hbarline hbarface hbartick hnote hhands mitty-bee mitty-main)
(borrow ((cite 'wharf) @ m (m ? m "src/apps/mitty/wharf.l")))   ; the baked module, else the tree's file
(borrow ((cite 'limn) @ m (m ? m "src/apps/mitty/limn.l")))
(borrow 'posix)
(:
 ; --- the moor: pump the master through the screen until the child hangs up.
 ; the screen lives in box bx (a relay swaps it); replies pour straight back;
 ; a dirty box (when given) cues the painter
 ; park on the first byte, then swig the rest of the gulp -- per-byte sees
 ; cap out near a megabyte a second, and a full-screen guest pours six
 ; the box is re-read every gulp on purpose: that is how a resize reaches a
 ; running moor with no signal, and why a pane's screen may be swapped freely.
 (moor bx m dirty) (see m @ ch
                    (ch = -1 ? ()
                     (: s (peep bx () 0)
                        _ (scribe s ch)
                        b (cask 8192)
                        _ (: (drain x) (swig m b @ n
                                          (charm? n && 0 < n ? (scribe (peep bx () 0) (snip b 0 n), drain ()) 0))
                           (drain ()))
                        rep (reply (peep bx () 0))
                        ; a reply is a byte stream and its order is the whole content
                        ; of it -- and one say beats six puts.
                        (rep ? (say m (foldl (a \ b \ a + string b) "" rep), flush m) 0,
                         dirty ? (pin dirty () 1) 0,
                         moor bx m dirty))))

 (waitfor pid) (gather pid @ s (? (two? s) s (nom? s) s (do (rest 2) (waitfor pid))))

 ; --- the mitty: every pane's screen, pty and child, under one wharf plan ---
 ; a pane is (box master pid stage): a child's has its master and pid and no stage,
 ; a stage's the stage and neither. the mitty is a tablet, and the keys are the
 ; whole state: plan focus next rows cols panes lay dirt more jobs clip keys bar bart barx, and the faces --
 ; face the one shown, faces the others' [plan focus] by number, the shown one's never kept there.
 ; the mitty's own tty: 'in and 'out, the process's unless a client's (rung 5's server);
 ; () when no client is attached, and then nothing is painted and the dirt waits
 (hin hb) (peep hb 'in in)
 (hout hb) (peep hb 'out out)
 (hlive? hb) (hot? (hout hb))
 (hbox p) <p
 (hmas p) <>p
 (hpid p) <>>p
 (hstage p) (p 3)
 ; what runs there, for the bar: a program's name (love's verb when it is love), a stage's own
 (hname p) (? (4 < #p) (p 4) "")
 (hname-of argv) (: b (: w <argv k (: (go i) (? (i < 0) 0 (w i = 47) (i + 1) (go (i - 1))) (go (#w - 1)))
                         (snip w k #w))
                     (b = "love" && two? >argv ? <>argv b))
 (hpty? p) (() != hmas p)
 ; the clip's text: a linewise register ends each line, a charwise one is as it is
 (hclip-text hb) (peep (hb 'clip) () () @ v
                    (? (atom? v) ""
                       (<v = 'lin) (foldl (a \ l \ a + l + "\n") "" <>v)
                       <>v))
 ; base64, for the clip's trip out through osc 52
 (hb64 s) (: t "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/" n #s j (jug 0)
             (ch v) (string (t (v & 63)))
             (at i) (i < n ? (s i) 0)
             (go i) (? (n <= i) 0
                       (: a (at i) b (at (i + 1)) c (at (i + 2))
                          (say j (ch (a >> 2) + ch (a << 4 | b >> 4)
                                  + (i + 1 < n ? (ch (b << 2 | c >> 6)) "=")
                                  + (i + 2 < n ? (ch c) "=")),
                           go (i + 3))))
             (go 0, slurp j))
 ; a pane's history and screen as rows of text, each with its trailing blanks off; the
 ; glyphs come out as limn paints them
 (hscreen-text p) (: s (peep (hbox p) () 0) r (gaze s 1) c (gaze s 2) hn (gaze s 9)
                     (cp i) (glass s i 0 & 2097151)
                     (tail? i) (glass s i 0 >> 21 & 3 = 2)        ; a wide char's right half: its lead says both
                     (glyph i) (tail? i ? "" (limn-glyph (cp i)))
                     (row i) (: (go q acc) (q < 0 ? acc (go (q - 1) (glyph (i * c + q) + acc)))
                                (last q) (? (q < 0) -1 (32 = cp (i * c + q) || 0 = cp (i * c + q)) (last (q - 1)) q)
                                (go (last (c - 1)) ""))
                     (map (i \ row (i - hn)) (jot (hn + r))))
 (hpane hb id) (peep (hb 'panes) id ())
 (hfind bs id) (two? bs ? (wharf-id <bs = id ? <bs (hfind >bs id)) ())
 (hsoil hb) (hb 'dirt @ b (pin b () 1))

 ; open a child on its own pty at r x c. tether's errno rides back out on a
 ; refusal -- a nom, never two?, which is how the caller tells it from a pane.
 (hopen argv r c) (: _ (setenv "TERM" "xterm-256color")   ; the dialect we actually speak
                     md (tether argv)
                     (atom? md ? md
                      (: m >md
                         s (screen (cask (screen () r c)) r c)
                         bx {s}
                         (settty m r c,
                          [bx m <md () (hname-of argv)]))))

 ; --- the stage door: a stage berths on a screen of its own, its frame scribed there
 ; at the pane's size, which the frame is asked for as w h
 (mitty-stage show step over?) {'show show 'step step 'over? over?}
 (hshow p) (peep (hbox p) () 0 @ s
              (scribe s (hstage p 'show (gaze s 2) (gaze s 1))))
 ; a note on its own stage, gone at any key
 (hnote t) (: k {0}
              (mitty-stage (\ w h ("\e[H\e[2J" + t + "\r\n\r\n(a key closes this)"))
                           (\ c (pin k () 1)) (\ _ (peep k () 0))))
 (hopen-stage sg r c) (: s (screen (cask (screen () r c)) r c)
                         p [{s} () () sg (peep sg 'name "stage")]
                         (hshow p,
                          p))

 ; --- the relay: the plan says where every pane is, so every screen is laid
 ; across to its rectangle and every pty told its new size. what the old grid
 ; held comes along; the rest is the guest's to repaint on its own sigwinch.
 ; a pane with no room still needs a valid screen (the nifs refuse a zero
 ; axis), so its grid is 1x1 and wharf-show? is what keeps it off the glass.
 ; the rows the panes share: all of them, less the bar's when it is up
 (hlr hb) (hb 'rows - peep hb 'bar 0)
 (hrelay hb) (wharf-lay (hb 'plan) (hlr hb) (hb 'cols) @ bs
                (map (b \ (hpane hb (wharf-id b) @ p
                             (atom? p ? 0
                              (: nr (max 1 (wharf-rows b)) nc (max 1 (wharf-cols b))
                                 bx (hbox p)
                                 s (peep bx () 0)
                                 (nr = gaze s 1 && nc = gaze s 2 ? 0
                                  (regrid s (cask (screen () nr nc)) nr nc @ s2
                                     (pin bx () s2,
                                      hpty? p ? (settty (hmas p) nr nc) (hshow p))))))))
                     bs,
                 pin hb 'lay bs,
                 hsoil hb))

 ; --- the frame -------------------------------------------------------------
 ; the painting is src/apps/mitty/limn.l's: cells at an origin, and the bars off wharf-bars.
 ; what stays here is which grid goes where, which is the only half mitty owns
 (hbars j hb) (limn-bars j (wharf-bars (hb 'plan) (hlr hb) (hb 'cols)))

 ; --- the bar: the bottom row, when 'bar is 1 -- the faces (the shown one lit), what has
 ; the keyboard, and on the right 'bart: the caller's 'barx text and the wall clock ---
 (hdlabel d) (" " + show d + " ")
 (hbarline hb)
  (: w (hb 'cols) ds (sort (hb 'face . hfaces hb))
     dl (foldl (a \ d \ a + (d = hb 'face ? ("\e[1;7m" + hdlabel d + "\e[22;27m") (hdlabel d))) "" ds)
     dw (foldl (a \ d \ a + #(hdlabel d)) 0 ds)
     p (hpane hb (hb 'focus)) nm (two? p ? (hname p) "")
     rt (peep hb 'bart "") rw (edwide rt)
     room (w - dw - 2)
     nm2 (edcut nm (max 0 (room - (rw < room - 1 ? (rw + 1) 0))))
     gap (max 0 (room - edwide nm2 - (rw < room - 1 ? rw 0)))
     ("\e[0;48;5;236;38;5;250m" + dl + "  " + nm2 + edpad "" gap " " + (rw < room - 1 ? rt "") + "\e[0m"))
 ; the face under column c of the bar, or ()
 (hbarface hb c) (: (go ds x) (? (atom? ds) () (: x2 (x + #(hdlabel <ds)) (c < x2 ? <ds (go >ds x2))))
                    (go (sort (hb 'face . hfaces hb)) 0))
 ; the clock, HH:MM in the local zone; "" where kore cannot say
 (hclock hb) (: z (peep hb 'tz () @ z0 (two? z0 ? <z0 (: z1 (cite 'kore 'tz-zone) zz (? z1 (z1 0) ()) (pin hb 'tz [zz], zz))))
                f (cite 'kore 'udatez) ms (clock 0)
                (? (z && f) (f "%H:%M" ms (z (ms // 1000))) ""))
 ; the right side again; a change is a frame
 (hbartick hb) (? !(peep hb 'bar 0) 0
                  (: x (peep hb 'barx () @ f (f ? (f ()) "")) t (x + (0 < #x ? "  " "") + hclock hb + " ")
                     (t = peep hb 'bart "" ? 0 (pin hb 'bart t, hsoil hb))))

 ; the outer terminal's mouse follows the focused pane's wish (quay.h's flag bits); the
 ; reports always come as ?1006's, and `mouse` lays them into what the pane asked for
 ; with 'mouse on the mitty wants presses and drags itself, for its bars and its bar
 (hmice hb f) (? (f & 4096) "\e[?1003h" (f & 2048 || peep hb 'mouse 0) "\e[?1002h" (f & 1536) "\e[?1000h"
                 "\e[?1003l\e[?1002l\e[?1000l")

 ; nothing is erased between frames, and nothing needs to be: panes and bars
 ; tile the wharf exactly (src/apps/mitty/wharf.l's standing law), so every cell is written
 ; every frame and no stale glyph can survive a layout change.
 ; a picture kitty holds (pics 1) whose pane's screen keeps it no longer -- the pane gone, or
 ; the store swept it -- is freed there, data and all, and forgotten, so it goes again if seen
 (hfree j hb)
  (: live {} seen {}
     (look ib) (peep seen ib 0 ? 0
                  (: _ (pin seen ib 1) p (hpane hb ib) s (two? p ? (peep (hbox p) () 0) 0)
                     (map (sl \ (picture s sl 2 @ g (charm? g ? (pin live (ib * 1048576 + (g & 1048575)) 1) 0)))
                          (jot 128))))
     (keep t id) (look (id // 1048576),
                  peep live id 0 ? (pin t id 1) (say j ("\e_Ga=d,d=I,i=" + show id + ",q=2\e\\"), t))
     (pin hb 'sent (foldl keep {} (sort (keys (hb 'sent))))))
 ; with kitty's pictures on (pics 1), every placement goes first and the ones still in view
 ; come back. sixels (pics 2) sit in the text layer: a pane's go out again only when what it
 ; shows of them moves, the cells the old ones covered erased before anything is painted,
 ; and never on the outer terminal's last row, which a sixel reaching would scroll
 (hframe hb)
  (: j (jug 0) pk (peep hb 'pics 0)
     shown (filter (b \ wharf-show? b && two? (hpane hb (wharf-id b))) (hb 'lay))
     old (peep hb 'six {}) now {}
     ; a shown pane's sixel entry: [sig ps rr laid], sig what they hang on, rr the rows
     ; they may take, laid the sixels sent, by what they show
     (placed b) (: s (peep (hbox (hpane hb (wharf-id b))) () 0)
                   rr (max 0 (min (wharf-rows b) (hb 'rows - 1 - wharf-row b)))
                   ps (limn-placed s rr (wharf-cols b))
                   [[(wharf-row b) (wharf-col b) (hb 'rows) (hb 'cols) ps] ps rr {}])
     (pk = 2 ? (map (b \ pin now (wharf-id b) (placed b)) shown) 0,
      say j (pk = 1 ? "\e[?25l\e_Ga=d,d=a,q=2\e\\" "\e[?25l"),
      map (id \ (: o (old id) n (peep now id ()) sg <o
                   (two? n && <n = sg ? 0 (limn-unsix j (o 1) (sg 0) (sg 1)))))
          (keys old),
      map (b \ (: id (wharf-id b) s (peep (hbox (hpane hb id)) () 0) r (wharf-rows b) c (wharf-cols b)
                  row0 (wharf-row b) col0 (wharf-col b)
                  (pk = 2 ?
                     (: n (now id) o (peep old id ()) rr (n 2) op (hb 'opx)
                        (limn-rows j s rr c row0 col0 0 -1 2,
                         limn-rows j s r c row0 col0 rr -1 0,
                         two? o && <o = <n ? (pin now id [<n (n 1) rr (o 3)])
                           ({} @ laid
                              (limn-sixes j s (n 1) row0 col0 (two? op ? <op (gaze s 6)) (two? op ? <>op (gaze s 7))
                                          (two? o ? (o 3) {}) laid,
                               pin now id [<n (n 1) rr laid]))))
                     (limn-rows j s r c row0 col0 0 -1 pk,
                      pk = 1 ? (limn-pics j s r c row0 col0 id (hb 'sent)) 0))))
          shown,
      pk = 2 ? (pin hb 'six now) 0,
      pk = 1 ? (hfree j hb) 0,
      hbars j hb,
      peep hb 'bar 0 ? (say j (limn-go (hb 'rows - 1) 0 + hbarline hb)) 0,
      (hclip-text hb @ ct
         (ct = hb 'c52 ? 0 (pin hb 'c52 ct, 0 < #ct ? (say j ("\e]52;c;" + hb64 ct + "\a")) 0))),
      (: p (hpane hb (hb 'focus)) b (hfind (hb 'lay) (hb 'focus))
         (two? p && two? b ?
            (: s (peep (hbox p) () 0) w (gaze s 0) c (gaze s 2) f (gaze s 3)
               cr (w // c + gaze s 8)                      ; the cursor's row, under the view
               _ (say j (limn-go (wharf-row b + min cr (wharf-rows b - 1)) (wharf-col b + w % c)))
               _ (1 & f && cr < wharf-rows b ? (say j "\e[?25h") 0)     ; the guest's cursor wish
               m (hmice hb f)
               (m = peep hb 'mice "" ? 0 (pin hb 'mice m, say j m)))
            0)),
      slurp j))

 ; --- the panes: opening, steering, shutting -------------------------------
 ; a pane's pump, twirled: moor runs until the child hangs up and the pane is
 ; shut for it. the handle is kept in 'jobs so the teardown can reap it.
 (hmoor hb id) (: p (hpane hb id)
                  t (twirl (_ \ (moor (hbox p) (hmas p) (hb 'dirt), hshut hb id)) 0)
                  (pin hb 'jobs (t . hb 'jobs)))

 ; tie a pane up: the first takes the whole wharf, another splits the focused pane
 ; and takes its focus, pct the share the focused one keeps. a pane opens at 1x1 and
 ; the relay right after is what gives it its real size; a child's pump is twirled here
 (hberth hb d pct p) (hb 'next @ id
                    (pin (hb 'panes) id p,
                     pin hb 'next (id + 1),
                     pin hb 'plan (() = hb 'plan ? id (wharf-split (hb 'plan) (hb 'focus) d pct id)),
                     pin hb 'focus id,
                     hrelay hb,
                     hpty? p ? (hmoor hb id) 0))
 ; the prefix's split: a fresh pane off the mitty's 'more, a thunk answering one
 (hsplit hb d) (hb 'more () @ p (two? p ? (hberth hb d 50 p) 0))

 (hsteer hb d) (wharf-steer (hb 'lay) (hb 'focus) d @ id
                  (id = hb 'focus ? 0 (pin hb 'focus id, hsoil hb)))

 ; shut a pane: its pty closes, the plan promotes its sibling over the bar they
 ; shared, and the focus moves on if it was the one that left. shutting twice
 ; is safe -- the second finds no pane and closes nothing, which is what a child
 ; hanging up on a pane the user already shut looks like.
 ; a pane on a face not shown leaves that face's plan, and an emptied face is gone; the
 ; shown face emptied hands the glass to the first face left
 (hshut hb id) (: p (hpane hb id)
                  _ (two? p && hpty? p ? (close (hmas p)) 0)
                  _ (two? p && !(hpty? p) && hstage p 'shut ? (hstage p 'shut ()) 0)   ; a stage's own leavings
                  _ (pin (hb 'panes) id ())
                  (elem id (wharf-panes (hb 'plan)) ?
                     (: pl (wharf-shut (hb 'plan) id)
                        (pin hb 'plan pl,
                         ? (id = hb 'focus) (wharf-panes pl @ bs (pin hb 'focus (two? bs ? <bs ()))) 0,
                         (() = pl && two? (hfaces hb) ? (hgo hb <(hfaces hb)) (hrelay hb))))
                     (hstow hb id)))
 (hstow hb id) (map (d \ (hb 'faces d @ v
                            (two? v && elem id (wharf-panes <v) ?
                               (: pl (wharf-shut <v id)
                                  f (<>v = id ? (wharf-panes pl @ bs (two? bs ? <bs ())) <>v)
                                  (pin (hb 'faces) d (() = pl ? () [pl f])))
                               0)))
                    (keys (hb 'faces)))

 ; --- the faces: each its own plan and focus over the one table of panes. a face not
 ; shown keeps its children running and its screens at the size they last had ---
 (hfaces hb) (sort (filter (d \ two? (hb 'faces d)) (keys (hb 'faces))))
 ; show face n: the shown one is put away, n taken out; a face not yet made opens a
 ; pane off 'more, and stays unmade when that fails
 (hgo hb n) (? (n = hb 'face) 0
               (: v (hb 'faces n)
                  p (two? v ? () (hb 'more ()))
                  (? (atom? v && atom? p) 0
                     (pin (hb 'faces) (hb 'face) (() = hb 'plan ? () [(hb 'plan) (hb 'focus)]),
                      pin (hb 'faces) n (),
                      pin hb 'face n,
                      (two? v ? (pin hb 'plan <v, pin hb 'focus <>v, hrelay hb)
                         (pin hb 'plan (), pin hb 'focus (), hberth hb 'stack 50 p))))))
 ; k faces along from the shown one, round the made ones in order
 (hcycle hb k) (: ds (sort (hb 'face . hfaces hb)) n #ds
                  (pos i) (ds i = hb 'face ? i (pos (i + 1)))
                  (hgo hb (ds ((pos 0 + k + n) % n))))
 (hfresh hb) (: (free i) (i = hb 'face || two? (hb 'faces i) ? (free (i + 1)) i)
                (hgo hb (free 0)))

 ; --- copy mode: the focused pane's screen as a vi buffer above it, on the clip;
 ; answers the buffer's state, or () on a seat with no vi. paste: the clip typed at
 ; a child, or handed to a stage's paste door ---
 (hcopy hb) (: p (hpane hb (hb 'focus)) vi (cite 'vi)
               (? (atom? p || !(tablet? vi)) ()
                  (: st (vi 'vi-open "")
                     rows (hscreen-text p)
                     _ (pin st 'lines (two? rows ? rows [""]))
                     fc (vi 'vi-face st {'reg (hb 'clip)})
                     sg (mitty-stage (fc 0) (fc 1) (fc 2))
                     (pin sg 'paste (fc 3),
                      hberth hb 'stack 50 (hopen-stage sg 1 1),
                      st))))
 (hpaste hb) (: p (hpane hb (hb 'focus)) v (peep (hb 'clip) () ())
                (? (atom? p || atom? v) 0
                   (hpty? p) (hpasted hb (hclip-text hb))
                   (hstage p @ sg
                      (sg 'paste ? (sg 'paste v, hshow p, hsoil hb) 0))))

 ; --- the history: the focused pane's view moves n lines back; a key brings it home ---
 (hpeer hb n) (hpane hb (hb 'focus) @ p
                 (atom? p ? 0
                    (peep (hbox p) () 0 @ s (peer s (max 0 (gaze s 8 + n)), hsoil hb))))
 (hhome hb p) (peep (hbox p) () 0 @ s (0 < gaze s 8 ? (peer s 0, hsoil hb) 0))
 (hhalf hb) (hfind (hb 'lay) (hb 'focus) @ b (two? b ? (max 1 (wharf-rows b // 2)) 1))

 ; a paste into the focused child, as `pasted` lays it for that pane's screen
 (hpasted hb t) (hpane hb (hb 'focus) @ p
                   (? (atom? p || !(hpty? p)) 0
                      (hhome hb p, (say (hmas p) (pasted (peep (hbox p) () 0) t), flush (hmas p)))))

 ; --- the mouse: an outer ?1006 report at x y (1-based). a press on another pane moves
 ; the focus; else the focused pane gets it at its own origin, clamped inside, as its
 ; screen asked -- and a wheel it did not ask for scrolls its history ---
 (hat bs r c) (two? bs ?
                 (<bs @ b
                    (wharf-row b <= r && r < wharf-row b + wharf-rows b
                     && wharf-col b <= c && c < wharf-col b + wharf-cols b ? b (hat >bs r c))))
 ; a bar under the cell: ['across row col len] or ['down row col len], () for none
 (hbarat hb r c) (: bs (filter (v \ (<v = 'across ? (<>v = r && <>>v <= c && c < <>>v + <>>>v)
                                       (<>>v = c && <>v <= r && r < <>v + <>>>v)))
                               (wharf-bars (hb 'plan) (hlr hb) (hb 'cols)))
                    (two? bs ? <bs ()))
 ; a drag moves the bar it took hold of, and the release lets go
 (hdrag hb r c how) (: g (hb 'drag) dir (g 2) to (dir = 'across ? r c)
                       (? (how = 1) (pin hb 'drag ())
                          (how = 2) (pin hb 'plan (wharf-drag (hb 'plan) (hlr hb) (hb 'cols) <g <>g to),
                                     pin hb 'drag (dir = 'across ? [to <>g dir] [<g to dir]),
                                     hrelay hb)
                          0))
 (hmouse hb b x y up)
  (: r (y - 1) c (x - 1)
     how (? up 1 (b & 32) 2 0)
     bb (b - (b & 32)) btn (bb - (bb & 28))
     at (hat (hb 'lay) r c)
     (? (two? (peep hb 'drag ())) (hdrag hb r c how)
        (how = 0 && btn = 0 && atom? at && r < hlr hb) (hbarat hb r c @ v (two? v ? (pin hb 'drag [r c <v]) 0))
        (peep hb 'bar 0 && r = hb 'rows - 1) (how = 0 && btn = 0 ? (hbarface hb c @ d (charm? d ? (hgo hb d, hsoil hb) 0)) 0)
        ((how = 0) && (btn < 64) && (two? at) && !(wharf-id at = hb 'focus))
        (pin hb 'focus (wharf-id at), hsoil hb)
        (: p (hpane hb (hb 'focus)) bf (hfind (hb 'lay) (hb 'focus))
           (? (atom? p || atom? bf || !(hpty? p)) 0
              (: s (peep (hbox p) () 0)
                 t (mouse s bb (max 0 (min (wharf-rows bf - 1) (r - wharf-row bf)))
                               (max 0 (min (wharf-cols bf - 1) (c - wharf-col bf))) how)
                 (? (0 < #t) (say (hmas p) t, flush (hmas p))
                    (how = 0 && 64 <= btn <= 65) (hpeer hb (btn = 64 ? 3 -3))
                    0))))))

 ; --- a sequence from the outer terminal, its ESC read: CSI's parameters to the final
 ; byte, then a mouse report, shift+PgUp/PgDn, or a bracketed paste (read to its end);
 ; anything else goes on to the pane whole ---
 (hnums t) (: (go i n acc) (? (i = #t) (rev (n . acc))
                              (t i = 59) (go (i + 1) 0 (n . acc))
                              (go (i + 1) (n * 10 + (t i - 48)) acc))
              (go 1 0 ()))                               ; past the <
 (hbracket hb) (: (go acc) (see (hin hb) @ b
                             (b < 0 ? acc
                                ((b . acc) @ a2
                                   (b = 126 && [126 49 48 50 91 27] = take 6 a2 ? (drop 6 a2) (go a2)))))
                 (string (rev (go ()))))
 (hsend hb t) (each ^#t (i \ hfeed hb (t i)), 0)
 ; an APC's body, to its ST: the one mitty reads is the answer to its kitty query, which
 ; turns the pictures on
 (hapc hb) (: (go acc) (see (hin hb) @ b
                          (? (b < 0) acc
                             (b = 27) (see (hin hb) @ b2 (b2 = 92 ? acc (go (acc + string b + string b2))))
                             (go (acc + string b))))
              t (go "")
              ; a client's size: mitty;size;R;C
              (t @ "Gi=31;OK" (pin hb 'pics 1, hsoil hb)
                 ("mitty;size;" + (r && 1 < #r))
                  (: ws (filter (w \ 0 < #w) (cite 'kore 'usplit 59 r))
                     (? (#ws = 2) (pin hb 'csize [(mitty-num <ws) (mitty-num (ws 1))], htide hb) 0))
                 0))
 (hseq hb) (see (hin hb) @ b1
              (? (b1 = 95) (hapc hb)
                 !(b1 = 91) (hfeed hb 27, -1 < b1 ? (hfeed hb b1) 0)
                 (: (csi acc) (see (hin hb) @ b (b < 0 || 63 < b && b < 127 ? [acc b] (csi (acc + string b))))
                    q (csi "") a <q f <>q
                    (? (f < 0) (hsend hb ("\e[" + a))
                       ((f = 77 || f = 109) && 0 < #a && a 0 = 60)
                        (hnums a @ ns (#ns = 3 ? (hmouse hb <ns <>ns <>>ns (f = 109)) 0))
                       (f = 126 && a = "5;2") (hpeer hb (hhalf hb))
                       (f = 126 && a = "6;2") (hpeer hb (0 - hhalf hb))
                       (f = 126 && a = "200") (hpasted hb (hbracket hb))
                       ; the DA answer the query drew out: a 4 is sixels, where kitty said nothing
                       (f = 99 && 0 < #a && a 0 = 63)
                        (peep hb 'pics 0 = 0 && elem 4 (hnums a) ? (pin hb 'pics 2, hsoil hb) 0)
                       ; its cell's size in pixels, which a sixel is drawn in
                       (f = 116 && 0 < #a && a 0 = 54)
                        (hnums ("?" + a) @ ns (#ns = 3 ? (pin hb 'opx [(ns 2) (ns 1)], hsoil hb) 0))
                       (hsend hb ("\e[" + a + string f))))))

 ; --- keys: raw stdin pours onto the focused pane, C-a first. a stage takes the
 ; key as a step and is painted again, or shut when the step was its last ---
 (hfeed hb ch) (hpane hb (hb 'focus) @ p
                  (? (atom? p) 0
                     (hpty? p) (hhome hb p, (put (hmas p) ch, flush (hmas p)))
                     (hstage p @ sg
                        (sg 'step ch,
                         sg 'over? () ? (hshut hb (hb 'focus))
                           (hshow p, hsoil hb)))))
 (hkey hb) (see (hin hb) @ k
              (k < 0 ? ()
                 (k @ 1   (hfeed hb 1)                  ; C-a C-a: a literal one
                      115 (hsplit hb 'stack)            ; s
                      118 (hsplit hb 'beside)           ; v
                      104 (hsteer hb 'left)             ; h
                      106 (hsteer hb 'down)             ; j
                      107 (hsteer hb 'up)               ; k
                      108 (hsteer hb 'right)            ; l
                      120 (hshut hb (hb 'focus))        ; x
                      91  (hcopy hb)                    ; [
                      93  (hpaste hb)                   ; ]
                      99  (hfresh hb)                   ; c
                      122 (hsleep hb)                   ; z
                      100 (peep hb 'serve 0 ? (hdetach hb) 0)   ; d, from a server
                      110 (hcycle hb 1)                 ; n
                      112 (hcycle hb -1)                ; p
                      (d && 47 < d < 58) (hgo hb (d - 48))   ; 0-9
                      (peep (hb 'keys) k () @ f (f ? (f () @ p (two? p ? (hberth hb 'beside 50 p) 0)) 0)))))
 ; a child gets the bytes as typed, a sequence read whole when its ESC has company
 ; (a lone ESC is a key); a stage gets edkey's keys, as on cli's stage, or its own
 ; reader's; and the user's eof leaves it
 ; g is the attach this pump serves: a later one (or a detach) ends it, so a client's eof
 ; never touches the client after it
 (oars hb g) (? (peep hb 'serve 0 && g != peep hb 'gen 0) 0
              (: p (hpane hb (hb 'focus))
                 ch (? (two? p && !(hpty? p)) (peep (hstage p) 'key edkey (hin hb)) (see (hin hb)))
                 (? (ch = -1 && peep hb 'serve 0) (g = peep hb 'gen 0 ? (hdetach hb) 0)   ; a client's eof is its leaving
                    (ch = -1) (hfeed hb 4)                 ; veof follows the user's own eof
                    (ch = -7) (hshut hb (hb 'focus))
                    (hwake hb) (: (dk _) (cue? (hin hb) ? (see (hin hb), dk 0) 0) (dk 0, oars hb g))   ; the key that ends a saver is the saver's
                    ((? (ch = 1) (hkey hb)
                        (ch = 27 && hpty? p && cue? (hin hb)) (hseq hb)
                        (hfeed hb ch)),
                     oars hb g))))

 ; --- idle: 'saver is a watch of src/apps/mitty/saver.l's, which has the glass after its minutes
 ; without a key; the mitty's own frames wait under it, and are laid again whole after ---
 ; a key: 1 when it woke a saver, which then is owed a whole frame
 (hwake hb) (: w (peep hb 'saver ()) k (cite 'saver 'saver-key) _ (pin hb 'forced 0)
               (? (tablet? w && k && k w (clock 0)) (: _ (hsoil hb) 1) 0))
 ; quiet: every pane on the shown face a bare shell, one at its prompt with no job in
 ; front -- its terminal's group its own -- and no face at all quiet too. only then does
 ; the saver's clock run; anything else on the glass holds it off, as a key would
 hshells ["lush" "sh" "bash" "zsh" "dash" "ksh" "mksh" "fish" "tcsh"]
 (hbare? p) (&& (two? p) (hpty? p) (elem (hname p) hshells)
                (: g (ttypg (hmas p)) (charm? g && g = hpid p)))
 (hquiet? hb) (all (id \ hbare? (hpane hb id)) (wharf-panes (hb 'plan)))
 ; the saver's escapes for now, "" when it has none; and whether it has the glass. C-a z
 ; ('forced) brings it whatever the panes hold
 (hidle hb) (: w (peep hb 'saver ()) t (cite 'saver 'saver-tick)
               (? !(tablet? w && t) ""
                  (: _ (? ((cite 'saver 'saver-on?) w || peep hb 'forced 0 || hquiet? hb) 0 (pin w 'last (clock 0)))
                     (t w (clock 0) (hb 'rows) (hb 'cols) 0))))
 (hidle? hb) (: w (peep hb 'saver ()) (tablet? w && (cite 'saver 'saver-on?) w))
 ; at once, the clock wound past its minutes: C-a z
 (hsleep hb) (: w (peep hb 'saver ()) (? (tablet? w && 0 < w 'idle) (: _ (pin hb 'forced 1) (pin w 'last (clock 0 - w 'idle))) 0))

 ; --- the tide: mirror the outer terminal's size onto the whole wharf -------
 ; the floor is not decoration, and it lives here so both callers share it: a
 ; fresh pty answers (0 . 0) -- two? and true and useless -- and a wharf of no
 ; cells lays every pane at zero extent, which paints a blank screen and never
 ; recovers. the opening had this floor; the tide did not, and quietly undid it
 ; half a second in.
 (hsize u) (tty 1 @ ws
              [(two? ws && 5 < <ws ? <ws 24)
               (two? ws && 19 < >ws ? >ws 80)])
 (htide hb) (: sz (peep hb 'serve 0 ? (peep hb 'csize [24 80]) (hsize 0)) r <sz c <>sz
               (r = hb 'rows && c = hb 'cols ? ()
                (pin hb 'rows r, pin hb 'cols c, hrelay hb)))

 ; --- the ticks: every stage with a tick door is asked, and painted on a yes; one
 ; that is over on its own, with no key, is shut ---
 (htick hb) (map (id \ (: p (hpane hb id) sg (two? p ? (hstage p) ())
                          (? !(tablet? sg) 0
                             (sg 'over? ()) (hshut hb id)
                             (sg 'tick && sg 'tick ()) (hshow p, hsoil hb)
                             0)))
                 (wharf-panes (hb 'plan)))

 ; a stage with a tick door is on a clock of its own -- a card to feed -- so the swim
 ; turns faster while one is berthed
 (hquick? hb) (any (id \ (: p (hpane hb id) sg (two? p ? (hstage p))
                             (tablet? sg && sg 'tick)))
                  (wharf-panes (hb 'plan)))
 ; --- the swim: repaint on dirt at ~30fps, feel the tide every half second,
 ; and end when the last pane empties ---
 (hswim hb tick) (: b (hb 'dirt) t0 (clock ())
                    (htick hb,
                     ? (hlive? hb) (hidle hb @ f (0 < #f ? (say (hout hb) f, flush (hout hb)) 0)) 0,
                     ? !(hlive? hb) 0 (hidle? hb) 0
                       (peep b () 0) (pin b () 0, say (hout hb) (hframe hb), flush (hout hb), 0) 0,   ; say is the bulk lane
                     ? (0 = tick % 16) (htide hb) 0,
                     ? (0 = tick % 32) (hbartick hb) 0,
                     rest (max 1 ((hquick? hb ? 8 33) - (clock () - t0))),   ; the turn's own time counts toward it
                     two? (wharf-panes (hb 'plan)) ? (hswim hb (tick + 1)) ()))

 ; --- the mitty, empty, at r x c: born dirty, so frame one is painted; 'more is
 ; the caller's, a thunk answering the pane a prefix split ties up ---
 (mitty-up r c) ({} @ hb
                  (pins hb 'plan () 'focus () 'next 1 'rows r 'cols c 'panes {}
                        'more () 'dirt {1} 'jobs () 'lay () 'clip {} 'sent {} 'pics 0 'six {} 'opx ()
                        'face 0 'faces {} 'c52 "" 'keys {} 'bar 0 'mouse 0 'drag (),
                   hb))

 ; --- sail: the mitty on the tty, raw and on the alternate screen, keys pumped
 ; and frames painted until the last pane empties; the tty as it was after ---
 ; the outer terminal taken: the alternate screen, the mouse's reports as ?1006's, pastes
 ; bracketed. does it take kitty's pictures? a 1x1 query, then its cell's size, and DA behind
 ; them so a terminal that ignores APC still answers something (and says whether it draws
 ; sixels). asked only where a child has the keys: a stage's reader would take the answers
 (hgreet hb) (: o (hout hb)
                (say o "\e[?1049h\e[2J\e[?1006h\e[?2004h",
                 hpty? (hpane hb (hb 'focus)) ? (say o "\e_Gi=31,s=1,v=1,a=q,t=d,f=24;AAAA\e\\\e[16t\e[c") 0,
                 flush o))
 ; ... and given back as it was
 (hbye hb) (: o (hout hb)
              (say o (peep hb 'pics 0 = 1 ? "\e_Ga=d,d=A,q=2\e\\" ""),   ; every picture sent, freed
               say o "\e[0m\e[?25h\e[?1003l\e[?1002l\e[?1000l\e[?1006l\e[?2004l\e[?1049l",
               flush o))
 (hsail hb) (: _ (raw 1)
               _ (hgreet hb)
               up (twirl (_ \ oars hb 0) 0)
               (hswim hb 1,                 ; ... until the last pane empties
                map (t \ landed? t ? (catch t) (freeze t)) (hb 'jobs),
                landed? up ? (catch up) (freeze up),
                hbye hb,
                raw 0,
                0))

 ; --- the server (rung 5): the mitty with no tty of its own, a client's socket as its
 ; 'in and 'out. one client at a time: an attach takes the glass from the last, and a
 ; client's leaving -- its eof, or C-a d -- leaves the panes running and the dirt waiting ---
 (hattach hb c) (: _ (hdetach hb)
                   g (peep hb 'gen 0 + 1)
                   _ (pins hb 'gen g 'in c 'out c 'mice "" 'pics 0 'sent {} 'six {})
                   _ (hgreet hb)
                   _ (hsoil hb)
                   (twirl (_ \ oars hb g) 0))
 (hdetach hb) (? !(hlive? hb) 0
                 (: c (hout hb)
                    (hbye hb, close c, pins hb 'in () 'out () 'gen (peep hb 'gen 0 + 1), 0)))

 ; --- mitty: tie argv, or a stage, up. answers the first child's status pair (the
 ; one the caller named), or tether's errno if it never started; 0 after a stage ---
 (mitty src) (: sz (hsize 0) r <sz c <>sz
                 stg (tablet? src)
                 p0 (stg ? (hopen-stage src r c) (hopen src r c))
                 (atom? p0 ? p0
                  (mitty-up r c @ hb
                     (pin hb 'more (stg ? (_ \ hopen ["sh"] 1 1) (_ \ hopen src 1 1)),
                      hberth hb 'stack 50 p0,
                      hsail hb,
                      stg ? 0 (waitfor (hpid p0))))))

 ; --- love mitty: the shell on any terminal -- lush in every pane a
 ; split or a face opens, and argv, when given, in the first ---
 ; --- the picker: a stage that lists items, filters them as it is typed at, and on enter
 ; becomes what its item opens, in place -- or, when the item answers no pane, simply goes.
 ; an item is [label thunk]. ↑↓ (or ^p ^n) choose, backspace unsays, esc goes ---
 (hsub? h n) (: (go i) (? (#h < i + #n) 0 (n = snip h i (i + #n)) 1 (go (i + 1))) (go 0))
 ; a stage pane stands in for pane id: the old one's own leavings first. a pty's moor would
 ; shut the id when its child hangs up, so only a stage's place is taken this way
 (hswap hb id p) (: o (hpane hb id)
                    (? (atom? o || hpty? o) 0
                       (: _ (hstage o 'shut ? (hstage o 'shut ()) 0)
                          (pin (hb 'panes) id p, hrelay hb, hpty? p ? (hmoor hb id) 0, hsoil hb))))
 (hpicker hb title items)
  (: st {'q "" 'sel 0} own {-1}
     (shown _) (filter (it \ 0 = #(st 'q) || hsub? <it (st 'q)) items)
     (go _) (hshut hb (peep own () -1))
     (pick it) ((it 1) () @ p (two? p ? (hswap hb (peep own () -1) p) (go 0)))
     (frame w h) (: xs (shown 0) n #xs sel (min (st 'sel) (max 0 (n - 1))) top (max 0 (sel - (h - 3)))
                    ("\e[H\e[2J\e[1m" + title + "\e[22m " + st 'q + "\r\n"
                     + foldl (a \ i \ a + (i = sel ? "\e[7m" "") + " " + edfit (<(xs i)) (max 1 (w - 2)) " " + " \e[27m\r\n")
                             "" (filter (i \ top <= i && i < top + h - 2) (jot n))))
     (step k) (? (k = 27) (go 0)
                 (k = 10 || k = 13) (: xs (shown 0) (? (two? xs) (pick (xs (min (st 'sel) (#xs - 1)))) (go 0)))
                 (k = -8 || k = 16) (pin st 'sel (max 0 (st 'sel - 1)))
                 (k = -9 || k = 14) (pin st 'sel (min (max 0 (#(shown 0) - 1)) (st 'sel + 1)))
                 (k = 127 || k = 8) (: q (st 'q) (pins st 'q (snip q 0 (max 0 (#q - 1))) 'sel 0))
                 (31 < k && k < 127) (pins st 'q (st 'q + string k) 'sel 0)
                 0)
     sg (mitty-stage frame step (_ \ 0))
     (pin sg 'name title, pin own () (hb 'next), hopen-stage sg 1 1))

 ; --- hands: the mitty as a model's tools see it -- every pane by id on every face, read
 ; as text, typed into, opened, focused, shut. own boxes the model's own pane, which it
 ; reads but never types into or shuts. every door answers [ok? text] ---
 (hids hb) (wharf-panes (hb 'plan) + catmap (d \ wharf-panes <(hb 'faces d)) (hfaces hb))
 (hface-of hb id) (elem id (wharf-panes (hb 'plan)) ? (hb 'face)
                     (: ds (filter (d \ elem id (wharf-panes <(hb 'faces d))) (hfaces hb)) (two? ds ? <ds ())))
 (hjoin ls) (? (two? ls) (foldl (a \ l \ a + "\n" + l) <ls >ls) "")
 ; the pane named by a model's id, a string
 (hpane-at hb t) (: n (? (string? t && 0 < #t && all (c \ 47 < c < 58) (map t ^#t))
                        (foldl (a \ c \ a * 10 + c - 48) 0 (map t ^#t)) -1)
                    p (hpane hb n)
                    (two? p ? [n p] ()))
 ; rows of a pane until it holds still: twice alike 150 ms apart, 5 s at most
 (hquiet p) (: (go a n) (: _ (rest 150) b (hscreen-text p) (? (b = a || n = 0) b (go b (n - 1))))
               (go (hscreen-text p) 32))
 (htail rs n) (: (cut l) (? (two? l && 0 = #(<l)) (cut >l) l)
                 (rev (take n (cut (rev rs)))))
 (hhands hb own)
  (: (mine? n) (n = peep own () -1)
     (miss t) [0 ("no pane " + show t)]
     {'panes (_ \ [1 (hjoin (map (n \ (: p (hpane hb n) s (peep (hbox p) () 0)
                                        (show n + "  window " + show (hface-of hb n) + "  "
                                         + (hpty? p ? ("a program, pid " + show (hpid p)) "a stage")
                                         + "  " + show (gaze s 2) + "x" + show (gaze s 1)
                                         + (n = hb 'focus && hface-of hb n = hb 'face ? "  (the user's keyboard)" "")
                                         + (mine? n ? "  (you)" ""))))
                                  (sort (hids hb))))])
      'read (t \ (hpane-at hb t @ q (two? q ? [1 (hjoin (hscreen-text (q 1)))] (miss t))))
      'type (t \ x \ (hpane-at hb t @ q
                        (? !(two? q) (miss t)
                           (mine? <q) [0 "that is your own pane"]
                           (: p (q 1) bs (map (c \ (hpty? p && c = 10 ? 13 c)) (map x ^#x))
                              (map (c \ (hpty? p ? (put (hmas p) c) (hstage p 'step c, hshow p))) bs,
                               hpty? p ? (flush (hmas p)) 0,
                               hsoil hb,
                               [1 (hjoin (htail (hquiet p) 24))])))))
      'open (_ \ (hb 'more () @ p
                    (? !(two? p) [0 "no pane opened"]
                       (: n (hb 'next) f (hb 'focus)
                          (hberth hb 'beside 50 p,
                           charm? f ? (pin hb 'focus f, hsoil hb) 0,        ; the keyboard stays put
                           [1 ("pane " + show n)])))))
      'focus (t \ (hpane-at hb t @ q
                     (? !(two? q) (miss t)
                        (: d (hface-of hb <q) (hgo hb d, pin hb 'focus <q, hsoil hb, [1 ("pane " + t + " has the keyboard")])))))
      'shut (t \ (hpane-at hb t @ q
                    (? !(two? q) (miss t)
                       (mine? <q) [0 "that is your own pane"]
                       (hshut hb <q, [1 ("pane " + t + " is closed")]))))})

 ; a model's pane: bee's full screen as a stage, a session of the hive, with the mitty's
 ; hands; why not, as a note
 (mitty-bee hb) (: b (cite 'bee 'bee-main) own {-1}
                 sg (? b (b ["--stage" (hhands hb own)]) "bee is not in this binary")
                 _ (pin own () (hb 'next))                        ; the id hberth gives it next
                 (? (tablet? sg) sg (hnote ("bee: " + (string? sg ? sg "cannot start")))))
 ; the launcher's list: the desktop's apps first, where this binary has them, then every verb
 mitty-apps ["lush" "bee" "vi" "mc" "top" "less" "man" "synth" "manifest" "story" "design" "lupa"
            "harp" "pom" "doom" "grass" "chucho"]
 (mitty-launch hb sh me)
  (: vs (sort (map show (keys (cite 'verbs 'tab))))
     names (filter (n \ elem n vs) mitty-apps + filter (n \ !(elem n mitty-apps)) vs)
     (hpicker hb "open"
              (map (n \ [n (? (n = "bee") (_ \ hopen-stage (mitty-bee hb) 1 1)
                                (n = "lush") (_ \ hopen sh 1 1)
                                (_ \ hopen (string? me ? [me n] [n]) 1 1))])
                   names)))
 ; the switcher's: every pane on every face, picking one shows its face and gives it the keyboard
 (mitty-switch hb)
  (hpicker hb "go to"
           (map (n \ (: d (hface-of hb n) p (hpane hb n)
                         [("face " + show d + "  " + hname p + "  (" + show n + ")")
                          (_ \ (hgo hb d, pin hb 'focus n, hsoil hb, ()))]))
                (filter (n \ n != hb 'next) (sort (hids hb)))))
 ; --- the bar's right side: the hive's live sessions, and each merge queue of this tree as
 ; its rows and its head's session and state. read every ten seconds, not every tick:
 ; the queue costs a git run ---
 (mitty-num t) (foldl (a \ c \ (47 < c && c < 58 ? (a * 10 + c - 48) a)) 0 (map t ^#t))
 (mitty-slurp p) (: f (open p "r") (? (hot? f) (: s (slurp f) _ (close f) s) ""))
 (mitty-live? card)
  (: ls (filter (l \ 4 < #l && "pid " = snip l 0 4) (lines (mitty-slurp card)))
     n (two? ls ? (mitty-num (snip <ls 4 #<ls)) 0)
     (0 < n && !(nom? (still n 0))))
 (mitty-hive _)
  (: e (getenv "BEE_HIVE") h (getenv "HOME")
     d (? (string? e && 0 < #e) e (string? h) (h + "/.love/run/hive") "")
     ns (readdir d)
     (two? ns ? #(filter (n \ mitty-live? (d + "/" + n + "/card")) ns) 0))
 (mitty-queues _)
  (: r (hark ["git" "for-each-ref" "--format=%(refname)" "refs/queue"])
     qs (two? r && 0 = <r ? (filter (l \ 0 < #l) (lines >r)) ())
     (map (q \ (: t (hark ["git" "cat-file" "-p" q])
                   rows (filter (l \ 0 < #l && 47 < l 0 && l 0 < 58) (lines (two? t && 0 = <t ? >t "")))
                   ws (two? rows ? (filter (w \ 0 < #w) (cite 'kore 'usplit 32 <rows)) ())
                   nm (snip q 11 #q)
                   (? !(two? rows) (nm + " empty")
                      (nm + " " + show #rows + (#rows = 1 ? " row" " rows") + ", " + (ws 1) + " " + (ws 5)))))
          qs))
 (mitty-barx _)
  (: t {'at 0 'x ""}
     (_ \ (: now (clock 0)
             (? (now - t 'at < 10000) (t 'x)
                (: hv (mitty-hive 0) qs (mitty-queues 0)
                   x ("hive " + show hv + foldl (a \ q \ a + " · " + q) "" qs)
                   (pins t 'at now 'x x, x))))))
 ; the saver as ~/.love/etc/mitty.l names it: (screensaver NAME [STYLE]) (screensaver-idle
 ; MINUTES), cycle after 10 unless said; a name no saver has, or 0 minutes, is never
 (mitty-saver _) (: sf (cite 'salt 'salt-file) wf (cite 'saver 'saver-watch) h (getenv "HOME")
                   c (? (sf && string? h) (sf (h + "/.love/etc/mitty.l") {}) {})
                   (word w) (string? w ? w (show w))
                   nm (peep c 'screensaver () @ v (two? v ? (join " " (map word v)) "cycle"))
                   m (peep c 'screensaver-idle () @ v (two? v ? <v 10))
                   (wf ? (wf nm m) ()))
 ; a mitty laid for the shell at r x c: lush in its panes (argv, when given, in the first), the
 ; bar, the mouse, the saver and the shell's keys; a server's has no tty until a client comes.
 ; answers it, or why it could not
 (mitty-lush as r c serve)
  (: me (selfpath 0) sh (string? me ? [me "lush"] ["sh"])
     p0 (hopen (two? as ? as sh) r c)
     (atom? p0 ? ("cannot start " + (two? as ? <as (sh 0)) + ": " + show p0)
        (mitty-up r c @ hb
           (? serve (pins hb 'serve 1 'csize [r c] 'in () 'out ()) 0,
            pin hb 'more (_ \ hopen sh 1 1),
            pins hb 'bar 1 'mouse 1 'barx (mitty-barx 0) 'saver (mitty-saver 0), hbartick hb, hrelay hb,
            pin (hb 'keys) 98 (_ \ hopen-stage (mitty-bee hb) 1 1),
            pin (hb 'keys) 32 (_ \ mitty-launch hb sh me),
            pin (hb 'keys) 119 (_ \ mitty-switch hb),
            hberth hb 'stack 50 p0,
            hb))))
 ; in this process, on this tty: the mitty ends with the process's own last pane. MITTY
 ; says to every child that it runs inside one: --here, or the socket of a served one
 (mitty-here as) (: _ (setenv "MITTY" "--here") sz (hsize 0) hb (mitty-lush as <sz (sz 1) 0)
                   (? (tablet? hb) (hsail hb, 0) (say err ("mitty: " + hb + "\n"), 1)))

 ; --- the server and its clients (rung 5): a mitty per name, listening on
 ; MITTY_RUN/NAME.sock (~/.love/run/mitty), outliving every terminal that attaches ---
 (mitty-dir _) (: e (getenv "MITTY_RUN") h (getenv "HOME")
                 (? (string? e && 0 < #e) e (string? h) (h + "/.love/run/mitty") "/tmp/mitty"))
 (mitty-sock nm) (mitty-dir 0 + "/" + nm + ".sock")
 (mitty-mkdirs p) (foldl (a \ w \ (: d (a + "/" + w) _ (mkdir d 448) d)) (0 < #p && p 0 = 47 ? "" ".")
                        (filter (w \ 0 < #w) (cite 'kore 'usplit 47 p)))
 (mitty-serve nm as)
  (: _ (mitty-mkdirs (mitty-dir 0)) path (mitty-sock nm)
     _ (setenv "MITTY" path)
     _ (unlink path)                                         ; a dead one's: a live one was asked first
     l (listen ['unix path])
     hb (? (hot? l) (mitty-lush as 24 80 1) ("cannot listen on " + path))
     (? !(tablet? hb) (hot? l ? (close l, unlink path, 1) 1)
        (: acc (twirl (_ \ (: (go _) (accept l @ c (hot? c ? (hattach hb c, go 0) 0)) (go 0))) 0)
           (hswim hb 1,                                      ; ... until the last pane empties
            hdetach hb,
            map (t \ landed? t ? (catch t) (freeze t)) (hb 'jobs),
            freeze acc, close l, unlink path,
            0))))
 ; a client: this tty's keys up the socket, the frames down it, and its size said as an APC
 ; when it changes. answers 1 once the server lets go, () when none listens at path
 (mitty-size r c) ("\e_mitty;size;" + show r + ";" + show c + "\e\\")
 (mitty-attach path)
  (: s (connect ['unix path])
     (? !(hot? s) ()
        (: sz (hsize 0)
           _ (raw 1)
           _ (say s (mitty-size <sz (sz 1)), flush s)
           ; park on the first byte, then swig the rest of the gulp, as moor does
           dn (twirl (_ \ (: b (cask 8192)
                             (dr _) (swig s b @ n (charm? n && 0 < n ? (say out (snip b 0 n), dr 0) 0))
                             (go _) (see s @ ch (ch < 0 ? 0 (put out ch, dr 0, flush out, go 0)))
                             (go 0))) 0)
           up (twirl (_ \ (: (dr _) (cue? in ? (put s (see in), dr 0) 0)
                             (go _) (see in @ ch (ch < 0 ? 0 (put s ch, dr 0, flush s, go 0)))
                             (go 0))) 0)
           tk (twirl (_ \ (: (go z) (: _ (rest 500) z2 (hsize 0)
                                       (? (z2 = z) (go z) (: _ (say s (mitty-size <z2 (z2 1))) _ (flush s) (go z2))))
                             (go sz))) 0)
           _ (catch dn)
           _ (freeze up) _ (freeze tk)
           _ (close s)
           _ (raw 0)
           1)))
 ; a server started detached -- its own session, no tty -- and attached to as it comes up
 (mitty-spawn nm as)
  (: me (selfpath 0) nul (openfd "/dev/null" 0)
     fds (: ns (readdir "/proc/self/fd") (two? ns ? (filter (n \ 2 < n) (map mitty-num ns)) ()))   ; none of ours goes along
     p (? (string? me) (spawnio ([me "setsid" me "mitty" "--serve" nm] + as) nul nul nul fds 0 0) -1)
     _ (? (0 <= nul) (close nul) 0)
     (charm? p && 0 < p))
 (mitty-reattach path n) (? (n = 0) () (mitty-attach path @ r (r = () ? (rest 50, mitty-reattach path (n - 1)) r)))
 (mitty-ls _) (: d (mitty-dir 0) fs (readdir d)
                ns (filter (f \ 5 < #f && ".sock" = snip f (#f - 5) #f) (two? fs ? fs ()))
                (map (f \ (: s (connect ['unix (d + "/" + f)])
                             (puts (snip f 0 (#f - 5) + (hot? s ? (close s, "") "  (dead)") + "\n"))))
                     (sort ns),
                 flush out, 0))
 ; love mitty: attach to the mitty named main (or -n NAME), started when none is up; one
 ; that cannot be served (a seat with no sockets) runs here instead. --here always does. a
 ; pane of mitty NAME never attaches to NAME: it would take the glass from the terminal
 ; showing it, and show the mitty inside itself
 (mitty-main as)
  (? (two? as && <as = "--serve" && two? >as) (mitty-serve <>as >>as)
     (two? as && <as = "--here") (mitty-here >as)
     (two? as && <as = "--ls") (mitty-ls 0)
     (two? as && elem <as ["-s" "--screensaver"]) ((cite 'saver 'saver-cli) >as)   ; a saver, no mitty
     (: nm (two? as && <as = "-n" && two? >as ? <>as "main")
        rest (two? as && <as = "-n" && two? >as ? >>as as)
        path (mitty-sock nm)
        (? (getenv "MITTY" = path) (say err ("mitty: already inside mitty " + nm + "; -n another, or --here to nest\n"), 1)
           (mitty-attach path) 0
           (mitty-spawn nm rest) (mitty-reattach path 60 @ r (r = () ? (mitty-here rest) 0))
           (mitty-here rest))))
 mitty-usage "usage: love mitty [-n NAME] [COMMAND ..]   the mitty NAME (main), started when none is up;
       COMMAND in its first pane. love mitty --ls lists them; --here runs one in this process;
       -s [NAME] a screensaver until a key, -s alone names them
  C-a: s v split, h j k l steer, x shut, [ ] copy and paste, c n p 0-9 faces, b a model,
       space open an app, w go to a pane, z the screensaver now, d detach, C-a a literal C-a"
 _ (pins (cite 'verbs 'tab) 'mitty (udoor 'mitty mitty-main mitty-usage 1 1)))
) ; module mitty
