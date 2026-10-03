; test/gate/kmitty.l -- test_kmitty: an empty boot line brings the x64 console up a mitty, lush in
; its first pane. keys go in through qemu's monitor (sendkey, the console's own keyboard): a
; command runs in the pane and its answer is painted, `exit` ends the last pane and the console
; shell stands in, and (reset 0) at it ends the machine -- qemu exits by itself, never by the
; ceiling. the serial line mirrors the console; a marker is read with the escapes stripped,
; since the mitty paints its cells between them. argv = (this elf); run on the host love.
(borrow 'posix)

(: elf <>argv
   dir ("/tmp/kmitty-" + show (getpid 0))
   _ (mkdir dir 448)
   ser (dir + "/serial") disk (dir + "/disk")
   mach (hark ["uname" "-m"])
   kvm (two? (stat "/dev/kvm") && has? >mach "x86_64" ? ["-enable-kvm" "-cpu" "host"] ())
   _ (hark ["truncate" "-s" "35840000" disk])
   qemu (["timeout" "300" "qemu-system-x86_64" "-m" "1536M" "-M" "q35"
          "-device" "isa-debug-exit,iobase=0xf4,iosize=0x04"
          "-drive" ("file=" + disk + ",if=none,format=raw,id=d0") "-device" "virtio-blk-pci,drive=d0"]
         + kvm
         + ["-serial" ("file:" + ser) "-monitor" "stdio" "-display" "none" "-no-reboot" "-kernel" elf])
   pi (pipe 0) nul (openfd "/dev/null" 2)
   p (spawnio qemu <pi nul nul [>pi] -1 0)
   _ (close <pi) _ (close nul)
   mon (fdopen >pi)
   ; the serial text with CSI, APC/OSC/DCS strings and CRs gone
   (csi s i) (? (#s <= i) i (64 <= s i <= 126) (i + 1) (csi s (i + 1)))
   (st s i) (? (#s <= i) i (s i = 7) (i + 1) (s i = 27) (i + 2) (st s (i + 1)))
   (skip s i) (? (#s <= i + 1) (i + 1)
                 (s (i + 1) = 91) (csi s (i + 2))
                 (elem (s (i + 1)) '(80 93 95)) (st s (i + 2))
                 (i + 2))
   (strip1 s i j) (? (#s <= i) (slurp j)
                     (s i = 27) (strip1 s (skip s i) j)
                     (s i = 13) (strip1 s (i + 1) j)
                     (put j (s i), strip1 s (i + 1) j))
   (strip s) (strip1 s 0 (jug 0))
   (text _) (uread ser @ r (two? r ? (strip <>r) ""))
   ; seen within n tenths, polled every tenth
   (seen? m n) (? (has? (text 0) m) 1 (n <= 0) 0 (rest 100, seen? m (n - 1)))
   (key k) (say mon ("sendkey " + k + "\n"), flush mon, rest 150)
   (keys ks) (each ks key)
   ok1 (seen? "/home $" 1200)                          ; lush's prompt, in the first pane
   bar (has? (text 0) "hive")                          ; the bar, its hive count at the right
   _ (keys ["e" "x" "p" "r" "spc" "5" "0" "spc" "minus" "spc" "8" "ret"])
   ok2 (seen? "42" 300)                                ; expr's answer, painted in the pane
   _ (keys ["e" "x" "i" "t" "ret"])
   ok3 (seen? ";3 love" 300)                           ; the last pane ended: the console shell
   _ (keys ["shift-9" "r" "e" "s" "e" "t" "spc" "0" "shift-0" "ret"])
   st (wait p)
   self (charm? st && st != 124)                       ; timeout's 124 is the ceiling's
   _ (close mon)
   tail (text 0 @ t (snip t (max 0 (#t - 600)) #t))
   _ (hark ["rm" "-rf" dir])
   (ok1 && bar && ok2 && ok3 && self
    ? (puts "kmitty: ok -- the console came up a mitty, lush ran in its pane, exit gave the shell, reset ended the machine\n")
    (say err ("test_kmitty FAILED: prompt " + show ok1 + " bar " + show bar + " answer " + show ok2
              + " shell " + show ok3 + " exit " + show st + "\n-- the console's last words:\n" + tail + "\n"),
     quit 1)))
