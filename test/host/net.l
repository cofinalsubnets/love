; --- test/host/net.l: kore's telnet and httpd ---
; telnet's option talk byte by byte, then the whole client on a pty against a server task
; in this process: it agrees to the echo, goes to character mode, sends a key as typed and
; a return as CR LF, and leaves when the server closes. httpd is kiosko under busybox's
; flags: a page served off -h on -p, and the flags it will not half obey refused.
;   cat test/00-init.l test/host/net.l | out/love
(borrow 'posix)
(: K (cite 'kore)
   new (K 'tn-new) byte (K 'tn-byte) send (K 'tn-send)
   (feed st s) (: (go i sh rp) (? (#s <= i) [sh rp] (: r (byte st (s i)) (go (i + 1) (sh + <r) (rp + r 1))))
                  (go 0 "" ""))
   (iac v x) (string 255 + string v + string x)
   st (new 0)
   ; the server may echo and suppress go-ahead, and asking again answers nothing; any
   ; other offer is refused, and so is any request but go-ahead's
   _ (test (feed st (iac 251 1) = ["" (iac 253 1)]) ((K 'tn-echo?) st)
           (feed st (iac 251 1) = ["" ""])
           (feed st (iac 251 3) = ["" (iac 253 3)])
           (feed st (iac 251 5) = ["" (iac 254 5)])
           (feed st (iac 253 24) = ["" (iac 252 24)])
           (feed st (iac 253 3) = ["" (iac 251 3)]) (feed st (iac 253 3) = ["" ""])
           ; taking the echo back is acknowledged once; a refusal of what is off is not
           (feed st (iac 252 1) = ["" (iac 254 1)]) !((K 'tn-echo?) st)
           (feed st (iac 252 1) = ["" ""]) (feed st (iac 254 24) = ["" ""])
           (feed st (iac 254 3) = ["" (iac 252 3)])
           ; subnegotiation is skipped whole, an IAC IAC inside it too; data around it shows
           (feed st ("a" + string 255 + string 250 + "\x18\x01" + string 255 + string 255 + "z" + string 255 + string 240 + "b")
            = ["ab" ""])
           ; IAC IAC is a data 255, a command with no option is nothing, CR NUL is a CR
           (feed st ("x" + string 255 + string 255 + "y" + string 255 + string 241 + "\r\x00\r\n") = [("x" + string 255 + "y\r\r\n") ""]))
   ; the other way: a 255 doubled, return as CR LF in character mode, a line's 10 in line
   ; mode, and a stray 13 there dropped
   _ (test (send 255 0 = string 255 + string 255) (send 13 1 = "\r\n") (send 97 1 = "a")
           (send 10 0 = "\r\n") (send 13 0 = "") (send 97 0 = "a"))

   ; -- the client on a pty ----------------------------------------------------------
   ; the server is a process of its own: this one reads the pty, and a read there holds
   ; the whole process, so a server task beside it would never be run. it offers the
   ; echo, waits for it taken, greets, reads a line, answers it and closes, and leaves
   ; what it read in a file
   love <cmdline
   port 7436
   dir "out/.nettest"
   _ (hark ["rm" "-rf" dir]) _ (mkdir dir 493)
   sfile (dir + "/srv.l")
   _ (: p (open sfile "w")
        _ (say p ("(borrow 'posix)
(: l (listen " + show port + ") c (accept l) got (jug 0)
   (rd n) (? (n < 1) 0 (: b (see c) (? (b < 0) 0 (: _ (put got b) (rd (n - 1))))))
   (line _) (: b (see c) (? (b < 0) 0 (: _ (put got b) (? (b = 10) 0 (line 0)))))
   _ (say c (string 255 + string 251 + string 1)) _ (flush c)
   _ (rd 3)
   _ (say c \"hello\\r\\n\") _ (flush c)
   _ (line 0)
   _ (say c \"got it\\r\\n\") _ (flush c)
   _ (close c)
   q (open \"" + dir + "/got\" \"w\") _ (say q (slurp got)) _ (close q)
   0)
"))
        (close p))
   (waitfor pid) (: s (gather pid) (? (two? s) s (nom? s) s (: _ (rest 2) (waitfor pid))))
   srv (tether [love sfile])
   _ (rest 300)                                   ; its listen, before our connect
   r (tether [love "kore" "telnet" "127.0.0.1" (show port)])
   _ (test (two? r))
   m >r
   ; type only once the greeting is up: by then the echo is taken and the terminal raw
   ; what the pty has shown up to the first pat, or "" at its end
   (upto pat t) (: b (see m) (? (b < 0) ""
                                (: t2 (t + string b) (? (0 <= (K 'wg-find) t2 pat 0) t2 (upto pat t2)))))
   seen (upto "hello" "")
   _ (test (0 < #seen))
   _ (: _ (say m "x\r") (flush m))
   more (slurp m)
   txt (seen + more)
   st2 (waitfor <r)
   _ (slurp >srv)
   _ (waitfor <srv)
   got (: q (open (dir + "/got") "r") (? (hot? q) (: g (slurp q) _ (close q) g) ""))
   _ (test (got = (iac 253 1) + "x\r\n")
           (0 <= (K 'wg-find) txt "Connected to 127.0.0.1." 0)
           (0 <= (K 'wg-find) txt "got it" 0)
           (0 <= (K 'wg-find) txt "Connection closed by foreign host." 0)
           (<st2 = 0))
   ; nothing listening: a refusal and exit 1; a bad port is a usage error
   r2 (tether [love "kore" "telnet" "127.0.0.1" "1"])
   t2 (slurp >r2)
   _ (test (0 <= (K 'wg-find) t2 "telnet: cannot connect to 127.0.0.1 port 1" 0) (<(waitfor <r2) = 1))
   r3 (tether [love "kore" "telnet" "127.0.0.1" "http"])
   _ (test (0 <= (K 'wg-find) (slurp >r3) "telnet: not a port: http" 0) (<(waitfor <r3) = 2))
   0)

; -- httpd -------------------------------------------------------------------------------
(: K (cite 'kore)
   love <cmdline
   root "out/.httpd"
   _ (hark ["rm" "-rf" root]) _ (mkdir root 493)
   _ (: p (open (root + "/index.html") "w") _ (say p "<p>served</p>") (close p))
   (waitfor pid) (: s (gather pid) (? (two? s) s (nom? s) s (: _ (rest 2) (waitfor pid))))
   (run args) (: r (tether (love . "kore" . "httpd" . args)) t (slurp >r) [t <(waitfor <r)])
   ; the refusals, each by name and before any socket
   a (run ["-p" "127.0.0.1:8080" "-h" root])
   b (run ["-c" "/etc/httpd.conf"])
   c (run ["-h" (root + "/none")])
   d (run ["extra"])
   _ (test (0 <= (K 'wg-find) <a "-p takes a port, not 127.0.0.1:8080" 0) (a 1 = 2)
           (0 <= (K 'wg-find) <b "httpd: -c is not supported" 0) (b 1 = 2)
           (0 <= (K 'wg-find) <c "httpd: not a directory" 0) (c 1 = 1)
           (0 <= (K 'wg-find) <d "usage: httpd" 0) (d 1 = 2))
   ; a page off -h on -p, fetched by wget's round trip; -f taken, 0.0.0.0: and :PORT too
   port 7437
   (fetch _) ((K 'wg-once) 0 "127.0.0.1" port "/")
   (try k) (: r (fetch 0) (? (two? r) r (k < 1) r (: _ (rest 50) (try (k - 1)))))
   srv (tether [love "kore" "httpd" "-f" "-p" ("0.0.0.0:" + show port) "-h" root])
   g (try 100)
   _ (test (two? g) (<g = 200) (g 2 = "<p>served</p>"))
   _ (still <srv 15)
   _ (waitfor <srv)
   0)

(test_fin (), puts "net: ok", putc 10, 0)
