; --- test/digest.l: the digests in love/lib/hash.c, held to what publishes them ---
; named digest, not hash, because test/hash.l is the tablet's.
; apps/kore's checksum tools are these plus a line of output, and test/kore/sum.sh holds those to GNU coreutils -- so this file is
; the half of the rope that does not need another implementation on the box.
;
;   vectors   RFC 1321's md5 suite, fips 180-4's sha examples and RFC 7693's blake2b
;             one, verbatim. a digest with no love twin has nothing else to be right
;             against.
;   cksum     ..except this one, which gets a twin: the POSIX crc is short enough to
;             state in love, so `hash-ckwalk` below is the statement of the polynomial
;             and the C is held to it at every length 0..129. the walk is written from
;             the standard and not from the C: same poly 0x04c11db7, register the other
;             way round from crc32's, seed 0, and the byte count walked through after
;             the message, low byte first, which is why an empty file is 4294967295.
;   lengths   the block is 64 bytes and the length rides the last 8 of it, so 55/56 and
;             119/120 are where a padding off by one shows (sha-384/512: 128 and 16,
;             so 111/112 and 239/240; blake2b holds a block back, so 128 and 256).
;   misuse    value ops: a wrong shape answers (), it does not digest.
;   stream    <X>-init/feed/done is the same digest resumable -- every one of them --
;             and its oracle is the one-shot beside it: fed in chunks of every awkward
;             size, at every length where the padding could slip, it must answer what
;             the one-shot answers. a second spelling of the compression function is
;             exactly what this must not be, so the test is agreement and not another
;             vector. the state's width is the only thing telling them apart, so the
;             misuse cases feed each nif its neighbours' casks.
;
; run:  cat test/00-init.l test/digest.l | out/love
(test
 (lit? sha256)
 (lit? md5)
 (lit? cksum))

(: (hash-mk n f) (: b (cask n) (go i) (? (n <= i) (string b) (: _ (pin b i (f i)) (go (i + 1)))) (go 0))
   hash-alpha "abcdefghijklmnopqrstuvwxyz"
   hash-mixed ("ABCDEFGHIJKLMNOPQRSTUVWXYZ" + hash-alpha + "0123456789")
   hash-nums  (: (go k a) (? (k < 1) a (go (k - 1) (a + "1234567890"))) (go 8 ""))
   hash-56 "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
   hash-112 ("abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmn"
             + "hijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu")
   ; the bytes, not the text: NULs and the high half included
   (hash-bytes n) (hash-mk n (\ i (((i * 2654435761) >> 11) & 255))))

; --- md5, RFC 1321 appendix A.5 ---
(test
 (md5 "" = "d41d8cd98f00b204e9800998ecf8427e")
 (md5 "a" = "0cc175b9c0f1b6a831c399e269772661")
 (md5 "abc" = "900150983cd24fb0d6963f7d28e17f72")
 (md5 "message digest" = "f96b697d7cb7938d525a2f31aaf161d0")
 (md5 hash-alpha = "c3fcd3d76192e4007dfb496cca67e13b")
 (md5 hash-mixed = "d174ab98d277d9f5a5611c2c9f419d9f")
 (md5 hash-nums = "57edf4a22be3c955ac49da2e2107b67a"))

; --- sha-256, fips 180-4 ---
(test
 (sha256 "" = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
 (sha256 "abc" = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
 (sha256 hash-56 = "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1")
 (sha256 hash-112 = "cf5b16a778af8380036ce59e7b0492370b249b11e8f07a51afac45037afee9d1"))

; --- cksum: the love statement of the polynomial, and the C against it ---
(: hash-m32 4294967295
   (hash-ckstep c) (: c2 ((c << 1) & hash-m32)
                      (? (0 < (c & 2147483648)) (c2 ^ 79764919) c2))
   (hash-ckbyte c b) (: (go c i) (? (i < 1) c (go (hash-ckstep c) (i - 1)))
                        (go (c ^ ((b & 255) << 24)) 8))
   ; the message, then its own length low byte first, then the register complemented
   (hash-ckwalk s)
    (: n #s
       (fold c m) (m < 1 ? (c ^ hash-m32) (fold (hash-ckbyte c (m & 255)) (m >> 8)))
       (go c i) (n <= i ? (fold c n) (go (hash-ckbyte c (s i)) (i + 1)))
       (go 0 0))
   (hash-cksame s) (? ((cksum s) = (hash-ckwalk s)) 1 0)
   (hash-cklen k) (: (go i) (? (k < i) 1 !(hash-cksame (hash-bytes i)) 0 (go (i + 1)))
                     (go 0)))
(test
 (930766865 = cksum "123456789")          ; what POSIX publishes for cksum
 (4294967295 = cksum "")                  ; the length fold: an empty message still turns it
 (hash-cklen 129)
 (hash-cksame hash-mixed)
 (hash-cksame (hash-mk 300 (i \ 0)))        ; 300 NULs: the register turns on a zero byte
 (charm? (cksum (hash-mk 300 (i \ 0)))))

; --- the lengths either side of a block and its length field ---
(: (hash-hexlen s n) (: d (n @ 32 (md5 s) (sha256 s))
                        (go k) (n <= k ? 1
                                (d k @ c (? (47 < c < 58 || 96 < c < 103) (go (k + 1)) 0)))
                        (#d = n ? (go 0) 0))
   (hash-shape ls)
    (? !(two? ls) 1
       (: s (hash-bytes <ls)
          (? !(hash-hexlen s 32) 0
             !(hash-hexlen s 64) 0
             !(hash-cksame s) 0
             (hash-shape >ls)))))
(test (hash-shape '(0 1 54 55 56 57 63 64 65 118 119 120 127 128 129 200)))

; --- misuse: value ops, so a wrong shape answers () ---
(test
 !(string? (md5 7))
 !(string? (md5 ()))
 !(string? (md5 (cask 8)))
 !(string? (sha256 7))
 !(string? (sha256 (iota 8)))
 !(charm? (cksum 7))
 !(charm? (cksum ()))
 !(charm? (cksum (cask 8))))

; --- the three resumable digests: each stream against its own one-shot ---------------
; the state is a cask the caller owns, and the width is the type -- 105 for sha-256,
; 89 for md5, 12 for cksum. a cask of any other size, or a feed of anything that is not
; a string, is a misuse and answers (); which is what stops one digest's state being
; fed to another's nif and answering a number that looks like an answer.
(: sha-st 105
   md5-st  89
   ck-st   12
   ; a text fed k bytes at a time through (width init feed done) -> the digest
   (dig-stream d s k)
    (: b (cask <d)
       _ (<>d b)
       n #s
       (go i) (n <= i ? (<>>>d b)
                 (: j (n < i + k ? n (i + k))
                    _ (<>>d b (snip s i j))
                    (go j)))
       (go 0))
   dig-sha (\ _ [sha-st sha256-init sha256-feed sha256-done])
   dig-md5 (\ _ [md5-st  md5-init    md5-feed    md5-done])
   dig-ck  (\ _ [ck-st   cksum-init  cksum-feed  cksum-done])
   ; init and feed answer the cask itself: a value the collector can walk, held live
   ; across a collection by whoever binds it
   (dig-gc d s) (: b (cask <d) (<>d b, <>>d b s, please 1, <>>>d b))
   (sha-stream s k) (dig-stream (dig-sha 0) s k)
   (md5-stream s k) (dig-stream (dig-md5 0) s k)
   (ck-stream s k)  (dig-stream (dig-ck 0) s k)
   ; every length across both padding boundaries (55/56 and 119/120), each fed whole
   ; and in chunks that divide the block, straddle it, and outrun it
   (dig-agree? n)
    (: s (hash-bytes n)
       (go ks) (? (atom? ks) 1
                  (? (sha256 s = sha-stream s <ks &&
                      md5 s = md5-stream s <ks &&
                      cksum s = ck-stream s <ks)
                     (go >ks) 0)))
   (sha-sweep lo hi) (:- (go lo) (go n)
    (hi < n ? 1 (dig-agree? n '(1 3 7 63 64 65 127 128) ? (go (n + 1)) 0))))

(test
 (lit? sha256-init) (lit? sha256-feed) (lit? sha256-done)
 ; the published vectors, arrived at a byte at a time
 (sha-stream "" 1 = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
 (sha-stream "abc" 1 = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
 (sha-stream hash-56 1 = sha256 hash-56)
 (sha-stream hash-112 7 = sha256 hash-112)
 ; the state outlives a collection with init's answer still bound
 (dig-gc (dig-sha 0) "abc" = sha256 "abc")
 (dig-gc (dig-md5 0) "abc" = md5 "abc")
 (dig-gc (dig-ck 0) "abc" = cksum "abc")
 ; 0..130 by every chunking: the block, the two pad boundaries, and past them
 (sha-sweep 0 130)
 ; a body that outruns any one feed, at a chunk size that is not a block multiple
 (sha-stream (hash-bytes 100000) 65536 = sha256 (hash-bytes 100000))
 (sha-stream (hash-bytes 100000) 1000 = sha256 (hash-bytes 100000))
 ; misuse: the state is a 105-byte cask or it is nothing
 !(sha256-init (cask 8))
 !(sha256-init "not a cask")
 !(sha256-feed (cask 8) "x")
 !(sha256-feed (cask sha-st) 7)
 !(sha256-done (cask 8))
 !(sha256-done "not a cask")
 ; --- md5 and cksum stream the same way ---
 (lit? md5-init) (lit? md5-feed) (lit? md5-done)
 (lit? cksum-init) (lit? cksum-feed) (lit? cksum-done)
 (md5-stream "" 1 = "d41d8cd98f00b204e9800998ecf8427e")
 (md5-stream "abc" 1 = "900150983cd24fb0d6963f7d28e17f72")
 (md5-stream hash-112 7 = md5 hash-112)
 (md5-stream (hash-bytes 100000) 1000 = md5 (hash-bytes 100000))
 ; cksum folds the length in at the end, so the empty file is 4294967295 and not 0 --
 ; the one place a streamed digest could plausibly answer "nothing fed" and be wrong
 (ck-stream "" 4 = 4294967295) (ck-stream "" 4 = cksum "")
 (ck-stream (hash-bytes 100000) 1000 = cksum (hash-bytes 100000))
 ; misuse, and crosswise: a state of the wrong width is refused, which is the only
 ; thing between three digests that all take a cask and a string
 !(md5-init (cask sha-st)) !(sha256-init (cask md5-st))
 !(cksum-init (cask sha-st)) !(md5-init (cask ck-st))
 !(md5-feed (cask md5-st) 7) !(cksum-feed (cask ck-st) 7)
 !(md5-done (cask 8)) !(cksum-done (cask 8)))

;; --- sha-1, sha-224, sha-384, sha-512 (fips 180-4) and blake2b (rfc 7693) ---
(test
 (lit? sha1) (lit? sha224) (lit? sha384) (lit? sha512) (lit? blake2b)
 (sha1 "" = "da39a3ee5e6b4b0d3255bfef95601890afd80709")
 (sha1 "abc" = "a9993e364706816aba3e25717850c26c9cd0d89d")
 (sha1 hash-56 = "84983e441c3bd26ebaae4aa1f95129e5e54670f1")
 (sha224 "abc" = "23097d223405d8228642a477bda255b32aadbce4bda0b3f7e36c9da7")
 (sha224 hash-56 = "75388b16512776cc5dba5da1fd890150b0c6455cb4f58b1952522525")
 (sha384 "abc" = "cb00753f45a35e8bb5a03d699ac65007272c32ab0eded1631a8b605a43ff5bed8086072ba1e7cc2358baeca134c825a7")
 (sha384 hash-112 = "09330c33f71147e83d192fc782cd1b4753111b173b3b05d22fa08086e3b0f712fcc7c71a557e2db966c3e9fa91746039")
 (sha512 "abc" = "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f")
 (sha512 hash-112 = "8e959b75dae313da8cf4f72814fc143f8f7779c6eb9f7fa17299aeadb6889018501d289e4900f7e4331b99dec4b5433ac7d329eeb6dd26545e96e55b874be909")
 (blake2b "abc" = "ba80a53f981c4d0d6a2797b69f12f6e94c212f14685ac4b74b12bb6fdbffa2d17d87c5392aab792dc252d5de4533cc9518d38aa8dbf1925ab92386edd4009923")
 !(string? (sha1 7)) !(string? (sha512 ())) !(string? (blake2b (cask 8))))

; --- the four newer block digests and blake2b, streamed against their one-shots ---
; sha-384/512 run a 128-byte block with a 16-byte length, so 111/112 and 239/240 are
; their pad boundaries; blake2b holds a whole block back until it knows whether it was
; the last, so 128, 256 and one either side are where it could slip
(: dig-sha1 (\ _ [93 sha1-init sha1-feed sha1-done])
   dig-sha224 (\ _ [106 sha224-init sha224-feed sha224-done])
   dig-sha384 (\ _ [202 sha384-init sha384-feed sha384-done])
   dig-sha512 (\ _ [201 sha512-init sha512-feed sha512-done])
   (dig-b2 n) [210 (\ b (blake2b-init b n)) blake2b-feed blake2b-done]
   (dig-agree2? n)
    (: s (hash-bytes n)
       (go ks) (? (atom? ks) 1
                  (? (sha1 s = dig-stream (dig-sha1 0) s <ks &&
                      sha224 s = dig-stream (dig-sha224 0) s <ks &&
                      sha384 s = dig-stream (dig-sha384 0) s <ks &&
                      sha512 s = dig-stream (dig-sha512 0) s <ks &&
                      blake2b s = dig-stream (dig-b2 64) s <ks)
                     (go >ks) 0)))
   (dig-sweep2 ns) (? !(two? ns) 1 (dig-agree2? <ns '(1 7 64 127 128 129) ? (dig-sweep2 >ns) 0))
   ; bsd sum's rotate-then-add, stated in love
   (hash-bsdwalk s) (: (go c i) (? (#s <= i) c (go ((((c >> 1) | ((c & 1) << 15)) + s i) & 65535) (i + 1))) (go 0 0))
   (hash-bsdsame s) (? (bsdsum 0 s = hash-bsdwalk s) 1 0))
(test
 (dig-sweep2 '(0 1 55 56 63 64 65 111 112 119 120 127 128 129 239 240 255 256 257 1000))
 (dig-stream (dig-sha512 0) (hash-bytes 100000) 1000 = sha512 (hash-bytes 100000))
 (dig-stream (dig-b2 64) (hash-bytes 100000) 65536 = blake2b (hash-bytes 100000))
 ; a shorter blake2b is its own digest, not a prefix of the long one
 (dig-stream (dig-b2 32) "abc" 1 = "bddd813c634239723171ef3fee98579b94964e3bb1cb3e427262c8c068d52319")
 (dig-stream (dig-b2 1) "" 1 = "2e")
 !(blake2b-init (cask 210) 0) !(blake2b-init (cask 210) 65) !(blake2b-init (cask 202) 64)
 ; the widths are the types: each refuses its neighbours' casks
 !(sha224-init (cask 105)) !(sha256-init (cask 106)) !(sha384-init (cask 201))
 !(sha512-init (cask 202)) !(sha1-init (cask 89)) !(sha1-done (cask 89))
 !(sha384-feed (cask 202) 7)
 ; bsd sum against the love statement, carried across a split as sum carries it
 (hash-bsdsame "") (hash-bsdsame hash-mixed) (hash-bsdsame (hash-bytes 1000))
 (bsdsum (bsdsum 0 (hash-bytes 500)) (snip (hash-bytes 1000) 500 1000) = bsdsum 0 (hash-bytes 1000))
 !(charm? (bsdsum 0 7)) !(charm? (bsdsum "x" "y")))

;; --- sha-3 (fips 202) through its sponge, and crc32 carried across a split ---
(: (dig-k3 bits sh) [204 (\ b (sha3-init b bits sh)) sha3-feed sha3-done])
(test
 (lit? sha3) (lit? sha3-init) (lit? crc32-on)
 (sha3 "" = "a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a")
 (sha3 "abc" = "3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532")
 (dig-stream (dig-k3 224 0) "abc" 1 = "e642824c3f8cf24ad09234ee7d3c766fc9a3a5168d0c94ad73b46fdf")
 (dig-stream (dig-k3 384 0) "abc" 2 = "ec01498288516fc926459f58e2c6ad8df9b473cb0fc08c2596da7cf0e49be4b298d88cea927ac7f539f1edf228376d25")
 (dig-stream (dig-k3 512 0) "abc" 3 = "b751850b1a57168a5693cd924b6b096e08f621827444f70d884f5d0240d2712e10e116e9192af3c91a7ec57647e3934057340b4cf408d5a56592f8274eec53f0")
 ; shake256's pad and rate, 32 bytes out
 (dig-stream (dig-k3 256 1) "abc" 1 = "483366601360a8771c6863080cc4114d8db44530f8f1e1ee4f94ea37e78b5739")
 ; the rate is 136 bytes at 256 bits: either side of it, and past it, by every chunking
 (dig-stream (dig-k3 256 0) (hash-bytes 135) 7 = sha3 (hash-bytes 135))
 (dig-stream (dig-k3 256 0) (hash-bytes 136) 136 = sha3 (hash-bytes 136))
 (dig-stream (dig-k3 256 0) (hash-bytes 100000) 1000 = sha3 (hash-bytes 100000))
 !(sha3-init (cask 204) 7 0) !(sha3-init (cask 204) 520 0) !(sha3-init (cask 202) 256 0)
 !(sha3-feed (cask 204) "x")
 (crc32-on 0 "" = 0)
 (crc32-on (crc32-on 0 (hash-bytes 500)) (snip (hash-bytes 1000) 500 1000) = crc32 (hash-bytes 1000))
 (crc32-on 0 "123456789" = 3421780262))

(: _ (test_fin ())
   _ (puts "digest: ok -- md5, the shas, sha-3 and blake2b on their published vectors, each stream
      against its one-shot, cksum and bsd sum against love walks
")
   0)
