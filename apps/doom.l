; apps/doom.l -- doom on the host, in an X window: the driver over the X wire
; (apps/lux/wire.l) and the verb.
;
;   love doom [-iwad FILE] [-display :N] [-frames N]
;
; from a love with no doom in it, the verb lays this binary's source under ./love-<ver>/,
; fetches doomgeneric and the shareware IWAD there, builds DOOM=1 once and runs that binary
; (doom-nest below); from one built with DOOM=1 it is the window right away. on inle the
; game is in the kernel and runs whole on the console, or the machine lays the nest off
; its own tree, fetches the pair off the same hosts through the page's network, builds
; the module with the game inside and boots that (doom-nest-inle).
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
; silent game and HORN=/dev/snd/pcmC1D0p names a card (inle/horn.c).
; -frames N ends the game after N drawn frames: the gate's door, and nobody else's.
(module 'doom
(borrow 'xwire)
(borrow 'posix)
(:
   ; --- the display, as lux reads it: DISPLAY -> the unix socket, the cookie off
   ;     XAUTHORITY or ~/.Xauthority when the server wants one ---
   (dispof d) (#d < 2 ? "0" (:- (go 0) b (snip d 1 #d)
               (go i) (i = #b || b i = 46 ? (snip b 0 i) (go (i + 1)))))
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
       _ (:- (go 0) (go i) (i < nkc * kpc ?
          (: sym (x-r32 s) (i % kpc = 0 && pin km (mink + i // kpc) sym, go (i + 1)))))
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
   (keyof sym) (: k (doomkeys sym) (? (charm? k) k (32 < sym < 127) sym))

   ; --- the driver ---
   (drive s sc win gc wad frames)
    (: depth (scr-depth sc)
       km (keysyms s (scr-mink sc) (scr-maxk sc))
       dl (x-intern s "WM_DELETE_WINDOW")
       buf (cask 1024000)
       ; every event waiting on the wire, none waited for; 1 = the window is gone
       (events _) (? !(cue? s) 0
                     (: e (x-next s)
                        (? (one? e) 1
                         (: c (ev-code e)
                            gone (c @ (17 || 33 && u32 (ev-raw e) 12 = dl) 1)
                            _ (c = 2 || c = 3 ?
                                 (: k (keyof (peep km (ev-detail e) 0))
                                  (charm? k && doom-key k (c = 2))))
                            (gone ? 1 (events 0))))))
       (loop n) (? (events 0) n
                   (frames && n >= frames) n
                   (: drew (doom-tick ())                                     ; -1: the game quit itself
                      (? (drew < 0) n
                         (: _ (drew ? (doom-frame buf, x-putframe s win gc depth buf))
                            (loop (n + drew))))))
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
   ; the machine under a page fetches through the browser, and codeload answers no
   ; cross-origin fetch: there the tree is laid a file at a time off the raw host, its
   ; roster the api's listing (both answer any origin)
   dg-tree "https://api.github.com/repos/ozkl/doomgeneric/git/trees/master?recursive=1"
   dg-raw "https://raw.githubusercontent.com/ozkl/doomgeneric/master/"
   (note s) (say err (";; " + s + "\n"), flush err)
   ; spawn in dir, wait -> status. the cwd comes back only after the wait: on inle it is
   ; the machine's one cwd, and a task spawned there would be moved with it
   (run-in dir argv)
    (: here (cwd 0)
       _ (chdir dir)
       p (spawn argv)
       st (charm? p ? (wait p) 1)
       _ (chdir here)
       st)
   (grab url path)
    (? (two? (stat path)) 0
       (: rc (cite 'kore 'wget-main ["-q" "-O" path url])
          (rc @ 0 0 (unlink path, rc))))
   (fetch url path) (? (two? (stat path)) 0 (note ("fetching " + url), grab url path))
   ; the listing's blobs under doomgeneric/: the fields come in order, so each "path"
   ; is the text between the next two quotes and its kind sits before the next "path"
   (dg-blobs s)
    (: (upto p i c) (i < #p && p i != c ? (upto p (i + 1) c) i)
       (path p) (: a (upto p 0 34) b (upto p (a + 1) 34) (b < #p ? (snip p (a + 1) b) ""))
       (blob? p) (two? >(split "\"blob\"" p))
       (filter (q \ starts? q "doomgeneric/") (map path (filter blob? >(split "\"path\"" s)))))
   (dg-lay dl)
    (: d (dl + "/doomgeneric")
       ls (dl + "/tree.json")
       (? (two? (stat (d + "/doomgeneric"))) 0
          (fetch dg-tree ls) 1
          (: q (open ls "r")
             s (? (hot? q) (: s (slurp q) _ (close q) s) "")
             ps (dg-blobs s)
             _ (unlink ls)
             _ (mkdir d 493)
             _ (mkdir (d + "/doomgeneric") 493)
             _ (note ("laying " + show #ps + " files of doomgeneric off " + dg-raw))
             bad (tally (filter (p \ (grab (dg-raw + p) (d + "/" + p) != 0)) ps))
             (? (nil? ps) 1 bad 1 0))))
   (dg-tar dl)
    (: tgz (dl + "/doomgeneric.tgz")
       r (fetch dg-url tgz)
       (? (r != 0) r
          (two? (stat (dl + "/doomgeneric"))) 0
          (cite 'tarcmd 'tar-main ["xzf" tgz dl],
           (two? (stat (dl + "/doomgeneric-master")) ?
              (rename (dl + "/doomgeneric-master") (dl + "/doomgeneric")) 0),
           unlink (dl + "/pax_global_header"),              ; the tarball's pax row, laid as a file
           two? (stat (dl + "/doomgeneric")) ? 0 1)))
   ; the nest's IWAD rides the exec unless the caller named one: the nest's cwd is the caller's
   (nest-args dl as) (any (= "-iwad") as ? as ("-iwad" . dl + "/doom1.wad" . as))
   ; the nest is shared with seed and web, which link its love without doom: the flag the
   ; link wrote says which love stands there, so a plain one is relinked rather than run
   (nest-doom? nest)
    (: q (open (nest + "/out/.doom.flag") "r")
       (hot? q && (: s (slurp q) _ (close q) (string? s && s = "DOOM=1\n"))))
   ; the pair the DOOM=1 lane wants, fetched into DL once: 0 when both stand there. the
   ; tree comes as the tarball where a socket is ours, and file by file where the
   ; network is a page's fetch door (kore's wget rides the same door)
   (doom-fetch dl)
    (: _ (mkdir dl 493)
       r1 (fetch wad-url (dl + "/doom1.wad"))
       r2 (elem 'fetch (names ()) ? (dg-lay dl) (dg-tar dl))
       (r1 != 0 || r2 != 0 ? 1 0))
   (doom-aboard? dl) (two? (stat (dl + "/doom1.wad")) && two? (stat (dl + "/doomgeneric")))
   ; the three rungs both nests climb: source laid under here, downloads in dl, the build.
   ; answers the sentence to fail with, or () when the nest stands ready; arm runs before cook
   (nest-lay here nest dl arm cook)
    (: _ (cite 'source 'src-nest here)                    ; laid once, shared by every verb
       (? (one? (stat (nest + "/Makefile"))) ("the source did not lay under " + here)
          (doom-fetch dl) "the downloads did not land"
          (: _ (arm 0)
             st (run-in nest cook)
             (st != 0 ? "the doom build failed" ()))))
   (doom-nest as)
    (: exe (selfpath 0)
       here (cwd 0)
       nest (here + "/love-" + love-version)
       bin (nest + "/out/love")
       dl (nest + "/dl")
       (fail s) (say err ("doom: " + s + "\n"), 1)
       (enter _) (: e (setenv "LOVE_DOOM_NEST" "1",
                       exec (bin . "doom" . nest-args dl as))
                  (fail $ "cannot run " + bin + " (" + show e + ")"))
       (? !(string? exe) (fail "cannot find this binary's path")
          ((0 < #(getenv "LOVE_DOOM_NEST")) && two? (stat bin))
           (fail ("the nest's love carries no doom either: `cook host DOOM=1` under " + nest))
          (two? (stat bin) && nest-doom? nest) (enter 0)
          (: m (nest-lay here nest dl
                         (\ _ (cite 'source 'src-arm nest exe,            ; autonomous: ours throughout
                                note "building the nest's love with doom inside"))
                         [exe "cook" "host" "DOOM=1" ("LOVE=" + exe)])
             (string? m ? (fail m) (enter 0)))))

   (inle? _) (? (elem 'love-os (names ())) (elem (ev 'love-os) '(inle wasm)) 0)
   ; --- the nest on inle: the same lay, off this machine's own tree, with the page's
   ; fetch door as the network and no binary to exec -- cook runs as
   ; a task under the same registry, seed's way, and LOVE=love names this kernel as the
   ; toolchain. the module it lays cannot be run from here, so the machine boots it
   ; (kexec) in place of this one, and that one carries the game
   (doom-nest-inle _)
    (: here (cwd 0)
       nest ((here = "/" ? "" here) + "/love-" + love-version)     ; the page's shell sits at /
       dl (nest + "/dl")
       mod (nest + "/out/love.wasm")
       (fail s) (say err ("doom: " + s + "\n"), 1)
       (enter _) (: _ (note ("booting " + mod))
                    e ((ev 'kexec) mod "sh -c 'doom; sh'")
                    (fail ("cannot boot " + mod + " (" + show e + ")")))
       (? !(elem 'kexec (names ())) (fail "this machine cannot boot what it builds")
          (two? (stat mod) && nest-doom? nest) (enter 0)
          ; a task shares no environment with its spawner on this seat, so what cook is
          ; told goes on its line
          (: m (nest-lay here nest dl (\ _ (note "building this machine's love with doom inside"))
                         ["cook" "wasm" "DOOM=1" "LOVE=love" "LUSHFLAGS=-a" "LOVE_ARMED=1"])
             (? (string? m) (fail m)
                (one? (stat mod)) (fail ("the build left no module at " + mod))
                (enter 0)))))
   (digits s) (:- (go 0 0) n #s (go i a) (n <= i ? a
               (: c (s i) (47 < c < 58 ? (go (i + 1) (a * 10 + c - 48)) a))))
   doom-usage "usage: love doom [-iwad FILE] [-display :N] [-frames N]"
   (doom-main as)
    (: (opt a k d) (? (one? a) d (<a = k && two? >a) <>a (opt >a k d))
       nestwad (cwd 0 + "/love-" + love-version + "/dl/doom1.wad")
       wad (opt as "-iwad" (two? (stat "dl/doom1.wad") ? "dl/doom1.wad" nestwad))
       disp (opt as "-display" (getenv "DISPLAY"))
       frames (: f (opt as "-frames" ()) (string? f ? (digits f) 0))
       ; on inle the game is linked in or it is not: no window, no nest, and nothing to
       ; fetch with -- the WAD is a baked file and (doom ()) runs it whole
       (? (inle? 0) (? (elem 'doom (names ())) (doom ()) (doom-nest-inle 0))
          !(elem 'doom-start (names ())) (doom-nest as)
          (one? (stat wad)) (say err ("doom: no IWAD at " + wad + "\n"), 1)
          (: dn (dispof (string? disp ? disp ""))
             s (x-connect ("/tmp/.X11-unix/X" + dn))
             (? !(hot? s) (say err ("doom: no display :" + dn + "\n"), 1)
                (: sc (x-setup s (xauth-cookie (xauth 0) dn))
                   (one? sc ? (say err "doom: the display refused us\n", 1)
                      (: win (scr-idbase sc) gc (scr-idbase sc + 1)
                         n (x-create s win (scr-root sc) 640 400 (scr-depth sc) (scr-visual sc),
                            x-gc s gc win,
                            x-title s win "doom",
                            x-protocols s win (x-intern s "WM_DELETE_WINDOW"),
                            x-map s win,
                            x-flush s,
                            x-autorepeat s,
                            doom-start wad ? 0 (say err "doom: would not start\n", quit 1),
                            drive s sc win gc wad frames)
                         (puts ("doom: " + show n + " frames\n"),
                          0))))))))

   door (udoor 'doom doom-main doom-usage 1 1)
   _ (pins (cite 'verbs 'tab) 'doom door)
   s (cite 'verbs 'fire ["doom" "doom.l"])
   _ (two? s ? (quit (door >s)) 0))              ; a binding, so the module exports
) ; module doom
