; gpu -- frames on the system's gpu, drawn by glhelp (glhelp.c), a process of its own that
; loads the system's gles through dlopen. $LOVE_GLHELP where it names one (an apk's, from the lib
; dir an app may run), else built once and kept in the nest's cache, keyed by its
; source: by mooncc, an executable naming the system's loader, else by the
; system's cc. LOVE_GPU_CC picks one, moon or cc. under android's bridge, its socket
; LOVE_GPU_FACE instead: glhelp in the app's own process, on the app's window. the bulk rides a
; file both hold (a tmpfs, else TMPDIR), a line each way says what to do with it.
;   (gpu-open x)                 a helper, or a nom with why: 'no-helper 'no-gpu; with x, one
;                                that can show on an X window; the bridge's shows on the app's
;                                window, 'face set, with no gpu-win
;   (gpu-win g xid)              the X window it shows on, () where it can
;   (gpu-show g f w h W H at rs P) the picture f w by h shown over the window W by H at [x y],
;                                or ['kept [S C]] the frame the helper kept, the pixels S over its
;                                sky laid with the colours C; then rects rs [x0 y0 x1 y1]
;                                of the paper P laid on it as they are
;   (gpu-tex g id w h t)         texture id, w by h: a tray of 0x00rrggbb (below 0 a hole), rows
;                                top first, or a list of them, each level half the last
;   (gpu-buf g id verts tris st) buf id: facets's verts (st numbers a vertex, 8, or 11 with the
;                                sun's r g b) and tris (4 a triangle, a texture's id, -1 none,
;                                -2 a glow, -3 - t a glass of t), flat trays
;   (gpu-verts g id verts st)    buf id's verts laid again, as many and as wide, its tris kept
;   (gpu-lamps g id cols li)     buf id's lamps: 24 numbers a vertex, 8 slots of r g b, slot k
;                                lamp li k's light there at full strength; the strengths
;                                sent with ks times them added to each vertex's colour
;   (gpu-scene g rs)             the scene kept: rs [id x y z r l k gr m ..], each buf, its ball, a
;                                light l whose strength times k its colours are times (l below 0
;                                none), its group and its mark; a frame's id -9 - gr draws those
;                                of gr it sees there, nearest first, but where its light is out
;                                or its mark down
;   (gpu-vis g ms ks)            kept: mark m down where ms m is 0, and ks the lights' strengths
;   (gpu-sun g sv sd bias)       the sun's view kept: its matrix sv and depths sd, facets's
;   (gpu-drop g id)
;   (gpu-place g ps)             each [id x y z] of ps: buf id drawn moved by x y z, until laid again
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
;                                as facets draws it with flags 352, 11 a vertex, its pixels bare
;                                alone 2^32 more, or (); [.. spots e] its places from the eye at e.
;                                c [v ..] with v 'lamps each batch's [cols li] or () and v 'dks
;                                the lamps' strengths, as gpu-lamps takes them; and v 'scene
;                                {'key 'make 'at 'vis 'kb}: (make ()) its bufs, each [verts tris
;                                name lamps [x y z r] l k gr m], laid as the scene while key is
;                                the same, group gr drawn after at gr batches; vis and kb gpu-vis's;
;                                v 'offs each batch's [x y z] it is drawn moved by, or ()
;                                with s 'pipe, [f c'] instead: the frame before and its c, this
;                                one drawn meanwhile; after a start or a stop the frame itself,
;                                then it once more
;   (gpu-state g)                s for a helper g: the bufs it holds, each by what it holds
(module (gpu gpu-open gpu-win gpu-show gpu-tex gpu-buf gpu-verts gpu-lamps gpu-scene gpu-vis gpu-sun gpu-drop gpu-place gpu-under gpu-frame gpu-send gpu-take gpu-close gpu-how gpu-state gpu-facets)
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
     gh (getenv "LOVE_GLHELP")
     (? (string? gh && here? gh) [gh] !(string? src) 'no-source !(string? d) 'no-cache
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
 ; ..the file the bulk goes through: in a tmpfs, else where the process keeps its own
 (bulk-file _) (: sp (dir? "/dev/shm" ? "/dev/shm" (getenv "TMPDIR" @ t (string? t && dir? t ? t (cache-dir ()))))
                  (string? sp ? (sp + "/glhelp-" + show (getpid 0) + "-" + show (clock 0))))
 (hello hi) (string? hi && 6 < #hi && snip hi 0 6 = "ready ")
 ; ..in an app's own process, on its window: the bridge's (LOVE_GPU_FACE), told the file first
 (face-open p) (: f (bulk-file ()) s (string? f ? (connect ['unix p]))
   (? !(port? s) ['no-gpu "the bridge's gpu is not there"]
      (: w (openfd f 1) r (openfd f 0) _ (say s (f + "\n")) hi (line s) _ (unlink f)
         (hello hi ? {'to s 'from s 'pid () 'w w 'r r 'room 0 'how (snip hi 6 #hi) 'face 1}
            (close s, close w, close r, ['no-gpu (string? hi ? hi "the bridge's gpu said nothing")])))))
 (gpu-open x) (getenv "LOVE_GPU_FACE" @ fc (string? fc ? (face-open fc) (spawned x)))
 (spawned x)
  (: argv (helper-argv ()) f (bulk-file ())
     (? !(two? argv) ['no-helper argv] !(string? f) ['no-helper 'no-file]
        (: w (openfd f 1) r (openfd f 0)
           a (pipe 0) b (pipe 0)
           p (spawnio (argv + [f] + (x ? ["x"] ())) <a >b -1 [>a <b] -1 0)
           _ (close <a) _ (close >b)
           q (fdopen <b)
           hi (line q)
           _ (unlink f)
           (? (hello hi)
              {'to >a 'from q 'pid p 'w w 'r r 'room 0 'how (snip hi 6 #hi) 'argv argv}
              (close >a, close q, close w, close r, (charm? p ? (wait p) 0),
                 ['no-gpu (string? hi ? hi "the helper said nothing")])))))
 (gpu-close g) (say (g 'to) "quit\n", close (g 'to), (g 'pid @ () 0 p (close (g 'from), wait p)), close (g 'w), close (g 'r), ())
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
 ; ..a buf's lamps, 8 slots a vertex of 3 words each, slot k lamp li k's light there
 (gpu-lamps g id cols li) (: nv (#cols // 24) c (cask (4 * 24 * nv)) _ ((cite 'guts 'pinf) c 0 4 cols)
   (put! g c, ask g ("lamps \(show id) \(show nv) 0 " + unwords (map show li))))
 (gpu-scene g rs) (: c (cask (4 * #rs)) _ ((cite 'guts 'pinf) c 0 4 (gem-tray [#rs] (map (x \ 1.0 * x) rs)))
   (put! g c, ask g "scene \(show (#rs // 9)) 0"))
 (gpu-vis g ms ks) (: m (tray? ms ? (1.0 * ms) (gem-tray [#ms] (map (x \ 1.0 * x) ms))) k (gem-tray [#ks] (map (x \ 1.0 * x) ks))
   c (cask (4 * (#m + #k))) _ ((cite 'guts 'pinf) c 0 4 m) _ ((cite 'guts 'pinf) c (4 * #m) 4 k)
   (put! g c, ask g "vis \(show #m) \(show #k) 0"))
 (gpu-sun g sv sd bias) (: c (cask (4 * #sd)) _ ((cite 'guts 'pinf) c 0 4 sd)
    (put! g c, ask g ("sun \(show (shape sd 1)) \(show (shape sd 0)) 0 " + unwords (map num (bias . map (i \ sv i) ^16)))))
 (gpu-drop g id) (ask g "drop \(show id)")
 (gpu-place g ps) (ask g ("place " + unwords (map (p \ unwords (show (p 0) . map num (p 1))) ps)))
 ; ..spots [S C] for the next frame w by h, laid in its sky
 (gpu-spots g w h sp) (: I (iota (sp 0 >= 0)) ns #I c (cask (8 * ns))
   _ (ns @ 0 0 ((cite 'guts 'pinf) c 0 4 (1.0 * sp 0 I), (cite 'guts 'pinf) c (4 * ns) 4 (1.0 * sp 1 I)))
   (ns @ 0 () (put! g c, ask g "spots \(show w) \(show h) \(show ns) 0")))
 (gpu-base g w h t) (: c (cask (4 * w * h)) _ ((cite 'guts 'pinv) c 0 4 4 t)
   (put! g c, ask g "base \(show w) \(show h) 0"))
 (gpu-under g cs ds)
  (: ch (shape ds 0) cw (shape ds 1) n (cw * ch) c (cask (8 * n))
     _ ((cite 'guts 'pinv) c 0 4 4 cs) _ ((cite 'guts 'pinf) c (4 * n) 4 ds)
     (put! g c, ask g "under \(show cw) \(show ch) 0"))
 (gpu-win g xid) (ask g "win \(show xid)")
 ; ..laid past the frame's own room, which the helper may still be filling, a kept one from the
 ; copy the helper made of it, the last taken; and answered when the file is next written
 (gpu-show g f w h W H at rs P)
  (: o (8 * w * h) kp (two? f) sp (kp && two? (f 1) ? (f 1) ()) I (two? sp ? (iota (sp 0 >= 0)) ()) ns #I
     n (kp ? (8 * ns) (4 * w * h)) (size r) (4 * (r 2 - r 0) * (r 3 - r 1)) c (cask (n + +(map size rs)))
     _ (? kp (ns @ 0 0 ((cite 'guts 'pinf) c 0 4 (1.0 * sp 0 I), (cite 'guts 'pinf) c (4 * ns) 4 (1.0 * sp 1 I)))
          ((cite 'guts 'pinv) c 0 4 4 f))
     ; ..each rect's rows, one after another
     (rows r a) (foldl (\ a y (pour c a P (4 * (y * W + r 0)) (4 * (r 2 - r 0)), a + 4 * (r 2 - r 0))) a (map (+ (r 1)) ^(r 3 - r 1)))
     _ (foldl (\ a r (rows r a)) n rs)
     (room! g (o + #c), fdpush (g 'w) c 0 o #c,
      say (g 'to) ("show \(show w) \(show h) \(show W) \(show H) \(show (at 0)) \(show (at 1)) \(show o) \(kp ? (show (g 'ks + 1)) "0") \(show ns) \(show #rs)"
                   + foldl (\ a r (a + " " + unwords (map show r))) "" rs + "\n"),
      pin g 'shows (peep g 'shows 0 + 1), ()))
 (num x) (show (1.0 * x))
 (gpu-frame g w h mat ids o) (gpu-send g w h mat ids o, gpu-take g w h)
 (gpu-send g w h mat ids o)
  (room! g (8 * w * h), say (g 'to) ("frame \(show w) \(show h) 0 " + unwords (map num (o + map (i \ mat i) ^16)) + " "
                                     + unwords (map show ids) + "\n"), ())
 (gpu-take g w h) (line (g 'from) @ () "the helper has gone" "kept \(k)" (pin g 'ks (read k), 'kept) "ok" (fdtray (g 'r) 0 (w * h) @ t (tray? t && #t = w * h ? t "the frame came short")) r r)
 (unwords l) (foldl (\ a s (a = "" ? s (a + " " + s))) "" l)
 (gpu-state g) {'g g 'bufs {} 'used {} 'n 0 'fr 0 'texs () 'wt {} 'once {} 'lamped {} 'held {} 'placed {}}
 ; ..a batch's buf, by the name k its maker gave it, else by its sizes and its sums weighed by
 ; place, so an order counts: lore moves and relights a batch in place, so what it holds names
 ; it; [id x t nv]. a name [m x] keeps one buf for m, laid again as x moves: its verts alone
 ; where its tris are the very ones. one not drawn for a while is dropped
 (batch s i v t k st) (? (k = 'once) (once s i v t st) (: nt (#t // 4) b (s 'bufs)
   nm (two? k && #k = 2)
   key (k = () ? [st #v nt (net (v * weights s #v)) (net (t * weights s #t))] ['k (nm ? <k k) st]) e (peep b key ())
   _ (pin (s 'used) key (s 'fr))
   (kept r f) (string? r ? r (pin b key f, f))
   (lay id) (gpu-buf (s 'g) id v t st @ () (: _ (id = s 'n ? (pin s 'n (id + 1))) _ (pin (s 'lamped) id ()) _ (pin (s 'placed) id ()) (kept () [id (nm ? (k 1) ()) t #v])) r r)
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
 (sweep s) (: b (s 'bufs) u (s 'used) fr (s 'fr) (old? k) (u k < fr - 120 && !peep (s 'held) (b k 0) 0)
   _ (each (filter old? (keys u)) (k \ gpu-drop (s 'g) (b k 0)))
   ks (filter (k \ !(old? k)) (keys u))
   (pins s 'bufs (foldl (\ t k (pin t k (b k))) {} ks) 'used (foldl (\ t k (pin t k (u k))) {} ks) 'wt {}))
 ; ..the sun's view, laid again only when it moves
 (sun! s sv sd b) (? (s 'sv == sv && s 'sd == sd && s 'sb = b) ()
   (gpu-sun (s 'g) sv sd b @ r (string? r ? r (pins s 'sv sv 'sd sd 'sb b, ()))))
 ; ..the sky, laid again only as its mesh is new, drawn from the eye each frame, and the spots
 ; in it a frame w by h asks
 (sky! s sk w h) (? !(two? sk) ()
   (: _ (#sk > 3 && two? (sk 3) ? (gpu-spots (s 'g) w h (sk 3)) ())
      e (#sk > 4 ? (sk 4) [0.0 0.0 0.0])
      q (? (peep s 'skv () == sk 0 && peep s 'skt () == sk 1) [(s 'skid)]
           (once s 'sky (sk 0) (sk 1) 11 @ [id] (pins s 'skv (sk 0) 'skt (sk 1) 'skid id, [id]) r r))
     (q @ [id] (id < 0 ? () (ask (s 'g) "sky \(show id) \(num (sk 2)) \(num (e 0)) \(num (e 1)) \(num (e 2))")) r r)))
 ; ..the lamps' strengths, sent as they change; and each batch's lamps lm i, [cols li] or (),
 ; laid on its buf once
 (lamps! s bs lm ks)
  (: k (? (!(two? ks) || alike (peep s 'ks ()) ks) () (ask (s 'g) ("ks " + unwords (map num ks)) @ () (pin s 'ks ks, ()) r r))
     (one i) (: q (lm i) id (bs i 0)
               (? (!(two? q) || id < 0 || peep (s 'lamped) id () == q 0) ()
                  (gpu-lamps (s 'g) id (q 0) (q 1) @ () (pin (s 'lamped) id (q 0), ()) r r)))
     (string? k ? k (: r (filter string? (map one ^(min #bs #lm))) (two? r ? <r ()))))
 ; ..the scene sc, laid again only as its key is new, its bufs held from the sweep; and its
 ; marks and the lights' strengths, each frame
 (scene! s sc st ks) (? !(tablet? sc) ()
   (: r (peep s 'skey () = sc 'key ? ()
          (: q ((sc 'make) ()) bs (map (i \ batch s i (q i 0) (q i 1) (q i 2) st) ^#q)
             (? (any string? bs) (<(filter string? bs))
                (: l (lamps! s bs (map (e \ e 3) q) ks)
                   r (string? l ? l (gpu-scene (s 'g) (catmap (i \ [(bs i 0)] + q i 4 + [(q i 5) (q i 6) (q i 7) (q i 8)]) (filter (i \ bs i 0 >= 0) ^#bs))))
                   (string? r ? r (pins s 'skey (sc 'key) 'held (foldl (\ t b (pin t (b 0) 1)) {} bs), ()))))))
      (string? r ? r (gpu-vis (s 'g) (sc 'vis) (sc 'kb)))))
 ; ..each batch's offset os i, sent as it moves
 (place! s bs os) (: ps (catmap (i \ (: o (os i) id (bs i 0)
                                       (two? o && id >= 0 && !(peep (s 'placed) id () = o) ? [[id o]] ()))) ^(min #bs #os))
   (atom? ps ? () (gpu-place (s 'g) (map (p \ [(p 0) (p 1)]) ps) @ () (each ps (p \ pin (s 'placed) (p 0) (p 1)), ()) e e)))
 ; ..the eye the glows face and the depths they fade by, facets's opts past 8, each frame
 (glow! s o) (? (#o < 18) () (ask (s 'g) ("glow " + unwords (map (i \ num (o (8 + i))) ^10))))
 ; ..the textures, each laid again only when it is not the one laid
 (texs! s texs) (? (alike (s 'texs) texs) ()
   (: o (s 'texs) all (!(two? o) || #o != #texs)
      (lay i) (: t (texs i) l (tray? t ? t (t 0)) (gpu-tex (s 'g) i (shape l 1) (shape l 0) t))
      r (filter string? (map lay (filter (i \ all || !(o i == texs i)) ^#texs))) (? (two? r) <r (pin s 'texs texs, ()))))
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
                 cv (two? c && tablet? (c 0) ? (c 0) {})
                 u ((bt ? (gpu-base (s 'g) w h G) ()) @ () (two? un ? (gpu-under (s 'g) (un 1) (un 2)) ()) e e)
                 sn (peep cv 'scene ()) sc (string? u ? u (scene! s sn st (peep cv 'dks ())))
                 la (string? sc ? sc (lamps! s bs (peep cv 'lamps ()) (peep cv 'dks ())) @ () (place! s bs (peep cv 'offs ())) e e)
                 ids (map (b \ b 0) bs) at (tablet? sn ? (sn 'at) ())
                 ; ..each group's mark where its at says
                 (laid i) (foldl (\ a g (at g = i ? (a + [(-9 - g)]) a)) [] ^#at)
                 y (string? la ? la (sky! s sk w h) @ () (glow! s o) r r)
                 ; ..kept unread where none of it is the cpu's, once shown on a window, with no sky to finish
                 ; or one that says its spots; but every 'read'th, which a feed in view reads back
                 rd (peep s 'read 0) kp (peep s 'keep 0 && (!(two? sk) || 2 < #(c 2 2)) && !(0 < rd && s 'fr % rd = 0) ? 512 0)
                 e (string? y ? y (gpu-send (s 'g) w h mat (atom? at ? ids (catmap (i \ laid i + (i < #ids ? [(ids i)] ())) ^(#ids + 1))) [(bt ? -1 G) (o 0) (o 1) (o 2) (o 3) (o 4) (o 6) ((fl & 136) + (sun ? 256 0) + kp)]))
                 p [w h c] (now _) (take s p @ q (string? q ? (pin s 'g (), ()) q))
                 (? (string? e) (pin s 'g (), ())
                    !(peep s 'pipe 0) (now () @ () () q (q 0))
                    (two? pr) (pins s 'pend p 'last pr, pr)
                    ; ..the last shown again while this one draws, but a kept one, whose frame this one drew over
                    (: (fresh _) (now () @ () () q (pin s 'last q, q))
                       (s 'last @ () (fresh ()) l (nom? (l 0) ? (fresh ()) (pin s 'pend p, [(l 0 + 0) (l 1)]))))))))))
 ; ..a frame sent as [w h c], taken: [f c], or the helper's words
 (take s p) (: f (gpu-take (s 'g) (p 0) (p 1)) (string? f ? f (no s 'drawn, [f (p 2)])))
 ; ..and one sent and no longer wanted, the last shown forgotten with it
 (drain s) (s 'pend @ () () p (pins s 'pend () 'last (), take s p, ()))
 (no s k) (: t (peep s 'why {}) (pins s 'why (pin t k (peep t k 0 + 1)), ())))
) ; module gpu
