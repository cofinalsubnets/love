; src/apps/hearts/image.l -- rung 0's image: a GPT disk for qemu virt (a64), and the signed
; updates that move it. the disk:
;   1 ESP (FAT32): EFI/BOOT/BOOTAA64.EFI (src/inle/uefi/slot.c), a/Image, a/cmd, hearts.st
;   2 root a, 3 root b (squashfs, deflated; b empty until an update writes it), 4 data (FAT32)
; a root: love as /bin/love, helm's script as init (/bin/helm), src/apps/hearts/dev.l and app.l, the update key.
; the parts lie back to back from 1 MiB, each `at` where the one before it ends.
; usage: love -l src/apps/sqfs.l image.l OUT LOVE IMAGE EFI SEED BADSEED [STAMP]
;   writes OUT/disk.img (v1 in slot a) and OUT/u1.hup (v2 signed by BADSEED, refused),
;   OUT/u2.hup (v2 with a byte of its root changed under a good head, refused), OUT/u3.hup (v2)
;   and OUT/u4.hup (v3, sick); LOVE is a baked a64 love, IMAGE the kernel,
;   EFI the chooser, SEED and BADSEED 32-byte keys as hex, STAMP the one time every file
;   carries (seconds, default 0): the same inputs give the same bytes on any host.
(borrow 'bytes)
(borrow 'posix)
(borrow 'gz)
(borrow 'fat)
(borrow 'sqfs)
(: ; its words are the ones after its own name, whatever loaded ahead of it
   (after l) (atom? l ? () (<l @ (_ + "image.l") >l (after >l)))
   as (after cmdline)
   ; by name: a borrow of 'ssh would bring its own split
   ed-sign (cite 'ssh 'ed-sign)
   ed-pub (cite 'ssh 'ed-pub)
   (gone s) (say err ("hearts-image: " + s + "\n"), quit 1)
   (rd f) (uread f @ r (two? r ? <>r (gone ("cannot read " + f))))
   (le v n) (wrle v n)
   mib 2048                                          ; sectors

   ; --- GPT --------------------------------------------------------------------
   ; a guid as the disk holds one: the first three fields little-endian
   (guidb s) (: (rv b) (foldl (a \ i \ string (b i) + a) "" ^#b)
                (split "-" s @ [a b c d e] (rv (hex2b a) + rv (hex2b b) + rv (hex2b c) + hex2b d + hex2b e)))
   esp-type (guidb "C12A7328-F81F-11D2-BA4B-00A0C93EC93B")
   linux-type (guidb "0FC63DAF-8483-4772-8E79-3D69D8477DE4")
   (made name) (snip (hex2b (sha256 ("hearts rung 0 " + name))) 0 16)   ; the same ids every build
   (u16name s) (join "" (map (c \ le c 2) (map (i \ s i) ^#s)))
   (entry p) (p @ [nm ty at n _]
               (ty + made nm + le at 8 + le (at + n - 1) 8 + le 0 8
                + (u16name nm @ w (w + zbytes (72 - #w)))))
   (entries ps) (: e (join "" (map entry ps)) (e + zbytes (128 * 128 - #e)))
   (header me alt total ents tbl)
    (: (fn c) ("EFI PART" + le 0x10000 4 + le 92 4 + le c 4 + le 0 4 + le me 8 + le alt 8
                 + le 34 8 + le (total - 34) 8 + made "disk" + le tbl 8 + le 128 4 + le 128 4
                 + le (gz-crc32 ents) 4)
       (fn (gz-crc32 (fn 0)) @ h (h + zbytes (512 - #h))))
   (pmbr total) (zbytes 446 + string 0 + string 0 + string 2 + string 0 + string 0xEE
                 + string 0xFF + string 0xFF + string 0xFF + le 1 4 + le (min (total - 1) 0xFFFFFFFF) 4
                 + zbytes 48 + string 0x55 + string 0xAA)

   ; the disk written front to back: each part padded to its slot, the backup table at the end
   (disk path ps total)
    (: ents (entries ps)
       p (open path "w")
       _ (hot? p ? 0 (gone ("cannot write " + path)))
       (pad n) (n > 0 ? (zbytes (min n (8 * 1048576)) @ z (say p z, pad (n - #z))))
       _ (say p (pmbr total), say p (header 1 (total - 1) total ents 2), say p ents)
       _ (pad ((mib - 34) * 512))
       _ (each ps (q \ q @ [nm ty at n b] (say p b, pad (n * 512 - #b))))
       _ (pad ((total - 33 - (mib + net (map (q \ q 3) ps))) * 512))
       (say p ents, say p (header (total - 1) 1 total ents (total - 33)), close p))

   ; --- FAT, laid in memory --------------------------------------------------
   (fatimg nsec files)
    (: im (cask (nsec * 512))
       dev [(lba \ k \ (cask (k * 512) @ b (pour b 0 im (lba * 512) (k * 512), string b)))
            (lba \ s \ (pour im (lba * 512) s 0 #s, #s // 512)) nsec (stamp * 1000)]
       _ (fat-mkfs dev || gone "fat-mkfs refused")
       f (fat-mount dev)
       (dirs path) (: ws (split "/" path)
                     (go acc l) (two? >l ? (fat-mkdir f (acc + <l), go (acc + <l + "/") >l) 0)
                     (go "" ws))
       _ (each files (x \ x @ [path b] (dirs path, fat-write f path b || gone ("fat-write " + path))))
       (string im))

   ; --- a root ---------------------------------------------------------------
   helm-conf """
     (oneshot mounts (exec "/bin/love" "/lib/hearts/dev.l" "mount"))
     (service watch (after mounts) (exec "/bin/love" "/lib/hearts/dev.l" "watch" "20") (restart no))
     (service app (after mounts) (exec "/bin/love" "/app/run.l") (restart no))
     (target default (wants mounts watch app))
     """
   (dir kids) ['dir 493 kids]
   (fil mode b) ['file mode b]
   (root love ver sick pub)
    (dir [["app" (dir [["run.l" (fil 420 (rd "src/apps/hearts/app.l"))]])]
        ["bin" (dir [["helm" (fil 493 helm)] ["love" (fil 493 love)]])]
        ["boot" (dir ())] ["data" (dir ())] ["dev" (dir ())] ["drop" (dir ())]
        ["etc" (dir ((sick ? [["sick" (fil 420 "")]] ())
                   + [["hearts.pub" (fil 420 pub)] ["helm.l" (fil 420 helm-conf)]
                      ["version" (fil 420 (ver + "\n"))]]))]
        ["lib" (dir [["hearts" (dir [["dev.l" (fil 420 (rd "src/apps/hearts/dev.l"))]])]])]
        ["proc" (dir ())] ["run" (dir ())] ["sys" (dir ())] ["tmp" (dir ())]
        ["usr" (dir [["bin" (dir ())]])]])
   ; helm is four files catted into one script, run by love as the kernel's init
   helm ("#!/bin/love\n" + join "" (map rd ["src/apps/helm/unit.l" "src/apps/helm/sup.l"
                                            "src/apps/helm/moor.l" "src/apps/helm/helm.l"]))
   cmd "console=ttyAMA0 rootfstype=squashfs ro rootwait panic=5 init=/bin/helm"

   ; --- an update: a signed 4K head, then the parts, as dev.l streams them ---------
   ; a part is [enc bytes raw]: enc 1 when bytes are raw deflated
   (hup seed ps)
    (: (ent p) (p @ [enc b raw] (le enc 8 + le #b 8 + le #raw 8 + hex2b (sha256 raw)))
       hd ("hearts-update 2\n" + join "" (map ent ps))
       head (hd + ed-sign seed (ed-pub seed) hd @ h (h + zbytes (4096 - #h)))
       body (head + join "" (map (p \ p 1) ps))
       (body + zbytes (padk #body 4096)))

   odir (as 0)
   love (rd (as 1))
   kernel (rd (as 2))
   efi (rd (as 3))
   seed (hex2b (as 4))
   bad (hex2b (as 5))
   stamp (#as > 6 ? (read (as 6)) 0)
   pub (ed-pub seed)
   (rootimg ver sick) (sqfs-make (root love ver sick pub) stamp 'zlib)
   r1 (rootimg "v1" 0)
   r2 (rootimg "v2" 0)
   r3 (rootimg "v3" 1)
   rsz (32 * mib)
   _ (#r1 <= rsz * 512 || gone "a root outgrows its slot")
   ; the kernel travels deflated, the root as it is (squashfs deflates its own blocks)
   kz (deflate-best kernel @ z (string? z ? z (gone "cannot deflate the kernel")))
   (upd r) [[1 kz kernel] [0 r r] [0 cmd cmd]]
   (flip s i) (snip s 0 i + string (255 - s i) + snip s (i + 1) #s)
   esp (fatimg (128 * mib) [["EFI/BOOT/BOOTAA64.EFI" efi] ["a/Image" kernel]
                            ["a/cmd" (cmd + " root=/dev/vda2\n")] ["hearts.st" "a-\n"]])
   data (fatimg (64 * mib) ())
   ps [["esp" esp-type mib (128 * mib) esp]
       ["root-a" linux-type (129 * mib) rsz r1]
       ["root-b" linux-type (161 * mib) rsz ""]
       ["data" linux-type (193 * mib) (64 * mib) data]]
   total (257 * mib + 34)
   (disk (odir + "/disk.img") ps total,
    uwrite (odir + "/u1.hup") (hup bad (upd r2)),
    uwrite (odir + "/u2.hup") (flip (hup seed (upd r2)) (4096 + #kz + 4096)),
    uwrite (odir + "/u3.hup") (hup seed (upd r2)),
    uwrite (odir + "/u4.hup") (hup seed (upd r3)),
    say err "hearts-image: disk.img and four updates\n"))
