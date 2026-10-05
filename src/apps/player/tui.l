; src/apps/player/tui.l -- the player in cells (notes/plan/av.md, the player): winamp's main
; panel, a visualizer, the ten-band eq and the playlist editor, stacked, drawn from the core's
; messages and driving it with its commands. it watches a core in process today and over the
; socket later, the same messages either way. `(borrow 'ptui)`, then:
;
;   (ptui-new c)          -> a view of core c, watching it as a client of its own
;   (ptui-frame d w h)    -> the screen, w by h
;   (ptui-key d k)        a key (cli's edkey codes, -12 a tap), sent on as the core's command
;   (ptui-tap d [x y])    a tap on cell x, y of the last frame, 0-based
;   (ptui-run d)          full screen on cli's stage until q
;   (ptui-close d)        stops watching
;
; keys: space toggle, x play, c pause, v stop, z prev, b next (winamp's), left/right seek, + -
; volume, [ ] balance, m spectrum or scope, e eq on, r repeat, R random, o sort, tab between
; the playlist and the eq, q quit. in the playlist: up/down, enter plays, d drops, J/K move
; the item, a adds files under here. in the eq: left/right a band, up/down a dB, 0 that band
; flat, f all flat, p/P the presets. a tap on the seek bar seeks, on a row picks it, on a
; slider sets it, on the visualizer switches it.
(module (ptui ptui-new ptui-frame ptui-key ptui-tap ptui-run ptui-close ptui-presets)
(borrow 'pcore)
(borrow 'seek)
(:
   bands ["60" "170" "310" "600" "1k" "3k" "6k" "12k" "14k" "16k"]
   emax 12                               ; the sliders' reach, dB either way, as winamp's
   ; winamp's own presets, rounded to the dB
   ptui-presets [["flat" [0 0 0 0 0 0 0 0 0 0]] ["classical" [0 0 0 0 0 0 -7 -7 -7 -10]]
                 ["club" [0 0 8 6 6 6 3 0 0 0]] ["dance" [10 7 2 0 0 -6 -7 -7 0 0]]
                 ["bass" [-8 10 10 6 2 -4 -8 -10 -11 -11]] ["treble" [-10 -10 -10 -4 2 11 12 12 12 12]]
                 ["pop" [-2 5 7 8 6 0 -2 -2 -2 -2]] ["rock" [8 5 -6 -8 -3 4 9 11 11 11]]
                 ["reggae" [0 0 0 -6 0 6 6 0 0 0]] ["soft" [5 2 0 -2 0 4 8 10 11 12]]
                 ["techno" [8 6 0 -6 -5 0 8 10 10 9]]]
   sortk ['title 'artist 'album 'dur 'uri]
   helps [" space toggle  x play  c pause  v stop  z prev  b next  left/right seek 5 s"
          " + - volume  [ ] balance  m spectrum/scope  e eq on  r repeat  R random  o sort"
          " tab the playlist or the eq  ? these keys  q quit"
          " playlist: up/down  enter plays  d drops  J/K move it  a adds files under here"
          " eq: left/right a band  up/down a dB  0 that band flat  f all flat  p/P presets"
          " a tap: the seek bar seeks, a row picks (twice plays), a slider sets, the bars switch"]
   blocks [" " "▁" "▂" "▃" "▄" "▅" "▆" "▇" "█"]
   audio [".wav" ".flac" ".mp3" ".ogg" ".opus"]
   (al t) (foldl (\ a kv (pin a <kv (kv 1))) {} t)             ; an alist as a tablet
   (S d k) (peep (d 'st) k ())
   (num? x) (charm? x || gem? x)                               ; an int or a float

   (ptui-new c)
    (: d {'c c 'st {} 'q () 'spec () 'peak () 'scope () 'vis 'spec 'focus 'list 'sel 0 'top 0
          'band 0 'preset 0 'sort -1 'msg "" 'msgat 0 'posat (clock 0) 'tick 0 'over 0 'feed ()
          'pick () 'geo {} 'help 0}
       (pin d 'id (core-watch c (m \ hear d m))))
   (ptui-close d) (: _ (? (d 'feed) (core-tell (d 'c) (d 'id) ['feed (<(d 'feed)) 0 0]) 0) (core-unwatch (d 'c) (d 'id)))

   ; --- what the core says --------------------------------------------------------
   (hear d m)
    (<m @ 'snap (pins d 'st (al (m 1)) 'q (map al ((m 2) 1)) 'posat (clock 0))
          'set (: _ (each (m 1) (kv \ pin (d 'st) <kv (kv 1)))
                  (? (elem 'pos (map (kv \ <kv) (m 1))) (pin d 'posat (clock 0)) d))
          'queue (pin d 'q (map al (m 2)))
          'msg (pins d 'msg (m 1) 'msgat (clock 0))
          'spec (pin d 'spec (m 2))
          'scope (pin d 'scope (m 2))
          d)
   (send d msg) (core-send (d 'c) msg)
   ; where play is, between the core's word on it, which comes four times a second
   (pos d) (: p (S d 'pos) p0 (? (num? p) p 0.0) dur (S d 'dur)
              t (S d 'state = 'play ? (p0 + (clock 0 - d 'posat) / 1000.0) p0)
              (? (num? dur && 0 < dur && dur < t) dur t))
   (two n) (n < 10 ? ("0" + show n) (show n))
   (mmss s) (: t (int (? (num? s) s 0)) (show (t // 60) + ":" + two (t % 60)))
   (fit s n) (edfit s (max 0 n) " ")
   (label it) (: t (peep it 'title "") a (peep it 'artist "") u (peep it 'uri "")
                 (? (string? t && 0 < #t) (? (string? a && 0 < #a) (a + " - " + t) t)
                    (: k (fsub (rev-s u) "/" 0) (? (0 <= k) (snip u (#u - k) #u) u))))
   (rev-s s) (string (rev (chars s)))
   (sgr c s) ("\e[" + c + "m" + s + "\e[0m")
   (clamp lo hi x) (min hi (max lo x))
   ; utf-8 of a codepoint under 0x10000, for the braille cells
   (u8 cp) (string [(224 | (cp >> 12)) (128 | ((cp >> 6) & 63)) (128 | (cp & 63))])

   ; --- the panels, each a list of rows, every row w cells -----------------------------
   (bar d w name)                                               ; a panel's top edge
    (sgr (d 'focus = name ? "1;36" "2") (fit ("─ " + (string? name ? name (show name)) + " " + rule w) w))
   (rule n) (cats (map (_ \ "─") ^(max 0 n)))
   (main d w)
    (: st (S d 'state) it (? (0 <= S d 'song && S d 'song < #(d 'q)) ((d 'q) (S d 'song)))
       glyph (st @ 'play "▶" 'pause "‖" "■")
       p (pos d) dur (S d 'dur)
       tm (" " + glyph + " " + mmss p + " / " + mmss dur + "  ")
       name (? (tablet? it) (label it) "")
       room (max 1 (w - #tm - 1))
       ; the title scrolls when it is wider than its room
       name2 (? (#name <= room) name
                (: s (name + "  ***  ") k ((d 'tick) // 4 % #s) (snip (s + s) k (k + room))))
       info (? (num? (S d 'kbps) && 0 < S d 'kbps)
               (show (S d 'kbps) + " kbps  " + show ((S d 'rate) // 1000) + " kHz  " + (S d 'ch = 1 ? "mono" "stereo"))
               "")
       (lit k s) (? (S d k = 1) (sgr "1;33" s) (sgr "2" s))
       flags (lit 'eqon "eq" + " " + lit 'repeat "rpt" + " " + lit 'random "rnd" + " " + lit 'single "1" + " " + lit 'consume "con")
       sw (max 3 (w - 2))
       k (? (num? dur && 0 < dur) (clamp 0 (sw - 1) (int (p / dur * sw))) -1)
       seek (" " + (? (k < 0) (sgr "2" (rule sw))
                        ((sgr "36" (cats (map (_ \ "━") ^k)) + "●") + sgr "2" (rule (sw - k - 1)))))
       v (S d 'vol) b (S d 'bal) vv (? (num? v) v 0) bb (? (num? b) b 0)
       vol (" vol " + sgr "32" (cats (map (i \ (i * 10 < vv ? "▮" "▯")) ^10)) + " " + fit (show vv) 3
            + "  bal " + cats (map (i \ (i = clamp 0 8 (int ((bb + 100) * 8 / 200)) ? "●" "─")) ^9) + " " + show bb)
       keys "  z|◀ x▶ c‖ v■ b▶|"
       [((sgr "1" tm) + fit name2 room)
        ((fit (" " + info + "   ") (w - 22)) + flags)
        seek
        (vol + fit keys (w - 35 - #(show bb)))])
   ; the spectrum, bars of eighths with a falling cap; the scope, braille
   (vis d w vh)
    (? (d 'vis = 'scope) (scope d w vh)
       (: nb (max 1 ((w - 1) // 2)) sp (d 'spec) pk (d 'peak)
          bins (map (i \ (i < #sp ? (sp i) 0)) ^nb)
          caps (map (i \ max (bins i) ((i < #pk ? (pk i) 0) - 6)) ^nb)
          _ (pin d 'peak caps)
          (row r)
           (: lv ((vh - 1 - r) * 8)
              col (? (r * 3 < vh) "31" (r * 3 < 2 * vh) "33" "32")
              (cats (map (i \ (: h (bins i * vh * 8 // 255) f (clamp 0 8 (h - lv))
                                 cr (vh - 1 - (caps i * vh * 8 // 255) // 8)
                                 (" " + (? (0 < f) (sgr col (blocks f)) (cr = r && 0 < caps i) (sgr "37" "▔") " "))))
                        ^nb)))
          (map row ^vh)))
   (scope d w vh)
    (: cols (d 'scope) n (2 * max 1 (w - 2)) dots (4 * vh)
       ; a column's [lo hi] as the dot rows it covers, 0 the top
       (span j) (: c (? (j < #cols) (cols j) [0 0]) lo (c 0) hi (c 1)
                   [(clamp 0 (dots - 1) ((127 - hi) * dots // 256)) (clamp 0 (dots - 1) ((127 - lo) * dots // 256))])
       sps (map span ^n)
       lb [1 2 4 64] rb [8 16 32 128]
       (cell r x) (: a (sps (2 * x)) b (sps (2 * x + 1))
                     bits (foldl (\ m k (: y (4 * r + k)
                                          (m | (<a <= y && y <= a 1 ? lb k 0) | (<b <= y && y <= b 1 ? rb k 0))))
                                 0 ^4)
                     (bits = 0 ? " " (u8 (10240 + bits))))
       (map (r \ " " + sgr "32" (cats (map (x \ cell r x) ^(n // 2)))) ^vh))
   ; the eq: preamp and the ten bands as sliders, the chosen one lit while the eq has focus
   (eq d w eh)
    (: rows (max 1 (eh - 1)) cw (max 3 ((w - 1) // 11))
       vals ([(S d 'pre)] + eqv d)
       names (["pre"] + bands)
       (rowof v) (clamp 0 (rows - 1) (int ((emax - clamp (0 - emax) emax v) * (rows - 1) / (2 * emax) + 0.5)))
       zr (rowof 0)
       on (d 'focus = 'eq)
       (cell r i) (: v (? (num? (vals i)) (vals i) 0) k (rowof v)
                     g (? (r = k) "█" ((zr <= r && r < k) || (k < r && r <= zr)) "┃" (r = zr) "┼" "│")
                     s (fit (" " + g) cw)
                     (? (on && i = d 'band) (sgr "7" s) (r = k ? (sgr "36" s) (sgr "2" s))))
       labels (cats (map (i \ fit (" " + names i) cw) ^11))
       ((map (r \ " " + cats (map (i \ cell r i) ^11)) ^rows) + [(" " + labels)]))
   (playlist d w ph)
    (: q (d 'q) n #q sel (clamp 0 (max 0 (n - 1)) (d 'sel)) _ (pin d 'sel sel)
       top (d 'top @ t (? (sel < t) sel (t + ph <= sel) (sel - ph + 1) t)) _ (pin d 'top top)
       cur (S d 'song)
       (line i) (: it (q i) tm (mmss (peep it 'dur 0)) mk (i = cur ? "▶" " ")
                   nn (show (i + 1)) s (fit (mk + fit "" (3 - #nn) + nn + ". " + label it) (w - #tm - 1) + " " + tm)
                   (? (i = sel && d 'focus = 'list) (sgr "7" s) (i = cur) (sgr "1;33" s) s))
       vis (take ph (drop top ^n))
       ((map line vis) + map (_ \ "") ^(ph - #vis)))
   (footer d w)
    (: q (d 'q) tot (foldl (\ a it (a + (peep it 'dur 0 @ x (num? x ? x 0)))) 0 q)
       sk (d 'sort @ k (k < 0 ? "" ("  sort " + show (sortk k))))
       note (? (clock 0 - d 'msgat < 5000 && 0 < #(d 'msg)) ("  " + d 'msg) "")
       (sgr "2" (fit (" " + show #q + " items, " + mmss tot + sk + note + "   tab eq/list  a add  ? keys  q quit") w)))

   ; --- the screen ------------------------------------------------------------------
   (ptui-frame d w h)
    (? (d 'pick) (seek-frame (d 'pick) w h)
       (: _ (pin d 'tick (d 'tick + 1))
          ; what fits: the main panel always, then the eq, the visualizer and the playlist
          room (h - 1 - 4 - 1)                                     ; title, main, footer
          eh (? (14 <= room) 6 0)
          left (room - (eh ? (eh + 1) 0))
          vh (clamp 0 8 (? (6 <= left) ((left - 2) // 2) (left - 3)))
          ph (max 0 (left - (vh ? (vh + 1) 0) - 1))
          _ (feed d (? (0 < vh) (d 'vis) ()) (? (d 'vis = 'scope) (2 * max 1 (w - 2)) (max 1 ((w - 1) // 2))))
          title (sgr "7" (fit (" love player  " + (S d 'sink @ s (string? s ? s "")) + "   " + show (S d 'clients @ c (num? c ? c 1)) + " attached") w))
          r0 5
          g {'seek 3 'vis (? vh [(r0 + 1) vh] ()) 'list (? ph [(r0 + (vh ? (vh + 1) 0) + 1) ph] ())
             'eq (? eh [(r0 + (vh ? (vh + 1) 0) + (ph ? (ph + 1) 0) + 1) eh] ()) 'w w}
          _ (pin d 'geo g)
          rows ([title] + main d w
                + (? vh ([(bar d w (d 'vis = 'scope ? "scope" "spectrum"))] + vis d w vh) ())
                + (? ph ([(bar d w (d 'help ? "keys" 'list))] + (d 'help ? (take ph (map (l \ fit l w) helps + map (_ \ "") ^ph)) (playlist d w ph))) ())
                + (? eh ([(bar d w 'eq)] + eq d w eh) ())
                + [(footer d w)])
          ("\e[H" + cats (map (r \ r + "\e[K\r\n") (take (h - 1) rows)) + (take 1 (drop (h - 1) rows) @ l (two? l ? (<l + "\e[K") "")) + "\e[J")))
   ; the feed this view wants, asked for once: (kind n), () for none
   (feed d kind n)
    (: want (? kind [kind n] ())
       (? (show want = show (d 'feed)) 0
          (: _ (? (d 'feed) (core-tell (d 'c) (d 'id) ['feed (<(d 'feed)) 0 0]) 0)
             _ (? kind (core-tell (d 'c) (d 'id) ['feed kind 30 n]) 0)
             (pin d 'feed want))))

   ; --- keys ------------------------------------------------------------------------
   (eqv d) (: e (S d 'eq) (map (i \ (? (two? e && i < #e && num? (e i)) (e i) 0)) ^10))
   (band d delta)
    (: b (d 'band)
       (? (b = 0) (send d ['pre (clamp (0 - emax) emax ((S d 'pre @ p (num? p ? p 0)) + delta))])
          (send d ['band (b - 1) (clamp (0 - emax) emax ((eqv d) (b - 1) + delta))])))
   (preset d k) (: n #ptui-presets i ((k + n) % n) p (ptui-presets i)
                   _ (pin d 'preset i) _ (send d ['eq (p 1)]) _ (send d ['pre 0])
                   (pins d 'msg ("preset " + <p) 'msgat (clock 0)))
   (toggle d k) (send d [k (S d k = 1 ? 0 1)])
   (selid d) (: q (d 'q) s (d 'sel) (? (s < #q) (peep (q s) 'id ())))
   (ptui-key d k)
    (? (d 'pick) (pickkey d k)
       (k @ 113 (pin d 'over 1)
            9 (pin d 'focus (d 'focus = 'list ? 'eq 'list))
            32 (send d ['toggle])  120 (send d ['play])  99 (send d ['pause])
            118 (send d ['stop])  122 (send d ['prev])  98 (send d ['next])
            (43 || 61) (send d ['vol (clamp 0 100 ((S d 'vol @ v (num? v ? v 0)) + 5))])
            45 (send d ['vol (clamp 0 100 ((S d 'vol @ v (num? v ? v 0)) - 5))])
            91 (send d ['bal (clamp -100 100 ((S d 'bal @ v (num? v ? v 0)) - 10))])
            93 (send d ['bal (clamp -100 100 ((S d 'bal @ v (num? v ? v 0)) + 10))])
            109 (pin d 'vis (d 'vis = 'spec ? 'scope 'spec))
            63 (pin d 'help (d 'help ? 0 1))
            101 (toggle d 'eqon)  114 (toggle d 'repeat)  82 (toggle d 'random)
            111 (: s ((d 'sort + 1) % #sortk) _ (pin d 'sort s) (send d ['sort (sortk s)]))
            -12 (ptui-tap d (edtap ()))
            (d 'focus = 'eq ? (eqkey d k) (listkey d k))))
   (eqkey d k)
    (k @ -1 (pin d 'band (max 0 (d 'band - 1)))  -2 (pin d 'band (min 10 (d 'band + 1)))
         -8 (band d 1)  -9 (band d -1)
         48 (? (d 'band = 0) (send d ['pre 0]) (send d ['band (d 'band - 1) 0]))
         102 (: _ (send d ['eq (map (_ \ 0) ^10)]) (send d ['pre 0]))
         112 (preset d (d 'preset + 1))  80 (preset d (d 'preset - 1))
         d)
   (listkey d k)
    (: n #(d 'q)
       (k @ -1 (send d ['seekby -5])  -2 (send d ['seekby 5])
            -8 (pin d 'sel (max 0 (d 'sel - 1)))  -9 (pin d 'sel (min (max 0 (n - 1)) (d 'sel + 1)))
            -5 (pin d 'sel 0)  -6 (pin d 'sel (max 0 (n - 1)))
            (10 || 13) (send d ['play (d 'sel)])
            (100 || 127) (selid d @ id (? id (send d ['del id]) d))
            74 (selid d @ id (? (id && d 'sel + 1 < n) (: _ (send d ['move id (d 'sel + 1)]) (pin d 'sel (d 'sel + 1))) d))
            75 (selid d @ id (? (id && 0 < d 'sel) (: _ (send d ['move id (d 'sel - 1)]) (pin d 'sel (d 'sel - 1))) d))
            97 (pin d 'pick (seek-new (filter (f \ any (x \ ends? (lower f) x) audio) (seek-files ".")) (it \ it) (it \ it) "add to the playlist"))
            d))
   (pickkey d k)
    (: s (d 'pick) _ (seek-key s k)
       (? (s 'over) (: _ (pin d 'pick ()) (s 'pick @ p (? (string? p) (send d ['add p]) d))) d))
   ; a tap: the seek bar seeks, a playlist row is chosen and played when tapped twice, a slider
   ; takes the dB of the row, the visualizer switches
   (ptui-tap d xy)
    (: x <xy y (xy 1) g (d 'geo) w (peep g 'w 80)
       (in a) (? (two? a) (<a <= y && y < <a + a 1))
       (? (y = g 'seek) (? (num? (S d 'dur) && 0 < S d 'dur) (send d ['seek (S d 'dur * clamp 0 1 ((x - 1) / max 1 (w - 2)))]) d)
          (in (g 'vis)) (pin d 'vis (d 'vis = 'spec ? 'scope 'spec))
          (in (g 'list)) (: i (d 'top + y - <(g 'list)) (? (i < #(d 'q)) (? (i = d 'sel && d 'focus = 'list) (send d ['play i]) (pins d 'sel i 'focus 'list)) d))
          (in (g 'eq)) (: e (g 'eq) rows (max 1 (e 1 - 1)) r (y - <e) cw (max 3 ((w - 1) // 11)) i (clamp 0 10 ((x - 1) // cw))
                          db (int (emax - r * 2 * emax / max 1 (rows - 1)))
                          (? (r < rows) (: _ (pins d 'band i 'focus 'eq) (band d (db - (? (i = 0) (S d 'pre @ p (num? p ? p 0)) ((eqv d) (i - 1)))))) d))
          d))

   (ptui-run d)
    (stage-run {'show (w \ h \ ptui-frame d w h) 'step (k \ ptui-key d k) 'over? (_ \ d 'over)
                'tick (_ \ 1) 'modes ['mouse 'hide] 'shut (_ \ ptui-close d)}))
) ; module ptui
