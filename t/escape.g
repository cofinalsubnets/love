; string-literal escape sequences. the C reader (g.c:g_read1) parses this
; source file at load time; the second block exercises the same reader via
; the charlist port (g.c:ci_getc, used by the REPL submit path) so the
; in-memory edit buffer agrees with file input.

(assert
  ; --- C reader path: this file is parsed by it ---
  ; \n / \t / \r / \0 become 1-byte strings with the corresponding byte.
  (= 1 (len "\n"))           (= "\n" (str (X 10 0)))
  (= 1 (len "\t"))           (= "\t" (str (X 9 0)))
  (= 1 (len "\r"))           (= "\r" (str (X 13 0)))
  (= 1 (len "\0"))           (= "\0" (str (X 0 0)))
  ; \xHH: two hex digits.
  (= 1 (len "\x00"))         (= "\x00" (str (X 0 0)))
  (= 1 (len "\x41"))         (= "\x41" (str (X 65 0)))
  (= 1 (len "\xff"))         (= "\xff" (str (X 255 0)))
  (= "\x41" "A")             (= "\x0a" "\n")
  (= "\xAB" "\xab")          ; mixed case
  ; \\ and \" still pass through via the take-next-char-as-is fallback.
  (= 1 (len "\\"))           (= "\\" (str (X 92 0)))
  (= 1 (len "\""))           (= "\"" (str (X 34 0)))
  ; embedded mid-string
  (= 3 (len "a\nb"))         (= "a\nb" (str (X 97 (X 10 (X 98 0)))))
  (= 3 (len "a\tb"))         (= "a\tb" (str (X 97 (X 9  (X 98 0)))))
  (= 3 (len "a\rb"))         (= "a\rb" (str (X 97 (X 13 (X 98 0)))))
  (= 3 (len "a\0b"))         (= "a\0b" (str (X 97 (X 0  (X 98 0)))))
  (= 3 (len "a\x42b"))       (= "a\x42b" (str (X 97 (X 66 (X 98 0))))))

; --- charlist port path: feed the C reader a charlist of `"..."` source.
; this round-trips through ci_getc, which is the editor's submit path.
(:
 ; chars-of-source-with-quotes -> the parsed datum.
 (parse cl) (car (cdr (parsecl cl)))
 (assert
   (= (str (X 10 0))                   (parse '(34 92 110 34)))   ; "\n"
   (= (str (X 9 0))                    (parse '(34 92 116 34)))   ; "\t"
   (= (str (X 13 0))                   (parse '(34 92 114 34)))   ; "\r"
   (= (str (X 0 0))                    (parse '(34 92 48 34)))    ; "\0"
   (= (str (X 92 0))                   (parse '(34 92 92 34)))    ; "\\"
   (= (str (X 34 0))                   (parse '(34 92 34 34)))    ; "\""
   ; \xHH: 120='x', then 2 hex digits
   (= (str (X 0 0))                    (parse '(34 92 120 48 48 34)))    ; "\x00"
   (= (str (X 65 0))                   (parse '(34 92 120 52 49 34)))    ; "\x41" = 'A'
   (= (str (X 255 0))                  (parse '(34 92 120 102 102 34)))  ; "\xff"
   (= (str (X 171 0))                  (parse '(34 92 120 65 66 34)))    ; "\xAB"
   (= (str (X 97 (X 10 (X 98 0))))     (parse '(34 97 92 110 98 34)))   ; "a\nb"
   (= (str (X 97 (X  9 (X 98 0))))     (parse '(34 97 92 116 98 34)))   ; "a\tb"
   (= (str (X 97 (X 13 (X 98 0))))     (parse '(34 97 92 114 98 34)))   ; "a\rb"
   (= (str (X 97 (X  0 (X 98 0))))     (parse '(34 97 92 48 98 34)))    ; "a\0b"
   (= (str (X 97 (X 66 (X 98 0))))     (parse '(34 97 92 120 52 50 98 34))))) ; "a\x42b"
