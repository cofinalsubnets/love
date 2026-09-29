; apps/ssh/server.l -- an ssh-2 server over client.l's transport: the same one of everything
; (curve25519-sha256, an ssh-ed25519 host key, chacha20-poly1305@openssh.com), publickey
; auth against authorized_keys (4252 §7), and one session channel per connection (4254): a
; shell or a command, over a pty when the client asks for one, else over three pipes.
;
;   (sshd-serve port hk keys me quiet)  listen, then serve each connection as a task ->
;                                       the listen's nom when the port cannot be taken
;   (ssh-keywrite path seed pub comment) an unencrypted openssh-key-v1 key, 0600, and its
;                                       .pub beside it -> 1 | a reason string
;   (ssh-authorized path)               the ed25519 keys authorized_keys grants
;   (ssh-me _)                          this process's user off /etc/passwd: [name home shell]
;
; hk is the host key as ssh-key answers it, [seed pub]; keys the authorized_keys path, read
; at each login so an edit counts at once; me the user served. there is no setuid here: the
; server serves the user it runs as, and a login naming anyone else is refused. the session
; runs that user's login shell. no rekeying, no port forwarding, no subsystems (sftp): a
; client's rekey is answered with a disconnect, and the rest are refused by name.
(module 'ssh
(borrow 'tls)
(borrow 'posix)

(:
   vsd "SSH-2.0-love_sshd"
   sd-win (1 << 21)
   sd-grace 120000                        ; login grace: a connection unauthed by 120 s is shut

   ; --- keys ---
   (ssh-publine pub comment)
    ("ssh-ed25519 " + b64e (sstr "ssh-ed25519" + sstr pub) 1 + (0 < #comment ? (" " + comment) "") + "\n")
   ; openssh-key-v1 under no cipher: the private section padded 1, 2, 3.. to the block of 8
   (sd-keytext seed pub comment)
    (: ck (rnd 4)
       body (ck + ck + sstr "ssh-ed25519" + sstr pub + sstr (seed + pub) + sstr comment)
       padded (body + bytes ((8 - #body % 8) % 8) (i \ i + 1))
       raw ("openssh-key-v1" + u8 0 + sstr "none" + sstr "none" + sstr "" + u32 1
            + sstr (sstr "ssh-ed25519" + sstr pub) + sstr padded)
       b (b64e raw 1)
       (lines i) (#b <= i ? "" (snip b i (min #b (i + 70)) + "\n" + lines (i + 70)))
       ("-----BEGIN OPENSSH PRIVATE KEY-----\n" + lines 0 + "-----END OPENSSH PRIVATE KEY-----\n"))
   (ssh-keywrite path seed pub comment)
    (: fd (openfd path 3)
       (? !(charm? fd) ("cannot create " + path + " (" + show fd + ")")
          (: p (fdopen fd) _ (say p (sd-keytext seed pub comment)) _ (close p)
             q (open (path + ".pub") "w")
             (hot? q ? (say q (ssh-publine pub comment), close q) 0,
              1))))
   ; lines whose first word is the key type; a line with options ahead of its type
   ; (command=, from=, ..) grants nothing, since none of them is honoured here
   (ssh-authorized path)
    (: q (open path "r")
       txt (hot? q ? (: s (slurp q) (close q, s)) "")
       (key l) (: f (filter (w \ 0 < #w) (split l 32))
                  b (2 <= #f ? (b64d (f 1)) "")
                  (<f = "ssh-ed25519" && #b = 51 && snip b 0 19 = sstr "ssh-ed25519" + u32 32
                   ? [(snip b 19 51)] ()))
       (catmap key (split txt 10)))
   (ssh-me _)
    (: uid (getuid 0)
       q (open "/etc/passwd" "r")
       txt (hot? q ? (: s (slurp q) (close q, s)) "")
       (find ls) (? (atom? ls) ()
                    (: f (split <ls 58)
                       (7 <= #f && unum (f 2) = uid ? [(f 0) (f 5) (f 6)] (find >ls))))
       (find (split txt 10)))
   (sd-fpr pub) ("SHA256:" + b64e (sha (sstr "ssh-ed25519" + sstr pub)) 0)
   (sd-log quiet m) (quiet ? 0 (say err ("sshd: " + m + "\n"), flush err))

   ; --- the exchange, the server's half of client.l's ssh-dial ---
   sd-kexs ["curve25519-sha256" "curve25519-sha256@libssh.org" "kex-strict-s-v00@openssh.com"]
   (sd-kexinit _) (u8 20 + rnd 16 + names sd-kexs + names ["ssh-ed25519"] + names [cipher] + names [cipher]
                  + names ["hmac-sha2-256"] + names ["hmac-sha2-256"] + names ["none"] + names ["none"]
                  + names [] + names [] + u8 0 + u32 0)
   ; the client's lists against ours -> a reason string, or the strict flag
   (sd-agree ic)
    (: c (cur ic) _ (g-skip c 17)
       kx (g-names c) hk (g-names c) cs (g-names c) sc (g-names c)
       (? !(elem "curve25519-sha256" kx || elem "curve25519-sha256@libssh.org" kx)
          ("no common key exchange; the client offers " + join "," kx)
          !(elem "ssh-ed25519" hk) ("no common host key type; the client takes " + join "," hk)
          !(elem cipher cs && elem cipher sc) ("no common cipher; the client offers " + join "," cs)
          (elem "kex-strict-c-v00@openssh.com" kx)))
   ; versions, kexinits, the ecdh reply signed by the host key, newkeys each way, and the
   ; userauth service -> 1 | a reason string. our send key is kd "D", the client's "C"
   (sd-hello t hk)
    (: _ (wr t (vsd + "\r\n"))
       vc (server-version t)
       is (sd-kexinit 0)
       _ (ssh-send t is)
       ic (string? vc ? (expect t 20) ())
       ok (? !(string? vc) "no version line" !(string? ic) "no kexinit" (sd-agree ic))
       (? (string? ok) ok
          (: _ (pin t 'strict ok)                          ; strict kex: noise before newkeys ends it (ssh-next)
             e (expect t 30)
             (? !(string? e) "no key exchange"
                (: c (cur e) _ (g-skip c 1) qc (g-str c)
                   priv (rnd 32) qs (x25519-pub priv)
                   shared (#qc = 32 ? (x25519 priv qc) (zeros 32))
                   (? (shared = zeros 32) "degenerate key exchange"
                      (: hs (hk 0) hp (hk 1)
                         ks (sstr "ssh-ed25519" + sstr hp)
                         kk (mpint shared)
                         h (sha (sstr vc + sstr vsd + sstr ic + sstr is + sstr ks + sstr qc + sstr qs + kk))
                         _ (ssh-send t (u8 31 + sstr ks + sstr qs + sstr (sstr "ssh-ed25519" + sstr (ed-sign hs hp h))))
                         _ (pin t 'sid h)
                         (kd x) (: k1 (sha (kk + h + x + h)) (k1 + sha (kk + h + k1)))
                         (pair k) [(snip k 0 32) (snip k 32 64)]
                         _ (ssh-send t (u8 21))
                         _ (pin t 'ck (pair (kd "D")))
                         _ (ok ? (pin t 'sseq 0) 0)
                         nk (expect t 21)
                         _ (pin t 'sk (pair (kd "C")))
                         _ (ok ? (pin t 'rseq 0) 0)
                         _ (pin t 'strict 0)
                         sr (string? nk ? (expect t 5) ())
                         sv (string? sr ? (: c2 (cur sr) (g-skip c2 1, g-str c2)) "")
                         (? !(string? nk) "no newkeys"
                            (sv != "ssh-userauth") "no userauth service request"
                            (ssh-send t (u8 6 + sstr "ssh-userauth"), 1)))))))))

   ; --- publickey auth -> [the key] | a reason string ---
   ; none and every other method are answered with the one taken; a key with no signature is
   ; a query (PK_OK when it would do); ten refusals and the door closes
   (sd-no t) (ssh-send t (u8 51 + names ["publickey"] + u8 0))
   (sd-auth t user keys n)
    (: p (ssh-next t)
       (? !(string? p) "closed during auth"
          (n < 1) "too many authentication failures"
          (p 0 != 50) "unexpected message during auth"
          (: c (cur p) _ (g-skip c 1)
             u (g-str c) sv (g-str c) m (g-str c)
             (? !(m = "publickey" && u = user && sv = "ssh-connection")
                (sd-no t, sd-auth t user keys (n - 1))
                (: sig? (g-u8 c) al (g-str c) blob (g-str c) at (c 'i)
                   pk (al = "ssh-ed25519" && #blob = 51 && snip blob 0 19 = sstr "ssh-ed25519" + u32 32
                       ? (snip blob 19 51) "")
                   (? !(0 < #pk && elem pk (ssh-authorized keys))
                      (sd-no t, sd-auth t user keys (n - 1))
                      !sig? (ssh-send t (u8 60 + sstr al + sstr blob), sd-auth t user keys n)
                      (: sc (cur (g-str c)) st (g-str sc) s64 (g-str sc)
                         (? (st = "ssh-ed25519" && #s64 = 64 && ed-verify pk (sstr (t 'sid) + snip p 0 at) s64)
                            (ssh-send t (u8 52), [pk])
                            (sd-no t, sd-auth t user keys (n - 1))))))))))

   ; --- the session channel ---
   ; s to the channel inside the peer's window and packet size, as data or (ext) as stderr
   (sd-data t ch s ext)
    (: (go i) (? (#s <= i || ch 'dead) 0
                 (: room (min (ch 'rmax) (ch 'rwin))
                    (? (room < 1) (rest 5, go i)
                       (: n (min room (#s - i)) b (snip s i (i + n))
                          _ (pin ch 'rwin (ch 'rwin - n))
                          _ (ssh-send t (? ext (u8 95 + u32 (ch 'rch) + u32 1 + sstr b)
                                           (u8 94 + u32 (ch 'rch) + sstr b)))
                          (go (i + n))))))
       (go 0))
   ; a task of the session's own, trapped: an uncaught raise in a task ends the process, and
   ; this one serves every other connection too
   (sd-spawn f) (twirl (_ \ trap f 0 (a \ b \ sd-log 0 ("session task failed: " + show a))) 0)
   ; a port's output to the channel until it ends: await parks on the fd, so a pty master
   ; read never holds the process
   (sd-pump t ch p ext)
    (: _ (await p) c (see p)
       (? (c = -1 || ch 'dead) 0
          (: _ (unsee p c) s (chug p) _ (sd-data t ch s ext) (sd-pump t ch p ext))))
   ; the output drained, then the status, eof and close
   (sd-finish t ch ports pid)
    (: e (two? >ports ? (sd-spawn (_ \ sd-pump t ch (ports 1) 1)) ())
       _ (sd-pump t ch <ports 0)
       _ (!e ? 0 (catch e))
       st (wait pid)
       _ (pin ch 'in ())
       _ (? (ch 'dead) 0
            (ssh-send t (u8 98 + u32 (ch 'rch) + sstr "exit-status" + u8 0 + u32 (st & 255)),
             ssh-send t (u8 96 + u32 (ch 'rch)),
             pin ch 'closed 1,
             ssh-send t (u8 97 + u32 (ch 'rch))))
       (map close ports))
   ; the login shell, or it running cmd; lush spells its login flag in full
   (sd-argv me cmd)
    (: sh (0 < #(me 2) ? (me 2) "/bin/sh")
       base (last (split sh 47))
       (string? cmd ? [sh "-c" cmd] [sh (base = "lush" ? "--login" "-l")]))
   ; the program, on a pty when one was asked for -> 1 | a reason string
   (sd-start t ch me cmd)
    (: argv (sd-argv me cmd)
       pt (ch 'pty)
       (? (two? pt)
          (: _ (setenv "TERM" (pt 0))
             r (tether argv)
             (? (atom? r) ("cannot start " + <argv + " (" + show r + ")")
                (: m >r
                   (settty m (pt 1) (pt 2),
                    pins ch 'pid <r 'in m 'tty 1,
                    sd-spawn (_ \ sd-finish t ch [m] <r),
                    1))))
          (: pi (pipe 0) po (pipe 0) pe (pipe 0)
             pid (spawnio argv <pi >po >pe [>pi <po <pe] -1 0)
             _ (close <pi) _ (close >po) _ (close >pe)
             (? !(charm? pid) (map close [>pi <po <pe], "cannot start " + <argv + " (" + show pid + ")")
                (pins ch 'pid pid 'in (fdopen >pi) 'tty 0,
                 sd-spawn (_ \ sd-finish t ch [(fdopen <po) (fdopen <pe)] pid),
                 1)))))
   (sd-open t c)
    (: kind (g-str c) rch (g-u32 c) rwin (g-u32 c) rmax (g-u32 c)
       (? (kind = "session" && !(t 'ch))
          (: ch (tablet 16)
             (pins ch 'rch rch 'rwin rwin 'rmax rmax 'used 0 'dead 0 'closed 0,
              pin t 'ch ch,
              ssh-send t (u8 91 + u32 rch + u32 0 + u32 sd-win + u32 32768)))
          (ssh-send t (u8 92 + u32 rch + u32 1 + sstr ("a " + kind + " channel is not served") + sstr ""))))
   ; a request on the channel; shell and exec answer before the program starts, so its first
   ; output never runs ahead of the reply
   (sd-req t ch c me quiet)
    (: _ (g-u32 c) nm (g-str c) wr? (g-u8 c)
       (ack ok) (wr? ? (ssh-send t (u8 (ok ? 99 100) + u32 (ch 'rch))) 0)
       (? !ch 0
          (nm = "pty-req") (: term (g-str c) cols (g-u32 c) rows (g-u32 c)
                              (pin ch 'pty [term rows cols], ack 1))
          (nm = "window-change") (: cols (g-u32 c) rows (g-u32 c)
                                    (ch 'tty = 1 ? (settty (ch 'in) rows cols) 0))
          (nm = "shell" || nm = "exec")
           (? (ch 'pid) (ack 0)
              (: cmd (nm = "exec" ? (g-str c) ())
                 _ (ack 1)
                 r (sd-start t ch me cmd)
                 (? (r = 1) 0
                    (sd-log quiet r,
                     sd-data t ch ("sshd: " + r + "\r\n") 1,
                     ssh-send t (u8 98 + u32 (ch 'rch) + sstr "exit-status" + u8 0 + u32 127),
                     ssh-send t (u8 96 + u32 (ch 'rch)),
                     pin ch 'closed 1,
                     ssh-send t (u8 97 + u32 (ch 'rch))))))
          (ack 0)))
   ; the client's bytes to the program's stdin; our window reopened past its half
   (sd-in t ch c)
    (: _ (g-u32 c) d (g-str c)
       (? !ch 0
          (: p (ch 'in)
             _ (!p ? 0 (say p d, flush p))
             used (ch 'used + #d)
             (? (sd-win // 2 < used) (ssh-send t (u8 93 + u32 (ch 'rch) + u32 used), pin ch 'used 0)
                (pin ch 'used used)))))
   ; eof closes a pipe's stdin; a pty has no half-close, so there it waits for the close
   (sd-eof ch) (!ch || !(ch 'in) || ch 'tty = 1 ? 0 (close (ch 'in), pin ch 'in ()))
   ; the connection's messages until the channel closes or the client goes
   (sd-conn t me quiet)
    (: p (ssh-next t)
       (? !(string? p) 0
          (: ty (p 0) c (cur p) _ (g-skip c 1) ch (t 'ch)
             _ (? (ty = 90) (sd-open t c)
                  (ty = 98) (sd-req t ch c me quiet)
                  (ty = 94) (sd-in t ch c)
                  (ty = 93) (!ch ? 0 (g-u32 c, pin ch 'rwin (ch 'rwin + g-u32 c)))
                  (ty = 96) (sd-eof ch)
                  (ty = 20) (ssh-send t (u8 1 + u32 11 + sstr "rekeying is not supported" + sstr ""))
                  0)
             (ty = 97 || ty = 20 ? 0 (sd-conn t me quiet)))))
   ; one connection, start to end; a program still running when the client goes is hung up on
   (sd-session c hk keys me quiet)
    (: t (tablet 16)
       _ (pins t 's c 'pend "" 'sseq 0 'rseq 0 'busy 0 'authed 0)
       _ (sd-spawn (_ \ (rest sd-grace, t 'authed ? 0 (close c))))   ; drop a still-unauthed connection (wakes its parked read; sd-loop's later close is a no-op)
       h (sd-hello t hk)
       a (h = 1 ? (sd-auth t (me 0) keys 10) h)
       _ (string? a ? 0 (pin t 'authed 1))
       (? (string? a) (sd-log quiet ("connection closed: " + a))
          (: _ (sd-log quiet ("accepted publickey for " + me 0 + " " + sd-fpr <a))
             _ (sd-conn t me quiet)
             ch (t 'ch)
             _ (? !ch 0
                  (pin ch 'dead 1,
                   ch 'closed = 1 ? 0 (ssh-send t (u8 97 + u32 (ch 'rch))),
                   !(ch 'pid) ? 0 (still (ch 'pid) 1)))
             (sd-log quiet ("session for " + me 0 + " ended")))))

   ; --- the loop, kiosko's shape: park on the listener, a task per client, the ended collected ---
   (sd-drain _) (two? (scoop 0) ? (sd-drain 0) 0)
   (sd-loop l hk keys me quiet)
    (: _ (await l)
       c (accept l)
       _ (sd-drain 0)
       _ (? (hot? c)
            (twirl (_ \ (: r (trap (c \ sd-session c hk keys me quiet) c
                                  (a \ b \ sd-log quiet ("session failed: " + show a)))
                           (seal c 1, close c))) ()) 0)
       (sd-loop l hk keys me quiet))
   (sshd-serve port hk keys me quiet)
    (: l (listen port)
       (? !(hot? l) l
          (sd-log quiet ("listening on port " + show port + ", host key " + sd-fpr (hk 1)),
           sd-loop l hk keys me quiet)))
)
) ; module 'ssh
