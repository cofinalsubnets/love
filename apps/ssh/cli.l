; apps/ssh/cli.l -- the ssh and sshd commands over the module: flags, keys, known_hosts and
; the one user served. apps/ssh/ssh.l is the door that loads it all from source; baked into
; the image, kore reaches both as (cite 'ssh-cli ..).
;
;   ssh [-p port] [-i identity] [-l user] [-t | -T] [-o option=value] [user@]host [command ..]
;   sshd [-Deq] [-p port] [-h host_key_file] [-o AuthorizedKeysFile=path]
;   scp [-pqrO] [-P port] [-i identity] [-o option=value] source .. target
(module (ssh-cli ssh-main sshd-main scp-main)
(borrow 'ssh)
(borrow 'tls)
(borrow 'posix)

; what ssh and scp share: the options and their defaults, and the login -- dial, the host key
; held to known_hosts, the identity, publickey auth. a failure is said as prog's and leaves
; with 255 through udie; the mains answer their status, and the seat (ssh.l) quits with it
(:
   (cl-die prog m) (udie 255 (prog + ": " + m))
   (cl-env k d) (: v (getenv k) (string? v ? v d))
   (cl-opts _)
    (: home (cl-env "HOME" "") o (tablet 8)
       (pins o 'port 22 'user (cl-env "USER" "") 'key (home + "/.ssh/id_ed25519")
               'kh (home + "/.ssh/known_hosts") 'strict 1 'pty -1,
        o))
   (cl-opt prog o kv)
    (: i (: (go i) (? (#kv <= i) i (kv i = 61) i (go (i + 1))) (go 0))
       k (snip kv 0 i) v (snip kv (i + 1) #kv)
       (? (k = "UserKnownHostsFile") (pin o 'kh v)
          (k = "StrictHostKeyChecking") (pin o 'strict (v != "no"))
          (cl-die prog ("unsupported option " + k))))
   ; known_hosts: 'ok on a match, 'bad on a different ed25519 key, else 'new
   (kh-name host port) (port = 22 ? host ("[" + host + "]:" + show port))
   (kh-check path name key)
    (: q (open path "r")
       txt (hot? q ? (: s (slurp q) (close q, s)) "")
       (look ls) (? (atom? ls) 'new
                    (: f (split <ls 32)
                       (? (3 <= #f && elem name (split <f 44) && f 1 = "ssh-ed25519")
                          (b64d (f 2) = key ? 'ok 'bad)
                          (look >ls))))
       (look (split txt 10)))
   (kh-add path name key)
    (: q (open path "a")
       (? (hot? q) (say q (name + " ssh-ed25519 " + b64e key 1 + "\n"), close q, 1) 0))
   ; a locked key's passphrase off the terminal, its echo off while it is typed
   (askpass path)
    (: q (open "/dev/tty" "r")
       (? !(hot? q) ()
          (: _ (say err ("Enter passphrase for key '" + path + "': ")) _ (flush err)
             _ (ptyecho q 0) ch (see q) _ (unsee q ch) l (chug q) _ (ptyecho q 1) _ (close q)
             _ (say err "\n") _ (flush err)
             n (string? l ? #l 0)
             (? !(string? l) () (0 < n && l (n - 1) = 10) (snip l 0 (n - 1)) l))))
   (cl-login prog o host)
    (: t (ssh-dial host (o 'port))
       _ (? (string? t) (cl-die prog t) 0)
       name (kh-name host (o 'port))
       path (o 'kh) key (t 'hostkey)
       _ (? !(o 'strict) 0
            (: v (kh-check path name key)
               (? (v = 'ok) 0
                  (v = 'bad) (cl-die prog ("the host key for " + name + " has CHANGED -- " + ssh-fingerprint t
                                           + " does not match " + path))
                  (kh-add path name key,
                   say err (prog + ": added " + name + " (" + ssh-fingerprint t + ") to " + path + "\n")))))
       k (ssh-key (o 'key) askpass)
       _ (? (string? k) (cl-die prog k) 0)
       a (ssh-auth t (o 'user) <k <>k)
       _ (? (string? a) (cl-die prog a) 0)
       t))

(: (ssh-main as)
 (:
    (atoi s) (: (go i a) (? (i < #s) (go (i + 1) (10 * a + s i - 48)) a) (go 0 0))
    (parse as o)
     (? (atom? as) o
        (: a <as r >as
           (? (a = "-p" && two? r) (pin o 'port (atoi <r), parse >r o)
              (a = "-i" && two? r) (pin o 'key <r, parse >r o)
              (a = "-l" && two? r) (pin o 'user <r, parse >r o)
              (a = "-o" && two? r) (cl-opt "ssh" o <r, parse >r o)
              (a = "-t") (pin o 'pty 1, parse r o)
              (a = "-T") (pin o 'pty 0, parse r o)
              (0 < #a && a 0 = 45) (cl-die "ssh" ("unknown flag " + a))
              (pin o 'dest a, ? (two? r) (pin o 'cmd (join " " r)) 0, o))))
    o (parse as (cl-opts 0))
    dest (o 'dest)
    _ (? (string? dest) 0 (cl-die "ssh" "usage: ssh [-p port] [-i identity] [-l user] [-t|-T] [user@]host [command]"))
    at (split dest 64)
    host (two? >at ? <>at <at)
    _ (? (two? >at) (pin o 'user <at) 0)
    t (cl-login "ssh" o host)
    cmd (o 'cmd)
    pty? (o 'pty < 0 ? (!cmd && two? (tty 0)) (o 'pty))
    st (ssh-run t cmd pty?)
    (st < 0 ? 255 st)))

; sshd serves the user it runs as. the host key is -h's, else the system's when this user
; can read it, else one of its own at ~/.ssh/sshd_ed25519_key, made on first use and said.
; it never detaches (-D is taken for openssh's sake) and logs to stderr (-e likewise).
(: (sshd-main as)
 (:
    usage "usage: sshd [-Deq] [-p port] [-h host_key_file] [-o AuthorizedKeysFile=path]"
    (die m) (udie 255 ("sshd: " + m))
    (readable? p) (: q (open p "r") (hot? q ? (close q, 1) 0))
    me (ssh-me 0)
    _ (? (two? me) 0 (die "no /etc/passwd line for this uid"))
    home (me 1)
    o (tablet 8)
    _ (pins o 'port 22 'quiet 0 'ak (home + "/.ssh/authorized_keys"))
    (opt kv)
     (: i (: (go i) (? (#kv <= i) i (kv i = 61) i (go (i + 1))) (go 0))
        k (snip kv 0 i) v (snip kv (i + 1) #kv)
        (? (k = "AuthorizedKeysFile") (pin o 'ak v) (die ("unsupported option " + k))))
    (parse as)
     (? (atom? as) 0
        (: a <as r >as
           (? (a = "-p" && two? r)
               (: n (unum <r)
                  (charm? n && 0 < n && n < 65536 ? (pin o 'port n) (die ("bad port " + <r)),
                   parse >r))
              (a = "-h" && two? r) (pin o 'hk <r, parse >r)
              (a = "-o" && two? r) (opt <r, parse >r)
              (a = "-D" || a = "-e") (parse r)
              (a = "-q") (pin o 'quiet 1, parse r)
              (die ("unknown argument " + a + "\n" + usage)))))
    _ (parse as)
    sys "/etc/ssh/ssh_host_ed25519_key"
    own (home + "/.ssh/sshd_ed25519_key")
    hkp (? (string? (o 'hk)) (o 'hk) (readable? sys) sys own)
    _ (? (hkp = own && !(readable? own))
         (: _ (mkdir (home + "/.ssh") 448)
            seed (rnd 32) pub (ed-pub seed)
            w (ssh-keywrite own seed pub ((me 0) + "@sshd"))
            (? (string? w) (die w)
               (say err ("sshd: made a host key, " + own + " (SHA256:" + b64e (sha (sstr "ssh-ed25519" + sstr pub)) 0 + ")\n"))))
         0)
    hk (ssh-key hkp (\ _ ()))
    _ (? (string? hk) (die hk) 0)
    _ (chdir home)
    _ (map (kv \ setenv (kv 0) (kv 1)) [["HOME" home] ["USER" (me 0)] ["LOGNAME" (me 0)] ["SHELL" (me 2)]])
    r (sshd-serve (o 'port) hk (o 'ak) me (o 'quiet))
    (die ("cannot listen on port " + show (o 'port) + " (" + show r + ")"))))
; --- scp: rcp's protocol over an exec channel (OpenSSH's scp -O) ---
; one engine, two carriers: io is a tablet of 'rd (n -> bytes | ()), 'line (-> through a
; newline | ()), 'wr (bytes ->) and 'err (a message the peer or we should see). the client
; carries it over ssh-open's channel; `scp -t` and `scp -f` carry it over stdin and stdout,
; the ends a remote shell runs. a name with a slash, or . or .., is refused on receipt.
(:
   (sc-oct m) (: (d k) (string (48 + (m >> k & 7))) (d 9 + d 6 + d 3 + d 0))
   (sc-unoct s) (foldl (a \ c \ a * 8 + c - 48) 0 (map (i \ s i) (jot #s)))
   (sc-isdir? p) (: st (stat p) (two? st ? (st 2 & 61440 = 16384) 0))
   (sc-base p) (: q (1 < #p && p (#p - 1) = 47 ? (snip p 0 (#p - 1)) p)
                  (last (split q 47)))
   (sc-z io) ((io 'wr) (string 0))
   ; the peer's answer to a step -> 1, or [code message] (1 a warning, 2 fatal)
   (sc-ack io)
    (: b ((io 'rd) 1)
       (? !(string? b) [2 "lost connection"]
          (b 0 = 0) 1
          (: l ((io 'line) 0) [(b 0) (string? l ? (snip l 0 (#l - 1)) "")])))
   (sc-bad r) (say err ("scp: " + r 1 + "\n"), flush err, 1)

   ; --- the source: files, and with rec directories, as C/D/E lines -> errors ---
   (sc-times io st pres) (pres ? ((io 'wr) ("T" + show (st 1 // 1000) + " 0 " + show (st 9 // 1000) + " 0\n"), sc-ack io) 1)
   (sc-copy q io) (: c (see q) (c = -1 ? 0 (unsee q c, (io 'wr) (chug q), sc-copy q io)))
   (sc-put io path name rec pres)
    (: st (stat path)
       (? (atom? st) ((io 'err) (path + ": " + show st), 1)
          (st 2 & 61440 = 16384)
           (? !rec ((io 'err) (path + ": not a regular file"), 1)
              (: t0 (sc-times io st pres)
                 _ ((io 'wr) ("D" + sc-oct (st 2 & 4095) + " 0 " + name + "\n"))
                 r (sc-ack io)
                 (? (r != 1) (sc-bad r)
                    (: n (net (map (e \ sc-put io (path + "/" + e) e rec pres) (sort (readdir path))))
                       _ ((io 'wr) "E\n")
                       r2 (sc-ack io)
                       (r2 = 1 ? n (n + sc-bad r2))))))
          (: q (open path "r")
             (? !(hot? q) ((io 'err) (path + ": " + show q), 1)
                (: t0 (sc-times io st pres)
                   _ ((io 'wr) ("C" + sc-oct (st 2 & 4095) + " " + show (st 0) + " " + name + "\n"))
                   r (sc-ack io)
                   (? (r != 1) (close q, sc-bad r)
                      (: _ (sc-copy q io) _ (close q) _ (sc-z io)
                         r2 (sc-ack io)
                         (r2 = 1 ? 0 (sc-bad r2)))))))))
   (sc-source io paths rec pres)
    (: r (sc-ack io)
       (r != 1 ? (sc-bad r) (net (map (p \ sc-put io p (sc-base p) rec pres) paths))))

   ; --- the sink: into target, a directory or (one file, not rec) a name -> errors ---
   ; the bytes of a file, n of them, written to q as they come
   (sc-recv io q n) (? (n < 1) 0 (: b ((io 'rd) (min n 32768))
                                    (? !(string? b) 0 ((hot? q ? (say q b) 0), sc-recv io q (n - #b)))))
   (sc-take io dir asdir rec pres tm errs)
    (: l ((io 'line) 0)
       (? !(string? l) errs
          (: k (l 0) body (snip l 1 (#l - 1))
             f (split body 32)
             (? (k = 1 || k = 2) (say err body, say err "\n", flush err,
                                  ? (k = 2) (errs + 1) (sc-take io dir asdir rec pres () (errs + 1)))
                (k = 69) (sc-z io, errs)
                (k = 84) (sc-z io, sc-take io dir asdir rec pres (map unum f) errs)
                (k = 67 || k = 68)
                 (: mode (sc-unoct (f 0)) size (unum (f 1)) name (join " " >>f)
                    dest (asdir ? (dir + "/" + name) dir)
                    (? (0 = #name || name = "." || name = ".." || elem 47 (map (i \ name i) (jot #name)))
                        ((io 'wr) (string 2 + "scp: unexpected filename: " + name + "\n"), errs + 1)
                       (k = 68)
                        (? !rec ((io 'wr) (string 2 + "scp: received a directory without -r\n"), errs + 1)
                           (: _ (sc-isdir? dest ? 0 (mkdir dest (mode | 448)))
                              _ (sc-z io)
                              e2 (sc-take io dest 1 rec pres () 0)
                              _ (two? tm ? (utime dest (<tm * 1000)) 0)
                              (sc-take io dir asdir rec pres () (errs + e2))))
                       (: q (open dest "w")
                          _ (sc-z io)
                          _ (sc-recv io q size)
                          _ ((io 'rd) 1)
                          ok (hot? q)
                          _ (ok ? (close q, chmod dest mode, ? (two? tm) (utime dest (<tm * 1000)) 0) 0)
                          _ (ok ? (sc-z io) ((io 'wr) (string 1 + "scp: " + dest + ": cannot write\n")))
                          (sc-take io dir asdir rec pres () (ok ? errs (errs + 1))))))
                ((io 'wr) (string 2 + "scp: protocol error\n"), errs + 1)))))
   (sc-sink io target rec pres)
    (sc-z io, sc-take io target (sc-isdir? target) rec pres () 0)

   ; --- the carriers ---
   (sc-stdio _)
    (: b (tablet 4) _ (pin b 'p "")
       (fill _) (: c (see in) (c = -1 ? 0 (unsee in c, pin b 'p (b 'p + chug in), 1)))
       (rd n) (: p (b 'p) (? (n <= #p) (pin b 'p (snip p n #p), snip p 0 n) (fill 0) (rd n) ()))
       (line _) (: p (b 'p) k ((: (g i) (? (#p <= i) -1 (p i = 10) i (g (i + 1)))) 0)
                   (? (0 <= k) (rd (k + 1)) (fill 0) (line 0) ()))
       io (tablet 4)
       (pins io 'rd rd 'line line 'wr (s \ (say out s, flush out))
               'err (m \ (say out (string 1 + "scp: " + m + "\n"), flush out)),
        io))
   (sc-chan t)
    (: io (tablet 4)
       (pins io 'rd (n \ ch-read t n) 'line (_ \ ch-line t) 'wr (s \ ch-write t s)
               'err (m \ (say err ("scp: " + m + "\n"), flush err)),
        io))
   ; "[user@]host:path" -> [user host path], or () for a local path (no colon, or a slash first)
   (sc-remote s)
    (: c ((: (g i) (? (#s <= i) -1 (s i = 58) i (s i = 47) -1 (g (i + 1)))) 0)
       (? (c < 1) ()
          (: uh (snip s 0 c) path (snip s (c + 1) #s)
             at (split uh 64)
             [(two? >at ? (join "@" (rev >(rev at))) ()) (last at) (0 < #path ? path ".")]))))

; the client's end: sources and a target, one side remote -> the status
(: (scp-client o ops rec pres)
 (:
    (die m) (cl-die "scp" m)
    target (last ops)
    srcs (rev >(rev ops))
    tr (sc-remote target)
    rs (map sc-remote srcs)
    up (two? tr)
    _ (? up (? (elem 1 (map (r \ ? (two? r) 1 0) rs)) (die "copying between two remote hosts is not supported") 0)
            (? (elem 0 (map (r \ ? (two? r) 1 0) rs)) (die "a local copy is cp's; name a remote host") 0))
    far (? up tr <rs)
    _ (? up 0 (? (elem 0 (map (r \ ? (r 1 = far 1) 1 0) rs)) (die "the sources must share one remote host") 0))
    _ (? (string? <far) (pin o 'user <far) 0)
    t (cl-login "scp" o (far 1))
    flags ((rec ? " -r" "") + (pres ? " -p" ""))
    cmd (? up ("scp" + flags + " -t -- " + (tr 2)) ("scp" + flags + " -f -- " + join " " (map (r \ r 2) rs)))
    okc (ssh-open t cmd)
    _ (? (string? okc) (die okc) 0)
    io (sc-chan t)
    e (? up (sc-source io srcs rec pres) (sc-sink io target rec pres))
    st (ch-end t)
    (0 < e || st != 0 ? 1 0)))

(: (scp-main as)
 (:
    usage "usage: scp [-pqrO] [-P port] [-i identity] [-o option=value] source .. target"
    (die m) (cl-die "scp" m)
    fl (tablet 8)
    o (cl-opts 0)
    (parse as)
     (? (atom? as) ()
        (: a <as r >as
           (? (a = "-P" && two? r) (: n (unum <r) (charm? n ? (pin o 'port n) (die ("bad port " + <r)), parse >r))
              (a = "-i" && two? r) (pin o 'key <r, parse >r)
              (a = "-o" && two? r) (cl-opt "scp" o <r, parse >r)
              (a = "--") r
              (1 < #a && a 0 = 45 && !(a = "-P" || a = "-i" || a = "-o"))
               (map (i \ pin fl (a i) 1) >(jot #a), parse r)
              as)))
    ops (parse as)
    rec (peep fl 114 0) pres (peep fl 112 0)
    _ (map (c \ ? (elem c [114 112 113 79 116 102 100 118]) 0 (die ("unknown option -" + string c + "\n" + usage))) (keys fl))
    ; the remote ends over stdin and stdout, else the client
    (st e) (0 < e ? 1 0)
    (? (peep fl 116 0) (? (two? ops && atom? >ops) (st (sc-sink (sc-stdio 0) <ops rec pres)) (die usage))
       (peep fl 102 0) (st (sc-source (sc-stdio 0) ops rec pres))
       (two? ops && two? >ops) (scp-client o ops rec pres)
       (die usage))))

) ; module ssh-cli
