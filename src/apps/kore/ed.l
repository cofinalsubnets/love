; src/apps/kore/ed.l -- ed and ex, the line editors: one buffer, two dialects over it. a
; toolbox file, no seat -- kore is its door; loads after re.l and sed.l (usubn).
;
;   ed [-s] [-p PROMPT] [FILE]
;   ex [-s] [-R] [-v] [-c CMD | +CMD] [FILE]
;
; the addresses are POSIX's in both: N . $ 'x /re/ ?re? with + - ^ offsets (a bare
; number after an address adds too), joined by , and ; -- either side may be missing:
; `,` is 1,$ and `;` is .,$, `,N` is 1,N and `N,` is N,N -- and % is 1,$.
; ed's commands: a c d e E f g G h H i j k l m n p P q Q r s t u v V w W wq z = ! and
; the bare newline, with the p l n suffixes. an error says `?`, H turns the reason on.
; s reads & \1..\9, % alone for the last replacement, a backslash-newline to split the
; line, and the g N p l n flags; a bare s repeats the last, g and p toggling it and r
; taking the last search's pattern.
; ex reads the same buffer by word: [range] word[!] [args], any unambiguous head of
; the word, | between commands (g v and ! take the rest), a count after the word,
; named registers for d ya pu, set, > < & ~, a range filtered through !cmd, and vi,
; which hands the buffer to the vi engine and ends with it.
; stdin not a terminal is a script, and an error in one ends the edit with 1 (POSIX's
; rule and GNU ed's; vim's ex carries on).
; out of scope: ^C (it kills, as it does every tool here), ex's file list (next,
; args), open mode, s's c flag, ed's -x and -r.
(module 'kore
(borrow 'cli)
(borrow 'posix)

(:
   ed-usage "usage: ed [-s] [-p PROMPT] [FILE]"
   ex-usage "usage: ex [-s] [-R] [-v] [-c CMD | +CMD] [FILE]"

   ; -- the buffer -------------------------------------------------------------------
   ; the lines are records [id text] laid in chunks, each chunk its count consed onto
   ; its records: an address walks the counts, and an edit rebuilds the chunks it
   ; touches and shares the rest, so undo keeps the old chunk list whole. 'n is the
   ; line count, 'dot the current line (0 before the first). an id outlives
   ; renumbering, so a mark or a global's hit follows its line and dies with it. every
   ; change bumps 'gen, which is how undo tells a command that changed the buffer from
   ; one that did not
   (ed-new ex?)
    {'buf () 'n 0 'nid 1 'dot 0 'gen 0 'file "" 'dirty () 'marks {} 'undo () 'undid ()
     'pat () 'spat () 'rep () 'sg () 'snth 1 'err "" 'help () 'prompt "*" 'pon ()
     'silent () 'ex ex? 'tty () 'quit () 'warn -1 'cmdn 0 'shcmd () 'regs {} 'ro ()
     'ing () 'win 22 'nu () 'list () 'sw 8 'report 2 'ap 1 'ic ()}
   (ed-fail m) (scare 'ederr m)
   (ed-recs e ts) (map (t \ (: k (e 'nid) _ (pin e 'nid (k + 1)) [k t])) ts)
   ed-cz 64                                        ; the chunk a long run is cut into
   (ed-chunks l)                                   ; records -> chunks, a short run one
    (: k #l
       (? (k = 0) ()
          (k <= (2 * ed-cz)) [(k . l)]
          ((ed-cz . take ed-cz l) . ed-chunks (drop ed-cz l))))
   (ed-flat cs) (? (two? cs) (>(<cs) + ed-flat >cs) ())
   (ed-all e) (ed-flat (e 'buf))
   ; the chunks from the one holding line a on -> [chunks lines-before-them]
   (ed-seek cs a)
    (: (go cs o) (? (two? cs && (o + <(<cs)) < a) (go >cs (o + <(<cs))) [cs o]) (go cs 0))
   (ed-span e a b)                                 ; the records a..b
    (? (b < a) ()
       (: (grab cs o) (? (two? cs && o < b) (>(<cs) + grab >cs (o + <(<cs))) ())
          (ed-seek (e 'buf) a @ [cs o] (take (b - a + 1) (drop (a - 1 - o) (grab cs o))))))
   (ed-texts e a b) (map (r \ <>r) (ed-span e a b))
   (ed-line e k) <>(<(ed-span e k k))
   (ed-id e k) <(<(ed-span e k k))
   ; records a..b become ins; b = a - 1 is a pure insertion ahead of a
   (ed-splice e a b ins)
    (: (skip cs o pre) (? (two? cs && (o + <(<cs)) < a) (skip >cs (o + <(<cs)) (<cs . pre)) [cs o pre])
       ; the chunks the edit reaches: one at least, then each that starts by b
       (grab cs o acc) (? (two? cs && ((atom? acc) || o < b)) (grab >cs (o + <(<cs)) (<cs . acc)) [cs (rev acc)])
       (skip (e 'buf) 0 () @ [cs o pre]
         ; an append at the end rides into the last chunk rather than one of its own
         (: back? (atom? cs && two? pre)
            cs2 (? back? [<pre] cs) o2 (? back? (o - <(<pre)) o) pre2 (? back? >pre pre)
            g (grab cs2 o2 ())
            mid (ed-flat <>g)
            nm (take (a - 1 - o2) mid + ins + drop (b - o2) mid)
            (pins e 'buf (rev pre2 + ed-chunks nm + <g) 'n ((e 'n) + #ins - (b - a + 1))
                  'gen (e 'gen + 1) 'dirty 1))))
   (ed-idx e id)                                   ; the line holding id, 0 when it is gone
    (: (go l k) (? (atom? l) 0 (<(<l) = id) k (go >l (k + 1))) (go (ed-all e) 1))
   ; the first record from line k on whose id is in marks -> its line, unmarked; 0 if none
   (ed-nextmark e marks k)
    (: (walk rs i cs) (? (two? rs) (? (peep marks <(<rs) ()) (pin marks <(<rs) (), i)
                                      (walk >rs (i + 1) cs))
                         (two? cs) (walk >(<cs) i >cs)
                         0)
       (ed-seek (e 'buf) k @ [cs o] (? (two? cs) (walk (drop (k - 1 - o) >(<cs)) k >cs) 0)))
   (ed-mark e c)
    (: k (? (97 <= c <= 122) (ed-idx e (peep (e 'marks) c 0)) 0)
       (? (0 < k) k (ed-fail "invalid mark")))
   (ed-ok e a) (? (0 <= a <= (e 'n)) a (ed-fail "invalid address"))
   (ed-blank? c) (c = 32 || c = 9)
   (ed-skip s i) (: n #s (go k) (? (k < n && ed-blank? (s k)) (go (k + 1)) k) (go i))
   (ed-trim s) (: n #s i (ed-skip s 0)
                  (bw k) (? (i < k && ed-blank? (s (k - 1))) (bw (k - 1)) k)
                  (snip s i (bw n)))

   ; -- patterns ---------------------------------------------------------------------
   ; the text up to an unescaped dl at i -> [next text closed?]. \dl is dl, and every
   ; other escape stays whole for the regex; a delimiter missing at the end is forgiven
   (ed-delim s i dl)
    (: n #s
       (go j acc)
        (? (n <= j) [j acc ()]
           (s j = 92 && (j + 1) < n && s (j + 1) = dl) (go (j + 2) (acc + string dl))
           (s j = 92 && (j + 1) < n) (go (j + 2) (acc + snip s j (j + 2)))
           (s j = dl) [(j + 1) acc 1]
           (go (j + 1) (acc + string (s j))))
       (go i ""))
   ; a pattern text -> its matcher, which becomes the last one; "" reuses that
   (ed-re e tx)
    (? (0 < #tx)
        (rebre tx @ [_ nds _] (: m (recomp (? (e 'ic) (refold nds) nds)) _ (pin e 'pat m) m)
          (ed-fail ("invalid pattern: " + tx)))
       (two? (e 'pat)) (e 'pat)
       (ed-fail "no previous pattern"))
   (ed-hit? m t) (two? (refindpm m t 0 (\ a b 1)))
   ; the next line from dot matching m, wrapping, forward or back
   (ed-search e m fwd?)
    (: n (e 'n) d (e 'dot) l (ed-all e) d2 (? (d < 1) 1 d)
       rot (? fwd? (drop d l + take d l) (rev (take (d2 - 1) l) + rev (drop (d2 - 1) l)))
       (go r k) (? (atom? r) (ed-fail "no match")
                   (ed-hit? m <>(<r)) k
                   (go >r (k + 1)))
       k (go rot 1)
       (? fwd? (((d + k - 1) % n) + 1) (((d2 - k - 1 + (2 * n)) % n) + 1)))

   ; -- addresses --------------------------------------------------------------------
   ; one address at i -> [j line], [i ()] when none is there
   (ed-addr e s i)
    (: n #s
       (dig? k) (k < n && 48 <= s k <= 57)
       (num k acc) (? (dig? k) (num (k + 1) (10 * acc + (s k - 48))) [k acc])
       (off? k) (k < n && (s k = 43 || s k = 45 || s k = 94))
       i0 (ed-skip s i)
       base (? (n <= i0) ()
               (dig? i0) (num i0 0)
               (s i0 = 46) [(i0 + 1) (e 'dot)]
               (s i0 = 36) [(i0 + 1) (e 'n)]
               (s i0 = 39) (? ((i0 + 1) < n) [(i0 + 2) (ed-mark e (s (i0 + 1)))] (ed-fail "invalid mark"))
               (s i0 = 47 || s i0 = 63)
                (ed-delim s (i0 + 1) (s i0) @ [j tx _] [j (ed-search e (ed-re e tx) (s i0 = 47))])
               ())
       ; the + - ^ tail; a bare number after an address adds
       (offs k v)
        (: k2 (ed-skip s k)
           (? (off? k2)
               (: sg (s k2 = 43 ? 1 -1)
                  (? (dig? (k2 + 1)) (num (k2 + 1) 0 @ [j d] (offs j (v + sg * d)))
                     (offs (k2 + 1) (v + sg))))
              (dig? k2) (num k2 0 @ [j d] (offs j (v + d)))
              [k v]))
       (? (two? base) (offs <base <>base)
          (off? i0) (offs i0 (e 'dot))
          [i ()]))
   ; the addresses ahead of a command -> [j a1 a2 given], the last two counting. `;`
   ; moves dot to its left address before the right one is read
   (ed-range e s i)
    (: n #s i0 (ed-skip s i)
       (go k a b cnt dflt)                         ; dflt: what a missing address stands for
        (ed-addr e s k @ [j v]
          (: got (charm? v) v2 (? got v dflt)
             j2 (ed-skip s j)
             (? (j2 < n && (s j2 = 44 || s j2 = 59))
                 (: sep (s j2)
                    x (ed-ok e (? got v (sep = 44 ? 1 (e 'dot))))
                    _ (? (sep = 59) (pin e 'dot x) 0)
                    (go (j2 + 1) b x (cnt + 1) (? got x (e 'n))))
                (charm? v2) [j (? (0 < cnt) b v2) (ed-ok e v2) (cnt + 1)]
                [j a b cnt])))
       (? (i0 < n && s i0 = 37) [(i0 + 1) 1 (e 'n) 2]
          (go i () () 0 ())))

   ; -- showing lines ----------------------------------------------------------------
   (ed-oct c) (string (48 + (c >> 6)) + string (48 + ((c >> 3) & 7)) + string (48 + (c & 7)))
   (ed-esc c)
    (? (c = 92) "\\\\" (c = 7) "\\a" (c = 8) "\\b" (c = 12) "\\f" (c = 13) "\\r"
       (c = 9) "\\t" (c = 11) "\\v" (c < 32 || 126 < c) ("\\" + ed-oct c) (string c))
   ; l's face: the escapes spelled, $ at the end, folded with a backslash short of 72
   (ed-list t)
    (: n #t o (jug 0)
       (go i col)
        (? (n <= i) (say o "$", slurp o)
           (: x (ed-esc (t i)) w #x
              (? (72 <= col + w) (say o "\\\n", go i 0)
                 (say o x, go (i + 1) (col + w)))))
       (go 0 0))
   ; one line out, by the flags (chars of p l n) and the ex options
   (ed-show e k t fl)
    (: l? (elem 108 fl || e 'list) n? (elem 110 fl || e 'nu)
       body (? l? (ed-list t) t)
       (say out (? n? (? (e 'ex) (upad 6 (show k) + "  " + body) (show k + "\t" + body)) body),
        put out 10))
   (ed-print e a b fl)
    (: (go l k) (? (two? l) (ed-show e k <>(<l) fl, go >l (k + 1)) 0)
       _ (go (ed-span e a b) a)
       (pin e 'dot b))
   (ed-flags e fl) (? (two? fl) (ed-show e (e 'dot) (ed-line e (e 'dot)) fl) 0)
   ; the p l n suffix at k -> its flags; anything else there is an error
   (ed-sfx s k)
    (: n #s
       (go i acc) (? (n <= i) acc
                     (elem (s i) '(112 108 110)) (go (i + 1) (s i . acc))
                     (ed-fail "invalid command suffix"))
       (go k ()))
   (ed-say e m) (? (e 'silent) 0 (say out m, put out 10))

   ; -- the edits --------------------------------------------------------------------
   ; texts after line at; dot the last of them, else none when nothing came
   (ed-add e at ts none)
    ((? (two? ts) (ed-splice e (at + 1) at (ed-recs e ts)) 0), pin e 'dot (? (two? ts) (at + #ts) none))
   (ed-del e a b)                                  ; -> the texts it took
    (: t (ed-texts e a b)
       _ (ed-splice e a b ())
       _ (pin e 'dot (? (a <= (e 'n)) a (e 'n)))
       t)
   ; lines a..b folded into one by j2, a joiner of two texts
   (ed-join e a b j2)
    (? (a < b)
       (: ts (ed-texts e a b)
          _ (ed-splice e a b (ed-recs e [(foldl j2 <ts >ts)]))
          (pin e 'dot a))
       0)
   (ed-move e a b d)
    (? (a <= d < b) (ed-fail "invalid destination")
       (: blk (ed-span e a b) k #blk
          _ (ed-splice e a b ())
          ip (? (d < a) d (d - k))
          _ (ed-splice e (ip + 1) ip blk)
          (pin e 'dot (ip + k))))
   (ed-copy e a b d)
    (: ts (ed-texts e a b) (ed-add e d ts d))
   ; the substitution over a..b -> the last line changed, 0 when none did. a newline the
   ; replacement made splits its line, the first piece keeping the line's id
   (ed-subst e a b m rep g? nth)
    (: (go rs i acc last)
        (? (atom? rs) [(rev acc) last]
           (: r <rs res (usubn m rep <>r g? nth)
              (? <res
                  (: ps (usplit 10 <>res) k #ps
                     acc2 (rev (ed-recs e >ps) + ([<r <ps] . acc))
                     (go >rs (i + k) acc2 (i + k - 1)))
                 (go >rs (i + 1) (r . acc) last))))
       out (go (ed-span e a b) a () 0)
       (? (<>out = 0) 0
          (ed-splice e a b <out, pin e 'dot <>out, <>out)))
   (ed-undo e)
    (: u (e 'undo)
       _ (? (two? u) 0 (ed-fail "nothing to undo"))
       _ (pins e 'undo [(e 'buf) (e 'dot) (e 'n)] 'undid 1)
       (pins e 'buf <u 'dot <>u 'n <>>u 'gen (e 'gen + 1) 'dirty 1))

   ; -- files and the shell ----------------------------------------------------------
   (ed-sh-out cmd)                                 ; a command's standard output, whole
    (: _ (flush out) pp (pipe 0)
       _ (? (nom? pp) (ed-fail "cannot pipe") 0)
       p (spawnio ["sh" "-c" cmd] -1 >pp -1 [<pp] -1 0)
       _ (close >pp)
       q (fdopen <pp) t (slurp q) _ (close q)
       _ (? (charm? p && 0 <= p) (wait p) 0)
       (? (string? t) t ""))
   (ed-sh-in cmd t)                                ; t to a command's standard input
    (: _ (flush out) pp (pipe 0)
       _ (? (nom? pp) (ed-fail "cannot pipe") 0)
       p (spawnio ["sh" "-c" cmd] <pp -1 -1 [>pp] -1 0)
       _ (close <pp)
       q (fdopen >pp) _ (say q t) _ (close q)
       _ (? (charm? p && 0 <= p) (wait p) 0)
       #t)
   (ed-sh-run cmd)
    (: _ (flush out) p (spawn ["sh" "-c" cmd])
       (? (nom? p) (ed-fail "cannot run the shell") (wait p)))
   ; the text after a ! -> the command: a leading ! is the last one, an unescaped % the
   ; file. answers [cmd changed?], and it becomes the last
   (ed-shcmd e t)
    (: n #t
       (go i acc ch)
        (? (n <= i) [acc ch]
           (t i = 92 && (i + 1) < n && t (i + 1) = 37) (go (i + 2) (acc + "%") ch)
           (t i = 37) (? (0 < #(e 'file)) (go (i + 1) (acc + e 'file) 1) (ed-fail "no current filename"))
           (go (i + 1) (acc + string (t i)) ch))
       r (? (0 < n && t 0 = 33)
             (? (string? (e 'shcmd)) (go 1 (e 'shcmd) 1) (ed-fail "no previous command"))
             (go 0 "" ()))
       _ (pin e 'shcmd <r)
       r)
   (ed-bang? nm) (0 < #nm && nm 0 = 33)
   ; a file's text, or a command's output after `!` -> the text, () when it will not open
   (ed-get e nm)
    (? (ed-bang? nm) (ed-sh-out <(ed-shcmd e (snip nm 1 #nm)))
       (: r (uread nm) (? (two? r) <>r ())))
   (ed-put e a b nm app?)                          ; -> bytes
    (: t (? (a < 1) "" (unlines (ed-texts e a b)))
       (? (ed-bang? nm) (ed-sh-in <(ed-shcmd e (snip nm 1 #nm)) t)
          (: q (open nm (? app? "a" "w"))
             (? (hot? q) (say q t, close q, #t)
                (ed-fail ("cannot open output file " + nm))))))
   ; the name a command reads: its own, else the remembered one, which it becomes if
   ; there was none
   (ed-name e arg)
    (? (0 < #arg) ((? (0 < #(e 'file) || ed-bang? arg) 0 (pin e 'file arg)), arg)
       (0 < #(e 'file)) (e 'file)
       (ed-fail "no current filename"))
   ; the buffer over again from nm -> bytes, () for a file that does not open
   (ed-load e nm)
    (: t (ed-get e nm)
       _ (pins e 'buf () 'n 0 'dot 0 'marks {} 'undo () 'undid 1 'gen (e 'gen + 1))
       _ (? (ed-bang? nm) 0 (pin e 'file nm))
       _ (? (string? t) (ed-add e 0 (lines t) 0) 0)
       _ (pin e 'dirty ())
       (? (string? t) #t ()))
   (ed-read e at nm)                               ; -> bytes
    (: t (ed-get e nm)
       _ (? (string? t) 0 (ed-fail ("cannot open input file " + nm)))
       _ (ed-add e at (lines t) (e 'dot))
       #t)

   ; -- global -----------------------------------------------------------------------
   ; the command list: the rest of the line, a trailing backslash pulling in the next
   (ed-glist s src)
    (: (go t) (: n #t
                 (? (0 < n && t (n - 1) = 92)
                     (: nx (src 0) h (snip t 0 (n - 1))
                        (? (string? nx) (go (h + "\n" + nx)) h))
                    t))
       (go s))
   (ed-lsrc ls)                                    ; a list read as a source
    (: b {'l ls} (_ \ (: l (b 'l) (? (two? l) (pin b 'l >l, <l) ()))))
   ; g v G V: mark the lines of a..b that match (or do not), then visit each mark still
   ; standing, dot on it. cl is the list's text; inter? reads one command per line.
   ; the hunt for the next mark goes on from the last, and once from the top when it
   ; runs out -- a command can move a marked line above the one it runs on
   (ed-global e a b m inv? cl inter? src)
    (: _ (? (e 'ing) (ed-fail "cannot nest global commands") 0)
       marks (tablet 0)
       _ (: (go l) (? (two? l) (: r <l h (ed-hit? m <>r)
                                     _ (? (? inv? !h h) (pin marks <r 1) 0) (go >l)) 0)
            (go (ed-span e a b)))
       ls (? (0 < #(ed-trim cl)) (usplit 10 cl) ["p"])
       _ (pin e 'ing 1)
       (run ls) (: s2 (ed-lsrc ls)
                   (go _) (: l (s2 1) (? (string? l) (ed-exec e l s2, go 0) 0))
                   (go 0))
       (visit from last)
        (: k0 (ed-nextmark e marks from)
           k (? (0 < k0 || from = 1) k0 (ed-nextmark e marks 1))
           (? (0 < k)
              (pin e 'dot k, (? !inter? (run ls, visit k last)
                    (: _ (ed-show e k (ed-line e k) ())
                       l (src 0)
                       c (? !(string? l) "" (l = "&") last l)
                       _ (? (0 < #c) (run [c]) 0)
                       (visit k c))))
              0))
       _ (visit 1 "")
       (pin e 'ing ()))

   ; -- the s command ----------------------------------------------------------------
   ; the replacement at i, delimited by dl -> [next text closed? line], line the one it
   ; ended on: a backslash ending a line pulls in the next, the newline left there
   ; splitting the line the replacement lands in
   (ed-reptext s i dl src)
    (: (go s i acc)
        (: n #s
           (? (n <= i) [i acc () s]
              (s i = 92 && (i + 1) = n)
               (: nx (src 0) (? (string? nx) (go nx 0 (acc + "\\\n")) [n acc () s]))
              (s i = 92) (go s (i + 2) (acc + snip s i (i + 2)))
              (s i = dl) [(i + 1) acc 1 s]
              (go s (i + 1) (acc + string (s i)))))
       (go s i ""))
   ; the flags after an s: g, a count, p l n -> [g? nth fl]
   (ed-sflags s k g? nth fl)
    (: n #s
       (dig? i) (i < n && 48 <= s i <= 57)
       (num i acc) (? (dig? i) (num (i + 1) (10 * acc + (s i - 48))) [i acc])
       (? (n <= k) [g? nth fl]
          (s k = 103) (ed-sflags s (k + 1) 1 nth fl)
          (dig? k) (num k 0 @ [j v] (? (v < 1) (ed-fail "invalid count") (ed-sflags s j g? v fl)))
          (elem (s k) '(112 108 110)) (ed-sflags s (k + 1) g? nth (s k . fl))
          (s k = 35) (ed-sflags s (k + 1) g? nth (110 . fl))
          (ed-blank? (s k)) (ed-sflags s (k + 1) g? nth fl)
          (ed-fail "invalid command suffix")))
   ; s at k over a..b: /re/rep/flags, or bare with flags to repeat the last
   (ed-sub e s k a b src)
    (: n #s
       dl (? (k < n) (s k) 10)
       fresh? !(dl = 10 || ed-blank? dl || elem dl '(103 112 108 110 114 35) || 48 <= dl <= 57)
       spec (? fresh?
                (: _ (? (dl = 92) (ed-fail "invalid pattern delimiter") 0)
                   r1 (ed-delim s (k + 1) dl)
                   m (ed-re e <>r1)
                   (ed-reptext s <r1 dl src @ [i2 rp closed? ln]
                     (: rep (? (rp = "%") (? (string? (e 'rep)) (e 'rep) (ed-fail "no previous substitution")) rp)
                        _ (pins e 'spat m 'rep rep)
                        ; an unclosed replacement prints, as if p were given
                        f (ed-sflags (? closed? (snip ln i2 #ln) "") 0 () 1 (? closed? () [112]))
                        _ (pins e 'sg <f 'snth <>f)
                        [m rep f])))
                (: _ (? (two? (e 'spat)) 0 (ed-fail "no previous substitution"))
                   ; the repeat: r takes the last search pattern, g and p toggle
                   (walk i m g? fl) (? (n <= i) [m g? fl]
                                       (s i = 114) (walk (i + 1) (e 'pat) g? fl)
                                       (s i = 103) (walk (i + 1) m !g? fl)
                                       (elem (s i) '(112 108 110)) (walk (i + 1) m g? (s i . fl))
                                       (ed-blank? (s i)) (walk (i + 1) m g? fl)
                                       (ed-fail "invalid command suffix"))
                   w (walk k (e 'spat) (e 'sg) ())
                   [<w (e 'rep) [<>w (e 'snth) <>>w]]))
       m <spec rep <>spec f <>>spec
       last (ed-subst e a b m rep <f <>f)
       (? (0 < last) (ed-flags e <>>f)
          (e 'ing) 0
          (ed-fail "no match")))

   ; -- the ed dialect ---------------------------------------------------------------
   ; the argument after a command letter: a file name or !command, blanks off its front
   (ed-arg s k) (: n #s (snip s (ed-skip s k) n))
   ; a modified buffer stops q and e once; the same command again straight after goes
   (ed-guard e)
    (? (e 'dirty && (e 'warn) != ((e 'cmdn) - 1))
       (pin e 'warn (e 'cmdn), ed-fail "warning: buffer modified")
       0)
   (ed-do e s src)
    (ed-range e s 0 @ [j0 a1 a2 cnt]
      (: n #s j (ed-skip s j0)
         c (? (j < n) (s j) 10)
         k (j + 1)
         dot (e 'dot)
         (rng d1 d2) (? (0 < cnt) [a1 a2] [d1 d2])
         ; a range that must name real lines
         (real d1 d2) (: r (rng d1 d2) (? (1 <= <r) r (ed-fail "invalid address")))
         (none _) (? (0 < cnt) (ed-fail "unexpected address") 0)
         (end _) (? (k < n) (ed-fail "invalid command suffix") 0)
         (? (c = 10) (: t (? (0 < cnt) a2 (dot + 1))
                        _ (? (1 <= t <= (e 'n)) 0 (ed-fail "invalid address"))
                        (ed-print e t t ()))
            (c = 97 || c = 105)                  ; a i
             (: fl (ed-sfx s k) at (<>(rng dot dot))
                ts (ed-input src)
                _ (? (c = 97) (ed-add e at ts at)
                     (ed-add e (? (0 < at) (at - 1) 0) ts at))
                (ed-flags e fl))
            (c = 99)                              ; c
             (: r (real dot dot) fl (ed-sfx s k)
                ts (ed-input src)
                _ (ed-del e <r <>r)
                _ (ed-add e (<r - 1) ts (e 'dot))
                (ed-flags e fl))
            (c = 100)                             ; d
             (: r (real dot dot) fl (ed-sfx s k) _ (ed-del e <r <>r) (ed-flags e fl))
            (c = 101 || c = 69)                   ; e E
             (: _ (none 0) _ (? (c = 101) (ed-guard e) 0)
                nm (ed-arg s k)
                nm2 (? (0 < #nm) nm (0 < #(e 'file)) (e 'file) (ed-fail "no current filename"))
                b (ed-load e nm2)
                (? (charm? b) (ed-say e (show b)) (ed-fail ("cannot open input file " + nm2))))
            (c = 102)                             ; f
             (: _ (none 0) nm (ed-arg s k)
                _ (? (0 < #nm) (pin e 'file nm) 0)
                (? (0 < #(e 'file)) (say out (e 'file), put out 10) (ed-fail "no current filename")))
            (c = 103 || c = 118 || c = 71 || c = 86)   ; g v G V
             (: r (real 1 (e 'n))
                dl (? (k < n) (s k) 10)
                _ (? (dl = 10 || ed-blank? dl) (ed-fail "invalid pattern delimiter") 0)
                d (ed-delim s (k + 1) dl)
                m (ed-re e <>d)
                inter? (c = 71 || c = 86)
                cl (? inter? (ed-sfx s <d, "") (ed-glist (snip s <d n) src))
                (ed-global e <r <>r m (c = 118 || c = 86) cl inter? src))
            (c = 104) (none 0, end 0, (? (0 < #(e 'err)) (say out (e 'err), put out 10) 0))
            (c = 72) (none 0, end 0, pin e 'help !(e 'help), (? ((e 'help) && 0 < #(e 'err)) (say out (e 'err), put out 10) 0))
            (c = 106)                             ; j
             (: r (real dot (dot + 1)) fl (ed-sfx s k)
                _ (? (<r = <>r && cnt < 2) 0 (ed-join e <r <>r (\ x y (x + y))))
                (ed-flags e fl))
            (c = 107)                             ; k
             (: t (<>(rng dot dot))
                _ (? (1 <= t) 0 (ed-fail "invalid address"))
                x (? (k < n) (s k) 0)
                _ (? (97 <= x <= 122 && (k + 1) = n) 0 (ed-fail "invalid mark"))
                (pin (e 'marks) x (ed-id e t)))
            (c = 108 || c = 110 || c = 112)       ; l n p
             (: r (real dot dot) fl (c . ed-sfx s k) (ed-print e <r <>r fl))
            (c = 109 || c = 116)                  ; m t
             (: r (real dot dot)
                d (ed-addr e s k)
                _ (? (charm? <>d) 0 (ed-fail "invalid destination"))
                dst (ed-ok e <>d)
                fl (ed-sfx s (ed-skip s <d))
                _ (? (c = 109) (ed-move e <r <>r dst) (ed-copy e <r <>r dst))
                (ed-flags e fl))
            (c = 80) (none 0, end 0, pin e 'pon !(e 'pon))
            (c = 113 || c = 81)                   ; q Q
             (none 0, end 0, (? (c = 113) (ed-guard e) 0), pin e 'quit [0])
            (c = 114)                             ; r
             (: t (<>(rng (e 'n) (e 'n)))
                nm (ed-name e (ed-arg s k))
                (ed-say e (show (ed-read e t nm))))
            (c = 115) (: r (real dot dot) (ed-sub e s k <r <>r src))
            (c = 117) (none 0, end 0, ed-undo e)
            (c = 119 || c = 87)                   ; w W wq
             (: q? (k < n && s k = 113)
                r (rng (? (0 < (e 'n)) 1 0) (e 'n))
                _ (? (<r = 0 && 0 < (e 'n)) (ed-fail "invalid address") 0)
                nm (ed-name e (ed-arg s (? q? (k + 1) k)))
                b (ed-put e <r <>r nm (c = 87))
                _ (? (<r <= 1 && <>r = (e 'n) && !(ed-bang? nm)) (pin e 'dirty ()) 0)
                _ (ed-say e (show b))
                (? q? (pin e 'quit [0]) 0))
            (c = 122)                             ; z
             (: t (<>(rng (dot + 1) (dot + 1)))
                _ (? (1 <= t <= (e 'n)) 0 (ed-fail "invalid address"))
                ct (edx-count s k)
                w (? (charm? <>ct) <>ct (e 'win))
                fl (ed-sfx s <ct)
                _ (? (0 < w) (pin e 'win w) (ed-fail "invalid window"))
                (ed-print e t (min (e 'n) (t + w - 1)) fl))
            (c = 61) (end 0, (say out (show (? (0 < cnt) a2 (e 'n))), put out 10))
            (c = 33)                              ; !
             (: _ (none 0) r (ed-shcmd e (snip s k n))
                _ (? <>r (say out <r, put out 10) 0)
                _ (ed-sh-run <r)
                (ed-say e "!"))
            (ed-fail "unknown command"))))

   ; -- the ex dialect ---------------------------------------------------------------
   ; the words and the shortest head each answers to, first match winning
   edx-words '(("append" 1) ("change" 1) ("copy" 2) ("delete" 1) ("edit" 1) ("file" 1)
              ("global" 1) ("insert" 1) ("join" 1) ("list" 1) ("mark" 2) ("move" 1)
              ("number" 2) ("print" 1) ("put" 2) ("quit" 1) ("read" 1) ("set" 2)
              ("shell" 2) ("substitute" 1) ("t" 1) ("undo" 1) ("vglobal" 1) ("visual" 2)
              ("write" 1) ("wq" 2) ("xit" 1) ("yank" 2) ("z" 1) ("k" 1))
   (edx-word w)
    (: (go l) (? (atom? l) ()
                 (: nm <(<l) k <>(<l)
                    (? (k <= #w <= #nm && w = snip nm 0 #w) nm (go >l))))
       (go edx-words))
   ; a count after a word: [next count], count () when there is none
   (edx-count s k)
    (: n #s i (ed-skip s k)
       (num j acc) (? (j < n && 48 <= s j <= 57) (num (j + 1) (10 * acc + (s j - 48))) [j acc])
       (? (i < n && 48 <= s i <= 57) (num i 0) [i ()]))
   ; the end of one command in a line: the first | not escaped, else the end
   (edx-bar s k)
    (: n #s (go i) (? (n <= i) n (s i = 92 && (i + 1) < n) (go (i + 2)) (s i = 124) i (go (i + 1)))
       (go k))
   (edx-report e k what) (? (e 'silent || k <= (e 'report)) 0 (say out (show k + " " + what), put out 10))
   (edx-auto e) (? ((e 'silent) || (e 'ing) || !(e 'ap) || (e 'dot) < 1) 0
                  (ed-show e (e 'dot) (ed-line e (e 'dot)) ()))
   (edx-lines k) (show k + (k = 1 ? " line" " lines"))
   ; the register a d ya pu names: a..z, an upper case one appending; 34 the unnamed
   (edx-reg s k)
    (: i (ed-skip s k) c (? (i < #s) (s i) 0)
       (? (97 <= c <= 122 || 65 <= c <= 90) [(i + 1) c] [i 34]))
   (edx-keep e c ts)
    (: rs (e 'regs) lc (? (65 <= c <= 90) (c + 32) c)
       _ (pin rs lc (? (lc = c) ts (peep rs lc () + ts)))
       (? (c = 34) 0 (pin rs 34 ts)))
   ; the width a line's lead is, tabs at 8, and a lead of that width, tabs then blanks
   (edx-lead t) (: n #t (go i w) (? (n <= i) [i w] (t i = 9) (go (i + 1) (((w // 8) + 1) * 8))
                                   (t i = 32) (go (i + 1) (w + 1)) [i w])
                  (go 0 0))
   (edx-indent w) (: (go k acc) (? (k < 8) (acc + edx-blanks k) (go (k - 8) (acc + "\t"))) (go w ""))
   (edx-blanks k) (? (k < 1) "" (" " + edx-blanks (k - 1)))
   (edx-shift e a b by)
    (: ls (ed-span e a b)
       (one r) (: t <>r (? (#t = 0) r
                           (: l (edx-lead t) w (max 0 (<>l + by))
                              [<r (edx-indent w + snip t <l #t)])))
       _ (ed-splice e a b (map one ls))
       (pin e 'dot b))
   ; ex's join: the next line's lead dropped, one blank between, two after a period,
   ; none before a ) or after a blank
   (edx-join2 x y)
    (: l (edx-lead y) t (snip y <l #y) n #x
       sep (? (#t = 0 || n = 0) "" (t 0 = 41) "" (ed-blank? (x (n - 1))) "" (x (n - 1) = 46) "  " " ")
       (x + sep + t))
   (edx-fileinfo e)
    (: nm (? (0 < #(e 'file)) (e 'file) "[No Name]") n (e 'n)
       (say out ("\"" + nm + "\"" + ((e 'dirty) ? " [Modified]" "") + " " + edx-lines n +
                 (? (0 < n) (" --" + show (((e 'dot) * 100) // n) + "%--") "") + "\n")))
   (edx-counts e nm b) (? (e 'silent) 0
                         (say out ("\"" + nm + "\" " + show (e 'n) + "L, " + show b + "B\n")))
   ; set: [no]number nu list ap autoprint ic ignorecase, sw= shiftwidth= report=, a
   ; name? to ask, all or nothing to hear the lot
   edx-opts '(("number" nu) ("nu" nu) ("list" list) ("autoprint" ap) ("ap" ap)
             ("ignorecase" ic) ("ic" ic) ("shiftwidth" sw) ("sw" sw) ("report" report)
             ("window" win) ("prompt" pon))
   (edx-set e arg)
    (: (says k) (: v (e k)
                   (? (charm? v && !(elem k '(nu list ap ic pon))) (show k + "=" + show v)
                      (v ? (show k) ("no" + show k))))
       (all _) (each '(ap ic list nu report sw win) (k \ (say out (says k + "\n"))), 0)
       (one w)
        (: n #w
           (eq i) (? (n <= i) () (w i = 61) i (eq (i + 1)))
           q? (0 < n && w (n - 1) = 63)
           w2 (? q? (snip w 0 (n - 1)) w)
           j (eq 0)
           nm (? (charm? j) (snip w2 0 j) w2)
           no? (2 < #nm && snip nm 0 2 = "no")
           key (: (look l) (? (atom? l) () (<(<l) = nm) <>(<l) (look >l)) (look edx-opts))
           key2 (? (!key && no?) (: (look l) (? (atom? l) () (<(<l) = snip nm 2 #nm) <>(<l) (look >l)) (look edx-opts)) key)
           (? !key2 (ed-fail ("unknown option: " + nm))
              q? (say out (says key2), put out 10)
              (charm? j) (: v (unum (snip w2 (j + 1) #w2))
                            (? (charm? v && charm? (e key2) && !(elem key2 '(nu list ap ic pon)))
                               (pin e key2 v) (ed-fail ("invalid argument: " + w))))
              (elem key2 '(nu list ap ic pon)) (pin e key2 (? !key () 1))
              (say out (says key2), put out 10)))
       ws (usplit 32 (ed-trim arg))
       (? (0 = #(ed-trim arg) || ed-trim arg = "all") (all 0)
          (each (filter (w \ 0 < #w) ws) one)))
   (edx-visual e)
    (: vb (cite 'vi 'vi-buffer)
       _ (? !vb (ed-fail "no visual mode here") 0)
       _ (flush out)
       _ (vb (ed-texts e 1 (e 'n)) (e 'file) (e 'dirty) (e 'dot))
       (pin e 'quit [0]))
   ; one ex command line: the range, the word, its arguments; a | runs the rest after.
   ; colons ahead of the range, or between it and the word, are vi's habit and nothing
   (edx-colons s i) (: i2 (ed-skip s i) (? (i2 < #s && s i2 = 58) (edx-colons s (i2 + 1)) i2))
   (edx-do e s0 src)
    (: s (snip s0 (edx-colons s0 0) #s0)
     (ed-range e s 0 @ [j0 a1 a2 cnt]
      (: n #s
         j (edx-colons s j0)
         c (? (j < n) (s j) 124)
         we (: (go i) (? (i < n && alpha? (s i)) (go (i + 1)) i) (go j))
         w (? (alpha? c) (snip s j we) (string c))
         word (? (alpha? c) (edx-word w) w)
         ; `ka` is k with its letter
         word2 (? (!word && #w = 2 && w 0 = 107) "k" word)
         k0 (? (alpha? c) (? (!word && #w = 2 && w 0 = 107) (j + 1) we) (? (c = 124) j (j + 1)))
         bang (k0 < n && s k0 = 33 && word2 != "!")
         k (? bang (k0 + 1) k0)
         whole? (elem word2 '("global" "vglobal" "!" "\""))
         bar (? whole? n (edx-bar s k))
         arg (snip s k bar)
         dot (e 'dot) nl (e 'n)
         (rng d1 d2) (? (0 < cnt) [a1 a2] [d1 d2])
         (real d1 d2) (: r (rng d1 d2) (? (1 <= <r) r (ed-fail "invalid range")))
         ; a count takes the lines from the range's last on
         (counted r arg) (edx-count arg 0 @ [i ct]
                           (? (charm? ct) (? (ct < 1) (ed-fail "invalid count")
                                             [<>r (min nl (<>r + ct - 1)) (snip arg i #arg)])
                              [<r <>r arg]))
         (flagsof t) (: t2 (ed-trim t) (map (x \ (x = 35 ? 110 x)) (ed-sfx t2 0)))
         _ (? !word2 (ed-fail ("not an editor command: " + w)) 0)
         _ (? (word2 = "|")
              (: t (? (0 < cnt) a2 (dot + 1))
                 _ (? (1 <= t <= nl) 0 (ed-fail "invalid range"))
                 (ed-print e t t ()))
              (word2 = "\"") 0
              (word2 = "append" || word2 = "insert")
               (: at (<>(rng dot dot))
                  ts (ed-input src)
                  (? (word2 = "append") (ed-add e at ts at)
                     (ed-add e (? (0 < at) (at - 1) 0) ts at)))
              (word2 = "change")
               (: r (counted (real dot dot) arg)
                  ts (ed-input src)
                  _ (edx-keep e 34 (ed-del e <r <>r))
                  (ed-add e (<r - 1) ts (e 'dot)))
              (word2 = "delete" || word2 = "yank")
               (: g (edx-reg arg 0) r (counted (real dot dot) (snip arg <g #arg))
                  _ (flagsof <>>r)
                  ts (? (word2 = "delete") (ed-del e <r <>r) (ed-texts e <r <>r))
                  _ (edx-keep e <>g ts)
                  _ (edx-report e #ts (? (word2 = "delete") "fewer lines" "lines yanked"))
                  (? (word2 = "delete") (edx-auto e) 0))
              (word2 = "put")
               (: g (edx-reg arg 0) at (<>(rng dot dot))
                  ts (peep (e 'regs) (? (65 <= <>g <= 90) (<>g + 32) <>g) ())
                  _ (? (two? ts) 0 (ed-fail "nothing in register"))
                  _ (ed-add e at ts at)
                  (edx-report e #ts "more lines"))
              (word2 = "join")
               (: r0 (real dot (dot + 1))
                  r (edx-count arg 0 @ [_ ct]
                      (? (charm? ct) [<>r0 (min nl (<>r0 + ct - 1))]
                         (<r0 = <>r0) [<r0 (min nl (<r0 + 1))]
                         r0))
                  _ (ed-join e <r <>r (? bang (\ x y (x + y)) edx-join2))
                  (edx-auto e))
              (word2 = "move" || word2 = "copy" || word2 = "t")
               (: r (real dot dot)
                  d (ed-addr e arg 0)
                  _ (? (charm? <>d) 0 (ed-fail "invalid destination"))
                  dst (ed-ok e <>d)
                  _ (? (word2 = "move") (ed-move e <r <>r dst) (ed-copy e <r <>r dst))
                  _ (edx-report e (<>r - <r + 1) (? (word2 = "move") "lines moved" "more lines"))
                  (edx-auto e))
              (word2 = "print" || word2 = "list" || word2 = "number" || word2 = "#")
               (: r (counted (real dot dot) arg)
                  fl (flagsof <>>r)
                  own (? (word2 = "list") [108] (word2 = "print") [] [110])
                  (ed-print e <r <>r (own + fl)))
              (word2 = "substitute" || word2 = "&" || word2 = "~")
               (: r (real dot dot)
                  t (ed-trim arg)
                  ; & and ~ repeat: ~ with the last pattern searched, not substituted
                  amp? (0 < #t && t 0 = 38)
                  t2 (? (word2 = "substitute") t
                        (word2 = "~") ("r" + (? amp? (snip t 1 #t) t))
                        amp? (snip t 1 #t) t)
                  ; a count at the end, standing apart: the lines from the range's last on
                  cl (: (go i) (? (0 < i && 48 <= t2 (i - 1) <= 57) (go (i - 1)) i) (go #t2))
                  ct (? (cl < #t2 && (cl = 0 || ed-blank? (t2 (cl - 1)))) (unum (snip t2 cl #t2)) ())
                  t3 (? (charm? ct) (snip t2 0 cl) t2)
                  r2 (? (charm? ct) [<>r (min nl (<>r + ct - 1))] r)
                  _ (ed-sub e t3 0 <r2 <>r2 src)
                  (edx-auto e))
              (word2 = "global" || word2 = "vglobal")
               (: r (real 1 nl)
                  t (snip s (ed-skip s k) n)
                  dl (? (0 < #t) (t 0) 10)
                  _ (? (dl = 10 || alpha? dl || dl = 92 || dl = 34 || dl = 124) (ed-fail "invalid pattern delimiter") 0)
                  d (ed-delim t 1 dl)
                  m (ed-re e <>d)
                  (ed-global e <r <>r m (bang || word2 = "vglobal") (ed-glist (snip t <d #t) src) () src))
              (word2 = "undo") (ed-undo e, edx-auto e)
              (word2 = "write" || word2 = "wq" || word2 = "xit")
               (: t (ed-trim arg)
                  app? (1 < #t && t 0 = 62 && t 1 = 62)
                  nm0 (? app? (ed-trim (snip t 2 #t)) t)
                  go? (? (word2 = "xit") ((e 'dirty) || 0 < #nm0) 1)
                  _ (? (e 'ro && !bang && !(ed-bang? nm0) && go?) (ed-fail "file is read only (add ! to override)") 0)
                  _ (? go?
                       (: r (rng (? (0 < nl) 1 0) nl)
                          nm (ed-name e nm0)
                          b (ed-put e <r <>r nm app?)
                          _ (? (<r <= 1 && <>r = nl && nm = (e 'file)) (pin e 'dirty ()) 0)
                          (? (ed-bang? nm) 0 (edx-counts e nm b)))
                       0)
                  (? (word2 = "write") 0 (pin e 'quit [0])))
              (word2 = "quit")
               (? (e 'dirty && !bang) (ed-fail "no write since last change (add ! to override)")
                  (pin e 'quit [0]))
              (word2 = "edit")
               (: nm0 (ed-trim arg)
                  _ (? (e 'dirty && !bang) (ed-fail "no write since last change (add ! to override)") 0)
                  nm (? (0 < #nm0) nm0 (0 < #(e 'file)) (e 'file) (ed-fail "no current filename"))
                  b (ed-load e nm)
                  (? (charm? b) (edx-counts e nm b) (ed-say e ("\"" + nm + "\" [New]"))))
              (word2 = "read")
               (: at (<>(rng dot dot))
                  nm (ed-name e (ed-trim arg))
                  b (ed-read e at nm)
                  (? (ed-bang? nm) 0 (edx-counts e nm b)))
              (word2 = "file")
               (: t (ed-trim arg) _ (? (0 < #t) (pin e 'file t) 0) (edx-fileinfo e))
              (word2 = "k" || word2 = "mark")
               (: t (<>(rng dot dot)) x (ed-trim arg)
                  _ (? (1 <= t) 0 (ed-fail "invalid range"))
                  _ (? (#x = 1 && 97 <= x 0 <= 122) 0 (ed-fail "invalid mark"))
                  (pin (e 'marks) (x 0) (ed-id e t)))
              (word2 = "set") (edx-set e arg)
              (word2 = "shell")
               (: sh (getenv "SHELL") _ (flush out)
                  p (spawn [(? (string? sh) sh "sh")])
                  (? (nom? p) (ed-fail "cannot run the shell") (wait p)))
              (word2 = "visual") (edx-visual e)
              (word2 = "z")
               (: t (<>(rng dot dot)) _ (? (1 <= t <= nl) 0 (ed-fail "invalid range"))
                  ct (edx-count arg 0)
                  w (? (charm? <>ct) <>ct (e 'win))
                  (ed-print e t (min nl (t + w - 1)) ()))
              (word2 = "=") (say out (show (? (0 < cnt) a2 nl)), put out 10)
              (word2 = "<" || word2 = ">")
               (: r0 (real dot dot)
                  ; the repeats: >> is twice the width
                  (reps i m) (? (i < #arg && arg i = c) (reps (i + 1) (m + 1)) [i m])
                  rp (reps 0 1)
                  r (counted r0 (snip arg <rp #arg))
                  _ (edx-shift e <r <>r ((c = 62 ? 1 -1) * <>rp * (e 'sw)))
                  (edx-auto e))
              (word2 = "!")
               (: t (snip s k n) r (ed-shcmd e t)
                  (? (0 < cnt)
                      ; a range goes through the command and comes back in its place
                      (: rr (real dot dot)
                         o (ed-sh-out-in <r (unlines (ed-texts e <rr <>rr)))
                         ts (lines o)
                         _ (ed-del e <rr <>rr)
                         _ (ed-add e (<rr - 1) ts (e 'dot))
                         (edx-report e #ts "lines filtered"))
                     ((? <>r (say out <r, put out 10) 0), ed-sh-run <r, ed-say e "!")))
              (ed-fail ("not an editor command: " + w)))
         (? (bar < n) (edx-do e (snip s (bar + 1) n) src) 0))))
   ; a range through a command: its lines in, its output back
   (ed-sh-out-in cmd t)
    (: _ (flush out) pi (pipe 0) po (pipe 0)
       _ (? (nom? pi || nom? po) (ed-fail "cannot pipe") 0)
       p (spawnio ["sh" "-c" cmd] <pi >po -1 [>pi <po] -1 0)
       _ (close <pi) _ (close >po)
       ; the writer in a task of its own, so a command that answers as it reads
       ; cannot wedge on a full pipe
       w (twirl (_ \ (: q (fdopen >pi) _ (say q t) (close q))) 0)
       q (fdopen <po) o (slurp q) _ (close q)
       _ (catch w)
       _ (? (charm? p && 0 <= p) (wait p) 0)
       (? (string? o) o ""))

   ; -- the loop ---------------------------------------------------------------------
   (ed-exec e s src) (? (e 'ex) (edx-do e s src) (ed-do e s src))
   ; text lines up to a lone ".", or the source's end
   (ed-input src)
    (: (go acc) (: l (src 0) (? (!(string? l) || l = ".") (rev acc) (go (l . acc))))
       (go ()))
   (ed-complain e m)
    (pin e 'err m, (? (e 'ex) (flush out, say err (m + "\n"), flush err)
            (say out "?\n", (? (e 'help) (say out m, put out 10) 0))), (? (e 'tty) 0 (pin e 'quit [1])))
   ; one command line from the top: an error lands here, and a change the command made
   ; is what u will undo -- g's whole visit as one
   (ed-top e l src)
    (: pre [(e 'buf) (e 'dot) (e 'n)] g0 (e 'gen)
       _ (pins e 'cmdn (e 'cmdn + 1) 'undid () 'ing ())
       _ (trap (_ \ (ed-exec e l src)) ()
               (\ a b (? (a = 'ederr) (ed-complain e b) (scare a b))))
       (? ((e 'gen) != g0 && !(e 'undid)) (pin e 'undo pre) 0))
   (ed-loop e src)
    (: (go _) (? (two? (e 'quit)) <(e 'quit)
                 (: l (src 1)
                    (? (string? l) (ed-top e l src, go 0) 0)))
       (go 0))
   ; stdin a line at a time, the prompt ahead of a command line
   (ed-stdin e rd)
    (cmd? \
            (: pr (? (e 'ex) (? (cmd? && e 'tty && e 'pon) ":" "")
                     (? (cmd? && e 'pon) (e 'prompt) ""))
               _ (? (0 < #pr) (say out pr) 0)
               _ (flush out)
               l (urd-line rd)
               (? (two? l) <l ())))
   (ed-run e f cmds)
    (: _ (pin e 'tty (two? (tty 0)))
       _ (? (string? f)
            (: b (ed-load e f)
               (? (charm? b)
                   (? (e 'ex) (edx-counts e f b) (ed-say e (show b)))
                  (e 'ex) (ed-say e ("\"" + f + "\" [New]"))
                  (say err (f + ": No such file or directory\n"), flush err)))
            0)
       rd (urd in)
       src (ed-stdin e rd)
       _ (each cmds (c \ (? (two? (e 'quit)) 0 (ed-top e c src))))
       st (ed-loop e src)
       _ (urd-give rd)
       _ (flush out)
       st)

   (ed-main as)
    (: e (ed-new ())
       (opts l) (? (atom? l) ()
                   (: a <l
                      (? (a = "-s" || a = "-") (pin e 'silent 1, opts >l)
                         (a = "-p") (? (two? >l) (pins e 'prompt <>l 'pon 1, opts >>l) (udie 2 ed-usage))
                         (2 < #a && snip a 0 2 = "-p") (pins e 'prompt (snip a 2 #a) 'pon 1, opts >l)
                         (a = "--") >l
                         (1 < #a && a 0 = 45) (udie 2 ("ed: unknown option " + a))
                         l)))
       fs (opts as)
       _ (? (two? fs && two? >fs) (udie 2 ed-usage) 0)
       (ed-run e (? (two? fs) <fs ()) ()))
   (ex-main as)
    (: e (ed-new 1)
       _ (pin e 'pon 1)
       (opts l cs) (? (atom? l) [() (rev cs)]
                      (: a <l
                         (? (a = "-s" || a = "-") (pins e 'silent 1 'pon (), opts >l cs)
                            (a = "-R") (pin e 'ro 1, opts >l cs)
                            (a = "-v") (opts >l ("visual" . cs))       ; ex -v is vi
                            (a = "-c") (? (two? >l) (opts >>l (<>l . cs)) (udie 2 ex-usage))
                            (2 < #a && snip a 0 2 = "-c") (opts >l (snip a 2 #a . cs))
                            (0 < #a && a 0 = 43) (opts >l ((? (1 < #a) (snip a 1 #a) "$") . cs))
                            (a = "--") [>l (rev cs)]
                            (1 < #a && a 0 = 45) (udie 2 ("ex: unknown option " + a))
                            [l (rev cs)])))
       r (opts as ())
       fs <r
       _ (? (two? fs && two? >fs) (udie 2 ex-usage) 0)
       (ed-run e (? (two? fs) <fs ()) <>r))
)
) ; module 'kore
