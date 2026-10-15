; test/host/jpeg.l -- src/apps/jpeg.l and src/love/picture/jpeg.c's jpeg-pixels
; jpeg-encode's own output read back near its source, and the refusals; where magick is
; here, a picture written every way it writes one -- baseline and progressive, each
; sampling, grey, restart markers, one pixel -- and each decode held to magick's.
;   cat test/00-init.l test/host/jpeg.l | out/love
(borrow 'posix)
(borrow 'jpeg)
(borrow "src/apps/jpeg.l")
(: dir (cwd 0 + "/out/.jpegd")
   _ (hark ["rm" "-rf" dir], mkdir dir 448)
   (put p s) (open p "w" @ q (say q s, close q))
   (rd p) (: q (open p "r") s (slurp q) (close q, s))
   (image w h f)
    (cask (4 * w * h) @ c
     (map (i \ (: p (f (i % w) (i // w)) o (4 * i)
                  (pins c o (p 0) (o + 1) (p 1) (o + 2) (p 2) (o + 3) (p 3))))
          (jot (w * h)),
      [w h (string c)]))
   grad (image 64 48 (x \ y \ [(x * 4) (y * 5) ((x + y) * 2) 255]))
   odd (image 13 7 (x \ y \ [(x * 19) 200 (y * 36) 255]))
   noise (image 64 48 (x \ y \ ((y * 64 + x) * 2654435761 >> 7 & 255 @ v
                                  [v (255 - v) (v // 2) 255])))
   ; the mean squared error of two rgba strings over r g b
   (mse a b) (: n (#a // 4)
                (go i acc) (? (i = #a) (acc / (3 * n))
                              (i % 4 = 3) (go (i + 1) acc)
                              (a i - b i @ d (go (i + 1) (acc + d * d))))
                (go 0 0))
   (enc im q) (jpeg-encode (im 0) (im 1) (im 2) q)

   ; -- its own, and the refusals -------------------------------------------------------
   g95 (jpeg-decode (enc grad 95))
   o90 (jpeg-decode (enc odd 90))
   j (enc grad 90)
   jn (enc noise 90)
   _ (test (jpeg-size j = [64 48]) (jpeg-size (enc odd 50) = [13 7])
           (two? g95) (g95 0 = 64) (g95 1 = 48) (#(g95 2) = #(grad 2)) (mse (g95 2) (grad 2) < 4)
           (two? o90) (#(o90 2) = 13 * 7 * 4) (mse (o90 2) (odd 2) < 40)
           (g95 2 3 = 255)
           (jpeg-decode "hello" = "not a jpeg") (jpeg-size "hello" = "not a jpeg")
           (jpeg-decode (snip j 0 300) = "cut short")
           (jpeg-pixels (snip j 0 300) 1 = 2) (jpeg-pixels 7 1 = 1)
           ; the entropy data cut halfway still draws, the rest of it grey
           (2000 < #jn) (two? (jpeg-decode (snip jn 0 (#jn // 2)))))

   ; -- exif's orientation ----------------------------------------------------------------
   ; s with an app1 after its soi whose tiff header, mm or ii, says orientation o
   (exif s o mm)
    (: (w2 v) (mm ? [(v >> 8) (v & 255)] [(v & 255) (v >> 8)])
       (w4 v) (mm ? [0 0 (v >> 8) (v & 255)] [(v & 255) (v >> 8) 0 0])
       t (by ((mm ? [77 77] [73 73]) + w2 42 + w4 8 + w2 1 + w2 274 + w2 3 + w4 1 + w2 o + [0 0] + w4 0))
       (snip s 0 2 + seg 225 ("Exif\0\0" + t) + snip s 2 #s))
   ; the picture shown upright for o, from flips and a transpose: 6 turns it a quarter clockwise
   (pxat im x y) (snip (im 2) (4 * (y * im 0 + x)) (4 * (y * im 0 + x) + 4))
   (remap im w h f) [w h (cats (map (k \ f (k % w) (k // w)) (jot (w * h))))]
   (upright im o)
    (: w (im 0) h (im 1)
       (? (o = 2) (remap im w h (x \ y \ pxat im (w - 1 - x) y))
          (o = 3) (remap im w h (x \ y \ pxat im (w - 1 - x) (h - 1 - y)))
          (o = 4) (remap im w h (x \ y \ pxat im x (h - 1 - y)))
          (o = 5) (remap im h w (x \ y \ pxat im y x))
          (o = 6) (remap im h w (x \ y \ pxat im y (h - 1 - x)))
          (o = 7) (remap im h w (x \ y \ pxat im (w - 1 - y) (h - 1 - x)))
          (o = 8) (remap im h w (x \ y \ pxat im (w - 1 - y) x))
          im))
   jo (enc odd 90)
   base (jpeg-decode jo)
   os (map (+ 1) (jot 8))
   _ (test (jpeg-orient jo = 1)
           (atom? (filter (o \ !(jpeg-orient (exif jo o 1) = o && jpeg-orient (exif jo o 0) = o)) os))
           (atom? (filter (o \ !(jpeg-decode (exif jo o 1) = upright base o)) os))
           (atom? (filter (o \ !(jpeg-decode (exif jo o 0) = upright base o)) os))
           (jpeg-size (exif jo 6 1) = [7 13]) (jpeg-size (exif jo 3 0) = [13 7])
           ; no turn past 8, nor from a tiff header that is not one, nor from a cut app1
           (jpeg-orient (exif jo 9 1) = 1) (jpeg-decode (exif jo 9 1) = base)
           (jpeg-orient (snip (exif jo 6 1) 0 30) = 1)
           (jpeg-orient ((exif jo 6 1) @ x (snip x 0 12 + "XX" + snip x 14 #x)) = 1))

   ; ..held near PIL's own turn, four flat quarters at each orientation
   pil? (: r (hark ["python3" "-c" "import PIL"]) (two? r) && (<r = 0))
   _ (put (dir + "/or.py") "import sys
from PIL import Image, ImageOps
d = sys.argv[1]
im = Image.new('RGB', (40, 24))
im.putdata([((220, 30, 30), (30, 200, 30), (30, 30, 220), (230, 230, 230))[(x >= 20) + 2 * (y >= 12)]
            for y in range(24) for x in range(40)])
for o in range(1, 9):
    e = Image.Exif(); e[274] = o
    im.save('%s/or%d.jpg' % (d, o), quality=95, exif=e)
    open('%s/or%d.rgba' % (d, o), 'wb').write(ImageOps.exif_transpose(Image.open('%s/or%d.jpg' % (d, o))).convert('RGBA').tobytes())
")
   (near-pil o) (: s (jpeg-decode (rd (dir + "/or" + show o + ".jpg"))) r (rd (dir + "/or" + show o + ".rgba"))
                   (two? s && #(s 2) = #r && (o < 5 ? (s 0 = 40) (s 0 = 24)) && mse (s 2) r < 30))
   _ (pil? ? (: r (hark ["python3" (dir + "/or.py") dir]) (test (<r = 0) (atom? (filter (o \ !(near-pil o)) os))))
        (gate-partly "jpeg: no python3 PIL, its turns skipped"))

   ; -- against magick ------------------------------------------------------------------
   magick? (open "/usr/bin/magick" "r" @ q (hot? q ? (close q, 1) 0))
   src (dir + "/src.rgba")
   _ (put src (grad 2))
   ; grad written with magick's flags -> [ours magick's] | ()
   (both nm flags)
    (: f (dir + "/" + nm + ".jpg")
       r (hark (["magick" "-size" "64x48" "-depth" "8" ("rgba:" + src)] + flags + [f]))
       m (hark ["magick" f "-depth" "8" "rgba:-"])
       (two? m && <m = 0 ?
          (: q (open f "r") s (slurp q) _ (close q) d (jpeg-decode s)
             (two? d ? [(d 2) >m]))))
   (near nm flags lim) (both nm flags @ p (two? p ? (mse (p 0) (p 1) < lim) 0))
   _ (magick? ?
        (test (near "b420" ["-sampling-factor" "4:2:0"] 1)
              (near "b422" ["-sampling-factor" "4:2:2"] 1)
              (near "b444" ["-sampling-factor" "4:4:4" "-quality" "95"] 1)
              ; 4:1:1 upsampled linearly where libjpeg repeats the sample
              (near "b411" ["-sampling-factor" "4:1:1"] 30)
              (near "p420" ["-interlace" "JPEG"] 1)
              (near "p444" ["-interlace" "JPEG" "-sampling-factor" "4:4:4"] 1)
              (near "grey" ["-colorspace" "gray"] 1)
              (near "pgrey" ["-colorspace" "gray" "-interlace" "JPEG"] 1)
              (near "rst" ["-define" "jpeg:restart-interval=2"] 1)
              (near "prst" ["-define" "jpeg:restart-interval=1" "-interlace" "JPEG"] 1)
              (near "q10" ["-quality" "10"] 1)
              (near "one" ["-resize" "1x1!"] 1))
        (gate-partly "jpeg: no magick, decodes against it skipped"))
   ; scans that carry no data stop at once, and past a thousand scans the rest are left:
   ; 1100 empty dc scans over 2048x2048 once cost a whole frame walk each. then a dc scan
   ; shifted by 13 whose predictor climbs past what an int holds after the shift
   (by l) (cask #l @ c (map (i \ pin c i (l i)) (jot #l), string c))
   (seg m b) (by [255 m (#b + 2 >> 8) (#b + 2 & 255)] + b)
   (frame w h dc) (by [255 216] + seg 219 (by (0 . map (_ \ 1) (jot 64)))
                   + seg 194 (by [8 (h >> 8) (h & 255) (w >> 8) (w & 255) 1 1 17 0])
                   + seg 196 (by (0 . 1 . map (_ \ 0) (jot 15)) + by [dc]))
   (sos al) (seg 218 (by [1 1 0 0 0 al]))
   empty (frame 2048 2048 0 + cats (map (_ \ (sos 0)) (jot 1100)) + by [255 217])
   t0 (clock 0)
   e (jpeg-decode empty)
   ms (clock 0 - t0)
   ; each block: the one code, then 11 one bits, a dc step of 2047
   ones (cats (map (_ \ (by [127 247 255 0 127 247 255 0 127 247 255 0])) (jot 100)))
   hi (jpeg-decode (frame 1600 8 11 + sos 13 + ones + by [255 217]))
   (test (two? e) (e 0 = 2048) (e 2 0 = 128) (#(e 2) = 16777216)
         (ms < 5000)
         (two? hi) (hi 0 = 1600),
    hark ["rm" "-rf" dir],
    0))

(test_fin (), puts "jpeg: ok", putc 10, 0)
