; --- test/host/pic.l: kore's pictures (apps/kore/pic.l) and the gif decoder under them -----
; a two-frame gif assembled by hand read back frame by frame; each kind sniffed, sized and
; drawn; pic run as a command; picless stepped through its keys, the screen left out. where
; magick is here, gifs of each disposal held to its coalesced frames.
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
           ((fr 2) 0 1 = 100) ((fr 2) 1 1 = 200)
           ((fr 2) 0 0 = bytes (red + blue)) ((fr 2) 1 0 = bytes (blue + red))
           (dec anim = [2 1 (bytes (red + blue))]))
   ; a stream cut inside the second image draws what came, over the first
   cut (frames (snip anim 0 (#anim - 3)))
   _ (test (#(cut 2) = 2) ((cut 2) 1 0 = bytes (blue + blue))
           (#((frames (snip anim 0 40)) 2) = 1)
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
   gf ((cite 'gif 'gif-encode) 16 12 px)
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
   _ (test (has ((art im 8 () 0) 0) "\e[38;5;"))
   ; a see-through picture draws blank cells
   clear (art [2 2 (bytes [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0])] 4 () 1)
   _ (test (clear = ["\e[0m \e[0m \e[0m"]))
   ; rows caps the height: 16x12 in 2 rows is 16 by 4 pixels at most, scale 3
   _ (test (#(art im 80 2 1) = 2))

   ; -- pic as a command ----------------------------------------------------------------
   _ (put (dir + "/a.gif") gf) _ (put (dir + "/b.jpg") jp) _ (put (dir + "/n.txt") "hello")
   r1 (hark [love "kore" "pic" "-w" "8" (dir + "/a.gif")])
   r2 (hark [love "kore" "jpegcat" "-w" "8" (dir + "/a.gif") (dir + "/b.jpg")])
   r3 (hark [love "kore" "pic" (dir + "/n.txt") (dir + "/none.png")])
   _ (test (<r1 = 0) (has >r1 "▀") !(has >r1 "a.gif")
           (<r2 = 0) (has >r2 "a.gif:\n") (has >r2 "b.jpg:\n")
           (<r3 = 1))

   ; -- picless, its keys -----------------------------------------------------------------
   _ (put (dir + "/anim.gif") anim)
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
   _ (: v ((K 'pv-view) st) (test (v 1 = 0)))
   ; the arrows arrive as their escapes
   _ (test (pkeys "\e[A\e[Bq\e[C\e[D" = [107 106 113 108 104]))
   _ (pstep st 63)
   _ (test (has (pframe st) "q quit"))
   _ (pstep st 113)
   _ (test (st 'quit))

   ; -- markdown and html2text on a terminal: a local picture under its image's line ------
   _ (put (dir + "/sub.gif") gf)
   md ((cite 'lapiz 'mdread) "# t\n\nsee ![it](sub.gif) here\n\n![gone](nope.png) and ![w](http://x/y.png)\n")
   lp ((K 'lens-pics) md 40 (dir + "/doc.md"))
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
