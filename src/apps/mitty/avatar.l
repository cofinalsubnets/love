; src/apps/mitty/avatar.l -- the avatars a screen wears: eight rows of eight pixels, a letter
; each or . for none, and a palette of letter and rgb; pom draws a grid as four rows of
; half-blocks, truecolor when COLORTERM says so, else the nearest of 256. 'ink, a letter,
; names the accent where the pixels would choose badly. the moon is drawn as it is tonight,
; so every answer is made per call.
;
;   (avatar-names _)        the names, in gallery order
;   (avatar-look nm)        {'name 'face 'ink 'pen}: its four rows drawn, the accent as an sgr
;                           and as the nearest of 256 for the saver's canvas; () for no such one
;   (avatar-gallery w nm)   every avatar with its name under it, as many to a row as w holds,
;                           the one named nm in bold
(module (avatar avatar-names avatar-look avatar-gallery)
(:
 (sgr code s) ("\e[" + code + "m" + s + "\e[0m")
 (tc _) ((cite 'pom 'pom-tc) 0)
 (tint x) ((cite 'pom 'pom-tint) x "38" (tc 0))
 (rgb x) [(x // 65536) (x // 256 % 256) (x % 256)]
 (pal a) (: (go l t) (? (atom? l) t (go (drop 2 l) (pin t (<l 0) (l 1)))) (go (a 'pal) {}))
 (grid a) (: p (pal a) (map (r \ map (x \ x = 46 ? () (p x)) (map r ^#r)) (a 'px)))
 (avatars _)
  (map (a \ pin a 'grid (grid a))
   [{'name "bunny" 'pal ["W" 0xffffff "P" 0xffafd7 "E" 0x303030 "N" 0xff5faf]
     'px [".WPW.WPW" ".WPW.WPW" "..WEWEW." ".WWWNWWW" ".WWWWWWW" ".WWWWWWW" "..WW.WW." "........"]}
    {'name "bee" 'pal ["W" 0xafd7ff "Y" 0xffd700 "K" 0x875f00 "E" 0xffffff "G" 0x808080]
     'px ["...W..W." "..W.WW.W" "..YKYKYE" ".GYKYKYE" "..YKYKY." "........" "...G.G.." "........"]}
    {'name "baby" 'ink "P" 'pal ["W" 0xeeeeee "C" 0xffd7af "E" 0x303030 "P" 0xffafaf]
     'px ["....WWW." "..WWCWWW" ".WWWCCWW" "WWECWWWW" "PCWWWWWW" ".WWWWWWW" "..WWWWW." "..P...P."]}
    {'name "hare" 'pal ["B" 0x5b6ee1]
     'px [".B....B." ".BB..BB." ".BB..BB." "..BBBB.." ".B.BB.B." ".B.BB.B." "..BBBB.." "...BB..."]}
    {'name "honeybee" 'pal ["K" 0x222034 "Y" 0xfbf236 "C" 0x5fcde4 "G" 0x696a6a "H" 0x595652]
     'px ["...GG..." "..GKKG.." "..HYYH.." ".CCCCCC." ".CYYYYC." "..KKKK.." "..HYYH.." "...KK..."]}
    {'name "beeface" 'pal ["K" 0x222034 "Y" 0xfbf236 "M" 0x45283c "B" 0x5b6ee1 "W" 0xffffff
                           "G" 0x847e87 "H" 0x696a6a "D" 0x595652 "R" 0x663931 "L" 0x639bff]
     'px [".K....K." "..K..K.." "..K..K.." ".KWMMWK." ".GHKKHG." "BMDRRDMB" "LBYYYYBL" "Y......Y"]}]
   + [{'name "moon" 'ink "L" 'pal ["L" (cite 'pom 'pom-lit)]
       'grid ((cite 'pom 'pom-pixels) ((cite 'pom 'pom-now) 0) 8)}])
 (avatar-names _) (map (a \ a 'name) (avatars 0))
 (avatar-of nm) (: l (filter (a \ a 'name = nm) (avatars 0)) (two? l ? <l ()))
 (draw a) ((cite 'pom 'pom-cells) (a 'grid) (tc 0))
 ; the accent: the most-used vivid colour, else the most-used of any; a tie to the stronger
 (ink-of a)
  (: k (peep a 'ink ())
     n (foldl (\ t x (pin t x (peep t x 0 + 1))) {} (catmap (r \ filter charm? r) (a 'grid)))
     (strength x) (: c (rgb x) (foldl max 0 c - foldl min 255 c))
     (vivid? x) (: hi (foldl max 0 (rgb x)) (90 <= hi && hi <= 4 * strength x))
     cs (map (x \ [(n x) (strength x) x]) (keys n))
     vs (filter (e \ vivid? (e 2)) cs)
     (string? k ? ((pal a) (k 0)) (<(rev (sort (two? vs ? vs cs))) 2)))
 (avatar-look nm)
  (: a (avatar-of nm)
     (? (tablet? a) (: k (ink-of a) {'name nm 'face (draw a) 'ink (tint k) 'pen ((cite 'pom 'pom-xterm) k)})))
 (avatar-gallery w nm)
  (: per (max 1 ((w - 2) // 11))
     (go l) (? (atom? l) ()
               (: row (take per l) fs (map draw row)
                  ((map (i \ foldl (\ s f (s + "  " + f i + " ")) "" fs) ^4)
                   + [(foldl (\ s a (s + "  " + sgr ((a 'name = nm ? "1;" "") + tint (ink-of a))
                                                     (edfit (a 'name) 9 " "))) "" row)]
                   + go (drop per l))))
     (go (avatars 0))))
) ; module avatar
