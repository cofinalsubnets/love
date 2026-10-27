; test/law/lds.l -- the ld script reader: words, expressions, statements, output sections

(borrow 'holo)
(: (ldx s) (lds-x (lds-words s))                      ; one expression
   (ldsec s) (: r (lds-read ("SECTIONS { " + s + " }"))  (<>(<r)))   ; SECTIONS' items
   (ldo s) <>(<(ldsec s))                               ; the first output section's tablet
   (test
      ; --- words: comments gone, strings whole, a glob one word, punctuation alone
      (lds-words "a /* b */ c" = '("a" "c"))
      (lds-words "*(.text.*) ;" = '("*" "(" ".text.*" ")" ";"))
      (lds-words "KEEP(*(SORT(___ksymtab+*)))" = '("KEEP" "(" "*" "(" "SORT" "(" "___ksymtab+*" ")" ")" ")"))
      (lds-words "ASSERT(x, \"too big\")" = '("ASSERT" "(" "x" "," "\"too big\"" ")"))
      ; --- expressions: C's precedence, unary, the ternary, numbers, builtins
      (ldx "1 + 2 * 3" = '(+ 1 (* 2 3)))
      (ldx "1 - 2 - 3" = '(- (- 1 2) 3))                    ; left-associative
      (ldx "a << 2 + 1" = '(<< "a" (+ 2 1)))
      (ldx "a == 0 || b == 24" = '(|| (== "a" 0) (== "b" 24)))
      (ldx "a & ~(4096 - 1)" = '(& "a" (cpl (- 4096 1))))
      (ldx "-(1 << 47)" = '(neg (<< 1 47)))
      (ldx "1 + x > 3 ? y + 1 : 0" = '(? (> (+ 1 "x") 3) (+ "y" 1) 0))
      (ldx "0x10000" = 65536) (ldx "4K" = 4096) (ldx "2M" = 2097152) (ldx "0X1f" = 31)
      (ldx "ALIGN(8)" = '(call "ALIGN" (8)))
      (ldx "ALIGN(ABSOLUTE(_end + 1), 0x200000)" = '(call "ALIGN" ((call "ABSOLUTE" ((+ "_end" 1))) 2097152)))
      (ldx "ADDR(.data) - 0" = '(- (call "ADDR" (".data")) 0))
      (ldx "." = ".")
      ; --- statements: an assignment glued or apart, PROVIDE, HIDDEN, ASSERT, ENTRY
      (lds-read "a = b;" = '((set "a" = "b")))
      (lds-read "a=b;" = '((set "a" = "b")))
      (lds-read ". += 1 << 12;" = '((set "." += (<< 1 12))))
      (lds-read "PROVIDE(x = y);" = '((provide "x" "y" 0)))
      (lds-read "HIDDEN(x = .);" = '((provide "x" "." 1)))
      (lds-read "ASSERT(a <= 4096, \"too big\")" = '((assert (<= "a" 4096) "too big")))
      (lds-read "OUTPUT_ARCH(aarch64) ENTRY(_text)" = '((arch "aarch64") (entry "_text")))
      ; --- an output section and its trailers
      (: t (ldo ".text : ALIGN(0x10000) { _stext = .; KEEP(*(.head.text)) *(.text .text.*) }")
         (t 'name = ".text" && t 'align = 65536
          && t 'body = '((set "_stext" = ".") (in 1 "*" ((none ".head.text")))
                         (in 0 "*" ((none ".text") (none ".text.*"))))))
      (: t (ldo ".rodata : AT(ADDR(.rodata) - 0) { *(.rodata) }")
         (t 'lma = '(- (call "ADDR" (".rodata")) 0)))
      (: t (ldo ".bss (NOLOAD) : { *(.bss) }") (t 'type = "NOLOAD"))
      (: t (ldo ".text 0x1000 : { *(.text) } :text =0x90")
         (t 'addr = 4096 && t 'phdrs = '("text") && t 'fill = 144))
      (: t (ldo ".text: { *(.text) }") (t 'name = ".text"))           ; the colon glued
      ; --- input descriptions: sorts, data, a section-level assignment between sections
      (: t (ldo "x : { *(SORT(___ksymtab+*)) *(SORT_BY_ALIGNMENT(.data..hot.*) .y) BYTE(0); LONG(1 + 1) }")
         (t 'body = '((in 0 "*" ((SORT "___ksymtab+*")))
                      (in 0 "*" ((SORT_BY_ALIGNMENT ".data..hot.*") (none ".y")))
                      (data 1 0) (data 4 (+ 1 1)))))
      (#(ldsec ".a : { *(.a) } . = ALIGN(8); idmap = .; .b : { *(.b) }") = 4)
      (: d <(ldsec "/DISCARD/ : { *(.discard) }") (<d = 'osec && <>d 'name = "/DISCARD/"))
      ; --- PHDRS and VERSION
      (: p <>(<(lds-read "PHDRS { text PT_LOAD FLAGS(5) FILEHDR PHDRS; note PT_NOTE; }"))
         (#p = 2 && <p 'name = "text" && <p 'type = "PT_LOAD" && <p 'flags = 5 && <p 'FILEHDR = 1
          && <>p 'type = "PT_NOTE"))
      (<(<(lds-read "VERSION { V1 { global: a; local: *; }; }")) = 'version)))

(test_fin (), say err "test/law/lds: words + expressions + statements + output sections + phdrs ok", put err 10, 0)
