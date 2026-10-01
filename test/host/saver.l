; test/host/saver.l -- the screensavers (src/apps/saver.l), headless: every saver's frame
; covers the screen it is asked for in well-formed escapes, the moon is lit on the side its
; phase says, the idle watch fires on a fake clock and a key takes the saver down, love bee -s
; names the savers, and bee on a pty goes to its saver and comes back with the key swallowed.
;   cat test/00-init.l test/host/saver.l | out/love
(borrow 'saver)

(: sv-love (: l <cmdline (l 0 = 47 ? l (cwd 0 + "/" + l)))
   sv-find (cite 'kore 'wg-find)
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
   _ (test (["life" "matrix" "pom" "slop"] = saver-names))

   ; --- each saver, two sizes: a whole frame covers every cell in escapes it may send ---
   _ (each saver-names
       (nm \ each [[24 80] [11 37]]
         (z \ (: r <z c (z 1) s (sv-scan (saver-frame nm r c 1500 0.4) r c)
                 (test <s (s 1 = r * c))))))

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

   ; --- love bee -s: the names, and an unknown one exits 2 naming them ---
   (sv-run argv) (: md (tether argv) o (slurp >md)
                    (wf p) (gather p @ g (two? g ? g (rest 2, wf p)))
                    st (wf <md)
                    _ (close >md)
                    [<st o])
   ls (sv-run [sv-love "bee" "-s"])
   bad (sv-run [sv-love "bee" "-s" "nope"])
   bad2 (sv-run [sv-love "bee" "--screensaver" "nope"])
   _ (test (0 = <ls) (all (n \ sv-has? (ls 1) n) saver-names)
           (2 = <bad) (sv-has? (bad 1) "no screensaver nope") (all (n \ sv-has? (bad 1) n) saver-names)
           (2 = <bad2))

   ; --- bee's own screen on a pty: idle to the saver, a key back, the key not typed ---
   ; HOME and the hive are a scratch directory's, the model one on this machine that is
   ; never asked: nothing is sent
   dir (cwd 0 + "/out/.saver-" + show (getpid 0))
   _ (mkdir dir 493) _ (mkdir (dir + "/.love") 448) _ (mkdir (dir + "/.love/etc") 448)
   _ (: p (open (dir + "/.love/etc/bee.l") "w")
        _ (say p "(api openai)\n(url \"http://127.0.0.1:9/v1/chat/completions\")\n(model mock)\n(screensaver pom)\n(screensaver-idle 0.02)\n")
        (close p))
   md (tether ["sh" "-c" ("cd '" + dir + "' && HOME='" + dir + "' BEE_HIVE='" + dir + "/hive' BEE_NAME=svtest PWD='" + dir
                         + "' exec '" + sv-love + "' bee")])
   m >md
   _ (settty m 24 80)
   box {'s ""}
   rd (twirl (_ \ (: (go _) (: b (see m) (? (b < 0) 0 (: _ (unsee m b) _ (pin box 's (box 's + chug m)) (go 0))))
                     (go 0))) 0)
   (upto n pat) (? (sv-has? (box 's) pat) 1 (n <= 0) 0 (: _ (rest 50) (upto (n - 1) pat)))
   (mark _) #(box 's)
   (since k) (: s (box 's) (snip s k #s))
   up (upto 100 "session svtest")                           ; its own screen first
   asleep (upto 100 "\e[?25l")                              ; then, after 1.2 s without a key, the saver
   k0 (mark 0)
   _ (rest 300)
   frames (0 < #(since k0))                                 ; and it moves
   k1 (mark 0)
   _ (say m "a") _ (flush m)
   (upk n pat) (? (sv-has? (since k1) pat) 1 (n <= 0) 0 (: _ (rest 50) (upk (n - 1) pat)))
   woke (upk 100 "\e[?25h")
   back (upk 100 "session svtest")                          ; the screen laid again whole
   k2 (mark 0)
   _ (say m "b") _ (flush m)
   (upk2 n pat) (? (sv-has? (since k2) pat) 1 (n <= 0) 0 (: _ (rest 50) (upk2 (n - 1) pat)))
   typed (upk2 60 ">\e[0m b")
   _ (say m (string 3)) _ (flush m)                          ; ^c leaves
   st (: (wf p n) (gather p @ g (? (two? g) g (n <= 0) (: _ (still p 9) [-1]) (: _ (rest 20) (wf p (n - 1))))) (wf <md 250))
   _ (test up asleep frames woke back typed
           !(sv-has? (since k1) ">\e[0m a")                  ; the a woke it and went nowhere
           (two? st && <st = 0))                               ; and ^c left it
   _ (close m)
   _ (hark ["rm" "-rf" dir])
   (test_fin (), puts "saver: ok", putc 10, 0))
