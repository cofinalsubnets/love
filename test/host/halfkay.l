; test/host/halfkay.l -- src/tools/halfkay.l's framing, to exact report bytes; no board
; run: cat test/00-init.l test/host/halfkay.l | out/love
(borrow 'posix)
(: dir (cwd 0 + "/out/.halfkayd")
   _ (hark ["rm" "-rf" dir], mkdir dir 448)
   (fill b n) (string (map (_ \ b) ^n))
   (put f s) (uwrite (dir + "/" + f) s)
   (get f) (uread (dir + "/" + f) @ [1 s] s _ ())
   (hk as) (hark ([(selfpath 0) "src/tools/halfkay.l"] + as))
   (frame f) (hk ["frame" (dir + "/" + f) (dir + "/" + f + ".out")] @ r (<r = 0 ? (get (f + ".out")) r))
   ; a report as the description words it: three offset bytes low first, 61 zeros, the block
   (rep off d) (string [(off % 256) (off // 256 % 256) (off // 65536)] + fill 0 61 + d)
   start (rep 16777215 (fill 0 1024))
   b0 (string (map (i \ i % 251) ^1024))
   ; block 0, two blank blocks, a full block, a short last one
   _ (put "a" (b0 + fill 255 2048 + fill 17 1024 + "abc"))
   ; all blank: block 0 still goes, since its write is the erase
   _ (put "b" (fill 255 1500))
   ; a blank block 0 ahead of data, and data ending on a block's edge
   _ (put "c" (fill 255 1024 + fill 7 1024))
   _ (put "e" "")
   _ (put "big" (fill 0 (8192 * 1024 + 1)))
   _ (test (frame "a" = rep 0 b0 + rep 3072 (fill 17 1024) + rep 4096 ("abc" + fill 255 1021) + start)
           (frame "b" = rep 0 (fill 255 1024) + start)
           (frame "c" = rep 0 (fill 255 1024) + rep 1024 (fill 7 1024) + start)
           (#(frame "a") = 4 * 1088)
           ; refused by name, nothing laid
           (<(frame "e") = 1) (<(frame "big") = 1) (get "big.out" = ())
           (<(hk ["write"]) = 1) (<(hk []) = 1))
   ; start DEV, the device reached through a link as sysfs lays one: its words
   (lay n id) (: d (dir + "/real-" + n)
                 _ (hark ["mkdir" "-p" (d + "/1-3.1:1.0/0003:16C0:0478.0001/hidraw/hidraw987")])
                 _ (uwrite (d + "/idVendor") "16c0\n", uwrite (d + "/idProduct") (id + "\n"))
                 _ (hark ["ln" "-s" d (dir + "/" + n)])
                 (dir + "/" + n))
   (says dev) (: _ (hark ["sh" "-c" ((selfpath 0) + " src/tools/halfkay.l start " + dev + " > " + dir + "/said 2>&1")])
                 (get "said"))
   _ (test (has? (says (dir + "/nowhere")) "no usb device at")
           (has? (says (lay "loader" "0489")) "is not in HalfKay: nothing sent")
           ; a board there passes the guard, and is refused only at its node, which no host has
           (has? (says (lay "parked" "0478")) "hidraw987"))
   _ (hark ["rm" "-rf" dir])
   0)

(test_fin (), puts "halfkay: ok", putc 10, 0)
