; test/host/libra.l -- libra, the .l balance tool (src/apps/libra/libra.l): the check and the
; doc lifter both read src/apps/libra/lint.l, so they agree on what a paren or a comment is
;   cat test/00-init.l test/host/libra.l | out/love

(borrow 'lint)          ; libra splices this, so the session asks too
(borrow 'salt)
(borrow 'libra)
(borrow 'lapiz)         ; the doc verb's surfaces, loaded on that verb alone

; no config anywhere; never (salt 'libra) here, which reads the machine's own ~/.love/etc/libra.l
(: lt-none {}
   (lt-conf prs) (foldl (t \ p \ (pin t <p >p, t)) {} prs))

; one warning is one line; the config rides in as an argument
(test
 (1 = #(lint-scan "(: a 1\n"))
 (1 = #(lint-of "(: a 1\n" lt-none))
 !(lint-scan "(: a 1)\n") !(lint-of "(: a 1)\n" lt-none))

; the config rules: the default is balance alone, (lint-scan src) = (lint-of src ()).
; a setting's value is the form's tail: (singleton 1) stores (1)
(: lt-sing (lt-conf [['singleton 1]])
   lt-dep  (lt-conf [['deprecated 'old-thing '(worse-thing "use better-thing")]])
   ; the 4th field is the rule, after line, column and text
   (lt-rule ws) (map (w \ <>>>w) ws)
   (lt-msg ws)  (map (w \ <>>w) ws))

(test
 !(lint-scan "(go)")
 (1 = #(lint-of "(go)" lt-sing))
 ('(singleton) = lt-rule (lint-of "(go)" lt-sing))
 ('(balance) = lt-rule (lint-scan "(: a 1\n")))

; a one-element form is that element; the position points at the opener
(test
 (: w <(lint-of "(: a 1\n   (go))" lt-sing) (2 = <w && 4 = <>w))
 (1 = #(lint-of "(0)" lt-sing))
 (1 = #(lint-of "((f x))" lt-sing))
 (1 = #(lint-of "foo(x)" lt-sing)))     ; two datums

; the three exemptions
(test
 ; 1. a constructor is a datum, and ' makes its contents data too
 !(lint-of "'(x)" lt-sing) !(lint-of "@(x)" lt-sing)
 !(lint-of "{x}" lt-sing)
 !(lint-of "'(a (b))" lt-sing)
 ; but a bracket list evaluates its elements
 (1 = #(lint-of "[a (b)]" lt-sing))
 ; 2. glued to an operator run: merged runs may lex as another operator (<(= x) vs <=x),
 ; and the scan has no operator table
 !(lint-of "(-(-5))" lt-sing) !(lint-of "<(<l)" lt-sing) !(lint-of ">(<l)" lt-sing)
 !(lint-of "<(= x)" lt-sing)
 ; 3. an all-punctuation token is the escape idiom: (+) is + as a value
 !(lint-of "(+)" lt-sing) !(lint-of "(*)" lt-sing) !(lint-of "(<=)" lt-sing)
 !(lint-of "(:)" lt-sing) !(lint-of "(?)" lt-sing) !(lint-of "(\\)" lt-sing)
 ; narrower than "starts with punctuation": (<>b) and <>b are one value
 (1 = #(lint-of "(<>b)" lt-sing)))

; the deprecated roster: a bare name, or `(name "hint")`
(test
 !(lint-scan "(f old-thing)")
 ("deprecated old-thing" = <(lt-msg (lint-of "(f old-thing)" lt-dep)))
 ("deprecated worse-thing -- use better-thing"
  = <(lt-msg (lint-of "(f worse-thing)" lt-dep)))
 ('(deprecated) = lt-rule (lint-of "(f old-thing)" lt-dep))
 (1 = #(lint-of "(f 'old-thing)" lt-dep))
 !(lint-of "; old-thing" lt-dep)
 !(lint-of "(f \"old-thing\")" lt-dep)
 !(lint-of "(f old-thing-x)" lt-dep)
 (2 = #(lint-of "(old-thing worse-thing)" lt-dep)))

; an imbalance is always fatal, an opinion never, whatever a config says
(test
 (fatal? <(lint-scan "(: a 1\n"))
 !(fatal? <(lint-of "(go)" lt-sing))
 !(fatal? <(lint-of "(f old-thing)" lt-dep)))

; doc: the header out of the file. lint-cmts reports every comment with its text, and a `;`
; inside a string is none
(: src "#!/usr/bin/env -S love -l
; two
;  three

; five
(: x \"a ; not a comment\"  ; six, to the right
   y 2)
; eight
"
   cs (lint-cmts src)
   (test (6 = tally cs)
         ('(1 1 "/usr/bin/env -S love -l" bang) = <cs)
         ('(2 1 " two" semi) = cs 1)
         ('(5 1 " five" semi) = cs 3)
         ('(6 27 " six, to the right" semi) = cs 4)
         ('(8 1 " eight" semi) = cs 5),
    0))

; the header: a #! line, an indented display, a blank inside, an indented sentence, a
; comment right of code (never the header), one under it
(: src "#!/usr/bin/env -S love -l
; the tool -- what it is for
;
;   a display, two spaces in
  ; and an indented line is still a sentence
; and back
;
(: run 1)   ; not the header
; nor this
"
   (test ('("the tool -- what it is for" "" "  a display, two spaces in"
            "  and an indented line is still a sentence" "and back")
          = ldoc-head src)
         ; an indented run is a display, dedented by its least indent
         (ldoc-md src = "the tool -- what it is for\n\n```\na display, two spaces in\nand an indented line is still a sentence\n```\nand back\n")
         (() = ldoc-head "(: x 1)\n; a tail comment\n")
         (() = ldoc-head "")
         ("" = ldoc-md "(: x 1)\n")
         ('("just this") = ldoc-head "; just this\n"),
    0))

; a banner is read as a section heading, and the body under it survives
(: d (mdread (ldoc-md "; --- a banner ---
; the body under it
(: x 1)
"))
   (test (2 = tally d)
         ('(head 2 ((text "a banner"))) = <d)
         ('(para ((text "the body under it"))) = d 1),
    0))

; the law, on real files that begin with a banner: the document keeps every alphanumeric of
; the header, so markdown's normalizations are not mistaken for loss
(:
   (alnum? c) (48 <= c && c <= 57 || 65 <= c && c <= 90 || 97 <= c && c <= 122)
   (bare s) ((: (g i acc) (i < tally s ? (g (i + 1) (alnum? (s i) ? (acc + string (s i)) acc)) acc))
             0 "")
   (itext l) (foldl (+) "" (map (x \ (<x @ t
                                        (? (t = 'text) <>x
                                           (t = 'code) <>x
                                           (t = 'link) (itext <>x + x 2)
                                           (t = 'strong || t = 'em) (itext <>x)
                                           ""))) l))
   (btext b) (<b @ t
                (? (t = 'head)  (itext (b 2))
                   (t = 'para)  (itext <>b)
                   (t = 'fence) (b 2)
                   (t = 'quote) (dtext <>b)
                   (t = 'bullets || t = 'numbers) (foldl (+) "" (map itext <>b))
                   (t = 'deflist) (foldl (+) "" (map (it \ (itext <it + itext <>it)) <>b))
                   ""))
   (dtext d) (foldl (+) "" (map btext d))
   (slurpf f) (open f "r" @ q (hot? q ? (slurp q) ""))
   (map (f \ (: src (slurpf f)
                head (foldl (+) "" (ldoc-head src))
                d (mdread (ldoc-md src))
                (test
                 (1 < tally d)
                 (0 < tally (bare head))
                 (bare head = bare (dtext d)))))
        ["src/apps/vi/hue.l" "src/apps/lush.l" "src/apps/libra/libra.l"],
    ; libra says markdown, lapiz says the rest
    (ldoc-md (slurpf "src/apps/vi/hue.l") @ md
     (test (0 < tally (md->ht md))
             (0 < tally (md->rf md)),
      0)),
    0))


; a banner is a section, a display a display, the prose never rewritten
(test
 ; a `--- name ---` banner is a level-2 heading
 (ldoc-md "; --- the table ------------------------------------------------\n; a row is a thing.\n(: x 1)\n"
  = "## the table\na row is a thing.\n")
 (ldoc-md "; --- the middle ---\n(: x 1)\n" = "## the middle\n")
 ; bare dashes are not
 (ldoc-md "; ---\n(: x 1)\n" = "---\n")
 ; a `usage:` line and the indented lines under it are one display
 (ldoc-md "; usage:  tool [-x] FILE ..    do the thing\n;     or: love -l tool.l FILE\n; and prose after it.\n(: x 1)\n"
  = "```\nusage:  tool [-x] FILE ..    do the thing\n    or: love -l tool.l FILE\n```\nand prose after it.\n")
 ; an indent under a list item is a wrap, lapiz's lazy continuation
 (ldoc-md "; - a bullet that wraps onto\n;   a second line\n; - and one that does not\n(: x 1)\n"
  = "- a bullet that wraps onto\n  a second line\n- and one that does not\n")
 (mdread (ldoc-md "; - a bullet that wraps onto\n;   a second line\n(: x 1)\n")
  = '((bullets (((text "a bullet that wraps onto a second line"))))))
 (ldoc-md "; a plain line, and it stays one.\n(: x 1)\n" = "a plain line, and it stays one.\n")
 (ldoc-md "; prose.\n; a second line fills into it.\n(: x 1)\n"
  = "prose.\na second line fills into it.\n"))

; a real header comes out with headings, which papel reads a page's title and nav from
(: (rd f) (open f "r" @ q (hot? q ? (slurp q) ""))
   d (mdread ("# src/apps/lapiz.l\n\n" + ldoc-md (rd "src/apps/lapiz.l")))
   heads (filter (b \ (<b = 'head)) d)
   (test (3 < tally heads)
         ('(head 1 ((text "src/apps/lapiz.l"))) = <heads)
         (2 = <>(heads 1))
         (0 < tally (filter (b \ (<b = 'fence)) d)),
    0))

(test_fin ())
(puts "libra: ok")
(putc 10)
