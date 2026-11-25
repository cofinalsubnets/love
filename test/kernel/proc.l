; test/kernel/proc.l -- a process: love woken from the machine's own image, in memory of its own,
; its calls answered through the kernel. it starts in its parent's cwd and environment and
; changes neither, its stdio is the stdio of the task that starts it, and its status comes back
; to that task. a seat that cannot run one says so and passes nothing. the wasm lane runs it,
; and x64's test_kernel_uproc.
(: o "/tmp/proc.out"
   chdir (cite 'posix 'chdir) cwd (cite 'posix 'cwd)
   ; the process's words, with its stdout and stderr on a file -> (status . what it wrote)
   (run argv) (: w (worn ())
                 q (open o "w")
                 _ (wear [<w q q])
                 st (proc-main argv)
                 _ (wear w)
                 _ (close q)
                 r (open o "r")
                 (st . (slurp r @ t (close r, t))))
   _ (chdir "/tmp")
   _ (setenv "PROCLAW" "kept")
   a (run ["sh" "-c" "echo $PROCLAW; pwd; cd /etc; pwd; export PROCLAW=moved; exit 7"])
   b (run ["-e" "(: _ (say out (show ((cite 'posix 'cwd) 0))) (quit 0))"])
   ; the console's 24-bit colour reaches a process: lore's check, baked against its getenv
   c (run ["-e" "(: _ (say out (show ((cite 'view 'view-deep?) 0))) (quit 0))"])
   ; its machine's memory is the kernel's heap: sysconf's pages hold /proc/meminfo's ram-words,
   ; a word 4 or 8 bytes, to within a page
   d (run ["-e" "(: s ((cite 'posix 'sysconf) 0) _ (say out (show (s 0) + \" \" + show (s 3 * s 0))) (quit 0))"])
   rw (open "/proc/meminfo" "r" @ q (slurp q @ t (close q, t @ "ram-words \(n)\n\(_)" (read n) 0)))
   mem (>d @ "\(z) \(n)" (: sz (read z) b (read n) u (rw > 0 ? ((b + rw // 2) // rw) 0)
                           (elem u [4 8] && b <= u * rw < b + sz))
         _ 0)
   fails (? (getenv "PROCLAW" != "kept") "the process moved its parent's environment"
            (cwd 0 != "/tmp") "the process moved its parent's cwd"
            (<a != 7) ("status " + show <a + ", not 7, wrote " + show >a)
            (>a != "kept\n/tmp\n/etc\n") ("the shell wrote " + show >a)
            (<b != 0 || >b != "\"/tmp\"") ("love wrote " + show >b + ", status " + show <b)
            (<c != 0 || >c != "1") ("lore's colour check wrote " + show >c + ", status " + show <c)
            (<d != 0 || !mem) ("sysconf wrote " + show >d + " beside ram-words " + show rw)
            ())
   (puts (two? fails || string? fails ? ("proc: failed: " + fails + "\n") "proc: ok\n")))
