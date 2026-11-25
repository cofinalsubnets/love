; test/gate/beorder.l -- holo's elf-swap over objects mooncc laid: each turns big-endian and
; back to itself, and ld-obj reads the two alike. (be-check DIR NAMES) writes DIR/be/NAME
; beside each for llvm-readelf, and prints a line per failure
(borrow '(holo posix))
(: (rd p) (uread p @ [1 t] t (scare 'beorder-read p))
   (view o) [(o 'class) (o 'type) (o 'mach) (o 'shnum) (o 'nsym)
             (map (o 'sec) ^(o 'shnum)) (map (o 'syms) ^(o 'nsym)) (o 'rels)]
   (one d nm)
    (: s (rd "\(d)/\(nm)") b (elf-swap s)
       _ (uwrite "\(d)/be/\(nm)" b)
       (? (b 5 != 2 || s 5 != 1) "\(nm): not turned big-endian"
          (elf-swap b != s) "\(nm): the swap does not turn back"
          (view (ld-obj nm b 1) != view (ld-obj nm s 1)) "\(nm): ld-obj reads the swap otherwise"
          ()))
   (be-check d nms)
    (filter (x \ x != ()) (map (one d) nms) @ bad
       (each bad (m \ say err "FAIL beorder: \(m)\n"),
        say out "beorder: \(#nms - #bad) of \(#nms) objects turned and read alike\n",
        quit (bad = () ? 0 1))))
