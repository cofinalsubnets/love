; test/host/webp.l -- src/apps/webp.l and src/love/lib/webp.c's webp-pixels
; small pictures libwebp wrote -- lossy, lossy over an alpha plane compressed and raw,
; lossless with a palette and with its transforms, one pixel, an animation whose first frame
; sits inside its canvas -- each decoded to the rgba libwebp gives, by its sha-256. then,
; where python3's PIL writes webp, more of them, each held to PIL's own decode byte for byte;
; last the refusals.
;   cat test/00-init.l test/host/webp.l | out/love
(borrow 'posix)
(borrow "src/apps/webp.l")
(: dir (cwd 0 + "/out/.webpd")
   _ (hark ["rm" "-rf" dir], mkdir dir 448)
   (rd p) (: q (open p "r") s (slurp q) (close q, s))
   (put p s) (open p "w" @ q (say q s, close q))
   (nib c) (? (c < 58) (c - 48) (c - 87))
   (unx h) (cask (#h // 2) @ c (map (i \ pin c i (nib (h (2 * i)) * 16 + nib (h (2 * i + 1)))) (jot (#h // 2)),
                               string c))

   ; -- libwebp's own -------------------------------------------------------------------
   lossy (unx (cats [
     "524946464600000057454250565038203a0000005003009d012a180012003eb554a44d24a32221280800"
     "9416896500c10a8000455b580000feebde2ff9dad86207b1ffc06ebe2db818136ce80000"]))
   lossy-sum "cba5f477e9e68b6011ba023555afc08764c16794562f0266195949d562bf8bf1"
   alpha (unx (cats [
     "524946467800000057454250565038580a000000100000001300000d0000414c50481f000000051f2024"
     "48a146222262280858081afaa7764f8588fe87007ca4fe521fa93f0056503820320000001003009d012a"
     "14000e003e9d3e9a4825a322a1300800b013894013a5d00010360000fef1dc8e4522c656f87f7f192bb4"
     "e000"]))
   alpha-sum "d5477295609b31e7830c204a07d2779c0da6b1100c429e2d4e5a859d8a33ab8d"
   alraw (unx (cats [
     "524946469000000057454250565038580a00000010000000080000060000414c50484000000000efbc38"
     "005700d6185c1084d4ff7f358f69008515ce79003f8f83759f26ffb270e16714b4a774589a76ffcfe562"
     "2cff7dffff33b1395c3a3d3cd387c48370ab565038202a000000b201009d012a0900070013805a25a002"
     "74ba0004300000feebde2fee0ccfabb1c3fee3b0375e88800000"]))
   alraw-sum "828da80b53d8d6f34c713c2f5bd2477937e68717c38167de3c583bd133fa4752"
   pal (unx (cats [
     "5249464626000000574542505650384c1a0000002f0c0002000f30697158fff98f0a02812484fd816788"
     "e87ffa24"]))
   pal-sum "a6a3ee1d8538597af20d62c25b5aba23dbdec993cfe41eb41bd84832ba2c7355"
   ll (unx (cats [
     "52494646a6000000574542505650384c9a0000002f0fc0020006d79164ab4a7a0f875fcf8498dda5718b"
     "e02ee3dab65d94f165435325e93967462ac8dcfb2ea34892a46845c00d6f5080de3d6676b3ffe9f0f122"
     "7f277f4021416f0882014840107942c10151ce1c241e9017d524676b4796c353100c88420e4f000f27af"
     "c4cdcbaf001810d85867964bce4adb4e9275633fb0b10381c02097d3b4f8ab7469256b3b3893ba5b7bc9"
     "d3cfde49fe01"]))
   ll-sum "ff2daa4232dbb3f7a21aa2b3e8dccaacfa0667aafee80cca1f0a30af3703f7ec"
   one (unx (cats [
     "524946463c0000005745425056503820300000003002009d012a0100010001402625a00274ba01f801f8"
     "0004680000fef14daffd268d53f1f696ffea7060e7cfc7f80000"]))
   one-sum "58ea3b0c19d2a7d0937f7913e974932cf15dc9636d010c3c9a32e6510fd6c18b"
   anim (unx (cats [
     "52494646b800000057454250565038580a000000020000001d0000130000414e494d06000000996633ff"
     "0000414e4d4640000000020000030000090000070000640000005650384c270000002f09c0010017f0b4"
     "7f0141896260e73ff80c28682385799604a46d8918c54244ffe3166f38c20000414e4d46440000000000"
     "0000000009000007000064000002565038202c000000d001009d012a0a00080002c04c25a00274ba01f8"
     "0003b000feed4ddffc0feb05fcf0fff1672311dad2000000"]))
   anim-sum "6586f4a5049936de5b28302f268beee554014a8b211e09ac3b874dd6207d1389"
   (is s w h sum) (webp-decode s @ d (two? d && d 0 = w && d 1 = h && sha256 (d 2) = sum))
   _ (test (webp-size lossy = [24 18]) (webp-size alpha = [20 14]) (webp-size ll = [16 12])
           (webp-size anim = [30 20])
           (is lossy 24 18 lossy-sum) (is alpha 20 14 alpha-sum) (is alraw 9 7 alraw-sum)
           (is pal 13 9 pal-sum) (is ll 16 12 ll-sum) (is one 1 1 one-sum) (is anim 30 20 anim-sum)
           ; the canvas round the first frame stays clear
           (webp-decode anim @ d (d 2 3 = 0)))

   ; -- against PIL ---------------------------------------------------------------------
   pil? (: r (hark ["python3" "-c" "from PIL import features; assert features.check('webp')"])
           (two? r) && (<r = 0))
   _ (put (dir + "/mk.py") "import sys, math
from PIL import Image
d = sys.argv[1]
def pic(w, h, alpha):
    im = Image.new('RGBA', (w, h))
    im.putdata([(int(127 + 120 * math.sin(x * 0.3 + y * 0.1)), (x * 255) // max(1, w - 1),
                 (y * 255) // max(1, h - 1) ^ (x * 7 & 63),
                 ((x * y * 37) & 255) if alpha else 255) for y in range(h) for x in range(w)])
    return im
cases = [(37, 23, 0, dict(quality=75)), (64, 48, 1, dict(quality=30, method=6)),
         (17, 9, 1, dict(quality=95, method=0)), (1, 1, 0, dict(quality=50)),
         (33, 17, 0, dict(lossless=True)), (40, 30, 1, dict(lossless=True, method=6)),
         (31, 7, 1, dict(lossless=True, method=0, exact=True)),
         (16, 16, 0, dict(lossless=True, quality=100, method=4))]
for i, (w, h, a, o) in enumerate(cases):
    im = pic(w, h, a)
    if i == 7: im = im.convert('RGB').quantize(6).convert('RGBA')
    im.save('%s/%d.webp' % (d, i), 'WEBP', **o)
    open('%s/%d.rgba' % (d, i), 'wb').write(Image.open('%s/%d.webp' % (d, i)).convert('RGBA').tobytes())
fr = [pic(20, 12, k) for k in (0, 1)]
fr[0].save(d + '/8.webp', 'WEBP', save_all=True, append_images=fr[1:], duration=50, lossless=True)
open(d + '/8.rgba', 'wb').write(Image.open(d + '/8.webp').convert('RGBA').tobytes())
")
   (same i) (: s (rd (dir + "/" + show i + ".webp")) d (webp-decode s)
               (two? d && d 2 = rd (dir + "/" + show i + ".rgba")))
   _ (pil? ? (: r (hark ["python3" (dir + "/mk.py") dir])
                (test (<r = 0) (same 0) (same 1) (same 2) (same 3) (same 4) (same 5) (same 6)
                      (same 7) (same 8)))
        (puts "webp: no python3 PIL with webp, its pictures skipped\n"))

   ; -- the refusals --------------------------------------------------------------------
   (flip s i) (cask #s @ c (map (k \ pin c k (s k)) (jot #s), pin c i (255 - s i), string c))
   (test (webp-decode "hello" = "not a webp") (webp-size "hello" = "not a webp")
         (webp-decode (snip ll 0 40) = "cut short") (webp-decode (snip lossy 0 20) = "cut short")
         (webp-pixels 7 = 1) (webp-pixels (snip alpha 0 60) = 2)
         ; a flipped byte answers why, or a picture, and never takes the process down
         (atom? (filter (i \ !(webp-decode (flip ll i) @ d (string? d || two? d))) (jot #ll))),
    hark ["rm" "-rf" dir],
    0))

(test_fin (), puts "webp: ok", putc 10, 0)
