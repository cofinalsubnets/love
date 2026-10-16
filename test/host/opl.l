; test/host/opl.l -- the FM instruments: a bank laid here, read, and its voices measured
;   cat test/00-init.l test/host/opl.l | out/love
(borrow 'opl)
(borrow 'bytes)
(: (opl-t-cat l) (foldl (\ a s (a + s)) "" l)
   (opl-t-b l) (opl-t-cat (map string l))
   ; ..an operator's six bytes: 0x20 (sustain, multiple), attack/decay, sustain/release, wave, ksl, level
   (opl-t-op mul ar tl) (opl-t-b [(32 + mul) (ar * 16) 15 0 0 tl])
   ; ..a voice: a modulator held silent (level 63), connection c, the carrier, a spare byte, the offset
   (opl-t-voice mul ar c) (opl-t-cat [(opl-t-op 1 15 63) (string c) (opl-t-op mul ar 0) (string 0) (wrle 0 2)])
   (opl-t-ins fl note v) (opl-t-cat [(wrle fl 2) (string 128) (string note) v v])
   ; ..a sine, its double, a slow attack, two voices at once, a fixed note, an added pair
   ins [(opl-t-ins 0 0 (opl-t-voice 1 15 0)) (opl-t-ins 0 0 (opl-t-voice 2 15 0)) (opl-t-ins 0 0 (opl-t-voice 1 1 0))
        (opl-t-ins 4 0 (opl-t-voice 1 15 0)) (opl-t-ins 1 81 (opl-t-voice 1 15 0)) (opl-t-ins 0 0 (opl-t-voice 1 15 1))]
   op2 (opl-t-cat ["#OPL_II#" (opl-t-cat ins) (opl-t-cat (map (_ \ zbytes 36) ^(175 - #ins)))
                   "sine" (zbytes 28) (opl-t-cat (map (_ \ zbytes 32) ^174))])
   B (opl-bank op2)
   _ (test (#B = 175) (B 0 'name = "sine") (B 1 'name = "") (B 3 'two = 1) (B 4 'fixed = 1)
           (opl-bank "hello" = ()) (opl-bank (snip op2 0 400) = ()))
   ; ..the same bank as a wad's GENMIDI lump
   wad (opl-t-cat ["PWAD" (wrle 1 4) (wrle (12 + #op2) 4) op2 (wrle 12 4) (wrle #op2 4) "GENMIDI" (zbytes 1)])
   _ (test (#(opl-bank wad) = 175) (opl-bank wad 0 'name = "sine"))
   _ (test (opl-drum B 35 = B 128) (opl-drum B 34 = ()) (opl-drum B 82 = ()))

   ; a second at 48k: the pitch by rising crossings, the level by the peak
   rate 48000
   (opl-t-y i n vel) ((opl-voice (B i) n vel 0.5 0 () rate) 1 (iota rate))
   (opl-t-cut y a b) (peep y (iota (b - a) + a) 0.0)
   (opl-t-ups y) (net ((opl-t-cut y 0 (rate - 1) <= 0.0) * (opl-t-cut y 1 rate > 0.0)))
   (opl-t-peak y) (sqrt (amax (y * y)))
   _ (test (abs (opl-t-ups (opl-t-y 0 69 127) - 440) <= 1)           ; a = 440
           (abs (opl-t-ups (opl-t-y 1 69 127) - 880) <= 1)           ; the multiple 2
           (abs (opl-t-ups (opl-t-y 4 30 127) - 880) <= 1)           ; the fixed note 81, whatever is asked
           (abs (opl-t-ups (opl-t-y 5 69 127) - 440) <= 1))          ; added, the silent modulator nothing
   _ (test (opl-t-peak (opl-t-y 0 69 127) > 0.99) (opl-t-peak (opl-t-y 0 69 64) < 0.5)
           (opl-t-peak (opl-t-y 0 69 0) = 0.0) (opl-t-peak (opl-t-y 3 69 127) > 1.9))
   ; ..attack 1 rises over seconds
   s (opl-t-y 2 69 127)
   _ (test (opl-t-peak (opl-t-cut s 0 4800) < 0.1) (opl-t-peak (opl-t-cut s 43200 48000) > 0.2))
   ; ..held, it ends an hour on; let go at half a second, release 15 ends it within a tenth, silent after
   h (opl-voice (B 0) 69 127 0.3 0 () rate)
   v (opl-voice (B 0) 69 127 0.3 0 24000 rate)
   _ (test (h 0 = 3600 * rate) (v 0 > 24000) (v 0 < 28800) (v 2 = 0.7) (v 3 = 0.3)
           (opl-t-peak ((v 1) (iota 4800 + 19000)) > 0.99) (opl-t-peak ((v 1) (iota 4800 + v 0)) < 0.001))
   ((test_fin ()),
    puts "opl: ok\n"))
