; test/host/doomx.l -- doom on the host in a headless X window: `love doom -frames 300` on an
; Xvfb, an arrow held through xtest, the run held to exit 0 and its frame count. no Xvfb -> a
; polite skip. wants a doom=1 love and the iwad; a love without doom would take the verb's nest
; path, which no gate may start. run: cat test/00-init.l test/host/doomx.l | out/love
(: _ (elem 'doom-start (names ()) ? 0 (puts "doomx: FAIL -- this love carries no doom (build with DOOM=1)", putc 10, quit 1))
   xv (tether ["Xvfb" "-displayfd" "1" "-screen" "0" "800x600x24" "-nolisten" "tcp"])
   (wfx p) (gather p @ g2 (two? g2 ? g2 (rest 2, wfx p)))
   _ (!(two? xv) ? (puts "doomx: ok (no Xvfb, skipped)", quit 0) 0)
   (rdnum p) ((: (go n st) (see p @ c
                              (? (c = -1) ()
                                 (c = 13) (go n st)
                                 (c = 10) (st = 1 ? n (go 0 0))
                                 (48 <= c && c < 58)
                                  (st = 2 ? (go 0 2) (go (10 * n + (c - 48)) 1))
                                 (go 0 2))))
              0 0)
   dn (rdnum >xv)
   _ (test (charm? dn))
   ; the game: silent (HORN=none), 300 frames, then it says how many it drew
   ph (tether ["env" "HORN=none" ("DISPLAY=:" + show dn) "out/love" "doom" "-frames" "300"])
   ; while it runs, a held key through xtest on a wire of our own: a second and a half
   ; of the up arrow (keycode 111), which the server repeats -- the path src/apps/doom.l's
   ; detectable autorepeat covers -- then the release. what this proves is that
   ; the key path and the xkb requests leave the wire in step: the frames still count.
   _ (rest 2500)
   XW (cite 'xwire)
   s (XW 'x-connect ("/tmp/.X11-unix/X" + show dn))
   _ (test (hot? s))
   sc (XW 'x-setup s ())
   qx (: n 5 _ (XW 'x-w8 s 98, XW 'x-w8 s 0, XW 'x-w16 s 4, XW 'x-w16 s n, XW 'x-w16 s 0)
         _ (XW 'x-wpad s "XTEST", XW 'x-flush s)
         hdr (XW 'x-reply s) (hdr 9))
   (fake ty dt) (: w8 (XW 'x-w8) w16 (XW 'x-w16) w32 (XW 'x-w32)
                   (w8 s qx, w8 s 2, w16 s 9, w8 s ty, w8 s dt, w16 s 0,
                    w32 s 0, w32 s 0, w32 s 0, w32 s 0,
                    w16 s 0, w16 s 0, w32 s 0, w16 s 0, w8 s 0, w8 s 0,
                    XW 'x-flush s))
   _ (0 < qx ? (fake 2 111, rest 1500, fake 3 111, 0) 0)
   _ (close s)
   out (: (go acc) (see >ph @ c (c = -1 ? acc (go (acc + string c)))) (go ""))
   st (wfx <ph)
   _ (still <xv 15)
   _ (wfx <xv)
   ; the pty's tail: the count, then whatever line ending the terminal put after it
   (trimr s) (#s @ n (0 < n && elem (s (n - 1)) '(10 13) ? (trimr (snip s 0 (n - 1))) s))
   o (trimr out)
   (test ("doom: 300 frames" = snip o (#o - 16) #o),
    puts "doomx: ok"))
