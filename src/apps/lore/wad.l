; wad -- a doom map walked, read from its wad by the unofficial doom specs and drawn by facets
; (src/love/raster.c) with no bsp renderer: each subsector a floor and a ceiling fan, cut from
; the box of the map by the nodes' partition lines and its own segs; each side its upper,
; middle and lower quads; each thing a sprite turned to the eye. a sector is a batch, so what
; moves is laid again alone; its light is the vertex colour, and fog toward black the distance.
;
; run: love lore wad FILE [MAP] [--kitty|--cells|--window] [--scale 1|2|4|8]
;      view's walking keys, a d to strafe, r to run, e or space to use, f to fire, 1-6 the guns; q or esc leaves
(module (wad wad-main wad-read wad-map wad-scene wad-new wad-pens wad-frame wad-step wad-tics wad-tick wad-free? wad-size wad-sector wad-usage wad-mixer)
(borrow 'posix)
(borrow 'rove)                          ; pad, for the status row
(borrow 'bytes)                         ; rdle
(borrow 'view)
(borrow 'mesh)
(borrow 'walk)
(borrow 'vec)                           ; sq
(borrow 'mixer)
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
 ; --- the play, by the doom wiki's tables: lines that move sectors, things that fight, are
 ;     taken or block, and the guns ---
 ; ..a line's special: [trigger repeat kind fast key], trigger 'u used on a door, 's a switch,
 ;   'w walked over, 'g shot
 line-kinds {1 ['u 1 'door 0 ()] 26 ['u 1 'door 0 'b] 27 ['u 1 'door 0 'y] 28 ['u 1 'door 0 'r] 117 ['u 1 'door 1 ()]
   31 ['u 0 'open 0 ()] 32 ['u 0 'open 0 'b] 33 ['u 0 'open 0 'r] 34 ['u 0 'open 0 'y] 118 ['u 0 'open 1 ()]
   2 ['w 0 'open 0 ()] 4 ['w 0 'door 0 ()] 86 ['w 1 'open 0 ()] 90 ['w 1 'door 0 ()]
   29 ['s 0 'door 0 ()] 63 ['s 1 'door 0 ()] 103 ['s 0 'open 0 ()] 46 ['g 1 'open 0 ()]
   10 ['w 0 'lift 0 ()] 88 ['w 1 'lift 0 ()] 21 ['s 0 'lift 0 ()] 62 ['s 1 'lift 0 ()]
   36 ['w 0 'high8 1 ()] 70 ['s 1 'high8 1 ()] 98 ['w 1 'high8 1 ()] 23 ['s 0 'down 0 ()] 38 ['w 0 'down 0 ()] 82 ['w 1 'down 0 ()]
   5 ['w 0 'ceil 0 ()] 91 ['w 1 'ceil 0 ()] 18 ['s 0 'next 0 ()] 20 ['s 0 'next 0 ()] 22 ['w 0 'next 0 ()]
   11 ['s 0 'exit 0 ()] 52 ['w 0 'exit 0 ()] 51 ['s 0 'secret 0 ()] 39 ['w 0 'tele 0 ()] 97 ['w 1 'tele 0 ()]
   6 ['w 0 'crush 1 ()] 25 ['w 0 'crush 0 ()] 73 ['w 1 'crush 0 ()] 77 ['w 1 'crush 1 ()] 57 ['w 0 'stop 0 ()] 74 ['w 1 'stop 0 ()]
   7 ['s 0 'stairs 0 ()] 8 ['w 0 'stairs 0 ()] 3 ['w 0 'close 0 ()] 42 ['s 1 'close 0 ()] 50 ['s 0 'close 0 ()] 75 ['w 1 'close 0 ()]
   16 ['w 0 'shut30 0 ()] 76 ['w 1 'shut30 0 ()]}
 ; ..a monster: [sprite health speed radius attack shots walk shoot pain die missile]
 monsters {3004 ["POSS" 20 8 20 'shot 1 "ABCD" "EF" "G" "HIJKL"] 9 ["SPOS" 30 8 20 'shot 3 "ABCD" "EF" "G" "HIJKL"]
   3001 ["TROO" 60 8 20 'ball 1 "ABCD" "EFG" "H" "IJKLM" ["BAL1" 10.0 3 8 0]] 3002 ["SARG" 150 10 30 'bite 1 "ABCD" "EFG" "H" "IJKLMN"]
   58 ["SARG" 150 10 30 'bite 1 "ABCD" "EFG" "H" "IJKLMN"] 3005 ["HEAD" 400 8 31 'ball 1 "A" "BCD" "E" "GHIJKL" ["BAL2" 10.0 5 8 0]]
   3003 ["BOSS" 1000 8 24 'ball 1 "ABCD" "EFG" "H" "IJKLMNO" ["BAL7" 15.0 8 8 0]] 3006 ["SKUL" 100 8 16 'bite 1 "AB" "CD" "E" "FGHIJK"]}
 ; ..a monster's [sight active pain death attack], a list one of which at random
 cries {"POSS" [["POSIT1" "POSIT2" "POSIT3"] "POSACT" "POPAIN" ["PODTH1" "PODTH2" "PODTH3"] "PISTOL"]
        "SPOS" [["POSIT1" "POSIT2" "POSIT3"] "POSACT" "POPAIN" ["PODTH1" "PODTH2" "PODTH3"] "SHOTGN"]
        "TROO" [["BGSIT1" "BGSIT2"] "BGACT" "POPAIN" ["BGDTH1" "BGDTH2"] "CLAW"]
        "SARG" ["SGTSIT" "DMACT" "DMPAIN" "SGTDTH" "SGTATK"] "HEAD" ["CACSIT" "DMACT" "DMPAIN" "CACDTH" ""]
        "BOSS" ["BRSSIT" "DMACT" "DMPAIN" "BRSDTH" "CLAW"] "SKUL" ["" "DMACT" "DMPAIN" "FIRXPL" "SKLATK"]}
 shots ["PUNCH" "PISTOL" "SHOTGN" "PISTOL" "RLAUNC" "PLASMA"]
 ; ..what blocks a body: the barrel, 10 round, and a column, lamp or tree, 16
 solid [2035 2028 30 31 32 33 36 37 47 43 54 48 35 41 42 44 45 46 55 56 57 70 72 85 86 25 26 27 28 29 49 50 51 52 53]
 ; ..what is taken: [what amount most], a gun its number and the ammo it comes with
 items {2011 ['hp 10 100] 2012 ['hp 25 100] 2014 ['hp 1 200] 2013 ['hp 100 200] 2015 ['ar 1 200] 2018 ['ar 100 100]
   2019 ['ar 200 200] 2007 ['bul 10 200] 2048 ['bul 50 200] 2008 ['shl 4 50] 2049 ['shl 20 50] 8 ['bul 10 200]
   2001 ['gun 2 8] 2002 ['gun 3 20] 2003 ['gun 4 2] 2004 ['gun 5 40] 2010 ['rkt 1 50] 2046 ['rkt 5 50] 2047 ['cel 20 300]
   17 ['cel 100 300] 2025 ['suit 2100 0] 5 ['key 'b 0] 40 ['key 'b 0] 6 ['key 'y 0] 39 ['key 'y 0] 13 ['key 'r 0] 38 ['key 'r 0]}
 ; ..a gun: [sprite flash ammo pellets damage dice spread frames reach flashes missile], its firing a
 ;   frame letter a tic and its flash's, "." none, as the DeHackEd docs list the states; a missile
 ;   [sprite speed damage dice splash]
 guns [["PUNG" () () 1 2 10 0.0 "BBBBCCCCDDDDDCCCCBBBBB" 64.0 "" ()]
       ["PISG" "PISF" 'bul 1 5 3 0.05 "AAAABBBBBBCCCCBBBBB" 4096.0 "....AAAAAAA" ()]
       ["SHTG" "SHTF" 'shl 7 5 3 0.2 "AAAAAAAAAABBBBBCCCCCDDDDCCCCCBBBBBAAAAAAAAAA" 4096.0 "...AAAABBB" ()]
       ["CHGG" "CHGF" 'bul 1 5 3 0.08 "AAAA" 4096.0 "AAAA" ()]
       ["MISG" "MISF" 'rkt 1 0 0 0.0 "BBBBBBBBBBBBBBBBBBBB" 4096.0 "AAABBBBCCCCDDDD" ["MISL" 20.0 20 8 128]]
       ["PLSG" "PLSF" 'cel 1 0 0 0.0 "AAA" 4096.0 "AAA" ["PLSS" 25.0 5 8 0]]]
 most {'bul 200 'shl 50 'rkt 50 'cel 300}
 ; ..what a missile's burst shows, and the lump it shows from
 bursts {"MISL" ["MISL" "BCD"] "PLSS" ["PLSE" "ABCDE"] "BAL1" ["BAL1" "CDE"] "BAL2" ["BAL2" "CDE"] "BAL7" ["BAL7" "CDE"]}
 ; ..a sector's light: types 1 random, 2 4 12 a fast strobe, 3 13 a slow one, 8 a glow, 17 a flicker;
 ;   and what its floor does to feet: types 4 5 7 16, the damage each 32 tics
 sore {4 20 5 10 7 5 16 20}
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
 ; ..one side's quads, w [a b sd back line], in front sector F
 (face F w ti th) (: fh (F 0) ch (F 1) a (w 0) b (w 1) sd (w 2) B (w 3) l (w 4) fl (l 2) xo (sd 0) yo (sd 1)
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
 ; ..a sector's sides but those that scroll (special 48), laid each frame instead
 (walls M s ti th) (cats (map (w \ face (M 'secs s) w ti th) (filter (w \ w 4 3 != 48) (faces M s))))
 (scrolls st) (: M (st 'M) sc (st 'sc) sd (M 'sides) t (st 't)
   ws (cats (map (l \ (: a (M 'vs (l 0)) b (M 'vs (l 1)) d (sd (l 5)) B (l 6 = 65535 ? () (M 'secs (sd (l 6) 5)))
                        (face (M 'secs (d 5)) [a b ((d 0 + t) . cup d) B l] (sc 'ti) (sc 'th))))
                 (filter (l \ l 3 = 48) (M 'lines))))
   (two? ws ? [(pack (join ws))] ()))
 (sector-mesh M ps s ti ski skc) (: F (M 'secs s) c (lit (F 4)) fp (filter (p \ p 0 = s && #(p 1) >= 3) ps)
   (cats (map (p \ [(fan (p 1) (F 0) (peep ti ("F:" + F 2) -1) c 0)
                    (F 3 = sky-flat ? (fan (p 1) (F 1) ski skc 1) (fan (p 1) (F 1) (peep ti ("F:" + F 3) -1) c 1))])
              fp)))
 ; ..a sector's batch, laid again alone when it moves
 (swap n) (snip n 0 3 @ "SW1" ("SW2" + snip n 3 #n) "SW2" ("SW1" + snip n 3 #n) _ n)
 (sector-batch M sc s) (pack (join (sector-mesh M (sc 'ps) s (sc 'ti) (sc 'ski) (sc 'skc) + walls M s (sc 'ti) (sc 'th))))
 ; ..a picture turned left for right, for the rotations a sprite's lump serves mirrored
 (flipx T) (: h (shape T 0) w (shape T 1) (peep T (star-tray [h w] (map (i \ (i // w) * w + w - 1 - i % w) ^(h * w))) 0))
 ; ..the textures a map names, laid and indexed: walls by name, flats as "F:" name, and each
 ;   sprite frame its things and the guns show, by name and rotation ("POSSA1", "POSSH0")
 (wad-scene w M) (: pal (palette w) defs (texdefs w) fs (span w "F_START" "F_END" @ t (#(keys t) > 0 ? t (span w "FF_START" "FF_END")))
   ss (span w "S_START" "S_END" @ t (#(keys t) > 0 ? t (span w "SS_START" "SS_END")))
   ; ..a switch's other face, SW1 for SW2 and back, laid beside it
   wn (: ns (uniq (cats (map (sd \ [(sd 2) (sd 3) (sd 4)]) (M 'sides))))
         (filter (k \ k != "-" && two? (defs k)) (uniq (ns + map swap ns))))
   fn (filter (k \ k != sky-flat && two? (fs k)) (uniq (cats (map (S \ [(S 2) (S 3)]) (M 'secs)))))
   need (uniq (filter string? (map (t \ peep thing-of (t 3) () @ () () s (snip s 0 4)) (M 'things)))
              + ["BAL1" "BAL2" "BAL7" "MISL" "PLSS" "PLSE"]
              + filter string? (map (g \ g 0) guns + map (g \ g 1) guns))
   ; ..each [key picture dims], a paired lump twice, its second mirrored
   reg (cats (map (k \ (: p (sprite pal (body w (ss k))) d (p 1)
                          ([[(snip k 0 6) (p 0) d]] + (#k < 8 ? () [[(snip k 0 4 + snip k 6 8) (flipx (p 0)) [(d 0) (d 1) (d 0 - d 2) (d 3)]]]))))
                  (filter (k \ #k >= 6 && elem (snip k 0 4) need) (keys ss))))
   texs (map (k \ texture w pal (defs k)) wn + map (k \ flat pal (body w (fs k))) fn + map (r \ r 1) reg)
   o (#wn + #fn)
   stex (foldl (\ t i (pin t (reg i 0) [(o + i) (reg i 2)])) {} ^#reg)
   ti (foldl (\ t i (pin t (wn i) i)) {} ^#wn)
   ti2 (foldl (\ t i (pin t ("F:" + fn i) (#wn + i))) ti ^#fn)
   th (foldl (\ t k (pin t k (defs k 2))) {} wn)
   mark (sky-mark pal)
   sc {'ps (map (q \ [(sector-of-ss M (q 0)) (q 1)]) (polys M)) 'ti ti2 'th th 'ski #texs 'skc (sky-lit mark)
       'texs (texs + [(star-tray [1 1] [16777215])]) 'mark mark 'stex stex
       'sky (defs (wad-sky (M 'name)) @ () () d (texture w pal d))}
   (pin sc 'secs (map (s \ sector-batch M sc s) ^#(M 'secs))))
 (wad-sky m) (? (m 0 = 69) ("SKY" + string (m 1))
                (: n ((m 3 - 48) * 10 + m 4 - 48) (n < 12 ? "SKY1" (n < 21 ? "SKY2" "SKY3"))))
 (uniq l) (keys (foldl (\ t k (pin t k 1)) {} l))
 ; --- the frame: the sectors' batches, and the things turned to the eye; the sky where the
 ;     scene left the screen bare, 256 texels to a quarter turn; the gun over it ---
 (bearing dx dz) (? (dz > 0.0) (atan (dx / dz)) (dz < 0.0) ((dx >= 0.0 ? pi (0.0 - pi)) + atan (dx / dz)) (dx >= 0.0 ? (pi / 2.0) (0.0 - pi / 2.0)))
 (wrap a) (a > pi ? (wrap (a - tau)) (a < 0.0 - pi ? (wrap (a + tau)) a))
 ; ..a thing's frame by what it is doing, and its rotation, 1 facing the eye
 (frame-of o) (: m (o 'm) t (o 'tic) (at s k) (string (s ((t // k) % #s))) (end s k) (string (s (min (#s - 1) (t // k))))
   (atom? m ? (o 'fr) (o 'st @ 'chase (at (m 6) 4) 'shoot (end (m 7) 8) 'pain (at (m 8) 4) 'die (end (m 9) 5) _ (at (m 6) 64))))
 (look st o) (: X (st 'sc 'stex) s (o 'spr + frame-of o)
   r (1 + ((int (floor ((wrap (o 'th - bearing (st 'px - o 'x) (st 'pz - o 'z)) + pi / 8.0) / (pi / 4.0))) + 8) % 8))
   (peep X (s + string (48 + r)) () @ () (peep X (s + "0") ()) e e))
 (sprites st) (: th (st 'th) rows (filter two? (map (o \ o 'gone = 1 ? () (look st o @ () () e [o e])) (st 'objs)))
   n #rows K (iota (4 * n)) i (K // 4) c (K % 4) q (iota n)
   (col f) (peep (gem-tray [n] (map f rows)) i 0.0)
   side (1.0 * ((c = 1) + (c = 2))) low (1.0 * (c >= 2)) w (col (r \ 1.0 * r 1 1 0)) h (col (r \ 1.0 * r 1 1 1))
   top (col (r \ (: o (r 0) (o 'hung ? (o 'ceil) (o 'y + r 1 1 3)))))
   d (side * w - col (r \ 1.0 * r 1 1 2)) k (col (r \ r 0 'k)) T (star-tray [n] (map (r \ r 1 0) rows))
   (n = 0 ? () [[(lace [(col (r \ r 0 'x) + d * cos th) (top - low * h) (col (r \ r 0 'z) - d * sin th) (side * w) (low * h) k k k])
                 (int (lace [(q * 4) (q * 4 + 2) (q * 4 + 1) T (q * 4) (q * 4 + 3) (q * 4 + 2) T]))]]))
 (sky-of st) (: S (st 'sc 'sky)
   (\ v I (tray? S
           ? (: w (v 'w) h (v 'h) sw (shape S 1) sh (shape S 0) foc (w / 2.0 / tan (fov / 2.0))
                a (v 'th + atan ((I % w + 0.5 - w / 2.0) / foc)) u (((floor (a * 1024.0 / tau)) % sw) + sw) % sw
                y (min ((I // w) * 200 // h) (sh - 1))
                (peep S (y * sw + u) 0))
             (I * 0))))
 ; ..a gun's picture on a w by h frame: where its texels fall, and what they are, its foot on the
 ;   frame's, as wide again as the frame is tall over 200
 (gun-px st w h key dx dy) (: e (peep (st 'sc 'stex) key ())
   (atom? e ? [() ()]
      (: T (st 'sc 'texs (e 0)) d (e 1) s (h / 200.0) gw (int (d 0 * s)) gh (int (d 1 * s))
         x0 (int ((dx - d 2) * s + (w - 320.0 * s) / 2.0)) y0 (int ((32 + dy - d 3) * s))
         J (iota (gw * gh)) sx (J % gw) sy (J // gw) c (peep T (int (sy / s) * d 0 + int (sx / s)) -1)
         X (x0 + sx) Y (y0 + sy) ok (iota ((c >= 0) * (X >= 0) * (X < w) * (Y >= 0) * (Y < h)))
         [(peep (Y * w + X) ok 0) (peep c ok 0)])))
 ; ..swung as the body moves, a gun's way, and lowered by 'gy
 (gun-over st f w h) (: g (guns (st 'gun)) v2 (sq (st 'vx) + sq (st 'vz)) bob (min2 16.0 (v2 / 4.0)) a (0.098 * st 't)
   dx (int (bob * cos a) // 2 * 2) dy ((int (bob * mag (sin a)) + st 'gy) // 2 * 2)
   _ (#(keys (peep st 'gunc {})) > 256 ? (pin st 'gunc {}) 0)
   cache (peep st 'gunc () @ () (pin st 'gunc {} 'gunc) c c)
   (px k) (: id (k + show w + "x" + show h + "@" + show dx + "," + show dy)
            (peep cache id () @ () (: v (gun-px st w h k dx dy) _ (pin cache id v) v) v v))
   (lay f k) (: p (px k) (#(p 0) > 0 ? (pin f (p 0) (p 1)) f))
   ; ..the tic of its firing it is at, its frame and its flash's then
   i (st 'gcd > 0 ? (#(g 7) - st 'gcd) -1) (at s) (i < 0 || i >= #s ? 46 (s i))
   f2 (lay f (g 0 + string (at (g 7) @ 46 65 c c) + "0"))
   (at (g 9) = 46 || !(string? (g 1)) ? f2 (lay f2 (g 1 + string (at (g 9)) + "0"))))
 (wad-pens st) (: k (peep st 'kp 1) w (k * st 'w) h (k * st 'h) sc (st 'sc)
   v (mesh-eye w h [(st 'px) (st 'py) (st 'pz)] (st 'th) (st 'ph) 0.0 fov 2.0 8000.0)
   all (sc 'secs + scrolls st + sprites st)
   f (peep (facets w h -1 (v 'cam) (map (b \ b 0) all) (map (b \ b 1) all) (sc 'texs) (gem-tray [8] [0.0 0.0 0.0 96.0 3000.0 8.0 0.0 0.0]))
           (iota (w * h)) 0)
   S (iota ((f = -1) + (f = sc 'mark)))
   f2 (#S = 0 ? f (pin f S (sky-of st v S)))
   (st 'hp > 0 ? (gun-over st f2 w h) f2))
 ; ..and under it the player's state, a row of the screen
 (status st) (: g (guns (st 'gun)) a (g 2)
   ("HP \(st 'hp)  AR \(st 'ar)  " + (a = () ? "" "AMMO \(st a)  ") + (g 0 @ "PUNG" "FIST" "PISG" "PISTOL" "SHTG" "SHOTGUN" "CHGG" "CHAINGUN" "MISG" "ROCKETS" _ "PLASMA") + (st 'run = 1 ? "  RUN" "")
    + (two? (st 'keys) ? ("  KEYS " + foldl (\ a k (a + show k)) "" (st 'keys)) "") + "  " + peep st 'msg ""))
 (band st s r) (: deep (st 'deep)
   (pen v) (deep ? (: (q x) ((x * 63 + 127) // 255) (q (v 0) * 4096 + q (v 1) * 64 + q (v 2))) (v 3))
   (cells s) (: (go i) (i < #s ? (: j (cite 'text 'cpnext s i) (snip s i j . go j)) ()) (go 0))
   {(r - 1) [0 (cells s) (pen [240 240 240 255]) (pen [20 20 20 233])]})
 (wad-frame st) (: w (st 'w) r (st 'h // 2) s (snip (pad (" " + status st) w " ") 0 w)
   (mesh-show st (wad-pens st) (esc + "[" + show r + ";1H" + esc + "[0;37;40m" + s + esc + "[0m") (band st s r)))
 ; --- the state: the map, its things, the movers, and the player: body, health, armor, guns, keys ---
 ; ..where a thing stands: its sector's floor, ceiling and light
 (place M o) (: S (M 'secs (wad-sector M (o 'x) (o 'z))) (pins o 'y (1.0 * S 0) 'ceil (1.0 * S 1) 'k (lit (S 4) 0)))
 (objs-of M) (: (keep t) ((t 4 & 16) = 0 && (t 4 & 4) != 0 && (two? (peep monsters (t 3) ()) || string? (thing-of (t 3))))
   (remap (filter keep (M 'things)) (\ i t (: ty (t 3) m (peep monsters ty ()) s (peep thing-of ty "")
                (place M {'id i 't ty 'x (1.0 * t 0) 'z (1.0 * t 1) 'th ((90 - t 2) * pi / 180.0) 'm m 'it (peep items ty ())
                          'spr (two? m ? (m 0) (snip s 0 4)) 'fr (snip s 4 5) 'hp (two? m ? (m 1) 20)
                          'r (two? m ? (1.0 * m 3) (ty = 2035 ? 10.0 16.0)) 'solid (two? m || elem ty solid ? 1 0)
                          'st (two? m ? 'idle 'still) 'tic 0 'cd 0 'heard 0 'deaf ((t 4 & 8) != 0) 'gone 0 'hung (elem ty hung) 'proj 0})))))
 ; ..a map entered: the player at its start, the rest of them carried
 (enter st wd M) (: p (filter (t \ t 3 = 1) (M 'things) @ () [0 0 90 1 7] l <l) x (1.0 * p 0) z (1.0 * p 1) sd (M 'sides)
   nb (foldl (\ t l (l 6 = 65535 ? t (: a (sd (l 5) 5) b (sd (l 6) 5) _ (pin t a (b . peep t a ())) (pin t b (a . peep t b ())))))
             {} (M 'lines))
   (pins st 'M M 'wd wd 'sc (wad-scene wd M) 'objs (objs-of M) 'movers () 'dirty {} 'lines (lines-of M) 'sol () 'nb nb
        'spec (star-tray [#(M 'lines)] (map (l \ l 3) (M 'lines))) 'exit () 'flips () 'scr (filter (l \ l 3 = 48) (M 'lines))
        ; ..the sectors whose light moves, and the dimmest of their neighbours to move it to
        'lights (filter tablet? (map (s \ (: S (M 'secs s) T (S 5) ls (map (q \ M 'secs q 4) (peep nb s ()))
                                          m (two? ls ? (foldl min2 <ls ls) 0)
                                          (elem T [1 2 3 4 8 12 13 17]
                                           ? {'s s 'T T 'hi (S 4) 'lo (m < S 4 ? m 0) 'ph (T = 12 || T = 13 ? 0 (rand 64)) 'now (S 4)} ())))
                                 ^#(M 'secs)))
        'px x 'pz z 'py (1.0 * (M 'secs (wad-sector M x z) 0) + eye-h) 'th ((90 - p 2) * pi / 180.0) 'ph 0.0 'msg (M 'name)))
 (fresh st) (pins st 'hp 100 'ar 0 'ac 0 'bul 50 'shl 0 'rkt 0 'cel 0 'has [0 1] 'gun 1 'keys () 'gcd 0 'frac 0.0
                     'vx 0.0 'vz 0.0 'gy 0 'gnext -1 'run 0 'suit 0 'sfx ())
 (wad-new w h wd M) (wad-size (enter (fresh {'deep 0 'kitty 0 'kp 1 't 0}) wd M) w (h // 2))
 (wad-size st w r) (mesh-size st w r)
 (restart st) (enter (fresh st) (st 'wd) (wad-map (st 'wd) (st 'M 'name)))
 ; --- the lines: where they stand, what blocks, the floors and ceilings either side ---
 (lines-of M) (: ls (M 'lines) vs (M 'vs) sd (M 'sides)
   (col f) (gem-tray [#ls] (map f ls)) (sec l k) (sd (l (l k = 65535 ? 5 k)) 5)
   (heights {'ax (col (l \ vs (l 0) 0)) 'ay (col (l \ vs (l 0) 1)) 'bx (col (l \ vs (l 1) 0)) 'by (col (l \ vs (l 1) 1))
             'blk (col (l \ (l 6 = 65535 || (l 2 & 1) != 0) ? 1.0 0.0)) 'bm (col (l \ (l 2 & 2) != 0 ? 1.0 0.0))
             'fs (star-tray [#ls] (map (l \ sec l 5) ls)) 'bs (star-tray [#ls] (map (l \ sec l 6) ls))}
            M))
 ; ..and their floors and ceilings either side, from the sectors' as they stand
 (heights L M) (: S (M 'secs) F (gem-tray [#S] (map (s \ 1.0 * s 0) S)) C (gem-tray [#S] (map (s \ 1.0 * s 1) S))
   (pins L 'ff (peep F (L 'fs) 0.0) 'fc (peep C (L 'fs) 0.0) 'bf (peep F (L 'bs) 0.0) 'bc (peep C (L 'bs) 0.0)))
 ; ..the solid things, as trays, laid again each tic
 (solids st) (: os (filter (o \ o 'solid = 1 && o 'gone = 0) (st 'objs)) (col f) (gem-tray [#os] (map f os))
   {'n #os 'x (col (o \ o 'x)) 'z (col (o \ o 'z)) 'r (col (o \ o 'r))})
 ; ..a body r round from ox oz, its feet at fl, free to stand at x z: no line too high, too low or
 ;   shut within r, none crossed on the way, no solid thing come nearer than r, and a monster
 ;   (mon) kept off the player and the lines that bar monsters
 (free-at st x z ox oz fl r mon) (: L (st 'lines)
   dx (L 'bx - L 'ax) dy (L 'by - L 'ay) t (max (min (((x - L 'ax) * dx + (z - L 'ay) * dy) / (dx * dx + dy * dy + 1e-9)) 1.0) 0.0)
   ex (L 'ax + t * dx - x) ey (L 'ay + t * dy - z) near (ex * ex + ey * ey < r * r)
   hi (max (L 'ff) (L 'bf)) lo (min (L 'fc) (L 'bc))
   bad (L 'blk + mon * L 'bm + (hi - fl > 1.0 * step-h) + (lo - hi < 1.0 * body-h))
   qx (x - ox) qz (z - oz)
   d1 (dx * (oz - L 'ay) - dy * (ox - L 'ax)) d2 (dx * (z - L 'ay) - dy * (x - L 'ax))
   d3 (qx * (L 'ay - oz) - qz * (L 'ax - ox)) d4 (qx * (L 'by - oz) - qz * (L 'bx - ox))
   S (peep st 'sol () @ () (pin st 'sol (solids st) 'sol) s s)
   dn ((S 'x - x) * (S 'x - x) + (S 'z - z) * (S 'z - z)) dw ((S 'x - ox) * (S 'x - ox) + (S 'z - oz) * (S 'z - oz))
   (!(aany ((near + (d1 * d2 < 0.0) * (d3 * d4 < 0.0)) * (bad > 0)))
    && (S 'n = 0 || !(aany ((dn < (S 'r + r) * (S 'r + r)) * (dn < dw))))
    && (mon = 0 || sq (st 'px - x) + sq (st 'pz - z) > sq (r + 1.0 * body-r))))
 (wad-free? st x z) (free-at st x z (st 'px) (st 'pz) (st 'py - eye-h) (1.0 * body-r) 0)
 ; ..the lines the way from a to b crosses, nearest first, [how far along, which]; one shut, or
 ;   with no gap, stops a sight
 (crossed st ax az bx bz) (: L (st 'lines) dx (L 'bx - L 'ax) dy (L 'by - L 'ay) qx (bx - ax) qz (bz - az)
   d1 (dx * (az - L 'ay) - dy * (ax - L 'ax)) d2 (dx * (bz - L 'ay) - dy * (bx - L 'ax))
   d3 (qx * (L 'ay - az) - qz * (L 'ax - ax)) d4 (qx * (L 'by - az) - qz * (L 'bx - ax))
   I (iota ((d1 * d2 < 0.0) * (d3 * d4 < 0.0))) s (peep (d1 / (d1 - d2 + 1e-9)) I 0.0)
   (sort (map (k \ [(peep s k 0.0) (peep I k 0)]) ^#I)))
 (shut st i) (: L (st 'lines) (g k) (peep (L k) i 0.0)
   (g 'blk > 0.0 || min2 (g 'fc) (g 'bc) - max2 (g 'ff) (g 'bf) <= 0.0))
 (sees st ax az bx bz) !(any (c \ shut st (c 1)) (crossed st ax az bx bz))
 ; --- the specials: a line set going moves its sectors, leaves the level, or sends the player on ---
 (act st i how) (: M (st 'M) l (M 'lines i) k (peep line-kinds (peep (st 'spec) i 0) ())
   (? (atom? k || !(k 0 = how || (how = 'u && k 0 = 's))) st
      (two? (k 4) && !(elem (k 4) (st 'keys))) (mix-cry (pin st 'msg ("you need the " + (k 4 @ 'b "blue" 'y "yellow" _ "red") + " key")) "NOWAY" ())
      (: secs (k 0 = 'u ? (l 6 = 65535 ? () [(M 'sides (l 6) 5)]) (filter (s \ l 4 != 0 && M 'secs s 6 = l 4) ^#(M 'secs)))
         _ (k 1 = 0 ? (pin st 'spec (pin (st 'spec) i 0)) 0)
         ; ..a switch shows it was thrown, a repeatable one again a second on
         _ (k 0 = 's ? (: _ (flip st (l 5)) _ (mix-cry st (elem (k 2) ['exit 'secret] ? "SWTCHX" "SWTCHN") [(0.5 * (M 'vs (l 0) 0 + M 'vs (l 1) 0)) (0.5 * (M 'vs (l 0) 1 + M 'vs (l 1) 1))]) (k 1 = 1 ? (pin st 'flips ([(st 't + 35) (l 5)] . st 'flips)) 0)) 0)
         (k 2 @ 'exit (pin st 'exit (next-map (M 'name) 0)) 'secret (pin st 'exit (next-map (M 'name) 1))
                'tele (mix-cry (teleport st (l 4)) "TELEPT" ())
                'stop (pin st 'movers (filter (m \ !(m 'k = 'crush && elem (m 's) secs)) (st 'movers)))
                'stairs (foldl (\ s q (stairs s q)) st secs)
                _ (foldl (\ s q (start s q (k 2) (k 3))) st secs)))))
 (flip st d) (: M (st 'M)
   _ (pin M 'sides (remap (M 'sides) (\ i e (i = d ? [(e 0) (e 1) (swap (e 2)) (swap (e 3)) (swap (e 4)) (e 5)] e))))
   (pin (st 'dirty) (M 'sides d 5) 1))
 (next-map m sec) (? (m 0 = 69) (: n (m 3 - 48) ("E" + string (m 1) + "M" + string (48 + (sec ? 9 (n = 9 ? 4 (n + 1))))))
                     (: n ((m 3 - 48) * 10 + m 4 - 48 + 1) ("MAP" + string (48 + n // 10) + string (48 + n % 10))))
 (teleport st tag) (: M (st 'M) d (filter (t \ t 3 = 14 && M 'secs (wad-sector M (1.0 * t 0) (1.0 * t 1)) 6 = tag) (M 'things))
   (atom? d ? st (: t <d x (1.0 * t 0) z (1.0 * t 1)
                    (pins st 'px x 'pz z 'th ((90 - t 2) * pi / 180.0) 'py (1.0 * (M 'secs (wad-sector M x z) 0) + eye-h)))))
 ; ..a sector set moving: doors, closers and crushers by the ceiling, the rest by the floor
 (start st s kind fast) (: M (st 'M) F (M 'secs s) ns (peep (st 'nb) s ())
   NF (map (q \ M 'secs q 0) ns) NC (map (q \ M 'secs q 1) ns)
   (lo l d) (two? l ? (foldl min2 <l l) d) (hi l d) (two? l ? (foldl max2 <l l) d)
   (start-to st s kind fast
     (kind @ 'door (lo NC (F 1) - 4) 'open (lo NC (F 1) - 4) 'close (F 0) 'shut30 (F 0) 'crush (F 0 + 8)
             'lift (min2 (F 0) (lo NF (F 0))) 'down (lo NF (F 0)) 'high8 (hi NF (F 0) + 8) 'ceil (lo NC (F 1))
             'next (lo (filter (f \ f > F 0) NF) (F 0)) _ (F 0))))
 ; ..one mover a sector; a door used again while it opens or waits goes back down
 (start-to st s kind fast to) (: F (st 'M 'secs s) was (filter (m \ m 's = s) (st 'movers))
   up (elem kind ['door 'open 'close 'shut30 'crush])
   (? (two? was) (: m <was _ (m 'k = 'door && m 'ph != 'back ? (: _ (pins m 'ph 'back 'w 0) (mix-cry st "DORCLS" (mid st s))) 0) st)
      (: _ (mix-cry st (kind @ 'door (fast ? "BDOPN" "DOROPN") 'open (fast ? "BDOPN" "DOROPN") 'close (fast ? "BDCLS" "DORCLS")
                             'shut30 "DORCLS" 'lift "PSTART" _ "") (mid st s))
      (pin st 'movers ({'s s 'k kind 'p (up ? 1 0) 'to (1.0 * to) 'home (1.0 * F (up ? 1 0)) 'ph 'go 'w 0
                        'v (kind @ 'crush (fast ? 2.0 1.0) 'lift 4.0 _ (fast ? 8.0 (up ? 2.0 1.0)))} . st 'movers)))))
 ; ..stairs: each step 8 over the last, on through the sector floored alike behind each
 (stairs st s) (: M (st 'M) sd (M 'sides) fl (M 'secs s 2)
   (next q) (: ls (filter (l \ l 6 != 65535 && sd (l 5) 5 = q && M 'secs (sd (l 6) 5) 2 = fl) (M 'lines)) (two? ls ? (sd (<ls 6) 5) -1))
   (go s q h seen) (? (q < 0 || elem q seen) s (go (start-to s q 'step 0 h) (next q) (h + 8) (q . seen)))
   (go st s (M 'secs s 0 + 8) ()))
 (remap l f) (: (go l i) (atom? l ? () (f i <l . go >l (i + 1))) (go l 0))
 ; ..a tic of a mover; 0 once it is done. a closing door meeting the player goes back up; a
 ;   crusher goes on down, hurting all under it, then up and down again until stopped
 (move-tic st m) (: M (st 'M) s (m 's) p (m 'p) k (m 'k) cur (1.0 * M 'secs s p) ph (m 'ph)
   (? (ph = 'wait) (: w (m 'w - 1) _ (pins m 'w w 'ph (w <= 0 ? 'back 'wait))
                      _ (w <= 0 ? (mix-cry st (k @ 'lift "PSTART" 'shut30 "DOROPN" _ (m 'v > 4.0 ? "BDCLS" "DORCLS")) (mid st s)) 0) 1)
      (: to (ph = 'go ? (m 'to) (m 'home)) nv (cur + max2 (0.0 - m 'v) (min2 (m 'v) (to - cur)))
         here (wad-sector M (st 'px) (st 'pz) = s) low (nv < M 'secs s 0 + 1.0 * body-h)
         _ (k = 'crush && ph = 'go && low && st 't % 4 = 0
            ? (: _ (here ? (hurt st 10) 0)
                 (each (filter (o \ two? (o 'm) && o 'gone = 0 && wad-sector M (o 'x) (o 'z) = s) (st 'objs)) (o \ hit st o 10 ()))) 0)
         (? (p = 1 && ph = 'back && k != 'crush && here && low) (: _ (pin m 'ph 'go) _ (mix-cry st "DOROPN" (mid st s)) 1)
            (: _ (pin M 'secs (remap (M 'secs) (\ i S (i = s ? (p = 0 ? (nv . cup S) (cap S . nv . cup (cup S))) S))))
               _ (each (s . peep (st 'nb) s ()) (q \ pin (st 'dirty) q 1))
               ; ..a floor grinds on, a lift or floor stops with a clunk
               door (elem k ['door 'open 'close 'shut30])
               _ (!door && k != 'lift && nv != to && st 't % 8 = 0 ? (mix-cry st "STNMOV" (mid st s)) 0)
               _ (!door && k != 'crush && nv = to ? (mix-cry st "PSTOP" (mid st s)) 0)
               (? (nv != to) 1
                  (k = 'crush) (: _ (pin m 'ph (ph = 'go ? 'back 'go)) 1)
                  (ph = 'back || !(elem k ['door 'lift 'shut30])) 0
                  (: _ (pins m 'ph 'wait 'w (k @ 'door 150 'lift 105 _ 1050)) 1)))))))
 ; ..the batches and lines of what moved, laid again; their lights as built
 (relay st) (: d (st 'dirty) M (st 'M) sc (st 'sc)
   (#(keys d) = 0 ? st
      (: _ (pin sc 'secs (remap (sc 'secs) (\ i b (peep d i 0 = 1 ? (sector-batch M sc i) b))))
         _ (each (keys d) (i \ pin (peep sc 'tint () @ () (pin sc 'tint {} 'tint) t t) i ()))
         _ (each (st 'lights) (L \ (peep d (L 's) 0 = 1 ? (pin L 'now (L 'hi)) 0)))
         _ (each (st 'objs) (o \ o 'proj = 0 ? (place M o) 0))
         (pins st 'dirty {} 'lines (heights (st 'lines) M) 'sol ()))))
 ; --- the lights: a strobe, glow or flicker a sector's batch's colours scaled, as its type says ---
 (glow L t) (: q (t + L 'ph) hi (L 'hi) lo (L 'lo)
   (L 'T @ 1 (q % 8 = 0 ? (rand 8 = 0 ? lo hi) (L 'now))
           2 (q % 20 < 5 ? hi lo) 4 (q % 20 < 5 ? hi lo) 12 (q % 20 < 5 ? hi lo)
           3 (q % 40 < 5 ? hi lo) 13 (q % 40 < 5 ? hi lo)
           8 (: span (max2 1 (hi - lo)) w (q * 8 % (2 * span)) (lo + mag (w - span)))
           17 (q % 4 = 0 ? (rand 4 = 0 ? (max2 lo (hi - 16)) hi) (L 'now))
           _ hi))
 (tint sc i b k) (: tt (peep sc 'tint () @ () (pin sc 'tint {} 'tint) t t)
   e (peep tt i () @ () (: v (b 0) I (iota ((iota #v % 8 >= 5) * (v <= 1.0))) x [I (peep v I 0.0)] _ (pin tt i x) x) x x)
   [(pin (b 0) (e 0) (e 1 * k)) (b 1)])
 (shine st) (: sc (st 'sc) t (st 't) ch {}
   _ (each (st 'lights) (L \ (: v (glow L t) (v = L 'now ? 0 (: _ (pin L 'now v) (pin ch (L 's) (1.0 * v / max2 1 (L 'hi))))))))
   (#(keys ch) = 0 ? st (: _ (pin sc 'secs (remap (sc 'secs) (\ i b (peep ch i -1.0 < 0.0 ? b (tint sc i b (ch i)))))) st)))
 ; --- the sounds: a DS lump is format 3, a rate, a count, then that many unsigned bytes, 16 of
 ;     padding at either end; mixed by mixer.l, whole within 200, gone past 1200 ---
 (spot o) [(o 'x) (o 'z)]
 (yell st o k) (peep cries (o 'spr) () @ () st c (: e (c k) (mix-cry st (string? e ? e (e (rand #e))) (spot o))))
 ; ..the middle of a sector, by its lines' ends
 (mid st s) (: L (st 'lines) w ((L 'fs = s) + (L 'bs = s) > 0) n (2.0 * max2 1 (net w))
   [(net ((L 'ax + L 'bx) * w) / n) (net ((L 'ay + L 'by) * w) / n)])
 ; ..a sound's samples, floats about 0, and its rate; read once a wad
 (noise wd nm) (: c (peep wd 'snd () @ () (pin wd 'snd {} 'snd) t t)
   (peep c nm 0 @ 0 (: b (lump wd ("DS" + nm))
                       n (string? b && #b > 40 && u16 b 0 = 3 ? (min2 (rdle b 4 4) (#b - 8)) 0)
                       v (n > 32 ? [(gem-tray [(n - 32)] (map (i \ (b (24 + i) - 128) / 128.0) ^(n - 32))) (u16 b 2)] ())
                       _ (pin c nm v) v)
                  v v))
 ; ..the mixer into horn hn, the player the ear, by doom's distances
 (wad-mixer hn wd) (mix-new hn (nm \ noise wd nm) (st \ [(st 'px) (st 'pz) (st 'th)]) {'near 200.0 'far 1200.0 'fps fps})
 ; --- the fight: monsters wake, chase and shoot, each other too once hurt by one; missiles fly
 ;     and burst; the player is hurt, takes what lies about, and shoots back ---
 (hurt st d) (: take (min2 (st 'ar) (st 'ac = 2 ? (d // 2) (d // 3))) hp (max2 0 (st 'hp - d + take))
   _ (st 'hp > 0 ? (mix-cry st (hp = 0 ? "PLDETH" "PLPAIN") ()) 0)
   (pins st 'ar (st 'ar - take) 'hp hp 'msg (hp = 0 ? "dead -- e to begin the level again" (st 'msg))))
 ; ..a thing hit by by: a monster turned on its own kind's foe, a barrel bursting
 (hit st o d by) (: m (o 'm) hp (o 'hp - d)
   (? (o 'gone = 1 || o 'st = 'die || (atom? m && o 't != 2035)) st
      (hp <= 0) (: _ (pins o 'hp 0 'st 'die 'tic 0 'solid 0) _ (o 't = 2035 ? (mix-cry st "BAREXP" (spot o)) (yell st o 3))
                   (o 't = 2035 ? (: _ (pin o 'gone 1) (splash st (o 'x) (o 'z) 128 by)) st))
      (: _ (pins o 'hp hp 'heard 1)
         _ (two? m && tablet? by && by 'id != o 'id && by 'spr != o 'spr ? (pin o 'tg by) 0)
         _ (two? m && randf 1.0 < 0.5 ? (: _ (pins o 'st 'pain 'tic 0) (yell st o 2)) 0) st)))
 ; ..all within r of x z hurt by how near
 (splash st x z r by) (: (near ax az) (sqrt (sq (ax - x) + sq (az - z)))
   d (near (st 'px) (st 'pz)) _ (d < r ? (hurt st (int (r - d))) 0)
   _ (each (filter (q \ q 'gone = 0 && q 'st != 'die && (two? (q 'm) || q 't = 2035)) (st 'objs))
           (q \ (: e (near (q 'x) (q 'z)) (e < r ? (hit st q (int (r - e)) by) 0))))
   st)
 ; ..a missile: [sprite speed damage dice splash] along bearing b, its maker by
 (launch st by x z y b p) (: id (peep st 'nid 100000) _ (pin st 'nid (id + 1))
   (pin st 'objs ({'id id 'proj 1 'spr (p 0) 'fr "A" 'x x 'z z 'y y 'vx (p 1 * sin b) 'vz (p 1 * cos b) 'th b 'r 8.0
                   'solid 0 'gone 0 'k 1.0 'tic 0 'hung 0 'm () 'by by 'dmg (p 2 * (1 + rand (p 3))) 'splash (p 4) 'boom 0} . st 'objs)))
 (burst st o) (: e (peep bursts (o 'spr) ["BAL1" "CDE"])
   _ (mix-cry st (o 'spr = "MISL" ? "BAREXP" "FIRXPL") (spot o))
   _ (o 'splash > 0 ? (splash st (o 'x) (o 'z) (1.0 * o 'splash) (o 'by)) 0)
   (pins o 'boom 1 'ex (e 1) 'spr (e 0) 'fr (string (e 1 0)) 'vx 0.0 'vz 0.0))
 (target st o) (: q (peep o 'tg ()) (tablet? q && q 'gone = 0 && q 'st != 'die ? [(q 'x) (q 'z) q] [(st 'px) (st 'pz) ()]))
 (fly st o) (? (o 'boom > 0) (: t (o 'boom + 1) s (o 'ex) (t > 5 * #s ? (pin o 'gone 1) (pins o 'boom t 'fr (string (s (min (#s - 1) (t // 5)))))))
   (: x (o 'x + o 'vx) z (o 'z + o 'vz) t (o 'tic + 1) L (st 'lines) y (o 'y) by (o 'by) mine (tablet? by ? (by 'id) -1)
      wall (any (c \ (: i (c 1) (g k) (peep (L k) i 0.0)
                       (shut st i || y < max2 (g 'ff) (g 'bf) || y > min2 (g 'fc) (g 'bc))))
                (crossed st (o 'x) (o 'z) x z))
      who (filter (q \ q 'solid = 1 && q 'gone = 0 && q 'id != mine && sq (q 'x - x) + sq (q 'z - z) < sq (q 'r + o 'r)) (st 'objs))
      (? (by != 'player && sq (st 'px - x) + sq (st 'pz - z) < sq (1.0 * body-r + o 'r)) (: _ (hurt st (o 'dmg)) (burst st o))
         (two? who) (: q <who _ (tablet? by && q 'spr = by 'spr ? 0 (hit st q (o 'dmg) by)) (burst st o))
         (wall || t > 175) (burst st o)
         (pins o 'x x 'z z 'tic t 'fr (o 'spr = "MISL" || t // 4 % 2 = 0 ? "A" "B")))))
 (attack st o d) (: m (o 'm) T (target st o) q (T 2) close (d < 80.0 + o 'r) vis (sees st (o 'x) (o 'z) (T 0) (T 1))
   (strike n) (tablet? q ? (hit st q n o) (hurt st n))
   _ (m 4 = 'ball && !close ? (vis ? (mix-cry st "FIRSHT" (spot o)) 0) (m 4 = 'shot || close ? (yell st o 4) 0))
   (m 4 @ 'shot (each ^(m 5) (_ \ (vis && randf 1.0 < max2 0.15 (0.8 - d / 1500.0) ? (strike (3 * (1 + rand 5))) 0)))
          'bite (close ? (strike (4 * (1 + rand 10))) 0)
          'ball (close ? (strike (3 * (1 + rand 8))) (vis ? (launch st o (o 'x) (o 'z) (o 'y + 32.0) (bearing (T 0 - o 'x) (T 1 - o 'z)) (m 10)) 0))
          _ 0))
 ; ..a walking frame's step, doom's way: on along its heading while that goes and its count
 ;   lasts, else toward the mark -- the diagonal, either axis, the old heading, any, and last back
 ;   the way it came
 (chase st o tx tz) (: v (1.0 * o 'm 2) dx (tx - o 'x) dz (tz - o 'z) md (peep o 'md -1)
   (go k) (: a (k * pi / 4.0) x (o 'x + v * sin a) z (o 'z + v * cos a)
            (free-at st x z (o 'x) (o 'z) (o 'y) (o 'r) 1 ? (: _ (place (st 'M) (pins o 'x x 'z z 'th a 'md k)) 1) 0))
   (dir sx sz) (sx = 0 && sz = 0 ? -1 ((int (floor (bearing (1.0 * sx) (1.0 * sz) / (pi / 4.0) + 0.5)) + 8) % 8))
   sx (dx > 10.0 ? 1 (dx < -10.0 ? -1 0)) sz (dz > 10.0 ? 1 (dz < -10.0 ? -1 0))
   (try ks) (? (atom? ks) 0 (: k <ks ok (k < 0 ? 0 (go k)) (ok = 1 ? (pin o 'mc (rand 16)) (try >ks))))
   (? (sq dx + sq dz < sq (o 'r + 1.0 * body-r + 8.0)) 0
      (: ok (md >= 0 && peep o 'mc 0 > 0 ? (go md) 0)
         (ok = 1 ? (pin o 'mc (o 'mc - 1)) (try [(dir sx sz) (dir sx 0) (dir 0 sz) md (rand 8) (rand 8) (md < 0 ? -1 ((md + 4) % 8))])))))
 (think st o) (: m (o 'm) t (o 'tic + 1) T (target st o) px (T 0) pz (T 1) dx (px - o 'x) dz (pz - o 'z) d (sqrt (dx * dx + dz * dz))
   _ (pin o 'tic t)
   _ (tablet? (peep o 'tg ()) && atom? (T 2) ? (pin o 'tg ()) 0)
   (o 'st @
    ; ..a monster sees ahead of it, or anything within reach; one deaf (ambush) wakes only so
    'idle (t % 8 = 0 && (o 'heard = 1 || (d < 2000.0 && (d < 80.0 + o 'r || mag (wrap (bearing dx dz - o 'th)) < pi / 2.0)
                                          && sees st (o 'x) (o 'z) px pz))
           ? (: _ (pins o 'st 'chase 'tic 0 'cd (rand 40)) (yell st o 0)) 0)
    ; ..a chase acts once a walking frame, 4 tics
    'chase (: cd (o 'cd - 4) reach (d < 80.0 + o 'r && m 4 != 'shot)
             (? (t % 4 != 0) 0
                ((tablet? (T 2) || st 'hp > 0) && cd <= 0 && (reach || (randf 1.0 < 0.2 && sees st (o 'x) (o 'z) px pz)))
                (pins o 'st 'shoot 'tic 0 'th (bearing dx dz))
                (: _ (pin o 'cd cd) _ (rand 64 = 0 ? (yell st o 1) 0) (chase st o px pz))))
    'shoot (? (t = 8 * (#(m 7) - 1)) (attack st o d) (t >= 8 * #(m 7)) (pins o 'st 'chase 'tic 0 'cd (30 + rand 60)) 0)
    'pain (t >= 6 ? (pins o 'st 'chase 'tic 0) 0)
    _ 0))
 ; ..what lies within reach taken, if it is wanted
 (gain st o) (: it (o 'it) k (it 0) n (it 1) top (it 2)
   (? (k = 'key) (: _ (pin o 'gone 1) (pins st 'keys (n . st 'keys) 'msg "a key"))
      (k = 'suit) (: _ (pin o 'gone 1) (pins st 'suit (st 't + n) 'msg "a radiation suit"))
      (k = 'gun) (: _ (pin o 'gone 1) a (guns n 2)
                    (pick (pins st 'has (sort (uniq (n . st 'has))) a (min2 (most a) (st a + top)) 'msg (guns n 0)) n))
      (st k >= top) st
      (k = 'ar && n >= 100) (: _ (pin o 'gone 1) (pins st 'ar n 'ac (n >= 200 ? 2 1)))
      (: _ (pin o 'gone 1) (pin st k (min2 top (st k + n))))))
 (take st) (foldl (\ s o (o 'gone = 1 || atom? (o 'it) || sq (o 'x - s 'px) + sq (o 'z - s 'pz) > 1296.0 ? s (got (gain s o) o))) st (st 'objs))
 (got st o) (o 'gone = 1 ? (mix-cry st (o 'it 0 @ 'gun "WPNUP" 'suit "GETPOW" _ "ITEMUP") ()) st)
 ; ..the nearest thing a shot along a reaches: a monster up, or a barrel
 (aim st a reach) (: px (st 'px) pz (st 'pz)
   (ok o) (: dx (o 'x - px) dz (o 'z - pz) d (sqrt (dx * dx + dz * dz))
            (d < reach + o 'r && mag (wrap (bearing dx dz - a)) < atan (o 'r / max2 d 1.0) && sees st px pz (o 'x) (o 'z)))
   (dd o) (sq (o 'x - px) + sq (o 'z - pz))
   hits (filter ok (filter (o \ o 'gone = 0 && o 'st != 'die && (two? (o 'm) || o 't = 2035)) (st 'objs)))
   (atom? hits ? () (foldl (\ b o (dd o < dd b ? o b)) <hits hits)))
 (fire st) (: g (guns (st 'gun)) a (g 2) th (st 'th) px (st 'px) pz (st 'pz)
   (? (st 'gcd > 0 || st 'hp <= 0 || st 'gy > 0 || st 'gnext >= 0) st
      (a != () && st a < 1) (pin st 'msg "no ammo")
      (: _ (pins st 'gcd #(g 7) 'msg "")
         _ (a = () ? 0 (pin st a (st a - 1)))
         _ (each (st 'objs) (o \ (two? (o 'm) && !(o 'deaf) && sq (o 'x - px) + sq (o 'z - pz) < 2560000.0 ? (pin o 'heard 1) 0)))
         _ (two? (g 10) ? (launch st 'player (px + 16.0 * sin th) (pz + 16.0 * cos th) (st 'py - 8.0) th (g 10))
              (each ^(g 3) (_ \ (aim st (th + g 6 * (randf 1.0 - 0.5)) (g 8) @ () 0
                                                                       o (: _ (st 'gun = 0 ? (mix-cry st "PUNCH" ()) 0) (hit st o (g 4 * (1 + rand (g 5))) 'player))))))
         _ (st 'gun = 0 ? 0 (mix-cry st (shots (st 'gun)) ()))
         c (filter (c \ peep (st 'spec) (c 1) 0 != 0) (crossed st px pz (px + 2048.0 * sin th) (pz + 2048.0 * cos th)))
         (two? c ? (act st (<c 1) 'g) st))))
 (use st) (: th (st 'th) c (crossed st (st 'px) (st 'pz) (st 'px + 64.0 * sin th) (st 'pz + 64.0 * cos th))
   (atom? c ? st (: i (<c 1) (peep (st 'spec) i 0 = 0 && shut st i ? (mix-cry st "NOWAY" ()) (act st i 'u)))))
 ; ..a gun put down 6 a tic and the next one raised; the body slid on as far as it goes, and slowed
 (gun-tic st) (? (st 'gnext >= 0) (st 'gy >= 96 ? (pins st 'gun (st 'gnext) 'gnext -1) (pin st 'gy (st 'gy + 6)))
                 (st 'gy > 0) (pin st 'gy (max2 0 (st 'gy - 6))) st)
 (glide st) (? (sq (st 'vx) + sq (st 'vz) < 0.01) (pins st 'vx 0.0 'vz 0.0)
               (: x0 (st 'px) z0 (st 'pz) s (put! st (x0 + st 'vx) (z0 + st 'vz))
                  (pins s 'vx (s 'px = x0 ? 0.0 (s 'vx * 0.90625)) 'vz (s 'pz = z0 ? 0.0 (s 'vz * 0.90625)))))
 ; ..a secret found, once
 (secret st q) (: M (st 'M) _ (pin M 'secs (remap (M 'secs) (\ i S (i = q ? [(S 0) (S 1) (S 2) (S 3) (S 4) 0 (S 6)] S))))
   (pins st 'msg "a secret" 'secrets (peep st 'secrets 0 + 1)))
 ; --- the tic, 35 a second: movers, monsters, missiles, switches, lights, the gun and the body,
 ;     what is taken, what the floor does; then what moved laid again ---
 (tic st) (: s (pins st 'sol () 'gcd (max2 0 (st 'gcd - 1)) 't (st 't + 1))
   _ (pin s 'movers (filter (m \ move-tic s m = 1) (s 'movers)))
   _ (each (s 'objs) (o \ (o 'gone = 1 ? 0 (o 'proj = 1 ? (fly s o) (two? (o 'm) ? (think s o) 0)))))
   _ (pin s 'flips (filter (f \ (f 0 > s 't ? 1 (: _ (flip s (f 1)) 0))) (s 'flips)))
   s2 (take (glide (shine (gun-tic s))))
   q (wad-sector (s2 'M) (s2 'px) (s2 'pz)) S (s2 'M 'secs q)
   _ (peep sore (S 5) 0 > 0 && s2 't % 32 = 0 && s2 'py - eye-h <= S 0 + 1 && s2 'suit < s2 't ? (hurt s2 (sore (S 5))) 0)
   _ (S 5 = 9 ? (secret s2 q) 0)
   _ (s2 't % 35 = 0 ? (pin s2 'objs (filter (o \ o 'proj = 0 || o 'gone = 0) (s2 'objs))) 0)
   (pin s2 'py (1.0 * S 0 + (s2 'hp > 0 ? eye-h 8))))
 (wad-tics st n) (relay (foldl (\ s _ (tic s)) st ^n))
 (wad-tick st) (: s (walk-dt st) a (peep s 'frac 0.0 + s 'dt * 35.0) n (min2 4 (int a))
   s2 (wad-tics (pin s 'frac (a - n)) n)
   (s2 'exit @ () s2 m (wad-map (s2 'wd) m @ () (pins s2 'exit () 'msg "the end") M (enter s2 (s2 'wd) M))))
 ; --- the walk: a body 16 round, up a step of 24, under 56 of headroom, in steps no longer than
 ;     half the body; the lines walked over set going ---
 (put! st x z) (: x0 (st 'px) z0 (st 'pz) n (1 + int (sqrt (sq (x - x0) + sq (z - z0)) / 12.0))
   ; ..the first piece that goes nowhere ends it, or a later one could step past a thing
   (go s k) (? (k > n) s
               (: px (s 'px) pz (s 'pz) s1 (walk-slide s (x0 + (x - x0) * k / n) (z0 + (z - z0) * k / n) wad-free?)
                  (s1 'px = px && s1 'pz = pz ? s1 (go s1 (k + 1)))))
   s (go st 1)
   s2 (foldl (\ s c (peep (s 'spec) (c 1) 0 = 0 ? s (act s (c 1) 'w))) s (crossed s x0 z0 (s 'px) (s 'pz)))
   (take (pin s2 'py (1.0 * (s2 'M 'secs (wad-sector (s2 'M) (s2 'px) (s2 'pz)) 0) + eye-h))))
 (pick st k) (elem k (st 'has) && k != st 'gun ? (pins st 'gnext k 'gcd 0) st)
 ; ..a step a push: the body's speed along the way made a walk's 8 a tic, or a run's 16
 (push st a) (: sp (st 'run = 1 ? 16.0 8.0)
   b (st 'th + (a @ 'back pi 'strafe-left (0.0 - pi / 2.0) 'strafe-right (pi / 2.0) _ 0.0))
   ux (sin b) uz (cos b) add (max2 0.0 (sp - (st 'vx * ux + st 'vz * uz)))
   (pins st 'vx (st 'vx + add * ux) 'vz (st 'vz + add * uz)))
 wad-binds {101 'use 32 'use 102 'fire 49 'gun1 50 'gun2 51 'gun3 52 'gun4 53 'gun5 54 'gun6
            97 'strafe-left 100 'strafe-right 44 'strafe-left 46 'strafe-right 114 'run}
 (wad-step st a) (: dt (peep st 'dt (1.0 / fps))
   (? (st 'hp <= 0) (a = 'use ? (restart st) st)
      (a @ 'use (use st) 'fire (fire st) 'gun1 (pick st 0) 'gun2 (pick st 1) 'gun3 (pick st 2) 'gun4 (pick st 3)
           'gun5 (pick st 4) 'gun6 (pick st 5) 'run (pins st 'run (1 - st 'run) 'msg (st 'run = 1 ? "walk" "run"))
           'forward (push st a) 'back (push st a) 'strafe-left (push st a) 'strafe-right (push st a)
           _ (walk-key st a {'turn (turn-v * dt) 'walk (walk-v * dt) 'tilt (tilt-v * dt) 'up 1.3 'down -1.2} put! @ () st s s))))
 (wad-walk o M)
   (view-walk {'new (w \ h \ (wad-size (pins (wad-new w h (o 'wad) M) 'deep (o 'md = 'window || view-deep? ()) 'kitty (mesh-mode (o 'md))
                                             'win (peep o 'win ()) 'scale (peep o 'scale 2))
                                       w (h // 2)))
               'size wad-size 'frame wad-frame 'key wad-step
               'binds (view-bind view-binds wad-binds) 'listed (view-listed ['use 'fire 'strafe-left 'strafe-right 'run 'gun1 'gun2 'gun3 'gun4 'gun5 'gun6 'finer 'coarser])
               'tick wad-tick
               'fps fps 'linger 0 'next () 'song (hn \ (hn ? (wad-mixer hn (o 'wad)) ())) 'win (peep o 'win ())})
 (wad-run o) (: wd (wad-read (o 'file)) m (o 'map)
   M (two? wd ? (wad-map wd m) ())
   (? (atom? wd) (say err ("wad: " + o 'file + ": not a wad\n"), flush err, 1)
      (atom? M) (say err ("wad: " + o 'file + ": no map " + m + "\n"), flush err, 1)
      (view-stage (pin o 'wad wd) (o2 \ wad-walk o2 M) (_ \ (say out mesh-gone, flush out)))))
 wad-usage "usage: love lore wad FILE [MAP] [--kitty|--cells|--window] [--scale 1|2|4|8]   (h l turn, k j step, a d strafe, r run, u n look, e or space use, f fire, 1-6 guns; ? the keys; q or esc leaves)"
 ; ..FILE and MAP first, then view's words
 (wad-opts as) (: pos (\ l (two? l && string? <l && #<l > 0 && <l 0 != 45))
   f (pos as ? <as ()) r (pos as ? >as as) m (pos r ? <r "E1M1") rest (pos r ? >r r)
   (string? f ? (view-words rest [(view-flag "--kitty" 'md 'kitty) (view-flag "--cells" 'md 'cells) (view-flag "--window" 'md 'window) view-scale]
                 @ () () o (pins o 'file f 'map m))
      ()))
 (wad-main as) (view-main "wad" wad-usage wad-opts wad-run as)
 _ (cite 'lore 'lore-enlist 'wad (udoor 'wad wad-main wad-usage 1 1)))
) ; module wad
