; test/host/kitpng.l -- kitty's f=100, a PNG laid into quay's store (src/love/quay/png.c)
; one 13x7 picture, its alpha either side of half, written by magick every way a PNG is
; -- each colour type, 1 to 16 bits, a palette with tRNS, Adam7 -- sent as kitty sends it,
; and every pixel held to magick's own read of the same file: set where its alpha is half
; or past, its rgb then exact. a torn file is refused, and a chunked one lands whole.
; no magick on the box -> a polite skip.
;   cat test/00-init.l test/host/kitpng.l | out/love
(borrow 'posix)
(: magick? (open "/usr/bin/magick" "r" @ q (hot? q ? (close q, 1) 0))
   _ (magick? ? 0 (puts "kitpng: ok (no magick, skipped)\n", quit 0))
   dir (cwd 0 + "/out/.kitpng")
   _ (hark ["rm" "-rf" dir], mkdir dir 448)
   (put p s) (open p "w" @ q (say q s, close q))
   (rd p) (uread p @ r (two? r ? <>r ""))
   ; base64, rfc 4648
   abc "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
   (b64 s) (: n #s
              (go i acc) (n <= i ? (cats (rev acc))
                          (: b0 (s i) b1 (i + 1 < n ? (s (i + 1)) 0) b2 (i + 2 < n ? (s (i + 2)) 0)
                             v (b0 << 16 | b1 << 8 | b2)
                             q (string (abc (v >> 18)) + string (abc (v >> 12 & 63))
                                + (i + 1 < n ? (string (abc (v >> 6 & 63))) "=")
                                + (i + 2 < n ? (string (abc (v & 63))) "="))
                             (go (i + 3) (q . acc))))
              (go 0 ()))
   W 13 H 7
   src (cask (4 * (W * H)) @ c
        (map (i \ (: x (i % W) y (i // W) o (4 * i)
                     (pins c o (x * 19) (o + 1) (200 - y * 20) (o + 2) (y * 36) (o + 3) (x * 20 + 5))))
             (jot (W * H)),
         string c))
   _ (put (dir + "/src.rgba") src)
   (make nm flags) (dir + "/" + nm + ".png" @ f
                    (hark (["magick" "-size" "13x7" "-depth" "8" ("rgba:" + dir + "/src.rgba")] + flags + [f]),
                     f))
   ; magick's read of a file: its pixels as the store keeps them
   (want f) (: r (hark ["magick" f "-depth" "8" "rgba:-"]) o >r
               (map (i \ (o (4 * i + 3) @ a
                            (a < 128 ? 0 (255 << 24 | o (4 * i) << 16 | o (4 * i + 1) << 8 | o (4 * i + 2)))))
                    (jot (W * H))))
   (mkscr r c) (screen (cask (screen () r c)) r c)
   ; the file through kitty onto a fresh screen: its pixels as tilepx reads them, and the reply
   (got f) (: s (mkscr 4 10)
              _ (scribe s ("\e_Ga=T,f=100,i=1;" + b64 (rd f) + "\e\\"))
              rep (string (reply s))
              [rep (map (i \ (: x (i % W) y (i // W) (tilepx s (x // 8) (x % 8) y))) (jot (W * H)))])
   ; (name flags), each a way magick writes a PNG
   ways [["rgba8" ["-define" "png:color-type=6"]]
         ["rgb8" ["-alpha" "off" "-define" "png:color-type=2"]]
         ["grey8" ["-colorspace" "gray" "-alpha" "off" "-define" "png:color-type=0"]]
         ["grey4" ["-colorspace" "gray" "-alpha" "off" "-define" "png:color-type=0" "-define" "png:bit-depth=4"]]
         ["grey2" ["-colorspace" "gray" "-alpha" "off" "-define" "png:color-type=0" "-define" "png:bit-depth=2"]]
         ["grey1" ["-colorspace" "gray" "-alpha" "off" "-threshold" "50%" "-define" "png:color-type=0" "-define" "png:bit-depth=1"]]
         ["greya8" ["-colorspace" "gray" "-define" "png:color-type=4"]]
         ["pal8" ["-define" "png:color-type=3"]]
         ["pal4" ["-colors" "12" "-alpha" "off" "-define" "png:color-type=3" "-define" "png:bit-depth=4"]]
         ["rgba16" ["-depth" "16" "-define" "png:color-type=6"]]
         ["rgb16" ["-depth" "16" "-alpha" "off" "-define" "png:color-type=2"]]
         ["adam7" ["-interlace" "PNG" "-define" "png:color-type=6"]]]
   (check w) (: f (make <w <>w) g (got f)
                (<g = "\e_Gi=1;OK\e\\" && <>g = want f ? 1
                 (puts ("kitpng: " + <w + " differs: " + show <g + "\n"), 0)))
   _ (test (foldl (a \ w \ (&& a (check w))) 1 ways))
   ; a torn file: refused, and nothing placed
   s (mkscr 4 10)
   torn (rd (dir + "/rgba8.png") @ b (snip b 0 (#b - 20)))
   _ (scribe s ("\e_Ga=T,f=100,i=3;" + b64 torn + "\e\\"))
   _ (test ("\e_Gi=3;EBADPNG:png\e\\" = string (reply s))
           !(tilepx s 0 0 0))
   ; the same file in chunks cut on a base64 quantum: m=1 then m=0
   s2 (mkscr 4 10)
   e (b64 (rd (dir + "/pal8.png")))
   k (4 * (#e // 8))
   (scribe s2 ("\e_Ga=T,f=100,i=4,m=1;" + snip e 0 k + "\e\\"),
    scribe s2 ("\e_Gm=0;" + snip e k #e + "\e\\"),
    test ("\e_Gi=4;OK\e\\" = string (reply s2))
         (want (dir + "/pal8.png") 0 = tilepx s2 0 0 0),
    hark ["rm" "-rf" dir],
    test_fin (),
    puts "kitpng: ok\n"))
