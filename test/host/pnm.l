; test/host/pnm.l -- src/apps/pnm.l: netpbm's pictures, read and written
; each kind PIL and magick write -- P1 to P6, 16 bits a sample, pam rgba and grey-alpha -- decoded
; to rgba by sha-256; odd maxvals, comments, pam's black-and-white; ppm and pam written and read
; back. then, where python3's PIL is, more held to PIL's decode byte for byte (magick's for the
; text kinds, 16-bit grey and pam); last the refusals.
;   cat test/00-init.l test/host/pnm.l | out/love
(borrow 'posix)
(borrow 'hashes)
(borrow 'pnm)
(borrow "src/apps/pnm.l")
(: dir (cwd 0 + "/out/.pnmd")
   _ (hark ["rm" "-rf" dir], mkdir dir 448)
   (rd p) (: q (open p "r") s (slurp q) (close q, s))
   (put p s) (open p "w" @ q (say q s, close q))
   (nib c) (? (c < 58) (c - 48) (c - 87))
   (unx h) (cask (#h // 2) @ c (map (i \ pin c i (nib (h (2 * i)) * 16 + nib (h (2 * i + 1)))) (jot (#h // 2)),
                               string c))
   (px d) (map (k \ d 2 k) (jot #(d 2)))

   ; -- fixtures --
   p1-pbm (unx (cats [
     "50310a3720350a312031203120312030203020300a312031203120312030203020300a31203120312031"
     "2030203020300a312031203120312030203020300a312031203120302030203020300a"
     ]))
   p1-pbm-sum "84b23f2e298a168f15d607132b643a125edc86bb03fe48afeb285a97f1e138b3"  ; 77 bytes, 35 px
   p2-pgm (unx (cats [
     "50320a3720350a3235350a33352034332039362038342031313420313433203139390a31302035332036"
     "312039332031353720313832203137300a3334203434203130372039332031323720313634203137330a"
     "35352034332038382039362031333220313735203231360a333120353520313032203131342031333220"
     "313638203231340a"
     ]))
   p2-pgm-sum "dcc4600b4a32488c54304e42ada9f415cd72d04225112bf016190c6052a336a0"  ; 134 bytes, 35 px
   p4-pbm (unx (cats [
     "50340a3720350ad8f4d2a8d8"
     ]))
   p4-pbm-sum "80d6f7a6833d6e459509a52aa19bbf9062a2f6b7752e7cf6130e4e26138aa447"  ; 12 bytes, 35 px
   p6-ppm (unx (cats [
     "50360a3720350a3235350aa500004d2500ca4a00186f0025940030b900bbde001d00356d2535134a352c"
     "6f35de9435d6b93523de357b006a2e256ad94a6a1e6f6a3f946a72b96a1fde6acb009f19259f714a9f17"
     "6f9f44949f94b99fd6de9f4900d43c25d49d4ad45c6fd43494d460b9d4beded4"
     ]))
   p6-ppm-sum "2dd82c2130dc85d76cd20f442798ab95593552987be2a902ed5098ea31adf904"  ; 116 bytes, 35 px
   p5d16-pgm (unx (cats [
     "50350a3720350a36353533350a233a2b01604154d172288f12c74f0a0835ad3d075ced9d7eb659aab321"
     "f12c116b235dc77f63a4d7adaf36dc2b6c58c66020844caff1d8981ef336bd660272b284b9a8aed750"
     ]))
   p5d16-pgm-sum "dcc4600b4a32488c54304e42ada9f415cd72d04225112bf016190c6052a336a0"  ; 83 bytes, 35 px
   p3d16-ppm (unx (cats [
     "50330a3720350a36353533350a3432343035203020302031393738392039353039203020353139313420"
     "3139303138203020363136382032383532372030203935303920333830333620300a3132333336203437"
     "353435203020343830353920353730353420302037343533203020313336323120323830313320393530"
     "392031333632310a34383833203139303138203133363231203131333038203238353237203133363231"
     "2035373035342033383033362031333632310a3534393938203437353435203133363231203839393520"
     "353730353420313336323120333136313120302032373234322031313832322039353039203237323432"
     "0a3535373639203139303138203237323432203737313020323835323720323732343220313631393120"
     "33383033362032373234320a323932393820343735343520323732343220373936372035373035342032"
     "373234322035323137312030203430383633203634323520393530392034303836330a32393034312031"
     "393031382034303836332035393131203238353237203430383633203137343736203338303336203430"
     "3836330a3338303336203437353435203430383633203534393938203537303534203430383633203138"
     "373631203020353434383420313534323020393530392035343438340a34303334392031393031382035"
     "343438342032333634342032383532372035343438342031333336342033383033362035343438340a32"
     "343637322034373534352035343438342034383833302035373035342035343438340a"
     ]))
   p3d16-ppm-sum "2dd82c2130dc85d76cd20f442798ab95593552987be2a902ed5098ea31adf904"  ; 581 bytes, 35 px
   pam-rgba-pam (unx (cats [
     "50370a574944544820370a48454947485420350a444550544820340a4d415856414c203235350a545550"
     "4c54595045205247425f414c5048410a454e444844520a310000ff202500ff1e4a00ff696f0080da9400"
     "80eeb900ffe8de0080990035005c2535ff7c4a3500996f35fffd943580e5b9358025de3500d6006a00af"
     "256a00fa4a6a80146f6aff27946affa0b96a80b3de6afffe009fffe9259f002f4a9f80f26f9fff21949f"
     "009eb99fffe4de9f80c500d4ffb125d400ec4ad480566fd4ff3b94d4801eb9d40093ded400"
     ]))
   pam-rgba-pam-sum "67e68fe5d914fca6f22f3f59a51c10d12ee7ecbd929eca76008ce2ee35d37976"  ; 205 bytes, 35 px
   pam-greya-pam (unx (cats [
     "50370a574944544820370a48454947485420350a444550544820320a4d415856414c203235350a545550"
     "4c5459504520475241595343414c455f414c5048410a454e444844520a0aff21ff3bff66809880b7ffd0"
     "80240032ff530074ffa380b980aa003500470072805bff7affae80ccff41ff57004a808eff7c00b1ffdb"
     "8039ff4f00768071ff86809a00cd00"
     ]))
   pam-greya-pam-sum "0c753f00b48a6ffdec629e4e601e2c02c2c8eac2668f5fabc077c36cf1e4da31"  ; 141 bytes, 35 px
   (is s w h sum) (pnm-decode s @ d (two? d && d 0 = w && d 1 = h && sha256 (d 2) = sum))
   _ (test (pnm-size p1-pbm = [7 5]) (pnm-size p6-ppm = [7 5]) (pnm-size pam-rgba-pam = [7 5])
           (is p1-pbm 7 5 p1-pbm-sum) (is p2-pgm 7 5 p2-pgm-sum) (is p4-pbm 7 5 p4-pbm-sum)
           (is p6-ppm 7 5 p6-ppm-sum) (is p5d16-pgm 7 5 p5d16-pgm-sum) (is p3d16-ppm 7 5 p3d16-ppm-sum)
           (is pam-rgba-pam 7 5 pam-rgba-pam-sum) (is pam-greya-pam 7 5 pam-greya-pam-sum)
           ; one picture as text and as bytes, at 8 bits and at 16
           (p2-pgm-sum = p5d16-pgm-sum) (p6-ppm-sum = p3d16-ppm-sum))

   ; a maxval that is not a byte's scales to 8 bits, rounded; a comment is a blank
   _ (test (px (pnm-decode "P2 # two\n2 1\n15\n0 15") = [0 0 0 255 255 255 255 255])
           (px (pnm-decode "P2 3 1 4 1 2 3") = [64 64 64 255 128 128 128 255 191 191 191 255])
           (px (pnm-decode (cats ["P5 1 1 1000\n" (string [1 244])])) = [128 128 128 255])
           (px (pnm-decode "P1\n3 1\n101") = [0 0 0 255 255 255 255 255 0 0 0 255])
           ; pam's black-and-white is 1 white, the bitmaps' other way round
           (px (pnm-decode (cats ["P7\nWIDTH 2\nHEIGHT 1\nDEPTH 1\nMAXVAL 1\nTUPLTYPE BLACKANDWHITE\nENDHDR\n"
                                  (string [0 1])])) = [0 0 0 255 255 255 255 255]))

   ; written and read back: a ppm drops alpha, a pam keeps it
   d (pnm-decode pam-rgba-pam)
   _ (test (pnm-decode (pam-encode (d 0) (d 1) (d 2)) = d)
           (snip (pnm-encode 1 1 (string [1 2 3 4])) 0 11 = "P6\n1 1\n255\n")
           (pnm-decode (pnm-encode (d 0) (d 1) (d 2)) @ e
              (two? e && atom? (filter (k \ e 2 k != (k % 4 = 3 ? 255 (d 2 k))) (jot #(d 2)))))
           (pnm-decode (pnm-encode 7 5 (pnm-decode p6-ppm 2)) = pnm-decode p6-ppm))

   ; -- against PIL --
   pil? (: r (hark ["python3" "-c" "import PIL"]) (two? r) && (<r = 0))
   _ (put (dir + "/mk.py") "import sys, random, shutil, subprocess
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
        w, h = map(int, subprocess.check_output([mg, 'identify', '-format', '%w %h', p]).split())
        im = Image.frombytes('RGBA', (w, h), subprocess.check_output([mg, p, '-depth', '8', 'rgba:-']))
    open(p + '.rgba', 'wb').write(im.tobytes()); man.append('%s %d %d' % (n, im.size[0], im.size[1]))
def mk(n, args, src):
    s = d + '/src.png'; src.save(s); subprocess.check_call([mg, s] + args + [d + '/' + n])
for w, h in [(7, 5), (13, 9), (1, 1), (33, 17)]:
    b = pic(w, h, 0); a = pic(w, h, 1); t = '%dx%d' % (w, h)
    for n, im in [('p4', b.convert('1')), ('p5', b.convert('L')), ('p6', b.convert('RGB'))]:
        e = {'p4': 'pbm', 'p5': 'pgm', 'p6': 'ppm'}[n]
        im.save('%s/%s-%s.%s' % (d, n, t, e)); ref('%s-%s.%s' % (n, t, e))
    if mg:
        for n, args, src in [('p1.pbm', ['-type', 'bilevel', '-compress', 'none'], b),
                             ('p2.pgm', ['-type', 'grayscale', '-compress', 'none'], b),
                             ('p3.ppm', ['-type', 'truecolor', '-compress', 'none'], b),
                             ('p6d16.ppm', ['-depth', '16'], b),
                             ('p5d16.pgm', ['-depth', '16', '-type', 'grayscale'], b),
                             ('p3d16.ppm', ['-depth', '16', '-compress', 'none'], b),
                             ('rgba.pam', ['-type', 'truecoloralpha'], a), ('rgb.pam', ['-type', 'truecolor'], a),
                             ('grey.pam', ['-type', 'grayscale'], a), ('greya.pam', ['-type', 'grayscalealpha'], a)]:
            m = t + '-' + n; mk(m, args, src); ref(m, 'mg')
open(d + '/manifest', 'w').write(chr(10).join(man) + chr(10))
")
   (same l) (: ws (split " " l) nm (ws 0) d (pnm-decode (rd (dir + "/" + nm)))
               (two? d && d 0 = <(sound (ws 1)) && d 1 = <(sound (ws 2)) && d 2 = rd (dir + "/" + nm + ".rgba")))
   _ (pil? ? (: r (hark ["python3" (dir + "/mk.py") dir])
                ls (filter (l \ 0 < #l) (split "\n" (rd (dir + "/manifest"))))
                (test (<r = 0) (10 < #ls) (atom? (filter (l \ !(same l)) ls))))
        (gate-partly "pnm: no python3 PIL, its pictures skipped"))

   ; -- the refusals --
   (flip s i) (cask #s @ c (map (k \ pin c k (s k)) (jot #s), pin c i (255 - s i), string c))
   (sane d) (string? d || two? d)
   (test (pnm-decode "hello" = "not a pnm") (pnm-size "P8 1 1 255\n" = "not a pnm")
         (pnm-decode "P6 2 2 255\n" = "cut short") (pnm-decode "P6 2" = "cut short")
         (pnm-decode "P6 0 1 255\n" = "no pixels") (pnm-decode "P5 1 1 0\nx" = "a bad maxval")
         (pnm-decode "P5 1 1 70000\nxx" = "a bad maxval") (pnm-decode "P2 1 1 4 9" = "a sample past maxval")
         (pnm-decode "P1 2 1 2 0" = "a bad bitmap digit")
         (pnm-decode "P7\nWIDTH 1\nHEIGHT 1\nDEPTH 5\nMAXVAL 255\nENDHDR\n12345" = "a bad depth")
         (pnm-decode "P7\nWIDTH x\nENDHDR\n" = "a bad pam header at WIDTH")
         ; every cut and every flipped byte answers why, or a picture, and never takes the process down
         (atom? (filter (i \ !(sane (pnm-decode (snip p6-ppm 0 i)))) (jot #p6-ppm)))
         (atom? (filter (i \ !(sane (pnm-decode (flip p6-ppm i)))) (jot #p6-ppm)))
         (atom? (filter (i \ !(sane (pnm-decode (flip p1-pbm i)))) (jot #p1-pbm)))
         (atom? (filter (i \ !(sane (pnm-decode (flip pam-greya-pam i)))) (jot #pam-greya-pam)))
         (atom? (filter (i \ !(sane (pnm-decode (flip p5d16-pgm i)))) (jot #p5d16-pgm))),
    hark ["rm" "-rf" dir],
    0))

(test_fin (), puts "pnm: ok", putc 10, 0)
