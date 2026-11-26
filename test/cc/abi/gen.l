; test/cc/abi/gen.l -- calls between two compilers, drawn from a seed: a caller and a callee.
;   love gen.l EXPECT SEED N DIR   EXPECT names the kinds mooncc refuses or lays otherwise
; every kind is swept through each place first, so coverage does not rest on the seed.
; DIR/GROUP-caller.c GROUP-callee.c, layout.c, report.c (the names) and kinds
(borrow 'posix)
(: nl (string 10)
   (times n f) (0 < n ? ((f 0) . (times (n - 1) f)) ())
   (glue l) (join "" l)
   (map2 f a b) (two? a && two? b ? (f <a <b . map2 f >a >b) ())
   (pick l) (l (rand #l))
   (slurpf p) (open p "r" @ q (hot? q ? (slurp q @ t (close q, t)) ""))
   (write p t) (string? t && 0 < #t ? (open p "w" @ q (say q t, close q)) (say out ("abi: no text for " + p + nl), quit 1))
   (lines s) (filter (l \ 0 < #l) (split nl s))

   ; a kind: name, C type, psABI classes (I an integer eightbyte, S an sse, M memory, "" none),
   ; its leaves as (path type), and the declaration. a leaf's type spells its check
   (k nm ty cls lv decl) {'nm nm 'ty ty 'cls cls 'lv lv 'decl decl}
   (sc nm ty cls t) (k nm ty cls [["" t]] "")
   (st nm cls lv body) (k nm ("struct " + nm) cls lv ("struct " + nm + " " + body + ";"))
   (un nm cls lv body) (k nm ("union " + nm) cls lv ("union " + nm + " " + body + ";"))
   (arr a n t) (map (i \ [(a + "[" + show i + "]") t]) ^n)
   (fs names t) (map (a \ [("." + a) t]) names)
   kinds [(sc "bool" "_Bool" "I" "b") (sc "char" "char" "I" "c") (sc "schar" "signed char" "I" "c")
          (sc "uchar" "unsigned char" "I" "uc") (sc "short" "short" "I" "s") (sc "ushort" "unsigned short" "I" "us")
          (sc "int" "int" "I" "i") (sc "uint" "unsigned" "I" "ui") (sc "long" "long" "I" "l")
          (sc "ulong" "unsigned long" "I" "ul") (sc "llong" "long long" "I" "l")
          (k "enum" "enum e" "I" [["" "e"]] "enum e { e0, e1 = 0x7fffffff };")
          (k "enumneg" "enum en" "I" [["" "i"]] "enum en { en0 = -1, en1 = 5 };")
          (sc "ptr" "char *" "I" "p") (sc "float" "float" "S" "f") (sc "double" "double" "S" "d")
          (sc "ldouble" "long double" "M" "E")
          (k "cfloat" "float _Complex" "S" [["" "cf"]] "") (k "cdouble" "double _Complex" "SS" [["" "cd"]] "")
          (sc "i128" "__int128" "II" "w")
          (st "s1" "I" (fs ["a"] "c") "{ signed char a; }") (st "s2" "I" (fs ["a"] "s") "{ short a; }")
          (st "s3" "I" (arr ".a" 3 "c") "{ signed char a[3]; }") (st "s5" "I" (arr ".a" 5 "uc") "{ unsigned char a[5]; }")
          (st "s4i" "I" (fs ["a"] "i") "{ int a; }") (st "s8" "I" (fs ["a" "b"] "i") "{ int a, b; }")
          (st "s9" "II" (arr ".a" 9 "c") "{ signed char a[9]; }") (st "s12" "II" (fs ["a" "b" "c"] "i") "{ int a, b, c; }")
          (st "s15" "II" (arr ".a" 15 "uc") "{ unsigned char a[15]; }")
          (st "s16" "II" (fs ["a" "b"] "l") "{ long a, b; }") (st "s17" "M" (arr ".a" 17 "c") "{ signed char a[17]; }")
          (st "s24" "M" (fs ["a" "b" "c"] "l") "{ long a, b, c; }") (st "s40" "M" (arr ".a" 10 "i") "{ int a[10]; }")
          (st "f1" "S" (fs ["a"] "f") "{ float a; }") (st "f2" "S" (fs ["a" "b"] "f") "{ float a, b; }")
          (st "f3" "SS" (fs ["a" "b" "c"] "f") "{ float a, b, c; }") (st "f4" "SS" (arr ".a" 4 "f") "{ float a[4]; }")
          (st "f5" "M" (arr ".a" 5 "f") "{ float a[5]; }") (st "d1" "S" (fs ["a"] "d") "{ double a; }")
          (st "d2" "SS" (fs ["a" "b"] "d") "{ double a, b; }") (st "d3" "M" (fs ["a" "b" "c"] "d") "{ double a, b, c; }")
          (st "di" "SI" [[".a" "d"] [".b" "i"]] "{ double a; int b; }") (st "ld" "IS" [[".a" "l"] [".b" "d"]] "{ long a; double b; }")
          (st "fi" "I" [[".a" "f"] [".b" "i"]] "{ float a; int b; }") (st "ifd" "IS" [[".a" "i"] [".b" "f"] [".c" "d"]] "{ int a; float b; double c; }")
          (st "ffi" "SI" [[".a" "f"] [".b" "f"] [".c" "i"]] "{ float a, b; int c; }")
          (st "nest" "II" (arr ".in.a" 3 "c" + [[".b" "s"] [".c" "l"]]) "{ struct { signed char a[3]; } in; short b; long c; }")
          (st "cfs" "SS" [[".z" "cf"] [".b" "f"]] "{ float _Complex z; float b; }")
          (st "w1" "II" (fs ["a"] "w") "{ __int128 a; }") (st "ea" "M" (fs ["a"] "E") "{ long double a; }")
          (st "pk9" "M" [[".a" "c"] [".b" "l"]] "{ signed char a; long b; } __attribute__((packed))")
          (st "pk3" "M" [[".a" "c"] [".b" "s"]] "{ signed char a; short b; } __attribute__((packed))")
          (st "pkm5" "M" [[".a" "c"] [".b" "i"]] "{ signed char a; int b __attribute__((packed)); }")
          (st "al16" "II" [[".a" "l"] [".b" "i"]] "{ long a; int b; } __attribute__((aligned(16)))")
          (st "al16m" "M" (fs ["a" "b" "c"] "l") "{ long a, b, c; } __attribute__((aligned(16)))")
          (st "bf1" "I" [[".a" "#5"] [".b" "#-3"] [".c" "#20"]] "{ unsigned a : 5; int b : 3; unsigned c : 20; }")
          (st "bf2" "II" [[".a" "#33"] [".b" "#31"] [".c" "c"]] "{ unsigned long a : 33, b : 31; signed char c; }")
          (st "bf3" "II" [[".a" "l"] [".b" "#7"]] "{ long a; unsigned b : 7; }")
          (un "uif" "I" [[".a" "i"]] "{ int a; float b; }") (un "udl" "I" [[".a" "d"]] "{ double a; long b; }")
          (un "ufd" "S" [[".a" "d"]] "{ double a; float b; }") (un "u12" "II" (arr ".a" 3 "i") "{ int a[3]; float b; }")
          (st "empty" "" [] "{ }") (st "flex" "I" [[".a" "i"]] "{ int a; char b[]; }")
          (st "flexl" "II" [[".a" "l"] [".b" "i"]] "{ long a; int b; char c[]; }")]
   byname {}
   _ (each kinds (x \ pin byname (x 'nm) x))


   ; a leaf drawn: the words it holds as C text, signs and high halves set, no nan
   (digit s) (string (s (rand #s)))
   (hex n) (glue (times n (_ \ digit "0123456789abcdef")))
   cty {"c" "signed char" "uc" "unsigned char" "s" "short" "us" "unsigned short" "i" "int" "ui" "unsigned"
        "l" "long" "ul" "unsigned long"}
   wid {"c" 2 "uc" 2 "s" 4 "us" 4 "i" 8 "ui" 8 "l" 16 "ul" 16}
   (fb _) ("0x" + digit "4c" + digit "1234" + hex 6 + "ul")
   (db _) ("0x" + digit "4c" + digit "01" + digit "159" + hex 13 + "ul")
   (word _) ("0x" + hex 16 + "ul")
   (bitw t) (read (snip t (t 1 = 45 ? 2 1) #t))
   (draw t)
    (? (t = "b") [("(_Bool)" + digit "01")] (t = "p") [("(char *)" + word 0)] (t = "e") ["e1"]
       (t = "f") [(fb 0)] (t = "d" || t = "E") [(db 0)] (t = "cf") [(fb 0) (fb 0)] (t = "cd") [(db 0) (db 0)]
       (t = "w") [(word 0) (word 0)]
       (t 0 = 35) (show (64 - bitw t) @ n [("(" + (t 1 = 45 ? "(long)" "") + "(" + word 0 + " << " + n + ") >> " + n + ")")])
       [("(" + cty t + ")0x" + hex (wid t))])
   ; a leaf's words: each got laid in G, each float taken from V, both the linking side's tables
   (gots t x)
    (? (t = "f") [(".f=" + x)] (t = "d" || t = "E") [(".d=" + x)]
       (t = "cf") (map (i \ ".f=((float *)&" + x + ")[" + i + "]") ["0" "1"])
       (t = "cd") (map (i \ ".d=((double *)&" + x + ")[" + i + "]") ["0" "1"])
       (t = "w") [(".u=(ul)(" + x + " >> 64)") (".u=(ul)" + x)]
       [(".u=(ul)" + x)])
   (sets t x v n)
    (: (f i) ("V[" + show (n + i) + "]")
     (? (t = "f") (x + "=" + f 0 + ".f;") (t = "d" || t = "E") (x + "=" + f 0 + ".d;")
       (t = "cf") ("((float *)&" + x + ")[0]=" + f 0 + ".f;((float *)&" + x + ")[1]=" + f 1 + ".f;")
       (t = "cd") ("((double *)&" + x + ")[0]=" + f 0 + ".d;((double *)&" + x + ")[1]=" + f 1 + ".d;")
       (t = "w") (x + "=(__int128)(((unsigned __int128)" + <v + " << 64) | " + <>v + ");")
       ; half the integers come from a word with other bits above theirs, for the caller to narrow
       (n % 2 = 1 && 0 < peep wid t 0) (x + "=(" + cty t + ")W[" + show n + "].u;")
       (x + "=" + <v + ";")))
   (vals kd) (map (l \ draw (l 1)) (kd 'lv))
   (words vs) (net (map tally vs))
   ; n the value's first word in V
   (setk kd x vs n) (: (go l v n) (two? l ? (sets (<l 1) (x + <l 0) <v n + go >l >v (n + #(<v))) "") (go (kd 'lv) vs n))
   ; lay a value's words in G from g on
   (chkk kd x g) (: ws (catmap (l \ gots (l 1) (x + l 0)) (kd 'lv))
                    (glue (map2 (i \ w \ "G[" + show (g + i) + "]" + w + ";") ^(#ws) ws)))
   ; the first word of each value in a list
   (offs vs) (: (go l n) (two? l ? (n . go >l (n + words <l)) ()) (go vs 0))
   (zapk kd x) (glue (map (l \ (elem (l 1) ["cf" "cd"]) ? "" (x + l 0 + "=0;")) (kd 'lv)))

   ; where the psABI puts each: reg, last (its file's last register), spill (too few left,
   ; one still free), stack. a name for the report and the coverage floor, nothing is laid by it
   (count c s) (tally (filter (x \ x = c) (bytes s)))
   (bytes s) (map (i \ s i) ^(#s))
   (placed ks) (: (go l ni ns) (? (nil? l) ()
                     (: cl (<l 'cls) i (count 73 cl) f (count 83 cl)
                        (? (cl = "") ("none" . go >l ni ns)
                           (cl = "M" || (i = 0 || ni = 6) && (f = 0 || ns = 8)) ("stack" . go >l ni ns)
                           (6 < ni + i || 8 < ns + f) ("spill" . go >l ni ns)
                           (((0 < i && ni + i = 6) || (0 < f && ns + f = 8) ? "last" "reg") . go >l (ni + i) (ns + f)))))
                  (go ks 0 0))

   ; one signature: rt and ks kinds, nn named (the rest after `...`)
   names {} seen {}
   (decl s) (: nn (s 'nn) ks (s 'ks)
               (s 'rt 'ty + " f" + show (s 'q) + "("
                + (nn < 1 ? "void" (join ", " (map (j \ ks j 'ty + " p" + show j) ^nn))) + (nn < #ks ? ", ..." "") + ")"))
   nv {}
   (mksig q rt ks nn) (: vs (map vals ks) rv (vals rt) n (peep nv 0 0) na (net (map words vs))
                         _ (pin nv 0 (n + na + words rv))
                         {'q q 'rt rt 'ks ks 'nn nn 'vs vs 'rv rv 'at n 'na na 'off (offs vs)})
   (callee s) (: q (s 'q) ks (s 'ks) nn (s 'nn) na (s 'na)
     (decl s + "{"
      + (nn < #ks ? ("__builtin_va_list ap;__builtin_va_start(ap,p" + show (nn - 1) + ");"
                     + glue (map (j \ ks (nn + j) 'ty + " p" + show (nn + j) + "=__builtin_va_arg(ap," + ks (nn + j) 'ty + ");") ^(#ks - nn))
                     + "__builtin_va_end(ap);") "")
      + glue (map (j \ chkk (ks j) ("p" + show j) (s 'off j)) ^(#ks))
      + glue (map (j \ zapk (ks j) ("p" + show j)) ^(#ks))
      + "ck(" + show q + ",0," + show na + ");"
      + s 'rt 'ty + " r;" + setk (s 'rt) "r" (s 'rv) (s 'at + na) + "return r;}" + nl))
   ; odd signatures leak their arguments' addresses and look at them again after the call
   (caller s) (: q (s 'q) ks (s 'ks) a (j \ "a" + show j) odd (q % 2 = 1) na (s 'na)
     ("static void t" + show q + "(void){"
      + glue (map (j \ ks j 'ty + " " + a j + ";" + setk (ks j) (a j) (s 'vs j) (s 'at + s 'off j)) ^(#ks))
      + (odd ? (glue (map (j \ "keep(&" + a j + ");") ^(#ks))) "")
      + s 'rt 'ty + " r=f" + show q + "(" + join "," (map a ^(#ks)) + ");"
      + (odd ? (glue (map (j \ chkk (ks j) (a j) (s 'off j)) ^(#ks))) "")
      + chkk (s 'rt) "r" na
      + "ck(" + show q + "," + (odd ? "1" "2") + "," + show (na + words (s 'rv)) + ");}" + nl))
   ; the values the tables hold, and each word's (argument word)
   (allv s) (catmap (catmap id) (s 'vs) + catmap id (s 'rv))
   ; a word of V with other bits above its type's
   (widen t v) (: n (4 * peep wid t 16)
                (n = 64 ? ("{(ul)(" + v + ")}")
                 ("{((ul)(" + v + ") & 0x" + glue (times (n // 4) (_ \ "f")) + "ul) | 0x5a5a5a5a5a5a5a5aul << " + show n + "}")))
   (leaft s) (catmap (x \ catmap (l \ elem (l 1) ["cf" "cd" "w"] ? [(l 1) (l 1)] [(l 1)]) (x 'lv)) (s 'ks + [(s 'rt)]))
   (where s) (: (go l j) (two? l ? ((: ws (catmap id <l) (map (i \ show j + "," + show i) ^(#ws))) + go >l (j + 1)) ())
                 (go (s 'vs) 0 + (: ws (catmap id (s 'rv)) (map (i \ "99," + show i) ^(#ws)))))

   prelude ("typedef unsigned long ul;" + nl
     + "typedef union { ul u; float f; double d; } cell;" + nl
     + "extern cell G[]; extern const cell V[], W[]; extern void ck(int, int, int), keep(void *);" + nl
     + glue (map (x \ x 'decl = "" ? "" (x 'decl + nl)) kinds))
   (group dir nm ss)
    (: ds (glue (map (s \ decl s + ";" + nl) ss))
       _ (write (dir + "/" + nm + "-callee.c") (prelude + ds + glue (map callee ss)))
       (write (dir + "/" + nm + "-caller.c")
        (prelude + ds + glue (map caller ss)
         + "void run_" + nm + "(void){" + glue (map (s \ "t" + show (s 'q) + "();") ss) + "}" + nl)))

   ; sizeof, alignof and each member's place, as numbers to compare
   (member? p) (0 < #p && !(elem 91 (bytes p)))
   (lays kd) ([["sizeof" ("sizeof(" + kd 'ty + ")")] ["align" ("_Alignof(" + kd 'ty + ")")]]
              + map (l \ [(l 0) ("(long)&((" + kd 'ty + " *)0)->" + snip (l 0) 1 #(l 0))]) (filter (l \ member? (l 0) && !(l 1 0 = 35)) (kd 'lv)))
   (main a)
    (: ex (map (l \ split " " l) (filter (l \ !(l 0 = 35)) (lines (slurpf (a 1)))))
       (exp w) (map (l \ l 1) (filter (l \ <l = w) ex))
       refuse (exp "varefuse") differ (catmap exp ["pass" "wrong" "split"])
       seed (read (a 2)) n (read (a 3)) dir (a 4)
       _ (rng-set (wheel seed))
       b byname
       qn {} sigs {}
       (q! _) (: v (peep qn 0 0) (pin qn 0 (v + 1), v))
       (sig rt ks nn) (: s (mksig (q! 0) rt ks nn)
                          _ (pin sigs (s 'q) s)
                          _ (pin names (s 'q) (decl s + (nn < #ks ? ("  then " + join ", " (map (j \ ks (nn + j) 'nm) ^(#ks - nn))) ""))) s)
       lng (b "long") dbl (b "double") int (b "int") ch (b "schar")
       (reps m x) (times m (_ \ x))
       odd? (x \ elem (x 'nm) differ)
       plain (filter (x \ !(odd? x)) kinds)
       (fsig rt ks) (sig rt ks #ks)
       (sweep x) [(fsig x (reps 4 lng + [x lng lng x ch x]))
                  (fsig x (reps 7 dbl + [x dbl x ch x]))
                  (fsig x (reps 5 lng + reps 6 dbl + [x lng dbl ch x int x]))]
       narrow? (x \ elem (x 'nm) ["bool" "char" "schar" "uchar" "short" "ushort" "float"])
       (vsweep x) [(sig int ([int x] + reps 3 lng + [x dbl x] + reps 7 dbl + [x int x]) 1)]
       vok (filter (x \ !(narrow? x)) plain)
       oddv (filter (x \ odd? x && !(narrow? x)) kinds)
       refused? (x \ elem (x 'nm) refuse)
       _ (write (dir + "/refuse") (join nl (map (x \ x 'nm) (filter refused? vok + oddv)) + nl))
       _ (write (dir + "/odd") (join nl (map (x \ x 'nm) (filter odd? kinds)) + nl))
       (one _) (: ks (times (1 + rand 14) (_ \ pick plain)) (sig (pick plain) ks #ks))
       (vone _) (: nn (1 + rand 8) ks (times nn (_ \ pick plain) + times (1 + rand 8) (_ \ pick (filter (x \ !(refused? x)) vok)))
                   (sig (pick plain) ks nn))
       fix (catmap sweep plain + times (n * 3 // 4) one)
       va (catmap vsweep (filter (x \ !(refused? x)) vok) + times (n - n * 3 // 4) vone)
       _ (group dir "fix" fix) _ (group dir "va" va)
       _ (each (filter refused? vok + oddv) (x \ group dir ("vax_" + x 'nm) (vsweep x)))
       _ (each (filter odd? kinds) (x \ group dir ("odd_" + x 'nm) (sweep x)))
       ; the floor: each kind that has registers is seen at each place it can be
       _ (each (fix + va) (s \ map2 (x \ p \ pin seen (x 'nm + " " + p) 1) (s 'ks) (placed (s 'ks))))
       (want x) (x 'cls = "" ? ["none"] (x 'cls = "M") ["stack"] (#(x 'cls) = 1) ["reg" "last" "stack"] ["reg" "last" "spill" "stack"])
       short (catmap (x \ filter (w \ !(peep seen w 0)) (map (w \ x 'nm + " " + w) (want x))) plain)
       ls (catmap (x \ map (t \ [(x 'nm + (t 0 0 = 46 ? (t 0) ("." + t 0))) (t 1)]) (lays x)) kinds)
       _ (write (dir + "/layout.c") (prelude + "const ul lay[]={" + join "," (map (l \ "(ul)(" + l 1 + ")") ls) + "};" + nl))
       _ (write (dir + "/report.h")
          ("static const char *const sigs[]={" + join ("," + nl) (map (i \ "\"" + names i + "\"") ^(peep qn 0 0)) + "};" + nl
           + "static const char *const lays[]={" + join ("," + nl) (map (l \ "\"" + l 0 + "\"") ls) + "};" + nl
           + "#define e1 0x7fffffff" + nl
           + "cell G[256]; const cell V[]={" + join ("," + nl) (map (i \ join "," (map (v \ "{(ul)(" + v + ")}") (allv (sigs i)))) ^(peep qn 0 0)) + "};" + nl
           + "const cell W[]={" + join ("," + nl) (map (i \ join "," (map2 widen (leaft (sigs i)) (allv (sigs i)))) ^(peep qn 0 0)) + "};" + nl
           + "static const struct { short at, n, na; } at[]={" + join "," (map (i \ "{" + show (sigs i 'at) + "," + show (#(allv (sigs i))) + "," + show (sigs i 'na) + "}") ^(peep qn 0 0)) + "};" + nl
           + "static const short wh[][2]={" + join ("," + nl) (map (i \ join "," (map (t \ "{" + t + "}") (where (sigs i)))) ^(peep qn 0 0)) + "};" + nl))
       _ (say out ("abi: seed " + show seed + ", " + show #kinds + " kinds, " + show #fix + " fixed and " + show #va
                   + " variadic signatures, " + show #ls + " layout words" + nl))
       (nil? short ? 0 (say out ("abi: never placed: " + join ", " short + nl), quit 1)))
   (main argv))
