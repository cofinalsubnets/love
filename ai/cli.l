; host CLI driver -- parse argv (after the program-name head) left to right:
;   -l/--load <file>    preload a file (read-eval it) before the program
;   -e/--eval <string>  read-eval the forms in a string (a program)
;   -v/--version        print the version and exit
;   -h/--help           print usage and exit
;   --                  end of options: the next arg is the program, the rest are its args
;   <file>              load the file (a program)
; with no program (no -e, no file), read-eval stdin to EOF. Loaded by main.c when args are
; present. `pre` handles leading -l preloads + -v/-h and returns (kind . rest); the global
; argv is then rebound (top-level (: argv ..) DEFGLOB -- book is mopped post-egg, so a
; pin/peep on it is a no-op; defglob writes g->book directly) to the program's view
; (program . args). cli.l is compiled by c0 BEFORE -l loads prel, so the always-run path
; (pre/load1/rdev) uses only nifs/special-forms, NOT prel fns (two? not atom?; |, the
; bitwise-or nif, not the || macro; link not the L macro for the export list).
;
; the helpers (rdev load1 eval1 bye version usage need pre) are CLOSURE-PRIVATE in the inner
; body-having `:`, OFF the global book -- only `parsed` and `argv` (the kept publics; argv is
; read by test/run.l + host/main.c) are defglob'd out, the cli sibling of the repl->bao
; consolidation. The triple holder is bound to `_`, NOT a name: a top-level body-less `:`
; defglobs every NAMED binding to the book, and this form RE-RUNS at startup (so an egg mop
; can't catch it), but `_` never leaks -- the intermediate stays off (names ()). The reads
; below pick it up by the sequence law. The inner body returns (parsed program-view-argv run),
; where `run` is the dispatch THUNK. Order matters: we defglob `argv` to the program's view
; FIRST, THEN call `(run 0)` -- the loaded program reads the global `argv`, so it must already
; be rebound before the load fires. (-v/-h still exit inside `pre`, before the rebind, as before.)
(: _
 (: (rdev q) ((: (go e q) (: r (scan q e) (? (= e r) 0 (: _ (ev 'ev r) (go e q))))) (mint 0) q)
    (load1 p) (: q (open p "r")
       (? q (rdev q) (: _ (say err (+ "ai: cannot open " p)) (nap 1))))
    (eval1 s) (rdev (tap (map s (jot (tally s)))))   ; a string is a fn over its bytes -> a charlist port
    (bye s) (: _ (puts s) _ (putc 10) _ (flush out) (nap 0))   ; print a line to out, flush, exit 0
    (version _) (bye (+ "ai " ai-version))                       ; _ arg: ai has no nullary calls
    (usage _) (bye (+ "usage: ai [-l FILE] [-e EXPR] [-v] [-h] [--] [FILE ...]\n"
               (+ "  -l, --load FILE   preload FILE (read-eval) before the program\n"
               (+ "  -e, --eval EXPR   read-eval the forms in EXPR\n"
               (+ "  -v, --version     print the version and exit\n"
               (+ "  -h, --help        print this help and exit\n"
               (+ "  --                end of options; the rest are files\n"
                  "with no program (no -e, no FILE), read-eval stdin to EOF.")))))))
    (need h t) (? (two? t) 0 (: _ (say err (+ "ai: " (+ h " needs an argument"))) (nap 2)))
    (pre a) (? (two? a)                              ; -> (kind . rest): 'eval code.args / 'file prog.args / 'stdin
     (: h (cap a) t (cup a) (?
      (| (= h "-l") (= h "--load"))    (: _ (need h t) _ (load1 (cap t)) (pre (cup t)))
      (| (= h "-v") (= h "--version")) (version 0)
      (| (= h "-h") (= h "--help"))    (usage 0)
      (| (= h "-e") (= h "--eval"))    (: _ (need h t) (link 'eval t))
      (= h "--")                        (? (two? t) (link 'file t) (link 'stdin 0))
      (link 'file a)))                  ; a positional file is the program
     (link 'stdin 0))
    p (pre (cup argv))                  ; runs -l preloads + -v/-h; the program kind
    av (? (= (cap p) 'eval) (cup (cup p)) (cup p))   ; the program's view of argv
    run (\ _ (? (= (cap p) 'eval) (eval1 (caup p))   ; the dispatch thunk: -e code / a file / stdin
              (= (cap p) 'file) (load1 (caup p))
              (rdev in)))
    (link p (link av (link run 0))))    ; the body: return (parsed program-argv run)
 parsed (cap _)                         ; DEFGLOB the kept publics out of the triple (the prev `_`)
 argv   (cap (cup _))                   ; rebind argv to the program's view, BEFORE the run
 _ ((caup (cup _)) 0))                  ; (run 0): dispatch now that argv is the program's view
