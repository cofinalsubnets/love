; test/host/tlsc.l -- the C twins of the ciphers held to the love files, which are the oracle:
; the RFC ciphertext and tag off the C side, every length 0..129, the block counter carried into
; a batch, and misuse answering (). poly1305's conditional subtract is unreachable from a
; message, so only test/host/tls.l reaches it.
; not in the corpus: host nifs. run: cat test/00-init.l test/host/tlsc.l | out/love

(borrow "src/apps/tls/tls.l")

(test
 (lit? chacha20)
 (lit? poly1305))

; the fixtures, leaked on purpose (a body-less `:`) so every assert below shares
; them -- the shape test/host/tls.l wears.
(: ckey (bytes 32 (i \ i))
   cnon (bytes 12 (i \ (i = 7 ? 74 0)))            ; §2.4.2's nonce: ..4a
   (cmsg n) (bytes n (i \ (i * 7 + 11 & 255)))   ; a fixed pseudo-random run
   ; the first length at which the twins disagree, or -1 if none does. a bare
   ; false would say "somewhere"; this names the block edge it broke on.
   (cbad i n) (n < i ? -1 (cmsg i @ m
                    (? !(chacha20 ckey cnon 1 m = cc-xor ckey cnon 1 m) i
                       !(poly1305 ckey m = po-mac ckey m) i
                       (cbad (i + 1) n))))
   (cctrbad c n) (cmsg 512 @ big                   ; eight blocks, so it carries
                    (? (n < c) -1
                       !(chacha20 ckey cnon c big = cc-xor ckey cnon c big) c
                       (cctrbad (c + 1) n))))

; --- vectors: the C side against the RFC, not merely against love ------------------
(: pt242 ("Ladies and Gentlemen of the class of '99: If I could offer you only "
          + "one tip for the future, sunscreen would be it.")
   k252 (unhex "85d6be7857556d337f4452fe42d506a80103808afb0db2fd4abff6af4149f51b")
   (test
    (hex (chacha20 ckey cnon 1 pt242)
     = ("6e2e359a2568f98041ba0728dd0d6981e97e7aec1d4360c20a27afccfd9fae0b"
        + "f91b65c5524733ab8f593dabcd62b3571639d624e65152ab8f530c359f0861d8"
        + "07ca0dbf500d6a6156a38e088a22b65e52bc514d16ccf806818ce91ab7793736"
        + "5af90bbf74a35be6b40b8eedf2785e42874d"))
    (hex (poly1305 k252 "Cryptographic Forum Research Group")
     = "a8061dc1305136c6c22b8baf0c0127a9")
    ; xor is its own inverse in C too, so the twin decrypts what it encrypted
    (pt242 = chacha20 ckey cnon 1 (chacha20 ckey cnon 1 pt242))))

; --- lengths: the two twins agree at every length across both block edges ----------
(test
 (-1 = cbad 0 129)
 ; ..and the run is not two piles of nothing: lengths differ, counters differ
 !(poly1305 ckey (cmsg 32) = poly1305 ckey (cmsg 33))
 !(chacha20 ckey cnon 1 (cmsg 64) = chacha20 ckey cnon 2 (cmsg 64)))

; --- counters: love varies the counter down a galaxy, C walks it ------------------
(test
 (-1 = cctrbad 0 5)
 ; block 1 of a batch is what counter 2 gives on its own -- love's vectorised
 ; galaxy and C's loop, meeting on the same 64 bytes
 (snip (chacha20 ckey cnon 1 (cmsg 512)) 64 128
  = cc-xor ckey cnon 2 (snip (cmsg 512) 64 128))
 ; a counter step really moves the keystream, so the above compares something
 !(chacha20 ckey cnon 1 (cmsg 512) = chacha20 ckey cnon 3 (cmsg 512)))

; --- misuse: a value op, so a wrong shape answers () and encrypts nothing ----------
(: shortk (bytes 31 (i \ i))
   longn (bytes 16 (i \ i))
   (test
    !(chacha20 shortk cnon 1 "hello")
    !(chacha20 ckey longn 1 "hello")
    !(chacha20 ckey cnon 'x "hello")
    !(chacha20 ckey cnon -1 "hello")
    !(poly1305 shortk "hello")
    !(poly1305 ckey 'x)
    ; ..and the empty message is a real answer, not a misuse: a 16-byte tag
    (16 = #(poly1305 ckey ""))
    (poly1305 ckey "" = po-mac ckey "")))

; --- aes-gcm: C alone, so the numbers are NIST's (the GCM spec's test cases 1-4, 13, 14,
; 16) -- empty and one-block messages under zero keys, the 64-byte message, the 60-byte
; one with 20 bytes of aad, and aes-256's. then a message round-trips at every length
; 0..70 across the block edges, a flipped tag or byte is refused, and misuse answers ()
(: k0 (unhex "00000000000000000000000000000000") iv0 (unhex "000000000000000000000000")
   k3 (unhex "feffe9928665731c6d6a8f9467308308") iv3 (unhex "cafebabefacedbaddecaf888")
   p3 (unhex "d9313225f88406e5a55909c5aff5269a86a7a9531534f7da2e4c303d8a318a721c3c0c95956809532fcf0e2449a6b525b16aedf5aa0de657ba637b391aafd255")
   c3 (unhex "42831ec2217774244b7221b784d0d49ce3aa212f2c02a4e035c17e2329aca12e21d514b25466931c7d8f6a5aac84aa051ba30b396a0aac973d58e091473f5985")
   a4 (unhex "feedfacedeadbeeffeedfacedeadbeefabaddad2")
   k32 (unhex "0000000000000000000000000000000000000000000000000000000000000000")
   k16 (unhex "feffe9928665731c6d6a8f9467308308feffe9928665731c6d6a8f9467308308")
   (hx s) (hex s)
   _ (test (hx (aes-gcm-seal k0 iv0 "" "") = "58e2fccefa7e3061367f1d57a4e7455a")
         (hx (aes-gcm-seal k0 iv0 "" (unhex "00000000000000000000000000000000"))
          = "0388dace60b6a392f328c2b971b2fe78ab6e47d42cec13bdf53a67b21257bddf")
         (aes-gcm-seal k3 iv3 "" p3 = c3 + unhex "4d5c2af327cd64a62cf35abd2ba6fab4")
         (aes-gcm-seal k3 iv3 a4 (snip p3 0 60) = snip c3 0 60 + unhex "5bc94fbc3221a5db94fae95ae7121a47")
         (hx (aes-gcm-seal k32 iv0 "" "") = "530f8afbc74536b9a963b4f1c4cb738b")
         (hx (aes-gcm-seal k32 iv0 "" (unhex "00000000000000000000000000000000"))
          = "cea7403d4d606b6e074ec5d3baf39d18d0d1c8a799996bf0265b98b5d48ab919")
         (aes-gcm-seal k16 iv3 a4 (snip p3 0 60)
          = unhex "522dc1f099567d07f47f37a32a84427d643a8cdcbfe5c0c97598a2bd2555d1aa8cb08e48590dbb3da7b08b1056828838c5f61e6393ba7a0abcc9f662"
            + unhex "76fc6ece0f4e1768cddf8853bb2d551b")
         (aes-gcm-open k3 iv3 a4 (snip c3 0 60 + unhex "5bc94fbc3221a5db94fae95ae7121a47") = snip p3 0 60)
         !(aes-gcm-open k3 iv3 a4 (snip c3 0 60 + unhex "5bc94fbc3221a5db94fae95ae7121a46"))
         !(aes-gcm-open k3 iv3 "" (snip c3 0 60 + unhex "5bc94fbc3221a5db94fae95ae7121a47"))
         !(aes-gcm-seal (snip k3 0 15) iv3 "" "x") !(aes-gcm-seal k3 (snip iv3 0 11) "" "x")
         !(aes-gcm-open k3 iv3 "" (zeros 15)))
   (rt n) (: m (bytes n (i \ (i * 13 + 7) & 255)) s (aes-gcm-seal k3 iv3 a4 m)
             flip (0 < n ? (string (s 0 ^ 1) + snip s 1 #s))
             (#s = n + 16 && aes-gcm-open k3 iv3 a4 s = m && (0 = n || !(aes-gcm-open k3 iv3 a4 flip))))
   (test (0 = #(filter (n \ !(rt n)) (jot 71)))))

(test_fin (),
 puts "src/apps/tls: ok -- the C twins agree with love (vectors, lengths, counters, misuse); aes-gcm holds NIST's cases
",
 0)
