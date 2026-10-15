; test/host/png.l -- src/apps/png.l and src/love/picture/png.c's unfilter
; the nif and the walk on rows worked by hand: each filter, a bad filter byte, too few
; bytes. then, where python3 with PIL and magick are here, images of every colour type, grey
; at 1 to 16 bits, palettes of 1 to 8, colour keys, 16-bit and interlaced ones at a size
; that splits bytes and adam7 passes, each decoded and held to magick's own rgba byte for
; byte. apng: a hand-muxed one by its frames' sums, and where PIL is, PIL's animations
; composed frame by frame, held to the spec's rule written out in python. last the
; refusals: not a png, a torn file, a flipped byte under a crc, a frame past the canvas.
;   cat test/00-init.l test/host/png.l | out/love
(borrow 'posix)
(borrow 'gz)
(borrow 'hashes)
(borrow 'png)
(borrow "src/apps/png.l")
(: dir (cwd 0 + "/out/.png")
   _ (hark ["rm" "-rf" dir], mkdir dir 448)
   (rd p) (: q (open p "r") s (slurp q) (close q, s))
   (put p s) (open p "w" @ q (say q s, close q))
   (bytes l) (cask #l @ c (map (i \ pin c i (l i)) (jot #l), string c))

   ; -- the nif --------------------------------------------------------------------------
   ; sub then paeth over the row above, then none, up and average, bpp 1 and 2
   r1 (png-unfilter (bytes [1 10 5 5  4 1 1 1]) 0 2 3 1)
   r2 (png-unfilter (bytes [9 9  0 7 8 9 250  2 1 1 1 10  3 2 2 2 2]) 2 3 4 2)
   ; the walk on the same rows, its filter bytes dropped after
   (walk l o rows n bpp)
    (: c (cask #l) _ (map (i \ pin c i (l i)) (jot #l))
       e (png-walk c o rows n bpp)
       (string? e ? e
        (foldl (acc \ y \ (acc + snip (string c) (o + 1 + y * (n + 1)) (o + 1 + y * (n + 1) + n))) ""
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
   (has p) (open p "r" @ q (hot? q ? (close q, 1) 0))
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
   _ (ok? ?
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
                      (? (two? want && <want = 0 && two? got && got 0 = 37 && got 1 = 23
                          && got 2 = >want)
                         1 (puts ("png: " + n + " differs from magick\n"), 0)))
           (test (filter (n \ !(one n)) names = ())))
        (gate-partly "png: no python3 PIL or magick, images skipped"))

   ; -- apng ----------------------------------------------------------------------------
   ; muxed by hand, 24x16: five palette frames under one PLTE and tRNS (index 0 clear, 1
   ; half). the first overwrites the canvas and stays; then over and cleared, over and put
   ; back, overwritten and kept, over and put back. each composed frame by its sha-256, as
   ; the spec's rule written out below gives it; a delay num/den in ms, a den of 0 is 100
   (nib c) (? (c < 58) (c - 48) (c - 87))
   (unx h) (cask (#h // 2) @ c (map (i \ pin c i (nib (h (2 * i)) * 16 + nib (h (2 * i + 1)))) (jot (#h // 2)),
                               string c))
   hand (unx (cats [
     "89504e470d0a1a0a0000000d4948445200000018000000100403000000fe0aa2a6000000086163544c000000"
     "050000000041ad4f6000000030504c5445000000ffffffe61e1e1ec83c283cdcfadc00000810182028303840"
     "4850586068707880889098a0a8b0b8c0c8d0d8e0e8cdb7e3960000001074524e530080ffffffffffffffffff"
     "ffffffffff928492720000001a6663544c0000000000000018000000100000000000000000000a006400005f"
     "7e059b0000007149444154789c4dceb10dc2401044d1e7c5cea1033740070e9d5d42e23e5d00019440077400"
     "1264202058c0b7d17c8df47758ae8b2a97367abcce287336cd666d9a35d1e3c2fd41c09bb6f8c295e1f803c6"
     "833f8cfbf444cfed9992c06a4889c0f6941298f2694e5ad64557aaddbb2a7f0019641417a96c381f0000001a"
     "6663544c00000001000000110000000b000000010000000200010000010180dbd6f000000053666441540000"
     "0002789c35cca10d80301400d1d726dfd339901da34ba098af8b60188054a3988020805367ee920a1bd9cf6b"
     "47b124957b8833c3104dc62d5a9f3244eb6f11ad7feddcbf4bdde1622595327900f3cf0e0937935de0000000"
     "1a6663544c00000003000000140000001000000004000000000003000702017b3b1a5f000000666664415400"
     "000004789c6dce410d02311844e1af7f56c07ac1006a8a000ed5500b558301924aa90036e550d803614e2f93"
     "bcccf02f69bbe2f5a0c4b72b354eb2e1e8b35402ddad2238e4b62fecb9490b735b66b87c48dc9fe71a69670e"
     "8289b134c3fc79f6069d4516e7da3550a40000001a6663544c000000050000000c0000000d00000000000000"
     "02001403e8000034c2e0b70000003e6664415400000006789c6dc5a10d80400c00c06bc92748ba19dba07115"
     "0cc560101058ce5c60ac12fc767d9d09d306f35e41df07daa8d2a80a8825e1f102099107b190f4e0bf000000"
     "1a6663544c00000007000000140000000c0000000200000002ffff000302016bd3e841000000586664415400"
     "000008789c6d8d310e802010c00ab9c4b068ee07c4cfb13af20537567ec713dcd0051c34ea60a7261d6a00eb"
     "81562c0f7feab25c322c3508408fc7daeea63a7b0497f608db88e41a14e860000598de45f92e4e4ca5117f86"
     "f2149d0000000049454e44ae426082"]))
   hand-sums ["da6932c97d2a790ad20045168e3c4157fb5a5aaaf67a6958ab79ad5fa8760ee8" "0d538ae7ca77f285f92eca5fbf1921c49873d4bca8e0db38e0ca87b23621676e" "968a2d9fe9b2da9fe5e19875ea95f27e3ed07a46397fefe02c3799507cb209ef" "8c48447fdf29c3b62053b24fb64c137dfd09c4b1b69ee9d04fdf2762a64831e6" "9e9ae97b382606465f7dfb4d625653400976cc170dbf5f85e23a4bec1504cc3d"]
   hf (png-frames hand 100)
   _ (test (two? hf) (hf 0 = 24) (hf 1 = 16) (#(hf 2) = 5)
           (map (f \ f 1) (hf 2) = [100 10 429 20 21845000])
           (map (f \ sha256 (f 0)) (hf 2) = hand-sums)
           (#(png-frames hand 2 2) = 2)
           ; the first frame is the default image, png-decode's
           (hf 2 0 0 = png-decode hand 2))
   _ (put (dir + "/an.py") """
    # apngs PIL wrote, each composed by the apng spec's rule written out here, every frame
    # decoded alone by PIL; where alpha is all or none, PIL's own composed frames must agree
    import sys, os, io, zlib, struct
    from PIL import Image, ImageDraw
    d = sys.argv[1]
    W, H = 40, 30
    def frame(i, semi=False, bg=(0, 0, 0, 0)):
        im = Image.new('RGBA', (W, H), bg); dr = ImageDraw.Draw(im)
        dr.rectangle([2 + 5 * i, 3 + 2 * i, 15 + 5 * i, 14 + 2 * i], fill=(200 - 30 * i, 40 + 40 * i, 90, 128 if semi else 255))
        dr.ellipse([18 - 2 * i, 6, 32 - i, 26 - i], fill=(20, 180 - 20 * i, 60 * i % 256, 200 if semi else 255))
        return im
    def save(nm, fr, **kw): fr[0].save('%s/%s.png' % (d, nm), save_all=True, append_images=fr[1:], **kw)
    save('opaque', [frame(i, bg=(250, 250, 240, 255)).convert('RGB') for i in range(5)], duration=[40, 50, 60, 70, 80], disposal=0, blend=0)
    save('clear', [frame(i) for i in range(5)], duration=100, disposal=1, blend=1)
    save('prev', [frame(i) for i in range(5)], duration=[30, 1000, 30, 30, 20], disposal=2, blend=1)
    save('mixed', [frame(i) for i in range(6)], duration=33, disposal=[0, 1, 2, 0, 2, 1], blend=[0, 1, 1, 0, 1, 1])
    save('hidden', [frame(9, bg=(0, 0, 255, 255))] + [frame(i) for i in range(3)], duration=[0, 70, 80, 90], default_image=True, disposal=1, blend=1)
    save('semi', [frame(i, True) for i in range(5)], duration=40, disposal=0, blend=1)
    save('semiprev', [frame(i, True, (255, 0, 0, 90) if i == 0 else (0, 0, 0, 0)) for i in range(5)], duration=40, disposal=[0, 2, 0, 1, 2], blend=1)
    def chunks(b):
        p = 8
        while p < len(b):
            n, = struct.unpack('>I', b[p:p + 4]); yield b[p + 4:p + 8], b[p + 8:p + 8 + n]; p += 12 + n
    def ck(t, body): return struct.pack('>I', len(body)) + t + body + struct.pack('>I', zlib.crc32(t + body))
    def spec(b):
        cs = {}; idat = b''; seen = False; frs = []
        for t, body in chunks(b):
            if t in (b'IHDR', b'PLTE', b'tRNS'): cs[t] = body
            elif t == b'IDAT': idat += body; seen = True
            elif t == b'fcTL': frs.append([body, not seen, b''])
            elif t == b'fdAT': frs[-1][2] += body[4:]
        w, h = struct.unpack('>II', cs[b'IHDR'][:8]); canvas = bytearray(w * h * 4); out = []
        for k, (fc, first, z) in enumerate(frs):
            _, fw, fh, x, y, dn, dd, dop, bop = struct.unpack('>IIIIIHHBB', fc); dd = dd or 100
            one = b'\x89PNG\r\n\x1a\n' + ck(b'IHDR', struct.pack('>II', fw, fh) + cs[b'IHDR'][8:]) \
                + b''.join(ck(t, cs[t]) for t in (b'PLTE', b'tRNS') if t in cs) + ck(b'IDAT', idat if first else z) + ck(b'IEND', b'')
            px = Image.open(io.BytesIO(one)).convert('RGBA').tobytes(); before = bytes(canvas)
            for r in range(fh):
                for c in range(fw):
                    s = px[4 * (r * fw + c):4 * (r * fw + c) + 4]; o = 4 * ((y + r) * w + x + c); t = canvas[o:o + 4]
                    if bop == 0 or s[3] == 255 or t[3] == 0: canvas[o:o + 4] = s
                    elif s[3]:
                        u = s[3] * 255; v = (255 - s[3]) * t[3]; al = u + v
                        canvas[o:o + 4] = bytes([(s[i] * u + t[i] * v) // al for i in range(3)] + [al // 255])
            out.append((bytes(canvas), (dn * 1000 + dd // 2) // dd))
            if dop == 1 or dop == 2 and k == 0:
                for r in range(fh): canvas[4 * ((y + r) * w + x):4 * ((y + r) * w + x + fw)] = bytes(4 * fw)
            elif dop == 2: canvas = bytearray(before)
        return w, h, out
    man = []; bad = 0
    for nm in ('opaque', 'clear', 'prev', 'mixed', 'hidden', 'semi', 'semiprev'):
        w, h, out = spec(open('%s/%s.png' % (d, nm), 'rb').read())
        for k, (px, ms) in enumerate(out): open('%s/%s.%d.rgba' % (d, nm, k), 'wb').write(px)
        man.append(' '.join([nm, str(w), str(h), str(len(out))] + [str(ms) for _, ms in out]))
        # PIL lerps a part-clear pixel's alpha too, and draws a hidden default image's frames over it
        if nm not in ('hidden', 'semi', 'semiprev'):
            im = Image.open('%s/%s.png' % (d, nm)); fr = []
            for i in range(im.n_frames): im.seek(i); fr.append(im.convert('RGBA').tobytes())
            bad += fr != [px for px, _ in out]
    open(d + '/anims', 'w').write('\n'.join(man) + '\n')
    sys.exit(bad)
    """)
   (anim-same l)
    (: ws (split " " l) nm (ws 0) n <(sound (ws 3)) ds (map (t \ <(sound t)) (drop 4 ws))
       r (png-frames (rd (dir + "/" + nm + ".png")) 1000)
       (two? r && r 0 = <(sound (ws 1)) && r 1 = <(sound (ws 2)) && #(r 2) = n
        && atom? (filter (k \ !(r 2 k 0 = rd (dir + "/" + nm + "." + show k + ".rgba") && r 2 k 1 = ds k)) (jot n))))
   _ (pil? ? (: r (hark ["python3" (dir + "/an.py") dir])
                ls (filter (l \ 0 < #l) (split "\n" (rd (dir + "/anims"))))
                (test (<r = 0) (#ls = 7) (atom? (filter (l \ !(anim-same l)) ls))))
        (gate-partly "png: no python3 PIL, its animations skipped"))

   ; -- refusals -------------------------------------------------------------------------
   good (ok? ? (rd (dir + "/c8.png")) "")
   (flip s i) (cask #s @ c (pour c 0 s 0 #s, pin c i (255 - s i), string c))
   _ (test (png-decode "GIF89a" = "not a png")
           (ok? ? (png-decode (snip good 0 (#good - 20)) = "truncated") 1)
           (ok? ? (png-decode (flip good (#good - 30)) = "bad crc in IDAT") 1)
           (ok? ? (png-decode (flip good 20) = "bad crc in IHDR") 1))
   ; a header past 2^24 pixels is refused before any of it is allocated, and so is image
   ; data too short for its header
   wrbe (cite 'bytes 'wrbe) zb (cite 'bytes 'zbytes)
   (chunk ty b) (wrbe #b 4 + ty + b + wrbe (crc32 (ty + b)) 4)
   (mkpng w h z) (bytes [137 80 78 71 13 10 26 10]
                  + chunk "IHDR" (wrbe w 4 + wrbe h 4 + bytes [8 6 0 0 0])
                  + chunk "IDAT" ("\x78\x01" + deflate z + zb 4) + chunk "IEND" "")
   rdbe (cite 'bytes 'rdbe)
   ; an apng of one 2x2 frame at x, its data the default image's
   (mkapng x) (: p (mkpng 2 2 (zb 18)) ih (8 + 8 + 13 + 4)
                 (snip p 0 ih + chunk "acTL" (wrbe 1 4 + wrbe 0 4)
                  + chunk "fcTL" (wrbe 0 4 + wrbe 2 4 + wrbe 2 4 + wrbe x 4 + wrbe 0 4 + wrbe 1 2 + wrbe 10 2 + bytes [0 0])
                  + snip p ih #p))
   ; the chunks with each crc laid again, so a flipped byte reaches what reads it
   (recrc s) (: (go p acc) (? (#s < p + 12) (cats (rev (snip s p #s . acc)))
                              (: e (p + 12 + rdbe s p 4)
                                 (? (#s < e) (cats (rev (snip s p #s . acc)))
                                    (go e (snip s p (e - 4) + wrbe (crc32 (snip s (p + 4) (e - 4))) 4 . acc)))))
                (go 8 [(snip s 0 8)]))
   (test (png-frames (mkpng 2 2 (zb 18)) 10 = [2 2 [[(zb 16) 0]]])
         (png-frames (mkapng 0) 10 = [2 2 [[(zb 16) 100]]])
         (png-frames (mkapng 1) 10 = "a frame past the canvas")
         (png-frames "GIF89a" 10 = "not a png")
         (atom? (filter (i \ !(png-frames (recrc (flip hand i)) 10 @ d (string? d || two? d))) (jot #hand)))
         (png-decode (mkpng 100000 100000 (zb 64)) = "too big")
         (png-decode (mkpng 4097 4096 (zb 64)) = "too big")
         (png-decode (mkpng 8 8 (zb 64)) = "short image data")
         (png-decode (mkpng 2 2 (zb 18)) = [2 2 (zb 16)]),
    hark ["rm" "-rf" dir],
    0))

(test_fin (), puts "png: ok", putc 10, 0)
