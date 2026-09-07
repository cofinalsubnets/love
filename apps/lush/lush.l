; lush 🐚, assembled: the shell state + job control, the lexer, the grammar,
; the glob, the word expander, the engine, the repl loops, then the entry +
; seat -- each part a (module 'lush form, so the parts register the one module
; and the loader keeps the file-made registration: this file loads the lot.
(use "apps/lush/job.l")
(use "apps/lush/lex.l")
(use "apps/lush/gram.l")
(use "apps/lush/glob.l")
(use "apps/lush/word.l")
(use "apps/lush/eval.l")
(use "apps/lush/line.l")
(use "apps/lush/main.l")
