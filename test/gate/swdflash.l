; test/gate/swdflash.l -- a board's image through love's own swd, for test/gate/mcuboard.sh on a
; host whose probe fact is love's: swd.l beside it, then the chip, the image and the probe's words.
;   love swdflash.l CHIP BASE IMAGE flash PROBE..   attach under reset, write, read back; left halted
;   love swdflash.l CHIP BASE IMAGE run PROBE..     reset, and let it run free
; a probe is `lovswd TTY` (the love swd probe) or `gpio CHIP SWCLK SWDIO NRST` (linux's gpio
; character device, the lines by offset). one flasher a chip: stm32f4 alone so far
(borrow "swd.l")
(: (fail m) (say err ("swdflash: " + m + "\n"), quit 1)
   (num s) (2 < #s && s 1 = 120 ? (foldl (\ a c (a * 16 + (c <= 57 ? c - 48 (c <= 70 ? c - 55 c - 87)))) 0 (map s (drop 2 ^#s)))
              (foldl (\ a c (a * 10 + c - 48)) 0 (map s ^#s)))
   (wire ps) (ps @ ["lovswd" tty] (probe-wire tty @ w (w 'clock 1000000, w))
                    ["gpio" chip c d r] (gpio-wire chip (num c) (num d) (num r))
                    (fail ("no probe known as " + show ps)))
   (main as)
    (: _ (#as < 5 ? (fail "usage: love swdflash.l CHIP BASE IMAGE flash|run PROBE..") 0)
       _ (<as = "stm32f4" ? 0 (fail ("no flasher for " + <as)))
       w (wire (drop 4 as))
       r (as 3 @
          "flash" (: s (uread (as 2) @ [1 s] s (fail ("cannot read " + as 2)))
                     ids (swd-attach w)
                     _ (say out ("swdflash: dpidr " + show <ids + ", " + show #s + " bytes at " + as 1 + "\n"))
                     (f4-flash w (num (as 1)) s))
          "run" (: _ (swd-connect w) (swd-run w))
          (fail ("no step " + as 3)))
       _ (w 'close 0)
       (r = 1 ? 0 (fail ("the image reads back wrong: " + show r))))
   (main >argv))
