; src/apps/chucho/smtp.l -- a message handed on: to a sendmail on this host, or to a
; submission server over SMTP (RFC 5321), in tls from the first byte (smtps://, port 465) or
; raised to it by STARTTLS (smtp://, port 587). a password goes only over tls, but to a
; server on this host. the tls is src/apps/tls's, certificates checked the way wget's are.
;
;   (smtp-send url user pass from rcpts raw)   -> 1 | why not, a string
;   (smtp-pipe cmd from rcpts raw)             -> 1 | why not: sendmail's way
;   (smtp-url u)                               -> [tls? host port] | ()
;   (smtp-wire raw)                            -> raw with crlf ends and dots stuffed
;   (smtp-conn tls? host port) (smtp-line c) (smtp-take c n) (smtp-put c s)
;   (smtp-tls c host port) (smtp-close c)      the line-at-a-time connection, which imap shares
(module (smtp smtp-send smtp-pipe smtp-url smtp-wire smtp-conn smtp-line smtp-put smtp-close smtp-take smtp-tls)
(borrow 'posix)
(borrow 'mime)
(:
 (smtp-url u)
  (: tls? (starts? u "smtps://")
     r (u @ ("smtps://" + x) x ("smtp://" + x) x ())
     (? !(string? r) ()
        (: h (r @ (a + "/" + _) a r)
           h2 (h @ (_ + "@" + b) b h)
           hpt (h2 @ (a + ":" + t) [a (mime-num t)] [h2 (tls? ? 465 587)])
           host <hpt port <>hpt
           (#host && 0 < port ? [tls? host port] ()))))
 ; crlf on every line, a leading dot doubled, and the end of data after
 (smtp-wire raw)
  (: t (replace raw "\r\n" "\n") t2 (t @ (a + "\n") a t)
     (join "\r\n" (map (l \ #l && l 0 = 46 ? ("." + l) l) (split "\n" t2)) + "\r\n"))

 ; --- a connection: tls's wire, plain or sealed, and the bytes read ahead -> it | why not ----
 (smtp-conn tls? host port)
  (cite 'tls 'tls-wire tls? host port 'verify @ w (? (tablet? w) {'w w 'buf ""} tls? ("tls: " + show w) w))
 (smtp-put c s) (cite 'tls 'tls-say (c 'w) s)
 (sm-more c) (cite 'tls 'tls-hear (c 'w) @ r (string? r ? r ()))
 ; the next line without its crlf, () at the end of the stream
 (smtp-line c)
  (: b (c 'buf)
     (b @ (a + "\n" + r) (pin c 'buf r, (a @ (x + "\r") x a))
        (sm-more c @ m (string? m ? (pin c 'buf (b + m), smtp-line c) ()))))
 ; the next n bytes exactly, () when the stream ends first: an imap literal
 (smtp-take c n)
  (: b (c 'buf)
     (? (n <= #b) (pin c 'buf (snip b n #b), snip b 0 n)
        (sm-more c @ m (string? m ? (pin c 'buf (b + m), smtp-take c n) ()))))
 ; a socket raised to tls in place -> 1 | why not
 (smtp-tls c host port)
  (cite 'tls 'tls-on (c 'w 's) host port 'verify @ t (tablet? t ? (pin c 'w t, 1) ("tls: " + show t)))
 ; a reply, its lines gathered -> [code [text ..]], code 0 when the server went away
 (sm-reply c)
  (: (go acc)
      (smtp-line c @ l
         (? !(string? l) [0 (rev acc)]
            (#l < 4 || l 3 != 45) [(mime-num (snip l 0 3)) (rev ((snip l (min 4 #l) #l) . acc))]
            (go ((snip l 4 #l) . acc))))
     (go ()))
 (sm-cmd c s) (smtp-put c (s + "\r\n"), sm-reply c)
 (smtp-close c) (cite 'tls 'tls-close (c 'w))
 sh-quote (cite 'lush 'sh-quote)
 (sm-local? h) (elem h ["localhost" "127.0.0.1" "::1"])

 ; --- the conversation ----------------------------------------------------------------------
 ; each step answers the next, or a why that ends it; a why carries the server's own words
 (sm-why what r) (what + ": " + show <r + " " + join " " <>r)
 (sm-ok? r lo hi) (lo <= <r && <r <= hi)
 (sm-ehlo c)
  (: un (uname 0) me (two? un ? <>un "localhost")
     r (sm-cmd c ("EHLO " + me))
     (sm-ok? r 250 259 ? r (sm-cmd c ("HELO " + me))))
 (sm-has? r w) (any (l \ starts? (upper l) w) <>r)
 (sm-talk c host port user pass from rcpts raw)
  (: g (sm-reply c)
     (? !(sm-ok? g 220 229) (sm-why "the server's greeting" g)
        (: e (sm-ehlo c)
           (? !(sm-ok? e 250 259) (sm-why "EHLO" e)
              (: tl (? (c 'w 'up) e
                       !(sm-has? e "STARTTLS") e
                       (sm-cmd c "STARTTLS" @ r
                          (? !(sm-ok? r 220 229) (sm-why "STARTTLS" r)
                             (smtp-tls c host port @ t (t = 1 ? (sm-ehlo c) t)))))
                 (sm-go c tl host user pass from rcpts raw))))))
 (sm-go c e host user pass from rcpts raw)
  (? (string? e) e
     !(sm-ok? e 250 259) (sm-why "EHLO" e)
     (#user && !(c 'w 'up) && !(sm-local? host)) "the server offers no tls; the password stays here"
     (: a (? !(#user) [235 ()]
             (sm-cmd c ("AUTH PLAIN " + mime-b64e ("\0" + user + "\0" + pass))))
        (? !(sm-ok? a 235 235) (sm-why "AUTH" a)
           (sm-cmd c ("MAIL FROM:<" + from + ">") @ m
              (? !(sm-ok? m 250 259) (sm-why "MAIL FROM" m)
                 (: (rc l) (? (atom? l) 1
                              (sm-cmd c ("RCPT TO:<" + <l + ">") @ r
                                 (sm-ok? r 250 259 ? (rc >l) (sm-why ("RCPT TO " + <l) r))))
                    ok (rc rcpts)
                    (? (string? ok) ok
                       (sm-cmd c "DATA" @ d
                          (? !(sm-ok? d 354 354) (sm-why "DATA" d)
                             (: _ (smtp-put c (smtp-wire raw + ".\r\n"))
                                f (sm-reply c)
                                (sm-ok? f 250 259 ? (sm-cmd c "QUIT", 1) (sm-why "the message" f))))))))))))
 (smtp-send url user pass from rcpts raw)
  (smtp-url url @ u
     (? (atom? u) ("not an smtp url: " + url)
        (: host <>u port <>>u
           (smtp-conn <u host port @ c
              (? (string? c) c
                 (: r (sm-talk c host port user pass from rcpts raw)
                    (smtp-close c, r)))))))

 ; --- sendmail ------------------------------------------------------------------------------
 (smtp-pipe cmd from rcpts raw)
  (: argv ("exec " + cmd + " -oi -f " + sh-quote from + " -- " + join " " (map sh-quote rcpts))
     _ (flush out) pp (pipe 0)
     (? (nom? pp) "cannot make a pipe"
        (: p (spawnio ["sh" "-c" argv] <pp -1 -1 [>pp] -1 0)
           _ (close <pp)
           q (fdopen >pp)
           _ (say q (replace raw "\r\n" "\n"))
           _ (close q)
           st (charm? p && 0 <= p ? (wait p) -1)
           (st = 0 ? 1 (cmd + " failed (" + show st + ")"))))))
) ; module smtp
