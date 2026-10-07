; src/tools/mkrt.l -- lay the compiled moonlibc runtime into an ELF object, one
; deflated archive per hosted ISA, so a bare `love cc` links without compiling
; 210 members first (moon.l's rtcarried; src/love/src.c answers runtime-gz).
;
;   love wake out/mooncc0.image src/tools/mkrt.l -m GRP.a ISA SRC..   one group's members
;   love wake out/mooncc0.image src/tools/mkrt.l out.o ARCH GRP.a..   the join
;
; the makefile owns the fan: a group is a few members of one ISA (out/rt/<isa>/<grp>.a,
; a plain archive), and the join reads every group, the ISA off each one's directory.
; the object holds, per name in {id, x64, a64, rv64}, mksrc.l's pair shape 8-aligned:
;
;   rtgz_<nm>_len   an 8-byte little-endian length
;   rtgz_<nm>       the bytes, right behind it (a .a under DEFLATE; `id`
;                      is moon.l's rtcid of the tree slice, plain text)
;
; a link carrying no runtime (love0, the gate links) names src/love/noblob.c instead. arbytes
; and rtcid are pure of the machine, so the seed's fixpoint carries this object unchanged.
; this rides the mooncc image (wake), since the members are mooncc compiles; arch names the
; object format (the link's arch), and a cross backend joins from its tree text.

(borrow 'posix)
(borrow 'gz)
(: (rt-die m) (say err ("mkrt: " + m + "\n"), quit 1)
   (rt-rdev cl)
    (sound cl @ 'torn (rt-die "torn backend text")
                (a . u) (ev a, rt-rdev u))
   (rt-be arch)
    (lit? (cite 'holo 'backends arch) ? 0
       (: f ("src/love/holo/" + string arch + ".l")
          q (open f "r")
          (hot? q ? (rt-rdev (flow q), close q)
             (rt-die ("no backend aboard and no text at " + f)))))
   (rt-le8 v i acc) (i = 8 ? acc (rt-le8 (v >> 8) (i + 1) (acc + [(v & 255)])))

   ; a group: its members out of the roster, in roster order, compiled past every cache --
   ; make is the cache now. "mksys" names the laid member, which has no source.
   rt-home "src/apps/moon/"
   (rt-group dst tgt srcs)
    (: _ (rt-be tgt)
       m1 (cite 'moon 'rtmem1)
       want (map (f \ f = "mksys" ? "" f) srcs)
       es (filter (e \ elem (e 1) want) ((cite 'moon 'rtplan) rt-home tgt 'linux ()))
       _ (#es < #want && rt-die (show tgt + ": a source outside the roster in " + show srcs))
       (cite 'holo 'write-bytes dst [((cite 'holo 'arbytes) (map (m1 tgt 'linux ()) es))]))   ; one blob
   ; a group archive's members, ((name bytes)..), past the index and the long-name table
   (rt-armems s)
    (: fld (cite 'holo 'ld-arfld)
       next (cite 'holo 'ld-arnext)
       mem (cite 'holo 'ld-armem)
       lt ((cite 'holo 'ld-arlong) s)
       (go off acc) (? (#s < (off + 60)) (rev acc)
                       (elem (fld s off 16) '("/" "//")) (go (next s off) acc)
                       (go (next s off) ((mem s off lt) . acc)))
       (go 8 ()))
   (rt-read p)
    (: q (open p "r")
       (hot? q ? (slurp q @ s (close q, s)) (rt-die ("no group at " + p))))
   ; one ISA's archive, laid from the groups in roster order: the bytes of the old fan's
   (rt-isa tgt grps)
    (: (add t p) (foldl (t \ m \ pin t <m <>m) t (rt-armems (rt-read p)))
       t (foldl (t \ p \ (rev (split "/" p) 1 = string tgt ? (add t p) t)) {} grps)
       ms (map (e \ peep t <e () @ b
                     (string? b ? [<e b] (rt-die (show tgt + ": no group carries " + <e))))
               ((cite 'moon 'rtplan) rt-home tgt 'linux ()))
       ((cite 'holo 'arbytes) ms))

   ; one member: label len, label bytes, zero-padded so the next len lands
   ; 8-aligned (a riscv core may trap an unaligned word; the pad is free)
   ; the archive rides as a BLOB -- the string itself, one item holding every byte
   ; (holo.l's item-len) -- so a megabyte member costs a cell and not a million.
   (rt-forms nm s)
    (: n #s
       pad (8 - (n & 7) & 7)
       [['label (name ("rtgz_" + nm + "_len"))]
        ['raw (rt-le8 n 0 ())]
        ['label (name ("rtgz_" + nm))]
        ['raw [s (rt-zerostr pad "")]]])
   (rt-zerostr k acc) (k < 1 ? acc (rt-zerostr (k - 1) (string 0 + acc)))

   (mkrt arch dst grps)
    ; every archive arch joins, not just the object's: the image bakes the
    ; native backend only, and each ISA's members ride its own obj writer
    (: _ (rt-be arch)
       objelf (cite 'holo 'objelf)
       cid ((cite 'moon 'rtcid) rt-home)
       _ (!(string? cid) ? (rt-die "no src/apps/moon/ slice to hash -- run from the tree root"))
       ; deflated: ~1.5 MB of archive across the three ISAs becomes ~210 kB,
       ; and rtcarried pays one inflate for the ISA it wants.
       (one tgt) (: z (deflate (rt-isa tgt grps))
                    _ (!(string? z) ? (rt-die (show tgt + ": deflate refused the archive")))
                    z)
       forms (rt-forms "id" cid
              + rt-forms "x64" (one 'x64)
              + rt-forms "a64" (one 'a64)
              + rt-forms "rv64" (one 'rv64))
       xs '("rtgz_id" "rtgz_id_len"
            "rtgz_x64" "rtgz_x64_len"
            "rtgz_a64" "rtgz_a64_len"
            "rtgz_rv64" "rtgz_rv64_len")
       ob (objelf arch () () () xs () () () () () forms)
       (cite 'holo 'write-bytes dst ob))        ; ob is a byte list, not a string

   (mkrt-main av)
    (? (3 <= #av && <av = "-m") (rt-group (av 1) (name (av 2)) >>>av)
       (3 <= #av) (mkrt (name (av 1)) <av >>av)
       (rt-die "usage: mkrt.l -m GRP.a ISA SRC.. | mkrt.l OUT.o ARCH GRP.a.."))

   (mkrt-main >argv))
