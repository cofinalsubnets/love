; login -- a terminal's login: a name, its password checked against the shadow file, then the
; user's shell, dropped to the user and recorded in utmp and wtmp.
;   love login [-r ROOT] [TTY]   on TTY (else the terminal it is given), ROOT for /etc and /var
; it runs as root. the password is never in argv, a log or the environment; an unknown name
; costs a hash as a known one does; each failure waits longer, and five end the session
(module (login login-main login-usage login-who login-groups login-auth login-env login-utrec
         login-utmp login-id)
(borrow '(posix cli crypt bytes))
(:
 login-usage "usage: love login [-r ROOT] [TTY]"
 ; an account file as rows of fields
 (lg-rows root f) (uread (root + f) @ r
                    (two? r ? (map (split ":") (filter (l \ 0 < #l && !(l 0 = 35)) (lines <>r))) ()))
 (lg-num s) (: (go i n) (? (i = #s) n (48 <= s i <= 57) (go (i + 1) (n * 10 + s i - 48)) -1)
               (0 < #s ? (go 0 0) -1))
 (lg-find rows name) (: (go l) (? (atom? l) () (<<l = name) <l (go >l)) (go rows))
 ; [name uid gid gecos home shell hash] for name, the hash the shadow's (passwd's own when it
 ; holds one), or () for no such account
 (login-who root name)
  (lg-find (lg-rows root "/etc/passwd") name @ p
   (? (#p < 7) ()
      (: sh (lg-find (lg-rows root "/etc/shadow") name)
         h (p 1 = "x" ? (two? sh && 1 < #sh ? (sh 1) "!") (p 1))
         [(p 0) (lg-num (p 2)) (lg-num (p 3)) (p 4) (p 5) (0 < #(p 6) ? (p 6) "/bin/sh") h])))
 ; the gids: the account's own first, then each group naming it, once each
 (login-groups root name gid)
  (foldl (\ acc g (? (#g < 4) acc
                     (: id (lg-num (g 2))
                        (id < 0 || elem id acc || !(elem name (split "," (g 3))) ? acc (acc + [id])))))
         [gid] (lg-rows root "/etc/group"))
 ; the account when pw is its password, else (); every miss hashes, so a name's absence
 ; takes the time a wrong password does
 lg-decoy "$6$rounds=5000$loginloginlogin$"
 (login-auth root name pw)
  (: w (login-who root name)
     ok (two? w && 0 <= w 1 && 0 <= w 2 && crypt-check pw (w 6))
     _ (ok ? 0 (crypt-hash pw lg-decoy))
     (ok ? w ()))
 (login-env w term)
  [["HOME" (w 4)] ["SHELL" (w 5)] ["USER" (w 0)] ["LOGNAME" (w 0)] ["TERM" term]
   ["PATH" (w 1 = 0 ? "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
                      "/usr/local/bin:/usr/bin:/bin")]]
 ; glibc's 384-byte utmp record: type, pid, line, id, user, host, then the seconds at 340
 (lg-le v n) (string (map (i \ v >> (8 * i) & 255) ^n))
 (lg-pad s n) (: t (#s < n ? s (snip s 0 n)) (t + string (map (_ \ 0) ^(n - #t))))
 (login-id line) (: l (#line > 3 && snip line 0 3 = "tty" ? (snip line 3 #line) line)
                    (#l > 4 ? (snip l (#l - 4) #l) l))
 (login-utrec type pid line user host secs)
  (lg-le type 2 + lg-le 0 2 + lg-le pid 4 + lg-pad line 32 + lg-pad (login-id line) 4
   + lg-pad user 32 + lg-pad host 256 + lg-le 0 8 + lg-le secs 4 + lg-le 0 4 + lg-pad "" 36)
 ; utmp with rec in its line's slot (same id), else at its end
 (login-utmp old rec)
  (: id (snip rec 40 44)
     (go i) (? (#old < i + 384) (old + rec) (snip old (i + 40) (i + 44) = id) (snip old 0 i + rec + snip old (i + 384) #old)
               (go (i + 384)))
     (go 0))
 (lg-record root line user pid)
  (: rec (login-utrec 7 pid line user "" (clock 0 // 1000))
     ut (root + "/run/utmp")
     old (uread ut @ r (two? r ? <>r ""))
     _ (uwrite ut (login-utmp old rec))
     q (open (root + "/var/log/wtmp") "a")
     (hot? q ? (say q rec, close q) 0))
 ; a line off fd 0 after a prompt, echo off when asked; () at end of input
 (lg-ask prompt echo)
  (: _ (say out prompt, flush out)
     _ (echo ? 0 (ptyecho in 0))
     l (chug in)
     _ (echo ? 0 (ptyecho in 1, say out "\n", flush out))
     (? !(string? l) () (0 < #l && l (#l - 1) = 10) (snip l 0 (#l - 1)) l))
 (lg-host _) (uname 0 @ u (two? u && 1 < #u ? (u 1) "localhost"))
 ; the session: the terminal the user's, the ids dropped, the shell exec'd as a login shell
 (lg-start root w line)
  (: tty (line = "" ? "" ("/dev/" + line))
     _ (lg-record root line (w 0) (getpid 0))
     _ (tty = "" ? 0 (chown tty (w 1) (w 2), chmod tty 400))
     e (setids (w 1) (w 2) (login-groups root (w 0) (w 2)))
     _ (nom? e ? (udie 1 ("login: cannot become " + w 0 + ": " + show e)) 0)
     _ (nom? (chdir (w 4)) ? (chdir "/") 0)
     _ (each (login-env w (getenv "TERM" @ t (string? t ? t "linux"))) (kv \ setenv (kv 0) (kv 1)))
     base (rev (split "/" (w 5)) @ (b . _) b _ "sh")
     (exec [((w 5) . ("-" + base))]))
 (lg-tries root line n)
  (? (n = 5) (uleave 1)
     (: name (lg-ask (lg-host 0 + " login: ") 1)
        _ (string? name ? 0 (uleave 0))
        pw (lg-ask "Password: " 0)
        w (0 < #name && string? pw ? (login-auth root name pw) ())
        (two? w ? (lg-start root w line)
           (: _ (rest (2000 << n)) _ (say out "Login incorrect\n\n", flush out) (lg-tries root line (n + 1))))))
 ; a tty argument becomes fds 0 1 2 and the controlling terminal
 (lg-take tty) (: fd (openfd tty 2)
                  _ (charm? fd ? 0 (udie 1 ("login: " + tty + ": " + show fd)))
                  (dup2 fd 0, dup2 fd 1, dup2 fd 2, setsid 1))
 (login-main as)
  (: (go as root tty) (? (atom? as) [root tty]
                         (<as = "-r" && two? >as) (go >>as <>as tty)
                         (two? >as || (0 < #<as && <as 0 = 45)) (udie 2 login-usage)
                         (go >as root <as))
     rt (go as "" "")
     tty (rt 1 = "" || rt 1 0 = 47 ? (rt 1) ("/dev/" + rt 1))
     _ (tty = "" ? 0 (lg-take tty))
     line (tty = "" ? "" (snip tty 5 #tty))
     (lg-tries (rt 0) line 0))
 _ (pins (cite 'verbs 'tab) 'login (udoor 'login login-main login-usage 1 1)))
) ; module login
