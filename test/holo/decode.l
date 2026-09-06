; the gate for src/core/holo/decode.l against objdump: test/gate/decode.sh lays @PAIRS@, one
; `text.bin text.dis` pair per line -- the raw .text of a gcc object and objdump's reading of
; it. the judge decodes the bytes and holds two things per instruction: the boundary (objdump
; started an instruction at the same offset, and nowhere in between) and the mnemonic, with
; objdump's at&T suffix and prefix words allowed for (movl = mov, cltq = cdqe, `lock cmpxchg`
; is our two items). a `.byte` of ours is a miss by construction: the bytes said something.
(use 'holo)

(: (slurpf f) (: q (open f "r") (slurp q))
   (words s) (filter (w \ #w > 0) (xa-split s 32))
   ;; objdump's line: "   1a:\tmov    %rsp,%rbp" -> (offset mnemonic), or () for anything else
   (hexv s) (foldl (a \ c \ a * 16 + (? (48 <= c <= 57) (c - 48) (97 <= c <= 102) (c - 87) (c - 55))) 0 (chars s))
   objdump-prefixes '("lock" "rep" "repz" "repnz" "data16" "cs" "ds" "es" "fs" "gs" "ss" "addr32" "bnd" "notrack")
   (odline l)
    (: c (xa-idx l 58)
       (? (c <= 0) ()
          (: off (xa-trim (snip l 0 c)) rest (xa-trim (snip l (c + 1) #l))
             (? (!(xa-allof? off xa-hexc? 0) || 0 = #rest) ()
                (: ws (filter (w \ !(member? w objdump-prefixes) && !(xa-has? w 46))
                              (words (string (map (c \ c = 9 ? 32 c) (chars rest)))))
                   (two? ws ? [(hexv off) <ws] ()))))))
   ;; ours: the last item of a row that is not a prefix word; a .byte is the miss "byte"
   (ourmn its) (: it (its (#its - 1))
                  (? (<it = 'dir) ".byte"
                     (show (it 1))))
   ;; objdump's mnemonic against ours: as spelt, less an at&T suffix, or through the nullary map
   (agree? ours theirs)
    (: n #theirs
       (? (ours = theirs) 1
          (n > 2 && ours = (snip theirs 0 (n - 1)) && member? (theirs (n - 1)) '(98 119 108 113)) 1
          (: k (xa-att-nil (name theirs)) (nom? k && ours = show k)) 1
          (theirs = "movsl" && ours = "movsd") 1
          (theirs = "movabs" && ours = "mov") 1
          0))
   misses {}                                        ; objdump's mnemonic -> how often we missed it
   (judge bin dis)
    (: s (slurpf bin)
       od (foldl (\ t l (: r (odline l) (? (two? r) (pin t <r <>r) t))) {} (xa-lines (slurpf dis)))
       rows (x64-disasm s 0)
       n {0 0} bmiss {0 0} mmiss {0 0} shown {0 0}
       (tell why r) (? (peep shown 0 0 < 4)
                      (: _ (pin shown 0 (peep shown 0 0 + 1))
                         (puts ("  " + why + " at " + show <r + " in " + bin + ": " + show (r 2) + " objdump: " + show (peep od <r ()) + "\n")))
                      0)
       _ (each rows (\ r (: their (peep od <r "") ours (ourmn (r 2))
                            _ (pin n 0 (peep n 0 0 + 1))
                            (? (0 = #their) (pin bmiss 0 (peep bmiss 0 0 + 1), tell "boundary" r)
                               !(agree? ours their) (pin mmiss 0 (peep mmiss 0 0 + 1), pin misses their (1 + peep misses their 0), tell "mnemonic" r)
                               0))))
       [(peep n 0 0) (peep bmiss 0 0) (peep mmiss 0 0)])
   ls (filter (l \ #l > 0) (xa-lines (slurpf "@PAIRS@")))
   tot (foldl (\ a l (: ws (words l) r (judge <ws <>ws) [(<a + <r) (<>a + <>r) (<>>a + <>>r)])) [0 0 0] ls)
   _ (? (two? (keys misses))
        (puts ("  missed: " + (foldl (\ a k (a + k + " " + show (misses k) + "  ")) "" (sort (keys misses))) + "\n"))
        0)
   _ (puts ("test/holo/decode: " + show #ls + " objects, " + show <tot + " instructions, "
            + show <>tot + " boundary misses, " + show <>>tot + " mnemonic misses\n"))
   _ (flush out)
   (? (0 = <>tot + <>>tot) 0 (quit 1)))
