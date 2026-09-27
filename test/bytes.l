; 'bytes: words in and out of byte strings, either end first
(: rdle (cite 'bytes 'rdle) rdbe (cite 'bytes 'rdbe) wrle (cite 'bytes 'wrle)
   wrbe (cite 'bytes 'wrbe) padk (cite 'bytes 'padk) zbytes (cite 'bytes 'zbytes)
   b2hex (cite 'bytes 'b2hex) hex2b (cite 'bytes 'hex2b) xorb (cite 'bytes 'xorb)
   (test
      (wrle 258 2 = "\x02\x01") (wrbe 258 2 = "\x01\x02") (wrle 1 0 = "")
      (wrle -1 2 = "\xff\xff") (wrle 65536 2 = "\x00\x00")   ; the low n bytes, two's complement
      (rdle "\x02\x01" 0 2 = 258) (rdbe "\x01\x02" 0 2 = 258) (rdle "xx\x01" 2 1 = 1)
      (rdle [2 1] 0 2 = 258)                                  ; a list reads the same
      (rdle (wrle (2 ** 64 - 1) 8) 0 8 = 2 ** 64 - 1)         ; a big both ways
      (rdbe (wrbe (2 ** 64 - 2) 8) 0 8 = 2 ** 64 - 2)
      (padk 0 4 = 0) (padk 5 4 = 3) (padk 8 4 = 0) (padk 513 512 = 511)
      (zbytes 3 = "\x00\x00\x00") (zbytes 0 = "")
      (b2hex "\x00\xab\x7f" = "00ab7f") (hex2b "00AB7f" = "\x00\xab\x7f") (b2hex "" = "")
      (xorb "\x0f\xf0" "\xff\xff" = "\xf0\x0f")))
