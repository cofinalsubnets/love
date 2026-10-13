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
   fails (? (getenv "PROCLAW" != "kept") "the process moved its parent's environment"
            (cwd 0 != "/tmp") "the process moved its parent's cwd"
            (<a != 7) ("status " + show <a + ", not 7")
            (>a != "kept\n/tmp\n/etc\n") ("the shell wrote " + show >a)
            (<b != 0 || >b != "\"/tmp\"") ("love wrote " + show >b + ", status " + show <b)
            ())
   (puts (two? fails || string? fails ? ("proc: failed: " + fails + "\n") "proc: ok\n")))
