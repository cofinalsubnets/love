; string-literal escape sequences. the C reader (g.c:g_read1) parses this
; source file at load time; the second block exercises the same reader via
; the charlist port (g.c:ci_getc, used by the REPL submit path) so the
; in-memory edit buffer agrees with file input.

(assert
  ; --- C reader path: this file is parsed by it ---
  ; \n / \t / \r / \0 become 1-byte strings with the corresponding byte.
  (= 1 (pin "\n"))           (= "\n" (string (X 10 0)))
  (= 1 (pin "\t"))           (= "\t" (string (X 9 0)))
  (= 1 (pin "\r"))           (= "\r" (string (X 13 0)))
  (= 1 (pin "\0"))           (= "\0" (string (X 0 0)))
  ; \xHH: two hex digits.
  (= 1 (pin "\x00"))         (= "\x00" (string (X 0 0)))
  (= 1 (pin "\x41"))         (= "\x41" (string (X 65 0)))
  (= 1 (pin "\xff"))         (= "\xff" (string (X 255 0)))
  (= "\x41" "A")             (= "\x0a" "\n")
  (= "\xAB" "\xab")          ; mixed case
  ; \\ and \" still pass through via the take-next-char-as-is fallback.
  (= 1 (pin "\\"))           (= "\\" (string (X 92 0)))
  (= 1 (pin "\""))           (= "\"" (string (X 34 0)))
  ; embedded mid-string
  (= 3 (pin "a\nb"))         (= "a\nb" (string (X 97 (X 10 (X 98 0)))))
  (= 3 (pin "a\tb"))         (= "a\tb" (string (X 97 (X 9  (X 98 0)))))
  (= 3 (pin "a\rb"))         (= "a\rb" (string (X 97 (X 13 (X 98 0)))))
  (= 3 (pin "a\0b"))         (= "a\0b" (string (X 97 (X 0  (X 98 0)))))
  (= 3 (pin "a\x42b"))       (= "a\x42b" (string (X 97 (X 66 (X 98 0))))))

; --- charlist port path: feed the C reader a charlist of `"..."` source
; through the ci synth port (the editor's submit path).
(:
 ; chars-of-source-with-quotes -> the parsed datum.
 (parse cl) (fread (strin cl) 0)
 (assert
   (= (string (X 10 0))                   (parse '(34 92 110 34)))   ; "\n"
   (= (string (X 9 0))                    (parse '(34 92 116 34)))   ; "\t"
   (= (string (X 13 0))                   (parse '(34 92 114 34)))   ; "\r"
   (= (string (X 0 0))                    (parse '(34 92 48 34)))    ; "\0"
   (= (string (X 92 0))                   (parse '(34 92 92 34)))    ; "\\"
   (= (string (X 34 0))                   (parse '(34 92 34 34)))    ; "\""
   ; \xHH: 120='x', then 2 hex digits
   (= (string (X 0 0))                    (parse '(34 92 120 48 48 34)))    ; "\x00"
   (= (string (X 65 0))                   (parse '(34 92 120 52 49 34)))    ; "\x41" = 'A'
   (= (string (X 255 0))                  (parse '(34 92 120 102 102 34)))  ; "\xff"
   (= (string (X 171 0))                  (parse '(34 92 120 65 66 34)))    ; "\xAB"
   (= (string (X 97 (X 10 (X 98 0))))     (parse '(34 97 92 110 98 34)))   ; "a\nb"
   (= (string (X 97 (X  9 (X 98 0))))     (parse '(34 97 92 116 98 34)))   ; "a\tb"
   (= (string (X 97 (X 13 (X 98 0))))     (parse '(34 97 92 114 98 34)))   ; "a\rb"
   (= (string (X 97 (X  0 (X 98 0))))     (parse '(34 97 92 48 98 34)))    ; "a\0b"
   (= (string (X 97 (X 66 (X 98 0))))     (parse '(34 97 92 120 52 50 98 34))))) ; "a\x42b"
