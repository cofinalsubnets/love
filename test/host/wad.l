; test/host/wad.l -- lore's wad: a wad laid here, a room 256 square under the sky with a barrel
; in it, read, walked and drawn. run: cat test/00-init.l test/host/wad.l | out/love
(borrow 'wad)
(borrow 'bytes)
(: (wad-t-w16 v) (wrle (v < 0 ? (v + 65536) v) 2)
   (wad-t-name s) (s + zbytes (8 - #s))
   (wad-t-cat l) (foldl (\ a s (a + s)) "" l)
   ; ..a patch w by h of one colour, each column a single post
   (wad-t-patch w h c lo to) (: col (wad-t-cat [(string 0) (string h) (string 0) (wad-t-cat (map (_ \ string c) ^h)) (string 0) (string 255)])
     (wad-t-cat [(wad-t-w16 w) (wad-t-w16 h) (wad-t-w16 lo) (wad-t-w16 to)
                 (wad-t-cat (map (k \ wrle (8 + 4 * w + k * #col) 4) ^w)) (wad-t-cat (map (_ \ col) ^w))]))
   (wad-t-tex nm w h) (wad-t-cat [(wad-t-name nm) (wrle 0 4) (wad-t-w16 w) (wad-t-w16 h) (wrle 0 4) (wad-t-w16 1)
                                  (wad-t-w16 0) (wad-t-w16 0) (wad-t-w16 (nm = "WALL" ? 0 1)) (wad-t-w16 1) (wad-t-w16 0)])
   ; ..gray but four: 10 red, 20 blue, 30 green, 40 yellow
   wad-t-pal (wad-t-cat (map (i \ (i @ 10 "\xc8\x1e\x1e" 20 "\x1e\x1e\xc8" 30 "\x1e\xc8\x1e" 40 "\xdc\xdc\x28"
                                     _ (wad-t-cat [(string i) (string i) (string i)])))
                             ^256))
   wad-t-t1 (: a (wad-t-tex "WALL" 64 64) b (wad-t-tex "SKY1" 256 128)
              (wad-t-cat [(wrle 2 4) (wrle 12 4) (wrle (12 + #a) 4) a b]))
   ; ..the room: four walls, each its right side in, one sector, one subsector, no nodes
   vs [[0 0] [0 256] [256 256] [256 0]]
   wad-t-map [["THINGS" (wad-t-cat (map (t \ wad-t-cat (map wad-t-w16 t)) [[128 64 90 1 7] [128 192 0 2035 7]]))]
              ["LINEDEFS" (wad-t-cat (map (i \ wad-t-cat (map wad-t-w16 [i ((i + 1) % 4) 1 0 0 i 65535])) ^4))]
              ["SIDEDEFS" (wad-t-cat (map (_ \ wad-t-cat [(wad-t-w16 0) (wad-t-w16 0) (wad-t-name "-") (wad-t-name "-") (wad-t-name "WALL") (wad-t-w16 0)]) ^4))]
              ["VERTEXES" (wad-t-cat (map (v \ wad-t-w16 (v 0) + wad-t-w16 (v 1)) vs))]
              ["SEGS" (wad-t-cat (map (i \ wad-t-cat (map wad-t-w16 [i ((i + 1) % 4) 0 i 0 0])) ^4))]
              ["SSECTORS" (wad-t-w16 4 + wad-t-w16 0)]
              ["NODES" ""]
              ["SECTORS" (wad-t-cat [(wad-t-w16 0) (wad-t-w16 128) (wad-t-name "FLR") (wad-t-name "F_SKY1") (wad-t-w16 255) (wad-t-w16 0) (wad-t-w16 0)])]
              ["REJECT" ""] ["BLOCKMAP" ""]]
   lumps ([["PLAYPAL" wad-t-pal] ["PNAMES" (wrle 2 4 + wad-t-name "WALLP" + wad-t-name "SKYP")] ["TEXTURE1" wad-t-t1]
           ["WALLP" (wad-t-patch 64 64 10 0 0)] ["SKYP" (wad-t-patch 256 128 20 0 0)]
           ["F_START" ""] ["FLR" (wad-t-cat (map (_ \ string 30) ^4096))] ["F_END" ""]
           ["S_START" ""] ["BAR1A0" (wad-t-patch 16 32 40 8 32)] ["S_END" ""] ["E1M1" ""]] + wad-t-map)
   ; ..laid: the header, the lumps, then the directory
   offs (rev (foldl (\ a l ((<a + #(l 1)) . a)) [12] lumps))
   body (wad-t-cat (map (l \ l 1) lumps))
   dir (wad-t-cat (map (i \ wrle (offs i) 4 + wrle #(lumps i 1) 4 + wad-t-name (lumps i 0)) ^#lumps))
   path ("out/.wad-room-" + show (getpid 0) + ".wad")
   _ (open path "w" @ p (say p ("PWAD" + wrle #lumps 4 + wrle (12 + #body) 4 + body + dir), close p))

   ; read: the lumps and the map
   wd (wad-read path)
   _ (test (#(wd 'ls) = #lumps) (wad-read "out/.no-such.wad" = ()))
   M (wad-map wd "E1M1")
   _ (test (#(M 'vs) = 4) (#(M 'lines) = 4) (#(M 'secs) = 1) (#(M 'things) = 2) (wad-map wd "E9M9" = ()))
   _ (test (wad-sector M 128.0 128.0 = 0))
   ; ..a node that names itself, as a damaged wad may: an answer, not a loop
   _ (test (wad-sector (pins (wad-map wd "E1M1") 'nodes [[0.0 0.0 1.0 0.0 0 0]]) 9.0 9.0 = 0))

   ; the start: the player's thing, the eye 41 over the floor, facing north (lore's z)
   st (pins (wad-new 64 40 wd M) 'w 64 'h 40 'kp 1)
   _ (test (st 'px = 128.0) (st 'pz = 64.0) (st 'py = 41.0) (st 'th = 0.0))

   ; drawn: the barrel ahead in the middle, the red wall beside it, the sky above, the floor below
   f (wad-pens st)
   (px x y) (peep f (y * 64 + x) -1)
   (rgb c) [((c >> 16) & 255) ((c >> 8) & 255) (c & 255)]
   (most c k) (: v (rgb c) (all (j \ j = k || v j < v k) ^3))
   _ (test (#f = 64 * 40) (aall (f != -1)))
   _ (test (: v (rgb (px 32 26)) (v 0 > 100 && v 1 > 100 && v 2 < 100)))   ; the barrel, yellow
   _ (test (most (px 8 20) 0))                                    ; the wall, red
   _ (test (px 32 0 = 1973960))                                   ; the sky's own blue, 0x1e1ec8, unlit
   _ (test (most (px 32 39) 1))                                   ; the floor, green

   ; walked: free in the room, not at the wall, and a walk north stops short of it
   _ (test (wad-free? st 128.0 128.0) !(wad-free? st 128.0 250.0) !(wad-free? st 4.0 128.0))
   s (foldl (\ s _ (wad-step s 'forward)) (pin st 'dt 0.25) ^40)
   ((test (s 'pz > 200.0) (s 'pz < 241.0) (s 'px = 128.0)),
    unlink path,
    test_fin (),
    puts "wad: ok\n"))
