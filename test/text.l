; post.l's byte and text floor: the classes, the digit readers, radix and utf-8 out
(test
 (digit? 48) (digit? 57) !(digit? 47) !(digit? 58) !(digit? 97)
 (alpha? 65) (alpha? 122) !(alpha? 64) !(alpha? 91) !(alpha? 48)
 (alnum? 48) (alnum? 90) !(alnum? 95) !(alnum? 32)
 (1 = digit? 48) (0 = digit? 32)                      ; a ?-name owes a bit
 (0 = hexv 48) (9 = hexv 57) (10 = hexv 97) (15 = hexv 70)
 (-1 = hexv 103) (-1 = hexv 71) (-1 = hexv 32)         ; -1, never (): 0 is a digit
 (8080 = unum "8080") !(unum "") !(unum "8a") !(unum "-1")
 (radix 255 16 = "ff") (radix 8 8 = "10") (radix 0 16 = "0")
 (radix (2 ** 64) 16 = "10000000000000000")           ; a big is past putbn's reach
 (radix (2 ** 64 - 1) 16 = "ffffffffffffffff") (radix (2 ** 70) 2 = "1" + zpad 70 "")
 (radix (0 - 2 ** 64) 16 = "-10000000000000000")
 (zpad 4 "7" = "0007") (zpad 1 "77" = "77") (zpad 2 "" = "00")
 (utf8 65 = "A") (utf8 233 = "\xc3\xa9") (utf8 8364 = "\xe2\x82\xac")
 (utf8 128512 = "\xf0\x9f\x98\x80")
 (1 = #(utf8 127)) (2 = #(utf8 128)) (2 = #(utf8 2047)) (3 = #(utf8 2048))
 (3 = #(utf8 65535)) (4 = #(utf8 65536)) (4 = #(utf8 1114111))
 (utf8 1114112 = "") (utf8 -1 = ""))
