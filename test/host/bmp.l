; test/host/bmp.l -- src/apps/bmp.l: bmp and its icons, read
; small pictures PIL, magick and hand-laid headers wrote -- 1, 4, 8, 16 (5-5-5, 5-6-5), 24 and
; 32 bits, a v5 header's alpha, 4-4-4-4, rle8 and rle4, the core header, a top-down one, and
; an icon holding a bmp and one holding a png -- each decoded to its rgba by sha-256. then,
; where python3's PIL is, more of them, each held to PIL's decode byte for byte (to magick's
; where PIL reads none, 4-bit channels widened to the full range); last the refusals.
;   cat test/00-init.l test/host/bmp.l | out/love
(borrow 'posix)
(borrow 'hashes)
(borrow 'bmp)
(borrow "src/apps/bmp.l")
(: dir (cwd 0 + "/out/.bmpd")
   _ (hark ["rm" "-rf" dir], mkdir dir 448)
   (rd p) (: q (open p "r") s (slurp q) (close q, s))
   (put p s) (open p "w" @ q (say q s, close q))
   (nib c) (? (c < 58) (c - 48) (c - 87))
   (unx h) (cask (#h // 2) @ c (map (i \ pin c i (nib (h (2 * i)) * 16 + nib (h (2 * i + 1)))) (jot (#h // 2)),
                               string c))

   ; -- fixtures ------------------------------------------------------------------------
   b1-bmp (unx (cats [
     "424d52000000000000003e000000280000000700000005000000010001000000000014000000c40e0000"
     "c40e0000020000000200000000000000ffffff0026000000560000002c0000000a00000026000000"
     ]))
   b1-bmp-sum "80d6f7a6833d6e459509a52aa19bbf9062a2f6b7752e7cf6130e4e26138aa447"  ; 82 bytes, 35 px
   b4-bmp (unx (cats [
     "424d9e0000000000000076000000280000000700000005000000010008000000000028000000c40e0000"
     "c40e000010000000100000008dd2ce0000debb009fb977003594de0035d226009f943d00009425009f6f"
     "30001b6f22006a4ac0006a386f005000b8006a007b009f252c001b383000850033000d0d090705020000"
     "0b0d0a07050200000c0f0907050204000e0a0e08030304000b0e030806060100"
     ]))
   b4-bmp-sum "36c69f1aa4acb873f59076bc8aa97811a60a6790dc21d6af8945885c6021d2c8"  ; 158 bytes, 35 px
   b8-bmp (unx (cats [
     "424dea00000000000000c2000000280000000700000005000000010008000000000028000000c40e0000"
     "c40e000023000000230000009fded600d4debe0035b9d60000debb009fb994006ab97200d4b960003594"
     "de006ade1f0035de230000b93000d49434009f9444006a943f0000942500d46f5c006a6f1e009f6f1700"
     "356f2c00006f18006a4ad900d44a9d00004aca009f4a710035256d009f00cb000000a5006a007b00d425"
     "3c009f2519006a252e00354a130000254d00d400490035001d00211c150f0b060100191d17110c040000"
     "1b1e14100d05080022181f12070209001a2016130e0a0300"
     ]))
   b8-bmp-sum "2dd82c2130dc85d76cd20f442798ab95593552987be2a902ed5098ea31adf904"  ; 234 bytes, 35 px
   b16-bmp (unx (cats [
     "424d86000000000000003600000028000000070000000500000001001000000000005000000000000000"
     "0000000000000000000000001a149a383a2dba295a1afa4e7a4300001318937c3371b3055322f306733f"
     "00000d1c8d582d3dad514d62ed0e6d4b000006088628265da601465ae67266130000006880782021a045"
     "403ee02e605f0000"
     ]))
   b16-bmp-sum "6f3a90a8366197f21f4c6e09f0492f2a47ec18b62498ccf86293f7f45850a4ca"  ; 134 bytes, 35 px
   b24-bmp (unx (cats [
     "424dae0000000000000036000000280000000700000005000000010018000000000078000000c40e0000"
     "c40e00000000000000000000d40049d4253cd44a9dd46f5cd49434d4b960d4debe0000009f00cb9f2519"
     "9f4a719f6f179f94449fb9949fded60000006a007b6a252e6a4ad96a6f1e6a943f6ab9726ade1f000000"
     "35001d35256d354a13356f2c3594de35b9d635de230000000000a500254d004aca006f1800942500b930"
     "00debb000000"
     ]))
   b24-bmp-sum "2dd82c2130dc85d76cd20f442798ab95593552987be2a902ed5098ea31adf904"  ; 174 bytes, 35 px
   b32-bmp (unx (cats [
     "424dc2000000000000003600000028000000070000000500000001002000000000008c000000c40e0000"
     "c40e00000000000000000000d400c5ffd425b100d44aec80d46f56ffd4943b80d4b91e00d4de93009f00"
     "feff9f25e9009f4a2f809f6ff2ff9f9421009fb99eff9fdee4806a00d6006a25af006a4afa806a6f14ff"
     "6a9427ff6ab9a0806adeb3ff3500990035255cff354a7c00356f99ff3594fd8035b9e58035de25000000"
     "31ff002520ff004a1eff006f69800094da8000b9eeff00dee880"
     ]))
   b32-bmp-sum "11e9985cc4e9d049babc4a19009fcc89f0732a66176edefebd16b324397a08c6"  ; 194 bytes, 35 px
   m32a-bmp (unx (cats [
     "424d16010000000000008a0000007c000000070000000500000001002000030000008c00000000000000"
     "0000000000000000000000000000ff0000ff0000ff000000000000ff424752738fc2f52851b81e151e85"
     "eb01333333136666662666666606999999093d0ad703285c8f3200000000000000000000000004000000"
     "000000000000000000000000d400c5ffd425b100d44aec80d46f56ffd4943b80d4b91e00d4de93009f00"
     "feff9f25e9009f4a2f809f6ff2ff9f9421009fb99eff9fdee4806a00d6006a25af006a4afa806a6f14ff"
     "6a9427ff6ab9a0806adeb3ff3500990035255cff354a7c00356f99ff3594fd8035b9e58035de25000000"
     "31ff002520ff004a1eff006f69800094da8000b9eeff00dee880"
     ]))
   m32a-bmp-sum "67e68fe5d914fca6f22f3f59a51c10d12ee7ecbd929eca76008ce2ee35d37976"  ; 278 bytes, 35 px
   m565-bmp (unx (cats [
     "424dda000000000000008a0000007c000000070000000500000001001000030000005000000000000000"
     "00000000000000000000000000f80000e00700001f00000000000000424752738fc2f52851b81e151e85"
     "eb01333333136666662666666606999999093d0ad703285c8f3200000000000000000000000004000000"
     "0000000000000000000000001a483a395a9a7a5bba34da65fabe000013c833195372731bb344d395f3d6"
     "00000d782d314dd26d23ad44cd75ed260000062026694612662ba6dcc6d5e626000000a0204940ca601b"
     "a024c035e0be0000"
     ]))
   m565-bmp-sum "b1e3cd45475b914b673037a34914959428bbfcdd92024e066bbdc4111633ce61"  ; 218 bytes, 35 px
   m4444-bmp (unx (cats [
     "424dda000000000000008a0000007c000000070000000500000001001000030000005000000000000000"
     "000000000000000000000000000f0000f00000000f00000000f00000424752738fc2f52851b81e151e85"
     "eb01333333136666662666666606999999093d0ad703285c8f3200000000000000000000000004000000"
     "0000000000000000000000000cfc2c0a4c8e7cf59c83bc02dc09000009ff290e498379fe9902b9f9d98d"
     "0000060d260a468f76f196f2b689d6fb0000030923f5430773f9938fb38dd302000000f320f240f27086"
     "908db0fed08e0000"
     ]))
   m4444-bmp-sum "b6edf97735b744cae969754747514d70671d88bbc78fa82268a9f3442b53b27c"  ; 218 bytes, 35 px
   mrle8-bmp (unx (cats [
     "424d92040000000000003604000028000000070000000500000001000800010000005c00000000000000"
     "00000000000100000001000035001d0000254d0035256d00006f1800354a1300356f2c006a252e006a00"
     "7b006a6f1e000000a500004aca006a4ad9000094250000b9300035de23006a943f006ab972006ade1f00"
     "3594de0035b9d60000debb009f2519009f6f17009f4a7100d4253c00d4004900d46f5c009f00cb00d44a"
     "9d009f944400d4943400d4b960009fb994009fded600d4debe0000000000000000000000000000000000"
     "000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
     "000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
     "000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
     "000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
     "000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
     "000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
     "000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
     "000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
     "000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
     "000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
     "000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
     "000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
     "000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
     "000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
     "000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
     "000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
     "000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
     "000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
     "000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
     "000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
     "0000000000000000000000000000000000000000000000000000000001190118011c011a011e011f0122"
     "01000000011b011501170116011d012001210100000001070106010b0108010f01100111010000000100"
     "01020104010501120113010e0100000001090101010a0103010c010d0114010000000001"
     ]))
   mrle8-bmp-sum "2dd82c2130dc85d76cd20f442798ab95593552987be2a902ed5098ea31adf904"  ; 1170 bytes, 35 px
   core-bmp (unx (cats [
     "424d92000000000000001a0000000c0000000700050001001800d4001cd425b1d44aabd46f90d494fcd4"
     "b92ed4de070000009f00469f25629f4a9d9f6f679f94059fb9219fded00000006a00646a25286a4a2c6a"
     "6ffd6a948c6ab9596ade6900000035006f35258d354a5c356f4635945c35b97535de5900000000000000"
     "2592004a5f006fb80094de00b91400ded1000000"
     ]))
   core-bmp-sum "91333c016d9fa080c47f405e208fb29b04eaf2eae2aa5b29381f3005f59858ac"  ; 146 bytes, 35 px
   top-bmp (unx (cats [
     "424dae00000000000000360000002800000007000000fbffffff010018000000000078000000130b0000"
     "130b00000000000000000000000000002592004a5f006fb80094de00b91400ded100000035006f35258d"
     "354a5c356f4635945c35b97535de590000006a00646a25286a4a2c6a6ffd6a948c6ab9596ade69000000"
     "9f00469f25629f4a9d9f6f679f94059fb9219fded0000000d4001cd425b1d44aabd46f90d494fcd4b92e"
     "d4de07000000"
     ]))
   top-bmp-sum "91333c016d9fa080c47f405e208fb29b04eaf2eae2aa5b29381f3005f59858ac"  ; 174 bytes, 35 px
   rle4-bmp (unx (cats [
     "424d8c000000000000007600000028000000080000000300000001000400020000001600000000000000"
     "00000000100000000000000000ff000010ef080020df100030cf180040bf200050af2800609f3000708f"
     "3800807f4000906f4800a05f5000b04f5800c03f6000d02f6800e01f7000f00f78000512000334500000"
     "02770002010103ab000008cd0001"
     ]))
   rle4-bmp-sum "cc51f7bd05ac09619dc6eb0c1f60bf795bb548a46f9c259f5442efe5bae998d2"  ; 140 bytes, 24 px
   i8b-ico (unx (cats [
     "000001000100080800000000200028010000160000002800000008000000100000000100200000000000"
     "00010000c40e0000c40e0000000000000000000000d200ff3fd21e807ed23c00bdd25afffcd278803bd2"
     "96007ad2b4ffb9d2d28000b4000036b41eff6cb43c80a2b45a00d8b478ff0eb4968044b4b4007ab4d2ff"
     "009600802d961e005a963cff87965a80b4967800e19696ff0e96b4803b96d200007800ff24781e804878"
     "3c006c785aff90787880b4789600d878b4fffc78d280005a00001b5a1eff365a3c80515a5a006c5a78ff"
     "875a9680a25ab400bd5ad2ff003c0080123c1e00243c3cff363c5a80483c78005a3c96ff6c3cb4807e3c"
     "d200001e00ff091e1e80121e3c001b1e5aff241e78802d1e9600361eb4ff3f1ed2800000000000001eff"
     "00003c8000005a00000078ff000096800000b4000000d2ff"
     ]))
   i8b-ico-sum "10822c16723771e868cd7afd43039ca456d76802ab121b806cf0236a8389aa2e"  ; 318 bytes, 64 px
   i8p-ico (unx (cats [
     "00000100010008080000000020009c0000001600000089504e470d0a1a0a0000000d4948445200000008"
     "000000080806000000c40fbe8b0000006349444154789c75cda10a03311405d15358b3363610151b1bdb"
     "5fcbfbf257139676dbbae1ce857940231bd158773e34c9199c8bf38b0fcd1e4a5282f2c18766bf4b5017"
     "35a917bf25ca963de88b9ef47ba26e3992118c5f89bee55ccc7f89b198c9335e5ca2312d32723f0f0000"
     "000049454e44ae426082"
     ]))
   i8p-ico-sum "10822c16723771e868cd7afd43039ca456d76802ab121b806cf0236a8389aa2e"  ; 178 bytes, 64 px
   (is s w h sum) ((snip s 0 2 = "BM" ? (bmp-decode s) (ico-decode s)) @ d
                     (two? d && d 0 = w && d 1 = h && sha256 (d 2) = sum))
   _ (test (bmp-size b1-bmp = [7 5]) (bmp-size core-bmp = [7 5]) (bmp-size top-bmp = [7 5])
           (bmp-size rle4-bmp = [8 3]) (ico-size i8b-ico = [8 8]) (ico-size i8p-ico = [8 8])
           (is b1-bmp 7 5 b1-bmp-sum) (is b4-bmp 7 5 b4-bmp-sum) (is b8-bmp 7 5 b8-bmp-sum)
           (is b16-bmp 7 5 b16-bmp-sum) (is b24-bmp 7 5 b24-bmp-sum) (is b32-bmp 7 5 b32-bmp-sum)
           (is m32a-bmp 7 5 m32a-bmp-sum) (is m565-bmp 7 5 m565-bmp-sum) (is m4444-bmp 7 5 m4444-bmp-sum)
           (is mrle8-bmp 7 5 mrle8-bmp-sum) (is core-bmp 7 5 core-bmp-sum) (is top-bmp 7 5 top-bmp-sum)
           (is rle4-bmp 8 3 rle4-bmp-sum) (is i8b-ico 8 8 i8b-ico-sum) (is i8p-ico 8 8 i8p-ico-sum)
           ; one picture, three ways: a palette, 24 bits, rle8
           (b8-bmp-sum = b24-bmp-sum) (mrle8-bmp-sum = b24-bmp-sum)
           ; the core header and a top-down one lay the same rows
           (core-bmp-sum = top-bmp-sum))

   ; -- against PIL ---------------------------------------------------------------------
   pil? (: r (hark ["python3" "-c" "import PIL"]) (two? r) && (<r = 0))
   _ (put (dir + "/mk.py") "import sys, struct, random, shutil, subprocess
from PIL import Image
d = sys.argv[1]; random.seed(7); mg = shutil.which('magick')
def pic(w, h, a):
    im = Image.new('RGBA', (w, h))
    im.putdata([(random.randrange(256), (x * 37) % 256, (y * 53) % 256,
                 random.choice([0, 128, 255]) if a else 255) for y in range(h) for x in range(w)])
    return im
man = []
def ref(n, how='pil'):
    p = d + '/' + n
    if how == 'pil':
        im = Image.open(p).convert('RGBA')
    else:
        w, h = map(int, subprocess.check_output([mg, 'identify', '-format', '%w %h', p + '[0]']).split())
        b = subprocess.check_output([mg, p + '[0]', '-depth', '8', 'rgba:-'])
        if how == 'mg4': b = bytes((v >> 4) * 17 for v in b)
        im = Image.frombytes('RGBA', (w, h), b)
    open(p + '.rgba', 'wb').write(im.tobytes()); man.append('%s %d %d' % (n, im.size[0], im.size[1]))
def mk(n, args, src):
    s = d + '/src.png'; src.save(s); subprocess.check_call([mg, s] + args + [d + '/' + n])
for w, h in [(7, 5), (13, 9), (1, 1), (33, 17)]:
    b = pic(w, h, 0); a = pic(w, h, 1); t = '%dx%d' % (w, h)
    for n, im in [('b1', b.convert('1')), ('b8g', b.convert('L')), ('b4', b.convert('RGB').quantize(16)),
                  ('b8', b.convert('RGB').quantize(200)), ('b24', b.convert('RGB')), ('b32', a)]:
        im.save('%s/%s-%s.bmp' % (d, n, t)); ref('%s-%s.bmp' % (n, t))
    if mg:
        for n, args, src, how in [('m32a', [], a, 'pil'),
                                  ('m565', ['-alpha', 'off', '-define', 'bmp:subtype=RGB565'], b, 'pil'),
                                  ('m555', ['-alpha', 'off', '-define', 'bmp:subtype=RGB555'], b, 'pil'),
                                  ('m4444', ['-define', 'bmp:subtype=ARGB4444'], a, 'mg4'),
                                  ('mrle8', ['-type', 'palette', '-colors', '60', '-compress', 'rle',
                                             '-define', 'bmp:format=bmp3'], b, 'pil')]:
            mk('%s-%s.bmp' % (n, t), args, src); ref('%s-%s.bmp' % (n, t), how)
big = pic(48, 48, 1)
big.save(d + '/png.ico', sizes=[(16, 16), (32, 32), (48, 48)]); ref('png.ico')
big.save(d + '/bmp.ico', sizes=[(16, 16), (48, 48)], bitmap_format='bmp'); ref('bmp.ico')
if mg:
    mk('m8.ico', ['-resize', '24x24', '-type', 'palette', '-colors', '40', '-alpha', 'off'], big); ref('m8.ico')
open(d + '/manifest', 'w').write(chr(10).join(man) + chr(10))
")
   (same l) (: ws (split " " l) nm (ws 0) s (rd (dir + "/" + nm))
               d (has? nm ".ico" ? (ico-decode s) (bmp-decode s))
               (two? d && d 0 = <(sound (ws 1)) && d 1 = <(sound (ws 2)) && d 2 = rd (dir + "/" + nm + ".rgba")))
   _ (pil? ? (: r (hark ["python3" (dir + "/mk.py") dir])
                ls (filter (l \ 0 < #l) (split "\n" (rd (dir + "/manifest"))))
                (test (<r = 0) (20 < #ls) (atom? (filter (l \ !(same l)) ls))))
        (gate-partly "bmp: no python3 PIL, its pictures skipped"))

   ; -- the refusals --------------------------------------------------------------------
   (flip s i) (cask #s @ c (map (k \ pin c k (s k)) (jot #s), pin c i (255 - s i), string c))
   (with s i v) (cask #s @ c (map (k \ pin c k (s k)) (jot #s), pin c i v, string c))
   (sane d) (string? d || two? d)
   (test (bmp-decode "hello" = "not a bmp") (bmp-size "hello" = "not a bmp")
         (ico-decode "hello" = "not an icon") (ico-size (snip i8b-ico 0 10) = "cut short")
         (bmp-decode (snip b24-bmp 0 60) = "cut short")
         (bmp-decode (with b24-bmp 30 4) = "a compression this can't read")
         (bmp-decode (with b24-bmp 28 7) = "a depth this can't read")
         (bmp-decode (with b24-bmp 14 20) = "a kind of bmp this can't read")
         ; every cut and every flipped byte answers why, or a picture, and never takes the process down
         (atom? (filter (i \ !(sane (bmp-decode (snip b24-bmp 0 i)))) (jot #b24-bmp)))
         (atom? (filter (i \ !(sane (bmp-decode (flip b8-bmp i)))) (jot #b8-bmp)))
         (atom? (filter (i \ !(sane (bmp-decode (flip rle4-bmp i)))) (jot #rle4-bmp)))
         (atom? (filter (i \ !(sane (bmp-decode (flip m4444-bmp i)))) (jot #m4444-bmp)))
         (atom? (filter (i \ !(sane (ico-decode (flip i8b-ico i)))) (jot #i8b-ico)))
         (atom? (filter (i \ !(sane (ico-decode (flip i8p-ico i)))) (jot #i8p-ico))),
    hark ["rm" "-rf" dir],
    0))

(test_fin (), puts "bmp: ok", putc 10, 0)
