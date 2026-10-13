; src/apps/mitty/porthole.l -- the mitty through a porthole: `love mitty --window`, the
; mitty in a window of its own (src/apps/window.l), on X or on inle's screen.
;
; the mitty is as it is on a terminal, its 'in and 'out two pipes instead of a tty. its frames
; pour through one quay screen, the glass -- the console's own parser, so the bars, the
; borders, the cursor, the saver and the pictures come as they are -- and the rows the glass
; names dirty are dyed onto the window's paper, 8 by 16 a cell. the window's events go back up
; as a terminal's bytes: a key's text as it types it, the keys with no text and every key
; under ctrl or alt as xterm spells them, the pointer as the reports the glass was asked for.
; closing the window hangs up every pane's child, and the mitty ends with its last pane.
(module '(porthole porthole porthole-bytes porthole-mods)
(borrow 'window)
(borrow 'mitty)
(borrow 'wharf)                         ; the panes, to hang up at a close
(borrow 'mooring)
(borrow 'posix)
(:
 ; --- keys: a set-1 code -> what a terminal sends ------------------------------------
 ; the modifiers as held, each by its two keys: shift ctrl alt
 porthole-mods {42 'shift 54 'shift 29 'ctrl 285 'ctrl 56 'alt 312 'alt}
 ; the keys with no text, xterm's spelling; [lead final] where a modifier goes between
 special {28 "\r" 284 "\r" 14 "\x7f" 1 "\e"
          328 ["\e[" "A"] 336 ["\e[" "B"] 333 ["\e[" "C"] 331 ["\e[" "D"]
          327 ["\e[" "H"] 335 ["\e[" "F"]
          329 ["\e[5" "~"] 337 ["\e[6" "~"] 338 ["\e[2" "~"] 339 ["\e[3" "~"]
          59 ["\eO" "P"] 60 ["\eO" "Q"] 61 ["\eO" "R"] 62 ["\eO" "S"]
          63 ["\e[15" "~"] 64 ["\e[17" "~"] 65 ["\e[18" "~"] 66 ["\e[19" "~"] 67 ["\e[20" "~"]
          68 ["\e[21" "~"] 87 ["\e[23" "~"] 88 ["\e[24" "~"]}
 ; the keys ctrl and alt read by place, as on a us board: the letters, the digits, and the
 ; punctuation ctrl folds onto C0
 places {16 113 17 119 18 101 19 114 20 116 21 121 22 117 23 105 24 111 25 112
         30 97 31 115 32 100 33 102 34 103 35 104 36 106 37 107 38 108
         44 122 45 120 46 99 47 118 48 98 49 110 50 109
         2 49 3 50 4 51 5 52 6 53 7 54 8 55 9 56 10 57 11 48
         57 32 26 91 27 93 43 92 12 45 13 61 39 59 40 39 41 96 51 44 52 46 53 47}
 ; a key down with the modifiers held -> its bytes, or "" for one whose text says it
 (porthole-bytes k held)
  (: sh (held 'shift) ct (held 'ctrl) al (held 'alt)
     m (1 + (sh ? 1 0) + (al ? 2 0) + (ct ? 4 0))
     sp (peep special k ()) pl (peep places k ())
     (? (string? sp) ((al ? "\e" "") + sp)
        (two? sp) (? (m = 1) (sp 0 + sp 1)
                     (sp 0 = "\eO" || sp 0 = "\e[") ("\e[1;" + show m + sp 1)
                     (sp 0 + ";" + show m + sp 1))
        (k = 15) (sh ? "\e[Z" "\t")
        !(charm? pl) ""
        ct (: c (? (97 <= pl <= 122) (pl - 96) (pl = 32 || pl = 50) 0 (pl = 91) 27 (pl = 92) 28
                   (pl = 93) 29 (pl = 54) 30 (pl = 47 || pl = 45) 31 -1)
              (c < 0 ? "" ((al ? "\e" "") + string c)))
        al ("\e" + string (sh && 97 <= pl <= 122 ? (pl - 32) pl))
        ""))

 ; --- the pointer: X's buttons as the report's, and the cell under a pixel ---------
 xbtn {1 0 2 1 3 2 4 64 5 65 6 66 7 67}
 (mods held) ((held 'shift ? 4 0) + (held 'alt ? 8 0) + (held 'ctrl ? 16 0))

 ; --- the glass: the rows it names dirty (wet reads and clears), the cursor's row and the
 ;     one it left, dyed onto the paper and shown ---
 (wets sc) (: (bits d base i acc) (i < 32 ? (bits d base (i + 1) (d >> i & 1 ? ((base + i) . acc) acc)) acc)
              (go k acc) (k < 8 ? (go (k + 1) (bits (wet sc k) (32 * k) 0 acc)) acc)
              (go 0 ()))
 (paint win gx all last)
  (: sc (peep gx () 0) p (window-paper win) W <(window-size win)
     r (gaze sc 1) c (gaze sc 2)
     cur (gaze sc 3 & 1 ? (gaze sc 0) -1)
     v (gaze sc 8)
     rows (tablet 8)
     _ (each (all ? (jot r) (wets sc)) (y \ (y < r ? (pin rows y 1) 0)))
     _ (-1 < cur && cur // c + v < r ? (pin rows (cur // c + v) 1) 0)
     _ (-1 < last && last != cur && last // c + v < r ? (pin rows (last // c + v) 1) 0)
     ys (sort (keys rows))
     _ (each ys (y \ dye sc p W y cur ()))
     (run a b l) (? (two? l && <l = b + 1) (run a <l >l)
                    (window-show win (a * 16) ((b + 1) * 16), two? l ? (run <l <l >l) 0))
     (two? ys ? (run <ys <ys >ys) 0, cur))

 ; --- porthole: the mitty for the shell (argv in its first pane, when given) in a window
 ;     of 80 by 24 cells. answers 0, or 1 and why it could not ---
 (porthole as)
  (window-open 640 384 "mitty" @ win
   (? !(tablet? win) (say err ("mitty: no window (" + show win + ")\n"), flush err, 1)
      (: wh (window-size win) r (max 2 ((wh 1) // 16)) c (max 20 (<wh // 8))
         ki (pipe 0) fo (pipe 0)
         kin (fdopen <ki) kout (fdopen >ki)            ; the keys: we write, the mitty reads
         fin (fdopen <fo) fout (fdopen >fo)            ; the frames: the mitty writes, we read
         gx {(screen (cask (screen () r c)) r c)}
         dirty {1}
         _ (setenv "COLORTERM" "truecolor")           ; the glass paints every pen as it is said
         hb (mitty-lush as r c 0)
         (? !(tablet? hb) (say err ("mitty: " + hb + "\n"), flush err, window-close win, 1)
            (: _ (pins hb 'in kin 'out fout 'csize [r c])
               _ (hgreet hb)
               _ (window-typing win 1)                  ; a phone's keyboard up
               held {}
               (send s) (0 < #s ? (say kout s, flush kout) 0)
               ; the pointer, sent in the form the glass was asked for, a move once a cell
               (point how b x y) (: sc (peep gx () 0)
                                    row (max 0 (min (gaze sc 1 - 1) (y // 16))) col (max 0 (min (gaze sc 2 - 1) (x // 8)))
                                    at (row * 65536 + col)
                                    (how = 2 && at = peep held 'at -1 ? 0
                                       (: _ (pin held 'at at)
                                          bb (how = 2 ? (peep held 'btn 3) (peep xbtn b 3))
                                          (send (mouse sc (bb + mods held) row col how)))))
               (event e) (: k (e 1)
                            (? (<e = 'down) (: md (peep porthole-mods k ())
                                               (md ? (pin held md 1) (send (porthole-bytes k held))))
                               (<e = 'up) (peep porthole-mods k () @ md (md ? (pin held md ()) 0))
                               (<e = 'text) (held 'ctrl || held 'alt ? 0 (send k))
                               (<e = 'press) (: _ (pin held 'btn (peep xbtn k 3)) (point 0 k (e 2) (e 3)))
                               (<e = 'release) (: _ (pin held 'btn ()) (point 1 k (e 2) (e 3)))
                               (<e = 'move) (point 2 0 (e 1) (e 2))
                               (<e = 'size) (: r2 (max 2 ((e 2) // 16)) c2 (max 20 ((e 1) // 8)) sc (peep gx () 0)
                                               (pin gx () (regrid sc (cask (screen () r2 c2)) r2 c2),
                                                pin hb 'csize [r2 c2],
                                                pin dirty () 2))
                               (<e = 'close) (each (wharf-panes (hb 'plan)) (id \ (hpane hb id @ p (hpty? p ? (still (hpid p) 1) 0))))
                               0))
               up (twirl (_ \ oars hb 0) 0)
               pump (twirl (_ \ moor-to gx fin kout dirty) 0)
               ; the glass's turn: the window's events, then the paper where the glass changed
               (look last) (: _ (each (window-events win) event)
                              d (peep dirty () 0)
                              l2 (0 < d ? (pin dirty () 0, paint win gx (d = 2) last) last)
                              (peep held 'over () ? () (rest 8, look l2)))
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
) ; module porthole
