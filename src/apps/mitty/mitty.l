; mitty -- the terminal: a program on a pty, its bytes through a quay screen, dyed onto a window
; (src/apps/window.l: x, inle or a phone). 8 by 16 a cell; events go up as a terminal's bytes,
; xterm's spelling. the pointer is the window's own (selection) where the screen asked for none,
; or under shift. pier.l puts its panes in a window through mw-face.
(module '(mitty mitty-main mitty-keybytes mw-face mw-font mw-args)
(borrow 'mooring)                       ; hopen moor-to waitfor
(borrow '(posix bytes window font cli))
(:
 ; --- keys: a set-1 code -> what a terminal sends ------------------------------------
 ; the modifiers as held, each by its two keys: shift ctrl alt
 mw-modkeys {42 'shift 54 'shift 29 'ctrl 285 'ctrl 56 'alt 312 'alt}
 ; the keys with no text, xterm's spelling; [lead final] where a modifier goes between
 mw-special {28 "\r" 284 "\r" 14 "\x7f" 1 "\e"
             328 ["\e[" "A"] 336 ["\e[" "B"] 333 ["\e[" "C"] 331 ["\e[" "D"]
             327 ["\e[" "H"] 335 ["\e[" "F"]
             329 ["\e[5" "~"] 337 ["\e[6" "~"] 338 ["\e[2" "~"] 339 ["\e[3" "~"]
             59 ["\eO" "P"] 60 ["\eO" "Q"] 61 ["\eO" "R"] 62 ["\eO" "S"]
             63 ["\e[15" "~"] 64 ["\e[17" "~"] 65 ["\e[18" "~"] 66 ["\e[19" "~"] 67 ["\e[20" "~"]
             68 ["\e[21" "~"] 87 ["\e[23" "~"] 88 ["\e[24" "~"]}
 ; the keys ctrl and alt read by place, as on a us board: the letters, the digits, and the
 ; punctuation ctrl folds onto C0
 mw-places {16 113 17 119 18 101 19 114 20 116 21 121 22 117 23 105 24 111 25 112
            30 97 31 115 32 100 33 102 34 103 35 104 36 106 37 107 38 108
            44 122 45 120 46 99 47 118 48 98 49 110 50 109
            2 49 3 50 4 51 5 52 6 53 7 54 8 55 9 56 10 57 11 48
            57 32 26 91 27 93 43 92 12 45 13 61 39 59 40 39 41 96 51 44 52 46 53 47}
 ; a key down with the modifiers held -> its bytes, or "" for one whose text says it
 (mitty-keybytes k held)
  (: sh (held 'shift) ct (held 'ctrl) al (held 'alt)
     m (1 + (sh ? 1 0) + (al ? 2 0) + (ct ? 4 0))
     sp (peep mw-special k ()) pl (peep mw-places k ())
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
 mw-xbtn {1 0 2 1 3 2 4 64 5 65 6 66 7 67}
 (mw-mods held) ((held 'shift ? 4 0) + (held 'alt ? 8 0) + (held 'ctrl ? 16 0))

 ; --- the selection on the glass: a press anchors (a double or triple, the word or line), a
 ;     drag stretches, a release takes the primary; a right press moves the nearer end ---
 (mw-choose win sc held how b gi)
  (: s0 (gaze sc 10) s1 (gaze sc 11)
     (? (how = 0 && b = 2 && s0 < s1)
        ((? (gi < s0) (s1 - 1) (s1 <= gi) s0 (gi - s0 < s1 - gi) (s1 - 1) s0) @ a
           (pins held 'anchor a 'drag 1, select sc a gi (peep held 'unit 0)))
        (how = 0 && b = 0)
        (: t (clock 0)
           n (t - peep held 'tp 0 < 400 && gi = peep held 'anchor () ? (min 3 (peep held 'clicks 0 + 1)) 1)
           (pins held 'tp t 'anchor gi 'clicks n 'unit (n - 1) 'drag 1,
            select sc gi gi (1 < n ? (n - 1) -1)))
        (how = 0 && b = 1) (window-ask win 'primary)
        !(peep held 'drag 0) 0
        (how = 2) (select sc (peep held 'anchor gi) gi (peep held 'unit 0))
        (pin held 'drag 0,
         s0 < s1 ? (window-own win 'primary (copied sc s0 s1)) 0)))

 ; --- the glass: the rows it names dirty (wet reads and clears), the cursor's row and the
 ;     one it left, dyed onto the paper and shown ---
 (mw-paint win gx font all last)
  (: sc (peep gx () 0) p (window-paper win) W <(window-size win)
     r (gaze sc 1) c (gaze sc 2)
     cur (gaze sc 3 & 1 ? (gaze sc 0) -1)
     v (gaze sc 8)
     rows (tablet 8)
     _ (each (all ? (jot r) (window-wets sc)) (y \ (y < r ? (pin rows y 1) 0)))
     _ (-1 < cur && cur // c + v < r ? (pin rows (cur // c + v) 1) 0)
     _ (-1 < last && last != cur && last // c + v < r ? (pin rows (last // c + v) 1) 0)
     ys (sort (keys rows))
     _ (each ys (y \ dye sc p W y cur font))
     (run a b l) (? (two? l && <l = b + 1) (run a <l >l)
                    (window-show win (a * 16) ((b + 1) * 16), two? l ? (run <l <l >l) 0))
     (two? ys ? (run <ys <ys >ys) 0, cur))

 ; --- a window's face over the screen in box gx: its events, the pointer, the selection, and the
 ;     paper where the screen changed. held keeps the keys and the press. o is what it faces: 'send
 ;     bytes for the program; 'wants r c b whether it takes a press; 'size r c a new grid; 'paste
 ;     text; 'close; 'key k, 1 for a key of its own; 'turn each turn. answers the loop to twirl ---
 (mw-face win gx font held dirty o)
  (: send (o 'send)
     (soil _) (pin dirty () (max 1 (peep dirty () 0)))
     ; the pointer, sent in the form the glass was asked for, a move once a cell;
     ; the window's own where the program wants no press, or under shift. a press
     ; decides for its drag and release
     (point how b x y) (: sc (peep gx () 0)
                          row (max 0 (min (gaze sc 1 - 1) (y // 16))) col (max 0 (min (gaze sc 2 - 1) (x // 8)))
                          at (row * 65536 + col)
                          bb (how = 2 ? (peep held 'btn 3) (peep mw-xbtn b 3))
                          mine (? (how != 0 && charm? (peep held 'btn ())) (peep held 'mine 0)
                                  (held 'shift || !(gaze sc 3 & 7680) || !(o 'wants row col bb)) 1
                                  0)
                          _ (how = 0 ? (pin held 'mine mine) 0)
                          (how = 2 && at = peep held 'at -1 ? 0
                             (: _ (pin held 'at at)
                                (? (mine && bb < 3)
                                    (mw-choose win sc held how bb ((row - gaze sc 8) * gaze sc 2 + col), soil 0)
                                   mine 0
                                   (send (mouse sc (bb + mw-mods held) row col how))))))
     ; the keys the window keeps: ctrl+shift+C and V, shift+Insert
     (ours k) (? (held 'ctrl && held 'shift && k = 46)
                   (peep gx () 0 @ sc (gaze sc 10 < gaze sc 11 ? (window-own win 'clipboard (copied sc (gaze sc 10) (gaze sc 11))) 0), 1)
                 (held 'ctrl && held 'shift && k = 47) (window-ask win 'clipboard, 1)
                 (held 'shift && !(held 'ctrl) && k = 338) (window-ask win 'primary, 1)
                 0)
     (event e) (: k (e 1)
                  (? (<e = 'down) (: md (peep mw-modkeys k ())
                                     (? md (pin held md 1) (ours k) 0 ((peep o 'key (_ \ 0)) k) 0 (send (mitty-keybytes k held))))
                     (<e = 'up) (peep mw-modkeys k () @ md (md ? (pin held md ()) 0))
                     (<e = 'text) (held 'ctrl || held 'alt ? 0 (send k))
                     (<e = 'press) (: _ (pin held 'btn (peep mw-xbtn k 3)) (point 0 k (e 2) (e 3)))
                     (<e = 'release) (: v (point 1 k (e 2) (e 3)) _ (pin held 'btn ()) v)
                     (<e = 'move) (point 2 0 (e 1) (e 2))
                     (<e = 'size) (: r2 (max 2 ((e 2) // 16)) c2 (max 20 ((e 1) // 8)) sc (peep gx () 0)
                                     (pin gx () (regrid sc (cask (regrid sc () r2 c2)) r2 c2),
                                      o 'size r2 c2,
                                      pin dirty () 2))
                     (<e = 'paste) (o 'paste k)
                     (<e = 'lost) (k = 'primary ? (pin held 'sel (), select (peep gx () 0) 0 0 -1, soil 0) 0)
                     (<e = 'close) (o 'close ())
                     0))
     (look last) (: _ (each (window-events win) event)
                    _ (o 'turn ())
                    d (peep dirty () 0)
                    l2 (0 < d ? (pin dirty () 0, mw-paint win gx font (d = 2) last) last)
                    (peep held 'over () ? () (rest 8, look l2)))
     look)

 ; -f FONT.hex, leading a window's words: the font, and the words past it
 (mw-font as) (? (two? as && <as = "-f" && two? >as) (uread <>as @ t (two? t ? (font-hex <>t))))
 (mw-args as) (? (two? as && <as = "-f") (two? >as ? >>as ()) as)
 ; --- the terminal: a program in a window, the shell when none; it ends with the program.
 ;     answers 0, or 1 and why it could not. a program asks a phone's keyboard away by ?7727 ---
 (mitty-main as0)
  (: font (mw-font as0) as (mw-args as0)
  (window-open 640 384 "mitty" @ win
   (? !(tablet? win) (say err ("mitty: no window (" + show win + ")\n"), flush err, 1)
      (: wh (window-size win) r (max 2 ((wh 1) // 16)) c (max 20 (<wh // 8))
         me (selfpath 0)
         _ (setenv "COLORTERM" "truecolor")
         _ (setenv "MITTY" "1")                       ; its pictures take
         p (hopen (two? as ? as (string? me ? [me "lush"] ["sh"])) r c)
         (? (atom? p) (say err ("mitty: cannot start: " + show p + "\n"), flush err, window-close win, 1)
            (: gx (hbox p) m (hmas p) dirty {1} held {'typing 1}
               _ (window-typing win 1)
               (send s) (0 < #s ? (peer (peep gx () 0) 0, say m s, flush m) 0)
               ; shift with pgup and pgdn look back, half a screen at a time
               (key k) (: sc (peep gx () 0) n (gaze sc 1 // 2)
                          (? !(held 'shift) 0
                             (k = 329) (peer sc (gaze sc 8 + n), pin dirty () 2, 1)
                             (k = 337) (peer sc (max 0 (gaze sc 8 - n)), pin dirty () 2, 1)
                             0))
               ; the clipboard and the keyboard, as the program last said
               (turn _) (: sc (peep gx () 0) want (gaze sc 13 ? 0 1)
                           (clipped sc @ (pc + ";" + d) (d = "" || d = "?" ? 0 (window-own win 'clipboard (b64d d))) _ 0,
                            want = held 'typing ? 0 (pin held 'typing want, window-typing win want)))
               look (mw-face win gx font held dirty
                     {'send send 'key key 'wants (r \ c \ b \ 1) 'size (r \ c \ settty m r c)
                      'paste (t \ 0 < #t ? (send (pasted (peep gx () 0) t)) 0)
                      'close (_ \ still (hpid p) 1) 'turn turn})
               face (twirl (_ \ look -1) 0)
               (moor-to gx m m dirty,
                waitfor (hpid p),
                pin held 'over 1,
                landed? face ? (catch face) (freeze face),
                close m,
                window-close win,
                0)))))))

 mitty-usage "usage: love mitty [-f FONT.hex] [COMMAND ..]   COMMAND, or the shell, in a window of its own;
  shift+pgup and pgdn look back, ctrl+shift+C and V copy and paste, a drag selects. panes: love pier"
 _ (pins (cite 'verbs 'tab) 'mitty (udoor 'mitty mitty-main mitty-usage 1 1)))
) ; module mitty
