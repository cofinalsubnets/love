; --- test/host/sshd.l: kore's sshd, served and logged into -------------------------------
; hermetic: the keys are written by the module's own ssh-keywrite, the server is a process of
; its own on a loopback port, and the client is kore's ssh on a pty (this process reads that
; pty, and a read there holds the process, so a server beside it here would never run).
; exec with stderr and a status, stdin to its eof, a pty the client's terminal sizes, and the
; refusals: an unknown key, another user. where openssh's client is installed it logs in
; too, which also holds our key files to what openssh will read. then scp both ways, the
; server's PATH finding love as `scp`, so both ends of the protocol are ours; openssh's
; scp -O against our remote end where it is installed.
;   cat test/00-init.l test/host/sshd.l | out/love
(borrow 'posix)
(borrow 'tls)
(borrow 'ssh)
(: love <cmdline
   dir ((cwd 0) + "/out/.sshdt")
   _ (hark ["rm" "-rf" dir]) _ (mkdir dir 448)
   me (ssh-me 0)
   user (me 0)
   port (test-free 0)
   (mk name) (: seed (rnd 32) pub (ed-pub seed) _ (ssh-keywrite (dir + "/" + name) seed pub name) [seed pub])
   hk (mk "host") id (mk "id") bad (mk "bad")
   ; the files read back as they were written, the private one closed to all but its owner
   _ (test ((ssh-key (dir + "/id") (\ _ ())) = id)
           ((: q (open (dir + "/id.pub") "r") l (slurp q) _ (close q) l) = ssh-publine (id 1) "id")
           (((stat (dir + "/id") 2) & 511) = 384))
   _ (: q (open (dir + "/ak") "w") _ (say q ("# a comment\nfrom=\"10.0.0.1\" " + ssh-publine (bad 1) "opt"
                                              + ssh-publine (id 1) "id")) (close q))
   _ (test ((ssh-authorized (dir + "/ak")) = [(id 1)]))
   (waitfor pid) (: s (gather pid) (? (two? s) s (nom? s) s (: _ (rest 2) (waitfor pid))))
   (has? t s) (0 <= (cite 'kore 'wg-find t s 0))
   ; the server's sessions find love as scp at the head of the PATH it inherits, and a
   ; hostile scp for the three evil-* names: a name not asked for, setuid bits, a planted tree
   _ (mkdir (dir + "/bin") 448)
   _ (: q (open (dir + "/bin/scp") "w")
        _ (say q ("#!/bin/sh\ncase \"$*\" in\n"
                  + " *evil-name) printf 'C0644 6 .bashrc\\nhello\\n\\000' ;;\n"
                  + " *evil-mode) printf 'C6777 6 evil-mode\\nhello\\n\\000' ;;\n"
                  + " *evil-tree) printf 'D0700 0 .ssh\\nC0600 3 authorized_keys\\nhi\\n\\000E\\n' ;;\n"
                  + " *) exec " + (love 0 = 47 ? love (cwd 0 + "/" + love)) + " kore scp \"$@\" ;;\nesac\n"))
        (close q))
   _ (chmod (dir + "/bin/scp") 493)
   path0 (getenv "PATH")
   _ (setenv "PATH" (dir + "/bin:" + path0))
   srv (tether [love "kore" "sshd" "-p" (show port) "-h" (dir + "/host") "-o" ("AuthorizedKeysFile=" + dir + "/ak")])
   _ (setenv "PATH" path0)
   _ (test-up port)                                ; its listen, before our connects
   (ssh key args) (tether (love . "kore" . "ssh" . "-p" . show port . "-i" . (dir + "/" + key)
                                . "-o" . "StrictHostKeyChecking=no" . args))
   (run key args) (: r (ssh key args) t (slurp >r) [t <(waitfor <r)])
   ; exec: stdout and stderr both reach the pty, the status comes home
   a (run "id" ["-T" (user + "@127.0.0.1") "echo out-$((6*7)); echo err >&2; exit 3"])
   _ (test (has? <a "out-42") (has? <a "err") (a 1 = 3))
   ; stdin to eof: a ^D on the client's terminal is the channel's eof, cat's stdin closed
   b (: r (ssh "id" ["-T" (user + "@127.0.0.1") "cat; echo done"])
        _ (rest 300) _ (say >r "piped\n\x04") _ (flush >r)
        t (slurp >r) [t <(waitfor <r)])
   _ (test (has? <b "piped") (has? <b "done") (b 1 = 0))
   ; a pty, sized as the client's own terminal is
   c (: r (ssh "id" ["-t" (user + "@127.0.0.1") "tty; stty size"])
        _ (settty >r 30 100)
        t (slurp >r) [t <(waitfor <r)])
   _ (test (has? <c "/dev/pts/") (has? <c "30 100") (c 1 = 0))
   ; a pty's TERM is its own session's: the client's xterm-test reaches the pty session,
   ; and a pipe session after it does not find it in the server's environment
   tt (: r (tetherenv (love . "kore" . "ssh" . "-p" . show port . "-i" . (dir + "/id")
                            . "-o" . "StrictHostKeyChecking=no" . ["-t" (user + "@127.0.0.1") "echo \"<$TERM>\""])
                      ["TERM=xterm-test"])
         t (slurp >r) [t <(waitfor <r)])
   tp (run "id" ["-T" (user + "@127.0.0.1") "echo \"[$TERM]\""])
   _ (test (has? <tt "<xterm-test>") (tt 1 = 0) (has? <tp "[") !(has? <tp "xterm-test") (tp 1 = 0))
   ; tetherenv sets each K=V in the child alone; () inherits, and what is not K=V is a misuse
   _ (setenv "FOO" "parent")
   (echofoo env) (: r (tetherenv ["sh" "-c" "echo \"<$FOO>\""] env) t (slurp >r) [t <(waitfor <r)])
   f1 (echofoo ["FOO=bar" "BAZ=1"])
   f2 (echofoo ())
   _ (test (has? <f1 "<bar>") (f1 1 = 0) (has? <f2 "<parent>") ((getenv "FOO") = "parent")
           ('badarg = tetherenv ["true"] ["NOEQ"]) ('badarg = tetherenv ["true"] ["=x"])
           ('badarg = tetherenv ["true"] "FOO=bar") ('badarg = tetherenv ["true"] ["FOO=b\0ar"]))
   ; the refusals
   d (run "bad" ["-T" (user + "@127.0.0.1") "true"])
   e (run "id" ["-T" "nobody-here@127.0.0.1" "true"])
   _ (test (has? <d "permission denied") (d 1 = 255) (has? <e "permission denied") (e 1 = 255))
   ; openssh's client, where there is one
   o (: q (open "/usr/bin/ssh" "r") (? (hot? q) (: _ (close q) 1) 0))
   _ (? o (: r (tether ["ssh" "-F" "/dev/null" "-o" "StrictHostKeyChecking=no" "-o" "UserKnownHostsFile=/dev/null"
                        "-o" "IdentitiesOnly=yes" "-o" "BatchMode=yes" "-o" "LogLevel=ERROR"
                        "-i" (dir + "/id") "-p" (show port) (user + "@127.0.0.1") "echo openssh-$((6*7)); exit 5"])
             t (slurp >r) st <(waitfor <r)
             (test (has? t "openssh-42") (st = 5)))
        0)
   ; scp: a file up keeping its mtime, a tree down, a missing file said, a refused target said
   (put p s) (: q (open p "w") _ (say q s) (close q))
   (got p) (: q (open p "r") (? (hot? q) (: s (slurp q) _ (close q) s) ()))
   blob (bytes 70000 (i \ (i * 7 + i // 256) & 255))
   _ (map (d \ mkdir (dir + d) 448) ["/src" "/src/sub" "/up" "/down" "/o"])
   _ (put (dir + "/src/f1") "hello\n") _ (put (dir + "/src/sub/blob") blob)
   _ (utime (dir + "/src/f1") 981158400000)
   (scp args) (: r (tether (love . "kore" . "scp" . "-P" . show port . "-i" . (dir + "/id")
                             . "-o" . "StrictHostKeyChecking=no" . args))
                 t (slurp >r) [t <(waitfor <r)])
   far (user + "@127.0.0.1:")
   s1 (scp ["-p" (dir + "/src/f1") (far + dir + "/up/")])
   s2 (scp ["-r" (far + dir + "/src") (dir + "/down/")])
   s3 (scp [(far + dir + "/src/nope") (dir + "/down/")])
   _ (mkdir (dir + "/up2") 448) _ (mkdir (dir + "/up2/f1") 448)
   s4 (scp [(dir + "/src/f1") (dir + "/src/sub/blob") (far + dir + "/up2/")])
   _ (test (s1 1 = 0) ((got (dir + "/up/f1")) = "hello\n") ((stat (dir + "/up/f1") 1) = 981158400000)
           (s2 1 = 0) ((got (dir + "/down/src/f1")) = "hello\n") ((got (dir + "/down/src/sub/blob")) = blob)
           (s3 1 = 1) (has? <s3 "nope") (s4 1 = 1) (has? <s4 "scp: ") ((got (dir + "/up2/blob")) = blob))
   ; the hostile server: a name not asked for is refused, a mode loses setuid, setgid and
   ; the umask's bits, and a directory not asked for is not made
   _ (mkdir (dir + "/ev") 448)
   um (: u (umask 18) _ (umask u) u)
   e1 (scp [(far + dir + "/src/evil-name") (dir + "/ev/")])
   e2 (scp [(far + dir + "/src/evil-mode") (dir + "/ev/")])
   e3 (scp ["-r" (far + dir + "/src/evil-tree") (dir + "/ev/")])
   _ (test (e1 1 = 1) (atom? (stat (dir + "/ev/.bashrc")))
           ((got (dir + "/ev/evil-mode")) = "hello\n")
           ((stat (dir + "/ev/evil-mode") 2 & 4095) = (511 & (511 ^ um)))
           (e3 1 = 1) (atom? (stat (dir + "/ev/.ssh"))))
   _ (? o (: r (tether ["scp" "-O" "-F" "/dev/null" "-o" "StrictHostKeyChecking=no" "-o" "UserKnownHostsFile=/dev/null"
                        "-o" "IdentitiesOnly=yes" "-o" "BatchMode=yes" "-o" "LogLevel=ERROR"
                        "-i" (dir + "/id") "-P" (show port) "-r" (dir + "/src") (far + dir + "/o/")])
             _ (slurp >r) st <(waitfor <r)
             (test (st = 0) ((got (dir + "/o/src/sub/blob")) = blob)))
        0)
   ; --- pre-auth amplification: an oversized packet or an overlong version line is
   ; dropped without buffering (rfc 4253 6.1 and 4.2), and a good login still follows ---
   (eaten c) (: _ (await c) b (see c) (b = -1 ? 1 (chug c, eaten c)))   ; 1 once the server closes us
   big (bytes 4 (i \ i = 0 ? 127 255))                                  ; a claimed packet length of 0x7fffffff
   over (: c (connect ['tcp "127.0.0.1" port])
            _ (say c ("SSH-2.0-probe\r\n" + big + bytes 4096 (\ 65))) _ (flush c)
            r (eaten c) _ (close c) r)
   long (: c (connect ['tcp "127.0.0.1" port])
            _ (say c (bytes 512 (\ 88))) _ (flush c)                    ; 512 bytes, no crlf: past the 255 cap
            r (eaten c) _ (close c) r)
   z (run "id" ["-T" (user + "@127.0.0.1") "echo alive-$((6*7))"])
   _ (test over long (has? <z "alive-42") (z 1 = 0))
   _ (still <srv 15)
   log (slurp >srv)
   _ (waitfor <srv)
   (test (has? log "listening on port") (has? log ("accepted publickey for " + user))
         (has? log "connection closed: ")))

(test_fin (), puts "sshd: ok", putc 10, 0)
