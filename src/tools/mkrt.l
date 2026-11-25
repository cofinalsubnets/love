; src/tools/mkrt.l -- lay the compiled moonlibc runtime into an ELF object, one zstd frame of
; archive per hosted ISA against the build ISA's, so a bare `love cc` links without compiling its
; members first.
;
;   love wake out/mooncc0.image src/tools/mkrt.l -m GRP.a ISA SRC..   one group's members
;   love wake out/mooncc0.image src/tools/mkrt.l out.o ARCH GRP.a..   the join
;
; a group is a few members of one ISA (out/rt/<isa>/<grp>.a); the join reads every group,
; the ISA off its directory, and lays one table, rtzst_tab (its length rtzst_tab_len), of
; entries `id`, `base`, then each ISA the groups name, an empty name ending it:
;
;   16 bytes   the name, zero-padded
;   16 bytes   the reference the frame decodes against, zero-padded: empty for the base's
;   8 bytes    the length, little-endian
;   n bytes    the entry, zero-padded to 8 (a riscv core may trap unaligned): `base` the build
;              ISA's .a as one zstd frame, each ISA's .a a frame against its reference's, `id`
;              moon.l's rtcid
;
; an ISA's reference is its nearest kin when the groups carry it (rt-refs), else the base
; a link with no runtime names src/love/noblob.c instead. arbytes and rtcid are pure of
; the machine, so the seed's fixpoint carries this object unchanged. arch names the
; object format; a cross backend joins from its tree text.

(borrow '(posix zstd))
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

   ; a group: its members in roster order, compiled past every cache (make is the cache).
   ; "mksys" names the laid member, which has no source.
   rt-home "src/apps/moon/"
   (rt-group dst tgt srcs)
    (: _ (rt-be tgt)
       m1 (cite 'moon 'rtmem1)
       want (map (f \ f = "mksys" ? "" f) srcs)
       es (filter (e \ elem (e 1) want) ((cite 'moon 'rtplan) rt-home tgt 'linux ()))
       _ (#es < #want && rt-die (show tgt + ": a source outside the roster in " + show srcs))
       ; laid beside and renamed onto: a link's -rt never reads a torn group
       tmp (dst + "." + show (getpid 0))
       (cite 'holo 'write-bytes tmp [((cite 'holo 'arbytes) (map (m1 tgt 'linux ()) es))],
        rename tmp dst))
   ; a group archive's members, ((name bytes)..), past the index and long-name table
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
   ; one ISA's archive, laid from the groups in roster order
   (rt-isa tgt grps)
    (: (add t p) (foldl (t \ m \ pin t <m <>m) t (rt-armems (rt-read p)))
       t (foldl (t \ p \ (rev (split "/" p) 1 = string tgt ? (add t p) t)) {} grps)
       ms (map (e \ peep t <e () @ b
                     (string? b ? [<e b] (rt-die (show tgt + ": no group carries " + <e))))
               ((cite 'moon 'rtplan) rt-home tgt 'linux ()))
       ((cite 'holo 'arbytes) ms))

   ; one entry: its name, its reference, its length, its bytes padded to 8; the bytes ride as
   ; one blob item
   (rt-forms nm ref s)
    (: n #s
       pad (8 - (n & 7) & 7)
       [['raw [(nm + rt-zerostr (16 - #nm) "") (ref + rt-zerostr (16 - #ref) "")]]
        ['raw (rt-le8 n 0 ())]
        ['raw [s (rt-zerostr pad "")]]])
   ; the kin a frame shares most with, each a step past x64's: thumb2 is arm's code without
   ; linux, thumb2sp thumb2's with its f64 softened
   rt-refs {"thumb2" "arm" "thumb2sp" "thumb2"}
   (rt-zerostr k acc) (k < 1 ? acc (rt-zerostr (k - 1) (string 0 + acc)))
   ; a raw item's byte count: a list of numbers, or of strings laid whole
   (rt-rawlen r) (foldl (a \ x \ a + (string? x ? #x 1)) 0 r)

   (mkrt arch dst grps)
    (: _ (rt-be arch)
       objelf (cite 'holo 'objelf)
       cid ((cite 'moon 'rtcid) rt-home)
       _ (!(string? cid) ? (rt-die "no src/apps/moon/ slice to hash -- run from the tree root"))
       (z? tgt z) (string? z ? z (rt-die (show tgt + ": zstd refused the archive")))
       ; the ISAs share most of their bytes, so each is a frame against the build ISA's archive
       ; or a kin's, and runtime-ar pays a decode per step to the base
       isas (foldl (a \ p \ rev (split "/" p) 1 @ i (elem i a ? a (a + [i]))) () grps)
       _ (!(elem (string arch) isas) && rt-die (string arch + ": the build isa is the base, so rt_isas must name it"))
       base (rt-isa arch grps)
       _ (foldl (a \ i \ a || 16 <= #i && rt-die (i + ": a name the table cannot hold")) 0 isas)
       (ref i) (rt-refs i @ k (string? k && elem k isas ? k "base"))
       (one i) (: a (string arch = i ? base (rt-isa (name i) grps))
                  r (ref i @ k (k = "base" ? base (rt-isa (name k) grps)))
                  (z? i (zstde-by a r 19)))
       ents (rt-forms "id" "" cid
             + rt-forms "base" "" (z? arch (zstde base 19))
             + foldl (a \ i \ a + rt-forms i (ref i) (one i)) () isas
             + [['raw [(rt-zerostr 40 "")]]])
       ; the length rides after the table, which runtime-ar walks by it
       forms ([['label 'rtzst_tab]] + ents
              + [['label 'rtzst_tab_len] ['raw (rt-le8 (foldl (a \ f \ a + rt-rawlen (f 1)) 0 ents) 0 ())]])
       ob (objelf arch () () () ["rtzst_tab" "rtzst_tab_len"] () () () () () forms)
       (cite 'holo 'write-bytes dst ob))        ; a byte list, not a string

   (mkrt-main av)
    (? (3 <= #av && <av = "-m") (rt-group (av 1) (name (av 2)) >>>av)
       (3 <= #av) (mkrt (name (av 1)) <av >>av)
       (rt-die "usage: mkrt.l -m GRP.a ISA SRC.. | mkrt.l OUT.o ARCH GRP.a.."))

   (mkrt-main >argv))
