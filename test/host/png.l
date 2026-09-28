; --- test/host/png.l: apps/png.l and love/lib/png.c's unfilter --------------------------
; the nif and the walk on rows worked by hand: each filter, a bad filter byte, too few
; bytes. then, where python3 with PIL and magick are here, images of every colour type, grey
; at 1 to 16 bits, palettes of 1 to 8, colour keys, 16-bit and interlaced ones at a size
; that splits bytes and adam7 passes, each decoded and held to magick's own rgba byte for
; byte. last the refusals: not a png, a torn file, a flipped byte under a crc.
;   cat test/00-init.l test/host/png.l | out/love
(borrow 'posix)
(borrow "apps/png.l")
(: dir ((cwd 0) + "/out/.png")
   _ (hark ["rm" "-rf" dir]) _ (mkdir dir 448)
   (rd p) (: q (open p "r") s (slurp q) _ (close q) s)
   (put p s) (: q (open p "w") _ (say q s) (close q))
   (bytes l) (: c (cask #l) _ (map (i \ pin c i (l i)) (jot #l)) (string c))

   ; -- the nif --------------------------------------------------------------------------
   ; sub then paeth over the row above, then none, up and average, bpp 1 and 2
   r1 (png-unfilter (bytes [1 10 5 5  4 1 1 1]) 0 2 3 1)
   r2 (png-unfilter (bytes [9 9  0 7 8 9 250  2 1 1 1 10  3 2 2 2 2]) 2 3 4 2)
   ; the walk on the same rows, its filter bytes dropped after
   (walk l o rows n bpp)
    (: c (cask #l) _ (map (i \ pin c i (l i)) (jot #l))
       e (png-walk c o rows n bpp)
       (? (string? e) e
          (foldl (\ acc y (acc + snip (string c) (o + 1 + y * (n + 1)) (o + 1 + y * (n + 1) + n))) ""
                 (jot rows))))
   _ (test (r1 = bytes [10 15 20 11 16 21])
           (r2 = bytes [7 8 9 250  8 9 10 4  6 6 10 7])
           (walk [1 10 5 5  4 1 1 1] 0 2 3 1 = r1)
           (walk [9 9  0 7 8 9 250  2 1 1 1 10  3 2 2 2 2] 2 3 4 2 = r2)
           (walk [5 1 2 3] 0 1 3 1 = "bad filter")
           (png-unfilter (bytes [5 1 2 3]) 0 1 3 1 = ())
           (png-unfilter (bytes [0 1 2]) 0 1 3 1 = ())
           (png-unfilter "abc" 0 1 3 0 = ()))

   ; -- images against magick ------------------------------------------------------------
   (has p) (: q (open p "r") (? (hot? q) (close q, 1) 0))
   pil? (: r (hark ["python3" "-c" "import PIL"]) (two? r) && (<r = 0))
   ok? (pil? && has "/usr/bin/magick")
   _ (put (dir + "/mk.py") "import sys
from PIL import Image
d = sys.argv[1]
w, h = 37, 23
px = [((x * 7 + y * 3) % 256, (x * y) % 256, (255 - x * 5 - y) % 256) for y in range(h) for x in range(w)]
rgb = Image.new('RGB', (w, h)); rgb.putdata(px)
rgba = Image.new('RGBA', (w, h)); rgba.putdata([p + ((p[0] + p[1]) % 256,) for p in px])
L = rgb.convert('L')
L.convert('1').save(d + '/g1.png')
L.save(d + '/g8.png')
L.save(d + '/g8t.png', transparency=L.getpixel((3, 3)))
Image.merge('LA', (L, rgba.getchannel('A'))).save(d + '/ga8.png')
rgb.save(d + '/c8.png')
rgb.save(d + '/c8t.png', transparency=rgb.getpixel((3, 3)))
rgba.save(d + '/ca8.png')
for n in (2, 4, 16, 256):
    p = rgb.quantize(n)
    p.save(d + '/p%d.png' % n, bits={2: 1, 4: 2, 16: 4, 256: 8}[n])
    p.save(d + '/p%dt.png' % n, bits={2: 1, 4: 2, 16: 4, 256: 8}[n], transparency=bytes(range(0, 256, 37)))
")
   (sh s) (hark ["sh" "-c" s])
   names ["g1" "g8" "g8t" "ga8" "c8" "c8t" "ca8" "p2" "p4" "p16" "p256" "p2t" "p4t" "p16t" "p256t"
          "g2" "g4" "g16" "c16" "ca16" "ga16" "ic8" "ica16" "ig1" "ip16"]
   _ (? ok?
        (: _ (sh ("python3 " + dir + "/mk.py " + dir))
           m ("cd " + dir + " && ")
           _ (sh (m + "magick g8.png -depth 16 -define png:bit-depth=16 g16.png"))
           ; the multiply keeps magick from writing a 16-bit image back down to 8
           x16 " -depth 16 -evaluate multiply 0.9973 "
           _ (sh (m + "magick c8.png" + x16 + "c16.png"))
           _ (sh (m + "magick ca8.png" + x16 + "ca16.png"))
           _ (sh (m + "magick ga8.png" + x16 + "ga16.png"))
           _ (sh (m + "magick ca8.png" + x16 + "-interlace PNG ica16.png"))
           _ (sh (m + "magick g8.png -depth 2 g2.png"))
           _ (sh (m + "magick g8.png -depth 4 g4.png"))
           _ (sh (m + "magick c8.png -interlace PNG ic8.png"))
           _ (sh (m + "magick g1.png -interlace PNG ig1.png"))
           _ (sh (m + "magick p16.png -interlace PNG ip16.png"))
           (one n) (: f (dir + "/" + n + ".png")
                      want (sh ("magick " + f + " -depth 8 rgba:-"))
                      got (png-decode (rd f))
                      (? ((two? want) && (<want = 0) && (two? got) && (got 0 = 37) && (got 1 = 23)
                          && (got 2 = >want))
                         1 (puts ("png: " + n + " differs from magick\n"), 0)))
           (test (filter (n \ !(one n)) names = ())))
        (puts "png: no python3 PIL or magick, images skipped\n"))

   ; -- refusals -------------------------------------------------------------------------
   good (? ok? (rd (dir + "/c8.png")) "")
   (flip s i) (: c (cask #s) _ (pour c 0 s 0 #s) _ (pin c i (255 - s i)) (string c))
   _ (test (png-decode "GIF89a" = "not a png")
           (? ok? ((png-decode (snip good 0 (#good - 20))) = "truncated") 1)
           (? ok? ((png-decode (flip good (#good - 30))) = "bad crc in IDAT") 1)
           (? ok? ((png-decode (flip good 20)) = "bad crc in IHDR") 1))
   _ (hark ["rm" "-rf" dir])
   0)

(test_fin (), puts "png: ok", putc 10, 0)
