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
; (program . args); cmdline keeps the full list. cli.l is compiled by c0 BEFORE -l loads
; prel, so the always-run path (pre/load1/rdev) uses only nifs/special-forms, NOT prel
; fns (chainp not atomp; |, the bitwise-or nif, not the || macro).
(: (rdev q) ((: (go e q) (: r (read q e) (? (= e r) 0 (: _ (ev 'ev r) (go e q))))) (mint 0) q)
   (load1 p) (: q (open p "r")
      (? q (rdev q) (: _ (fputs err (+ "ai: cannot open " p)) (exit 1))))
   (eval1 s) (rdev (sip (map s (jot (tally s)))))   ; a string is a fn over its bytes -> a charlist port
   (bye s) (: _ (puts s) _ (putc 10) _ (fflush out) (exit 0))   ; print a line to out, flush, exit 0
   (version _) (bye (+ "ai " ai-version))                       ; _ arg: ai has no nullary calls
   (usage _) (bye (+ "usage: ai [-l FILE] [-e EXPR] [-v] [-h] [--] [FILE ...]\n"
              (+ "  -l, --load FILE   preload FILE (read-eval) before the program\n"
              (+ "  -e, --eval EXPR   read-eval the forms in EXPR\n"
              (+ "  -v, --version     print the version and exit\n"
              (+ "  -h, --help        print this help and exit\n"
              (+ "  --                end of options; the rest are files\n"
                 "with no program (no -e, no FILE), read-eval stdin to EOF.")))))))
   (need h t) (? (chainp t) 0 (: _ (fputs err (+ "ai: " (+ h " needs an argument"))) (exit 2)))
   (pre a) (? (chainp a)                              ; -> (kind . rest): 'eval code.args / 'file prog.args / 'stdin
    (: h (cap a) t (cup a) (?
     (| (= h "-l") (= h "--load"))    (: _ (need h t) _ (load1 (cap t)) (pre (cup t)))
     (| (= h "-v") (= h "--version")) (version 0)
     (| (= h "-h") (= h "--help"))    (usage 0)
     (| (= h "-e") (= h "--eval"))    (: _ (need h t) (link 'eval t))
     (= h "--")                        (? (chainp t) (link 'file t) (link 'stdin 0))
     (link 'file a)))                  ; a positional file is the program
    (link 'stdin 0)))
(: parsed (pre (cup argv)))                         ; runs -l preloads + -v/-h; returns the program kind
(: argv (? (= (cap parsed) 'eval) (cup (cup parsed)) (cup parsed)))  ; DEFGLOB: rebind argv to the program's view
(? (= (cap parsed) 'eval) (eval1 (caup parsed))     ; run the program: -e code / a file / stdin
   (= (cap parsed) 'file) (load1 (caup parsed))
   (rdev in))
