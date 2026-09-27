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

; -- nslookup and ping --------------------------------------------------------------------
; nslookup against a nameserver that is a process of its own (the pty read holds this one):
; four queries, box.test's a and aaaa -- one address, then an empty yes -- and nosuch.test's
; two, both NXDOMAIN. it tells them apart by the first letter of the name and finds the
; type just past it. ping sends two echoes to loopback, where the kernel lets it, and ping6
; (and ping -6) to ::1 where the host has ipv6; then both again in a fresh user and network
; namespace: there ping_group_range shuts the echo socket and the namespace's root may open
; a raw one, the socket the bsds ping through.
(: K (cite 'kore)
   love <cmdline
   dir "out/.nettest"
   _ (hark ["rm" "-rf" dir]) _ (mkdir dir 493)
   nfile (dir + "/ns.l")
   _ (: p (open nfile "w")
        _ (say p "(borrow 'posix)
(borrow 'dns)
(: p (bind ['udp 7441])
   (b16 v) (dns-be16 v)
   (one _) (: d (recv p) q <>d
              nx (q 13 = 110) e (? nx 25 22) t (q e * 256 + q (e + 1))
              a (? (!nx && t = 1) [(string 192 + string 12 + b16 1 + b16 1 + b16 0 + b16 60 + b16 4
                                    + string 10 + string 1 + string 2 + string 3)] ())
              r (snip q 0 2 + b16 (? nx 33155 33152) + b16 1 + b16 #a + b16 0 + b16 0
                 + snip q 12 (e + 4) + catmap (x \\ x) a)
              _ (send p <d r) 0)
   _ (map one ^4)
   _ (rest 50)
   0)
")
        (close p))
   (waitfor pid) (: s (gather pid) (? (two? s) s (nom? s) s (: _ (rest 2) (waitfor pid))))
   (run args) (: r (tether (love . "kore" . args)) t (slurp >r) [t <(waitfor <r)])
   (has? t s) (0 <= (K 'wg-find) t s 0)
   srv (tether [love nfile])
   _ (rest 300)                                   ; its bind, before our queries
   a (run ["nslookup" "-port=7441" "box.test" "127.0.0.1"])
   b (run ["nslookup" "-port=7441" "nosuch.test" "127.0.0.1"])
   _ (slurp >srv) _ (waitfor <srv)
   c (run ["nslookup" "-type=bogus" "box.test"])
   _ (test (has? <a "Address:\t127.0.0.1:7441") (has? <a "Name:\tbox.test") (has? <a "Address: 10.1.2.3")
           !(has? <a "can't find") (a 1 = 0)
           (has? <b "** server can't find nosuch.test: NXDOMAIN") (b 1 = 1)
           (has? <c "nslookup: unknown option -type=bogus") (c 1 = 2))
   ; ping: two echoes and the summary, or the socket refused and said so
   ; two echoes to h and the summary, or the socket refused and said so
   (echoes r h) (? (has? <r " echo socket here") (test (r 1 = 2))
                   (test (has? <r ("PING " + h + " (" + h + "): 56 data bytes"))
                         (has? <r ("64 bytes from " + h + ": seq=1 ttl="))
                         (has? <r "2 packets transmitted, 2 packets received, 0% packet loss")
                         (has? <r "round-trip min/avg/max = ") (r 1 = 0)))
   v6? (: q (open "/proc/net/if_inet6" "r") (? (hot? q) (: _ (close q) 1) 0))
   _ (echoes (run ["ping" "-c" "2" "-i" "0.2" "127.0.0.1"]) "127.0.0.1")
   _ (? v6? (: _ (echoes (run ["ping6" "-c" "2" "-i" "0.2" "::1"]) "::1")
               (echoes (run ["ping" "-6" "-c" "2" "-i" "0.2" "::1"]) "::1")) 0)
   ; the raw sockets, where unshare and ip are there to make the namespace (99 when not)
   (inns cmd) (: r (tether ["/bin/sh" "-c" ("unshare -rn sh -c 'ip link set lo up' 2>/dev/null || exit 99; "
                                           + "exec unshare -rn sh -c 'ip link set lo up && exec " + love
                                           + " kore " + cmd + "'")])
                 t (slurp >r) [t <(waitfor <r)])
   rw (inns "ping -c 2 -i 0.2 127.0.0.1")
   _ (? (rw 1 = 99) 0
        (: _ (test (has? <rw "64 bytes from 127.0.0.1: seq=1 ttl=")
                   (has? <rw "2 packets transmitted, 2 packets received, 0% packet loss") (rw 1 = 0))
           (? v6? (: r6 (inns "ping6 -c 2 -i 0.2 ::1")
                     (test (has? <r6 "64 bytes from ::1: seq=1 ttl=")
                           (has? <r6 "2 packets transmitted, 2 packets received, 0% packet loss") (r6 1 = 0)))
              0)))
   u6 (run ["ping6" "-4" "::1"])
   _ (test (has? <u6 "ping6: unknown option -4") (u6 1 = 2))
   h (run ["ping" "-c" "x" "127.0.0.1"])
   ; -i and -W read seconds with up to three places; a time prints as ms to three
   (test (has? <h "ping: bad -c x") (h 1 = 2)
         ((K 'ping-ms) "1" = 1000) ((K 'ping-ms) "0.2" = 200) ((K 'ping-ms) "2.5" = 2500)
         ((K 'ping-ms) "x" = ()) ((K 'ping-t) 84000 = "0.084") ((K 'ping-t) 11331000 = "11.331")))

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
