; src/apps/chucho/box.l -- mailboxes on disk: a maildir (cur/ new/ tmp/, the flags in each
; file's name) or an mbox (one file, a "From " line before each message). a box is read whole
; into a tablet, changed in memory, and written back by mb-sync, which drops the deleted and
; lays the flags.
;
;   (mb-kind p)            'maildir 'mbox 'imap or () for nothing there
;   (mb-open p)            -> {'kind 'path 'msgs [msg ..]} | why not, a string
;   (mb-raw b m)           -> the message's text as it was sent; an imap box's through imap.l
;   (mb-sync b)            -> the box read again | why not, a string
;   (mb-append p raw fl)   -> 1 | why not: raw onto the box at p, made when absent (a path
;                             ending in / makes a maildir)
;
; a message is a tablet: 'hs its headers (mime-heads), 'date its secs, 'day [month day] in
; the sender's zone, 'size, 'flags the maildir letters sorted (D F P R S T), 'flags0 as read,
; 'del, and where it lives: 'file for a maildir's, 'from and 'raw (still quoted) for an
; mbox's. an mbox keeps the flags in its Status and X-Status headers: R is S here, O is "not
; new", X-Status's A F D are R F T.
(module (mailbox mb-kind mb-open mb-raw mb-sync mb-append mb-flag mb-has? mb-new? mb-msg)
(borrow 'posix)
(borrow 'mime)
(borrow 'cal)
(:
 (mb-dir? p) (stat p @ st (two? st && 16384 = st 2 & 61440))
 (mb-kind p)
  (? (starts? p "imap://" || starts? p "imaps://") 'imap
     (mb-dir? (p + "/cur") && mb-dir? (p + "/new")) 'maildir
     (two? (stat p)) (mb-dir? p ? () 'mbox)
     ())
 (mb-has? m c) (has? (m 'flags) (string c))
 (mb-new? m) !(mb-has? m 83)
 ; a flag string with c set or cleared, kept in order
 (mb-flag f c on?)
  (string (sort (? on? (elem c (chars f) ? (chars f) (c . chars f))
                   (filter (x \ x != c) (chars f)))))
 (mb-msg hs fl size)
  (: d (mime-date (mime-get hs "date"))
     (pins {} 'hs hs 'date (two? d ? <d 0) 'day (two? d ? [(d 2) (d 3)] [1 1]) 'size size 'flags fl
           'flags0 fl 'del 0))
 (mb-head t) (findsub t "\n\n" @ k (k < 0 ? t (snip t 0 k)))

 ; --- maildir ---------------------------------------------------------------------------
 ; the head of a file, without reading a long body to find it
 (mb-peek p)
  (open p "r" @ q
     (? !(hot? q) ()
        (: b (cask 16384) k (swig q b)
           t (charm? k && 0 < k ? (snip (string b) 0 k) "")
           (close q,
            (k = 16384 && findsub (replace t "\r\n" "\n") "\n\n" < 0 ? (uread p @ r (two? r ? <>r t)) t)))))
 (mb-info n) (findsub n ":2," @ k (k < 0 ? "" (snip n (k + 3) #n)))
 (mb-base n) (findsub n ":" @ k (k < 0 ? n (snip n 0 k)))
 (mb-dmsg p sub n)
  (: f (p + "/" + sub + "/" + n) st (stat f) t (mb-peek f)
     (? (!(two? st) || !(string? t)) ()
        (: m (mb-msg (mime-heads <(mime-split t)) (string (sort (chars (mb-info n)))) <st)
           (pins m 'file f 'sub sub 'name n, m))))
 (mb-dlist p sub)
  (readdir (p + "/" + sub) @ ns
     (two? ns ? (filter tablet? (map (mb-dmsg p sub) (filter (n \ #n && n 0 != 46) ns))) ()))
 (mb-dopen p)
  (: ms (mb-dlist p "cur" + mb-dlist p "new")
     (pins {} 'kind 'maildir 'path p 'msgs (sortby (a \ b \ a 'date <= b 'date) ms)))
 (mb-dsync b)
  (: p (b 'path)
     (one m)
      (? (m 'del) (unlink (m 'file))
         (m 'flags = m 'flags0 && m 'sub = "cur") 0
         (rename (m 'file) (p + "/cur/" + mb-base (m 'name) + ":2," + m 'flags)))
     (each (b 'msgs) one, mb-open p))
 (mb-uniq _)
  (: c (clock 0) un (uname 0) h (two? un ? <>un "localhost")
     (show (c // 1000) + ".M" + show (c % 1000) + "P" + show (getpid 0) + "R" + show (rand 1000000)
      + "." + replace (replace h "/" "\\057") ":" "\\072"))
 (mb-dappend p raw fl)
  (: n (mb-uniq 0) tmp (p + "/tmp/" + n)
     (? !(uwrite tmp raw) ("cannot write " + tmp)
        (rename tmp (#fl ? (p + "/cur/" + n + ":2," + fl) (p + "/new/" + n)) @ r
           (nom? r ? ("cannot file " + tmp) 1))))
 (mb-mkdir p) (each ["" "/cur" "/new" "/tmp"] (s \ mkdir (p + s) 448), mb-kind p = 'maildir)

 ; --- mbox ------------------------------------------------------------------------------
 ; where each message's From line starts
 (mb-starts t)
  (: (go i acc) (fsub t "\nFrom " i @ k (k < 0 ? (rev acc) (go (k + 1) ((k + 1) . acc))))
     (go 0 (starts? t "From " ? [0] ())))
 ; ">From " quoting, one > undone on each line of >s before a From (mboxrd, and mboxo's too)
 (mb-unquote t)
  (? !(has? t ">From ") t
     (: (one l) (: (go i) (i < #l && l i = 62 ? (go (i + 1)) i)
                   (go 0 @ k (0 < k && starts? (snip l k #l) "From " ? (snip l 1 #l) l)))
        (join "\n" (map one (split "\n" t)))))
 (mb-quote t)
  (: (one l) (: (go i) (i < #l && l i = 62 ? (go (i + 1)) i)
                (go 0 @ k (starts? (snip l k #l) "From " ? (">" + l) l)))
     (join "\n" (map one (split "\n" t))))
 (mb-sflags hs)
  (: s (mime-get hs "status") x (mime-get hs "x-status")
     (on t c f) (has? t c ? f "")
     (string (sort (chars (on s "R" "S" + on x "A" "R" + on x "F" "F" + on x "D" "T")))))
 (mb-mmsg t a e)
  (: nl (fsub t "\n" a) fe (nl < 0 || e < nl ? e nl)
     raw (snip t (fe < e ? (fe + 1) e) e)
     raw2 (raw @ (r + "\n") r raw)
     hs (mime-heads (mb-head (replace raw2 "\r\n" "\n")))
     m (mb-msg hs (mb-sflags hs) #raw2)
     (pins m 'from (snip t a fe) 'raw raw2 'old (has? (mime-get hs "status") "O"), m))
 (mb-stamp p) (stat p @ st (two? st ? [<st (st 1)] ()))
 (mb-mopen p)
  (uread p @ r
     (? !(two? r) ("cannot read " + p)
        (: t <>r ss (mb-starts t)
           (go l acc) (l @ (a . b . _) (go >l ((mb-mmsg t a b) . acc))
                            [a] (rev ((mb-mmsg t a #t) . acc))
                            (rev acc))
           (pins {} 'kind 'mbox 'path p 'msgs (go ss ()) 'stamp (mb-stamp p)))))
 ; the head with its Status lines laid again from the flags
 (mb-restatus raw fl)
  (: k (findsub raw "\n\n") h (k < 0 ? raw (snip raw 0 k)) rest (k < 0 ? "" (snip raw k #raw))
     ls (filter (l \ !(starts? (lower l) "status:") && !(starts? (lower l) "x-status:")) (split "\n" h))
     (has c s) (has? fl c ? s "")
     st ("Status: " + has "S" "R" + "O")
     xs (has "R" "A" + has "F" "F" + has "T" "D")
     (join "\n" (ls + [st] + (#xs ? [("X-Status: " + xs)] ())) + rest))
 (mb-msync b)
  (: p (b 'path) ms (b 'msgs)
     dirty (any (m \ m 'del || m 'flags != m 'flags0 || !(m 'old)) ms)
     (? !dirty b
        (mb-stamp p != b 'stamp) (p + " changed on disk; not written")
        (: j (jug 0)
           _ (each (filter (m \ !(m 'del)) ms)
                   (m \ mb-restatus (m 'raw) (m 'flags) @ r
                      (say j (m 'from + "\n" + r + (ends? r "\n" ? "\n" "\n\n")))))
           tmp (p + ".chucho-" + show (getpid 0))
           (? !(uwrite tmp (slurp j)) ("cannot write " + tmp)
              (nom? (rename tmp p)) (unlink tmp, "cannot replace " + p)
              (mb-open p)))))
 (mb-asctime ms)
  (: s (ms // 1000) days (s // 86400) ymd (civil days) r (s % 86400)
     (p2 v) (zpad 2 (show v))
     (wd3 (wday days) + " " + mon3 (ymd 1 - 1) + " " + (ymd 2 < 10 ? " " "") + show (ymd 2) + " "
      + p2 (r // 3600) + ":" + p2 (r % 3600 // 60) + ":" + p2 (r % 60) + " " + show <ymd))
 (mb-mappend p raw fl)
  (: hs (mime-heads <(mime-split raw))
     a (mime-addrs (mime-get hs "from"))
     who (two? a && #(<a 1) ? (<a 1) "MAILER-DAEMON")
     r0 (replace raw "\r\n" "\n")
     body (mb-quote (#fl ? (mb-restatus r0 fl) r0))
     t ("From " + who + " " + mb-asctime (clock 0) + "\n" + body + (ends? body "\n" ? "\n" "\n\n"))
     (open p "a" @ q
        (? !(hot? q) ("cannot open " + p)
           (say q t, close q, 1))))

 ; --- the doors -------------------------------------------------------------------------
 (mb-open p)
  (mb-kind p @ k
     (? (k = 'maildir) (mb-dopen p) (k = 'mbox) (mb-mopen p)
        (k = 'imap) (p + ": an imap box opens with its password (imap-open)")
        (p + ": no mailbox there")))
 (mb-raw b m)
  (b 'kind @ 'mbox (mb-unquote (m 'raw)) 'imap (cite 'imap 'imap-raw b m) (uread (m 'file) @ r (two? r ? <>r "")))
 (mb-sync b) (b 'kind @ 'mbox (mb-msync b) 'imap (cite 'imap 'imap-sync b) (mb-dsync b))
 (mb-append p raw fl)
  (mb-kind p @ k
     (? (k = 'maildir) (mb-dappend p raw fl)
        (k = 'imap) "an imap box takes a message with its password (imap-append)"
        (k = 'mbox || (!k && !(ends? p "/"))) (mb-mappend p raw fl)
        (mb-mkdir (p @ (q + "/") q p)) (mb-dappend (p @ (q + "/") q p) raw fl)
        ("cannot make " + p))))
) ; module mailbox
