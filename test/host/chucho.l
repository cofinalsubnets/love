; test/host/chucho.l -- the mail reader, headless: mime's decodings, the two mailbox kinds and
; their round trips, smtp's wire form, imap's urls and responses, and chucho's steps -- the
; threads, the index and pager frames, the keys, the drafts a reply and a forward start from,
; and a message built and handed to a sendmail. the tty runner and live smtp and imap servers
; stay live probes.
; run: cat test/00-init.l test/host/chucho.l | out/love

(borrow 'posix)
(borrow 'mime)
(borrow 'mailbox)
(borrow 'smtp)
(borrow 'imap)
(borrow 'chucho)
(borrow 'text)

(: R "/tmp/chuchotest"
   (cht-rm p) (lstat p @ st
                 (? !(two? st) 0
                    (16384 = st 2 & 61440) (readdir p @ ns (each (two? ns ? ns ()) (n \ n = "." || n = ".." ? 0 (cht-rm (p + "/" + n))), rmdir p))
                    (unlink p)))
   (cht-plain s) ((: (g i acc esc) (i < #s ? (s i @ c
                                       (? esc (g (i + 1) acc (64 <= c <= 126 && c != 91 ? 0 1))
                                          (c = 27) (g (i + 1) acc 1)
                                          (g (i + 1) (acc + string c) 0))) acc)) 0 "" 0)
   _ (cht-rm R)
   _ (mkdir R 493)

   ; --- mime: the head, encoded words, the transfer encodings, charsets ----------------------
   m1 ("From: =?utf-8?Q?Ren=C3=A9e?= <renee@x.org>\r\nTo: a@b.c, \"Doe, J\" <j@d.e>\r\n"
       + "Subject: =?iso-8859-1?q?caf=E9?= =?utf-8?B?IOKcqA==?=\r\n folded\r\n"
       + "Date: Thu, 30 Sep 2026 20:22:55 -0400\r\n"
       + "Content-Type: multipart/mixed; boundary=\"XX\"\r\n\r\npre\r\n--XX\r\n"
       + "Content-Type: multipart/alternative; boundary=YY\r\n\r\n--YY\r\n"
       + "Content-Type: text/plain; charset=utf-8\r\nContent-Transfer-Encoding: quoted-printable\r\n\r\n"
       + "hi =C3=A9 soft=\r\nbreak\r\n--YY\r\nContent-Type: text/html\r\n\r\n<p>hi</p>\r\n--YY--\r\n"
       + "--XX\r\nContent-Type: application/pdf; name=\"a.pdf\"\r\nContent-Transfer-Encoding: base64\r\n\r\n"
       + "aGVsbG8g\r\nd29ybGQ=\r\n--XX--\r\nepi\r\n")
   hs1 (mime-heads <(mime-split m1))
   _ (test ("café ✨ folded" = mime-words (mime-get hs1 "subject"))       ; two charsets, the gap dropped
           ([["" "a@b.c"] ["Doe, J" "j@d.e"]] = mime-addrs (mime-get hs1 "to"))  ; a comma inside quotes
           ([["Renée" "renee@x.org"]] = mime-addrs (mime-get hs1 "from"))
           ("" = mime-get hs1 "cc"))
   ; the date in its own zone, and the epoch it names
   _ (test ([1790814175 2026 9 30 20 22 -240] = mime-date (mime-get hs1 "date"))
           ([915530400 1999 1 5 10 0 0] = mime-date "5 Jan 99 10:00 GMT")
           !(mime-date "no date here"))
   ; the alternative keeps its plain text; the pdf comes decoded, named; pre and epi are dropped
   lv1 (mime-leaves m1)
   _ (test ([["text/plain" "hi é softbreak" ""] ["application/pdf" "hello world" "a.pdf"]]
            = map (l \ [(l 0) (l 3) (l 4)]) lv1))
   _ (test ("aGVsbG8gd29ybGQ=" = mime-b64e "hello world") ("ab" = mime-b64 (mime-b64e "ab"))
           ("a=b" = mime-qp "a=3Db") ("ab" = mime-qp "a=\nb") ("=zz" = mime-qp "=zz"))
   _ (test ("café" = mime-utf8 (string [99 97 102 233]) "iso-8859-1")
           ("“x”" = mime-utf8 (string [147 120 148]) "windows-1252")
           ("café" = mime-words (mime-head-enc "café")) ("plain" = mime-head-enc "plain"))
   _ (mime-ctype "text/plain; charset=\"utf-8\"; name*=utf-8''caf%C3%A9.txt" @ [t pm]
        (test ("text/plain" = t) ("utf-8" = pm "charset") ("café.txt" = pm "name")))

   ; --- a maildir: written, read in date order, its flags in the names, synced ---------------
   md (R + "/md")
   ma ("From: Ann <ann@x.org>\nTo: me@here.org\nSubject: lunch?\nMessage-ID: <a1@x>\n"
       + "Date: Mon, 28 Sep 2026 10:00:00 +0000\n\nshall we?\nFrom the start\n")
   mb ("From: Bob <bob@y.org>\nTo: ann@x.org, me@here.org\nCc: carol@z.org\nSubject: Re: lunch?\n"
       + "Message-ID: <b1@y>\nIn-Reply-To: <a1@x>\nReferences: <a1@x>\n"
       + "Date: Tue, 29 Sep 2026 10:00:00 +0000\n\nyes!\n> shall we?\n-- \nbob\n")
   mc ("From: =?utf-8?Q?Ren=C3=A9e?= <r@w.org>\nSubject: other " + string 27 + "[31mred\n"
       + "Date: Tue, 29 Sep 2026 09:00:00 +0000\nContent-Type: text/html\n\n<p>hello <b>there</b></p>\n")
   md2 ("From: Ann <ann@x.org>\nSubject: Re: lunch?\nMessage-ID: <a2@x>\nIn-Reply-To: <b1@y>\n"
        + "References: <a1@x> <b1@y>\nDate: Wed, 30 Sep 2026 10:00:00 +0000\n\nnoon\n")
   _ (test (1 = mb-append (md + "/") ma "S") (1 = mb-append md mb "") (1 = mb-append md mc "")
           (1 = mb-append md md2 "RS"))
   _ (test ('maildir = mb-kind md) (() = mb-kind (R + "/nothing")))
   b1 (mb-open md)
   _ (test (["lunch?" ("other " + string 27 + "[31mred") "Re: lunch?" "Re: lunch?"]
            = map (m \ mime-get (m 'hs) "subject") (b1 'msgs))
           (["S" "" "" "RS"] = map (m \ m 'flags) (b1 'msgs)))
   _ (test (ma = mb-raw b1 <(b1 'msgs)))                    ; a maildir keeps the bytes as sent
   _ (pin (b1 'msgs 1) 'del 1, pin (b1 'msgs 2) 'flags "FS")
   b2 (mb-sync b1)
   _ (test (3 = #(b2 'msgs)) (["S" "" "FS" "RS"] != map (m \ m 'flags) (b2 'msgs))
           (["S" "FS" "RS"] = map (m \ m 'flags) (b2 'msgs))
           !(any (m \ !(has? (m 'file) "/cur/")) (b2 'msgs)))  ; synced, the new are moved to cur

   ; --- an mbox: From lines quoted and unquoted, the flags in Status, rewritten whole --------
   mx (R + "/mbox")
   _ (test (1 = mb-append mx ma "") (1 = mb-append mx mb "S") ('mbox = mb-kind mx))
   x1 (mb-open mx)
   _ (test (2 = #(x1 'msgs)) (["" "S"] = map (m \ m 'flags) (x1 'msgs))
           (ma = mb-raw x1 <(x1 'msgs))                     ; ">From the start" read back as sent
           (has? (uread mx 1) "\n>From the start\n"))
   _ (pin <(x1 'msgs) 'flags "FRS", pin (x1 'msgs 1) 'del 1)
   x2 (mb-sync x1)
   _ (test (1 = #(x2 'msgs)) ("FRS" = <(x2 'msgs) 'flags)
           (has? (uread mx 1) "Status: RO\nX-Status: AF\n")
           (has? (mb-raw x2 <(x2 'msgs)) "shall we?\nFrom the start\n"))
   ; an mbox changed under the reader is not written over
   _ (pin <(x2 'msgs) 'del 1, mb-append mx md2 "")
   _ (test (string? (mb-sync x2)) (2 = #(mb-open mx 'msgs)))

   ; --- smtp: the wire and the url ------------------------------------------------------------
   _ (test ("..a\r\nb\r\n" = smtp-wire ".a\nb\n") ("x\r\n" = smtp-wire "x")
           ([1 "mail.x.org" 465] = smtp-url "smtps://me@mail.x.org")
           ([0 "h" 2525] = smtp-url "smtp://h:2525") ([0 "h" 587] = smtp-url "smtp://h/")
           !(smtp-url "imap://h"))

   ; --- imap: the url, and a response with a literal in it read as a tree ---------------------
   _ (test ([1 "me@x.org" "mail.x.org" 993 "Archive"] = imap-url "imaps://me%40x.org@mail.x.org/Archive")
           ([0 "" "h" 143 "INBOX"] = imap-url "imap://h") !(imap-url "smtp://h")
           ('imap = mb-kind "imaps://h/INBOX") ("\"a\\\\b\\\"\"" = imap-quote "a\\b\""))
   _ (test (["*" "3" "FETCH" ["UID" "5" "FLAGS" ["\\Seen" "\\Answered"] "BODY[HEADER]" "Subject: x\r\n\r\n"]]
            = imap-parse ["* 3 FETCH (UID 5 FLAGS (\\Seen \\Answered) BODY[HEADER]" ["Subject: x\r\n\r\n"] ")"])
           (["*" "OK" "[UIDVALIDITY 7]" "quo\"ted" ()] = imap-parse ["* OK [UIDVALIDITY 7] \"quo\\\"ted\" NIL"]))

   ; --- chucho: the threads, and the index -----------------------------------------------------
   mdc (R + "/mdc")
   _ (each [[ma "S"] [mb ""] [mc ""] [md2 "RS"]] (p \ mb-append (mdc + "/") (p 0) (p 1)))
   cfg {'from ["Me <me@here.org>"] 'sendmail [(R + "/sendmail.sh")] 'record [(R + "/sent")]}
   s (chucho-new (mb-open mdc) cfg)
   _ (test ([["lunch?" ""] ["Re: lunch?" "└─>"] ["Re: lunch?" "  └─>"] ["other ^[[31mred" ""]]
            = map (e \ [(e 0 'subj) (e 1)]) (s 'order))
           (1 = s 'cur))                                    ; the first new message
   f1 (chucho-frame s 90 12)
   rows1 (split "\r\n" f1)
   _ (test (has? f1 "└─>Re: lunch?") (has? f1 "Renée") !(has? f1 (string 27 + "[31mred"))
           (has? f1 "[Msgs:4 New:2 Del:0]---(threads)"))
   _ (each (take 11 rows1) (r \ test (90 = swidth (cht-plain r))))
   ; o reorders by date, and keeps the cursor on its message
   _ (chucho-key s 111, test (0 = s 'thr) ("other ^[[31mred" = s 'order 1 0 'subj) (2 = s 'cur))
   _ (chucho-key s 111, test (1 = s 'cur))
   ; d marks and moves on; u takes it back; N and F toggle
   _ (chucho-key s 100, test (1 = s 'order 1 0 'del) (2 = s 'cur))
   _ (chucho-key s 107, chucho-key s 117, test (0 = s 'order 1 0 'del))
   _ (chucho-key s 70, test (mb-has? (s 'order 1 0) 70))
   _ (chucho-key s 78, test !(mb-new? (s 'order 1 0)))
   _ (chucho-key s 78, test (mb-new? (s 'order 1 0)))
   ; / finds by subject or sender, n again
   _ (chucho-key s 47, each (chars "renee") (c \ chucho-key s c), chucho-key s 10, test (1 = s 'cur))
   _ (chucho-key s 47, chucho-key s 21, each (chars "rené") (c \ chucho-key s c), chucho-key s 10, test (3 = s 'cur))
   _ (chucho-key s 47, chucho-key s 21, each (chars "nobody") (c \ chucho-key s c), chucho-key s 10)
   _ (test (3 = s 'cur) (has? (s 'msg) "not found"))

   ; --- the pager: the headers in order, the body safe, html through lapiz, the end ------------
   _ (chucho-key s 61, chucho-key s 106, chucho-key s 10)
   _ (test ('pager = s 'view) !(mb-new? (s 'pm)) ("yes!" = cht-plain (s 'pl 6)))
   _ (test (["Date: Tue, 29 Sep 2026 10:00:00 +0000" "From: Bob <bob@y.org>" "To: ann@x.org, me@here.org"
             "Cc: carol@z.org" "Subject: Re: lunch?"] = map cht-plain (take 5 (s 'pl))))
   _ (test (has? (s 'pl 8) "-- ") (has? (s 'pl 8) "\e[2m"))                ; the signature dimmed
   _ (chucho-key s 106, chucho-key s 106, test ("other ^[[31mred" = s 'pm 'subj))
   _ (test (any (l \ has? l "hello \e[1mthere") (s 'pl))                 ; lapiz's own paint survives
           !(any (l \ has? l "\e[31m") (s 'pl)))                         ; a sender's does not
   _ (chucho-key s 104, test (any (l \ starts? (cht-plain l) "Content-Type: text/html") (s 'pl)))
   _ (chucho-key s 113, test ('index = s 'view))
   ; a long line wraps at a space, the pieces in order
   _ (test (["one two" "three"] = chucho-wrap "one two three" 9) (["abcdefgh" "ij"] = chucho-wrap "abcdefghij" 8))
   _ (test ("one     " = chucho-vis ("one" + string 9)) ("^A^?" = chucho-vis (string 1 + string 127)))

   ; --- drafts: reply, group reply, forward ---------------------------------------------------
   bob (s 'order 1 0)
   r1 (chucho-reply s bob 0)
   _ (test ("Bob <bob@y.org>" = mime-get (r1 'hs) "to") ("Re: lunch?" = mime-get (r1 'hs) "subject")
           ("" = mime-get (r1 'hs) "cc")
           ([["In-Reply-To" "<b1@y>"] ["References" "<a1@x> <b1@y>"]] = r1 'extra)
           (starts? (r1 'body) "On Sep 29 2026, Bob wrote:\n> yes!\n> > shall we?\n"))
   r2 (chucho-reply s bob 1)
   _ (test ("ann@x.org, carol@z.org" = mime-get (r2 'hs) "cc"))     ; me dropped from the group
   f2 (chucho-forward s bob)
   _ (test ("Fwd: Re: lunch?" = mime-get (f2 'hs) "subject") ("" = mime-get (f2 'hs) "to")
           (has? (f2 'body) "----- Forwarded message from Bob <bob@y.org> -----")
           (has? (f2 'body) "Cc: carol@z.org"))
   ; r leaves the editor to the runner, as an act
   _ (chucho-key s 61, chucho-key s 106, chucho-key s 114, test ('compose = <(s 'act)) ("Re: lunch?" = mime-get (s 'act 1 'hs) "subject"))
   _ (pin s 'act ())

   ; --- a message built: headers encoded, bcc kept off, an attachment, and sent -----------------
   _ (uwrite (R + "/att.txt") "attached\n")
   d1 (pins (chucho-draft s "Zoë <zoe@x.org>, dan@x.org" "" "héllo" "a body\n" () "")
            'atts [(R + "/att.txt")])
   _ (pin d1 'hs (map (h \ <h = "bcc" ? ["bcc" "hid@x.org"] h) (d1 'hs)))
   b3 (chucho-build s d1)
   _ (b3 @ [raw rc who]
        (: h (mime-heads <(mime-split raw))
           (test (["zoe@x.org" "dan@x.org" "hid@x.org"] = rc) ("me@here.org" = who)
                 ("=?utf-8?B?Wm/Dqw==?= <zoe@x.org>, dan@x.org" = mime-get h "to")
                 ("héllo" = mime-words (mime-get h "subject"))
                 ("" = mime-get h "bcc") (has? (mime-get h "message-id") "@here.org>")
                 ([["text/plain" "a body\n" ""] ["text/plain" "attached\n" "att.txt"]]
                  = map (l \ [(l 0) (l 3) (l 4)]) (mime-leaves raw)))))
   _ (test ("no recipients" = chucho-build s (chucho-draft s "" "" "x" "y" () "")))
   ; handed to a sendmail that keeps what it is given; filed in the record; the reply marked
   _ (uwrite (R + "/sendmail.sh") ("#!/bin/sh\necho \"$@\" > " + R + "/args\ncat > " + R + "/got\n"),
      chmod (R + "/sendmail.sh") 493)
   d2 (chucho-reply s bob 0)
   _ (pins s 'draft d2 'view 'compose)
   _ (chucho-key s 121, test (['send] = s 'act))
   _ (pin s 'act (), ch-send-now s)
   _ (test ("Mail sent." = s 'msg) ('index = s 'view) (mb-has? bob 82)
           ("-oi -f me@here.org -- bob@y.org\n" = uread (R + "/args") 1)
           (has? (uread (R + "/got") 1) "In-Reply-To: <b1@y>")
           (1 = #(mb-open (R + "/sent") 'msgs)) (mb-has? <(mb-open (R + "/sent") 'msgs) 83))

   ; --- q asks before it purges, with one key ---------------------------------------------------
   s2 (chucho-new (mb-open mdc) cfg)
   _ (chucho-key s2 100, chucho-key s2 113)
   _ (test (has? (s2 'prompt 0) "Purge 1 deleted") (0 = s2 'over))
   _ (chucho-key s2 110, test (1 = s2 'over) (4 = #(mb-open mdc 'msgs)))   ; n keeps it
   s3 (chucho-new (mb-open mdc) cfg)
   _ (chucho-key s3 100, chucho-key s3 113, chucho-key s3 121)
   (test (1 = s3 'over) (3 = #(mb-open mdc 'msgs)),
    cht-rm R,
    test_fin ()))
(puts "chucho: ok -- mime's decodings, a maildir and an mbox round trip, the threads, the index and pager frames, the keys, and a reply built and sent\n")
