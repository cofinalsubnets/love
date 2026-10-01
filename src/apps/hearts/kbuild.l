; hearts' kbuild -- the kernel's build graph read by love, never run by make.
;
; a directory's Kbuild (or Makefile) is evaluated by cook's variable layer over a seed: the
; config (auto.conf, itself make text), srctree/src/obj, and the arch's core-y/libs-y. hearts
; owns the rest -- the descent, the composites, the archives -- the way scripts/Makefile.build
; lays them, and its answers are held to a reference build's vmlinux.a, member for member.
;
; a hearts build is clean and one-shot: no fixdep, no .cmd, no if_changed, no recursion.
(module (hearts-kbuild hk-seed hk-dir hk-members hk-vmlinux)
(borrow 'posix)
(borrow 'cook)
(borrow 'path)
(:
 hk-vars (cite 'cook 'cook-vars)
 hk-expand (cite 'cook 'cook-expand)
 (hk-slurp p) (uread p @ [1 s] s ())
 (hk-copy t) (foldl (a \ k \ pin a k (t k)) {} (keys t))
 (hk-words t v) (words (hk-expand ("$(" + v + ")") t))
 (hk-dir? w) (ends? w "/")
 (hk-strip w) (snip w 0 (#w - 1))
 ; a member as ar names it: arch/arm64/kvm/../../../virt/kvm/x.o is virt/kvm/x.o
 (hk-path p) (join "/" (pclean (segs p) 0))

 ; the seed every directory starts from: the config, the tree's names, and the lists the
 ; top Makefile builds around the arch's (core-y and drivers-y empty, libs-y lib/ before it)
 (hk-seed K arch conf)
  (: t (pins {} "srctree" K "objtree" "." "ARCH" arch "SRCARCH" arch)
     a (hk-vars (hk-slurp conf) t, hk-copy t)
     (pins a "core-y" "" "drivers-y" "" "libs-y" "lib/",
      hk-vars (hk-slurp (K + "/arch/" + arch + "/Makefile")) a,
      pins t "ARCH_CORE" (join " " (hk-words a "core-y"))
             "ARCH_LIB" (join " " (filter hk-dir? (hk-words a "libs-y")))
             "ARCH_DRIVERS" (join " " (hk-words a "drivers-y" + hk-words a "drivers-m"))
             "hk-libs" (join " " (filter hk-dir? (hk-words a "libs-y")))))

 ; one directory evaluated: its Kbuild, else its Makefile. "" is the root
 (hk-dir K seed dir)
  (: t (hk-copy seed)
     o (dir = "" ? "." dir)
     f (K + "/" + (dir = "" ? "" (dir + "/")))
     src (hk-slurp (f + "Kbuild") || hk-slurp (f + "Makefile") || "")
     (pins t "obj" o "src" o, hk-vars src t, t))

 ; what Makefile.build lays in a directory's built-in.a, flattened: obj-y in order, a
 ; composite by its parts (foo-objs, foo-y), a subdirectory by its own members in place.
 ; answers (built-in members, lib.a members); lib-y is sorted, as Makefile.build sorts it
 (hk-members K seed dir)
  (: t (hk-dir K seed dir)
     pfx (dir = "" ? "" (dir + "/"))
     oy (hk-words t "obj-y")
     (part m) (: b (snip m 0 (#m - 2))
                 ps (hk-words t (b + "-objs") + hk-words t (b + "-y"))
                 (map (p \ hk-path (pfx + p)) (two? ps ? ps [m])))
     (one m) (hk-dir? m ? <(hk-members K seed (pfx + hk-strip m)) (part m))
     lib (filter (m \ !(elem m oy)) (uniq (sort (hk-words t "lib-y" + hk-words t "lib-m"))))
     [(uniq (catmap one oy)) (map (m \ hk-path (pfx + m)) lib)])

 ; vmlinux.a: the root's built-in.a, then each libs-y directory's lib.a, the head objects
 ; (scripts/head-object-list.txt, matched as grep -F does) hoisted ahead in archive order
 (hk-vmlinux K seed)
  (: all (uniq (<(hk-members K seed "") +
                catmap (d \ <>(hk-members K seed (hk-strip d))) (words (seed "hk-libs"))))
     heads (filter (l \ 0 < #l && l 0 != 35)
                   (map strip (lines (hk-slurp (K + "/scripts/head-object-list.txt") || ""))))
     (head? m) (any (h \ 0 <= findsub m h) heads)
     (filter head? all + filter (m \ !(head? m)) all)))
) ; module hearts-kbuild
