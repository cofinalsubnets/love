; test/host/quit.l -- love leaves the process as it found it: quit drains each port's buffered
; bytes, and a scare gives a piped stdin back blocking, so a reader after it waits
; run: cat test/00-init.l test/host/quit.l | out/love
(: open (cite 'posix 'open)
   d "out/.quitd"
   f "\(d)/put.txt"
   pr "\(d)/put.l"
   _ (hark ["mkdir" "-p" d])
   _ (open pr "w" @ p (say p "(: open (cite 'posix 'open) (open \"\(f)\" \"w\" @ p (put p 104, put p 105, quit 0)))", close p))
   _ (test (<(hark ["out/love" pr]) = 0))
   _ (test (>(hark ["cat" f]) = "hi"))
   s (hark ["sh" "-c" "(sleep 1; echo z) | (out/love -e \"(scare 'x 1)\" 2>/dev/null; cat)"])
   _ (test (s = (0 . "z\n")))
   _ (hark ["rm" "-rf" d])
   0)
(test_fin (), puts "quit: ok", putc 10, 0)
