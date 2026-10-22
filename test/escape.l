; string-literal escapes, read from this file and again through a charlist port

(test
  ; --- C reader path: this file is parsed by it ---
  ; \n / \t / \r / \0 become 1-byte strings with the corresponding byte.
  (1 = tally "\n")           ("\n" = string [10])
  (1 = tally "\t")           ("\t" = string [9])
  (1 = tally "\r")           ("\r" = string [13])
  (1 = tally "\0")           ("\0" = string [0])
  ; \xhh: two hex digits.
  (1 = tally "\x00")         ("\x00" = string [0])
  (1 = tally "\x41")         ("\x41" = string [65])
  (1 = tally "\xff")         ("\xff" = string [255])
  ("\x41" = "A")             ("\x0a" = "\n")
  ("\xAB" = "\xab")          ; mixed case
  ; \\ and \" take the next char as is.
  (1 = tally "\\")           ("\\" = string [92])
  (1 = tally "\"")           ("\"" = string [34])
  ; embedded mid-string
  (3 = tally "a\nb")         ("a\nb" = string [97 10 98])
  (3 = tally "a\tb")         ("a\tb" = string [97 9 98])
  (3 = tally "a\rb")         ("a\rb" = string [97 13 98])
  (3 = tally "a\0b")         ("a\0b" = string [97 0 98])
  (3 = tally "a\x42b")       ("a\x42b" = string [97 66 98]))

; --- charlist port path: the reader fed a charlist of `"..."` source
(:
 ; chars-of-source-with-quotes -> the parsed datum.
 (parse cl) <(sound cl)
 (test
   (string [10] = parse '(34 92 110 34)) ; "\n"
   (string [9] = parse '(34 92 116 34))  ; "\t"
   (string [13] = parse '(34 92 114 34)) ; "\r"
   (string [0] = parse '(34 92 48 34))   ; "\0"
   (string [92] = parse '(34 92 92 34))  ; "\\"
   (string [34] = parse '(34 92 34 34))  ; "\""
   ; \xhh: 120='x', then 2 hex digits
   (string [0] = parse '(34 92 120 48 48 34))                        ; "\x00"
   (string [65] = parse '(34 92 120 52 49 34))                       ; "\x41" = 'A'
   (string [255] = parse '(34 92 120 102 102 34))                    ; "\xff"
   (string [171] = parse '(34 92 120 65 66 34))                      ; "\xab"
   (string [97 10 98] = parse '(34 97 92 110 98 34))         ; "a\nb"
   (string [97 9 98] = parse '(34 97 92 116 98 34))         ; "a\tb"
   (string [97 13 98] = parse '(34 97 92 114 98 34))         ; "a\rb"
   (string [97 0 98] = parse '(34 97 92 48 98 34))          ; "a\0b"
   (string [97 66 98] = parse '(34 97 92 120 52 50 98 34)))) ; "a\x42b"

; \u{h..}: one to six hex digits naming a code point, laid as its utf-8 bytes, or \uhhhh
; just four. anything else after \u is no escape and reads as the letter, the rest as written
(test
  ("\u{41}" = "A")                ("\u{0}" = "\0")
  ("\u{e9}" = "\xc3\xa9")         ("\u{E9}" = "\u{e9}")
  ("\u{20ac}" = "\xe2\x82\xac")   ("\u{1f600}" = "\xf0\x9f\x98\x80")
  ("\u{65e5}\u{672c}" = "日本")   ("a\u{65e5}b" = "a日b")
  ("\u{7ff}" = "\xdf\xbf")        ("\u{800}" = "\xe0\xa0\x80")
  ("\u{ffff}" = "\xef\xbf\xbf")   ("\u{10000}" = "\xf0\x90\x80\x80")
  ("\u{10ffff}" = "\xf4\x8f\xbf\xbf")
  ("\u" = "u")                    ("\uab" = "uab")
  ("\u0041" = "A")                ("\u00e9" = "\u{e9}")          ; four digits, no braces
  ("\u280b" = "⠋")                ("\u20AC5" = "\u{20ac}5")      ; a fifth digit is the text's
  ("\ud800" = "ud800")            ("\u12g4" = "u12g4")            ; a surrogate, a non-digit
  ("\u{}" = "u{}")                ("\u{110000}" = "u{110000}")    ; none, and past unicode
  ("\u{d800}" = "u{d800}")        ("\u{dfff}" = "u{dfff}")        ; a surrogate is no character
  ("\u{0000041}" = "u{0000041}")  ("\u{4g}" = "u{4g}")            ; seven digits, a non-digit
  ('torn = sound '(34 92 117 123 52 49))
  ('torn = sound '(34 92 117 50 56)))                         ; input ending inside one

; raw texts: n quotes open and n close, nothing escapes; when the opener ends its line
; the closer's indent comes off every line, and the breaks beside the quotes go
(test
  ("""a\nb""" = "a\\nb")          ("""say "hi"""" = "say \"hi\"")
  (""""has """ in"""" = "has \"\"\" in")
  ("""
   one
     two

   three
   """ = "one\n  two\n\nthree")
  ("""
  a
""" = "  a")
  ("""
   """ = "")
  ("""
   a """ b
   """ = "a \"\"\" b")
  ((sound "\"\" \"x\"" @ r [<r <(sound >r)]) = ["" "x"])          ; two strings, spaced
  ('torn = sound '(34 34 34 10 32 97 10))                         ; no closing line
  ('torn = sound '(34 34 34 97 98)))

; holes: \( reads a form to its closer, and the text runs on. a string is laid as it is,
; anything else shown; a text without one is just itself
(: esc-c 7 esc-l [1 2 3])
(test
  ("cycle \(esc-c) of \(#esc-l)" = "cycle 7 of 3")
  ("\(esc-c - 1)\(esc-c + 1)" = "68")
  ("a \("b") c" = "a b c")                 ("\(quote q) \(esc-l)" = "q (1 2 3)")
  ("n \("in \(esc-c)") m" = "n in 7 m")    ("\\(x)" = "\\" + "(x)")
  ((sound "\"a \\(x) b\"") = [['weave ['list "a " '(x) " b"]]])
  ((sound "\"\\(#l) \\(# l)\"") = [['weave ['list (cap (sound "(#l)")) " " '(# l)]]])
  ('torn = sound "\"a \\(x")             ('torn = sound "\"a \\(x) b"))
