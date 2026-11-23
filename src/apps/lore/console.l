; console -- a debug console over a game: a pane beside its picture, panes slip's, where a line
; of love is typed and answered, the game's state and its own words in scope. a game's loop
; lays the panes (con-lay), hands its keys through (con-event a window's, con-term a
; terminal's), shows its picture in the scene's pane and con-box beside it, and evaluates by
; (con-task (_ \ con-eval words st line) stop?).
(module (console con-new con-up con-open con-keyed? con-lay con-key con-box con-cells con-shift con-task con-show con-eval con-event con-term con-events con-stop)
(borrow '(cli slip window))
(borrow '(rove horn text))
(:
 esc (string 27)
 ; what it takes by place in a window
 con-set1 {1 27 28 13 284 13 14 127 15 9 328 -8 336 -9 331 -1 333 -2 327 -5 335 -6 339 -4 329 -14 337 -15}
 ; a text's cells, each one character
 (con-cells s) (: (go i) (i < #s ? (: j (cite 'text 'cpnext s i) (snip s i j . go j)) ()) (go 0))
 ; --- the console: a pane beside the scene's, the two slip's, a line of love typed at cli's
 ;     line editor and its answer over it. con: 'on, 'ps the panes, 'cw ctrl-w waiting for its
 ;     key, 'ed the editor, 'log what was said, newest first, 'old the lines entered, newest
 ;     first, 'at which of them is up, -1 none, 'back how many rows up the log is shown; of a window, 'by the place that opened it, still
 ;     down, 'ctrl whether one is, and 'kept the events read while a line ran ---
 (con-new _) {'on 0 'by () 'ctrl 0 'kept ()  'ps (slip-new 'scene 'scene) 'cw 0 'split ['stack 60 'scene 'con] 'ed (ednew ()) 'log () 'old () 'at -1 'back 0}
 ; ..it up, with the keys, or away, its split kept for the next time
 (con-up con on) (: ps (con 'ps) _ (on ? (slip-plan ps (con 'split), pin ps 'focus 'con) (pin con 'split (ps 'plan), slip-plan ps 'scene)) (pins con 'on on 'cw 0))
 ; ..whether it is up and has the keys
 (con-keyed? con) (con 'on && con 'ps 'focus = 'con)
 ; ..the panes on a w by r cell screen: [scene con], each [x y w r], con () while it is away
 (con-lay con w r) (: ps (con 'ps) _ (slip-lay ps (8 * w) (16 * r)) [(slip-cells ps 'scene) (con 'on ? (slip-cells ps 'con) ())])
 ; ..a key's code k, or a text: ctrl-d puts it away, ctrl-c drops the line, enter answers (eval line), up
 ; and down the lines before, page up and down, or ctrl-b and ctrl-f, the log's pages, ctrl-w then a key slip's,
 ; ctrl-w twice and the rest the line editor's
 (con-key con eval k) (: ed (con 'ed) old (con 'old)
   (up i) (: j (max -1 (min (#old - 1) i)) _ (pin con 'at j) _ (pin con 'ed (ednew ())) (j < 0 ? con (type (chars (old j)))))
   (type cs) (: _ (each cs (edstep (con 'ed))) con)
   (say l) (pin con 'log (take 200 (foldl (\ a s (s . a)) (con 'log) l)))
   (enter t) (: _ (pins con 'ed (ednew ()) 'at -1 'back 0)
      (? (all (i \ t i = 32) ^#t) con
         (: _ (say [("> " + t)]) _ (pin con 'old (old @ (q . _) (q = t ? old (t . old)) [t])) _ (say (split "\n" (eval t))) con)))
   (? (con 'cw) (: _ (pin con 'cw 0) c (string? k && 0 < #k ? (k 0) k) (c = 23 ? (edstep ed 23, con) (slip-key (con 'ps) c, con)))
      (string? k) (type (chars k))
      (k @ 4 (con-up con 0) 3 (: _ (say [("> " + edtext ed + "^C")]) (pins con 'ed (ednew ()) 'at -1 'back 0)) 23 (pin con 'cw 1) -8 (up (con 'at + 1)) -9 (up (con 'at - 1))
           (2 || -14) (pin con 'back (con 'back + 8)) (6 || -15) (pin con 'back (max 0 (con 'back - 8)))
           (9 || 27) con
           _ (: _ (edstep ed k) (ed 'ev = 10 ? (enter (edtext ed)) con)))))
 ; ..its pane q drawn, rows of text at a cell: [x0 y0 rows]: what was said, wrapped, and the line, the
 ; cursor a block where it has the keys, and the bar between it and the scene
 (con-box con q) (: w (q 2) n (q 3) m (max 1 (w - 2)) row (s \ " " + pad s m " " + " ")
   (wrapped s) (: c (con-cells s) k (max 1 ((#c + m - 1) // m)) (map (i \ foldl (+) "" (map (j \ c (i * m + j)) ^(max 0 (min m (#c - i * m))))) ^k))
   ls (foldl (\ a s (#a < n - 1 + con 'back ? (wrapped s + a) a)) () (con 'log))
   bk (max 0 (min (con 'back) (#ls - (n - 1)))) _ (pin con 'back bk)
   ls (take (n - 1) (drop (max 0 (#ls - (n - 1) - bk)) ls))
   ed (con 'ed) l (con-cells ("> " + string (rev (ed 'l)))) r (con-cells (string (ed 'r))) o (max 0 (#l + 1 - m))
   c (take m (drop o (l + [(con-keyed? con ? "▏" " ")] + r)))
   rows (map row (ls + map (_ \ "") ^(max 0 (n - 1 - #ls)) + [(foldl (+) "" c)]))
   (slip-bars (con 'ps) @
     (['across y _ k] . _) (: b (foldl (+) "" (map (_ \ "─") ^k)) (y < q 1 ? [(q 0) (q 1 - 1) (b . rows)] [(q 0) (q 1) (rows + [b])]))
     (['down _ x _] . _) (x < q 0 ? [(q 0 - 1) (q 1) (map (s \ "│" + s) rows)] [(q 0) (q 1) (map (s \ s + "│") rows)])
     _ [(q 0) (q 1) rows]))
 ; ..a terminal's frame f, drawn from home, with its home at column x of row y
 (con-shift f x y) (? (x = 0 && y = 0) f
   (: home (esc + "[" + show (y + 1) + ";" + show (x + 1) + "H")
      (num s i) (: (go j n) (j < #s && 48 <= s j && s j <= 57 ? (go (j + 1) (10 * n + s j - 48)) [n j]) (go i 0))
      (moved s) (: a (num s 0) i (a 1) b (i < #s && s i = 59 ? (num s (i + 1)) [0 0])
                   (? (0 < #s && s 0 = 72) (show (y + 1) + ";" + show (x + 1) + s)
                      (0 < b 1 && b 1 < #s && s (b 1) = 72) (show (a 0 + y) + ";" + show (b 0 + x) + snip s (b 1) #s)
                      s))
      ps (split (esc + "[") f) g (foldl (\ o s (: _ (say o (esc + "[" + moved s)) o)) (: o (jug 0) _ (say o <ps) o) >ps)
      (home + join ("\r\n" + (0 < x ? (esc + "[" + show x + "C") "")) (split "\r\n" (slurp g)))))
 ; ..(f ()) on a task of its own, waited for, ctrl-c stopping it: (stop? ()) is asked after a
 ; moment and then every frame's while, 1 where it was typed
 (con-task f stop?) (: t (twirl f 0) t0 (clock 0)
   (go _) (? (landed? t) (catch t) (clock 0 - t0 < 100) (rest 1, go ()) (stop? ()) (freeze t, "^C") (rest 10, go ()))
   (go ()))
 ; ..a line evaluated: love, with st and the names ws gives values, [[name doc value] ..];
 ; help lists them. its answer as show has it, as far as con-max characters, then ..; a
 ; tablet's keys sorted
 con-max 4000
 (con-show x) (: j (jug 0) n {'n 0} (full _) (con-max < n 'n)
   (put s) (: t (#s > con-max ? (snip s 0 con-max) s) _ (pin n 'n (n 'n + #t)) (say j t))
   (each-of l f) (foldl (\ a y (? (full ()) a (: _ (a ? (put " ") 0) _ (f y) 1))) 0 l)
   (go x) (? (full ()) 0
             (tablet? x) (: _ (put "{") _ (each-of (sort (keys x)) (k \ (go k, put " ", go (x k)))) (put "}"))
             (two? x) (: _ (put "(") (tl l) (? (full ()) 0 (two? l) (: _ (put " ") _ (go <l) (tl >l)) (l = ()) 0 (: _ (put " . ") (go l))) _ (go <x) _ (tl >x) (put ")"))
             (string? x) (put (show (#x > con-max ? (snip x 0 con-max) x)))
             (atom? x && con-max < trap (_ \ #x) 0 (a \ b \ 0)) (: _ (put (show (peep x (iota (con-max // 8)) 0))) (pin n 'n (con-max + 1)))
             (put (show x)))
   _ (go x) s (slurp j) (full () ? (snip s 0 (min #s con-max) + " ..") s))
 (con-eval words st ln) (: ws ([["st" "the walk's state, a tablet" st]] + words st)
   (? (ln = "help") (join "\n" (map (w \ pad (w 0) 10 " " + w 1) ws))
      (sound ("(" + foldl (\ a w (a + w 0 + " \\ ")) "" ws + ln + "\n)") @
        (d . _) (trap (_ \ (: r (foldl (\ f w (f (w 2))) (ev d) ws) (string? r && #r <= con-max ? r (con-show r)))) () (a \ b \ ";; " + show a + " " + show b))
        _ ";; unfinished")))
 ; ..a window's record e, t what it typed and at (place -> code) what its key is, for the console,
 ; open? whether its key opens one: 1 where it was the console's, 0 to go on
 (con-event con eval e t at open?) (: c (e 1) on (con 'on) (code n) (charm? n ? n ()) pl (<e = 'down ? (at c) ())
   (say k) (: _ (con-key con eval k) 1)
   (? (elem <e ['down 'up] && elem c [29 285]) (pin con 'ctrl (<e = 'down ? 1 0), 1)
      (<e = 'up && c = con 'by) (pin con 'by (), 0)
      (<e = 'down && c = con 'by) 1
      (<e = 'down && on && !(elem c [42 54]) && (con-keyed? con || con 'cw || con 'ctrl && pl = 119))
        (? (con 'ctrl && charm? pl && 97 <= pl && pl <= 122) (say (pl & 31))
           (0 < #t && 32 <= t 0 && t 0 != 127 && !(con 'ctrl)) (say t)
           (charm? (con-set1 c)) (say (con-set1 c))
           (charm? pl && con 'cw) (say pl)
           1)
      (<e = 'down && open?) (pin con 'by c, con-open con, 1)
      ; a press on the scene is the scene's too, which has the keys then
      (<e = 'press && on) (slip-press (con 'ps) (e 2) (e 3) = 'scene ? 0 1)
      (<e = 'move) (slip-drag (con 'ps) c (e 2))
      (<e = 'release) (slip-drop (con 'ps))
      0))
 ; ..it up, or where it is up already given the keys
 (con-open con) (con 'on ? (pin (con 'ps) 'focus 'con) (con-up con 1))
 ; ..a terminal's key k: () where it was the console's, else k
 (con-term con eval k open?) (? (con-keyed? con) (: _ (k @ 0 () -7 (con-up con 0) (con-key con eval k)) ())
                                (con 'on && (con 'cw || k = 23)) (: _ (con-key con eval k) ())
                                open? (: _ (con-open con) ())
                                k)
 ; ..the records of win waiting, those kept first
 (con-events con win) (: k (con 'kept) _ (pin con 'kept ()) (k + window-events win))
 ; ..ctrl-c typed while a line runs: a window's records kept for after, a terminal's keys let go
 (con-stop con win at) (tablet? win ? (: es (window-events win) _ (pin con 'kept (con 'kept + es))
     (foldl (\ a e (e @ ['down c] (? (elem c [29 285]) (pin con 'ctrl 1, a) (at c = 99 && con 'ctrl) 1 a) ['up c] (? (elem c [29 285]) (pin con 'ctrl 0, a) a) ['close] 1 _ a)) 0 es))
   (: (go _) (cue? 0 ? (edkey in @ k (? (k = 3 || k = -7) 1 (k = 0) 0 (go ()))) 0) (go ())))))
