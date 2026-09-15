; test/gate/lay.l -- the lay law, asked of a finished binary: no two PT_LOADs share a page
; of the largest page its ISA can meet, and each keeps p_vaddr = p_offset (mod that page).
; a loader maps a segment from p_vaddr rounded DOWN to whatever page the kernel runs, so
; two segments sharing one are laid over each other on any machine whose pages are bigger
; than those of the machine that linked them -- a fault the linking machine cannot see.
; aarch64 is where that bites: its kernels come in 4K, 16K and 64K and meet one binary.
; reads the header off its own table. a law that borrowed the linker's field rows would
; agree with it by construction, and this one has to be able to disagree.
; the roster is the caller's: this is the question an OS loader asks, and a kernel or a
; board image is placed by something else entirely.
; usage: love test/gate/lay.l <elf>..  -- prints every break, and leaves with 1 if there was one.
(borrow 'kore)
(:
   ; the largest page each ISA's kernels are built with. x86-64 and riscv have one page
   ; wherever they run; aarch64 varies, and ld's own default there says the same number.
   ; 0 is "this law has nothing to say", which is a break too -- a new ISA must answer.
   (pageof m) (? (m = 183) 65536 (elem m '(62 243)) 4096 0)
   (le s i n) (foldl (\ a k (a + ((s (i + k)) * (k 256)))) 0 (jot n))
   (down p v) (v - (v % p))
   (up p v) (: r (v % p) (r = 0 ? v (v + p - r)))
   ; the pt_loads of one file, in header order, as [off vaddr filesz memsz align]
   (loads s)
    (: po (le s 32 8) e (le s 54 2) n (le s 56 2)
       (go i acc)
        (? (n <= i) (rev acc)
           (: h (po + (i * e))
              (go (i + 1) (? (1 = le s h 4)
                             ([(le s (h + 8) 8) (le s (h + 16) 8) (le s (h + 32) 8)
                               (le s (h + 40) 8) (le s (h + 48) 8)] . acc)
                             acc))))
       (go 0 ()))
   ; every break one file commits, in words. () is a clean lay.
   (breaks path s)
    (: m (le s 18 2) p (pageof m) ls (loads s)
       (nm i) ((path + ": LOAD ") + show i)
       (add ac x) (? x (x . ac) ac)
       (algn i g) (? ((g 4) = p) ()
                     ((((nm i) + " p_align ") + show (g 4)) + " wants " + show p))
       (cong i g) (? (((g 1) % p) = (<g % p)) ()
                     (((((nm i) + " vaddr ") + show (g 1)) + " and offset ") + show <g
                      + " differ mod " + show p))
       ; the ground a segment really takes, its ends rounded the way a loader rounds them
       ext (map (\ g [(down p (g 1)) (up p ((g 1) + (g 3)))]) ls)
       (share i ac)
        (foldl (\ a j (: x (ext i) y (ext j)
                         (? ((<x >= (y 1)) || (<y >= (x 1))) a
                            (((((nm i) + " and LOAD ") + show j) + " share a page of "
                              + show p) . a))))
               ac (jot i))
       (? (0 = p) ((((path + ": machine ") + show m) + " has no page in this law") . ())
          (foldl (\ ac i (: g (ls i)
                            (add (add (share i ac) (cong i g)) (algn i g))))
                 () (jot #ls))))
   (check path)
    (: r (uread path)
       (? (two? r) (breaks path <>r) ((path + ": cannot read") . ())))
   bad (foldl (\ a p (a + check p)) () >argv)
   _ (each bad (\ m (: _ (puts m) (puts "\n"))))
   _ (puts (0 < #bad ? (("lay: " + show #bad) + " breaks\n")
                       (("lay: " + show #(>argv)) + " binaries, every segment on its own page\n")))
   (quit (0 < #bad ? 1 0)))
