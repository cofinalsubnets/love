; test/holo/fuzz/sysdiff.l -- holo system-lane differential: every privileged encoding,
; byte-exact against llvm-mc. fuzz.l is a decode oracle (holo may legally pick among
; encodings); the system lane is the opposite -- each op has exactly one encoding and a
; small enumerable operand space, so the sharp oracle is assemble-side: write the
; instruction llvm-mc's way, assemble, demand the same bytes holo produced.
;
; the a64 op tables and riscv's CSR table are read straight out of crew/holo/a64.l
; and rv64.l, so a row added to holo is checked the next run with no edit here -- the
; uncovered row is the one that ships wrong. the x86 side has no name tables (the operand
; space IS the register file), so it enumerates. SYSDIFF_ARCH=x64|a64|rv64 narrows;
; default all three.
;
;   out/host/love test/holo/fuzz/sysdiff.l          (exit 1 on any disagreement)

(reads (open "crew/holo/holo.l" "r"))
(reads (open "crew/holo/x64.l" "r"))
(reads (open "crew/holo/a64.l" "r"))
(reads (open "crew/holo/rv64.l" "r"))
; holo rides module 'holo: reading the source registers it, and the names come
; through the door rather than off this file's layer.
(use 'holo)

(:
 (trim s) (: n (tally s)
             (a i) (? ((i < n) && (((s i) = 32) || ((s i) = 9))) (a (i + 1)) i)
             (b j) (? ((0 < j) && (((s (j - 1)) = 32) || ((s (j - 1)) = 9))) (b (j - 1)) j)
             i (a 0) j (b n)
             (? (i < j) (snip s i j) ""))
 (lines s) (: n (tally s)
              (go i j acc) (? (n <= j) (rev (? (i < j) ((snip s i j) >< acc) acc))
                              ((s j) = 10) (go (j + 1) (j + 1) ((snip s i j) >< acc))
                              (go i (j + 1) acc))
              (go 0 0 ()))
 (idx-from s sub i0) (: n (tally s) k (tally sub)
                        (at? i j) (? (k <= j) 1 ((s (i + j)) = (sub j)) (at? i (j + 1)) 0)
                        (go i) (? (n < (i + k)) () (at? i 0) i (go (i + 1)))
                        (go i0))
 (idx-of s sub) (idx-from s sub 0)
 (has? s sub) (charm? (idx-of s sub))
 (digit? c) ((48 <= c) && (c <= 57))
 (s2d s) (: n (tally s)                                  ; decimal, () on a non-digit
            (go i acc) (? (n <= i) acc (digit? (s i)) (go (i + 1) (10 * acc + ((s i) - 48))) ())
            (? (n = 0) () (go 0 0)))
 (sh c) (: pid (spawn ["sh" "-c" c]) (? (nom? pid) 1 (wait pid)))
 (rdf p) (: q (open p "r") (? (hot? q) (: t (slurp q) _ (close q) t) ""))
 (wrf p t) (: q (open p "w") _ (say q t) (close q))
 tmpd "out/host"

 ; --- the ('key >< ..) rows of a `name (tabof ...)` form in a64.l, source order ---
 a64src (rdf "crew/holo/a64.l")
 rv64src (rdf "crew/holo/rv64.l")
 (table-in src nm)
  (: i (idx-of src ("\n   " + nm + " (tabof"))
     _ (? (charm? i) 0 (: _ (puts ("sysdiff: no table " + nm + "\n")) (quit 1)))
     j0 (idx-from src "(tabof" i)
     ; walk to the (tabof ..) close, then harvest ('name >< inside [i, j)
     (close j d) (? ((src j) = 40) (close (j + 1) (d + 1))
                    ((src j) = 41) (? (d = 1) j (close (j + 1) (d - 1)))
                    (close (j + 1) d))
     j (close j0 0)
     (namec? c) ((digit? c) || ((65 <= c) && (c <= 90)) || ((97 <= c) && (c <= 122)) || (c = 95))
     (harvest k acc)
      (: h (idx-from src "('" k)
         (? (!(charm? h) || (j < h)) (rev acc)
            (: (e m) (? (namec? (src m)) (e (m + 1)) m)
               b (e (h + 2))
               (? (has? (snip src b (b + 3)) "><")
                  (harvest b ((snip src (h + 2) b) >< acc))
                  (harvest b acc)))))
     (harvest i ()))
 (table nm) (table-in a64src nm)

 ; --- the cases: [ir-form asm-text pair-key] (pair-key () when unpaired) ---
 (cases-a64 _)
  (: sysregs (table "a64-sysregs")
     out (foldl (\ a r (a + [[['mrs 'r5 (intern r)] ("mrs x5, " + r) ()]
                            [['msr (intern r) 'r5] ("msr " + r + ", x5") ()]]))
                () sysregs)
     out (foldl (\ a o (a + [[['dsb (intern o)] ("dsb " + o) ()]
                            [['dmb (intern o)] ("dmb " + o) ()]]))
                out (table "a64-barrier-opts"))
     out (foldl (\ a f (a + foldl (\ b i (b + [[['msri (intern f) i] ("msr " + f + ", #" + show i) ()]])) () ^16))
                out (table "a64-pstate"))
     ; the sys family: llvm-mc knows which operations take a register and refuses the
     ; other spelling; offer both, and `pair` demands the accepted one matched.
     out (foldl (\ a row (: ir <row
                            (foldl (\ b o (: pk (ir + " " + o)
                                             (b + [[[(intern ir) (intern o) 'r7] (ir + " " + o + ", x7") pk]
                                                   [[(intern ir) (intern o) 'zr] (ir + " " + o) pk]])))
                                   a (table (row 1)))))
                out '(("tlbi" "a64-tlbi-ops") ("ic" "a64-ic-ops")
                      ("dc" "a64-dc-ops") ("at" "a64-at-ops")))
     out (foldl (\ a imm (a + [[['brk imm] ("brk #" + show imm) ()]
                              [['dbrk imm] ("hlt #" + show imm) ()]
                              [['hvc imm] ("hvc #" + show imm) ()]
                              [['smc imm] ("smc #" + show imm) ()]
                              [['udf imm] ("udf #" + show imm) ()]]))
                out '(0 1 2 15 255 4660 61440 65535))
     out (foldl (\ a n (a + [[[(intern n)] n ()]])) out '("isb" "wfi" "wfe" "eret"))
     (out + [[['lea 'r9 'sp 0] "mov x9, sp" ()]                 ; the sp move `mov` cannot make
             [['lea 'sp 'r9 0] "mov sp, x9" ()]]))

 x64-r2x '((r0 "rax") (r1 "rcx") (r2 "rdx") (r3 "rbx") (r4 "rbp") (r5 "rsi") (r6 "rdi")
           (r7 "r8") (r8 "r9") (r9 "r10") (r10 "r11") (r11 "r12") (r12 "r13") (r13 "r14")
           (r14 "r15") (sp "rsp"))
 x64-w '(("rax" "ax") ("rcx" "cx") ("rdx" "dx") ("rbx" "bx") ("rsp" "sp") ("rbp" "bp")
         ("rsi" "si") ("rdi" "di") ("r8" "r8w") ("r9" "r9w") ("r10" "r10w") ("r11" "r11w")
         ("r12" "r12w") ("r13" "r13w") ("r14" "r14w") ("r15" "r15w"))
 (cases-x64 _)
  (: gp (filter (\ p !(<p = 'sp)) x64-r2x)               ; rsp is not a cr-move operand
     out (foldl (\ a n (a + foldl (\ b p (b + [[['ldcr <p n] ("mov " + <>p + ", cr" + show n) ()]
                                              [['stcr n <p] ("mov cr" + show n + ", " + <>p) ()]]))
                                  () gp))
                () '(0 1 2 3 4 5 6 7 8))
     out (foldl (\ a p (: r <p x <>p
                          a2 (foldl (\ b off (b + [[['lgdt r off] ("lgdt [" + x + " + " + show off + "]") ()]
                                                  [['lidt r off] ("lidt [" + x + " + " + show off + "]") ()]
                                                  [['invlpg r off] ("invlpg [" + x + " + " + show off + "]") ()]]))
                                    a '(0 8 16 200))
                          (a2 + [[['ltr r] ("ltr " + (: w (assoc x x64-w) <>w)) ()]])))
                out x64-r2x)
     out (foldl (\ a n (? (n = 3) a                        ; llvm folds `int 3` to CC; holo keeps cd 03
                          (a + [[['int n] ("int " + show n) ()]])))
                out ^256)
     (out + foldl (\ a n (a + [[[(intern n)] n ()]])) ()
            '("cli" "sti" "hlt" "ud2" "iretq" "swapgs" "rdmsr" "wrmsr" "cpuid" "rdtsc")))

 ; the riscv register file, holo's name on the left and the disassembler's on the right. zr is
 ; x0, which nothing but the system lane ever names.
 rv-r2x '((r0 "a0") (r1 "a1") (r3 "a3") (r8 "t0") (r13 "s2") (sp "sp") (fp "s0") (lr "ra") (zr "zero"))
 (cases-rv _)
  (: ; every named CSR read and written -- the table that would otherwise ship a wrong number
     out (foldl (\ a c (a + [[['csrr 'r0 (intern c)] ("csrr a0, " + c) ()]
                            [['csrw (intern c) 'r0] ("csrw " + c + ", a0") ()]]))
                () (table-in rv64src "rv-csrnames"))
     ; the register file, one csr each way
     out (foldl (\ a p (: r <p x <>p
                          (a + [[['csrr r 'mstatus] ("csrr " + x + ", mstatus") ()]
                                [['csrw 'mtvec r] ("csrw mtvec, " + x) ()]])))
                out rv-r2x)
     ; the write pseudos and the read-modify-write forms they are made of, one funct3 apiece
     out (foldl (\ a op (a + foldl (\ b p (: r <p x <>p
                                             (b + [[[(intern op) 'sstatus r] (op + " sstatus, " + x) ()]])))
                                   () rv-r2x))
                out '("csrw" "csrs" "csrc"))
     out (foldl (\ a op (a + foldl (\ b p (: r <p x <>p
                                             (b + [[[(intern op) 'r0 'sie r] (op + " a0, sie, " + x) ()]])))
                                   () rv-r2x))
                out '("csrrw" "csrrs" "csrrc"))
     ; the 5-bit immediate forms, at both ends of the field and inside it
     out (foldl (\ a op (a + foldl (\ b u (b + [[[(intern op) 'sstatus u] (op + " sstatus, " + show u) ()]]))
                                   () '(0 1 2 15 16 31)))
                out '("csrwi" "csrsi" "csrci"))
     out (foldl (\ a op (a + foldl (\ b u (b + [[[(intern op) 'r0 'mie u] (op + " a0, mie, " + show u) ()]]))
                                   () '(0 1 2 15 16 31)))
                out '("csrrwi" "csrrsi" "csrrci"))
     ; the tlb flush over both slots, then the words that take no operand at all
     out (foldl (\ a p (: r <p x <>p
                          (a + [[['sfence r 'zr] ("sfence.vma " + x + ", zero") ()]
                                [['sfence 'zr r] ("sfence.vma zero, " + x) ()]])))
                out rv-r2x)
     (out + [[['wfi] "wfi" ()] [['sret] "sret" ()] [['mret] "mret" ()]
             [['fence] "fence" ()] [['fencei] "fence.i" ()]]))

 ; --- llvm-mc assembling: two passes (an error would slide the encodings) ---
 ro-reject "expected writable system register"
 (llvm arch asms)
  (: triple (? (arch = "a64") "a64" (arch = "rv64") "rv64" "x64")
     mattr (? (arch = "rv64") " -mattr=+m,+f,+d,+zicsr,+zifencei" "")
     nhead (? (arch = "x64") 1 0)
     head (? (arch = "x64") ".intel_syntax noprefix\n" "")
     (lay ls) (wrf (tmpd + "/.sysd.in") (head + foldl (\ a l (a + "\t" + l + "\n")) "" ls))
     _ (lay asms)
     _ (sh ("llvm-mc -triple=" + triple + mattr + " --show-encoding < " + tmpd + "/.sysd.in > "
            + tmpd + "/.sysd.out 2> " + tmpd + "/.sysd.err"))
     ; pass 1: the rejected line numbers (0-based case index) and their reasons
     bad (foldl (\ a ln (: i (idx-of ln "<stdin>:")
                           (? !(charm? i) a
                              (: j (idx-from ln ":" (i + 8))
                                 e (idx-of ln ": error: ")
                                 (? (!(charm? j) || !(charm? e)) a
                                    (: n (s2d (snip ln (i + 8) j))
                                       (? (n = ()) a
                                          ([(n - 1 - nhead) (snip ln (e + 9) (tally ln))] >< a))))))))
                () (lines (rdf (tmpd + "/.sysd.err"))))
     good (: (go i m acc) (? !(two? m) (rev acc)
                             (? (two? (assoc i bad)) (go (i + 1) >m acc)
                                (go (i + 1) >m (<m >< acc))))
             (go 0 asms ()))
     _ (lay good)
     _ (sh ("llvm-mc -triple=" + triple + mattr + " --show-encoding < " + tmpd + "/.sysd.in > "
            + tmpd + "/.sysd.out 2>/dev/null"))
     enc (foldl (\ a ln (: i (idx-of ln "encoding: [")
                           (? !(charm? i) a
                              (: j (idx-from ln "]" i)
                                 raw (snip ln (i + 11) j)
                                 hx (: (go k acc) (? ((tally raw) <= k) (string (rev acc))
                                                     (: c (raw k)
                                                        (? ((c = 48) && (k + 1 < tally raw) && ((raw (k + 1)) = 120))
                                                           (go (k + 2) acc)
                                                           (c = 44) (go (k + 1) acc)
                                                           (go (k + 1) (c >< acc)))))
                                       (go 0 ()))
                                 (a + [hx])))))
                () (lines (rdf (tmpd + "/.sysd.out"))))
     _ (? ((tally enc) = (tally good)) 0
          (: _ (puts ("sysdiff: llvm-mc gave " + show (tally enc) + " encodings for "
                      + show (tally good) + " lines\n")) (quit 1)))
     ; reassemble the full column: [hex ()] accepted, [() why] rejected
     (: (go i m es acc)
         (? !(two? m) (rev acc)
            (: b (assoc i bad)
               (? (two? b) (go (i + 1) >m es ([() <>b] >< acc))
                  (go (i + 1) >m >es ([<es ()] >< acc)))))
        (go 0 asms enc ())))

 (sweep arch)
  (: cs (? (arch = "a64") (cases-a64 0) (arch = "rv64") (cases-rv 0) (cases-x64 0))
     _ (puts ("\n=== holo " + arch + " system-lane differential vs llvm-mc ===\n"))
     tgt (? (arch = "a64") 'a64 (arch = "rv64") 'rv64 'x64)
     ref (llvm arch (map (\ c (c 1)) cs))
     seen (tablet 0)
     _ (map (\ c (? ((c 2) = ()) 0
                    (? (peep seen (intern (c 2)) -1) 0 (pin seen (intern (c 2)) 0))))
            cs)
     (one c r st)                                         ; st = [npass nskip fails]
      (: ir <c asm (c 1) pair (c 2)
         want <r why (r 1)
         got (holo-hex tgt [ir])
         (? (want = ())
            (? ((has? why ro-reject) && (4 <= tally asm) && ((snip asm 0 4) = "msr ")) [<st (st 1 + 1) (st 2)]
               !(pair = ()) [<st (st 1 + 1) (st 2)]
               [<st (st 1) ((st 2) + [[ir asm got ("llvm-mc reject: " + why)]])])
            (? (got = want)
               (: _ (? (pair = ()) 0 (pin seen (intern pair) 1))
                  [(<st + 1) (st 1) (st 2)])
               [<st (st 1) ((st 2) + [[ir asm got ("want " + want)]])])))
     st (: (go m rs st) (? !(two? m) st (go >m >rs (one <m <rs st)))
           (go cs ref [0 0 ()]))
     ; a pair whose spellings llvm-mc both refused hides a table typo -- fail it
     fails ((st 2)
            + (foldl (\ a c (: pk (c 2)
                               (? (pk = ()) a
                                  (? (peep seen (intern pk) 0) a
                                     (: _ (pin seen (intern pk) 1)
                                        (a + [[pk pk () "llvm-mc took NEITHER spelling"]]))))))
                     () cs))
     _ (puts ("  " + show <st + " match  " + show (tally fails) + " fail  "
              + show (st 1) + " skipped (read-only / wrong-arity spelling)\n"))
     _ (map (\ f (puts ("  " + show <f + "\n      as " + f 1 + " got=" + ("" + f 2)
                        + " :: " + f 3 + "\n")))
            fails)
     (? (two? fails) 1 0))

 sd-arch ("" + getenv "SYSDIFF_ARCH")
 arches (? (sd-arch = "x64") '("x64") (sd-arch = "a64") '("a64") (sd-arch = "rv64") '("rv64")
           '("x64" "a64" "rv64"))
 bad (foldl (\ a x (a + sweep x)) 0 arches)
 (? (0 < bad) (quit 1) (quit 0)))
