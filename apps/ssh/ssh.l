; apps/ssh/ssh.l -- ssh, the client: the module assembled, and the command over it.
;
;   ssh [-p port] [-i identity] [-l user] [-t | -T] [-o option=value] [user@]host [command ..]
;
; a command runs by exec, and without one a shell -- over a pty when stdin is a terminal,
; or as -t / -T say. the host key is held to known_hosts: a match goes on, a changed key
; stops, an unknown host is added and said (openssh's accept-new). -o takes
; UserKnownHostsFile and StrictHostKeyChecking=no, which skips the check. hashed
; known_hosts lines are HMAC-SHA1 and not read; such a host reads as unknown.
;
;   out/love apps/ssh/ssh.l user@host
(borrow "apps/tls/tls.l")
(borrow "apps/ssh/sha512.l")
(borrow "apps/ssh/ed25519.l")
(borrow "apps/ssh/aes.l")
(borrow "apps/ssh/bcrypt.l")
(borrow "apps/ssh/client.l")

(module (ssh-cli ssh-main)
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

(: s (cite 'verbs 'fire ["ssh" "ssh.l"])
   (two? s ? (ssh-main >s)))
) ; module ssh-cli
