; apps/kore/pic.l -- pictures on a terminal and between formats. png, jpeg and gif are read
; (apps/png.l, apps/jpeg.l, apps/gif.l); png, jpeg, gif and sixel are written.
;
;   pic [cat] [-g MODE] [-w COLS] [-h ROWS] [FILE..]
;         each picture as wide as the terminal (or COLS, or 80) and no taller than ROWS,
;         never enlarged; no FILE reads stdin. MODE is block (the default), two pixels a
;         cell (the upper a `▀`, the lower its background, 24-bit where COLORTERM says so,
;         else the 256-colour cube); sixel; kitty's graphics; or auto, what the terminal
;         answers to being asked, blocks off a terminal. pngcat, jpegcat, gifcat the same
;   pic less [-g MODE] FILE..   a viewer: fitted, zoomed and panned, a gif played, in
;         MODE as pic cat's. picless too
;   pic convert [-q Q] [-t TYPE] IN OUT
;         one format to another, by OUT's extension or TYPE (png gif jpeg sixel ans); - is
;         stdin or stdout. a gif keeps its first frame, a file already TYPE is copied. ans
;         is pic cat's blocks as text, 80 wide
;   pic pixelize [-w COLS] [-h ROWS] [-s PX] [-c 256] [-q Q] [-t TYPE] IN OUT
;         the picture as pic cat's blocks draw it at COLS (80) by ROWS, written back out:
;         each half-cell PX pixels square (the source's size by default), clear where the
;         terminal's ground shows, and in the cube's own levels with -c 256; or, to .ans,
;         the blocks' text itself
;
; www draws a page's pictures through pic-art too.
(module 'kore
(borrow 'cli)
(borrow 'posix)

(:
   pic-usage (cats ["usage: pic [cat] [-g block|sixel|kitty|auto] [-w COLS] [-h ROWS] [FILE..]\n"
                    "       pic less [-g block|sixel|kitty|auto] FILE..\n"
                    "       pic convert [-q QUALITY] [-t png|gif|jpeg|sixel|ans] IN OUT\n"
                    "       pic pixelize [-w COLS] [-h ROWS] [-s PX] [-c 256] [-q QUALITY] [-t TYPE] IN OUT"])
   picless-usage "usage: pic less [-g block|sixel|kitty|auto] FILE.."
   pic-swig (cite 'posix 'swig)
   picless-help "q quit  + - zoom  0 fit  hjkl/arrows pan  n p file  space play  , . frame"

   ; -- reading -----------------------------------------------------------------
   (pic-le16 b i) (b i + 256 * b (i + 1))
   (pic-be32 b i) ((((b i * 256) + b (i + 1)) * 256 + b (i + 2)) * 256 + b (i + 3))
   ; bytes -> 'png 'jpeg 'gif | ()
   (pic-kind b)
    (? !(string? b && 8 <= #b) ()
       (snip b 1 4 = "PNG") 'png
       ((b 0 = 255) && (b 1 = 216)) 'jpeg
       (snip b 0 4 = "GIF8") 'gif
       ())
   ; -> [w h] off the header | why not
   (pic-size b)
    (: k (pic-kind b)
       (? (k = 'png) (? (24 <= #b) [(pic-be32 b 16) (pic-be32 b 20)] "cut short")
          (k = 'jpeg) (cite 'jpeg 'jpeg-size b)
          (k = 'gif) [(pic-le16 b 6) (pic-le16 b 8)]
          "not a picture"))
   ; -> [w h rgba] | why not; a gif's first frame
   (pic-decode b)
    (: k (pic-kind b)
       (? (k = 'png) (cite 'png 'png-decode b)
          (k = 'jpeg) (cite 'jpeg 'jpeg-decode b)
          (k = 'gif) (cite 'gif 'gif-decode b)
          "not a picture"))
   ; -> [w h [[rgba ms] ..]] | why not: a gif's frames, as many as fit 128 MB, and a still
   ; one frame of no time
   (pic-frames b)
    (? (pic-kind b = 'gif)
        (: d (pic-size b) n (d 0 * d 1)
           (cite 'gif 'gif-frames b (max 1 (min 1000 (33554432 // (max 1 n))))))
       (: r (pic-decode b) (? (two? r) [(r 0) (r 1) [[(r 2) 0]]] r)))

   ; -- sampling ----------------------------------------------------------------
   ; ow*oh pixels, the first at source x0 y0 and s source pixels to each -> [ow oh rgba]. a
   ; pixel is its box's mean over four samples weighted by alpha, so a see-through sample
   ; does not darken it; clear (alpha 0) off the picture or where mostly see-through, else
   ; alpha 255
   (pic-sample im x0 y0 s ow oh)
    (: w (im 0) h (im 1) px (im 2) c (cask (4 * ow * oh))
       (at x y) (: i (4 * ((y * w) + x)) [(peep px i 0) (peep px (i + 1) 0) (peep px (i + 2) 0) (peep px (i + 3) 0)])
       (on v n) (0 <= v < n)
       (pix x y o)
        (? (!(on (x0 + ((x + 0.5) * s)) w) || !(on (y0 + ((y + 0.5) * s)) h)) 0
           (: xs (map (f \ max 0 (min (w - 1) (int (x0 + ((x + f) * s))))) [0.25 0.75])
              ys (map (f \ max 0 (min (h - 1) (int (y0 + ((y + f) * s))))) [0.25 0.75])
              ss (foldl (\ acc a (foldl (\ acc b ((at a b) . acc)) acc ys)) () xs)
              a +(map (p \ p 3) ss)
              (ch k) ((+(map (p \ p k * p 3) ss)) // a)
              (? (a < 512) 0 (pins c o (ch 0) (o + 1) (ch 1) (o + 2) (ch 2) (o + 3) 255))))
       _ (map (y \ map (x \ pix x y (4 * ((y * ow) + x))) ^ow) ^oh)
       [ow oh (string c)])
   ; the same box by nearest pixel, alpha kept: quick enough to redraw a screen of pixels
   (pic-near im x0 y0 s ow oh)
    (: w (im 0) h (im 1) px (im 2) c (cask (4 * ow * oh))
       sx (map (x \ 4 * max 0 (min (w - 1) (int (x0 + ((x + 0.5) * s))))) ^ow)
       (row y) (: b (4 * w * max 0 (min (h - 1) (int (y0 + ((y + 0.5) * s)))))
                  (foldl (\ o x (pour c o px (b + x) 4, o + 4)) (4 * ow * y) sx))
       _ (map row ^oh)
       [ow oh (string c)])
   ; the scale that fits a picture in cols by rows cells, never enlarging it; rows () is
   ; no limit
   (pic-fit im cols rows)
    (max 1.0 (max (im 0 / cols) (? !rows 0 (im 1 / (2 * rows)))))

   ; -- blocks ------------------------------------------------------------------
   ; a colour as sgr: 24-bit when deep, else the 256-colour cube
   (pic-deep _) (: ct (getenv "COLORTERM") (string? ct && (ct = "truecolor" || ct = "24bit")))
   (pic-sgr deep fg c)
    (? deep ((? fg "38;2;" "48;2;") + show (c 0) + ";" + show (c 1) + ";" + show (c 2))
       (: (q v) ((v * 5 + 127) // 255)
          ((? fg "38;5;" "48;5;") + show (16 + 36 * q (c 0) + 6 * q (c 1) + q (c 2)))))
   ; a sampled picture as rows of cells, two pixels to each
   (pic-cells sm deep)
    (: ow (sm 0) oh (sm 1) px (sm 2) e (string 27)
       (pix x y) (: o (4 * ((y * ow) + x))
                    (? ((oh <= y) || (px (o + 3) = 0)) () [(px o) (px (o + 1)) (px (o + 2))]))
       (sg fg c) (e + "[" + pic-sgr deep fg c + "m")
       (cell t b) (? (!t && !b) (e + "[0m ")
                     !b (e + "[0m" + sg 1 t + "▀")
                     !t (e + "[0m" + sg 1 b + "▄")
                     (sg 1 t + sg 0 b + "▀"))
       (row r) (: o (jug 0)
                  _ (map (x \ say o (cell (pix x (2 * r)) (pix x (2 * r + 1)))) ^ow)
                  (slurp o + e + "[0m"))
       (map row ^((oh + 1) // 2)))
   (pic-view im x0 y0 s ow oh deep) (pic-cells (pic-sample im x0 y0 s ow oh) deep)
   ; the blocks as text, a line a row
   (pic-ans im cols rows deep) (cats (map (r \ r + "\n") (pic-art im cols rows deep)))
   ; a picture as rows of cells at most cols wide and rows tall
   (pic-art im cols rows deep)
    (: s (pic-fit im cols rows)
       (pic-view im 0 0 s (max 1 (int (im 0 / s))) (max 1 (int (im 1 / s))) deep))

   ; -- graphics: sixel and kitty's -----------------------------------------------
   ; a picture as one sixel string: the palette gif's (exact to 255 colours, a median cut
   ; past; idx holds each pixel's register plus one, 0 clear, in a byte), a pixel under
   ; half alpha left to the ground. a band's colours each run from their first pixel to
   ; their last
   (pic-sixel im)
    (: w (im 0) h (im 1) px (im 2) n (w * h) e (string 27)
       key (cite 'gif 'gif-key)
       pal (cite 'gif 'gif-palette px n 255)
       cols (pal 0) ix (pal 1) f (pal 2)
       idx (cask n)
       _ (map (i \ (: k (f (key px (4 * i))) (pin idx i (? (k < 0) 0 (1 + peep ix k 0))))) ^n)
       (pct v) ((v * 100 + 127) // 255)
       (colour i) (: c (cols i)
                     ("#" + show i + ";2;" + show (pct ((c >> 16) & 255)) + ";"
                      + show (pct ((c >> 8) & 255)) + ";" + show (pct (c & 255))))
       (run v k) (: ch (string (63 + v)) (? (3 < k) ("!" + show k + ch) (catmap (_ \ ch) ^k)))
       (rle m lo hi)
        (: o (jug 0)
           _ (? (0 < lo) (say o (run 0 lo)) 0)
           (go x v k) (? (hi < x) (say o (run v k), slurp o)
                         (: b (peep m x 0)
                            (? (b = v) (go (x + 1) v (k + 1)) (say o (run v k), go (x + 1) b 1))))
           (go (lo + 1) (peep m lo 0) 1))
       (band y0)
        (: t (tablet 0) lo (tablet 0) hi (tablet 0) ys (map (r \ y0 + r) ^(min 6 (h - y0)))
           (dot x y) (: c (peep idx ((y * w) + x) 0)
                        (? !c 0
                           (: m (peep t c ())
                              m2 (? (m = ()) (: k (cask w) _ (pin t c k) _ (pin lo c x) k) m)
                              (pin m2 x ((peep m2 x 0) | (1 << (y - y0))), pin hi c x))))
           _ (map (x \ map (y \ dot x y) ys) ^w)
           (ujoinc 36 (map (c \ "#" + show (c - 1) + rle (t c) (lo c) (hi c)) (sort (keys t))) + "-"))
       (e + "P0;1;0q\"1;1;" + show w + ";" + show h
        + catmap colour ^#cols
        + catmap (b \ band (6 * b)) ^((h + 5) // 6)
        + e + "\\"))
   ; a picture through kitty's protocol: raw rgba placed at the cursor, 4096 bytes of
   ; base64 a chunk, no answer asked for
   (pic-kitty im) (pic-kits im "")
   ; ..with more keys on the first chunk, each "k=v,"
   (pic-kits im keys)
    (: e (string 27) b (ubenc ub64set 6 (im 2)) n #b o (jug 0)
       (go i) (: j (min n (i + 4096)) m (? (j < n) "1" "0")
                 _ (say o (e + "_G" + (? (i = 0) ("a=T,f=32,q=2," + keys + "s=" + show (im 0) + ",v=" + show (im 1) + ",") "")
                           + "m=" + m + ";" + snip b i j + e + "\\"))
                 (? (j < n) (go j) (slurp o)))
       (go 0))
   ; what pic asks a terminal: kitty's query and the cell size, then DA1, which every
   ; terminal answers and so ends the wait
   pic-ask (cats [(string 27) "_Gi=31,s=1,v=1,a=q,t=d,f=24;AAAA" (string 27) "\\"
                  (string 27) "[16t" (string 27) "[c"])
   (pic-digits s i) (: (go i v) (? ((#s <= i) || !(47 < s i < 58)) v (go (i + 1) (v * 10 + s i - 48))) (go i 0))
   (pic-past s i) (? ((#s <= i) || !(47 < s i < 58)) i (pic-past s (i + 1)))
   ; DA1's answer in s as ";p;..;p;", or "" before it is whole
   (pic-da s)
    (: i (wg-find s (string 27 + "[?") 0)
       (go j) (? ((i < 0) || (#s <= j)) "" (s j = 99) (";" + snip s (i + 3) j + ";")
                 ((s j = 59) || (47 < s j < 58)) (go (j + 1)) "")
       (go (i + 3)))
   ; the answers to pic-ask -> {'kitty 'sixel 'cw 'ch}, cw and ch 0 when not said
   (pic-heard s)
    (: c (wg-find s (string 27 + "[6;") 0)
       {'kitty (0 <= wg-find s (string 27 + "_Gi=31;OK") 0)
        'sixel (0 <= wg-find (pic-da s) ";4;" 0)
        'ch (? (c < 0) 0 (pic-digits s (c + 4)))
        'cw (? (c < 0) 0 (pic-digits s (pic-past s (c + 4) + 1)))})
   ; the terminal on stdin and stdout asked, raw for at most a second
   (pic-probe _)
    (? !(two? (tty 0) && two? (tty 1)) (pic-heard "")
       (: b (cask 256)
          _ (raw 1)
          _ (puts pic-ask)
          _ (flush out)
          t0 (clock 0)
          (go acc) (: k (pic-swig in b) s (acc + (? (charm? k && 0 < k) (snip (string b) 0 k) ""))
                      (? ((0 < #(pic-da s)) || (1000 < (clock 0 - t0))) s (rest 10, go s)))
          s (go "")
          _ (raw 0)
          (pic-heard s)))
   ; a picture sized for cols by rows cells of cw by ch pixels, never enlarged
   (pic-px im cols rows cw ch)
    (: s (max 1.0 (max (im 0 / (cols * cw)) (? !rows 0 (im 1 / (rows * ch)))))
       (? (s = 1.0) im (pic-sample im 0 0 s (max 1 (int (im 0 / s))) (max 1 (int (im 1 / s))))))

   ; -- files -------------------------------------------------------------------
   ; a name's picture type by its extension | ()
   (pic-type nm)
    (: (dot i) (? (i < 0) -1 (nm i = 46) i (dot (i - 1)))
       x (wg-lower (snip nm (dot (#nm - 1) + 1) #nm))
       (x @ "png" 'png "gif" 'gif "jpg" 'jpeg "jpeg" 'jpeg "six" 'sixel "sixel" 'sixel "ans" 'ans ()))
   ; -> the picture's bytes as ty | why not
   (pic-encode ty im q)
    (? (ty = 'png) (cite 'png 'png-encode (im 0) (im 1) (im 2))
       (ty = 'gif) (cite 'gif 'gif-encode (im 0) (im 1) (im 2))
       (ty = 'jpeg) (: r (jpeg-encode (im 0) (im 1) (im 2) q) (? (string? r) r "cannot encode a jpeg"))
       (ty = 'sixel) (pic-sixel im)
       "no such type")
   (pic-in who p)
    (? (p = "-") (slurp in)
       (: r (uread p) (? (two? r) <>r (udie 1 (who + ": cannot open " + p)))))
   (pic-out who p b)
    (? (p = "-") (say out b, flush out, 0)
       (uwrite p b) 0
       (udie 1 (who + ": cannot write " + p)))
   ; the type of the -t value or the out file's name, or leave
   (pic-otype who t p dflt)
    (: v (uoptv t 116) ty (? (string? v) (pic-type ("." + v)) (pic-type p))
       (? (ty != ()) ty ((dflt != ()) && !(string? v)) dflt
          (udie 2 (who + ": " + (? (string? v) ("no type " + v) ("no type for " + p)) + "; png gif jpeg sixel or ans"))))
   (pic-num t k d) (: v (uoptv t k) (? (string? v) (: n (uatoi v) (? (0 < n) n d)) d))
   (pic-decoded who nm b)
    (: im (pic-decode b) (? (two? im) im (udie 1 (who + ": " + nm + ": " + im))))

   ; -- the verbs ---------------------------------------------------------------
   (pic-main as)
    (? (atom? as) (pic-cat as)
       (<as @ "cat" (pic-cat >as)
              "less" (picless-main >as)
              "convert" (pic-convert >as)
              "pixelize" (pic-pixelize >as)
              "help" (say out (pic-usage + "\n"), 0)
              (pic-cat as)))
   ; -g's mode, block when unsaid; auto taken by what the terminal answered
   (pic-mode who t)
    (: v (uoptv t 103) g (? (string? v) v "block")
       (? (elem g ["auto" "block" "sixel" "kitty"]) g (udie 2 (who + ": no mode " + g + "; block sixel kitty or auto"))))
   (pic-pick g pr) (? (g != "auto") g (pr 'kitty) "kitty" (pr 'sixel) "sixel" "block")
   (pic-cat as)
    (: fo (uflags "pic" as [103 104 119] "ghw")
       t (fo 0) fs (fo 1)
       ws (tty 1)
       cols (pic-num t 119 (? (two? ws && 0 < >ws) >ws 80))
       rows (pic-num t 104 ())
       g (pic-mode "pic" t)
       pr (? ((g = "block") || !(two? ws)) (pic-heard "") (pic-probe 0))
       mode (pic-pick g pr)
       cw (? (0 < pr 'cw) (pr 'cw) 8) ch (? (0 < pr 'ch) (pr 'ch) 16)
       deep (pic-deep 0)
       (draw im)
        (mode @ "sixel" (say out (pic-sixel (pic-px im cols rows cw ch)))
                "kitty" (say out (pic-kitty (pic-px im cols rows cw ch) + "\n"))
                (map (r \ puts (r + "\n")) (pic-art im cols rows deep)))
       (one nm b)
        (: im (pic-decode b)
           (? (two? im) ((? (1 < #fs) (puts (nm + ":\n")) 0), draw im, flush out, 0)
              (say err ("pic: " + nm + ": " + im), put err 10, 1)))
       (? (two? fs)
           (foldl (\ a f (: r (uread f)
                            x (? (two? r) (one f <>r)
                                 (say err ("pic: cannot open " + f), put err 10, 1))
                            (? (a || x) 1 0)))
                  0 fs)
          (one "stdin" (slurp in))))
   (pic-convert as)
    (: who "pic convert"
       fo (uflags who as [113 116] "qt")
       t (fo 0) ops (fo 1)
       _ (? (#ops = 2) () (udie 2 pic-usage))
       ty (pic-otype who t (ops 1) ())
       b (pic-in who (ops 0))
       ; a file already of the type goes across as it is, a gif's frames with it
       (pic-out who (ops 1)
                (? ((pic-kind b = ty) && !(string? (uoptv t 113))) b
                   (ty = 'ans) (pic-ans (pic-decoded who (ops 0) b) 80 () 1)
                   (: r (pic-encode ty (pic-decoded who (ops 0) b) (pic-num t 113 90))
                      (? (string? r) r (udie 1 (who + ": " + r)))))))
   (pic-pixelize as)
    (: who "pic pixelize"
       fo (uflags who as [99 104 113 115 116 119] "chqstw")
       t (fo 0) ops (fo 1)
       _ (? (#ops = 2) () (udie 2 pic-usage))
       ty (pic-otype who t (ops 1) 'png)
       c (: v (uoptv t 99) (? (string? v) v "24"))
       _ (? (elem c ["24" "256"]) () (udie 2 (who + ": -c is 24 or 256")))
       im (pic-decoded who (ops 0) (pic-in who (ops 0)))
       cols (pic-num t 119 80) rows (pic-num t 104 ())
       (pic-out who (ops 1)
                (? (ty = 'ans) (pic-ans im cols rows (c = "24"))
                   (pic-encode ty (pic-blocky im cols rows (pic-num t 115 0) (c = "24")) (pic-num t 113 90)))))
   ; the picture as pic-art draws it in cols by rows cells -> [w h rgba]: each pixel of the
   ; cells k pixels square (0: the source's own scale), a last odd row's lower half clear
   ; as the ground, and when not deep the colour the cube's level shows
   (pic-blocky im cols rows k deep)
    (: s (pic-fit im cols rows) sm (pic-sample im 0 0 s (max 1 (int (im 0 / s))) (max 1 (int (im 1 / s))))
       ow (sm 0) oh (sm 1) px (sm 2)
       k2 (? (0 < k) k (max 1 (int (s + 0.5))))
       W (ow * k2) oh2 (2 * ((oh + 1) // 2)) H (oh2 * k2)
       c (cask (4 * W * H))
       lv [0 95 135 175 215 255]
       (tone v) (? deep v (lv ((v * 5 + 127) // 255)))
       (fill sy)
        (: row (cask (4 * W))
           _ (? (oh <= sy) 0 (map (x \ (: i (4 * ((sy * ow) + x)) o0 (4 * x * k2)
                     (map (d \ (: o (o0 + 4 * d)
                                  (? (px (i + 3) = 0) (pins row o 0 (o + 1) 0 (o + 2) 0 (o + 3) 0)
                                     (pins row o (tone (px i)) (o + 1) (tone (px (i + 1)))
                                           (o + 2) (tone (px (i + 2))) (o + 3) 255))))
                          ^k2)))
             ^ow))
           (string row))
       _ (map (sy \ (: r (fill sy) (map (d \ pour c (4 * W * ((sy * k2) + d)) r 0 (4 * W)) ^k2)))
              ^oh2)
       [W H (string c)])

   ; -- picless: the viewer ----------------------------------------------------------
   ; st: 'fs 'i the file, 'im [w h frames] or why not, 'f the frame, 'z the zoom over the fit,
   ; 'cx 'cy the view's centre in source pixels, 'play, 'due the next frame's clock,
   ; 'h 'w the screen, 'rows the cache of drawn frames for 'ck, the view they were drawn for,
   ; 'mode block sixel or kitty and 'ux 'uy the pixels a cell holds in it
   (pv-new fs h w)
    (: st (tablet 0)
       _ (pins st 'fs fs 'i 0 'h h 'w w 'quit 0 'msg "" 'mode "block" 'ux 1 'uy 2)
       (pv-load st))
   (pv-load st)
    (: nm (st 'fs (st 'i))
       r (uread nm)
       im (? (two? r) (pic-frames <>r) "cannot open")
       ok (two? im)
       (pins st 'im im 'f 0 'z 1.0 'play 1 'due 0 'rows (tablet 0) 'ck ()
                'cx (? ok (im 0 / 2) 0) 'cy (? ok (im 1 / 2) 0)))
   (pv-nf st) (: im (st 'im) (? (two? im) #(im 2) 0))
   ; [s x0 y0 ow oh left top]: the scale, the source origin, the output pixels, and the cells
   ; and rows of margin that centre a picture smaller than the screen. the centre is held
   ; where the edges stop it. a sixel is whole bands of 6, lest its last spill onto the
   ; status line and scroll
   (pv-view st)
    (: im (st 'im) w (im 0) h (im 1) cols (st 'w) rows (st 'h - 1) ux (st 'ux) uy (st 'uy)
       pw (cols * ux) ph (: p (rows * uy) (? (st 'mode = "sixel") (6 * (p // 6)) p))
       s ((max 1.0 (max (w / pw) (h / ph))) / (st 'z))
       vw (pw * s) vh (ph * s)
       (axis c n v) (? (n <= v) 0 (max 0 (min (n - v) (c - (v / 2)))))
       x0 (axis (st 'cx) w vw) y0 (axis (st 'cy) h vh)
       _ (? (vw < w) (pin st 'cx (x0 + (vw / 2))) 0)
       _ (? (vh < h) (pin st 'cy (y0 + (vh / 2))) 0)
       ow (max 1 (min pw (int ((w - x0) / s))))
       oh (max 1 (min ph (int ((h - y0) / s))))
       [s x0 y0 ow oh ((cols - ((ow + ux - 1) // ux)) // 2) ((rows - ((oh + uy - 1) // uy)) // 2)])
   ; the status line: the file's own name, not its path, and what it is
   (pv-status st)
    (: im (st 'im) path (st 'fs (st 'i)) nf (pv-nf st)
       nm (: (go i) (? (i < 0) path (path i = 47) (snip path (i + 1) #path) (go (i - 1)))
             (go (#path - 1)))
       tag (? (1 < #(st 'fs)) ("  [" + show (st 'i + 1) + "/" + show #(st 'fs) + "]") "")
       (? (st 'msg = picless-help) picless-help
          (atom? im) (nm + ": " + im + tag)
          (: v (pv-view st)
             (nm + tag + "  " + show (im 0) + "x" + show (im 1)
              + "  " + show (int ((100 / (v 0)) + 0.5)) + "%"
              + (? (1 < nf) ("  frame " + show (st 'f + 1) + "/" + show nf
                             + (? (st 'play) "" " (paused)")) "")
              + (? (0 < #(st 'msg)) ("  " + st 'msg) "  (? for keys)")))))
   pv-unkit (string 27 + "_Ga=d,d=a,q=2" + string 27 + "\\")
   ; the whole screen as one string, the frame drawn once per view
   (pv-frame st)
    (: e (string 27) im (st 'im) rows (st 'h - 1)
       (at r) (e + "[" + show (r + 1) + ";1H")
       body
        (? (atom? im) (catmap (r \ at r + e + "[K") ^rows)
           (: v (pv-view st) ck [(v 0) (v 1) (v 2) (v 3) (v 4) (st 'w) (st 'h)]
              _ (? (ck = st 'ck) 0 (pins st 'ck ck 'rows (tablet 0)))
              f (st 'f)
              fr [(im 0) (im 1) (im 2 f 0)] mode (st 'mode)
              (draw _)
               (? (mode = "block") (pic-view fr (v 1) (v 2) (v 0) (v 3) (v 4) (pic-deep 0))
                  (: px (pic-near fr (v 1) (v 2) (v 0) (v 3) (v 4))
                     (? (mode = "sixel") (pic-sixel px) (pic-kits px "C=1,"))))
              drawn (: d (peep (st 'rows) f ())
                       (? (d = ()) (: d2 (draw 0) _ (pin (st 'rows) f d2) d2) d))
              pad (catmap (_ \ " ") ^(v 5)) top (v 6)
              (? (mode = "block")
                  (catmap (r \ at r + (? (top <= r < (top + #drawn)) (pad + drawn (r - top)) "") + e + "[K") ^rows)
                 ; the rows cleared, kitty's pictures let go, then the picture at its corner
                 (catmap (r \ at r + e + "[K") ^rows
                  + (? (mode = "kitty") pv-unkit "")
                  + e + "[" + show (top + 1) + ";" + show ((v 5) + 1) + "H" + drawn))))
       line (: s (pv-status st) (? (st 'w < #s) (snip s 0 (st 'w)) s))
       (body + at rows + e + "[7m" + line + e + "[0m" + e + "[K"))
   ; one key. panning moves a quarter of the view
   (pv-step st c)
    (: im (st 'im) ok (two? im) nf (pv-nf st)
       v (? ok (pv-view st) ())
       (pan dx dy) (? ok (pins st 'cx ((st 'cx) + ((dx * (v 0) * (st 'w) * (st 'ux)) / 4))
                                  'cy ((st 'cy) + ((dy * (v 0) * ((st 'h) - 1) * (st 'uy)) / 4))) 0)
       (file k) (: n #(st 'fs) _ (pin st 'i ((((st 'i + k) % n) + n) % n)) (pv-load st))
       (frame k) (? (1 < nf) (pins st 'play 0 'f ((((st 'f + k) % nf) + nf) % nf)) 0)
       _ (pin st 'msg "")
       (? (c = 113 || c = 81) (pin st 'quit 1)
          (c = 43 || c = 61) (pin st 'z (min 64 (st 'z * 1.5)))
          (c = 45 || c = 95) (pin st 'z (max 0.125 (st 'z / 1.5)))
          (c = 48 || c = 102) (pins st 'z 1.0 'cx (? ok (im 0 / 2) 0) 'cy (? ok (im 1 / 2) 0))
          (c = 104) (pan -1 0) (c = 108) (pan 1 0)
          (c = 107) (pan 0 -1) (c = 106) (pan 0 1)
          (c = 110 || (c = 32 && nf < 2)) (file 1)
          (c = 112 || c = 78) (file -1)
          (c = 32) (pins st 'play !(st 'play) 'due 0)
          (c = 46) (frame 1) (c = 44) (frame -1)
          (pin st 'msg picless-help)))
   ; the clock moves a playing gif on: 1 when the frame changed
   (pv-tick st now)
    (: nf (pv-nf st)
       (? (nf < 2 || !(st 'play)) 0
          (st 'due = 0) (pin st 'due (now + (st 'im 2 (st 'f) 1)), 0)
          (now < st 'due) 0
          (: f ((st 'f + 1) % nf)
             _ (pins st 'f f 'due (now + (st 'im 2 f 1)))
             1)))
   ; bytes off the keyboard -> key codes, the arrows as h j k l
   (pv-keys ks)
    (: n #ks
       (go i acc)
        (? (n <= i) (rev acc)
           ((ks i = 27) && (i + 2) < n && (ks (i + 1) = 91))
            (: f (ks (i + 2))
               (go (i + 3) (? (f = 65) (107 . acc) (f = 66) (106 . acc) (f = 67) (108 . acc)
                              (f = 68) (104 . acc) acc)))
           (ks i = 27) (go (i + 1) acc)
           (go (i + 1) (ks i . acc)))
       (go 0 ()))
   (picless-main as)
    (: fo (uflags "pic less" as [103] "g")
       fs (fo 1)
       _ (? (two? fs) () (udie 2 picless-usage))
       g (pic-mode "pic less" (fo 0))
       ws (tty 1)
       _ (? (two? ws) () (udie 2 "pic less: not a terminal"))
       hw (pgwin ws)
       st (pv-new fs <hw <>hw)
       pr (? (g = "block") (pic-heard "") (pic-probe 0))
       mode (pic-pick g pr)
       _ (? (mode = "block") 0
            (pins st 'mode mode 'ux (? (0 < pr 'cw) (pr 'cw) 8) 'uy (? (0 < pr 'ch) (pr 'ch) 16)))
       b (cask 64) e (string 27)
       _ (raw 1)
       _ (puts (e + "[?1049h" + e + "[?25l" + e + "[2J"))
       (fin _) (puts ((? (mode = "kitty") pv-unkit "") + e + "[0m" + e + "[?25h" + e + "[?1049l"),
                flush out, raw 0, 0)
       (go dirty)
        (: ws2 (tty 1) hw2 (? (two? ws2) (pgwin ws2) [(st 'h) (st 'w)])
           moved (!(<hw2 = st 'h) || !(<>hw2 = st 'w))
           _ (? moved (pins st 'h <hw2 'w <>hw2, puts (e + "[2J")) 0)
           _ (? (dirty || moved) (puts (pv-frame st), flush out) 0)
           n (pic-swig in b)
           ks (? (charm? n && 0 < n) (pv-keys (snip (string b) 0 n)) ())
           _ (map (c \ pv-step st c) ks)
           (? (st 'quit) (fin ())
              (: t (pv-tick st (clock 0))
                 _ (? (two? ks || t) 0 (rest (? ((1 < pv-nf st) && st 'play) 15 50)))
                 (go (two? ks || t)))))
       (go 1)))
) ; module 'kore
