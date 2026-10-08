; test/host/imgenc.l -- gif.l (one frame, and a run of them), png.l's png-encode and jpeg.c's jpeg-encode over a checker, a keyed
; run, one pixel, noise that refills lzw's table, and a gradient the median cut must choose among.
; each png reads back exact. where magick is here, gifs are held to the source (exact to 256
; colours), and jpegs near it; without magick, the markers alone.
; run: cat test/00-init.l test/host/imgenc.l | out/love
(borrow 'posix)
(borrow 'jpeg)
(borrow "src/apps/gif.l")
(borrow "src/apps/png.l")
(: dir (cwd 0 + "/out/.imgenc")
   _ (hark ["rm" "-rf" dir], mkdir dir 448)
   (put p s) (open p "w" @ q (say q s, close q))
   ; a w*h image from f x y -> [r g b a]
   (image w h f)
    (cask (4 * w * h) @ c
     (map (i \ (: p (f (i % w) (i // w)) o (4 * i)
                  (pins c o (p 0) (o + 1) (p 1) (o + 2) (p 2) (o + 3) (p 3))))
          (jot (w * h)),
      [w h (string c)]))
   checker (image 5 3 (x \ y \ ((x + y) % 2 ? [255 255 255 255] [0 0 0 255])))
   keyed (image 9 4 (x \ y \ (? (x < 3) [0 0 0 0] (y = 1) [200 30 40 255] [10 90 250 255])))
   dot (image 1 1 (x \ y \ [7 8 9 255]))
   noise (image 160 120 (x \ y \ ((y * 160 + x) * 2654435761 >> 7 & 255 @ v
                                    [v (255 - v) (v // 2) 255])))
   grad (image 64 48 (x \ y \ [(x * 4) (y * 5) ((x + y) * 2) 255]))

   ; -- markers, and the refusals -------------------------------------------------------
   (gif im) (gif-encode (im 0) (im 1) (im 2))
   (jpeg im q) (jpeg-encode (im 0) (im 1) (im 2) q)
   (png im) (png-encode (im 0) (im 1) (im 2))
   (has s p) (#p @ n (: (go i) (? (#s - n < i) 0 (snip s i (i + n) = p) 1 (go (i + 1))) (go 0)))
   (ends s a z) (snip s 0 #a = a && snip s (#s - #z) #s = z)
   soi (string 255 + string 216)
   eoi (string 255 + string 217)
   _ (test (ends (gif checker) "GIF89a" ";") (ends (gif dot) "GIF89a" ";")
           (ends (jpeg grad 90) soi eoi) (ends (jpeg grad 1) soi eoi) (ends (jpeg grad 100) soi eoi)
           (jpeg-encode 64 48 "short" 90 = ()) (jpeg-encode 64 48 (grad 2) 0 = ())
           (jpeg-encode 0 48 (grad 2) 90 = ()) (jpeg-encode 64 48 (grad 2) 101 = ()))
   _ (test (ends (png dot) "\x89PNG\r\n\x1a\n" "IEND\xaeB`\x82")
           (png-decode (png checker) = checker) (png-decode (png keyed) = keyed)
           (png-decode (png dot) = dot) (png-decode (png noise) = noise) (png-decode (png grad) = grad)
           ; depth and colour type: two colours a 1-bit palette, 256 an 8-bit one, past that rgba
           (png checker 24 = 1) (png checker 25 = 3) (png noise 24 = 8) (png noise 25 = 3)
           (png grad 25 = 6) (has (png keyed) "tRNS") !(has (png checker) "tRNS"))

   ; -- a run of frames: gif-anim, read back by gif-frames -- each as given, its delay kept
   flip (image 9 4 (x \ y \ ((x + y) % 2 ? [255 255 255 255] [0 0 0 255])))
   one (image 9 4 (x \ y \ [7 8 9 255]))
   run [[keyed 100] [flip 250] [one 40] [keyed 30]]
   anim (gif-anim 9 4 (map (f \ [(f 0 2) (f 1)]) run))
   got (gif-frames anim 10)
   _ (test (ends anim "GIF89a" ";") (has anim "NETSCAPE2.0")
           (got 0 = 9) (got 1 = 4) (#(got 2) = 4)
           ('(100 250 40 30) = map (f \ f 1) (got 2))
           (all (i \ got 2 i 0 = run i 0 2) ^4))

   ; -- against magick ------------------------------------------------------------------
   magick? (open "/usr/bin/magick" "r" @ q (hot? q ? (close q, 1) 0))
   ; decode a file with magick -> its rgba | ()
   (back f) (hark ["magick" f "-depth" "8" "rgba:-"] @ r (two? r && <r = 0 ? >r))
   ; the mean squared error of two rgba strings over r g b
   (mse a b) (: n (#a // 4)
                (go i acc) (? (i = #a) (acc / (3 * n))
                              (i % 4 = 3) (go (i + 1) acc)
                              (a i - b i @ d (go (i + 1) (acc + d * d))))
                (go 0 0))
   (round nm im)
    (dir + "/" + nm + ".gif" @ f (put f (gif im), back f))
   (pround nm im)
    (dir + "/" + nm + ".png" @ f (put f (png im), back f))
   (jround nm im q)
    (dir + "/" + nm + ".jpg" @ f (put f (jpeg im q), back f))
   ((magick? ?
       (: g1 (round "checker" checker) g2 (round "keyed" keyed) g3 (round "dot" dot)
          g4 (round "noise" noise) g5 (round "grad" grad)
          j1 (jround "grad90" grad 90) j2 (jround "noise90" noise 90) j3 (jround "grad20" grad 20)
          ; 3072 colours cut to 256 measure 35 db, a q90 jpeg 49 and a q20 one 34
          an (dir + "/anim.gif" @ f (put f anim, hark ["magick" "identify" "-format" "%T " f]))
          (test (two? an && <an = 0 && >an = "10 25 4 3 ")
                (g1 = checker 2) (g2 = keyed 2) (g3 = dot 2) (g4 = noise 2)
                (pround "keyed" keyed = keyed 2) (pround "dot" dot = dot 2)
                (pround "noise" noise = noise 2) (pround "grad" grad = grad 2)
                (string? g5) (#g5 = #(grad 2)) (mse g5 (grad 2) < 40)
                (string? j1) (#j1 = #(grad 2)) (mse j1 (grad 2) < 4)
                (string? j2) (#j2 = #(noise 2))
                (string? j3) (mse j1 (grad 2) < mse j3 (grad 2))))
       (gate-partly "imgenc: no magick, decodes skipped")),
    hark ["rm" "-rf" dir],
    0))

(test_fin (), puts "imgenc: ok", putc 10, 0)
