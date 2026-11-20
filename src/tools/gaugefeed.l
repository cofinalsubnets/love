; gaugefeed -- this box's cpu temperature to the esp32-c6 gauge (test/boards/esp32c6/gauge.c)
; over the chip's usb serial: a line "T" and tenths of a degree each second, from the first
; thermal zone of the type asked. it gives the port up while another process holds it, as
; esprom does, and writes only when the line before has gone; a line the chip leaves unread
; 3 s boots it from its flash, once until the port drains, since an unread byte holds the
; next open's drain. a port that goes, unplugged, ends it. opening the port resets nothing
;   love src/tools/gaugefeed.l [-z TYPE] TTY      TYPE x86_pkg_temp
(borrow 'posix)
(: dtr 2 rts 4
   (die m) (say err ("gaugefeed: " + m + "\n"), flush err, quit 1)
   (zdir k) ("/sys/class/thermal/thermal_zone" + show k)
   (line p) (uread p @ [1 t] (t @ (a + "\n" + b) a t) _ ())
   ; the zone of that type, first of the sixty-four a box might have
   (zone ty) (: (go k) (k = 64 ? (die ("no thermal zone " + ty)) (line (zdir k + "/type") = ty ? (zdir k) (go (k + 1))))
                (go 0))
   (num s) (foldl (a \ c \ a * 10 + c - 48) 0 (map s ^#s))
   (milli z) (line (z + "/temp") @ (t && #t) (t 0 = 45 ? (0 - num >t) (num t)) _ (die ("cannot read " + z + "/temp")))
   ; a process other than me with an fd on tty; the ones not mine read as none
   (held me tty)
    (: (has k) (readdir ("/proc/" + k + "/fd") @ (l && two? l) (foldl (a \ f \ a || readlink ("/proc/" + k + "/fd/" + f) = tty) 0 l) _ 0)
       (foldl (a \ k \ a || k != me && 48 <= k 0 <= 57 && has k) 0 (readdir "/proc")))
   (opts as o) (as @ ("-z" . t . r) (opts r (pin o 'type t)) _ [o as])
   (main as)
    (: oa (opts as {'type "x86_pkg_temp"}) o <oa
       dev (<>oa @ [d] d _ (die "usage: love src/tools/gaugefeed.l [-z TYPE] TTY"))
       z (zone (o 'type))
       fd (openfd dev 5)
       _ (charm? fd ? 0 (die (dev + ": " + uerrno fd)))
       st (termios fd)
       _ (nom? st ? (die (dev + ": " + uerrno st)))
       ; raw 8N1 as esprom lays it: no echo sends the chip's lines back to it
       _ (settermios fd ([0 0 2224 0 115200] + drop 5 st @ t (snip t 0 10 + [0 1] + drop 12 t)))
       p (fdopen fd)
       me (readlink "/proc/self")
       tty (readlink ("/proc/self/fd/" + show fd))
       (outq _) (ioctl fd 21521 0)                     ; TIOCOUTQ, the bytes not yet taken
       ; esprom's plain boot on a USB-Serial-JTAG: IO0 high through RTS's reset
       (boot _) (modem fd 0 dtr, modem fd rts 0, rest 100, modem fd 0 (dtr | rts))
       ; s seconds a line has waited, b a boot spent on it
       (go s b)
        (rest 1000,
         (? (readlink ("/proc/self/fd/" + show fd) != tty) (die (dev + ": gone"))
            (held me tty) (go 0 b)
            (0 < outq 0) (s < 2 || b ? (go (s + 1) b) (boot 0, go 0 1))
            (milli z @ m (say p ("T" + show (m // 100) + "\n"), flush p, go 0 0))))
       (go 0 0))
   (main >argv))
