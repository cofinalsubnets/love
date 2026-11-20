; wchisp -- WCH's USB ISP bootloader, the mask rom a CH32V20x shows as 4348:55e0 or 1a86:55e0
; with BOOT0 held over reset: name the chip, read its config, erase, write, verify and boot.
;   love src/tools/wchisp.l info                 the chip, its bootloader, uid and option bytes
;   love src/tools/wchisp.l flash IN.bin         IN at the flash's start: erase, write, verify, boot
;   love src/tools/wchisp.l frames IN.bin UID VARIANT SEED   the bulk bytes flash sends, a packet
;                                                a line in hex, against a chip that answers so
; a request is its command, the data's length in 16 bits little-endian, the data; an answer
; the command, a byte, the length, the data, a status first where it has one. written data
; rides XORed with a key the chip derives from a seed sent it, its uid and its variant
(borrow 'posix)
(borrow 'usb)
(borrow 'hashes)                       ; sha256, for a seed
(: magic "MCU ISP & WCH.CN" family 25 piece 56 erase-min 8
   (die m) (udie 1 ("wchisp: " + m))
   (hd d) (string (d < 10 ? (48 + d) (87 + d)))
   (hx2 b) (hd (b >> 4) + hd (b & 15))
   (hex s) (cats (map (i \ hx2 (s i)) ^#s))
   (unhex t) (: (nib c) (c < 58 ? (c - 48) ((c | 32) - 87)) (map (i \ nib (t (2 * i)) << 4 | nib (t (2 * i + 1))) ^(#t // 2)))
   (bytes s) (map s ^#s)
   (le16 n) [(n & 255) (n >> 8 & 255)]
   (le32 n) (le16 n + le16 (n >> 16))
   (pkt c ds) (string ([c] + le16 #ds + ds))
   ; --- the requests ---
   (ask-id _) (pkt 161 ([0 family] + bytes magic))
   (ask-cfg _) (pkt 167 [31 0])
   (ask-seed sd) (pkt 163 sd)
   (ask-erase n) (pkt 164 (le32 (max erase-min ((n + 1023) // 1024))))
   (xor ds key) (map (i \ ds i ^ key (i % 8)) ^#ds)
   (ask-write o ds key) (pkt 165 (le32 o + [0] + xor ds key))
   (ask-verify o ds key) (pkt 166 (le32 o + [0] + xor ds key))
   (ask-end _) (pkt 162 [1])
   ; ..the key from a seed of 30 to 60 bytes, the uid's bytes summed and the variant
   (key-of sd uid var) (: n #sd a (n // 5) b (n // 7) u (+uid & 255) (k i) (sd i ^ u) k0 (k (4 * b))
     [k0 (k a) (k b) (k (6 * b)) (k (3 * b)) (k (3 * a)) (k (5 * b)) (k0 + var & 255)])
   ; ..an image padded with 0xff to a multiple of 8, in pieces of 56 at their offsets
   (padded s) (s + string (map (_ \ 255) ^((8 - #s % 8) % 8)))
   (pieces s) (map (o \ [o (bytes (snip s o (min #s (o + piece))))]) (map (i \ i * piece) ^((#s + piece - 1) // piece)))
   (writes s key) (map (p \ ask-write (p 0) (p 1) key) (pieces s) + [(ask-write #s [] key)])
   (verifies s key) (map (p \ ask-verify (p 0) (p 1) key) (pieces s))
   ; ..what flash sends, in order, given the chip's uid and variant and the two seeds
   (session img uid var s1 s2) (: s (padded img)
     ([(ask-id ()) (ask-cfg ()) (ask-seed s1) (ask-erase #s)] + writes s (key-of s1 uid var)
      + [(ask-seed s2)] + verifies s (key-of s2 uid var) + [(ask-end ())]))
   ; --- the answers: [command status data], status the data's first byte ---
   (answer r) (#r < 4 ? () (: n (r 2 | r 3 << 8) d (bytes (snip r 4 (4 + n))) [(r 0) (d @ () () _ <d) d]))
   ; ..a config read: [option bytes, bootloader version, uid]
   (config d) [(take 12 (drop 2 d)) (take 4 (drop 14 d)) (take 8 (drop 18 d))]
   ; --- the device: found under /sys, its bulk pair from its first interface's endpoints ---
   sys "/sys/bus/usb/devices/"
   (rd p) (uread p @ [1 s] (s @ (t + "\n") t t) "")
   (wch? d) (: v (rd (sys + d + "/idVendor")) p (rd (sys + d + "/idProduct")) (p = "55e0" && (v = "4348" || v = "1a86")))
   (find _) (filter wch? (filter (d \ !(elem 58 (bytes d))) (sort (readdir sys))))
   (num s) (foldl (\ a c (a * 10 + c - 48)) 0 (bytes s))
   (hexn s) (foldl (\ a c (a * 16 + (c < 58 ? (c - 48) ((c | 32) - 87)))) 0 (bytes s))
   (pad3 n) ((n < 10 ? "00" (n < 100 ? "0" "")) + show n)
   (node d) "/dev/bus/usb/\(pad3 (num (rd (sys + d + "/busnum"))))/\(pad3 (num (rd (sys + d + "/devnum"))))"
   (eps d) (: f (sys + d + "/" + d + ":1.0/") es (filter (e \ snip e 0 3 = "ep_") (sort (readdir f)))
     bulk (filter (e \ rd (f + e + "/type") = "Bulk") es) (dir w) (filter (e \ rd (f + e + "/direction") = w) bulk)
     (dir "out" @ (o . _) (dir "in" @ (i . _) [(hexn (rd (f + o + "/bEndpointAddress"))) (hexn (rd (f + i + "/bEndpointAddress")))] _ ()) _ ()))
   (open-chip _) (: ds (find ())
     (? (atom? ds) (die "no bootloader on usb: hold BOOT over a reset (4348:55e0 or 1a86:55e0)")
        (two? >ds) (die ("more than one bootloader: " + join " " ds))
        (: d <ds e (eps d) fd (openfd (node d) 6)
           (? (atom? e) (die ("no bulk pair under " + d))
              (!(charm? fd)) (die ("cannot open " + node d + ": " + show fd + " (the udev rule?)"))
              (usb-claim fd 0 @ () 0 e (die ("cannot claim its interface: " + show e))) 0
              {'fd fd 'out (e 0) 'in (e 1)}))))
   (talk c q) (: n (usb-bulk (c 'fd) (c 'out) q 2000) b (cask 64)
     (? (n != #q) (die ("a request went short: " + show n))
        (: m (usb-bulk (c 'fd) (c 'in) b 5000)
           (charm? m ? (answer (snip (string b) 0 m)) (die ("no answer: " + show m))))))
   (shut c) (usb-release (c 'fd) 0, close (c 'fd))
   ; ..each answer as it ought to be: its command, and a status of 0 where asked
   (ok c q ok0) (talk c q @ a (? (atom? a || a 0 != q 0) (die ("an answer to another command: " + hex q))
                                 (ok0 && a 1 != 0) (die ("command " + hx2 (q 0) + " failed: " + hx2 (a 1)))
                                 a))
   ; --- the verbs ---
   (hello c) (: id (ok c (ask-id ()) 0) d (id 2)
     (? (#d < 2 || d 0 = 241) (die "the bootloader would not identify")
        (d 1 != family) (die ("not a CH32V20x: chip type " + hx2 (d 1)))
        (: cf (config ((ok c (ask-cfg ()) 0) 2)) [(d 0) (d 1) cf])))
   (say-chip h) (: cf (h 2) v (cf 1)
     (puts ("chip type " + hx2 (h 1) + " variant " + hx2 (h 0) + ", bootloader " + show (v 0) + show (v 1) + "." + show (v 2) + show (v 3)
            + ", uid " + hex (string (cf 2)) + "\noption bytes " + hex (string (cf 0)) + "\n")))
   (info _) (: c (open-chip ()) h (hello c) (say-chip h, shut c))
   (seed _) (: s (sha256 (show (nclock 0))) t (sha256 (s + show (getpid 0))) (take 60 (bytes (s + t))))
   (flash path) (: img (uread path @ [1 s] s (die ("cannot read " + path)))
     (? (#img = 0 || #img > 262144) (die "an image of 1 byte to 256K")
        (: c (open-chip ()) h (hello c) cf (h 2) _ (say-chip h)
           _ (cf 0 0 != 165 ? (die "read protected (RDPR not a5): unprotecting erases the chip, not done here") 0)
           s (padded img) var (h 0) uid (cf 2)
           (keyed sd) (: k (key-of sd uid var) a (ok c (ask-seed sd) 0) (a 1 != (+k & 255) ? (die "the chip derived another key") k))
           k1 (keyed (seed ()))
           _ (ok c (ask-erase #s) 1, puts ("erased " + show (max erase-min ((#s + 1023) // 1024)) + "K\n"))
           _ (each (writes s k1) (q \ ok c q 1))
           k2 (keyed (seed ()))
           _ (each (verifies s k2) (q \ ok c q 1))
           _ (puts ("wrote and verified " + show #img + " bytes; booting it\n"))
           (talk c (ask-end ()), shut c))))
   (frames path uid var sd) (: img (uread path @ [1 s] s (die ("cannot read " + path)))
     (each (session img (unhex uid) (hexn var) (unhex sd) (unhex sd)) (q \ puts (hex q + "\n"))))
   (main as) (as @
     ["info"] (info ())
     ["flash" p] (flash p)
     ["frames" p u v s] (frames p u v s)
     _ (die "usage: love src/tools/wchisp.l info | flash IN.bin | frames IN.bin UID VARIANT SEED"))
   (main >argv))
