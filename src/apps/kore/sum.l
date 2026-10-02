; src/apps/kore/sum.l -- the checksum tools: cksum, sum, crc32, md5sum, sha1sum, sha224sum,
; sha256sum, sha384sum, sha512sum, b2sum, sha3sum, in GNU's faces, and the -c lane that reads
; those lines back. the digests are src/love/lib/hash.c's nifs; an image without them (the
; kernel's) says which one is missing and leaves with 2.
; loads after fs.l for udirp. a body-less top-level `:` -- the mains leak, kore.l
; registers them.
(module 'kore
(borrow 'posix)

(:
   ; --- the digest door ------------------------------------------------------
   ; the probe is asked at first call and kept, never at load: this file is baked
   ; into the artifact by a love that has the nifs, so a load-time answer would be the
   ; baking love's and not the running one's. src/apps/gz.l's gz-nif, the same reasoning --
   ; and the same reason each probe is a lambda: an unbound global scares when it is
   ; referenced, not when the function around it is compiled.
   sum-door {}
   sum-ckp (_ \ (cksum ""))
   sum-md5p (_ \ (md5 ""))
   sum-shap (_ \ (sha256 ""))
   sum-sha1p (_ \ (sha1 ""))
   sum-sha224p (_ \ (sha224 ""))
   sum-sha384p (_ \ (sha384 ""))
   sum-sha512p (_ \ (sha512 ""))
   sum-b2p (_ \ (blake2b ""))
   sum-bsdp (_ \ (bsdsum 0 ""))
   sum-sha3p (_ \ (sha3 ""))
   sum-crcp (_ \ (crc32-on 0 ""))
   (sum-nif k f)
    (peep sum-door k () @ v
       (charm? v ? v
        ((trap (_ \ (f 0, 1)) () (\ a b 0)) @ w
           (pin sum-door k w, w))))
   (sum-have who nm k probe) (sum-nif k probe ? 0 (udie 2 (who + ": this image carries no " + nm)))

   ; the triples live inside lambdas for the reason the probes do: an unbound global
   ; scares when it is referenced, and this file is baked by a love that has the nifs
   ; into an image that may not. [state-width init feed done].
   (sum-shad _) [105 sha256-init sha256-feed sha256-done]
   (sum-md5d _) [89  md5-init    md5-feed    md5-done]
   (sum-ckd _)  [12  cksum-init  cksum-feed  cksum-done]
   (sum-sha1d _)   [93  sha1-init   sha1-feed   sha1-done]
   (sum-sha224d _) [106 sha224-init sha224-feed sha224-done]
   (sum-sha384d _) [202 sha384-init sha384-feed sha384-done]
   (sum-sha512d _) [201 sha512-init sha512-feed sha512-done]
   (sum-b2d n)     [210 (b \ (blake2b-init b n)) blake2b-feed blake2b-done]
   (sum-sha3d n sh) [204 (b \ (sha3-init b n sh)) sha3-feed sha3-done]

   ; one operand folded a gulp at a time -> [acc bytes] | 'dir | the open's nom. "-"
   ; is stdin, as it is everywhere in kore. a 100 MB file goes past a gulp at a time
   ; and is never held; the byte count rides out because cksum's and sum's lines say it.
   ; 'dir is its own answer because a directory opens and reads empty -- digested, it
   ; would be the digest of nothing, a plausible wrong number rather than a miss.
   (sum-fold f step z)
    (udirp f ? 'dir
     ((f = "-" ? [in 0] (open f "r" @ q (hot? q ? [q 1] q))) @ p
        (atom? p ? p
         (: rd (urd <p)
            (go a n) (: h (urd-gulp rd) k #h
                        (k ? (go (step a h) (n + k)) [a n]))
            r (go z 0)
            (<>p ? (close <p) 0,
             r)))))
   ; ..through a digest, its state a cask of tens of bytes -> [digest bytes] | as above
   (sum-run mk f)
    (: d (mk 0)
       b (cask <d)
       _ (<>d b)
       r (sum-fold f (\ c h (<>>d c h)) b)
       (atom? r ? r
        (<>>>d b @ v (v = () ? () [v <>r]))))
   ; the -c list is read whole, and should be: it is a list of digests, never the thing
   ; digested. one line a file, and nobody writes a gigabyte of them.
   (sum-list f)
    (? (f = "-") [1 (slurp in + "")]
       (udirp f) 'dir
       (uread f @ r (two? r ? [1 (<>r + "")])))
   (sum-nope who f r)
    (say err (who + ": " + f + ": " + (? (r = 'dir) "Is a directory" (nom? r) (uerrno r) "cannot open")), put err 10)

   ; --- the two output faces -------------------------------------------------
   ; cksum says the byte count too, and says no name for stdin (GNU's face exactly)
   (sum-ckline v n f) (show v + " " + show n + (#f ? (" " + f) "") + "\n")
   (sum-hexline v n f) (v + "  " + f + "\n")

   ; --- the digest lane ------------------------------------------------------
   ; every operand onto out; sn names stdin in the no-operand lane. one unreadable
   ; file complains and costs the status, the rest still run.
   (sum-say who line mk sn as)
    (: (row f nm ok)
        (sum-run mk f @ r
           (two? r ? (say out (line <r <>r nm), ok)
            (sum-nope who f r, 0)))
       (go a ok) (two? a ? (go >a (row <a <a ok)) (flush out, ok ? 0 1))
       (two? as ? (go as 1)
        (row "-" sn 1, flush out, 0)))

   ; --- the -c lane ----------------------------------------------------------
   ; a line is n hex digits, two characters (two spaces, or " *" where the writer
   ; called it binary), then the name. the shape is asked in full -- the digits
   ; counted and read -- because a looser split takes any line with a space in it for
   ; a checksum line, and a file of prose then reads as a list of failures instead of
   ; the "no checksum lines here" it is. an upper-case list is a list.
   (sum-lower s)
    (jug 0 @ o (each ^#s (k \ (s k @ c (put o (64 < c && c < 71 ? (c + 32) c)))), slurp o))
   (sum-hex? l n)
    (: (go k) (n <= k ? 1
               (l k @ c
                  (47 < c && c < 58 || 96 < c && c < 103 || 64 < c && c < 71 ?
                     (go (k + 1)) 0)))
       (go 0))
   ; n 0 is b2sum's: any length it could have written, the hex run before the space,
   ; even and at most 128 digits
   (sum-split l n0)
    (: t #l
       (run k) (k < t && sum-hex? (snip l k (k + 1)) 1 ? (run (k + 1)) k)
       n (n0 ? n0 (run 0 @ k (1 < k && k <= 128 && k % 2 = 0 ? k t)))
       c (n + 1 < t ? (l (n + 1)) 0)
       (n + 2 < t ? (l n = 32 && (c = 32 || c = 42) && sum-hex? l n ?
                         [(sum-lower (snip l 0 n)) (snip l (n + 2) t)])))
   ; the lists read back. the state is [bad unread seen sour]: lines that did not match,
   ; files named in a line that could not be read, lines that were checksum lines at
   ; all, and lists that were no good. sour is its own count because it costs the
   ; status and says nothing: the two warnings below are each a claim about lines, and
   ; a list nobody could read has none to make a claim about.
   ; o: --quiet drops the OK lines, --status every line and warning, --ignore-missing a
   ; listed file that is not there, --strict fails on a line that is no checksum line
   ; and -w says each such line, by its list and number
   (sum-check who mk n as o)
    (: (row l st)
        (: p (sum-split l n)
           bad <st unread <>st seen <>>st sour <>>>st
           (atom? p ? (pin o 'ln (peep o 'ln 0 + 1),
                       pin o 'ill (peep o 'ill 0 + 1),
                       (o 'w && !(o 'status) ? (say err (who + ": " + o 'nm + ": " + show (o 'ln) + ": improperly formatted "
                                                         + upper (snip who 0 (#who - 3)) + " checksum line\n")) 0),
                       st)
            (: _ (pin o 'ln (peep o 'ln 0 + 1))
               said <p f <>p r (sum-run (mk #said) f)
               (say1 m) (o 'status ? 0 (say out (f + m + "\n")))
               (? (atom? r) (o 'miss && r = 'enoent ? [bad unread seen sour]
                             (o 'status ? 0 (sum-nope who f r), say1 ": FAILED open or read", [bad (unread + 1) (seen + 1) sour]))
                  (<r = said) (o 'quiet ? 0 (say1 ": OK"), [bad unread (seen + 1) sour])
                  (say1 ": FAILED", [(bad + 1) unread (seen + 1) sour])))))
       (over ls st) (two? ls ? (over >ls (row <ls st)) st)
       ; one list, and GNU's complaint where nothing in it was a checksum line
       (list1 nm text st)
        (: was <>>st
           _ (pins o 'nm nm 'ln 0)
           s2 (over (lines text) st)
           (was < <>>s2 ? s2
            (say err (who + ": " + nm + ": no properly formatted checksum lines found"), put err 10, [<s2 <>s2 <>>s2 (<>>>s2 + 1)])))
       (walk a st)
        (atom? a ? st
         (sum-list <a @ r
            (two? r ? (walk >a (list1 <a <>r st))
             (sum-nope who <a r, walk >a [<st <>st <>>st (<>>>st + 1)]))))
       st (two? as ? (walk as [0 0 0 0]) (list1 "standard input" (slurp in + "") [0 0 0 0]))
       bad <st unread <>st sour <>>>st
       _ (flush out)
       ill (peep o 'ill 0)
       ((o 'status ? 0
         ; a list with no checksum line at all has said so, and says no count of them
         (0 < ill && 0 < <>>st ? (sum-warn who ill "line" (ill = 1 ? " is improperly formatted" " are improperly formatted")) 0,
          0 < unread ? (sum-warn who unread "listed file" " could not be read") 0,
          0 < bad ? (sum-warn who bad "computed checksum" " did NOT match") 0)),
        flush err,
        0 < bad || 0 < unread || 0 < sour || o 'strict && 0 < ill ? 1 0))
   ; "1 listed file could not be read", "2 listed files could not be read" -- the noun
   ; takes the s and the verb does not, which holds for both warnings GNU says here
   (sum-warn who n what tail)
    (say err (who + ": WARNING: " + show n + " " + what + (n = 1 ? "" "s") + tail), put err 10)

   ; --- the mains ------------------------------------------------------------
   ; the digest tools share a front: -c reads a list back, anything else digests operands
   ; -b marks a digest binary (a * before the name), -t text (the default two spaces);
   ; with -c, the flags sum-check reads
   (sum-front who nm k probe mk n as)
    (: fo (uflagsl who as () (chars "bctw" + [1001 1002 1003 1004]) {"check" 99 "binary" 98 "text" 116 "warn" 119 "quiet" 1001 "status" 1002
                                     "ignore-missing" 1003 "strict" 1004})
       t <fo
       o {'quiet (t 1001) 'status (t 1002) 'miss (t 1003) 'strict (t 1004) 'w (t 119)}
       line (t 98 ? (\ v n f (v + " *" + f + "\n")) sum-hexline)
       (sum-have who nm k probe, (t 99 ? (sum-check who (_ \ mk) n (fo 1) o)
           (sum-say who line mk "-" (fo 1)))))
   (cksum-main as) (sum-have "cksum" "cksum" 0 sum-ckp, sum-say "cksum" sum-ckline sum-ckd "" (uflags "cksum" as () "" 1))
   (md5sum-main as) (sum-front "md5sum" "md5" 1 sum-md5p sum-md5d 32 as)
   (sha256sum-main as) (sum-front "sha256sum" "sha256" 2 sum-shap sum-shad 64 as)
   (sha1sum-main as) (sum-front "sha1sum" "sha1" 3 sum-sha1p sum-sha1d 40 as)
   (sha224sum-main as) (sum-front "sha224sum" "sha224" 4 sum-sha224p sum-sha224d 56 as)
   (sha384sum-main as) (sum-front "sha384sum" "sha384" 5 sum-sha384p sum-sha384d 96 as)
   (sha512sum-main as) (sum-front "sha512sum" "sha512" 6 sum-sha512p sum-sha512d 128 as)

   ; b2sum: blake2b, 512 bits or -l's (a multiple of 8, 0 the default). -c reads a
   ; line of any length b2sum could have written, unless -l pins one
   (b2sum-main as)
    (: _ (sum-have "b2sum" "blake2b" 7 sum-b2p)
       (bad w m) (udie 1 ("b2sum: invalid length: '" + w + "'" + (#m ? ("\nb2sum: " + m) "")))
       (bits w) (unum w @ v
                   (? !(charm? v) (bad w "")
                      (512 < v) (bad w "maximum digest length for 'BLAKE2b' is 512 bits")
                      (v % 8) (bad w "length is not a multiple of 8")
                      v))
       fo (uflagsl "b2sum" as '(108) (chars "bctwl" + [1001 1002 1003 1004]) {"check" 99 "length" 108 "binary" 98 "text" 116 "warn" 119 "quiet" 1001
                                              "status" 1002 "ignore-missing" 1003 "strict" 1004})
       t <fo ops (fo 1)
       o {'quiet (t 1001) 'status (t 1002) 'miss (t 1003) 'strict (t 1004) 'w (t 119)}
       l (uoptv t 108 @ v (v ? (bits v) 0)) nn (l ? (l // 8) 64)
       (t 99 ? (sum-check "b2sum" (l ? (_ \ (_ \ (sum-b2d nn))) (k \ (_ \ (sum-b2d (k // 2)))))
                          (l ? (2 * nn) 0) ops o)
        (sum-say "b2sum" (t 98 ? (\ v n f (v + " *" + f + "\n")) sum-hexline) (_ \ (sum-b2d nn)) "-" ops)))

   ; sha3sum: toybox's -a BITS (224 by default, 128..512), -b the digest alone, -S shake's
   ; pad; busybox's -c beside them, reading a list of the length -a says
   (sha3sum-main as)
    (: _ (sum-have "sha3sum" "sha3" 9 sum-sha3p)
       (bad m) (udie 1 ("sha3sum: " + m + " (see \"sha3sum --help\")"))
       (bits w) (unum w @ v
                   (? !(charm? v) (bad ("-a '" + w + "'")) (v < 128) (bad "-a < 128") (512 < v) (bad "-a > 512") v))
       (go a o)
        (atom? a ? o
         (: w <a n #w
            (? (w = "--") (pin o 'fs (o 'fs + >a), o)
               (w = "-a") (two? >a ? (pin o 'a (bits <>a), go >>a o) (bad "Missing argument to -a"))
               (1 < n && w 0 = 45)
                (: (cl k) (? (n <= k) (go >a o)
                             (w k = 97) (pin o 'a (bits (? (k + 1 < n) (snip w (k + 1) n) (two? >a) <>a "")), go (k + 1 < n || atom? >a ? >a >>a) o)
                             (elem (w k) "bSc") (pin o (w k @ 98 'b 83 'S 'c) 1, cl (k + 1))
                             (bad ("Unknown option '" + string (w k) + "'")))
                   (cl 1))
               (pin o 'fs (o 'fs + [w]), go >a o))))
       o (go as {'a 224 'fs ()})
       mk (_ \ (sum-sha3d (o 'a) (o 'S)))
       (o 'c ? (sum-check "sha3sum" (_ \ mk) (2 * (o 'a // 8)) (o 'fs) {})
        (sum-say "sha3sum" (o 'b ? (\ v n f (v + "\n")) sum-hexline) mk "-" (o 'fs))))

   ; crc32: toybox's -- zlib's crc of each file, eight hex digits and the name
   (crc32-main as)
    (: _ (sum-have "crc32" "crc32" 10 sum-crcp)
       (row f nm ok)
        (sum-fold f crc32-on 0 @ r
           (two? r ? (say out (zpad 8 (radix <r 16) + (#nm ? (" " + nm) "") + "\n"), ok)
            (sum-nope "crc32" f r, 0)))
       (walk a ok) (two? a ? (walk >a (row <a <a ok)) ok)
       ok (two? as ? (walk as 1) (row "-" "" 1))
       (flush out,
        ok ? 0 1))

   ; sum: bsd's 16-bit rotating checksum over 1024-byte blocks (-r, the default), or
   ; system v's byte total folded to 16 bits over 512-byte blocks (-s, --sysv), the
   ; last one given winning; a name is said for a named operand only, "-" included
   (sum-main as)
    (: _ (sum-have "sum" "bsdsum" 8 sum-bsdp)
       (usage m) (udie 1 ("sum: " + m + "\nTry 'sum --help' for more information."))
       (flags w k sv) (? (#w <= k) sv
                         (w k = 114) (flags w (k + 1) 0)
                         (w k = 115) (flags w (k + 1) 1)
                         (usage ("invalid option -- '" + string (w k) + "'")))
       (go a sv ops)
        (atom? a ? [sv (rev ops)]
         (: w <a n #w
            (? (w = "--") [sv (rev ops + >a)]
               (w = "--sysv") (go >a 1 ops)
               (2 < n && snip w 0 2 = "--") (usage ("unrecognized option '" + w + "'"))
               (1 < n && w 0 = 45) (go >a (flags w 1 sv) ops)
               (go >a sv (w . ops)))))
       r (go as 0 ())
       sv <r fs <>r
       (pad w c s) (w <= #s ? s (pad w c (string c + s)))
       (line v n nm)
        ((sv ? (: t (v & 4294967295) q ((t & 65535) + (t >> 16)) (show ((q & 65535) + (q >> 16)) + " " + show ((n + 511) // 512)))
            (pad 5 48 (show v) + " " + pad 5 32 (show ((n + 1023) // 1024))))
         + (#nm ? (" " + nm) "") + "\n")
       (row f nm ok)
        (sum-fold f (sv ? (\ a h (a + net h)) bsdsum) 0 @ r
           (two? r ? (say out (line <r <>r nm), ok)
            (sum-nope "sum" f r, 0)))
       (walk a ok) (two? a ? (walk >a (row <a <a ok)) ok)
       ok (two? fs ? (walk fs 1) (row "-" "" 1))
       (flush out,
        ok ? 0 1)))
) ; module 'kore
