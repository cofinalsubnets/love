; test/kernel/spawn.l -- a process starts processes: posix_spawn makes a new one through the
; kernel, wait4 brings its status back, kill ends it. the shell runs as a process here: a
; pipeline of two love processes, a stage of the shell's own in its heap beside a process, a
; capture, and background jobs -- a process and a stage -- that kill reaches and whose cd
; stays theirs. the wasm lane runs it.
(: o "/tmp/spawn.out"
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
   line """love -e '(: _ (say out "one two three\n") (quit 0))' | love wc -w
echo four five | wc -w
echo x | (cat; exit 6); echo "stage $?"
sleep 5 & kill $!; wait $!; echo "process $?"
(while :; do :; done) & kill $!; wait $!; echo "task $?"
(cd /etc; true) & wait; pwd
x=$(echo in | cat); echo "[$x]"
exit 3"""
   want "3\n2\nx\nstage 6\nprocess 143\ntask 143\n/tmp\n[in]\n"
   a (run ["sh" "-c" line])
   fails (? (cwd 0 != "/tmp") "the shell moved its parent's cwd"
            (<a != 3) ("status " + show <a + ", not 3")
            (>a != want) ("the shell wrote " + show >a)
            ())
   (puts (two? fails || string? fails ? ("spawn: failed: " + fails + "\n") "spawn: ok\n"), reset 0))
