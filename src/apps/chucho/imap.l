; src/apps/chucho/imap.l -- a mailbox on an IMAP server (RFC 9051, the part a reader needs):
; LOGIN, SELECT, the headers fetched for the index and a body when it is read, the flags
; stored back and the deleted expunged, a message appended. imaps:// is tls from the first
; byte (993), imap:// is raised to it by STARTTLS (143); a password goes only over tls, but
; to this host. the connection is smtp's (src/apps/chucho/smtp.l).
;
;   (imap-url u)                  -> [tls? user host port mailbox] | ()
;   (imap-open u user pass)       -> a box, as mailbox's: {'kind 'imap 'path 'msgs ..} | why not
;   (imap-raw b m) (imap-sync b)  -> the message's text; the box read again | why not
;   (imap-append u user pass raw fl) -> 1 | why not
;   (imap-close b)
;   (imap-parse segs)             -> a response's tokens as a tree: strings, () for NIL, lists
;
; a message is mailbox's, with 'uid; 'raw holds its text once read. the box keeps its
; credentials, so a connection the server dropped is made again.
(module (imap imap-url imap-open imap-raw imap-sync imap-append imap-close imap-parse imap-quote)
(borrow 'posix)
(borrow 'mime)
(borrow 'smtp)
(borrow 'mailbox)
(:
 im-flags [["\\seen" 83] ["\\answered" 82] ["\\flagged" 70] ["\\draft" 68]]

 (imap-url u)
  (: tls? (starts? u "imaps://")
     r (? tls? (snip u 8 #u) (starts? u "imap://") (snip u 7 #u) ())
     (? !(string? r) ()
        (: k (findsub r "/")
           auth (k < 0 ? r (snip r 0 k))
           box (k < 0 ? "INBOX" (snip r (k + 1) #r))
           at (: (go i) (? (i < 0) -1 (auth i = 64) i (go (i - 1))) (go (#auth - 1)))
           user (at < 0 ? "" (replace (snip auth 0 at) "%40" "@"))
           hp (snip auth (at + 1) #auth)
           c (findsub hp ":")
           host (c < 0 ? hp (snip hp 0 c))
           port (c < 0 ? (tls? ? 993 143) (mime-num (snip hp (c + 1) #hp)))
           (#host && 0 < port ? [tls? user host port (#box ? box "INBOX")] ()))))
 (imap-quote s) ("\"" + replace (replace s "\\" "\\\\") "\"" "\\\"" + "\"")

 ; --- a response: its lines, the literals between them read exactly -----------------------
 ; the {n} a line ends with, -1 for none
 (im-litn l)
  (? (#l < 3 || l (#l - 1) != 125) -1
     (: (go i) (? (i < 0) -1 (l i = 123) i (go (i - 1)))
        k (go (#l - 2))
        (k < 0 ? -1 (mime-num (replace (snip l (k + 1) (#l - 1)) "+" "") @ n
                       (n < 0 ? -1 n)))))
 ; -> the segments: text, and each literal as [its bytes]; () when the stream ends
 (im-segs c)
  (: (go acc)
      (smtp-line c @ l
         (? !(string? l) ()
            (im-litn l @ n
               (? (n < 0) (rev (l . acc))
                  (smtp-take c n @ b
                     (? !(string? b) ()
                        (: k (: (g i) (? (l i = 123) i (g (i - 1))) (g (#l - 1)))
                           (go ([b] . (snip l 0 k) . acc)))))))))
     (go ()))
 ; the segments as tokens: 'lp 'rp, strings, () for NIL
 (im-toks t acc)
  (: n #t
     (atom-end i) (? (n <= i) i (elem (t i) [32 40 41]) i (go-br i))
     ; brackets inside an atom (BODY[HEADER]) may hold spaces and parens
     (go-br i) (? (t i = 91) (: (g j) (? (n <= j) j (t j = 93) (atom-end (j + 1)) (g (j + 1))) (g (i + 1)))
                  (atom-end (i + 1)))
     (quoted i acc2)
      (? (n <= i) [i (string (rev acc2))]
         (t i = 92 && i + 1 < n) (quoted (i + 2) (t (i + 1) . acc2))
         (t i = 34) [(i + 1) (string (rev acc2))]
         (quoted (i + 1) (t i . acc2)))
     (go i acc)
      (? (n <= i) acc
         (t i = 32) (go (i + 1) acc)
         (t i = 40) (go (i + 1) ('lp . acc))
         (t i = 41) (go (i + 1) ('rp . acc))
         (t i = 34) (quoted (i + 1) () @ [j s] (go j (s . acc)))
         (atom-end i @ j (snip t i j @ w (go j ((upper w = "NIL" ? () w) . acc)))))
     (go 0 acc))
 (im-tree ts)
  (: (go l acc)
      (? (atom? l) [(rev acc) ()]
         (<l = 'rp) [(rev acc) >l]
         (<l = 'lp) (go >l () @ [sub r] (go r (sub . acc)))
         (go >l (<l . acc)))
     (go ts () @ [t _] t))
 (imap-parse segs)
  (im-tree (rev (foldl (a \ s \ string? s ? (im-toks s a) (<s . a)) () segs)))

 ; --- commands ------------------------------------------------------------------------------
 ; -> [status [untagged ..] text]: status "OK" "NO" "BAD", or "" when the line went dead
 (im-cmd c cmd) (im-cmd-lit c cmd ())
 ; a command with a literal after it: sent when the server says go on
 (im-cmd-lit c cmd lit)
  (: n (c 'tagn + 1)
     tag ("c" + show n)
     _ (pin c 'tagn n)
     _ (smtp-put c (tag + " " + cmd + (string? lit ? (" {" + show #lit + "}") "") + "\r\n"))
     (go acc)
      (im-segs c @ segs
         (? (atom? segs) (pin c 'dead 1, ["" (rev acc) "the server went away"])
            (: l <segs
               (? (starts? l (tag + " "))
                   (: r (snip l (#tag + 1) #l) k (findsub r " ")
                      [(upper (k < 0 ? r (snip r 0 k))) (rev acc) (k < 0 ? "" (snip r (k + 1) #r))])
                  (starts? l "+") (? (string? lit) (smtp-put c (lit + "\r\n"), go acc) (go acc))
                  (go ((imap-parse segs) . acc))))))
     (go ()))
 (im-ok? r) (<r = "OK")
 (im-why what r) (what + ": " + (<r = "" ? "the server went away" (<r + " " + r 2)))

 ; --- the session ---------------------------------------------------------------------------
 ; -> a connection logged in, or why not
 (im-login u user pass)
  (u @ [tls? _ host port _]
     (: c0 (? tls? (cite 'tls 'tls-open host port 'verify @ t (tablet? t ? (pins (smtp-conn (t 's)) 'tls t) ("tls: " + show t)))
              (cite 'dns 'dial host port @ s (hot? s ? (smtp-conn s) ("cannot connect to " + host + ":" + show port))))
        (? (string? c0) c0
           (: c (pins c0 'tagn 0 'dead 0)
              g (smtp-line c)
              (? (!(string? g) || !(starts? g "* OK") && !(starts? g "* PREAUTH")) (smtp-close c, "the server did not greet")
                 (: up (? (tablet? (c 'tls)) 1
                          (im-cmd c "STARTTLS" @ r (im-ok? r ? (smtp-tls c host port) 0)))
                    (? (string? up) (smtp-close c, up)
                       (up != 1 && !(elem host ["localhost" "127.0.0.1" "::1"]))
                        (smtp-close c, "the server offers no tls; the password stays here")
                       (starts? g "* PREAUTH") c
                       (im-cmd c ("LOGIN " + imap-quote user + " " + imap-quote pass) @ r
                          (im-ok? r ? c (smtp-close c, im-why "LOGIN" r)))))))))
     "not an imap url")
 ; a FETCH response's items as a tablet: names upper, values as they came
 (im-items l) (: (go x t) (x @ (k . v . r) (go r (pin t (upper k) v)) t) (go l {}))
 (im-msg it)
  (: h (it "BODY[HEADER]")
     fl (it "FLAGS")
     fs (two? fl ? (map lower fl) ())
     lt (string (sort (catmap (p \ elem (p 0) fs ? [(p 1)] ()) im-flags)))
     m (mb-msg (mime-heads (mb-head-of (string? h ? h ""))) lt (mime-num (show-or (it "RFC822.SIZE"))))
     (pins m 'uid (mime-num (show-or (it "UID"))) 'del (elem "\\deleted" fs ? 1 0), m))
 (show-or v) (string? v ? v "0")
 (mb-head-of t) (replace t "\r\n" "\n" @ x (findsub x "\n\n" @ k (k < 0 ? x (snip x 0 k))))
 ; the selected box's messages -> [msg ..] | why not
 (im-list c name)
  (im-cmd c ("SELECT " + imap-quote name) @ r
     (? !(im-ok? r) (im-why ("SELECT " + name) r)
        (: ex (foldl (a \ x \ x @ ["*" n "EXISTS"] (mime-num n) a) 0 (r 1))
           (? (ex < 1) ()
              (im-cmd c "FETCH 1:* (UID FLAGS RFC822.SIZE BODY.PEEK[HEADER])" @ f
                 (? !(im-ok? f) (im-why "FETCH" f)
                    (map (x \ x @ ["*" _ "FETCH" it] (im-msg (im-items it)) ())
                         (filter (x \ x @ ["*" _ "FETCH" _] 1 0) (f 1)))))))))
 (imap-open url user pass)
  (imap-url url @ u
     (? (atom? u) ("not an imap url: " + url)
        (im-login u user pass @ c
           (? (string? c) c
              (im-list c (u 4) @ ms
                 (? (string? ms) (smtp-close c, ms)
                    (pins {} 'kind 'imap 'path url 'conn c 'msgs ms 'user user 'pass pass)))))))
 ; the connection, made again when the server dropped it
 (im-live b)
  (? !(b 'conn 'dead) (b 'conn)
     (im-login (imap-url (b 'path)) (b 'user) (b 'pass) @ c
        (? (string? c) c
           (im-cmd c ("SELECT " + imap-quote (imap-url (b 'path) 4)) @ r
              (im-ok? r ? (pin b 'conn c, c) (im-why "SELECT" r))))))
 (imap-raw b m)
  (? (string? (m 'raw)) (m 'raw)
     (im-live b @ c
        (? (string? c) ""
           (im-cmd c ("UID FETCH " + show (m 'uid) + " BODY.PEEK[]") @ r
              (: it (foldl (a \ x \ x @ ["*" _ "FETCH" l] (im-items l) a) {} (r 1))
                 t (it "BODY[]")
                 (string? t ? (pin m 'raw (replace t "\r\n" "\n"), m 'raw) ""))))))
 (im-flagstr m)
  (join " " (catmap (p \ has? (m 'flags) (string (p 1)) ? [(ch-cap1 (p 0))] ()) im-flags
             + (m 'del ? ["\\Deleted"] ())))
 (ch-cap1 f) ("\\" + upper (snip f 1 2) + snip f 2 #f)
 (imap-sync b)
  (im-live b @ c
     (? (string? c) c
        (: ch (filter (m \ m 'del || m 'flags != m 'flags0) (b 'msgs))
           bad (filter (m \ !(im-ok? (im-cmd c ("UID STORE " + show (m 'uid) + " FLAGS.SILENT (" + im-flagstr m + ")")))) ch)
           ex (? (any (m \ m 'del) (b 'msgs)) (im-cmd c "EXPUNGE") ["OK"])
           (? (two? bad) "the server refused some flags"
              !(im-ok? ex) (im-why "EXPUNGE" ex)
              (im-list c (imap-url (b 'path) 4) @ ms
                 (? (string? ms) ms (pins {} 'kind 'imap 'path (b 'path) 'conn c 'msgs ms 'user (b 'user) 'pass (b 'pass))))))))
 (imap-append url user pass raw fl)
  (imap-url url @ u
     (? (atom? u) ("not an imap url: " + url)
        (im-login u user pass @ c
           (? (string? c) c
              (: lit (replace (replace raw "\r\n" "\n") "\n" "\r\n")
                 f (join " " (catmap (p \ has? fl (string (p 1)) ? [(ch-cap1 (p 0))] ()) im-flags))
                 r (im-cmd-lit c ("APPEND " + imap-quote (u 4) + " (" + f + ")") lit)
                 (im-cmd c "LOGOUT", smtp-close c, im-ok? r ? 1 (im-why "APPEND" r)))))))
 (imap-close b) (b 'conn @ c (tablet? c && !(c 'dead) ? (im-cmd c "LOGOUT", smtp-close c) 0)))
) ; module imap
