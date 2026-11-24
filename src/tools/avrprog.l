; avrprog -- an avr board's flash read back through its own bootloader. it reads alone:
; no command it sends writes or erases
;   love src/tools/avrprog.l -p TTY 328p read FILE    optiboot: stk500v1 (avr061) at 115200
;   love src/tools/avrprog.l -p TTY 32u4 read FILE    caterina: avr109 over usb, entered by a
;                                                     1200 baud touch
; the board's sketch stops, and starts again after. TTY is best a /dev/serial/by-path name,
; which stays the same when the 32u4 comes back as its bootloader
(borrow 'posix)
(: dtr 2 rts 4
   flash 32768
   chunk 128
   chips {"328p" "\x1e\x95\x0f" "32u4" "\x1e\x95\x87"}
   usage "usage: avrprog -p TTY 328p|32u4 read FILE"
   (die m) (say err ("avrprog: " + m + "\n"), flush err, quit 1)
   (hex s) (join "" (map (i \ (s i < 16 ? "0" "") + radix (s i) 16) ^#s))
   (open? dev k) (openfd dev 5 @ fd (charm? fd || k = 0 ? fd (rest 100, open? dev (k - 1))))
   ; raw 8N1, CS8 CREAD CLOCAL, a byte at a time
   (raw fd b) (termios fd @ t (nom? t ? t (settermios fd ([0 0 2224 0 b] + drop 5 t @ u (snip u 0 10 + [0 1] + drop 12 u)))))
   ; the port gone and back, as a reset over usb leaves it; one that stays is let be
   (cycle dev what)
    (: (there? _) (two? (stat dev))
       (gone k) (there? 0 ? (k = 0 ? 0 (rest 50, gone (k - 1))) 1)
       (back k) (there? 0 ? (rest 300) (k = 0) (die (dev + ": no port " + what)) (rest 50, back (k - 1)))
       (gone 40 ? (back 160) 0))
   ; dtr dropped at 1200 baud; a port that stays may be the bootloader already
   (touch dev)
    (: fd (openfd dev 5)
       _ (charm? fd ? 0 (die (dev + ": " + uerrno fd)))
       _ (raw fd 1200, modem fd 0 (dtr | rts), close fd)
       (cycle dev "after the touch"))
   (main as)
    (: a (as @ ["-p" d c "read" f] [d c f] _ (die usage))
       dev (a 0) chip (a 1) path (a 2)
       sig (chips chip)
       _ (string? sig ? 0 (die usage))
       usb (chip = "32u4")
       _ (usb ? (touch dev))
       fd (open? dev 30)
       _ (charm? fd ? 0 (die (dev + ": " + uerrno fd)))
       _ (raw fd 115200)
       p (fdopen fd)
       got {'b ""}
       (down _) (await p, see p @ c (c = -1 ? 0 (unsee p c, pin got 'b (got 'b + chug p), down 0)))
       _ (twirl down 0)
       (send s) (say p s, flush p)
       ; n bytes by the deadline, or ()
       (take n t) (got 'b @ b (n <= #b ? (pin got 'b (snip b n #b), snip b 0 n)
                                 (clock 0 < t) (rest 2, take n t) ()))
       ; a whole command, then its n bytes
       (ask s n ms) (pin got 'b "", send s, take n (clock 0 + ms))
       leave (usb ? "E" "Q ")
       ; the sketch's port waited for, so the next touch meets the sketch
       (bye _) (ask leave (usb ? 1 2) 500, usb ? (cycle dev "after the bootloader"))
       (fail m) (bye 0, die m)
       (want r what) (string? r ? r (fail (what + ": no answer")))
       ; stk500v1: 14, the n bytes, 10
       (stk s n what) (want (ask s (n + 2) 1000) what @ r
                         (r 0 = 20 && r (n + 1) = 16 ? (snip r 1 (n + 1)) (fail (what + ": " + hex (snip r 0 (min 4 #r))))))
       ; the reset line is dtr through a capacitor
       (pulse _) (modem fd 0 (dtr | rts), rest 250, modem fd (dtr | rts) 0, rest 100)
       ; one sync a reset: optiboot blinks before it reads, and two would overrun its uart
       (sync k) (k = 0 ? (die (dev + ": no answer from the bootloader"))
                 (pulse 0, ask "0 " 2 1000 = "\x14\x10" ? 0 (sync (k - 1))))
       (hi n) (n // 256) (lo n) (n % 256)
       start (usb ? (_ \ ask "S" 7 2000 @ r (r = "CATERIN" ? 0 (die (dev + ": no answer from the bootloader"))))
                (_ \ sync 5))
       signature (usb ? (_ \ want (ask "s" 3 1000) "signature" @ r (string [(r 2) (r 1) (r 0)]))
                    (_ \ stk "u " 3 "signature"))
       ; addresses are words in both
       seek (usb ? (w \ want (ask (string [65 (hi w) (lo w)]) 1 1000) "address" @ r (r 0 = 13 ? 0 (fail "address refused")))
               (w \ stk (string [85 (lo w) (hi w) 32]) 0 "address"))
       block (usb ? (n \ want (ask (string [103 (hi n) (lo n) 70]) n 2000) "read")
                (n \ stk (string [116 (hi n) (lo n) 70 32]) n "read"))
       (go i l) (i = flash ? (join "" (rev l)) (seek (i // 2), block chunk @ b (go (i + chunk) (b . l))))
       _ (start 0)
       s (signature 0)
       _ (s = sig ? 0 (fail ("signature " + hex s + ", not the " + chip + "'s")))
       d (go 0 ())
       w (uwrite path d)
       _ (bye 0)
       (w ? (say out "\(chip) signature \(hex s), \(#d) bytes to \(path)\n", flush out, quit 0)
        (die ("cannot write " + path))))
   (main >argv))
