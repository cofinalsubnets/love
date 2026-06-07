; gen_claudemd.g -- regenerate CLAUDE.md from test/lang.g (the source of truth).
; CLAUDE.md is just test/lang.g wrapped in a ```gwen fenced code block, so the
; project guide and a runnable, asserted test stay the same artifact. Run from the
; repo root: `out/host/gl tools/gen_claudemd.g` (driven by `make claudemd`).
(: (die m) (: _ (fputs err m) _ (fputc err 10) (exit 1))
   src (open "test/lang.g" "r")
   _ (? src 0 (die "gen_claudemd: cannot open test/lang.g"))
   text (slurp src)
   _ (close src)
   dst (open "CLAUDE.md" "w")
   _ (? dst 0 (die "gen_claudemd: cannot open CLAUDE.md for writing"))
   _ (fputs dst "```gwen") _ (fputc dst 10)         ; open fence
   _ (fputs dst text)                                ; lang.g verbatim (ends in newline)
   _ (fputs dst "```") _ (fputc dst 10)             ; close fence
   (close dst))
