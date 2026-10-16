; src/apps/ssh/cli.l -- the ssh and sshd commands over the module: flags, keys, known_hosts and
; the one user served. src/apps/ssh/ssh.l is the door that loads it all from source; baked into
; the image, kore reaches both as (cite 'ssh-cli ..).
;
;   ssh [-p port] [-i identity] [-l user] [-t | -T] [-o option=value] [user@]host [command ..]
;       -o UserKnownHostsFile=path, -o StrictHostKeyChecking=ask|accept-new|yes|no, -o IdentityFile=path
;   sshd [-Deq] [-p port] [-h host_key_file] [-o AuthorizedKeysFile=path]
;   scp [-pqrO] [-P port] [-i identity] [-o option=value] source .. target
;   ssh-keygen [-q] [-a rounds] [-C comment] [-f file] [-N passphrase] [-t ed25519], or -y, -l,
;       -p, -F host, -R host
;   ssh-copy-id [-fn] [-i identity_file] [-p port] [-o option=value] [-t target_path] [user@]host
;   ssh-keyscan [-Hq] [-f file] [-p port] [-t type] host ..
(module (ssh-cli ssh-main sshd-main scp-main keygen-main copyid-main keyscan-main kh-name kh-check kh-verdict)
(borrow 'ssh)
(borrow 'tls)
(borrow 'posix)
(borrow 'bytes)
(borrow 'hashes)

; what ssh and scp share: the options and their defaults, and the login -- dial, the host key
; held to known_hosts, the identity, publickey auth. a failure is said as prog's and leaves
; with 255 through udie; the mains answer their status, and the seat (ssh.l) quits with it
(:
   (cl-die prog m) (udie 255 (prog + ": " + m))
   (cl-env k d) (: v (getenv k) (string? v ? v d))
   (cl-opts _)
    (: home (cl-env "HOME" "") o (tablet 8)
       (pins o 'port 22 'user (cl-env "USER" "") 'key (home + "/.ssh/id_ed25519")
               'kh (home + "/.ssh/known_hosts") 'shk "ask" 'pty -1,
        o))
   (cl-opt prog o kv)
    ((kv @ (k + "=" + v) [k v] [kv ""]) @ [k v]
       (? (k = "UserKnownHostsFile") (pin o 'kh v)
          (k = "IdentityFile") (pin o 'key v)
          (k = "StrictHostKeyChecking")                    ; ask (the default), accept-new, yes, no
           (: w (v = "off" ? "no" v)
              (elem w ["ask" "accept-new" "yes" "no"] ? (pin o 'shk w)
                 (cl-die prog ("unsupported StrictHostKeyChecking value " + v))))
          (cl-die prog ("unsupported option " + k))))
   ; known_hosts as openssh reads it. a name list holds plain names, [host]:port and
   ; |1|salt|hash (hmac-sha1 of the name keyed by the salt); wildcards and ! are not read
   (kh-low s) (string (map (i \ (: c (s i) (64 < c && c < 91 ? (c + 32) c))) (jot #s)))
   (kh-name host port) (: h (kh-low host) (port = 22 ? h ("[" + h + "]:" + show port)))
   (kh-hmac1 k m)
    (: kp (k + zeros (64 - #k))
       (x p) (xors kp (bytes 64 (_ \ p)))
       (unhex (sha1 (x 92 + unhex (sha1 (x 54 + m))))))
   (kh-named? pats name)
    (elem 1 (map (p \ (? (3 < #p && snip p 0 3 = "|1|")
                         (: f (split p 124) (#f = 4 && kh-hmac1 (b64d (f 2)) name = b64d (f 3) ? 1 0))
                         (kh-low p = name ? 1 0)))
                 (split pats 44)))
   ; -> [verdict line type ca]. verdicts by rank: 'revoked (the key is on an @revoked line,
   ; whatever its names), 'ok, 'bad (another ed25519 key), 'other (known only under
   ; another key type), 'new. ca is 1 when a @cert-authority line names the host: no
   ; certificate is read here, so such a line is skipped, never trusted
   (kh-check path name key)
    (: q (open path "r")
       txt (hot? q ? (: s (slurp q) (close q, s)) "")
       (fields l) (filter (w \ 0 < #w) (split (string (map (i \ (: c (l i) (c = 9 ? 32 c))) (jot #l))) 32))
       (cls l ln)
        (: f (fields l) w (two? f ? <f "")
           (? (0 = #w || w 0 = 35) ()
              (w = "@revoked") (3 < #f && b64d (f 3) = key ? ['revoked ln (f 2)] ())
              (w = "@cert-authority") (2 < #f && kh-named? (f 1) name ? ['ca ln (f 2)] ())
              (w 0 = 64) ()
              (3 <= #f && kh-named? w name)
               (f 1 = "ssh-ed25519" ? [(b64d (f 2) = key ? 'ok 'bad) ln (f 1)] ['other ln (f 1)])
              ()))
       (go ls ln a) (? (atom? ls) a (go >ls (ln + 1) (: h (cls <ls ln) (two? h ? (h . a) a))))
       hits (rev (go (split txt 10) 1 ()))
       (first v) (: m (filter (h \ <h = v) hits) (two? m ? <m ()))
       r (? (two? (first 'revoked)) (first 'revoked) (two? (first 'ok)) (first 'ok)
            (two? (first 'bad)) (first 'bad) (two? (first 'other)) (first 'other) ['new 0 ""])
       [<r (r 1) (r 2) (two? (first 'ca) ? 1 0)])
   (kh-add path name key)
    (: q (open path "a")
       (? (hot? q) (say q (name + " ssh-ed25519 " + b64e key 1 + "\n"), close q, 1) 0))
   ; a line off the controlling terminal after a prompt, echoed or not -> the line, or ()
   ; when there is no terminal to ask on
   (ttyask prompt echo)
    (: q (open "/dev/tty" "r")
       (? !(hot? q) ()
          (: _ (say err prompt) _ (flush err)
             _ (echo ? 0 (ptyecho q 0)) ch (see q) _ (unsee q ch) l (chug q) _ (echo ? 0 (ptyecho q 1)) _ (close q)
             _ (echo ? 0 (say err "\n", flush err))
             n (string? l ? #l 0)
             (? !(string? l) () (0 < n && l (n - 1) = 10) (snip l 0 (n - 1)) l))))
   ; a locked key's passphrase, its echo off while it is typed
   (askpass path) (ttyask ("Enter passphrase for key '" + path + "': ") 0)
   ; the offered host key against known_hosts -> 'go, 'add (a new host, or one known under
   ; another type and confirmed on the terminal) | the refusal. (ask prompt) -> a line | ()
   (kh-verdict prog o path name key fpr ask)
    (: shk (o 'shk)
       (asks q) (shk = "yes" ? () (ask ("The authenticity of host '" + name + "' can't be established.\n"
                                         + "ED25519 key fingerprint is " + fpr + ".\n" + q
                                         + "Are you sure you want to continue connecting (yes/no)? ")))
       (? (shk = "no") 'go
          (: r (kh-check path name key) v <r at (path + ":" + show (r 1))
             _ (r 3 = 1 ? (say err (prog + ": " + path + " has a @cert-authority line for " + name
                                    + "; certificates are not read, so it is skipped\n")) 0)
             (? (v = 'ok) 'go
                (v = 'revoked) ("WARNING: REVOKED HOST KEY DETECTED! the ssh-ed25519 host key for "
                                + name + " is marked as revoked in " + at + ". Host key verification failed.")
                (v = 'bad) ("WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED! the host key for "
                            + name + " is " + fpr + ", which does not match " + at + ". Host key verification failed.")
                (v = 'other)
                 (asks ("Warning: keys of a different type are already known for this host: "
                        + r 2 + " in " + at + ".\n") = "yes" ? 'add
                    ("WARNING: the host key for " + name + " is known as " + r 2 + " in " + at
                     + ", and the host offered ssh-ed25519 " + fpr + ". Host key verification failed."))
                (shk = "accept-new") 'add
                (shk = "yes") ("No ssh-ed25519 host key is known for " + name
                               + " and you have requested strict checking. Host key verification failed.")
                (asks "" = "yes" ? 'add "Host key verification failed.")))))
   (cl-login prog o host)
    (: t (ssh-dial host (o 'port))
       _ (? (string? t) (cl-die prog t) 0)
       name (kh-name host (o 'port))
       path (o 'kh) key (t 'hostkey)
       v (kh-verdict prog o path name key (ssh-fingerprint t) (m \ ttyask m 1))
       _ (? (v = 'go) 0
            (v = 'add) (kh-add path name key,
                        say err (prog + ": added " + name + " (" + ssh-fingerprint t + ") to " + path + "\n"))
            (cl-die prog v))
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
    _ (? (string? dest) 0 (cl-die "ssh" "usage: ssh [-p port] [-i identity] [-l user] [-t|-T] [-o option=value] [user@]host [command]"))
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
     ((kv @ (k + "=" + v) [k v] [kv ""]) @ [k v]
        (? (k = "AuthorizedKeysFile") (pin o 'ak v) (die ("unsupported option " + k))))
    (parse as)
     (? (atom? as) 0
        (: a <as r >as
           (? (a = "-p" && two? r)
               (: n (uport <r)
                  (n ? (pin o 'port n) (die ("bad port " + <r)),
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
; the ends a remote shell runs. a name with a slash, or . or .., is refused on receipt;
; the client takes at the top only the names it asked for, and a mode loses its setuid,
; setgid and sticky bits, and the umask's too without -p.
(:
   sc-match (cite 'glob 'match)
   (sc-oct m) (: (d k) (string (48 + (m >> k & 7))) (d 9 + d 6 + d 3 + d 0))
   (sc-unoct s) (foldl (a \ c \ a * 8 + c - 48) 0 (map (i \ s i) (jot #s)))
   (sc-isdir? p) (: st (stat p) (two? st ? (st 2 & 61440 = 16384) 0))
   (sc-base p) (: q (1 < #p && p (#p - 1) = 47 ? (snip p 0 (#p - 1)) p)
                  (last (split q 47)))
   (sc-z io) (io 'wr (string 0))
   ; the peer's answer to a step -> 1, or [code message] (1 a warning, 2 fatal)
   (sc-ack io)
    (: b (io 'rd 1)
       (? !(string? b) [2 "lost connection"]
          (b 0 = 0) 1
          (: l (io 'line 0) [(b 0) (string? l ? (snip l 0 (#l - 1)) "")])))
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
                 _ (io 'wr ("D" + sc-oct (st 2 & 4095) + " 0 " + name + "\n"))
                 r (sc-ack io)
                 (? (r != 1) (sc-bad r)
                    (: n (net (map (e \ sc-put io (path + "/" + e) e rec pres) (sort (readdir path))))
                       _ (io 'wr "E\n")
                       r2 (sc-ack io)
                       (r2 = 1 ? n (n + sc-bad r2))))))
          (: q (open path "r")
             (? !(hot? q) ((io 'err) (path + ": " + show q), 1)
                (: t0 (sc-times io st pres)
                   _ (io 'wr ("C" + sc-oct (st 2 & 4095) + " " + show (st 0) + " " + name + "\n"))
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
   (sc-recv io q n) (? (n < 1) 0 (: b (io 'rd (min n 32768))
                                    (? !(string? b) 0 ((hot? q ? (say q b) 0), sc-recv io q (n - #b)))))
   ; want: the names asked for, globs allowed; () takes any (scp -t, or inside a directory)
   (sc-want? want name) (atom? want || elem 1 (map (p \ ? (p = name || sc-match p name) 1 0) want))
   (sc-mode m pres) (: o (umask 18) _ (umask o) (m & 511 & (pres ? 511 (511 ^ o))))
   (sc-take io want dir asdir rec pres tm errs)
    (: l (io 'line 0)
       (? !(string? l) errs
          (: k (l 0) body (snip l 1 (#l - 1))
             f (split body 32)
             (? (k = 1 || k = 2) (say err body, say err "\n", flush err,
                                  ? (k = 2) (errs + 1) (sc-take io want dir asdir rec pres () (errs + 1)))
                (k = 69) (sc-z io, errs)
                (k = 84) (sc-z io, sc-take io want dir asdir rec pres (map unum f) errs)
                (k = 67 || k = 68)
                 (: mode (sc-unoct (f 0)) size (unum (f 1)) name (join " " >>f)
                    dest (asdir ? (dir + "/" + name) dir)
                    (? (0 = #name || name = "." || name = ".." || elem 47 (map (i \ name i) (jot #name))
                        || !(sc-want? want name))
                        ((io 'wr) (string 2 + "scp: unexpected filename: " + name + "\n"), errs + 1)
                       (k = 68)
                        (? !rec ((io 'wr) (string 2 + "scp: received a directory without -r\n"), errs + 1)
                           (: _ (sc-isdir? dest ? 0 (mkdir dest (sc-mode mode 1 | 448)))
                              _ (sc-z io)
                              e2 (sc-take io () dest 1 rec pres () 0)
                              _ (two? tm ? (utime dest (<tm * 1000)) 0)
                              (sc-take io want dir asdir rec pres () (errs + e2))))
                       (: q (open dest "w")
                          _ (sc-z io)
                          _ (sc-recv io q size)
                          _ (io 'rd 1)
                          ok (hot? q)
                          _ (ok ? (close q, chmod dest (sc-mode mode pres), ? (two? tm) (utime dest (<tm * 1000)) 0) 0)
                          _ (ok ? (sc-z io) (io 'wr (string 1 + "scp: " + dest + ": cannot write\n")))
                          (sc-take io want dir asdir rec pres () (ok ? errs (errs + 1))))))
                ((io 'wr) (string 2 + "scp: protocol error\n"), errs + 1)))))
   (sc-sink io want target rec pres)
    (sc-z io, sc-take io want target (sc-isdir? target) rec pres () 0)

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
    (s @ ((uh && 0 < #uh && fsub uh "/" 0 < 0) + ":" + path)
       (: at (split uh 64)
          [(two? >at ? (join "@" (rev >(rev at))) ()) (last at) (0 < #path ? path ".")])
       ()))

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
    ; the names a download may bring: each source's own, its glob matched; a brace takes any
    want (map (r \ (: b (sc-base (r 2)) (elem 123 (map (i \ b i) (jot #b)) ? "*" b))) rs)
    e (? up (sc-source io srcs rec pres) (sc-sink io want target rec pres))
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
    (? (peep fl 116 0) (? (two? ops && atom? >ops) (st (sc-sink (sc-stdio 0) () <ops rec pres)) (die usage))
       (peep fl 102 0) (st (sc-source (sc-stdio 0) ops rec pres))
       (two? ops && two? >ops) (scp-client o ops rec pres)
       (die usage))))

; --- ssh-keygen, ssh-copy-id and ssh-keyscan: ed25519 keys in openssh's own format ---
; flags by getopt's rules: letters run together, a value glued on or the next word
(:
   ; -> [flags rest]: flags a tablet of letter -> its values, last first, or 1 for a flag
   ; without one; (kg-opt o c) the last value
   (kg-getopt prog usage vals bools as)
    (: o (tablet 8)
       (word w i r)
        (? (#w <= i) (go r)
           (: c (w i)
              (? (elem c vals) (? (i + 1 < #w) (pin o c (snip w (i + 1) #w . peep o c ()), go r)
                                  (two? r) (pin o c (<r . peep o c ()), go >r)
                                  (cl-die prog ("option requires an argument -- " + string c + "\n" + usage)))
                 (elem c bools) (pin o c 1, word w (i + 1) r)
                 (cl-die prog ("unknown option -- " + string c + "\n" + usage)))))
       (go as) (? (atom? as) () (<as = "--") >as (1 < #<as && <as 0 = 45) (word <as 1 >as) as)
       r (go as)
       [o r])
   (kg-opt o c) (peep o c () @ v (two? v ? <v v))
   (kg-slurp path) (: q (open path "r") (hot? q ? (: s (slurp q) (close q, s)) ()))
   (kg-fpr blob) ("SHA256:" + b64e (sha blob) 0)
   (kg-blob pub) (sstr "ssh-ed25519" + sstr pub)
   ; a public key line's parts wherever its type sits (authorized_keys puts options ahead,
   ; known_hosts names) -> [bits fingerprint comment label] | ()
   (kg-pubparts l)
    (: f (filter (w \ 0 < #w) (split l 32))
       (at i) (? (#f <= i + 1) ()
                 (: t (f i) b (b64d (f (i + 1)))
                    (? (3 < #t && (snip t 0 4 = "ssh-" || snip t 0 4 = "ecds" || snip t 0 3 = "sk-")
                        && 4 < #b && snip b 4 (4 + #t) = t)
                       (: cm (join " " (snip f (i + 2) #f))
                          c (cur b) _ (g-str c)
                          bits (? (t = "ssh-rsa") (: _ (g-str c) n (g-str c) (bitlen (foldl (a \ c \ a * 256 + c) 0 (chars n))))
                                  (fsub t "256" 0 >= 0) 256 (fsub t "384" 0 >= 0) 384 (fsub t "521" 0 >= 0) 521
                                  (fsub t "ed25519" 0 >= 0) 256 0)
                          lab (? (t = "ssh-rsa") "RSA" (t = "ssh-ed25519") "ED25519"
                                 (t = "sk-ssh-ed25519@openssh.com") "ED25519-SK"
                                 (snip t 0 3 = "sk-") "ECDSA-SK" (snip t 0 4 = "ecds") "ECDSA" "DSA")
                          [bits (kg-fpr b) (0 < #cm ? cm (0 < i ? (f (i - 1)) "no comment")) lab])
                       (at (i + 1)))))
       (0 < #f && f 0 0 != 35 ? (at 0) ()))
   ; a passphrase twice on the terminal, or () when there is none or the two differ
   (kg-newpass prog)
    (: a (ttyask "Enter passphrase (empty for no passphrase): " 0)
       (? !(string? a) (cl-die prog "no terminal to read a passphrase from; give it with -N")
          (ttyask "Enter same passphrase again: " 0 @ b
             (a = b ? a (cl-die prog "passphrases do not match"))))))

; ssh-keygen: make an ed25519 key, or read one: -y its public line, -l a fingerprint, -p a
; new passphrase; -F and -R find and remove a host in known_hosts
(: (keygen-main as)
 (:
    usage "usage: ssh-keygen [-q] [-a rounds] [-C comment] [-f file] [-N passphrase] [-t ed25519]
       ssh-keygen -y [-f file] [-P passphrase]
       ssh-keygen -l [-f file]
       ssh-keygen -p [-a rounds] [-f file] [-P old] [-N new]
       ssh-keygen -F hostname [-f known_hosts]
       ssh-keygen -R hostname [-f known_hosts]"
    (die m) (cl-die "ssh-keygen" m)
    go (kg-getopt "ssh-keygen" usage (chars "tfNCPaFRE") (chars "qylpvh") as)
    o <go
    (opt c) (kg-opt o c)
    _ (? (two? (go 1)) (die ("unexpected argument " + <(go 1) + "\n" + usage)) 0)
    _ (? (opt 104) (die usage) 0)
    home (cl-env "HOME" "")
    q (opt 113)
    rounds (? (opt 97) (unum (opt 97)) 24)
    _ (? (charm? rounds && 0 < rounds) 0 (die ("bad rounds " + show (opt 97))))
    kfile (opt 102)
    (pass p) (opt 80 @ v (string? v ? v (ttyask ("Enter passphrase for \"" + p + "\": ") 0)))
    (read p) (: t (kg-slurp p)
                (? !(string? t) (die ("cannot read " + p))
                   (ssh-keyparts p t pass @ k (string? k ? (die k) k))))
    (say1 s) (say out s, flush out)
    (keyfile _) (? (string? kfile) kfile
                   (: d (home + "/.ssh/id_ed25519")
                      a (ttyask ("Enter file in which to save the key (" + d + "): ") 1)
                      (string? a && 0 < #a ? a d)))
    ; known_hosts' lines whose names hold host, in order -> [number line]..
    kh (? (string? kfile) kfile (home + "/.ssh/known_hosts"))
    (khfind host)
     (: t (kg-slurp kh) name (kh-low host)
        (go ls n a)
         (? (atom? ls) (rev a)
            (: f (filter (w \ 0 < #w) (split <ls 32))
               w (two? f && <f 0 = 64 && two? >f ? (f 1) (two? f ? <f ""))
               (go >ls (n + 1) (0 < #w && w 0 != 35 && kh-named? w name ? ([n <ls] . a) a))))
        (string? t ? (go (split t 10) 1 ()) (die ("cannot read " + kh))))
    (? (opt 70)                                                  ; -F
        (: hs (khfind (opt 70))
           (map (h \ say1 ("# Host " + opt 70 + " found: line " + show <h + " \n" + h 1 + "\n")) hs,
            two? hs ? 0 1))
       (opt 82)                                                  ; -R
        (: hs (khfind (opt 82))
           (? (atom? hs) (say err ("Host " + opt 82 + " not found in " + kh + "\n"), 0)
              (: t (kg-slurp kh) ns (map (h \ <h) hs)
                 keep (: (k ls n) (? (atom? ls) () (elem n ns) (k >ls (n + 1)) (<ls . k >ls (n + 1)))
                         (k (split t 10) 1))
                 mode (stat kh 2 & 511)
                 _ (unlink (kh + ".old"))
                 _ (? (nom? (rename kh (kh + ".old"))) (die ("cannot rename " + kh)) 0)
                 w (open kh "w")
                 _ (? (hot? w) (say w (join "\n" keep), close w, chmod kh mode) (die ("cannot write " + kh)))
                 (map (n \ say1 ("# Host " + opt 82 + " found: line " + show n + "\n")) ns,
                  say1 (kh + " updated.\nOriginal contents retained as " + kh + ".old\n"),
                  0))))
       (opt 108)                                                 ; -l
        (: p (keyfile 0)
           t (kg-slurp p)
           _ (? (string? t) 0 (die ("cannot read " + p)))
           (line r) (say1 (show <r + " " + r 1 + " " + r 2 + " (" + r 3 + ")\n"))
           ls (filter two? (map kg-pubparts (split t 10)))
           (? (two? ls) (map line ls, 0)
              (ssh-keyhead p t @ k
                 (? (string? k) (die (p + " is not a key file"))
                    (: pt (kg-slurp (p + ".pub"))
                       r (string? pt ? (kg-pubparts <(split pt 10)) ())
                       (line (two? r ? r [256 (kg-fpr (kg-blob (k 1))) "no comment" "ED25519"]), 0))))))
       (opt 121)                                                 ; -y
        (: p (keyfile 0) k (read p) (say1 (ssh-publine (k 1) (k 2)), 0))
       (opt 112)                                                 ; -p
        (: p (keyfile 0) k (read p)
           np (? (string? (opt 78)) (opt 78) (kg-newpass "ssh-keygen"))
           tmp (p + ".new")
           _ (unlink tmp)
           w (ssh-keyfile tmp (ssh-keyout <k (k 1) (k 2) np rounds))
           _ (? (string? w) (die w) 0)
           _ (? (nom? (rename tmp p)) (die ("cannot replace " + p)) 0)
           (say1 "Your identification has been saved with the new passphrase.\n", 0))
       ; making a key
       (: ty (opt 116 @ t (string? t ? t "ed25519"))
          _ (? (ty = "ed25519") 0 (die ("unsupported key type " + ty + "; ed25519 keys only")))
          _ (q ? 0 (say1 "Generating public/private ed25519 key pair.\n"))
          p (keyfile 0)
          dir (: i (last (filter (i \ p i = 47) (jot #p))) (charm? i ? (snip p 0 i) ""))
          _ (? (0 < #dir && atom? (stat dir))
               (: _ (mkdir dir 448) (q ? 0 (say1 ("Created directory '" + dir + "'.\n")))) 0)
          _ (? (two? (stat p))
               (ttyask (p + " already exists.\nOverwrite (y/n)? ") 1 @ a
                  (string? a && 0 < #a && (a 0 = 121 || a 0 = 89) ? (unlink p) (die "not overwriting")))
               0)
          np (? (string? (opt 78)) (opt 78) (kg-newpass "ssh-keygen"))
          me (uname () @ u (two? u ? (u 1) "localhost"))
          cm (opt 67 @ c (string? c ? c (cl-env "USER" "" + "@" + me)))
          seed (rnd 32) pub (ed-pub seed)
          w (ssh-keyfile p (ssh-keyout seed pub cm np rounds))
          _ (? (string? w) (die w) 0)
          pq (open (p + ".pub") "w")
          _ (? (hot? pq) (say pq (ssh-publine pub cm), close pq) (die ("cannot write " + p + ".pub")))
          (q ? 0 (say1 ("Your identification has been saved in " + p + "\nYour public key has been saved in "
                        + p + ".pub\nThe key fingerprint is:\n" + kg-fpr (kg-blob pub) + " " + cm + "\n")),
           0)))))

; ssh-copy-id: the identity's public line onto the far end's authorized_keys, by a shell
; there: ~/.ssh (or -t's directory) made 700 and the file 600, a key already there skipped. the
; login is ssh's, its own identity (-o IdentityFile picks another); -n says what it would do,
; -f skips the check
(: (copyid-main as)
 (:
    usage "usage: ssh-copy-id [-fn] [-i identity_file] [-p port] [-o option=value] [-t target_path] [user@]host"
    (die m) (cl-die "ssh-copy-id" m)
    go (kg-getopt "ssh-copy-id" usage (chars "ipot") (chars "fnh") as)
    fl <go args (go 1)
    (opt c) (kg-opt fl c)
    _ (? (opt 104 || !(two? args) || two? >args) (die usage) 0)
    o (cl-opts 0)
    _ (? (opt 112) (: n (unum (opt 112)) (charm? n ? (pin o 'port n) (die ("bad port " + opt 112)))) 0)
    _ (map (kv \ cl-opt "ssh-copy-id" o kv) (rev (peep fl 111 ())))
    id (opt 105 @ i (? !(string? i) (o 'key + ".pub") (4 < #i && snip i (#i - 4) #i = ".pub") i (i + ".pub")))
    pt (kg-slurp id)
    _ (? (string? pt) 0 (die ("cannot read " + id)))
    line (filter (l \ two? (kg-pubparts l)) (split pt 10) @ ls (two? ls ? <ls (die (id + " holds no public key"))))
    f (filter (w \ 0 < #w) (split line 32))
    blob (: (go i) (? (#f <= i + 1) (f 1) (snip (f i) 0 4 = "ssh-" ? (f (i + 1)) (go (i + 1)))) (go 0))
    (sq s) ("'" + join "'\\''" (split s 39) + "'")
    ak (opt 116 @ t (string? t ? (sq t) ".ssh/authorized_keys"))
    akd (opt 116 @ t (? !(string? t) ".ssh" (: i (last (filter (i \ t i = 47) (jot #t))) (? !(charm? i) "." (i = 0) "/" (sq (snip t 0 i))))))
    cmd (? (opt 110) ("cd && if grep -qF " + sq blob + " " + ak + " 2>/dev/null; then echo present; else echo absent; fi")
           ("cd || exit 1; umask 077; mkdir -p " + akd + " && chmod 700 " + akd + " && touch " + ak + " && chmod 600 " + ak + " || exit 1; "
            + (opt 102 ? "" ("if grep -qF " + sq blob + " " + ak + "; then echo present; exit 0; fi; "))
            + "if [ -s " + ak + " ] && [ -n \"$(tail -c 1 " + ak + ")\" ]; then echo >> " + ak + "; fi; "
            + "printf '%s\\n' " + sq line + " >> " + ak + " && echo added"))
    dest <args
    at (split dest 64)
    host (two? >at ? (last at) <at)
    _ (? (two? >at) (pin o 'user (join "@" (rev >(rev at)))) 0)
    t (cl-login "ssh-copy-id" o host)
    okc (ssh-open t cmd)
    _ (? (string? okc) (die okc) 0)
    (rest a) (ch-line t @ l (string? l ? (rest (l . a)) (rev a)))
    said (join "" (rest ()))
    st (ch-end t)
    who (o 'user + "@" + host)
    fpr (: r (kg-pubparts line) (r 1))
    (? (st != 0) (die ("the far end said " + show st + " " + said))
       (fsub said "present" 0 >= 0) (say err ("ssh-copy-id: " + fpr + " is already on " + who + ", skipped\n"), 0)
       (fsub said "absent" 0 >= 0) (say out ("would add " + fpr + " to " + who + ": " + line + "\n"), 0)
       (fsub said "added" 0 >= 0) (say out ("Number of key(s) added: 1, " + fpr + " to " + who + "\n"), 0)
       (die ("the far end said " + said)))))

; ssh-keyscan: each host's ed25519 key, as known_hosts lines on stdout; -H hashes the names.
; a host's version line goes to stderr unless -q, and a host with no answer sets status 1
(: (keyscan-main as)
 (:
    usage "usage: ssh-keyscan [-Hq] [-f file] [-p port] [-t type] host .."
    (die m) (cl-die "ssh-keyscan" m)
    go (kg-getopt "ssh-keyscan" usage (chars "ptf") (chars "Hqh") as)
    fl <go
    (opt c) (kg-opt fl c)
    _ (? (opt 104) (die usage) 0)
    port (opt 112 @ p (? (string? p) (unum p @ n (charm? n ? n (die ("bad port " + p)))) 22))
    tys (opt 116 @ t (string? t ? (split t 44) ["ed25519"]))
    ed (elem 1 (map (t \ t = "ed25519" || t = "ssh-ed25519" ? 1 0) tys))
    _ (map (t \ t = "ed25519" || t = "ssh-ed25519" ? 0
                (say err ("ssh-keyscan: only ed25519 keys are read here; skipping " + t + "\n"))) tys)
    hosts (go 1 + (opt 102 @ f (? !(string? f) ()
                                          (: t (f = "-" ? (slurp in) (kg-slurp f))
                                             (string? t ? (filter (l \ 0 < #l && l 0 != 35) (split t 10))
                                                (die ("cannot read " + f)))))))
    _ (? (two? hosts) 0 (die usage))
    (hashed n) (: salt (rnd 20) ("|1|" + b64e salt 1 + "|" + b64e (kh-hmac1 salt n) 1))
    (one h)
     (: t (ssh-dial h port)
        (? (string? t) (say err ("ssh-keyscan: " + h + ": " + t + "\n"), 1)
           (: _ (close (t 's))
              _ (opt 113 ? 0 (say err ("# " + h + ":" + show port + " " + ssh-clean (t 'peer) + "\n")))
              n (kh-name h port)
              (say out ((opt 72 ? (hashed n) n) + " ssh-ed25519 " + b64e (t 'hostkey) 1 + "\n"), flush out, 0))))
    (? !ed 1 (foldl max 0 (map one hosts) ? 1 0))))

) ; module ssh-cli
