; --- test/host/pier.l: the terminal in its own X window, headless ---
; spawns an Xvfb and runs `love pier` on it with a child that paints two red cells and
; reads a line. the window's pixels come back through GetImage: the red is there, laid by
; the console's own painter (dye). then `a` and Return go in through XTEST -- pier's key
; path to the pty -- and the child, having read `a`, paints two green cells a row down.
; a second Return scrolls both off the top, and shift+PgUp looks back through the history
; until the red is in the corner again; a plain key brings the view home. then the child
; asks for the mouse (?1000, ?1006), and a click at row 1, col 2 through XTEST reaches it
; as its press and release reports: it paints a blue cell in the corner. last it asks for
; bracketed paste, the test takes the primary selection, and a middle click has pier ask
; for it: "p\nq" arrives bracketed, the newline a return, and the child paints magenta.
; then it prints "hello world": a drag over hello selects it and pier takes the primary,
; which the test asks for and reads back; a double click on world takes the word.
; the child's exit takes pier with it, status 0. no Xvfb on the box -> a polite skip.
;   cat test/00-init.l test/host/pier.l | out/love
(: xv (tether ["Xvfb" "-displayfd" "1" "-screen" "0" "800x600x24" "-nolisten" "tcp"])
   (wfx p) (: g2 (gather p) (two? g2 ? g2 (rest 2, wfx p)))
   _ (? !(two? xv) (puts "pier: ok (no Xvfb, skipped)\n", quit 0) 0)
   (rdnum p) ((: (go n st) (: c (see p)
                              (? (c = -1) ()
                                 (c = 13) (go n st)
                                 (c = 10) (st = 1 ? n (go 0 0))
                                 ((48 <= c) && (c < 58))
                                  (st = 2 ? (go 0 2) (go ((10 * n) + (c - 48)) 1))
                                 (go 0 2))))
              0 0)
   dn (rdnum >xv)
   _ (test (charm? dn))
   kid "printf '\\033[41m  \\033[m'; read l; [ \"$l\" = a ] && printf '\\033[42m  \\033[m'; read l; i=0; while [ $i -lt 80 ]; do echo; i=$((i+1)); done; stty raw -echo; printf '\\033[?1000h\\033[?1006h'; r=$(dd bs=1 count=19 2>/dev/null); [ \"$r\" = \"$(printf 'a\\033[<0;3;2M\\033[<0;3;2m')\" ] && printf '\\033[H\\033[44m  \\033[m'; printf '\\033[?1000l\\033[?1006l\\033[?2004h'; r=$(dd bs=1 count=15 2>/dev/null); [ \"$r\" = \"$(printf '\\033[200~p\\rq\\033[201~')\" ] && printf '\\033[H\\033[45m  \\033[m'; printf '\\033[3;1Hhello world'; sleep 5"
   ph (tether ["out/love" "pier" "-display" (":" + show dn) "sh" "-c" kid])
   _ (rest 2500)
   XW (cite 'xwire)
   (w8 s v) ((XW 'x-w8) s v) (w16 s v) ((XW 'x-w16) s v) (w32 s v) ((XW 'x-w32) s v)
   s ((XW 'x-connect) ("/tmp/.X11-unix/X" + show dn))
   _ (test (hot? s))
   sc ((XW 'x-setup) s ())
   tree ((XW 'x-querytree) s ((XW 'scr-root) sc))
   _ (test (two? tree))
   kids <>tree                                         ; (1 windows): the children
   _ (test (two? kids))
   win (: (last l) (? (two? >l) (last >l) <l) (last kids))
   ; GetImage, ZPixmap: a 16x16 square of pier's window at (x,y), as (r g b) of its middle pixel
   (px x y) (: _ (w8 s 73) _ (w8 s 2) _ (w16 s 5) _ (w32 s win)
               _ (w16 s x) _ (w16 s y) _ (w16 s 16) _ (w16 s 16) _ (w32 s 4294967295)
               _ ((XW 'x-flush) s)
               hdr ((XW 'x-reply) s)
               n (((XW 'u32) hdr 4) * 4)
               bs ((XW 'x-rbytes) s n)
               at (((8 * 16) + 8) * 4)                   ; the middle, bgrx
               [(bs (at + 2)) (bs (at + 1)) (bs at)])
   _ (test ([128 0 0] = px 0 0))                       ; the red cells, xterm-256's 1
   ; XTEST: the key `a` (keycode 38) and Return (36), pressed and let go
   qx (: _ (w8 s 98) _ (w8 s 0) _ (w16 s 4) _ (w16 s 5) _ (w16 s 0)
         _ ((XW 'x-wpad) s "XTEST") _ ((XW 'x-flush) s)
         hdr ((XW 'x-reply) s) (hdr 9))
   (fake ty kc) (: _ (w8 s qx) _ (w8 s 2) _ (w16 s 9) _ (w8 s ty) _ (w8 s kc) _ (w16 s 0)
                   _ (w32 s 0) _ (w32 s 0) _ (w32 s 0) _ (w32 s 0)
                   _ (w16 s 0) _ (w16 s 0) _ (w32 s 0) _ (w16 s 0) _ (w8 s 0) _ (w8 s 0)
                   ((XW 'x-flush) s))
   _ (test (0 < qx))
   _ (fake 2 38) _ (fake 3 38) _ (fake 2 36) _ (fake 3 36)
   _ (rest 1500)
   _ (test ([0 128 0] = px 0 16))                      ; a row down: the green, the child read `a`
   _ (fake 2 36) _ (fake 3 36)                         ; Return: eighty lines scroll it all away
   _ (rest 1500)
   _ (test ([0 0 0] = px 0 0))
   (pgup n) (? (0 < n) (: _ (fake 2 50) _ (fake 2 112) _ (fake 3 112) _ (fake 3 50) (pgup (n - 1))) 0)
   _ (pgup 6)                                          ; shift+Prior, six times: past the top
   _ (rest 1000)
   _ (test ([128 0 0] = px 0 0))                       ; the history's first line, in the corner
   _ (fake 2 50) _ (fake 3 50) _ (fake 2 38) _ (fake 3 38)   ; shift alone says nothing; `a` goes home
   _ (rest 1000)
   _ (test ([0 0 0] = px 0 0))
   (fakeat ty d x y) (: _ (w8 s qx) _ (w8 s 2) _ (w16 s 9) _ (w8 s ty) _ (w8 s d) _ (w16 s 0)
                        _ (w32 s 0) _ (w32 s 0) _ (w32 s 0) _ (w32 s 0)
                        _ (w16 s x) _ (w16 s y) _ (w32 s 0) _ (w16 s 0) _ (w8 s 0) _ (w8 s 0)
                        ((XW 'x-flush) s))
   _ (fakeat 6 0 20 24) _ (fake 4 1) _ (fake 5 1)      ; to row 1, col 2, and a click
   _ (rest 1000)
   _ (test ([0 0 128] = px 0 0))                       ; the child read `a` and both reports
   ; the primary, held by a window of the test's: create it, own the selection, and answer
   ; the one SelectionRequest pier's middle click makes (in a task, so a silence can't hang)
   ow ((XW 'scr-idbase) sc)
   _ (: _ (w8 s 1) _ (w8 s 0) _ (w16 s 8) _ (w32 s ow) _ (w32 s ((XW 'scr-root) sc))
        _ (w16 s 0) _ (w16 s 0) _ (w16 s 1) _ (w16 s 1) _ (w16 s 0) _ (w16 s 2) _ (w32 s 0) _ (w32 s 0)
        _ (w8 s 22) _ (w8 s 0) _ (w16 s 4) _ (w32 s ow) _ (w32 s 1) _ (w32 s 0)
        ((XW 'x-flush) s))
   (owner _) (: e ((XW 'x-next) s)
              (? !(two? e) 0
                 !(((XW 'ev-code) e) = 30) (owner 0)
                 (: raw ((XW 'ev-raw) e) u32 (XW 'u32)
                    rq (u32 raw 12) sel (u32 raw 16) ty (u32 raw 20) pr (u32 raw 24)
                    _ (w8 s 18) _ (w8 s 0) _ (w16 s 7) _ (w32 s rq) _ (w32 s pr) _ (w32 s ty)
                    _ (w8 s 8) _ (w8 s 0) _ (w16 s 0) _ (w32 s 3) _ ((XW 'x-wpad) s "p\nq")
                    _ (w8 s 25) _ (w8 s 0) _ (w16 s 11) _ (w32 s rq) _ (w32 s 0)
                    _ (w8 s 31) _ (w8 s 0) _ (w16 s 0) _ (w32 s 0) _ (w32 s rq) _ (w32 s sel)
                    _ (w32 s ty) _ (w32 s pr) _ (w32 s 0) _ (w32 s 0)
                    ((XW 'x-flush) s))))
   ot (twirl (\ _ (owner 0)) 0)
   _ (fake 4 2) _ (fake 5 2)                           ; the middle button: paste
   _ (rest 1500)
   _ (? (landed? ot) 0 (freeze ot))
   _ (test ([128 0 128] = px 0 0))                     ; the child read the paste, bracketed
   ; the primary as the test's window reads it: ConvertSelection, then the property
   ut ((XW 'x-intern) s "UTF8_STRING") tp ((XW 'x-intern) s "TSEL")
   (ask _) (: _ (w8 s 24) _ (w8 s 0) _ (w16 s 6) _ (w32 s ow) _ (w32 s 1) _ (w32 s ut) _ (w32 s tp) _ (w32 s 0)
              _ ((XW 'x-flush) s)
              (wait _) (: e ((XW 'x-next) s)
                          (? !(two? e) ""
                             (((XW 'ev-code) e) = 31) (string (((XW 'x-getprop) s ow tp) 2))
                             (wait 0)))
              (wait 0))
   (primary _) (: got {} t (twirl (\ _ (pin got () (ask 0))) 0)
                  _ (rest 1000)
                  _ (? (landed? t) 0 (freeze t))
                  (peep got () ""))
   _ (fakeat 6 0 4 40) _ (fake 4 1) _ (fakeat 6 0 36 40) _ (fake 5 1)   ; a drag across hello, row 2
   _ (rest 500)
   _ (test ("hello" = primary 0))
   _ (fakeat 6 0 60 40) _ (fake 4 1) _ (fake 5 1) _ (fake 4 1) _ (fake 5 1)   ; a double click on world
   _ (rest 500)
   _ (test ("world" = primary 0))
   _ (close s)
   st (wfx <ph)
   _ (test (two? st) (0 = <st))                        ; the child's exit took pier with it
   _ (still <xv 15)
   _ (wfx <xv)
   _ (test_fin ())
   (puts "pier: ok\n"))
