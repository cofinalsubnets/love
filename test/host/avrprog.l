; test/host/avrprog.l -- src/tools/avrprog.l against bootloaders played here on a pty: the bytes
; read are the flash's, every command is a whole reading one, and a wrong chip is refused
; run: cat test/00-init.l test/host/avrprog.l | out/love
(borrow 'cli)
(: dir (cwd 0 + "/out/.avrprogd")
   _ (hark ["rm" "-rf" dir], mkdir dir 448)
   img (string (map (i \ (i * 7 + i // 256) % 256) ^32768))
   (file f) (uread (dir + "/" + f) @ [1 s] s _ ())
   (waitfor pid) (gather pid @ s (two? s ? s (nom? s) s (rest 2, waitfor pid)))
   (run chip f) (tether ["sh" "-c" ("exec '" + selfpath 0 + "' src/tools/avrprog.l -p /dev/tty " + chip + " read '" + dir + "/" + f + "' >'" + dir + "/" + f + ".log' 2>&1")])
   ; the device's side: (cmd c k) answers a command's reply, k reading n more of its bytes
   (play chip f cmd)
    (: r (run chip f) m >r seen {'c () 'w 0}
       (more n) (map (_ \ see m) ^n)
       (go _) (see m @ c (c = -1 ? 0 (pin seen 'c (c . seen 'c), cmd c more seen @ a (say m a, flush m, go 0))))
       _ (twirl go 0)
       st (waitfor <r)
       [<st (seen 'c)])
   (cut seen n) (seen 'w @ w (pin seen 'w (w + n), snip img w (w + n)))
   ; each bootloader by its command bytes
   (caterina sig c more seen)
    (? (c = 83) "CATERIN" (c = 115) (string (rev sig)) (c = 69) "\r"
       (c = 65) (more 2 @ l (pin seen 'w (2 * (l 0 * 256 + l 1)), "\r"))
       (c = 103) (more 3 @ l (l 2 = 70 ? (cut seen (l 0 * 256 + l 1)) "?")) "?")
   (opti sig c more seen)
    (: (ok s) ("\x14" + s + "\x10")
       (? (c = 48) (more 1, ok "") (c = 117) (more 1, ok (string sig)) (c = 81) (more 1, ok "")
          (c = 85) (more 3 @ l (pin seen 'w (2 * (l 0 + 256 * l 1)), ok ""))
          (c = 116) (more 4 @ l (l 2 = 70 ? (ok (cut seen (l 0 * 256 + l 1))) "?")) "?"))
   (only l s) (foldl (a \ c \ a && 0 <= findsub s (string [c])) 1 l)
   u (play "32u4" "u" (caterina [30 149 135]))
   p (play "328p" "p" (opti [30 149 15]))
   x (play "32u4" "x" (caterina [30 149 15]))
   y (play "328p" "y" (opti [30 149 135]))
   _ (test (u 0 = 0) (file "u" = img) (only (u 1) "SsAgE") (<(u 1) = 69)
           (p 0 = 0) (file "p" = img) (only (p 1) "0uUtQ") (<(p 1) = 81)
           ; another chip: nothing read, nothing written, the bootloader left
           (x 0 = 1) (file "x" = ()) (only (x 1) "SsE") (<(x 1) = 69)
           (y 0 = 1) (file "y" = ()) (only (y 1) "0uQ") (<(y 1) = 81)
           (<(hark [(selfpath 0) "src/tools/avrprog.l" "-p" "/dev/null" "328p" "write" "f"]) = 1))
   _ (hark ["rm" "-rf" dir])
   0)
(test_fin (), puts "avrprog: ok", putc 10, 0)
