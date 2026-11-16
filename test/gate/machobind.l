; test/gate/machobind.l ELF MACHO -- dyld's binds in a mach-o, against the ELF of the same link.
; moonlibc's libsys. words are bss in both containers: each must be bound once, weakly, by its
; bare name, inside __DATA, and the binds must keep the ELF's spacing word for word, so each
; lands on its own word. llvm-objdump can't read binds in segments without sections, and the
; macbook is the only dyld we have
; usage: love test/gate/machobind.l ELF MACHO
(borrow '(holo posix))
(: (die m) (say err "FAIL machobind: \(m)\n", quit 1)
   (slurp-file p) (uread p @ [1 s] (s + "") (die "cannot read \(p)"))
   _ (two? >>argv || die "usage: machobind.l ELF MACHO")
   ep <>argv
   mp <>>argv
   e (slurp-file ep)
   m (slurp-file mp)
   _ (rle32 m 0 = 4277009103 || die "\(mp) is not a 64-bit mach-o")
   (cstr s i) (: (go j) (s j = 0 ? j (go (j + 1))) (snip s i (go i)))
   ; the load commands: __DATA's (addr vsize), dyld_info's bind (offset size)
   cmds (: n (rle32 m 16)
           (go i at acc) (i = n ? acc
                            (go (i + 1) (at + rle32 m (at + 4)) ([(rle32 m at) at] . acc)))
           (go 0 32 ()))
   dseg (: f (filter (c \ <c = 25 && cstr m (c 1 + 8) = "__DATA") cmds)
           (two? f ? [(rle64 m (<f 1 + 24)) (rle64 m (<f 1 + 32))] (die "no __DATA")))
   bnd (: f (filter (c \ <c = 2147483682) cmds)
          (two? f ? [(rle32 m (<f 1 + 16)) (rle32 m (<f 1 + 20))] (die "no dyld_info")))
   (uleb p) (: (go p v sh) (: b (m p) (go2 v2) (b < 128 ? [v2 (p + 1)] (go (p + 1) v2 (sh + 7)))
                              (go2 (v + (b & 127) * 2 ** sh)))
               (go p 0 0))
   ; the bind opcodes this linker lays: special dylib, type, a name (weak or not), segment and
   ; offset, bind. -> ((name seg off weak) ..)
   binds (: z (<bnd + <>bnd)
            (go p nm wk sg off acc)
             (? (z <= p) (rev acc)
                (: b (m p) op (b & 240) im (b & 15)
                   (? (b = 0) (rev acc)
                      (op = 16 || op = 48 || op = 80) (go (p + 1) nm wk sg off acc)
                      (op = 64) (: q (p + 1) s (cstr m q) (go (q + #s + 1) s (im & 1) sg off acc))
                      (op = 112) (uleb (p + 1) @ [v p2] (go p2 nm wk im v acc))
                      (op = 144) (go (p + 1) nm wk sg off ([nm sg off wk] . acc))
                      (die "bind opcode \(b) at \(p)"))))
            (go <bnd () 0 0 0 ()))
   ; the ELF's words: name (less "libsys.") -> address
   ew (: t {}
         ((each (ld-syms "machobind" e)
                (r \ starts? <r "libsys." ? (pin t (snip <r 7 #<r) (r 4)) 0)),
          t))
   ewords (keys ew)
   mb (: t {} ((each binds (b \ starts? <b "_" ? (pin t (snip <b 1 #<b) b) 0)), t))
   _ (0 < #ewords || die "\(ep) carries no libsys. word")
   _ (each (sort ewords)
           (n \ (: b (peep mb n ())
                   (? (atom? b) (die "\(n): no bind")
                      (b 1 != 3) (die "\(n): bound in segment \(b 1), not __DATA")
                      (<>dseg <= b 2) (die "\(n): bound past __DATA's \(<>dseg) bytes")
                      (b 3 != 1) (die "\(n): bound strongly")
                      0))))
   _ (#(filter (b \ elem (snip <b 1 #<b) ewords) binds) = #ewords || die "a word bound twice")
   ; spacing: sorted by the ELF's address, each step is the mach-o's step
   ks (sort (map (n \ [(ew n) n]) ewords))
   _ (each (zip ks >ks)
           (pr \ (: a <<pr na <>(<pr) b <>pr nb <>>pr
                    d (mb nb 2 - mb na 2)
                    (b - a = d ? 0 (die "\(na) -> \(nb): \(b - a) bytes in the ELF, \(d) in the mach-o")))))
   (say out "machobind: \(#ewords) libsys words, each bound weakly by name on its own word in __DATA\n"))
