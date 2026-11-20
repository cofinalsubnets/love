; test/host/wchisp.l -- src/tools/wchisp.l lays a flash session's bulk requests to the byte: the
; key from the seed, the uid's sum and the variant, worked here by hand; data padded with ff
; to 8s, in writes of 56 and an empty one. off a chip, the usb nifs only refuse what they cannot take
; run: cat test/00-init.l test/host/wchisp.l | out/love
(borrow '(posix usb))
(: dir (cwd 0 + "/out/.wchispd-" + show (getpid 0))
   tool (cwd 0 + "/src/tools/wchisp.l")
   lv (cwd 0 + "/out/love")
   _ (hark ["rm" "-rf" dir], mkdir dir 448)
   (put p s) (open p "w" @ q (say q s, close q))
   (frames img uid var sd) (: i (dir + "/img") o (dir + "/out") _ (put i img)
     rc (hark ["sh" "-c" ("LOVE_NO_IMAGE= '" + lv + "' '" + tool + "' frames '" + i + "' " + uid + " " + var + " " + sd + " > '" + o + "'")])
     (<rc = 0 ? (uread o @ [1 s] (lines s) ()) ()))
   zeros (cats (map (_ \ "00") ^30))
   ; a 76-byte image, a zero seed: the key is the uid's sum, 0x24, seven times, then 0x24 + 0x31
   img (string ([111 0 0 0] + map (i \ 65 + i) ^26 + map (i \ 97 + i) ^26 + map (i \ 48 + i) ^10 + map (i \ "!@#$%^&*()" i) ^10))
   f (frames img "0102030405060708" "31" zeros)
   ; a seed of 0..29 picks bytes 16 6 4 24 12 18 20 of it, each XOR 0x24, the last k0 + 0x31:
   ; eight zero bytes written are the key itself
   g (frames (string [0 0 0 0 0 0 0 0]) "0102030405060708" "31" "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d")
   _ (test (#f = 11)
           (f 0 = "a1120000194d4355204953502026205743482e434e")
           (f 1 = "a702001f00")
           (f 2 = "a31e00" + zeros)
           (f 3 = "a4040008000000")
           (f 4 = "a53d0000000000004b242424656667116162636c6d6e6f19696a6b74757677017172737c7d7e453747404142434c4d3f4f48494a4b54552757505152535c5d2f")
           (f 5 = "a51d00380000000014151617101112621c1d05640700010b020e0c0ddbdbdbaa")
           (f 6 = "a505005000000000")
           (f 7 = f 2)
           (f 8 = "a6" + snip (f 4) 2 #(f 4))
           (f 9 = "a6" + snip (f 5) 2 #(f 5))
           (f 10 = "a2010001")
           (g 4 = "a50d000000000000" + "3422203c28363065"))
   ; the nifs refuse what is not an fd and a buffer before any ioctl
   _ (test (!(charm? (usb-bulk "x" 2 "" 10))) (!(charm? (usb-bulk 0 129 "text" 10))) (!(charm? (usb-claim -1 0))))
   _ (hark ["rm" "-rf" dir])
   0)
(test_fin (), puts "wchisp: ok", putc 10, 0)
