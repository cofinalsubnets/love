; src/apps/lux/config.l -- the config, ~/.xmonad/xmonad.hs transliterated, as plain values.
; read by salt: ~/.love/etc/lux.l, then ./.lux.l winning; each setting has a default.
; a repeated setting replaces, so a roster is one form; `()` alone is the empty roster.
;   (border 3)  (tags 9)  (mod sup)  (nudge 20)  (layout (rtall 1 0.02 0.5) (dwindle phi))
;   (layout-wrap minimize smart toggle-full mirror)  (float-class steam Gimp)
;   (bind ((sup Return) (spawn "alacritty")) ((sup ",") (msg shrink)))  (unbind (sup p))
;   (display ":7")  (xauthority "/home/me/.Xauthority")
; a chord is a list, the key last: a symbol names it, a one-char string, or a keysym number.
; conf-* take the tablet, so test/law/lux.l checks the defaults against an empty one.
(borrow 'xwire)
(borrow 'salt)
(:
   ; --- the readers: a roster keeps names and forms; an absent roster takes d ---
   (conf-live? e) (two? e || name? e || string? e)
   (conf-roster c k d) (salt-all c k @ r (two? r ? (filter conf-live? r) d))
   (conf-mod c) (kmod-of (salt-one c 'mod 'sup) supm @ m (m ? m supm))
   (conf-tags c) (salt-one c 'tags 9 @ n (charm? n && (0 < n) ? n 9))

   lux-conf (salt 'lux)

   ; borderWidth = 3, normalBorderColor / focusedBorderColor
   lux-border (salt-one lux-conf 'border 3)
   lux-normal-color (salt-one lux-conf 'normal-color "Dark Slate Blue")
   lux-focused-color (salt-one lux-conf 'focused-color "Light Cyan")

   ; workspaces = map show [1 .. 9]
   lux-tags (map (+ 1) (jot (conf-tags lux-conf)))

   ; layoutHook: l1 ||| l2 with minimize, smartBorders, toggle Full, mirror wraps;
   ;   avoidStruts and windowNavigation live in the driver. phi = fib 32 / fib 31
   (lux-fib m n i) (i < 1 ? m (lux-fib n (m + n) (i - 1)))
   lux-phi (lux-fib 0 1 32 / lux-fib 0 1 31)
   ; one ||| member: the head names the layout; `phi` may stand for any number
   (lux-arg a i d) (: (go l k) (? (atom? l) d
                                  (0 < k) (go >l (k - 1))
                                  (<l @ v (v = 'phi ? lux-phi (constellation? v ? v d))))
                      (go a i))
   (lux-lay-of sp)
    (: h (two? sp ? <sp sp) a (two? sp ? >sp ())
       (h @ 'rtall   (resizable-tall (lux-arg a 0 1) (lux-arg a 1 0.02) (lux-arg a 2 0.5))
            'tall    (tall (lux-arg a 0 1))
            'dwindle (dwindle (lux-arg a 0 lux-phi))
            'full    full
            ()))
   (lux-wrap-of w inner) (w @ 'minimize    (minimize inner)
                              'smart       (smart-borders inner)
                              'toggle-full (toggle-full inner)
                              'mirror      (mirror inner)
                              inner)
   lux-lays (filter two? (map lux-lay-of
                              (conf-roster lux-conf 'layout '((rtall 1 0.02 0.5) (dwindle phi)))))
   lux-wraps (conf-roster lux-conf 'layout-wrap '(minimize smart toggle-full mirror))
   lux-layout (foldr lux-wrap-of (choice lux-lays) lux-wraps)

   lux-manage (manage-for (conf-roster lux-conf 'center-class mg-center-def)
                          (conf-roster lux-conf 'float-class mg-float-def)
                          (conf-roster lux-conf 'ignore-class ()))
   lux-mod (conf-mod lux-conf)
   lux-keymap (keys-build lux-mod (salt-one lux-conf 'nudge 20) (conf-tags lux-conf)
                          (conf-roster lux-conf 'bind ()) (conf-roster lux-conf 'unbind ()))

   ; LUX_NOSTARTUP skips the spawns, for a headless Xvfb harness
   lux-startup (getenv "LUX_NOSTARTUP" ? ()
                  (conf-roster lux-conf 'startup
                               '(("setxkbmap" "-option" "ctrl:nocaps" "-option" "compose:rctrl"))))

   ; the display names the unix socket; the xauthority setting, else $XAUTHORITY, else
   ;   ~/.Xauthority holds the cookie (a display manager may leave a stale ~/.Xauthority)
   (lux-dispof d) (#d < 2 ? "7"                                           ; unset: the Xephyr harness
                     (snip d 1 #d @ b
                        (: (go i) (i = #b || b i = 46 ? (snip b 0 i) (go (i + 1)))
                           (go 0))))
   (lux-dispnum u) (lux-dispof (salt-one lux-conf 'display () @ d (string? d ? d (getenv "DISPLAY"))))
   (lux-xauth u) (getenv "XAUTHORITY" @ v (0 < #v ? v (getenv "HOME" + "/.Xauthority")))
   (lux-auth-for disp) (xauth-cookie (salt-one lux-conf 'xauthority (lux-xauth ())) disp)
   lux-display ("/tmp/.X11-unix/X" + lux-dispnum ())
   lux-auth (lux-auth-for (lux-dispnum ())))
