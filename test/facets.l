; src/love/raster.c's facets: triangles onto a frame. a shared edge is drawn once, the nearer
; face stands whichever comes first, a texture laid a texel a pixel comes back as it was, and
; its level follows how many texels a pixel crosses. the loop holds more each round, so the
; collections the frame asks for move it under the heap (make test_gcstress). frame-bytes
; spells a frame for a window or a terminal
(: (fc-flat l) (foldr (+) () l)
   (fc-g l) (fc-flat l @ f (gem-tray [(tally f)] f))
   (fc-z l) (fc-flat l @ f (star-tray [(tally f)] f))
   fc-id (fc-g [[1.0 0.0 0.0 0.0] [0.0 1.0 0.0 0.0] [0.0 0.0 1.0 0.0] [0.0 0.0 0.0 1.0]])
   ; a vertex: x y z, u v, r g b
   (fc-vx x y z u v r g b) [(1.0 * x) (1.0 * y) (1.0 * z) (1.0 * u) (1.0 * v) (1.0 * r) (1.0 * g) (1.0 * b)]
   (fc-n f c) (net (f = c))
   red 16711680 blue 255
   ; the screen as two halves, red and blue, and the same drawn blue first
   sq (fc-g [(fc-vx -1 -1 0 0 0 1 0 0) (fc-vx 1 -1 0 0 0 1 0 0) (fc-vx 1 1 0 0 0 1 0 0)
             (fc-vx -1 -1 0 0 0 0 0 1) (fc-vx 1 1 0 0 0 0 0 1) (fc-vx -1 1 0 0 0 0 0 1)])
   ab (facets 8 6 7 fc-id sq (fc-z [[0 1 2 -1] [3 4 5 -1]]) () ())
   ba (facets 8 6 7 fc-id sq (fc-z [[3 4 5 -1] [0 1 2 -1]]) () ())
   ; one face over the whole screen, near (z -0.5, blue) and far (z 0.5, red)
   (big z r b) [(fc-vx -1 -1 z 0 0 r 0 b) (fc-vx 3 -1 z 0 0 r 0 b) (fc-vx -1 3 z 0 0 r 0 b)]
   nf (fc-g (big -0.5 0 1 + big 0.5 1 0))
   (deep tris) (facets 4 4 7 fc-id nf (fc-z tris) () ())
   (cull tri fl) (facets 4 4 7 fc-id nf (fc-z [tri]) () (fc-g [[0.0 0.0 0.0 0.0 0.0 fl]]))
   ; a 4x4 texture laid a texel a pixel, perspective and affine; one texel a hole
   tex (star-tray [4 4] (map (k \ 1052688 * k) ^16))
   hol (star-tray [4 4] (map (k \ k = 5 ? -1 (1052688 * k)) ^16))
   (quad s) (fc-g [(fc-vx -1 1 0 0 0 1 1 1) (fc-vx 1 1 0 s 0 1 1 1) (fc-vx 1 -1 0 s s 1 1 1) (fc-vx -1 -1 0 0 s 1 1 1)])
   qt (fc-z [[0 3 2 0] [0 2 1 0]])
   (laid s texs fl) (facets 4 4 7 fc-id (quad s) qt texs (fc-g [[0.0 0.0 0.0 0.0 0.0 fl]]))
   (flat f) (map (k \ peep f [(k // 4) (k % 4)] 0) ^16)
   ; levels: red where a pixel is a texel, green where it crosses four
   lv [[(star-tray [4 4] (map (k \ red) ^16)) (star-tray [2 2] (map (k \ 65280) ^4))]]
   ; a perspective eye 1 above a floor that runs out behind it: cut at the near plane
   pm (fc-g [[1.0 0.0 0.0 0.0] [0.0 1.0 0.0 0.0] [0.0 0.0 -1.002 -0.2002] [0.0 0.0 -1.0 0.0]])
   fl (fc-g [(fc-vx -50 -1 5 0 0 1 0 0) (fc-vx 50 -1 5 0 0 1 0 0) (fc-vx 0 -1 -50 0 0 1 0 0)])
   floor (facets 8 8 7 pm fl (fc-z [[0 1 2 -1]]) () ())
   ; a ramp of red, left to right
   rp (facets 8 1 0 fc-id (fc-g [(fc-vx -1 -1 0 0 0 0 0 0) (fc-vx 1 -1 0 0 0 1 0 0) (fc-vx 1 3 0 0 0 1 0 0)
                                  (fc-vx -1 -1 0 0 0 0 0 0) (fc-vx 1 3 0 0 0 1 0 0) (fc-vx -1 3 0 0 0 0 0 0)])
              (fc-z [[0 1 2 -1] [3 4 5 -1]]) () ())
   ; the two halves as two batches, each counting from its own verts
   bt (facets 8 6 7 fc-id [(fc-g [(fc-vx -1 -1 0 0 0 1 0 0) (fc-vx 1 -1 0 0 0 1 0 0) (fc-vx 1 1 0 0 0 1 0 0)])
                          (fc-g [(fc-vx -1 -1 0 0 0 0 0 1) (fc-vx 1 1 0 0 0 0 0 1) (fc-vx -1 1 0 0 0 0 0 1)])]
                         [(fc-z [[0 1 2 -1]]) (fc-z [[0 1 2 -1]])] () ())
   ; a frame as bytes: rgb, xrgb words, rgb in base64; doubled
   px2 (star-tray [1 2] [1193046 16777215])
   (fc-go k keep bad)
    (k = 0 ? bad
       (facets 64 48 7 fc-id sq (fc-z [[0 1 2 -1] [3 4 5 -1]]) () () @ f
        (fc-go (k - 1) (cask 16384 . keep) (bad + (fc-n f red + fc-n f blue != 3072)))))
   (test
      ([6 8] = shape ab) (fc-n ab 7 = 0) (fc-n ab red + fc-n ab blue = 48) (0 < fc-n ab red)
      (fc-n ab red = fc-n ba red)
      (fc-n (deep [[0 1 2 -1] [3 4 5 -1]]) blue = 16) (fc-n (deep [[3 4 5 -1] [0 1 2 -1]]) blue = 16)
      (fc-n (cull [0 1 2 -1] 8) blue = 16) (fc-n (cull [0 2 1 -1] 8) 7 = 16) (fc-n (cull [0 2 1 -1] 0) blue = 16)
      (flat (laid 4 [tex] 0) = map (k \ 1052688 * k) ^16)
      (flat (laid 4 [tex] 1) = map (k \ 1052688 * k) ^16)
      (peep (laid 4 [hol] 0) [1 1] 0 = 7) (peep (laid 4 [hol] 0) [1 2] 0 = 1052688 * 6)
      (fc-n (laid 4 lv 0) red = 16) (fc-n (laid 16 lv 0) 65280 = 16)
      (fc-n (facets 4 4 7 fc-id nf (fc-z [[0 1 2 -1]]) () (fc-g [[10.0 20.0 30.0 0.0 0.5 0.0]])) 660510 = 16)
      (peep floor [0 3] 0 = 7) (peep floor [7 3] 0 = red) (peep floor [7 0] 0 = red)
      (peep rp [0 0] 0 < peep rp [0 4] 0) (peep rp [0 4] 0 < peep rp [0 7] 0)
      (facets 0 4 7 fc-id sq (fc-z [[0 1 2 -1]]) () () = ())
      (facets 4 4 7 fc-id (fc-g [[1.0 2.0 3.0]]) (fc-z [[0 1 2 -1]]) () () = ())
      (fc-n (facets 4 4 7 fc-id sq (fc-z [[0 1 9 -1]]) () ()) 7 = 16)
      (show bt = show ab)
      (facets 8 6 7 fc-id [sq] [] () () = ())
      (frame-bytes px2 0 1 = "\x12\x34\x56\xff\xff\xff")
      (frame-bytes px2 1 1 = "\x56\x34\x12\x00\xff\xff\xff\x00")
      (frame-bytes px2 2 1 = "EjRW////")
      (frame-bytes px2 0 2 = "\x12\x34\x56\x12\x34\x56\xff\xff\xff\xff\xff\xff\x12\x34\x56\x12\x34\x56\xff\xff\xff\xff\xff\xff")
      (frame-bytes px2 3 1 = ())
      (fc-go 100 () 0 = 0)))
