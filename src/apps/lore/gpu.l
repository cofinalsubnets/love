; gpu -- frames on the system's gpu, drawn by glhelp (glhelp.c), a process of its own that
; loads the system's gles through dlopen. built once and kept in the nest's cache, keyed by its
; source: by mooncc, a -shared object with a _start that the system's loader runs, else by the
; system's cc. LOVE_GPU_CC picks one, moon or cc. the bulk rides a tmpfs file both hold, a
; line each way says what to do with it.
;   (gpu-open _)                 a helper, or a nom with why: 'no-helper 'no-gpu
;   (gpu-tex g id w h t)         texture id, w by h: a tray of 0x00rrggbb (below 0 a hole), rows
;                                top first, or a list of them, each level half the last
;   (gpu-buf g id verts tris)    buf id: facets's verts (8 numbers a vertex) and tris (4 a
;                                triangle, a texture's id or below 0 none), flat trays
;   (gpu-drop g id)
;   (gpu-frame g w h mat ids o)  the bufs ids through mat (16 numbers, row-major, gl's clip
;                                box), o [clear fr fg fb near far tone]: a cask of w*h 0x00rrggbb,
;                                rows top first
;   (gpu-close g)
; each answers () where it worked, else the helper's words, but gpu-frame
(module (gpu gpu-open gpu-tex gpu-buf gpu-drop gpu-frame gpu-close gpu-how)
(borrow '(posix hashes))
(:
 (dir? p) (stat p @ s (two? s && 16384 = 61440 & <>>s))
 (up p) (#p @ n (: (go i) (i < 0 ? "." (p i = 47 ? (i ? (snip p 0 i) "/") (go (i - 1)))) (go (n - 1))))
 (base p) (#p @ n (: (go i) (i < 0 ? p (p i = 47 ? (snip p (i + 1) n) (go (i - 1)))) (go (n - 1))))
 ; ..the nest's cache: beside bin/ in a nest, else beside the binary (out/ in a checkout)
 (cache-dir _) (: s (selfpath 0) b (up s) r (base b = "bin" ? (up b) b)
                  d (r + "/cache/glhelp")
                  (, (mkdir (r + "/cache") 493) (mkdir d 493) (dir? d ? d ())))
 (source _) (open "/love/src/apps/lore/glhelp.c" "r" @ q
              (hot? q ? (slurp q @ t (close q, t))
                 (open "src/apps/lore/glhelp.c" "r" @ q (hot? q ? (slurp q @ t (close q, t)) ()))))
 (here? p) (two? (stat p))
 ; ..the system loader a mooncc build runs under, by the machine
 (loader m) (m @ "x86_64" "/lib64/ld-linux-x86-64.so.2" "aarch64" "/lib/ld-linux-aarch64.so.1" ())
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
                      && made mb (o \ [(selfpath 0) "cc" "-O2" "-shared" "-o" o cf "-l:libc.so.6"]))
           (cc? _) (how != 'moon && made cb (o \ ["cc" "-O2" "-o" o cf]))
           (? (moon? ()) [ld mb] (cc? ()) [cb] 'no-compiler))))
 ; ..a line from the helper, its newline gone; () once it has gone
 (line q) (: (go acc) (see q @ c (c < 0 ? (acc = "" ? () acc) (c = 10 ? acc (go (acc + string [c]))))) (go ""))
 (ask g s) (, (say (g 'to) (s + "\n")) (line (g 'from) @ () "the helper has gone" "ok" () r r))
 (gpu-how g) (g 'how)
 (gpu-open _)
  (: argv (helper-argv ())
     (? !(two? argv) ['no-helper argv]
        (: sp (dir? "/dev/shm" ? "/dev/shm" (cache-dir ()))
           f (sp + "/glhelp-" + show (getpid 0) + "-" + show (clock 0))
           w (openfd f 1) r (openfd f 0)
           a (pipe 0) b (pipe 0)
           p (spawnio (argv + [f]) <a >b -1 [>a <b] -1 0)
           _ (close <a) _ (close >b)
           q (fdopen <b)
           hi (line q)
           _ (unlink f)
           (? (string? hi && 6 < #hi && snip hi 0 6 = "ready ")
              {'to >a 'from q 'pid p 'w w 'r r 'room 0 'how (snip hi 6 #hi) 'argv argv}
              (, (close >a) (close q) (close w) (close r) (charm? p ? (wait p) 0)
                 ['no-gpu (string? hi ? hi "the helper said nothing")])))))
 (gpu-close g) (, (say (g 'to) "quit\n") (close (g 'to)) (close (g 'from)) (close (g 'w)) (close (g 'r)) (wait (g 'pid)) ())
 ; ..the shared file at least n bytes
 (room! g n) (g 'room < n ? (truncate (g 'w) n 0, pin g 'room n) g)
 (put! g c) (, (room! g #c) (fdpush (g 'w) c 0 0 #c))
 (gpu-tex g id w h t)
  (: ls (two? t && !(tray? t) ? t [t])
     (side n k) (max 1 (n // (k 2)))
     sz (map (k \ side w k * side h k) ^#ls)
     c (cask (4 * +sz))
     _ (foldl (\ o k (, ((cite 'guts 'pinv) c o 4 4 (ls k)) (o + 4 * sz k))) 0 ^#ls)
     (, (put! g c) (ask g "tex \(show id) \(show w) \(show h) \(show #ls) 0")))
 (gpu-buf g id verts tris)
  (: nv (#verts // 8) nt (#tris // 4) c (cask (32 * nv + 16 * nt))
     _ ((cite 'guts 'pinf) c 0 4 verts) _ ((cite 'guts 'pinv) c (32 * nv) 4 4 tris)
     (, (put! g c) (ask g "buf \(show id) \(show nv) \(show nt) 0")))
 (gpu-drop g id) (ask g "drop \(show id)")
 (num x) (show (1.0 * x))
 (gpu-frame g w h mat ids o)
  (: n (4 * w * h) _ (room! g n)
     r (ask g ("frame \(show w) \(show h) 0 " + unwords (map num (o + map (i \ mat i) ^16)) + " "
               + unwords (map show ids)))
     (? r r (: c (cask n) (fdpull (g 'r) c 0 0 n, c))))
 (unwords l) (foldl (\ a s (a = "" ? s (a + " " + s))) "" l))
) ; module gpu
