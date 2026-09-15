; mc -- a two-pane file browser on the stage lupa and design share. each pane holds its
; own directory, tab crosses between them, enter descends and "u" climbs. a name wears
; the colour ls gives its class, off the same four the lstat already answers.
;
;   j k / arrows  the cursor      ^b ^f  a page        g G  the ends
;   tab  the other pane           enter  descend       u  the parent
;   r  re-read the pane           q  leave
;
; every key is a pure step on the state and every frame a pure lay into a port, so the
; tool gates headless; only mc-run ties the tty, on cli's stage.
; usage: love mc [DIR [DIR]]
(module (mc mc-main mc-run mc-new mc-key mc-frame mc-read mc-pane mc-at mc-goto mc-cell)
(borrow 'posix)
(:
 (mc-rfind s b) (: (go k) (? (k < 0) (0 - 1) (s k = b) k (go (k - 1))) (go (#s - 1)))

 ; --- an entry is [name mode size], the mode an LSTAT's: a link is a link here -------
 (mc-join d n) (d @ "/" ("/" + n) (d + "/" + n))
 (mc-dir? e) (16384 = e 1 & 61440)
 (mc-link? e) (40960 = e 1 & 61440)
 ; is the path a directory with the links FOLLOWED -- what enter asks, since a link to
 ; a directory is one to walk into even though its own mode says otherwise
 (mc-dirat? q) (: st (stat q) (two? st && 16384 = st 2 & 61440))
 ; the sgr a name wears, "" for none: ls's four classes (apps/kore/fs.l's uls-hue). only a
 ; broken link costs a second call, since only the stat behind a link can miss.
 (mc-hue d e)
  (? (mc-dir? e) "\e[1;34m"
     (mc-link? e) (two? (stat (mc-join d <e)) ? "\e[36m" "\e[31m")
     (e 1 & 73) "\e[32m"
     "")
 (mc-ent d n) (: st (lstat (mc-join d n)) (? (two? st) [n (st 2) <st] ()))
 ; a directory's rows: "..", then the directories, then the rest, each by name. a name
 ; that will not stat is dropped, the way ls drops it, and the root owes no "..".
 ; a path that is no directory answers () -- which is what lets mc-cd refuse a move
 ; rather than stand the pane on nothing.
 (mc-read d)
  (? !(mc-dirat? d) ()
     (: ns (readdir d)
        es (filter two? (map (mc-ent d) (? (two? ns) ns ())))
        by (a \ b \ <a <= <b)
        ds (sortby by (filter mc-dir? es))
        fs (sortby by (filter (nil? * mc-dir?) es))
        (d @ "/" (ds + fs) ([".." 16384 0] . ds + fs))))

 ; --- a pane: {'dir 'es 'cur 'top} --------------------------------------------------
 (mc-pane d) (pins {} 'dir d 'es (mc-read d) 'cur 0 'top 0)
 (mc-at p) <(drop (p 'cur) (p 'es))
 ; the cursor, and the window that follows it. top moves only far enough to keep the
 ; cursor on the screen, which is what makes ^f read as a page and not as a jump.
 (mc-goto p i n)
  (: es (p 'es) m #es
     c (? (i < 0) 0 (m <= i) (? m (m - 1) 0) i)
     t (p 'top)
     t2 (? (c < t) c (t + n <= c) (c - n + 1) t)
     (pins p 'cur c 'top (t2 < 0 ? 0 t2)))
 ; a pane that cannot read the new directory keeps the one it has, so an unreadable
 ; path is a key that did nothing rather than an empty pane with no way back.
 (mc-cd p d) (: es (mc-read d) (two? es ? (pins p 'dir d 'es es 'cur 0 'top 0) p))
 (mc-parent d) (: k (mc-rfind d 47) (? (d = "/") "/" (k < 1) "/" (snip d 0 k)))
 (mc-enter p)
  (: e (mc-at p)
     (? (one? e) p
        (<e = "..") (mc-cd p (mc-parent (p 'dir)))
        (: q (mc-join (p 'dir) <e) (? (mc-dirat? q) (mc-cd p q) p))))

 ; --- the step: every arm answers the state, so an idle key answers it unchanged -----
 (mc-act s) (s $ s 'act ? 'r 'l)
 (mc-key s c)
  (: p (mc-act s) n (s 'rows) cur (p 'cur) (c @- s
   (-8 || 107) (mc-goto p (cur - 1) n, s)
   (-9 || 106) (mc-goto p (cur + 1) n, s)
   2             (mc-goto p (cur - n) n, s)
   6             (mc-goto p (cur + n) n, s)
   103           (mc-goto p 0 n, s)
   71            (mc-goto p (#(p 'es) - 1) n, s)
   (9 || -1 || -2) (pin s 'act (? (s 'act) 0 1))
   (10 || 13)  (mc-enter p, s)
   117           (mc-cd p (mc-parent (p 'dir)), s)
   114           (mc-cd p (p 'dir), s)
   (113 || -7) (pin s 'over 1)))

 ; --- the frame ---------------------------------------------------------------------
 ; the two panes side by side with a rule between, a header each, the cursor's path
 ; underneath and the keys along the bottom. every row is cut to the screen and cleared
 ; to its end, so a narrow terminal loses the right pane's tail and nothing else.
 (mc-size e) (? (mc-dir? e) "<dir>" (show (e 2)))
 ; sel: 0 none, 1 the active pane's cursor, 2 the other pane's -- the idle pane keeps
 ; a mark so tab comes back to where it left, without claiming the eye the active one has
 (mc-cell d e w sel)                           ; one listing row, fitted plain then dressed
  (: sz (mc-size e)
     k (w - #sz - 2)
     txt (" " + (edfit <e (? (k < 1) 1 k) " ") + " " + sz)
     row (edfit txt w " ")
     h (mc-hue d e)
     (? (sel = 1) ("\e[7m" + row + "\e[0m")
        (sel = 2) ("\e[4m" + row + "\e[0m")
        #h (h + row + "\e[0m")
        row))
 (mc-row p k w act?)
  (: es (p 'es) i ((p 'top) + k)
     (? (#es <= i) (edfit "" w " ")
        (mc-cell (p 'dir) <(drop i es) w (? (i != (p 'cur)) 0 act? 1 2))))
 (mc-head d w) ("\e[7m" + (edfit (" " + d) w " ") + "\e[0m")
 mc-keys " tab pane  enter descend  u up  g G ends  r reread  q quit"
 (mc-frame s w h)
  (: j (jug 0)
     rows (? (h < 6) 1 (h - 3))
     _ (pin s 'rows rows)
     lw ((w - 1) // 2)
     rw (w - 1 - lw)
     l (s 'l) r (s 'r)
     _ (say j "\e[H\e[0m")
     _ (say j (mc-head (l 'dir) lw + "\e[0m|" + mc-head (r 'dir) rw + "\e[0m\e[K\r\n"))
     _ (each ^rows (k \ say j $
        mc-row l k lw (0 = s 'act) + "\e[0m|" + mc-row r k rw (1 = s 'act) + "\e[0m\e[K\r\n"))
     p (mc-act s) e (mc-at p)
     _ (say j (edfit (" " + (two? e ? (mc-join (p 'dir) <e) (p 'dir))) w " " + "\e[K\r\n"))
     _ (say j ("\e[7m" + edfit mc-keys w " " + "\e[0m\e[K\e[?25l"))
     (slurp j))

 ; --- the runner: the tool on cli's stage -------------------------------------------
 (mc-new ld rd) (pins {} 'l (mc-pane ld) 'r (mc-pane rd) 'act 0 'rows 20 'over 0)
 (mc-run ld rd)
  (: s (mc-new ld rd)
     (stage (mc-frame s) (mc-key s) (\ _ (s 'over))))
 mc-usage "usage: love mc [DIR [DIR]]"
 (mc-main as)
  (: d1 (two? as ? <as ("" + (cwd 0)))
     d2 (two? as && two? >as ? <>as d1)
     (? !(mc-dirat? d1) (puts ("mc: " + d1 + ": not a directory\n"), 1)
        !(mc-dirat? d2) (puts ("mc: " + d2 + ": not a directory\n"), 1)
        (mc-run d1 d2)))
 _ (pins (cite 'verbs 'tab) 'mc (udoor 'mc mc-main mc-usage 1 1)))
) ; module mc
