; wm/keys.l -- the keymap DSL + xmonad's DEFAULT keymap + the config's custom
; table. PURE DATA: a binding is (mods keysym action), an action a tagged list
; the driver (wm/wm.l) interprets -- so the whole table rides the corpus and
; wm/law.l asserts its shape, the union law, and the directional generator.
; The config is xmonad's `(. keys def) . M.union . M.fromList $ [custom]`:
; custom bindings UNION over the stock table, custom winning on (mods keysym).
;
; The action vocabulary (what the driver's do-act cases on):
;   (msg M)            sendMessage M to the layout stack
;   (go DIR (dx dy))   f_t: float -> keysMoveWindow by (dx dy); tiled -> Go DIR
;   (swapd DIR (dx dy))     float -> keysResizeWindow;          tiled -> Swap DIR
;   (resize DIR (dx dy))    float -> keysResizeWindow;          tiled -> Shrink/Expand by DIR
;   (view T) (shift T) (spawn ARGV) (exec ARGV) (kill) (quit) (restart)
;   (refresh) (reset-layout) (sink) (float-toggle) (next-match FWD)
;   (focus-dn) (focus-up) (focus-master) (swap-dn) (swap-up) (swap-master)
; A body-LESS `:` -- the vocabulary leaks to the driver.
(:
   ; --- modifier masks (the X state bits) ---
   shiftm 1  ctrlm 4  altm 8  supm 64                                            ; sup = mod4, alt = mod1
   kmodmask 77                                                                   ; shift|ctrl|alt|sup: what a lookup masks state by

   ; --- keysyms (X11 core; letters/digits are ASCII) ---
   xk-ret 65293  xk-tab 65289  xk-left 65361  xk-up 65362  xk-right 65363  xk-down 65364

   ; --- a binding row ---
   (kb mods sym act) (L mods sym act)
   (kb-mods r) (cap r)  (kb-sym r) (caup r)  (kb-act r) (nthl r 2)
   (keys-has t mods sym) (any (\ r (&& (= (kb-mods r) mods) (= (kb-sym r) sym))) t)
   (keys-find t mods sym) (: hit (afind (\ r (&& (= (kb-mods r) mods) (= (kb-sym r) sym))) t)
                             (? (two? hit) (kb-act hit) ()))
   (keys-union custom def) (cat custom (filter (\ r (! (keys-has custom (kb-mods r) (kb-sym r)))) def))
   (keys-syms t) (foldl (\ a r (? (any (\ x (= x (kb-sym r))) a) a (link (kb-sym r) a))) () t)

   ; --- the directional block: the .hs list comprehension as a map --
   ;     (dir keysyms delta) x {hjkl, arrows} x {sup, sup+shift, sup+ctrl} ---
   kdirs (L (L 'left  (L 104 xk-left)  (L -20 0))
            (L 'down  (L 106 xk-down)  (L 0 20))
            (L 'up    (L 107 xk-up)    (L 0 -20))
            (L 'right (L 108 xk-right) (L 20 0)))
   (kdir-rows d) (: dir (cap d) delta (nthl d 2)
                    (foldl cat () (map (\ sym (L (kb supm sym (L 'go dir delta))
                                                 (kb (| supm shiftm) sym (L 'swapd dir delta))
                                                 (kb (| supm ctrlm) sym (L 'resize dir delta))))
                                       (caup d))))
   keys-dir (foldl cat () (map kdir-rows kdirs))

   ; --- the custom command block, exactly the config's table ---
   keys-cmd (L
     (kb supm 120 '(kill))                                                       ; sup+x
     (kb (| supm shiftm) 113 '(quit))                                            ; sup+shift+q
     (kb supm xk-ret (L 'spawn (L "xfce4-terminal")))                            ; sup+return  term
     (kb supm 96 (L 'spawn (L "rofi" "-show" "drun")))                           ; sup+`       menu
     (kb supm 32 '(msg next-layout))                                             ; sup+space
     (kb supm 98 '(toggle-struts))                                               ; sup+b       ToggleStruts (ewmh.l's avoid flag)
     (kb supm 109 '(msg mirror))                                                 ; sup+m       Toggle MIRROR
     (kb supm 102 '(msg toggle-layout))                                          ; sup+f       toggleLayouts Full
     (kb supm 112 (L 'spawn (L "xfce4-screenshooter")))                          ; sup+p
     (kb supm 119 '(float-toggle))                                               ; sup+w       f_t sink float
     (kb (| supm shiftm) 101 (L 'spawn (L "gvim" "/home/gwen/g/wm")))            ; sup+shift+e edit config
     (kb supm 101 (L 'spawn (L "rofimoji")))                                     ; sup+e
     (kb supm 122 (L 'spawn (L "xscreensaver-command" "-activate")))             ; sup+z
     (kb (| supm shiftm) 111 (L 'exec (L "openbox" "--replace")))                ; sup+shift+o abdicate
     (kb (| supm shiftm) 122 (L 'spawn (L "xscreensaver-command" "-lock")))      ; sup+shift+z
     (kb altm xk-tab '(next-match 1))                                            ; alt+tab     nextMatch Forward
     (kb supm xk-tab '(next-match 0))                                            ; sup+tab     nextMatch Backward
     (kb supm 44 '(msg inc-master))                                              ; sup+,       IncMasterN 1
     (kb supm 46 '(msg dec-master))                                              ; sup+.       IncMasterN -1
     (kb (| supm shiftm) 44 '(msg shrink))                                       ; sup+shift+,
     (kb (| supm shiftm) 46 '(msg expand)))                                      ; sup+shift+.
   keys-custom (cat keys-dir keys-cmd)

   ; --- xmonad's `keys def`, single-monitor subset (mod+{w,e,r} screens and
   ;     mod+shift+/ help are not ported; some rows are overridden by custom) ---
   kdigits (map (+ 1) (jot 9))
   keys-def (cat (L
     (kb (| supm shiftm) xk-ret (L 'spawn (L "xterm")))                          ; mod+shift+return  terminal
     (kb supm 112 (L 'spawn (L "dmenu_run")))                                    ; mod+p             (custom overrides)
     (kb (| supm shiftm) 99 '(kill))                                             ; mod+shift+c
     (kb supm 32 '(msg next-layout))                                             ; mod+space
     (kb (| supm shiftm) 32 '(reset-layout))                                     ; mod+shift+space
     (kb supm 110 '(refresh))                                                    ; mod+n
     (kb supm xk-tab '(focus-dn))                                                ; mod+tab           (custom overrides)
     (kb (| supm shiftm) xk-tab '(focus-up))
     (kb supm 106 '(focus-dn))                                                   ; mod+j
     (kb supm 107 '(focus-up))                                                   ; mod+k             (custom overrides j/k with Go)
     (kb supm 109 '(focus-master))                                               ; mod+m             (custom overrides)
     (kb supm xk-ret '(swap-master))                                             ; mod+return        (custom overrides)
     (kb (| supm shiftm) 106 '(swap-dn))                                         ; mod+shift+j
     (kb (| supm shiftm) 107 '(swap-up))                                         ; mod+shift+k
     (kb supm 104 '(msg shrink))                                                 ; mod+h             (custom overrides)
     (kb supm 108 '(msg expand))                                                 ; mod+l             (custom overrides)
     (kb supm 116 '(sink))                                                       ; mod+t             withFocused sink
     (kb supm 44 '(msg inc-master))
     (kb supm 46 '(msg dec-master))
     (kb (| supm shiftm) 113 '(quit))                                            ; mod+shift+q
     (kb supm 113 '(restart)))                                                   ; mod+q
     (cat (map (\ d (kb supm (+ 48 d) (L 'view d))) kdigits)                     ; mod+1..9
          (map (\ d (kb (| supm shiftm) (+ 48 d) (L 'shift d))) kdigits)))       ; mod+shift+1..9

   the-keys (keys-union keys-custom keys-def)                                    ; what the driver grabs and drives

   ; --- nextMatch's MRU pick, pure: row = the workspace's windows, f = the
   ;     focus, hist = every focus ever, most recent first. Forward walks to
   ;     the most recently used OTHER window (the alt-tab flip); Backward to
   ;     the least. Windows never yet focused count as oldest. ---
   (nm-pick row f hist fwd)
    (: cands (filter (\ w (&& (! (= w f)) (any (\ x (= x w)) row))) hist)
       fresh (filter (\ w (&& (! (= w f)) (! (any (\ x (= x w)) cands)))) row)
       order (cat cands fresh)
       (? (! (two? order)) () fwd (cap order) (cap (rev order)))))
