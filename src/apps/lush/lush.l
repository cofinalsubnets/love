; lush 🐚, assembled: the shell state + job control, the lexer, the grammar,
; the glob, the word expander, the engine, the repl loops, then the entry +
; seat -- each part a (module 'lush form, so the parts register the one module
; and the loader keeps the file-made registration: this file loads the lot.
(use "src/apps/lush/job.l")
(use "src/apps/lush/lex.l")
(use "src/apps/lush/gram.l")
(use "src/apps/lush/glob.l")
(use "src/apps/lush/word.l")
(use "src/apps/lush/eval.l")
(use "src/apps/lush/line.l")
(use "src/apps/lush/main.l")
