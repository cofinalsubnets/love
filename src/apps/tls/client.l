; src/apps/tls/client.l -- a TLS 1.3 client over the ciphers beside it: x25519 for the key
; share, HKDF-SHA256 for the schedule, chacha20-poly1305 for the records. one suite, one
; group, one version -- what every server of the last five years speaks, and what a
; fetch needs. ⚠ the peer is NOT verified: the certificate is read into the transcript and
; believed. that is an integrity-and-privacy channel against a passive wire, not an
; identity, and a caller that needs identity should say so before trusting a byte.
;
;   (tls-dial host port)   resolve, connect, shake hands -> a session | ()
;   (tls-say t s)          send s as application data
;   (tls-slurp t)          every byte of application data the peer sends, to its close
;   (tls-close t)          a close_notify, and the socket shut
;
; the session is a tablet: the socket, a pending-bytes run, the two traffic keys and their
; sequence numbers, the transcript. x25519 rides the bignums (RFC 7748's ladder, the field
; by `%` and `//` -- bit ops on bigs are not a floor this tree stands on yet), which is
; milliseconds for one handshake.
(module 'tls
(use 'dns)
(:
   ; --- bytes and words ---
   (u8 v) (string (v & 255))
   (u16 v) (u8 (v >> 8) + u8 v)
   (u24 v) (u8 (v >> 16) + u16 v)
   (u32 v) (u8 (v >> 24) + u24 v)
   (rd16 s i) ((s i << 8) + s (i + 1))
   (rd24 s i) ((s i << 16) + rd16 s (i + 1))
   (zeros n) (bytes n (i \ 0))
   (xors a b) (bytes #a (i \ a i ^ b i))
   ; a small count as eight bytes, either end first
   (u64le n) (bytes 8 (i \ (n >> (8 * i)) & 255))
   (u64be n) (bytes 8 (i \ (n >> (8 * (7 - i))) & 255))
   (pad16 s) (zeros ((16 - (#s % 16)) % 16))

   ; --- the hash floor: sha256 raw, hmac, hkdf ---
   (sha s) (unhex (sha256 s))
   (hmac k m) (: kp (k + zeros (64 - #k))
                 (sha ((xors kp (bytes 64 (i \ 92))) + sha ((xors kp (bytes 64 (i \ 54))) + m))))
   (hkdf-extract salt ikm) (hmac salt ikm)
   (hkdf-label secret label ctx n)                                   ; HKDF-Expand-Label, n <= 32
    (: lab ("tls13 " + label)
       info (u16 n + u8 #lab + lab + u8 #ctx + ctx)
       (snip (hmac secret (info + u8 1)) 0 n))
   (derive secret label tr) (hkdf-label secret label (sha tr) 32)

   ; --- x25519 ---
   p25519 ((255 2) - 19)
   (fmod a) (% (+ (% a p25519) p25519) p25519)                        ; % truncates: fold a negative back in
   (fmul a b) (fmod (a * b))
   (finv a) (modpow a (p25519 - 2) p25519)
   (le-num s) (: (go i a) (? (i < 0) a (go (i - 1) ((a * 256) + s i))) (go (#s - 1) 0))
   (le-bytes n) (bytes 32 (i \ (% (// n ((8 * i) 2)) 256)))
   (bit k t) (% (// k (t 2)) 2)
   ; the ladder, RFC 7748 section 5: the state is (x2 z2 x3 z3), swapped by the scalar's bits
   (ladder k u)
    (: a24 121665
       (step st t)
        (: x2 <st z2 <>st x3 (st 2) z3 (st 3)
           a (fmod (x2 + z2)) aa (fmul a a) b (fmod (x2 - z2)) bb (fmul b b) e (fmod (aa - bb))
           c (fmod (x3 + z3)) d (fmod (x3 - z3)) da (fmul d a) cb (fmul c b)
           s1 (fmod (da + cb)) s2 (fmod (da - cb))
           [(fmul aa bb) (fmul e (fmod (aa + (a24 * e)))) (fmul s1 s1) (fmul u (fmul s2 s2))])
       (swap st) [(st 2) (st 3) <st <>st]
       (go t st sw)
        (? (t < 0) (sw ? (swap st) st)
           (: kt (bit k t)
              st2 (? (= 1 (sw ^ kt)) (swap st) st)
              (go (t - 1) (step st2 t) kt)))
       r (go 254 [1 0 u 1] 0)
       (fmul <r (finv <>r)))
   (x25519 k u)
    (: kk (bytes 32 (i \ (? (i = 0) (k 0 & 248) (i = 31) ((k 31 & 127) | 64) (k i))))
       uu (% (le-num u) (255 2))
       (le-bytes (ladder (le-num kk) uu)))
   (x25519-pub k) (x25519 k (bytes 32 (i \ (i = 0 ? 9 0))))

   (rnd n) (: q (open "/dev/urandom" "r")
              b (bytes n (i \ (see q)))
              _ (close q)
              b)

   ; --- the aead, RFC 8439: the poly key is block zero of the stream ---
   (nonce iv seq) (xors iv (zeros 4 + u64be seq))
   (aead-seal key iv seq aad pt)
    (: nn (nonce iv seq)
       pk (snip (cc-stream key nn 0 1) 0 32)
       ct (cc-xor key nn 1 pt)
       (ct + po-mac pk (aad + pad16 aad + ct + pad16 ct + u64le #aad + u64le #ct)))
   (aead-open key iv seq aad ctag)
    (: n (#ctag - 16)
       (? (n < 0) ()
          (: nn (nonce iv seq)
             pk (snip (cc-stream key nn 0 1) 0 32)
             ct (snip ctag 0 n)
             tag (snip ctag n #ctag)
             (? (= tag (po-mac pk (aad + pad16 aad + ct + pad16 ct + u64le #aad + u64le #ct)))
                [1 (cc-xor key nn 1 ct)]
                ()))))

   ; --- the wire: exact reads over the socket, a run kept between records ---
   (rd t n)
    (: (go pend) (? (n <= #pend) pend
                    (: c (see (t 's))
                       (? (c = -1) ()
                          (go (pend + string c + chug (t 's))))))
       pend (go (t 'pend))
       (? !(string? pend) ()
          (: _ (pin t 'pend (snip pend n #pend))
             [1 (snip pend 0 n)])))
   (rdrec t)                                                           ; -> (type body) | ()
    (: h (rd t 5)
       (? !(two? h) ()
          (: hdr <>h
             b (rd t (rd16 hdr 3))
             (? !(two? b) () [(hdr 0) <>b]))))
   (wr t s) (say (t 's) s, flush (t 's))
   ; one encrypted record out under the client's current key; type rides the inner tail
   (seal t type pt)
    (: inner (pt + u8 type)
       aad (u8 23 + u16 771 + u16 (#inner + 16))
       ct (aead-seal (t 'ckey) (t 'civ) (t 'cseq) aad inner)
       _ (pin t 'cseq (t 'cseq + 1))
       (wr t (aad + ct)))
   ; one record in: a plaintext CCS is skipped, an encrypted one opened under the server's
   ; key -> (inner-type body) | () at the end or on a bad tag
   (open-rec t)
    (: r (rdrec t)
       (? !(two? r) ()
          (<r = 20) (open-rec t)
          !(<r = 23) ()
          (: body <>r
             aad (u8 23 + u16 771 + u16 #body)
             pt (aead-open (t 'skey) (t 'siv) (t 'sseq) aad body)
             _ (pin t 'sseq (t 'sseq + 1))
             (? !(two? pt) ()
                (: s <>pt
                   (strip i) (? ((i > 0) && (s (i - 1) = 0)) (strip (i - 1)) i)
                   e (strip #s)
                   (? (e < 1) () [(s (e - 1)) (snip s 0 (e - 1))]))))))

   ; --- handshake messages off the decrypted stream, each added to the transcript ---
   (hs-next t)
    (: (go buf) (? ((4 <= #buf) && ((4 + rd24 buf 1) <= #buf))
                   (: n (4 + rd24 buf 1)
                      msg (snip buf 0 n)
                      _ (pin t 'hbuf (snip buf n #buf))
                      _ (pin t 'tr (t 'tr + msg))
                      [(buf 0) (snip msg 4 n)])
                   (: r (open-rec t)
                      (? !(two? r) ()
                         (<r = 22) (go (buf + <>r))
                         (go buf))))
       (go (t 'hbuf)))

   ; --- the client hello ---
   (ext type body) (u16 type + u16 #body + body)
   (client-hello host pub sid)
    (: sni (ext 0 (u16 (#host + 3) + u8 0 + u16 #host + host))
       groups (ext 10 (u16 2 + u16 29))
       sigs (ext 13 (u16 12 + u16 1027 + u16 2052 + u16 1025 + u16 2055 + u16 2053 + u16 1281))
       vers (ext 43 (u8 2 + u16 772))
       modes (ext 45 (u8 1 + u8 1))
       share (ext 51 (u16 36 + u16 29 + u16 32 + pub))
       exts (sni + groups + sigs + vers + modes + share)
       body (u16 771 + rnd 32 + u8 32 + sid + u16 2 + u16 4867 + u8 1 + u8 0 + u16 #exts + exts)
       (u8 1 + u24 #body + body))
   ; the server hello's key share, and its version: () for any hello we cannot use
   (server-share body)
    (: sidn (body 34)
       i (35 + sidn)
       suite (rd16 body i)
       extn (rd16 body (i + 3))
       (go j end share ok)
        (? (j + 4 > end) (? (ok && (string? share)) share ())
           (: ty (rd16 body j) ln (rd16 body (j + 2)) d (snip body (j + 4) (j + 4 + ln))
              (go (j + 4 + ln) end
                  (? ((ty = 51) && (rd16 d 0 = 29) && (rd16 d 2 = 32)) (snip d 4 36) share)
                  (? ((ty = 43) && (rd16 d 0 = 772)) 1 ok))))
       (? !(suite = 4867) ()
          (go (i + 5) (i + 5 + extn) () 0)))

   ; --- the handshake, whole ---
   (tls-dial host port)
    (: s (dial host port)
       (? !(hot? s) ()
          (: t (tablet 16)
             _ (pin t 's s) _ (pin t 'pend "") _ (pin t 'hbuf "") _ (pin t 'tr "")
             _ (pin t 'cseq 0) _ (pin t 'sseq 0)
             priv (rnd 32)
             ch (client-hello host (x25519-pub priv) (rnd 32))
             _ (pin t 'tr ch)
             _ (wr t (u8 22 + u16 769 + u16 #ch + ch))
             r (rdrec t)
             (? (!(two? r) || !(<r = 22) || !((<>r) 0 = 2)) (close s, ())
                (: sh <>r
                   _ (pin t 'tr (t 'tr + sh))
                   share (server-share (snip sh 4 #sh))
                   (? !(string? share) (close s, ())
                      (: shared (x25519 priv share)
                         early (hkdf-extract (zeros 32) (zeros 32))
                         hs (hkdf-extract (derive early "derived" "") shared)
                         chs (derive hs "c hs traffic" (t 'tr))
                         shs (derive hs "s hs traffic" (t 'tr))
                         _ (pin t 'ckey (hkdf-label chs "key" "" 32)) _ (pin t 'civ (hkdf-label chs "iv" "" 12))
                         _ (pin t 'skey (hkdf-label shs "key" "" 32)) _ (pin t 'siv (hkdf-label shs "iv" "" 12))
                         ; the server's flight: extensions, the certificate, its verify, finished
                         (flight _) (: m (hs-next t)
                                      (? !(two? m) ()
                                         (<m = 20) m
                                         (flight 0)))
                         fin (flight 0)
                         (? !(two? fin) (close s, ())
                            (: ; the client finished is over the transcript through the server's
                               fkey (hkdf-label chs "finished" "" 32)
                               vd (hmac fkey (sha (t 'tr)))
                               cfin (u8 20 + u24 32 + vd)
                               _ (wr t (u8 20 + u16 771 + u16 1 + u8 1))          ; a CCS for the middleboxes
                               _ (seal t 22 cfin)
                               master (hkdf-extract (derive hs "derived" "") (zeros 32))
                               cap (derive master "c ap traffic" (t 'tr))
                               sap (derive master "s ap traffic" (t 'tr))
                               _ (pin t 'ckey (hkdf-label cap "key" "" 32)) _ (pin t 'civ (hkdf-label cap "iv" "" 12))
                               _ (pin t 'skey (hkdf-label sap "key" "" 32)) _ (pin t 'siv (hkdf-label sap "iv" "" 12))
                               _ (pin t 'cseq 0) _ (pin t 'sseq 0)
                               t)))))))))

   ; --- the application half ---
   (tls-say t s)
    (: n #s
       (go i) (? (n <= i) 0
                 (: k (? ((n - i) < 16384) (n - i) 16384)
                    _ (seal t 23 (snip s i (i + k)))
                    (go (i + k))))
       (go 0))
   (tls-slurp t)
    (: j (jug 0)
       (go _) (: r (open-rec t)
                 (? !(two? r) 0
                    (<r = 23) (say j <>r, go 0)
                    (<r = 21) 0                                        ; an alert: close_notify or worse, the end either way
                    (go 0)))                                            ; a ticket, a key update: not ours
       _ (go 0)
       (slurp j))
   (tls-close t) (: _ (seal t 21 (u8 1 + u8 0)) (close (t 's))))
) ; module tls
