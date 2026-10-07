; src/tools/mkstars.l -- lore's star catalogue from the Yale Bright Star Catalogue (5th
; revised ed., Hoffleit & Warren 1991; CDS V/50, its catalog file unzipped): every star to
; magnitude 4.5 with a J2000 place, brightest first, as src/apps/lore/starmap.l.
;   love src/tools/mkstars.l CATALOG OUT.l
; each star is four integers: right ascension and declination in hundredths of a degree,
; V and B-V in hundredths of a magnitude (B-V 60, about the sun's, where the catalogue has none)
(borrow 'posix)
(: lim 450
   ; a fixed-width field, bytes i to j of the line, read as a number, or () where it is blank
   (field l i j) (: s (snip l i j) (0 = net (map (k \ s k != 32) ^#s) ? () (read s)))
   (hund x) (int (floor (x * 100.0 + 0.5)))
   (star l) (: rh (field l 75 77) rm (field l 77 79) rs (field l 79 83)
               dd (field l 84 86) dm (field l 86 88) ds (field l 88 90)
               v (field l 102 107) bv (field l 109 114)
               (? (rh = () || dd = () || v = () || lim < hund v) ()
                  (: sg (snip l 83 84 = "-" ? -1.0 1.0)
                     [(hund (15.0 * (rh + rm / 60.0 + rs / 3600.0)))
                      (hund (sg * (dd + dm / 60.0 + ds / 3600.0)))
                      (hund v) (bv = () ? 60 (hund bv))])))
   (rows l) (? (atom? l) () (catmap (s \ " " + catmap (n \ " " + show n) s) (take 8 l) . rows (drop 8 l)))
   (main args) (: src (: q (open (args 0) "r") s (slurp q) (close q, s))
                  ss (map (p \ p 1) (sort (map (s \ [(s 2) s]) (filter two? (map star (lines src))))))
                  body ("; src/apps/lore/starmap.l -- written by src/tools/mkstars.l from the Yale Bright Star\n"
                        + "; Catalogue (5th revised ed., Hoffleit & Warren 1991; CDS V/50): its " + show #ss + " stars to\n"
                        + "; magnitude 4.5, brightest first. each is four integers: right ascension and declination\n"
                        + "; J2000 in hundredths of a degree, V and B-V in hundredths of a magnitude. not edited by hand\n"
                        + "(module (starmap star-cat)\n(: star-cat [\n"
                        + catmap (r \ r + "\n") (rows ss) + " ])\n) ; module starmap\n")
                  q (open (args 1) "w")
                  (hot? q ? (say q body, close q)
                     (say err ("mkstars: cannot open " + args 1 + "\n"), quit 1)))
   (main >argv))
