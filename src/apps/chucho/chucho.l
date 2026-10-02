; chucho -- a mail reader after mutt's manner: a mailbox as an index, threaded, a message in the
; pager, mail written in your editor and handed to sendmail or an SMTP server.
;
;   index  j k / arrows  move      enter  read          d u  delete, undelete
;          ^f ^b         a page    = *    the ends      N F  new, flagged
;          r g f m       reply, group reply, forward, mail
;          s C           save (and delete), copy        c  another mailbox
;          / n           search                          o  threads or dates
;          $             write the changes               q x  quit, quit unwritten
;   pager  space -       a page    enter up/down  a line   j k  the next, previous message
;          h             all the headers                 v  the parts, to save
;          q i           back to the index
;   compose  y send   e edit   a attach   D drop the last   q abandon
;
; the settings are salt's (src/apps/libra/salt.l), ~/.love/etc/chucho.l:
;   (from "Your Name <you@example.org>")    (spool "~/Maildir")    (folder "~/Mail")
;   (record "=sent")    (sendmail "/usr/sbin/sendmail")    (smtp "smtps://you@mail.example.org")
;   (smtp-user "you")   (smtp-pass-cmd "pass show mail")    (editor "vi")    (signature "~/.sig")
;   (alternates "you@old.example.org")    (spool "imaps://you@mail.example.org/INBOX")
;   (imap-user "you")   (imap-pass-cmd "pass show mail")
;
; every key is a pure step on the state, and every frame a pure lay; what wants the tty --
; the editor, the send -- the step leaves as 'act and the runner performs. so the tool gates
; headless; only chucho-run ties the tty.
; usage: love chucho [-f MAILBOX]
;        love chucho [-s SUBJECT] [-c CC] [-a FILE].. ADDRESS..   (the body on stdin, or edited)
(module (chucho chucho-main chucho-run chucho-new chucho-key chucho-frame chucho-order
         chucho-render chucho-reply chucho-forward chucho-build chucho-draft chucho-send
         chucho-thread chucho-vis chucho-wrap chucho-rfcdate ch-send-now)
(borrow 'posix)
(borrow 'tui)
(borrow 'cal)
(borrow 'text)
(borrow 'mime)
(borrow 'mailbox)
(borrow 'smtp)
(borrow 'imap)
(:
 ch-esc (string 27)
 ch-hdrs ["date" "from" "to" "cc" "subject"]
 ch-help ["index" "  j k  up down     the cursor          enter    read the message"
          "  ^f ^b  space -   a page              = *      the first, the last"
          "  d u              delete, undelete    N F      toggle new, flagged"
          "  r g f m          reply, group, forward, mail"
          "  s C              save and delete, copy to a mailbox"
          "  c                change mailbox      / n      search, again"
          "  o                threads or dates    $        write the changes"
          "  q x              quit, quit without writing      ?  this"
          "" "pager"
          "  space -          a page              enter up down   a line"
          "  j k              next, previous      h        all headers"
          "  v                the parts           q i      the index"
          "" "compose"
          "  y send   e edit   a attach   D drop the last attachment   q abandon"]

 ; --- text for the screen -------------------------------------------------------------------
 ; a line with its control bytes shown as ^X and its tabs laid to stops of 8: no escape a
 ; sender wrote reaches the terminal
 (chucho-vis l)
  (: j (jug 0) n #l
     (go i col)
      (n <= i ? (slurp j)
         (l i @ c
            (? (c = 9) (8 - col % 8 @ k (say j (edfit "" k " "), go (i + 1) (col + k)))
               (c = 13) (go (i + 1) col)
               (c < 32 || c = 127) (say j ("^" + string (c = 127 ? 63 (c + 64))), go (i + 1) (col + 2))
               (put j c, go (i + 1) (col + (128 <= c < 192 ? 0 1))))))
     (go 0 0))
 ; a long line broken at a space where one falls in the second half, else hard
 (chucho-wrap l w)
  (? (w < 8 || swidth l <= w) [l]
     (: h (scut l w)
        (sp i) (? (i < #h // 2) -1 (h i = 32) i (sp (i - 1)))
        k (sp (#h - 1))
        (? (0 < k) ((snip l 0 k) . chucho-wrap (snip l (k + 1) #l) w)
           (#h < 1) [l]
           (h . chucho-wrap (snip l #h #l) w))))
 ; the escapes out of a string: what lapiz paints, unpainted for quoting
 (ch-plain s)
  (: j (jug 0) n #s
     (go i esc)
      (n <= i ? (slurp j)
         (s i @ c
            (? esc (go (i + 1) (64 <= c <= 126 && c != 91 ? 0 1))
               (c = 27) (go (i + 1) 1)
               (put j c, go (i + 1) 0))))
     (go 0 0))
 (ch-noctl s) (string (filter (c \ c = 10 || c = 9 || 31 < c && c != 127) (chars s)))

 ; --- settings --------------------------------------------------------------------------------
 (ch-home _) (getenv "HOME" @ h (string? h ? h ""))
 (ch-short p) (ch-home 0 @ h (#h && starts? p h ? ("~" + snip p #h #p) p))
 (ch-cfg s k d) (s 'cfg k @ v (two? v ? (show-or <v) d))
 (show-or v) (string? v ? v (show v))
 ; ~ is home, = and + the folder
 (ch-path s p)
  (? (#p < 1) p
     (p 0 = 126) (ch-home 0 + snip p 1 #p)
     (p 0 = 61 || p 0 = 43) (ch-path s (ch-cfg s 'folder "~/Mail") + "/" + snip p 1 #p)
     p)
 (ch-me s)
  (: f (ch-cfg s 'from "")
     a (mime-addrs f)
     (two? a ? (a 0 1) (show-or (getenv "USER") + "@" + (uname 0 @ u (two? u ? (u 1) "localhost")))))
 (ch-mine? s a)
  (: x (lower a)
     (x = lower (ch-me s) || any (y \ lower y = x) (words (ch-cfg s 'alternates ""))))

 ; --- a message's fields, read once ------------------------------------------------------------
 (ch-ids v) (: (go i acc)
                (fsub v "<" i @ a
                   (a < 0 ? (rev acc)
                      (fsub v ">" a @ b (b < 0 ? (rev acc) (go (b + 1) ((snip v a (b + 1)) . acc))))))
               (go 0 ()))
 (ch-prep m)
  (? (m 'prep) m
     (: hs (m 'hs)
        fr (mime-addrs (mime-get hs "from"))
        (pins m 'prep 1
                'subj (chucho-vis (mime-words (mime-get hs "subject")))
                'who (two? fr ? (fr 0 @ [n a] (#n ? n a)) "")
                'fromaddr (two? fr ? (fr 0 1) "")
                'mid <(ch-ids (mime-get hs "message-id"))
                'refs (ch-ids (mime-get hs "references") @ rs
                         (rs + filter (x \ !(elem x rs)) (ch-ids (mime-get hs "in-reply-to")))))))
 (ch-base-subj s)
  (: l (lower s)
     (? (starts? l "re:" || starts? l "fw:") (ch-base-subj (strip (snip s 3 #s)))
        (starts? l "fwd:") (ch-base-subj (strip (snip s 4 #s)))
        s))

 ; --- threads: a parent is the last reference this box holds ----------------------------------
 ; -> [[msg prefix] ..], each thread under its first message, the threads by date
 (chucho-thread ms)
  (: ids (foldl (t \ m \ string? (m 'mid) ? (pin t (m 'mid) m) t) {} ms)
     (parent m) (: (go l) (? (atom? l) ()
                              (ids <l @ p (tablet? p && p 'ix != m 'ix ? p (go >l))))
                   (go (rev (m 'refs))))
     kids (foldl (t \ m \ parent m @ p (tablet? p ? (pin t (p 'mid) (t (p 'mid) + [m])) t)) {} ms)
     seen {}
     by (a \ b \ a 'date <= b 'date)
     (walk m pre last? top? acc)
      (? (seen (m 'ix)) acc
         (: _ (pin seen (m 'ix) 1)
            me (top? ? "" (pre + (last? ? "\xe2\x94\x94\xe2\x94\x80>" "\xe2\x94\x9c\xe2\x94\x80>")))
            down (top? ? "" (pre + (last? ? "  " "\xe2\x94\x82 ")))
            ks (sortby by (string? (m 'mid) ? (kids (m 'mid) @ k (two? k ? k ())) ()))
            (go l a) (l @ [k] (walk k down 1 0 a) (k . r) (go r (walk k down 0 0 a)) a)
            (go ks ([m me] . acc))))
     roots (sortby by (filter (m \ !(tablet? (parent m))) ms))
     out (foldl (a \ m \ walk m "" 1 1 a) () roots)
     ; a cycle in the references leaves its messages unreached: they stand as threads
     rest (filter (m \ !(seen (m 'ix))) ms)
     (rev (foldl (a \ m \ walk m "" 1 1 a) out rest)))

 ; --- the state ------------------------------------------------------------------------------
 (chucho-new b cfg)
  (: s (pins {} 'box b 'cfg cfg 'view 'index 'cur 0 'top 0 'rows 20 'w 80 'msg ""
             'thr 1 'order () 'over 0 'act () 'prompt () 'full 0 'pl () 'ptop 0 'pm ()
             'find "" 'draft () 'pass ())
     (chucho-order s,
      (s 'order @ o (pin s 'cur (ch-first o))),
      s))
 ; the cursor starts on the first new message, else the last
 (ch-first o) (: (go l i) (? (atom? l) (max 0 (#o - 1)) (mb-new? (<l 0)) i (go >l (i + 1))) (go o 0))
 (chucho-order s)
  (: ms (map (k \ s 'box 'msgs k @ m (ch-prep m, pin m 'ix k)) ^#(s 'box 'msgs))
     old (ch-at s)
     o (s 'thr ? (chucho-thread ms) (map (m \ [m ""]) (sortby (a \ b \ a 'date <= b 'date) ms)))
     (pin s 'order o,
      (tablet? old ? (: (go l i) (? (atom? l) 0 (<l 0 'ix = old 'ix) (pin s 'cur i) (go >l (i + 1))) (go o 0)) 0),
      pin s 'cur (max 0 (min (s 'cur) (#o - 1)))))
 (ch-at s) (s 'order @ o (two? o ? (drop (s 'cur) o @ l (two? l ? <(<l))) ()))
 (ch-goto s i)
  (: n #(s 'order) c (max 0 (min i (n - 1)))
     (pins s 'cur c 'top (max 0 (tui-settle c (s 'top) (s 'rows)))))
 (ch-say s m) (pin s 'msg m)
 (ch-count s f) (#(filter f (s 'box 'msgs)))

 ; --- the pager's text ------------------------------------------------------------------------
 (ch-hl name v) (ch-esc + "[1m" + name + ":" + ch-esc + "[0m " + v)
 (ch-cap n) (join "-" (map (p \ #p ? (upper (snip p 0 1) + snip p 1 #p) p) (split "-" n)))
 ; a leaf as lines: text as text, html through lapiz, anything else named
 ; a leaf as [lines painted?]: text as text, html through lapiz (fed no control byte, so its
 ; paint is its own), anything else no lines
 (ch-leaf l w)
  (l @ [t pm hs body nm]
     (: cs (pm "charset")
        u (ch-noctl (mime-utf8 body (string? cs ? cs "us-ascii")))
        (? (starts? (lower (mime-get hs "content-disposition")) "attachment") [() 0]
           (elem t ["text/plain" "message/delivery-status" "text/x-diff" "message/rfc822"]) [(lines u) 0]
           (t = "text/html")
            (cite 'lapiz 'ht->tty u (max 20 (w - 1)) @ r (string? r ? [(lines r) 1] [(lines u) 0]))
           [() 0]))
     [() 0])
 (ch-leaf-text l w) (ch-leaf l w @ [ls _] (map ch-plain ls) ())
 (ch-tag l i)
  (l @ [t pm hs body nm]
     (ch-esc + "[35m[-- " + show (i + 1) + ": " + (#nm ? (chucho-vis nm + ", ") "") + t + ", "
      + ch-size #body + " --]" + ch-esc + "[0m")
     "")
 (ch-shown? l) (l @ [t pm hs body nm] (? (starts? (lower (mime-get hs "content-disposition")) "attachment") 0
                                         (elem t ["text/plain" "text/html" "message/rfc822" "message/delivery-status" "text/x-diff"]) 1
                                         0) 0)
 ; a body line painted: a quote by depth, a signature dim
 (ch-paint l sig?)
  (: d (: (go i k) (? (#l <= i) k (l i = 62) (go (i + 1) (k + 1)) (l i = 32) (go (i + 1) k) k) (go 0 0))
     (? sig? (ch-esc + "[2m" + l + ch-esc + "[0m")
        (0 < d) (ch-esc + (d % 2 ? "[36m" "[33m") + l + ch-esc + "[0m")
        l))
 ; a header wrapped plain, then its name made bold
 (ch-hdr-lines n v w)
  (chucho-wrap (n + ": " + v) w @ (x . r)
     ((ch-esc + "[1m" + snip x 0 (#n + 1) + ch-esc + "[0m" + snip x (#n + 1) #x) . r)
     [])
 (chucho-render s m w)
  (: raw (mb-raw (s 'box) m)
     hs (mime-heads <(mime-split raw))
     shown (? (s 'full) hs (catmap (n \ filter (h \ <h = n) hs) ch-hdrs))
     hl (catmap (h \ ch-hdr-lines (ch-cap <h) (chucho-vis (mime-words (h 1))) w) shown)
     ; the body lines, reversed: a plain line shown safe, wrapped and painted; a signature
     ; runs from its "-- " line to the leaf's end
     (plain xs sg out)
      (xs @ (x . r) (chucho-vis x @ v
                       (: sg2 (sg || v = "-- ")
                          (plain r sg2 (rev (map (p \ ch-paint p sg2) (chucho-wrap v w)) + out))))
            out)
     (body l i acc)
      (? (atom? l) acc
         (ch-leaf <l w @ [ls html?]
            (: tag (ch-shown? <l ? () [(ch-tag <l i)])
               acc2 (rev tag + acc)
               (body >l (i + 1) (html? ? (rev ls + acc2) (plain ls 0 acc2))))))
     (hl + [""] + rev (body (mime-leaves raw) 0 ())))

 ; --- the frame -------------------------------------------------------------------------------
 ; a month and day: [m d], or a day's secs
 (ch-day v) (? (two? v) (mon3 (v 0 - 1) + " " + zpad 2 (show (v 1))) (civil (v // 86400) @ [_ m d] (ch-day [m d]) ""))
 (ch-size n)
  (? (n < 1000) (show n)
     (n < 10240) (show (n // 1024) + "." + show (n % 1024 * 10 // 1024) + "K")
     (n < 1048576) (show (n // 1024) + "K")
     (show (n // 1048576) + "M"))
 (ch-flags m)
  ((m 'del ? "D" (mb-new? m ? "N" (mb-has? m 82 ? "r" " "))) + (mb-has? m 70 ? "!" " "))
 (ch-irow s e i w sel?)
  (e @ [m pre]
     (: who (ch-mine? s (m 'fromaddr) && #(mime-get (m 'hs) "to")
                ? ("To " + (mime-addrs (mime-get (m 'hs) "to") @ ((n a) . _) (#n ? n a) ""))
                (m 'who))
        sz ("(" + ch-size (m 'size) + ")")
        head (edfit "" (4 - #(show (i + 1))) " " + show (i + 1))
        txt (head + " " + ch-flags m + " " + ch-day (m 'day) + "  " + edfit (chucho-vis who) 18 " "
             + " " + edfit "" (7 - #sz) " " + sz + " " + pre + m 'subj)
        row (edfit txt w " ")
        (? sel? (ch-esc + "[7m" + row + ch-esc + "[0m")
           (m 'del) (ch-esc + "[31m" + row + ch-esc + "[0m")
           (mb-has? m 70) (ch-esc + "[33m" + row + ch-esc + "[0m")
           (mb-new? m) (ch-esc + "[1m" + row + ch-esc + "[0m")
           row))
     (edfit "" w " "))
 (ch-bar w t) (ch-esc + "[7m" + edfit t w " " + ch-esc + "[0m")
 ch-ikeys " q:Quit  d:Del  u:Undel  s:Save  m:Mail  r:Reply  g:Group  f:Fwd  ?:Help"
 ch-pkeys " i:Exit  -:PrevPg  <Space>:NextPg  v:View Attachm.  d:Del  r:Reply  j:Next  ?:Help"
 ch-vkeys " s:Save to a file  j k:Move  q:Back to the message"
 ch-ckeys " y:Send  e:Edit  a:Attach  D:Drop attachment  q:Abort  ?:Help"
 (ch-pbody s n w)
  (: pl (s 'pl) t (s 'ptop) (map (k \ drop (t + k) pl @ l (two? l ? <l "")) ^n))
 (ch-cbody s n w)
  (: d (s 'draft) hs (d 'hs)
     (row nm) ("    " + ch-cap nm + ": " + chucho-vis (mime-get hs nm))
     as (d 'atts)
     ls (map row ["from" "to" "cc" "bcc" "subject"] + [""]
         + (two? as ? ["-- Attachments"] [])
         + map (a \ "    " + a) as)
     (map (k \ drop k ls @ l (two? l ? (edfit <l w " ") "")) ^n))
 (ch-ibody s n w)
  (: o (s 'order) t (s 'top)
     (map (k \ drop (t + k) o @ l (two? l ? (ch-irow s <l (t + k) w (t + k = s 'cur)) (edfit "" w " "))) ^n))
 (ch-status s w)
  (: b (s 'box) v (s 'view)
     (? (v = 'pager)
         (: n #(s 'pl) r (s 'rows) t (s 'ptop)
            pc (n <= r ? "all" (t + r >= n ? "end" (show (100 * (t + r) // n) + "%")))
            ("-- chucho: " + (s 'pm 'subj) + "  -- (" + pc + ")"))
        (v = 'compose) "-- chucho: compose"
        (v = 'help) "-- chucho: help"
        (v = 'parts) "-- chucho: the parts"
        ("-*-chucho: " + ch-short (b 'path) + " [Msgs:" + show #(b 'msgs) + " New:" + show (ch-count s mb-new?)
         + " Del:" + show (ch-count s (m \ m 'del)) + "]---(" + (s 'thr ? "threads" "date") + ")")))
 (ch-parts-body s n w)
  (: lv (s 'parts) c (s 'pcur)
     (map (k \ drop k lv @ l (two? l ? (ch-tag <l k @ t (k = c ? (ch-esc + "[7m" + edfit (ch-plain t) w " " + ch-esc + "[0m") t)) "")) ^n))
 (chucho-frame s w h)
  (: n (max 1 (h - 3))
     _ (pins s 'rows n 'w w)
     v (s 'view)
     top (? (v = 'pager) ch-pkeys (v = 'compose) ch-ckeys (v = 'parts) ch-vkeys ch-ikeys)
     body (? (v = 'pager || v = 'help) (ch-pbody s n w)
             (v = 'compose) (ch-cbody s n w)
             (v = 'parts) (ch-parts-body s n w)
             (ch-ibody s n w))
     rows ([(ch-bar w top)] + body + [(ch-bar w (ch-status s w))])
     p (s 'prompt)
     stat (two? p ? (p 0 + (p 2 = 1 ? (edfit "" (swidth (p 1)) "*") (p 1))) (s 'msg))
     cc (min w (1 + swidth (ch-plain stat)))
     (? (two? p) (tui-fresh s h [w h v] () rows (edfit stat w " ") h cc + ch-esc + "[?25h")
        (ch-esc + "[?25l" + tui-fresh s h [w h v] () rows (edfit stat w " ") h 1)))

 ; --- prompts: a line typed at the bottom, then handed on ------------------------------------
 ; 'prompt is [label text how then], then a step (s text) -> s; how is 0, 1 for a
 ; password's stars, or 'key for an answer of one key
 (ch-ask s label init hid then) (pin s 'prompt [label init hid then])
 (ch-pkey s c)
  (s 'prompt @ [label t hid then]
     (? (hid = 'key && c != 27 && c != 7) (pin s 'prompt (), then s (string (max 0 c)))
        (c = 10 || c = 13) (pin s 'prompt (), then s t)
        (c = 27 || c = 7) (pins s 'prompt () 'msg "")
        (c = 127 || c = 8) (pin s 'prompt [label (#t ? (cpsnip t 0 (cplen t - 1)) t) hid then])
        (c = 21) (pin s 'prompt [label "" hid then])
        (31 < c && c < 256) (pin s 'prompt [label (t + string c) hid then])
        s)
     s)
 ; a yes or no, read off the first letter
 (ch-yes? t) (#t && (t 0 = 121 || t 0 = 89))

 ; --- the index's steps -------------------------------------------------------------------------
 (ch-move s d) (ch-goto s (s 'cur + d))
 (ch-next-live s)
  (: o (s 'order)
     (go i) (? (#o <= i) (s 'cur) (o i 0 'del) (go (i + 1)) i)
     (ch-goto s (go (s 'cur + 1))))
 (ch-open s m)
  (? !(tablet? m) (ch-say s "no message here")
     (: _ (mb-has? m 83 ? 0 (pin m 'flags (mb-flag (m 'flags) 83 1)))
        (pins s 'view 'pager 'pm m 'ptop 0 'pl (chucho-render s m (s 'w)) 'msg "")))
 (ch-mark s f)
  (ch-at s @ m (tablet? m ? (f m, s) (ch-say s "no message here")))
 (ch-find s t from)
  (: o (s 'order) q (lower t)
     (hit? m) (has? (lower (m 'subj + " " + m 'who + " " + m 'fromaddr)) q)
     (go k) (? (#o <= k) () (hit? <(o ((from + k) % #o))) ((from + k) % #o) (go (k + 1)))
     (? (#q < 1) (ch-say s "no search yet")
        (go 1 @ i (charm? i ? (ch-goto s i, ch-say s "") (ch-say s ("not found: " + t))))))
 (ch-save s del?)
  (ch-at s @ m
     (? !(tablet? m) (ch-say s "no message here")
        (ch-ask s (del? ? "Save to mailbox: " "Copy to mailbox: ")
                ("=" + (findsub (m 'fromaddr) "@" @ k (k < 0 ? (m 'fromaddr) (snip (m 'fromaddr) 0 k)))) 0
                (s \ t \ (: p (ch-path s t)
                            r (ch-append s p (mb-raw (s 'box) m) (mb-flag (m 'flags) 83 1))
                            (? (r = 1) ((del? ? (pin m 'del 1) 0), ch-say s ((del? ? "saved to " "copied to ") + t))
                               (ch-say s r)))))))
 (ch-sync s)
  (: r (mb-sync (s 'box))
     (? (string? r) (ch-say s r)
        (: n #(s 'box 'msgs) (pin s 'box r, chucho-order s, ch-goto s (s 'cur),
                               ch-say s ("written; " + show #(r 'msgs) + " kept")))))
 (ch-dirty? s) (any (m \ m 'del || m 'flags != m 'flags0) (s 'box 'msgs))
 (ch-quit s)
  (? (ch-count s (m \ m 'del) = 0) ((ch-dirty? s ? (ch-sync s) s), pin s 'over 1)
     (ch-ask s ("Purge " + show (ch-count s (m \ m 'del)) + " deleted messages? (y/n) ") "" 'key
             (s \ t \ ((ch-yes? t ? (ch-sync s) (each (s 'box 'msgs) (m \ pin m 'del 0), ch-sync s)), pin s 'over 1))))
 ; --- opening a box: an imap one with its password -- set, a command's, or asked for -------
 (ch-imap-user s p) (imap-url p @ u (two? u && #(u 1) ? (u 1) (ch-cfg s 'imap-user (show-or (getenv "USER")))))
 (ch-imap-pass s)
  (? (string? (s 'ipass)) (s 'ipass)
     #(ch-cfg s 'imap-pass "") (ch-cfg s 'imap-pass "")
     #(ch-cfg s 'imap-pass-cmd "") (ch-pass-cmd (ch-cfg s 'imap-pass-cmd ""))
     ())
 ; p opened and handed to k as (k s box); a refusal is said
 (ch-openbox s p k)
  (? (mb-kind p = 'imap)
      (ch-imap-pass s @ pw
         (? (string? pw)
             (ch-say s ("opening " + p + " ..."),
              imap-open p (ch-imap-user s p) pw @ b (string? b ? (pin s 'ipass (), ch-say s b) (pin s 'ipass pw, k s b)))
            (ch-ask s ("Password for " + ch-imap-user s p + ": ") "" 1 (s \ t \ (pin s 'ipass t, ch-openbox s p k)))))
     (mb-open p @ b (string? b ? (ch-say s b) (k s b))))
 (ch-install s b)
  ((s 'box 'kind = 'imap ? (imap-close (s 'box)) 0),
   pins s 'box b 'cur 0 'top 0, chucho-order s,
   (s 'order @ o (ch-goto s (ch-first o))), ch-say s "")
 ; a message onto the box at p: an imap one logs in for it
 (ch-append s p raw fl)
  (? (mb-kind p = 'imap) (imap-append p (ch-imap-user s p) (show-or (ch-imap-pass s)) raw fl)
     (mb-append p raw fl))
 (ch-change s)
  (ch-ask s "Open mailbox: " "" 0
          (s \ t \ ((ch-dirty? s ? (mb-sync (s 'box)) 0), ch-openbox s (ch-path s t) ch-install)))
 (chucho-key s c)
  (? (two? (s 'prompt)) (ch-pkey s c)
     (s 'view = 'pager) (ch-pager-key s c)
     (s 'view = 'help) (ch-pager-key s c)
     (s 'view = 'compose) (ch-compose-key s c)
     (s 'view = 'parts) (ch-parts-key s c)
     (ch-index-key s c))
 (ch-index-key s c)
  (: n (s 'rows) m (ch-at s)
     (c @- s
      (-9 || 106 || 14) (ch-move s 1)
      (-8 || 107 || 16) (ch-move s -1)
      (6 || 32 || -6) (ch-move s n)
      (2 || 45) (ch-move s (0 - n))
      (61 || -5) (ch-goto s 0)
      42 (ch-goto s #(s 'order))
      (10 || 13) (ch-open s m)
      100 (ch-mark s (m \ pin m 'del 1), ch-next-live s)
      117 (ch-mark s (m \ pin m 'del 0))
      78 (ch-mark s (m \ pin m 'flags (mb-flag (m 'flags) 83 (mb-new? m))))
      70 (ch-mark s (m \ pin m 'flags (mb-flag (m 'flags) 70 !(mb-has? m 70))))
      111 (pin s 'thr (s 'thr ? 0 1), chucho-order s, ch-goto s (s 'cur))
      47 (ch-ask s "Search for: " (s 'find) 0 (s \ t \ (pin s 'find t, ch-find s t (s 'cur))))
      110 (ch-find s (s 'find) (s 'cur))
      115 (ch-save s 1)
      67 (ch-save s 0)
      99 (ch-change s)
      36 (ch-sync s)
      12 (pin s 'lastr (), s)
      63 (pins s 'view 'help 'pl ch-help 'ptop 0 'back 'index)
      109 (pin s 'act ['compose (chucho-draft s "" "" "" "" () "")])
      114 (ch-reply s m 0)
      103 (ch-reply s m 1)
      102 (ch-fwd s m)
      (113 || -7) (ch-quit s)
      120 (pin s 'over 1)))
 (ch-reply s m all?)
  (? (tablet? m) (pin s 'act ['compose (chucho-reply s m all?)]) (ch-say s "no message here"))
 (ch-fwd s m)
  (? (tablet? m) (pin s 'act ['compose (chucho-forward s m)]) (ch-say s "no message here"))
 (ch-pager-key s c)
  (: n (s 'rows) t (s 'ptop) len #(s 'pl)
     (to k) (pin s 'ptop (max 0 (min k (len - 1))))
     help? (s 'view = 'help)
     (c @- s
      (32 || 6 || -2) (t + n < len ? (to (t + n)) (help? ? s (ch-say s "the end of the message")))
      (45 || 2 || -1) (to (t - n))
      (10 || 13 || -9) (to (t + 1))
      (-8 || 8 || 127) (to (t - 1))
      (-5 || 60) (to 0)
      (-6 || 62) (to (len - n))
      (113 || 105 || -7) (pins s 'view (help? ? (s 'back) 'index) 'msg "")
      106 (help? ? s (ch-move s 1, ch-open s (ch-at s)))
      107 (help? ? s (ch-move s -1, ch-open s (ch-at s)))
      104 (help? ? s (pin s 'full (s 'full ? 0 1), pins s 'pl (chucho-render s (s 'pm) (s 'w)) 'ptop 0))
      100 (help? ? s (pin (s 'pm) 'del 1, ch-next-live s, ch-open s (ch-at s)))
      118 (help? ? s (pins s 'view 'parts 'parts (mime-leaves (mb-raw (s 'box) (s 'pm))) 'pcur 0))
      114 (help? ? s (ch-reply s (s 'pm) 0))
      103 (help? ? s (ch-reply s (s 'pm) 1))
      102 (help? ? s (ch-fwd s (s 'pm)))
      63 (help? ? s (pins s 'view 'help 'pl ch-help 'ptop 0 'back 'pager 'opl (s 'pl)))))
 (ch-parts-key s c)
  (: lv (s 'parts) k (s 'pcur)
     (c @- s
      (-9 || 106) (pin s 'pcur (min (#lv - 1) (k + 1)))
      (-8 || 107) (pin s 'pcur (max 0 (k - 1)))
      (10 || 13 || 115)
       (drop k lv @ l
          (two? l ? (<l @ [t pm hs body nm]
                       (ch-ask s "Save to file: " ("~/" + (#nm ? nm "part")) 0
                               (s \ p \ (uwrite (ch-path s p) body ? (ch-say s ("saved " + p)) (ch-say s ("cannot write " + p))))))
             s))
      (113 || 105 || -7) (pins s 'view 'pager 'msg "")))

 ; --- drafts ----------------------------------------------------------------------------------
 ; a draft: 'hs the headers as edited, 'body, 'atts the files, 'extra the threading headers,
 ; 'reply the message answered
 (chucho-draft s to cc subj body extra quote)
  (: sig (ch-cfg s 'signature "")
     st (#sig ? (uread (ch-path s sig)) ())
     tail (two? st ? ("\n-- \n" + st 1) "")
     (pins {} 'hs [["from" (ch-cfg s 'from (ch-me s))] ["to" to] ["cc" cc] ["bcc" ""] ["subject" subj]]
              'body (quote + body + tail) 'atts () 'extra extra 'reply ()))
 (ch-quote-text s m)
  (: lv (mime-leaves (mb-raw (s 'box) m))
     ts (catmap (l \ ch-shown? l ? (ch-leaf-text l 72) ()) lv)
     (join "\n" (map (l \ #l ? ("> " + l) ">") ts) + "\n"))
 (ch-addrs-str as) (join ", " (map (a \ a @ [n x] (#n ? (n + " <" + x + ">") x)) as))
 (chucho-reply s m all?)
  (: hs (m 'hs)
     rt (mime-get hs "reply-to")
     to0 (mime-addrs (#rt ? rt (mime-get hs "from")))
     to (? (all? && ch-mine? s (m 'fromaddr)) (mime-addrs (mime-get hs "to")) to0)
     cc (? all? (filter (a \ !(ch-mine? s (a 1)) && !(any (b \ lower (b 1) = lower (a 1)) to))
                         (mime-addrs (mime-get hs "to") + mime-addrs (mime-get hs "cc")))
           ())
     subj (mime-words (mime-get hs "subject") @ x (ch-base-subj x @ b ("Re: " + b)))
     mid (m 'mid)
     refs (string? mid ? (m 'refs + [mid]) (m 'refs))
     d (mime-date (mime-get hs "date"))
     when (two? d ? (ch-day [(d 2) (d 3)] + " " + show (d 1)) "")
     intro ("On " + when + ", " + m 'who + " wrote:\n")
     dr (chucho-draft s (ch-addrs-str to) (ch-addrs-str cc) subj (intro + ch-quote-text s m)
                      (string? mid ? [["In-Reply-To" mid] ["References" (join " " refs)]] ()) "")
     (pin dr 'reply m, dr))
 (chucho-forward s m)
  (: hs (m 'hs)
     subj ("Fwd: " + mime-words (mime-get hs "subject"))
     (h n) (mime-get hs n @ v (#v ? [(ch-cap n + ": " + mime-words v)] ()))
     txt (join "\n" (catmap (l \ ch-shown? l ? (ch-leaf-text l 72) ()) (mime-leaves (mb-raw (s 'box) m))))
     body ("\n----- Forwarded message from " + m 'who + " <" + m 'fromaddr + "> -----\n\n"
           + join "\n" (h "date" + h "from" + h "to" + h "cc" + h "subject") + "\n\n" + txt
           + "\n\n----- End forwarded message -----\n")
     (chucho-draft s "" "" subj body () ""))
 ; the draft as the editor sees it, and read back
 (ch-draft-text d)
  (join "" (map (h \ ch-cap <h + ": " + h 1 + "\n") (d 'hs)) + "\n" + d 'body)
 (ch-draft-read d t)
  (mime-split t @ [h b] (pins d 'hs (mime-heads h) 'body b))

 ; --- the message as it is sent ---------------------------------------------------------------
 (chucho-rfcdate ms)
  (: s (ms // 1000) z (s // 86400) ymd (civil z) r (s % 86400) (p2 v) (zpad 2 (show v))
     (wd3 (wday z) + ", " + p2 (ymd 2) + " " + mon3 (ymd 1 - 1) + " " + show <ymd + " "
      + p2 (r // 3600) + ":" + p2 (r % 3600 // 60) + ":" + p2 (r % 60) + " +0000"))
 (ch-special? n) (any (c \ has? "()<>[]:;@\\,.\"" (string c)) (chars n))
 (ch-enc-name n)
  (? !(mime-ascii? n) (mime-head-enc n) (ch-special? n) ("\"" + replace n "\"" "\\\"" + "\"") n)
 (ch-enc-addrs v) (join ", " (map (a \ a @ [n x] (#n ? (ch-enc-name n + " <" + x + ">") x)) (mime-addrs v)))
 (ch-type p)
  (: l (lower p)
     (? (ends? l ".txt") "text/plain" (ends? l ".pdf") "application/pdf" (ends? l ".png") "image/png"
        (ends? l ".jpg" || ends? l ".jpeg") "image/jpeg" (ends? l ".gif") "image/gif"
        (ends? l ".html" || ends? l ".htm") "text/html" (ends? l ".zip") "application/zip"
        (ends? l ".gz") "application/gzip" (ends? l ".patch" || ends? l ".diff") "text/x-diff"
        "application/octet-stream"))
 (ch-b64-lines t) (: e (mime-b64e t) (go i acc) (? (#e <= i) (join "\n" (rev acc)) (go (i + 76) ((snip e i (min #e (i + 76))) . acc)))
                     (go 0 ()))
 (ch-base n) (: (go i) (? (i < 0) n (n i = 47) (snip n (i + 1) #n) (go (i - 1))) (go (#n - 1)))
 (ch-uniq _) (show (clock 0) + "." + show (getpid 0) + "." + show (rand 1000000000))
 ; -> [raw recipients sender] | why not
 (chucho-build s d)
  (: hs (d 'hs)
     from (mime-get hs "from") fa (mime-addrs from)
     sender (two? fa ? (fa 0 1) (ch-me s))
     rc (map (a \ a 1) (mime-addrs (mime-get hs "to") + mime-addrs (mime-get hs "cc") + mime-addrs (mime-get hs "bcc")))
     dom (sender @ (_ + "@" + d) d "localhost")
     addr? (n \ elem n ["from" "to" "cc" "reply-to"])
     keep (filter (h \ h @ [n v] (#(strip v) && n != "bcc") 0) hs)
     hd (map (h \ h @ [n v] (ch-cap n + ": " + (? (addr? n) (ch-enc-addrs v) (n = "subject") (mime-head-enc v) v))) keep)
     body (replace (d 'body) "\r\n" "\n")
     cs (mime-ascii? body ? "us-ascii" "utf-8")
     tp ("Content-Type: text/plain; charset=" + cs + "\nContent-Transfer-Encoding: " + (cs = "utf-8" ? "8bit" "7bit"))
     atts (map (p \ [p (uread (ch-path s p))]) (d 'atts))
     bad (filter (a \ !(two? (a 1))) atts)
     bd ("=-chucho-" + ch-uniq 0)
     (part a) (a @ [p r] ("--" + bd + "\nContent-Type: " + ch-type p + "; name=\"" + ch-base p
                           + "\"\nContent-Disposition: attachment; filename=\"" + ch-base p
                           + "\"\nContent-Transfer-Encoding: base64\n\n" + ch-b64-lines (r 1) + "\n") "")
     mime (? (two? atts)
              ("Content-Type: multipart/mixed; boundary=\"" + bd + "\"\n\n--" + bd + "\n" + tp + "\n\n"
               + body + (ends? body "\n" ? "\n" "\n\n") + cats (map part atts) + "--" + bd + "--\n")
              (tp + "\n\n" + body))
     (? (atom? rc) "no recipients"
        (two? bad) ("cannot read " + <(<bad))
        [(join "\n" (hd + map (x \ x @ [n v] (n + ": " + v) "") (d 'extra)
                     + [("Date: " + chucho-rfcdate (clock 0)) ("Message-ID: <" + ch-uniq 0 + "@" + dom + ">")
                        "MIME-Version: 1.0" "User-Agent: chucho (love)"]) + "\n" + mime)
         rc sender]))
 ; the password: set, or a command's first line, or asked for and kept for the session
 (ch-pass-cmd cmd)
  (: _ (flush out) pp (pipe 0)
     (? (nom? pp) ""
        (: p (spawnio ["sh" "-c" cmd] -1 >pp -1 [<pp] -1 0)
           _ (close >pp)
           q (fdopen <pp) t (slurp q) _ (close q)
           _ (charm? p && 0 <= p ? (wait p) 0)
           (string? t ? (lines t @ (l . _) l "") ""))))
 ; -> 1 | why not | 'pass when a password must be asked for first
 (chucho-send s raw rc sender)
  (: sm (ch-cfg s 'sendmail "") url (ch-cfg s 'smtp "")
     user (ch-cfg s 'smtp-user (? (has? url "@") (url @ u (findsub u "//" @ a (findsub u "@" @ b (snip u (a + 2) b)))) ""))
     pc (ch-cfg s 'smtp-pass-cmd "")
     pass (? (string? (s 'pass)) (s 'pass) (#(ch-cfg s 'smtp-pass "")) (ch-cfg s 'smtp-pass "")
             #pc (ch-pass-cmd pc) ())
     (? #url (? (#user && !(string? pass)) 'pass (smtp-send url user (string? pass ? pass "") sender rc raw))
        (smtp-pipe (#sm ? sm (stat "/usr/sbin/sendmail" @ st (two? st ? "/usr/sbin/sendmail" "sendmail"))) sender rc raw)))
 (ch-sent s d raw)
  (: rec (ch-cfg s 'record "")
     r (#rec ? (ch-append s (ch-path s rec) raw "S") 1)
     m (d 'reply)
     ((tablet? m ? (pin m 'flags (mb-flag (m 'flags) 82 1)) 0),
      pins s 'view 'index 'draft () 'msg (r = 1 ? "Mail sent." ("Mail sent; not filed: " + r))))
 (ch-send-now s)
  (: d (s 'draft) b (chucho-build s d)
     (? (string? b) (ch-say s b)
        (b @ [raw rc sender]
           (chucho-send s raw rc sender @ r
              (? (r = 1) (ch-sent s d raw)
                 (r = 'pass) (ch-ask s "SMTP password: " "" 1 (s \ t \ (pin s 'pass t, ch-send-now s)))
                 (ch-say s r))))))
 (ch-compose-key s c)
  (c @- s
   121 (ch-say s "sending...", pin s 'act ['send])
   101 (pin s 'act ['edit])
   97 (ch-ask s "Attach file: " "~/" 0
              (s \ t \ (two? (stat (ch-path s t)) ? (pin (s 'draft) 'atts (s 'draft 'atts + [t]), s)
                         (ch-say s ("no file " + t)))))
   68 (s 'draft 'atts @ as (two? as ? (pin (s 'draft) 'atts (take (#as - 1) as), s) s))
   (113 || -7) (ch-ask s "Abandon this message? (y/n) " "" 'key
                       (s \ t \ (ch-yes? t ? (pins s 'view 'index 'draft () 'msg "abandoned") s)))
   63 (pins s 'view 'help 'pl ch-help 'ptop 0 'back 'compose))

 ; --- the runner: the tty's half --------------------------------------------------------------
 (ch-editor s) (ch-cfg s 'editor (getenv "VISUAL" @ v (string? v && #v ? v (getenv "EDITOR" @ e (string? e && #e ? e "vi")))))
 (ch-tmp _) ((getenv "TMPDIR" @ t (string? t && #t ? t "/tmp")) + "/chucho-" + show (getpid 0) + "-" + show (clock 0) + ".eml")
 ; the screen given back while the editor has it, and taken again after
 (ch-edit s d)
  (: p (ch-tmp 0) t0 (ch-draft-text d)
     _ (uwrite p t0)
     _ (say out (ch-esc + "[?25h" + ch-esc + "[?1049l"), flush out, raw 0)
     pid (spawn ["sh" "-c" (ch-editor s + " '" + replace p "'" "'\\''" + "'")])
     _ (charm? pid && 0 <= pid ? (wait pid) 0)
     _ (raw 1, say out (ch-esc + "[?1049h"), pin s 'lastr ())
     r (uread p)
     _ (unlink p)
     (? (atom? r) (ch-say s "the draft is gone")
        (r 1 = t0 && !(s 'draft)) (ch-say s "unchanged; not sent")
        (: _ (ch-draft-read d (r 1)) (pins s 'view 'compose 'draft d 'msg ""))))
 (ch-act s)
  (s 'act @ a (pin s 'act (),
               a @ ['compose d] (pin s 'draft (), ch-edit s d)
                   ['edit] (ch-edit s (s 'draft))
                   ['send] (ch-send-now s)
                   s))
 (ch-loop s)
  (: ws (tty 1)
     h (two? ws && 7 < <ws ? <ws 24)
     w (two? ws && 19 < <>ws ? <>ws 80)
     (say out (chucho-frame s w h),
      flush out,
      (two? (s 'act) ? (ch-act s, ch-loop s)
         (edkey in @ c (chucho-key s c, s 'over ? s (ch-loop s))))))
 (chucho-run s)
  (raw 1, say out (ch-esc + "[?1049h"), ch-loop s,
   (s 'box 'kind = 'imap ? (imap-close (s 'box)) 0),
   say out (ch-esc + "[0m" + ch-esc + "[?25h" + ch-esc + "[?1049l"), flush out, raw 0, 0)

 ; --- the door --------------------------------------------------------------------------------
 ch-usage "usage: love chucho [-f MAILBOX]\n       love chucho [-s SUBJECT] [-c CC] [-a FILE].. ADDRESS..   (the body on stdin)"
 (ch-cfgs _) (cite 'salt 'salt 'chucho)
 (ch-spool s)
  (: c (ch-cfg s 'spool "") m (getenv "MAIL") h (ch-home 0)
     (? #c (ch-path s c) (string? m && #m) m
        (mb-kind (h + "/Maildir") = 'maildir) (h + "/Maildir")
        (h + "/mbox")))
 ; -s -c -a and addresses: a message without the index, the body read or edited
 (ch-batch s as)
  (: (go l subj cc atts to)
      (l @ ("-s" . v . r) (go r v cc atts to)
           ("-c" . v . r) (go r subj (#cc ? (cc + ", " + v) v) atts to)
           ("-a" . v . r) (go r subj cc (atts + [v]) to)
           (a . r) (go r subj cc atts (to + [a]))
           [subj cc atts to])
     o (go as "" "" () ())
     d (chucho-draft s (join ", " (o 3)) (o 1) (o 0) "" () "")
     _ (pin d 'atts (o 2))
     tty? (two? (tty 0))
     (? !tty? (: b (slurp in) _ (pin d 'body (string? b ? b ""))
                 r (pin s 'draft d, ch-send-now s)
                 (s 'msg = "Mail sent." ? 0 (say err ("chucho: " + s 'msg + "\n"), 1)))
        (: _ (raw 1, say out (ch-esc + "[?1049h"))
           _ (ch-edit s d)
           _ (s 'view = 'compose ? (ch-loop s) 0)
           _ (say out (ch-esc + "[0m" + ch-esc + "[?25h" + ch-esc + "[?1049l"), flush out, raw 0)
           (puts (s 'msg + "\n"), 0))))
 (ch-flag? a) (#a && a 0 = 45 && !(elem a ["-s" "-c" "-a"]))
 (chucho-main as)
  (: cfg (ch-cfgs 0)
     s0 (pins {} 'cfg (tablet? cfg ? cfg {}))
     (? (two? as && <as = "-f" && two? >as) (ch-start s0 (ch-path s0 <>as))
        (two? as && ch-flag? <as)
         (puts (ch-usage + "\n"), 2)
        (two? as) (ch-batch (chucho-new (pins {} 'kind 'none 'path "" 'msgs ()) (s0 'cfg)) as)
        (ch-start s0 (ch-spool s0))))
 ; a local box must open before the screen is taken; an imap one may ask for its password
 (ch-start s0 p)
  (? (mb-kind p = 'imap)
      (: s (chucho-new (pins {} 'kind 'none 'path p 'msgs ()) (s0 'cfg))
         (ch-openbox s p ch-install, chucho-run s))
     (mb-open p @ b (string? b ? (puts ("chucho: " + b + "\n"), 1) (chucho-run (chucho-new b (s0 'cfg))))))
 _ (pins (cite 'verbs 'tab) 'chucho (udoor 'chucho chucho-main ch-usage 1 1)))
) ; module chucho
