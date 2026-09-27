; apps/ssh/client.l -- an ssh-2 client: transport (RFC 4253), publickey auth (4252), one
; session channel (4254). one of everything: curve25519-sha256 for the exchange, an
; ssh-ed25519 host key, chacha20-poly1305@openssh.com both ways, and an unencrypted
; ed25519 identity -- what a modern OpenSSH offers first.
;
;   (ssh-dial host port)          connect, exchange keys, check the host -> session | a reason string
;   (ssh-auth t user seed pub)    publickey auth -> 1 | a reason string
;   (ssh-run t cmd pty?)          a session channel: exec cmd, or a shell for () -> exit status;
;                                 a pty follows the terminal's size on each SIGWINCH
;   (ssh-key path)                an openssh-key-v1 file -> [seed pub] | a reason string
;
; the session is a tablet like tls's: the socket, a pending run, a sequence number and
; key pair each way, the session id. the chacha key is 64 bytes, the payload key first
; and the length key second; openssh's nonce is the sequence number, which is the IETF
; nif's nonce with the counter's high word zero ahead of it.
(module 'ssh
(borrow 'tls)
(borrow 'dns)
(borrow 'posix)

(:
   m32 ((1 << 32) - 1)
   ; --- the wire's encodings (RFC 4251 §5) ---
   (be32 s i) ((rd16 s i << 16) + rd16 s (i + 2))
   (sstr s) (u32 #s + s)
   (join sep l) (? (two? l) (foldl (a \ x \ a + sep + x) <l >l) "")
   (names l) (sstr (join "," l))
   (split s ch)
    (: (go i j a) (? (#s <= i) (rev (snip s j i . a))
                     (s i = ch) (go (i + 1) (i + 1) (snip s j i . a))
                     (go (i + 1) j a))
       (go 0 0 ()))
   ; a non-negative big-endian run as an mpint: leading zeros off, a zero byte on a high bit
   (mpint s)
    (: (lead i) (? ((i < #s) && (s i = 0)) (lead (i + 1)) i)
       r (snip s (lead 0) #s)
       (sstr (? ((0 < #r) && (127 < r 0)) (u8 0 + r) r)))

   ; a cursor over a payload: a tablet of the run and an index, read forward
   (cur s) (: c (tablet 2) _ (pin c 's s) _ (pin c 'i 0) c)
   (g-skip c n) (: i (c 'i) _ (pin c 'i (i + n)) i)
   (g-u8 c) ((c 's) (g-skip c 1))
   (g-u32 c) (be32 (c 's) (g-skip c 4))
   (g-str c) (: n (g-u32 c) i (g-skip c n) (snip (c 's) i (i + n)))
   (g-names c) (: s (g-str c) (? (#s = 0) () (split s 44)))

   ; --- base64, both ways (RFC 4648; decode skips what is not the alphabet) ---
   b64a "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
   (b64v c) (? ((64 < c) && (c < 91)) (c - 65) ((96 < c) && (c < 123)) (c - 71)
               ((47 < c) && (c < 58)) (c + 4) (c = 43) 62 (c = 47) 63 -1)
   (b64d s)
    (: vs (filter (v \ -1 < v) (map (i \ b64v (s i)) (jot #s)))
       (go l acc k out)
        (? (two? l) (: a2 ((acc << 6) | <l) k2 (k + 6)
                       (? (8 <= k2) (go >l (a2 & ((1 << (k2 - 8)) - 1)) (k2 - 8) (a2 >> (k2 - 8) . out))
                          (go >l a2 k2 out)))
           (string (rev out)))
       (go vs 0 0 ()))
   (b64e s pad?)
    (: n #s
       (grp i) (: b0 (s i) b1 (? (i + 1 < n) (s (i + 1)) 0) b2 (? (i + 2 < n) (s (i + 2)) 0)
                  v ((b0 << 16) | (b1 << 8) | b2)
                  k (? (i + 2 < n) 4 (i + 1 < n) 3 2)
                  q (string (map (j \ b64a ((v >> (18 - 6 * j)) & 63)) (jot k)))
                  (q + (? pad? (snip "==" 0 (4 - k)) "")))
       (go i a) (? (n <= i) a (go (i + 3) (a + grp i)))
       (go 0 ""))

   ; --- packets: (ssh-send t payload) and (ssh-recv t) -> payload | () ---
   (nonce seq) (zeros 4 + u64be seq)
   (polykey k n) (chacha20 k n 0 (zeros 32))
   (send1 t p)
    (: k (t 'ck) seq (t 'sseq)
       enc (two? k)
       pl (? enc (1 + #p) (5 + #p))
       pd (8 - pl % 8)
       pad (? (pd < 4) (pd + 8) pd)
       body (u8 pad + p + zeros pad)
       len (u32 #body)
       _ (pin t 'sseq ((seq + 1) & m32))
       (? enc
          (: n (nonce seq) el (chacha20 <>k n 0 len) eb (chacha20 <k n 1 body)
             (wr t (el + eb + poly1305 (polykey <k n) (el + eb))))
          (wr t (len + body))))
   ; tasks share the socket, and a write can park: one packet on the wire at a time
   (ssh-send t p) (? (t 'busy) (rest 1, ssh-send t p)
                     (: _ (pin t 'busy 1) r (send1 t p) _ (pin t 'busy 0) r))
   (unpad b) (snip b 1 (#b - b 0))
   (ssh-recv t)
    (: k (t 'sk) seq (t 'rseq)
       _ (pin t 'rseq ((seq + 1) & m32))
       h (rd t 4)
       (? !(two? h) ()
          !(two? k) (: r (rd t (be32 <>h 0)) (? (two? r) (unpad <>r) ()))
          (: n (nonce seq) el <>h
             len (be32 (chacha20 <>k n 0 el) 0)
             r (? (len < 262144) (rd t (len + 16)) ())
             (? !(two? r) ()
                (: eb (snip <>r 0 len)
                   (? !(= (snip <>r len (len + 16)) (poly1305 (polykey <k n) (el + eb))) ()
                      (unpad (chacha20 <k n 1 eb))))))))

   ; the next payload that is not transport noise: ignore, debug and ext-info pass, a
   ; banner goes to stderr, a global request is refused, a disconnect is the end
   (ssh-next t)
    (: p (ssh-recv t)
       (? !(string? p) ()
          (: ty (p 0) c (cur p) _ (g-skip c 1)
             (? ((ty = 2) || (ty = 4) || (ty = 7)) (ssh-next t)
                (ty = 53) (say err (g-str c), ssh-next t)
                (ty = 80) (: _ (g-str c) _ (? (g-u8 c) (ssh-send t (u8 82)) 0) (ssh-next t))
                (ty = 1) (: code (g-u32 c) (say err ("ssh: disconnected: " + g-str c + "\n"), ()))
                p))))
   ; a payload of type ty, or ()
   (expect t ty) (: p (ssh-next t) (? ((string? p) && (p 0 = ty)) p ()))

   ; --- the version lines ---
   (rdline t)
    (: (go a) (: r (rd t 1)
                 (? !(two? r) () (<>r = "\n") a (go (a + <>r))))
       l (go "")
       (? (string? l) (? ((0 < #l) && (l (#l - 1) = 13)) (snip l 0 (#l - 1)) l) ()))
   (server-version t)
    (: l (rdline t)
       (? !(string? l) () ((4 <= #l) && (snip l 0 4 = "SSH-")) l (server-version t)))

   ; --- the exchange: curve25519-sha256 (RFC 8731) ---
   vc "SSH-2.0-love_ssh"
   kexs ["curve25519-sha256" "curve25519-sha256@libssh.org" "ext-info-c" "kex-strict-c-v00@openssh.com"]
   cipher "chacha20-poly1305@openssh.com"
   (kexinit _) (u8 20 + rnd 16 + names kexs + names ["ssh-ed25519"] + names [cipher] + names [cipher]
              + names ["hmac-sha2-256"] + names ["hmac-sha2-256"] + names ["none"] + names ["none"]
              + names [] + names [] + u8 0 + u32 0)
   ; the server's lists, checked against ours -> a reason string, or the strict flag
   (agree is)
    (: c (cur is) _ (g-skip c 17)
       kx (g-names c) hk (g-names c) cs (g-names c) sc (g-names c)
       (? !((elem "curve25519-sha256" kx) || (elem "curve25519-sha256@libssh.org" kx))
          ("no common key exchange; the server offers " + join "," kx)
          !(elem "ssh-ed25519" hk) ("no ssh-ed25519 host key; the server offers " + join "," hk)
          !((elem cipher cs) && (elem cipher sc)) ("no common cipher; the server offers " + join "," cs)
          (elem "kex-strict-s-v00@openssh.com" kx)))

   (ssh-dial host port)
    (: s (dial host port)
       (? !(hot? s) ("cannot connect to " + host + " port " + show port)
          (: t (tablet 16)
             _ (pin t 's s) _ (pin t 'pend "") _ (pin t 'sseq 0) _ (pin t 'rseq 0) _ (pin t 'busy 0)
             _ (wr t (vc + "\r\n"))
             vs (server-version t)
             ic (kexinit 0)
             _ (ssh-send t ic)
             is (expect t 20)
             ok (? (string? vs) (? (string? is) (agree is) "no kexinit") "no version line")
             (? (string? ok) (close s, ok)
                (: priv (rnd 32) qc (x25519-pub priv)
                   _ (ssh-send t (u8 30 + sstr qc))
                   r (expect t 31)
                   (? !(string? r) (close s, "no key exchange reply")
                      (: c (cur r) _ (g-skip c 1)
                         ks (g-str c) qs (g-str c) sg (g-str c)
                         shared (x25519 priv qs)
                         kk (mpint shared)
                         h (sha (sstr vc + sstr vs + sstr ic + sstr is + sstr ks + sstr qc + sstr qs + kk))
                         kc (cur ks) kt (g-str kc) hpk (g-str kc)
                         sc (cur sg) st (g-str sc) sb (g-str sc)
                         (? (= shared (zeros 32)) (close s, "degenerate shared secret")
                            !((kt = "ssh-ed25519") && (st = "ssh-ed25519") && (ed-verify hpk h sb))
                             (close s, "the host key's signature does not verify")
                            (: _ (pin t 'sid h) _ (pin t 'hostkey ks)
                               (kd x) (: k1 (sha (kk + h + x + h)) (k1 + sha (kk + h + k1)))
                               (pair k) [(snip k 0 32) (snip k 32 64)]
                               _ (ssh-send t (u8 21))
                               _ (pin t 'ck (pair (kd "C")))
                               _ (? ok (pin t 'sseq 0) 0)
                               nk (expect t 21)
                               _ (pin t 'sk (pair (kd "D")))
                               _ (? ok (pin t 'rseq 0) 0)
                               (? !(string? nk) (close s, "no newkeys")
                                  (: _ (ssh-send t (u8 5 + sstr "ssh-userauth"))
                                     (? (string? (expect t 6)) t (close s, "no userauth service")))))))))))))

   ; the host key's fingerprint, as openssh prints it
   (ssh-fingerprint t) ("SHA256:" + b64e (sha (t 'hostkey)) 0)

   ; --- publickey auth (RFC 4252 §7) ---
   (ssh-auth t user seed pub)
    (: blob (sstr "ssh-ed25519" + sstr pub)
       head (u8 50 + sstr user + sstr "ssh-connection" + sstr "publickey" + u8 1
             + sstr "ssh-ed25519" + sstr blob)
       sg (ed-sign seed pub (sstr (t 'sid) + head))
       _ (ssh-send t (head + sstr (sstr "ssh-ed25519" + sstr sg)))
       r (ssh-next t)
       (? !(string? r) "the server closed during auth"
          (r 0 = 52) 1
          (r 0 = 51) (: c (cur r) _ (g-skip c 1)
                        ("permission denied (" + join "," (g-names c) + ")"))
          "unexpected auth reply"))

   ; --- the identity: openssh-key-v1 (PROTOCOL.key), unencrypted ed25519 only ---
   (ssh-key path)
    (: q (open path "r")
       (? !(hot? q) ("cannot read " + path)
          (: txt (slurp q) _ (close q)
             body (join "" (filter (l \ !((0 < #l) && (l 0 = 45))) (split txt 10)))
             b (b64d body)
             magic "openssh-key-v1"
             (? !((snip b 0 14) = magic) (path + ": not an openssh private key")
                (: c (cur b) _ (g-skip c 15)
                   ciph (g-str c) _ (g-str c) _ (g-str c) _ (g-u32 c) _ (g-str c)
                   pc (cur (g-str c))
                   c1 (g-u32 pc) c2 (g-u32 pc) ty (g-str pc) pk (g-str pc) sk (g-str pc)
                   (? !(ciph = "none") (path + ": encrypted keys are not supported yet")
                      !(c1 = c2) (path + ": damaged key")
                      !(ty = "ssh-ed25519") (path + ": " + ty + " keys are not supported yet")
                      [(snip sk 0 32) pk]))))))

   ; --- the session channel (RFC 4254) ---
   lwin (1 << 21)
   (chreq t name reply body)
    (ssh-send t (u8 98 + u32 (t 'rch) + sstr name + u8 reply + body))
   ; wait out a channel request's reply, taking window adjusts on the way -> 1 | 0
   (reply t)
    (: p (ssh-next t)
       (? !(string? p) 0
          (p 0 = 99) 1
          (p 0 = 100) 0
          (p 0 = 93) (: c (cur p) _ (g-skip c 5) _ (pin t 'rwin (t 'rwin + g-u32 c)) (reply t))
          (reply t)))
   ; stdin to the channel, a packet per read, inside the peer's window and packet size
   (pump t)
    (: ch (see in)
       (? (ch = -1) (ssh-send t (u8 96 + u32 (t 'rch)))
          (: _ (unsee in ch)
             s (chug in)
             (put1 i) (? (#s <= i) 0
                         (: room (min (t 'rmax) (t 'rwin))
                            (? (room < 1) (rest 5, put1 i)
                               (: n (min room (#s - i))
                                  _ (pin t 'rwin (t 'rwin - n))
                                  _ (ssh-send t (u8 94 + u32 (t 'rch) + sstr (snip s i (i + n))))
                                  (put1 (i + n))))))
             _ (put1 0)
             (pump t))))
   ; the channel's traffic until it closes -> the exit status
   (drain t)
    (: p (ssh-next t)
       (? !(string? p) (t 'status)
          (: ty (p 0) c (cur p) _ (g-skip c 5)
             (? (ty = 94) (: d (g-str c) _ (say out d) _ (flush out)
                             used (t 'used + #d)
                             _ (? (lwin // 2 < used)
                                (ssh-send t (u8 93 + u32 (t 'rch) + u32 used), pin t 'used 0)
                                (pin t 'used used))
                             (drain t))
                (ty = 95) (: _ (g-u32 c) d (g-str c) _ (say err d) _ (flush err)
                             _ (pin t 'used (t 'used + #d))
                             (drain t))
                (ty = 93) (pin t 'rwin (t 'rwin + g-u32 c), drain t)
                (ty = 98) (: nm (g-str c) wr? (g-u8 c)
                             _ (? (nm = "exit-status") (pin t 'status (g-u32 c))
                                  (nm = "exit-signal") (pin t 'status 255)
                                  0)
                             _ (? wr? (ssh-send t (u8 100 + u32 (t 'rch))) 0)
                             (drain t))
                (ty = 97) (: _ (ssh-send t (u8 97 + u32 (t 'rch))) (t 'status))
                (drain t)))))

   ; the terminal's size as the wire's cols, rows and two zero pixel counts
   (geom _) (: a (tty 1) sz (? (two? a) a (tty 0))
               ((? (two? sz) (u32 >sz + u32 <sz) (u32 80 + u32 24)) + u32 0 + u32 0))
   ; SIGWINCH (28 on linux and the BSDs) queued to a signalfd; each wake sends the size now
   (winch t sig) (: _ (await sig) _ (sigtake sig)
                    _ (chreq t "window-change" 0 (geom 0))
                    (winch t sig))

   (ssh-run t cmd pty?)
    (: _ (ssh-send t (u8 90 + sstr "session" + u32 0 + u32 lwin + u32 32768))
       r (ssh-next t)
       (? !((string? r) && (r 0 = 91)) -1
          (: c (cur r) _ (g-skip c 5)
             _ (pin t 'rch (g-u32 c)) _ (pin t 'rwin (g-u32 c)) _ (pin t 'rmax (g-u32 c))
             _ (pin t 'used 0) _ (pin t 'status -1)
             term (: e (getenv "TERM") (? (string? e) e "xterm"))
             _ (? pty? (chreq t "pty-req" 1 (sstr term + geom 0 + sstr (u8 0))) 0)
             okp (? pty? (reply t) 1)
             _ (? (nil? cmd) (chreq t "shell" 1 "") (chreq t "exec" 1 (sstr cmd)))
             (? !(reply t) -1
                (: _ (? pty? (raw 1) 0)
                   sig (? pty? (sigfd [28]) ())
                   _ (? (hot? sig) (twirl (_ \ winch t sig) 0) 0)
                   _ (twirl (_ \ pump t) 0)
                   st (drain t)
                   _ (? pty? (raw 0) 0)
                   st)))))
)
) ; module 'ssh
