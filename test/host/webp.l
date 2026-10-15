; test/host/webp.l -- src/apps/webp.l and webp.c's webp-pixels: libwebp's pictures, stills and
; animations, by sha-256; then, where PIL writes webp, held to PIL's decode byte for byte; the lossless
; encoder read back exactly, here and by PIL; then the refusals.
;   cat test/00-init.l test/host/webp.l | out/love
(borrow 'posix)
(borrow 'hashes)
(borrow 'webp)
(borrow "src/apps/webp.l")
(: dir (cwd 0 + "/out/.webpd")
   _ (hark ["rm" "-rf" dir], mkdir dir 448)
   (rd p) (: q (open p "r") s (slurp q) (close q, s))
   (put p s) (open p "w" @ q (say q s, close q))
   (nib c) (? (c < 58) (c - 48) (c - 87))
   (unx h) (cask (#h // 2) @ c (map (i \ pin c i (nib (h (2 * i)) * 16 + nib (h (2 * i + 1)))) (jot (#h // 2)),
                               string c))

   ; -- libwebp's own
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

   ; animations
   ; muxed by hand on a 20x12 canvas: a drawn first frame, semi-clear frames blended over it,
   ; one cleared away and the next copied where it was, an overwrite with alpha, a blend
   hand (unx (cats [
     "52494646d801000057454250565038580a000000120000001300000b0000414e494d06000000ffffffff"
     "0000414e4d46360000000000000000001300000b00001e0000005650384c1e0000002f13c00200b98ce8"
     "7fec22a2ff0121016184ff7b357518462b2600a99435414e4d463e000000010000010000070000050000"
     "280000005650384c260000002f07400110b98ce87f404840c8fe4f962c187d05691bb0b0dd1193a62176"
     "9bc309e0891bb401414e4d4640000000020000020000050000030000320000015650384c270000002f05"
     "c00010b98ce87fec22a2ff01856c2340e74f765e3fc2288c874020c5916cf204b0410a1d0000414e4d46"
     "500000000300000100000900000500003c0000005650384c380000002f09400110b93244f43f7611d1ff"
     "50286adb060a7f8465d3d70e0cd1640ca0a2b66de0600be0da388dcd26a092300780e607d805fc00a70a"
     "414e4d463c0000000000000000001300000b0000460000035650384c230000002f13c00210b98ce87fec"
     "22a2ff01210121fb3f5a53077928840429c4e804507289d60000414e4d46440000000100000000000500"
     "00050000500000005650384c2c0000002f054001102f20904dbefcad939800850002a0a021c8b60d6dbb"
     "ccb30f3e0402c482162dfe772c44f43fb005"
     ]))
   hand-sums ["a8d3533e51a9f876926efe3e0cbf6267add7dfb82856da78c09325184449814e" "61da5fdf7f5b8202c079637c6dc6c34d6548bf53738697b4ecfa66a1d8a990e7" "06bbd9e01704d83d0c3bf99df48382aa7be88904c181ee717ab52a7f1d5b021f" "7cb1f76e6839cc61f18380dc2e2aa2d4bf3a87a2347b44878b6ece72b5da2555" "d3599e46d35d21404cb89b55a81867152378631b5bd4ced635b73ddf67115510" "81de011603658cd4eaecb56d436365aeda7c2322c164cbc74b5aee4140a96c55"]
   hf (webp-frames hand 100)
   _ (test (two? hf) (hf 0 = 20) (hf 1 = 12) (#(hf 2) = 6)
           (map (f \ f 1) (hf 2) = [30 40 50 60 70 80])
           (map (f \ sha256 (f 0)) (hf 2) = hand-sums)
           (#(webp-frames hand 2 2) = 2)
           ; the first frame is webp-decode's, and a still picture is one frame of no time
           (webp-frames anim 10 @ f (two? f && f 2 0 0 = webp-decode anim 2))
           (webp-frames lossy 10 = [24 18 [[(webp-decode lossy 2) 0]]]))

   ; against PIL
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
        (gate-partly "webp: no python3 PIL with webp, its pictures skipped"))
   _ (put (dir + "/an.py") "# animated webps from PIL (libwebp's encoder picks each frame's box, blend and dispose), and each
# frame as PIL composes it (libwebp's animation decoder): <name>.<k>.rgba, durations in the manifest
import sys, struct, random, math
from PIL import Image, ImageSequence
d = sys.argv[1]; random.seed(5)
def frame(w, h, k, alpha, moving):
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0) if alpha else (20, 40, 60, 255))
    px = im.load()
    for y in range(h):
        for x in range(w):
            if moving and abs(x - (k * 3) % w) < 4 and abs(y - (k * 2) % h) < 3:
                px[x, y] = (255, (k * 40) % 256, 30, 255 if not alpha else (100 + k * 30) % 256)
            elif not moving:
                px[x, y] = (int(127 + 120 * math.sin(x * 0.3 + k)), (y * 9 + k * 20) % 256, (x * y + k) % 256,
                            ((x + k) * 23) % 256 if alpha else 255)
    return im
cases = [('lossless-move', 24, 16, 1, 1, dict(lossless=True)),
         ('lossless-move-opaque', 24, 16, 0, 1, dict(lossless=True)),
         ('lossy-move', 32, 20, 1, 1, dict(lossless=False, quality=80)),
         ('mixed-alpha', 30, 18, 1, 0, dict(allow_mixed=True, quality=70)),
         ('lossless-full', 17, 11, 1, 0, dict(lossless=True)),
         ('kmax1', 24, 16, 1, 1, dict(lossless=True, kmin=0, kmax=1)),
         ('minsize', 24, 16, 1, 1, dict(lossless=True, minimize_size=True))]
man = []
for name, w, h, alpha, moving, o in cases:
    fs = [frame(w, h, k, alpha, moving) for k in range(6)]
    p = '%s/%s.webp' % (d, name)
    fs[0].save(p, 'WEBP', save_all=True, append_images=fs[1:], duration=[40, 50, 60, 70, 80, 90], loop=0, **o)
    im = Image.open(p); n = 0
    for k, f in enumerate(ImageSequence.Iterator(im)):
        open('%s/%s.%d.rgba' % (d, name, k), 'wb').write(f.convert('RGBA').tobytes()); n += 1
    # what the encoder chose, frame by frame: x y w h dispose blend
    b = open(p, 'rb').read(); q = 12; fl = []; durs = []
    while q + 8 <= len(b):
        cc = b[q:q + 4]; sz = struct.unpack('<I', b[q + 4:q + 8])[0]
        if cc == b'ANMF':
            x = int.from_bytes(b[q + 8:q + 11], 'little') * 2; y = int.from_bytes(b[q + 11:q + 14], 'little') * 2
            fw = int.from_bytes(b[q + 14:q + 17], 'little') + 1; fh = int.from_bytes(b[q + 17:q + 20], 'little') + 1
            durs.append(int.from_bytes(b[q + 20:q + 23], 'little'))
            f = b[q + 23]; fl.append('%d,%d %dx%d %s%s %s' % (x, y, fw, fh, 'D' if f & 1 else '-', 'N' if f & 2 else 'B', b[q + 24:q + 28].decode()))
        q += 8 + sz + (sz & 1)
    man.append('%s %d %d %d %s' % (name, w, h, n, ' '.join(map(str, durs))))
open(d + '/anims', 'w').write(chr(10).join(man) + chr(10))
")
   (anim-same l)
    (: ws (split " " l) nm (ws 0) n <(sound (ws 3)) ds (map (t \ <(sound t)) (drop 4 ws))
       r (webp-frames (rd (dir + "/" + nm + ".webp")) 1000)
       (two? r && r 0 = <(sound (ws 1)) && r 1 = <(sound (ws 2)) && #(r 2) = n
        && atom? (filter (k \ !(r 2 k 0 = rd (dir + "/" + nm + "." + show k + ".rgba") && r 2 k 1 = ds k)) (jot n))))
   _ (pil? ? (: r (hark ["python3" (dir + "/an.py") dir])
                ls (filter (l \ 0 < #l) (split "\n" (rd (dir + "/anims"))))
                (test (<r = 0) (6 < #ls) (atom? (filter (l \ !(anim-same l)) ls))))
        (gate-partly "webp: no python3 PIL with webp, its animations skipped"))

   ; -- the lossless encoder: palettes packed 8, 4, 2 and 1 a pixel, alpha, a gradient, noise,
   ; one pixel, a long row, each read back exactly here and by libwebp
   (image w h f)
    (cask (4 * w * h) @ c
     (map (i \ (: p (f (i % w) (i // w)) o (4 * i)
                  (pins c o (p 0) (o + 1) (p 1) (o + 2) (p 2) (o + 3) (p 3))))
          (jot (w * h)),
      [w h (string c)]))
   (pal k) (image 37 23 (x \ y \ (: i ((x * 7 + y * 3) % k) [((i * 53) % 256) ((i * 97) % 256) (i % 256) 255])))
   encs [(pal 2) (pal 3) (pal 5) (pal 17) (pal 256)
         (image 40 30 (x \ y \ [((x * 3) % 256) ((y * 4) % 256) ((x * y) % 256) (((x + y) * 5) % 256)]))
         (image 33 17 (x \ y \ (: v (((y * 33 + x) * 2654435761) >> 7)
                                  [(v & 255) ((v >> 8) & 255) ((v >> 16) & 255) 255])))
         (image 1 1 (x \ y \ [9 8 7 6])) (image 700 1 (x \ y \ [(x % 7) 2 3 255]))]
   enc-out (map (im \ webp-encode (im 0) (im 1) (im 2)) encs)
   _ (test (atom? (filter (k \ !(webp-decode (enc-out k) = encs k)) (jot #encs)))
           (#(webp-encode 300 200 (string (cask 240000))) < 60)
           (webp-encode 2 2 "abc" = ()) (webp-encode 0 1 "" = ()) (webp-encode 20000 1 (string (cask 80000)) = ()))
   _ (each (jot #encs) (k \ (put (dir + "/e" + show k + ".rgba") (encs k 2), put (dir + "/e" + show k + ".webp") (enc-out k))))
   _ (put (dir + "/enc.py") """
     import sys
     from PIL import Image
     d, n = sys.argv[1], int(sys.argv[2])
     sys.exit(sum(Image.open('%s/e%d.webp' % (d, k)).convert('RGBA').tobytes() != open('%s/e%d.rgba' % (d, k), 'rb').read() for k in range(n)))
     """)
   _ (pil? ? (: r (hark ["python3" (dir + "/enc.py") dir (show #encs)]) (test (<r = 0)))
        (gate-partly "webp: no python3 PIL with webp, its reading of our encoder skipped"))

   ; -- refusals
   (flip s i) (cask #s @ c (map (k \ pin c k (s k)) (jot #s), pin c i (255 - s i), string c))
   (test (webp-decode "hello" = "not a webp") (webp-size "hello" = "not a webp")
         (webp-decode (snip ll 0 40) = "cut short") (webp-decode (snip lossy 0 20) = "cut short")
         (webp-pixels 7 = 1) (webp-pixels (snip alpha 0 60) = 2)
         ; a flipped byte answers why, or a picture, and never takes the process down
         (atom? (filter (i \ !(webp-decode (flip ll i) @ d (string? d || two? d))) (jot #ll)))
         (atom? (filter (i \ !(webp-frames (flip hand i) 10 @ d (string? d || two? d))) (jot #hand)))
         (webp-frames "hello" 10 = "not a webp"),
    hark ["rm" "-rf" dir],
    0))

(test_fin (), puts "webp: ok", putc 10, 0)
