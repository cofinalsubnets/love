; --- test/host/imgenc.l: apps/gif.l and love/lib/jpeg.c's jpeg-encode ------------------
; images made here: a two-colour checker, a keyed one with a transparent run, one pixel,
; 256 colours of noise long enough to fill lzw's table past 4095 again and again, and a
; gradient of thousands that the median cut has to choose among. where magick is here each
; gif is decoded and held to the source -- exact up to 256 colours, near past them -- and
; each jpeg decoded at its size and near the source. without magick, the markers alone.
;   cat test/00-init.l test/host/imgenc.l | out/love
(borrow 'posix)
(borrow "apps/gif.l")
(: dir ((cwd 0) + "/out/.imgenc")
   _ (hark ["rm" "-rf" dir]) _ (mkdir dir 448)
   (put p s) (: q (open p "w") _ (say q s) (close q))
   ; a w*h image from f x y -> [r g b a]
   (image w h f)
    (: c (cask (4 * w * h))
       _ (map (i \ (: p (f (i % w) (i // w)) o (4 * i)
                      (pins c o (p 0) (o + 1) (p 1) (o + 2) (p 2) (o + 3) (p 3))))
              (jot (w * h)))
       [w h (string c)])
   checker (image 5 3 (\ x y (? ((x + y) % 2) [255 255 255 255] [0 0 0 255])))
   keyed (image 9 4 (\ x y (? (x < 3) [0 0 0 0] (y = 1) [200 30 40 255] [10 90 250 255])))
   dot (image 1 1 (\ x y [7 8 9 255]))
   noise (image 160 120 (\ x y (: v (((((y * 160) + x) * 2654435761) >> 7) & 255)
                                  [v (255 - v) (v // 2) 255])))
   grad (image 64 48 (\ x y [(x * 4) (y * 5) ((x + y) * 2) 255]))

   ; -- markers, and the refusals -------------------------------------------------------
   (gif im) (gif-encode (im 0) (im 1) (im 2))
   (jpeg im q) (jpeg-encode (im 0) (im 1) (im 2) q)
   (ends s a z) ((snip s 0 #a = a) && (snip s (#s - #z) #s = z))
   soi (string 255 + string 216)
   eoi (string 255 + string 217)
   _ (test (ends (gif checker) "GIF89a" ";") (ends (gif dot) "GIF89a" ";")
           (ends (jpeg grad 90) soi eoi) (ends (jpeg grad 1) soi eoi) (ends (jpeg grad 100) soi eoi)
           (jpeg-encode 64 48 "short" 90 = ()) (jpeg-encode 64 48 (grad 2) 0 = ())
           (jpeg-encode 0 48 (grad 2) 90 = ()) (jpeg-encode 64 48 (grad 2) 101 = ()))

   ; -- against magick ------------------------------------------------------------------
   magick? (: q (open "/usr/bin/magick" "r") (? (hot? q) (close q, 1) 0))
   ; decode a file with magick -> its rgba | ()
   (back f) (: r (hark ["magick" f "-depth" "8" "rgba:-"]) (? ((two? r) && (<r = 0)) >r ()))
   ; the mean squared error of two rgba strings over r g b
   (mse a b) (: n (#a // 4)
                (go i acc) (? (i = #a) (acc / (3 * n))
                              ((i % 4) = 3) (go (i + 1) acc)
                              (: d ((a i) - (b i)) (go (i + 1) (acc + (d * d)))))
                (go 0 0))
   (round nm im)
    (: f (dir + "/" + nm + ".gif") _ (put f (gif im)) (back f))
   (jround nm im q)
    (: f (dir + "/" + nm + ".jpg") _ (put f (jpeg im q)) (back f))
   _ (? magick?
        (: g1 (round "checker" checker) g2 (round "keyed" keyed) g3 (round "dot" dot)
           g4 (round "noise" noise) g5 (round "grad" grad)
           j1 (jround "grad90" grad 90) j2 (jround "noise90" noise 90) j3 (jround "grad20" grad 20)
           ; 3072 colours cut to 256 measure 35 db, a q90 jpeg 49 and a q20 one 34
           (test (g1 = checker 2) (g2 = keyed 2) (g3 = dot 2) (g4 = noise 2)
                 (string? g5) (#g5 = #(grad 2)) (mse g5 (grad 2) < 40)
                 (string? j1) (#j1 = #(grad 2)) (mse j1 (grad 2) < 4)
                 (string? j2) (#j2 = #(noise 2))
                 (string? j3) (mse j1 (grad 2) < mse j3 (grad 2))))
        (puts "imgenc: no magick, decodes skipped\n"))
   _ (hark ["rm" "-rf" dir])
   0)

(test_fin (), puts "imgenc: ok", putc 10, 0)
