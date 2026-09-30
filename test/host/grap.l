; --- test/host/grap.l: grap (src/apps/kore/grap.l), the laws without plan 9 at hand ---
; a graph's coordinate macros and automatic ticks as plan 9 spells them, the troff around a
; graph kept, log axes' decades, troff's minus on a negative tick; then grap as a command,
; its output drawn by kore's pic. test/gate/grap.sh holds it to plan 9's own, byte for byte.
;   cat test/00-init.l test/host/grap.l | out/love
(borrow 'posix)
(: K (cite 'kore)
   run (K 'gr-run)
   (grap t) (: r (run ["-"] t) (? (<r = 0) (r 1) ""))
   (has s p) (0 <= (K 'wg-find) s p 0)
   love ((cwd 0) + "/out/love")
   dir ((cwd 0) + "/out/.graptest-" + show (getpid 0))
   _ (hark ["rm" "-rf" dir]) _ (mkdir dir 448)
   (put p s) (: q (open p "w") _ (say q s) (close q))

   ; -- one graph: its system, frame, automatic ticks and marks ------------------------
   g1 (grap "a\n.G1\n1 2\n2 4\n3 9\n.G2\nb\n")
   _ (test (has g1 ".lf 1 -\na\n.PS\nscale = 1\n.lf 3\n")
           (has g1 "Graph: [\n\t# gg 1 .. 3, 2 .. 9\n")
           (has g1 "define xy_gg @ \t(($1)-(0.86))*1.31579, (($2)-(1.51))*0.250627 @\n")
           (has g1 "Frame:\tbox ht frameht wid framewid with .sw at 0,0 \n")
           (has g1 "xq,xm = 0.5,0, yq,ym = 2,0\n")
           (has g1 "\tline  left ticklen from (0,y_gg(8))\n\t\"8 \" wid 0.23 rjust at last line.end\n")
           (has g1 "box invis wid 0 ht 1*textht \"\\(bu\" at xy_gg(3,9)\n\n] \n.PE\n.lf 7\nb\n"))
   ; an empty graph draws nothing, but the picture is still there
   _ (test (has (grap ".G1\n.G2\n") ".PS\nscale = 1\n.lf 2\n.lf 1 /usr/lib/plan9/lib/grap.defines\n.lf 1 -\n.PE\n.lf 3\n")
           !(has (grap ".G1\n.G2\n") "Graph"))
   ; a range through zero: -0 on the first tick, and troff's minus on the negative ones
   g2 (grap ".G1\nticks bot from -1 to 1 by 0.5\n0 0\n.G2\n")
   _ (test (has g2 "box invis \"\\-0.5\" ht .25") (has g2 "box invis \"0\" ht .25")
           (has (grap ".G1\n0 0\n10 100\n.G2\n") "\"-0 \" wid 0.37 rjust"))
   ; a log axis: 1 2 5 a decade, the top of the range left out, the ticks at the logs
   g3 (grap ".G1\ncoord y 1,100 log y\n1 1\n.G2\n")
   _ (test (has g3 "(0,y_gg(0.30103))\n\t\"2 \"") (has g3 "\"50 \"") !(has g3 "\"100 \"")
           (has g3 "box invis wid 0 ht 1*textht \"\\(bu\" at xy_gg(1,0)"))
   ; draw joins the points, a mark at each
   g4 (grap ".G1\ndraw dashed \"x\"\n1 1\n2 2\n.G2\n")
   _ (test (has g4 "Lgg: xy_gg(1,1)\n\"x\" at xy_gg(1,1)\nline dashed from Lgg to xy_gg(2,2); Lgg: Here\n"))
   ; for, if and a macro, run as text
   g5 (grap ".G1\ndefine p { plot \"$1\" at $2, $2 }\nfor i from 1 to 2 do { p(k, i) }\nif 1 > 2 then { p(no, 5) } else { p(yes, 3) }\n.G2\n")
   _ (test (has g5 "# for i from 1 to 2 by + 1 \n") (has g5 "\"k\" at xy_gg(2,2)") (has g5 "\"yes\" at xy_gg(3,3)")
           !(has g5 "\"no\""))

   ; -- the command ----------------------------------------------------------------------
   f (dir + "/g.ms")
   _ (put f ".G1\nlabel bot \"x\"\n1 1\n2 3\n.G2\n")
   r1 (hark [love "kore" "grap" f])
   r2 (hark [love "kore" "grap" (dir + "/none.g")])
   _ (test (<r1 = 0) (has >r1 (".lf 1 " + f + "\n")) (has >r1 "Label:\tbox invis")
           (<r2 = 1))
   ; what grap writes, kore's pic draws
   _ (put (dir + "/g.pic") >r1)
   r3 (hark [love "kore" "pic" (dir + "/g.pic")])
   _ (test (<r3 = 0) (has >r3 "\\D'l "))
   _ (hark ["rm" "-rf" dir]))
(test_fin (), puts "grap: ok", putc 10, 0)
