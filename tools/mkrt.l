; tools/mkrt.l -- lay the compiled nolibc runtime into an ELF object, one
; deflated archive per hosted ISA, so a bare `love cc` links without compiling
; 197 members first (moon.l's rtcarried; src/host/src.c answers runtime-gz).
;
;   love wake out/mooncc0.image tools/mkrt.l out.o [arch]
;
; the object holds, per name in {id, x64, a64, rv64}, mksrc.l's pair
; shape 8-aligned:
;
;   ai_rtgz_<nm>_len   an 8-byte little-endian length
;   ai_rtgz_<nm>       the bytes, right behind it (a .a under DEFLATE; `id`
;                      is moon.l's rtcid of the tree slice, plain text)
;
; src/host/src.c declares every symbol weak, so a love carrying no runtime (love0)
; answers nothing and the compile-from-source lane stands. determinism is
; load-bearing: arbytes and rtcid are all pure of the machine, so the
; seed's fixpoint carries this object unchanged.
; this rides the mooncc image (wake), not the mksys cat: the archives are
; mooncc compiles, so the whole compiler must be aboard; arch names the object
; format (the LINK's arch), and a cross backend joins from its tree text the
; way mksrc.l joins one.

(: (rt-die m) (say err ("mkrt: " + m + "\n"), quit 1)
   (rt-rdev cl)
    (sound cl @ 'torn (rt-die "torn backend text")
                (a . u) (ev a, rt-rdev u))
   (rt-be arch)
    (? (lit? (from 'holo 'backends arch)) 0
       ; the backend file is the canonical arch word now -- one spelling, no map
       (: f ("src/core/holo/" + string arch + ".l")
          q (open f "r")
          (? (hot? q) (rt-rdev (flow q), close q)
             (rt-die ("no backend aboard and no text at " + f)))))
   (rt-bytes s i acc) (i < 0 ? acc (rt-bytes s (i - 1) (s i . acc)))
   (rt-le8 v i acc) (i = 8 ? acc (rt-le8 (v >> 8) (i + 1) (acc + [(v & 255)])))
   (rt-zeros k acc) (k < 1 ? acc (rt-zeros (k - 1) (0 . acc)))

   ; the archives are three independent mooncc runs -- a cold one is ~45 s and
   ; nothing in it reads another -- so build them at once and let the runtime
   ; cache be the join: a child's whole output is the entry it writes, which is
   ; what `one` below reads back. no cache directory, no fan-out: the work
   ; would die with the child. a fork we asked for and did not get leaves its
   ; target to `one`, one archive slower.
   (rt-fan rtarch cd ts)
    (? !(string? cd) ()
       (: _ (flush out, flush err)
          ps (rt-kids rtarch ts ())
          (foldl (\ _ p (wait p)) 0 ps)))
   (rt-kids rtarch ts acc)
    (? (one? ts) acc
       (: p (fork 0)
          (? (p = 0) (rtarch "src/apps/moon/" <ts 'linux (), quit 0)
             (0 < p) (rt-kids rtarch >ts (p . acc))
             acc)))

   ; one member: label len, label bytes, zero-padded so the next len lands
   ; 8-aligned (a riscv core may trap an unaligned word; the pad is free)
   (rt-forms nm s)
    (: n #s
       pad ((8 - (n & 7)) & 7)
       [['label (name ("ai_rtgz_" + nm + "_len"))]
        ['raw (rt-le8 n 0 ())]
        ['label (name ("ai_rtgz_" + nm))]
        ['raw (rt-bytes s (n - 1) (rt-zeros pad ()))]])

   (mkrt arch dst)
    ; every archive arch joins, not just the object's: the image bakes the
    ; native backend only, and each ISA's members ride its own obj writer
    (: _ (rt-be 'x64, rt-be 'a64, rt-be 'rv64, rt-be arch)
       rtcid (from 'moon 'rtcid)
       rtarch (from 'moon 'rtarch)
       objelf (from 'holo 'objelf)
       cid (rtcid "src/apps/moon/")
       _ (!(string? cid) ? (rt-die "no src/apps/moon/ slice to hash -- run from the tree root"))
       ; through rtarch, so the runtime cache serves a repeat build (~instant)
       ; and only a real slice or compiler change recompiles the members --
       ; without this every seed and rebake paid three full runtime compiles.
       cd ((from 'moon 'mcdir) ())
       _ (rt-fan rtarch cd '(x64 a64 rv64))
       ; deflated: ~1.5 MB of archive across the three ISAs becomes ~210 kB,
       ; and rtcarried pays one inflate for the ISA it wants.
       (one tgt) (: a (rtarch "src/apps/moon/" tgt 'linux ())
                    _ (!(string? a) ? (rt-die (show tgt + ": no archive (a member refused?)")))
                    z (deflate a)
                    _ (!(string? z) ? (rt-die (show tgt + ": deflate refused the archive")))
                    _ (say out $ "MKRT\t" + show tgt + " " + show #a + " -> " + show #z + "\n")
                    z)
       forms ((rt-forms "id" cid)
              + (rt-forms "x64" (one 'x64))
              + (rt-forms "a64" (one 'a64))
              + (rt-forms "rv64" (one 'rv64)))
       xs '("ai_rtgz_id" "ai_rtgz_id_len"
            "ai_rtgz_x64" "ai_rtgz_x64_len"
            "ai_rtgz_a64" "ai_rtgz_a64_len"
            "ai_rtgz_rv64" "ai_rtgz_rv64_len")
       ob (objelf arch () () () xs () () () () () forms)
       _ ((from 'holo 'write-bytes) dst ob)     ; ob is a byte list, not a string
       (say out ("MKRT\t" + dst + "\n")))

   (mkrt-main av)
    (: n #av
       (1 <= n ? (mkrt (2 <= n ? (name <>av) 'x64) <av)
        (rt-die "usage: love wake out/mooncc0.image tools/mkrt.l OUT.o [ARCH]")))

   (mkrt-main >argv))
