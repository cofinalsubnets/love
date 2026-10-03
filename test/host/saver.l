; test/host/saver.l -- mitty's screensavers (src/apps/mitty/saver.l), headless: every saver's
; frame covers the screen it is asked for in well-formed escapes, the moon is lit on the side
; its phase says, the idle watch fires on a fake clock and a key takes the saver down, and
; love mitty -s names the savers. mitty's glass going to its saver is test/host/mitty.l's.
;   cat test/00-init.l test/host/saver.l | out/love
(borrow 'saver)

(: sv-love (: l <cmdline (l 0 = 47 ? l (cwd 0 + "/" + l)))
   sv-find fsub
   (sv-has? h n) (0 <= sv-find h n 0)
   (sv-num s) (: (go i a) (? (i < #s) (? (48 <= s i < 58) (go (i + 1) (a * 10 + s i - 48)) -1) a)
                 (#s ? (go 0 0) -1))
   ; a frame read the way a terminal reads it -> [ok cells]: every escape one the savers
   ; send, every glyph inside r by c, and how many distinct cells were written
   (sv-scan f r c)
    (: seen (cask (r * c))
       (csi i) (: (go j) (? (j < #f && (48 <= f j < 60 || f j = 63)) (go (j + 1)) j) (go i))
       (go i y x ok n)
        (? (#f <= i) [ok n]
           (f i = 27)
            (: j (csi (i + 2)) ps (snip f (i + 2) j) fin (? (j < #f) (f j) 0)
               ns (map sv-num (cite 'kore 'usplit 59 ps))
               (? !(f (i + 1) = 91) [0 n]
                  (fin = 72) (? (#ns = 2 && 1 <= <ns <= r && 1 <= ns 1 <= c) (go (j + 1) (<ns - 1) (ns 1 - 1) ok n) [0 n])
                  (fin = 67) (? (#ns = 1 && 0 < <ns) (go (j + 1) y (x + <ns) ok n) [0 n])
                  (fin = 109) (? (ps = "0" || #ns = 3 && (<ns = 38 || <ns = 48) && ns 1 = 5 && 0 <= ns 2 < 256)
                                 (go (j + 1) y x ok n) [0 n])
                  (fin = 104 || fin = 108) (? (ps = "?2026") (go (j + 1) y x ok n) [0 n])
                  [0 n]))
           (: b (f i) w (? (b < 128) 1 (b < 224) 2 (b < 240) 3 4)
              (? (0 <= y < r && 0 <= x < c)
                 (: k (y * c + x) fresh (peep seen k 0 = 0)
                    _ (pin seen k 1)
                    (go (i + w) y (x + 1) ok (fresh ? (n + 1) n)))
                 [0 n])))
       (go 0 0 0 1 0))
   _ (test (["court" "grass99" "life" "matrix" "pom" "slop"] = saver-names))

   ; --- each saver, two sizes: a whole frame covers every cell in escapes it may send ---
   _ (each saver-names
       (nm \ each [[24 80] [11 37]]
         (z \ (: r <z c (z 1) s (sv-scan (saver-frame nm r c 1500 0.4) r c)
                 (test <s (s 1 = r * c))))))

   ; --- a style after the name: pom natural covers the screen too, and is not pom's own
   ; --- face; a style a saver has not is never one ---
   nat (saver-frame "pom natural" 24 80 1500 0.4)
   _ (test (sv-scan nat 24 80 @ s (<s && s 1 = 24 * 80)) (nat != saver-frame "pom" 24 80 1500 0.4)
           (0 < (saver-watch "pom natural" 5) 'idle) (0 = (saver-watch "pom fancy" 5) 'idle)
           (0 = (saver-watch "life natural" 5) 'idle))

   ; --- the lore scenes are pictures: half blocks over the whole canvas, in many pens ---
   (pic? nm) (: cv (saver-canvas nm 24 80 1500 ()) cs (map (i \ saver-cell cv (i // 80) (i % 80)) ^(24 * 80))
                pens (foldl (t \ k \ pin t (k 1) 1) {} cs)
                (all (k \ <k = 128) cs && 6 < #(keys pens)))
   _ (test (pic? "court") (pic? "grass99"))

   ; --- the moon is lit on its phase's side ---
   ph (cite 'pom 'pom-phase)
   wax (ph 12 9 23 2026)                                  ; waxing gibbous, 81%
   wane (ph 23 12 31 1999)                                ; waning crescent, 33%
   (lit? cv y x) (: k (saver-cell cv y x) (<k = 128 && elem (k 1) [230 187]))
   (dark? cv y x) (: k (saver-cell cv y x) (<k = 128 && k 1 = 234))
   cw (saver-canvas "pom" 24 80 0 wax)
   cn (saver-canvas "pom" 24 80 0 wane)
   _ (test (saver-moon-lit? wax 0.8 0.0) !(saver-moon-lit? wax -0.9 0.0)
           (saver-moon-lit? wane -0.9 0.0) !(saver-moon-lit? wane 0.5 0.0)
           (lit? cw 11 55) (dark? cw 11 23)                 ; lit right, dark at the left limb
           (lit? cn 11 25) (dark? cn 11 55)                 ; and the waning one the other way
           (sv-has? (saver-frame "pom" 24 80 0 wax) "Waxing Gibbous, 81% of full")
           (sv-has? (saver-frame "pom" 24 80 0 wane) "Waning Crescent, 33% of full"))

   ; --- the idle watch, on a fake clock ---
   w (saver-watch "matrix" 10)
   mn 60000
   _ (test ("" = saver-tick w 0 24 80 0)                    ; the first tick starts the clock
           ("" = saver-tick w (10 * mn - 1) 24 80 0)       ; a moment short of ten minutes
           !(saver-on? w)
           (0 = saver-key w (5 * mn))                      ; a key, not the saver's: the clock again
           ("" = saver-tick w (10 * mn) 24 80 0))
   f0 (saver-tick w (15 * mn) 24 80 0)                    ; ten minutes from that key
   _ (test (saver-on? w)
           (snip f0 0 6 = "\e[?25l")                        ; the cursor goes
           (: s (sv-scan (snip f0 6 #f0) 24 80) (<s && s 1 = 24 * 80))
           ("" = saver-tick w (15 * mn + 10) 24 80 0)      ; the next frame is not due yet
           (0 < #(saver-tick w (15 * mn + 70) 24 80 0))
           !(sv-has? (saver-tick w (15 * mn + 140) 24 80 0) "✉")
           (sv-has? (saver-tick w (15 * mn + 210) 24 80 1) "✉")   ; mail came: a mark
           (<(sv-scan (saver-tick w (15 * mn + 280) 24 80 1) 24 80))
           (1 = saver-key w (15 * mn + 300))               ; the key that wakes it is swallowed
           !(saver-on? w)
           ("\e[0m\e[?25h" = saver-tick w (15 * mn + 301) 24 80 1)   ; the cursor back
           ("" = saver-tick w (15 * mn + 400) 24 80 1)
           (0 = saver-key w (16 * mn)))                    ; and the next key is the screen's
   _ (test ("" = saver-tick (saver-watch "pom" 0) 0 24 80 0)
           (: w0 (saver-watch "pom" 0) _ (saver-tick w0 0 24 80 0) ("" = saver-tick w0 (999 * mn) 24 80 0))   ; 0 is never
           (: wn (saver-watch "nope" 1) _ (saver-tick wn 0 24 80 0) ("" = saver-tick wn (9 * mn) 24 80 0))   ; nor a name it lacks
           (: wf (saver-watch "pom" 0.5) _ (saver-tick wf 0 24 80 0) (0 < #(saver-tick wf 30000 24 80 0))))
   ; cycle: a saver of the roster at each start, and the next once five minutes have run
   wc (saver-watch "cycle" 1)
   _ (saver-tick wc 0 24 80 0)
   _ (saver-tick wc mn 24 80 0)
   c1 ((wc 'on) 'nm)
   _ (saver-tick wc (6 * mn + 1) 24 80 0)
   c2 ((wc 'on) 'nm)
   _ (saver-key wc (7 * mn))
   _ (saver-tick wc (7 * mn + 1) 24 80 0)
   _ (saver-tick wc (9 * mn) 24 80 0)
   c3 ((wc 'on) 'nm)
   _ (test (elem c1 saver-names) (elem c2 saver-names) (elem c3 saver-names) (c1 != c2) (c2 != c3))

   ; --- love mitty -s: the names, and an unknown one exits 2 naming them ---
   (sv-run argv) (: md (tether argv) o (slurp >md)
                    (wf p) (gather p @ g (two? g ? g (rest 2, wf p)))
                    st (wf <md)
                    _ (close >md)
                    [<st o])
   ls (sv-run [sv-love "mitty" "-s"])
   bad (sv-run [sv-love "mitty" "-s" "nope"])
   bad2 (sv-run [sv-love "mitty" "--screensaver" "nope"])
   bad3 (sv-run [sv-love "mitty" "-s" "pom" "fancy"])
   _ (test (0 = <ls) (all (n \ sv-has? (ls 1) n) saver-names)
           (2 = <bad) (sv-has? (bad 1) "no screensaver nope") (all (n \ sv-has? (bad 1) n) saver-names)
           (2 = <bad2) (2 = <bad3) (sv-has? (ls 1) "pom [natural]") (sv-has? (ls 1) "cycle"))

   (test_fin (), puts "saver: ok", putc 10, 0))
