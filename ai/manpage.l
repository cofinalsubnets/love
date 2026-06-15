; generates the manual page: out/host/ai.1 (groff -man source on stdout)
(:
 (putln s) (: _ (puts s) (putc 10))
 concat (foldl (+) "")
 sec "1"
 nom "ai"
 upnom "AI"
 section (+ ".SH ")
 (fmt i s) (concat (L "\\f[" i "]" s "\\f[R]"))
 bold (fmt "B")
 ital (fmt "I")
 lines (L
   (concat (L ".TH \"" upnom "\" \"" sec "\" \"\" \"Version " ai-version "\" \"" upnom "\""))
   (section "NAME")
   (+ (bold nom) " \\- list expression interpreter")
   (section "SYNOPSIS")
   ".PP"
   (concat (L (bold nom) " [" (bold "-l") (ital " lib") "] [" (ital "file") (ital "\\&...") "]"))
   (section "DESCRIPTION")
   (+ nom " is a small lisp where every value is a total function of one argument.")
   (section "COMMAND LINE OPTIONS")
   ".TP"
   ".B \\-l \\fIlib\\fR"
   "load lib before processing the remaining arguments"
   ".TP"
   ".I file\\&..."
   "scripts to eval"
   ".TP"
   "If arguments are given, process them in order and exit; else if stdin is a tty then start a repl; else eval stdin.")
 (each lines putln))
