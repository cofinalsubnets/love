; test/gate/machobind.l ELF BINDS -- dyld's binds in a mach-o, against the ELF of the same link.
; BINDS is `love objdump --macho --bind` of the mach-o. moonlibc's libsys. words are bss in both
; containers: each must be bound once, weakly, by its bare name, in __DATA, and the binds must
; keep the ELF's spacing word for word, so each lands on its own word
; usage: love test/gate/machobind.l ELF BINDS
(borrow '(holo posix))
(: (die m) (say err "FAIL machobind: \(m)\n", quit 1)
   (slurp-file p) (uread p @ [1 s] (s + "") (die "cannot read \(p)"))
   _ (two? >>argv || die "usage: machobind.l ELF BINDS")
   ep <>argv
   e (slurp-file ep)
   (unhex s) (foldl (\ a c (a * 16 + (c < 58 ? (c - 48) (c < 71 ? (c - 55) (c - 87))))) 0 (map s ^#s))
   ; the rows: segment section address type addend dylib symbol [(weak_import)]
   ; -> name -> (segment section address weak), and how many rows named it
   rows (map (l \ filter (x \ 0 < #x) (split " " l))
             (filter (l \ starts? l "__") (split "\n" (slurp-file <>>argv))))
   mb (: t {} ((each rows (w \ #w > 6 ? (pin t (w 6) [<w (w 1) (unhex (snip (w 2) 2 #(w 2))) (#w > 7 && w 7 = "(weak_import)")]) 0)), t))
   (named n) #(filter (w \ #w > 6 && w 6 = n) rows)
   ; the ELF's words: name (less "libsys.") -> address
   ew (: t {}
         ((each (ld-syms "machobind" e)
                (r \ starts? <r "libsys." ? (pin t (snip <r 7 #<r) (r 4)) 0)),
          t))
   ewords (sort (keys ew))
   _ (two? ewords || die "\(ep) carries no libsys. word")
   _ (each ewords
           (n \ (: b (peep mb ("_" + n) ())
                   (? (atom? b) (die "\(n): no bind")
                      (named ("_" + n) != 1) (die "\(n): bound \(named ("_" + n)) times")
                      (<b != "__DATA") (die "\(n): bound in \(<b), not __DATA")
                      !(elem (b 1) ["__data" "__bss"]) (die "\(n): bound outside __DATA's sections")
                      (b 3 != 1) (die "\(n): bound strongly")
                      0))))
   ; spacing: sorted by the ELF's address, each step is the mach-o's step
   (at n) (mb ("_" + n) 2)
   ks (sort (map (n \ [(ew n) n]) ewords))
   _ (each (zip ks >ks)
           (pr \ (: a <<pr na <>(<pr) b <>pr nb <>>pr d (at nb - at na)
                    (b - a = d ? 0 (die "\(na) -> \(nb): \(b - a) bytes in the ELF, \(d) in the mach-o")))))
   (say out "machobind: \(#ewords) libsys words, each bound weakly by name on its own word in __DATA\n"))
