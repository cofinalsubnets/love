; the gate for src/core/holo/dialect.l against gcc: test/gate/dialect.sh compiles every test/cc
; file with -masm=att and -masm=intel, and both spellings of one program must read to one value
; -- labels, .globl and every instruction. the other directives compare by name only (gcc quotes
; symbols in its Intel output and not in its at&T). @PAIRS@ is the list the shell lays, one
; `att.s intel.s` pair per line; a miss prints the first differing item of the pair.
(use 'holo)

(: (slurpf f) (: q (open f "r") (slurp q))
   (strip its) (map (it \ <it = 'dir ? ['dir <>it] it) its)
   (words s) (filter (w \ #w > 0) (xa-split s 32))
   (report a i) ((: (g a i k)
                    (? (!(two? a) && !(two? i)) 0
                       (!(two? a) || !(two? i) || !(<a = <i))
                       (putx ["item" k (two? a ? <a ()) (two? i ? <i ())], puts "\n")
                       (g >a >i (k + 1)))) a i 0)
   ls (filter (l \ #l > 0) (xa-lines (slurpf "@PAIRS@")))
   n {0 0} bad {0 0}
   _ (each ls (\ l (: ws (words l)
                      a (strip (att-read (slurpf <ws)))
                      i (strip (intel-read (slurpf <>ws)))
                      _ (pin n 0 (peep n 0 0 + 1))
                      (? (a = i) 0
                         (: _ (pin bad 0 (peep bad 0 0 + 1))
                            _ (puts ("DIFF " + <ws + "\n"))
                            (report a i))))))
   _ (puts ("test/holo/dialect: " + show (peep n 0 0) + " pairs, " + show (peep bad 0 0) + " differ\n"))
   _ (flush out)
   (? (0 = peep bad 0 0) 0 (quit 1)))
