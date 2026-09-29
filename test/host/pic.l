; --- test/host/pic.l: kore's pictures (apps/kore/pic.l) and the gif decoder under them -----
; a two-frame gif assembled by hand read back frame by frame; each kind sniffed, sized and
; drawn; sixel and kitty's graphics read back off a quay screen, and quay's answers to the
; probe; pic and its verbs run as commands; picless stepped through its keys, the screen
; left out. where magick is here, gifs of each disposal held to its coalesced frames.
;   cat test/00-init.l test/host/pic.l | out/love
(borrow 'posix)
(: K (cite 'kore)
   kind (K 'pic-kind) size (K 'pic-size) dec (K 'pic-decode) frames (K 'pic-frames)
   art (K 'pic-art) view (K 'pic-view)
   pnew (K 'pv-new) pstep (K 'pv-step) pframe (K 'pv-frame) ptick (K 'pv-tick) pkeys (K 'pv-keys)
   dir ((cwd 0) + "/out/.pic")
   love ((cwd 0) + "/out/love")
   _ (hark ["rm" "-rf" dir]) _ (mkdir dir 448)
   (put p s) (: q (open p "w") _ (say q s) (close q))
   (bytes l) (foldl (\ a b (a + string b)) "" l)
   (has s p) (0 <= (K 'wg-find) s p 0)
   red [255 0 0 255] blue [0 0 255 255]

   ; -- two frames by hand: 2x1, red blue then blue red, 100 and 200 ms ----------------
   ; clear 4, the two indices, end 5, three bits a code, lsb first
   anim ("GIF89a" + bytes ([2 0 1 0 128 0 0 255 0 0 0 0 255]
                + [33 249 4 0 10 0 0 0] + [44 0 0 0 0 2 0 1 0 0 2 2 68 10 0]
                + [33 249 4 0 20 0 0 0] + [44 0 0 0 0 2 0 1 0 0 2 2 12 10 0] + [59]))
   fr (frames anim)
   _ (test (kind anim = 'gif) (size anim = [2 1]) (two? fr) (#(fr 2) = 2)
           (fr 2 0 1 = 100) (fr 2 1 1 = 200)
           (fr 2 0 0 = bytes (red + blue)) (fr 2 1 0 = bytes (blue + red))
           (dec anim = [2 1 (bytes (red + blue))]))
   ; a stream cut inside the second image draws what came, over the first
   cut (frames (snip anim 0 (#anim - 3)))
   _ (test (#(cut 2) = 2) (cut 2 1 0 = bytes (blue + blue))
           (#(frames (snip anim 0 40) 2) = 1)
           (frames "GIF8" = "not a picture") (dec "hello" = "not a picture"))

   ; -- each kind, and its drawing ------------------------------------------------------
   (image w h f)
    (: c (cask (4 * w * h))
       _ (map (i \ (: p (f (i % w) (i // w)) o (4 * i)
                      (pins c o (p 0) (o + 1) (p 1) (o + 2) (p 2) (o + 3) (p 3))))
              (jot (w * h)))
       (string c))
   px (image 16 12 (\ x y (? (x < 8) [0 0 200 255] [200 100 0 255])))
   jp (jpeg-encode 16 12 px 95)
   gf (cite 'gif 'gif-encode 16 12 px)
   _ (test (kind jp = 'jpeg) (size jp = [16 12]) (kind gf = 'gif) (size gf = [16 12])
           (kind "\x89PNG\r\n\x1a\nxxxxxxxxxxxxxxxx" = 'png) (kind "hi" = ()))
   im (dec gf)
   _ (test (two? im) (im 2 = px))
   ; 8 cells wide halves it: 8 columns of cells, 3 rows (6 pixels); 40 wide never enlarges
   a8 (art im 8 () 1) a40 (art im 40 () 1)
   _ (test (#a8 = 3) (#a40 = 6)
           (has (a8 0) "\e[38;2;0;0;200m\e[48;2;0;0;200m▀") (has (a8 0) "38;2;200;100;0")
           ; a row ends back at the plain colours
           (has (a8 2) "▀\e[0m"))
   ; the 256-colour cube when not deep
   _ (test (has (art im 8 () 0 0) "\e[38;5;"))
   ; a see-through picture draws blank cells
   clear (art [2 2 (bytes [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0])] 4 () 1)
   _ (test (clear = ["\e[0m \e[0m \e[0m"]))
   ; rows caps the height: 16x12 in 2 rows is 16 by 4 pixels at most, scale 3
   _ (test (#(art im 80 2 1) = 2))

   ; -- sixel and kitty's, through quay ---------------------------------------------------
   ; a picture's pixels as a quay screen of 8x16 cells holds them, clear 0
   (mkscr r c) (screen (cask (screen () r c)) r c)
   (shot im t) (: s (mkscr 4 10) _ (scribe s t) w (im 0)
                  (map (i \ (: x (i % w) y (i // w) (tilepx s (((y // 16) * 10) + (x // 8)) (x % 8) (y % 16))))
                       (jot (w * (im 1)))))
   (argb im) (map (i \ (: o (4 * i) p (im 2)
                          (? (p (o + 3) < 128) 0 ((((255 << 24) | (p o << 16)) | (p (o + 1) << 8)) | p (o + 2)))))
                  (jot ((im 0) * (im 1))))
   six (K 'pic-sixel) kit (K 'pic-kitty)
   ; sixel's colours are whole percents, so a channel may move by 2; clear stays clear
   (near a b)
    (: (ch v k) ((v >> k) & 255)
       (px1 u v) (? ((u = 0) || (v = 0)) (u = v)
                    (foldl (\ ok k (ok && (abs (ch u k - ch v k) <= 2))) 1 [0 8 16 24]))
       ((#a = #b) && (foldl (\ ok i (ok && px1 (a i) (b i))) 1 (jot #a))))
   ; clear columns and a clear row, 104 colours: within sixel's palette whole
   cut (: c (cask (4 * 30 * 20))
          _ (map (i \ (: x (i % 30) y (i // 30) o (4 * i)
                         (? ((x < 4) || (y = 7)) 0 (pins c o (x * 8) (o + 1) ((y % 4) * 60) (o + 2) 90 (o + 3) 255))))
                 (jot 600))
          [30 20 (string c)])
   _ (test (shot im (kit im) = argb im) (shot cut (kit cut) = argb cut)
           (near (shot im (six im)) (argb im)) (near (shot cut (six cut)) (argb cut))
           !(shot im (six im) = argb im)
           (snip (six im) 0 3 = "\ePq" || snip (six im) 0 8 = "\eP0;1;0q")
           ; a big picture goes in chunks of 4096, the last m=0
           (: k (kit [64 64 (string (cask (4 * 64 * 64)))])
              ((has k "m=1;") && (has k "\e_Gm=0;") && !(has k "\e_Gm=1;\e"))))
   ; the probe: quay says it takes both, and its cell
   heard (K 'pic-heard (string (reply (scribe (mkscr 4 10) (K 'pic-ask)))))
   _ (: h heard (test (h 'kitty) (h 'sixel) (h 'cw = 8) (h 'ch = 16)))
   _ (: h (K 'pic-heard "") (test !(h 'kitty) !(h 'sixel) (h 'cw = 0)))
   _ (: h (K 'pic-heard "\e[6;20;10t\e[?62;22c") (test !(h 'kitty) !(h 'sixel) (h 'cw = 10) (h 'ch = 20)))

   ; -- pic as a command ----------------------------------------------------------------
   _ (put (dir + "/a.gif") gf) _ (put (dir + "/b.jpg") jp) _ (put (dir + "/n.txt") "hello")
   _ (put (dir + "/anim.gif") anim)
   r1 (hark [love "kore" "pic" "-w" "8" (dir + "/a.gif")])
   r2 (hark [love "kore" "jpegcat" "-w" "8" (dir + "/a.gif") (dir + "/b.jpg")])
   r3 (hark [love "kore" "pic" "cat" (dir + "/n.txt") (dir + "/none.png")])
   _ (test (<r1 = 0) (has >r1 "▀") !(has >r1 "a.gif")
           (<r2 = 0) (has >r2 "a.gif:\n") (has >r2 "b.jpg:\n")
           (<r3 = 1))
   (pic as) (hark ([love "kore" "pic"] + as))
   ; a bare pic sniffs: a picture is drawn, anything else is a document for classic pic
   ; (apps/kore/gpic.l), and a flag says which outright
   _ (put (dir + "/d.ms") ".PS\nbox\n.PE\ntext\n")
   _ (test (: r (pic [(dir + "/a.gif")]) ((<r = 0) && (has >r "▀")))
           (: r (pic [(dir + "/n.txt")]) ((<r = 0) && (has >r ".do if !dPS") && (has >r "\nhello\n")))
           (: r (pic [(dir + "/d.ms")]) ((<r = 0) && (has >r "\\D'p 0.000i -0.500i -0.750i") && (has >r ".PE\n.lf 4\ntext\n")))
           (: r (pic ["-t" (dir + "/d.ms")]) ((<r = 0) && (has >r "\\special{pa 750 500}%")))
           (: r (pic ["-n" (dir + "/d.ms")]) ((<r = 0) && (has >r "\\D'l 0.750i 0.000i'")))
           (: r (pic ["-w" "8" (dir + "/n.txt")]) (<r = 1))
           (: r (pic [(dir + "/n.txt") (dir + "/none.png")]) (<r = 3)))
   (file p) (: r (uread p) (? (two? r) <>r ""))
   ; the verbs; cat is the default, and a mode is said, not probed, off a terminal
   _ (test (pic ["cat" "-w" "8" (dir + "/a.gif")] = r1)
           (: r (pic ["-g" "sixel" (dir + "/a.gif")]) ((<r = 0) && (snip >r 0 2 = "\eP")))
           (: r (pic ["cat" "-g" "kitty" (dir + "/a.gif")]) ((<r = 0) && (snip >r 0 3 = "\e_G")))
           (<(pic ["-g" "neon" (dir + "/a.gif")]) = 2)
           (: r (pic ["help"]) ((<r = 0) && has >r "pic convert")))
   ; convert: by extension or -t, a file already its type copied as it is
   _ (test (<(pic ["convert" (dir + "/a.gif") (dir + "/c.png")]) = 0)
           (dec (file (dir + "/c.png")) = im)
           (<(pic ["convert" (dir + "/c.png") (dir + "/c.gif")]) = 0)
           (dec (file (dir + "/c.gif")) = im)
           (<(pic ["convert" (dir + "/anim.gif") (dir + "/d.gif")]) = 0)
           (file (dir + "/d.gif") = anim)
           (<(pic ["convert" "-t" "jpg" (dir + "/c.png") (dir + "/c.out")]) = 0)
           (kind (file (dir + "/c.out")) = 'jpeg)
           (: r (pic ["convert" "-t" "sixel" (dir + "/c.png") "-"]) ((<r = 0) && near (shot im >r) (argb im)))
           (<(pic ["convert" (dir + "/c.png") (dir + "/c.bmp")]) = 2)
           (<(pic ["convert" (dir + "/n.txt") (dir + "/n.png")]) = 1)
           (<(pic ["convert" (dir + "/c.png")]) = 2))
   ; pixelize: 16x12 at 8 cells is 8x6 pixels, each s pixels square; the cube's levels
   ; with -c 256, and an odd last row's lower half clear
   pz (dir + "/z.png")
   _ (test (<(pic ["pixelize" "-w" "8" "-s" "3" (dir + "/a.gif") pz]) = 0)
           (: z (dec (file pz)) ((z 0 = 24) && (z 1 = 18) && (snip (z 2) 0 4 = "\0\0\xc8\xff")
                                 && (snip (z 2) (4 * 23) (4 * 24) = "\xc8d\0\xff")))
           (<(pic ["pixelize" "-w" "8" "-c" "256" (dir + "/a.gif") pz]) = 0)
           ; the default scale is the source's: 2 source pixels to each
           (: z (dec (file pz)) ((z 0 = 16) && (z 1 = 12) && (snip (z 2) 0 4 = "\0\0\xd7\xff")))
           (<(pic ["pixelize" "-w" "5" "-s" "1" (dir + "/a.gif") pz]) = 0)
           ; 16x12 at 5 cells: 5 wide and 3 high, 4 once the last cell's lower half is kept
           (: z (dec (file pz)) ((z 0 = 5) && (z 1 = 4) && (z 2 (4 * 15 + 3) = 0) && (z 2 (4 * 10 + 3) = 255)))
           (<(pic ["pixelize" "-c" "7" (dir + "/a.gif") pz]) = 2)
           ; the cube's colours are few, so a palette: colour type 3
           (<(pic ["pixelize" "-w" "8" "-c" "256" (dir + "/b.jpg") pz]) = 0)
           (file pz 25 = 3))
   ; the blocks as text: .ans is pic cat's own lines, truecolor unless -c 256
   ans (K 'pic-ans im 8 () 1)
   _ (test (ans = cats (map (r \ r + "\n") (art im 8 () 1)))
           (<(pic ["pixelize" "-w" "8" (dir + "/a.gif") (dir + "/a.ans")]) = 0)
           (file (dir + "/a.ans") = ans)
           (<(pic ["pixelize" "-w" "8" "-c" "256" "-t" "ans" (dir + "/a.gif") "-"]) = 0)
           (: r (pic ["pixelize" "-w" "8" "-c" "256" "-t" "ans" (dir + "/a.gif") "-"]) (has >r "38;5;"))
           (<(pic ["convert" (dir + "/a.gif") (dir + "/c.ans")]) = 0)
           (file (dir + "/c.ans") = (K 'pic-ans) im 80 () 1))

   ; -- picless, its keys -----------------------------------------------------------------
   st (pnew [(dir + "/anim.gif") (dir + "/a.gif") (dir + "/n.txt")] 12 200)
   s0 (pframe st)
   _ (test (has s0 "anim.gif  [1/3]  2x1") (has s0 "frame 1/2") !(has s0 "paused")
           ; a 2x1 picture fits at its size, never enlarged: 100%, in the middle of the screen
           (has s0 "100%"))
   ; the clock: the first tick sets the due time, a tick past it moves the frame on
   _ (test (ptick st 1000 = 0) (ptick st 1050 = 0) (ptick st 1100 = 1) (st 'f = 1)
           (has (pframe st) "frame 2/2"))
   _ (pstep st 32)
   _ (test !(st 'play) (has (pframe st) "(paused)") (ptick st 99999 = 0))
   _ (pstep st 46)
   _ (test (st 'f = 0))
   _ (pstep st 44)
   _ (test (st 'f = 1))
   ; zoom in doubles past the fit and back; 0 fits again
   _ (pstep st 43)
   _ (test (has (pframe st) "150%"))
   _ (pstep st 48)
   _ (test (has (pframe st) "100%"))
   ; n to the next file, p back; a file that is no picture says so
   _ (pstep st 110)
   _ (test (st 'i = 1) (has (pframe st) "a.gif  [2/3]  16x12"))
   _ (pstep st 110)
   _ (test (has (pframe st) "n.txt: not a picture"))
   _ (pstep st 112)
   _ (test (st 'i = 1))
   ; panning a picture zoomed past the screen moves the view and stops at the edge
   _ (map (c \ pstep st c) [43 43 43 43 43 43])
   c0 (st 'cx)
   _ (pstep st 108)
   _ (test (c0 < st 'cx))
   _ (map (c \ pstep st c) [104 104 104 104 104 104 104 104 104 104])
   _ (: v (K 'pv-view st) (test (v 1 = 0)))
   ; the arrows arrive as their escapes
   _ (test (pkeys "\e[A\e[Bq\e[C\e[D" = [107 106 113 108 104]))
   _ (pstep st 63)
   _ (test (has (pframe st) "q quit"))
   _ (pstep st 113)
   _ (test (st 'quit))

   ; -- picless in sixel and kitty's: the screen it writes, read back off quay ------------
   ; a 16x12 picture on 6 rows of 30 cells of 8x16 fits at its size, centred: 14 cells over
   ; (30 less its 2, halved) and 2 rows down (5 rows less its 1, halved)
   (pv-in mode)
    (: q (pnew [(dir + "/a.gif")] 6 30) _ (pins q 'mode mode 'ux 8 'uy 16) q)
   (seen q) (: s (mkscr 6 30) _ (scribe s (pframe q))
               (map (i \ (: x (i % 16) y (i // 16)
                             (tilepx s ((((y // 16) + 2) * 30) + ((x // 8) + 14)) (x % 8) (y % 16))))
                    (jot 192)))
   gq (pv-in "sixel") kq (pv-in "kitty")
   _ (test (has (pframe gq) "16x12  100%") (has (pframe gq) "\e[3;15H\eP")
           (near (seen gq) (argb im)) (seen kq = argb im)
           (has (pframe kq) "\e_Ga=d,d=a,q=2\e\\") (has (pframe kq) "C=1,"))
   ; zoomed past the screen, a pixel is s screen pixels wide and panning moves by them
   _ (map (c \ pstep gq c) [43 43 43 43 43 43 43])
   gx (gq 'cx)
   _ (pstep gq 108)
   _ (test (has (pframe gq) "1709%") (gx < gq 'cx)
           ; a sixel is whole bands: 5 rows of 16 is 80 pixels, 78 of them drawn
           (: v (K 'pv-view gq) (v 4 = 78)))
   ; the default is blocks, and off a terminal the viewer says so
   _ (test (<(hark [love "kore" "pic" "less" (dir + "/a.gif")]) = 2)
           (<(hark [love "kore" "pic" "less" "-g" "neon" (dir + "/a.gif")]) = 2))

   ; -- markdown and html2text on a terminal: a local picture under its image's line ------
   _ (put (dir + "/sub.gif") gf)
   md (cite 'lapiz 'mdread "# t\n\nsee ![it](sub.gif) here\n\n![gone](nope.png) and ![w](http://x/y.png)\n")
   lp (K 'lens-pics md 40 (dir + "/doc.md"))
   ll (: (go i st acc) (? (#lp <= i) (rev acc) (lp i = 10) (go (i + 1) (i + 1) (snip lp st i . acc)) (go (i + 1) st acc))
         (go 0 0 ()))
   at (: (go i) (? (#ll <= i) -1 (has (ll i) "see [it] here") i (go (i + 1))) (go 0))
   _ (test (0 <= at) (has (ll (at + 1)) "▀") (has (ll (at + 6)) "▀") !(has (ll (at + 7)) "▀")
           ; 16 wide at 40 columns: the picture's own size, set in at the text's margin
           (snip (ll (at + 1)) 0 5 = "     ")
           (#(filter (l \ has l "▀") ll) = 6)
           (has lp "[gone] and [w]"))

   ; -- against magick: every disposal, frame by frame -----------------------------------
   magick? (: q (open "/usr/bin/magick" "r") (? (hot? q) (close q, 1) 0))
   (coalesced f) (: r (hark ["magick" f "-coalesce" "-depth" "8" "rgba:-"]) (? ((two? r) && (<r = 0)) >r ()))
   ; pixels that differ in whether they are seen, or in colour where both are
   (off a b) (: n (#a // 4)
                (go i bad) (? (i = n) bad
                              (: o (4 * i) sa (127 < a (o + 3)) sb (127 < b (o + 3))
                                 (go (i + 1) (? (sa != sb) (bad + 1)
                                                (sa && (snip a o (o + 3) != snip b o (o + 3))) (bad + 1)
                                                bad))))
                (go 0 0))
   (anim-of d)
    (: f (dir + "/d" + d + ".gif")
       r (hark ["magick" "-size" "30x20" "xc:#303060"
                "(" "-size" "30x20" "xc:none" "-fill" "red" "-draw" "rectangle 2,2 10,10" ")"
                "(" "-size" "30x20" "xc:none" "-fill" "yellow" "-draw" "rectangle 12,5 20,14" ")"
                "(" "-size" "30x20" "xc:none" "-fill" "white" "-draw" "circle 22,10 22,16" ")"
                "-set" "delay" "7" "-dispose" d "-loop" "0" "-layers" "optimize" f])
       q (open f "r") s (slurp q) _ (close q)
       fs (frames s) m (coalesced f)
       ((two? fs) && (string? m) && (#(fs 2) = 4)
        && (off (foldl (\ a x (a + <x)) "" (fs 2)) m = 0)))
   _ (? magick?
        (test (anim-of "None") (anim-of "Background") (anim-of "Previous"))
        (puts "pic: no magick, disposals against it skipped\n"))
   _ (hark ["rm" "-rf" dir])
   0)

(test_fin (), puts "pic: ok", putc 10, 0)
