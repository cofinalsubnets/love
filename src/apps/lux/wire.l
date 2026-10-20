; src/apps/lux/wire.l -- the x11 wire protocol: handshake, requests, keyboard, events.
; host-only (unix connect). every op takes the socket `s` explicitly, and the byte
; writers call the real put/get nifs.
;
; (x-setup s) -> [root wpx hpx minkc maxkc idbase cmap vis depth]
; (x-next s) -> [code detail window state raw]; () at eof
(module '(xwire
  x-w8 x-w16 x-w32 x-flush x-r8 x-r16 x-r32 x-skip
  x-rstr x-pad4 x-wname x-rbytes u16 u32 evq x-reply
  x-connect x-wpad x-setup scr-root scr-w scr-h scr-mink scr-maxk
  scr-idbase scr-cmap scr-visual scr-depth x-cwa-events x-configure x-map x-unmap
  x-focus x-sync x-clear-enters x-border x-intern x-getprop x-atoms-of x-getprop-atoms x-has-atom x-getclass
  x-transient x-getgeom x-raise x-lower x-kill x-wmdel x-confnotify x-delprop
  x-grabbtn x-replay x-allow-async x-grabptr x-ungrabptr x-querytree x-attrs x-manageable?
  x-redirect x-keymap x-grab x-ungrabkeys x-color x-borderpix x-bgpix x-clear x-cursor xauth-parse
  xauth-cookie x-decode x-next ev-code ev-detail ev-window ev-state ev-raw
  i16 x-queryext x-randr-init x-monitors x-warp x-queryptr
  x-dispnum x-authfile x-open x-window x-gc x-title x-protocols x-autorepeat x-putrows x-keysyms
  x-sym x-text x-set1 x-events)
(borrow 'posix)
(borrow 'bytes)
(:
   ; --- byte IO over the socket (little-endian) ---
   (x-w8 s v)  (put s v)
   (x-w16 s v) (put s (255 & v), put s (255 & v >> 8))
   (x-w32 s v) (x-w16 s (65535 & v), x-w16 s (65535 & v >> 16))
   x-flush flush
   x-r8 see
   (x-r16 s) (: a (see s) b (see s) (a | b << 8))
   (x-r32 s) (: a (x-r16 s) b (x-r16 s) (a | b << 16))
   (x-skip s n) (each ^n (i \ see s))
   (x-rstr s n) (jug 0 @ j (each ^n (i \ say j (string (see s))), slurp j))
   (x-pad4 n) (padk n 4)
   (x-wname s t) (each ^#t (i \ put s (t i)))
   (x-rbytes s n) (map (i \ see s) ^n)
   (u16 l off) (rdle l off 2)                                          ; little-endian reads from a byte list
   (u32 l off) (rdle l off 4)

   ; --- reply/event demux: byte0 0 error, 1 reply, >=2 event. x-reply stashes
   ;     events in evq while it waits; x-next drains evq first ---
   evq {0 ()}
   (x-reply s) (x-rbytes s 32 @ pkt
                (<pkt = 1 || (127 & <pkt) = 0 ? pkt                              ; an error answers the wait too (a dead window
                 (pin evq 0 (evq 0 + [pkt]), x-reply s)))                        ; must not hang the wm)

   ; --- connect + setup -> the screen record | (). auth is () or the
   ;     mit-magic-cookie-1 (name data) ---
   (x-connect path) (connect ['unix path])
   (x-wpad s t)                                                                  ; a string + its 4-byte padding
    (x-wname s t, (: (go i) (i < x-pad4 #t ? (put s 0, go (i + 1))) (go 0)))
   (x-setup s auth)
    (: an #<auth ad #<>auth
       _ (x-w8 s 108, x-w8 s 0, x-w16 s 11, x-w16 s 0,
          x-w16 s an, x-w16 s ad, x-w16 s 0,
          auth @ (a b) (x-wpad s a, x-wpad s b),
          x-flush s)
       st (x-r8 s)
       (? !(st = 1) ()                                                           ; refused
          (: _ (x-r8 s) _ (x-r16 s) _ (x-r16 s)
             alen (x-r16 s)
             _ (x-r32 s) idbase (x-r32 s) _ (x-r32 s) _ (x-r32 s)
             vlen (x-r16 s) _ (x-r16 s)
             _ (x-r8 s) nfmt (x-r8 s)
             _ (x-skip s 4)
             minkc (x-r8 s) maxkc (x-r8 s)
             _ (x-skip s 4)
             _ (x-skip s (vlen + x-pad4 vlen))
             _ (x-skip s (8 * nfmt))
             root (x-r32 s) cmap (x-r32 s) _ (x-r32 s) _ (x-r32 s) _ (x-r32 s)
             wpx (x-r16 s) hpx (x-r16 s)
             _ (x-skip s 8)                                                      ; mm sizes, min/max installed maps
             vis (x-r32 s) _ (x-r8 s) _ (x-r8 s)                                 ; root visual; backing-stores, save-unders
             depth (x-r8 s) (x-r8 s,                                             ; root depth (PutImage needs it)
                             x-skip s (4 * alen - (32 + (vlen + x-pad4 vlen + (8 * nfmt + 40)))),
                             [root wpx hpx minkc maxkc idbase cmap vis depth]))))
   (scr-root sc) <sc  (scr-w sc) <>sc  (scr-h sc) <>>sc
   (scr-mink sc) (sc 3)  (scr-maxk sc) (sc 4)  (scr-idbase sc) (sc 5)
   (scr-cmap sc) (sc 6)  (scr-visual sc) (sc 7)  (scr-depth sc) (sc 8)

   ; --- requests ---
   (x-cwa-events s win mask)                                                     ; cweventMask
    (x-w8 s 2, x-w8 s 0, x-w16 s 4, x-w32 s win, x-w32 s 2048, x-w32 s mask)
   (x-configure s win x y w h)                                                   ; border-width is x-border's alone
    (x-w8 s 12, x-w8 s 0, x-w16 s 7, x-w32 s win, x-w16 s 15, x-w16 s 0,
     x-w32 s x, x-w32 s y, x-w32 s w, x-w32 s h)
   (x-map s win)   (x-w8 s 8, x-w8 s 0, x-w16 s 2, x-w32 s win)
   (x-unmap s win) (x-w8 s 10, x-w8 s 0, x-w16 s 2, x-w32 s win)
   (x-focus s win) (x-w8 s 42, x-w8 s 1, x-w16 s 3, x-w32 s win, x-w32 s 0)      ; SetInputFocus, PointerRoot revert
   (x-sync s) (x-w8 s 43, x-w8 s 0, x-w16 s 1, x-flush s, x-reply s)             ; a round trip, events so far stashed
   (x-clear-enters s) (x-sync s, pin evq 0 (filter (p \ (127 & <p) != 7) (evq 0)))   ; drop the EnterNotify our own paint caused
   (x-border s win px)                                                           ; ConfigureWindow border-width
    (x-w8 s 12, x-w8 s 0, x-w16 s 4, x-w32 s win, x-w16 s 16, x-w16 s 0, x-w32 s px)

   ; a request of op on win alone, or on the name nm, flushed -> its reply
   (x-query s op win) (x-w8 s op, x-w8 s 0, x-w16 s 2, x-w32 s win, x-flush s, x-reply s)
   (x-query-name s op nm)
    (: n #nm
       (x-w8 s op, x-w8 s 0, x-w16 s (2 + (n + x-pad4 n) // 4),
        x-w16 s n, x-w16 s 0, x-wpad s nm, x-flush s, x-reply s))

   ; --- InternAtom; also the redirect sync point ---
   (x-intern s nm) (x-query-name s 16 nm @ hdr (<hdr = 1 ? (u32 hdr 8)))           ; () on an error

   ; --- GetProperty -> (format nitems bytes) ---
   (x-getprop s win prop)
    (: _ (x-w8 s 20, x-w8 s 0, x-w16 s 6, x-w32 s win, x-w32 s prop,
          x-w32 s 0, x-w32 s 0, x-w32 s 1024, x-flush s)
       hdr (x-reply s)
       (? !(<hdr = 1) [0 0 ()]                                                   ; window died
          (: rlen (u32 hdr 4) fmt (hdr 1) n (u32 hdr 16)
             bytes (x-rbytes s (rlen * 4))
             [fmt n (take (n * (fmt // 8)) bytes)])))                            ; padding dropped
   (x-atoms-of bytes) (#bytes < 4 ? ()                                           ; 4 le bytes -> a 32-bit atom list
                         (u32 bytes 0 . x-atoms-of (drop 4 bytes)))
   (x-getprop-atoms s win prop) (x-atoms-of (x-getprop s win prop 2))
   (x-has-atom s win propnm valnm) (: at (x-getprop-atoms s win (x-intern s propnm)) va (x-intern s valnm)
                                      (any (a \ a = va) at))
   (x-getclass s win)                                                            ; wm_class "instance\0class\0" -> the class
    (: bytes (x-getprop s win 67 2)
       (go l seen acc) (? !(two? l) acc
                          (<l = 0) (seen ? acc (go >l 1 acc))
                          (go >l seen (seen ? (acc + string <l) acc)))
       (go bytes 0 ""))
   (x-transient s win) (x-getprop-atoms s win 68 @ a (two? a ? <a))              ; wm_transient_for -> parent | ()

   ; --- GetGeometry -> (x y w h) ---
   (x-getgeom s win)
    (: hdr (x-query s 14 win)
       (? !(<hdr = 1) '(0 0 1 1)                                                 ; window died
          [(u16 hdr 12) (u16 hdr 14) (u16 hdr 16) (u16 hdr 18)]))
   (x-raise s win) (x-w8 s 12, x-w8 s 0, x-w16 s 4, x-w32 s win,                 ; stackMode=Above
                    x-w16 s 64, x-w16 s 0, x-w32 s 0)
   (x-lower s win) (x-w8 s 12, x-w8 s 0, x-w16 s 4, x-w32 s win,                 ; stackMode=Below
                    x-w16 s 64, x-w16 s 0, x-w32 s 1)
   (x-kill s win) (x-w8 s 113, x-w8 s 0, x-w16 s 2, x-w32 s win)                 ; KillClient: severs the whole connection
   (x-wmdel s win)                                                               ; ICCCM close: wm_delete_window ClientMessage
    (: pr (x-intern s "WM_PROTOCOLS") dl (x-intern s "WM_DELETE_WINDOW")
       (x-w8 s 25, x-w8 s 0, x-w16 s 11, x-w32 s win, x-w32 s 0,
        x-w8 s 33, x-w8 s 32, x-w16 s 0, x-w32 s win, x-w32 s pr,
        x-w32 s dl, x-w32 s 0, x-w32 s 0, x-w32 s 0, x-w32 s 0))
   (x-confnotify s win)                                                          ; ICCCM 4.1.5: an overruled ConfigureRequest still gets
    (: hdr (x-query s 14 win)                                                     ; a synthetic ConfigureNotify with the real geometry
       (? !(<hdr = 1) 0                                                          ; (VTE sizes its grid off it)
          (: gx (u16 hdr 12) gy (u16 hdr 14) gw (u16 hdr 16) gh (u16 hdr 18) bw (u16 hdr 20)
             (x-w8 s 25, x-w8 s 0, x-w16 s 11, x-w32 s win, x-w32 s 131072,
              x-w8 s 22, x-w8 s 0, x-w16 s 0, x-w32 s win, x-w32 s win,
              x-w32 s 0, x-w16 s gx, x-w16 s gy, x-w16 s gw, x-w16 s gh,
              x-w16 s bw, x-w16 s 0, x-w32 s 0))))
   (x-delprop s win prop) (x-w8 s 19, x-w8 s 0, x-w16 s 3, x-w32 s win, x-w32 s prop)   ; DeleteProperty
   (x-grabbtn s win)                                                             ; GrabButton 1/2/3 sync: a click freezes until x-replay
    (: (one b) (x-w8 s 28, x-w8 s 0, x-w16 s 6, x-w32 s win,                     ; (click-to-focus); the wheel stays ungrabbed
                x-w16 s 4, x-w8 s 0, x-w8 s 1, x-w32 s 0,
                x-w32 s 0, x-w8 s b, x-w8 s 0, x-w16 s 32768)
       (one 1, one 2, one 3))
   (x-replay s) (x-w8 s 35, x-w8 s 2, x-w16 s 2, x-w32 s 0)                      ; AllowEvents ReplayPointer, CurrentTime
   (x-allow-async s) (x-w8 s 35, x-w8 s 1, x-w16 s 2, x-w32 s 0)                 ; AllowEvents AsyncPointer: thaw a sync grab without replaying
   (x-grabptr s win)                                                             ; GrabPointer: ButtonRelease|PointerMotion, the drag
    (x-w8 s 26, x-w8 s 0, x-w16 s 6, x-w32 s win,
     x-w16 s 72, x-w8 s 1, x-w8 s 1, x-w32 s 0, x-w32 s 0, x-w32 s 0, x-flush s,
     x-reply s)                                                                  ; the grab status: read to keep the demux synced
   (x-ungrabptr s) (x-w8 s 27, x-w8 s 0, x-w16 s 2, x-w32 s 0)                   ; UngrabPointer, CurrentTime
   (x-warp s win x y) (x-w8 s 41, x-w8 s 0, x-w16 s 6, x-w32 s 0, x-w32 s win,
                       x-w16 s 0, x-w16 s 0, x-w16 s 0, x-w16 s 0, x-w16 s x, x-w16 s y)
   (x-queryptr s win)                                                            ; QueryPointer -> the pointer's root (x y)
    (: hdr (x-query s 38 win)
       (<hdr = 1 ? [(i16 hdr 16) (i16 hdr 18)] '(0 0)))

   ; --- at startup adopt windows mapped before the redirect, and restart survivors ---
   (x-querytree s win)
    (: hdr (x-query s 15 win)
       ; presence rides out of band: [1 windows], or () when the query failed --
       ; QueryTree on the root cannot fail legitimately, so () means a garbled reply
       (? !(<hdr = 1) ()
          (: n (u16 hdr 16) bytes (x-rbytes s (u32 hdr 4 * 4))
             [1 (take n (x-atoms-of bytes))])))
   (x-attrs s win)                                                               ; -> (map-state override-redirect); 2 = IsViewable
    (: hdr (x-query s 3 win)
       (? !(<hdr = 1) '(0 1)                                                    ; window died: unmanageable
          (x-rbytes s (u32 hdr 4 * 4),                                          ; drain the reply data
           [(hdr 26) (hdr 27)])))
   (x-manageable? s win) (x-attrs s win @ a (<a = 2 && <>a = 0))

   ; --- become the wm: 1 = we hold it, 0 = another wm (the Access error answers the
   ;     intern wait, so refusal reads as the intern's ()) ---
   (x-redirect s root)                                                           ; substructure redirect+notify, and root StructureNotify
    (x-cwa-events s root 1703936,                                                ; (randr reshapes it)
     x-intern s "WM_STATE" ? 1 0)

   ; --- RandR 1.5: the monitors are the screens ---
   (i16 l off) (u16 l off @ v (v < 32768 ? v (v - 65536)))
   (x-queryext s nm)                                                            ; -> (major-opcode first-event) | ()
    (x-query-name s 98 nm @ hdr (<hdr = 1 && hdr 8 ? [(hdr 9) (hdr 10)]))
   (x-randr-init s root)
    (x-queryext s "RANDR" @ ext
       (!ext ? ()
          (: op <ext
             _ (x-w8 s op, x-w8 s 0, x-w16 s 3, x-w32 s 1, x-w32 s 5, x-flush s)
             hdr (x-reply s)
             (? !(<hdr = 1 && (u32 hdr 8 > 1 || u32 hdr 12 >= 5)) ()
                (x-w8 s op, x-w8 s 4, x-w16 s 3, x-w32 s root, x-w16 s 71, x-w16 s 0,   ; screen|crtc|output|resource
                 x-flush s, ext)))))
   (x-monitors s rr root)                                                       ; active only, primary first
    (: _ (x-w8 s <rr, x-w8 s 42, x-w16 s 3, x-w32 s root, x-w8 s 1, x-w8 s 0, x-w16 s 0, x-flush s)
       hdr (x-reply s)
       (? !(<hdr = 1) ()
          (: n (u32 hdr 12) b (x-rbytes s (4 * u32 hdr 4))
             (go i off) (i >= n ? ()
                           ([(i16 b (off + 8)) (i16 b (off + 10)) (u16 b (off + 12)) (u16 b (off + 14))]
                            . go (i + 1) (off + 24 + 4 * u16 b (off + 6))))
             (go 0 0))))

   ; --- keyboard ---
   (x-kbmap s mink nkc)                                                         ; GetKeyboardMapping's request -> its reply
    (x-w8 s 101, x-w8 s 0, x-w16 s 2, x-w8 s mink, x-w8 s nkc, x-w16 s 0, x-flush s, x-reply s)
   (x-keymap s mink maxk syms)                                                   ; syms: the keysyms to locate
    (: nkc (1 + (maxk - mink))
       hdr (x-kbmap s mink nkc)
       ; an error reply must not be read as keysyms: it would desync the connection
       ; for good. 0 keysyms = "no chords"
       kpc (<hdr = 1 ? (hdr 1) 0)
       km (tablet 8)
       ((: (go i) (i < nkc * kpc ?
                   (x-r32 s @ sym
                      ((? (any (x \ x = sym) syms && !(peep km sym 0))
                          (pin km sym (mink + i // kpc))),
                       go (i + 1))))
           (go 0)),
        km))
   (x-grab s root lib kc) (kc < 1 ? 0
                            (x-w8 s 33, x-w8 s 1, x-w16 s 4, x-w32 s root,
                             x-w16 s lib, x-w8 s kc, x-w8 s 1, x-w8 s 1,
                             x-w8 s 0, x-w8 s 0, x-w8 s 0))
   (x-ungrabkeys s root) (x-w8 s 34, x-w8 s 0, x-w16 s 3,                        ; a regrab starts clean
                          x-w32 s root, x-w16 s 32768, x-w16 s 0)

   ; --- AllocNamedColor: a color name -> a pixel ---
   (x-color s cmap nm)
    (: n #nm
       _ (x-w8 s 85, x-w8 s 0, x-w16 s (3 + (n + x-pad4 n) / 4),
          x-w32 s cmap, x-w16 s n, x-w16 s 0, x-wpad s nm, x-flush s)
       hdr (x-reply s) (<hdr = 1 ? (u32 hdr 8) 0))                               ; error: pixel 0
   (x-borderpix s win px)                                                        ; cwborderPixel
    (x-w8 s 2, x-w8 s 0, x-w16 s 4, x-w32 s win, x-w32 s 8, x-w32 s px)
   (x-bgpix s win px)                                                            ; cwbackPixel
    (x-w8 s 2, x-w8 s 0, x-w16 s 4, x-w32 s win, x-w32 s 2, x-w32 s px)
   (x-clear s win)                                                               ; ClearArea, no exposures: repaints the
    (x-w8 s 61, x-w8 s 0, x-w16 s 4, x-w32 s win, x-w32 s 0, x-w32 s 0)          ; background around mapped children

   ; --- root cursor xC_left_ptr: OpenFont "cursor", CreateGlyphCursor, cwcursor ---
   (x-cursor s root fid cid)
    (x-w8 s 45, x-w8 s 0, x-w16 s 5, x-w32 s fid,
     x-w16 s 6, x-w16 s 0, x-wpad s "cursor",
     x-w8 s 94, x-w8 s 0, x-w16 s 8, x-w32 s cid, x-w32 s fid, x-w32 s fid,
     x-w16 s 68, x-w16 s 69,
     x-w16 s 0, x-w16 s 0, x-w16 s 0,
     x-w16 s 65535, x-w16 s 65535, x-w16 s 65535,
     x-w8 s 46, x-w8 s 0, x-w16 s 2, x-w32 s fid,                                ; the cursor keeps its glyphs
     x-w8 s 2, x-w8 s 0, x-w16 s 4, x-w32 s root, x-w32 s 16384, x-w32 s cid)

   ; --- ~/.Xauthority: big-endian length-prefixed records -> the display's
   ;     mit-magic-cookie-1 (name data) | () ---
   (xauth-parse b disp)
    (: n #b
       (fld i) (: ln (b i << 8 | b (i + 1)) e (i + 2 + ln) [(snip b (i + 2) e) e])
       (go i) (n - i < 10 ? ()
                 (: ad (fld (i + 2)) nu (fld <>ad) nm (fld <>nu) da (fld <>nm)
                    (<nu = disp && <nm = "MIT-MAGIC-COOKIE-1" ? [<nm <da]
                     (go <>da))))
       (go 0))
   (xauth-cookie path disp)
    (open path "r" @ p
       (hot? p ? (slurp p @ b (close p, xauth-parse b disp))))

   ; --- a client of our own: [s sc], or 'no-display | 'refused ---
   (x-dispnum d) (#d < 2 ? "0"
                    (: b (snip d 1 #d)
                       (go i) (i = #b || b i = 46 ? (snip b 0 i) (go (i + 1)))
                       (go 0)))
   (x-authfile _) (getenv "XAUTHORITY" @ v (0 < #v ? v (getenv "HOME" + "/.Xauthority")))
   (x-open disp)
    (: dn (x-dispnum (string? disp ? disp ""))
       s (x-connect ("/tmp/.X11-unix/X" + dn))
       (? !(hot? s) 'no-display
          (x-setup s (xauth-cookie (x-authfile 0) dn) @ sc
             (two? sc ? [s sc] (close s, 'refused)))))

   ; --- a window of ours: black back pixel, the events in mask ---
   (x-window s win parent w h mask)
    (x-w8 s 1, x-w8 s 0, x-w16 s 10, x-w32 s win, x-w32 s parent,
     x-w16 s 0, x-w16 s 0, x-w16 s w, x-w16 s h, x-w16 s 0, x-w16 s 1, x-w32 s 0,
     x-w32 s 2050, x-w32 s 0, x-w32 s mask)
   (x-gc s gc win) (x-w8 s 55, x-w8 s 0, x-w16 s 4, x-w32 s gc, x-w32 s win, x-w32 s 0)
   (x-title s win t)                                                             ; ChangeProperty WM_NAME STRING
    (#t @ n
       (x-w8 s 18, x-w8 s 0, x-w16 s (6 + (n + x-pad4 n) // 4), x-w32 s win,
        x-w32 s 39, x-w32 s 31, x-w8 s 8, x-w8 s 0, x-w16 s 0, x-w32 s n, x-wpad s t))
   (x-protocols s win)                                                           ; answers the delete atom
    (: pr (x-intern s "WM_PROTOCOLS") dl (x-intern s "WM_DELETE_WINDOW")
       ((x-w8 s 18, x-w8 s 0, x-w16 s 7, x-w32 s win, x-w32 s pr, x-w32 s 4,
         x-w8 s 32, x-w8 s 0, x-w16 s 0, x-w32 s 1, x-w32 s dl),
        dl))
   ; XKB detectable autorepeat: a held key repeats presses only, no fake releases.
   ; a server without XKB keeps its default
   (x-autorepeat s)
    (: n #"XKEYBOARD"
       _ (x-w8 s 98, x-w8 s 0, x-w16 s (2 + (n + x-pad4 n) // 4), x-w16 s n, x-w16 s 0, x-wpad s "XKEYBOARD", x-flush s)
       hdr (x-reply s)
       op (<hdr = 1 ? (hdr 9) 0)
       (op < 1 ? 0
          (x-w8 s op, x-w8 s 0, x-w16 s 2, x-w16 s 1, x-w16 s 0, x-flush s,
           x-reply s,
           x-w8 s op, x-w8 s 21, x-w16 s 7, x-w16 s 256, x-w16 s 0, x-w32 s 1, x-w32 s 1, x-w32 s 0, x-w32 s 0, x-w32 s 0, x-flush s,
           x-reply s,
           1)))
   ; PutImage rows y..y+n at 32 bpp. a request length is 16 bits of words, so a
   ; band is at most 262112 bytes whatever the width
   (x-putrows s win gc depth fb w y n)
    (: rb (w * 4)
       band (262112 // rb @ v (v < 1 ? 1 (min 64 v)))
       (go y left) (left < 1 ? (x-flush s)
                      (: k (min band left) bytes (k * rb)
                         ((x-w8 s 72, x-w8 s 2, x-w16 s (6 + bytes // 4), x-w32 s win, x-w32 s gc,
                           x-w16 s w, x-w16 s k, x-w16 s 0, x-w16 s y, x-w8 s 0, x-w8 s depth, x-w16 s 0),
                          x-flush s,
                          say s (snip fb (y * rb) (y * rb + bytes)),
                          go (y + k) (left - k))))
       (go y n))
   ; keycode -> [sym shifted-sym], the whole table once (GetKeyboardMapping)
   (x-keysyms s mink maxk)
    (: nkc (maxk - mink + 1)
       hdr (x-kbmap s mink nkc)
       kpc (<hdr = 1 ? (hdr 1) 0)
       km (tablet 256)
       (go k) (k < nkc && 0 < kpc ?                                                ; an error reply carries no table
                 (: s0 (x-r32 s) s1 (1 < kpc ? (x-r32 s) 0)
                    (x-skip s (4 * max 0 (kpc - 2)),
                     pin km (mink + k) [s0 s1],
                     go (k + 1)))
                 km)
       (go 0))
   ; a KeyPress's keysym: shift (or caps lock on a letter) takes column 2; 0 for none
   (x-sym km kc st)
    (peep km kc () @ p
       (? !(two? p) 0
          (: lower <p upper <>p
             letter (97 <= lower <= 122)
             (st & 1 != 0 || letter && st & 2 != 0 ? (0 < upper ? upper lower) lower))))
   ; keysym -> utf-8 text; "" for the rest and under ctrl or alt
   (x-text sym st)
    (? (st & 12 != 0) ""
       (32 <= sym <= 126) (string sym)
       (160 <= sym <= 255) (utf8 sym)
       (16777216 <= sym <= 17891327) (utf8 (sym - 16777216))
       "")
   ; keycode -> PS/2 set-1 code (inle's tap). less 8 it is linux's code, set 1's own
   ; below the keypad; extended keys are 0xe0 folded onto 0x100. () for none
   x-set1-ext {96 284 97 285 98 309 99 311 100 312 102 327 103 328 104 329 105 331 106 333
               107 335 108 336 109 337 110 338 111 339 125 347 126 348 127 349}
   (x-set1 kc) (kc - 8 @ e (? (0 < e < 84 || 86 <= e <= 88) e (peep x-set1-ext e ())))
   ; ..and a key the keymap makes a ctrl, wherever it sits (caps lock as ctrl), ctrl's own
   (x-key km kc) (x-sym km kc 0 @ 65507 29 65508 285 _ (x-set1 kc))

   ; --- the event decoder: code 0 = X error (window is garbage) ---
   (x-decode pkt) [(127 & <pkt) (pkt 1) (u32 pkt 8) (u16 pkt 28) pkt]
   (x-next s)                                                                    ; a stashed event first
    (evq 0 @ q
       (two? q ? (pin evq 0 >q, x-decode <q)
        (see s @ b0
           (b0 = -1 ? ()
            ((b0 . x-rbytes s 31) @ pkt
               (b0 = 1 ? (x-skip s (4 * u32 pkt 4), x-next s)                    ; an orphaned reply: skip
                (x-decode pkt)))))))
   (ev-code e) <e  (ev-detail e) <>e  (ev-window e) (e 2)  (ev-state e) (e 3)
   (ev-raw e) (e 4)
   ; --- a window's events: [down key] [up key] [text s] [press b x y] [release b x y]
   ;     [move x y] [size w h] [close]; a key is its set-1 code ---
   (x-events e km dl)
    (: c (ev-code e) kc (ev-detail e) st (ev-state e) raw (ev-raw e)
       (? (c = 2 || c = 3)
            (: k (x-key km kc) t (c = 2 ? (x-text (x-sym km kc st) st) "")
               ((charm? k ? [[(c = 2 ? 'down 'up) k]] ()) + (0 < #t ? [['text t]] ())))
          (c = 4 || c = 5) [[(c = 4 ? 'press 'release) kc (i16 raw 24) (i16 raw 26)]]
          (c = 6) [['move (i16 raw 24) (i16 raw 26)]]
          (c = 22) [['size (u16 raw 20) (u16 raw 22)]]
          (c = 17 || (c = 33 && u32 raw 12 = dl)) [['close]]
          ())))
) ; module xwire
