; a/x11.l -- the X11 colour names, as rgb.txt spells them, to hex and to a pen.
;
;   (x11 "honeydew")        "#f0fff0", or () for a name that is not one
;   (x11-rgb "lavender")    (230 230 250)
;   (x11-fg "lavender")     "\e[38;2;230;230;250m" -- and x11-bg the background's
;   (x11-256 "lavender")    189: the cube cell quay lands that truecolour on (l/quay/quay.c)
;   (x11-names 0)           every name, sorted
;   love x11 NAME..         the verb: a line per name -- hex, rgb, the cube cell
;
; a name is matched lowercase with its spaces, hyphens and underscores dropped, so
; "Navy Blue" and navyblue are one. the four names where X11 and the web disagree
; carry X11's value -- gray bebebe, green 00ff00, maroon b03060, purple a020f0 -- and
; the web's are webgray, webgreen, webmaroon, webpurple, as rgb.txt has them.
(module 'x11
(borrow 'posix)
(:
 x11-rows
  '(("aliceblue" "f0f8ff") ("antiquewhite" "faebd7") ("aqua" "00ffff") ("aquamarine" "7fffd4")
    ("azure" "f0ffff") ("beige" "f5f5dc") ("bisque" "ffe4c4") ("black" "000000")
    ("blanchedalmond" "ffebcd") ("blue" "0000ff") ("blueviolet" "8a2be2") ("brown" "a52a2a")
    ("burlywood" "deb887") ("cadetblue" "5f9ea0") ("chartreuse" "7fff00") ("chocolate" "d2691e")
    ("coral" "ff7f50") ("cornflowerblue" "6495ed") ("cornsilk" "fff8dc") ("crimson" "dc143c")
    ("cyan" "00ffff") ("darkblue" "00008b") ("darkcyan" "008b8b") ("darkgoldenrod" "b8860b")
    ("darkgray" "a9a9a9") ("darkgreen" "006400") ("darkgrey" "a9a9a9") ("darkkhaki" "bdb76b")
    ("darkmagenta" "8b008b") ("darkolivegreen" "556b2f") ("darkorange" "ff8c00") ("darkorchid" "9932cc")
    ("darkred" "8b0000") ("darksalmon" "e9967a") ("darkseagreen" "8fbc8f") ("darkslateblue" "483d8b")
    ("darkslategray" "2f4f4f") ("darkslategrey" "2f4f4f") ("darkturquoise" "00ced1") ("darkviolet" "9400d3")
    ("deeppink" "ff1493") ("deepskyblue" "00bfff") ("dimgray" "696969") ("dimgrey" "696969")
    ("dodgerblue" "1e90ff") ("firebrick" "b22222") ("floralwhite" "fffaf0") ("forestgreen" "228b22")
    ("fuchsia" "ff00ff") ("gainsboro" "dcdcdc") ("ghostwhite" "f8f8ff") ("gold" "ffd700")
    ("goldenrod" "daa520") ("gray" "bebebe") ("green" "00ff00") ("greenyellow" "adff2f")
    ("grey" "bebebe") ("honeydew" "f0fff0") ("hotpink" "ff69b4") ("indianred" "cd5c5c")
    ("indigo" "4b0082") ("ivory" "fffff0") ("khaki" "f0e68c") ("lavender" "e6e6fa")
    ("lavenderblush" "fff0f5") ("lawngreen" "7cfc00") ("lemonchiffon" "fffacd") ("lightblue" "add8e6")
    ("lightcoral" "f08080") ("lightcyan" "e0ffff") ("lightgoldenrod" "eedd82") ("lightgoldenrodyellow" "fafad2")
    ("lightgray" "d3d3d3") ("lightgreen" "90ee90") ("lightgrey" "d3d3d3") ("lightpink" "ffb6c1")
    ("lightsalmon" "ffa07a") ("lightseagreen" "20b2aa") ("lightskyblue" "87cefa") ("lightslateblue" "8470ff")
    ("lightslategray" "778899") ("lightslategrey" "778899") ("lightsteelblue" "b0c4de") ("lightyellow" "ffffe0")
    ("lime" "00ff00") ("limegreen" "32cd32") ("linen" "faf0e6") ("magenta" "ff00ff")
    ("maroon" "b03060") ("mediumaquamarine" "66cdaa") ("mediumblue" "0000cd") ("mediumorchid" "ba55d3")
    ("mediumpurple" "9370db") ("mediumseagreen" "3cb371") ("mediumslateblue" "7b68ee") ("mediumspringgreen" "00fa9a")
    ("mediumturquoise" "48d1cc") ("mediumvioletred" "c71585") ("midnightblue" "191970") ("mintcream" "f5fffa")
    ("mistyrose" "ffe4e1") ("moccasin" "ffe4b5") ("navajowhite" "ffdead") ("navy" "000080")
    ("navyblue" "000080") ("oldlace" "fdf5e6") ("olive" "808000") ("olivedrab" "6b8e23")
    ("orange" "ffa500") ("orangered" "ff4500") ("orchid" "da70d6") ("palegoldenrod" "eee8aa")
    ("palegreen" "98fb98") ("paleturquoise" "afeeee") ("palevioletred" "db7093") ("papayawhip" "ffefd5")
    ("peachpuff" "ffdab9") ("peru" "cd853f") ("pink" "ffc0cb") ("plum" "dda0dd")
    ("powderblue" "b0e0e6") ("purple" "a020f0") ("rebeccapurple" "663399") ("red" "ff0000")
    ("rosybrown" "bc8f8f") ("royalblue" "4169e1") ("saddlebrown" "8b4513") ("salmon" "fa8072")
    ("sandybrown" "f4a460") ("seagreen" "2e8b57") ("seashell" "fff5ee") ("sienna" "a0522d")
    ("silver" "c0c0c0") ("skyblue" "87ceeb") ("slateblue" "6a5acd") ("slategray" "708090")
    ("slategrey" "708090") ("snow" "fffafa") ("springgreen" "00ff7f") ("steelblue" "4682b4")
    ("tan" "d2b48c") ("teal" "008080") ("thistle" "d8bfd8") ("tomato" "ff6347")
    ("turquoise" "40e0d0") ("violet" "ee82ee") ("violetred" "d02090") ("webgray" "808080")
    ("webgreen" "008000") ("webgrey" "808080") ("webmaroon" "800000") ("webpurple" "800080")
    ("wheat" "f5deb3") ("white" "ffffff") ("whitesmoke" "f5f5f5") ("yellow" "ffff00")
    ("yellowgreen" "9acd32"))
 x11-tab (foldl (\ t r (pin t <r <>r)) {} x11-rows)
 ; the key: lowercase, the separators dropped
 (x11-key s) (string (filter (c \ c != 32 && c != 45 && c != 95)
                             (map (c \ (64 < c && c < 91 ? (c + 32) c)) (map s ^#s))))
 (x11 n) (: h (string? n ? (peep x11-tab (x11-key n) ()) ()) (string? h ? ("#" + h) ()))
 (x11-hex2 s i) (: (dig c) (? (47 < c && c < 58) (c - 48) (96 < c && c < 103) (c - 87) 0)
                   (16 * dig (s i) + dig (s (i + 1))))
 (x11-rgb n) (: h (x11 n) (string? h ? [(x11-hex2 h 1) (x11-hex2 h 3) (x11-hex2 h 5)] ()))
 (x11-sgr k n) (: c (x11-rgb n)
                  (two? c ? ("\e[" + show k + ";2;" + show <c + ";" + show (c 1) + ";" + show (c 2) + "m") ""))
 (x11-fg n) (x11-sgr 38 n)
 (x11-bg n) (x11-sgr 48 n)
 ; the 6x6x6 cube's levels are 0 95 135 175 215 255; a channel lands on the nearest
 (x11-cube v) (v < 48 ? 0 ((v - 35) // 40))
 (x11-256 n) (: c (x11-rgb n) (two? c ? (16 + 36 * x11-cube <c + 6 * x11-cube (c 1) + x11-cube (c 2)) ()))
 (x11-names _) (sort (keys x11-tab))
 (x11-main as)
  (: (line n) (: h (x11 n)
                 (string? h ? (puts (n + " " + h + " " + show (x11-rgb n) + " " + show (x11-256 n) + "\n"), 0)
                  (say err ("x11: not a colour: " + n + "\n"), 1)))
     (two? as ? (foldl (\ a n (a || line n)) 0 as)
      (each (x11-names 0) line)))
 _ (pins (cite 'verbs 'tab) 'x11 x11-main)
 s (cite 'verbs 'fire ["x11" "x11.l"])
 _ (two? s ? (x11-main >s) 0))                     ; a binding: a module's letrec ends in none
) ; module 'x11
