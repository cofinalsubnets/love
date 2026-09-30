; berth -- quay's terminal multiplexer: where programs tie up.
;
; each child rides its own pty (tether); its bytes pour through a quay cb screen (the
; kernel console's vt parser, hosted by src/love/cb.c) and the grids repaint the outer
; terminal. the panes come from wharf.l (plan tree -> rectangles), the paint from limn.l
; (grid -> escapes); neither knows a pty, so the kernel console uses them too.
;
; C-a is the prefix, intercepted in the key pump below every guest: s/v split, h j k l
; steer, x shut, [ copy mode (the pane's screen as a vi buffer), ] paste, C-a a literal.
; the clip is the harbour's one register, vi's shape, shared by every vi buffer on it.
; a guest may be a stage of this process -- cli's triple (show w h) (step k) (over? _) --
; berthed like a child; a door 'key reads its keys, a door 'tick asks for a frame.
;
; run: out/love -e "(: _ (borrow 'berth) (berth [\"sh\"]))"
; host-only (screen/tether/tty ride src/love/*.c): never in the corpus; test/host/berth.l
; smokes it over a real pty. a module, so a guest that berths itself (vi's splits) cites it.
(module '(berth berth berth-stage harbour hberth hsail hopen hopen-stage moor waitfor
          hbox hmas hpid hstage hpty? hpane hsoil hrelay hframe hmoor hsplit hsteer hshut
          hfeed hkey oars hsize htide htick hswim hquick? hcopy hpaste hclip-text hscreen-text
          hseq hmouse hpeer hpasted)
(borrow ((cite 'wharf) @ m (m ? m "src/apps/berth/wharf.l")))   ; the baked module, else the tree's file
(borrow ((cite 'limn) @ m (m ? m "src/apps/berth/limn.l")))
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

 ; --- the harbour: every berth's screen, pty and child, under one wharf plan ---
 ; a pane is (box master pid stage): a child's has its master and pid and no stage,
 ; a stage's the stage and neither. the harbour is a tablet, and the keys are the
 ; whole state: plan focus next rows cols panes lay dirt more jobs clip.
 (hbox p) <p
 (hmas p) <>p
 (hpid p) <>>p
 (hstage p) (p 3)
 (hpty? p) (() != hmas p)
 ; the clip's text: a linewise register ends each line, a charwise one is as it is
 (hclip-text hb) (peep (hb 'clip) () () @ v
                    (? (atom? v) ""
                       (<v = 'lin) (foldl (a \ l \ a + l + "\n") "" <>v)
                       <>v))
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
                          [bx m <md ()]))))

 ; --- the stage door: a stage berths on a screen of its own, its frame scribed there
 ; at the pane's size, which the frame is asked for as w h
 (berth-stage show step over?) {'show show 'step step 'over? over?}
 (hshow p) (peep (hbox p) () 0 @ s
              (scribe s (hstage p 'show (gaze s 2) (gaze s 1))))
 (hopen-stage sg r c) (: s (screen (cask (screen () r c)) r c)
                         p [{s} () () sg]
                         (hshow p,
                          p))

 ; --- the relay: the plan says where every berth is, so every screen is laid
 ; across to its rectangle and every pty told its new size. what the old grid
 ; held comes along; the rest is the guest's to repaint on its own sigwinch.
 ; a berth with no room still needs a valid screen (the nifs refuse a zero
 ; axis), so its grid is 1x1 and wharf-show? is what keeps it off the glass.
 (hrelay hb) (wharf-lay (hb 'plan) (hb 'rows) (hb 'cols) @ bs
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
 ; the painting is src/apps/berth/limn.l's: cells at an origin, and the bars off wharf-bars.
 ; what stays here is which grid goes where, which is the only half berth owns
 (hbars j hb) (limn-bars j (wharf-bars (hb 'plan) (hb 'rows) (hb 'cols)))

 ; the outer terminal's mouse follows the focused pane's wish (quay.h's flag bits); the
 ; reports always come as ?1006's, and `mouse` lays them into what the pane asked for
 (hmice f) (? (f & 4096) "\e[?1003h" (f & 2048) "\e[?1002h" (f & 1536) "\e[?1000h"
              "\e[?1003l\e[?1002l\e[?1000l")

 ; nothing is erased between frames, and nothing needs to be: panes and bars
 ; tile the wharf exactly (src/apps/berth/wharf.l's standing law), so every cell is written
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
      (: p (hpane hb (hb 'focus)) b (hfind (hb 'lay) (hb 'focus))
         (two? p && two? b ?
            (: s (peep (hbox p) () 0) w (gaze s 0) c (gaze s 2) f (gaze s 3)
               cr (w // c + gaze s 8)                      ; the cursor's row, under the view
               _ (say j (limn-go (wharf-row b + min cr (wharf-rows b - 1)) (wharf-col b + w % c)))
               _ (1 & f && cr < wharf-rows b ? (say j "\e[?25h") 0)     ; the guest's cursor wish
               m (hmice f)
               (m = peep hb 'mice "" ? 0 (pin hb 'mice m, say j m)))
            0)),
      slurp j))

 ; --- the berths: opening, steering, shutting -------------------------------
 ; a pane's pump, twirled: moor runs until the child hangs up and the berth is
 ; shut for it. the handle is kept in 'jobs so the teardown can reap it.
 (hmoor hb id) (: p (hpane hb id)
                  t (twirl (_ \ (moor (hbox p) (hmas p) (hb 'dirt), hshut hb id)) 0)
                  (pin hb 'jobs (t . hb 'jobs)))

 ; tie a pane up: the first takes the whole wharf, another splits the focused berth
 ; and takes its focus, pct the share the focused one keeps. a pane opens at 1x1 and
 ; the relay right after is what gives it its real size; a child's pump is twirled here
 (hberth hb d pct p) (hb 'next @ id
                    (pin (hb 'panes) id p,
                     pin hb 'next (id + 1),
                     pin hb 'plan (() = hb 'plan ? id (wharf-split (hb 'plan) (hb 'focus) d pct id)),
                     pin hb 'focus id,
                     hrelay hb,
                     hpty? p ? (hmoor hb id) 0))
 ; the prefix's split: a fresh pane off the harbour's 'more, a thunk answering one
 (hsplit hb d) (hb 'more () @ p (two? p ? (hberth hb d 50 p) 0))

 (hsteer hb d) (wharf-steer (hb 'lay) (hb 'focus) d @ id
                  (id = hb 'focus ? 0 (pin hb 'focus id, hsoil hb)))

 ; shut a berth: its pty closes, the plan promotes its sibling over the bar they
 ; shared, and the focus moves on if it was the one that left. shutting twice
 ; is safe -- the second finds no pane and closes nothing, which is what a child
 ; hanging up on a berth the user already shut looks like.
 (hshut hb id) (: p (hpane hb id)
                  _ (two? p && hpty? p ? (close (hmas p)) 0)
                  _ (pin (hb 'panes) id ())
                  pl (wharf-shut (hb 'plan) id)
                  (pin hb 'plan pl,
                   ? (id = hb 'focus) (wharf-berths pl @ bs (pin hb 'focus (two? bs ? <bs ()))) 0,
                   hrelay hb))

 ; --- copy mode: the focused pane's screen as a vi buffer above it, on the clip;
 ; answers the buffer's state, or () on a seat with no vi. paste: the clip typed at
 ; a child, or handed to a stage's paste door ---
 (hcopy hb) (: p (hpane hb (hb 'focus)) vi (cite 'vi)
               (? (atom? p || !(tablet? vi)) ()
                  (: st (vi 'vi-open "")
                     rows (hscreen-text p)
                     _ (pin st 'lines (two? rows ? rows [""]))
                     fc (vi 'vi-face st {'reg (hb 'clip)})
                     sg (berth-stage (fc 0) (fc 1) (fc 2))
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

 ; --- the mouse: an outer ?1006 report at x y (1-based). a press on another berth moves
 ; the focus; else the focused pane gets it at its own origin, clamped inside, as its
 ; screen asked -- and a wheel it did not ask for scrolls its history ---
 (hat bs r c) (two? bs ?
                 (<bs @ b
                    (wharf-row b <= r && r < wharf-row b + wharf-rows b
                     && wharf-col b <= c && c < wharf-col b + wharf-cols b ? b (hat >bs r c))))
 (hmouse hb b x y up)
  (: r (y - 1) c (x - 1)
     how (? up 1 (b & 32) 2 0)
     bb (b - (b & 32)) btn (bb - (bb & 28))
     at (hat (hb 'lay) r c)
     (? ((how = 0) && (btn < 64) && (two? at) && !(wharf-id at = hb 'focus))
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
 (hbracket u) (: (go acc) (see in @ b
                             (b < 0 ? acc
                                ((b . acc) @ a2
                                   (b = 126 && [126 49 48 50 91 27] = take 6 a2 ? (drop 6 a2) (go a2)))))
                 (string (rev (go ()))))
 (hsend hb t) (: (go i) (i < #t ? (hfeed hb (t i), go (i + 1)) 0) (go 0))
 ; an APC's body, to its ST: the one berth reads is the answer to its kitty query, which
 ; turns the pictures on
 (hapc hb) (: (go acc) (see in @ b
                          (? (b < 0) acc
                             (b = 27) (see in @ b2 (b2 = 92 ? acc (go (acc + string b + string b2))))
                             (go (acc + string b))))
              t (go "")
              (t = "Gi=31;OK" ? (pin hb 'pics 1, hsoil hb) 0))
 (hseq hb) (see in @ b1
              (? (b1 = 95) (hapc hb)
                 !(b1 = 91) (hfeed hb 27, -1 < b1 ? (hfeed hb b1) 0)
                 (: (csi acc) (see in @ b (b < 0 || 63 < b && b < 127 ? [acc b] (csi (acc + string b))))
                    q (csi "") a <q f <>q
                    (? (f < 0) (hsend hb ("\e[" + a))
                       ((f = 77 || f = 109) && 0 < #a && a 0 = 60)
                        (hnums a @ ns (#ns = 3 ? (hmouse hb <ns <>ns <>>ns (f = 109)) 0))
                       (f = 126 && a = "5;2") (hpeer hb (hhalf hb))
                       (f = 126 && a = "6;2") (hpeer hb (0 - hhalf hb))
                       (f = 126 && a = "200") (hpasted hb (hbracket 0))
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
 (hkey hb) (see in @ k
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
                      0)))
 ; a child gets the bytes as typed, a sequence read whole when its ESC has company
 ; (a lone ESC is a key); a stage gets edkey's keys, as on cli's stage, or its own
 ; reader's; and the user's eof leaves it
 (oars hb) (: p (hpane hb (hb 'focus))
              ch (? (two? p && !(hpty? p)) (peep (hstage p) 'key edkey in) (see in))
              (? (ch = -1) (hfeed hb 4)                 ; veof follows the user's own eof
                 (ch = -7) (hshut hb (hb 'focus))
                 ((? (ch = 1) (hkey hb)
                     (ch = 27 && hpty? p && cue? in) (hseq hb)
                     (hfeed hb ch)),
                  oars hb)))

 ; --- the tide: mirror the outer terminal's size onto the whole wharf -------
 ; the floor is not decoration, and it lives here so both callers share it: a
 ; fresh pty answers (0 . 0) -- two? and true and useless -- and a wharf of no
 ; cells lays every berth at zero extent, which paints a blank screen and never
 ; recovers. the opening had this floor; the tide did not, and quietly undid it
 ; half a second in.
 (hsize u) (tty 1 @ ws
              [(two? ws && 5 < <ws ? <ws 24)
               (two? ws && 19 < >ws ? >ws 80)])
 (htide hb) (: sz (hsize 0) r <sz c <>sz
               (r = hb 'rows && c = hb 'cols ? ()
                (pin hb 'rows r, pin hb 'cols c, hrelay hb)))

 ; --- the ticks: every stage with a tick door is asked, and painted on a yes; one
 ; that is over on its own, with no key, is shut ---
 (htick hb) (map (id \ (: p (hpane hb id) sg (two? p ? (hstage p) ())
                          (? !(tablet? sg) 0
                             (sg 'over? ()) (hshut hb id)
                             (sg 'tick && sg 'tick ()) (hshow p, hsoil hb)
                             0)))
                 (wharf-berths (hb 'plan)))

 ; a stage with a tick door is on a clock of its own -- a card to feed -- so the swim
 ; turns faster while one is berthed
 (hquick? hb) (any (id \ (: p (hpane hb id) sg (two? p ? (hstage p))
                             (tablet? sg && sg 'tick)))
                  (wharf-berths (hb 'plan)))
 ; --- the swim: repaint on dirt at ~30fps, feel the tide every half second,
 ; and end when the last berth empties ---
 (hswim hb tick) (hb 'dirt @ b
                    (htick hb,
                     ? (peep b () 0) (pin b () 0, say out (hframe hb), 0) 0,   ; say is the bulk lane
                     ? (0 = tick % 16) (htide hb) 0,
                     rest (hquick? hb ? 8 33),
                     two? (wharf-berths (hb 'plan)) ? (hswim hb (tick + 1)) ()))

 ; --- the harbour, empty, at r x c: born dirty, so frame one is painted; 'more is
 ; the caller's, a thunk answering the pane a prefix split ties up ---
 (harbour r c) ({} @ hb
                  (pins hb 'plan () 'focus () 'next 1 'rows r 'cols c 'panes {}
                        'more () 'dirt {1} 'jobs () 'lay () 'clip {} 'sent {} 'pics 0 'six {} 'opx (),
                   hb))

 ; --- sail: the harbour on the tty, raw and on the alternate screen, keys pumped
 ; and frames painted until the last berth empties; the tty as it was after ---
 (hsail hb) (: _ (raw 1)
               _ (say out "\e[?1049h\e[2J\e[?1006h\e[?2004h")   ; the mouse's reports as ?1006's, pastes bracketed
               ; does the outer terminal take kitty's pictures? a 1x1 query, then its cell's
               ; size, and DA behind them so a terminal that ignores APC still answers something
               ; (and says whether it draws sixels). asked only where a child has the keys: a
               ; stage's reader would take the answers for keys
               _ (hpty? (hpane hb (hb 'focus)) ? (say out "\e_Gi=31,s=1,v=1,a=q,t=d,f=24;AAAA\e\\\e[16t\e[c") 0)
               _ (flush out)
               up (twirl (_ \ oars hb) 0)
               (hswim hb 1,                 ; ... until the last berth empties
                map (t \ landed? t ? (catch t) (freeze t)) (hb 'jobs),
                landed? up ? (catch up) (freeze up),
                say out (peep hb 'pics 0 = 1 ? "\e_Ga=d,d=A,q=2\e\\" ""),   ; every picture sent, freed
                say out "\e[0m\e[?25h\e[?1003l\e[?1002l\e[?1000l\e[?1006l\e[?2004l\e[?1049l",
                flush out,
                raw 0,
                0))

 ; --- berth: tie argv, or a stage, up. answers the first child's status pair (the
 ; one the caller named), or tether's errno if it never started; 0 after a stage ---
 (berth src) (: sz (hsize 0) r <sz c <>sz
                 stg (tablet? src)
                 p0 (stg ? (hopen-stage src r c) (hopen src r c))
                 (atom? p0 ? p0
                  (harbour r c @ hb
                     (pin hb 'more (stg ? (_ \ hopen ["sh"] 1 1) (_ \ hopen src 1 1)),
                      hberth hb 'stack 50 p0,
                      hsail hb,
                      stg ? 0 (waitfor (hpid p0)))))))
) ; module berth
