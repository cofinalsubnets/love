; berth -- quay's terminal multiplexer: where programs tie up.
;
; each child rides its own pty (tether); its bytes pour through a quay cb screen
; -- the same vt parser the kernel console runs, hosted in a cask by love/cb.c --
; and the grids repaint the outer terminal as painted cells. keys pour down the
; other way; dsr/da answers ride home off each screen's reply queue; the outer
; size is polled each second-ish and mirrored onto every pty (the kernel raises
; sigwinch on the children for us). a resize opens fresh grids -- the full-screen
; guests repaint on their sigwinch, which is the one-buffer bargain throughout.
;
; where the panes come from: apps/berth/wharf.l, and nothing about it is berth's. it is
; a plan tree in and rectangles in cells out -- no nif, no pty, no framebuffer --
; so the kernel console can lay its own panes with the same arithmetic. where the
; paint comes from: apps/berth/limn.l, the same bargain one layer down -- a grid and an
; origin in, escapes out, and it knows no more about a pty than wharf does. that
; sharing is the point; berth is just the first seat to ask. what is left here is
; which grid goes where, which is the only half berth actually owns.
;
; C-a is the prefix, and the intercept sits in the key pump, below every guest:
;   C-a s / C-a v   split the focused berth, stacked or beside
;   C-a h j k l     steer the focus
;   C-a x           shut the focused berth
;   C-a [           copy mode: the focused pane's screen in a vi buffer above it
;   C-a ]           paste the clip into the focused pane
;   C-a C-a         send a literal C-a through
; a guest never sees the prefix and never has to cooperate.
;
; the clip is the harbour's: one register, vi's shape, that every vi buffer on the
; wharf yanks into and puts from, so a yank in one pane is a put in another. copy
; mode is vi too -- the screen's rows become a buffer, and its motions and yanks
; are the selection -- and :q closes it. a paste into a child is the text typed at
; it; into a stage, its 'paste door, which vi answers with a put, or the text typed
; in insert mode
;
; a guest need not be a child either: a stage of this process -- cli's triple, (show w
; h) the frame as escapes, (step k) a key, (over? _) done -- berths the same way. its
; frame is scribed onto the pane's screen as a child's bytes are, so it knows nothing
; of panes, and its keys come through edkey as on cli's stage, or through its own
; reader if a door 'key holds one, for a guest whose keys edkey does not spell. a door
; 'tick is asked every swim: a true answer is a frame to paint, which is how a guest
; with a clock or a card gets its turn without a key. splits from a stage open a shell.
;
; run: out/love -e "(: _ (borrow 'berth) (berth [\"sh\"]))"
;      out/love -e "(: _ (borrow 'berth) (berth [\"vim\" \"README.md\"]))"
;      out/love -e "(: _ (borrow 'berth) (berth (berth-stage SHOW STEP OVER?)))"
;      (-l apps/berth/berth.l ahead of -e runs the file on disk instead of the baked one)
;
; host-only (screen/scribe + tether/gather + raw/tty ride love/*.c), so
; berth never joins the corpus; the moor core needs no tty and is smoke-
; tested end to end over a real pty by test/host/berth.l. a module, so a guest
; that berths itself (vi's splits) cites it: harbour makes an empty wharf, hberth
; ties a pane up on it, and hsail runs it on the tty until the last pane leaves.
(module '(berth berth berth-stage harbour hberth hsail hopen hopen-stage moor waitfor
          hbox hmas hpid hstage hpty? hpane hsoil hrelay hframe hmoor hsplit hsteer hshut
          hfeed hkey oars hsize htide htick hswim hquick? hcopy hpaste hclip-text hscreen-text)
(borrow (: m (cite 'wharf) (? m m "apps/berth/wharf.l")))   ; the baked module, else the tree's file
(borrow (: m (cite 'limn) (? m m "apps/berth/limn.l")))
(borrow 'posix)
(:
 ; --- the moor: pump the master through the screen until the child hangs up.
 ; the screen lives in box bx (a relay swaps it); replies pour straight back;
 ; a dirty box (when given) cues the painter
 ; park on the first byte, then swig the rest of the gulp -- per-byte sees
 ; cap out near a megabyte a second, and a full-screen guest pours six
 ; the box is re-read every gulp on purpose: that is how a resize reaches a
 ; running moor with no signal, and why a pane's screen may be swapped freely.
 (moor bx m dirty) (: ch (see m)
                    (? (= ch -1) ()
                     (: s (peep bx () 0)
                        _ (scribe s ch)
                        b (cask 8192)
                        _ (: (drain x) (: n (swig m b)
                                          (? (charm? n && < 0 n)
                                             (: _ (scribe (peep bx () 0) (snip b 0 n))
                                                (drain ()))
                                             0))
                           (drain ()))
                        rep (reply (peep bx () 0))
                        ; a reply is a byte stream and its order is the whole content
                        ; of it -- and one say beats six puts.
                        _ (? rep (: _ (say m (foldl (\ a b (+ a (string b))) "" rep))
                                    (flush m))
                             0)
                        _ (? dirty (pin dirty () 1) 0)
                        (moor bx m dirty))))

 (waitfor pid) (: s (gather pid) (? (two? s) s (nom? s) s (do (rest 2) (waitfor pid))))

 ; --- the harbour: every berth's screen, pty and child, under one wharf plan ---
 ; a pane is (box master pid stage): a child's has its master and pid and no stage,
 ; a stage's the stage and neither. the harbour is a tablet, and the keys are the
 ; whole state: plan focus next rows cols panes lay dirt more jobs clip.
 (hbox p) <p
 (hmas p) <>p
 (hpid p) <>>p
 (hstage p) (p 3)
 (hpty? p) (!= () (hmas p))
 ; the clip's text: a linewise register ends each line, a charwise one is as it is
 (hclip-text hb) (: v (peep (hb 'clip) () ())
                    (? !(two? v) ""
                       (<v = 'lin) (foldl (\ a l (a + l + "\n")) "" <>v)
                       <>v))
 ; a pane's screen as rows of text, each with its trailing blanks off; the glyphs
 ; come out as limn paints them
 (hscreen-text p) (: s (peep (hbox p) () 0) r (gaze s 1) c (gaze s 2)
                     (cp i) (glass s i 0 & 2097151)
                     (row i) (: (go q acc) (? (q < 0) acc (go (q - 1) ((limn-glyph (cp (i * c + q))) + acc)))
                                (last q) (? (q < 0) -1 (32 = cp (i * c + q) || 0 = cp (i * c + q)) (last (q - 1)) q)
                                (go (last (c - 1)) ""))
                     (map row (jot r)))
 (hpane hb id) (peep (hb 'panes) id ())
 (hfind bs id) (? (two? bs) (? (= (wharf-id <bs) id) <bs (hfind >bs id)) ())
 (hsoil hb) (: b (hb 'dirt) (pin b () 1))

 ; open a child on its own pty at r x c. tether's errno rides back out on a
 ; refusal -- a nom, never two?, which is how the caller tells it from a pane.
 (hopen argv r c) (: _ (setenv "TERM" "xterm-256color")   ; the dialect we actually speak
                     md (tether argv)
                     (? !(two? md) md
                      (: m >md
                         s (screen (cask (screen () r c)) r c)
                         bx {s}
                         _ (settty m r c)
                         [bx m <md ()])))

 ; --- the stage door: a stage berths on a screen of its own, its frame scribed there
 ; at the pane's size, which the frame is asked for as w h
 (berth-stage show step over?) {'show show 'step step 'over? over?}
 (hshow p) (: s (peep (hbox p) () 0)
              (scribe s ((hstage p) 'show (gaze s 2) (gaze s 1))))
 (hopen-stage sg r c) (: s (screen (cask (screen () r c)) r c)
                         p [{s} () () sg]
                         _ (hshow p)
                         p)

 ; --- the relay: the plan says where every berth is, so every screen is opened
 ; to its rectangle and every pty told its new size. content is the guest's to
 ; repaint on its own sigwinch -- the one-buffer bargain, now once per pane.
 ; a berth with no room still needs a valid screen (the nifs refuse a zero
 ; axis), so its grid is 1x1 and wharf-show? is what keeps it off the glass.
 (hrelay hb) (: bs (wharf-lay (hb 'plan) (hb 'rows) (hb 'cols))
                _ (map (\ b (: p (hpane hb (wharf-id b))
                               (? !(two? p) 0
                                (: nr (max 1 (wharf-rows b)) nc (max 1 (wharf-cols b))
                                   bx (hbox p)
                                   s (peep bx () 0)
                                   (? ((= nr (gaze s 1)) && (= nc (gaze s 2))) 0
                                    (: s2 (screen (cask (screen () nr nc)) nr nc)
                                       _ (pin bx () s2)
                                       (? (hpty? p) (settty (hmas p) nr nc) (hshow p))))))))
                       bs)
                _ (pin hb 'lay bs)
                (hsoil hb))

 ; --- the frame -------------------------------------------------------------
 ; the painting is apps/berth/limn.l's: cells at an origin, and the bars off wharf-bars.
 ; what stays here is which grid goes where, which is the only half berth owns
 (hbars j hb) (limn-bars j (wharf-bars (hb 'plan) (hb 'rows) (hb 'cols)))

 ; nothing is erased between frames, and nothing needs to be: panes and bars
 ; tile the wharf exactly (apps/berth/wharf.l's standing law), so every cell is written
 ; every frame and no stale glyph can survive a layout change.
 (hframe hb)
  (: j (jug 0)
     _ (say j "\e[?25l")
     _ (map (\ b (: p (hpane hb (wharf-id b))
                    (? (wharf-show? b && two? p)
                       (limn-rows j (peep (hbox p) () 0) (wharf-rows b) (wharf-cols b)
                                    (wharf-row b) (wharf-col b) 0 -1)
                       0)))
            (hb 'lay))
     _ (hbars j hb)
     _ (: p (hpane hb (hb 'focus)) b (hfind (hb 'lay) (hb 'focus))
          (? (two? p && two? b)
             (: s (peep (hbox p) () 0) w (gaze s 0) c (gaze s 2) f (gaze s 3)
                _ (say j (limn-go (wharf-row b + (// w c)) (wharf-col b + (% w c))))
                (? (& 1 f) (say j "\e[?25h") 0))          ; the guest's cursor wish
             0))
     (slurp j))

 ; --- the berths: opening, steering, shutting -------------------------------
 ; a pane's pump, twirled: moor runs until the child hangs up and the berth is
 ; shut for it. the handle is kept in 'jobs so the teardown can reap it.
 (hmoor hb id) (: p (hpane hb id)
                  t (twirl (\ _ (: _ (moor (hbox p) (hmas p) (hb 'dirt)) (hshut hb id))) 0)
                  (pin hb 'jobs (t . hb 'jobs)))

 ; tie a pane up: the first takes the whole wharf, another splits the focused berth
 ; and takes its focus, pct the share the focused one keeps. a pane opens at 1x1 and
 ; the relay right after is what gives it its real size; a child's pump is twirled here
 (hberth hb d pct p) (: id (hb 'next)
                    _ (pin (hb 'panes) id p)
                    _ (pin hb 'next (id + 1))
                    _ (pin hb 'plan (? (= () (hb 'plan)) id (wharf-split (hb 'plan) (hb 'focus) d pct id)))
                    _ (pin hb 'focus id)
                    _ (hrelay hb)
                    (? (hpty? p) (hmoor hb id) 0))
 ; the prefix's split: a fresh pane off the harbour's 'more, a thunk answering one
 (hsplit hb d) (: p ((hb 'more) ()) (? (two? p) (hberth hb d 50 p) 0))

 (hsteer hb d) (: id (wharf-steer (hb 'lay) (hb 'focus) d)
                  (? (= id (hb 'focus)) 0 (: _ (pin hb 'focus id) (hsoil hb))))

 ; shut a berth: its pty closes, the plan promotes its sibling over the bar they
 ; shared, and the focus moves on if it was the one that left. shutting twice
 ; is safe -- the second finds no pane and closes nothing, which is what a child
 ; hanging up on a berth the user already shut looks like.
 (hshut hb id) (: p (hpane hb id)
                  _ (? (two? p && hpty? p) (close (hmas p)) 0)
                  _ (pin (hb 'panes) id ())
                  pl (wharf-shut (hb 'plan) id)
                  _ (pin hb 'plan pl)
                  _ (? (= id (hb 'focus))
                       (: bs (wharf-berths pl) (pin hb 'focus (? (two? bs) <bs ())))
                       0)
                  (hrelay hb))

 ; --- copy mode: the focused pane's screen as a vi buffer above it, on the clip;
 ; answers the buffer's state, or () on a seat with no vi. paste: the clip typed at
 ; a child, or handed to a stage's paste door ---
 (hcopy hb) (: p (hpane hb (hb 'focus)) vi (cite 'vi)
               (? (!(two? p) || !(tablet? vi)) ()
                  (: st (vi 'vi-open "")
                     rows (hscreen-text p)
                     _ (pin st 'lines (two? rows ? rows [""]))
                     fc (vi 'vi-face st {'reg (hb 'clip)})
                     sg (berth-stage (fc 0) (fc 1) (fc 2))
                     _ (pin sg 'paste (fc 3))
                     _ (hberth hb 'stack 50 (hopen-stage sg 1 1))
                     st)))
 (hpaste hb) (: p (hpane hb (hb 'focus)) v (peep (hb 'clip) () ())
                (? (!(two? p) || !(two? v)) 0
                   (hpty? p) (: _ (say (hmas p) (hclip-text hb)) (flush (hmas p)))
                   (: sg (hstage p)
                      (? (sg 'paste) (: _ (sg 'paste v) _ (hshow p) (hsoil hb)) 0))))

 ; --- keys: raw stdin pours onto the focused pane, C-a first. a stage takes the
 ; key as a step and is painted again, or shut when the step was its last ---
 (hfeed hb ch) (: p (hpane hb (hb 'focus))
                  (? !(two? p) 0
                     (hpty? p) (: _ (put (hmas p) ch) (flush (hmas p)))
                     (: sg (hstage p)
                        _ (sg 'step ch)
                        (? (sg 'over? ()) (hshut hb (hb 'focus))
                           (: _ (hshow p) (hsoil hb))))))
 (hkey hb) (: k (see in)
              (? (< k 0)   ()
                 (= k 1)   (hfeed hb 1)                 ; C-a C-a: a literal one
                 (= k 115) (hsplit hb 'stack)           ; s
                 (= k 118) (hsplit hb 'beside)          ; v
                 (= k 104) (hsteer hb 'left)            ; h
                 (= k 106) (hsteer hb 'down)            ; j
                 (= k 107) (hsteer hb 'up)              ; k
                 (= k 108) (hsteer hb 'right)           ; l
                 (= k 120) (hshut hb (hb 'focus))       ; x
                 (= k 91)  (hcopy hb)                   ; [
                 (= k 93)  (hpaste hb)                  ; ]
                 0))
 ; a child gets the bytes as typed; a stage gets edkey's keys, as on cli's stage, or
 ; its own reader's; and the user's eof leaves it
 (oars hb) (: p (hpane hb (hb 'focus))
              ch (? (two? p && !(hpty? p)) ((peep (hstage p) 'key edkey) in) (see in))
              (? (= ch -1) (hfeed hb 4)                 ; veof follows the user's own eof
                 (= ch -7) (hshut hb (hb 'focus))
               (: _ (? (= ch 1) (hkey hb) (hfeed hb ch))
                  (oars hb))))

 ; --- the tide: mirror the outer terminal's size onto the whole wharf -------
 ; the floor is not decoration, and it lives here so both callers share it: a
 ; fresh pty answers (0 . 0) -- two? and true and useless -- and a wharf of no
 ; cells lays every berth at zero extent, which paints a blank screen and never
 ; recovers. the opening had this floor; the tide did not, and quietly undid it
 ; half a second in.
 (hsize u) (: ws (tty 1)
              [(? (two? ws && (< 5 <ws)) <ws 24)
               (? (two? ws && (< 19 >ws)) >ws 80)])
 (htide hb) (: sz (hsize 0) r <sz c <>sz
               (? ((= r (hb 'rows)) && (= c (hb 'cols))) ()
                (: _ (pin hb 'rows r) _ (pin hb 'cols c) (hrelay hb))))

 ; --- the ticks: every stage with a tick door is asked, and painted on a yes; one
 ; that is over on its own, with no key, is shut ---
 (htick hb) (map (\ id (: p (hpane hb id) sg (? (two? p) (hstage p) ())
                          (? !(tablet? sg) 0
                             (sg 'over? ()) (hshut hb id)
                             (sg 'tick && sg 'tick ()) (: _ (hshow p) (hsoil hb))
                             0)))
                 (wharf-berths (hb 'plan)))

 ; a stage with a tick door is on a clock of its own -- a card to feed -- so the swim
 ; turns faster while one is berthed
 (hquick? hb) (any (\ id (: p (hpane hb id) sg (? (two? p) (hstage p) ()))
                          (tablet? sg && sg 'tick))
                  (wharf-berths (hb 'plan)))
 ; --- the swim: repaint on dirt at ~30fps, feel the tide every half second,
 ; and end when the last berth empties ---
 (hswim hb tick) (: b (hb 'dirt)
                    _ (htick hb)
                    _ (? (peep b () 0)
                         (: _ (pin b () 0) _ (say out (hframe hb)) 0)   ; say is the bulk lane
                         0)
                    _ (? (= 0 (% tick 16)) (htide hb) 0)
                    _ (rest (hquick? hb ? 8 33))
                    (? (two? (wharf-berths (hb 'plan))) (hswim hb (tick + 1)) ()))

 ; --- the harbour, empty, at r x c: born dirty, so frame one is painted; 'more is
 ; the caller's, a thunk answering the pane a prefix split ties up ---
 (harbour r c) (: hb {}
                  _ (pins hb 'plan () 'focus () 'next 1 'rows r 'cols c 'panes {}
                          'more () 'dirt {1} 'jobs () 'lay () 'clip {})
                  hb)

 ; --- sail: the harbour on the tty, raw and on the alternate screen, keys pumped
 ; and frames painted until the last berth empties; the tty as it was after ---
 (hsail hb) (: _ (raw 1)
               _ (say out "\e[?1049h\e[2J")
               _ (flush out)
               up (twirl (\ _ (oars hb)) 0)
               _ (hswim hb 1)               ; ... until the last berth empties
               _ (map (\ t (? (landed? t) (catch t) (freeze t))) (hb 'jobs))
               _ (? (landed? up) (catch up) (freeze up))
               _ (say out "\e[0m\e[?25h\e[?1049l")
               _ (flush out)
               _ (raw 0)
               0)

 ; --- berth: tie argv, or a stage, up. answers the first child's status pair (the
 ; one the caller named), or tether's errno if it never started; 0 after a stage ---
 (berth src) (: sz (hsize 0) r <sz c <>sz
                 stg (tablet? src)
                 p0 (stg ? (hopen-stage src r c) (hopen src r c))
                 (? !(two? p0) p0
                  (: hb (harbour r c)
                     _ (pin hb 'more (stg ? (\ _ (hopen ["sh"] 1 1)) (\ _ (hopen src 1 1))))
                     _ (hberth hb 'stack 50 p0)
                     _ (hsail hb)
                     (stg ? 0 (waitfor (hpid p0)))))))
) ; module berth
