; bench/ccdead.l -- how much of each lane's libc the binary can never reach.
;
;   love bench/ccdead.l            (after ./ccbench.sh, or `make ccbench`)
;   love bench/ccdead.l ELF ..     (no own-object split, so every text symbol reads as libc)
;
; ccsize.sh counts the libc bytes a lane ships; this counts the ones it can call. the method walks
; call/jmp/lea targets out of `objdump -d`, seeded from _start and from every function address in
; the data sections (vtables and jump tables are reached no other way). a missed indirect call marks
; a live function dead, never the reverse, so reachable is a lower bound and dead an upper one.
; the musl lane is the control: its dead set is the floor a static-linking libc cannot get under.

(borrow 'posix)
(: root (cwd 0)
   wd (root + "/out/bench/cc")

   ; --- shelling out, captured ------------------------------------------------
   (shout argv)
    (: pp (pipe 0) r <pp w >pp
       kid (spawnmap argv [(1 . w) (2 . ())] () 0 0)
       _ (close w)
       (charm? kid && kid < 0 ? (close r, "")
          (: q (fdopen r) s (slurp q) (close q, wait kid, "" + s))))

   ; --- little string kit -----------------------------------------------------
   (lines s)
    (: n #s
       (go i a acc) (? (n <= i) (rev (i <= a ? acc (snip s a i . acc)))
                       (s i = 10) (go (i + 1) (i + 1) (snip s a i . acc))
                       (go (i + 1) a acc))
       (go 0 0 ()))
   (blank? c) (c = 32 || c = 9 || c = 13)
   (fields s)
    (: n #s
       (go i a acc) (? (n <= i) (rev (i <= a ? acc (snip s a i . acc)))
                       (blank? (s i)) (go (i + 1) (i + 1) (i <= a ? acc (snip s a i . acc)))
                       (go (i + 1) a acc))
       (go 0 0 ()))
   (at? s sub i)                                   ; does sub sit at offset i of s
    (#sub @ m (i + m <= #s && snip s i (i + m) = sub))
   (hex s)                                         ; hex text -> charm, no 0x
    (: n #s
       (go i v) (? (n <= i) v
                   (: c (s i)
                      d (? (47 < c && c < 58) (c - 48) (96 < c && c < 103) (c - 87)
                           (64 < c && c < 71) (c - 55) -1)
                      (d < 0 ? v (go (i + 1) (v * 16 + d)))))
       (go 0 0))

   ; --- the compiler-mangled suffixes, stripped (twice, as gcc nests them) -----
   ; .isra.0 .part.1 .constprop.0 .cold .lto_priv.42 .localalias .llvm.1234
   canon-tags '("isra" "part" "constprop" "cold" "lto_priv" "localalias" "llvm")
   (tail-ok? s i)                                  ; only . _ and digits to the end
    (: n #s
       (go k) (? (n <= k) 1
                 (s k @ c (c = 46 || c = 95 || 47 < c && c < 58 ? (go (k + 1)) 0)))
       (go i))
   (canon1 s)
    (: n #s
       (try i) (? (n <= i) s
                  (s i = 46)
                   (filter (t \ at? s t (i + 1) && tail-ok? s (i + 1 + #t)) canon-tags @ hit
                      (two? hit ? (snip s 0 i) (try (i + 1))))
                  (try (i + 1)))
       (try 0))
   (canon s) (canon1 (canon1 s))

   ; --- nm: the defined text symbols ------------------------------------------
   (tsyms-of txt)                                  ; -> ((addr . name) ..), nm order
    (: rows (map fields (lines txt))
       ok (filter (f \ 3 = #f && (f 1 = "T" || f 1 = "t")) rows)
       (map (f \ hex <f . canon (f 2)) ok))

   ; sizes by address gap -- mooncc's ELF carries no st_size, so the next symbol
   ; is what bounds this one; the last symbol in the run measures 0.
   (sizes rows)
    (: t {}
       (go rs) (? !(two? rs) t
                  (: r <rs nm >r
                     nx (two? >rs ? <<>rs <r)
                     (pin t nm (peep t nm 0 + (nx - <r)), go >rs)))
       (go rows))
   (byaddr rows) ({} @ t (each rows (r \ pin t <r >r), t))

   ; --- objdump: the call graph ------------------------------------------------
   ; a header line is `0000000000401000 <name>:`; every other line with a tab is an
   ; instruction, and each <target> or <target+0x..> on it is an edge.
   (edges-of txt)
    (: e {}
       (tgts ln acc i)                             ; the <..> spellings on one line
        (: n #ln
           (? (n <= i) (rev acc)
              (ln i = 60)
               (: (fin j) (? (n <= j) (rev acc)
                             (ln j = 62) (: nm (snip ln (i + 1) j)
                                            p (idx-plus nm)
                                            (tgts ln ((p < 0 ? nm (snip nm 0 p)) . acc) (j + 1)))
                             (fin (j + 1)))
                  (fin (i + 1)))
              (tgts ln acc (i + 1))))
       (idx-plus nm) (: n #nm
                        (go k) (? (n <= k) -1 (nm k = 43) k (go (k + 1)))
                        (go 0))
       (tab? ln) (: n #ln
                    (go k) (? (n <= k) 0 (ln k = 9) 1 (go (k + 1)))
                    (go 0))
       (hdr ln)                                    ; -> name | ()
        (: n #ln
           (go k) (? (n <= k) ()
                     (ln k = 60)
                      (ln (n - 1) = 58 && ln (n - 2) = 62 ? (snip ln (k + 1) (n - 2)))
                     (go (k + 1)))
           (2 < n ? (go 0)))
       (go ls cur) (? !(two? ls) e
                      (: ln <ls h (hdr ln)
                         (? (string? h) (e h ? 0 (pin e h {}), go >ls h)
                            (string? cur && tab? ln)
                             (peep e cur {} @ s
                                (each (tgts ln () 0) (t \ pin s t 1), go >ls cur))
                            (go >ls cur))))
       (go (lines txt) ()))

   ; --- a function pointer sitting in data is a root: nothing calls it by name --
   data-secs '(".data" ".rodata" ".data.rel.ro" ".init_array")
   (le64 s i)                                      ; 8 bytes little-endian
    (: (go k v) (8 <= k ? v (go (k + 1) (v + (s (i + k) << 8 * k))))
       (go 0 0))
   (data-roots elf ba acc)
    (: (scan raw i n acc)
        (? (n <= i) acc
           ; the top two bytes gate the read: a text address never reaches 2^48,
           ; so this skips almost every offset without building a number.
           (raw (i + 7) = 0 && raw (i + 6) = 0)
            (ba (le64 raw i) @ nm
               (scan raw (i + 1) n (string? nm ? (nm . acc) acc)))
           (scan raw (i + 1) n acc))
       (go secs acc)
        (? !(two? secs) acc
           (: raw (shout ["objcopy" "-O" "binary" "--only-section" <secs elf "/dev/stdout"])
              n #raw
              (go >secs (n < 8 ? acc (scan raw 0 (n - 7) acc)))))
       (go data-secs acc))

   (reach elf ba)
    (: e (edges-of (shout ["objdump" "-d" elf]))
       seed (filter (n \ e n) '("_start" "__love_start" "main"))
       roots (data-roots elf ba seed)
       seen {}
       (go q) (? !(two? q) seen
                 (: n <q
                    (seen n ? (go >q)
                       (: _ (pin seen n 1)
                          kids (e n @ s (s ? (keys s)))
                          (go (kids + >q))))))
       (go roots))

   ; --- the lane's own love C, by its own objects, never by what the other lacks -
   (objsyms objs)
    ({} @ t
       (two? objs ? (each (tsyms-of (shout (["nm" "--defined-only"] + objs))) (r \ pin t >r 1)) 0,
        t))
   (isdir? p) (stat p @ st (two? st && st 2 & 61440 = 16384))
   (base-of p) (: n #p                             ; the lane name a bare ELF argument wears
                  (go i) (? (n <= i) p (p (n - 1 - i) = 47) (snip p (n - i) n) (go (i + 1)))
                  (go 0))
   (ls-suffix d sfx)
    (#sfx @ n
       (filter (f \ #f @ m (n <= m && snip f (m - n) m = sfx)) (sort (readdir d))))
   (ownof lane)
    (: d (lane = "mooncc" ? (wd + "/mooncc") (wd + "/o-love-" + lane))
       (? !(isdir? d) ()
          (: os (lane = "mooncc"
                 ? (: skip '("love.o" "moonlibc.o" "sys.o")
                      keep (filter (f \ !(elem f skip) && !(at? f "m_" 0))
                                   (ls-suffix d ".o"))
                      (map (f \ d + "/" + f) keep + [(d + "/love.o") (d + "/m_am.o")]))
                   (d + "/host" @ hd
                      ([(d + "/love.o") (d + "/lm.o")]
                       + (isdir? hd ? (map (f \ hd + "/" + f) (ls-suffix hd ".o"))))))
             live (filter (p \ two? (stat p)) os)
             (two? live ? (objsyms live)))))

   ; --- the table ---------------------------------------------------------------
   (pad s n) (#s @ m (n <= m ? s (pad (s + " ") n)))
   (lpad s n) (#s @ m (n <= m ? s (lpad (" " + s) n)))
   ; one decimal of a percent, integer-only: `/` would answer a gem and print its whole tail
   (pct a b) (b ? (1000 * a // b @ q (show (q // 10) + "." + show (q % 10) + "%")) "0.0%")

   (row lane elf own)
    (: rows (tsyms-of (shout ["nm" "-n" "--defined-only" elf]))
       sz (sizes rows)
       live (reach elf (byaddr rows))
       libc (filter (n \ !(own && own n)) (keys sz))
       dead (filter (n \ !(live n)) libc)
       tot (foldl (\ a n (a + peep sz n 0)) 0 libc)
       dz (foldl (\ a n (a + peep sz n 0)) 0 dead)
       (say out (pad lane 12 + " " + lpad (show #libc) 6
                 + " " + lpad (show tot) 10
                 + " " + lpad (show (#libc - #dead)) 6
                 + " " + lpad (show (tot - dz)) 10
                 + " " + lpad (show #dead) 6
                 + " " + lpad (show dz) 10
                 + "  " + lpad (pct dz tot) 5 + "\n"),
        #("" + getenv "CCDEAD_V")
         ? (each (take 20 (sortby (\ a b (peep sz b 0 < peep sz a 0)) dead))
                 (n \ say out ("      " + pad n 28 + " " + lpad (show (peep sz n 0)) 7 + "\n")))
           0,
        0))

   (: av >argv
      lanes (? (two? av)
               (map (e \ [(base-of e) e ()]) av)
               (: known '("mooncc" "gcc-musl" "clang-musl" "gcc" "clang")
                  (filter (l \ two? (stat <>l))
                          (map (l \ [l (wd + "/love-" + l) (ownof l)]) known))))
      (two? lanes ? 0
         (say err ("ccdead: no lane binaries under " + wd + " -- run ./ccbench.sh first\n"),
          quit 1),
       say out "libc .text, shipped against reachable  (musl is the control: its dead set is the floor)\n",
       say out (pad "lane" 12 + " " + lpad "syms" 6 + " " + lpad "shipped" 10
                + " " + lpad "live" 6 + " " + lpad "bytes" 10
                + " " + lpad "dead" 6 + " " + lpad "bytes" 10 + "\n"),
       each lanes (l \ row <l <>l <>>l),
       0)))
