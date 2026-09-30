; src/apps/kore/chem.l -- chem, bentley, jelinski and kernighan's language for chemical
; structure diagrams: a troff preprocessor whose diagrams, each between .cstart and .cend (or
; begin chem and end inside a picture), become classic pic over groff's chem.pic macros, for
; pic (src/apps/kore/gpic.l) to draw. held to groff's chem byte for byte (test/gate/chem.sh),
; learned by asking it, never by reading it.
;
;   chem [FILE..]
;
; a line is one thing, or several split at a lone semicolon: a bond, a ring, a moiety, a
; quoted string, a setting, or pic, which goes through. each is placed against the last
; thing drawn, in the direction the last bond took.
(module 'kore
(borrow 'posix)

(:
   ; -- tables (at the head: a value binding sees only those above it) ------------------
   ; degrees, 0 up and clockwise, as chem's bonds take them
   ch-dirs {"up" 0 "down" 180 "left" 270 "right" 90 "ne" 45 "nw" 315 "se" 135 "sw" 225}
   ch-compass ["n" "ne" "e" "se" "s" "sw" "w" "nw"]
   ch-bond-kinds {"double" "doublebond" "triple" "triplebond" "front" "frontbond" "back" "backbond"}
   ch-settings ["textht" "cwid" "db" "size"]
   ; chem turns degrees to radians by this, not by pi
   ch-deg 57.29578
   ch-pi 3.141592653589793
   ch-prelude (cats ["\ttextht = 0.16; textwid = .1; cwid = 0.12\n"
                     "\tlineht = 0.2; linewid = 0.2\n"])

   ; -- numbers -----------------------------------------------------------------------
   (ch-fl x) (x * 1.0)
   (ch-g x) (? (x = 0 && 1 / ch-fl x < 0) "-0" (aw-gen (ch-fl x) 6))
   (ch-norm a) (: m (a % 360) (? (m < 0) (m + 360) m))
   ; the eighth of the compass an angle points nearest, 0 north
   (ch-oct a) (((2 * ch-norm a + 45) // 90) % 8)
   (ch-cmp a) (ch-compass (ch-oct a))
   ; an atom's corner a bond at a leaves from: its centre's straight up or down, else the
   ; right end's or the left's, at the compass point nearest
   (ch-acorner a) (: m (ch-norm a) ((? (m = 0 || m = 180) "C" (m < 180) "R" "L") + "." + ch-cmp m))
   ; a numeral's leading part as chem reads one: an integer from its digits
   (ch-num? w) (: n #w (dig i) (? (i < n && 48 <= w i <= 57) (dig (i + 1)) i)
                  a (? (0 < n && (w 0 = 45 || w 0 = 43)) 1 0) b (dig a)
                  c (? (b < n && w b = 46) (dig (b + 1)) b)
                  (0 < n && a < c && (b > a || c > b + 1) && c = n))
   (ch-int w) (int (gem w))

   ; -- moieties ----------------------------------------------------------------------
   (ch-upper? c) (65 <= c <= 90)
   (ch-chars w) (map (i \ w i) ^#w)
   (ch-blank? c) (c = 32 || c = 9)
   (ch-starts? l w) (#w <= #l && snip l 0 #w = w)
   (ch-macro? l w) (ch-starts? l w && (#l = #w || ch-blank? (l #w)))
   ; words split on blanks
   (ch-words s)
    (: n #s
       (go i acc) (? (n <= i) (rev acc)
                     (ch-blank? (s i)) (go (i + 1) acc)
                     (: (e j) (? (j < n && !(ch-blank? (s j))) (e (j + 1)) j)
                        j (e i) (go j (snip s i j . acc))))
       (go 0 ()))
   (ch-dig? c) (48 <= c <= 57)
   ; a moiety's name: its letters and figures
   (ch-name w) (cats (map (c \ string c) (filter (c \ (ch-upper? c || (97 <= c <= 122) || ch-dig? c)) (ch-chars w))))
   ; its text for troff: figures lowered and shrunk, one point between figures kept among
   ; them, a point before one raised
   (ch-text w)
    (: n #w o (jug 0)
       (digs i) (? (i < n && ch-dig? (w i)) (digs (i + 1)) i)
       (go i) (? (n <= i) (slurp o)
                 (ch-dig? (w i))
                  (: j (digs i) k (? (j + 1 < n && w j = 46 && ch-dig? (w (j + 1))) (digs (j + 1)) j)
                     _ (say o ("\\s-3\\d" + snip w i k + "\\u\\s+3"))
                     (go k))
                 (w i = 46 && i + 1 < n && ch-dig? (w (i + 1)))
                  (: _ (say o "\\v#-.3m#.\\v#.3m#") (go (i + 1)))
                 (: _ (put o (w i)) (go (i + 1))))
       (go 0))
   ; its width: a capital a character's, anything else half
   (ch-wid s w) (foldl (\ a c (a + (? (ch-upper? c) (s 'cwid) (s 'cwid / 2)))) 0.0 (ch-chars w))
   ; where a bond meets it along the text: the first C's middle, or its left edge when
   ; anything but capitals follows it; the first character's middle without one
   (ch-cx s w)
    (: i (: (go k) (? (#w <= k) -1 (w k = 67) k (go (k + 1))) (go 0))
       rest (? (i < 0) "" (snip w (i + 1) #w))
       caps (: (all k) (? (#rest <= k) 1 (ch-upper? (rest k)) (all (k + 1)) 0) (all 0))
       (? (i < 1) (s 'cwid / 2)
          (ch-wid s (snip w 0 i) + (? caps (s 'cwid / 2) 0.0))))
   ; atom("text", width, height, where bonds meet, and the size's own height, width, gap)
   (ch-atom s w)
    ("atom(\"" + ch-text w + "\", " + ch-g (ch-wid s w) + ", " + ch-g (s 'textht) + ", " + ch-g (ch-cx s w)
     + ", " + ch-g (s 'ht0) + ", " + ch-g (s 'cw0) + ", " + ch-g (s 'gap0) + ")")

   ; -- places ---------------------------------------------------------------------------
   ; the vertex of a ring a way points to: its sides' sectors counted from its first
   (ch-vertex r a) (: m (ch-norm (a - r 'off)) ((m * r 'n) // 360 + 1))
   ; the place on the last thing a bond or a neighbour meets it at, going a
   (ch-ref s a)
    (: k (s 'last) r (s 'ring)
       (k @ 'bond "Last.end"
            'atom ("Last." + ch-acorner a)
            'ring ("Last.V" + show (ch-vertex r a) + "." + ch-cmp a)
            ("Last." + ch-cmp a)))
   ; a bond's from: a moiety's corner, a bond's end, a ring's vertex, a named place's side
   (ch-from s x a)
    (: k (peep (s 'names) x ())
       dot (: (go i) (? (i < 0) -1 (x i = 46) i (go (i - 1))) (go (#x - 1)))
       (? (k = 'atom) (x + "." + ch-acorner a)
          (k = 'bond) (x + ".end")
          (tablet? k) (x + ".V" + show (ch-vertex k a) + "." + ch-cmp a)
          (0 <= dot && dot + 1 < #x && ch-upper? (x (dot + 1))) (x + "." + ch-cmp a)
          (x + " ")))

   ; -- statements -----------------------------------------------------------------------
   (ch-o s t) (say (s 'o) t)
   (ch-ol s t) (ch-o s (t + "\n"))
   (ch-join ws) (? (atom? ws) "" (foldl (\ a w (a + " " + w)) <ws >ws))
   ; [double|triple|front|back] bond [angle|dir] [length n] [from X | to X.. | pic..]
   (ch-bond s pre ws)
    (: kind (? (<ws = "bond") "bond" (ch-bond-kinds <ws))
       rest (? (<ws = "bond") >ws >>ws)
       (go l a len third)
        (? (atom? l) [a len third]
           (ch-num? <l) (go >l (ch-norm (ch-int <l)) len third)
           (peep ch-dirs <l () != ()) (go >l (ch-dirs <l) len third)
           (<l = "length" && two? >l) (go >>l a (gem <>l) third)
           (<l = "from" && two? >l) [a len ['from <>l]]
           (<l = "to" && two? >l) [a 0 ['to (ch-join >l)]]
           [a len ['pic (ch-join l)]])
       r (go rest (s 'dir) (s 'db) ())
       a <r len (r 1) th (r 2)
       third (? (th = ()) ("from " + ch-ref s a + " ")
                (<th = 'from) ("from " + ch-from s (th 1) a)
                (<th = 'to) ("to " + th 1 + " ")
                (th 1 + " "))
       _ (ch-ol s (pre + "Last: " + kind + "(" + ch-g len + ", " + show a + ", " + third + ")"))
       (pins s 'last 'bond 'dir a))
   ; a moiety, placed against the last thing, or where its pic says
   (ch-moiety s pre ws)
    (: w <ws nm (ch-name w) a (s 'dir)
       where (? (two? >ws) (" " + ch-join >ws)
                (" with ." + ch-acorner (a + 180) + " at " + ch-ref s a))
       _ (ch-ol s (pre + "Last: " + nm + ": " + ch-atom s w + where))
       _ (pin (s 'names) nm 'atom)
       (pin s 'last 'atom))
   (ch-bp s pre)
    (: a (s 'dir)
       _ (ch-ol s (pre + "Last: BP: \"\" ht 0 wid 0 with ." + ch-cmp (a + 180) + " at " + ch-ref s a))
       (pin s 'last 'other))
   ; a ring: [aromatic] ring|ringN|benzene|flatring [pointing D] [aromatic] [put M at N]..
   ; [double I,J ..] [pic..]
   (ch-ring s pre ws line)
    (: aro0 (<ws = "aromatic")
       ws1 (? aro0 >ws ws)
       kw <ws1
       n0 (ch-ring-sides kw)
       flat (kw = "flatring")
       (go l r)
        (? (atom? l) r
           (<l = "pointing" && two? >l) (go >>l (pin r 'off (peep ch-dirs <>l 0)))
           (<l = "aromatic") (go >l (pin r 'aro 1))
           (<l = "put" && two? >l && two? >>l && >>l 0 = "at" && two? >>>l)
            (go >>>>l (pin r 'puts ([(ch-int (>>>l 0)) <>l] . r 'puts)))
           (<l = "double")
            (: (pairs m acc) (? (two? m && 0 <= wg-find <m "," 0) (pairs >m (<m . acc)) [m (rev acc)])
               pr (pairs >l ())
               (go <pr (pin r 'dbl (r 'dbl + pr 1))))
           (pin r 'extra (cats (map (w \ " " + w) l))))
       r (go >ws1 {'n (? flat 5 n0) 'n6 n0 'off 0 'aro (aro0 || kw = "benzene") 'puts () 'dbl () 'extra "" 'flat flat})
       _ (ch-ring-body s pre r line)
       (pins s 'last 'ring 'ring r))
   (ch-ring-body s pre r line)
    (: n6 (r 'n6) n (r 'n) off (r 'off) side (0.3 * s 'scale)
       ; the size is pi's own; the angles below are chem's degrees
       rad (side / (2 * sin (ch-pi / n6)))
       step (360.0 / n6)
       (vx k) (: t ((off + (k - 1) * step) / ch-deg) ("(" + ch-g (rad * sin t) + "," + ch-g (rad * cos t) + ")"))
       _ (ch-ol s (pre + "Last: [\n\tC: 0,0"))
       _ (map (k \ ch-ol s ("\tV" + show k + ": " + vx k)) ^(n6 + 2))
       _ (? (r 'flat) (ch-ol s "\tV4: V5; V5: V6") 0)
       puts (r 'puts) anyput (two? puts)
       (put-at k) (: p (filter (p \ <p = k) puts) (? (two? p) (<p 1) ()))
       half (s 'ht0 / 2)
       (chop k f) (? (put-at k != ()) (ch-g (half * f)) "0")
       (chops i j f) (? anyput (" chop " + chop i f + " chop " + chop j f) "")
       ; a pair said either way round is the side from its first vertex
       dbl (map (p \ (: ws (usplit 44 p) a (ch-int <ws) b (ch-int <>ws)
                        (? ((a % n) + 1 = b) [a b] [b a])))
                (r 'dbl))
       _ (map (i \ (: j (i % n + 1)
                      k (i + 1)
                      m (put-at k)
                      _ (? (m = ()) 0
                           (ch-ol s ("\tV" + show k + ": ellipse invis ht " + ch-g (s 'ht0) + " wid " + ch-g (s 'cw0)
                                     + " at V" + show k + "\n\t" + ch-name m + ":" + ch-atom s m + " at V" + show k)))
                      k2 (k % n + 1)
                      _ (ch-ol s ("\tline from V" + show k + " to V" + show k2 + chops k k2 1))
                      ; the flat ring's cut side is set in further, and chopped less
                      (cut d) (r 'flat && <d = 3)
                      (map (d \ (: f (? (cut d) "0.75" "0.85")
                                   (ch-ol s ("\tline from " + f + "<C,V" + show <d + "> to " + f + "<C,V" + show (d 1) + ">"
                                             + chops <d (d 1) (? (cut d) 0.2 (2 / 3.0))))))
                           (filter (d \ <d = k) dbl))))
              ^n)
       _ (? (r 'aro) (ch-ol s ("\tcircle rad " + ch-g (? (r 'flat) (0.4 * side) (rad / 2)) + " at 0,0")) 0)
       a (s 'dir)
       place (? (elem "with" (ch-words (r 'extra))) ""
                ("with .V" + show (ch-vertex r (a + 180)) + "." + ch-cmp (a + 180) + " at " + ch-ref s a))
       (ch-ol s ("] " + place + " " + r 'extra)))

   ; a line of a diagram
   (ch-line s l)
    (: ws (ch-words l)
       w0 (? (two? ws) <ws "")
       (? (atom? ws) 0
          (w0 0 = 35) 0
          (w0 = "pic") (: i (wg-find l "pic" 0)
                          _ (ch-ol s (ch-trim (snip l (i + 3) #l)))
                          (pin s 'last 'other))
          (elem w0 ch-settings) (ch-set s w0 (<(rev ws)))
          (: _ (ch-o s ("\n#" + l + "\n"))
             (ch-chunks s l ws))))
   ; settings: the last word is the value
   (ch-set s k v)
    (: x2 (ch-fl (gem v))
       (k @ "textht" (pin s 'textht x2)
            "cwid" (pin s 'cwid x2)
            "db" (pin s 'db x2)
            (ch-size s (x2 / 10))))
   (ch-size s k)
    (pins s 'scale k 'textht (0.16 * k) 'cwid (0.12 * k) 'db (0.2 * k) 'ht0 (0.16 * k) 'cw0 (0.12 * k) 'gap0 (0.015 * k))
   ; a line's things, split at a lone semicolon; a label on the first
   (ch-chunks s l ws)
    (: lab (? (two? ws && #<ws > 1 && <ws (#<ws - 1) = 58 && ch-upper? (<ws 0)) (snip <ws 0 (#<ws - 1)) ())
       ws1 (? (lab = ()) ws >ws)
       ; only a bond is split from what follows it, and that is one moiety's word, whatever
       ; it spells
       (split m) (: (go l acc) (? (atom? l) [m]
                                  (<l = ";") (? (two? acc && ch-bond? (rev acc) && two? >l) [(rev acc) [";" <>l]] [m])
                                  (go >l (<l . acc)))
                    (go m ()))
       cs (split ws1)
       (go l pre first) (? (atom? l) 0
                           (: _ (ch-thing s pre <l (? first l ()) lab)
                              (go >l "" 0)))
       (go cs (? (lab = ()) "" (lab + ": ")) 1))
   ; the rings: ring, benzene and flatring six-sided, ringN N-sided by its last figure, 1 to 8
   (ch-ring? w) (elem w ["benzene" "flatring"] || ch-starts? w "ring")
   (ch-ring-sides w) (: d (? (ch-starts? w "ring" && 4 < #w) (w (#w - 1) - 48) 6) (? (1 <= d <= 8) d 6))
   (ch-bond? ws) (: w <ws (w = "bond" || (peep ch-bond-kinds w () != () && two? >ws && <>ws = "bond")))
   (ch-thing s pre ws line lab)
    (: w <ws kind (? (w = ";") (? (<>ws = "BP") 'bp 'moiety) (ch-bond? ws) 'bond
                     (ch-ring? w || (w = "aromatic" && two? >ws && ch-ring? <>ws)) 'ring
                     (w = "BP") 'bp
                     (w 0 = 34) 'str
                     (ch-upper? (w 0)) 'atom
                     'pic)
       _ (? (kind = 'bond) (ch-bond s pre ws)
            (kind = 'ring) (ch-ring s pre ws line)
            (kind = 'bp) (ch-bp s pre)
            (kind = 'moiety) (ch-moiety s pre >ws)
            (kind = 'atom) (ch-moiety s pre ws)
            (kind = 'str) (: _ (ch-ol s (pre + "Last: " + ch-join ws)) (pin s 'last 'other))
            (: _ (ch-ol s (pre + ch-join ws)) (pin s 'last 'other)))
       ; a label names what the line drew
       (? (lab = ()) 0
          (pin (s 'names) lab (s 'last @ 'ring (s 'ring) 'atom 'atom 'bond 'bond 'other))))

   ; -- the document -------------------------------------------------------------------
   ; groff's chem.pic, which the diagrams lean on
   (ch-macros _)
    (: d "/usr/share/groff"
       vs (? (udirp d) (sort (filter (e \ 0 < #e && ch-dig? (e 0)) (readdir d))) ())
       hit (filter (v \ two? (stat (d + "/" + v + "/tmac/chem.pic"))) vs)
       (? (two? hit) (d + "/" + <hit + "/tmac/chem.pic") "chem.pic"))
   (ch-start s)
    (: _ (? (s 'begun) 0
            (: _ (pin s 'begun 1) (ch-o s ("copy \"" + ch-macros 0 + "\"\n" + ch-prelude))))
       _ (ch-ol s "Last: 0,0")
       (pins s 'last 'start 'dir 90))
   ; every line is read with its blanks trimmed off both ends; only a diagram's comment
   ; lines keep them
   (ch-doc s text)
    (: ls (lines text)
       (troff? t) (0 < #t && (t 0 = 46 || t 0 = 39))
       (go l mode)
        (? (atom? l) 0
           (: x <l t (ch-trim x) ws (ch-words t)
              (? (mode = 'chem)
                  (? (ch-starts? t ".cend") (: _ (ch-ol s ".PE") (go >l 'text))
                     (troff? t) (: _ (ch-ol s t) (go >l mode))
                     (: _ (ch-line s x) (go >l mode)))
                 (mode = 'begin)
                  (? (ws = ["end"]) (go >l 'pic)
                     (troff? t) (: _ (ch-ol s t) (go >l mode))
                     (: _ (ch-line s x) (go >l mode)))
                 (t = ".cstart") (: _ (ch-ol s ".PS") _ (ch-start s) (go >l 'chem))
                 (mode = 'pic)
                  (? (ws = ["begin" "chem"]) (: _ (ch-start s) (go >l 'begin))
                     (: _ (ch-ol s t) (go >l (? (ch-macro? t ".PE") 'text 'pic))))
                 (: _ (ch-ol s t) (go >l (? (ch-macro? t ".PS") 'pic 'text))))))
       (go ls 'text))
   (ch-trim t)
    (: (a i) (? (i < #t && ch-blank? (t i)) (a (i + 1)) i)
       (b j) (? (0 < j && ch-blank? (t (j - 1))) (b (j - 1)) j)
       i (a 0) j (b #t)
       (? (i < j) (snip t i j) ""))

   (chem-main as) (chem-run as ())
   (chem-run as sin) (ch-run as sin @ [st t] (say out t, flush out, st) 0)
   ; a run -> [status output]
   (ch-run as sin)
    (: s {'o (jug 0) 'names (tablet 0) 'begun 0 'last 'start 'dir 90 'ring ()}
       _ (ch-size s 1.0)
       fs (filter (a \ !(ch-starts? a "-") || a = "-") as)
       (go l) (? (atom? l) 0
                 (: f <l
                    t (? (f = "-") (? (string? sin) sin (slurp in)) (: r (uread f) (? (two? r) <>r ())))
                    (? (string? t) (: _ (ch-doc s t) (go >l))
                       (: _ (say err ("chem: can't open " + f + "\n")) (pin s 'status 1)))))
       _ (go (? (two? fs) fs ["-"]))
       [(peep s 'status 0) (slurp (s 'o))])
)
) ; module 'kore
