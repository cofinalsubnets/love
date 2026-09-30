; --- test/host/chem.l: chem (src/apps/kore/chem.l), the laws without groff at hand ---
; the prelude and chem.pic's copy once, a moiety's width and subscripts, a bond's corners, a
; ring's vertices in chem's own degrees, heterocycles chopped at their atoms; then chem as a
; command. test/gate/chem.sh holds it to groff's own, byte for byte.
;   cat test/00-init.l test/host/chem.l | out/love
(borrow 'posix)
(: K (cite 'kore)
   run (K 'ch-run)
   (chem t) (: r (run ["-"] t) (? (<r = 0) (r 1) ""))
   (has s p) (0 <= (K 'wg-find) s p 0)
   love ((cwd 0) + "/out/love")
   dir ((cwd 0) + "/out/.chemtest-" + show (getpid 0))
   _ (hark ["rm" "-rf" dir]) _ (mkdir dir 448)
   (put p s) (: q (open p "w") _ (say q s) (close q))

   ; -- the alkyl chain of the manual ----------------------------------------------------
   c1 (chem "a\n.cstart\nCH3\nbond\nC\ndouble bond up\nO\nbond right from C\nCH3\n.cend\nb\n.cstart\n.cend\n")
   _ (test (has c1 "a\n.PS\ncopy \"")
           (has c1 "\"\n\ttextht = 0.16; textwid = .1; cwid = 0.12\n\tlineht = 0.2; linewid = 0.2\nLast: 0,0\n\n#CH3\n")
           (has c1 "Last: CH3: atom(\"CH\\s-3\\d3\\u\\s+3\", 0.3, 0.16, 0.06, 0.16, 0.12, 0.015) with .L.w at Last.e\n")
           (has c1 "Last: bond(0.2, 90, from Last.R.e )\n")
           (has c1 "Last: doublebond(0.2, 0, from Last.C.n )\n")
           (has c1 "Last: O: atom(\"O\", 0.12, 0.16, 0.06, 0.16, 0.12, 0.015) with .C.s at Last.end\n")
           (has c1 "Last: bond(0.2, 90, from C.R.e)\n")
           ; the second diagram has no prelude
           (has c1 ".PE\nb\n.PS\nLast: 0,0\n.PE\n"))
   ; -- rings: chem's degrees are 57.29578 to the radian, so a vertex straight down is off
   c2 (chem ".cstart\nR1: ring put N at 1 double 2,3\n.cend\n")
   _ (test (has c2 "R1: Last: [\n\tC: 0,0\n\tV0: (-0.259808,0.15)\n\tV1: (0,0.3)\n")
           (has c2 "\tV4: (8.00947e-09,-0.3)\n")
           (has c2 "\tV1: ellipse invis ht 0.16 wid 0.12 at V1\n\tN:atom(\"N\", 0.12, 0.16, 0.06, 0.16, 0.12, 0.015) at V1\n")
           (has c2 "\tline from V1 to V2 chop 0.08 chop 0\n")
           (has c2 "\tline from 0.85<C,V2> to 0.85<C,V3> chop 0 chop 0\n")
           (has c2 "] with .V5.w at Last.e \n"))
   ; the size scales what it says, a ring5's radius is pi's own
   c3 (chem ".cstart\nsize 12\nbenzene\n.cend\n")
   c4 (chem ".cstart\nring5 pointing down\n.cend\n")
   _ (test (has c3 "\tcircle rad 0.18 at 0,0\n") (has c4 "\tV5: (0.242705,-0.0788596)\n"))

   ; -- the command ----------------------------------------------------------------------
   f (dir + "/c.ms")
   _ (put f ".cstart\nbenzene\nbond 30 ; OH\n.cend\n")
   r1 (hark [love "kore" "chem" f])
   r2 (hark [love "kore" "chem" (dir + "/none.chem")])
   _ (test (<r1 = 0) (has >r1 "#bond 30 ; OH\nLast: bond(0.2, 30, from Last.V1.ne )\n")
           (<r2 = 1))
   _ (hark ["rm" "-rf" dir]))
(test_fin (), puts "chem: ok", putc 10, 0)
