; wad -- a doom map walked, read from its wad by the unofficial doom specs and drawn by facets
; (src/love/raster.c) with no bsp renderer: each subsector a floor and a ceiling fan, cut from
; the box of the map by the nodes' partition lines and its own segs; each side its upper,
; middle and lower quads; each thing a sprite turned to the eye. a sector is a batch, so what
; moves is laid again alone; its light is the vertex colour, and fog toward black the distance.
;
; run: love lore wad FILE [MAP] [--kitty|--cells|--window] [--scale 1|2|4|8]
;      view's walking keys; q or esc leaves
(module (wad wad-main wad-read wad-map wad-scene wad-new wad-pens wad-frame wad-step wad-free? wad-size wad-sector wad-usage)
(borrow 'posix)
(borrow 'bytes)                         ; rdle
(borrow 'view)
(borrow 'mesh)
(borrow 'walk)
(borrow 'vec)                           ; sq
(:
 fps 35
 eye-h 41 body-r 16 step-h 24 body-h 56
 walk-v 280.0 turn-v 2.4 tilt-v 1.2
 fov (pi / 2.0)
 ; --- the wad: its lumps, the last of a name winning; a map's ten by order after its marker ---
 (s16 b o) (rdle b o 2 @ v (v < 32768 ? v (v - 65536)))
 (nm b o) (: t (snip b o (o + 8)) (go k) (k < #t && t k != 0 ? (go (k + 1)) k) (snip t 0 (go 0)))
 (wad-read p) (: r (uread p) s (two? r ? (r 1) "")
   (? (#s < 12 || !(elem (snip s 0 4) ["IWAD" "PWAD"])) ()
      (: n (rdle s 4 4) o (rdle s 8 4)
         ls (map (i \ (: q (o + 16 * i) [(nm s (q + 8)) (rdle s q 4) (rdle s (q + 4) 4)])) ^n)
         {'s s 'ls ls 'ix (foldl (\ t i (pin t (ls i 0) i)) {} ^n)})))
 (body w l) (snip (w 's) (l 1) (l 1 + l 2))
 (lump w k) (peep (w 'ix) k -1 @ -1 () i (body w (w 'ls i)))
 ; ..the lumps between two markers, by name
 (span w a b) (: ls (w 'ls) i (peep (w 'ix) a -1) j (peep (w 'ix) b -1)
   (i < 0 || j < i ? {} (foldl (\ t k (pin t (ls k 0) (ls k))) {} (map (+ (i + 1)) ^(j - i - 1)))))
 (recs b k f) (map (i \ f b (k * i)) ^(#b // k))
 (u16 b o) (rdle b o 2)
 ; --- the map: vertexes, lines, sides, sectors, segs, subsectors, nodes and things, each a list ---
 (wad-map w m) (: i (peep (w 'ix) m -1) n #(w 'ls)
   L (foldl (\ t k (i + k < n ? (pin t (w 'ls (i + k) 0) (body w (w 'ls (i + k)))) t)) {} (map (+ 1) ^10))
   (? (i < 0 || !(string? (L "SECTORS"))) ()
      {'name m
       'vs (recs (L "VERTEXES") 4 (\ b o [(1.0 * s16 b o) (1.0 * s16 b (o + 2))]))
       'lines (recs (L "LINEDEFS") 14 (\ b o (map (k \ u16 b (o + 2 * k)) ^7)))
       'sides (recs (L "SIDEDEFS") 30 (\ b o [(s16 b o) (s16 b (o + 2)) (nm b (o + 4)) (nm b (o + 12)) (nm b (o + 20)) (u16 b (o + 28))]))
       'secs (recs (L "SECTORS") 26 (\ b o [(s16 b o) (s16 b (o + 2)) (nm b (o + 4)) (nm b (o + 12)) (s16 b (o + 20)) (u16 b (o + 22)) (u16 b (o + 24))]))
       'segs (recs (L "SEGS") 12 (\ b o (map (k \ u16 b (o + 2 * k)) ^6)))
       'ssecs (recs (L "SSECTORS") 4 (\ b o [(u16 b o) (u16 b (o + 2))]))
       'nodes (recs (L "NODES") 28 (\ b o [(1.0 * s16 b o) (1.0 * s16 b (o + 2)) (1.0 * s16 b (o + 4)) (1.0 * s16 b (o + 6)) (u16 b (o + 24)) (u16 b (o + 26))]))
       'things (recs (L "THINGS") 10 (\ b o [(s16 b o) (s16 b (o + 2)) (s16 b (o + 4)) (u16 b (o + 6)) (u16 b (o + 8))]))}))
 ; --- the pictures: the palette; a patch's posts laid into a texture; flats; the textures
 ;     TEXTURE1 and 2 compose from PNAMES' patches ---
 (palette w) (: b (lump w "PLAYPAL") (star-tray [256] (map (i \ (b (3 * i) << 16) | (b (3 * i + 1) << 8) | b (3 * i + 2)) ^256)))
 ; ..a patch's texels as [index byte] at ox oy on a w by h texture
 ; ..a damaged one stops at the lump's end
 (posts b c) (: (go o) (o + 3 > #b ? () (b o @ 255 () td (: n (b (o + 1)) ([td (snip b (o + 3) (o + 3 + n))] . go (o + n + 4)))))
   (go (rdle b (8 + 4 * c) 4)))
 (texels b ox oy w h) (: pw (u16 b 0)
   (cats (map (c \ (: x (ox + c)
                    (0 <= x && x < w
                     ? (cats (map (q \ filter (e \ e 0 >= 0) (map (k \ (: y (oy + q 0 + k) (0 <= y && y < h ? [(y * w + x) (q 1 k)] [-1 0]))) ^#(q 1))) (posts b c)))
                       ())))
              ^pw)))
 (compose pal w h ps) (: es (cats (map (p \ texels (p 2) (p 0) (p 1) w h) ps)) n #es
   T (star-tray [h w] (map (_ \ -1) ^(w * h)))
   (n = 0 ? T (pin T (star-tray [n] (map (e \ e 0) es)) (peep pal (star-tray [n] (map (e \ e 1) es)) 0))))
 ; ..the texture table: name -> [w h patches], each patch [ox oy name]
 (texdefs w) (: pn (lump w "PNAMES") pns (string? pn ? (map (k \ nm pn (4 + 8 * k)) ^(rdle pn 0 4)) ())
   (one b) (string? b ? (map (k \ (: o (rdle b (4 + 4 * k) 4) np (u16 b (o + 20))
                                 [(nm b o) (u16 b (o + 12)) (u16 b (o + 14))
                                  (map (j \ (: q (o + 22 + 10 * j) [(s16 b q) (s16 b (q + 2)) (pns (u16 b (q + 4)))])) ^np)]))
                         ^(rdle b 0 4))
                ())
   (foldl (\ t d (pin t (d 0) d)) {} (one (lump w "TEXTURE1") + one (lump w "TEXTURE2"))))
 (texture w pal d) (compose pal (d 1) (d 2) (filter (p \ string? (p 2)) (map (p \ [(p 0) (p 1) (lump w (p 2))]) (d 3))))
 (flat pal b) (peep pal (star-tray [64 64] (map (i \ b i) ^4096)) 0)
 ; ..a sprite: its picture, and its offsets [w h left top]
 (sprite pal b) [(compose pal (u16 b 0) (u16 b 2) [[0 0 b]]) [(u16 b 0) (u16 b 2) (s16 b 4) (s16 b 6)]]
 ; --- things: a type's sprite and frame (the doom wiki's thing table); hung from the ceiling ---
 thing-sprites [3004 "POSSA" 9 "SPOSA" 3001 "TROOA" 3002 "SARGA" 58 "SARGA" 3006 "SKULA" 3005 "HEADA"
   3003 "BOSSA" 16 "CYBRA" 7 "SPIDA" 65 "CPOSA" 69 "BOS2A" 68 "BSPIA" 71 "PAINA" 66 "SKELA" 67 "FATTA" 64 "VILEA" 84 "SSWVA"
   2001 "SHOTA" 82 "SGN2A" 2002 "MGUNA" 2003 "LAUNA" 2004 "PLASA" 2005 "CSAWA" 2006 "BFUGA"
   2007 "CLIPA" 2048 "AMMOA" 2008 "SHELA" 2049 "SBOXA" 2010 "ROCKA" 2046 "BROKA" 2047 "CELLA" 17 "CELPA" 8 "BPAKA"
   2011 "STIMA" 2012 "MEDIA" 2014 "BON1A" 2015 "BON2A" 2018 "ARM1A" 2019 "ARM2A" 83 "MEGAA" 2013 "SOULA"
   2022 "PINVA" 2023 "PSTRA" 2024 "PINSA" 2025 "SUITA" 2026 "PMAPA" 2045 "PVISA"
   5 "BKEYA" 6 "YKEYA" 13 "RKEYA" 40 "BSKUA" 39 "YSKUA" 38 "RSKUA"
   2035 "BAR1A" 72 "KEENA" 48 "ELECA" 30 "COL1A" 31 "COL2A" 32 "COL3A" 33 "COL4A" 36 "COL5A" 37 "COL6A"
   47 "SMITA" 43 "TRE1A" 54 "TRE2A" 2028 "COLUA" 85 "TLMPA" 86 "TLP2A" 34 "CANDA" 35 "CBRAA"
   44 "TBLUA" 45 "TGRNA" 46 "TREDA" 55 "SMBTA" 56 "SMGTA" 57 "SMRTA" 70 "FCANA" 41 "CEYEA" 42 "FSKUA"
   10 "PLAYW" 12 "PLAYW" 15 "PLAYN" 18 "POSSL" 19 "SPOSL" 20 "TROOM" 21 "SARGN" 22 "HEADL" 23 "SKULK"
   24 "POL5A" 25 "POL1A" 26 "POL6A" 27 "POL4A" 28 "POL2A" 29 "POL3A"
   49 "GOR1A" 50 "GOR2A" 51 "GOR3A" 52 "GOR4A" 53 "GOR5A" 59 "GOR2A" 60 "GOR4A" 61 "GOR3A" 62 "GOR5A" 63 "GOR1A"
   73 "HDB1A" 74 "HDB2A" 75 "HDB3A" 76 "HDB4A" 77 "HDB5A" 78 "HDB6A" 79 "POB1A" 80 "POB2A" 81 "BRS1A"]
 thing-of (foldl (\ t k (pin t (thing-sprites (2 * k)) (thing-sprites (2 * k + 1)))) {} ^(#thing-sprites // 2))
 hung [49 50 51 52 53 59 60 61 62 63]
 ; ..a frame's lump: its front view, else any first rotation
 (frame-lump ss f) (: a (peep ss (f + "0") ()) b (peep ss (f + "1") ()) ks (filter (k \ snip k 0 6 = f + "1") (keys ss))
   (two? a ? a (two? b ? b (two? ks ? (ss <ks) ()))))
 ; --- the shapes: the map's box cut by each node's line to its subsectors, each by its segs ---
 (side-of a b) (: x (a 0) y (a 1) dx (b 0 - x) dy (b 1 - y) (p \ (p 0 - x) * dy - (p 1 - y) * dx))
 (lerp a b t) [(a 0 + t * (b 0 - a 0)) (a 1 + t * (b 1 - a 1))]
 (clip P f) (: n #P
   (cats (map (i \ (: a (P i) b (P ((i + 1) % n)) fa (f a) fb (f b)
                     x ((fa < 0) = (fb < 0) ? () [(lerp a b (fa / (fa - fb)))])
                     (fa < 0 ? x (a . x))))
              ^n)))
 (polys M) (: vs (M 'vs) ns (M 'nodes) segs (M 'segs)
   xs (map (v \ v 0) vs) ys (map (v \ v 1) vs)
   x0 (foldl min2 <xs xs - 64.0) x1 (foldl max2 <xs xs + 64.0) y0 (foldl min2 <ys ys - 64.0) y1 (foldl max2 <ys ys + 64.0)
   (leaf i P) (: s (M 'ssecs i)
     (foldl (\ Q k (: g (segs (s 1 + k)) (clip Q (side-of (vs (g 0)) (vs (g 1)))))) P ^(s 0)))
   ; ..a node's children below it, as every builder lays them, so a damaged tree cannot cycle
   (go c P up) (? (c >= 32768) (c - 32768 < #(M 'ssecs) ? [[(c - 32768) (leaf (c - 32768) P)]] ())
                  (c >= up) ()
                  (: n (ns c) f (side-of [(n 0) (n 1)] [(n 0 + n 2) (n 1 + n 3)])
                     (go (n 4) (clip P f) c + go (n 5) (clip P (p \ 0.0 - f p)) c)))
   (go (#ns = 0 ? 32768 (#ns - 1)) [[x0 y0] [x0 y1] [x1 y1] [x1 y0]] #ns))
 (sector-of-ss M i) (: g (M 'segs (M 'ssecs i 1)) l (M 'lines (g 3)) (M 'sides (l (g 4 = 0 ? 5 6)) 5))
 ; ..the subsector, and so the sector, a point stands in
 (wad-sector M x y) (: ns (M 'nodes)
   (go c up) (? (c >= 32768) (sector-of-ss M (c - 32768))
                (c >= up) 0
                (: n (ns c) (go ((x - n 0) * n 3 - (y - n 1) * n 2 >= 0.0 ? (n 4) (n 5)) c)))
   (go (#ns = 0 ? 32768 (#ns - 1)) #ns))
 ; --- the scene: per sector a batch, its floor and ceiling and the sides facing into it ---
 sky-flat "F_SKY1"
 ; ..a sky ceiling hides what is past it: drawn white so bright it is a pure colour the palette
 ;   lacks, through any fog, then the sky in its place
 (sky-mark pal) <(filter (m \ !(aany (pal = m))) [65535 65280 16776960 16711935 255 16711680] @ () [65535] l l)
 (sky-lit m) [(m >> 16 > 0 ? 1000.0 0.0) ((m >> 8) & 255 > 0 ? 1000.0 0.0) (m & 255 > 0 ? 1000.0 0.0)]
 (lit L) (: k (max2 0.0 (min2 1.0 (L / 255.0))) [k k k])
 (vert p y u v c) [(p 0) (1.0 * y) (p 1) (1.0 * u) (1.0 * v) (c 0) (c 1) (c 2)]
 (fan P y t c ceil) (: n #P
   [(map (p \ vert p y (p 0) (0.0 - p 1) c) P)
    (map (i \ ceil ? [0 (i + 1) (i + 2) t] [0 (i + 2) (i + 1) t]) ^(n - 2))])
 ; ..a wall from a to b, seen from its front, ylo to yhi, its texels from u0 along and v0 down
 (quad a b ylo yhi u0 v0 t c) (: l (sqrt (sq (b 0 - a 0) + sq (b 1 - a 1))) dv (yhi - ylo)
   [[(vert a yhi u0 v0 c) (vert b yhi (u0 + l) v0 c) (vert b ylo (u0 + l) (v0 + dv) c) (vert a ylo u0 (v0 + dv) c)]
    [[0 2 1 t] [0 3 2 t]]])
 (join ms) (: (go ms o) (atom? ms ? () (: m <ms (map (q \ [(q 0 + o) (q 1 + o) (q 2 + o) (q 3)]) (m 1) . go >ms (o + #(m 0)))))
   [(cats (map (m \ m 0) ms)) (cats (go ms 0))])
 (pack m) [(gem-tray [(8 * #(m 0))] (cats (m 0))) (star-tray [(4 * #(m 1))] (cats (m 1)))]
 ; ..the sides of line l facing into sector s: [a b sd other] each
 (faces M s) (cats (map (l \ (: a (M 'vs (l 0)) b (M 'vs (l 1)) r (l 5) f (l 6) sd (M 'sides)
                               two (f != 65535)
                               ((r != 65535 && sd r 5 = s ? [[a b (sd r) (two ? (M 'secs (sd f 5)) ()) l]] ())
                                + (two && sd f 5 = s ? [[b a (sd f) (M 'secs (sd r 5)) l]] ()))))
                        (M 'lines)))
 (walls M s ti th) (: F (M 'secs s) fh (F 0) ch (F 1)
   (one w) (: a (w 0) b (w 1) sd (w 2) B (w 3) l (w 4) fl (l 2) xo (sd 0) yo (sd 1)
     L (F 4 + (a 0 = b 0 ? 16 (a 1 = b 1 ? -16 0))) c (lit L)
     (tex k) (sd k = "-" ? -1 (peep ti (sd k) -1)) (hgt k) (peep th (sd k) 128)
     (? (atom? B) [(quad a b fh ch xo (yo + (fl & 16 ? (hgt 4 - (ch - fh)) 0)) (tex 4) c)]
        (: bf (B 0) bc (B 1) both-sky (F 3 = sky-flat && B 3 = sky-flat)
           up (bc < ch && !both-sky ? [(quad a b bc ch xo (yo + (fl & 8 ? 0 (hgt 2 - (ch - bc)))) (tex 2) c)] ())
           lo (bf > fh ? [(quad a b fh bf xo (yo + (fl & 16 ? (ch - bf) 0)) (tex 3) c)] ())
           top (min2 ch bc) bot (max2 fh bf) mh (hgt 4)
           mid (sd 4 = "-" ? () (: y1 (fl & 16 ? (min2 top (bot + mh)) top) y0 (max2 bot (y1 - mh))
                                 (y0 < y1 ? [(quad a b y0 y1 xo yo (tex 4) c)] ())))
           (up + lo + mid))))
   (cats (map one (faces M s))))
 (sector-mesh M ps s ti ski skc) (: F (M 'secs s) c (lit (F 4)) fp (filter (p \ p 0 = s && #(p 1) >= 3) ps)
   (cats (map (p \ [(fan (p 1) (F 0) (peep ti ("F:" + F 2) -1) c 0)
                    (F 3 = sky-flat ? (fan (p 1) (F 1) ski skc 1) (fan (p 1) (F 1) (peep ti ("F:" + F 3) -1) c 1))])
              fp)))
 ; ..the textures a map names, laid and indexed: walls by name, flats as "F:" name
 (wad-scene w M) (: pal (palette w) defs (texdefs w) fs (span w "F_START" "F_END" @ t (#(keys t) > 0 ? t (span w "FF_START" "FF_END")))
   ss (span w "S_START" "S_END" @ t (#(keys t) > 0 ? t (span w "SS_START" "SS_END")))
   wn (filter (k \ k != "-" && two? (defs k)) (uniq (cats (map (sd \ [(sd 2) (sd 3) (sd 4)]) (M 'sides)))))
   fn (filter (k \ k != sky-flat && two? (fs k)) (uniq (cats (map (S \ [(S 2) (S 3)]) (M 'secs)))))
   sp (filter (t \ string? (thing-of (t 3)) && (t 4 & 16) = 0 && (t 4 & 4) != 0) (M 'things))
   sn (uniq (map (t \ thing-of (t 3)) sp))
   sl (map (f \ frame-lump ss f) sn) sk (filter (i \ two? (sl i)) ^#sn)
   texs (map (k \ texture w pal (defs k)) wn + map (k \ flat pal (body w (fs k))) fn
         + map (i \ sprite pal (body w (sl i)) 0) sk)
   spr (map (i \ sprite pal (body w (sl i)) 1) sk)
   ti (foldl (\ t i (pin t (wn i) i)) {} ^#wn)
   ti2 (foldl (\ t i (pin t ("F:" + fn i) (#wn + i))) ti ^#fn)
   si (foldl (\ t j (pin t (sn (sk j)) j)) {} ^#sk)
   th (foldl (\ t k (pin t k (defs k 2))) {} wn)
   ps (map (q \ [(sector-of-ss M (q 0)) (q 1)]) (polys M))
   ski #texs mark (sky-mark pal)
   secs (map (s \ pack (join (sector-mesh M ps s ti2 ski (sky-lit mark) + walls M s ti2 th))) ^#(M 'secs))
   ; ..each thing [x y floor top k tex size]
   o (#wn + #fn)
   things (filter two? (map (t \ (: j (peep si (thing-of (t 3)) -1) x (1.0 * t 0) y (1.0 * t 1) S (M 'secs (wad-sector M x y))
                                   (j < 0 ? () [x y (elem (t 3) hung ? (1.0 * S 1) (1.0 * (S 0 + spr j 3))) (lit (S 4)) (o + j) (spr j)])))
                        sp))
   sky (defs (wad-sky (M 'name)) @ () () d (texture w pal d))
   {'texs (texs + [(star-tray [1 1] [16777215])]) 'mark mark 'secs secs 'things things 'spr (sprite-cols things) 'sky sky})
 (wad-sky m) (? (m 0 = 69) ("SKY" + string (m 1))
                (: n ((m 3 - 48) * 10 + m 4 - 48) (n < 12 ? "SKY1" (n < 21 ? "SKY2" "SKY3"))))
 (uniq l) (keys (foldl (\ t k (pin t k 1)) {} l))
 ; --- the frame: the sectors' batches, and the things turned to the eye; the sky where the
 ;     scene left the screen bare, 256 texels to a quarter turn ---
 ; ..each thing four corners, all but where they stand along the eye's right laid once
 (sprite-cols ts) (: n #ts K (iota (4 * n)) i (K // 4) c (K % 4) q (iota n)
   (col f) (peep (gem-tray [n] (map f ts)) i 0.0)
   side (1.0 * ((c = 1) + (c = 2))) low (1.0 * (c >= 2)) w (col (t \ 1.0 * t 5 0)) h (col (t \ 1.0 * t 5 1))
   T (star-tray [n] (map (t \ t 4) ts))
   {'n n 'x (col (t \ t 0)) 'z (col (t \ t 1)) 'd (side * w - col (t \ 1.0 * t 5 2))
    'y (col (t \ t 2) - low * h) 'u (side * w) 'v (low * h) 'k (col (t \ t 3 0))
    'tris (int (lace [(q * 4) (q * 4 + 2) (q * 4 + 1) T (q * 4) (q * 4 + 3) (q * 4 + 2) T]))})
 (sprites st) (: S (st 'sc 'spr) th (st 'th) k (S 'k)
   (S 'n = 0 ? () [[(lace [(S 'x + S 'd * cos th) (S 'y) (S 'z - S 'd * sin th) (S 'u) (S 'v) k k k]) (S 'tris)]]))
 (sky-of st) (: S (st 'sc 'sky)
   (\ v I (tray? S
           ? (: w (v 'w) h (v 'h) sw (shape S 1) sh (shape S 0) foc (w / 2.0 / tan (fov / 2.0))
                a (v 'th + atan ((I % w + 0.5 - w / 2.0) / foc)) u (((floor (a * 1024.0 / tau)) % sw) + sw) % sw
                y (min ((I // w) * 200 // h) (sh - 1))
                (peep S (y * sw + u) 0))
             (I * 0))))
 (wad-pens st) (: k (peep st 'kp 1) w (k * st 'w) h (k * st 'h) sc (st 'sc)
   v (mesh-eye w h [(st 'px) (st 'py) (st 'pz)] (st 'th) (st 'ph) 0.0 fov 2.0 8000.0)
   all (sc 'secs + sprites st)
   f (peep (facets w h -1 (v 'cam) (map (b \ b 0) all) (map (b \ b 1) all) (sc 'texs) (gem-tray [8] [0.0 0.0 0.0 96.0 3000.0 8.0 0.0 0.0]))
           (iota (w * h)) 0)
   S (iota ((f = -1) + (f = sc 'mark)))
   (#S = 0 ? f (pin f S (sky-of st v S))))
 (wad-frame st) (mesh-show st (wad-pens st) "" {})
 ; --- the state, and the walk: a body 16 round, up a step of 24, under 56 of headroom ---
 (wad-new w h wd M) (: sc (wad-scene wd M) st (filter (t \ t 3 = 1) (M 'things) @ () [0 0 90 1 7] l <l)
   x (1.0 * st 0) y (1.0 * st 1)
   (wad-size {'px x 'pz y 'py (1.0 * (M 'secs (wad-sector M x y) 0) + eye-h) 'th ((90 - st 2) * pi / 180.0) 'ph 0.0
              'M M 'sc sc 'deep 0 'kitty 0 'kp 1 't 0}
             w (h // 2)))
 (wad-size st w r) (mesh-size st w r)
 (lines-of M) (: ls (M 'lines) vs (M 'vs) sd (M 'sides) S (M 'secs)
   (col f) (gem-tray [#ls] (map f ls))
   (sec l k) (l k = 65535 ? () (S (sd (l k) 5)))
   (h l k i) (sec l k @ () (sec l 5 i) s (1.0 * s i))
   {'ax (col (l \ vs (l 0) 0)) 'ay (col (l \ vs (l 0) 1)) 'bx (col (l \ vs (l 1) 0)) 'by (col (l \ vs (l 1) 1))
    'blk (col (l \ (l 6 = 65535 || (l 2 & 1) != 0) ? 1.0 0.0))
    'ff (col (l \ h l 5 0)) 'fc (col (l \ h l 5 1)) 'bf (col (l \ h l 6 0)) 'bc (col (l \ h l 6 1))})
 (wad-free? st x z) (: L (peep st 'lines () @ () (lines-of (st 'M)) l l) fl (st 'py - eye-h)
   dx (L 'bx - L 'ax) dy (L 'by - L 'ay) t (max (min (((x - L 'ax) * dx + (z - L 'ay) * dy) / (dx * dx + dy * dy + 1e-9)) 1.0) 0.0)
   ex (L 'ax + t * dx - x) ey (L 'ay + t * dy - z) near (ex * ex + ey * ey < 1.0 * body-r * body-r)
   hi (max (L 'ff) (L 'bf)) lo (min (L 'fc) (L 'bc))
   bad (L 'blk + (hi - fl > 1.0 * step-h) + (lo - hi < 1.0 * body-h))
   ; ..and the way there crossing none of them
   px (st 'px) pz (st 'pz) qx (x - px) qz (z - pz)
   d1 (dx * (pz - L 'ay) - dy * (px - L 'ax)) d2 (dx * (z - L 'ay) - dy * (x - L 'ax))
   d3 (qx * (L 'ay - pz) - qz * (L 'ax - px)) d4 (qx * (L 'by - pz) - qz * (L 'bx - px))
   cross ((d1 * d2 < 0.0) * (d3 * d4 < 0.0))
   !(aany ((near + cross) * (bad > 0))))
 ; ..a step in pieces no longer than half the body, so none passes through a line
 (put! st x z) (: s0 (peep st 'lines () @ () (pin st 'lines (lines-of (st 'M))) _ st)
   x0 (s0 'px) z0 (s0 'pz) n (1 + int (sqrt (sq (x - x0) + sq (z - z0)) / 12.0))
   s (foldl (\ s k (walk-slide s (x0 + (x - x0) * k / n) (z0 + (z - z0) * k / n) wad-free?)) s0 (map (+ 1) ^n))
   (pin s 'py (1.0 * (s 'M 'secs (wad-sector (s 'M) (s 'px) (s 'pz)) 0) + eye-h)))
 (wad-step st a) (: dt (peep st 'dt (1.0 / fps))
   (walk-key st a {'turn (turn-v * dt) 'walk (walk-v * dt) 'tilt (tilt-v * dt) 'up 1.3 'down -1.2} put! @ () st s s))
 (wad-walk o M)
   (view-walk {'new (w \ h \ (wad-size (pins (wad-new w h (o 'wad) M) 'deep (o 'md = 'window || view-deep? ()) 'kitty (mesh-mode (o 'md))
                                             'win (peep o 'win ()) 'scale (peep o 'scale 2))
                                       w (h // 2)))
               'size wad-size 'frame wad-frame 'key wad-step
               'binds view-binds 'listed (view-listed ['finer 'coarser])
               'tick (st \ (walk-dt st, st))
               'fps fps 'linger 0 'next () 'song (_ \ ()) 'win (peep o 'win ())})
 (wad-run o) (: wd (wad-read (o 'file)) m (o 'map)
   M (two? wd ? (wad-map wd m) ())
   (? (atom? wd) (say err ("wad: " + o 'file + ": not a wad\n"), flush err, 1)
      (atom? M) (say err ("wad: " + o 'file + ": no map " + m + "\n"), flush err, 1)
      (view-stage (pin o 'wad wd) (o2 \ wad-walk o2 M) (_ \ (say out mesh-gone, flush out)))))
 wad-usage "usage: love lore wad FILE [MAP] [--kitty|--cells|--window] [--scale 1|2|4|8]   (h l turn, k j step, u n look; ? the keys; q or esc leaves)"
 ; ..FILE and MAP first, then view's words
 (wad-opts as) (: pos (\ l (two? l && string? <l && #<l > 0 && <l 0 != 45))
   f (pos as ? <as ()) r (pos as ? >as as) m (pos r ? <r "E1M1") rest (pos r ? >r r)
   (string? f ? (view-words rest [(view-flag "--kitty" 'md 'kitty) (view-flag "--cells" 'md 'cells) (view-flag "--window" 'md 'window) view-scale]
                 @ () () o (pins o 'file f 'map m))
      ()))
 (wad-main as) (view-main "wad" wad-usage wad-opts wad-run as)
 _ (cite 'lore 'lore-enlist 'wad (udoor 'wad wad-main wad-usage 1 1)))
) ; module wad
