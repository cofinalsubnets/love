; test/gate/fzgen.l -- the random cases of the grap, gpic and chem gates, drawn from a seed.
;   love test/gate/fzgen.l LANG SEED N DIR   writes DIR/fz-SEED-I.EXT for I in [0, N)
;   love test/gate/fzgen.l LANG known           the divergences LANG's cases steer around
; each case draws from its own stream (seed, index), so one regenerates alone. undefined
; names and odd attribute runs are drawn on purpose: both tools must refuse alike
(borrow 'posix)
(: nl (string 10)
   ; the known differences: each one a steer below, named where it is read, until it is
   ; fixed and its entry goes. the gates print them; FZ_STEER=0 draws through them all
   fz-known [["grap" "syntax-recovery" "a syntax error's .lf line and echoed rest (a bare draw or new, words in data, copy thru short of fields)"]]
   fz-steer (getenv "FZ_STEER" != "0")
   (known? nm) (fz-steer && any (k \ k 1 = nm) fz-known)
   (pick l) (l (rand #l))
   (chance p) (randf 1.0 < p)
   (opt p s) (chance p ? s "")
   (sp l) (join " " (filter (s \ 0 < #s) l))
   (times n f) (0 < n ? ((f 0) . (times (n - 1) f)) ())
   (q s) ("\"" + s + "\"")
   ; numbers as a hand writes them: ints, and floats to 1-4 places
   (fl hi) (: d (1 + rand 4) (show (rand (hi * d 10) / d 10)))
   ; a graph on a log scale draws neither negatives nor zeros: lg holds it for the case
   lg {}
   (log? _) (peep lg 0 0)
   (num hi) (: s (chance 0.3 ? (show (rand hi)) (fl hi)) (log? 0 && elem s ["0" "0.0"] ? "1" s))
   (sgn s) (!(log? 0) && chance 0.1 ? ("-" + s) s)
   (pos _) (chance 0.5 ? (show (1 + rand 9)) (fl 9 @ s (s = "0" ? "1" s)))
   (small _) (pick ["0.05" ".2" ".1" "0.5" "1" "1.5" "2" "2.5" "0.3"])

   ; --- grap ---------------------------------------------------------------------------
   gside ["bot" "left" "top" "right"]
   gstyle ["solid" "dashed" "dotted" "invis"]
   gmarks ["bullet" "delta" "plus" "times" "square" "star"]
   gstrs ["a" "\\(*a" "\\fBbold\\fP" "Time (s)" "value" "x axis" "y" "n"]
   (gstr _) (q (chance 0.12 ? (show (rand 100) + "%") (pick gstrs)))
   (gpt nm) (sp [nm (sgn (num 100) + ", " + num 100)])
   (gsty _) (sp [(pick gstyle) (opt 0.4 (small 0))])
   (gex k) (: r (rand (k < 1 ? 2 7))
              (? (r < 2) (num 10)
                 (r = 2) ("(" + gex (k - 1) + ")")
                 (r = 3) (pick ["int" "log" "exp" "sqrt"] + "(" + pos 0 + ")")
                 (r = 4) ("max(" + gex (k - 1) + ", " + gex (k - 1) + ")")
                 (r = 5) (gex (k - 1) + " " + pick ["+" "-" "*"] + " " + gex (k - 1))
                 (gex (k - 1) + " / " + pos 0)))
   ; a data line outside copy thru is all numbers; inside, every field the body reads
   (gdata _) (rand (known? "syntax-recovery" ? 4 5) @ k
              (? (k = 0) (num 100)
                 (k = 1) (sp [(num 1000) (num 100) (num 10)])
                 (k = 4) (sp [(pick ["a" "b" "x1"]) (num 100) (num 100)])
                 (sp [(sgn (num 100)) (num 100)])))
   (gcdata _) (sp [(num 1000) (known? "syntax-recovery" || chance 0.8 ? (num 100) "")
                   (chance 0.5 ? (pick ["a" "b" "x1"]) (num 10))])
   (glist _) (join ", " (times (1 + rand 4) (_ \ sp [(num 100) (opt 0.3 (gstr 0))])))
   (grange star) (sp ["from" (show (1 + rand 9)) "to" (show (10 + rand 20))
                      (opt 0.6 ("by " + (star ? (pick ["" "*" "+"]) "") + show (2 + rand 9)))])
   gfmt ["%.1f" "%g" "%5f" "%g%%" "%.2f"]
   ; a range, now and then high to low
   (grng _) (: a (sgn (num 100)) b (show (read a + 1 + rand 900))
               (chance 0.15 ? (b + ", " + a) (a + ", " + b)))
   (gcoord nm) (: x (chance 0.7) y (chance 0.5)
                  (sp ["coord" nm (x ? ("x " + grng 0) "") (y ? ("y " + grng 0) "")
                       (log? 0 ? (pick ["" "log x" "log y" "log log" "log x log y"]) "")]))
   (gplot nm) (sp ["plot"
                   (rand 6 @ k (? (k = 0) (pick gmarks)
                                  (k = 1) (gex 2)
                                  (k = 2) ("sprintf(" + q (pick ["%g" "%e" "x=%g" "%.2f" "%5f"]) + ", " + gex 1 + ")")
                                  (sp [(gstr 0) (pick ["" "ljust" "rjust above"])])))
                   "at" (gpt nm)])
   (gcopy last) (: body (pick ["circle at $1, $2" "next at $1, $2" "plot \"$3\" at $1, $2"
                               "line from $1,$2 to $1,$2+1"])
                   til (!last || chance 0.6)
                   ([(sp ["copy thru {" body "}" (til ? "until \"END\"" "")])]
                    + times (1 + rand 5) gcdata + (til ? ["END"] ())))
   (gframe _) (sp ["frame" (opt 0.4 ("ht " + pick ["1" "1.5" "2" "2.5" "3"]))
                   (opt 0.3 ("wid " + pick ["1" "2" "3" "4"]))
                   (join " " (times (rand 3) (_ \ sp [(pick gside) (gsty 0)])))
                   (opt 0.2 (pick gstyle))])
   (gticks _) (sp ["ticks" (pick gside)
                   (opt 0.4 (sp [(pick ["in" "out"]) (opt 0.4 (small 0))]))
                   (rand 5 @ k (? (k = 0) "off"
                                  (k = 1) ("at " + glist 0)
                                  (k = 2) (sp [(grange 1) (opt 0.3 (q (pick gfmt)))])
                                  ""))])
   (ggrid _) (sp ["grid" (pick gside) (opt 0.5 (gsty 0))
                  (chance 0.5 ? ("at " + glist 0) ("from " + show (1 + rand 5) + " to " + show (6 + rand 20) + " by " + show (1 + rand 9)))])
   (glabel _) (sp ["label" (opt 0.85 (pick gside)) (gstr 0) (opt 0.3 (gstr 0))
                   (opt 0.4 (pick ["ljust" "rjust" "above" "below"]))
                   (opt 0.3 (sp [(pick ["up" "down" "left" "right"]) (small 0)]))
                   (opt 0.15 ("width " + small 0))])
   ; a bare draw or new is a syntax error
   (gdraw _) (sp [(pick ["draw" "new"]) (chance 0.5 ? (gsty 0) "")
                  (pick ["" "bullet" "delta" "\"x\"" "\"\\(sq\""])] @ s
                 (known? "syntax-recovery" && elem s ["draw" "new"] ? (s + " dotted") s))
   ; one statement, as lines; nm names the coordinate system the case set up, if any
   (gstmt nm last) (rand 31 @ k
     (? (k < 4) [(gdata 0)]
        (k < 8) [(gplot nm)]
        (k = 8) [(sp ["next" nm "at" (gpt nm)])]
        (k = 9) [(sp [(pick ["line" "arrow"]) (opt 0.5 (gsty 0)) "from" (gpt nm) "to" (gpt nm)])]
        (k = 10) [(sp ["circle" (opt 0.3 ("rad " + small 0)) "at" (gpt nm)])]
        (k = 11) (: v ("v" + show (1 + rand 3)) [(v + " = " + gex 3) ("plot \"v\" at " + v + ", 2")])
        (k = 12) [(pick ["pic box" "pic circle at 1,1" "pic \"hi\" at 0,0"])]
        (k = 13) (: p ("pt" + show (1 + rand 2))
                    [("define " + p + " { plot \"$1\" at $2, $3 }")
                     (p + "(" + pick ["a" "b" "xy"] + ", " + num 100 + ", " + num 100 + ")")])
        (k = 14) [(sp ["for i" (grange 1) "do {"
                       (pick ["plot \"i\" at i, i*i" "plot bullet at i, i+1" "next at i, i"]) "}"])]
        (k < 17) [(gframe 0)]
        (k < 20) [(gticks 0)]
        (k = 20) [(ggrid 0)]
        (k < 23) [(glabel 0)]
        (k = 23) [(gdraw 0)]
        (k = 24) (gcopy last)
        (k = 25) [(chance 0.3 ? ("if " + pos 0 + " && " + pos 0 + " then { plot \"both\" at " + gpt "" + " }")
                     ("if " + num 10 + " " + pick ["<" ">" "==" "!=" ">="] + " " + num 10
                      + " then { plot \"t\" at " + gpt "" + " } else { plot \"f\" at " + gpt "" + " }"))]
        (k = 26) [(pick ["print \"msg\"" ("print sqrt(" + pos 0 + ")")])]
        (k = 27) [(pick [".sp" (".ps " + show (8 + rand 5)) ".ft B"])]
        (k = 28) [(pick ["margin = 0" "margin = .2" ("margin = " + small 0)])]
        (k = 29) [(chance 0.3 ? (sp ["coord" nm]) (gcoord nm))]
        [(gplot nm)]))
   (grap _) (: _ (pin lg 0 (chance 0.25 ? 1 0))
               nm (pick ["" "" "" "aa"])
               head (nm != "" || chance 0.4 ? [(gcoord nm)] ())
               n (1 + rand 12)
               body (catmap (i \ gstmt nm (i = n - 1)) ^n)
               ([(sp [".G1" (pick ["" "3i" "4i 2i"])])] + head + body + [".G2"]))

   ; --- gpic ---------------------------------------------------------------------------
   pprims ["box" "circle" "ellipse" "arc" "line" "arrow" "spline" "move" "polygon"]
   pcorn [".n" ".s" ".e" ".w" ".ne" ".nw" ".se" ".sw" ".c" ".center" ".start" ".end" ".top"
          ".bottom" ".left" ".right"]
   pstrs ["a" "A B" "q" "xy" "label" "text\\fB!\\fP" "\\fBb\\fP" "1"]
   psets ["boxwid" "boxht" "arcrad" "arrowwid" "circlerad" "dashwid" "ellipsewid" "fillval"
          "lineht" "linethick" "linewid" "movewid" "textht" "textwid"]
   pdirs ["up" "down" "left" "right"]
   (ppt _) ("(" + sgn (fl 3) + ", " + fl 3 + ")")
   (pobj c) (rand 3 @ k (? (k = 0 && #(c 'labs)) (pick (c 'labs))
                           (k < 2) ("last " + pick (pprims + ["[]"]))
                           (pick ["1st " "2nd " "2nd last "] + pick pprims)))
   ; a position nests one level: an inner one is a point or a place on an object
   (pbase c) (chance 0.5 ? (ppt 0) (pobj c + opt 0.5 (pick pcorn)))
   (ppos c) (rand 6 @ k (? (k < 2) (ppt 0)
                           (k = 2) (ppt 0 + " + " + ppt 0)
                           (k = 3) (pobj c + opt 0.5 (pick pcorn))
                           (k = 4) (pick ["1/3" "1/2" "2/3"] + " of the way between " + pbase c + " and " + pbase c)
                           (fl 1 + " <" + pbase c + ", " + pbase c + ">")))
   (pvar c) (c 'vars ? (pick ["x" "y" "z"]) (pos 0))
   (pex c k) (: r (rand (k < 1 ? 2 8))
                (? (r = 0) (num 5)
                   (r = 1) (pvar c)
                   (r = 2) ("(" + pex c (k - 1) + ")")
                   (r = 3) (pick ["sin" "cos" "exp" "sqrt" "int"] + "(" + pos 0 + ")")
                   (r = 4) (pick ["max" "min" "atan2"] + "(" + pex c (k - 1) + ", " + pos 0 + ")")
                   (r = 5) (pex c (k - 1) + " " + pick ["+" "-" "*"] + " " + pex c (k - 1))
                   (r = 6) (pex c (k - 1) + " " + pick ["/" "%"] + " " + pos 0)
                   ("-(" + pex c (k - 1) + ")")))
   (ptext c) (sp [(chance 0.15 ? ("sprintf(" + q (pick ["%g" "%+g" "%.2f" "%5f|"]) + ", " + pex c 1 + ")")
                                (q (pick pstrs)))
                  (opt 0.4 (pick ["ljust" "rjust" "above" "below"]))
                  (opt 0.15 (pick ["ljust" "rjust" "above" "below"]))])
   ; the attributes each kind of object takes, as the random packs drew them; dashed and
   ; dotted curves are test/gpic/open's, a filled round shape -t's pen order; one line style
   ; to an object, its length short, and one from, to and at
   pkinds {"box" "closed" "circle" "round" "ellipse" "oval" "arc" "arc" "polygon" "poly" "spline" "curve"}
   pattrs {"closed" ["dashed" "dotted" "invis" "thick" "fill" "same" "text" "colour" "ht" "wid" "at" "slant"]
           "round"  ["dashed" "dotted" "invis" "thick" "same" "text" "colour" "ht" "wid" "rad" "diam" "at"]
           "oval"   ["invis" "thick" "same" "text" "colour" "ht" "wid" "rad" "diam" "at"]
           "arc"    ["invis" "thick" "same" "text" "colour" "rad" "cw" "from" "to" "dir" "then" "head"]
           "poly"   ["fill" "line" "then" "text"]
           "curve"  ["invis" "thick" "same" "text" "colour" "chop" "head" "from" "to" "by" "dir" "then"]
           "open"   ["dashed" "dotted" "invis" "thick" "same" "text" "colour" "chop" "head" "cw" "from" "to"
                     "by" "dir" "then"]}
   (pkind nm) (peep pkinds nm "open")
   (pattr c nm) (pick (pattrs (pkind nm)) @ w
     (? (w = "dashed" || w = "dotted") (sp [w (opt 0.4 (pick ["0.05" ".1" ".2"]))])
        (w = "line") (pick ["dashed" "dotted"])
        (w = "thick") ("thick " + pick ["0.5" "1" "2"])
        (w = "fill") (sp ["fill" (opt 0.4 (pick ["0.3" "0.5" "1"]))])
        (w = "text") (ptext c)
        (w = "colour") (pick ["color" "outline" "shaded"] + " " + q (pick ["red" "blue" "green"]))
        (elem w ["ht" "wid" "rad" "diam"]) (w + " " + small 0)
        (elem w ["at" "from" "to"]) (w + " " + ppos c)
        (w = "slant") (pick ["xslanted" "yslanted"] + " " + pick ["0.2" "0.5" "-0.3"])
        (w = "cw") (pick ["cw" "ccw"])
        (w = "dir") (sp [(pick pdirs) (opt 0.6 (small 0))])
        (w = "then") (sp ["then" (pick pdirs) (opt 0.5 (small 0))])
        (w = "head") (pick ["->" "<-" "<->"])
        (w = "chop") (sp ["chop" (opt 0.4 (small 0))])
        (w = "by") ("by " + fl 2 + ", " + sgn (fl 2))
        w))
   ; an invisible object takes no colour; a bare length only a line, a with only a closed shape
   (pprim c) (: nm (pick pprims)
                as (times (rand 4) (_ \ pattr c nm))
                (style? a) (elem (<(words a)) ["dashed" "dotted"])
                (once? a acc) (elem (<(words a)) ["from" "to" "at"] && any (b \ <(words b) = <(words a)) acc)
                as1 (foldl (\ acc a ((style? a && any style? acc) || once? a acc ? acc (acc + [a]))) () as)
                as' (elem "invis" as1 ? (filter (a \ !(elem (<(words a)) ["color" "outline" "shaded"])) as1) as1)
                (sp [nm (pkind nm = "open" ? (opt 0.12 (small 0)) "") (join " " as')
                     (elem nm ["box" "circle" "ellipse"] ? (opt 0.1 ("with " + pick pcorn + " at " + ppos c)) "")]))
   (plab c p) (chance p ? (: l ("L" + show (rand 4)) (pin c 'labs (l . (c 'labs)), l + ": ")) "")
   ; a block holds plain statements, and blocks while k lasts
   (pblock c k) (sp ["[" (join "; " (times (1 + rand 3) (_ \ (0 < k && chance 0.2 ? (pblock c (k - 1)) (pstmt1 c 0))))) "]"
                     (opt 0.3 (chance 0.5 ? ("at " + ppos c) ("with " + pick pcorn + " at " + ppos c)))])
   ; one statement on one line; k bounds the nesting of blocks, loops and ifs
   (pstmt1 c k) (rand (k < 1 ? 14 20) @ r
     (? (r < 7) (plab c 0.25 + pprim c)
        (r = 7) (plab c 0.2 + ptext c + opt 0.2 (" at " + ppos c))
        (r = 8) (pick pdirs)
        (r = 9) (pick psets + " = " + small 0)
        (r = 10) (c 'vars ? (pick ["x" "y" "z"] + " = " + pex c 2) ("x = " + num 3))
        (r = 11) (0 < #(c 'defs) ? (pick (c 'defs)) (pprim c))
        (r = 12) (sp ["move" "to" (ppos c)])
        (r = 13) (sp [(pick ["box" "circle" "ellipse"]) (ptext c)])
        (r < 17) (plab c 0.3 + pblock c k)
        (r = 17) (sp ["for" (pick ["i" "j"]) "=" (show (1 + rand 2)) "to" (show (2 + rand 3))
                      (opt 0.6 ("by " + pick ["" "*"] + show (2 + rand 2)))
                      "do {" (pstmt1 c 0) "}"])
        (r = 18) (sp ["if" (pex c 1) (pick ["<" ">" "!=" "=="]) (pex c 1) "then {" (pstmt1 c 0) "}"
                      (opt 0.5 ("else { " + pstmt1 c 0 + " }"))])
        (: m ("m" + show (rand 3)) (pin c 'defs (m . (c 'defs)), "define " + m + " { " + pprim c + " }"))))
   (gpic _) (: c {'labs () 'defs () 'vars (chance 0.3)}
               pre (c 'vars ? [("x = " + small 0) ("y = " + small 0) ("z = " + small 0)] ())
               ([".PS"] + pre + times (1 + rand 8) (_ \ pstmt1 c 2) + [".PE"]))

   ; --- chem ---------------------------------------------------------------------------
   catoms ["BP" "Br" "C" "C2H5" "CH" "CH2" "CH2OH" "CH3" "CH3CH2" "CHO" "Cl" "CN" "C=O" "CO" "COOH"
           "F" "Fe(CN)6" "H" "H2O" "HC" "HO" "HOCH2" "N" "Na+" "N(CH3)2" "NH" "NH2" "NH4+" "NHCH3"
           "NO2" "O" "O-" "OC" "OCH3" "OH" "S" "SO3H"]
   clabs ["A" "B" "C1" "R1" "R2" "R3" "X1"]
   ccomp ["n" "s" "e" "w" "ne" "nw" "se" "sw" "up" "down" "left" "right"]
   ; a place on a labelled object; a bond's label is always given its end
   (cplace c) (: l (pick (c 'labs))
                 (l + pick (elem l (c 'bonds) ? [".start" ".end"] ["" "" ".start" ".end" ".c" (".V" + show (1 + rand 6))])))
   (clab c p bond) (chance p ? (: l (pick clabs)
                                  (pin c 'labs (l . (c 'labs)),
                                   pin c 'bonds (bond ? (l . (c 'bonds)) (filter (b \ b != l) (c 'bonds))),
                                   l + ": ")) "")
   ; a bond from a name no label holds is drawn bare, from Q or Last; from reads to the
   ; line's end, so the style comes before it
   (cbond c) (: some (0 < #(c 'labs))
                r (rand 6 @ k (? (some && k < 3) ("from " + cplace c)
                                 (k = 3) (pick ["from Q" "from Last"]) ""))
                bare (elem r ["from Q" "from Last"])
                (sp [(pick ["" "" "front" "back" "double" "triple"]) "bond"
                     (opt 0.6 (chance 0.5 ? (show (rand 420 - 30)) (pick ccomp)))
                     (bare ? "" (opt 0.3 ("length " + pick ["0.3" ".2" "0.5" "1"])))
                     (bare ? "" (opt 0.2 (pick ["dashed" "dotted"]))) r
                     (opt 0.4 ("; " + pick catoms))]))
   ; a ring's vertices bound its puts and doubles; a flat ring's last bond is missing
   crings {"ring" 6 "ring3" 3 "ring4" 4 "ring5" 5 "ring6" 6 "ring8" 8 "benzene" 6 "flatring" 5 "aromatic ring" 6}
   (cring c) (: nm (pick ["ring" "ring" "ring3" "ring4" "ring5" "ring6" "ring8" "benzene" "flatring" "aromatic ring"])
                n (crings nm)
                (sp [nm (opt 0.5 ("pointing " + pick ["up" "down" "left" "right"])) (opt 0.2 "aromatic")
                     (join " " (times (rand 3) (_ \ "put " + pick catoms + " at " + show (1 + rand n))))
                     (opt 0.4 ("double " + join "," (catmap (_ \ (1 + rand (n - 1)) @ v [(show v) (show (v + 1))]) ^(1 + rand 2))))
                     ((0 < #(c 'labs)) ? (opt 0.1 ("with .V" + show (1 + rand n) + " at " + cplace c)) "")]))
   (cstmt c) (rand 16 @ k
     (? (k < 4) (pick catoms @ a (clab c 0.3 0 + a))     ; the body first: a label never names its own line
        (k < 10) (cbond c @ b (clab c 0.2 1 + b))
        (k < 13) (cring c @ r (clab c 0.3 0 + r))
        (k = 13) (pick [("size " + show (8 + rand 5)) ("size = " + show (8 + rand 5)) "textht 0.2"
                        "textht = 0.14" "cwid = .1" "db 0.3" "db = .25"])
        (k = 14) (pick ["# comment" "   # indented"])
        (pick ["pic box wid 0.1" "pic   circle rad 0.05"])))
   (cblock c) (: body (times (1 + rand 8) (_ \ cstmt c))
                 (chance 0.75 ? ([".cstart"] + body + [".cend"])
                    ([".PS" "box wid 0.2 ht 0.2" "begin chem"] + body + ["end" "move right 0.1" ".PE"])))
   (chem _) (: c {'labs () 'bonds ()}
               (catmap (_ \ (chance 0.3 ? [(pick ["a paragraph line" "text" ".sp" "'sp" ".ft B"])] ()) + cblock c)
                       ^(1 + rand 3)))

   langs {"grap" [grap ".g"] "gpic" [gpic ".pic"] "chem" [chem ".chem"]}
   (main a) (: g (langs (a 1)) dir (a 4)
               (? (g = ()) (say err ("fzgen: no language " + a 1 + nl))
                  (a 2 = "known")
                   (each (filter (k \ <k = a 1) fz-known) (k \ say out (k 1 + ": " + k 2 + (fz-steer ? "" " (not steered)") + nl)))
                  (: seed (read (a 2)) n (read (a 3))
                   (each ^n (i \ (: _ (rng-set (wheel (seed * 1000003 + i)))
                                   f (open (dir + "/fz-" + show seed + "-" + show i + g 1) "w")
                                   (say f (join nl (g 0 0) + nl), close f)))))))
   (main [(argv 0) (argv 1) (argv 2) (argv 3) (argv 4)]))
