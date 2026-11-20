; test/kernel/stay.l -- test_uefi_stay's corpus: the kernel as the firmware's guest (love.stay
; beside love.elf) and the boot menu on it (src/inle/uefi/menu.l). the menu's rows, keys, frames
; and boots through doors of its own, then through the firmware's: test/kernel/boot.l off the
; volume, and test/kernel/c/efihello.c started, answering 42
(borrow 'posix)
(chdir "/love")
(: (feed p) (open p "r" @ q (port? q ? (reads q, close q) (scare 'no-corpus-member p))))
(each ["test/00-init.l" "src/inle/uefi/menu.l"] feed)

; --- boot.l as rows: the defaults, the shell row last, what is not an entry passed over
(: c (bm-conf """(timeout 3) (default 1) ; a note
                 (entry "arch" "/vmlinuz.efi" "rw" "/initrd.img")
                 (entry "hello" "/hello.efi")
                 (entry 7) (bogus 1) (timeout -2)""")
   e (bm-conf ())
   torn (bm-conf """(timeout 2) (entry "a" """)
   far (bm-conf """(default 4) (entry "a" "/a.efi")""")
   (test
      (c 'timeout = 3) (c 'default = 1)
      (c 'rows = [["arch" "/vmlinuz.efi" "rw" "/initrd.img"] ["hello" "/hello.efi" "" ()] bm-shell])
      (e 'rows = [bm-shell]) (e 'timeout = 5) (e 'default = 0)
      (torn 'timeout = 2) (torn 'rows = [bm-shell])         ; a torn form ends the read
      (far 'default = 0)))                                  ; a default past the rows is the first

; --- the keys: arrows wrap, a key stops the timeout, e edits a line, enter or a digit picks
(: c (bm-conf """(timeout 3) (default 1) (entry "arch" "/vmlinuz.efi" "rw" "/initrd.img")
                 (entry "hello" "/hello.efi")""")
   arch (c 'rows 0) hello (c 'rows 1)
   st (bm-new c "")
   _ (test (st 'cur = 1) (0 < bm-left st <= 3))
   _ (bm-step c st -9)
   _ (test (st 'cur = 2) (nil? (st 'until)))
   _ (bm-step c st -9)
   _ (test (st 'cur = 0))
   _ (bm-step c st -8)
   _ (bm-step c st 101)
   _ (test (st 'cur = 2) (nil? (st 'edit)))             ; the shell has no line to edit
   _ (bm-step c st 106)
   _ (bm-step c st 101)
   _ (test (st 'cur = 0) (st 'edit = "rw"))
   _ (each (map " quietx" ^7) (bm-step c st))
   _ (bm-step c st 127)
   _ (test (st 'edit = "rw quiet") (nil? (st 'pick)))
   _ (bm-step c st 13)
   _ (test (st 'pick = [arch "rw quiet"]))
   s2 (bm-new c "")
   _ (bm-step c s2 57)
   _ (test (nil? (s2 'pick)))                           ; a digit past the rows
   _ (bm-step c s2 50)
   _ (test (s2 'pick = [hello ""]))
   s3 (bm-new c "")
   _ (bm-step c s3 101, bm-step c s3 21, bm-step c s3 120)
   _ (test (s3 'edit = "x"))                            ; ^U clears the line
   _ (bm-step c s3 27)
   (test (nil? (s3 'edit)) (nil? (s3 'pick))))          ; escape leaves it, the row's line kept

; --- the timeout: none at 0, the default once it runs out, a frame when the seconds move
(: c0 (bm-conf """(timeout 0) (entry "a" "/a.efi" "x")""")
   s0 (bm-new c0 "")
   c (bm-conf """(timeout 2) (entry "a" "/a.efi" "x") (entry "b" "/b.efi")""")
   s1 (bm-new c "")
   (test (nil? (s0 'until)) (bm-tick c0 s0 = 0)
         (bm-tick c s1 = 1) (bm-tick c s1 = 0) (nil? (s1 'pick))
         (pin s1 'until (clock 0 - 1), bm-tick c s1 = 1)
         (s1 'pick = [(c 'rows 0) "x"])))

; --- after a boot that came back the timeout runs to a reboot, and a key stops it; after the
; shell, or with no timeout, a key waits
(: log {}
   d {'reset (_ \ pin log 'r 1) 'boot (p \ cmd \ rd \ (pin log 'b p, -1014)) 'read (_ \ ()) 'shell (_ \ 0)}
   c (bm-conf """(timeout 2) (entry "a" "/a.efi" "x")""")
   c0 (bm-conf """(timeout 0) (entry "a" "/a.efi" "x")""")
   s0 (bm-visit c "" 1)
   s1 (bm-visit c "a: the firmware refused /a.efi, status 14" 0)
   s2 (bm-visit c "" 0)
   s3 (bm-visit c "a returned 3" 0)
   s4 (bm-visit c0 "a returned 3" 0)
   _ (test (nil? (s0 'back)) (0 < bm-left s0 <= 2)
           (s1 'back = 1) (0 < bm-left s1 <= 2) (0 <= findsub (bm-show c s1 60 12) "a reboot in ")
           (nil? (s2 'until)) (nil? (s4 'until)) (s3 'back = 1))
   _ (pin s1 'until (clock 0 - 1), bm-tick c s1)
   _ (test (s1 'pick = ['reset]))
   _ (bm-after c d s1)
   _ (test (log 'r = 1) (nil? (log 'b)))
   _ (bm-step c s3 -9)
   (test (nil? (s3 'until)) (bm-tick c s3 = 0) (nil? (s3 'pick))))

; --- the frame: the rows, the cursor's row in reverse, the word, the footer, h - 1 lines
(: c (bm-conf """(timeout 3) (default 1) (entry "arch" "/vmlinuz.efi" "rw") (entry "hello" "/hello.efi")""")
   st (bm-new c "arch returned 7")
   f (bm-show c st 40 12)
   (lines f) #(filter (b \ b = 10) (map f ^#f))
   _ (test (0 <= findsub f "1  arch") (0 <= findsub f (sgr 7 " 2  hello ")) (0 <= findsub f "3  love")
           (0 <= findsub f "arch returned 7") (0 <= findsub f "hello in 3s")
           (lines f = 8) (lines (bm-show c st 40 4) = 3))
   _ (bm-step c st 101)
   (test (0 <= findsub (bm-show c st 40 12) "hello: ")))

; --- the boot words through doors of the law's own; no boot.l is the shell alone
(: log {}
   d {'read (p \ p = "/initrd.img" ? "RD") 'boot (p \ cmd \ rd \ (pin log 'b [p cmd rd], log 'ans))
      'shell (_ \ pin log 'sh 1)}
   c (bm-conf """(entry "arch" "/vmlinuz.efi" "rw" "/initrd.img") (entry "nord" "/k.efi" "" "/gone.img")
                 (entry "plain" "/p.efi")""")
   arch (c 'rows 0) nord (c 'rows 1) plain (c 'rows 2)
   _ (pin log 'ans 42)
   _ (test (bm-boot d [arch "rw x"] = "arch returned 42") (log 'b = ["/vmlinuz.efi" "rw x" "RD"]))
   _ (pin log 'b ())
   _ (test (bm-boot d [nord ""] = "nord: no /gone.img") (nil? (log 'b)))
   _ (test (bm-boot d [plain ""] = "plain returned 42") (log 'b = ["/p.efi" "" ()]))
   _ (pin log 'ans -1014)
   _ (test (bm-boot d [plain ""] = "plain: the firmware refused /p.efi, status 14"))
   _ (pin log 'ans -2)
   _ (test (bm-boot d [plain ""] = "plain: /p.efi failed, -2"))
   _ (test (bm-boot d [bm-shell ""] = "") (log 'sh = 1))
   _ (pin log 'sh 0)
   _ (bm-main (pin d 'read (_ \ ())))
   (test (log 'sh = 1)))

; --- the firmware's doors: boot.l off the volume, an image started that answers back
(: b (efi-read "/boot.l")
   c (bm-conf b)
   d (bm-doors ())
   (test (string? b) (nil? (efi-read "/no-such"))
         (#(c 'rows) = 3) (c 'default = 1)
         (bm-boot d [(c 'rows 0) "one two"] = "efihello returned 42")
         (bm-boot d [(c 'rows 1) "three"] = "efihello, a ramdisk returned 42")
         (bm-boot d [["gone" "/gone.efi" "" ()] ""] @ m (0 <= findsub m "/gone.efi" && findsub m "returned" < 0))))

(feed "test/zz-fin.l")
