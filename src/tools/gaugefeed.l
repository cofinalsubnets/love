; gaugefeed -- this box's cpu temperature to the esp32-c6 gauge (test/boards/esp32c6/gauge.c)
; over the chip's usb serial: a line "T" and tenths of a degree each second, from the first
; thermal zone of the type asked. the port is only written; opening it resets nothing
;   love src/tools/gaugefeed.l [-z TYPE] TTY      TYPE x86_pkg_temp
(borrow 'posix)
(: (die m) (say err ("gaugefeed: " + m + "\n"), flush err, quit 1)
   (zdir k) ("/sys/class/thermal/thermal_zone" + show k)
   (line p) (uread p @ [1 t] (t @ (a + "\n" + b) a t) _ ())
   ; the zone of that type, first of the sixty-four a box might have
   (zone ty) (: (go k) (k = 64 ? (die ("no thermal zone " + ty)) (line (zdir k + "/type") = ty ? (zdir k) (go (k + 1))))
                (go 0))
   (num s) (foldl (a \ c \ a * 10 + c - 48) 0 (map s ^#s))
   (milli z) (line (z + "/temp") @ (t && #t) (t 0 = 45 ? (0 - num >t) (num t)) _ (die ("cannot read " + z + "/temp")))
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
       (go _) (milli z @ m (say p ("T" + show (m // 100) + "\n"), flush p, rest 1000, go 0))
       (go 0))
   (main >argv))
