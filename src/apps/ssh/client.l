; src/apps/ssh/client.l -- an ssh-2 client: transport (RFC 4253), publickey auth (4252), one
; session channel (4254). one of everything: curve25519-sha256 for the exchange, an
; ssh-ed25519 host key, chacha20-poly1305@openssh.com both ways, and an ed25519
; identity, bare or as ssh-keygen locks one -- what a modern OpenSSH offers first.
;
;   (ssh-dial host port)          connect, exchange keys, check the host -> session | a reason string
;   (ssh-auth t user seed pub)    publickey auth -> 1 | a reason string
;   (ssh-run t cmd pty?)          a session channel: exec cmd, or a shell for () -> exit status;
;                                 a pty follows the terminal's size on each SIGWINCH
;   (ssh-key path ask)            an openssh-key-v1 file -> [seed pub] | a reason string;
;                                 (ask path) -> the passphrase | (), asked only of a locked key
;   (ssh-keytext path txt ask)    the same over the file's text, path only naming it
;
; the session is a tablet like tls's: the socket, a pending run, a sequence number and
; key pair each way, the session id. the chacha key is 64 bytes, the payload key first
; and the length key second; openssh's nonce is the sequence number, which is the IETF
; nif's nonce with the counter's high word zero ahead of it.
(module 'ssh
(borrow 'tls)
(borrow 'dns)
(borrow 'posix)
(borrow 'bytes)

(:
   m32 ((1 << 32) - 1)
   ; --- the wire's encodings (RFC 4251 §5) ---
   (be32 s i) (rdbe s i 4)
   (sstr s) (u32 #s + s)
   (names l) (sstr (join "," l))
   (split s ch)
    (: (go i j a) (? (#s <= i) (rev (snip s j i . a))
                     (s i = ch) (go (i + 1) (i + 1) (snip s j i . a))
                     (go (i + 1) j a))
       (go 0 0 ()))
   ; a non-negative big-endian run as an mpint: leading zeros off, a zero byte on a high bit
   (mpint s)
    (: (lead i) (i < #s && s i = 0 ? (lead (i + 1)) i)
       r (snip s (lead 0) #s)
       (sstr (0 < #r && 127 < r 0 ? (u8 0 + r) r)))

   ; a cursor over a payload: a tablet of the run and an index, read forward
   (cur s) (tablet 2 @ c (pin c 's s, pin c 'i 0, c))
   (g-skip c n) (: i (c 'i) (pin c 'i (i + n), i))
   (g-u8 c) (c 's (g-skip c 1))
   (g-u32 c) (be32 (c 's) (g-skip c 4))
   (g-str c) (: n (g-u32 c) i (g-skip c n) (snip (c 's) i (i + n)))
   (g-names c) (g-str c @ s (#s = 0 ? () (split s 44)))

   ; a peer's text for our terminal: c0 but tab and newline, del, c1 (u+0080..u+009f) and
   ; any byte outside well-formed utf-8 are dropped -- the reach of openssh's strnvis
   (ssh-clean s)
    (: n #s
       (cont? i) (i < n && 127 < s i && s i < 192)
       (seq i) (s i @ b                                     ; a well-formed sequence's length at i, else 0
                  (b < 194 || 244 < b ? 0
                     (: k (? (b < 224) 1 (b < 240) 2 3)
                        lo (? (b = 224) 160 (b = 240) 144 128)
                        hi (? (b = 237) 159 (b = 244) 143 191)
                        s1 (i + 1 < n ? (s (i + 1)) 0)
                        (? !(lo <= s1 && s1 <= hi) 0
                           (k = 1 || cont? (i + 2) && (k = 2 || cont? (i + 3))) (k + 1)
                           0))))
       (go i a)
        (n <= i ? (string (rev a))
           (s i @ b
              (? (b < 32) (go (i + 1) (b = 9 || b = 10 ? (b . a) a))
                 (b < 127) (go (i + 1) (b . a))
                 ((b = 127 ? 0 (seq i)) @ m
                    (? (m = 0) (go (i + 1) a)
                       (b = 194 && s (i + 1) < 160) (go (i + 2) a)
                       (go (i + m) (foldl (a2 \ j \ (s (i + j) . a2)) a ^m)))))))
       (go 0 ()))

   ; --- packets: (ssh-send t payload) and (ssh-recv t) -> payload | () ---
   (nonce seq) (zeros 4 + u64be seq)
   (polykey k n) (chacha20 k n 0 (zeros 32))
   (send1 t p)
    (: k (t 'ck) seq (t 'sseq)
       enc (two? k)
       pl (enc ? (1 + #p) (5 + #p))
       pd (8 - pl % 8)
       pad (pd < 4 ? (pd + 8) pd)
       body (u8 pad + p + zeros pad)
       len (u32 #body)
       (seq = m32 ? (: s (t 's) (hot? s ? (close s) 0, ()))        ; the next would wrap and reuse a nonce: hang up
          (pin t 'sseq (seq + 1),
           enc ?
             (: n (nonce seq) el (chacha20 <>k n 0 len) eb (chacha20 <k n 1 body)
                (wr t (el + eb + poly1305 (polykey <k n) (el + eb))))
             (wr t (len + body)))))
   ; tasks share the socket, and a write can park: one packet on the wire at a time
   (ssh-send t p) (t 'busy ? (rest 1, ssh-send t p)
                     (: _ (pin t 'busy 1) r (send1 t p) (pin t 'busy 0, r)))
   (unpad b) (snip b 1 (#b - b 0))
   (ssh-recv t)
    (: k (t 'sk) seq (t 'rseq)
       _ (pin t 'rseq (seq + 1 & m32))
       h (seq = m32 ? () (rd t 4))                   ; a wrapped sequence number ends it, as sending does
       (? (atom? h) ()
          (atom? k) (be32 <>h 0 @ len                            ; pre-newkeys: rfc 4253 6.1 caps a packet at 35000
                       (35000 < len ? () (rd t len @ r (two? r ? (unpad <>r) ()))))
          (: n (nonce seq) el <>h
             len (be32 (chacha20 <>k n 0 el) 0)
             r (len < 262144 ? (rd t (len + 16)) ())
             (atom? r ? ()
                (snip <>r 0 len @ eb
                   (snip <>r len (len + 16) != poly1305 (polykey <k n) (el + eb) ? ()
                      (unpad (chacha20 <k n 1 eb))))))))

   ; the next payload that is not transport noise: ignore, debug and ext-info pass, a
   ; banner goes to stderr, a global request is refused, a disconnect is the end. under
   ; strict kex ('strict, agreement to newkeys) any of that noise ends the connection
   (ssh-next t)
    (ssh-recv t @ p
       (? !(string? p) ()
          (: ty (p 0) c (cur p) (g-skip c 1,
                                 (? (t 'strict = 1 && elem ty [2 4 7 53 80]) ()
                                    (ty = 2 || ty = 4 || ty = 7) (ssh-next t)
                                    (ty = 53) (say err (ssh-clean (g-str c)), ssh-next t)
                                    (ty = 80) (g-str c, g-u8 c ? (ssh-send t (u8 82)) 0, ssh-next t)
                                    (ty = 1) (g-u32 c @ code (say err ("ssh: disconnected: " + ssh-clean (g-str c) + "\n"), ()))
                                    p)))))
   ; a payload of type ty, or ()
   (expect t ty) (ssh-next t @ p (string? p && p 0 = ty ? p ()))

   ; --- the version lines ---
   ; a crlf-terminated line, bytes gathered in a list and capped at 255 (rfc 4253 4.2);
   ; overlong or eof ends the session
   (rdline t)
    (: (go acc n) (255 < n ? ()
                     (rd t 1 @ r
                        (? (atom? r) () (<>r = "\n") (string (rev acc)) (go (<>r 0 . acc) (n + 1)))))
       l (go () 0)
       (string? l ? (0 < #l && l (#l - 1) = 13 ? (snip l 0 (#l - 1)) l) ()))
   ; the peer's version line, skipping at most 1024 lines of banner ahead of it
   (server-version t)
    (: (go j) (1024 < j ? ()
                 (rdline t @ l
                    (? !(string? l) () (4 <= #l && snip l 0 4 = "SSH-") l (go (j + 1)))))
       (go 0))

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
       (? !(elem "curve25519-sha256" kx || elem "curve25519-sha256@libssh.org" kx)
          ("no common key exchange; the server offers " + join "," kx)
          (nelem "ssh-ed25519" hk) ("no ssh-ed25519 host key; the server offers " + join "," hk)
          !(elem cipher cs && elem cipher sc) ("no common cipher; the server offers " + join "," cs)
          (elem "kex-strict-s-v00@openssh.com" kx)))

   (ssh-dial host port)
    (dial host port @ s
       (? !(hot? s) ("cannot connect to " + host + " port " + show port)
          (: t (tablet 16)
             _ (pin t 's s) _ (pin t 'pend "") _ (pin t 'sseq 0) _ (pin t 'rseq 0) _ (pin t 'busy 0)
             _ (wr t (vc + "\r\n"))
             vs (server-version t)
             ic (kexinit 0)
             _ (ssh-send t ic)
             is (expect t 20)
             ok (string? vs ? (string? is ? (agree is) "no kexinit") "no version line")
             (string? ok ? (close s, ok)
                (: _ (pin t 'strict ok)
                   priv (rnd 32) qc (x25519-pub priv)
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
                         (? (shared = zeros 32) (close s, "degenerate shared secret")
                            !(kt = "ssh-ed25519" && st = "ssh-ed25519" && ed-verify hpk h sb)
                             (close s, "the host key's signature does not verify")
                            (: _ (pin t 'sid h) _ (pin t 'hostkey ks)
                               (kd x) (sha (kk + h + x + h) @ k1 (k1 + sha (kk + h + k1)))
                               (pair k) [(snip k 0 32) (snip k 32 64)]
                               _ (ssh-send t (u8 21))
                               _ (pin t 'ck (pair (kd "C")))
                               _ (ok ? (pin t 'sseq 0) 0)
                               nk (expect t 21)
                               (pin t 'sk (pair (kd "D")),
                                ok ? (pin t 'rseq 0) 0,
                                pin t 'strict 0,
                                (? !(string? nk) (close s, "no newkeys")
                                   (ssh-send t (u8 5 + sstr "ssh-userauth"),
                                    string? (expect t 6) ? t (close s, "no userauth service")))))))))))))

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
          (r 0 = 51) (cur r @ c (g-skip c 1, "permission denied (" + join "," (g-names c) + ")"))
          "unexpected auth reply"))

   ; --- the identity: openssh-key-v1 (PROTOCOL.key), an ed25519 key, bare or under aes-ctr ---
   ; the cipher's key length, 0 for none, -1 for what is not read
   (key-len ciph) (? (ciph = "none") 0 (ciph = "aes128-ctr") 16 (ciph = "aes192-ctr") 24
                     (ciph = "aes256-ctr") 32 -1)
   ; the private section in the clear: bcrypt_pbkdf gives the aes key and then the iv
   (unlock kl ko pass enc)
    (: salt (g-str ko) rounds (g-u32 ko)
       kiv (bcrypt-pbkdf pass salt rounds (kl + 16))
       (aes-ctr (aes-keys (snip kiv 0 kl)) (snip kiv kl (kl + 16)) enc))
   (ssh-key path ask)
    (open path "r" @ q
       (? !(hot? q) ("cannot read " + path)
          (slurp q @ txt (close q, ssh-keytext path txt ask))))
   (ssh-keytext path txt ask)
    (: body (join "" (filter (l \ !(0 < #l && l 0 = 45)) (split txt 10)))
       b (b64d body)
       magic "openssh-key-v1"
       (snip b 0 14 != magic ? (path + ": not an openssh private key")
          (: c (cur b) _ (g-skip c 15)
             ciph (g-str c) kdf (g-str c) ko (cur (g-str c)) _ (g-u32 c) _ (g-str c)
             enc (g-str c)
             kl (key-len ciph)
             (? (kl < 0) (path + ": keys under " + ciph + " are not supported")
                (0 < kl && kdf != "bcrypt") (path + ": the kdf " + kdf + " is not supported")
                ((0 < kl ? (ask path) "") @ pass
                   (? !(string? pass) (path + ": no passphrase")
                      (: pc (cur (0 < kl ? (unlock kl ko pass enc) enc))
                         c1 (g-u32 pc) c2 (g-u32 pc) ty (g-str pc) pk (g-str pc) sk (g-str pc)
                         (? (c1 != c2) (path + (0 < kl ? ": incorrect passphrase" ": damaged key"))
                            (ty != "ssh-ed25519") (path + ": " + ty + " keys are not supported yet")
                            [(snip sk 0 32) pk]))))))))

   ; --- the session channel (RFC 4254) ---
   lwin (1 << 21)
   (chreq t name reply body)
    (ssh-send t (u8 98 + u32 (t 'rch) + sstr name + u8 reply + body))
   ; wait out a channel request's reply, taking window adjusts on the way -> 1 | 0
   (reply t)
    (ssh-next t @ p
       (? !(string? p) 0
          (p 0 = 99) 1
          (p 0 = 100) 0
          (p 0 = 93) (cur p @ c (g-skip c 5, pin t 'rwin (t 'rwin + g-u32 c), reply t))
          (reply t)))
   ; stdin to the channel, a packet per read, inside the peer's window and packet size
   (pump t)
    (see in @ ch
       (ch = -1 ? (ssh-send t (u8 96 + u32 (t 'rch)))
          (: _ (unsee in ch)
             s (chug in)
             (put1 i) (#s <= i ? 0
                         (min (t 'rmax) (t 'rwin) @ room
                            (room < 1 ? (rest 5, put1 i)
                               (min room (#s - i) @ n
                                  (pin t 'rwin (t 'rwin - n),
                                   ssh-send t (u8 94 + u32 (t 'rch) + sstr (snip s i (i + n))),
                                   put1 (i + n))))))
             (put1 0, pump t))))
   ; the channel's traffic until it closes -> the exit status
   (drain t)
    (ssh-next t @ p
       (? !(string? p) (t 'status)
          (: ty (p 0) c (cur p) (g-skip c 5,
                                 (? (ty = 94) (: d (g-str c) _ (say out d) _ (flush out)
                                                 used (t 'used + #d)
                                                 (lwin // 2 < used ?
                                                  (ssh-send t (u8 93 + u32 (t 'rch) + u32 used), pin t 'used 0)
                                                  (pin t 'used used),
                                                  drain t))
                                    (ty = 95) (: _ (g-u32 c) d (g-str c)
                                                 (say err d, flush err, pin t 'used (t 'used + #d), drain t))
                                    (ty = 93) (pin t 'rwin (t 'rwin + g-u32 c), drain t)
                                    (ty = 98) (: nm (g-str c) wr? (g-u8 c)
                                                 ((? (nm = "exit-status") (pin t 'status (g-u32 c))
                                                     (nm = "exit-signal") (pin t 'status 255)
                                                     0),
                                                  wr? ? (ssh-send t (u8 100 + u32 (t 'rch))) 0,
                                                  drain t))
                                    (ty = 97) (ssh-send t (u8 97 + u32 (t 'rch)), t 'status)
                                    (drain t))))))

   ; the terminal's size as the wire's cols, rows and two zero pixel counts
   (geom _) (: a (tty 1) sz (two? a ? a (tty 0))
               ((two? sz ? (u32 >sz + u32 <sz) (u32 80 + u32 24)) + u32 0 + u32 0))
   ; SIGWINCH (28 on linux and the BSDs) queued to a signalfd; each wake sends the size now
   (winch t sig) (await sig, sigtake sig, chreq t "window-change" 0 (geom 0), winch t sig)

   (ssh-run t cmd pty?)
    (: _ (ssh-send t (u8 90 + sstr "session" + u32 0 + u32 lwin + u32 32768))
       r (ssh-next t)
       (? !(string? r && r 0 = 91) -1
          (: c (cur r) _ (g-skip c 5)
             _ (pin t 'rch (g-u32 c)) _ (pin t 'rwin (g-u32 c)) _ (pin t 'rmax (g-u32 c))
             _ (pin t 'used 0) _ (pin t 'status -1)
             term (getenv "TERM" @ e (string? e ? e "xterm"))
             _ (pty? ? (chreq t "pty-req" 1 (sstr term + geom 0 + sstr (u8 0))) 0)
             okp (pty? ? (reply t) 1)
             (!cmd ? (chreq t "shell" 1 "") (chreq t "exec" 1 (sstr cmd)),
              (? !(reply t) -1
                 (: _ (pty? ? (raw 1) 0)
                    sig (pty? ? (sigfd [28]) ())
                    _ (hot? sig ? (twirl (_ \ winch t sig) 0) 0)
                    _ (twirl (_ \ pump t) 0)
                    st (drain t)
                    (pty? ? (raw 0) 0,
                     st)))))))

   ; --- a channel as a byte stream, for a protocol riding exec (scp) ---
   ;   (ssh-open t cmd)   a session channel running cmd, no pty -> 1 | a reason string
   ;   (ch-read t n)      exactly n bytes, or () when the channel ended first
   ;   (ch-line t)        through the next newline, or ()
   ;   (ch-write t s)     inside the peer's window, waiting on its adjusts
   ;   (ch-end t)         eof, then the channel's close -> the exit status
   ; one task drives it: a read pulls packets until it has enough, stderr goes to ours
   (ssh-open t cmd)
    (: _ (ssh-send t (u8 90 + sstr "session" + u32 0 + u32 lwin + u32 32768))
       r (ssh-next t)
       (? !(string? r && r 0 = 91) "the server refused a session channel"
          (: c (cur r) _ (g-skip c 5)
             rch (g-u32 c) rwin (g-u32 c) rmax (g-u32 c)       ; in wire order: pins evaluates last first
             (pins t 'rch rch 'rwin rwin 'rmax rmax 'used 0 'status -1 'rbuf "" 'eof 0 'closed 0,
              chreq t "exec" 1 (sstr cmd),
              reply t ? 1 ("the server would not run " + cmd)))))
   (ch-took t n) (: used (t 'used + n)
                    (lwin // 2 < used ? (ssh-send t (u8 93 + u32 (t 'rch) + u32 used), pin t 'used 0)
                       (pin t 'used used)))
   ; one packet into the channel's state -> 0 once it can bring no more
   (ch-pull t)
    ((t 'closed = 1 ? () (ssh-next t)) @ p
       (? !(string? p) (pins t 'eof 1 'closed 1, 0)
          (: ty (p 0) c (cur p) (g-skip c 5,
                                 (? (ty = 94) (g-str c @ d (pin t 'rbuf (t 'rbuf + d), ch-took t #d, 1))
                                    (ty = 95) (: _ (g-u32 c) d (g-str c) (say err d, flush err, ch-took t #d, 1))
                                    (ty = 93) (pin t 'rwin (t 'rwin + g-u32 c), 1)
                                    (ty = 98) (: nm (g-str c) wr? (g-u8 c)
                                                 ((? (nm = "exit-status") (pin t 'status (g-u32 c)) (nm = "exit-signal") (pin t 'status 255) 0),
                                                  wr? ? (ssh-send t (u8 100 + u32 (t 'rch))) 0,
                                                  1))
                                    (ty = 96) (pin t 'eof 1, 1)
                                    (ty = 97) (ssh-send t (u8 97 + u32 (t 'rch)), pins t 'eof 1 'closed 1, 0)
                                    1)))))
   (ch-read t n)
    (t 'rbuf @ b
       (? (n <= #b) (pin t 'rbuf (snip b n #b), snip b 0 n)
          (t 'eof = 1) ()
          (ch-pull t, ch-read t n)))
   (ch-line t)
    (: b (t 'rbuf)
       k ((: (g i) (? (#b <= i) -1 (b i = 10) i (g (i + 1)))) 0)
       (? (0 <= k) (ch-read t (k + 1))
          (t 'eof = 1) ()
          (ch-pull t, ch-line t)))
   (ch-write t s)
    (: (go i) (? (#s <= i) 1
                 (t 'closed = 1) 0
                 (min (t 'rmax) (t 'rwin) @ room
                    (room < 1 ? (ch-pull t, go i)
                       (min room (#s - i) @ n
                          (pin t 'rwin (t 'rwin - n),
                           ssh-send t (u8 94 + u32 (t 'rch) + sstr (snip s i (i + n))),
                           go (i + n))))))
       (go 0))
   (ch-end t)
    (t 'closed = 1 ? 0 (ssh-send t (u8 96 + u32 (t 'rch))),
     (: (go _) (t 'closed = 1 ? (t 'status) (ch-pull t, go 0)) (go 0)))
)
) ; module 'ssh
