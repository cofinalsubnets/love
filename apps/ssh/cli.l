; apps/ssh/cli.l -- the ssh and sshd commands over the module: flags, keys, known_hosts and
; the one user served. apps/ssh/ssh.l is the door that loads it all from source; baked into
; the image, kore reaches both as (cite 'ssh-cli ..).
;
;   ssh [-p port] [-i identity] [-l user] [-t | -T] [-o option=value] [user@]host [command ..]
;   sshd [-Deq] [-p port] [-h host_key_file] [-o AuthorizedKeysFile=path]
(module (ssh-cli ssh-main sshd-main)
(borrow 'ssh)
(borrow 'tls)
(borrow 'posix)

(: (ssh-main as)
 (:
    (die m) (say err ("ssh: " + m + "\n"), quit 255)
    (atoi s) (: (go i a) (? (i < #s) (go (i + 1) (10 * a + s i - 48)) a) (go 0 0))
    (env k d) (: v (getenv k) (? (string? v) v d))

    ; known_hosts: 'ok on a match, 'bad on a different ed25519 key, else 'new
    (kh-name host port) (? (port = 22) host ("[" + host + "]:" + show port))
    (kh-check path name key)
     (: q (open path "r")
        txt (? (hot? q) (: s (slurp q) _ (close q) s) "")
        (look ls) (? !(two? ls) 'new
                     (: f (split <ls 32)
                        (? ((3 <= #f) && (elem name (split <f 44)) && (f 1 = "ssh-ed25519"))
                           (? (b64d (f 2) = key) 'ok 'bad)
                           (look >ls))))
        (look (split txt 10)))
    (kh-add path name key)
     (: q (open path "a")
        (? (hot? q) (say q (name + " ssh-ed25519 " + b64e key 1 + "\n"), close q, 1) 0))
    (hostcheck t o name)
     (: path (o 'kh) key (t 'hostkey)
        (? !(o 'strict) 1
           (: v (kh-check path name key)
              (? (v = 'ok) 1
                 (v = 'bad) (die ("the host key for " + name + " has CHANGED -- " + ssh-fingerprint t
                                  + " does not match " + path))
                 (: _ (kh-add path name key)
                    (say err ("ssh: added " + name + " (" + ssh-fingerprint t + ") to " + path + "\n")))))))

    ; a locked key's passphrase off the terminal, its echo off while it is typed
    (askpass path)
     (: q (open "/dev/tty" "r")
        (? !(hot? q) ()
           (: _ (say err ("Enter passphrase for key '" + path + "': ")) _ (flush err)
              _ (ptyecho q 0) ch (see q) _ (unsee q ch) l (chug q) _ (ptyecho q 1) _ (close q)
              _ (say err "\n") _ (flush err)
              n (? (string? l) #l 0)
              (? !(string? l) () ((0 < n) && (l (n - 1) = 10)) (snip l 0 (n - 1)) l))))

    (opt o kv)
     (: i (: (go i) (? (#kv <= i) i (kv i = 61) i (go (i + 1))) (go 0))
        k (snip kv 0 i) v (snip kv (i + 1) #kv)
        (? (k = "UserKnownHostsFile") (pin o 'kh v)
           (k = "StrictHostKeyChecking") (pin o 'strict !(v = "no"))
           (die ("unsupported option " + k))))
    (parse as o)
     (? !(two? as) o
        (: a <as r >as
           (? ((a = "-p") && (two? r)) (: _ (pin o 'port (atoi <r)) (parse >r o))
              ((a = "-i") && (two? r)) (: _ (pin o 'key <r) (parse >r o))
              ((a = "-l") && (two? r)) (: _ (pin o 'user <r) (parse >r o))
              ((a = "-o") && (two? r)) (: _ (opt o <r) (parse >r o))
              (a = "-t") (: _ (pin o 'pty 1) (parse r o))
              (a = "-T") (: _ (pin o 'pty 0) (parse r o))
              ((0 < #a) && (a 0 = 45)) (die ("unknown flag " + a))
              (: _ (pin o 'dest a) _ (? (two? r) (pin o 'cmd (join " " r)) 0) o))))

    (: home (env "HOME" "")
    o (tablet 8)
    _ (pin o 'port 22) _ (pin o 'user (env "USER" "")) _ (pin o 'key (home + "/.ssh/id_ed25519"))
    _ (pin o 'kh (home + "/.ssh/known_hosts")) _ (pin o 'strict 1) _ (pin o 'pty -1)
    _ (parse as o)
    dest (o 'dest)
    _ (? (string? dest) 0 (die "usage: ssh [-p port] [-i identity] [-l user] [-t|-T] [user@]host [command]"))
    at (split dest 64)
    host (? (two? >at) <>at <at)
    _ (? (two? >at) (pin o 'user <at) 0)
    t (ssh-dial host (o 'port))
    _ (? (string? t) (die t) 0)
    _ (hostcheck t o (kh-name host (o 'port)))
    k (ssh-key (o 'key) askpass)
    _ (? (string? k) (die k) 0)
    a (ssh-auth t (o 'user) <k <>k)
    _ (? (string? a) (die a) 0)
    cmd (o 'cmd)
    pty? (? (o 'pty < 0) ((nil? cmd) && (two? (tty 0))) (o 'pty))
    st (ssh-run t cmd pty?)
    (quit (? (st < 0) 255 st)))))

; sshd serves the user it runs as. the host key is -h's, else the system's when this user
; can read it, else one of its own at ~/.ssh/sshd_ed25519_key, made on first use and said.
; it never detaches (-D is taken for openssh's sake) and logs to stderr (-e likewise).
(: (sshd-main as)
 (:
    usage "usage: sshd [-Deq] [-p port] [-h host_key_file] [-o AuthorizedKeysFile=path]"
    (die m) (say err ("sshd: " + m + "\n"), quit 255)
    (readable? p) (: q (open p "r") (? (hot? q) (: _ (close q) 1) 0))
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
     (? !(two? as) 0
        (: a <as r >as
           (? ((a = "-p") && (two? r))
               (: n (unum <r) _ (? ((charm? n) && (0 < n) && (n < 65536)) (pin o 'port n) (die ("bad port " + <r)))
                  (parse >r))
              ((a = "-h") && (two? r)) (: _ (pin o 'hk <r) (parse >r))
              ((a = "-o") && (two? r)) (: _ (opt <r) (parse >r))
              ((a = "-D") || (a = "-e")) (parse r)
              (a = "-q") (: _ (pin o 'quiet 1) (parse r))
              (die ("unknown argument " + a + "\n" + usage)))))
    _ (parse as)
    sys "/etc/ssh/ssh_host_ed25519_key"
    own (home + "/.ssh/sshd_ed25519_key")
    hkp (? (string? (o 'hk)) (o 'hk) (readable? sys) sys own)
    _ (? ((hkp = own) && !(readable? own))
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
) ; module ssh-cli
