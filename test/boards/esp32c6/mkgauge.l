; test/boards/esp32c6/mkgauge.l -- xbell's magma as the gauge's pixel table: each entry's srgb
; taken to linear light, scaled to TOP thousandths of full, laid grb as a c header
;   love test/boards/esp32c6/mkgauge.l XBELL OUT TOP
(borrow 'posix)
(: (fail m) (say err ("mkgauge: " + m + "\n"), quit 1)
   (dig c) (? (c <= 57) (c - 48) (c <= 70) (c - 55) (c - 87))
   (hex? c) ((48 <= c && c <= 57) || (97 <= c && c <= 102))
   ; the hex digits of xbell's magma block, its quotes and line breaks dropped
   (digits s) (s @ (a + "magma (cats [" + b + "])" + c) (filter hex? (map b ^#b)) ())
   (lin v) (v / 255 @ x (x <= 0.04045 ? (x / 12.92) (2.4 ((x + 0.055) / 1.055))))
   (level v top) (int (lin v * 255 * top / 1000 + 0.5))
   (main args)
    (: _ (#args = 3 ? 0 (fail "usage: love test/boards/esp32c6/mkgauge.l XBELL OUT TOP"))
       s (uread (args 0) @ [1 s] s (fail ("cannot read " + args 0)))
       ds (digits s)
       _ (#ds = 1536 ? 0 (fail ("no 256-entry magma in " + args 0 + ", " + show #ds + " digits")))
       top (num (args 2))
       (byte i) (dig (ds (2 * i)) * 16 + dig (ds (2 * i + 1)))
       (entry k) (: r (byte (3 * k)) g (byte (3 * k + 1)) b (byte (3 * k + 2))
                    ("  {" + show (level g top) + ", " + show (level r top) + ", " + show (level b top) + "},\n"))
       q (open (args 1) "w")
       (hot? q ? (say q ("// laid by test/boards/esp32c6/mkgauge.l from " + args 0 + "'s magma: grb, linear, "
                         + show top + "/1000 of full\n"
                         + "static uint8_t const gauge_grb[256][3] = {\n"
                         + cats (map entry ^256) + "};\n"),
                  close q)
                 (fail ("cannot open " + args 1))))
   (num s) (foldl (a \ c \ a * 10 + c - 48) 0 (map s ^#s))
   (main >argv))
