; test/kernel/cprog.l -- a C program is a process: a `mooncc -t wasm` module in the ramfs runs
; as itself, in memory of its own, its calls through the kernel. the wasm lane hands in
; test/kernel/c/{hello,cat}.c built on the host, at /mnt/host. the shell runs them as a process
; does and as the kernel's own shell does: by path and on PATH, a C cat in a pipeline with a love
; verb, their words, cwd, environment and status their own.
(: o "/tmp/cprog.out"
   chdir (cite 'posix 'chdir) mkdir (cite 'posix 'mkdir)
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
   _ (cp "/mnt/host/hello.wasm" "/tmp/c/hello")
   _ (cp "/mnt/host/cat.wasm" "/tmp/c/cat")
   _ (chdir "/tmp")
   ; the kernel's own shell keeps its exports from a child (not yet one environment), so only
   ; the process's line hands HELLO on
   (line env) ("""/tmp/c/hello one 7; echo "st $?"
echo three four | /tmp/c/cat | wc -w
cd /tmp/c && ./cat /nope; echo "st $?"
ls | ./cat
export PATH=/tmp/c:$PATH
""" + env + """hello two 0
exit 3""")
   (want h) ("""hello from C: one 7 in /tmp, HELLO=unset
st 7
2
cat: cannot open
st 1
cat
hello
hello from C: two 0 in /tmp/c, HELLO=""" + h + "\n")
   ; lush as a process, and lush as the kernel's own task
   a (onto (_ \ proc-main ["sh" "-c" (line "export HELLO=hi; ")]))
   b (onto (_ \ spawn ["sh" "-c" (line "")] @ p (wait p)))
   fails (? (<a != 3) ("process: status " + show <a + ", not 3")
            (>a != want "hi") ("process: the shell wrote " + show >a)
            (<b != 3) ("kernel: status " + show <b + ", not 3")
            (>b != want "unset") ("kernel: the shell wrote " + show >b)
            ())
   (puts (string? fails ? ("cprog: failed: " + fails + "\n") "cprog: ok\n"), reset 0))
