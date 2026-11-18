; test/gate/swdflash.l -- a board's image through love's own swd, for test/gate/mcuboard.sh on a
; host whose probe fact is love's: swd.l beside it, then the chip, the image and the probe's words.
;   love swdflash.l CHIP BASE IMAGE flash PROBE..   attach under reset, write, read back; left halted
;   love swdflash.l CHIP BASE IMAGE run PROBE..     reset, and let it run free
; a probe is `lovswd TTY` (the love swd probe), `gpio CHIP SWCLK SWDIO NRST` (linux's gpio
; character device, the lines by offset) or `dap HIDRAW` (a cmsis-dap's hid interface, daplink's).
; one flasher a chip: stm32f4, nrf52
(borrow "swd.l")
(: (fail m) (say err ("swdflash: " + m + "\n"), quit 1)
   (num s) (read s @ (n && charm? n) n (fail ("not a number: " + s)))
   (wire ps) (ps @ ["lovswd" tty] (probe-wire tty @ w (w 'clock 1000000, w))
                    ["gpio" chip c d r] (gpio-wire chip (num c) (num d) (num r))
                    ["dap" hid] (dap-wire hid @ w (w 'clock 4000000, w))
                    (fail ("no probe known as " + show ps)))
   (main as)
    (: _ (#as < 5 ? (fail "usage: love swdflash.l CHIP BASE IMAGE flash|run PROBE..") 0)
       fl ({"stm32f4" f4-flash "nrf52" nrf-flash} (as 0))
       _ (fl = () ? (fail ("no flasher for " + <as)) 0)
       w (wire (drop 4 as))
       r (trap (_ \ as 3 @
          "flash" (: s (uread (as 2) @ [1 s] s (fail ("cannot read " + as 2)))
                     ids (swd-attach w)
                     _ (say out ("swdflash: dpidr " + show <ids + ", " + show #s + " bytes at " + as 1 + "\n"))
                     (fl w (num (as 1)) s))
          "run" (: _ (swd-connect w) (swd-run w))
          (fail ("no step " + as 3))) 0
          (a \ b \ (w 'close 0, fail (show a + " answered " + show b))))
       _ (w 'close 0)
       (r = 1 ? 0 (fail ("the image reads back wrong: " + show r))))
   (main >argv))
