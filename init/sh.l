; --- sh: a real (Unix) command shell in ai ---
; reads a line, runs real programs via spawn + wait -- inherited stdio, so output is
; LIVE and the command owns the terminal (not captured like `run`). this is the shell
; init execs on the console: the pid1 story end to end (init -> sh -> real programs).
; it rides the host/init.c job-control nifs (spawn/wait/chdir/cwd) + getenv, plus the
; v2 plumbing (pipe/openfd/spawnio/shutfd) for | < > >>. run:
;   out/host/ai -l init/sh.l -e "(sh 0)"
; line editing on a real tty is bao's own editor (`edln`, the baked shell core):
; in-line editing + up/down command history. `-l/-e` pass argv so main.c skips raw
; mode -- sh raws the tty itself (edln owns echo) and drops back to cooked around
; each child (programs want a normal tty), exactly the readline dance. piped /
; non-tty input falls back to the cooked-tty line reader (no editing, no history).
; EOF (^D) ends the shell; the loop is tail-recursive (no stack growth across commands).
;
; v2: '...' / "..." quoting, pipes (a | b | c), redirects (< > >>). operators are
; SPACE-SEPARATED (`a | b`, `cmd > file`); glued lexing (`a>b`) is a later pass. a
; missing command shows as the child's exit 127 (spawn forks then execs); pipes wire
; fds in C (spawnio's child dup2s + closes the pipe ends, so a downstream reader EOFs).

(: (sh-rev l) (foldl (\ a x (link x a)) () l)
   (sh-nth l i) (? (= i 0) (cap l) (sh-nth (cup l) (- i 1)))

   ; --- read one line (cooked tty): bytes until \n; 'eof at immediate EOF.
   (sh-getline port) (: c (get port) (? (< c 0) 'eof (= c 10) "" (+ (+ "" c) (sh-rest port))))
   (sh-rest port)    (: c (get port) (? (< c 0) ""   (= c 10) "" (+ (+ "" c) (sh-rest port))))

   ; --- tokenize: whitespace split, with '...' / "..." quoting (literal contents).
   ; operators (| < > >>) are ordinary space-separated word tokens, parsed below.
   (sh-ws? b) (? (= b 32) 1 (? (= b 9) 1 (= b 10)))
   (sh-words s) (sh-sc s 0 (tally s) "" 0 ())
   (sh-sc s i n cur started acc)
     (? (= i n) (sh-rev (? started (link cur acc) acc))
        (: b (s i)
           (? (sh-ws? b) (sh-sc s (+ i 1) n "" 0 (? started (link cur acc) acc))
              (= b 34)   (sh-quoted s (+ i 1) n cur 34 acc)        ; "
              (= b 39)   (sh-quoted s (+ i 1) n cur 39 acc)        ; '
              (sh-sc s (+ i 1) n (+ cur b) 1 acc))))
   (sh-quoted s i n cur q acc)                                     ; literal until the matching quote
     (? (= i n) (sh-rev (link cur acc))
        (: b (s i) (? (= b q) (sh-sc s (+ i 1) n cur 1 acc)
                      (sh-quoted s (+ i 1) n (+ cur b) q acc))))

   ; --- parse: split words on "|" into stages; pull < > >> + their files from each.
   (sh-split words) (sh-sp words () ())
   (sh-sp words cur acc)
     (? !words (sh-rev (link (sh-rev cur) acc))
        (: w (cap words) (? (= w "|") (sh-sp (cup words) () (link (sh-rev cur) acc))
                            (sh-sp (cup words) (link w cur) acc))))
   (sh-redirs words) (sh-rd words () () () 0)                      ; -> (argv infile outfile append?)
   (sh-rd words argv in out app)
     (? !words (L (sh-rev argv) in out app)
        (: w (cap words)
           (? (= w "<")  (sh-rd (cuup words) argv (caup words) out app)
              (= w ">")  (sh-rd (cuup words) argv in (caup words) 0)
              (= w ">>") (sh-rd (cuup words) argv in (caup words) 1)
              (sh-rd (cup words) (link w argv) in out app))))

   ; --- execute --------------------------------------------------------------------
   (sh-makepipes n) (? (< n 1) () (link (pipe 0) (sh-makepipes (- n 1))))
   (sh-flat ps) (? !ps () (link (cap (cap ps)) (link (cup (cap ps)) (sh-flat (cup ps)))))  ; (r w r w ..)

   ; one pipeline stage: wire in/out from the pipes (a file redirect overrides), spawn.
   (sh-stage stage pipes allfds i last)
     (: rd (sh-redirs stage) argv (sh-nth rd 0) inf (sh-nth rd 1) outf (sh-nth rd 2) app (sh-nth rd 3)
        pin  (? (= i 0)    (0 - 1) (cap (sh-nth pipes (- i 1))))   ; read prev pipe
        pout (? (= i last) (0 - 1) (cup (sh-nth pipes i)))         ; write this pipe
        ifd  (? inf  (openfd inf 0)            pin)
        ofd  (? outf (openfd outf (? app 2 1)) pout)
        pid  (spawnio argv ifd ofd (0 - 1) allfds)
        _    (? inf  (shutfd ifd) 0)  _ (? outf (shutfd ofd) 0)    ; parent drops the file fds
        pid)
   (sh-stages stages pipes allfds i last)
     (? !stages () (link (sh-stage (cap stages) pipes allfds i last)
                         (sh-stages (cup stages) pipes allfds (+ i 1) last)))

   ; single stage, no pipe: builtins, else a file-redirected spawn + wait.
   (sh-single stage)
     (: rd (sh-redirs stage) argv (sh-nth rd 0) inf (sh-nth rd 1) outf (sh-nth rd 2) app (sh-nth rd 3)
        (? !argv 0
           (: cmd (cap argv)
              (? (= cmd "exit") 'done
                 (= cmd "cd")   (: _ (chdir (? (cup argv) (caup argv) (getenv "HOME"))) 0)
                 (= cmd "pwd")  (: _ (puts (+ (cwd 0) "\n")) 0)
                 (: ifd (? inf  (openfd inf 0)            (0 - 1))
                    ofd (? outf (openfd outf (? app 2 1)) (0 - 1))
                    pid (spawnio argv ifd ofd (0 - 1) ())
                    _   (? inf  (shutfd ifd) 0)  _ (? outf (shutfd ofd) 0)
                    _   (wait pid)
                    0)))))

   (sh-run words)
     (: stages (sh-split words)
        (? (< (tally stages) 2) (sh-single (cap stages))
           (: n      (- (tally stages) 1)
              pipes  (sh-makepipes n)
              allfds (sh-flat pipes)
              pids   (sh-stages stages pipes allfds 0 n)
              _      (each allfds (\ fd (shutfd fd)))             ; parent closes every pipe fd
              _      (each pids   (\ p (wait p)))                 ; reap the whole pipeline
              0)))

   ; --- the REPL: a real tty gets edln (in-line editing + up/down history);
   ; piped / non-tty input gets the cooked-tty line reader. (sh _) probes with
   ; (raw 1): () = a tty (interactive), an errno = not a tty (cooked fallback).
   ; both loops are tail-recursive; ^D / `exit` ends the shell.
   (sh-cooked _)
     (: _    (say out (+ (cwd 0) "$ "))  _ (flush out)
        line (sh-getline in)
        (? (id? line 'eof) (puts "\n")
           (: words (sh-words line)
              (? !words (sh-cooked 0)
                 (: r (sh-run words) (? (id? r 'done) 0 (sh-cooked 0)))))))
   ; interactive: edln owns echo, so raw the tty for the prompt and drop to cooked
   ; around each child. edln returns (line . nhist) -- the raw charlist + the grown
   ; history -- or 'eof; thread nhist back in so up/down recall across commands.
   (sh-loop hist)
     (: r (edln in (+ (cwd 0) "$ ") hist)
        (? (id? r 'eof) (: _ (raw 0) (puts "\n"))                 ; cooked, newline, end
           (: line (cap r) nhist (cup r)
              words (sh-words (slurp (tap line)))                 ; charlist -> string for the tokenizer
              (? !words (sh-loop nhist)
                 (: _  (raw 0)                                    ; cooked for the child
                    rr (sh-run words)
                    (? (id? rr 'done) (raw 0)
                       (: _ (raw 1) (sh-loop nhist))))))))         ; re-raw for the next prompt
   (sh _) (: ok (raw 1) (? (nil? ok) (sh-loop ()) (sh-cooked 0))))
