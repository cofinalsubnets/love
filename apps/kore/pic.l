; apps/kore/pic.l -- pictures on a terminal, two pixels a cell: the upper pixel the colour
; of a `▀`, the lower its background, 24-bit where COLORTERM says the terminal takes it and
; the 256-colour cube otherwise. png, jpeg and gif (apps/png.l, apps/jpeg.l, apps/gif.l).
;
;   pic [-w COLS] [-h ROWS] [FILE..]   each picture printed as wide as the terminal (or
;                                      COLS, or 80) and no taller than ROWS, never enlarged;
;                                      no FILE reads stdin. pngcat, jpegcat, gifcat the same
;   picless FILE..                     a viewer: fitted to the screen, zoomed and panned,
;                                      a gif played. pngless, jpegless, gifless the same
;
; www draws a page's pictures through pic-art too.
(module 'kore
(borrow 'cli)
(borrow 'posix)

(:
   pic-usage "usage: pic [-w COLS] [-h ROWS] [FILE..]"
   picless-usage "usage: picless FILE.."
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
          (k = 'jpeg) ((cite 'jpeg 'jpeg-size) b)
          (k = 'gif) [(pic-le16 b 6) (pic-le16 b 8)]
          "not a picture"))
   ; -> [w h rgba] | why not; a gif's first frame
   (pic-decode b)
    (: k (pic-kind b)
       (? (k = 'png) ((cite 'png 'png-decode) b)
          (k = 'jpeg) ((cite 'jpeg 'jpeg-decode) b)
          (k = 'gif) ((cite 'gif 'gif-decode) b)
          "not a picture"))
   ; -> [w h [[rgba ms] ..]] | why not: a gif's frames, as many as fit 128 MB, and a still
   ; one frame of no time
   (pic-frames b)
    (? (pic-kind b = 'gif)
        (: d (pic-size b) n (d 0 * d 1)
           ((cite 'gif 'gif-frames) b (max 1 (min 1000 (33554432 // (max 1 n))))))
       (: r (pic-decode b) (? (two? r) [(r 0) (r 1) [[(r 2) 0]]] r)))

   ; -- drawing -----------------------------------------------------------------
   (pic-deep _) (: ct (getenv "COLORTERM") (string? ct && (ct = "truecolor" || ct = "24bit")))
   ; a colour as sgr: 24-bit when deep, else the 256-colour cube
   (pic-sgr deep fg c)
    (? deep ((? fg "38;2;" "48;2;") + show (c 0) + ";" + show (c 1) + ";" + show (c 2))
       (: (q v) ((v * 5 + 127) // 255)
          ((? fg "38;5;" "48;5;") + show (16 + 36 * q (c 0) + 6 * q (c 1) + q (c 2)))))
   ; rows of cells for ow*oh output pixels, the first at source x0 y0 and s source pixels to
   ; each. a pixel is its box's mean over four samples weighted by alpha, so a see-through
   ; sample does not darken it, and () where it is off the picture or mostly see-through
   (pic-view im x0 y0 s ow oh deep)
    (: w (im 0) h (im 1) px (im 2) e (string 27)
       (at x y) (: i (4 * ((y * w) + x)) [(peep px i 0) (peep px (i + 1) 0) (peep px (i + 2) 0) (peep px (i + 3) 0)])
       (on v n) (0 <= v < n)
       (pix x y)
        (? ((oh <= y) || !(on (x0 + ((x + 0.5) * s)) w) || !(on (y0 + ((y + 0.5) * s)) h)) ()
           (: xs (map (f \ max 0 (min (w - 1) (int (x0 + ((x + f) * s))))) [0.25 0.75])
              ys (map (f \ max 0 (min (h - 1) (int (y0 + ((y + f) * s))))) [0.25 0.75])
              ss (foldl (\ acc a (foldl (\ acc b ((at a b) . acc)) acc ys)) () xs)
              a +(map (p \ p 3) ss)
              (? (a < 512) () (map (k \ (+(map (p \ p k * p 3) ss)) // a) ^3))))
       (sg fg c) (e + "[" + pic-sgr deep fg c + "m")
       (cell t b) (? (!t && !b) (e + "[0m ")
                     !b (e + "[0m" + sg 1 t + "▀")
                     !t (e + "[0m" + sg 1 b + "▄")
                     (sg 1 t + sg 0 b + "▀"))
       (row r) (: o (jug 0)
                  _ (map (x \ say o (cell (pix x (2 * r)) (pix x (2 * r + 1)))) ^ow)
                  (slurp o + e + "[0m"))
       (map row ^((oh + 1) // 2)))
   ; the scale that fits a picture in cols by rows cells, never enlarging it; rows () is
   ; no limit
   (pic-fit im cols rows)
    (max 1.0 (max (im 0 / cols) (? (nil? rows) 0 (im 1 / (2 * rows)))))
   ; a picture as rows of cells at most cols wide and rows tall
   (pic-art im cols rows deep)
    (: s (pic-fit im cols rows)
       (pic-view im 0 0 s (max 1 (int (im 0 / s))) (max 1 (int (im 1 / s))) deep))

   ; -- pic: printed --------------------------------------------------------------
   (pic-main as)
    (: t (tablet 0)
       o (uopt as t '(104 119) () ())                   ; -h and -w take values
       _ (? (two? o) () (udie 2 pic-usage))
       _ (: c (uoptun t '(104 119)) (? (nil? c) () (udie 2 ("pic: unknown option -" + string c))))
       (num k d) (: v (uoptv t k) (? (string? v) (: n (uatoi v) (? (0 < n) n d)) d))
       ws (tty 1)
       cols (num 119 (? (two? ws && 0 < >ws) >ws 80))
       rows (num 104 ())
       deep (pic-deep 0)
       fs <>>o
       (one nm b)
        (: im (pic-decode b)
           (? (two? im)
               (: _ (? (1 < #fs) (puts (nm + ":\n")) 0)
                  _ (map (r \ puts (r + "\n")) (pic-art im cols rows deep))
                  0)
              (: _ (say err ("pic: " + nm + ": " + im)) _ (put err 10) 1)))
       (? (two? fs)
           (foldl (\ a f (: r (uread f)
                            x (? (two? r) (one f <>r)
                                 (: _ (say err ("pic: cannot open " + f)) _ (put err 10) 1))
                            (? (a || x) 1 0)))
                  0 fs)
          (one "stdin" (slurp in))))

   ; -- picless: the viewer ----------------------------------------------------------
   ; st: 'fs 'i the file, 'im [w h frames] or why not, 'f the frame, 'z the zoom over the fit,
   ; 'cx 'cy the view's centre in source pixels, 'play, 'due the next frame's clock,
   ; 'h 'w the screen, 'rows the cache of drawn frames for 'ck, the view they were drawn for
   (pv-new fs h w)
    (: st (tablet 0)
       _ (pins st 'fs fs 'i 0 'h h 'w w 'quit 0 'msg "")
       (pv-load st))
   (pv-load st)
    (: nm ((st 'fs) (st 'i))
       r (uread nm)
       im (? (two? r) (pic-frames <>r) "cannot open")
       ok (two? im)
       (pins st 'im im 'f 0 'z 1.0 'play 1 'due 0 'rows (tablet 0) 'ck ()
                'cx (? ok (im 0 / 2) 0) 'cy (? ok (im 1 / 2) 0)))
   (pv-nf st) (: im (st 'im) (? (two? im) #(im 2) 0))
   ; [s x0 y0 ow oh left top]: the scale, the source origin, the output pixels, and the cells
   ; and rows of margin that centre a picture smaller than the screen. the centre is held
   ; where the edges stop it
   (pv-view st)
    (: im (st 'im) w (im 0) h (im 1) cols (st 'w) rows (st 'h - 1)
       s ((pic-fit im cols rows) / (st 'z))
       vw (cols * s) vh (2 * rows * s)
       (axis c n v) (? (n <= v) 0 (max 0 (min (n - v) (c - (v / 2)))))
       x0 (axis (st 'cx) w vw) y0 (axis (st 'cy) h vh)
       _ (? (vw < w) (pin st 'cx (x0 + (vw / 2))) 0)
       _ (? (vh < h) (pin st 'cy (y0 + (vh / 2))) 0)
       ow (max 1 (min cols (int ((w - x0) / s))))
       oh (max 1 (min (2 * rows) (int ((h - y0) / s))))
       [s x0 y0 ow oh ((cols - ow) // 2) ((rows - ((oh + 1) // 2)) // 2)])
   ; the status line: the file's own name, not its path, and what it is
   (pv-status st)
    (: im (st 'im) path ((st 'fs) (st 'i)) nf (pv-nf st)
       nm (: (go i) (? (i < 0) path (path i = 47) (snip path (i + 1) #path) (go (i - 1)))
             (go (#path - 1)))
       tag (? (1 < #(st 'fs)) ("  [" + show (st 'i + 1) + "/" + show #(st 'fs) + "]") "")
       (? (st 'msg = picless-help) picless-help
          !(two? im) (nm + ": " + im + tag)
          (: v (pv-view st)
             (nm + tag + "  " + show (im 0) + "x" + show (im 1)
              + "  " + show (int ((100 / (v 0)) + 0.5)) + "%"
              + (? (1 < nf) ("  frame " + show (st 'f + 1) + "/" + show nf
                             + (? (st 'play) "" " (paused)")) "")
              + (? (0 < #(st 'msg)) ("  " + st 'msg) "  (? for keys)")))))
   ; the whole screen as one string, the frame's rows drawn once per view
   (pv-frame st)
    (: e (string 27) im (st 'im) rows (st 'h - 1)
       (at r) (e + "[" + show (r + 1) + ";1H")
       body
        (? !(two? im) (catmap (r \ at r + e + "[K") ^rows)
           (: v (pv-view st) ck [(v 0) (v 1) (v 2) (v 3) (v 4) (st 'w) (st 'h)]
              _ (? (ck = st 'ck) 0 (pins st 'ck ck 'rows (tablet 0)))
              f (st 'f)
              drawn (: d (peep (st 'rows) f ())
                       (? (nil? d)
                           (: d2 (pic-view [(im 0) (im 1) ((im 2) f 0)] (v 1) (v 2) (v 0) (v 3) (v 4) (pic-deep 0))
                              _ (pin (st 'rows) f d2) d2)
                          d))
              pad (catmap (_ \ " ") ^(v 5)) top (v 6)
              (catmap (r \ at r + (? (top <= r < (top + #drawn)) (pad + drawn (r - top)) "") + e + "[K") ^rows)))
       line (: s (pv-status st) (? (st 'w < #s) (snip s 0 (st 'w)) s))
       (body + at rows + e + "[7m" + line + e + "[0m" + e + "[K"))
   ; one key. panning moves a quarter of the view
   (pv-step st c)
    (: im (st 'im) ok (two? im) nf (pv-nf st)
       v (? ok (pv-view st) ())
       (pan dx dy) (? ok (pins st 'cx ((st 'cx) + ((dx * (v 0) * (st 'w)) / 4))
                                  'cy ((st 'cy) + ((dy * (v 0) * ((st 'h) - 1)) / 2))) 0)
       (file k) (: n #(st 'fs) _ (pin st 'i ((((st 'i + k) % n) + n) % n)) (pv-load st))
       (frame k) (? (1 < nf) (pins st 'play 0 'f ((((st 'f + k) % nf) + nf) % nf)) 0)
       _ (pin st 'msg "")
       (? ((c = 113) || (c = 81)) (pin st 'quit 1)
          ((c = 43) || (c = 61)) (pin st 'z (min 64 (st 'z * 1.5)))
          ((c = 45) || (c = 95)) (pin st 'z (max 0.125 (st 'z / 1.5)))
          ((c = 48) || (c = 102)) (pins st 'z 1.0 'cx (? ok (im 0 / 2) 0) 'cy (? ok (im 1 / 2) 0))
          (c = 104) (pan -1 0) (c = 108) (pan 1 0)
          (c = 107) (pan 0 -1) (c = 106) (pan 0 1)
          ((c = 110) || ((c = 32) && (nf < 2))) (file 1)
          ((c = 112) || (c = 78)) (file -1)
          (c = 32) (pins st 'play !(st 'play) 'due 0)
          (c = 46) (frame 1) (c = 44) (frame -1)
          (pin st 'msg picless-help)))
   ; the clock moves a playing gif on: 1 when the frame changed
   (pv-tick st now)
    (: nf (pv-nf st)
       (? ((nf < 2) || !(st 'play)) 0
          (st 'due = 0) (: _ (pin st 'due (now + ((st 'im) 2 (st 'f) 1))) 0)
          (now < st 'due) 0
          (: f ((st 'f + 1) % nf)
             _ (pins st 'f f 'due (now + ((st 'im) 2 f 1)))
             1)))
   ; bytes off the keyboard -> key codes, the arrows as h j k l
   (pv-keys ks)
    (: n #ks
       (go i acc)
        (? (n <= i) (rev acc)
           ((ks i = 27) && ((i + 2) < n) && (ks (i + 1) = 91))
            (: f (ks (i + 2))
               (go (i + 3) (? (f = 65) (107 . acc) (f = 66) (106 . acc) (f = 67) (108 . acc)
                              (f = 68) (104 . acc) acc)))
           (ks i = 27) (go (i + 1) acc)
           (go (i + 1) (ks i . acc)))
       (go 0 ()))
   (picless-main as)
    (: fs as
       _ (? (two? fs) () (udie 2 picless-usage))
       ws (tty 1)
       _ (? (two? ws) () (udie 2 "picless: not a terminal"))
       hw (pgwin ws)
       st (pv-new fs <hw <>hw)
       b (cask 64) e (string 27)
       _ (raw 1)
       _ (puts (e + "[?1049h" + e + "[?25l" + e + "[2J"))
       (fin _) (: _ (puts (e + "[0m" + e + "[?25h" + e + "[?1049l")) _ (flush out) _ (raw 0) 0)
       (go dirty)
        (: ws2 (tty 1) hw2 (? (two? ws2) (pgwin ws2) [(st 'h) (st 'w)])
           moved (!(<hw2 = st 'h) || !(<>hw2 = st 'w))
           _ (? moved (: _ (pins st 'h <hw2 'w <>hw2) (puts (e + "[2J"))) 0)
           _ (? (dirty || moved) (: _ (puts (pv-frame st)) (flush out)) 0)
           n (pic-swig in b)
           ks (? (charm? n && 0 < n) (pv-keys (snip (string b) 0 n)) ())
           _ (map (c \ pv-step st c) ks)
           (? (st 'quit) (fin ())
              (: t (pv-tick st (clock 0))
                 _ (? ((two? ks) || t) 0 (rest (? ((1 < pv-nf st) && (st 'play)) 15 50)))
                 (go ((two? ks) || t)))))
       (go 1)))
) ; module 'kore
