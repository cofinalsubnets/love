; mc -- a two-pane file browser on the stage lupa and design share. each pane holds its
; own directory, tab crosses between them, enter descends and "u" climbs. a name wears
; the colour ls gives its class, off the same four the lstat already answers.
;
;   j k / arrows  the cursor      ^b ^f  a page        g G  the ends
;   tab  the other pane           enter  descend (a file: to whoever lent mc 'open)
;   u  the parent
;   v ^q  quick view: the other pane shows the cursor's entry -- a picture fitted, text's
;         first lines, a directory's count; again to go back
;   t  thumbnails: the other pane lays the active pane's pictures as a grid
;   /  find: every file under the pane's directory, narrowed as it is typed at (seek.l);
;      enter takes the pane to the file, esc back
;   r  re-read the pane           q  leave
;
; pictures are drawn by kore pic (src/apps/kore/pic.l): in blocks, or sixel or kitty's graphics
; where the terminal answers to them and -g does not say otherwise. a thumbnail is cached by
; path, mtime and size in cells; one that is dear to decode waits for the keys to rest.
;
; every key is a pure step on the state and every frame a pure lay into a port, so the
; tool gates headless; only mc-run ties the tty, on a stage like cli's.
; usage: love mc [-g block|sixel|kitty|auto] [DIR [DIR]]
(module (mc mc-main mc-run mc-new mc-key mc-frame mc-read mc-pane mc-at mc-goto mc-cell mc-vis)
(borrow 'posix)
(borrow 'tui)
(borrow ((cite 'seek) @ m (m ? m "src/apps/seek.l")))
(:
 mc-kitkeys "i=7,p=1,C=1,"          ; kitty's keys: image 7, placement 1, cursor stays
 (mc-rfind s b) (: (go k) (? (k < 0) (0 - 1) (s k = b) k (go (k - 1))) (go (#s - 1)))

 ; --- an entry is [name mode size], the mode an LSTAT's: a link is a link here -------
 (mc-join d n) (d @ "/" ("/" + n) (d + "/" + n))
 (mc-dir? e) (16384 = e 1 & 61440)
 (mc-link? e) (40960 = e 1 & 61440)
 ; is the path a directory with the links FOLLOWED -- what enter asks, since a link to
 ; a directory is one to walk into even though its own mode says otherwise
 (mc-dirat? q) (stat q @ st (two? st && 16384 = st 2 & 61440))
 ; the sgr a name wears, "" for none: ls's four classes (src/apps/kore/fs.l's uls-hue). only a
 ; broken link costs a second call, since only the stat behind a link can miss.
 (mc-hue d e)
  (? (mc-dir? e) "\e[1;34m"
     (mc-link? e) (two? (stat (mc-join d <e)) ? "\e[36m" "\e[31m")
     (e 1 & 73) "\e[32m"
     "")
 (mc-ent d n) (lstat (mc-join d n) @ st (two? st ? [n (st 2) <st]))
 ; a directory's rows: "..", then the directories, then the rest, each by name. a name
 ; that will not stat is dropped, the way ls drops it, and the root owes no "..".
 ; a path that is no directory answers () -- which is what lets mc-cd refuse a move
 ; rather than stand the pane on nothing.
 (mc-read d)
  (!(mc-dirat? d) ? ()
     (: ns (readdir d)
        es (filter two? (map (mc-ent d) (two? ns ? ns)))
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
     c (? (i < 0) 0 (m <= i) (m ? (m - 1) 0) i)
     t (p 'top)
     t2 (tui-settle c t n)
     (pins p 'cur c 'top (t2 < 0 ? 0 t2)))
 ; a pane that cannot read the new directory keeps the one it has, so an unreadable
 ; path is a key that did nothing rather than an empty pane with no way back.
 (mc-cd p d) (mc-read d @ es (two? es ? (pins p 'dir d 'es es 'cur 0 'top 0) p))
 (mc-parent d) (mc-rfind d 47 @ k (? (d = "/") "/" (k < 1) "/" (snip d 0 k)))
 ; a directory is entered; a file goes to 'open, when whoever runs mc lent one (vi's :ex)
 (mc-enter s p)
  (mc-at p @ e
     (? (atom? e) p
        (<e = "..") (mc-cd p (mc-parent (p 'dir)))
        (mc-join (p 'dir) <e @ q (? (mc-dirat? q) (mc-cd p q)
                                     !(nil? (s 'open)) ((s 'open) q, p)
                                     p))))

 ; --- the step: every arm answers the state, so an idle key answers it unchanged -----
 ; 'qv is the other pane's use: 0 its own listing, 1 quick view, 2 thumbnails
 (mc-act s) (s $ s 'act ? 'r 'l)
 ; / : the files under the active pane's directory, in a picker drawn in mc's place; a
 ; pick takes the pane to the file's directory with the cursor on it
 (mc-find s p)
  (: d (p 'dir)
     (rel f) (starts? f (d + "/") ? (snip f (#d + 1) #f) f)
     (pin s 'seek (seek-new (seek-files d) (f \ rel f) rel "find")))
 (mc-found s f)
  (: p (mc-act s) dir (mc-parent f) nm (snip f (mc-rfind f 47 + 1) #f)
     (mc-cd p dir,
      (: (at l i) (? !(two? l) 0 (<(<l) = nm) i (at >l (i + 1)))
         (mc-goto p (at (p 'es) 0) (s 'rows)))))
 (mc-seekey s c)
  (: d (s 'seek)
     (seek-key d c,
      d 'over ? (pin s 'seek (), d 'pick @ f (string? f ? (mc-found s f) 0)) 0,
      s))
 (mc-key s c)
  (: p (mc-act s) n (s 'rows) cur (p 'cur) (? !(nil? (s 'seek)) (mc-seekey s c) (c @- s
   (-8 || 107) (mc-goto p (cur - 1) n, s)
   (-9 || 106) (mc-goto p (cur + 1) n, s)
   2             (mc-goto p (cur - n) n, s)
   6             (mc-goto p (cur + n) n, s)
   103           (mc-goto p 0 n, s)
   71            (mc-goto p (#(p 'es) - 1) n, s)
   (9 || -1 || -2) (pin s 'act (s 'act ? 0 1))
   (10 || 13)  (mc-enter s p, s)
   117           (mc-cd p (mc-parent (p 'dir)), s)
   114           (mc-cd p (p 'dir), s)
   (118 || 17)   (pin s 'qv (s 'qv = 1 ? 0 1))
   116           (pin s 'qv (s 'qv = 2 ? 0 2))
   47            (mc-find s p, s)
   (113 || -7) (pin s 'over 1))))

 ; --- looking inside: text, bytes and directories ------------------------------------
 ; the first n bytes of a regular file, "" of anything else -- opening a fifo would park
 (mc-peek q n)
  (stat q @ st
     (!(two? st && 32768 = st 2 & 61440) ? ""
        (open q "r" @ p
           (!(hot? p) ? ""
              (: b (cask n) k (swig p b) (close p,
                                          (charm? k && 0 < k ? (snip (string b) 0 k) "")))))))
 ; a line with its control bytes shown: a tab to the next stop of 8, the rest as ^X
 (mc-vis l)
  (: j (jug 0)
     (go i col)
      (#l <= i ? (slurp j)
         (l i @ c
            (? (c = 9) (8 - col % 8 @ k (say j (edfit "" k " "), go (i + 1) (col + k)))
               (c < 32 || c = 127) (say j ("^" + string (c = 127 ? 63 (c + 64))), go (i + 1) (col + 2))
               (say j (snip l i (i + 1)), go (i + 1) (col + (128 <= c < 192 ? 0 1))))))
     (go 0 0))
 (mc-hx v d) (d < 1 ? "" (mc-hx (v // 16) (d - 1) + snip "0123456789abcdef" (v % 16) (v % 16 + 1)))
 (mc-nul? b) (: (go i) (? (#b <= i) () (b i = 0) 1 (go (i + 1))) (go 0))
 ; a binary file as a dump: offset, the bytes in hex, and those that print
 (mc-dump b n w)
  (: k (max 1 (min 16 ((w - 10) // 4)))
     (row o) (min k (#b - o) @ m
                (mc-hx o 6 + " " + catmap (i \ i < m ? (" " + mc-hx (b (o + i)) 2) "   ") ^k + "  "
                 + catmap (i \ (b (o + i) @ c (32 <= c < 127 ? (snip b (o + i) (o + i + 1)) "."))) ^m))
     (map (r \ row (r * k)) ^(min n ((#b + k - 1) // k))))
 ; the head of a file as rows: its lines, or a dump where a nul says it is not text. a
 ; line the peek cut short is left off
 (mc-text b n w)
  (? (#b = 0) ["(empty)"]
     (mc-nul? b) (mc-dump b n w)
     (: ls (lines b) ls2 (#b < 4096 || #ls < 2 ? ls (take (#ls - 1) ls))
        (map mc-vis (take n ls2))))
 (mc-pad rs) (map (r \ " " + r) rs)
 (mc-count q n)
  (readdir q @ ns
     (atom? ns && ns != () ? ["cannot read"]
        (#ns @ m ([(show m + (m = 1 ? " entry" " entries")) ""] + take (n - 2) (sort ns)))))

 ; --- pictures ----------------------------------------------------------------------
 ; a picture fitted to cols by rows cells, never enlarged, by pic's nearest sampler ->
 ; [cells-wide rows graphic]: block rows and "", or blank rows under a sixel or kitty's
 (mc-thumb im cols rows gm cw ch deep)
  (: kp (cite 'kore)
     (near s) (kp 'pic-near im 0 0 s (max 1 (int (im 0 / s))) (max 1 (int (im 1 / s))))
     (gm = "block" ?
         (near (kp 'pic-fit im cols rows) @ sm [(sm 0) (kp 'pic-cells sm deep) ""])
        (: ph (rows * ch) ph2 (max 1 (gm @ "sixel" (6 * (ph // 6)) ph))
           sm (near (max 1.0 (max (im 0 / (cols * cw)) (im 1 / ph2))))
           g (gm @ "sixel" (kp 'pic-sixel sm) (kp 'pic-kits sm mc-kitkeys))
           [((sm 0 + cw - 1) // cw) (map (_ \ "") ^((sm 1 + ch - 1) // ch)) g])))
 ; the thumbnail of the picture at q, or a string saying why none: from the cache when it
 ; is there, else decoded when cheap or when the frame has budget, else "..." and owed
 (mc-thumbat s q st cols rows gm)
  (: sz <st
     key (q + " " + show (st 1) + " " + show sz + " " + show cols + " " + show rows + " " + gm)
     hit (s 'cache key)
     (? (hit != ()) hit
        (s 'cap < sz) ("too big to show, " + show (sz // 1048576) + " MB")
        (sz < s 'cheap || 0 < s 'budget)
         (: _ (pin s 'budget (s 'budget - 1))
            r (uread q)
            im (two? r ? (cite 'kore 'pic-decode <>r) "cannot read")
            th (two? im ? (mc-thumb im cols rows gm (s 'cw) (s 'ch) (s 'deep)) im)
            ((64 < #(keys (s 'cache)) ? (pin s 'cache {}) 0),
             pin (s 'cache) key th,
             th))
        (pin s 'owe 1, "...")))
 ; a picture in the quick view: the thumbnail centred, its name and what it is under it
 (mc-pic s q nm st k b w n)
  (: d (cite 'kore 'pic-size b)
     tag (two? d ? (show (d 0) + "x" + show (d 1) + "  " + show k) (show k))
     th (mc-thumbat s q st (max 1 (w - 2)) (max 1 (n - 3)) (s 'gm))
     art (string? th ? [th] (th 1))
     lp (max 0 ((w - (string? th ? (edwide th) (th 0))) // 2))
     blk (map (r \ edfit "" lp " " + r) art + ["" (" " + nm) (" " + tag)])
     top (max 0 ((n - #blk) // 2))
     [(map (_ \ "") ^top + blk) (? (string? th) () (th 2 = "") () [lp top (th 2)])])
 ; the other pane in quick view -> [rows graphic], graphic () or [col row string] in it
 (mc-look s p w n)
  (: e (mc-at p)
     q (two? e ? (mc-join (p 'dir) <e) (p 'dir))
     st (stat q)
     (? !(two? st) [[(" " + (two? e ? <e "") + ": a link to nothing")] ()]
        (16384 = st 2 & 61440) [(mc-pad (mc-count q n)) ()]
        !(32768 = st 2 & 61440) [[" not a regular file"] ()]
        (: b (mc-peek q 4096) k (cite 'kore 'pic-kind b)
           (k != () ? (mc-pic s q <e st k b w n) [(mc-pad (mc-text b n (w - 1))) ()]))))
 ; the other pane in thumbnails: the active pane's pictures by name, tiles of block art
 ; with a name under each, the page the cursor's picture is on, its name reversed
 mc-tw 14
 mc-th 6
 (mc-grid s p w n)
  (: es (filter (e \ !(mc-dir? e) && elem (cite 'kore 'pic-type <e) '(png gif jpeg)) (p 'es))
     cur (mc-at p)
     nc (max 1 (w // mc-tw)) nr (max 1 (n // mc-th)) per (nc * nr)
     ci (: (go l i) (? (atom? l) 0 (<l = cur) i (go >l (i + 1))) (go es 0))
     pg (drop (per * (ci // per)) es)
     (tile e ln)
      (: q (mc-join (p 'dir) <e) st (stat q)
         (? (ln = mc-th - 1) (edfit (" " + <e) (mc-tw - 1) " " @ t (e = cur ? ("\e[7m" + t + "\e[0m ") (t + " ")))
            !(two? st) (edfit "" mc-tw " ")
            (: th (mc-thumbat s q st (mc-tw - 2) (mc-th - 1) "block")
               art (string? th ? [th] (th 1))
               top ((mc-th - 1 - #art) // 2)
               r (top <= ln < top + #art ? (art (ln - top)) "")
               (edfit (" " + r) mc-tw " "))))
     (band b) (take nc (drop (b * nc) pg) @ ts (map (ln \ catmap (e \ tile e ln) ts) ^mc-th))
     rows (catmap band ^(min nr ((#pg + nc - 1) // nc)))
     [(two? es ? rows [" no pictures here"]) ()])

 ; --- the frame ---------------------------------------------------------------------
 ; the two panes side by side with a rule between, a header each, the cursor's path
 ; underneath and the keys along the bottom. every row is cut to the screen and cleared
 ; to its end, so a narrow terminal loses the right pane's tail and nothing else.
 (mc-size e) (mc-dir? e ? "<dir>" (show (e 2)))
 ; sel: 0 none, 1 the active pane's cursor, 2 the other pane's -- the idle pane keeps
 ; a mark so tab comes back to where it left, without claiming the eye the active one has
 (mc-cell d e w sel)                           ; one listing row, fitted plain then dressed
  (: sz (mc-size e)
     k (w - #sz - 2)
     txt (" " + edfit <e (k < 1 ? 1 k) " " + " " + sz)
     row (edfit txt w " ")
     h (mc-hue d e)
     (? (sel = 1) ("\e[7m" + row + "\e[0m")
        (sel = 2) ("\e[4m" + row + "\e[0m")
        #h (h + row + "\e[0m")
        row))
 (mc-row p k w act?)
  (: es (p 'es) i (p 'top + k)
     (#es <= i ? (edfit "" w " ")
        (mc-cell (p 'dir) <(drop i es) w (? (i != p 'cur) 0 act? 1 2))))
 (mc-head d w) ("\e[7m" + edfit (" " + d) w " " + "\e[0m")
 mc-keys " tab pane  enter in  u up  / find  v view  t thumbs  r reread  q quit"
 ; a graphic goes out after the text, at its place, since text laid over it may wipe it:
 ; a sixel whole every frame; kitty's sent once as image 7 and then placed again by id,
 ; every picture let go when it changes
 (mc-gfx s x0 y0 g)
  (: e (string 27)
     at (two? g ? (e + "[" + show (y0 + g 1) + ";" + show (x0 + g 0) + "H") "")
     gs (two? g ? (at + g 2) "")
     un (cite 'kore 'pv-unkit)
     old (s 'shown)
     (pin s 'shown gs,
      (? (s 'gm != "kitty") gs
         (gs = old) (gs = "" ? "" (at + e + "_Ga=p,i=7,p=1,C=1,q=2" + e + "\\"))
         (un + gs))))
 (mc-frame s w h)
  (? !(nil? (s 'seek)) (seek-frame (s 'seek) w h)
  (: j (jug 0)
     rows (h < 6 ? 1 (h - 3))
     _ (pins s 'rows rows 'owe 0)
     lw ((w - 1) // 2)
     rw (w - 1 - lw)
     l (s 'l) r (s 'r) a (s 'act) qv (s 'qv)
     p (mc-act s) e (mc-at p)
     here (two? e ? (mc-join (p 'dir) <e) (p 'dir))
     vw (a = 0 ? rw lw)
     v (qv @ 1 (mc-look s p vw rows) 2 (mc-grid s p vw rows) [() ()])
     (vrow k) (: x <(drop k <v) (edfit (string? x ? x "") vw " "))
     vh (qv @ 1 ("view " + (two? e ? <e (p 'dir))) 2 ("thumbnails " + p 'dir) "")
     (lrow k) (qv && a = 1 ? (vrow k) (mc-row l k lw (0 = a)))
     (rrow k) (qv && a = 0 ? (vrow k) (mc-row r k rw (1 = a)))
     (say j "\e[H\e[0m",
      say j (mc-head (qv && a = 1 ? vh (l 'dir)) lw + "\e[0m|"
             + mc-head (qv && a = 0 ? vh (r 'dir)) rw + "\e[0m\e[K\r\n"),
      each ^rows (k \ say j $ lrow k + "\e[0m|" + rrow k + "\e[0m\e[K\r\n"),
      say j (edfit (" " + here) w " " + "\e[K\r\n"),
      say j ("\e[7m" + edfit mc-keys w " " + "\e[0m\e[K\e[?25l"),
      say j (mc-gfx s (a = 0 ? (lw + 2) 1) 2 (v 1)),
      slurp j)))

 ; --- the runner: the tool on a stage ------------------------------------------------
 ; 'gm the graphics (block sixel kitty) and 'cw 'ch a cell's pixels; 'cache the drawn
 ; thumbnails; a decode past 'cheap bytes spends 'budget, and a frame that could not
 ; afford one sets 'owe; past 'cap bytes a picture is only named
 (mc-new ld rd)
  (pins {} 'l (mc-pane ld) 'r (mc-pane rd) 'act 0 'rows 20 'over 0 'qv 0
        'gm "block" 'cw 8 'ch 16 'deep (cite 'kore 'pic-deep 0) 'cache {}
        'cheap 65536 'cap 33554432 'budget 1000 'owe 0 'shown "")
 ; a key within k ms: 1, else ()
 (mc-rest k) (? (k < 1) () (cue? 0) 1 (rest 10, mc-rest (k - 10)))
 ; cli's stage, but a thumbnail still owed waits for the keys to rest a beat and is then
 ; decoded, one a beat, so a cursor run over pictures never stalls on each
 (mc-loop s)
  (: ws (tty 1)
     h (two? ws && 7 < <ws ? <ws 24)
     w (two? ws && 19 < <>ws ? <>ws 80)
     (say out (mc-frame s w h),
      flush out,
      (s 'owe && !(mc-rest 150) ? (pin s 'budget 1, mc-loop s)
         (edkey in @ c (pin s 'budget 0,
                        (c @ -7 () (mc-key s c, s 'over ? () (mc-loop s))))))))
 (mc-run ld rd gm)
  (: s (mc-new ld rd)
     kp (cite 'kore)
     pr (gm @ "block" (kp 'pic-heard "") (kp 'pic-probe 0))
     (pins s 'gm (kp 'pic-pick gm pr) 'budget 0
             'cw (0 < pr 'cw ? (pr 'cw) 8) 'ch (0 < pr 'ch ? (pr 'ch) 16),
      raw 1, say out "\e[?1049h", mc-loop s,
      say out ((s 'gm @ "kitty" (kp 'pv-unkit) "") + "\e[0m\e[?25h\e[?1049l"), flush out, raw 0, 0))
 mc-usage "usage: love mc [-g block|sixel|kitty|auto] [DIR [DIR]]"
 (mc-main as)
  (: g? (two? as && <as = "-g")
     gm (g? ? (two? >as ? <>as "") "auto")
     ds (g? ? (drop 2 as) as)
     d1 (two? ds ? <ds ("" + cwd 0))
     d2 (two? ds && two? >ds ? <>ds d1)
     (? !(elem gm ["auto" "block" "sixel" "kitty"]) (puts ("mc: no mode " + gm + "; block sixel kitty or auto\n"), 2)
        !(mc-dirat? d1) (puts ("mc: " + d1 + ": not a directory\n"), 1)
        !(mc-dirat? d2) (puts ("mc: " + d2 + ": not a directory\n"), 1)
        (mc-run d1 d2 gm)))
 _ (pins (cite 'verbs 'tab) 'mc (udoor 'mc mc-main mc-usage 1 1)))
) ; module mc
