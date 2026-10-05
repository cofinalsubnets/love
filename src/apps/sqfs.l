; src/apps/sqfs.l -- squashfs 4.0, written: a tree in, an image out, the same bytes for
; the same tree. every file is root's and every time is one stamp; blocks are stored, no
; fragments, no export table, no xattrs.
;   (sqfs-make tree stamp)  -> the image, padded to 4K
;   (sqfs-tree path)        -> a host directory as a tree (modes kept; owners and times not)
; a node: ['dir mode kids] with kids [name node] .., ['file mode bytes], ['link target]
(module (sqfs sqfs-make sqfs-tree)
(borrow 'bytes)
(borrow 'posix)
(: bsize 131072
   mblk 8192                                       ; a metadata block's payload
   (oops m) (say err ("sqfs: " + m + "\n"), quit 1)
   (le v n) (wrle v n)
   ; a stream position names its block and offset: a stored block is its payload and a header
   (mstart p) (p // mblk * (mblk + 2))
   (mref p) ((mstart p << 16) | (p % mblk))
   (nk k) (k @ 'd 'dn 'i 'in 'rn)                      ; a stream's length, by its name
   (add st k s) (pin st k (s . st k), pin st (nk k) (st (nk k) + #s))
   (pos st k) (st (nk k))
   (whole st k) (join "" (rev (st k)))
   (blocks s) (#s = 0 ? ""
                 (snip s 0 (min mblk #s) @ c (le (#c | 0x8000) 2 + c + blocks (snip s #c #s))))
   (take st) (st 'n @ i (pin st 'n (i + 1), i))
   (count nd) (nd 0 = 'dir ? (foldl (a \ c \ a + count (c 1)) 1 (nd 2)) 1)
   (ihead st ty mode ino) (le ty 2 + le (mode & 4095) 2 + le 0 2 + le 0 2 + le (st 't) 4 + le ino 4)
   (inode st s) (pos st 'i @ p (add st 'i s, mref p))

   ; a listing as mksquashfs lays one: a header opens a run that shares its inodes' block, holds
   ; at most 256 and keeps their numbers within an i16 of its base, and a run is also cut where
   ; the bytes since the last index point would pass a block, which records one. es are
   ; [name ino ref type]; answers [bytes points], a point [offset name]
   (listing es)
    (: (head r) (r @ [blk base l] (le (#l - 1) 4 + le blk 4 + le base 4
                   + join "" (map (e \ e @ [nm ino ref ty] (le (ref & 65535) 2 + le (ino - base) 2
                                     + le ty 2 + le (#nm - 1) 2 + nm)) (rev l))))
       (near d) (-32768 <= d && d <= 32767)
       (go es rs cur p ip ix)
        (atom? es ? [(join "" (map head (rev (two? cur ? (cur . rs) rs)))) (rev ix)]
           (: e <es nm (e 0)
              far (two? cur && p + 8 + #nm - ip > mblk)
              (? (two? cur && #(cur 2) < 256 && cur 0 = (e 2 >> 16) && near (e 1 - cur 1) && !far)
                   (go >es rs [(cur 0) (cur 1) (e . cur 2)] (p + 8 + #nm) ip ix)
                 (go >es (two? cur ? (cur . rs) rs) [(e 2 >> 16) (e 1) [e]] (p + 20 + #nm)
                     (far ? p ip) (far ? ([p nm] . ix) ix)))))
       (go es () () 0 0 ()))

   ; inodes are laid post-order, so a listing can name its children's; they are numbered
   ; pre-order, a directory before its contents, and the root last. answers [ino ref type]
   (emit st nd me parent)
    (nd 0 @
      'dir (: rs (foldl (a \ c \ (take st @ k (emit st (c 1) k me @ [i r t] ([(c 0) i r t] . a))))
                        () (sort (nd 2)))
              es (rev rs)
              lp (pos st 'r)
              ls (listing es)
              s (ls 0)
              _ (add st 'r s)
              subs (#(filter (e \ e 3 = 1) es))
              ; past 256 entries the inode is the extended one, as mksquashfs chooses, and it
              ; carries the listing's index points
              (? (#es <= 256 && #s + 3 <= 65535)
                   [me (inode st (ihead st 1 (nd 1) me + le (mstart lp) 4 + le (2 + subs) 4
                                  + le (#s + 3) 2 + le (lp % mblk) 2 + le parent 4)) 1]
                 (#s + 3 > 0xFFFFFFFF) (oops "a directory too big")
                 [me (inode st (ihead st 8 (nd 1) me + le (2 + subs) 4 + le (#s + 3) 4
                                + le (mstart lp) 4 + le parent 4 + le #(ls 1) 2 + le (lp % mblk) 2
                                + le 0xFFFFFFFF 4
                                + join "" (map (x \ x @ [i nm] (le i 4 + le (mstart (lp + i)) 4
                                                                + le (#nm - 1) 4 + nm)) (ls 1)))) 1]))
      'file (: ino me b (nd 2) n #b at (n ? (96 + pos st 'd) 0)
               nb ((n + bsize - 1) // bsize)
               sz (foldl (a \ k \ (snip b (k * bsize) (min n (k * bsize + bsize)) @ c
                                   (add st 'd c, a + le (#c | 0x1000000) 4))) "" ^nb)
               [ino (inode st (ihead st 2 (nd 1) ino + le at 4 + le 0xFFFFFFFF 4 + le 0 4
                               + le n 4 + sz)) 2])
      'link (: ino me t (nd 1)
               [ino (inode st (ihead st 3 511 ino + le 1 4 + le #t 4 + t)) 3])
      (oops ("no such node " + show (nd 0))))

   (sqfs-make tree stamp)
    (: st (pins {} 'n 1 't stamp 'd () 'dn 0 'i () 'in 0 'r () 'rn 0)
       total (count tree)
       root (emit st tree total (total + 1))
       data (whole st 'd)
       it (96 + #data)
       itab (blocks (whole st 'i))
       dt (it + #itab)
       dtab (blocks (whole st 'r))
       idb (dt + #dtab)
       idx (idb + 6)
       used (idx + 8)
       sb (le 0x73717368 4 + le total 4 + le stamp 4 + le bsize 4 + le 0 4 + le 1 2 + le 17 2
           + le 0x031b 2 + le 1 2 + le 4 2 + le 0 2 + le (root 1) 8 + le used 8 + le idx 8
           + le -1 8 + le it 8 + le dt 8 + le idb 8 + le -1 8)
       img (sb + data + itab + dtab + le 0x8004 2 + le 0 4 + le idb 8)
       (img + zbytes (padk #img 4096)))

   (sqfs-tree p)
    (: lnk (readlink p) st (stat p)
       (? (string? lnk) ['link lnk]
          (atom? st) (oops ("cannot stat " + p))
          (61440 & <>>st = 16384)
            ['dir (4095 & <>>st) (map (k \ [k (sqfs-tree (p + "/" + k))]) (sort (readdir p)))]
          (uread p @ b (b ? ['file (4095 & <>>st) <>b] (oops ("cannot read " + p)))))))
) ; module sqfs
