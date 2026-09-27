; apps/kore/net.l -- telnet and httpd: two network tools over doors the tree already has.
;
;   telnet HOST [PORT]                a remote terminal over tcp, port 23 by default
;   httpd [-fv] [-p PORT] [-h DIR]    kiosko under busybox's name and flags
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
(module 'kore
(borrow 'cli)
(borrow 'posix)

(:
   tn-usage "usage: telnet HOST [PORT]"
   httpd-usage "usage: httpd [-fv] [-p PORT] [-h DIR]"

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
           (? (c = 255) (: _ (pin st 'm 1) ["" ""])
              (c = 0 && st 'cr) (: _ (pin st 'cr 0) ["" ""])
              (: _ (pin st 'cr (c = 13)) [(string c) ""]))
          (m = 1)
           (? (c = 255) (: _ (pins st 'm 0 'cr 0) [(string 255) ""])
              (251 <= c <= 254) (: _ (pins st 'm 2 'v c) ["" ""])
              (c = 250) (: _ (pin st 'm 3) ["" ""])
              (: _ (pin st 'm 0) ["" ""]))                 ; NOP, GA, AYT..: nothing to show
          (m = 2) (: _ (pin st 'm 0) ["" (tn-opt st (st 'v) c)])
          (m = 3) (: _ (? (c = 255) (pin st 'm 4) 0) ["" ""])
          (: _ (pin st 'm (? (c = 240) 0 3)) ["" ""])))   ; SE ends it; anything else stays in
   ; a verb about option x -> the reply owed. the server may echo (1) and suppress go-ahead
   ; (3), we suppress go-ahead, and everything else is refused. a request for what is
   ; already on, or a refusal of what is already off, answers nothing: that is what keeps
   ; two agreeable ends from acknowledging each other forever
   (tn-opt st v x)
    (: him (st 'him) us (st 'us)
       (? (v = 251) (? (elem x him) ""
                       (elem x '(1 3)) (: _ (pin st 'him (x . him)) (tn-cmd 253 x))
                       (tn-cmd 254 x))
          (v = 252) (? (elem x him) (: _ (pin st 'him (filter (y \ y != x) him)) (tn-cmd 254 x)) "")
          (v = 253) (? (elem x us) ""
                       (x = 3) (: _ (pin st 'us (x . us)) (tn-cmd 251 x))
                       (tn-cmd 252 x))
          (? (elem x us) (: _ (pin st 'us (filter (y \ y != x) us)) (tn-cmd 252 x)) "")))
   ; one typed byte -> the wire. in character mode return is 13 and ends a line; in line
   ; mode the terminal hands a line ending 10, and a 13 is a stray from a CR LF file
   (tn-send c raw?)
    (? (c = 255) (string 255 + string 255)
       raw? (? (c = 13) "\r\n" (string c))
       (c = 10) "\r\n" (c = 13) "" (string c))

   ; -- telnet: the face ---------------------------------------------------------------
   (telnet-main as)
    (: _ (? (0 < #as < 3) 0 (udie 2 tn-usage))
       _ (: w (uoptstray as as) (? (nil? w) 0 (udie 2 ("telnet: unknown option " + w))))
       host <as
       port (? (two? >as) (: n (unum <>as) (? (charm? n && 0 < n < 65536) n (udie 2 ("telnet: not a port: " + <>as)))) 23)
       _ (: _ (say err ("Trying " + host + "...\n")) (flush err))
       s ((cite 'dns 'dial) host port)
       _ (? s 0 (udie 1 ("telnet: cannot connect to " + host + " port " + show port)))
       _ (: _ (say err ("Connected to " + host + ".\nEscape character is '^]'.\n")) (flush err))
       tty? (two? (tty 0))
       st (tn-new 0)
       ; the terminal in step with the server's echo: raw while it echoes
       (mode _) (: r (tn-echo? st) (? (tty? && r != st 'raw) (: _ (raw r) (pin st 'raw r)) 0))
       ; the server's side, in its own task: shown, answered, and at its close the end of
       ; the program -- the other task is parked on a key that may never come
       (down _)
        (: c (see s)
           (? (c < 0) (: _ (? tty? (raw 0) 0) _ (flush out)
                         _ (say err "Connection closed by foreign host.\n") _ (flush err) (quit 0))
              (: r (tn-byte st c)
                 _ (? #<r (: _ (say out <r) (flush out)) 0)
                 _ (? #(r 1) (: _ (say s (r 1)) (flush s)) 0)
                 _ (mode 0)
                 (down 0))))
       d (twirl down 0)
       (up _)
        (: c (see in)
           (? (c < 0) (: _ (seal s 1) _ (catch d) 0)      ; stdin done: half-close, drain
              (c = 29) (: _ (? tty? (raw 0) 0) _ (say err "\nConnection closed.\n") _ (close s) 0)
              (: _ (say s (tn-send c (st 'raw))) _ (flush s) (up 0))))
       (up 0))

   ; -- httpd --------------------------------------------------------------------------
   ; busybox's flags onto kiosko's serve. the value flags it does not have are still read
   ; as taking a value, so the refusal names the flag and not the word after it
   (httpd-main as)
    (: t (tablet 0)
       o (uopt as t '(112 104 99 117 114 109 101 100) () ())
       _ (? (two? o) 0 (udie 2 httpd-usage))
       _ (: u (uoptun t '(102 118 112 104))
            (? (nil? u) 0 (udie 2 ("httpd: -" + string u + " is not supported (kiosko serves files, no more)"))))
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
       port (? (nil? ps) 80 (: n (unum ps) (? (charm? n && 0 < n < 65536) n (udie 2 ("httpd: not a port: " + ps)))))
       root (: h (uoptv t 104) (? (string? h) h "."))
       _ (? (two? (readdir root)) 0 (udie 1 ("httpd: not a directory: " + root)))
       r ((cite 'kiosko 'serve) root port !(peep t 118 0) ())
       (? (nom? r) (udie 1 ("httpd: cannot listen on :" + show port + " -- " + show r)) 0)))
) ; module 'kore
