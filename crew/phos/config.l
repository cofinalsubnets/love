; crew/phos/config.l -- the CONFIG: ~/.xmonad/xmonad.hs transliterated. Everything the
; Haskell record pinned, as plain values the driver (crew/phos/phos.l) reads -- the DSL
; underneath (core/layout/manage/keys/ewmh) already IS the xmonad vocabulary,
; so this file is short the way a config should be. A body-LESS `:`.
(:
   ; borderWidth = 3, normalBorderColor / focusedBorderColor
   phos-border 3
   phos-normal-color "Dark Slate Blue"
   phos-focused-color "Light Cyan"

   ; workspaces = map show [1 .. 9]
   phos-tags (map (+ 1) (jot 9))

   ; layoutHook = minimize . smartBorders . avoidStruts . windowNavigation
   ;            . toggleLayouts Full . mkToggle (single MIRROR) $ l1 ||| l2
   ;   (avoidStruts lives in the driver as ewmh-rect; windowNavigation is
   ;    nav-target under the directional keys -- both always-on, not records)
   ;   l2 = Dwindle R CW phi 1.1 where phi = fib 32 / fib 31 -- the fib, verbatim
   (phos-fib m n i) (? (< i 1) m (phos-fib n (+ m n) (- i 1)))
   phos-phi (/ (phos-fib 0 1 32) (phos-fib 0 1 31))
   phos-layout (minimize (smart-borders (toggle-full (mirror
              (choice (L (resizable-tall 1 (/ 2 100) (/ 1 2)) (dwindle phos-phi)))))))

   ; manageHook / keys: assembled in manage.l / keys.l (composeAll and
   ;   `keys def UNION custom` are the DSL's own assembly points)
   phos-manage manage-default
   phos-keymap the-keys

   ; startupHook = spawn "setxkbmap -option ctrl:nocaps -option compose:rctrl"
   ;   (setWMName "LG3D (XMonad)" rides ewmh-init; the cursor is x-cursor).
   ;   PHOS_NOSTARTUP skips the spawns -- a headless harness wants no keyboard
   ;   churn on its bare Xvfb
   phos-startup (? (getenv "PHOS_NOSTARTUP") () (L (L "setxkbmap" "-option" "ctrl:nocaps" "-option" "compose:rctrl")))

   ; the display: DISPLAY (":0" / ":7.0" -> the unix socket), the cookie from
   ;   ~/.Xauthority when the server wants one (an -ac Xephyr has no entry -> ())
   (phos-dispnum u) (: d (getenv "DISPLAY")
                     (? (< (tally d) 2) "7"                                      ; unset: the Xephyr harness habit
                        (: b (snip d 1 (tally d))
                           (: (go i) (? (|| (= i (tally b)) (= (b i) 46)) (snip b 0 i) (go (+ i 1)))
                              (go 0)))))
   (phos-auth-for disp) (xauth-cookie (+ (getenv "HOME") "/.Xauthority") disp)
   phos-display (+ "/tmp/.X11-unix/X" (phos-dispnum ()))
   phos-auth (phos-auth-for (phos-dispnum ())))
