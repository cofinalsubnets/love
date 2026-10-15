; test/host/qoi.l -- src/apps/qoi.l and src/love/picture/qoi.c
; seven pixels that take every op once -- rgb, a run, diff, luma, an index hit, rgba -- written
; to the bytes the spec gives and read back; pictures of each kind round trip exactly; where
; python3's PIL is, our files read in PIL as their source, PIL's read here the same, and our
; ops byte for byte PIL's own encoder's; last the refusals and flipped bytes.
;   cat test/00-init.l test/host/qoi.l | out/love
(borrow 'posix)
(borrow 'qoi)
(borrow "src/apps/qoi.l")
(: dir (cwd 0 + "/out/.qoid")
   _ (hark ["rm" "-rf" dir], mkdir dir 448)
   (rd p) (: q (open p "r") s (slurp q) (close q, s))
   (put p s) (open p "w" @ q (say q s, close q))
   (bytes l) (cask #l @ c (map (i \ pin c i (l i)) (jot #l), string c))
   (image w h f)
    (cask (4 * w * h) @ c
     (map (i \ (: p (f (i % w) (i // w)) o (4 * i)
                  (pins c o (p 0) (o + 1) (p 1) (o + 2) (p 2) (o + 3) (p 3))))
          (jot (w * h)),
      [w h (string c)]))

   ; -- every op ----------------------------------------------------------------------
   ops (bytes (cats [[10 20 30 255] [10 20 30 255] [10 20 30 255] [11 19 31 255] [21 31 41 255]
                     [10 20 30 255] [10 20 30 128]]))
   want (bytes [113 111 105 102 0 0 0 7 0 0 0 1 4 0
                254 10 20 30  193  119  172 102  9  255 10 20 30 128  0 0 0 0 0 0 0 1])
   _ (test (qoi-encode 7 1 ops = want) (qoi-decode want = [7 1 ops]) (qoi-size want = [7 1]))

   ; -- round trips ---------------------------------------------------------------------
   pics [(image 97 61 (x \ y \ [((x * 3) % 256) ((y * 4) % 256) ((x * y) % 256) 255]))
         (image 33 17 (x \ y \ (: v (((y * 33 + x) * 2654435761) >> 7)
                                  [(v & 255) ((v >> 8) & 255) ((v >> 16) & 255) ((v >> 24) & 255)])))
         (image 40 30 (x \ y \ (((x // 8 + y // 6) & 1) = 1 ? [200 30 30 255] [30 30 200 90])))
         (image 1 1 (x \ y \ [9 8 7 6]))
         (image 300 2 (x \ y \ [1 2 3 255]))]
   (trip im) (qoi-encode (im 0) (im 1) (im 2) @ q (string? q && qoi-decode q = im))
   _ (test (atom? (filter (im \ !(trip im)) pics))
           ; an opaque picture says 3 channels, one with alpha 4
           (qoi-encode 1 1 (bytes [1 2 3 255]) 12 = 3) (qoi-encode 1 1 (bytes [1 2 3 4]) 12 = 4))

   ; -- against PIL ---------------------------------------------------------------------
   pil? (: r (hark ["python3" "-c" "import PIL.QoiImagePlugin"]) (two? r) && (<r = 0))
   _ (each (jot #pics) (k \ (: im (pics k)
                             (put (dir + "/p" + show k + ".rgba") (im 2),
                              put (dir + "/p" + show k + ".qoi") (qoi-encode (im 0) (im 1) (im 2))))))
   _ (put (dir + "/q.py") """
     import sys
     from PIL import Image
     d, n = sys.argv[1], int(sys.argv[2]); bad = 0
     for k in range(n):
         src = open('%s/p%d.rgba' % (d, k), 'rb').read(); ours = open('%s/p%d.qoi' % (d, k), 'rb').read()
         im = Image.open('%s/p%d.qoi' % (d, k)); bad += im.convert('RGBA').tobytes() != src
         im = Image.frombytes('RGBA', im.size, src)
         if all(a == 255 for a in src[3::4]): im = im.convert('RGB')
         im.save('%s/pil%d.qoi' % (d, k)); pil = open('%s/pil%d.qoi' % (d, k), 'rb').read()
         bad += pil[:13] != ours[:13] or pil[14:] != ours[14:]
     sys.exit(bad)
     """)
   _ (pil? ? (: r (hark ["python3" (dir + "/q.py") dir (show #pics)])
                (test (<r = 0)
                      (atom? (filter (k \ !(qoi-decode (rd (dir + "/pil" + show k + ".qoi")) = pics k)) (jot #pics)))))
        (gate-partly "qoi: no python3 PIL with qoi, held to it skipped"))

   ; -- refusals ------------------------------------------------------------------------
   (flip s i) (cask #s @ c (pour c 0 s 0 #s, pin c i (255 - s i), string c))
   q0 (qoi-encode (pics 2 0) (pics 2 1) (pics 2 2))
   (test (qoi-decode "hello there, world" = "not a qoi") (qoi-size "qoif" = "not a qoi")
         (qoi-decode (snip want 0 20) = "cut short")
         (qoi-decode ("qoif" + bytes [0 0 16 1 0 0 16 1 4 0]) = "too big")
         (qoi-decode ("qoif" + bytes [0 0 0 0 0 0 0 1 4 0]) = "not a qoi")
         (qoi-encode 2 2 "abc" = ()) (qoi-encode 0 1 "" = ())
         ; a flipped byte answers why, or a picture of its size
         (atom? (filter (i \ !(qoi-decode (flip q0 i) @ d (string? d || (two? d && #(d 2) = 4 * d 0 * d 1)))) (jot #q0))),
    hark ["rm" "-rf" dir],
    0))

(test_fin (), puts "qoi: ok", putc 10, 0)
