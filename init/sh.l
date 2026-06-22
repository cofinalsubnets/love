; --- sh: a real (Unix) command shell in ai ---
; reads a line, runs real programs via spawn + wait -- inherited stdio, so output is
; LIVE and the command owns the terminal (not captured like `run`). this is the shell
; init execs on the console: the pid1 story end to end (init -> sh -> real programs).
; it rides the host/init.c job-control nifs (spawn / wait / chdir / cwd) + getenv;
; external commands resolve through PATH (execvp). builtins: cd, exit, pwd. run:
;   out/host/ai -l init/sh.l -e "(sh 0)"
; line editing is the terminal's (cooked tty): -l/-e pass argv, so ai skips its own raw
; mode and the kernel tty echoes + buffers each line. a NON-tty stdin (a pipe) works too
; -- getline reads to \n / EOF, and EOF (^D) ends the shell. NB: a missing command shows
; as the child's exit 127 (spawn forks then execs, so the parent only sees the status) --
; the errno-pipe trick `run` uses would name it; left as polish.

(: (sh-rev l) (foldl (\ a x (link x a)) () l)

   ; --- read one line off `port` (cooked tty): bytes until \n; 'eof at immediate EOF.
   ; get returns the byte, or a negative (EOF) at end of stream.
   (sh-getline port) (: c (get port) (? (< c 0) 'eof (= c 10) "" (+ (+ "" c) (sh-rest port))))
   (sh-rest port)    (: c (get port) (? (< c 0) ""   (= c 10) "" (+ (+ "" c) (sh-rest port))))

   ; --- whitespace split -> a list of non-empty word strings (no quoting yet).
   (sh-ws? b)         (? (= b 32) 1 (? (= b 9) 1 (= b 10)))
   (sh-flush cur acc) (? !cur acc (link cur acc))               ; push cur if non-empty
   (sh-tok s i n cur acc)
     (? (= i n) (sh-rev (sh-flush cur acc))
        (: b (s i)
           (? (sh-ws? b) (sh-tok s (+ i 1) n "" (sh-flush cur acc))
              (sh-tok s (+ i 1) n (+ cur b) acc))))
   (sh-words s) (sh-tok s 0 (tally s) "" ())

   ; --- run one argv: a builtin, or spawn+wait an external. returns 'done to quit.
   (sh-run argv)
     (: cmd (cap argv)  rest (cup argv)
        (? (= cmd "exit") 'done
           (= cmd "cd")   (: _ (chdir (? rest (cap rest) (getenv "HOME"))) 0)
           (= cmd "pwd")  (: _ (puts (+ (cwd 0) "\n")) 0)
           (: pid (spawn argv)                                  ; fork+exec, inherited stdio
              (? (< pid 0) (: _ (puts (+ "sh: cannot spawn " cmd)) 0)
                 (: _ (wait pid) 0)))))                         ; BLOCK for the foreground job

   ; --- the REPL: prompt, read, tokenize, run; loop until exit / EOF (tail-recursive).
   (sh _)
     (: _    (say out (+ (cwd 0) "$ "))  _ (flush out)         ; the prompt
        line (sh-getline in)
        (? (id? line 'eof) (puts "\n")                         ; ^D / end of input -> leave
           (: argv (sh-words line)
              (? !argv (sh 0)                                  ; blank line -> reprompt
                 (: r (sh-run argv) (? (id? r 'done) 0 (sh 0))))))))
