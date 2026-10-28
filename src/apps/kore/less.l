; src/apps/kore/less.l -- the pager; `less` and `more` are the same door. the engine is pure:
; a state tablet stepped a byte at a time (pgstep) and rendered to one escape frame (pgframe);
; the face reads keys, performs the file requests the engine leaves, and blits.
; long lines wrap; a display row carries its source line, so counts stay the source's.
; an sgr sequence rides through at no column and is reopened across a wrap. no -S, marks, or +F.
(borrow 're)

(module 'kore
(borrow 'cli)
(borrow 'posix)
(borrow 'text)

(:
   pg-ere (cite 're 'reere) pg-fold (cite 're 'refold) pg-find (cite 're 'refind)

   pg-help
    "  less -- the pager (`more` is the same door)

  SPACE  f  ^F  ^V     forward one screenful      N SPACE   forward N lines
  b  ^B                back one screenful         N b       back N lines
  RETURN  j  e  ^N     forward one line           N j       forward N lines
  k  y  ^Y  ^P         back one line              N k       back N lines
  d  ^D                forward half a screen      u  ^U     back half a screen
  g  <                 the first line             N g       line N
  G  >                 the last line              N G       line N
  p  %                 the start                  N p       N percent in

  /PATTERN             search forward (ERE)       n         the next match
  ?PATTERN             search backward            N         the match the other way

  =  ^G                where you are              h         this page
  :n  :p               the next / previous file   :q  q  Q  quit

  -N line numbers   -i case-blind search   -s blank runs squeezed   -e quit at the end
"

   ; -- the display: tabs, columns, and the wrap ---------------------------------
   (pgsp k) (k < 1 ? "" (" " + pgsp (k - 1)))
   pgrst (string 27 + "[0m")
   ; the length of an sgr sequence (ESC [ digits ; m) at k, or 0. the only escape a text may
   ; carry: any other CSI could move our cursor. it costs no column
   (pgesc s k)
    (#s @ n
       (!(k + 1 < n && s k = 27 && s (k + 1) = 91) ? 0
          ((: (g i) (? (n <= i) 0
                       (s i = 109) (i + 1 - k)
                       (47 < s i < 58 || s i = 59) (g (i + 1))
                       0)) (k + 2))))
   ; the sgr in force after h, given what was in force before it. the shower closes every
   ; attribute inside the word that opened it, so the last sequence is the whole answer
   (pgact a h)
    (: n #h
       (go i a) (n <= i ? a
                 (pgesc h i @ e
                    (e ? (snip h i (i + e) @ q (go (i + e) (q = pgrst ? "" q)))
                       (go (i + 1) a))))
       (go 0 a))
   ; a byte as two hex digits
   (pghex b) ("0123456789ABCDEF" @ d (string (d (b >> 4)) + string (d (b & 15))))
   ; a source line -> what it looks like on a screen: tabs to the next 8th column,
   ; a control byte as ^X, a byte that is no utf-8 as <9B>, a c1 control as <U+009B>,
   ; an sgr sequence itself, everything else its own bytes
   (pgtabs ln)
    (: n #ln
       o (jug 0)
       (go k c)
        (n <= k ? (slurp o)
         (pgesc ln k @ e
            (e ? (say o (snip ln k (k + e)), go (k + e) c)
               (ln k @ b
                  (? (b = 9) (8 - c % 8 @ p
                                (say o (pgsp p), go (k + 1) (c + p)))
                     (b = 127) (say o "^?", go (k + 1) (c + 2))
                     (b < 32) (say o ("^" + string (b + 64)), go (k + 1) (c + 2))
                     (b < 128) (put o b, go (k + 1) (c + 1))
                     (: m (cpn ln k) u (cpat ln k)
                        (? (m = 0) (say o ("<" + pghex b + ">"), go (k + 1) (c + 4))
                           (u < 160) (say o ("<U+00" + pghex u + ">"), go (k + m) (c + 8))
                           (say o (snip ln k (k + m)),
                            go (k + m) (c + max 0 (wcwidth u))))))))))
       (go 0 0))
   ; the byte index where column k of s falls, stopping before a character that would
   ; overflow, so a wide one straddling the edge goes whole to the next row
   (pgspan s k)
    (: n #s
       (go i c) (n <= i ? i
                 (pgesc s i @ e
                    (e ? (go (i + e) c)
                       (c + max 0 (wcwidth (cpat s i)) @ c2
                          (k < c2 ? i (go (cpnext s i) c2))))))
       (go 0 0))
   (pgclip w s) (pgspan s w @ k (k < #s ? (snip s 0 k) s))
   ; the status line clips from the left: its tail carries the news, and a deep path would
   ; push it off the screen
   (pgclipl w s) (#s @ k (w < k ? ("<" + snip s (k - w + 1) k) s))
   ; a line -> its fragments at width w, at least one, so a blank line is a row. a fragment
   ; closes the colour it leaves open and the next reopens it
   (pgwrap w ln)
    (: (go s a acc)
        (pgspan s w @ k
           (#s <= k ? (rev ((a + s) . acc))
            (: h (snip s 0 k) a2 (pgact a h)
               (go (snip s k #s) a2 ((a + h + (#a2 ? pgrst "")) . acc)))))
       (go (pgtabs ln) "" ()))
   ; the display rows: [fragment line first?], source order
   (pgrows w ls)
    (: (frag fs i acc first) (atom? fs ? acc
                              (frag >fs i ([<fs i first] . acc) ()))
       (go l i acc) (atom? l ? (rev acc)
                     (go >l (i + 1) (frag (pgwrap w <l) i acc 1)))
       (go ls 0 ()))
   ; line -> the first row it owns. walked in order, so the first sighting wins
   (pglrow rw)
    (: t {}
       (go r i last) (atom? r ? t
                      (<>(<r) @ ln
                         (ln = last ? 0 (pin t ln i),
                          go >r (i + 1) ln)))
       (go rw 0 -1))
   ; the rows from 'top, walked on from the last answer when the view did not move back,
   ; so a frame does not re-walk the whole buffer per keystroke
   (pgfrom st)
    (: top (st 'top) ct (st 'ct)
       l (0 <= ct && ct <= top ? (drop (top - ct) (st 'cr)) (drop top (st 'rw)))
       (pins st 'ct top 'cr l,
        l))

   ; -- the state ---------------------------------------------------------------
   (pgflag st c) (peep (st 'opt) c 0)
   (pgnew opt w h)
    (tablet 0 @ st
       (pins st 'opt opt 'w w 'h h 'ls () 'rw () 'lr {} 'nr 0 'nl 0,
        pins st 'top 0 'file "" 'files () 'fi 0 'msg "" 'cnt "" 'mode 'n,
        pins st 'cmd "" 'lead 47 'pat "" 'nds () 'dir 1 'zz () 'quit () 'doe () 'sav () 'ct -1 'cr () 'hi "",
        st))
   (pgwidth st) (st 'w - (pgflag st 78 ? 8 0) @ w (w < 1 ? 1 w))
   (pgbody st) (st 'h - 1 @ b (b < 1 ? 1 b))
   (pgmax st) (st 'nr - pgbody st @ m (m < 0 ? 0 m))
   ; blank runs to one blank (-s)
   (pgsqueeze ls)
    (: (go l was acc) (atom? l ? (rev acc)
                       (!(0 < #(<l)) @ b
                          (b && was ? (go >l b acc) (go >l b (<l . acc)))))
       (go ls 0 ()))
   (pgwrapall st)
    (pgrows (pgwidth st) (st 'ls) @ rw
       (pins st 'rw rw 'nr #rw 'lr (pglrow rw) 'ct -1 'cr (),
        st))
   ; a text's lines into the buffer under a name, at the top
   (pgload st ls nm)
    ((pgflag st 115 ? (pgsqueeze ls) ls) @ l2
       (pins st 'ls l2 'nl #l2 'file nm,
        pgwrapall st,
        pin st 'top 0,
        st))
   (pgmsg st m) (pin st 'msg m, st)

   ; -- the motions -------------------------------------------------------------
   (pggo st k) (pgmax st @ m
                  (pin st 'top (? (k < 0) 0 (m < k) m k), st))
   (pgtopline st) (<(pgfrom st) @ r (two? r ? <>r 0))
   ; the row a source line starts on, clamped to the buffer
   (pgline! st i)
    (: n (st 'nl)
       k (? (i < 0) 0 (n <= i) (n < 1 ? 0 (n - 1)) i)
       (pggo st (peep (st 'lr) k 0)))
   (pgpct st n) ((? (n < 0) 0 (100 < n) 100 n) * st 'nl @ k (k // 100))
   ; forward: at the end already, -e is the door out
   (pgdown st k)
    (: t (st 'top) m (pgmax st)
       (t = m && pgflag st 101 ? (pgquit st) (pggo st (t + k))))
   (pgup st k) (pggo st (st 'top - k))

   ; -- the search --------------------------------------------------------------
   ; a pattern -> (nodes) or (), so an empty pattern is still a presence
   (pgnds st p)
    (pg-ere p @ r
       (atom? r ? () [(pgflag st 105 ? (pg-fold <>r) <>r)]))
   ; the nearest source line from i in direction d that the nodes match, or -1
   (pgseek st nds i d)
    (: ls (st 'ls)
       (hit ln) (two? (pg-find nds ln 0))
       (fwd l k) (? (atom? l) -1 (hit <l) k (fwd >l (k + 1)))
       (bak l k best) (atom? l || i < k ? best
                       (bak >l (k + 1) (hit <l ? k best)))
       (? (i < 0) (0 < d ? (fwd ls 0) -1)
          (0 < d) (fwd (drop i ls) i)
          (bak ls 0 -1)))
   ; the stored pattern, one step on in direction d
   (pghunt st d)
    (st 'nds @ w
       (atom? w ? (pgmsg st "no previous pattern")
        (: _ (pin st 'dir d)
           i (pgseek st <w (pgtopline st + d) d)
           (i < 0 ? (pgmsg st ("pattern not found: " + st 'pat)) (pgline! st i)))))
   (pgsearch st p d)
    ((0 < #p ? (pgnds st p) (st 'nds)) @ w
       (? (0 < #p && atom? w) (pgmsg st ("bad pattern: " + p))
          (atom? w) (pgmsg st "no previous pattern")
          (pin st 'nds w, 0 < #p ? (pin st 'pat p) 0, pghunt st d)))

   ; -- the help page, and the file walk ----------------------------------------
   (pghelp st)
    (two? (st 'sav) ? st
     (pin st 'sav [(st 'ls) (st 'file) (st 'top)], pgload st (lines pg-help) "HELP"))
   ; back out of the help -- 1 when there was a page to go back to
   (pgback st)
    (st 'sav @ s
       (atom? s ? ()
        (pin st 'sav (), pgload st <s <>s, pggo st <>>s, 1)))
   (pgquit st) (pgback st ? st (pin st 'quit 1))
   ; the operand walk: the engine names the file, the face reads it -- through its 'load
   ; when it gave one (a name -> [lines title], or a complaint), else the file whole
   (pgdoe st)
    (st 'doe @ rq
       (atom? rq ? 0
        (: _ (pin st 'doe ())
           nm <rq
           ld (pgflag st 'load)
           r (ld ? (ld nm) (uread nm @ u (two? u ? [(lines <>u) nm] (nm + ": cannot open"))))
           _ (string? r ? (pgmsg st r) (pgload st <r <>r))
           0)))
   (pgfile st d)
    (: fs (st 'files) k (st 'fi + d)
       (? (k < 0) (pgmsg st "no previous file")
          (#fs <= k) (pgmsg st "no next file")
          (pin st 'fi k, pin st 'doe [(fs k)], st)))

   ; -- the step ----------------------------------------------------------------
   (pgcnt st d) (st 'cnt @ c (0 < #c ? (uatoi c) d))
   (pgask st ld) (pins st 'mode 'c 'lead ld 'cmd "", st)
   ; the : commands are one letter, typed straight after the colon
   (pgcolon st c)
    (pin st 'mode 'n, (? (c = 110) (pgfile st 1)
          (c = 112) (pgfile st -1)
          (c = 113 || c = 81) (pin st 'quit 1)
          (c = 27) st
          (pgmsg st ("no : command " + string c))))
   ; the typed line: return runs it, ESC drops it, a backspace off the front does too
   (pgtyped st c)
    (st 'cmd @ cm
       (? (c = 13 || c = 10)
           (pins st 'mode 'n 'cmd "", st 'lead = 63 ? (pgsearch st cm -1) (pgsearch st cm 1))
          (c = 27) (pins st 'mode 'n 'cmd "", st)
          (c = 8 || c = 127)
           (0 < #cm ? (pin st 'cmd (snip cm 0 (#cm - 1)), st)
            (pins st 'mode 'n 'cmd "", st))
          (c < 32) st
          (pin st 'cmd (cm + string c), st)))
   ; one key in normal mode; a digit stacks a count and everything else spends it
   (pgnorm st c)
    (: _ (pin st 'msg "")
       b (pgbody st)
       half (b // 2 @ k (k < 1 ? 1 k))
       n (pgcnt st 0)
       zz (st 'zz)
       (48 <= c <= 57 ? (pin st 'cnt (st 'cnt + string c), st)
        (pins st 'cnt "" 'zz (), (? (c = 32 || c = 102 || c = 6 || c = 22) (pgdown st (n ? n b))
              (c = 13 || c = 10 || c = 106 || c = 14 || c = 101 || c = 5)
               (pgdown st (n ? n 1))
              (c = 98 || c = 2) (pgup st (n ? n b))
              (c = 107 || c = 121 || c = 25 || c = 16) (pgup st (n ? n 1))
              (c = 100 || c = 4) (pgdown st (n ? n half))
              (c = 117 || c = 21) (pgup st (n ? n half))
              (c = 103 || c = 60) (pgline! st ((n ? n 1) - 1))
              (c = 71 || c = 62) (pgline! st ((n ? n (st 'nl)) - 1))
              (c = 112 || c = 37) (pgline! st (pgpct st n))
              (c = 47) (pgask st 47)
              (c = 63) (pgask st 63)
              (c = 110) (pghunt st (st 'dir))
              (c = 78) (pghunt st (0 - st 'dir))
              (c = 58) (pin st 'mode 'x, st)
              (c = 61 || c = 7) (pgmsg st (pgstat st))
              (c = 104 || c = 72) (pghelp st)
              (c = 113 || c = 81) (pgquit st)
              (c = 90) (zz ? (pgquit st) (pin st 'zz 1, st))
              st))))
   (pgstep st c)
    (? (st 'mode = 'c) (pgtyped st c)
       (st 'mode = 'x) (pgcolon st c)
       (pgnorm st c))

   ; -- the frame ---------------------------------------------------------------
   ; the last visible source line -- the tail of the window, or the buffer's end
   (pglast st)
    (: b (pgbody st) top (st 'top) k (top + b)
       r (pgfrom st (st 'nr < k ? (st 'nr - top - 1) (b - 1)))
       (two? r ? (<>r + 1) (st 'nl)))
   (pgstat st)
    (: b (pgbody st) nl (st 'nl)
       end? (st 'nr <= st 'top + b)
       l2 (pglast st)
       pc (nl < 1 ? 100 (l2 * 100 // nl))
       ((0 < #(st 'file) ? (st 'file) "-") + "  " + show (pgtopline st + 1)
        + "-" + show l2 + "/" + show nl + "  " + show pc + "%"
        + (end? ? "  (END)" "")))
   ; the matches in a fragment, in standout. a match spanning a wrap shows on both
   ; halves, which is what painting the fragment rather than the line buys
   (pgpaint e nds s)
    (: n #s
       (go i acc)
        (n <= i ? (acc + snip s i n)
         (pg-find nds s i @ m
            (atom? m ? (acc + snip s i n)
             (: a <>m z <>>m
                (z <= a ? (acc + snip s i n)
                 (go z (acc + snip s i a + e + "[7m" + snip s a z + e + "[27m")))))))
       (go 0 ""))
   ; each h in a fragment in standout: a face's own highlight ('hi), a browser's current link
   (pgmark e h s)
    (: n #s m #h
       (go i st acc)
        (? (n < i + m) (acc + snip s st n)
           (h = snip s i (i + m)) (go (i + m) (i + m) (acc + snip s st i + e + "[7m" + h + e + "[27m"))
           (go (i + 1) st acc))
       (go 0 0 ""))
   (pgframe st)
    (: e (string 27)
       w (st 'w) b (pgbody st)
       nds (st 'nds @ v (two? v ? <v))
       hi (st 'hi)
       (lay r) (: fr <r
                  t0 (two? nds ? (pgpaint e nds fr) fr)
                  tx (string? hi && 0 < #hi ? (pgmark e hi t0) t0)
                  (pgflag st 78 ?
                     ((<>>r ? (upad 7 (show (<>r + 1))) "       ") + " " + tx) tx))
       (rows l k acc)
        (b <= k ? acc
         (rows (two? l ? >l l) (k + 1)
               (acc + (two? l ? (lay <l) "~") + e + "[K" + "\r\n")))
       ask (? (st 'mode = 'c) (string (st 'lead) + st 'cmd)
              (st 'mode = 'x) ":"
              (0 < #(st 'msg)) (st 'msg)
              (pgstat st))
       line (pgclipl w ask)
       (e + "[H" + rows (pgfrom st) 0 ""
          + e + "[7m" + line + e + "[0m" + e + "[K"
          + e + "[" + show (st 'h) + ";" + show (#line + 1) + "H"))

   ; -- the face: keys off a port, frames onto out -------------------------------
   ; not a terminal: pour the operands through
   (pgpour as) (uchunks "less" puts as)
   ; less's start command: +N opens at line N, +/pat at its first match
   (pgstart st p)
    (? !(0 < #p) st
       (p 0 = 47) (pgsearch st (snip p 1 #p) 1)
       (pgline! st (uatoi p - 1)))
   ; one key -> [byte pushback]: arrow and page keys decoded to their plain twins, shift-tab
   ; to 265. any other byte after ESC is pushed back, so ESC q reads as two keys
   (pgkey kq pend)
    (0 <= pend ? [pend -1]
     (see kq @ c
        (!(c = 27) ? [c -1]
           (see kq @ c2
              (!(c2 = 91) ? [27 c2]
                 (: (tail d) (see kq @ c3
                                (48 <= c3 <= 57 ? (tail c3) [d c3]))
                    r (tail -1)
                    d <r f <>r
                    [(? (f = 65) 107 (f = 66) 106 (f = 72) 103 (f = 70) 71 (f = 90) 265
                        (f = 126 && d = 53) 98
                        (f = 126 && d = 54) 32
                        (f = 126 && d = 49) 103
                        (f = 126 && d = 52) 71
                        27) -1]))))))
   ; the window may move under us; the top line is what survives a rewrap
   (pgresize st)
    (ttysize 0 0 @ hw
       (<hw = st 'h && <>hw = st 'w ? 0
        (pgtopline st @ ln
           (pins st 'h <hw 'w <>hw,
            pgwrapall st,
            pgline! st ln,
            1))))
   ; the loop. fs is the operand list (() when the text came off stdin), kq the
   ; keyboard port -- `in` when an operand is the text, /dev/tty when stdin was
   (pgride fs ls nm kq w h opt plus)
    (: st (pgnew opt w h)
       _ (pin st 'files fs)
       _ (pgload st ls nm)
       _ (pgstart st plus)
       (doe _) (pgdoe st)
       (go pend)
        (: _ (pgresize st)
           _ (puts (pgframe st)) _ (flush out)
           kr (pgkey kq pend)
           c <kr
           (c < 0 ? 0 (pgstep st c, doe (), st 'quit ? 0 (go <>kr))))
       (ttytake (), mind go -1 (_ \ ttygive ()), 0))
   ; the flags kore's pager knows, and the complaint for anything else
   (pgopts as)
    (: t {}
       o (uopt as t () '(101) ())
       (two? o ? () (udie 2 "less: bad option"),
        (uoptbad as t '(78 105 115 101) @ c
           (!c ? () (udie 2 ("less: unknown option -" + string c)))),
        [t <>>o]))
   (less-main as)
    (: r (pgopts as)
       t <r
       rest <>r
       ; +N / +/pat sits ahead of the names, which is where less takes it
       plus? (two? rest && 1 < #(<rest) && <rest 0 = 43)
       plus (plus? ? (snip <rest 1 #(<rest)) "")
       fs (plus? ? >rest rest)
       ws (tty 1)
       hw (ttysize 0 0)
       (? (atom? ws) (pgpour fs)
          (two? fs)
           (: f <fs
              rd (uread f)
              (two? rd ? () (udie 1 ("less: cannot open " + f)),
               pgride fs (lines <>rd) f in <>hw <hw t plus))
          ; no operand: stdin is the text, and `raw` only works on fd 0, so the pipe moves
          ; aside and /dev/tty takes fd 0; no tty, pour it. `raw` is the isatty here:
          ; () for a terminal on fd 0, 'enotty else -- a terminal stdin means no text
          (: tty0? !(raw 1)
             _ (raw 0)
             _ (tty0? ? (udie 2 "usage: less [-Nise] [+N|+/PAT] [FILE..]") 0)
             dfd (dup 0)
             tfd (openfd "/dev/tty" 0)
             (nom? tfd || nom? dfd ?
                 (charm? dfd ? (close dfd) 0, pgpour ())
                (: _ (dup2 tfd 0)
                   _ (close tfd)
                   q (fdopen dfd)
                   txt (slurp q)
                   (close q,
                    pgride () (lines txt) "" (fdopen 0) <>hw <hw t plus)))))))
) ; module 'kore
