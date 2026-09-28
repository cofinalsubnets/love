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

; 'text: utf-8 read as characters, and the columns a terminal gives them. a bad sequence is one
; U+FFFD per byte; the widths are glibc's, so a prompt lines up where the terminal draws it
(: cpat (cite 'text 'cpat) cpnext (cite 'text 'cpnext) cps (cite 'text 'cps)
   cplen (cite 'text 'cplen) cpsnip (cite 'text 'cpsnip) cprev (cite 'text 'cprev)
   wcwidth (cite 'text 'wcwidth) swidth (cite 'text 'swidth) scut (cite 'text 'scut)
   (test
      (cps "a日本語é" = [97 26085 26412 35486 233]) (cps "" = ()) (cplen "a日本語é" = 5)
      (cps (utf8 128512) = [128512]) (cps (utf8 1114111) = [1114111])
      (cpat "a日" 1 = 26085) (cpnext "a日" 1 = 4) (cpnext "a日" 0 = 1)
      (cps "\xc0\x80" = [65533 65533])                     ; overlong
      (cps "\xed\xa0\x80" = [65533 65533 65533])           ; a surrogate
      (cps "\xe2\x82" = [65533 65533]) (cps "\x80a" = [65533 97])   ; torn, stray
      (cps "\xf4\x90\x80\x80" = [65533 65533 65533 65533]) ; past U+10FFFF
      (cpsnip "a日本語é" 1 3 = "日本") (cpsnip "a日" 1 9 = "日") (cpsnip "a日" 2 1 = "")
      (cprev "a日本語é" = "é語本日a") (cprev "" = "") (cprev "\xe2\x82a" = "a\x82\xe2")
      (wcwidth 65 = 1) (wcwidth 0 = 0) (wcwidth 10 = -1) (wcwidth 127 = -1) (wcwidth 159 = -1)
      (wcwidth 173 = 1) (wcwidth 768 = 0) (wcwidth 8203 = 0) (wcwidth 4448 = 0)
      (wcwidth 19968 = 2) (wcwidth 44032 = 2) (wcwidth 65313 = 2) (wcwidth 128512 = 2)
      (wcwidth 4447 = 2) (wcwidth 12872 = 2) (wcwidth 19904 = 2) (wcwidth 1114112 = -1)
      (swidth "a日本語é" = 8) (swidth "e\xcc\x81" = 1) (swidth "a\tb" = 2) (swidth "" = 0)
      (scut "a日本語é" 4 = "a日") (scut "a日本語é" 3 = "a日") (scut "a日本語é" 99 = "a日本語é")
      (scut "e\xcc\x81x" 1 = "e\xcc\x81") (scut "日" 1 = "")))

; cli's field measures ride 'text: a column is a column however many bytes wear it
(: edwide (cite 'cli 'edwide) edcut (cite 'cli 'edcut) edfit (cite 'cli 'edfit)
   (test
      (edwide "\e[1m日本\e[0m>" = 5) (edwide "abc" = 3) (edwide "e\xcc\x81" = 1)
      (edwide "a\tb" = 3) (edfit "a\tb" 4 " " = "a\tb ")   ; an ascii byte is a column, a tab too
      (edcut "日本語" 3 = "日") (edcut "日本語" 4 = "日本") (edcut "abc" 9 = "abc")
      (edcut "\e[31mab\e[0mcd" 2 = "\e[31mab\e[0m")        ; a cut coloured run ends in a reset
      (edcut "e\xcc\x81x" 1 = "e\xcc\x81")                  ; the combining mark rides its base
      (edfit "日本語" 3 "." = "日.") (edfit "日" 4 " " = "日  ")))

; 'text's classes and case maps: glibc 2.44's, off tools/mkctype.l. grep -i folds by cpfold,
; gnulib's rule, which is not symmetric: U+1C80 takes U+0412, and U+0412 does not take it
(: cpupper (cite 'text 'cpupper) cplower (cite 'text 'cplower) cpis (cite 'text 'cpis)
   cpclass? (cite 'text 'cpclass?) cpfold (cite 'text 'cpfold) cpfolds (cite 'text 'cpfolds)
   (test
      (cpupper 97 = 65) (cpupper 65 = 65) (cpupper 233 = 201) (cpupper 255 = 376)
      (cpupper 383 = 83) (cpupper 305 = 73) (cpupper 962 = 931) (cpupper 26085 = 26085)
      (cplower 201 = 233) (cplower 304 = 105) (cplower 8490 = 107) (cplower 7838 = 223)
      (cplower 256 = 257) (cplower 257 = 257) (cpupper 257 = 256)   ; latin extended, stride 2
      (cpis "alpha" 233) (cpis "alpha" 26085) (cpis "alpha" 1635) !(cpis "digit" 1635)
      (cpis "alnum" 1635) !(cpis "alpha" 48) (cpis "alnum" 48)       ; a digit past 0-9 is alpha
      (cpis "upper" 201) !(cpis "upper" 233) (cpis "lower" 223) (cpis "lower" 42799)
      (cpis "punct" 8212) (cpis "punct" 160) (cpis "graph" 160) !(cpis "space" 160)
      (cpis "space" 8195) (cpis "blank" 8195) (cpis "space" 8232) !(cpis "blank" 8232)
      (cpis "cntrl" 133) (cpis "cntrl" 8232) !(cpis "print" 8232) !(cpis "print" 55296)
      (cpis "xdigit" 70) !(cpis "xdigit" 71) (cpclass? "punct") !(cpclass? "foo")
      (sort (cpfold 115) = [83 383]) (sort (cpfold 105) = [73 305]) (cpfold 304 = ())
      (cpfold 107 = [75]) (cpfold 8490 = ()) (sort (cpfold 963) = [931 962])
      (sort (cpfold 7296) = [1042 1074]) !(elem 7296 (cpfold 1042))
      (cpfold 49 = ()) (sort (cpfolds 97 99) = [65 66 67])))
