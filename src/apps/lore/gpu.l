; gpu -- frames on the system's gpu, drawn by glhelp (glhelp.c), a process of its own that
; loads the system's gles through dlopen. built once and kept in the nest's cache, keyed by its
; source: by mooncc, an executable naming the system's loader, else by the
; system's cc. LOVE_GPU_CC picks one, moon or cc. the bulk rides a tmpfs file both hold, a
; line each way says what to do with it.
;   (gpu-open x)                 a helper, or a nom with why: 'no-helper 'no-gpu; with x, one
;                                that can show on an X window
;   (gpu-win g xid)              the X window it shows on, () where it can
;   (gpu-show g f w h W H at ys P) the picture f w by h shown over the window W by H at [x y],
;                                then rows ys [y0 y1] of the paper P laid on it as they are
;   (gpu-tex g id w h t)         texture id, w by h: a tray of 0x00rrggbb (below 0 a hole), rows
;                                top first, or a list of them, each level half the last
;   (gpu-buf g id verts tris st) buf id: facets's verts (st numbers a vertex, 8, or 11 with the
;                                sun's r g b) and tris (4 a triangle, a texture's id, -1 none,
;                                -2 a glow, -3 - t a glass of t), flat trays
;   (gpu-verts g id verts st)    buf id's verts laid again, as many and as wide, its tris kept
;   (gpu-sun g sv sd bias)       the sun's view kept: its matrix sv and depths sd, facets's
;   (gpu-drop g id)
;   (gpu-base g w h t)           the next frame's ground, w*h colours, below 0 bare
;   (gpu-under g cs ds)          the next frame laid first with a smaller one's colours cs and
;                                depths ds, facets's [ground cs ds]
;   (gpu-frame g w h mat ids o)  the bufs ids through mat (16 numbers, row-major, gl's clip
;                                box), o [clear fr fg fb near far tone flags]: a tray of w*h
;                                of facets's words, rows top first; clear the ground, below 0
;                                bare; flags facets's 8, cull, 128, seen, and 256, the sun's view
;   (gpu-send g w h mat ids o)   the same frame begun, the helper drawing it while the caller
;   (gpu-take g w h)             goes on, and then its tray
;   (gpu-close g)
; each answers () where it worked, else the helper's words, but gpu-frame and gpu-take
;   (gpu-facets s w h base mat verts tris texs opts ks sk c)  facets's answer with flags 64,
;                                from the helper in s (gpu-state's), or () where facets must
;                                draw it:
;                                a base not a colour, -1 or w*h colours, nor such a ground
;                                under a smaller frame, flags
;                                past 8 64 and 128, or a helper gone. ks names each batch, or
;                                (): one named alike holds alike, so is not summed again, and
;                                one named 'once is laid anew each frame, unsummed, in a slot
;                                of its own. sk [verts tris tone] a sky drawn under what is bare
;                                as facets draws it with flags 96, its pixels bare alone 2^32
;                                more, or ()
;                                with s 'pipe, [f c'] instead: the frame before and its c, this
;                                one drawn meanwhile; after a start or a stop the frame itself,
;                                then it once more
;   (gpu-state g)                s for a helper g: the bufs it holds, each by what it holds
(module (gpu gpu-open gpu-win gpu-show gpu-tex gpu-buf gpu-verts gpu-sun gpu-drop gpu-under gpu-frame gpu-send gpu-take gpu-close gpu-how gpu-state gpu-facets)
(borrow '(posix hashes))
(:
 (dir? p) (stat p @ s (two? s && 16384 = 61440 & <>>s))
 (up p) (#p @ n (: (go i) (i < 0 ? "." (p i = 47 ? (i ? (snip p 0 i) "/") (go (i - 1)))) (go (n - 1))))
 (base p) (#p @ n (: (go i) (i < 0 ? p (p i = 47 ? (snip p (i + 1) n) (go (i - 1)))) (go (n - 1))))
 ; ..the nest's cache: beside bin/ in a nest, else beside the binary (out/ in a checkout)
 (cache-dir _) (: s (selfpath 0) b (up s) r (base b = "bin" ? (up b) b)
                  d (r + "/cache/glhelp")
                  (mkdir (r + "/cache") 493, mkdir d 493, (dir? d ? d ())))
 (source _) (open "/love/src/apps/lore/glhelp.c" "r" @ q
              (hot? q ? (slurp q @ t (close q, t))
                 (open "src/apps/lore/glhelp.c" "r" @ q (hot? q ? (slurp q @ t (close q, t)) ()))))
 (here? p) (two? (stat p))
 ; ..the system loader a mooncc build names: the one the system's own shell names (its
 ; PT_INTERP), else by the machine; and the libraries it names, bionic's or glibc's
 (le t o n) (: (go i a) (i < 0 ? a (go (i - 1) (a * 256 + peep t (o + i) 0))) (go (n - 1) 0))
 (elf-interp t) (? !(string? t && 64 <= #t && snip t 0 4 = "\x7fELF" && t 5 = 1) ()
                   (: w (t 4 = 2) at (le t (w ? 32 28) (w ? 8 4)) sz (le t (w ? 54 42) 2) k (le t (w ? 56 44) 2)
                      (go i) (i >= k ? ()
                               (: h (at + i * sz) off (le t (h + (w ? 8 4)) (w ? 8 4)) len (le t (h + (w ? 32 16)) (w ? 8 4))
                                  (le t h 4 = 3 && 1 < len && off + len <= #t ? (snip t off (off + len - 1)) (go (i + 1)))))
                      (go 0)))
 (interp f) (open f "r" @ q (hot? q ? (slurp q @ t (close q, elf-interp t)) ()))
 (shell-loader _) (: (go l) (atom? l ? () (interp <l @ p (string? p && here? p ? p (go >l)))) (go ["/system/bin/sh" "/bin/sh"]))
 (loader m) (shell-loader () @ p (string? p ? p
              (m @ "x86_64" "/lib64/ld-linux-x86-64.so.2" "aarch64" "/lib/ld-linux-aarch64.so.1"
                   "riscv64" "/lib/ld-linux-riscv64-lp64d.so.1" ())))
 (droid? ld) (string? ld && 18 <= #ld && snip ld 0 18 = "/system/bin/linker")
 (libs ld) (droid? ld ? ["-l:libc.so" "-l:libdl.so"] ["-l:libc.so.6"])
 (run argv) (: p (spawnio argv -1 -1 -1 () -1 0) (charm? p && 0 <= p ? (wait p) -1))
 ; ..argv to start the helper, built if the cache lacks it: mooncc first unless told
 (helper-argv _)
  (: src (source ()) d (cache-dir ()) m (uname 0 @ u (two? u ? (u 4) ""))
     how (getenv "LOVE_GPU_CC" @ () 'any "moon" 'moon "cc" 'cc w (scare 'gpu-cc w))
     (? !(string? src) 'no-source !(string? d) 'no-cache
        (: key (snip (sha256 (src + m)) 0 12) cf (d + "/glhelp-" + key + ".c")
           mb (d + "/glhelp-" + key + ".moon") cb (d + "/glhelp-" + key + ".cc") ld (loader m)
           ; ..each made under a name of its own and moved into place: shards build at once
           tmp ("." + show (getpid 0))
           _ (here? cf ? 0 (open (cf + tmp) "w" @ q (say q src, close q, rename (cf + tmp) cf)))
           (made f argv) (here? f || (0 = run (argv (f + tmp)) && !(rename (f + tmp) f)))
           (moon? _) (how != 'cc && string? ld && here? ld
                      && made mb (o \ ([(selfpath 0) "cc" "-O2" "-dynamic-linker" ld "-o" o cf] + libs ld)))
           (cc? _) (how != 'moon && made cb (o \ ["cc" "-O2" "-o" o cf]))
           (? (moon? ()) [mb] (cc? ()) [cb] 'no-compiler))))
 ; ..a line from the helper, its newline gone; () once it has gone
 (line q) (: (go acc) (see q @ c (c < 0 ? (acc = "" ? () acc) (c = 10 ? acc (go (acc + string [c]))))) (go ""))
 (ask g s) (say (g 'to) (s + "\n"), (line (g 'from) @ () "the helper has gone" "ok" () r r))
 (gpu-how g) (g 'how)
 (gpu-open x)
  (: argv (helper-argv ())
     (? !(two? argv) ['no-helper argv]
        (: sp (dir? "/dev/shm" ? "/dev/shm" (cache-dir ()))
           f (sp + "/glhelp-" + show (getpid 0) + "-" + show (clock 0))
           w (openfd f 1) r (openfd f 0)
           a (pipe 0) b (pipe 0)
           p (spawnio (argv + [f] + (x ? ["x"] ())) <a >b -1 [>a <b] -1 0)
           _ (close <a) _ (close >b)
           q (fdopen <b)
           hi (line q)
           _ (unlink f)
           (? (string? hi && 6 < #hi && snip hi 0 6 = "ready ")
              {'to >a 'from q 'pid p 'w w 'r r 'room 0 'how (snip hi 6 #hi) 'argv argv}
              (close >a, close q, close w, close r, (charm? p ? (wait p) 0),
                 ['no-gpu (string? hi ? hi "the helper said nothing")])))))
 (gpu-close g) (say (g 'to) "quit\n", close (g 'to), close (g 'from), close (g 'w), close (g 'r), wait (g 'pid), ())
 ; ..the shared file at least n bytes, once the shows it holds are done with
 (room! g n) (settle g, (g 'room < n ? (truncate (g 'w) n 0, pin g 'room n) g))
 (settle g) (0 < peep g 'shows 0 ? (line (g 'from), pin g 'shows (g 'shows - 1), settle g) g)
 (put! g c) (room! g #c, fdpush (g 'w) c 0 0 #c)
 (gpu-tex g id w h t)
  (: ls (two? t && !(tray? t) ? t [t])
     (side n k) (max 1 (n // (k 2)))
     sz (map (k \ side w k * side h k) ^#ls)
     c (cask (4 * +sz))
     _ (foldl (\ o k ((cite 'guts 'pinv) c o 4 4 (ls k), (o + 4 * sz k))) 0 ^#ls)
     (put! g c, ask g "tex \(show id) \(show w) \(show h) \(show #ls) 0"))
 (gpu-buf g id verts tris st)
  (: nv (#verts // st) nt (#tris // 4) c (cask (4 * st * nv + 16 * nt))
     _ ((cite 'guts 'pinf) c 0 4 verts) _ ((cite 'guts 'pinv) c (4 * st * nv) 4 4 tris)
     (put! g c, ask g "buf \(show id) \(show nv) \(show nt) 0 \(show st)"))
 (gpu-verts g id verts st) (: nv (#verts // st) c (cask (4 * st * nv)) _ ((cite 'guts 'pinf) c 0 4 verts)
   (put! g c, ask g "verts \(show id) \(show nv) 0 \(show st)"))
 (gpu-sun g sv sd bias) (: c (cask (4 * #sd)) _ ((cite 'guts 'pinf) c 0 4 sd)
    (put! g c, ask g ("sun \(show (shape sd 1)) \(show (shape sd 0)) 0 " + unwords (map num (bias . map (i \ sv i) ^16)))))
 (gpu-drop g id) (ask g "drop \(show id)")
 (gpu-base g w h t) (: c (cask (4 * w * h)) _ ((cite 'guts 'pinv) c 0 4 4 t)
   (put! g c, ask g "base \(show w) \(show h) 0"))
 (gpu-under g cs ds)
  (: ch (shape ds 0) cw (shape ds 1) n (cw * ch) c (cask (8 * n))
     _ ((cite 'guts 'pinv) c 0 4 4 cs) _ ((cite 'guts 'pinf) c (4 * n) 4 ds)
     (put! g c, ask g "under \(show cw) \(show ch) 0"))
 (gpu-win g xid) (ask g "win \(show xid)")
 ; ..laid past the frame's own room, which the helper may still be filling, and answered
 ; when the file is next written
 (gpu-show g f w h W H at ys P)
  (: o (8 * w * h) n (4 * w * h) (rows y) (4 * W * (y 1 - y 0)) c (cask (n + +(map rows ys)))
     _ ((cite 'guts 'pinv) c 0 4 4 f)
     _ (foldl (\ a y (pour c a P (4 * W * y 0) (rows y), a + rows y)) n ys)
     (room! g (o + #c), fdpush (g 'w) c 0 o #c,
      say (g 'to) ("show \(show w) \(show h) \(show W) \(show H) \(show (at 0)) \(show (at 1)) \(show o) \(show #ys)"
                   + foldl (\ a y (a + " " + show (y 0) + " " + show (y 1))) "" ys + "\n"),
      pin g 'shows (peep g 'shows 0 + 1), ()))
 (num x) (show (1.0 * x))
 (gpu-frame g w h mat ids o) (gpu-send g w h mat ids o, gpu-take g w h)
 (gpu-send g w h mat ids o)
  (room! g (8 * w * h), say (g 'to) ("frame \(show w) \(show h) 0 " + unwords (map num (o + map (i \ mat i) ^16)) + " "
                                     + unwords (map show ids) + "\n"), ())
 (gpu-take g w h) (line (g 'from) @ () "the helper has gone" "ok" (fdtray (g 'r) 0 (w * h) @ t (tray? t && #t = w * h ? t "the frame came short")) r r)
 (unwords l) (foldl (\ a s (a = "" ? s (a + " " + s))) "" l)
 (gpu-state g) {'g g 'bufs {} 'used {} 'n 0 'fr 0 'texs () 'wt {} 'once {}}
 ; ..a batch's buf, by the name k its maker gave it, else by its sizes and its sums weighed by
 ; place, so an order counts: lore moves and relights a batch in place, so what it holds names
 ; it; [id x t nv]. a name [m x] keeps one buf for m, laid again as x moves: its verts alone
 ; where its tris are the very ones. one not drawn for a while is dropped
 (batch s i v t k st) (? (k = 'once) (once s i v t st) (: nt (#t // 4) b (s 'bufs)
   nm (two? k && #k = 2)
   key (k = () ? [st #v nt (net (v * weights s #v)) (net (t * weights s #t))] ['k (nm ? <k k) st]) e (peep b key ())
   _ (pin (s 'used) key (s 'fr))
   (kept r f) (string? r ? r (pin b key f, f))
   (lay id) (gpu-buf (s 'g) id v t st @ () (: _ (id = s 'n ? (pin s 'n (id + 1))) (kept () [id (nm ? (k 1) ()) t #v])) r r)
   (? (two? e) (? (!nm || e 1 = k 1) e
                  (e 2 == t && e 3 = #v) (gpu-verts (s 'g) (e 0) v st @ () (kept () [(e 0) (k 1) t #v]) r r)
                  (lay (e 0)))
      (nt = 0) [-1]
      (lay (s 'n)))))
 ; ..a batch laid anew in the i-th slot
 (once s i v t st) (: o (s 'once) id (peep o i () @ () (: n (s 'n) (pins s 'n (n + 1), pin o i n, n)) n n)
   (#t < 4 ? [-1] (gpu-buf (s 'g) id v t st @ () [id] r r)))
 ; ..the weights for n words, kept until the sweep
 (weights s n) (: t (s 'wt) (peep t n () @ () (: w (iota n % 997 + 1) (pin t n w, w)) w w))
 (sweep s) (: b (s 'bufs) u (s 'used) fr (s 'fr) (old? k) (u k < fr - 120)
   _ (each (filter old? (keys u)) (k \ gpu-drop (s 'g) (b k 0)))
   ks (filter (k \ !(old? k)) (keys u))
   (pins s 'bufs (foldl (\ t k (pin t k (b k))) {} ks) 'used (foldl (\ t k (pin t k (u k))) {} ks) 'wt {}))
 ; ..the sun's view, laid again only when it moves
 (sun! s sv sd b) (? (s 'sv == sv && s 'sd == sd && s 'sb = b) ()
   (gpu-sun (s 'g) sv sd b @ r (string? r ? r (pins s 'sv sv 'sd sd 'sb b, ()))))
 ; ..the sky, laid each frame
 (sky! s sk) (? !(two? sk) () (once s 'sky (sk 0) (sk 1) 8 @ [id] (id < 0 ? () (ask (s 'g) "sky \(show id) \(num (sk 2))")) r r))
 ; ..the textures, laid again only when one of them is not the one laid
 (texs! s texs) (? (alike (s 'texs) texs) ()
   (: (lay i) (: t (texs i) l (tray? t ? t (t 0)) (gpu-tex (s 'g) i (shape l 1) (shape l 0) t))
      r (filter string? (map lay ^#texs)) (? (two? r) <r (pin s 'texs texs, ()))))
 (alike a b) (a == b || two? a && two? b && #a = #b && all (i \ a i == b i) ^#a)
 (gpu-facets s w h B mat vs ts texs ol ks sk c)
  (: o (tray? ol ? ol (two? ol ? (ol 0) ())) st (tray? ol ? 8 11) sv (ol 1) sd (ol 2)
     sun (st = 11 && tray? sv && 16 <= #sv && tray? sd && #(shape sd) = 2)
     fl (tray? o ? (int (o 5)) -1)
     un (two? B && #B = 3 && tray? (B 1) && tray? (B 2) && #(B 1) = #(B 2) ? B ()) G (two? un ? <un B)
     bt (tray? G && #G = w * h)
     (? (!(tray? o) || (fl & 55) != 0 || !(bt || charm? G && -1 <= G) || bt && amin G < -1 || s 'g = ()) (drain s, no s 'gate)
        ; ..the frame sent before taken first, before anything is laid where it lies
        (: pr (s 'pend @ () () p (p 0 = w && p 1 = h ? (take s p) (drain s)))
           _ (pin s 'fr (s 'fr + 1)) V (tray? vs ? [vs] vs) T (tray? ts ? [ts] ts)
           tx (texs! s texs @ () (sun ? (sun! s sv sd (o 7)) ()) r r)
           bs (string? tx ? () (map (i \ batch s i (V i) (T i) (two? ks ? (ks i) ()) st) ^#V))
           (? (string? pr || string? tx || any string? bs) (pin s 'g (), ())
              (: _ (s 'fr % 60 = 0 ? (sweep s) 0)
                 u ((bt ? (gpu-base (s 'g) w h G) ()) @ () (two? un ? (gpu-under (s 'g) (un 1) (un 2)) ()) e e)
                 y (string? u ? u (sky! s sk))
                 e (string? y ? y (gpu-send (s 'g) w h mat (map (b \ b 0) bs) [(bt ? -1 G) (o 0) (o 1) (o 2) (o 3) (o 4) (o 6) ((fl & 136) + (sun ? 256 0))]))
                 p [w h c] (now _) (take s p @ q (string? q ? (pin s 'g (), ()) q))
                 (? (string? e) (pin s 'g (), ())
                    !(peep s 'pipe 0) (now () @ () () q (q 0))
                    (two? pr) (pins s 'pend p 'last pr, pr)
                    (s 'last @ () (now () @ () () q (pin s 'last q, q)) l (pin s 'pend p, [(l 0 + 0) (l 1)]))))))))
 ; ..a frame sent as [w h c], taken: [f c], or the helper's words
 (take s p) (: f (gpu-take (s 'g) (p 0) (p 1)) (string? f ? f (no s 'drawn, [f (p 2)])))
 ; ..and one sent and no longer wanted, the last shown forgotten with it
 (drain s) (s 'pend @ () () p (pins s 'pend () 'last (), take s p, ()))
 (no s k) (: t (peep s 'why {}) (pins s 'why (pin t k (peep t k 0 + 1)), ())))
) ; module gpu
