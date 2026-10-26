; src/apps/caja/mouth.l -- caja's mouth, tex.web parts 5-7 and 17-29 section for section:
; printing, errors, eqtb and the save stack, the hash, the input stack, get_next, expansion,
; scanning, conditionals and \input. the first part of the module caja-tex; exec.l follows.
; tex.web's globals are J's fields; eqtb is the tablets 'eq 'et 'el 'xl; a token is tex.web's
; integer; a token list is a love list, a pointer into it the list from there, compared by ==.
(module 'caja-tex
(borrow 'posix)
(borrow 'tfm)
(borrow 'caja-box)
(:
   ; --- tex.web's constants, under their own names (let is let-cmd: let is a macro) ------
   hash-size 60000 no-print 16 term-only 17 log-only 18 term-and-log 19 pseudo 20 new-string 21
   max-selector 21 batch-mode 0 nonstop-mode 1 scroll-mode 2 error-stop-mode 3 spotless 0
   warning-issued 1 error-message-issued 2 fatal-error-stop 3 inf-bad 10000 hlist-node 0
   width-offset 1 depth-offset 2 height-offset 3 normal 0 vlist-node 1 rule-node 2 ins-node 3
   mark-node 4 adjust-node 5 ligature-node 6 disc-node 7 whatsit-node 8 math-node 9 glue-node 10
   cond-math-glue 98 mu-glue 99 a-leaders 100 c-leaders 101 x-leaders 102 fil 1 fill 2 filll 3
   kern-node 11 explicit 1 penalty-node 12 unset-node 13 escape 0 relax 0 left-brace 1
   right-brace 2 math-shift 3 tab-mark 4 car-ret 5 out-param 5 mac-param 6 sup-mark 7 sub-mark 8
   ignore 9 endv 9 spacer 10 letter 11 other-char 12 active-char 13 par-end 13 match 13 comment 14
   end-match 14 stop 14 invalid-char 15 delim-num 15 max-char-code 15 char-num 16 math-char-num 17
   mark 18 xray 19 make-box 20 hmove 21 vmove 22 un-hbox 23 un-vbox 24 remove-item 25 hskip 26
   vskip 27 mskip 28 kern 29 mkern 30 leader-ship 31 halign 32 valign 33 no-align 34 vrule 35
   hrule 36 insert 37 vadjust 38 ignore-spaces 39 after-assignment 40 after-group 41
   break-penalty 42 start-par 43 ital-corr 44 accent 45 math-accent 46 discretionary 47 eq-no 48
   left-right 49 math-comp 50 limit-switch 51 above 52 math-style 53 math-choice 54 non-script 55
   vcenter 56 case-shift 57 message 58 extension 59 in-stream 60 begin-group 61 end-group 62
   omit 63 ex-space 64 no-boundary 65 radical 66 end-cs-name 67 min-internal 68 char-given 68
   math-given 69 last-item 70 max-non-prefixed-command 70 toks-register 71 assign-toks 72
   assign-int 73 assign-dimen 74 assign-glue 75 assign-mu-glue 76 assign-font-dimen 77
   assign-font-int 78 set-aux 79 set-prev-graf 80 set-page-dimen 81 set-page-int 82
   set-box-dimen 83 set-shape 84 def-code 85 def-family 86 set-font 87 def-font 88 register 89
   max-internal 89 advance 90 multiply 91 divide 92 prefix 93 let-cmd 94 shorthand-def 95
   read-to-cs 96 def 97 set-box 98 hyph-data 99 set-interaction 100 max-command 100
   undefined-cs 101 expand-after 102 no-expand 103 input 104 if-test 105 fi-or-else 106
   cs-name 107 convert 108 the 109 top-bot-mark 110 call 111 long-call 112 outer-call 113
   long-outer-call 114 end-template 115 dont-expand 116 glue-ref 117 shape-ref 118 box-ref 119
   data 120 vmode 1 hmode 102 mmode 203 level-zero 0 level-one 1 active-base 1 single-base 257
   null-cs 513 hash-base 514 frozen-control-sequence 60514 frozen-protection 60514 frozen-cr 60515
   frozen-end-group 60516 frozen-right 60517 frozen-fi 60518 frozen-end-template 60519
   frozen-endv 60520 frozen-relax 60521 end-write 60522 frozen-dont-expand 60523
   frozen-null-font 60524 font-id-base 60524 undefined-control-sequence 60781 glue-base 60782
   line-skip-code 0 baseline-skip-code 1 par-skip-code 2 above-display-skip-code 3
   below-display-skip-code 4 above-display-short-skip-code 5 below-display-short-skip-code 6
   left-skip-code 7 right-skip-code 8 top-skip-code 9 split-top-skip-code 10 tab-skip-code 11
   space-skip-code 12 xspace-skip-code 13 par-fill-skip-code 14 thin-mu-skip-code 15
   med-mu-skip-code 16 thick-mu-skip-code 17 glue-pars 18 skip-base 60800 mu-skip-base 61056
   local-base 61312 output-routine-loc 61313 every-par-loc 61314 every-math-loc 61315
   every-display-loc 61316 every-hbox-loc 61317 every-vbox-loc 61318 every-job-loc 61319
   every-cr-loc 61320 err-help-loc 61321 toks-base 61322 box-base 61578 cur-font-loc 61834
   math-font-base 61835 cat-code-base 61883 lc-code-base 62139 uc-code-base 62395
   sf-code-base 62651 math-code-base 62907 int-base 63163 pretolerance-code 0 tolerance-code 1
   line-penalty-code 2 hyphen-penalty-code 3 ex-hyphen-penalty-code 4 club-penalty-code 5
   widow-penalty-code 6 display-widow-penalty-code 7 broken-penalty-code 8 bin-op-penalty-code 9
   rel-penalty-code 10 pre-display-penalty-code 11 post-display-penalty-code 12
   inter-line-penalty-code 13 double-hyphen-demerits-code 14 final-hyphen-demerits-code 15
   adj-demerits-code 16 mag-code 17 delimiter-factor-code 18 looseness-code 19 time-code 20
   day-code 21 month-code 22 year-code 23 show-box-breadth-code 24 show-box-depth-code 25
   hbadness-code 26 vbadness-code 27 pausing-code 28 tracing-online-code 29 tracing-macros-code 30
   tracing-stats-code 31 tracing-paragraphs-code 32 tracing-pages-code 33 tracing-output-code 34
   tracing-lost-chars-code 35 tracing-commands-code 36 tracing-restores-code 37 uc-hyph-code 38
   output-penalty-code 39 max-dead-cycles-code 40 hang-after-code 41 floating-penalty-code 42
   global-defs-code 43 cur-fam-code 44 escape-char-code 45 default-hyphen-char-code 46
   default-skew-char-code 47 end-line-char-code 48 new-line-char-code 49 language-code 50
   left-hyphen-min-code 51 right-hyphen-min-code 52 holding-inserts-code 53
   error-context-lines-code 54 int-pars 55 count-base 63218 del-code-base 63474 dimen-base 63730
   par-indent-code 0 math-surround-code 1 line-skip-limit-code 2 hsize-code 3 vsize-code 4
   max-depth-code 5 split-max-depth-code 6 box-max-depth-code 7 hfuzz-code 8 vfuzz-code 9
   delimiter-shortfall-code 10 null-delimiter-space-code 11 script-space-code 12
   pre-display-size-code 13 display-width-code 14 display-indent-code 15 overfull-rule-code 16
   hang-indent-code 17 h-offset-code 18 v-offset-code 19 emergency-stretch-code 20
   scaled-base 63751 eqtb-size 64006 restore-old-value 0 restore-zero 1 insert-token 2
   level-boundary 3 bottom-level 0 simple-group 1 hbox-group 2 adjusted-hbox-group 3 vbox-group 4
   vtop-group 5 align-group 6 no-align-group 7 output-group 8 math-group 9 disc-group 10
   insert-group 11 vcenter-group 12 math-choice-group 13 semi-simple-group 14 math-shift-group 15
   math-left-group 16 max-group-code 16 left-brace-token 256 left-brace-limit 512
   right-brace-token 512 right-brace-limit 768 math-shift-token 768 tab-token 1024
   out-param-token 1280 space-token 2592 letter-token 2816 other-token 3072 match-token 3328
   end-match-token 3584 mid-line 1 skip-blanks 17 new-line 33 skipping 1 defining 2 matching 3
   aligning 4 absorbing 5 token-list 0 parameter 0 u-template 1 v-template 2 backed-up 3
   inserted 4 macro 5 output-text 6 every-par-text 7 every-math-text 8 every-display-text 9
   every-hbox-text 10 every-vbox-text 11 every-job-text 12 every-cr-text 13 mark-text 14
   write-text 15 no-expand-flag 257 top-mark-code 0 first-mark-code 1 bot-mark-code 2
   split-first-mark-code 3 split-bot-mark-code 4 int-val 0 dimen-val 1 glue-val 2 mu-val 3
   ident-val 4 tok-val 5 input-line-no-code 3 badness-code 4 octal-token 3111 alpha-token 3168
   point-token 3118 continental-point-token 3116 zero-token 3120 A-token 2881 other-A-token 3137
   default-rule 26214 number-code 0 roman-numeral-code 1 string-code 2 meaning-code 3
   font-name-code 4 job-name-code 5 closed 2 just-open 1 if-char-code 0 if-cat-code 1
   if-int-code 2 if-dim-code 3 if-odd-code 4 if-vmode-code 5 if-hmode-code 6 if-mmode-code 7
   if-inner-code 8 if-void-code 9 if-hbox-code 10 if-vbox-code 11 ifx-code 12 if-eof-code 13
   if-true-code 14 if-false-code 15 if-case-code 16 if-code 1 fi-code 2 else-code 3 or-code 4
   slant-code 1 space-code 2 space-stretch-code 3 space-shrink-code 4 x-height-code 5 quad-code 6
   extra-space-code 7 ord-noad 16 op-noad 17 bin-noad 18 rel-noad 19 open-noad 20 close-noad 21
   punct-noad 22 inner-noad 23 limits 1 no-limits 2 radical-noad 24 fraction-noad 25 under-noad 26
   over-noad 27 accent-noad 28 vcenter-noad 29 left-noad 30 right-noad 31 style-node 14
   display-style 0 text-style 2 script-style 4 script-script-style 6 choice-node 15 text-size 0
   script-size 16 script-script-size 32 span-code 256 cr-code 257 cr-cr-code 258 fil-code 0
   fill-code 1 ss-code 2 fil-neg-code 3 skip-code 4 mskip-code 5 box-code 0 copy-code 1
   last-box-code 2 vsplit-code 3 vtop-code 4 above-code 0 over-code 1 atop-code 2 delimited-code 3
   char-def-code 0 math-char-def-code 1 count-def-code 2 dimen-def-code 3 skip-def-code 4
   mu-skip-def-code 5 toks-def-code 6 show-box-code 1 show-the-code 2 show-lists-code 3
   open-node 0 write-node 1 close-node 2 special-node 3 immediate-code 4 set-language-code 5
   unity 65536 two 131072 carriage-return 13 invalid-code 127 null-code 0 inf-penalty 10000
   eject-penalty -10000 stack-size 5000 max-in-open 15 param-size 60 save-size 50000
   buf-size 200000 infinity-int 2147483647 null-list () cs-token-flag 4095 hex-token 3106
   max-dimen 1073741823 null-flag -1073741824 ignore-depth -65536000 null-font 0 font-base 0
   par-shape-loc local-base show-code 0 var-code 28672 empty 0 inserts-only 1 box-there 2

   ; a character as print shows it: itself when printable, else ^^ notation (tex.web 48-49)
   char-str (foldl (\ t k (pin t k (? (32 <= k <= 126) (string k)
                                    (k < 64) ("^^" + string (k + 64))
                                    (k < 128) ("^^" + string (k - 64))
                                    ("^^" + string (k // 16 @ d (d < 10 ? (48 + d) (87 + d)))
                                     + string (k % 16 @ d (d < 10 ? (48 + d) (87 + d)))))))
                   {} ^256)
   months "JANFEBMARAPRMAYJUNJULAUGSEPOCTNOVDEC"

   skip-param-names ["lineskip" "baselineskip" "parskip" "abovedisplayskip" "belowdisplayskip"
      "abovedisplayshortskip" "belowdisplayshortskip" "leftskip" "rightskip" "topskip"
      "splittopskip" "tabskip" "spaceskip" "xspaceskip" "parfillskip" "thinmuskip" "medmuskip"
      "thickmuskip"]
   int-param-names ["pretolerance" "tolerance" "linepenalty" "hyphenpenalty" "exhyphenpenalty"
      "clubpenalty" "widowpenalty" "displaywidowpenalty" "brokenpenalty" "binoppenalty"
      "relpenalty" "predisplaypenalty" "postdisplaypenalty" "interlinepenalty"
      "doublehyphendemerits" "finalhyphendemerits" "adjdemerits" "mag" "delimiterfactor"
      "looseness" "time" "day" "month" "year" "showboxbreadth" "showboxdepth" "hbadness"
      "vbadness" "pausing" "tracingonline" "tracingmacros" "tracingstats" "tracingparagraphs"
      "tracingpages" "tracingoutput" "tracinglostchars" "tracingcommands" "tracingrestores"
      "uchyph" "outputpenalty" "maxdeadcycles" "hangafter" "floatingpenalty" "globaldefs" "fam"
      "escapechar" "defaulthyphenchar" "defaultskewchar" "endlinechar" "newlinechar" "language"
      "lefthyphenmin" "righthyphenmin" "holdinginserts" "errorcontextlines"]
   dimen-param-names ["parindent" "mathsurround" "lineskiplimit" "hsize" "vsize" "maxdepth"
      "splitmaxdepth" "boxmaxdepth" "hfuzz" "vfuzz" "delimitershortfall" "nulldelimiterspace"
      "scriptspace" "predisplaysize" "displaywidth" "displayindent" "overfullrule" "hangindent"
      "hoffset" "voffset" "emergencystretch"]
   ; the primitives whose meaning a frozen control sequence copies
   frozen-of {"endgroup" frozen-end-group "relax" frozen-relax "fi" frozen-fi
              "nullfont" frozen-null-font "cr" frozen-cr "right" frozen-right}
   ; every primitive (tex.web 226-1344): name, command, modifier
   primitive-table [["lineskip" assign-glue (glue-base + line-skip-code)]
      ["baselineskip" assign-glue (glue-base + baseline-skip-code)]
      ["parskip" assign-glue (glue-base + par-skip-code)]
      ["abovedisplayskip" assign-glue (glue-base + above-display-skip-code)]
      ["belowdisplayskip" assign-glue (glue-base + below-display-skip-code)]
      ["abovedisplayshortskip" assign-glue (glue-base + above-display-short-skip-code)]
      ["belowdisplayshortskip" assign-glue (glue-base + below-display-short-skip-code)]
      ["leftskip" assign-glue (glue-base + left-skip-code)]
      ["rightskip" assign-glue (glue-base + right-skip-code)]
      ["topskip" assign-glue (glue-base + top-skip-code)]
      ["splittopskip" assign-glue (glue-base + split-top-skip-code)]
      ["tabskip" assign-glue (glue-base + tab-skip-code)]
      ["spaceskip" assign-glue (glue-base + space-skip-code)]
      ["xspaceskip" assign-glue (glue-base + xspace-skip-code)]
      ["parfillskip" assign-glue (glue-base + par-fill-skip-code)]
      ["thinmuskip" assign-mu-glue (glue-base + thin-mu-skip-code)]
      ["medmuskip" assign-mu-glue (glue-base + med-mu-skip-code)]
      ["thickmuskip" assign-mu-glue (glue-base + thick-mu-skip-code)]
      ["output" assign-toks output-routine-loc]
      ["everypar" assign-toks every-par-loc]
      ["everymath" assign-toks every-math-loc]
      ["everydisplay" assign-toks every-display-loc]
      ["everyhbox" assign-toks every-hbox-loc]
      ["everyvbox" assign-toks every-vbox-loc]
      ["everyjob" assign-toks every-job-loc]
      ["everycr" assign-toks every-cr-loc]
      ["errhelp" assign-toks err-help-loc]
      ["pretolerance" assign-int (int-base + pretolerance-code)]
      ["tolerance" assign-int (int-base + tolerance-code)]
      ["linepenalty" assign-int (int-base + line-penalty-code)]
      ["hyphenpenalty" assign-int (int-base + hyphen-penalty-code)]
      ["exhyphenpenalty" assign-int (int-base + ex-hyphen-penalty-code)]
      ["clubpenalty" assign-int (int-base + club-penalty-code)]
      ["widowpenalty" assign-int (int-base + widow-penalty-code)]
      ["displaywidowpenalty" assign-int (int-base + display-widow-penalty-code)]
      ["brokenpenalty" assign-int (int-base + broken-penalty-code)]
      ["binoppenalty" assign-int (int-base + bin-op-penalty-code)]
      ["relpenalty" assign-int (int-base + rel-penalty-code)]
      ["predisplaypenalty" assign-int (int-base + pre-display-penalty-code)]
      ["postdisplaypenalty" assign-int (int-base + post-display-penalty-code)]
      ["interlinepenalty" assign-int (int-base + inter-line-penalty-code)]
      ["doublehyphendemerits" assign-int (int-base + double-hyphen-demerits-code)]
      ["finalhyphendemerits" assign-int (int-base + final-hyphen-demerits-code)]
      ["adjdemerits" assign-int (int-base + adj-demerits-code)]
      ["mag" assign-int (int-base + mag-code)]
      ["delimiterfactor" assign-int (int-base + delimiter-factor-code)]
      ["looseness" assign-int (int-base + looseness-code)]
      ["time" assign-int (int-base + time-code)]
      ["day" assign-int (int-base + day-code)]
      ["month" assign-int (int-base + month-code)]
      ["year" assign-int (int-base + year-code)]
      ["showboxbreadth" assign-int (int-base + show-box-breadth-code)]
      ["showboxdepth" assign-int (int-base + show-box-depth-code)]
      ["hbadness" assign-int (int-base + hbadness-code)]
      ["vbadness" assign-int (int-base + vbadness-code)]
      ["pausing" assign-int (int-base + pausing-code)]
      ["tracingonline" assign-int (int-base + tracing-online-code)]
      ["tracingmacros" assign-int (int-base + tracing-macros-code)]
      ["tracingstats" assign-int (int-base + tracing-stats-code)]
      ["tracingparagraphs" assign-int (int-base + tracing-paragraphs-code)]
      ["tracingpages" assign-int (int-base + tracing-pages-code)]
      ["tracingoutput" assign-int (int-base + tracing-output-code)]
      ["tracinglostchars" assign-int (int-base + tracing-lost-chars-code)]
      ["tracingcommands" assign-int (int-base + tracing-commands-code)]
      ["tracingrestores" assign-int (int-base + tracing-restores-code)]
      ["uchyph" assign-int (int-base + uc-hyph-code)]
      ["outputpenalty" assign-int (int-base + output-penalty-code)]
      ["maxdeadcycles" assign-int (int-base + max-dead-cycles-code)]
      ["hangafter" assign-int (int-base + hang-after-code)]
      ["floatingpenalty" assign-int (int-base + floating-penalty-code)]
      ["globaldefs" assign-int (int-base + global-defs-code)]
      ["fam" assign-int (int-base + cur-fam-code)]
      ["escapechar" assign-int (int-base + escape-char-code)]
      ["defaulthyphenchar" assign-int (int-base + default-hyphen-char-code)]
      ["defaultskewchar" assign-int (int-base + default-skew-char-code)]
      ["endlinechar" assign-int (int-base + end-line-char-code)]
      ["newlinechar" assign-int (int-base + new-line-char-code)]
      ["language" assign-int (int-base + language-code)]
      ["lefthyphenmin" assign-int (int-base + left-hyphen-min-code)]
      ["righthyphenmin" assign-int (int-base + right-hyphen-min-code)]
      ["holdinginserts" assign-int (int-base + holding-inserts-code)]
      ["errorcontextlines" assign-int (int-base + error-context-lines-code)]
      ["parindent" assign-dimen (dimen-base + par-indent-code)]
      ["mathsurround" assign-dimen (dimen-base + math-surround-code)]
      ["lineskiplimit" assign-dimen (dimen-base + line-skip-limit-code)]
      ["hsize" assign-dimen (dimen-base + hsize-code)]
      ["vsize" assign-dimen (dimen-base + vsize-code)]
      ["maxdepth" assign-dimen (dimen-base + max-depth-code)]
      ["splitmaxdepth" assign-dimen (dimen-base + split-max-depth-code)]
      ["boxmaxdepth" assign-dimen (dimen-base + box-max-depth-code)]
      ["hfuzz" assign-dimen (dimen-base + hfuzz-code)]
      ["vfuzz" assign-dimen (dimen-base + vfuzz-code)]
      ["delimitershortfall" assign-dimen (dimen-base + delimiter-shortfall-code)]
      ["nulldelimiterspace" assign-dimen (dimen-base + null-delimiter-space-code)]
      ["scriptspace" assign-dimen (dimen-base + script-space-code)]
      ["predisplaysize" assign-dimen (dimen-base + pre-display-size-code)]
      ["displaywidth" assign-dimen (dimen-base + display-width-code)]
      ["displayindent" assign-dimen (dimen-base + display-indent-code)]
      ["overfullrule" assign-dimen (dimen-base + overfull-rule-code)]
      ["hangindent" assign-dimen (dimen-base + hang-indent-code)]
      ["hoffset" assign-dimen (dimen-base + h-offset-code)]
      ["voffset" assign-dimen (dimen-base + v-offset-code)]
      ["emergencystretch" assign-dimen (dimen-base + emergency-stretch-code)]
      [" " ex-space 0]
      ["/" ital-corr 0]
      ["accent" accent 0]
      ["advance" advance 0]
      ["afterassignment" after-assignment 0]
      ["aftergroup" after-group 0]
      ["begingroup" begin-group 0]
      ["char" char-num 0]
      ["csname" cs-name 0]
      ["delimiter" delim-num 0]
      ["divide" divide 0]
      ["endcsname" end-cs-name 0]
      ["endgroup" end-group 0]
      ["expandafter" expand-after 0]
      ["font" def-font 0]
      ["fontdimen" assign-font-dimen 0]
      ["halign" halign 0]
      ["hrule" hrule 0]
      ["ignorespaces" ignore-spaces 0]
      ["insert" insert 0]
      ["mark" mark 0]
      ["mathaccent" math-accent 0]
      ["mathchar" math-char-num 0]
      ["mathchoice" math-choice 0]
      ["multiply" multiply 0]
      ["noalign" no-align 0]
      ["noboundary" no-boundary 0]
      ["noexpand" no-expand 0]
      ["nonscript" non-script 0]
      ["omit" omit 0]
      ["parshape" set-shape 0]
      ["penalty" break-penalty 0]
      ["prevgraf" set-prev-graf 0]
      ["radical" radical 0]
      ["read" read-to-cs 0]
      ["relax" relax 256]
      ["setbox" set-box 0]
      ["the" the 0]
      ["toks" toks-register 0]
      ["vadjust" vadjust 0]
      ["valign" valign 0]
      ["vcenter" vcenter 0]
      ["vrule" vrule 0]
      ["par" par-end 256]
      ["input" input 0]
      ["endinput" input 1]
      ["topmark" top-bot-mark top-mark-code]
      ["firstmark" top-bot-mark first-mark-code]
      ["botmark" top-bot-mark bot-mark-code]
      ["splitfirstmark" top-bot-mark split-first-mark-code]
      ["splitbotmark" top-bot-mark split-bot-mark-code]
      ["count" register int-val]
      ["dimen" register dimen-val]
      ["skip" register glue-val]
      ["muskip" register mu-val]
      ["spacefactor" set-aux hmode]
      ["prevdepth" set-aux vmode]
      ["deadcycles" set-page-int 0]
      ["insertpenalties" set-page-int 1]
      ["wd" set-box-dimen width-offset]
      ["ht" set-box-dimen height-offset]
      ["dp" set-box-dimen depth-offset]
      ["lastpenalty" last-item int-val]
      ["lastkern" last-item dimen-val]
      ["lastskip" last-item glue-val]
      ["inputlineno" last-item input-line-no-code]
      ["badness" last-item badness-code]
      ["number" convert number-code]
      ["romannumeral" convert roman-numeral-code]
      ["string" convert string-code]
      ["meaning" convert meaning-code]
      ["fontname" convert font-name-code]
      ["jobname" convert job-name-code]
      ["if" if-test if-char-code]
      ["ifcat" if-test if-cat-code]
      ["ifnum" if-test if-int-code]
      ["ifdim" if-test if-dim-code]
      ["ifodd" if-test if-odd-code]
      ["ifvmode" if-test if-vmode-code]
      ["ifhmode" if-test if-hmode-code]
      ["ifmmode" if-test if-mmode-code]
      ["ifinner" if-test if-inner-code]
      ["ifvoid" if-test if-void-code]
      ["ifhbox" if-test if-hbox-code]
      ["ifvbox" if-test if-vbox-code]
      ["ifx" if-test ifx-code]
      ["ifeof" if-test if-eof-code]
      ["iftrue" if-test if-true-code]
      ["iffalse" if-test if-false-code]
      ["ifcase" if-test if-case-code]
      ["fi" fi-or-else fi-code]
      ["or" fi-or-else or-code]
      ["else" fi-or-else else-code]
      ["nullfont" set-font null-font]
      ["span" tab-mark span-code]
      ["cr" car-ret cr-code]
      ["crcr" car-ret cr-cr-code]
      ["pagegoal" set-page-dimen 0]
      ["pagetotal" set-page-dimen 1]
      ["pagestretch" set-page-dimen 2]
      ["pagefilstretch" set-page-dimen 3]
      ["pagefillstretch" set-page-dimen 4]
      ["pagefilllstretch" set-page-dimen 5]
      ["pageshrink" set-page-dimen 6]
      ["pagedepth" set-page-dimen 7]
      ["end" stop 0]
      ["dump" stop 1]
      ["hskip" hskip skip-code]
      ["hfil" hskip fil-code]
      ["hfill" hskip fill-code]
      ["hss" hskip ss-code]
      ["hfilneg" hskip fil-neg-code]
      ["vskip" vskip skip-code]
      ["vfil" vskip fil-code]
      ["vfill" vskip fill-code]
      ["vss" vskip ss-code]
      ["vfilneg" vskip fil-neg-code]
      ["mskip" mskip mskip-code]
      ["kern" kern explicit]
      ["mkern" mkern mu-glue]
      ["moveleft" hmove 1]
      ["moveright" hmove 0]
      ["raise" vmove 1]
      ["lower" vmove 0]
      ["box" make-box box-code]
      ["copy" make-box copy-code]
      ["lastbox" make-box last-box-code]
      ["vsplit" make-box vsplit-code]
      ["vtop" make-box vtop-code]
      ["vbox" make-box (vtop-code + vmode)]
      ["hbox" make-box (vtop-code + hmode)]
      ["shipout" leader-ship (a-leaders - 1)]
      ["leaders" leader-ship a-leaders]
      ["cleaders" leader-ship c-leaders]
      ["xleaders" leader-ship x-leaders]
      ["indent" start-par 1]
      ["noindent" start-par 0]
      ["unpenalty" remove-item penalty-node]
      ["unkern" remove-item kern-node]
      ["unskip" remove-item glue-node]
      ["unhbox" un-hbox box-code]
      ["unhcopy" un-hbox copy-code]
      ["unvbox" un-vbox box-code]
      ["unvcopy" un-vbox copy-code]
      ["-" discretionary 1]
      ["discretionary" discretionary 0]
      ["eqno" eq-no 0]
      ["leqno" eq-no 1]
      ["mathord" math-comp ord-noad]
      ["mathop" math-comp op-noad]
      ["mathbin" math-comp bin-noad]
      ["mathrel" math-comp rel-noad]
      ["mathopen" math-comp open-noad]
      ["mathclose" math-comp close-noad]
      ["mathpunct" math-comp punct-noad]
      ["mathinner" math-comp inner-noad]
      ["underline" math-comp under-noad]
      ["overline" math-comp over-noad]
      ["displaylimits" limit-switch normal]
      ["limits" limit-switch limits]
      ["nolimits" limit-switch no-limits]
      ["displaystyle" math-style display-style]
      ["textstyle" math-style text-style]
      ["scriptstyle" math-style script-style]
      ["scriptscriptstyle" math-style script-script-style]
      ["above" above above-code]
      ["over" above over-code]
      ["atop" above atop-code]
      ["abovewithdelims" above (delimited-code + above-code)]
      ["overwithdelims" above (delimited-code + over-code)]
      ["atopwithdelims" above (delimited-code + atop-code)]
      ["left" left-right left-noad]
      ["right" left-right right-noad]
      ["long" prefix 1]
      ["outer" prefix 2]
      ["global" prefix 4]
      ["def" def 0]
      ["gdef" def 1]
      ["edef" def 2]
      ["xdef" def 3]
      ["let" let-cmd normal]
      ["futurelet" let-cmd (normal + 1)]
      ["chardef" shorthand-def char-def-code]
      ["mathchardef" shorthand-def math-char-def-code]
      ["countdef" shorthand-def count-def-code]
      ["dimendef" shorthand-def dimen-def-code]
      ["skipdef" shorthand-def skip-def-code]
      ["muskipdef" shorthand-def mu-skip-def-code]
      ["toksdef" shorthand-def toks-def-code]
      ["catcode" def-code cat-code-base]
      ["mathcode" def-code math-code-base]
      ["lccode" def-code lc-code-base]
      ["uccode" def-code uc-code-base]
      ["sfcode" def-code sf-code-base]
      ["delcode" def-code del-code-base]
      ["textfont" def-family math-font-base]
      ["scriptfont" def-family (math-font-base + script-size)]
      ["scriptscriptfont" def-family (math-font-base + script-script-size)]
      ["hyphenation" hyph-data 0]
      ["patterns" hyph-data 1]
      ["hyphenchar" assign-font-int 0]
      ["skewchar" assign-font-int 1]
      ["batchmode" set-interaction batch-mode]
      ["nonstopmode" set-interaction nonstop-mode]
      ["scrollmode" set-interaction scroll-mode]
      ["errorstopmode" set-interaction error-stop-mode]
      ["openin" in-stream 1]
      ["closein" in-stream 0]
      ["message" message 0]
      ["errmessage" message 1]
      ["lowercase" case-shift lc-code-base]
      ["uppercase" case-shift uc-code-base]
      ["show" xray show-code]
      ["showbox" xray show-box-code]
      ["showthe" xray show-the-code]
      ["showlists" xray show-lists-code]
      ["openout" extension open-node]
      ["write" extension write-node]
      ["closeout" extension close-node]
      ["special" extension special-node]
      ["immediate" extension immediate-code]
      ["setlanguage" extension set-language-code]]
   ; --- printing (tex.web 54-71) ----------------------------------------------------------
   (int-par J k) (J 'eq (int-base + k))
   (dimen-par J k) (J 'eq (dimen-base + k))
   (glue-par J k) (J 'eq (glue-base + k))
   (nl-char? J c) (c = int-par J new-line-char-code)
   (write-port J s) (J 'write-file s)
   (print-ln J)
    (J 'selector @ s
       (? (s = term-and-log)
           (put (J 'term-out) 10, put (J 'log-file) 10, pins J 'term-offset 0 'file-offset 0)
          (s = log-only) (put (J 'log-file) 10, pin J 'file-offset 0)
          (s = term-only) (put (J 'term-out) 10, pin J 'term-offset 0)
          (s < no-print) (put (write-port J s) 10)))
   (print-char J c)
    (nl-char? J c && J 'selector < pseudo ? (print-ln J) (print-raw J c))
   ; print_char less its new-line test: the bytes of a character's printed form
   (print-raw J c)
    (: s (J 'selector)
       _ (? (s = term-and-log)
             (: _ (put (J 'term-out) c) _ (put (J 'log-file) c)
                t (J 'term-offset + 1) f (J 'file-offset + 1)
                _ (pin J 'term-offset (t = J 'max-print-line ? (put (J 'term-out) 10, 0) t))
                (pin J 'file-offset (f = J 'max-print-line ? (put (J 'log-file) 10, 0) f)))
            (s = log-only)
             (: _ (put (J 'log-file) c) _ (pin J 'file-offset (J 'file-offset + 1))
                (J 'file-offset = J 'max-print-line ? (print-ln J)))
            (s = term-only)
             (: _ (put (J 'term-out) c) _ (pin J 'term-offset (J 'term-offset + 1))
                (J 'term-offset = J 'max-print-line ? (print-ln J)))
            (s = no-print) ()
            (s = pseudo)
             (J 'tally < J 'trick-count ? (pin (J 'trick-buf) (J 'tally % J 'error-line) c))
            (s = new-string) (pin J 'str-buf (c . J 'str-buf))
            (put (write-port J s) c))
       (pin J 'tally (J 'tally + 1)))
   (print-bytes J s) (: n #s (go k) (k < n ? (print-char J (s k), go (k + 1))) (go 0))
   ; print: a string's bytes as they are, a character code (< 256) in its printed form
   (print J s)
    (? (string? s) (print-bytes J s)
       (J 'selector > pseudo) (print-char J s)
       (nl-char? J s && J 'selector < pseudo) (print-ln J)
       (char-str s @ t (: n #t (go k) (k < n ? (print-raw J (t k), go (k + 1))) (go 0))))
   (slow-print J s)
    (string? s ? (: n #s (go k) (k < n ? (print J (s k), go (k + 1))) (go 0)) (print J s))
   (print-nl J s)
    (: sel (J 'selector)
       (? ((J 'term-offset > 0 && sel % 2 = 1) || (J 'file-offset > 0 && sel >= log-only))
          (print-ln J),
       print J s))
   (print-esc J s)
    (int-par J escape-char-code @ c (0 <= c < 256 ? (print J c), slow-print J s))
   (print-int J n) (print-bytes J (show n))
   (print-two J n) (abs n % 100 @ m (print-char J (48 + m // 10), print-char J (48 + m % 10)))
   (print-hex J n)
    (: (digs n acc) (n < 16 ? (n . acc) (digs (n // 16) ((n % 16) . acc)))
       (print-char J 34,
        map (d \ print-char J (d < 10 ? (48 + d) (55 + d))) (digs n ())))
   (print-roman-int J n0)
    (: s "m2d5c2l5x2v5i"
       (go j v n)
        (? (n >= v) (print-char J (s j), go j v (n - v))
           (n <= 0) ()
           (: k (j + 2) u0 (v // (s (k - 1) - 48))
              dbl (s (k - 1) = 50)
              k2 (dbl ? (k + 2) k) u (dbl ? (u0 // (s (k2 - 1) - 48)) u0)
              (n + u >= v ? (print-char J (s k2), go j v (n + u))
                 (go (j + 2) (v // (s (j + 1) - 48)) n))))
       (go 0 1000 n0))
   (print-scaled J s0)
    (: s (s0 < 0 ? (print-char J 45, 0 - s0) s0)
       _ (print-int J (s // unity)) _ (print-char J 46)
       (go s d)
        (: s2 (d > unity ? (s + 32768 - 50000) s)
           _ (print-char J (48 + s2 // unity))
           s3 (10 * (s2 % unity))
           (s3 > d * 10 ? (go s3 (d * 10))))
       (go (10 * (s % unity) + 5) 10))
   (print-current-string J) (print-bytes J (string (rev (J 'str-buf))))
   ; the string printed under new_string, the buffer emptied
   (take-string J) (: s (string (rev (J 'str-buf))) (pin J 'str-buf (), s))

   ; --- terminal input (tex.web 71) ---------------------------------------------------------
   ; a line from the terminal, trailing blanks gone as input_ln drops them; () at its end
   (read-term J)
    (: q (J 'term-in) b (jug 0)
       (go n)
        (see q @ c (? (c < 0) (n = 0 ? () (strip-tail (slurp b)))
                      (c = 10) (strip-tail (slurp b))
                      (put b c, go (n + 1))))
       (go 0))
   (strip-tail s) (: (go k) (k > 0 && (s (k - 1) = 32 || s (k - 1) = 9) ? (go (k - 1)) k)
                     (snip s 0 (go #s)))
   (term-input J)
    (: _ (flush (J 'term-out))
       l (read-term J)
       (? (l = ()) (fatal-error J "End of file on the terminal!")
          (: _ (pin J 'term-offset 0) _ (pin J 'selector (J 'selector - 1))
             _ (: n #l (go k) (k < n ? (print J (l k), go (k + 1))) (go 0))
             _ (print-ln J) _ (pin J 'selector (J 'selector + 1))
             l)))
   (prompt-input J s) (print J s, term-input J)

   ; --- errors (tex.web 72-98) --------------------------------------------------------------
   (print-err J s) (print-nl J "! ", print J s)
   (set-help J lines) (pin J 'help lines)
   (jump-out J) (scare 'caja-end 0)
   (tex-error J)
    (: _ (J 'history < error-message-issued ? (pin J 'history error-message-issued))
       _ (print-char J 46) _ (show-context J)
       (? (J 'interaction = error-stop-mode) (advice J)
          (: _ (pin J 'error-count (J 'error-count + 1))
             _ (J 'error-count = 100 ?
                  (print-nl J "(That makes 100 errors; please try again.)",
                   pin J 'history fatal-error-stop, jump-out J))
             (put-help J))))
   ; the help lines, on the transcript only (tex.web 90)
   (put-help J)
    (: _ (J 'interaction > batch-mode ? (pin J 'selector (J 'selector - 1)))
       _ (? (J 'use-err-help) (print-ln J, give-err-help J)
            (map (s \ print-nl J s) (J 'help)))
       _ (pin J 'help ()) _ (print-ln J)
       _ (J 'interaction > batch-mode ? (pin J 'selector (J 'selector + 1)))
       (print-ln J))
   ; the dialog at an error stop (tex.web 83-89): each answer that does not return loops
   (advice J)
    (? (J 'interaction != error-stop-mode) ()
       (: _ (clear-for-error-prompt J)
          l (prompt-input J "? ")
          (? (#l = 0) ()
             (: c (l 0 @ c (c >= 97 ? (c - 32) c))
                (? (48 <= c <= 57 && J 'deletions-allowed) (delete-tokens J l c, advice J)
                   (c = 69 && edit-file? J)
                    (print-nl J "You want to edit file ",
                     slow-print J (J 'edit-name), print J " at line ", print-int J (J 'line),
                     pin J 'interaction scroll-mode, jump-out J)
                   (c = 72) (help-now J, advice J)
                   (c = 73) (insert-from-terminal J l)
                   (c = 81 || c = 82 || c = 83) (change-interaction J c)
                   (c = 88) (pin J 'interaction scroll-mode, jump-out J)
                   (print-menu J, advice J))))))
   (edit-file? J) (string? (J 'edit-name))
   (print-menu J)
    (print J "Type <return> to proceed, S to scroll future error messages,",
     print-nl J "R to run without stopping, Q to run quietly,",
     print-nl J "I to insert something, ",
     edit-file? J ? (print J "E to edit your file,"),
     J 'deletions-allowed ?
       (print-nl J "1 or ... or 9 to ignore the next 1 to 9 tokens of input,"),
     print-nl J "H for help, X to quit.")
   (change-interaction J c)
    (pins J 'error-count 0 'interaction (batch-mode + c - 81),
     print J "OK, entering ",
     (? (c = 81) (print-esc J "batchmode", pin J 'selector (J 'selector - 1))
        (c = 82) (print-esc J "nonstopmode")
        (print-esc J "scrollmode")),
     print J "...", print-ln J, flush (J 'term-out))
   (insert-from-terminal J l)
    (: _ (begin-file-reading J)
       I (J 'cur)
       (? (#l > 1) (pins I 'buf (" " + snip l 1 #l) 'loc 1 'limit (#l - 1))
          (prompt-input J "insert>" @ m (pins I 'buf m 'loc 0 'limit (#m - 1)))))
   (delete-tokens J l c0)
    (: s1 (J 'cur-tok) s2 (J 'cur-cmd) s3 (J 'cur-chr) s4 (J 'align-state)
       _ (pins J 'align-state 1000000 'ok-to-interrupt 0)
       c (#l > 1 && 48 <= l 1 <= 57 ? (c0 * 10 + l 1 - 48 * 11) (c0 - 48))
       (go n) (n > 0 ? (get-token J, go (n - 1)))
       _ (go c)
       _ (pins J 'cur-tok s1 'cur-cmd s2 'cur-chr s3 'align-state s4 'ok-to-interrupt 1)
       _ (set-help J ["I have just deleted some text, as you asked."
                  "You can now delete more, or insert, or whatever."])
       (show-context J))
   (help-now J)
    (: _ (? (J 'use-err-help) (give-err-help J, pin J 'use-err-help 0)
            (: _ (J 'help = () ? (set-help J ["Sorry, I don't know how to help in this situation."
                                          "Maybe you should try asking a human?"]))
               (map (\ s (print J s, print-ln J)) (J 'help))))
       (set-help J ["Sorry, I already gave what help I could..."
                "Maybe you should try asking a human?"
                "An error might have occurred before I noticed any problems."
                "``If all else fails, read the instructions.''"]))
   (int-error J n) (print J " (", print-int J n, print-char J 41, tex-error J)
   (normalize-selector J)
    (pin J 'selector (J 'log-opened ? term-and-log term-only),
     J 'job-name = () ? (open-log-file J),
     J 'interaction = batch-mode ? (pin J 'selector (J 'selector - 1)))
   (succumb J)
    (J 'interaction = error-stop-mode ? (pin J 'interaction scroll-mode),
     J 'log-opened ? (tex-error J),
     pin J 'history fatal-error-stop, jump-out J)
   (fatal-error J s)
    (normalize-selector J, print-err J "Emergency stop", set-help J [s], succumb J)
   (overflow J s n)
    (normalize-selector J, print-err J "TeX capacity exceeded, sorry [",
     print J s, print-char J 61, print-int J n, print-char J 93,
     set-help J ["If you really absolutely need more capacity,"
             "you can ask a wizard to enlarge me."],
     succumb J)
   (confusion J s)
    (normalize-selector J,
     (? (J 'history < error-message-issued)
        (print-err J "This can't happen (", print J s, print-char J 41,
         set-help J ["I'm broken. Please show this to someone who can fix can fix"])
        (print-err J "I can't go on meeting you like this",
         set-help J ["One of your faux pas seems to have wounded me deeply..."
                 "in fact, I'm barely conscious. Please fix it and try again."])),
     succumb J)

   ; --- arithmetic (tex.web 99-108) ---------------------------------------------------------
   (half x) (x % 2 != 0 ? ((x + 1) // 2) (x // 2))
   (round-decimals digs) (((foldr (\ d a ((a + d * two) // 10)) 0 digs) + 1) // 2)
   (mult-and-add J n0 x0 y m)
    (: n (n0 < 0 ? (0 - n0) n0) x (n0 < 0 ? (0 - x0) x0)
       (? (n = 0) y
          (x <= (m - y) // n && 0 - x <= (m + y) // n) (n * x + y)
          (pin J 'arith-error 1, 0)))
   (nx-plus-y J n x y) (mult-and-add J n x y 1073741823)
   (mult-integers J n x) (mult-and-add J n x 0 2147483647)
   (x-over-n J x0 n0)
    (? (n0 = 0) (pins J 'arith-error 1 'remainder x0, 0)
       (: neg (n0 < 0) x (neg ? (0 - x0) x0) n (neg ? (0 - n0) n0)
          q (x >= 0 ? (x // n) (0 - (0 - x) // n))
          r (x >= 0 ? (x % n) (0 - (0 - x) % n))
          (pin J 'remainder (neg ? (0 - r) r), q)))
   (xn-over-d J x0 n d)
    (: pos (x0 >= 0) x (pos ? x0 (0 - x0))
       t (x % 32768 * n) u (x // 32768 * n + t // 32768)
       v (u % d * 32768 + t % 32768)
       r (u // d >= 32768 ? (pin J 'arith-error 1, u) (32768 * (u // d) + v // d))
       (pin J 'remainder (pos ? (v % d) (0 - v % d)), pos ? r (0 - r)))
   (badness t s)
    (? (t = 0) 0 (s <= 0) inf-bad
       ((? (t <= 7230584) (t * 297 // s) (s >= 1663497) (t // (s // 297)) t) @ r
          (r > 1290 ? inf-bad ((r * r * r + 131072) // 262144))))

   ; --- the table of equivalents (tex.web 220-255) ----------------------------------------
   (equiv J p) (peep (J 'eq) p ())
   (eq-type J p) (peep (J 'et) p undefined-cs)
   (eq-level J p) (peep (J 'el) p level-zero)
   (xeq-level J p) (peep (J 'xl) p level-one)
   (set-eqtb J p t l e) (pin (J 'et) p t, pin (J 'el) p l, pin (J 'eq) p e)
   (set-equiv J p e) (pin (J 'eq) p e)
   (cat-code J c) (J 'eq (cat-code-base + c))
   (new-spec g) {'width (g 'width) 'stretch (g 'stretch) 'sto (g 'sto) 'shrink (g 'shrink)
                 'sho (g 'sho)}
   (spec w st sto sh sho) {'width w 'stretch st 'sto sto 'shrink sh 'sho sho}
   (init-eqtb J)
    (: zg (J 'zero-glue)
       (fill-range a b t l e) (: (go k) (k <= b ? (set-eqtb J k t l e, go (k + 1))) (go a))
       _ (fill-range glue-base (local-base - 1) glue-ref level-one zg)
       _ (set-eqtb J par-shape-loc shape-ref level-one ())
       _ (fill-range box-base (box-base + 255) box-ref level-one ())
       _ (fill-range cur-font-loc (math-font-base + 47) data level-one null-font)
       _ (fill-range cat-code-base (int-base - 1) data level-one 0)
       _ (map (\ k (pin (J 'eq) (cat-code-base + k) other-char, pin (J 'eq) (math-code-base + k) k,
                    pin (J 'eq) (sf-code-base + k) 1000))
              ^256)
       _ (map (\ kv (pin (J 'eq) (cat-code-base + kv 0) (kv 1)))
              [[carriage-return car-ret] [32 spacer] [92 escape] [37 comment]
               [invalid-code invalid-char] [null-code ignore]])
       _ (map (\ k (pin (J 'eq) (math-code-base + k) (k + var-code))) (map (+ 48) ^10))
       _ (map (\ k (: l (k + 32)
                      (pin (J 'eq) (cat-code-base + k) letter, pin (J 'eq) (cat-code-base + l) letter,
                       pin (J 'eq) (math-code-base + k) (k + var-code + 256),
                       pin (J 'eq) (math-code-base + l) (l + var-code + 256),
                       pin (J 'eq) (lc-code-base + k) l, pin (J 'eq) (lc-code-base + l) l,
                       pin (J 'eq) (uc-code-base + k) k, pin (J 'eq) (uc-code-base + l) k,
                       pin (J 'eq) (sf-code-base + k) 999)))
              (map (+ 65) ^26))
       _ (: (go k) (k <= eqtb-size ? (pin (J 'eq) k 0, go (k + 1))) (go int-base))
       _ (map (\ kv (pin (J 'eq) (int-base + kv 0) (kv 1)))
              [[mag-code 1000] [tolerance-code 10000] [hang-after-code 1] [max-dead-cycles-code 25]
               [escape-char-code 92] [end-line-char-code carriage-return]])
       _ (map (\ k (pin (J 'eq) (del-code-base + k) -1)) ^256)
       _ (pin (J 'eq) (del-code-base + 46) 0)
       ; the frozen control sequences no primitive call makes (tex.web 258, 553, 780, 1216)
       _ (pin (J 'et) frozen-dont-expand dont-expand)
       _ (pin (J 'text) frozen-dont-expand "notexpanded:")
       _ (pin (J 'text) frozen-protection "inaccessible")
       J)
   (begin-diagnostic J)
    (pin J 'old-setting (J 'selector),
     int-par J tracing-online-code <= 0 && J 'selector = term-and-log ?
       (pin J 'selector (J 'selector - 1),
        J 'history = spotless ? (pin J 'history warning-issued)))
   (end-diagnostic J blank)
    (print-nl J "", blank ? (print-ln J), pin J 'selector (J 'old-setting))
   (print-skip-param J n)
    (n < 0 || n >= #skip-param-names ? (print J "[unknown glue parameter!]")
       (print-esc J (skip-param-names n)))
   (print-param J n)
    (n < 0 || n >= #int-param-names ? (print J "[unknown integer parameter!]")
       (print-esc J (int-param-names n)))
   (print-length-param J n)
    (n < 0 || n >= #dimen-param-names ? (print J "[unknown dimen parameter!]")
       (print-esc J (dimen-param-names n)))
   (print-glue J d order s)
    (print-scaled J d,
     (? (order < normal || order > filll) (print J "foul")
        (order > normal) (print J "fil", map (_ \ print-char J 108) ^(order - 1))
        (s != "") (print J s)))
   (print-spec J p s)
    (? (p = ()) (print-char J 42)
       (print-scaled J (p 'width), s != "" ? (print J s),
        p 'stretch != 0 ? (print J " plus ", print-glue J (p 'stretch) (p 'sto) s),
        p 'shrink != 0 ? (print J " minus ", print-glue J (p 'shrink) (p 'sho) s)))
   (print-size J s)
    (? (s = text-size) (print-esc J "textfont") (s = script-size) (print-esc J "scriptfont")
       (print-esc J "scriptscriptfont"))
   (print-style J c)
    (c // 2 @ k (0 <= k <= 3 ? (print-esc J (["displaystyle" "textstyle" "scriptstyle"
                                               "scriptscriptstyle"] k))
                  (print J "Unknown style!")))
   (font-id-text J f) (J 'text (font-id-base + f))
   ; show_eqtb (tex.web 252): location n as \tracingrestores says it
   (show-eqtb J n)
    (? (n < active-base) (print-char J 63)
       (n < glue-base)
        (sprint-cs J n, print-char J 61, print-cmd-chr J (eq-type J n) (equiv J n),
         eq-type J n >= call ? (print-char J 58, show-token-list J (equiv J n) () 32))
       (n < local-base)
        (? (n < skip-base)
            (print-skip-param J (n - glue-base), print-char J 61,
             print-spec J (equiv J n) (n < glue-base + thin-mu-skip-code ? "pt" "mu"))
           (n < mu-skip-base)
            (print-esc J "skip", print-int J (n - skip-base), print-char J 61,
             print-spec J (equiv J n) "pt")
           (print-esc J "muskip", print-int J (n - mu-skip-base), print-char J 61,
            print-spec J (equiv J n) "mu"))
       (n < int-base)
        (? (n = par-shape-loc)
            (print-esc J "parshape", print-char J 61,
             equiv J n = () ? (print-char J 48) (print-int J (#(equiv J n))))
           (n < toks-base)
            (print-cmd-chr J assign-toks n, print-char J 61,
             equiv J n != () ? (show-token-list J (equiv J n) () 32))
           (n < box-base)
            (print-esc J "toks", print-int J (n - toks-base), print-char J 61,
             equiv J n != () ? (show-token-list J (equiv J n) () 32))
           (n < cur-font-loc)
            (print-esc J "box", print-int J (n - box-base), print-char J 61,
             equiv J n = () ? (print J "void") (up J 'show-box1 (equiv J n)))
           (n < cat-code-base)
            ((? (n = cur-font-loc) (print J "current font")
                (n < math-font-base + 16) (print-esc J "textfont", print-int J (n - math-font-base))
                (n < math-font-base + 32)
                 (print-esc J "scriptfont", print-int J (n - math-font-base - 16))
                (print-esc J "scriptscriptfont", print-int J (n - math-font-base - 32))),
             print-char J 61, print-esc J (font-id-text J (equiv J n)))
           (n < math-code-base)
            ((? (n < lc-code-base) (print-esc J "catcode", print-int J (n - cat-code-base))
                (n < uc-code-base) (print-esc J "lccode", print-int J (n - lc-code-base))
                (n < sf-code-base) (print-esc J "uccode", print-int J (n - uc-code-base))
                (print-esc J "sfcode", print-int J (n - sf-code-base))),
             print-char J 61, print-int J (equiv J n))
           (print-esc J "mathcode", print-int J (n - math-code-base), print-char J 61,
            print-int J (equiv J n)))
       (n < dimen-base)
        ((? (n < count-base) (print-param J (n - int-base))
            (n < del-code-base) (print-esc J "count", print-int J (n - count-base))
            (print-esc J "delcode", print-int J (n - del-code-base))),
         print-char J 61, print-int J (J 'eq n))
       (n <= eqtb-size)
        ((n < scaled-base ? (print-length-param J (n - dimen-base))
            (print-esc J "dimen", print-int J (n - scaled-base))),
         print-char J 61, print-scaled J (J 'eq n), print J "pt")
       (print-char J 63))
   ; a call upward, to the part of caja-tex that hangs it on J 'up
   (up J k x) (J 'up k J x)

   ; --- the hash (tex.web 256-267) -------------------------------------------------------
   (id-lookup J s)
    (peep (J 'hash) s () @ p
       (? (p != ()) p
          (J 'no-new-control-sequence) undefined-control-sequence
          (: q (J 'hash-used)
             (? (q >= frozen-control-sequence) (overflow J "hash size" hash-size)
                (pin J 'hash-used (q + 1), pin (J 'hash) s q, pin (J 'text) q s,
                 pin J 'cs-count (J 'cs-count + 1), q)))))
   (print-cs J p)
    (? (p < hash-base)
        (? (p >= single-base)
            (? (p = null-cs) (print-esc J "csname", print-esc J "endcsname", print-char J 32)
               (print-esc J (p - single-base),
                cat-code J (p - single-base) = letter ? (print-char J 32)))
           (p < active-base) (print-esc J "IMPOSSIBLE.")
           (print J (p - active-base)))
       (p >= undefined-control-sequence) (print-esc J "IMPOSSIBLE.")
       (peep (J 'text) p () = ()) (print-esc J "NONEXISTENT.")
       (print-esc J (J 'text p), print-char J 32))
   (sprint-cs J p)
    (? (p < hash-base)
        (? (p < single-base) (print J (p - active-base))
           (p < null-cs) (print-esc J (p - single-base))
           (print-esc J "csname", print-esc J "endcsname"))
       (print-esc J (J 'text p)))
   (primitive J s c o)
    (: p (#s = 1 ? (single-base + s 0)
            (: _ (pin J 'no-new-control-sequence 0) q (id-lookup J s)
               (pin J 'no-new-control-sequence 1, q)))
       (set-eqtb J p c level-one o, p))
   (primitives J)
    (: _ (pin J 'cur-val 0)
       (go l)
        (two? l ?
           (<l @ [s c o]
              (: p (primitive J s c o)
                 _ (? (s = "par") (pins J 'par-loc p 'par-token (cs-token-flag + p))
                      (s = "write") (pin J 'write-loc p))
                 frz (peep frozen-of s ())
                 _ (frz != () ? (pin (J 'text) frz s, set-eqtb J frz c level-one o))
                 (go >l))))
       _ (go primitive-table)
       ; the alignment's own templates and the endwrite (tex.web 780, 1369)
       _ (pin (J 'text) frozen-end-template "endtemplate")
       _ (pin (J 'text) frozen-endv "endtemplate")
       _ (set-eqtb J frozen-endv endv level-one null-list)
       _ (set-eqtb J frozen-end-template end-template level-one null-list)
       _ (pin (J 'text) end-write "endwrite")
       _ (pin (J 'el) end-write level-one)
       (pin (J 'text) frozen-null-font "nullfont"))

   ; --- the save stack (tex.web 268-288) -------------------------------------------------
   (saved J k) (J 'ss (J 'save-ptr + k))
   (set-saved J k v) (pin (J 'ss) (J 'save-ptr + k) v)
   (check-full-save-stack J)
    (J 'save-ptr > J 'max-save-stack ?
       (pin J 'max-save-stack (J 'save-ptr),
        J 'max-save-stack > save-size - 6 ? (overflow J "save size" save-size)))
   (push-save J e) (pin (J 'ss) (J 'save-ptr) e, pin J 'save-ptr (J 'save-ptr + 1))
   (new-save-level J c)
    (check-full-save-stack J,
     push-save J [level-boundary (J 'cur-group) (J 'cur-boundary)],
     J 'cur-level = 255 ? (overflow J "grouping levels" 255),
     pins J 'cur-boundary (J 'save-ptr - 1) 'cur-level (J 'cur-level + 1) 'cur-group c)
   (eqtb-word J p)
    (p < int-base ? [(eq-type J p) (eq-level J p) (equiv J p)] (J 'eq p))
   (set-eqtb-word J p w)
    (p < int-base ? (set-eqtb J p (w 0) (w 1) (w 2)) (pin (J 'eq) p w))
   (eq-save J p l)
    (check-full-save-stack J,
     (? (l = level-zero) (push-save J [restore-zero l p])
        (push-save J (eqtb-word J p), push-save J [restore-old-value l p])))
   (eq-define J p t e)
    (eq-level J p != J 'cur-level && J 'cur-level > level-one ? (eq-save J p (eq-level J p)),
     set-eqtb J p t (J 'cur-level) e)
   (eq-word-define J p w)
    (xeq-level J p != J 'cur-level ?
       (eq-save J p (xeq-level J p), pin (J 'xl) p (J 'cur-level)),
     pin (J 'eq) p w)
   (geq-define J p t e) (set-eqtb J p t level-one e)
   (geq-word-define J p w) (pin (J 'eq) p w, pin (J 'xl) p level-one)
   (save-for-after J t)
    (J 'cur-level > level-one ?
       (check-full-save-stack J, push-save J [insert-token level-zero t]))
   (restore-trace J p s)
    (begin-diagnostic J, print-char J 123, print J s, print-char J 32, show-eqtb J p,
     print-char J 125, end-diagnostic J 0)
   (unsave J)
    (? (J 'cur-level > level-one)
       (: _ (pin J 'cur-level (J 'cur-level - 1))
          tr (int-par J tracing-restores-code > 0)
          (go _)
           (: _ (pin J 'save-ptr (J 'save-ptr - 1))
              e (J 'ss (J 'save-ptr))
              (? (e 0 = level-boundary) (pins J 'cur-group (e 1) 'cur-boundary (e 2))
                 (e 0 = insert-token)
                  (: t (J 'cur-tok) _ (pin J 'cur-tok (e 2)) _ (back-input J)
                     (pin J 'cur-tok t, go ()))
                 (: p (e 2) l (e 1)
                    w (? (e 0 = restore-old-value)
                         (pin J 'save-ptr (J 'save-ptr - 1), J 'ss (J 'save-ptr))
                         [undefined-cs level-zero ()])
                    _ (? (p < int-base)
                          (? (eq-level J p = level-one) (tr ? (restore-trace J p "retaining"))
                             (set-eqtb-word J p w, tr ? (restore-trace J p "restoring")))
                         (xeq-level J p != level-one)
                          (pin (J 'eq) p w, pin (J 'xl) p l,
                           tr ? (restore-trace J p "restoring"))
                         (tr ? (restore-trace J p "retaining")))
                    (go ()))))
          (go ()))
       (confusion J "curlevel"))
   (prepare-mag J)
    (: _ (J 'mag-set > 0 && int-par J mag-code != J 'mag-set ?
            (print-err J "Incompatible magnification (", print-int J (int-par J mag-code),
             print J ");", print-nl J " the previous value will be retained",
             set-help J ["I can handle only one magnification ratio per job. So I've"
                         "reverted to the magnification you used earlier on this run."],
             int-error J (J 'mag-set),
             geq-word-define J (int-base + mag-code) (J 'mag-set)))
       _ (int-par J mag-code @ m (m <= 0 || m > 32768 ?
            (print-err J "Illegal magnification has been changed to 1000",
             set-help J ["The magnification ratio must be between 1 and 32768."],
             int-error J m, geq-word-define J (int-base + mag-code) 1000)))
       (pin J 'mag-set (int-par J mag-code)))

   ; --- token lists shown (tex.web 292-299) ----------------------------------------------
   ; q a tail of p (the scanner's place) marks where show_context's second line starts
   (show-token-list J p0 q l)
    (: (go p mc n)
        (? (p = () || J 'tally >= l) (p != () ? (print-esc J "ETC."))
           (: _ (p == q ? (set-trick-count J))
              t <p
              (? (t >= cs-token-flag) (print-cs J (t - cs-token-flag), go >p mc n)
                 (t < 0) (print-esc J "BAD.", go >p mc n)
                 (: m (t // 256) c (t % 256)
                    (? (m = mac-param) (print J c, print J c, go >p mc n)
                       (m = out-param)
                        (print J mc, c <= 9 ? (print-char J (c + 48), go >p mc n) (print-char J 33))
                       (m = match)
                        (: n2 (n + 1)
                           (print J c, print-char J n2, n2 > 57 ? () (go >p c n2)))
                       (m = end-match) (print J "->", go >p mc n)
                       (m < 13 && m != 0 && m != 5 && m != 9) (print J c, go >p mc n)
                       (print-esc J "BAD.", go >p mc n))))))
       (pin J 'tally 0, go p0 35 48))
   (token-show J p) (p != () ? (show-token-list J p () 10000000))
   (print-meaning J)
    (print-cmd-chr J (J 'cur-cmd) (J 'cur-chr),
     (? (J 'cur-cmd >= call) (print-char J 58, print-ln J, token-show J (J 'cur-chr))
        (J 'cur-cmd = top-bot-mark)
         (print-char J 58, print-ln J, token-show J (J 'cur-mark (J 'cur-chr)))))

   ; --- the input stack (tex.web 300-331) -------------------------------------------------
   (cur J k) (J 'cur k)
   (push-input J)
    (: _ (J 'input-ptr > J 'max-in-stack ?
            (pin J 'max-in-stack (J 'input-ptr),
             J 'input-ptr = stack-size ? (overflow J "input stack size" stack-size)))
       (pins J 'istack (J 'cur . J 'istack) 'input-ptr (J 'input-ptr + 1)
               'cur {'state 0 'index 0 'start () 'loc () 'limit 0 'name 0 'buf ""}))
   (pop-input J)
    (pins J 'cur <(J 'istack) 'istack >(J 'istack) 'input-ptr (J 'input-ptr - 1))
   (begin-token-list J p t)
    (: _ (push-input J) I (J 'cur)
       _ (pins I 'state token-list 'start p 'index t 'loc p)
       (? (t = macro) (pin I 'limit (J 'param-ptr))
          (t > macro && int-par J tracing-macros-code > 1)
           (begin-diagnostic J, print-nl J "",
            (? (t = mark-text) (print-esc J "mark") (t = write-text) (print-esc J "write")
               (print-cmd-chr J assign-toks (t - output-text + output-routine-loc))),
            print J "->", token-show J p, end-diagnostic J 0)))
   (back-list J p) (begin-token-list J p backed-up)
   (ins-list J p) (begin-token-list J p inserted)
   (end-token-list J)
    (: I (J 'cur)
       _ (? (I 'index >= backed-up)
             (I 'index = macro ? (pin J 'param-ptr (I 'limit)))
            (I 'index = u-template)
             (J 'align-state > 500000 ? (pin J 'align-state 0)
                (fatal-error J "(interwoven alignment preambles are not allowed)")))
       (pop-input J))
   (back-input J)
    (: (go _) (J 'cur @ I (I 'state = token-list && I 'loc = () && I 'index != v-template ?
                             (end-token-list J, go ())))
       _ (go ())
       t (J 'cur-tok)
       _ (t < right-brace-limit ?
            (pin J 'align-state (J 'align-state + (t < left-brace-limit ? -1 1))))
       _ (push-input J)
       l [t]
       (pins (J 'cur) 'state token-list 'start l 'index backed-up 'loc l))
   (back-error J) (pin J 'ok-to-interrupt 0, back-input J, pin J 'ok-to-interrupt 1, tex-error J)
   (ins-error J)
    (pin J 'ok-to-interrupt 0, back-input J, pin (J 'cur) 'index inserted,
     pin J 'ok-to-interrupt 1, tex-error J)
   (begin-file-reading J)
    (: _ (J 'in-open = max-in-open ? (overflow J "text input levels" max-in-open))
       _ (pin J 'in-open (J 'in-open + 1))
       _ (push-input J)
       I (J 'cur)
       _ (pin (J 'line-stack) (J 'in-open) (J 'line))
       (pins I 'index (J 'in-open) 'start 0 'state mid-line 'name 0 'buf "" 'loc 0 'limit -1))
   (end-file-reading J)
    (: I (J 'cur)
       _ (pin J 'line (J 'line-stack (I 'index)))
       _ (pin (J 'input-file) (I 'index) ())
       _ (pop-input J)
       (pin J 'in-open (J 'in-open - 1)))
   (terminal-input? I) (I 'name = 0)
   (clear-for-error-prompt J)
    (: (go _) (J 'cur @ I (I 'state != token-list && terminal-input? I && J 'input-ptr > 0
                           && I 'loc > I 'limit ? (end-file-reading J, go ())))
       (go (), print-ln J))

   ; --- show_context (tex.web 311-320) ----------------------------------------------------
   (set-trick-count J)
    (: f (J 'tally) t (f + 1 + J 'error-line - J 'half-error-line)
       (pins J 'first-count f 'trick-count (t < J 'error-line ? (J 'error-line) t)))
   (show-context J)
    (: levels (rev (J 'cur . J 'istack))           ; input_stack[0..input_ptr]
       top (J 'input-ptr)
       ecl (int-par J error-context-lines-code)
       (go b nn)
        (: I (levels b)
           bottom (I 'state != token-list && (string? (I 'name) || b = 0))
           shown (? (b = top || bottom || nn < ecl) (show-level J I b top)
                    (nn = ecl) (print-nl J "...", 1)
                    0)
           (bottom ? (pins J 'base-ptr b 'edit-name (b > 0 && string? (I 'name) ? (I 'name) ()))
              (go (b - 1) (nn + shown))))
       (go top -1))
   ; one level of the context, two lines; answers 1 when it printed, 0 when it skipped
   (show-level J I b top)
    (? (b = top || I 'state != token-list || I 'index != backed-up || I 'loc != ())
       (: _ (pin J 'tally 0)
          old (J 'selector)
          l (? (I 'state != token-list) (print-location J I b, pseudo-line J I)
               (print-list-type J I, pseudo-list J I))
          _ (pin J 'selector old)
          _ (two-lines J l)
          1)
       0)
   (print-location J I b)
    (: nm (I 'name)
       (? (string? nm) (print-nl J "l.", print-int J (J 'line))
          (nm = 0) (print-nl J (b = 0 ? "<*>" "<insert> "))
          (print-nl J "<read ", nm = 17 ? (print-char J 42) (print-int J (nm - 1)),
           print-char J 62)),
       print-char J 32)
   (begin-pseudoprint J)
    (J 'tally @ l (pins J 'tally 0 'selector pseudo 'trick-count 1000000, l))
   (pseudo-line J I)
    (: l (begin-pseudoprint J)
       buf (I 'buf) lim (I 'limit)
       j (lim >= 0 && lim < #buf && buf lim = int-par J end-line-char-code ? lim (lim + 1))
       (go i) (i < j ? (i = I 'loc ? (set-trick-count J), print J (buf i), go (i + 1)))
       (go (I 'start), l))
   (print-list-type J I)
    (: t (I 'index)
       (? (t = parameter) (print-nl J "<argument> ")
          (t = u-template || t = v-template) (print-nl J "<template> ")
          (t = backed-up) (print-nl J (I 'loc = () ? "<recently read> " "<to be read again> "))
          (t = inserted) (print-nl J "<inserted text> ")
          (t = macro) (print-ln J, print-cs J (I 'name))
          (t = output-text) (print-nl J "<output> ")
          (t = every-par-text) (print-nl J "<everypar> ")
          (t = every-math-text) (print-nl J "<everymath> ")
          (t = every-display-text) (print-nl J "<everydisplay> ")
          (t = every-hbox-text) (print-nl J "<everyhbox> ")
          (t = every-vbox-text) (print-nl J "<everyvbox> ")
          (t = every-job-text) (print-nl J "<everyjob> ")
          (t = every-cr-text) (print-nl J "<everycr> ")
          (t = mark-text) (print-nl J "<mark> ")
          (t = write-text) (print-nl J "<write> ")
          (print-nl J "?")))
   (pseudo-list J I)
    (begin-pseudoprint J @ l (show-token-list J (I 'start) (I 'loc) 100000, l))
   (two-lines J l)
    (: _ (J 'trick-count = 1000000 ? (set-trick-count J))
       fc (J 'first-count) tc (J 'trick-count) t (J 'tally)
       el (J 'error-line) hel (J 'half-error-line) buf (J 'trick-buf)
       m (t < tc ? (t - fc) (tc - fc))
       pn (l + fc <= hel ? [0 (l + fc)] (print J "...", [(l + fc - hel + 3) hel]))
       p (pn 0) n (pn 1)
       _ (: (go q) (q < fc ? (print-char J (buf (q % el)), go (q + 1))) (go p))
       _ (print-ln J)
       _ (map (_ \ print-char J 32) ^n)
       p2 (m + n <= el ? (fc + m) (fc + el - n - 3))
       _ (: (go q) (q < p2 ? (print-char J (buf (q % el)), go (q + 1))) (go fc))
       (m + n > el ? (print J "...")))

   ; --- get_next (tex.web 332-365) --------------------------------------------------------
   (check-outer-validity J)
    (? (J 'scanner-status != normal)
       (: _ (pin J 'deletions-allowed 0)
          I (J 'cur)
          _ (J 'cur-cs != 0 ?
               ((I 'state = token-list || name-num I < 1 || name-num I > 17) ?
                  (back-list J [(cs-token-flag + J 'cur-cs)])),
               pins J 'cur-cmd spacer 'cur-chr 32)
          _ (? (J 'scanner-status > skipping) (runaway-recover J)
               (: _ (print-err J "Incomplete ") _ (print-cmd-chr J if-test (J 'cur-if))
                  _ (print J "; all text was ignored after line ") _ (print-int J (J 'skip-line))
                  _ (set-help J ["A forbidden control sequence occurred in skipped text."
                                 "This kind of error happens when you say `\\if...' and forget"
                                 "the matching `\\fi'. I've inserted a `\\fi'; this might work."])
                  _ (? (J 'cur-cs != 0) (pin J 'cur-cs 0)
                       (pin J 'help ("The file ended while I was skipping conditional text."
                                     . >(J 'help))))
                  _ (pin J 'cur-tok (cs-token-flag + frozen-fi))
                  (ins-error J)))
          (pin J 'deletions-allowed 1)))
   ; a level's name as tex.web compares it: a file's past 17, the terminal's 0, a \read's 1-17
   (name-num I) (string? (I 'name) ? 18 (I 'name))
   (runaway-recover J)
    (: _ (runaway J)
       _ (? (J 'cur-cs = 0) (print-err J "File ended")
            (pin J 'cur-cs 0, print-err J "Forbidden control sequence found"))
       _ (print J " while scanning ")
       ss (J 'scanner-status)
       p (? (ss = defining) (print J "definition", [(right-brace-token + 125)])
            (ss = matching) (print J "use", pin J 'long-state outer-call, [(J 'par-token)])
            (ss = aligning)
             (print J "preamble", pin J 'align-state -1000000,
              [(cs-token-flag + frozen-cr) (right-brace-token + 125)])
            (print J "text", [(right-brace-token + 125)]))
       _ (ins-list J p)
       _ (print J " of ") _ (sprint-cs J (J 'warning-index))
       _ (set-help J ["I suspect you have forgotten a `}', causing me"
                      "to read past where you wanted me to stop."
                      "I'll try to recover; but if the error is serious,"
                      "you'd better type `E' or `X' now and fix your file."])
       (tex-error J))
   (runaway J)
    (J 'scanner-status @ ss
       (ss > skipping ?
          (: _ (print-nl J "Runaway ")
             p (? (ss = defining) (print J "definition", J 'def-ref)
                  (ss = matching) (print J "argument", J 'temp-list)
                  (ss = aligning) (print J "preamble", J 'hold-list)
                  (print J "text", J 'def-ref))
             (print-char J 63, print-ln J, show-token-list J (rev p) () (J 'error-line - 10)))))
   (hex? c) (48 <= c <= 57 || 97 <= c <= 102)
   (hex-val c) (c <= 57 ? (c - 48) (c - 87))
   (get-next J)
    (: _ (pin J 'cur-cs 0)
       _ (? (J 'cur 'state != token-list) (next-from-file J) (next-from-list J))
       (J 'cur-cmd <= car-ret && J 'cur-cmd >= tab-mark && J 'align-state = 0 ?
          (up J 'insert-v-template 0, get-next J)))
   (next-from-list J)
    (: I (J 'cur) loc (I 'loc)
       (? (loc = ()) (end-token-list J, get-next-restart J)
          (: t <loc _ (pin I 'loc >loc)
             (? (t >= cs-token-flag)
                (: cs (t - cs-token-flag)
                   _ (pins J 'cur-cs cs 'cur-cmd (eq-type J cs) 'cur-chr (equiv J cs))
                   (J 'cur-cmd >= outer-call ?
                      (? (J 'cur-cmd = dont-expand)
                         ; the token after \notexpanded:, which keeps its meaning but not its expansion
                         (: cs2 (<(I 'loc) - cs-token-flag)
                            _ (pin I 'loc ())
                            _ (pins J 'cur-cs cs2 'cur-cmd (eq-type J cs2) 'cur-chr (equiv J cs2))
                            (J 'cur-cmd > max-command ? (pins J 'cur-cmd relax 'cur-chr no-expand-flag)))
                         (check-outer-validity J))))
                (: cmd (t // 256) chr (t % 256)
                   _ (pins J 'cur-cmd cmd 'cur-chr chr)
                   (? (cmd = left-brace) (pin J 'align-state (J 'align-state + 1))
                      (cmd = right-brace) (pin J 'align-state (J 'align-state - 1))
                      (cmd = out-param)
                       (begin-token-list J (J 'param-stack (I 'limit + chr - 1)) parameter,
                        get-next-restart J)))))))
   ; goto restart, from inside get_next: the alignment test runs only once, at the end
   (get-next-restart J)
    (pin J 'cur-cs 0, J 'cur 'state != token-list ? (next-from-file J) (next-from-list J))
   (next-from-file J)
    (: I (J 'cur)
       (? (I 'loc <= I 'limit)
          (: c (I 'buf (I 'loc)) _ (pin I 'loc (I 'loc + 1)) (reswitch J I c))
          (: _ (pin I 'state new-line) (next-line J I))))
   (reswitch J I c)
    (: cmd (cat-code J c) st (I 'state)
       _ (pins J 'cur-chr c 'cur-cmd cmd)
       (? (cmd = ignore || (cmd = spacer && st != mid-line)) (next-from-file J)
          (cmd = escape) (scan-cs J I)
          (cmd = active-char)
           (: cs (c + active-base)
              (pins J 'cur-cs cs 'cur-cmd (eq-type J cs) 'cur-chr (equiv J cs),
               pin I 'state mid-line,
               J 'cur-cmd >= outer-call ? (check-outer-validity J)))
          (cmd = sup-mark)
           (: loc (I 'loc) buf (I 'buf)
              (? (loc < I 'limit && c = buf loc && buf (loc + 1) < 128)
                 (: c2 (buf (loc + 1)) loc2 (loc + 2)
                    (? (hex? c2 && loc2 <= I 'limit && hex? (buf loc2))
                       (pin I 'loc (loc2 + 1), reswitch J I (16 * hex-val c2 + hex-val (buf loc2)))
                       (pin I 'loc loc2, reswitch J I (c2 < 64 ? (c2 + 64) (c2 - 64)))))
                 (pin I 'state mid-line)))
          (cmd = invalid-char)
           (print-err J "Text line contains an invalid character",
            set-help J ["A funny symbol that I can't read has just been input."
                        "Continue, and I'll forget that it ever happened."],
            pin J 'deletions-allowed 0, tex-error J, pin J 'deletions-allowed 1,
            get-next-restart J)
          (cmd = spacer) (pins I 'state skip-blanks, pin J 'cur-chr 32)
          (cmd = car-ret)
           (pin I 'loc (I 'limit + 1),
            (? (st = mid-line) (pins J 'cur-cmd spacer 'cur-chr 32)
               (st = skip-blanks) (next-from-file J)
               (: p (J 'par-loc)
                  (pins J 'cur-cs p 'cur-cmd (eq-type J p) 'cur-chr (equiv J p),
                   J 'cur-cmd >= outer-call ? (check-outer-validity J)))))
          (cmd = comment) (pin I 'loc (I 'limit + 1), next-from-file J)
          (cmd = left-brace) (pin J 'align-state (J 'align-state + 1), pin I 'state mid-line)
          (cmd = right-brace) (pin J 'align-state (J 'align-state - 1), pin I 'state mid-line)
          (st != mid-line && (cmd = math-shift || cmd = tab-mark || cmd = mac-param
                              || cmd = sub-mark || cmd = letter || cmd = other-char))
           (pin I 'state mid-line)))
   ; a control sequence (tex.web 354-356): ^^ codes in its name are reduced in the buffer
   (scan-cs J I)
    (: (found cs)
        (pins J 'cur-cs cs 'cur-cmd (eq-type J cs) 'cur-chr (equiv J cs),
         J 'cur-cmd >= outer-call ? (check-outer-validity J))
       ; a ^^ code at k-1, k: answers 1 when it reduced one, so the scan starts again
       (reduce k c cat)
        (: buf (I 'buf) lim (I 'limit)
           (? (k < lim && buf k = c && cat = sup-mark && buf (k + 1) < 128)
              (: c2 (buf (k + 1))
                 d (hex? c2 && k + 2 <= lim && hex? (buf (k + 2)) ? 3 2)
                 nc (d > 2 ? (16 * hex-val c2 + hex-val (buf (k + 2))) (c2 < 64 ? (c2 + 64) (c2 - 64)))
                 (pins I 'buf (snip buf 0 (k - 1) + string nc + snip buf (k + d) #buf)
                         'limit (lim - d),
                  1))
              0))
       (start-cs _)
        (: loc (I 'loc) buf (I 'buf) lim (I 'limit)
           c (buf loc) cat (cat-code J c)
           _ (pin I 'state (cat = letter || cat = spacer ? skip-blanks mid-line))
           (? (cat = letter && loc + 1 <= lim)
              (: (ahead k) (: c (buf k) cat (cat-code J c)
                              (cat = letter && k + 1 <= lim ? (ahead (k + 1)) [(k + 1) c cat]))
                 r (ahead (loc + 1))
                 k (r 0)
                 (? (reduce k (r 1) (r 2)) (start-cs ())
                    (: k2 (r 2 != letter ? (k - 1) k)
                       (? (k2 > loc + 1)
                          (pin I 'loc k2, found (id-lookup J (snip buf loc k2)))
                          (pin I 'loc (loc + 1), found (single-base + buf loc))))))
              (? (reduce (loc + 1) c cat) (start-cs ())
                 (pin I 'loc (loc + 1), found (single-base + buf loc)))))
       (? (I 'loc > I 'limit) (found null-cs) (start-cs ())))
   (next-line J I)
    (? (string? (I 'name))
       (: _ (pin J 'line (J 'line + 1))
          f (J 'input-file (I 'index))
          l (J 'force-eof ? () (input-ln f))
          (? (l = ())
             (: _ (print-char J 41) _ (pin J 'open-parens (J 'open-parens - 1))
                _ (flush (J 'term-out)) _ (pin J 'force-eof 0)
                _ (end-file-reading J) _ (check-outer-validity J)
                (get-next-restart J))
             (: _ (firm-up-the-line J I l) (next-from-file J))))
       (I 'name != 0) (pins J 'cur-cmd 0 'cur-chr 0)
       (J 'input-ptr > 0) (end-file-reading J, get-next-restart J)
       (: _ (J 'selector < log-only ? (open-log-file J))
          (? (J 'interaction > nonstop-mode)
             (: inactive (end-line-char-inactive? J)
                _ ((inactive ? (I 'limit + 1) (I 'limit)) = I 'start ?
                     (print-nl J "(Please type a command or say `\\end')"))
                _ (print-ln J)
                l (prompt-input J "*")
                _ (set-line J I l)
                (next-from-file J))
             (fatal-error J "*** (job aborted, no legal \\end found)"))))
   (end-line-char-inactive? J) (int-par J end-line-char-code @ e (e < 0 || e > 255))
   ; a fresh line in I's buffer, the end_line_char after it unless that is inactive
   (set-line J I l)
    (? (end-line-char-inactive? J) (pins I 'buf l 'limit (#l - 1) 'loc 0)
       (pins I 'buf (l + string (int-par J end-line-char-code)) 'limit #l 'loc 0))
   (firm-up-the-line J I l)
    (? (int-par J pausing-code > 0 && J 'interaction > nonstop-mode)
       (: _ (print-ln J) _ (print-bytes-as J l) r (prompt-input J "=>")
          (set-line J I (#r > 0 ? r l)))
       (set-line J I l))
   (print-bytes-as J l) (: n #l (go k) (k < n ? (print J (l k), go (k + 1))) (go 0))
   ; input_ln on a file read whole: the next line, trailing blanks gone, or () at its end
   (input-ln f)
    (: s (f 's) p (f 'pos) n #s
       (? (p >= n) ()
          (: (eol k) (k < n && s k != 10 ? (eol (k + 1)) k)
             e (eol p)
             (pin f 'pos (e + 1), strip-tail (snip s p e)))))
   (get-token J)
    (pin J 'no-new-control-sequence 0, get-next J, pin J 'no-new-control-sequence 1,
     pin J 'cur-tok (J 'cur-cs = 0 ? (J 'cur-cmd * 256 + J 'cur-chr) (cs-token-flag + J 'cur-cs)))

   ; --- expansion (tex.web 366-401) --------------------------------------------------------
   (print-mode J m)
    (? (m > 0) (print J (["vertical" "horizontal" "display math"] (m // (max-command + 1))))
       (m = 0) (print J "no")
       (print J (["internal vertical" "restricted horizontal" "math"] ((0 - m) // (max-command + 1)))),
     print J " mode")
   (mode J) (J 'cur-list 'mode)
   (show-cur-cmd-chr J)
    (begin-diagnostic J, print-nl J "{",
     mode J != J 'shown-mode ? (print-mode J (mode J), print J ": ", pin J 'shown-mode (mode J)),
     print-cmd-chr J (J 'cur-cmd) (J 'cur-chr), print-char J 125, end-diagnostic J 0)
   (expand J)
    (: cv (J 'cur-val) cvl (J 'cur-val-level) rx (J 'radix) co (J 'cur-order)
       cmd (J 'cur-cmd)
       _ (? (cmd < call)
             (: _ (int-par J tracing-commands-code > 1 ? (show-cur-cmd-chr J))
                (? (cmd = top-bot-mark)
                    (peep (J 'cur-mark) (J 'cur-chr) () @ m (m != () ? (begin-token-list J m mark-text)))
                   (cmd = expand-after)
                    (: _ (get-token J) t (J 'cur-tok) _ (get-token J)
                       _ (J 'cur-cmd > max-command ? (expand J) (back-input J))
                       (pin J 'cur-tok t, back-input J))
                   (cmd = no-expand)
                    (: sss (J 'scanner-status) _ (pin J 'scanner-status normal)
                       _ (get-token J) _ (pin J 'scanner-status sss)
                       t (J 'cur-tok) _ (back-input J)
                       (t >= cs-token-flag ?
                          (J 'cur @ I (: l ((cs-token-flag + frozen-dont-expand) . I 'loc)
                                         (pins I 'start l 'loc l)))))
                   (cmd = cs-name) (manufacture-cs J)
                   (cmd = convert) (conv-toks J)
                   (cmd = the) (ins-the-toks J)
                   (cmd = if-test) (conditional J)
                   (cmd = fi-or-else) (fi-or-else-now J)
                   (cmd = input)
                    (? (J 'cur-chr > 0) (pin J 'force-eof 1)
                       (J 'name-in-progress) (insert-relax J)
                       (start-input J))
                   (: _ (print-err J "Undefined control sequence")
                      _ (set-help J ["The control sequence at the end of the top line"
                                     "of your error message was never \\def'ed. If you have"
                                     "misspelled it (e.g., `\\hobx'), type `I' and the correct"
                                     "spelling (e.g., `I\\hbox'). Otherwise just continue,"
                                     "and I'll forget about whatever was undefined."])
                      (tex-error J))))
            (cmd < end-template) (macro-call J)
            (pin J 'cur-tok (cs-token-flag + frozen-endv), back-input J))
       (pins J 'cur-val cv 'cur-val-level cvl 'radix rx 'cur-order co))
   (manufacture-cs J)
    (: (collect acc)
        (: _ (get-x-token J)
           (J 'cur-cs = 0 ? (collect (J 'cur-tok . acc)) (rev acc)))
       r (collect ())
       _ (J 'cur-cmd != end-cs-name ?
            (print-err J "Missing ", print-esc J "endcsname", print J " inserted",
             set-help J ["The control sequence marked <to be read again> should"
                         "not appear between \\csname and \\endcsname."],
             back-error J))
       cs (? (#r > 1)
              (: _ (pin J 'no-new-control-sequence 0)
                 p (id-lookup J (foldl (\ a t (a + string (t % 256))) "" r))
                 (pin J 'no-new-control-sequence 1, p))
             (r = ()) null-cs
             (single-base + <r % 256))
       _ (pin J 'cur-cs cs)
       _ (eq-type J cs = undefined-cs ? (eq-define J cs relax 256))
       (pin J 'cur-tok (cs + cs-token-flag), back-input J))
   (insert-relax J)
    (pin J 'cur-tok (cs-token-flag + J 'cur-cs), back-input J,
     pin J 'cur-tok (cs-token-flag + frozen-relax), back-input J,
     pin (J 'cur) 'index inserted)
   (get-x-token J)
    (: (go _)
        (: _ (get-next J) cmd (J 'cur-cmd)
           (? (cmd <= max-command) ()
              (cmd >= call)
               (? (cmd < end-template) (macro-call J, go ())
                  (pins J 'cur-cs frozen-endv 'cur-cmd endv))
              (expand J, go ())))
       (go (),
        pin J 'cur-tok (J 'cur-cs = 0 ? (J 'cur-cmd * 256 + J 'cur-chr) (cs-token-flag + J 'cur-cs))))
   (x-token J)
    (: (go _) (J 'cur-cmd > max-command ? (expand J, get-next J, go ()))
       (go (),
        pin J 'cur-tok (J 'cur-cs = 0 ? (J 'cur-cmd * 256 + J 'cur-chr) (cs-token-flag + J 'cur-cs))))

   ; --- macro_call (tex.web 389-401) ------------------------------------------------------
   ; S carries the scan: 'r the place in the macro's parameter text, 's where the current
   ; delimiter starts (() for none), 'm the tokens stored, 'n the parameters done. the
   ; parameter being built is J 'temp-list, backwards, where runaway finds it
   (macro-call J)
    (: sss (J 'scanner-status) swi (J 'warning-index)
       _ (pin J 'warning-index (J 'cur-cs))
       rc (J 'cur-chr)
       _ (int-par J tracing-macros-code > 0 ?
            (begin-diagnostic J, print-ln J, print-cs J (J 'warning-index), token-show J rc,
             end-diagnostic J 0))
       S {'r rc 's () 'm 0 'n 0 'mc 0 'unbalance 0 'pstack {}}
       ok (<rc != end-match-token ? (scan-params J S) 1)
       _ (ok ? (feed-macro J S rc))
       (pins J 'scanner-status sss 'warning-index swi))
   (feed-macro J S rc)
    (: (go _) (J 'cur @ I (I 'state = token-list && I 'loc = () && I 'index != v-template ?
                             (end-token-list J, go ())))
       _ (go ())
       _ (begin-token-list J rc macro)
       I (J 'cur)
       _ (pins I 'name (J 'warning-index) 'loc >(S 'r))
       n (S 'n) pp (J 'param-ptr)
       _ (n > 0 ?
            (pp + n > J 'max-param-stack ?
               (pin J 'max-param-stack (pp + n),
                J 'max-param-stack > param-size ? (overflow J "parameter stack size" param-size)),
             map (\ m (pin (J 'param-stack) (pp + m) (S 'pstack m))) ^n,
             pin J 'param-ptr (pp + n)))
       ())
   (scan-params J S)
    (: _ (pin J 'scanner-status matching)
       ls (eq-type J (J 'cur-cs))
       _ (pin J 'long-state (ls >= outer-call ? (ls - 2) ls))
       (one _)
        (: _ (pin J 'temp-list ())
           r (S 'r)
           _ (? (<r > match-token + 255 || <r < match-token) (pin S 's ())
                (pins S 'mc (<r - match-token) 's >r 'r >r 'm 0))
           (? (!(scan-one J S)) 0
              (<(S 'r) = end-match-token) 1
              (one ())))
       (one ()))
   (store-tok J t) (pin J 'temp-list (t . J 'temp-list))
   (delimiter-or-undelimited? t) (t >= match-token && t <= end-match-token)
   ; one parameter, or the delimiter before the first: 1 found, 0 aborted (tex.web 392)
   (scan-one J S)
    (: (cont _)
        (: _ (get-token J) t (J 'cur-tok) r (S 'r)
           (? (t = <r)
              (: r2 >r _ (pin S 'r r2)
                 (? (delimiter-or-undelimited? <r2)
                    (t < left-brace-limit ? (pin J 'align-state (J 'align-state - 1)), found ())
                    (cont ())))
              (recent J S @ x
                 (? (x = 'cont) (cont ())
                    (x = 'abort) 0
                    (rest-of J S @ y (? (y = 'cont) (cont ()) (y = 'abort) 0
                                        (: _ (pin S 'm (S 'm + 1))
                                           (!(delimiter-or-undelimited? <(S 'r)) ? (cont ()) (found ())))))))))
       (found _) (S 's != () ? (tuck-away J S), 1)
       (cont ()))
   ; the tokens matched so far of a delimiter that failed join the parameter (tex.web 397)
   (recent J S)
    (? (S 's == S 'r) 'next
       (S 's = ()) (improper-use J, 'abort)
       (: (outer t)
           (: _ (store-tok J <t) _ (pin S 'm (S 'm + 1))
              (inner u v)
               (? (u == S 'r) (? (J 'cur-tok != <v) 'done (pin S 'r >v, 'cont))
                  (<u != <v) 'done
                  (inner >u >v))
              (inner >t (S 's) = 'cont ? 'cont
                 (: t2 >t (t2 == S 'r ? (pin S 'r (S 's), 'next) (outer t2)))))
          (outer (S 's))))
   (improper-use J)
    (print-err J "Use of ", sprint-cs J (J 'warning-index),
     print J " doesn't match its definition",
     set-help J ["If you say, e.g., `\\def\\a1{...}', then you must always"
                 "put `1' after `\\a', since control sequence names are"
                 "made up of letters only. The macro here has not been"
                 "followed by the required stuff, so I'm ignoring it."],
     tex-error J)
   (rest-of J S)
    (: t (J 'cur-tok)
       (? (t = J 'par-token && J 'long-state != long-call) (runaway-arg J S, 'abort)
          (t < right-brace-limit)
           (? (t < left-brace-limit) (contribute-group J S)
              (: _ (back-input J) _ (print-err J "Argument of ") _ (sprint-cs J (J 'warning-index))
                 _ (print J " has an extra }")
                 _ (set-help J ["I've run across a `}' that doesn't seem to match anything."
                                "For example, `\\def\\a#1{...}' and `\\a}' would produce"
                                "this error. If you simply proceed now, the `\\par' that"
                                "I've just inserted will cause me to report a runaway"
                                "argument that might be the root of the problem. But if"
                                "your `}' was spurious, just type `2' and it will go away."])
                 _ (pins J 'align-state (J 'align-state + 1) 'long-state call 'cur-tok (J 'par-token))
                 _ (ins-error J)
                 'cont))
          (t = space-token && delimiter-or-undelimited? <(S 'r)) 'cont
          (store-tok J t, 'stored)))
   (contribute-group J S)
    (: _ (pin S 'unbalance 1)
       (go _)
        (: _ (store-tok J (J 'cur-tok)) _ (get-token J) t (J 'cur-tok)
           (? (t = J 'par-token && J 'long-state != long-call) (runaway-arg J S, 'abort)
              (t < left-brace-limit) (pin S 'unbalance (S 'unbalance + 1), go ())
              (t < right-brace-limit)
               (: _ (pin S 'unbalance (S 'unbalance - 1))
                  (S 'unbalance = 0 ? (store-tok J t, 'stored) (go ())))
              (go ())))
       (go ()))
   (runaway-arg J S)
    (J 'long-state = call ?
       (runaway J, print-err J "Paragraph ended before ", sprint-cs J (J 'warning-index),
        print J " was complete",
        set-help J ["I suspect you've forgotten a `}', causing me to apply this"
                    "control sequence to too much text. How can we recover?"
                    "My plan is to forget the whole thing and hope for the best."],
        back-error J),
     pin J 'align-state (J 'align-state - S 'unbalance))
   (tuck-away J S)
    (: rp (J 'temp-list) n (S 'n)
       arg (S 'm = 1 && rp != () && <rp < right-brace-limit ? >(rev >rp) (rev rp))
       _ (pin (S 'pstack) n arg)
       _ (pin S 'n (n + 1))
       (int-par J tracing-macros-code > 0 ?
          (begin-diagnostic J, print-nl J (S 'mc), print-int J (n + 1), print J "<-",
           show-token-list J arg () 1000, end-diagnostic J 0)))

   ; --- basic scanning (tex.web 402-463) ------------------------------------------------
   (scan-left-brace J)
    (: (go _) (get-x-token J, J 'cur-cmd = spacer || J 'cur-cmd = relax ? (go ()))
       _ (go ())
       (J 'cur-cmd != left-brace ?
          (print-err J "Missing { inserted",
           set-help J ["A left brace was mandatory here, so I've put one in."
                       "You might want to delete and/or insert some corrections"
                       "so that I will find a matching right brace soon."
                       "(If you're confused by all this, try typing `I}' now.)"],
           back-error J,
           pins J 'cur-tok (left-brace-token + 123) 'cur-cmd left-brace 'cur-chr 123
                  'align-state (J 'align-state + 1))))
   (non-blank J) (get-x-token J, J 'cur-cmd = spacer ? (non-blank J))
   (scan-optional-equals J) (non-blank J, J 'cur-tok != other-token + 61 ? (back-input J))
   (scan-keyword J s)
    (: n #s
       (go k acc)
        (? (k >= n) 1
           (: _ (get-x-token J) c (s k)
              (? (J 'cur-cs = 0 && (J 'cur-chr = c || J 'cur-chr = c - 32))
                  (go (k + 1) (J 'cur-tok . acc))
                 (J 'cur-cmd != spacer || acc != ())
                  (back-input J, acc != () ? (back-list J (rev acc)), 0)
                 (go k acc))))
       (go 0 ()))
   (mu-error J)
    (print-err J "Incompatible glue units",
     set-help J ["I'm going to assume that 1mu=1pt when they're mixed."], tex-error J)
   (scanned J v l) (pins J 'cur-val v 'cur-val-level l)
   (zero-result J level)
    (scanned J 0 (level != tok-val ? dimen-val int-val))
   (scan-something-internal J level negative)
    (: m (J 'cur-chr) cmd (J 'cur-cmd)
       _ (? (cmd = def-code)
             (: _ (scan-char-num J) c (J 'cur-val)
                (scanned J (m < int-base ? (equiv J (m + c)) (J 'eq (m + c))) int-val))
            (cmd = toks-register || cmd = assign-toks || cmd = def-family || cmd = set-font
             || cmd = def-font)
             (? (level != tok-val)
                 (print-err J "Missing number, treated as zero",
                  set-help J ["A number should have been here; I inserted `0'."
                              "(If you can't figure out why I needed to see a number,"
                              "look up `weird error' in the index to The TeXbook.)"],
                  back-error J, scanned J 0 dimen-val)
                (cmd <= assign-toks)
                 (: p (cmd < assign-toks ? (scan-eight-bit-int J, toks-base + J 'cur-val) m)
                    (scanned J (equiv J p) tok-val))
                (back-input J, scan-font-ident J, scanned J (font-id-base + J 'cur-val) ident-val))
            (cmd = assign-int) (scanned J (J 'eq m) int-val)
            (cmd = assign-dimen) (scanned J (J 'eq m) dimen-val)
            (cmd = assign-glue) (scanned J (equiv J m) glue-val)
            (cmd = assign-mu-glue) (scanned J (equiv J m) mu-val)
            (cmd = set-aux)
             (? (abs (mode J) != m)
                 (print-err J "Improper ", print-cmd-chr J set-aux m,
                  set-help J ["You can refer to \\spacefactor only in horizontal mode;"
                              "you can refer to \\prevdepth only in vertical mode; and"
                              "neither of these is meaningful inside \\write. So"
                              "I'm forgetting what you said and using zero instead."],
                  tex-error J, zero-result J level)
                (m = vmode) (scanned J (J 'cur-list 'prev-depth) dimen-val)
                (scanned J (J 'cur-list 'space-factor) int-val))
            (cmd = set-prev-graf)
             (? (mode J = 0) (scanned J 0 int-val)
                (: (find l) (abs (<l 'mode) = vmode ? <l (find >l))
                   (scanned J (find (J 'cur-list . J 'nest) 'pg) int-val)))
            (cmd = set-page-int)
             (scanned J (m = 0 ? (J 'dead-cycles) (J 'insert-penalties)) int-val)
            (cmd = set-page-dimen)
             (scanned J (J 'page-contents = 0 && !(J 'output-active) ? (m = 0 ? max-dimen 0)
                           (J 'page-so-far m))
                      dimen-val)
            (cmd = set-shape) (scanned J (#(equiv J par-shape-loc)) int-val)
            (cmd = set-box-dimen)
             (: _ (scan-eight-bit-int J) b (equiv J (box-base + J 'cur-val))
                (scanned J (b = () ? 0 (b (? (m = width-offset) 'width (m = height-offset) 'height
                                             'depth)))
                         dimen-val))
            (cmd = char-given || cmd = math-given) (scanned J m int-val)
            (cmd = assign-font-dimen)
             (: _ (find-font-dimen J 0) (scanned J (font-dimen-value J) dimen-val))
            (cmd = assign-font-int)
             (: _ (scan-font-ident J) f (J 'fonts (J 'cur-val))
                (scanned J (m = 0 ? (peep f 'hyphenchar -1) (peep f 'skewchar -1)) int-val))
            (cmd = register)
             (: _ (scan-eight-bit-int J) n (J 'cur-val)
                (scanned J (? (m = int-val) (J 'eq (count-base + n)) (m = dimen-val) (J 'eq (scaled-base + n))
                              (m = glue-val) (equiv J (skip-base + n)) (equiv J (mu-skip-base + n)))
                         m))
            (cmd = last-item) (fetch-last-item J m)
            (: _ (print-err J "You can't use `") _ (print-cmd-chr J cmd m)
               _ (print J "' after ") _ (print-esc J "the")
               _ (set-help J ["I'm forgetting what you said and using zero instead."])
               (tex-error J, zero-result J level)))
       (go _)
        (J 'cur-val-level > level ?
           ((? (J 'cur-val-level = glue-val) (pin J 'cur-val (J 'cur-val 'width))
               (J 'cur-val-level = mu-val) (mu-error J)),
            pin J 'cur-val-level (J 'cur-val-level - 1), go ()))
       _ (go ())
       (negative ?
          (? (J 'cur-val-level >= glue-val)
              (: g (new-spec (J 'cur-val))
                 (pins g 'width (0 - g 'width) 'stretch (0 - g 'stretch) 'shrink (0 - g 'shrink),
                  pin J 'cur-val g))
             (pin J 'cur-val (0 - J 'cur-val)))))
   (fetch-last-item J m)
    (? (m > glue-val)
        (scanned J (m = input-line-no-code ? (J 'line) (J 'badness)) int-val)
       (: _ (scanned J (m = glue-val ? (J 'zero-glue) 0) m)
          tl (J 'cur-list 'tail)
          (? (tl 'type != 'char && mode J != 0)
              (? (m = int-val && tl 'type = penalty-node) (pin J 'cur-val (tl 'penalty))
                 (m = dimen-val && tl 'type = kern-node) (pin J 'cur-val (tl 'width))
                 (m = glue-val && tl 'type = glue-node)
                  (pin J 'cur-val (tl 'glue), tl 'sub = mu-glue ? (pin J 'cur-val-level mu-val)))
             (mode J = vmode && tl == J 'cur-list 'head)
              (? (m = int-val) (pin J 'cur-val (J 'last-penalty))
                 (m = dimen-val) (pin J 'cur-val (J 'last-kern))
                 (J 'last-glue != () ? (pin J 'cur-val (J 'last-glue)))))))
   (bad-code J what msg hi)
    (J 'cur-val < 0 || J 'cur-val > hi ?
       (print-err J what, set-help J [msg (ends-with-zero what)], int-error J (J 'cur-val),
        pin J 'cur-val 0))
   (ends-with-zero what) "I changed this one to zero."
   (scan-eight-bit-int J)
    (scan-int J, bad-code J "Bad register code" "A register number must be between 0 and 255." 255)
   (scan-char-num J)
    (scan-int J, bad-code J "Bad character code" "A character number must be between 0 and 255." 255)
   (scan-four-bit-int J)
    (scan-int J, bad-code J "Bad number" "Since I expected to read a number between 0 and 15," 15)
   (scan-fifteen-bit-int J)
    (scan-int J, bad-code J "Bad mathchar" "A mathchar number must be between 0 and 32767." 32767)
   (scan-twenty-seven-bit-int J)
    (scan-int J, bad-code J "Bad delimiter code"
                    "A numeric delimiter code must be between 0 and 2^{27}-1." 134217727)
   ; the next non-blank non-sign token; answers whether the signs made it negative
   (scan-signs J)
    (: (go neg)
        (: _ (non-blank J)
           (? (J 'cur-tok = other-token + 45) (pin J 'cur-tok (other-token + 43), go !neg)
              (J 'cur-tok = other-token + 43) (go neg)
              neg))
       (go 0))
   (internal? J) (J 'cur-cmd >= min-internal && J 'cur-cmd <= max-internal)
   (scan-int J)
    (: _ (pins J 'radix 0 'ok-so-far 1)
       negative (scan-signs J)
       _ (? (J 'cur-tok = alpha-token) (scan-alpha J)
            (internal? J) (scan-something-internal J int-val 0)
            (scan-numeric J))
       (negative ? (pin J 'cur-val (0 - J 'cur-val))))
   (scan-alpha J)
    (: _ (get-token J) t (J 'cur-tok)
       v (? (t < cs-token-flag)
             (: _ (J 'cur-cmd <= right-brace ?
                     (pin J 'align-state (J 'align-state + (J 'cur-cmd = right-brace ? 1 -1))))
                (J 'cur-chr))
            (t < cs-token-flag + single-base) (t - cs-token-flag - active-base)
            (t - cs-token-flag - single-base))
       (? (v > 255)
          (print-err J "Improper alphabetic constant",
           set-help J ["A one-character control sequence belongs after a ` mark."
                       "So I'm essentially inserting \\0 here."],
           pin J 'cur-val 48, back-error J)
          (pin J 'cur-val v, get-x-token J, J 'cur-cmd != spacer ? (back-input J))))
   (scan-numeric J)
    (: rm (? (J 'cur-tok = octal-token) (get-x-token J, [8 1073741824])
             (J 'cur-tok = hex-token) (get-x-token J, [16 134217728])
             [10 214748364])
       radix (rm 0) m (rm 1)
       _ (pins J 'radix radix 'cur-val 0)
       (digit t)
        (? (t < zero-token + radix && t >= zero-token && t <= zero-token + 9) (t - zero-token)
           (radix != 16) -1
           (t <= A-token + 5 && t >= A-token) (t - A-token + 10)
           (t <= other-A-token + 5 && t >= other-A-token) (t - other-A-token + 10)
           -1)
       (go vacuous)
        (digit (J 'cur-tok) @ d
           (? (d < 0) vacuous
              (: v (J 'cur-val)
                 _ (? (v >= m && (v > m || d > 7 || radix != 10))
                       (J 'ok-so-far ?
                          (print-err J "Number too big",
                           set-help J ["I can only go up to 2147483647='17777777777=\"7FFFFFFF,"
                                       "so I'm using that number instead of yours."],
                           tex-error J, pins J 'cur-val infinity-int 'ok-so-far 0))
                      (pin J 'cur-val (v * radix + d)))
                 _ (get-x-token J)
                 (go 0))))
       (? (go 1)
          (print-err J "Missing number, treated as zero",
           set-help J ["A number should have been here; I inserted `0'."
                       "(If you can't figure out why I needed to see a number,"
                       "look up `weird error' in the index to The TeXbook.)"],
           back-error J)
          (J 'cur-cmd != spacer) (back-input J)))
   (scan-normal-dimen J) (scan-dimen J 0 0 0)
   (scan-dimen J mu inf shortcut)
    (: D {'f 0 'neg 0}
       _ (pins J 'arith-error 0 'cur-order normal)
       ; 'sign: cur_val needs only its sign; 'units: cur_val is a count of units still to scan
       how (? shortcut 'units
              (: _ (pin D 'neg (scan-signs J))
                 (? (internal? J)
                    (? mu (: _ (scan-something-internal J mu-val 0) _ (coerce-glue J)
                             (? (J 'cur-val-level = mu-val) 'sign
                                (J 'cur-val-level != int-val ? (mu-error J), 'units)))
                       (: _ (scan-something-internal J dimen-val 0)
                          (J 'cur-val-level = dimen-val ? 'sign 'units)))
                    (: _ (back-input J)
                       _ (J 'cur-tok = continental-point-token ? (pin J 'cur-tok point-token))
                       _ (? (J 'cur-tok != point-token) (scan-int J) (pins J 'radix 10 'cur-val 0))
                       _ (J 'cur-tok = continental-point-token ? (pin J 'cur-tok point-token))
                       _ (J 'radix = 10 && J 'cur-tok = point-token ? (scan-decimal J D))
                       'units))))
       _ (how = 'units ?
            (J 'cur-val < 0 ? (pins D 'neg (!(D 'neg)), pin J 'cur-val (0 - J 'cur-val)),
             scan-units J D mu inf))
       _ (J 'arith-error || abs (J 'cur-val) >= 1073741824 ?
            (print-err J "Dimension too large",
             set-help J ["I can't work with sizes bigger than about 19 feet."
                         "Continue and I'll use the largest value I can."],
             tex-error J, pins J 'cur-val max-dimen 'arith-error 0))
       (D 'neg ? (pin J 'cur-val (0 - J 'cur-val))))
   (coerce-glue J) (J 'cur-val-level >= glue-val ? (pin J 'cur-val (J 'cur-val 'width)))
   (scan-decimal J D)
    (: _ (get-token J)
       (go k acc)
        (: _ (get-x-token J) t (J 'cur-tok)
           (? (t > zero-token + 9 || t < zero-token) (rev acc)
              (go (k + 1) (k < 17 ? ((t - zero-token) . acc) acc))))
       digs (go 0 ())
       _ (pin D 'f (round-decimals digs))
       (J 'cur-cmd != spacer ? (back-input J)))
   ; the units after a number (tex.web 453-459); cur_val and D's f make the dimension
   (scan-units J D mu inf)
    (: (attach-fraction _)
        (J 'cur-val >= 16384 ? (pin J 'arith-error 1)
           (pin J 'cur-val (J 'cur-val * unity + D 'f)))
       (optional-space _) (get-x-token J, J 'cur-cmd != spacer ? (back-input J))
       (found v)
        (pin J 'cur-val (nx-plus-y J (D 'save) v (xn-over-d J v (D 'f) 65536)))
       (fil-units _)
        (: _ (pin J 'cur-order fil)
           (go _) (scan-keyword J "l" ?
                     ((J 'cur-order = filll ?
                         (print-err J "Illegal unit of measure (", print J "replaced by filll)",
                          set-help J ["I dddon't go any higher than filll."], tex-error J)
                         (pin J 'cur-order (J 'cur-order + 1))),
                      go ()))
           (go (), attach-fraction ()))
       (internal-units _)
        (: _ (pin D 'save (J 'cur-val))
           _ (non-blank J)
           (? (!(internal? J)) (back-input J, 0)
              (: _ (? mu (scan-something-internal J mu-val 0, coerce-glue J,
                          J 'cur-val-level != mu-val ? (mu-error J))
                      (scan-something-internal J dimen-val 0))
                 (found (J 'cur-val), 1))))
       (em-ex _)
        (? mu 0
           (scan-keyword J "em") (: v (font-param J (equiv J cur-font-loc) quad-code)
                                    (optional-space (), found v, 1))
           (scan-keyword J "ex") (: v (font-param J (equiv J cur-font-loc) x-height-code)
                                    (optional-space (), found v, 1))
           0)
       (set-conversion num denom)
        (: _ (pin J 'cur-val (xn-over-d J (J 'cur-val) num denom))
           f (((num * D 'f) + 65536 * J 'remainder) // denom)
           (pin J 'cur-val (J 'cur-val + f // 65536), pin D 'f (f % 65536)))
       (other-units _)
        (? (scan-keyword J "in") (set-conversion 7227 100, attach-fraction ())
           (scan-keyword J "pc") (set-conversion 12 1, attach-fraction ())
           (scan-keyword J "cm") (set-conversion 7227 254, attach-fraction ())
           (scan-keyword J "mm") (set-conversion 7227 2540, attach-fraction ())
           (scan-keyword J "bp") (set-conversion 7227 7200, attach-fraction ())
           (scan-keyword J "dd") (set-conversion 1238 1157, attach-fraction ())
           (scan-keyword J "cc") (set-conversion 14856 1157, attach-fraction ())
           (scan-keyword J "sp") ()
           (: _ (print-err J "Illegal unit of measure (") _ (print J "pt inserted)")
              _ (set-help J ["Dimensions can be in units of em, ex, in, pt, pc,"
                             "cm, mm, dd, cc, bp, or sp; but yours is a new one!"
                             "I'll assume that you meant to say pt, for printer's points."
                             "To recover gracefully from this error, it's best to"
                             "delete the erroneous units; e.g., type `2' to delete"
                             "two letters. (See Chapter 27 of The TeXbook.)"])
              (tex-error J, attach-fraction ())))
       (? (inf && scan-keyword J "fil") (fil-units (), optional-space ())
          (internal-units ()) ()
          (em-ex ()) ()
          mu
           (: _ (? (!(scan-keyword J "mu"))
                   (print-err J "Illegal unit of measure (", print J "mu inserted)",
                    set-help J ["The unit of measurement in math glue must be mu."
                                "To recover gracefully from this error, it's best to"
                                "delete the erroneous units; e.g., type `2' to delete"
                                "two letters. (See Chapter 27 of The TeXbook.)"],
                    tex-error J))
              (attach-fraction (), optional-space ()))
          (: _ (scan-keyword J "true" ?
                  (prepare-mag J,
                   int-par J mag-code != 1000 ?
                     (: m (int-par J mag-code)
                        _ (pin J 'cur-val (xn-over-d J (J 'cur-val) 1000 m))
                        f ((1000 * D 'f + 65536 * J 'remainder) // m)
                        (pin J 'cur-val (J 'cur-val + f // 65536), pin D 'f (f % 65536)))))
             (? (scan-keyword J "pt") (attach-fraction (), optional-space ())
                (other-units (), optional-space ())))))
   (scan-glue J level)
    (: mu (level = mu-val)
       negative (scan-signs J)
       (? (internal? J)
           (: _ (scan-something-internal J level negative)
              (? (J 'cur-val-level >= glue-val) (J 'cur-val-level != level ? (mu-error J))
                 (: _ (? (J 'cur-val-level = int-val) (scan-dimen J mu 0 1)
                         (level = mu-val) (mu-error J))
                    (glue-tail J mu))))
          (: _ (back-input J) _ (scan-dimen J mu 0 0)
             _ (negative ? (pin J 'cur-val (0 - J 'cur-val)))
             (glue-tail J mu))))
   (glue-tail J mu)
    (: q (spec (J 'cur-val) 0 normal 0 normal)
       _ (scan-keyword J "plus" ? (scan-dimen J mu 1 0, pins q 'stretch (J 'cur-val) 'sto (J 'cur-order)))
       _ (scan-keyword J "minus" ? (scan-dimen J mu 1 0, pins q 'shrink (J 'cur-val) 'sho (J 'cur-order)))
       (pin J 'cur-val q))
   (scan-rule-spec J)
    (: q (J 'cur-cmd = vrule ? (cb-rule default-rule null-flag null-flag) (cb-rule null-flag default-rule 0))
       (go _)
        (? (scan-keyword J "width") (scan-normal-dimen J, pin q 'width (J 'cur-val), go ())
           (scan-keyword J "height") (scan-normal-dimen J, pin q 'height (J 'cur-val), go ())
           (scan-keyword J "depth") (scan-normal-dimen J, pin q 'depth (J 'cur-val), go ())
           q)
       (go ()))

   ; --- fonts as the scanner sees them (tex.web 577-578) ------------------------------
   (font-param J f k) (peep (J 'fonts f 'tfm 'param) k 0)
   (scan-font-ident J)
    (: _ (non-blank J) cmd (J 'cur-cmd)
       (pin J 'cur-val
          (? (cmd = def-font) (equiv J cur-font-loc)
             (cmd = set-font) (J 'cur-chr)
             (cmd = def-family) (: m (J 'cur-chr) _ (scan-four-bit-int J) (equiv J (m + J 'cur-val)))
             (: _ (print-err J "Missing font identifier")
                _ (set-help J ["I was looking for a control sequence whose"
                               "current meaning has been defined by \\font."])
                _ (back-error J)
                null-font))))
   ; find_font_dimen leaves the font and the parameter in J 'fd, or () where tex.web's
   ; cur_val would be fmem_ptr: a cell that reads as zero and keeps nothing written to it
   (find-font-dimen J writing)
    (: _ (scan-int J) n (J 'cur-val) _ (scan-font-ident J) f (J 'cur-val)
       t (J 'fonts f 'tfm)
       _ (writing && n >= space-code && n <= space-shrink-code ? (pin (J 'fonts f) 'glue ()))
       ok (? (n <= 0) 0
             (n > t 'np)
              (? (f < J 'nfonts) 0
                 (: _ (: (go k) (k <= n ? (pin (t 'param) k 0, go (k + 1))) (go (t 'np + 1)))
                    (pin t 'np n, 1)))
             1)
       _ (pin J 'fd (ok ? [f n] ()))
       (!ok ?
          (print-err J "Font ", print-esc J (font-id-text J f), print J " has only ",
           print-int J (t 'np), print J " fontdimen parameters",
           set-help J ["To increase the number of font parameters, you must"
                       "use \\fontdimen immediately after the \\font is loaded."],
           tex-error J)))
   (font-dimen-value J) (J 'fd @ fd (fd = () ? 0 (font-param J (fd 0) (fd 1))))

   ; --- building token lists (tex.web 464-486) ---------------------------------------------
   (str-toks s) (map (\ c (c = 32 ? space-token (other-token + c))) (chars s))
   (in-new-string J f)
    (: old (J 'selector) _ (pins J 'selector new-string 'str-buf ()) _ (f ())
       _ (pin J 'selector old)
       (take-string J))
   (the-toks J)
    (: _ (get-x-token J) _ (scan-something-internal J tok-val 0)
       v (J 'cur-val) l (J 'cur-val-level)
       (? (l = ident-val) [(cs-token-flag + v)]
          (l = tok-val) v
          (str-toks (in-new-string J (\ _
             (? (l = int-val) (print-int J v)
                (l = dimen-val) (print-scaled J v, print J "pt")
                (print-spec J v (l = glue-val ? "pt" "mu"))))))))
   (ins-the-toks J) (ins-list J (the-toks J))
   (conv-toks J)
    (: c (J 'cur-chr)
       _ (? (c <= roman-numeral-code) (scan-int J)
            (c <= meaning-code)
             (: sss (J 'scanner-status) _ (pin J 'scanner-status normal) _ (get-token J)
                (pin J 'scanner-status sss))
            (c = font-name-code) (scan-font-ident J)
            (J 'job-name = () ? (open-log-file J)))
       (ins-list J (str-toks (in-new-string J (\ _
          (? (c = number-code) (print-int J (J 'cur-val))
             (c = roman-numeral-code) (print-roman-int J (J 'cur-val))
             (c = string-code) (J 'cur-cs != 0 ? (sprint-cs J (J 'cur-cs)) (print-char J (J 'cur-chr)))
             (c = meaning-code) (print-meaning J)
             (c = font-name-code)
              (: f (J 'fonts (J 'cur-val)) t (f 'tfm)
                 (print J (f 'name),
                  t 'size != t 'dsize ? (print J " at ", print-scaled J (t 'size), print J "pt")))
             (print J (J 'job-name))))))))
   (store-def J t) (pin J 'def-ref (t . J 'def-ref))
   ; scan_toks answers the list; while it runs J 'def-ref holds it backwards for runaway
   (scan-toks J macro-def xpand)
    (: _ (pins J 'scanner-status (macro-def ? defining absorbing) 'warning-index (J 'cur-cs)
               'def-ref ())
       S {'t zero-token 'hb 0 'u 1}
       found (? macro-def (scan-param-part J S) (scan-left-brace J, 0))
       _ (!found ? (scan-body J S macro-def xpand))
       _ (pin J 'scanner-status normal)
       _ (S 'hb != 0 ? (store-def J (S 'hb)))
       _ (pin J 'def-ref (rev (J 'def-ref)))
       (J 'def-ref))
   ; the parameter part of a definition: 1 when the body's brace was missing
   (scan-param-part J S)
    (: (go _)
        (: _ (get-token J)
           (? (J 'cur-tok < right-brace-limit) 'done1
              (J 'cur-cmd = mac-param)
               (: s (match-token + J 'cur-chr) _ (get-token J)
                  (? (J 'cur-tok < left-brace-limit)
                      (pin S 'hb (J 'cur-tok), store-def J (J 'cur-tok), store-def J end-match-token,
                       'done)
                     (S 't = zero-token + 9)
                      (print-err J "You already have nine parameters",
                       set-help J ["I'm going to ignore the # sign you just used,"
                                   "as well as the token that followed it."],
                       tex-error J, go ())
                     (: _ (pin S 't (S 't + 1))
                        _ (J 'cur-tok != S 't ?
                             (print-err J "Parameters must be numbered consecutively",
                              set-help J ["I've inserted the digit you should have used after the #."
                                          "Type `1' to delete what you did use."],
                              back-error J))
                        (store-def J s, go ()))))
              (store-def J (J 'cur-tok), go ())))
       (? (go () = 'done) 0
          (: _ (store-def J end-match-token)
             (? (J 'cur-cmd = right-brace)
                 (print-err J "Missing { inserted", pin J 'align-state (J 'align-state + 1),
                  set-help J ["Where was the left brace? You said something like `\\def\\a}',"
                              "which I'm going to interpret as `\\def\\a{}'."],
                  tex-error J, 1)
                0))))
   (scan-body J S macro-def xpand)
    (: (go _)
        (: _ (? xpand (expand-next J) (get-token J))
           t (J 'cur-tok)
           (? (t < right-brace-limit)
               (? (J 'cur-cmd < right-brace) (pin S 'u (S 'u + 1), store-def J t, go ())
                  (: _ (pin S 'u (S 'u - 1)) (S 'u != 0 ? (store-def J t, go ()))))
              (J 'cur-cmd = mac-param && macro-def)
               (param-number J S xpand, store-def J (J 'cur-tok), go ())
              (store-def J t, go ())))
       (go ()))
   ; get_next until unexpandable, \the's tokens stored as they are (tex.web 478)
   (expand-next J)
    (: (go _)
        (: _ (get-next J)
           (? (J 'cur-cmd <= max-command) ()
              (J 'cur-cmd != the) (expand J, go ())
              (: l (the-toks J) (pin J 'def-ref (foldl (\ a t (t . a)) (J 'def-ref) l), go ()))))
       (go (), x-token J))
   (param-number J S xpand)
    (: s (J 'cur-tok) _ (? xpand (get-x-token J) (get-token J))
       (J 'cur-cmd != mac-param ?
          (? (J 'cur-tok <= zero-token || J 'cur-tok > S 't)
              (print-err J "Illegal parameter number in definition of ",
               sprint-cs J (J 'warning-index),
               set-help J ["You meant to type ## instead of #, right?"
                           "Or maybe a } was forgotten somewhere earlier, and things"
                           "are all screwed up? I'm going to assume that you meant ##."],
               back-error J, pin J 'cur-tok s)
             (pin J 'cur-tok (out-param-token - 48 + J 'cur-chr)))))
   (read-open J m) (peep (J 'read-open) m closed)
   (read-toks J n r)
    (: _ (pins J 'scanner-status defining 'warning-index r 'def-ref [end-match-token])
       m (n < 0 || n > 15 ? 16 n)
       s (J 'align-state) _ (pin J 'align-state 1000000)
       (go n) (: n2 (read-line J m n r) (J 'align-state != 1000000 ? (go n2)))
       _ (go n)
       _ (pins J 'def-ref (rev (J 'def-ref)) 'scanner-status normal 'align-state s)
       (pin J 'cur-val (J 'def-ref)))
   ; one line of a \read into J 'def-ref; answers n, -1 once the terminal has prompted
   (read-line J m n r)
    (: _ (begin-file-reading J) I (J 'cur) _ (pin I 'name (m + 1))
       ro (read-open J m)
       n2 (? (ro = closed)
              (? (J 'interaction <= nonstop-mode)
                  (fatal-error J "*** (cannot \\read from terminal in nonstop modes)")
                 (n < 0) (set-line J I (prompt-input J ""), n)
                 (print-ln J, sprint-cs J r, set-line J I (prompt-input J "="), -1))
             (: l (input-ln (J 'read-file m))
                _ (? (l != ()) (pin (J 'read-open) m normal)
                     (: _ (pin (J 'read-open) m closed)
                        (ro = normal && J 'align-state != 1000000 ?
                           (runaway J, print-err J "File ended within ", print-esc J "read",
                            set-help J ["This \\read has unbalanced braces."],
                            pin J 'align-state 1000000, pins I 'buf "" 'limit -1, tex-error J))))
                _ (set-line J I (l = () ? "" l))
                n))
       _ (pin I 'state new-line)
       (go _)
        (: _ (get-token J)
           (? (J 'cur-tok = 0) ()
              (J 'align-state < 1000000)
               (: (drain _) (get-token J, J 'cur-tok != 0 ? (drain ()))
                  (drain (), pin J 'align-state 1000000))
              (store-def J (J 'cur-tok), go ())))
       _ (go ())
       _ (end-file-reading J)
       n2)

   ; --- conditionals (tex.web 487-510) ------------------------------------------------------
   ; the condition stack is a list of tablets; its cells are compared by identity
   (push-cond J)
    (pins J 'cond-ptr ({'limit (J 'if-limit) 'cur-if (J 'cur-if) 'line (J 'if-line)} . J 'cond-ptr)
            'cur-if (J 'cur-chr) 'if-limit if-code 'if-line (J 'line))
   (pop-cond J)
    (: p <(J 'cond-ptr)
       (pins J 'if-line (p 'line) 'cur-if (p 'cur-if) 'if-limit (p 'limit) 'cond-ptr >(J 'cond-ptr)))
   (pass-text J)
    (: sss (J 'scanner-status) _ (pins J 'scanner-status skipping 'skip-line (J 'line))
       (go l)
        (: _ (get-next J)
           (? (J 'cur-cmd = fi-or-else)
               (l != 0 ? (go (J 'cur-chr = fi-code ? (l - 1) l)))
              (J 'cur-cmd = if-test) (go (l + 1))
              (go l)))
       (go 0, pin J 'scanner-status sss))
   (change-if-limit J l p)
    (? (p == J 'cond-ptr) (pin J 'if-limit l)
       (: (go q)
           (? (q = ()) (confusion J "if")
              (>q == p) (pin <q 'limit l)
              (go >q))
          (go (J 'cond-ptr))))
   (conditional J)
    (: _ (push-cond J) save (J 'cond-ptr) this (J 'cur-chr)
       b (if-value J this save)
       (? (b = 'ret) ()
          (b = 'common) (common-ending J)
          (: _ (int-par J tracing-commands-code > 1 ?
                  (begin-diagnostic J, print J (b ? "{true}" "{false}"), end-diagnostic J 0))
             (? b (change-if-limit J else-code save)
                (skip-to-else J save, common-ending J)))))
   (common-ending J) (J 'cur-chr = fi-code ? (pop-cond J) (pin J 'if-limit fi-code))
   (extra-or J)
    (print-err J "Extra ", print-esc J "or",
     set-help J ["I'm ignoring this; it doesn't match any \\if."], tex-error J)
   (skip-to-else J save)
    (: (go _)
        (: _ (pass-text J)
           (? (J 'cond-ptr == save) (J 'cur-chr = or-code ? (extra-or J, go ()))
              (J 'cur-chr = fi-code ? (pop-cond J), go ())))
       (go ()))
   (if-value J this save)
    (? (this <= if-cat-code) (test-chars J this)
       (this <= if-dim-code) (test-rel J this)
       (this = if-odd-code) (scan-int J, J 'cur-val % 2 != 0)
       (this = if-vmode-code) (abs (mode J) = vmode)
       (this = if-hmode-code) (abs (mode J) = hmode)
       (this = if-mmode-code) (abs (mode J) = mmode)
       (this = if-inner-code) (mode J < 0)
       (this <= if-vbox-code)
        (: _ (scan-eight-bit-int J) p (equiv J (box-base + J 'cur-val))
           (? (this = if-void-code) (p = ())
              (p = ()) 0
              (p 'type = (this = if-hbox-code ? hlist-node vlist-node))))
       (this = ifx-code) (test-ifx J)
       (this = if-eof-code) (scan-four-bit-int J, read-open J (J 'cur-val) = closed)
       (this = if-true-code) 1
       (this = if-false-code) 0
       (if-case J save))
   (get-x-or-active J)
    (get-x-token J,
     J 'cur-cmd = relax && J 'cur-chr = no-expand-flag ?
       (pins J 'cur-cmd active-char 'cur-chr (J 'cur-tok - cs-token-flag - active-base)))
   (not-char? J) (J 'cur-cmd > active-char || J 'cur-chr > 255)
   (test-chars J this)
    (: _ (get-x-or-active J)
       m (not-char? J ? relax (J 'cur-cmd)) n (not-char? J ? 256 (J 'cur-chr))
       _ (get-x-or-active J)
       _ (not-char? J ? (pins J 'cur-cmd relax 'cur-chr 256))
       (this = if-char-code ? (n = J 'cur-chr) (m = J 'cur-cmd)))
   (test-rel J this)
    (: (scan _) (this = if-int-code ? (scan-int J) (scan-normal-dimen J))
       _ (scan ()) n (J 'cur-val) _ (non-blank J)
       t (J 'cur-tok - other-token)
       r (? (t >= 60 && t <= 62) t
            (: _ (print-err J "Missing = inserted for ") _ (print-cmd-chr J if-test this)
               _ (set-help J ["I was expecting to see `<', `=', or `>'. Didn't."])
               (back-error J, 61)))
       _ (scan ())
       v (J 'cur-val)
       (? (r = 60) (n < v) (r = 61) (n = v) (n > v)))
   (test-ifx J)
    (: sss (J 'scanner-status) _ (pin J 'scanner-status normal)
       _ (get-next J) n (J 'cur-cs) p (J 'cur-cmd) q (J 'cur-chr)
       _ (get-next J)
       b (? (J 'cur-cmd != p) 0
            (J 'cur-cmd < call) (J 'cur-chr = q)
            (J 'cur-chr @ a (equiv J n @ c (a == c || a = c))))
       (pin J 'scanner-status sss, b))
   (if-case J save)
    (: _ (scan-int J) n (J 'cur-val)
       _ (int-par J tracing-commands-code > 1 ?
            (begin-diagnostic J, print J "{case ", print-int J n, print-char J 125, end-diagnostic J 0))
       (go n)
        (? (n = 0) (change-if-limit J or-code save, 'ret)
           (: _ (pass-text J)
              (? (J 'cond-ptr == save) (J 'cur-chr = or-code ? (go (n - 1)) 'common)
                 (J 'cur-chr = fi-code ? (pop-cond J), go n))))
       (go n))
   (fi-or-else-now J)
    (? (J 'cur-chr > J 'if-limit)
        (? (J 'if-limit = if-code) (insert-relax J)
           (print-err J "Extra ", print-cmd-chr J fi-or-else (J 'cur-chr),
            set-help J ["I'm ignoring this; it doesn't match any \\if."], tex-error J))
       (: (go _) (J 'cur-chr != fi-code ? (pass-text J, go ()))
          (go (), pop-cond J)))

   ; --- file names (tex.web 511-538, as tex live has them) --------------------------------
   ; a name's area runs to its last /, its extension from the last . after that
   (split-name s)
    (: n #s
       (last c k) (? (k < 0) -1 (s k = c) k (last c (k - 1)))
       a (last 47 (n - 1))
       e (last 46 (n - 1))
       e2 (e > a ? e n)
       [(snip s (a + 1) e2) (snip s 0 (a + 1)) (snip s e2 n)])
   (end-name J s)
    (split-name (string (filter (\ c (c != 34)) (chars s))) @ [n a e]
       (pins J 'cur-name n 'cur-area a 'cur-ext e))
   (scan-file-name J)
    (: _ (pin J 'name-in-progress 1) _ (non-blank J)
       (go acc q)
        (? (J 'cur-cmd > other-char || J 'cur-chr > 255) (back-input J, acc)
           (J 'cur-chr = 32 && !q) acc
           (: c (J 'cur-chr) acc2 (c . acc) q2 (c = 34 ? !q q)
              (get-x-token J, go acc2 q2)))
       s (string (rev (go () 0)))
       (end-name J s, pin J 'name-in-progress 0))
   (print-file-name J n a e) (slow-print J a, slow-print J n, slow-print J e)
   (ends-with? s t) (#s >= #t && snip s (#s - #t) #s = t)
   ; kpathsea's search for a tex input: name.tex before name, in the current directory as ./
   (find-input J name)
    (: cands (ends-with? name ".tex" ? [name] [(name + ".tex") name])
       dirs (contains? name 47 ? [""] (J 'tex-inputs))
       (try ds cs)
        (? (ds = ()) ()
           (cs = ()) (try >ds cands)
           (: p (<ds + <cs) (readable? p ? p (try ds >cs))))
       (try dirs cands))
   (contains? s c) (: n #s (go k) (? (k >= n) 0 (s k = c) 1 (go (k + 1))) (go 0))
   (readable? p) (open p "r" @ q (hot? q ? (close q, 1) 0))
   (read-whole p) (: q (open p "r") s (slurp q) (close q, {'s s 'pos 0}))
   (pack-cur-name J) (J 'cur-area + J 'cur-name + J 'cur-ext)
   (prompt-file-name J s e)
    (: _ (? (s = "input file name") (print-err J "I can't find file `")
            (print-err J "I can't write on file `"))
       _ (print-file-name J (J 'cur-name) (J 'cur-area) (J 'cur-ext))
       _ (print J "'.")
       _ (e = ".tex" || e = "" ? (show-context J))
       _ (print-ln J) _ (print J "(Press Enter to retry, or Control-D to exit")
       _ (e != "" ? (print J "; default file extension is `", print J e, print J "'"))
       _ (print J ")") _ (print-ln J)
       _ (print-nl J "Please type another ") _ (print J s)
       _ (J 'interaction < scroll-mode ?
            (fatal-error J "*** (job aborted, file error in nonstop mode)"))
       l (prompt-input J ": ")
       (go k) (k < #l && l k = 32 ? (go (k + 1)) k)
       (end-name J (snip l (go 0) #l), J 'cur-ext = "" ? (pin J 'cur-ext e)))
   (open-log-file J)
    (: old (J 'selector)
       _ (J 'job-name = () ? (pin J 'job-name "texput"))
       name (J 'job-name + ".log")
       _ (pins J 'log-file (open name "w") 'log-name name 'selector log-only 'log-opened 1)
       _ (say (J 'log-file) (J 'banner))
       _ (slow-print J (J 'format-ident)) _ (print J "  ")
       t (J 'sys-time)
       _ (print-int J (t 'day)) _ (print-char J 32)
       _ (say (J 'log-file) (snip months (3 * t 'month - 3) (3 * t 'month)))
       _ (print-char J 32) _ (print-int J (t 'year)) _ (print-char J 32)
       _ (print-two J (t 'time // 60)) _ (print-char J 58) _ (print-two J (t 'time % 60))
       I (<(rev (J 'cur . J 'istack)))
       _ (print-nl J "**")
       buf (I 'buf) l (I 'limit)
       l2 (l >= 0 && l < #buf && buf l = int-par J end-line-char-code ? (l - 1) l)
       (go k) (k <= l2 ? (print J (buf k), go (k + 1)))
       _ (go (I 'start))
       _ (print-ln J)
       (pin J 'selector (old + 2)))
   (start-input J)
    (: _ (scan-file-name J)
       (go _)
        (: _ (begin-file-reading J)
           p (find-input J (pack-cur-name J))
           (? (p != ()) p
              (end-file-reading J, prompt-file-name J "input file name" "", go ())))
       path (go ())
       I (J 'cur)
       _ (pin (J 'input-file) (I 'index) (read-whole path))
       _ (pin I 'name path)
       _ (J 'job-name = () ? (pin J 'job-name (J 'cur-name), open-log-file J))
       _ (? (J 'term-offset + #path > J 'max-print-line - 2) (print-ln J)
            (J 'term-offset > 0 || J 'file-offset > 0) (print-char J 32))
       _ (print-char J 40) _ (pin J 'open-parens (J 'open-parens + 1))
       _ (slow-print J path) _ (flush (J 'term-out))
       _ (pins I 'state new-line 'start 0)
       _ (pin J 'line 1)
       l (input-ln (J 'input-file (I 'index)))
       (firm-up-the-line J I (l = () ? "" l)))
   (give-err-help J) (token-show J (equiv J err-help-loc))

))
