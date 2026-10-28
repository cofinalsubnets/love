; src/apps/kore/im.l -- pictures on a terminal and between formats: png, jpeg, gif, webp,
; bmp, ico, netpbm's and qoi read (src/apps/png.l, jpeg.l, gif.l, webp.l, bmp.l, pnm.l, qoi.l);
; png, jpeg, gif, webp (lossless), qoi, ppm, pam and sixel written.
; the default draw is blocks, two pixels a cell (▀ fg over bg), 24-bit where COLORTERM says so,
; else the 256-colour cube; never enlarged. convert keeps a gif's first frame.
; www draws a page's pictures through im-art too.
(module 'kore
(borrow 'cli)
(borrow 'posix)
(borrow 'jpeg)

(:
   im-usage (cats ["usage: im [cat] [-g block|sixel|kitty|auto] [-w COLS] [-h ROWS] [FILE..]\n"
                    "       im less [-g block|sixel|kitty|auto] FILE..\n"
                    "       im convert [-q QUALITY] [-t png|gif|jpeg|webp|qoi|ppm|pam|sixel|ans] IN OUT\n"
                    "       im pixelize [-w COLS] [-h ROWS] [-s PX] [-c 256] [-q QUALITY] [-t TYPE] IN OUT"])
   imless-usage "usage: im less [-g block|sixel|kitty|auto] FILE.."
   im-swig (cite 'posix 'swig)
   imless-help "q quit  + - zoom  0 fit  hjkl/arrows pan  n p file  space play  , . frame"

   ; -- reading -----------------------------------------------------------------
   (im-le16 b i) (b i + 256 * b (i + 1))
   (im-be32 b i) (((b i * 256 + b (i + 1)) * 256 + b (i + 2)) * 256 + b (i + 3))
   ; bytes -> 'png 'jpeg 'gif 'webp 'bmp 'ico 'pnm 'qoi | ()
   (im-kind b)
    (? !(string? b && 8 <= #b) ()
       (snip b 1 4 = "PNG") 'png
       (b 0 = 255 && b 1 = 216) 'jpeg
       (snip b 0 4 = "GIF8") 'gif
       (12 <= #b && snip b 0 4 = "RIFF" && snip b 8 12 = "WEBP") 'webp
       (snip b 0 2 = "BM") 'bmp
       (b 0 = 0 && b 1 = 0 && (b 2 = 1 || b 2 = 2) && b 3 = 0 && 0 < b 4 + b 5) 'ico
       (b 0 = 80 && 49 <= b 1 <= 55 && elem (b 2) [9 10 13 32]) 'pnm
       (snip b 0 4 = "qoif") 'qoi
       ())
   ; -> [w h] off the header | why not
   (im-size b)
    (im-kind b @ k
       (? (k = 'png) (24 <= #b ? [(im-be32 b 16) (im-be32 b 20)] "cut short")
          (k = 'jpeg) (cite 'jpeg 'jpeg-size b)
          (k = 'gif) [(im-le16 b 6) (im-le16 b 8)]
          (k = 'webp) (cite 'webp 'webp-size b)
          (k = 'bmp) (cite 'bmp 'bmp-size b)
          (k = 'ico) (cite 'bmp 'ico-size b)
          (k = 'pnm) (cite 'pnm 'pnm-size b)
          (k = 'qoi) (cite 'qoi 'qoi-size b)
          "not a picture"))
   ; -> [w h rgba] | why not; a gif's or an animated webp's first frame, an apng's default image
   (im-decode b)
    (im-kind b @ k
       (? (k = 'png) (cite 'png 'png-decode b)
          (k = 'jpeg) (cite 'jpeg 'jpeg-decode b)
          (k = 'gif) (cite 'gif 'gif-decode b)
          (k = 'webp) (cite 'webp 'webp-decode b)
          (k = 'bmp) (cite 'bmp 'bmp-decode b)
          (k = 'ico) (cite 'bmp 'ico-decode b)
          (k = 'pnm) (cite 'pnm 'pnm-decode b)
          (k = 'qoi) (cite 'qoi 'qoi-decode b)
          "not a picture"))
   ; -> [w h [[rgba ms] ..]] | why not: a gif's or a webp's frames, as many as fit 128 MB, and
   ; a still one frame of no time
   (im-frames b)
    (: k (im-kind b) d (im-size b) most (string? d ? 1 (max 1 (min 1000 (33554432 // max 1 (d 0 * d 1)))))
       (? (string? d) d
          (k = 'gif) (cite 'gif 'gif-frames b most)
          (k = 'webp) (cite 'webp 'webp-frames b most)
          (k = 'png) (cite 'png 'png-frames b most)
          (im-decode b @ r (two? r ? [(r 0) (r 1) [[(r 2) 0]]] r))))

   ; -- sampling ----------------------------------------------------------------
   ; ow*oh pixels from source x0 y0, s source pixels to each -> [ow oh rgba]. a pixel is its
   ; box's mean over four samples weighted by alpha, so a see-through sample does not darken it
   (im-sample im x0 y0 s ow oh)
    (: w (im 0) h (im 1) px (im 2) c (cask (4 * ow * oh))
       (at x y) (4 * (y * w + x) @ i [(peep px i 0) (peep px (i + 1) 0) (peep px (i + 2) 0) (peep px (i + 3) 0)])
       (on v n) (0 <= v < n)
       (pix x y o)
        (!(on (x0 + (x + 0.5) * s) w) || !(on (y0 + (y + 0.5) * s) h) ? 0
         (: xs (map (f \ max 0 (min (w - 1) (int (x0 + (x + f) * s)))) [0.25 0.75])
            ys (map (f \ max 0 (min (h - 1) (int (y0 + (y + f) * s)))) [0.25 0.75])
            ss (foldl (\ acc a (foldl (\ acc b ((at a b) . acc)) acc ys)) () xs)
            a +(map (p \ p 3) ss)
            (ch k) ((+(map (p \ p k * p 3) ss)) // a)
            (a < 512 ? 0 (pins c o (ch 0) (o + 1) (ch 1) (o + 2) (ch 2) (o + 3) 255))))
       (map (y \ map (x \ pix x y (4 * (y * ow + x))) ^ow) ^oh,
        [ow oh (string c)]))
   ; the same box by nearest pixel, alpha kept: quick enough to redraw a screen of pixels
   (im-near im x0 y0 s ow oh)
    (: w (im 0) h (im 1) px (im 2) c (cask (4 * ow * oh))
       sx (map (x \ 4 * max 0 (min (w - 1) (int (x0 + (x + 0.5) * s)))) ^ow)
       (row y) (4 * w * max 0 (min (h - 1) (int (y0 + (y + 0.5) * s))) @ b
                  (foldl (\ o x (pour c o px (b + x) 4, o + 4)) (4 * ow * y) sx))
       (map row ^oh,
        [ow oh (string c)]))
   ; the scale that fits a picture in cols by rows cells, never enlarging it; rows () is
   ; no limit
   (im-fit im cols rows)
    (max 1.0 (max (im 0 / cols) (!rows ? 0 (im 1 / (2 * rows)))))

   ; -- blocks ------------------------------------------------------------------
   ; a colour as sgr: 24-bit when deep, else the 256-colour cube
   (im-deep _) (getenv "COLORTERM" @ ct (string? ct && (ct = "truecolor" || ct = "24bit")))
   (im-sgr deep fg c)
    (deep ? "\(fg ? "38;2;" "48;2;")\(c 0);\(c 1);\(c 2)"
       (: (q v) ((v * 5 + 127) // 255)
          "\(fg ? "38;5;" "48;5;")\(16 + 36 * q (c 0) + 6 * q (c 1) + q (c 2))"))
   ; a sampled picture as rows of cells, two pixels to each
   (im-cells sm deep)
    (: ow (sm 0) oh (sm 1) px (sm 2)
       (pix x y) (4 * (y * ow + x) @ o
                    (oh <= y || px (o + 3) = 0 ? () [(px o) (px (o + 1)) (px (o + 2))]))
       (sg fg c) "\e[\(im-sgr deep fg c)m"
       (cell t b) (? (!t && !b) "\e[0m "
                     !b "\e[0m\(sg 1 t)▀"
                     !t "\e[0m\(sg 1 b)▄"
                     "\(sg 1 t)\(sg 0 b)▀")
       (row r) (jug 0 @ o
                  (map (x \ say o (cell (pix x (2 * r)) (pix x (2 * r + 1)))) ^ow,
                   "\(slurp o)\e[0m"))
       (map row ^((oh + 1) // 2)))
   (im-view im x0 y0 s ow oh deep) (im-cells (im-sample im x0 y0 s ow oh) deep)
   ; the blocks as text, a line a row
   (im-ans im cols rows deep) (cats (map (r \ "\(r)\n") (im-art im cols rows deep)))
   ; a picture as rows of cells at most cols wide and rows tall
   (im-art im cols rows deep)
    (im-fit im cols rows @ s
       (im-view im 0 0 s (max 1 (int (im 0 / s))) (max 1 (int (im 1 / s))) deep))

   ; -- graphics: sixel and kitty's -----------------------------------------------
   ; one sixel string, gif's palette (exact to 255 colours, median cut past); idx is each
   ; pixel's register plus one, 0 clear; a pixel under half alpha is left to the ground
   (im-sixel im)
    (: w (im 0) h (im 1) px (im 2) n (w * h)
       key (cite 'gif 'gif-key)
       pal (cite 'gif 'gif-palette px n 255)
       cols (pal 0) ix (pal 1) f (pal 2)
       idx (cask n)
       _ (map (i \ (f (key px (4 * i)) @ k (pin idx i (k < 0 ? 0 (1 + peep ix k 0))))) ^n)
       (pct v) ((v * 100 + 127) // 255)
       (colour i) (cols i @ c
                     "#\(i);2;\(pct (c >> 16 & 255));\(pct (c >> 8 & 255));\(pct (c & 255))")
       (run v k) (string (63 + v) @ ch (3 < k ? "!\(k)\(ch)" (catmap (_ \ ch) ^k)))
       (rle m lo hi)
        (: o (jug 0)
           _ (0 < lo ? (say o (run 0 lo)) 0)
           (go x v k) (hi < x ? (say o (run v k), slurp o)
                       (peep m x 0 @ b
                          (b = v ? (go (x + 1) v (k + 1)) (say o (run v k), go (x + 1) b 1))))
           (go (lo + 1) (peep m lo 0) 1))
       (band y0)
        (: t {} lo {} hi {} ys (map (r \ y0 + r) ^(min 6 (h - y0)))
           (dot x y) (peep idx (y * w + x) 0 @ c
                        (!c ? 0
                           (: m (t c)
                              m2 (m = () ? (cask w @ k
                                              (pin t c k, pin lo c x, k)) m)
                              (pin m2 x (peep m2 x 0 | 1 << y - y0), pin hi c x))))
           (map (x \ map (y \ dot x y) ys) ^w,
            "\(ujoinc 36 (map (c \ "#\(c - 1)\(rle (t c) (lo c) (hi c))") (sort (keys t))))-"))
       ("\eP0;1;0q\"1;1;\(w);\(h)"
        + catmap colour ^#cols
        + catmap (b \ band (6 * b)) ^((h + 5) // 6)
        + "\e\\"))
   ; a picture through kitty's protocol: raw rgba placed at the cursor, 4096 bytes of
   ; base64 a chunk, no answer asked for
   (im-kitty im) (im-kits im "")
   ; ..with more keys on the first chunk, each "k=v,"
   (im-kits im keys)
    (: b (ubenc ub64set 6 (im 2)) n #b o (jug 0)
       (go i) (: j (min n (i + 4096)) m (j < n ? "1" "0")
                 (say o "\e_G\(i = 0 ? "a=T,f=32,q=2,\(keys)s=\(im 0),v=\(im 1)," "")m=\(m);\(snip b i j)\e\\",
                  j < n ? (go j) (slurp o)))
       (go 0))
   ; what im asks a terminal: kitty's query and the cell size, then DA1, which every
   ; terminal answers and so ends the wait
   im-ask "\e_Gi=31,s=1,v=1,a=q,t=d,f=24;AAAA\e\\\e[16t\e[c"
   (im-digits s i) (: (go i v) (#s <= i || !(47 < s i < 58) ? v (go (i + 1) (v * 10 + s i - 48))) (go i 0))
   (im-past s i) (#s <= i || !(47 < s i < 58) ? i (im-past s (i + 1)))
   ; DA1's answer in s as ";p;..;p;", or "" before it is whole
   (im-da s)
    (: i (fsub s "\e[?" 0)
       (go j) (? (i < 0 || #s <= j) "" (s j = 99) ";\(snip s (i + 3) j);"
                 (s j = 59 || 47 < s j < 58) (go (j + 1)) "")
       (go (i + 3)))
   ; the answers to im-ask -> {'kitty 'sixel 'cw 'ch}, cw and ch 0 when not said
   (im-heard s)
    (fsub s "\e[6;" 0 @ c
       {'kitty (0 <= fsub s "\e_Gi=31;OK" 0)
        'sixel (0 <= fsub (im-da s) ";4;" 0)
        'ch (c < 0 ? 0 (im-digits s (c + 4)))
        'cw (c < 0 ? 0 (im-digits s (im-past s (c + 4) + 1)))})
   ; the terminal on stdin and stdout asked, raw for at most a second
   (im-probe _)
    (!(two? (tty 0) && two? (tty 1)) ? (im-heard "")
       (: b (cask 256)
          _ (raw 1)
          _ (puts im-ask)
          _ (flush out)
          t0 (clock 0)
          (go acc) (: k (im-swig in b) s (acc + (charm? k && 0 < k ? (snip (string b) 0 k) ""))
                      (0 < #(im-da s) || 1000 < clock 0 - t0 ? s (rest 10, go s)))
          s (go "")
          (raw 0,
           im-heard s)))
   ; a picture sized for cols by rows cells of cw by ch pixels, never enlarged
   (im-px im cols rows cw ch)
    (max 1.0 (max (im 0 / (cols * cw)) (!rows ? 0 (im 1 / (rows * ch)))) @ s
       (s = 1.0 ? im (im-sample im 0 0 s (max 1 (int (im 0 / s))) (max 1 (int (im 1 / s))))))

   ; -- files -------------------------------------------------------------------
   ; a name's picture type by its extension | ()
   (im-type nm)
    (: (dot i) (? (i < 0) -1 (nm i = 46) i (dot (i - 1)))
       x (wg-lower (snip nm (dot (#nm - 1) + 1) #nm))
       (x @ "png" 'png "gif" 'gif "jpg" 'jpeg "jpeg" 'jpeg "webp" 'webp "qoi" 'qoi "ppm" 'ppm "pnm" 'ppm "pam" 'pam "six" 'sixel
            "sixel" 'sixel "ans" 'ans ()))
   ; -> the picture's bytes as ty | why not
   (im-encode ty im q)
    (? (ty = 'png) (cite 'png 'png-encode (im 0) (im 1) (im 2))
       (ty = 'gif) (cite 'gif 'gif-encode (im 0) (im 1) (im 2))
       (ty = 'jpeg) (jpeg-encode (im 0) (im 1) (im 2) q @ r (string? r ? r "cannot encode a jpeg"))
       (ty = 'webp) (cite 'webp 'webp-encode (im 0) (im 1) (im 2) @ r (string? r ? r "cannot encode a webp"))
       (ty = 'qoi) (cite 'qoi 'qoi-encode (im 0) (im 1) (im 2) @ r (string? r ? r "cannot encode a qoi"))
       (ty = 'ppm) (cite 'pnm 'pnm-encode (im 0) (im 1) (im 2))
       (ty = 'pam) (cite 'pnm 'pam-encode (im 0) (im 1) (im 2))
       (ty = 'sixel) (im-sixel im)
       "no such type")
   (im-in who p)
    (p = "-" ? (slurp in)
     (uread p @ r (two? r ? <>r (udie 1 "\(who): cannot open \(p)"))))
   (im-out who p b)
    (? (p = "-") (say out b, flush out, 0)
       (uwrite p b) 0
       (udie 1 "\(who): cannot write \(p)"))
   ; the type of the -t value or the out file's name, or leave
   (im-otype who t p dflt)
    (: v (uoptv t 116) ty (string? v ? (im-type ".\(v)") (im-type p))
       (? (ty != ()) ty (dflt != () && !(string? v)) dflt
          (udie 2 "\(who): \(string? v ? "no type \(v)" "no type for \(p)"); png gif jpeg webp qoi ppm pam sixel or ans")))
   (im-num t k d) (uoptv t k @ v (string? v ? (uatoi v @ n (0 < n ? n d)) d))
   (im-decoded who nm b)
    (im-decode b @ im (two? im ? im (udie 1 "\(who): \(nm): \(im)")))

   ; -- the verbs ---------------------------------------------------------------
   (im-main as)
    (<as @ "cat" (im-cat >as)
           "less" (imless-main >as)
           "convert" (im-convert >as)
           "pixelize" (im-pixelize >as)
           "help" (say out "\(im-usage)\n", 0)
           (im-cat as))
   ; -g's mode, block when unsaid; auto taken by what the terminal answered
   (im-mode who t)
    (: v (uoptv t 103) g (string? v ? v "block")
       (elem g ["auto" "block" "sixel" "kitty"] ? g (udie 2 "\(who): no mode \(g); block sixel kitty or auto")))
   (im-pick g pr) (? (g != "auto") g (pr 'kitty) "kitty" (pr 'sixel) "sixel" "block")
   (im-cat as)
    (: fo (uflags "im" as [103 104 119] "ghw")
       t (fo 0) fs (fo 1)
       ws (tty 1)
       cols (im-num t 119 (two? ws && 0 < >ws ? >ws 80))
       rows (im-num t 104 ())
       g (im-mode "im" t)
       pr (g = "block" || !(two? ws) ? (im-heard "") (im-probe 0))
       mode (im-pick g pr)
       cw (0 < pr 'cw ? (pr 'cw) 8) ch (0 < pr 'ch ? (pr 'ch) 16)
       deep (im-deep 0)
       (draw im)
        (mode @ "sixel" (say out (im-sixel (im-px im cols rows cw ch)))
                "kitty" (say out "\(im-kitty (im-px im cols rows cw ch))\n")
                (map (r \ puts "\(r)\n") (im-art im cols rows deep)))
       (one nm b)
        (im-decode b @ im
           (two? im ? (1 < #fs ? (puts "\(nm):\n") 0, draw im, flush out, 0)
            (say err "im: \(nm): \(im)", put err 10, 1)))
       (two? fs ?
           (foldl (\ a f (: r (uread f)
                            x (two? r ? (one f <>r)
                               (say err "im: cannot open \(f)", put err 10, 1))
                            (a || x ? 1 0)))
                  0 fs)
          (one "stdin" (slurp in))))
   (im-convert as)
    (: who "im convert"
       fo (uflags who as [113 116] "qt")
       t (fo 0) ops (fo 1)
       _ (#ops = 2 ? () (udie 2 im-usage))
       ty (im-otype who t (ops 1) ())
       b (im-in who (ops 0))
       ; a file already of the type goes across as it is, a gif's frames with it
       (im-out who (ops 1)
                (? (im-kind b = ty && !(string? (uoptv t 113))) b
                   (ty = 'ans) (im-ans (im-decoded who (ops 0) b) 80 () 1)
                   (im-encode ty (im-decoded who (ops 0) b) (im-num t 113 90) @ r
                      (string? r ? r (udie 1 "\(who): \(r)"))))))
   (im-pixelize as)
    (: who "im pixelize"
       fo (uflags who as [99 104 113 115 116 119] "chqstw")
       t (fo 0) ops (fo 1)
       _ (#ops = 2 ? () (udie 2 im-usage))
       ty (im-otype who t (ops 1) 'png)
       c (uoptv t 99 @ v (string? v ? v "24"))
       _ (elem c ["24" "256"] ? () (udie 2 "\(who): -c is 24 or 256"))
       im (im-decoded who (ops 0) (im-in who (ops 0)))
       cols (im-num t 119 80) rows (im-num t 104 ())
       (im-out who (ops 1)
                (ty = 'ans ? (im-ans im cols rows (c = "24"))
                 (im-encode ty (im-blocky im cols rows (im-num t 115 0) (c = "24")) (im-num t 113 90)))))
   ; the picture as im-art draws it in cols by rows cells -> [w h rgba]: each pixel of the
   ; cells k pixels square (0: the source's own scale), a last odd row's lower half clear
   ; as the ground, and when not deep the colour the cube's level shows
   (im-blocky im cols rows k deep)
    (: s (im-fit im cols rows) sm (im-sample im 0 0 s (max 1 (int (im 0 / s))) (max 1 (int (im 1 / s))))
       ow (sm 0) oh (sm 1) px (sm 2)
       k2 (0 < k ? k (max 1 (int (s + 0.5))))
       W (ow * k2) oh2 (2 * ((oh + 1) // 2)) H (oh2 * k2)
       c (cask (4 * W * H))
       lv [0 95 135 175 215 255]
       (tone v) (deep ? v (lv ((v * 5 + 127) // 255)))
       (fill sy)
        (cask (4 * W) @ row
           ((oh <= sy ? 0 (map (x \ (: i (4 * (sy * ow + x)) o0 (4 * x * k2)
                  (map (d \ (o0 + 4 * d @ o
                               (px (i + 3) = 0 ? (pins row o 0 (o + 1) 0 (o + 2) 0 (o + 3) 0)
                                (pins row o (tone (px i)) (o + 1) (tone (px (i + 1)))
                                      (o + 2) (tone (px (i + 2))) (o + 3) 255))))
                       ^k2)))
          ^ow)),
            string row))
       (map (sy \ (fill sy @ r (map (d \ pour c (4 * W * (sy * k2 + d)) r 0 (4 * W)) ^k2)))
            ^oh2,
        [W H (string c)]))

   ; -- imless: the viewer -----------------------------------------------------------
   ; 'z the zoom over the fit, 'cx 'cy the view's centre in source pixels, 'rows the cache of
   ; drawn frames for the view 'ck, 'ux 'uy the pixels a cell holds
   (pv-new fs h w)
    (tablet 0 @ st
       (pins st 'fs fs 'i 0 'h h 'w w 'quit 0 'msg "" 'mode "block" 'ux 1 'uy 2,
        pv-load st))
   (pv-load st)
    (: nm (st 'fs (st 'i))
       r (uread nm)
       im (two? r ? (im-frames <>r) "cannot open")
       ok (two? im)
       (pins st 'im im 'f 0 'z 1.0 'play 1 'due 0 'rows {} 'ck ()
                'cx (ok ? (im 0 / 2) 0) 'cy (ok ? (im 1 / 2) 0)))
   (pv-nf st) (st 'im @ im (two? im ? #(im 2) 0))
   ; [s x0 y0 ow oh left top]: scale, source origin, output pixels, centring margin. a sixel
   ; is whole bands of 6, lest its last spill onto the status line and scroll
   (pv-view st)
    (: im (st 'im) w (im 0) h (im 1) cols (st 'w) rows (st 'h - 1) ux (st 'ux) uy (st 'uy)
       pw (cols * ux) ph (rows * uy @ p (st 'mode = "sixel" ? (6 * (p // 6)) p))
       s (max 1.0 (max (w / pw) (h / ph)) / st 'z)
       vw (pw * s) vh (ph * s)
       (axis c n v) (n <= v ? 0 (max 0 (min (n - v) (c - v / 2))))
       x0 (axis (st 'cx) w vw) y0 (axis (st 'cy) h vh)
       _ (vw < w ? (pin st 'cx (x0 + vw / 2)) 0)
       _ (vh < h ? (pin st 'cy (y0 + vh / 2)) 0)
       ow (max 1 (min pw (int ((w - x0) / s))))
       oh (max 1 (min ph (int ((h - y0) / s))))
       [s x0 y0 ow oh ((cols - (ow + ux - 1) // ux) // 2) ((rows - (oh + uy - 1) // uy) // 2)])
   ; the status line: the file's own name, not its path, and what it is
   (pv-status st)
    (: im (st 'im) path (st 'fs (st 'i)) nf (pv-nf st)
       nm (: (go i) (? (i < 0) path (path i = 47) (snip path (i + 1) #path) (go (i - 1)))
             (go (#path - 1)))
       tag (1 < #(st 'fs) ? "  [\(st 'i + 1)/\(#(st 'fs))]" "")
       (? (st 'msg = imless-help) imless-help
          (atom? im) "\(nm): \(im)\(tag)"
          (pv-view st @ v
             ("\(nm)\(tag)  \(im 0)x\(im 1)  \(int (100 / v 0 + 0.5))%"
              + (1 < nf ? "  frame \(st 'f + 1)/\(nf)\(st 'play ? "" " (paused)")" "")
              + (0 < #(st 'msg) ? "  \(st 'msg)" "  (? for keys)")))))
   pv-unkit "\e_Ga=d,d=a,q=2\e\\"
   ; the whole screen as one string, the frame drawn once per view
   (pv-frame st)
    (: im (st 'im) rows (st 'h - 1)
       (at r) "\e[\(r + 1);1H"
       body
        (atom? im ? (catmap (r \ "\(at r)\e[K") ^rows)
         (: v (pv-view st) ck [(v 0) (v 1) (v 2) (v 3) (v 4) (st 'w) (st 'h)]
            _ (ck = st 'ck ? 0 (pins st 'ck ck 'rows {}))
            f (st 'f)
            fr [(im 0) (im 1) (im 2 f 0)] mode (st 'mode)
            (draw _)
             (mode = "block" ? (im-view fr (v 1) (v 2) (v 0) (v 3) (v 4) (im-deep 0))
              (im-near fr (v 1) (v 2) (v 0) (v 3) (v 4) @ px
                 (mode = "sixel" ? (im-sixel px) (im-kits px "C=1,"))))
            drawn (peep (st 'rows) f () @ d
                     (d = () ? (draw 0 @ d2
                                  (pin (st 'rows) f d2, d2)) d))
            pad (catmap (_ \ " ") ^(v 5)) top (v 6)
            (mode = "block" ?
                (catmap (r \ "\(at r)\(top <= r < top + #drawn ? (pad + drawn (r - top)) "")\e[K") ^rows)
               ; the rows cleared, kitty's pictures let go, then the picture at its corner
               (catmap (r \ "\(at r)\e[K") ^rows
                + (mode = "kitty" ? pv-unkit "")
                + "\e[\(top + 1);\(v 5 + 1)H\(drawn)"))))
       line (pv-status st @ s (st 'w < #s ? (snip s 0 (st 'w)) s))
       (body + "\(at rows)\e[7m\(line)\e[0m\e[K"))
   ; one key. panning moves a quarter of the view
   (pv-step st c)
    (: im (st 'im) ok (two? im) nf (pv-nf st)
       v (ok ? (pv-view st))
       (pan dx dy) (ok ? (pins st 'cx (st 'cx + (dx * v 0 * st 'w * st 'ux) / 4)
                                  'cy (st 'cy + (dy * v 0 * (st 'h - 1) * st 'uy) / 4)) 0)
       (file k) (#(st 'fs) @ n
                   (pin st 'i (((st 'i + k) % n + n) % n), pv-load st))
       (frame k) (1 < nf ? (pins st 'play 0 'f (((st 'f + k) % nf + nf) % nf)) 0)
       (pin st 'msg "",
        (? (c = 113 || c = 81) (pin st 'quit 1)
           (c = 43 || c = 61) (pin st 'z (min 64 (st 'z * 1.5)))
           (c = 45 || c = 95) (pin st 'z (max 0.125 (st 'z / 1.5)))
           (c = 48 || c = 102) (pins st 'z 1.0 'cx (ok ? (im 0 / 2) 0) 'cy (ok ? (im 1 / 2) 0))
           (c = 104) (pan -1 0) (c = 108) (pan 1 0)
           (c = 107) (pan 0 -1) (c = 106) (pan 0 1)
           (c = 110 || c = 32 && nf < 2) (file 1)
           (c = 112 || c = 78) (file -1)
           (c = 32) (pins st 'play !(st 'play) 'due 0)
           (c = 46) (frame 1) (c = 44) (frame -1)
           (pin st 'msg imless-help))))
   ; the clock moves a playing animation on: 1 when the frame changed
   (pv-tick st now)
    (pv-nf st @ nf
       (? (nf < 2 || !(st 'play)) 0
          (st 'due = 0) (pin st 'due (now + st 'im 2 (st 'f) 1), 0)
          (now < st 'due) 0
          ((st 'f + 1) % nf @ f
             (pins st 'f f 'due (now + st 'im 2 f 1),
              1))))
   ; bytes off the keyboard -> key codes, the arrows as h j k l
   (pv-keys ks)
    (: n #ks
       (go i acc)
        (? (n <= i) (rev acc)
           (ks i = 27 && i + 2 < n && ks (i + 1) = 91)
            (ks (i + 2) @ f
               (go (i + 3) (? (f = 65) (107 . acc) (f = 66) (106 . acc) (f = 67) (108 . acc)
                              (f = 68) (104 . acc) acc)))
           (ks i = 27) (go (i + 1) acc)
           (go (i + 1) (ks i . acc)))
       (go 0 ()))
   (imless-main as)
    (: fo (uflags "im less" as [103] "g")
       fs (fo 1)
       _ (two? fs ? () (udie 2 imless-usage))
       g (im-mode "im less" (fo 0))
       _ (two? (tty 1) ? () (udie 2 "im less: not a terminal"))
       hw (ttysize 0 0)
       st (pv-new fs <hw <>hw)
       pr (g = "block" ? (im-heard "") (im-probe 0))
       mode (im-pick g pr)
       _ (mode = "block" ? 0
          (pins st 'mode mode 'ux (0 < pr 'cw ? (pr 'cw) 8) 'uy (0 < pr 'ch ? (pr 'ch) 16)))
       b (cask 64)
       (go dirty)
        (: hw2 (ttysize 0 0)
           moved (!(<hw2 = st 'h) || !(<>hw2 = st 'w))
           _ (moved ? (pins st 'h <hw2 'w <>hw2, puts "\e[2J") 0)
           _ (dirty || moved ? (puts (pv-frame st), flush out) 0)
           n (im-swig in b)
           ks (charm? n && 0 < n ? (pv-keys (snip (string b) 0 n)))
           (map (c \ pv-step st c) ks,
            (st 'quit ? 0
             (pv-tick st (clock 0) @ t
                (two? ks || t ? 0 (rest (1 < pv-nf st && st 'play ? 15 50)),
                 go (two? ks || t))))))
       (ttytake ['hide], mind go 1 (_ \ (mode = "kitty" ? (puts pv-unkit) 0, ttygive ['hide])), 0)))
) ; module 'kore
