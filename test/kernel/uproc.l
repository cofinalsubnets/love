; test/kernel/uproc.l -- a C program as an x64 process: the ELF the lane hands in at /proc/initrd
; (test/kernel/c/hello.c, the host's mooncc's) runs in ring 3, in an address space of its own, its
; calls through the kernel -- started by the kernel and by the kernel's own shell. its words, cwd,
; environment and status are its own; the kernel's memory is not, to read or to hand over. a seat
; with no /proc/initrd skips
(stat "/proc/initrd" @ st
 (!(two? st) ? (puts "uproc: no /proc/initrd here, laws skipped", putc 10, ())
  (: o "/tmp/uproc.out"
     chdir (cite 'posix 'chdir) mkdir (cite 'posix 'mkdir) was ((cite 'posix 'cwd) 0)
     (cp a b) (: i (open a "r") t (slurp i) _ (close i) q (open b "w") _ (say q t) (close q))
     ; f run with its stdout and stderr on a file -> (status . what it wrote)
     (onto f) (: w (worn ())
                q (open o "w")
                _ (wear [<w q q])
                st (f ())
                _ (wear w)
                _ (close q)
                r (open o "r")
                (st . (slurp r @ t (close r, t))))
     _ (mkdir "/tmp/c" 493)
     _ (cp "/proc/initrd" "/tmp/c/hello")
     _ (chdir "/tmp")
     _ (setenv "HELLO" "hi")
     a (onto (_ \ proc-main ["/tmp/c/hello" "one" "7"]))
     b (onto (_ \ spawn ["sh" "-c" "cd c && ./hello two 0; echo st $?"] @ p (wait p)))
     c (onto (_ \ proc-main ["/tmp/c/hello" "peek"]))
     d (onto (_ \ proc-main ["/tmp/c/hello" "poke"]))
     fails (? (<a != 7) ("by the kernel: status " + show <a + ", not 7")
              (>a != "hello from C: one 7 in /tmp, HELLO=hi\n") ("by the kernel: wrote " + show >a)
              (<b != 0) ("by its shell: status " + show <b + ", not 0")
              (>b != "hello from C: two 0 in /tmp/c, HELLO=hi\nst 0\n") ("by its shell: wrote " + show >b)
              (<c != 139) ("a read of the kernel: status " + show <c + ", not 139")
              (<d != 3) ("the kernel handed to write: status " + show <d + ", not 3")
              ())
     _ (chdir was)
     _ (test (!(string? fails)))
   (puts (string? fails ? ("uproc: failed: " + fails + "\n") "uproc: ok\n")))))
