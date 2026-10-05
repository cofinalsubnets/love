; test/host/ptui.l -- src/apps/player/tui.l: the player in cells, over a core in process on
; HORN=none. its frames at two sizes, and its keys and taps as the core's commands, read back
; off the core's own state.
;   cat test/00-init.l test/host/ptui.l | out/love
(borrow 'posix)
(borrow 'pcore)
(borrow 'ptui)
(: pt-dir (cwd 0 + "/out/.ptuid")
   _ (hark ["rm" "-rf" pt-dir], mkdir pt-dir 448)
   _ (setenv "HORN" "none")
   pt-pinv (cite 'guts 'pinv)
   (pt-le v n) (string (map (k \ (v >> (8 * k)) & 255) ^n))
   (pt-wav pcm) ("RIFF" + pt-le (36 + #pcm) 4 + "WAVEfmt " + pt-le 16 4 + pt-le 1 2 + pt-le 2 2 + pt-le 44100 4
                 + pt-le 176400 4 + pt-le 4 2 + pt-le 16 2 + "data" + pt-le #pcm 4 + pcm)
   (pt-sine f n) (: c (cask (4 * n)) t (int (8000.0 * sin (iota n * (2.0 * 3.141592653589793 * f / 44100))))
                    _ (pt-pinv c 0 2 4 t) _ (pt-pinv c 2 2 4 t) (string c))
   (pt-lay nm s) (open (pt-dir + "/" + nm) "w" @ q (say q s, close q))
   _ (pt-lay "bravo.wav" (pt-wav (pt-sine 440.0 88200)))
   _ (pt-lay "alpha.wav" (pt-wav (pt-sine 1000.0 44100)))
   ; a frame without its escapes, a line a row
   (pt-plain s) (: (go i acc) (? (#s <= i) (string (rev acc))
                                 (s i = 27) (: (sk j) (? (#s <= j) j (64 <= s j && s j <= 126) (j + 1) (sk (j + 1)))
                                               (go (sk (i + 2)) acc))
                                 (s i = 13) (go (i + 1) acc)
                                 (go (i + 1) (s i . acc)))
                   (go 0 ()))
   (pt-in s p) (0 <= fsub s p 0)
   pt-c (core-new "main")
   _ (core-send pt-c ['add (pt-dir + "/bravo.wav")]) _ (core-send pt-c ['add (pt-dir + "/alpha.wav")])
   pt-d (ptui-new pt-c)
   (pt-st k) (peep (pt-d 'st) k ())
   (pt-q _) (map (it \ peep it 'uri "" @ u (snip u (#pt-dir + 1) #u)) (pt-d 'q)))

; --- the frame: every panel at 80 by 24, and a small screen does not break it -------------
(: f (pt-plain (ptui-frame pt-d 80 24)) ls (lines f)
   small (ptui-frame pt-d 40 12)
   tiny (ptui-frame pt-d 20 6)
   _ (test (pt-in f "love player  main") (pt-in f "bravo.wav") (pt-in f "alpha.wav")
           (pt-in f "─ spectrum") (pt-in f "─ list") (pt-in f "─ eq")
           (pt-in f "pre") (pt-in f "16k") (pt-in f "2 items, 0:03")
           (pt-in f "  1. bravo.wav") (pt-in f "  2. alpha.wav") (pt-in f "0:02") (pt-in f "0:01")
           (24 >= #ls) (string? small) (string? tiny))
   0)

; --- transport and the mixer, as the core hears them -------------------------------------
(: _ (ptui-key pt-d 32) a (pt-st 'state)                    ; space: play
   _ (ptui-key pt-d 99) b (pt-st 'state)                    ; c: pause
   _ (ptui-key pt-d 118) c (pt-st 'state)                   ; v: stop
   f (pt-plain (ptui-frame pt-d 80 24))
   _ (ptui-key pt-d 45) v (pt-st 'vol)                      ; -: volume down 5
   _ (ptui-key pt-d 91) bl (pt-st 'bal)                     ; [: balance left 10
   _ (ptui-key pt-d 114) rp (pt-st 'repeat)                 ; r: repeat
   _ (test (a = 'play) (b = 'pause) (c = 'stop) (pt-in f " ■ ")
           (v = 95) (bl = -10) (rp = 1))
   0)

; --- the eq: a band chosen and moved, flat, a preset, off ---------------------------------
(: _ (ptui-key pt-d 9) fo (pt-d 'focus)                      ; tab: the eq
   _ (ptui-key pt-d -2) _ (ptui-key pt-d -2)                 ; right twice: 170 Hz
   _ (ptui-key pt-d -8) _ (ptui-key pt-d -8) _ (ptui-key pt-d -8)
   e1 (pt-st 'eq)
   _ (ptui-key pt-d -1) _ (ptui-key pt-d -9) e0 ((pt-st 'eq) 0)   ; left: 60 Hz, down a dB
   _ (ptui-key pt-d 112) e2 (pt-st 'eq)                       ; p: the next preset, classical
   _ (ptui-key pt-d 102) e3 (pt-st 'eq)                       ; f: flat
   _ (ptui-key pt-d 101) on (pt-st 'eqon)                     ; e: off
   _ (ptui-key pt-d 9) fo2 (pt-d 'focus)
   _ (test (fo = 'eq) (e1 1 = 3) (e1 0 = 0) (pt-d 'band = 1) (e0 = -1)
           (e2 = (ptui-presets 1) 1) (e3 = [0 0 0 0 0 0 0 0 0 0]) (on = 0) (fo2 = 'list))
   0)

; --- the playlist: chosen, moved, sorted, dropped, played ---------------------------------
(: _ (ptui-key pt-d -9) s1 (pt-d 'sel)                        ; down: the second
   _ (ptui-key pt-d 75) q1 (pt-q ()) s2 (pt-d 'sel)          ; K: up a place
   _ (ptui-key pt-d 111) q2 (pt-q ())                         ; o: sort by title
   _ (ptui-key pt-d -6) _ (ptui-key pt-d 10) song (pt-st 'song)   ; end, enter: play it
   _ (ptui-key pt-d 100) q3 (pt-q ())                         ; d: drop it
   _ (test (s1 = 1) (q1 = ["alpha.wav" "bravo.wav"]) (s2 = 0)
           (q2 = ["alpha.wav" "bravo.wav"]) (song = 1) (q3 = ["alpha.wav"]))
   0)

; --- the visualizer, a tap, and leaving ---------------------------------------------------
(: _ (ptui-key pt-d 109) vm (pt-d 'vis) f (ptui-frame pt-d 80 24)
   _ (ptui-key pt-d 109) vm2 (pt-d 'vis)
   _ (ptui-key pt-d 63) hf (pt-plain (ptui-frame pt-d 80 24)) _ (ptui-key pt-d 63)   ; ?: the keys
   ; a tap on the eq's preamp column at its top row is +12 dB
   g (pt-d 'geo) er (<(g 'eq))
   _ (ptui-tap pt-d [2 er]) pre (pt-st 'pre)
   _ (test (vm = 'scope) (pt-in f "─ scope") (vm2 = 'spec) (two? (g 'eq)) (pre = 12) (pt-d 'band = 0)
           (pt-in hf "─ keys") (pt-in hf "J/K move it"))
   _ (ptui-key pt-d 113)
   _ (test (pt-d 'over = 1))
   _ (ptui-close pt-d) _ (core-close pt-c)
   0)

(: _ (hark ["rm" "-rf" pt-dir]) (test_fin ()))
(puts "ptui: ok", putc 10, 0)
