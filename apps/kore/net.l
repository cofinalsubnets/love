; apps/kore/net.l -- telnet, telnetd, httpd, nslookup, ping and ping6: network tools over
; doors the tree already has (love/sock.c's connect/listen/bind, apps/dns.l, kiosko).
;
;   telnet HOST [PORT]                a remote terminal over tcp, port 23 by default
;   telnetd [-FK] [-p PORT] [-b ADDR[:PORT]] [-l LOGIN] [-f ISSUE]   its server
;   httpd [-fv] [-p PORT] [-h DIR]    kiosko under busybox's name and flags
;   nslookup [-type=T] HOST [SERVER]  a name's records, asked of a nameserver directly
;   ping [-46q] [-c N] [-i S] [-W S] [-s N] HOST  icmp echoes and their round trips
;   ping6 [-q] [-c N] [-i S] [-W S] [-s N] HOST   the same over ipv6 (ping -6)
;   traceroute [-46nI] [-f F] [-m M] [-q N] [-w S] HOST   the routers on the way (traceroute6)
;
; telnet is nc (apps/ain.l) with the protocol's options answered (RFC 854, 855): it lets the
; server echo and suppress go-ahead, offers to suppress go-ahead itself, refuses every other
; option either way, and skips subnegotiation. on a terminal it follows the server's echo:
; while the server echoes, the terminal is raw and each key goes as it is typed (character
; mode); otherwise the terminal's own line editing holds a line until return (line mode).
; a line ends CR LF on the wire, and a data byte 255 goes doubled. ^] closes the connection.
; stdin not a terminal: its lines are sent, and its end half-closes the connection and waits
; for the server to close.
;
; httpd is kiosko (apps/kiosko/kiosko.l) under busybox's name: -p PORT (80 by default),
; -h DIR (. by default), -v logs each request, and -f is taken and always true -- it never
; detaches. kiosko listens on every address, so -p IP:PORT is refused rather than half
; obeyed, and so is the rest of busybox's set (-c -u -r -m -e -d -i), by name.
;
; nslookup asks the first nameserver in /etc/resolv.conf that answers (or SERVER, a quad or
; a name, on -port or 53), with no hosts file and no search domains -- what it says, as busybox's
; nslookup prints it. with no -type it asks A and AAAA; a dotted quad asks its PTR. the
; query offers EDNS0's 1232 bytes, so a long answer arrives whole; one that still does not
; fit is said to be cut. a name that does not exist is exit 1.
;
; ping sends an icmp echo every -i seconds (1), -c times or until ^C, and prints each
; reply's round trip and ttl, then the loss and min/avg/max. it rides linux's unprivileged
; echo socket, open to the groups in net.ipv4.ping_group_range, or else a raw one, which is
; root's (the bsds have only that); where both refuse, it says so. no reply at all is exit
; 1, as busybox's. ping6 is the same over icmp6, its ttl the hop limit; ping takes it for
; -6 or an address with a colon in it.
(module 'kore
(borrow 'cli)
(borrow 'posix)

(:
   tn-usage "usage: telnet HOST [PORT]"
   httpd-usage "usage: httpd [-fv] [-p PORT] [-h DIR]"
   ns-usage "usage: nslookup [-type=A|AAAA|CNAME|MX|NS|PTR|SOA|TXT] [-port=N] HOST [SERVER]"
   ping-usage "usage: ping [-46q] [-c COUNT] [-i SECS] [-W SECS] [-s SIZE] HOST"
   ping6-usage "usage: ping6 [-q] [-c COUNT] [-i SECS] [-W SECS] [-s SIZE] HOST"
   ns-types '(("a" 1) ("aaaa" 28) ("cname" 5) ("mx" 15) ("ns" 2) ("ptr" 12) ("soa" 6) ("txt" 16))
   ns-rcodes '((1 "FORMERR") (2 "SERVFAIL") (3 "NXDOMAIN") (4 "NOTIMP") (5 "REFUSED"))

   ; -- telnet: the option talk -------------------------------------------------------
   ; the state of one connection: 'm is where the next byte falls -- 0 data, 1 past IAC,
   ; 2 past IAC and a verb ('v), 3 inside SB, 4 past IAC inside SB. 'him and 'us are the
   ; options in force at each end, 'cr a CR just shown (a NUL after it is part of it), and
   ; 'raw whether the terminal is in character mode
   (tn-new _) (: st (tablet 0) _ (pins st 'm 0 'v 0 'him () 'us () 'cr 0 'raw 0) st)
   (tn-cmd v x) (string 255 + string v + string x)
   (tn-echo? st) (elem 1 (st 'him))
   ; one byte off the wire -> [shown reply]: the text for the screen and the bytes owed
   ; back to the server, either ""
   (tn-byte st c)
    (: m (st 'm)
       (? (m = 0)
           (? (c = 255) (pin st 'm 1, ["" ""])
              (c = 0 && st 'cr) (pin st 'cr 0, ["" ""])
              (pin st 'cr (c = 13), [(string c) ""]))
          (m = 1)
           (? (c = 255) (pins st 'm 0 'cr 0, [(string 255) ""])
              (251 <= c <= 254) (pins st 'm 2 'v c, ["" ""])
              (c = 250) (pin st 'm 3, ["" ""])
              (pin st 'm 0, ["" ""]))                 ; NOP, GA, AYT..: nothing to show
          (m = 2) (pin st 'm 0, ["" (tn-opt st (st 'v) c)])
          (m = 3) ((? (c = 255) (pin st 'm 4) 0), ["" ""])
          (pin st 'm (? (c = 240) 0 3), ["" ""])))   ; SE ends it; anything else stays in
   ; a verb about option x -> the reply owed. the server may echo (1) and suppress go-ahead
   ; (3), we suppress go-ahead, and everything else is refused. a request for what is
   ; already on, or a refusal of what is already off, answers nothing: that is what keeps
   ; two agreeable ends from acknowledging each other forever
   (tn-opt st v x)
    (: him (st 'him) us (st 'us)
       (? (v = 251) (? (elem x him) ""
                       (elem x '(1 3)) (pin st 'him (x . him), tn-cmd 253 x)
                       (tn-cmd 254 x))
          (v = 252) (? (elem x him) (pin st 'him (filter (y \ y != x) him), tn-cmd 254 x) "")
          (v = 253) (? (elem x us) ""
                       (x = 3) (pin st 'us (x . us), tn-cmd 251 x)
                       (tn-cmd 252 x))
          (? (elem x us) (pin st 'us (filter (y \ y != x) us), tn-cmd 252 x) "")))
   ; one typed byte -> the wire. in character mode return is 13 and ends a line; in line
   ; mode the terminal hands a line ending 10, and a 13 is a stray from a CR LF file
   (tn-send c raw?)
    (? (c = 255) (string 255 + string 255)
       raw? (? (c = 13) "\r\n" (string c))
       (c = 10) "\r\n" (c = 13) "" (string c))

   ; -- telnet: the face ---------------------------------------------------------------
   (telnet-main as)
    (: _ (? (0 < #as < 3) 0 (udie 2 tn-usage))
       _ (: w (uoptstray as as) (? !w 0 (udie 2 ("telnet: unknown option " + w))))
       host <as
       port (? (two? >as) (: n (unum <>as) (? (charm? n && 0 < n < 65536) n (udie 2 ("telnet: not a port: " + <>as)))) 23)
       _ (say err ("Trying " + host + "...\n"), flush err)
       s ((cite 'dns 'dial) host port)
       _ (? s 0 (udie 1 ("telnet: cannot connect to " + host + " port " + show port)))
       _ (say err ("Connected to " + host + ".\nEscape character is '^]'.\n"), flush err)
       tty? (two? (tty 0))
       st (tn-new 0)
       ; the terminal in step with the server's echo: raw while it echoes
       (mode _) (: r (tn-echo? st) (? (tty? && r != st 'raw) (raw r, pin st 'raw r) 0))
       ; the server's side, in its own task: shown, answered, and at its close the end of
       ; the program -- the other task is parked on a key that may never come
       (down _)
        (: c (see s)
           (? (c < 0) ((? tty? (raw 0) 0), flush out, say err "Connection closed by foreign host.\n", flush err, quit 0)
              (: r (tn-byte st c)
                 _ (? #<r (say out <r, flush out) 0)
                 _ (? #(r 1) (say s (r 1), flush s) 0)
                 _ (mode 0)
                 (down 0))))
       d (twirl down 0)
       (up _)
        (: c (see in)
           (? (c < 0) (seal s 1, catch d, 0)      ; stdin done: half-close, drain
              (c = 29) ((? tty? (raw 0) 0), say err "\nConnection closed.\n", close s, 0)
              (say s (tn-send c (st 'raw)), flush s, up 0)))
       (up 0))

   ; -- telnetd ------------------------------------------------------------------------
   ; busybox's: each connection a program on a pty, /bin/login unless -l names another.
   ; the server offers to echo and suppress go-ahead and asks the window size (NAWS), which
   ; the pty follows; every other option is refused. the state of one connection's input:
   ; 'm 0 data, 1 past IAC, 2 past a verb ('v), 3 inside SB (its bytes in 'sb), 4 past IAC
   ; inside SB; 'cr a CR just passed, whose LF or NUL is part of it
   td-usage "usage: telnetd [-FK] [-p PORT] [-b ADDR[:PORT]] [-l LOGIN] [-f ISSUE]"
   td-offer (tn-cmd 251 1 + tn-cmd 251 3 + tn-cmd 253 31)
   (td-new _) (: st (tablet 0) _ (pins st 'm 0 'v 0 'cr 0 'sb "") st)
   ; the client's verb about option x -> the reply owed: its will of NAWS or go-ahead and its
   ; do of echo or go-ahead are what we asked or offered, and a won't or don't needs none
   (td-opt v x) (? (v = 251 && !(x = 31) && !(x = 3)) (tn-cmd 254 x)
                   (v = 253 && !(x = 1) && !(x = 3)) (tn-cmd 252 x)
                   "")
   ; NAWS's width and height, two bytes each, onto the pty
   (td-sb b pty) (? (#b = 5 && (b 0 = 31) && !!pty) (settty pty (b 3 * 256 + b 4) (b 1 * 256 + b 2)) 0)
   ; one byte off the wire -> [bytes for the pty, the reply owed]
   (td-byte st c pty)
    (: m (st 'm)
       (? (m = 0)
           (? (c = 255) (pin st 'm 1, ["" ""])
              ((st 'cr) = 1 && (c = 10 || c = 0)) (pin st 'cr 0, ["" ""])
              (pin st 'cr (? (c = 13) 1 0), [(string c) ""]))
          (m = 1)
           (? (c = 255) (pins st 'm 0 'cr 0, [(string 255) ""])
              (251 <= c <= 254) (pins st 'm 2 'v c, ["" ""])
              (c = 250) (pins st 'm 3 'sb "", ["" ""])
              (pin st 'm 0, ["" ""]))
          (m = 2) (pin st 'm 0, ["" (td-opt (st 'v) c)])
          (m = 3) ((? (c = 255) (pin st 'm 4) (pin st 'sb (st 'sb + string c))), ["" ""])
          ((? (c = 240) (pin st 'm 0, td-sb (st 'sb) pty)
                  (c = 255) (pins st 'm 3 'sb (st 'sb + string 255))
                  (pin st 'm 3)), ["" ""])))
   ; a chunk off the wire -> [bytes for the pty, the replies owed]
   (td-chunk st s pty)
    (: (go i d r) (? (#s <= i) [d r] (: x (td-byte st (s i) pty) (go (i + 1) (d + <x) (r + x 1))))
       (go 0 "" ""))
   ; the pty's bytes for the wire: a 255 doubled
   (td-esc s) (? (wg-find s (string 255) 0 < 0) s
                 ((: (go i a) (? (#s <= i) a (go (i + 1) (a + (? (s i = 255) (string 255 + string 255) (string (s i)))))))
                  0 ""))
   ; one connection: the program's output to the client in this task, the client's bytes
   ; to the program in another; the program's end is the session's, and the client's going
   ; hangs the program up
   (td-session c argv issue)
    (: _ (setenv "TERM" "xterm")
       r (tether argv)
       (? (atom? r) (say c ("telnetd: cannot run " + <argv + " (" + show r + ")\r\n"), flush c)
          (: pid <r m >r st (td-new 0)
             _ (say c (td-offer + issue)) _ (flush c)
             (up _) (: ch (see c)
                       (? (ch = -1) (still pid 1)
                          (: _ (unsee c ch) x (td-chunk st (chug c) m)
                             _ (? (0 < #<x) (say m <x, flush m) 0)
                             _ (? (0 < #(x 1)) (say c (x 1), flush c) 0)
                             (up 0))))
             u (twirl (_ \ trap up 0 (\ a b (still pid 1))) 0)
             (down _) (: _ (await m) ch (see m)
                         (? (ch = -1) 0
                            (unsee m ch, say c (td-esc (chug m)), flush c, down 0)))
             _ (trap down 0 (\ a b 0))
             _ (freeze u)
             _ (close m)
             (wait pid))))
   (td-loop l argv issue)
    (: _ (await l)
       c (accept l)
       _ ((: (g _) (? (two? (scoop 0)) (g 0) 0)) 0)
       _ (? (hot? c) (twirl (_ \ (trap (c \ (td-session c argv issue)) c (\ a b 0), close c)) ()) 0)
       (td-loop l argv issue))
   (telnetd-main as)
    (: t (tablet 0)
       o (uopt as t '(112 98 108 102 119) () ())
       _ (? (two? o) 0 (udie 2 td-usage))
       _ (: u (uoptun t '(112 98 108 102 70 75))
            (? !u 0 (udie 2 ("telnetd: -" + string u + " is not supported\n" + td-usage))))
       _ (? (two? (o 2)) (udie 2 td-usage) 0)
       login (: l (uoptv t 108) (? (string? l) l "/bin/login"))
       (portof s) (: n (unum s) (? (charm? n && 0 < n < 65536) n (udie 2 ("telnetd: not a port: " + s))))
       ; -b ADDR[:PORT], a quad; -p PORT
       bv (uoptv t 98)
       bk (? (string? bv) ((: (g i) (? (#bv <= i) -1 (bv i = 58) i (g (i + 1)))) 0) -1)
       addr (? (string? bv) (? (bk < 0) bv (snip bv 0 bk)) ())
       _ (? !addr 0 (two? ((cite 'dns 'dns-quad) addr)) 0 (udie 2 ("telnetd: -b takes a dotted quad, not " + addr)))
       pv (uoptv t 112)
       port (? (string? pv) (portof pv) (0 <= bk) (portof (snip bv (bk + 1) #bv)) 23)
       l (? !addr (listen port) (listen ['tcp addr port]))
       _ (? (hot? l) 0 (udie 1 ("telnetd: cannot listen on port " + show port + " (" + show l + ")")))
       _ (? (login = "/bin/login") 0
            (say err ("telnetd: no login: whoever reaches port " + show port + " runs " + login + "\n"), flush err))
       ip (: f (uoptv t 102) (? (string? f) f "/etc/issue.net"))
       issue (: q (open ip "r")
                (? (hot? q) (: s (slurp q) _ (close q)
                                ((: (go i a) (? (#s <= i) a (go (i + 1) (a + (? (s i = 10) "\r\n" (string (s i)))))))
                                 0 ""))
                   ""))
       (td-loop l [login] issue))

   ; -- nslookup -----------------------------------------------------------------------
   (ns-assoc k l) ((: (g l) (? (atom? l) () (<<l = k) <><l (g >l))) l)
   ; a record as busybox's nslookup lays it
   (ns-line x)
    (: nm <x t (x 1) v (x 2)
       (? (t = 1 || t = 28) ("Name:\t" + nm + "\nAddress: " + v)
          (t = 5) (nm + "\tcanonical name = " + v)
          (t = 2) (nm + "\tnameserver = " + v)
          (t = 15) (nm + "\tmail exchanger = " + v)
          (t = 16) (nm + "\ttext = " + v)
          (t = 12) (nm + "\tname = " + v)
          (t = 6) (nm + v)
          (nm + "\t" + v)))
   ; a dotted quad's reverse name, in-addr.arpa's
   (ns-rev q) (: a (<((cite 'dns 'dns-quad) q)) (o k) (show (a >> k & 255))
                 (o 0 + "." + o 8 + "." + o 16 + "." + o 24 + ".in-addr.arpa"))
   (nslookup-main as)
    (: D (cite 'dns)
       fl (filter (w \ 1 < #w && w 0 = 45) as)
       ops (filter (w \ !(1 < #w && w 0 = 45)) as)
       _ (? (0 < #ops < 3) 0 (udie 2 ns-usage))
       ; -type=T (or -query=T) and -port=N, each NAME=VALUE; anything else is refused by name
       (bad w) (udie 2 ("nslookup: unknown option " + w + "\n" + ns-usage))
       kvs (map (w \ (: k ((: (g i) (? (#w <= i) -1 (w i = 61) i (g (i + 1)))) 0)
                        (? (k < 0) (bad w) [(snip w 1 k) (snip w (k + 1) #w) w])))
                fl)
       tys (map (x \ (: t (ns-assoc (wg-lower (x 1)) ns-types) (? !t (bad (x 2)) t)))
                (filter (x \ <x = "type" || <x = "query") kvs))
       port (: ps (filter (x \ <x = "port") kvs)
               (? (atom? ps) 53 (: n (unum ((last ps) 1)) (? (charm? n && 0 < n < 65536) n (bad ((last ps) 2))))))
       _ (map (x \ ? (elem <x '("type" "query" "port")) 0 (bad (x 2))) kvs)
       host <ops
       quad? (two? ((D 'dns-quad) host))
       ; what is asked: the flag's type, else a quad's PTR, else A and AAAA
       ask (? (two? tys) [(last tys)] quad? [12] [1 28])
       qname (? (quad? && elem 12 ask) (ns-rev host) host)
       ; the servers: SERVER as a quad or a name, else resolv.conf's in order
       sv (? (two? >ops)
              (: a (? (two? ((D 'dns-quad) <>ops)) ((D 'dns-quad) <>ops) ((D 'resolve) <>ops))
                 (? (two? a) [(<a . port)] (udie 1 ("nslookup: can't resolve server " + <>ops))))
              (map (s \ <s . port) ((D 'dns-servers) "/etc/resolv.conf")))
       ; one type asked of the servers in turn -> [server records-answer], or () from none
       (one t l) (? (atom? l) ()
                    (: id ((D 'dns-id) 0) s <l
                       r ((D 'dns-raw) <s >s ((D 'dns-qedns) id qname t) 2500)
                       (? (string? r) [s ((D 'dns-records) r id)] (one t >l))))
       rs (map (t \ one t sv) ask)
       got (filter two? rs)
       _ (? (atom? got) (udie 1 ";; connection timed out; no servers could be reached") 0)
       s <(<got)
       _ (say out ("Server:\t\t" + (D 'dns-show) <s + "\nAddress:\t" + (D 'dns-show) <s + ":" + show >s + "\n\n"))
       ; each type's answer: its records under the heading, or the server's no
       (show1 a)
        (? (a = 'torn) (say out ("*** the answer for " + qname + " did not fit and was cut\n\n"), 0)
           (atom? a) 0
           (: rc <a
              (? (0 < rc) (say out ("** server can't find " + qname + ": "
                                          + (: m (ns-assoc rc ns-rcodes) (? (string? m) m ("rcode " + show rc))) + "\n\n"), 1)
                 (atom? (a 2)) 0
                 ((? (a 1) 0 (say out "Non-authoritative answer:\n")), map (x \ say out (ns-line x + "\n")) (a 2), say out "\n", 2))))
       marks (map (r \ ? (two? r) (show1 (r 1)) 0) rs)
       _ (flush out)
       (? (elem 2 marks) 0
          (elem 1 marks) 1
          (say out ("*** Can't find " + qname + ": No answer\n\n"), flush out, 0)))

   ; -- ping ---------------------------------------------------------------------------
   ; "1", "0.2", "2.5" seconds -> ms, or () for anything else
   (ping-ms s)
    (: k ((: (g i) (? (#s <= i) -1 (s i = 46) i (g (i + 1)))) 0)
       w (unum (? (k < 0) s (snip s 0 k)))
       f (? (k < 0) "" (snip s (k + 1) #s))
       fr (? (#f = 0) 0 (: v (unum (snip (f + "000") 0 3)) (? (charm? v) v ())))
       (? (charm? w && charm? fr && (k != 0 || 0 < #f)) (w * 1000 + fr) ()))
   ; ns -> "m.mmm", the ms busybox prints
   (ping-t ns) (: us (ns // 1000) f (show (us % 1000))
                  (show (us // 1000) + "." + snip ("00" + f) (#f - 1) (#f + 2)))
   (ping-main as) (ping-run 0 as)
   (ping6-main as) (ping-run 1 as)
   ; v6 when ping6, or ping's -6, or a host with a colon; -4 holds ping to v4
   (ping-run six? as)
    (: t (tablet 0)
       nm (? six? "ping6" "ping")
       use (? six? ping6-usage ping-usage)
       o (uopt as t '(99 105 87 115) () ())
       _ (? (two? o) 0 (udie 2 use))
       _ (: u (uoptun t (? six? '(99 105 87 115 113) '(99 105 87 115 113 52 54))) (? !u 0 (udie 2 (nm + ": unknown option -" + string u + "\n" + use))))
       ops (o 2)
       _ (? (two? ops && atom? >ops) 0 (udie 2 use))
       (num c d lo) (: v (uoptv t c)
                       (? !v d (: n (unum v) (? (charm? n && lo <= n) n (udie 2 (nm + ": bad -" + string c + " " + v))))))
       host <ops
       six (? six? 1 (peep t 52 0) 0 (peep t 54 0) 1 (((cite 'dns) 'dns-colon?) host))
       count (num 99 () 1)
       size (num 115 56 0)
       cap (? six 1452 1464)                          ; one datagram on a 1500-byte link
       _ (? (size <= cap) 0 (udie 2 (nm + ": -s is at most " + show cap + ", one datagram")))
       ms (: v (uoptv t 105) (? !v 1000 (: m (ping-ms v) (? (charm? m && 0 < m) m (udie 2 (nm + ": bad -i " + v))))))
       wait (: v (uoptv t 87) (? !v 10000 (: m (ping-ms v) (? (charm? m) m (udie 2 (nm + ": bad -W " + v))))))
       quiet (peep t 113 0)
       D (cite 'dns)
       ad (? six ((D 'resolve6) host)
             (two? ((D 'dns-quad) host)) (map (D 'dns-show) ((D 'dns-quad) host))
             (map (D 'dns-show) ((D 'resolve) host)))
       _ (? (two? ad) 0 (udie 1 (nm + ": bad address '" + host + "'")))
       ip <ad
       p (bind [(? six 'icmp6 'icmp) 'ttl])
       _ (? (nom? p)
            (udie 2 (nm + ": no icmp" + (? six "6" "") + " echo socket here (" + show p
                     + "); it wants root, or on linux your group in net.ipv4.ping_group_range")) 0)
       _ (say out ("PING " + host + " (" + ip + "): " + show size + " data bytes\n"), flush out)
       st {'sent 0 'got 0 'min () 'max 0 'sum 0}
       at (tablet 0)                                   ; seq -> the nclock it went at
       (pkt n) (string (? six 128 8) + string 0 + "\x00\x00\x00\x00" + string (n >> 8 & 255) + string (n & 255)
                + catmap (i \ string (i & 255)) ^size)
       ; the replies, as they come: each seq once, its round trip off its send time
       (rx _)
        (: d (recv p)
           b <>d
           n (? (8 <= #b && b 0 = (? six 129 0)) (b 6 * 256 + b 7) -1)
           t0 (at n)
           _ (? !t0 0
                (: rt (nclock t0)
                   _ (pull at n ())
                   _ (? quiet 0
                        (say out (show #b + " bytes from " + ip + ": seq=" + show n
                                       + (? (two? >>d) (" ttl=" + show (d 2)) "") + " time=" + ping-t rt + " ms\n"), flush out))
                   ; 'got last: its count is what ends the wait for the last reply
                   (pins st 'sum (st 'sum + rt) 'max (max rt (st 'max))
                         'min (? !(st 'min) rt (min rt (st 'min))) 'got (st 'got + 1))))
           (rx 0))
       r (twirl rx 0)
       ; the summary, then out: 0 when anything came back
       (fin _)
        (: sn (st 'sent) gt (st 'got)
           _ (freeze r) _ (close p)
           _ (say out ("\n--- " + host + " ping statistics ---\n" + show sn + " packets transmitted, "
                       + show gt + " packets received, " + show (? (0 < sn) ((sn - gt) * 100 // sn) 0)
                       + "% packet loss\n"
                       + (? (0 < gt) ("round-trip min/avg/max = " + ping-t (st 'min) + "/"
                                      + ping-t (st 'sum // gt) + "/" + ping-t (st 'max) + " ms\n") "")))
           _ (flush out)
           (quit (? (0 < gt) 0 1)))
       ; ^C ends it with the summary, as ping's own does
       sg (sigfd [2])
       _ (? (hot? sg) (twirl (_ \ (await sg, sigtake sg, fin 0)) 0) 0)
       (tx n)
        (? (charm? count && count <= n) 0
           (pin at (n & 65535) (nclock 0), (: w (send p [ip 0] (pkt (n & 65535))) (? (nom? w) (udie 1 (nm + ": sendto: " + show w)) 0)), pin st 'sent (st 'sent + 1), (? (charm? count && count <= n + 1) 0 (rest ms)), tx (n + 1)))
       _ (tx 0)
       ; the last echoes get up to -W to come home
       t1 (clock 0)
       _ ((: (g _) (? (st 'got < st 'sent && clock 0 - t1 < wait) (rest 10, g 0) 0)) 0)
       (fin 0))

   ; -- traceroute ---------------------------------------------------------------------
   ; icmp echoes with the ttl rising from -f (1) to -m (30), -q (3) to each hop: the routers'
   ; time-exceeded errors come back through (bind [.. 'errs]), the target's echo reply ends
   ; it, and so does an unreachable (marked !N !H !P !X). each probe waits -w seconds (3).
   ; a router's name is its PTR off the first nameserver unless -n. busybox's probes are udp;
   ; these are what its -I sends, the one kind an unprivileged linux socket may send
   tr-usage "usage: traceroute [-46nI] [-f FIRST] [-m MAX] [-q N] [-w SECS] HOST"
   tr6-usage "usage: traceroute6 [-nI] [-f FIRST] [-m MAX] [-q N] [-w SECS] HOST"
   (traceroute-main as) (tr-run 0 as)
   (traceroute6-main as) (tr-run 1 as)
   ; an unreachable's code -> its mark, "" when it means the target answered (port, v4 3; v6 4)
   (tr-mark six type code)
    (? six (? (type = 1) (? (code = 4) "" (code = 0) " !N" (code = 3) " !H" " !X") "")
       (type = 3) (? (code = 3) "" (code = 0) " !N" (code = 1) " !H" (code = 2) " !P" " !X")
       "")
   (tr-run six? as)
    (: t (tablet 0)
       nm (? six? "traceroute6" "traceroute")
       use (? six? tr6-usage tr-usage)
       o (uopt as t '(102 109 113 119) () ())
       _ (? (two? o) 0 (udie 2 use))
       _ (: u (uoptun t (? six? '(102 109 113 119 110 73) '(102 109 113 119 110 73 52 54)))
            (? !u 0 (udie 2 (nm + ": unknown option -" + string u + "\n" + use))))
       ops (o 2)
       _ (? (two? ops && atom? >ops) 0 (udie 2 use))
       (num c d lo) (: v (uoptv t c)
                       (? !v d (: n (unum v) (? (charm? n && lo <= n && n <= 255) n (udie 2 (nm + ": bad -" + string c + " " + v))))))
       first (num 102 1 1) most (num 109 30 1) nq (num 113 3 1)
       wait (: v (uoptv t 119) (? !v 3000 (: m (ping-ms v) (? (charm? m && 0 < m) m (udie 2 (nm + ": bad -w " + v))))))
       _ (? (first <= most) 0 (udie 2 (nm + ": -f is past -m")))
       names? !(peep t 110 0)
       host <ops
       D (cite 'dns)
       six (? six? 1 (peep t 52 0) 0 (peep t 54 0) 1 ((D 'dns-colon?) host))
       ad (? six ((D 'resolve6) host)
             (two? ((D 'dns-quad) host)) (map (D 'dns-show) ((D 'dns-quad) host))
             (map (D 'dns-show) ((D 'resolve) host)))
       _ (? (two? ad) 0 (udie 1 (nm + ": bad address '" + host + "'")))
       ip <ad
       p (bind [(? six 'icmp6 'icmp) 'errs])
       _ (? (nom? p)
            (udie 2 (nm + ": no icmp" + (? six "6" "") + " echo socket here (" + show p
                     + "); it wants root, or on linux your group in net.ipv4.ping_group_range")) 0)
       size (8 + 32)
       _ (say out (nm + " to " + host + " (" + ip + "), " + show most + " hops max, "
                        + show (size + (? six 40 20)) + " byte packets\n"), flush out)
       (pkt n) (string (? six 128 8) + string 0 + "\x00\x00\x00\x00" + string (n >> 8 & 255) + string (n & 255)
                + catmap (i \ string (i & 255)) ^32)
       ; a router's name, once each: its PTR off the first nameserver, else its address
       names (tablet 0)
       ns (: s ((D 'dns-servers) "/etc/resolv.conf") (? (two? s) <s ()))
       (name a)
        (? (!names? || six || !ns) a
           (: c (names a)
              (? !!c c
                 (: id ((D 'dns-id) 0)
                    r ((D 'dns-raw) <ns >ns ((D 'dns-qedns) id (ns-rev a) 12) 1000)
                    rs (? (string? r) ((D 'dns-records) r id) ())
                    ptr (? (two? rs) (filter (x \ x 1 = 12) (rs 2)) ())
                    v (? (two? ptr) (<ptr 2) a)
                    _ (pin names a v)
                    v))))
       ; the answer to probe n, or () when -w passes first: a stray (a late answer to an
       ; earlier probe) is skipped
       (answer n until)
        (: left (until - clock 0)
           (? (left < 1) ()
              (: r (twirl (_ \ recv p) ())
                 w (twirl (_ \ (rest left, freeze r)) ())
                 d (catch r)
                 _ (freeze w)
                 b (? (two? d) <>d "")
                 (? (atom? d) ()
                    (8 <= #b && (b 6 * 256 + b 7) = n) d
                    (answer n until)))))
       ; one hop: nq probes, a line -> 1 once the target or an unreachable answered
       (hop h)
        (: _ (say out (? (h < 10) (" " + show h) (show h)))
           (probe k last done)
            (? (nq <= k) done
               (: n (: v (peep t 'seq 0) _ (pin t 'seq ((v + 1) & 65535)) v)
                  t0 (nclock 0)
                  _ (send p [ip 0 'ttl h] (pkt n))
                  d (answer n (clock 0 + wait))
                  (? !d
                     (say out " *", flush out, probe (k + 1) last done)
                     (: rt (nclock t0)
                        a <<d
                        kind (? (two? >>>d) (d 3) ())
                        _ (? (a = last) 0 (say out ("  " + (? names? (name a + " (" + a + ")") a))))
                        mark (? (two? kind) (tr-mark six <kind (kind 1)) "")
                        _ (say out ("  " + ping-t rt + " ms" + mark), flush out)
                        end (? !kind 1 (? six (<kind = 1) (<kind = 3)) 1 0)
                        (probe (k + 1) a (? end 1 done))))))
           r (probe 0 "" 0)
           _ (say out "\n", flush out)
           r)
       (go h) (? (most < h) 0 (? (hop h) 0 (go (h + 1))))
       _ (go first)
       _ (close p)
       (quit 0))

   ; -- httpd --------------------------------------------------------------------------
   ; busybox's flags onto kiosko's serve. the value flags it does not have are still read
   ; as taking a value, so the refusal names the flag and not the word after it
   (httpd-main as)
    (: t (tablet 0)
       o (uopt as t '(112 104 99 117 114 109 101 100) () ())
       _ (? (two? o) 0 (udie 2 httpd-usage))
       _ (: u (uoptun t '(102 118 112 104))
            (? !u 0 (udie 2 ("httpd: -" + string u + " is not supported (kiosko serves files, no more)"))))
       _ (? (two? (o 2)) (udie 2 httpd-usage) 0)
       pv (uoptv t 112)
       ; -p [IP:]PORT: an address other than every one is refused, not quietly widened
       ps (? (string? pv)
              (: k ((: (g i) (? (i < 0) -1 (pv i = 58) i (g (i - 1)))) (#pv - 1))
                 ip (? (k < 0) "" (snip pv 0 k))
                 (? (#ip && ip != "0.0.0.0" && ip != "*")
                     (udie 2 ("httpd: kiosko listens on every address; -p takes a port, not " + pv))
                    (snip pv (k + 1) #pv)))
              ())
       port (? !ps 80 (: n (unum ps) (? (charm? n && 0 < n < 65536) n (udie 2 ("httpd: not a port: " + ps)))))
       root (: h (uoptv t 104) (? (string? h) h "."))
       _ (? (two? (readdir root)) 0 (udie 1 ("httpd: not a directory: " + root)))
       r ((cite 'kiosko 'serve) root port !(peep t 118 0) ())
       (? (nom? r) (udie 1 ("httpd: cannot listen on :" + show port + " -- " + show r)) 0)))
) ; module 'kore
