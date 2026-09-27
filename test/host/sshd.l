; --- test/host/sshd.l: kore's sshd, served and logged into -------------------------------
; hermetic: the keys are written by the module's own ssh-keywrite, the server is a process of
; its own on a loopback port, and the client is kore's ssh on a pty (this process reads that
; pty, and a read there holds the process, so a server beside it here would never run).
; exec with stderr and a status, stdin to its eof, a pty the client's terminal sizes, and the
; refusals: an unknown key, another user. where openssh's client is installed it logs in
; too, which also holds our key files to what openssh will read.
;   cat test/00-init.l test/host/sshd.l | out/love
(borrow 'posix)
(borrow 'tls)
(borrow 'ssh)
(: love <cmdline
   dir ((cwd 0) + "/out/.sshdt")
   _ (hark ["rm" "-rf" dir]) _ (mkdir dir 448)
   me (ssh-me 0)
   user (me 0)
   port 7452
   (mk name) (: seed (rnd 32) pub (ed-pub seed) _ (ssh-keywrite (dir + "/" + name) seed pub name) [seed pub])
   hk (mk "host") id (mk "id") bad (mk "bad")
   ; the files read back as they were written, the private one closed to all but its owner
   _ (test ((ssh-key (dir + "/id") (\ _ ())) = id)
           ((: q (open (dir + "/id.pub") "r") l (slurp q) _ (close q) l) = ssh-publine (id 1) "id")
           ((((stat (dir + "/id")) 2) & 511) = 384))
   _ (: q (open (dir + "/ak") "w") _ (say q ("# a comment\nfrom=\"10.0.0.1\" " + ssh-publine (bad 1) "opt"
                                              + ssh-publine (id 1) "id")) (close q))
   _ (test ((ssh-authorized (dir + "/ak")) = [(id 1)]))
   (waitfor pid) (: s (gather pid) (? (two? s) s (nom? s) s (: _ (rest 2) (waitfor pid))))
   (has? t s) (0 <= ((cite 'kore 'wg-find) t s 0))
   srv (tether [love "kore" "sshd" "-p" (show port) "-h" (dir + "/host") "-o" ("AuthorizedKeysFile=" + dir + "/ak")])
   _ (rest 400)                                    ; its listen, before our connects
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
   _ (still <srv 15)
   log (slurp >srv)
   _ (waitfor <srv)
   (test (has? log "listening on port") (has? log ("accepted publickey for " + user))
         (has? log "connection closed: ")))

(test_fin (), puts "sshd: ok", putc 10, 0)
