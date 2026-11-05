; pier -- the terminal multiplexer, on tmux's keys and commands. each child rides its own pty; its
; bytes pour through a quay screen and the grids repaint the outer terminal. panes come from
; wharf.l, the paint from limn.l; neither knows a pty, so the console uses them too.
; the prefix is C-b, or C-a under PIER_PREFIX=C-a, read in the key pump ahead of every guest. a
; guest may also be a stage of this process, cli's triple (show w h) (step k) (over? _); a door
; 'key reads its keys, 'tick asks for a frame. the clip is one vi-shaped register, sent out by
; osc 52 or to 'own. host-only; a module, so a guest that berths itself (vi's splits) cites it.
(module '(pier pier pier-stage pier-up hberth hsail hopen-stage
          hstage hpty? hpane hshow hsoil hrelay hframe hmoor hsplit hsteer hshut
          hfeed hkey oars hsize htide htick hswim hquick? hcopy hpaste hclip-text hscreen-text
          hseq hmouse hpeer hpasted hfaces hgo hcycle hfresh hsub? hswap hpicker pier-launch pier-switch pier-hive pier-queues pier-barx hin hout hlive? hgreet hbye hattach hdetach pier-lush pier-here pier-serve pier-attach pier-sock pier-dir pier-ls pier-size hname hlr hbarat hdrag hmice hbarline hbarface hbartick hnote pier-window pier-main)
(borrow ((cite 'wharf) @ m (m ? m "src/apps/mitty/wharf.l")))   ; the baked module, else the tree's file
(borrow ((cite 'limn) @ m (m ? m "src/apps/mitty/limn.l")))
(borrow ((cite 'seek) @ m (m ? m "src/apps/seek.l")))
(borrow 'mooring)                       ; hopen moor waitfor
(borrow '(posix bytes window cli))
(borrow 'mitty)                         ; mw-face, for pier-window
(:
 ; --- the pier: a tablet holding the whole state (see pier-up), every pane under one plan.
 ; a pane is (box master pid stage name): a child's has master and pid, a stage's the stage.
 ; 'face is the one shown, 'faces the others' [plan focus] by number, never the shown one.
 ; 'in and 'out are the process's tty or a client's; () with none attached, and the dirt waits
 (hin hb) (peep hb 'in in)
 (hout hb) (peep hb 'out out)
 (hlive? hb) (hot? (hout hb))
 (hstage p) (p 3)
 ; what runs there, for the bar: a program's name (love's verb when it is love), a stage's own
 (hname p) (? (4 < #p) (p 4) "")
 (hpty? p) (() != hmas p)
 ; the clip's text: a linewise register ends each line, a charwise one is as it is
 (hclip-text hb) (peep (hb 'clip) () () @ v
                    (? (atom? v) ""
                       (<v = 'lin) (foldl (a \ l \ a + l + "\n") "" <>v)
                       <>v))
 ; a pane's osc 52 sets the clip to its text; a query (?) or an empty one is nothing
 (hclips hb) (map (id \ (hpane hb id @ p
                          (hpty? p ? (clipped (peep (hbox p) () 0) @
                                       (pc + ";" + d) (d = "" || d = "?" ? 0 (pin (hb 'clip) () ['chr (b64d d)]))
                                       _ 0)
                             0)))
                  (sort (keys (hb 'panes))))
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

 ; --- the stage door: a stage berths on a screen of its own, its frame scribed there
 ; at the pane's size, which the frame is asked for as w h
 (pier-stage show step over?) {'show show 'step step 'over? over?}
 (hshow p) (peep (hbox p) () 0 @ s
              (scribe s (hstage p 'show (gaze s 2) (gaze s 1))))
 ; a note on its own stage, gone at any key
 (hnote t) (: k {0}
              (pier-stage (\ w h ("\e[H\e[2J" + t + "\r\n\r\n(a key closes this)"))
                           (\ c (pin k () 1)) (\ _ (peep k () 0))))
 (hopen-stage sg r c) (: s (screen (cask (screen () r c)) r c)
                         p [{s} () () sg (peep sg 'name "stage")]
                         (hshow p,
                          p))

 ; --- the relay: every screen regridded to its rectangle and every pty told its size.
 ; a pane with no room is 1x1 (the nifs refuse a zero axis); wharf-show? keeps it off the glass.
 ; the rows the panes share: all of them, less the bar's when it is up
 (hlr hb) (hb 'rows - peep hb 'bar 0)
 (hrelay hb) (wharf-lay (hb 'plan) (hlr hb) (hb 'cols) @ bs
                (map (b \ (hpane hb (wharf-id b) @ p
                             (atom? p ? 0
                              (: nr (max 1 (wharf-rows b)) nc (max 1 (wharf-cols b))
                                 bx (hbox p)
                                 s (peep bx () 0)
                                 (nr = gaze s 1 && nc = gaze s 2 ? 0
                                  (regrid s (cask (regrid s () nr nc)) nr nc @ s2
                                     (pin bx () s2,
                                      hpty? p ? (settty (hmas p) nr nc) (hshow p))))))))
                     bs,
                 pin hb 'lay bs,
                 hsoil hb))

 ; --- the frame -------------------------------------------------------------
 ; limn paints; pier only says which grid goes where
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

 ; the outer mouse mode follows the focused pane's flag bits; reports always come as ?1006
 ; and `mouse` re-encodes them. 'mouse on: the pier wants drags itself, for its bars
 (hmice hb f) (? (f & 4096) "\e[?1003h" (f & 2048 || peep hb 'mouse 0) "\e[?1002h" (f & 1536) "\e[?1000h"
                 "\e[?1003l\e[?1002l\e[?1000l")

 ; nothing is erased between frames: panes and bars tile the wharf exactly, so every cell
 ; is written. a kitty picture (pics 1) no pane's screen keeps any more is freed there
 (hfree j hb)
  (: live {} seen {}
     (look ib) (peep seen ib 0 ? 0
                  (: _ (pin seen ib 1) p (hpane hb ib) s (two? p ? (peep (hbox p) () 0) 0)
                     (map (sl \ (picture s sl 2 @ g (charm? g ? (pin live (ib * 1048576 + (g & 1048575)) 1) 0)))
                          (jot 128))))
     (keep t id) (look (id // 1048576),
                  peep live id 0 ? (pin t id 1) (say j ("\e_Ga=d,d=I,i=" + show id + ",q=2\e\\"), t))
     (pin hb 'sent (foldl keep {} (sort (keys (hb 'sent))))))
 ; kitty (pics 1): every placement goes, the ones in view come back. sixels (pics 2) are
 ; resent only when they move, old cells erased first, never on the last row (it would scroll)
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
      hclips hb,
      (hclip-text hb @ ct
         (ct = hb 'c52 ? 0 (pin hb 'c52 ct, 0 < #ct ? (peep hb 'own () @ f (() = f ? (say j ("\e]52;c;" + b64e ct 1 + "\a")) (f ct))) 0))),
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
 ; a pane's pump runs until the child hangs up, then shuts it; 'jobs keeps it for the teardown
 (hmoor hb id) (: p (hpane hb id)
                  t (twirl (_ \ (moor (hbox p) (hmas p) (hb 'dirt), hshut hb id)) 0)
                  (pin hb 'jobs (t . hb 'jobs)))

 ; the first pane takes the whole wharf, another splits the focused one (pct its share) and
 ; takes the focus. a pane opens 1x1 and the relay gives it its size
 (hberth hb d pct p) (hb 'next @ id
                    (pin (hb 'panes) id p,
                     pin hb 'next (id + 1),
                     pin hb 'plan (() = hb 'plan ? id (wharf-split (hb 'plan) (hb 'focus) d pct id)),
                     pin hb 'focus id,
                     hrelay hb,
                     hpty? p ? (hmoor hb id) 0))
 ; the prefix's split: a fresh pane off the pier's 'more, a thunk answering one
 (hsplit hb d) (hb 'more () @ p (two? p ? (hberth hb d 50 p) 0))

 (hsteer hb d) (wharf-steer (hb 'lay) (hb 'focus) d @ id
                  (id = hb 'focus ? 0 (pin hb 'focus id, hsoil hb)))

 ; shutting twice is safe: a child may hang up on a pane the user already shut. a pane on
 ; a hidden face leaves that face's plan; the shown face emptied hands over to the first left
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

 ; --- copy mode: the focused pane's screen as a vi buffer; () where there is no vi.
 ; paste: the clip typed at a child, or handed to a stage's paste door ---
 (hcopy hb) (: p (hpane hb (hb 'focus)) vi (cite 'vi)
               (? (atom? p || !(tablet? vi)) ()
                  (: st (vi 'vi-open "")
                     rows (hscreen-text p)
                     _ (pin st 'lines (two? rows ? rows [""]))
                     fc (vi 'vi-face st {'reg (hb 'clip)})
                     sg (pier-stage (fc 0) (fc 1) (fc 2))
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
 ; an APC's body, to its ST: the one pier reads is the answer to its kitty query, which
 ; turns the pictures on
 (hapc hb) (: (go acc) (see (hin hb) @ b
                          (? (b < 0) acc
                             (b = 27) (see (hin hb) @ b2 (b2 = 92 ? acc (go (acc + string b + string b2))))
                             (go (acc + string b))))
              t (go "")
              ; a client's size: pier;size;R;C
              (t @ "Gi=31;OK" (pin hb 'pics 1, hsoil hb)
                 ("pier;size;" + (r && 1 < #r))
                  (: ws (filter (w \ 0 < #w) (cite 'kore 'usplit 59 r))
                     (? (#ws = 2) (pin hb 'csize [(pier-num <ws) (pier-num (ws 1))], htide hb) 0))
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

 ; --- keys: raw stdin pours onto the focused pane, the prefix first. a stage takes the
 ; key as a step and is painted again, or shut when the step was its last ---
 (hfeed hb ch) (hpane hb (hb 'focus) @ p
                  (? (atom? p) 0
                     (hpty? p) (hhome hb p, (put (hmas p) ch, flush (hmas p)))
                     (hstage p @ sg
                        (sg 'step ch,
                         sg 'over? () ? (hshut hb (hb 'focus))
                           (hshow p, hsoil hb)))))
 ; an arrow, the ESC read; a lone ESC is nothing
 (harrow hb) (cue? (hin hb) && (see (hin hb) @ b (b = 91 || b = 79))
              ? (see (hin hb) @ f
                   (? (f = 65) (hsteer hb 'up) (f = 66) (hsteer hb 'down)
                      (f = 67) (hsteer hb 'right) (f = 68) (hsteer hb 'left) 0)))
 ; the next pane in plan order, round to the first
 (hnext hb) (wharf-panes (hb 'plan) @ ps
             (: (go l) (? (atom? l) <ps (<l = hb 'focus) (two? >l ? <>l <ps) (go >l))
                (two? ps ? (pin hb 'focus (go ps), hsoil hb))))
 (hkey hb) (see (hin hb) @ k
              (? (k < 0) ()
                 (k = hb 'prefix) (hfeed hb k)          ; twice: a literal one
                 (k @ 34  (hsplit hb 'stack)            ; " and s
                      115 (hsplit hb 'stack)
                      37  (hsplit hb 'beside)           ; % and v
                      118 (hsplit hb 'beside)
                      27  (harrow hb)
                      111 (hnext hb)                    ; o
                      104 (hsteer hb 'left)             ; h
                      106 (hsteer hb 'down)             ; j
                      107 (hsteer hb 'up)               ; k
                      108 (hsteer hb 'right)            ; l
                      120 (hshut hb (hb 'focus))        ; x
                      91  (hcopy hb)                    ; [
                      93  (hpaste hb)                   ; ]
                      99  (hfresh hb)                   ; c
                      100 (peep hb 'serve 0 ? (hdetach hb) 0)   ; d, from a server
                      110 (hcycle hb 1)                 ; n
                      112 (hcycle hb -1)                ; p
                      (d && 47 < d < 58) (hgo hb (d - 48))   ; 0-9
                      (peep (hb 'keys) k () @ f (f ? (f () @ p (two? p ? (hberth hb 'beside 50 p) 0)) 0)))))
 ; a child gets bytes as typed, a sequence whole when its ESC has company; a stage gets
 ; edkey's keys or its own reader's. g is the attach served: a later one ends this pump
 (oars hb g) (? (peep hb 'serve 0 && g != peep hb 'gen 0) 0
              (: p (hpane hb (hb 'focus))
                 ch (? (two? p && !(hpty? p)) (peep (hstage p) 'key edkey (hin hb)) (see (hin hb)))
                 (? (ch = -1 && peep hb 'serve 0) (g = peep hb 'gen 0 ? (hdetach hb) 0)   ; a client's eof is its leaving
                    (ch = -1) (hfeed hb 4)                 ; veof follows the user's own eof
                    (ch = -7) (hshut hb (hb 'focus))
                    ((? (ch = hb 'prefix) (hkey hb)
                        (ch = 27 && hpty? p && cue? (hin hb)) (hseq hb)
                        (hfeed hb ch)),
                     oars hb g))))

 ; --- the tide: mirror the outer terminal's size onto the whole wharf -------
 ; floored: a fresh pty answers (0 . 0), and a zero wharf never recovers. a pier with
 ; no tty of its own is told its size, 'csize
 (hsize u) (tty 1 @ ws
              [(two? ws && 5 < <ws ? <ws 24)
               (two? ws && 19 < >ws ? >ws 80)])
 (htide hb) (: sz (peep hb 'serve 0 || peep hb 'csize () ? (peep hb 'csize [24 80]) (hsize 0)) r <sz c <>sz
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
                     ? !(hlive? hb) 0
                       (peep b () 0) (pin b () 0, say (hout hb) (hframe hb), flush (hout hb), 0) 0,   ; say is the bulk lane
                     ? (0 = tick % 16) (htide hb) 0,
                     ? (0 = tick % 32) (hbartick hb) 0,
                     rest (max 1 ((hquick? hb ? 8 33) - (clock () - t0))),   ; the turn's own time counts toward it
                     two? (wharf-panes (hb 'plan)) ? (hswim hb (tick + 1)) ()))

 ; --- the pier, empty, at r x c: born dirty, so frame one is painted; 'more is
 ; the caller's, a thunk answering the pane a prefix split ties up ---
 (pier-up r c) ({} @ hb
                  (pins hb 'plan () 'focus () 'next 1 'rows r 'cols c 'panes {}
                        'more () 'dirt {1} 'jobs () 'lay () 'clip {} 'sent {} 'pics 0 'six {} 'opx ()
                        'face 0 'faces {} 'c52 "" 'keys {} 'bar 0 'mouse 0 'drag ()
                        'prefix (getenv "PIER_PREFIX" = "C-a" ? 1 2),
                   hb))

 ; --- sail: the pier on the tty, raw, until the last pane empties ---
 ; alternate screen, ?1006 mouse, bracketed paste; then a kitty query, the cell size, and DA
 ; (sixels?) so every terminal answers something. only where a child has the keys: a
 ; stage's reader would eat the answers
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

 ; --- the server: a client's socket as 'in and 'out, one client at a time. an attach takes
 ; the glass from the last; a leaving (eof, the prefix and d) leaves the panes running. a client
 ; opens with its size, so hseq reads on from that ESC ---
 (hattach hb c) (: _ (hdetach hb)
                   g (peep hb 'gen 0 + 1)
                   _ (pins hb 'gen g 'in c 'out c 'mice "" 'pics 0 'sent {} 'six {})
                   _ (hgreet hb)
                   _ (hsoil hb)
                   (twirl (_ \ (hseq hb, oars hb g)) 0))
 (hdetach hb) (? !(hlive? hb) 0
                 (: c (hout hb)
                    (hbye hb, close c, pins hb 'in () 'out () 'gen (peep hb 'gen 0 + 1), 0)))

 ; --- a command: ! and its words in base64, a line, answered with what went wrong if anything.
 ; it never touches the glass, and a connection that says neither is only asking if we're up ---
 (hcmd hb c)
  (: (line acc) (see c @ b (b < 0 || b = 10 ? (rev acc) (line (b . acc))))
     ws (map b64d (filter (w \ 0 < #w) (cite 'kore 'usplit 32 (string (line ())))))
     w <ws a >ws
     ans (? (w = "kill") (each (hids hb) (hshut hb), "")
            (w = "split") (hopen-for hb >a @ q (two? q ? (hberth hb (<a = "h" ? 'beside 'stack) 50 q, "") "cannot start"))
            (w = "select") (hsteer hb (<a @ d (? (d = "L") 'left (d = "R") 'right (d = "U") 'up 'down)), "")
            ("no such command: " + show w))
     (say c ans, close c))
 (hopen-for hb as) (two? as ? (hopen as 1 1) (hb 'more ()))
 (hmeet hb c) (twirl (_ \ see c @ b (? (b = 27) (hattach hb c) (b = 33) (hcmd hb c) (close c))) 0)

 ; --- pier: tie argv, or a stage, up. answers the first child's status pair (the
 ; one the caller named), or tether's errno if it never started; 0 after a stage ---
 (pier src) (: sz (hsize 0) r <sz c <>sz
                 stg (tablet? src)
                 p0 (stg ? (hopen-stage src r c) (hopen src r c))
                 (atom? p0 ? p0
                  (pier-up r c @ hb
                     (pin hb 'more (stg ? (_ \ hopen ["sh"] 1 1) (_ \ hopen src 1 1)),
                      hberth hb 'stack 50 p0,
                      hsail hb,
                      stg ? 0 (waitfor (hpid p0))))))

 ; --- the picker: seek's list in a pane; enter replaces it with what the item opens, or
 ; closes it when the item answers no pane. an item is [label thunk] ---
 (hsub? h n) (: (go i) (? (#h < i + #n) 0 (n = snip h i (i + #n)) 1 (go (i + 1))) (go 0))
 ; a stage pane stands in for pane id: the old one's own leavings first. a pty's moor would
 ; shut the id when its child hangs up, so only a stage's place is taken this way
 (hswap hb id p) (: o (hpane hb id)
                    (? (atom? o || hpty? o) 0
                       (: _ (hstage o 'shut ? (hstage o 'shut ()) 0)
                          (pin (hb 'panes) id p, hrelay hb, hpty? p ? (hmoor hb id) 0, hsoil hb))))
 (hpicker hb title items)
  (: own {-1} d (seek-new items cap cap title)
     (go _) (hshut hb (peep own () -1))
     (pick it) ((it 1) () @ p (two? p ? (hswap hb (peep own () -1) p) (go 0)))
     (step k) (seek-key d k, d 'over ? (d 'pick @ it (two? it ? (pick it) (go 0))) 0)
     sg (pier-stage (w \ h \ seek-frame d w h) step (_ \ 0))
     (pin sg 'name title, pin own () (hb 'next), hopen-stage sg 1 1))

 ; every pane by id on every face, and the face that holds one
 (hids hb) (wharf-panes (hb 'plan) + catmap (d \ wharf-panes <(hb 'faces d)) (hfaces hb))
 (hface-of hb id) (elem id (wharf-panes (hb 'plan)) ? (hb 'face)
                     (: ds (filter (d \ elem id (wharf-panes <(hb 'faces d))) (hfaces hb)) (two? ds ? <ds ())))
 ; the launcher's list: the desktop's apps first, where this binary has them, then every verb
 pier-apps ["lush" "vi" "mc" "top" "less" "man" "synth" "manifest" "story" "design" "hexedit"
            "harp" "pom" "doom" "grass" "chucho"]
 (pier-launch hb sh me)
  (: vs (sort (map show (keys (cite 'verbs 'tab))))
     names (filter (n \ elem n vs) pier-apps + filter (n \ !(elem n pier-apps)) vs)
     (hpicker hb "open"
              (map (n \ [n (? (n = "lush") (_ \ hopen sh 1 1)
                                (_ \ hopen (string? me ? [me n] [n]) 1 1))])
                   names)))
 ; the switcher's: every pane on every face, picking one shows its face and gives it the keyboard
 (pier-switch hb)
  (hpicker hb "go to"
           (map (n \ (: d (hface-of hb n) p (hpane hb n)
                         [("face " + show d + "  " + hname p + "  (" + show n + ")")
                          (_ \ (hgo hb d, pin hb 'focus n, hsoil hb, ()))]))
                (filter (n \ n != hb 'next) (sort (hids hb)))))
 ; --- the bar's right side: the hive's live sessions, and each merge queue of this tree as
 ; its rows and its head's session and state. read every ten seconds, not every tick:
 ; the queue costs a git run ---
 (pier-num t) (foldl (a \ c \ (47 < c && c < 58 ? (a * 10 + c - 48) a)) 0 (map t ^#t))
 ; the sessions whose pid is live, as src/apps/hive.l reads the cards
 (pier-hive _) (: pid (cite 'hive 'hive-pid) alive? (cite 'hive 'hive-alive?)
                  #(filter (p \ alive? (pid (p 1))) (cite 'hive 'hive-cards 0)))
 (pier-queues _)
  (: r (hark ["git" "for-each-ref" "--format=%(refname)" "refs/queue"])
     qs (two? r && 0 = <r ? (filter (l \ 0 < #l) (lines >r)) ())
     (map (q \ (: t (hark ["git" "cat-file" "-p" q])
                   rows (filter (l \ 0 < #l && 47 < l 0 && l 0 < 58) (lines (two? t && 0 = <t ? >t "")))
                   ws (two? rows ? (filter (w \ 0 < #w) (cite 'kore 'usplit 32 <rows)) ())
                   nm (snip q 11 #q)
                   (? !(two? rows) (nm + " empty")
                      (nm + " " + show #rows + (#rows = 1 ? " row" " rows") + ", " + (ws 1) + " " + (ws 5)))))
          qs))
 (pier-barx _)
  (: t {'at 0 'x ""}
     (_ \ (: now (clock 0)
             (? (now - t 'at < 10000) (t 'x)
                (: hv (pier-hive 0) qs (pier-queues 0)
                   x ("hive " + show hv + foldl (a \ q \ a + " · " + q) "" qs)
                   (pins t 'at now 'x x, x))))))
 ; a pier laid for the shell at r x c: lush in its panes (argv, when given, in the first), the
 ; bar, the mouse and the shell's keys; a server's has no tty until a client comes.
 ; answers it, or why it could not
 (pier-lush as r c serve)
  (: me (selfpath 0) sh (string? me ? [me "lush"] ["sh"])
     p0 (hopen (two? as ? as sh) r c)
     (atom? p0 ? ("cannot start " + (two? as ? <as (sh 0)) + ": " + show p0)
        (pier-up r c @ hb
           (? serve (pins hb 'serve 1 'csize [r c] 'in () 'out ()) 0,
            pin hb 'more (_ \ hopen sh 1 1),
            pins hb 'bar 1 'mouse 1 'barx (pier-barx 0), hbartick hb, hrelay hb,
            pin (hb 'keys) 32 (_ \ pier-launch hb sh me),
            pin (hb 'keys) 119 (_ \ pier-switch hb),
            hberth hb 'stack 50 p0,
            hb))))
 ; in this process, on this tty: the pier ends with the process's own last pane. PIER
 ; says to every child that it runs inside one: --here, or the socket of a served one
 (pier-here as) (: _ (setenv "PIER" "--here") sz (hsize 0) hb (pier-lush as <sz (sz 1) 0)
                   (? (tablet? hb) (hsail hb, 0) (say err ("pier: " + hb + "\n"), 1)))

 ; --- the server and its clients: a pier per name on PIER_RUN/NAME.sock, outliving its terminals ---
 (pier-dir _) (getenv "PIER_RUN" @ e (string? e && 0 < #e ? e (cite 'path 'nest 0 + "/run/pier")))
 (pier-sock nm) (pier-dir 0 + "/" + nm + ".sock")
 (pier-serve nm as)
  (: _ (umkdirs (pier-dir 0) 448) path (pier-sock nm)
     _ (setenv "PIER" path)
     _ (unlink path)                                         ; a dead one's: a live one was asked first
     l (listen ['unix path])
     hb (? (hot? l) (pier-lush as 24 80 1) ("cannot listen on " + path))
     (? !(tablet? hb) (hot? l ? (close l, unlink path, 1) 1)
        (: acc (twirl (_ \ (: (go _) (accept l @ c (hot? c ? (hmeet hb c, go 0) 0)) (go 0))) 0)
           (hswim hb 1,                                      ; ... until the last pane empties
            hdetach hb,
            map (t \ landed? t ? (catch t) (freeze t)) (hb 'jobs),
            freeze acc, close l, unlink path,
            0))))
 ; a client: this tty's keys up the socket, the frames down it, and its size said as an APC
 ; when it changes. answers 1 once the server lets go, () when none listens at path
 (pier-size r c) ("\e_pier;size;" + show r + ";" + show c + "\e\\")
 (pier-attach path)
  (: s (connect ['unix path])
     (? !(hot? s) ()
        (: sz (hsize 0)
           _ (raw 1)
           _ (say s (pier-size <sz (sz 1)), flush s)
           ; park on the first byte, then swig the rest of the gulp, as moor does
           dn (twirl (_ \ (: b (cask 8192)
                             (dr _) (swig s b @ n (charm? n && 0 < n ? (say out (snip b 0 n), dr 0) 0))
                             (go _) (see s @ ch (ch < 0 ? 0 (put out ch, dr 0, flush out, go 0)))
                             (go 0))) 0)
           up (twirl (_ \ (: (dr _) (cue? in ? (put s (see in), dr 0) 0)
                             (go _) (see in @ ch (ch < 0 ? 0 (put s ch, dr 0, flush s, go 0)))
                             (go 0))) 0)
           tk (twirl (_ \ (: (go z) (: _ (rest 500) z2 (hsize 0)
                                       (? (z2 = z) (go z) (: _ (say s (pier-size <z2 (z2 1))) _ (flush s) (go z2))))
                             (go sz))) 0)
           _ (catch dn)
           _ (freeze up) _ (freeze tk)
           _ (close s)
           _ (raw 0)
           1)))
 ; a server started detached -- its own session, no tty -- and attached to as it comes up
 (pier-spawn nm as)
  (: me (selfpath 0) nul (openfd "/dev/null" 0)
     fds (: ns (readdir "/proc/self/fd") (two? ns ? (filter (n \ 2 < n) (map pier-num ns)) ()))   ; none of ours goes along
     p (? (string? me) (spawnio ([me "setsid" me "pier" "--serve" nm] + as) nul nul nul fds 0 0) -1)
     _ (? (0 <= nul) (close nul) 0)
     (charm? p && 0 < p))
 (pier-reattach path n) (? (n = 0) () (pier-attach path @ r (r = () ? (rest 50, pier-reattach path (n - 1)) r)))
 (pier-live? path) (connect ['unix path] @ s (hot? s ? (close s, 1) 0))
 (pier-names _) (: fs (readdir (pier-dir 0))
                   sort (map (f \ snip f 0 (#f - 5)) (filter (f \ 5 < #f && ".sock" = snip f (#f - 5) #f) (two? fs ? fs ()))))
 (pier-ls _) (each (pier-names 0) (n \ puts (n + (pier-live? (pier-sock n) ? "" "  (dead)") + "\n")),
              flush out, 0)
 ; --- pier-window: the pier for the shell (argv in its first pane, when given) in a window
 ;     of 80 by 24 cells, as mitty's face draws one. answers 0, or 1 and why it could not ---
 (pier-window as0)
  (: font (mw-font as0) as (mw-args as0)
  (window-open 640 384 "pier" @ win
   (? !(tablet? win) (say err ("pier: no window (" + show win + ")\n"), flush err, 1)
      (: wh (window-size win) r (max 2 ((wh 1) // 16)) c (max 20 (<wh // 8))
         ki (pipe 0) fo (pipe 0)
         kin (fdopen <ki) kout (fdopen >ki)            ; the keys: we write, the pier reads
         fin (fdopen <fo) fout (fdopen >fo)            ; the frames: the pier writes, we read
         gx {(screen (cask (screen () r c)) r c)}
         dirty {1}
         _ (setenv "COLORTERM" "truecolor")           ; the glass paints every pen as it is said
         hb (pier-lush as r c 0)
         (? !(tablet? hb) (say err ("pier: " + hb + "\n"), flush err, window-close win, 1)
            (: _ (pins hb 'in kin 'out fout 'csize [r c] 'own (window-own win 'clipboard) 'bar 0)
               _ (hgreet hb)
               _ (window-typing win 1)                  ; a phone's keyboard up
               held {}
               (send s) (0 < #s ? (say kout s, flush kout) 0)
               (soil _) (pin dirty () (max 1 (peep dirty () 0)))
               ; whether the pier wants a press: a wheel, or one on a bar, another pane, or a
               ; pane that asked
               (hubs r c bb) (: at (hat (hb 'lay) r c) p (hpane hb (hb 'focus))
                                (? (64 <= bb) 1
                                   (atom? at && r < hlr hb && two? (hbarat hb r c)) 1
                                   (peep hb 'bar 0 && r = hb 'rows - 1) 1
                                   (two? at && wharf-id at != hb 'focus) 1
                                   (two? p && hpty? p) (gaze (peep (hbox p) () 0) 3 & 7680 ? 1 0)
                                   0))
               up (twirl (_ \ oars hb 0) 0)
               pump (twirl (_ \ moor-to gx fin kout dirty) 0)
               ; the pier writes every cell of a frame, and a write ends the glass's
               ; selection: it is kept here with its text, and laid again while that holds
               (keep _) (: sc (peep gx () 0) s0 (gaze sc 10) s1 (gaze sc 11) k (peep held 'sel ())
                           (? (s0 < s1) (two? k && <k = s0 && k 1 = s1 ? 0 (pin held 'sel [s0 s1 (copied sc s0 s1)]))
                              !(two? k) 0
                              (copied sc <k (k 1) = k 2) (select sc <k (k 1 - 1) 0, soil 0)
                              (pin held 'sel ())))
               ; the bar while there is more than one pane or face to show on it
               (lone _) (: want (1 < #(wharf-panes (hb 'plan)) || two? (hfaces hb) ? 1 0)
                           (want = peep hb 'bar 0 ? 0 (pin hb 'bar want, hrelay hb, hsoil hb)))
               look (mw-face win gx font held dirty
                     {'send send 'wants hubs 'size (r \ c \ pin hb 'csize [r c])
                      'paste (t \ 0 < #t ? (send ("\e[200~" + t + "\e[201~")) 0)
                      'close (_ \ each (wharf-panes (hb 'plan)) (id \ (hpane hb id @ p (hpty? p ? (still (hpid p) 1) 0))))
                      'turn (_ \ (keep 0, lone 0))})
               face (twirl (_ \ look -1) 0)
               (hswim hb 1,                                   ; ... until the last pane empties
                map (t \ landed? t ? (catch t) (freeze t)) (hb 'jobs),
                hbye hb,
                pin held 'over 1,
                close fout, close kout,
                landed? up ? (catch up) (freeze up),
                landed? pump ? (catch pump) (freeze pump),
                landed? face ? (catch face) (freeze face),
                close fin, close kin,
                window-close win,
                0)))))))

 ; --- the commands, tmux's: each 0, or 1 and why it could not ---
 (pier-no t) (say err ("pier: " + t + "\n"), flush err, 1)
 ; the word after flag w, or ()
 (pier-opt as w) (? (atom? as) () (<as = w && two? >as) <>as (pier-opt >as w))
 ; -t NAME, else the session this pane is in, else main
 (pier-at as) (: t (pier-opt as "-t") e (getenv "PIER")
                 (? t (pier-sock t) (string? e && 0 < #e && e != "--here") e (pier-sock "main")))
 ; words to a session's server -> 0, or 1 and its complaint
 (pier-tell path ws)
  (: s (connect ['unix path])
     (? !(hot? s) (pier-no "no session at " + path)
        (say s ("!" + join " " (map (w \ b64e w 1) ws) + "\n"), flush s,
         slurp s @ r (close s, 0 < #r ? (pier-no r) 0))))
 ; the first free name: main, else a number
 (pier-free _) (: ns (pier-names 0) (go i) (elem (show i) ns ? (go (i + 1)) (show i))
                  (elem "main" ns && pier-live? (pier-sock "main") ? (go 0) "main"))
 (pier-up? path n) (? (pier-live? path) 1 (n < 1) 0 (rest 50, pier-up? path (n - 1)))
 ; attach to session nm, started when none is up, else run here. a pane of nm never attaches to
 ; nm: it would take the glass from the terminal showing it
 (pier-open nm as)
  (pier-sock nm @ path
    (? (getenv "PIER" = path) (pier-no ("already inside " + nm + "; new -s another, or --here to nest"))
       (!(two? (tty 0)) && window-here? 0) (pier-window as)   ; a display and no tty
       (pier-attach path) 0
       (pier-spawn nm as) (pier-reattach path 60 @ r (r = () ? (pier-here as) 0))
       (pier-here as)))
 ; new [-d] [-s NAME] [COMMAND ..]
 (pier-new as)
  (: (opts l o) (? (two? l && <l = "-d") (opts >l (pin o 'd 1))
                   (two? l && <l = "-s" && two? >l) (opts >>l (pin o 's <>l))
                   (pin o 'as l))
     o (opts as {})
     nm (peep o 's (pier-free 0)) path (pier-sock nm)
     (? (pier-live? path) (pier-no ("duplicate session: " + nm))
        !(o 'd) (pier-open nm (o 'as))
        (pier-spawn nm (o 'as) && pier-up? path 60) 0
        (pier-no ("cannot start " + nm))))
 ; attach [-t NAME]: with no name main, else the first up
 (pier-join as)
  (: t (pier-opt as "-t")
     up (filter (n \ pier-live? (pier-sock n)) (pier-names 0))
     nm (? t t (elem "main" up) "main" (two? up) <up ())
     (? !nm (pier-no "no sessions")
        (getenv "PIER" = pier-sock nm) (pier-no ("already inside " + nm))
        (pier-attach (pier-sock nm)) 0
        (pier-no ("no session: " + nm))))
 ; split-window [-h|-v] [-t NAME] [COMMAND ..]: -h side by side, as tmux
 (pier-splitw as)
  (: (opts l d t) (? (two? l && <l = "-h") (opts >l "h" t)
                     (two? l && <l = "-v") (opts >l "v" t)
                     (two? l && <l = "-t" && two? >l) (opts >>l d ["-t" <>l])
                     [d t l])
     o (opts as "v" ())
     (pier-tell (pier-at (o 1)) ("split" . <o . o 2)))
 ; select-pane -L|-R|-U|-D [-t NAME]
 (pier-selectp as)
  (: d (filter (w \ elem w ["-L" "-R" "-U" "-D"]) as)
     (two? d ? (pier-tell (pier-at as) ["select" (snip <d 1 2)])
        (pier-no "select-pane: -L, -R, -U or -D")))

 ; a word from tmux's list is that command; any other is a program for the first pane
 (pier-main as)
  (: w (two? as ? <as ()) r (two? as ? >as ())
     (? (w = "--serve" && two? r) (pier-serve <r >r)
        (w = "--here") (pier-here r)
        (w = "--window") (pier-window r)                     ; in a window of its own
        (w = "ls" || w = "list-sessions") (pier-ls 0)
        (w = "new" || w = "new-session") (pier-new r)
        (w = "a" || w = "attach" || w = "attach-session") (pier-join r)
        (w = "kill-session") (pier-tell (pier-at r) ["kill"])
        (w = "split-window" || w = "splitw") (pier-splitw r)
        (w = "select-pane" || w = "selectp") (pier-selectp r)
        (pier-open "main" as)))
 pier-usage "usage: love pier [COMMAND ..]   session main, started when none is up, COMMAND in its first pane
       love pier new [-d] [-s NAME] [COMMAND ..] | attach [-t NAME] | ls | kill-session [-t NAME]
       love pier split-window [-h|-v] [-t NAME] [COMMAND ..] | select-pane -L|-R|-U|-D [-t NAME]
       love pier --here runs one in this process; --window [-f FONT.hex] one in a window of its own
  C-b (C-a under PIER_PREFIX=C-a): % \" split, arrows or h j k l steer, o next pane, s v split, x shut,
       [ ] copy and paste, c n p 0-9 windows, b a model, space open an app, w go to a pane, d detach,
       the prefix twice a literal one"
 _ (pins (cite 'verbs 'tab) 'pier (udoor 'pier pier-main pier-usage 1 1)))
) ; module pier
