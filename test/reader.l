; the reader's laws, compared structurally, never by printing: the printer shows (mono (< x)) as `<x`
(: (rdr s) (sound s @ r (two? r ? <r r)))

; --- the read protocol: (datum . rest), () at a clean end, or `torn` inside a shape ---
; presence is the cons, never the net: "()" reads a datum
(test
 (sound '(49) @ r (two? r && 1 = <r && !>r))                   ; a datum, nothing after
 !(sound ())                                          ; a clean end
 ('torn = sound '(40))                              ; the text ran out inside a shape
 (sound '(49 32 50) @ r                               ; the residue reads the next
  (1 = <r && 2 = <(sound >r)))
 (sound '(40 41) @ r (two? r && !<r))                   ; the datum () is still a datum
 ; a charlist whose tail is a number: the tail is its residue as it stands, as a name's is
 (sound (cons 97 5) @ r ('a = <r && 5 = >r))
 (sound (cons 97 0) @ r ('a = <r && 0 = >r && charm? >r))
 (sound (cons 97 (cons 32 1)) @ r ('a = <r && 1 = >>r)))

; --- the string door: an empty string, or a value with no text, is a clean end ---
(test
 (sound "(1 2) 3" @ r
  ('(1 2) = <r && 3 = <(sound >r)))                    ; ...and the residue resumes
 (sound "1" @ r (two? r && 1 = <r))
 !(sound "")                                          ; empty text: a clean end, not torn
 ('torn = sound "(1")
 !(sound 42) !(sound 'notaport)                       ; nothing to read is a clean end
 ((sound "(1 2) 3") = sound (map "(1 2) 3" ^7)))  ; the two doors agree, datum and rest

; --- the port door: the datums agree with the string's. a tap gulps a byte at a time,
; so every lookahead re-forces a remembered tail ---
(: (rdr-all x)                                      ; every datum of a text, in order
   (: (go cl acc) (sound cl @ r
                   (? (two? r)      (go >r (<r . acc))
                      (r = 'torn) 'torn
                      (rev acc)))
      (go x ()))
   (rdr-doors s) (: cl (map s (jot #s))
                    d (rdr-all s)
                    (d = rdr-all cl && d = rdr-all (tap cl))))
(test
 (: p (tap (map "(1 2) 3" ^7)) r (sound p)
    ('(1 2) = <r && 3 = <(sound >r)))                     ; a port, and its residue resumes
 !(sound (tap ()))                                  ; a spent port is a clean end
 !(sound (jug 0))                                   ; ...and so is one with no read door
 ('torn = sound (tap (map "(1" ^2)))              ; torn reads torn off a port too
 (rdr-doors "(1 2) 3 \"hi\" 'q")
 (rdr-doors "#!/usr/bin/env love\n(a b)")           ; the lookahead: 3 forces
 (rdr-doors "\"\\x41\\x42\" 7")                     ; the \xnn lane: 2 forces
 (rdr-doors "; comment\n(a . b) {1 2} @(3) (0 ~ 1)")
 (rdr-doors "map (+ 1) '(1 2 3)")                   ; an operator run, glued and spaced
 (rdr-doors "1.5e3 -2 0xff 1/2 [a b] {c d}"))

; --- a promise at every byte: tokens, texts and comments read as the string does, in linear time
(: (rdr-drip s i) (i < #s ? (s i . (u \ rdr-drip s (i + 1))))
   (rdr-dripped s) (<(sound (rdr-drip s 0)) = <(sound s))
 (test (rdr-dripped "abc-def 7") (rdr-dripped "2?<>x") (rdr-dripped "\"a \\x41\\u{e9} \\(1 + 2) b\" 3")
       (rdr-dripped "\"\"\"raw \" text\"\"\"") (rdr-dripped "; a comment\n(a . b)")
       (rdr-dripped "#!/usr/bin/env love\n(a b)")
       (test-linear-words (n \ sound (rdr-drip ("a" * n) 0)) 16000)
       (test-linear-words (n \ sound (rdr-drip ("\"" + "a b " * n + "\"") 0)) 4000)
       (test-linear-words (n \ sound (rdr-drip ("; " + "c" * n + "\n7") 0)) 16000)))

; --- the lexer: a name token keeps - ? ! and the prime inside it; a punct-led token is a sigil
(test
 ('old-thing = rdr "old-thing")                     ; - inside a name
 ('nl->sp = rdr "nl->sp")                           ; ...and -> inside one too
 ('x? = rdr "x?") ('x! = rdr "x!")
 ("x'" = (string (rdr "x'")))                         ; the prime: x' is a name
 ('<= = rdr "<= "))                                 ; a spaced run is a plain symbol

; --- comments: `;` and `#!` run to end of line ---
(test
 (7 = rdr "; nope
7")
 (7 = rdr "#! nope ( ( \"
7"))

; --- strings: "..." with \ escapes; an unterminated one is torn ---
(test
 ("hi" = rdr "\"hi\"")
 ("a\"b" = rdr "\"a\\\"b\"")
 ("" = rdr "\"\"")
 ('torn = sound "\"oops"))

; --- numbers: an integer reads at full precision in all three bases, the same in every build ---
(test
 (3 = rdr "3") (-3 = rdr "-3") (3 = rdr "+3")
 (16 = rdr "0x10") (255 = rdr "0xff") (255 = rdr "0XFF")  ; hex, either case
 (-255 = rdr "-0xff") (255 = rdr "+0xff")
 (493 = rdr "0755") (7 = rdr "007") (0 = rdr "00")        ; octal, the leading zero its whole prefix
 ((0 - (1 / 2)) = rdr "-.5") ((1 / 2) = rdr "+.5")
 (18446744073709551615 = rdr "18446744073709551615")          ; decimal above the word: a big
 (18446744073709551615 = rdr "0xffffffffffffffff")
 (18446744073709551615 = rdr "01777777777777777777777")
 (18446744071564165120 = rdr "0xffffffff80200000")            ; a high-half address
 (9223372036854775807 = rdr "0x7fffffffffffffff")             ; 2^63-1
 (340282366920938463463374607431768211455 = rdr "0xffffffffffffffffffffffffffffffff")
 (73786976294838206463 = rdr "007777777777777777777777")      ; 2^66-1, octal
 ; a prefix with no digits is a symbol; 08 is neither octal nor decimal, so it reads as a float
 ('0x = rdr "0x") ('0xg = rdr "0xg") ('0b101 = rdr "0b101")
 (8.0 = rdr "08"))

; --- quote and the constructor wraps: ' quotes and @ builds a tuple, glued to the datum ---
(test
 ('(\ x) = rdr "'x")
 ('(hash a b) = rdr "{a b}")
 ('(tuple 1 2) = rdr "@(1 2)")
 ('(0 ~ 1) = rdr "(0 ~ 1)")                         ; ~ spaced is a plain symbol
 ('(mono (~ x)) = rdr "~x")                         ; ~ glued is conj
 ; the empty collections go to a one-arg nif; every emission is ()-tailed
 ('(tablet 0) = rdr "{}")
 ('(iota 0) = rdr "@()")
 (() = >>(rdr "{}"))
 (() = >>(rdr "<x")))

; --- the valence law: a glued run emits (mono (run datum)), spaced the plain symbol.
; : and ? do not fuse at head; \ never fuses ---
(test
 ('(mono (< x)) = rdr "<x")
 ('(f (mono (< x))) = rdr "(f <x)")
 ('(mono (<> b)) = rdr "<>b")
 ('(< x) = rdr "(< x)")                             ; spaced: no wrap
 ('(: a 1) = rdr "(: a 1)")                         ; : at head is not fused
 ('(mono (! -5)) = rdr "!-5"))                      ; the shed: ! then -5

; --- + and - are operator runs, but a digit or `.` right after them makes a numeral.
; --5 sheds a - before the digit, ++5 is split by opfix: two lanes, both asserted ---
(test
 ('(mono (- -5)) = rdr "--5")       (5 = --5)
 ('(mono (++ 5)) = rdr "++5")       (5 = ++5)
 ('(mono (-- -5)) = rdr "---5")     (-5 = ---5)
 ('(mono (-+ 5)) = rdr "-+5")       (-5 = -+5)
 ('(mono (- x)) = rdr "-x")
 ('(mono (+ x)) = rdr "+x")
 (-3 = rdr "-3") (3 = rdr "+3")
 ('- = rdr "- x")                                   ; a lone - is the symbol
 ('(mono (- (f x))) = rdr "-(f x)")                 ; glued to a form: negate
 ('(mono (+ (tuple 3 4))) = rdr "+@(3 4)"))         ; ...or to a constructor

; --- the opener carries the wrap; the closers are one, so a crossed pair reads silently ---
(test
 ('(list a b) = rdr "[a b]")          ('(hash a b) = rdr "{a b}")
 ('(list) = rdr "[]")                 ('(tablet 0) = rdr "{}")
 ('(list (list a b) (list c d)) = rdr "[[a b] [c d]]")   ; the nest is the whole point
 ((rdr "-(list 1 2)") = rdr "-[1 2]")               ; and it glues like a form does
 ('(list a b) = rdr "[a b)") ('(a b) = rdr "(a b]")    ; a crossed pair, silent
 (() = rdr "()") !(0 = rdr "()")
 (', = rdr ","))                                    ; the comma is its own datum

; --- @ over any opener renames the wrap: @[1 2] is @(1 2). ' is no constructor, it quotes the form.
; spaced, @ is the plain symbol, the match head ---
(test
 ((rdr "@(1 2 3)") = rdr "@[1 2 3]") ((rdr "@()") = rdr "@[]")
 ((rdr "@(a b)") = rdr "@{a b}")
 ((rdr "@(1 2)") = rdr "@[1 2]")
 ('@ = rdr "@ [1 2]") ('(@ x (list _a b) b) = rdr "(@ x [_a b] b)")  ; @ reads glue
 ('(\ (list a b)) = rdr "'[a b]")                   ; ' is not a constructor: it quotes the form
 ('(\ (tuple 1 2)) = rdr "'@(1 2)")                 ; sigil over sigil still stacks
 ('torn = rdr "@["))
