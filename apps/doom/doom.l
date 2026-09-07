; apps/doom/doom.l -- doom on the host, in an X window: the driver over the X wire
; (apps/lux/wire.l) and the verb.
;
;   love doom [-iwad FILE] [-display :N] [-frames N]
;
; from a love with no doom in it, the verb lays this binary's source under ./love-<ver>/,
; fetches doomgeneric and the shareware IWAD there, builds DOOM=1 once and runs that binary
; (doom-nest below); from one built with DOOM=1 it is the window right away.
;
; the game is C, linked into this binary by the DOOM=1 lane (inle/doom.c's host
; doors: doom-start / doom-tick / doom-frame / doom-key); this file is the window.
; one 640x400 InputOutput window at the root's depth, the frame pushed as four
; PutImage bands (a band is 100 rows: 256000 bytes, under the 65535-word request
; ceiling with no BIG-REQUESTS to negotiate), the keyboard read as KeyPress/
; KeyRelease and respelled from keysyms to doomkeys.h's codes, with XKB's detectable
; autorepeat on so a held key is not a release every 40 ms. the socket is polled
; between frames (cue?), never waited on: doom's own tick keeps the clock.
; sound rides the horn's C face inside the mixer, so `HORN=none love doom` is a
; silent game and HORN=/dev/snd/pcmC1D0p names a card (host/horn.c).
; -frames N ends the game after N drawn frames: the gate's door, and nobody else's.
(module 'doom
(use 'xwire)
(:
   ; --- the display, as lux reads it: DISPLAY -> the unix socket, the cookie off
   ;     XAUTHORITY or ~/.Xauthority when the server wants one ---
   (dispof d) (? (#d < 2) "0"
                 (: b (snip d 1 #d)
                    (: (go i) ((i = tally b) || (b i = 46) ? (snip b 0 i) (go (i + 1)))
                       (go 0))))
   (xauth u) (: v (getenv "XAUTHORITY") (0 < tally v ? v (getenv "HOME" + "/.Xauthority")))

   ; --- the requests the wire does not carry: a window of ours, a GC, a title,
   ;     the delete protocol, and PutImage ---
   (x-create s win parent w h depth visual)                                    ; CreateWindow, event-mask: keys + structure
    (x-w8 s 1, x-w8 s depth, x-w16 s 9, x-w32 s win, x-w32 s parent,
     x-w16 s 0, x-w16 s 0, x-w16 s w, x-w16 s h, x-w16 s 0, x-w16 s 1,
     x-w32 s visual, x-w32 s 2048, x-w32 s 131075)                            ; KeyPress|KeyRelease|StructureNotify
   (x-gc s gc win) (x-w8 s 55, x-w8 s 0, x-w16 s 4, x-w32 s gc, x-w32 s win, x-w32 s 0)
   (x-title s win t)                                                           ; ChangeProperty WM_NAME STRING
    (: n #t
       (x-w8 s 18, x-w8 s 0, x-w16 s (6 + (n + x-pad4 n) // 4), x-w32 s win,
        x-w32 s 39, x-w32 s 31, x-w8 s 8, x-w8 s 0, x-w16 s 0, x-w32 s n, x-wpad s t))
   (x-protocols s win dl)                                                      ; WM_PROTOCOLS = [WM_DELETE_WINDOW]
    (: pr (x-intern s "WM_PROTOCOLS")
       (x-w8 s 18, x-w8 s 0, x-w16 s 7, x-w32 s win, x-w32 s pr, x-w32 s 4,
        x-w8 s 32, x-w8 s 0, x-w16 s 0, x-w32 s 1, x-w32 s dl))
   ; a held key, by default, is a release and a press every 40 ms after the server's delay,
   ; and doom reads every one of those releases as the key going up: the player stops
   ; walking after half a second. XKB's detectable autorepeat turns a held key into
   ; presses only. QueryExtension for the opcode, XkbUseExtension, then PerClientFlags
   ; (UseCoreKbd, change and value both the DetectableAutoRepeat bit). a server without
   ; XKB answers no opcode, and the keys stay as they were.
   (x-autorepeat s)
    (: n #"XKEYBOARD"
       _ (x-w8 s 98, x-w8 s 0, x-w16 s (2 + ((n + x-pad4 n) // 4)), x-w16 s n, x-w16 s 0, x-wpad s "XKEYBOARD", x-flush s)
       hdr (x-reply s)
       op (<hdr = 1 ? (hdr 9) 0)
       (? (op < 1) 0
          (: _ (x-w8 s op, x-w8 s 0, x-w16 s 2, x-w16 s 1, x-w16 s 0, x-flush s)
             _ (x-reply s)
             _ (x-w8 s op, x-w8 s 21, x-w16 s 7, x-w16 s 256, x-w16 s 0, x-w32 s 1, x-w32 s 1, x-w32 s 0, x-w32 s 0, x-w32 s 0, x-flush s)
             _ (x-reply s)
             1)))
   ; one band of rows out of the frame cask: ZPixmap at the window's depth, 32 bpp
   (x-putband s win gc depth buf y rows)
    (: n (rows * 2560)
       _ (x-w8 s 72, x-w8 s 2, x-w16 s (6 + n // 4), x-w32 s win, x-w32 s gc,
          x-w16 s 640, x-w16 s rows, x-w16 s 0, x-w16 s y, x-w8 s 0, x-w8 s depth, x-w16 s 0)
       (say s (snip buf (y * 2560) (y * 2560 + n))))
   (x-putframe s win gc depth buf)
    (x-putband s win gc depth buf 0 100, x-putband s win gc depth buf 100 100,
     x-putband s win gc depth buf 200 100, x-putband s win gc depth buf 300 100, x-flush s)

   ; --- the keyboard: keycode -> its first keysym, the whole table once ---
   (keysyms s mink maxk)
    (: nkc (1 + (maxk - mink))
       _ (x-w8 s 101, x-w8 s 0, x-w16 s 2, x-w8 s mink, x-w8 s nkc, x-w16 s 0, x-flush s)
       hdr (x-reply s)
       kpc (<hdr = 1 ? (hdr 1) 0)
       km (tablet 8)
       _ (: (go i) (i < nkc * kpc ?
                    (: sym (x-r32 s)
                       _ (? (i % kpc = 0) (pin km (mink + (i // kpc)) sym) 0)
                       (go (i + 1))))
            (go 0))
       km)
   ; a keysym -> doomkeys.h's code, () for one doom has no name for. letters arrive
   ; lower-case (the unshifted column), which is what doom's menus want.
   doomkeys {65361 172 65362 173 65363 174 65364 175                              ; arrows
             65307 27 65293 13 65289 9 65288 127 65299 255                       ; esc enter tab backspace pause
             65505 182 65506 182 65507 163 65508 163 65513 184 65514 184          ; shifts fire alts
             65509 186 65407 197 65300 198 65377 217                              ; caps num scroll prtscr
             65360 199 65367 207 65365 201 65366 209 65379 210 65535 211          ; home end pgup pgdn ins del
             65470 187 65471 188 65472 189 65473 190 65474 191                    ; f1..f5
             65475 192 65476 193 65477 194 65478 195 65479 196 65480 215 65481 216 ; f6..f12
             32 162}                                                              ; space: use
   (keyof sym) (: k (peep doomkeys sym ())
                  (? (charm? k) k ((32 < sym) && (sym < 127)) sym ()))

   ; --- the driver ---
   (drive s sc win gc wad frames)
    (: depth (scr-depth sc)
       km (keysyms s (scr-mink sc) (scr-maxk sc))
       dl (x-intern s "WM_DELETE_WINDOW")
       buf (cask 1024000)
       ; every event waiting on the wire, none waited for; 1 = the window is gone
       (events _) (? !(cue? s) 0
                     (: e (x-next s)
                        (? !(two? e) 1
                           (: c (ev-code e)
                              gone (? (c = 17) 1                                          ; DestroyNotify
                                      ((c = 33) && ((u32 (ev-raw e) 12) = dl)) 1         ; the close button
                                      0)
                              _ (? ((c = 2) || (c = 3))
                                   (: k (keyof (peep km (ev-detail e) 0))
                                      (charm? k ? (doom-key k (c = 2)) 0))
                                   0)
                              (gone ? 1 (events 0))))))
       (loop n) (? (events 0) n
                   (frames && (n >= frames)) n
                   (: drew (doom-tick ())
                      _ (? drew (: _ (doom-frame buf) (x-putframe s win gc depth buf)) 0)
                      (loop (n + drew))))
       (loop 0))

   ; --- the nest: a love with doom in it, laid in ./love-<ver>/ off this binary's source --
   ; `love doom` from a binary that carries no doom lays this binary's source under
   ; ./love-<ver>/ (the source verb's lay: files, no build), fetches doomgeneric and the
   ; shareware IWAD into its dl/ with wget, builds `cook host DOOM=1 LOVE=<this binary>`
   ; there ONCE -- the artifact is the toolchain: its egg lane stands in for love0, its own
   ; mooncc compiles every object, and no bootstrap love is built -- and execs that binary's
   ; doom. the nest is kept, so the next `love doom` is one exec. nothing outside the
   ; current directory is written.
   wad-url "https://raw.githubusercontent.com/Daivuk/PureDOOM/master/doom1.wad"
   dg-url "https://codeload.github.com/ozkl/doomgeneric/tar.gz/refs/heads/master"
   (note s) (say err (";; " + s + "\n"), flush err)
   (run-in dir argv)                                                          ; spawn in dir, wait -> status
    (: here (cwd 0)
       _ (chdir dir)
       p (spawn argv)
       _ (chdir here)
       (charm? p ? (wait p) 1))
   (fetch url path)
    (? (two? (stat path)) 0
       (: _ (note ("fetching " + url))
          rc ((from 'kore 'wget-main) ["-q" "-O" path url])
          (? (rc = 0) 0 (: _ (unlink path) rc))))
   ; the nest's IWAD rides the exec unless the caller named one: the nest's cwd is the caller's
   (nest-args dl as) (? (any (\ a (a = "-iwad")) as) as ("-iwad" . ((dl + "/doom1.wad") . as)))
   (doom-nest as)
    (: exe (selfpath 0)
       here (cwd 0)
       nest (here + "/love-" + love-version)
       bin (nest + "/out/love")
       dl (nest + "/dl")
       (fail s) (say err ("doom: " + s + "\n"), 1)
       (? !(string? exe) (fail "cannot find this binary's path")
          ((0 < tally (getenv "LOVE_DOOM_NEST")) && (two? (stat bin)))
           (fail ("the nest's love carries no doom either: `cook host DOOM=1` under " + nest))
          (two? (stat bin))
           (: _ (setenv "LOVE_DOOM_NEST" "1")
              e (exec (bin . ("doom" . (nest-args dl as))))
              (fail ("cannot run " + bin + " (" + show e + ")")))
          (: _ (? (two? (stat (nest + "/Makefile"))) 0
                  (: _ (note ("laying this love's source under " + nest))
                     _ (run-in here [exe "source" here])                    ; the verb: its names are its own
                     0))
             (? !(two? (stat (nest + "/Makefile"))) (fail ("the source did not lay under " + here))
                (: _ (mkdir dl 493)
                   r1 (fetch wad-url (dl + "/doom1.wad"))
                   r2 (? (two? (stat (dl + "/doomgeneric"))) 0
                         (: r (fetch dg-url (dl + "/doomgeneric.tgz"))
                            (? !(r = 0) r
                               (: _ ((from 'tarcmd 'tar-main) ["xzf" (dl + "/doomgeneric.tgz") dl])
                                  _ (rename (dl + "/doomgeneric-master") (dl + "/doomgeneric"))
                                  _ (unlink (dl + "/doomgeneric.tgz"))
                                  _ (unlink (dl + "/pax_global_header"))              ; the tarball's pax row, laid as a file
                                  (two? (stat (dl + "/doomgeneric")) ? 0 1)))))
                   (? (!(r1 = 0) || !(r2 = 0)) (fail "the downloads did not land")
                      (: _ ((from 'source 'src-arm) nest exe)                     ; autonomous: ours throughout
                         _ (note "building the nest's love with doom inside -- this binary is the toolchain")
                         st2 (run-in nest [exe "cook" "host" "DOOM=1" ("LOVE=" + exe)])
                         (? !(st2 = 0) (fail "the doom build failed")
                            (: _ (setenv "LOVE_DOOM_NEST" "1")
                               e (exec (bin . ("doom" . (nest-args dl as))))
                               (fail ("cannot run " + bin + " (" + show e + ")")))))))))))

   (digits s) (: n #s
                 (go i a) (? (n <= i) a
                             (: c (s i) (? ((47 < c) && (c < 58)) (go (i + 1) ((a * 10) + (c - 48))) a)))
                 (go 0 0))
   (doom-usage _) (say err "usage: love doom [-iwad FILE] [-display :N] [-frames N]\n", 1)
   (doom-main as)
    (: (opt a k d) (? !(two? a) d ((<a = k) && (two? >a)) <>a (opt >a k d))
       nestwad (cwd 0 + "/love-" + love-version + "/dl/doom1.wad")
       wad (opt as "-iwad" (? (two? (stat "dl/doom1.wad")) "dl/doom1.wad" nestwad))
       disp (opt as "-display" (getenv "DISPLAY"))
       frames (: f (opt as "-frames" ()) (string? f ? (digits f) 0))
       (? (any (\ a (a = "-h" || a = "--help")) as) (doom-usage 0)
          !(member? 'doom-start (names ())) (doom-nest as)
          !(two? (stat wad)) (say err ("doom: no IWAD at " + wad + "\n"), 1)
          (: dn (dispof (string? disp ? disp ""))
             s (x-connect ("/tmp/.X11-unix/X" + dn))
             (? !(hot? s) (say err ("doom: no display :" + dn + "\n"), 1)
                (: sc (x-setup s (xauth-cookie (xauth 0) dn))
                   (? !(two? sc) (say err "doom: the display refused us\n", 1)
                      (: win (scr-idbase sc) gc (scr-idbase sc + 1)
                         _ (x-create s win (scr-root sc) 640 400 (scr-depth sc) (scr-visual sc))
                         _ (x-gc s gc win)
                         _ (x-title s win "doom")
                         _ (x-protocols s win (x-intern s "WM_DELETE_WINDOW"))
                         _ (x-map s win)
                         _ (x-flush s)
                         _ (x-autorepeat s)
                         _ (? (doom-start wad) 0 (say err "doom: would not start\n", quit 1))
                         n (drive s sc win gc wad frames)
                         _ (puts ("doom: " + show n + " frames\n"))
                         0)))))))

   _ (pins (from 'verbs 'tab) 'doom doom-main)
   s (from 'verbs 'fire ["doom" "doom.l"])
   (two? s ? (quit (doom-main >s))))
) ; module doom
