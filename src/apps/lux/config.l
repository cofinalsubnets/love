; src/apps/lux/config.l -- the config, ~/.xmonad/xmonad.hs transliterated, as plain values.
; read by salt: ~/.love/etc/lux.l, then ./.lux.l winning; each setting has a default.
; a repeated setting replaces, so a roster is one form; `()` alone is the empty roster.
;   (border 3)  (tags 9)  (mod sup)  (nudge 20)  (layout (rtall 1 0.02 0.5) (dwindle phi))
;   (layout-wrap minimize smart toggle-full mirror)  (float-class steam Gimp)
;   (bind ((sup Return) (spawn "alacritty")) ((sup ",") (msg shrink)))  (unbind (sup p))
;   (display ":7")  (xauthority "/home/me/.Xauthority")
; a chord is a list, the key last: a symbol names it, a one-char string, or a keysym number.
; conf-* take the tablet, so test/law/lux.l checks the defaults against an empty one.
(module 'lux
(borrow 'xwire)
(borrow 'salt)
(:
   ; --- the readers: a roster keeps names and forms; an absent roster takes d ---
   (conf-live? e) (two? e || name? e || string? e)
   (conf-roster c k d) (salt-all c k @ r (two? r ? (filter conf-live? r) d))
   (conf-mod c) (kmod-of (salt-one c 'mod 'sup) supm @ m (m ? m supm))
   (conf-tags c) (salt-one c 'tags 9 @ n (charm? n && (0 < n) ? n 9))

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

   ; the display names the unix socket; the xauthority setting, else $XAUTHORITY, else
   ;   ~/.Xauthority holds the cookie (a display manager may leave a stale ~/.Xauthority)
   (lux-dispof d) (#d < 2 ? "7"                                           ; unset: the Xephyr harness
                     (snip d 1 #d @ b
                        (: (go i) (i = #b || b i = 46 ? (snip b 0 i) (go (i + 1)))
                           (go 0))))
   (lux-xauth u) (getenv "XAUTHORITY" @ v (0 < #v ? v (getenv "HOME" + "/.Xauthority")))

   ; the settings, read at the first ask and never at load, where a bake would keep the
   ; baker's own (lux-cfg 'border): conf border normal-color focused-color tags layout
   ; manage mod keymap startup dispnum display auth
   cfg {}
   (lux-cfg k) (cfg 'read ? (cfg k) (lux-read (), cfg k))
   (lux-read _)
    (: c (salt 'lux)
       lays (filter two? (map lux-lay-of (conf-roster c 'layout '((rtall 1 0.02 0.5) (dwindle phi)))))
       wraps (conf-roster c 'layout-wrap '(minimize smart toggle-full mirror))
       m (conf-mod c)
       d (lux-dispof (salt-one c 'display () @ v (string? v ? v (getenv "DISPLAY"))))
       (pins cfg 'read 1 'conf c
             ; borderWidth = 3, normalBorderColor / focusedBorderColor
             'border (salt-one c 'border 3)
             'normal-color (salt-one c 'normal-color "Dark Slate Blue")
             'focused-color (salt-one c 'focused-color "Light Cyan")
             ; workspaces = map show [1 .. 9]
             'tags (map (+ 1) (jot (conf-tags c)))
             'layout (foldr lux-wrap-of (choice lays) wraps)
             'manage (manage-for (conf-roster c 'center-class mg-center-def)
                                 (conf-roster c 'float-class mg-float-def)
                                 (conf-roster c 'ignore-class ()))
             'mod m
             'keymap (keys-build m (salt-one c 'nudge 20) (conf-tags c)
                                 (conf-roster c 'bind ()) (conf-roster c 'unbind ()))
             ; LUX_NOSTARTUP skips the spawns, for a headless Xvfb harness
             'startup (getenv "LUX_NOSTARTUP" ? ()
                         (conf-roster c 'startup
                                      '(("setxkbmap" "-option" "ctrl:nocaps" "-option" "compose:rctrl"))))
             'dispnum d
             'display ("/tmp/.X11-unix/X" + d)
             'auth (xauth-cookie (salt-one c 'xauthority (lux-xauth ())) d))))
) ; module lux
