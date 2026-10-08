; src/apps/ext4.l -- an empty ext4, laid as mke2fs -t ext4 -b 4096 lays one, its uuid, hash
; seed and clock given: a journal, flex_bg, 64bit, metadata_csum (crc32c), an orphan file and
; room to grow (the resize inode). every block mke2fs places is placed by its rules -- the
; geometry, the flex groups' tables, first-fit from a goal for the rest -- so the bytes are its.
;   (ext4-make nb uuid seed stamp) -> {block bytes ..}, the blocks that are not zero; nb 4K
;                                     blocks, uuid and seed 16 bytes, stamp seconds
;   (ext4-image blocks nb)         -> the whole image as one string
;   (ext4-write path blocks nb)    -> the image into a file, sparse: only its blocks written
(module (ext4 ext4-make ext4-image ext4-write)
(borrow 'bytes)
(borrow 'posix)
(borrow 'hashes)
(: bs 4096  bpg 32768  isz 256  flex 16  apb 1024  fino 11  usedi 12
   (le v n) (wrle v n)
   (be v) (wrbe v 4)
   (oops m) (say err ("ext4: " + m + "\n"), quit 1)
   (cdiv a b) ((a + b - 1) // b)
   (ones n) (join "" (map (_ \ string 255) ^n))
   ; ext4's crc32c is the raw register: no complement in or out
   (crc c s) (4294967295 - crc32c-on (4294967295 - c) s)
   (pow? g k) (g = 1 || (g % k = 0 && pow? (g // k) k))
   (super? g) (g < 2 || pow? g 3 || pow? g 5 || pow? g 7)
   (at s o v n) (snip s 0 o + le v n + snip s (o + n) #s)
   (atb s o b) (snip s 0 o + b + snip s (o + #b) #s)

   ; --- the used blocks, as half-open runs [a b) sorted by start -----------------------------
   (runs _) (pins {} 'iv ())
   (mark u a n)
    (: (ins l) (? (atom? l) [[a (a + n)]]
                  (<l 0 < a) (<l . ins >l)
                  ([a (a + n)] . l))
       (merge l) (? (atom? l || atom? >l) l
                    (<>l 0 <= <l 1) (merge ([(<l 0) (max (<l 1) (<>l 1))] . >>l))
                    (<l . merge >l))
       (pin u 'iv (merge (ins (u 'iv)))))
   ; the run that holds b, or (); the first run that meets [b, b+n), or ()
   (hit u b) (foldl (r \ v \ (two? r ? r (v 0 <= b && b < v 1 ? v ()))) () (u 'iv))
   (meet u b n) (foldl (r \ v \ (two? r ? r (v 0 < b + n && b < v 1 ? v ()))) () (u 'iv))
   (used u a b) (foldl (s \ v \ s + max 0 (min b (v 1) - max a (v 0))) 0 (u 'iv))
   ; the first free block in [a, b], or -1
   (zero u a b) (? (a > b) -1 (hit u a @ v (atom? v ? a (zero u (v 1) b))))
   ; n bits from block a: set where used, and past the end nb
   (bitmap u a n nb)
    (join "" (map (k \ (: lo (a + k * 8)
                         (? (lo + 8 <= nb && atom? (meet u lo 8)) (string 0)
                            (string (foldl (x \ j \ (lo + j >= nb || two? (hit u (lo + j)) ? (x | (1 << j)) x)) 0 ^8)))))
                  ^(n // 8)))

   ; --- the image's blocks, {number bytes} -----------------------------------------------------
   (bput img b s) (pin img b (s + zbytes (bs - #s)))
   (poke img b o s) (pin img b (atb (peep img b (zbytes bs)) o s))

   ; --- geometry, as ext2fs_initialize settles it: a last group too small for its tables and
   ; 50 blocks more is dropped, and the reserve is kept at its ratio --------------------------
   (geometry nb0)
    (: nin (nb0 * bs // (nb0 * bs < 536870912 ? 4096 16384))
       (fit nb)
        (: ng (cdiv nb bpg)
           db (cdiv ng 64)
           ipg0 (cdiv nin ng)
           _ (ipg0 > 8 * bs ? (oops "too many inodes for a group") 0)
           ib (cdiv (ipg0 * isz) bs)
           ipg (ib * bs // isz @ i (i - i % 8))
           mx (nb < 4194303 ? (nb * 1024) 4294967295)
           rsv (min apb (cdiv (cdiv mx bpg) 64 - db))
           over (2 + ib + (super? (ng - 1) ? (1 + db + rsv) 0))
           rem (nb % bpg)
           (rem > 0 && rem < over + 50 ? (fit (nb - rem)) {'nb nb 'ng ng 'db db 'ipg ipg 'ib ib 'rsv rsv}))
       g (fit nb0)
       r (5 * nb0 // 100)
       (pin g 'r (g 'nb = nb0 ? r (floor (100.0 * r / nb0 * g 'nb / 100.0)))))

   (ext4-make nb0 uuid hseed stamp)
    (: g (geometry nb0)
       nb (g 'nb) ng (g 'ng) db (g 'db) ipg (g 'ipg) ib (g 'ib) rsv (g 'rsv)
       u (runs 0)
       img {}
       inodes {}
       bbl {} ibl {} itl {}
       seed (crc 4294967295 uuid)
       (gfirst gr) (gr * bpg)
       (glast gr) (min nb (gr * bpg + bpg) - 1)
       (free gr) (glast gr - gfirst gr + 1 - used u (gfirst gr) (glast gr + 1))
       ; each group's superblock, descriptors and growth room
       _ (foldl (_ \ gr \ (super? gr ? (mark u (gfirst gr) (1 + db + rsv)) 0)) 0 ^ng)

       ; --- the tables, flex_bg's way: bitmaps then tables, packed at the flex group's head ---
       ; gfb: the first b in [s, f) whose n blocks are free, or -1
       (gfb s f n)
        (: (go b) (? (b >= f || b + n > nb) -1
                     (meet u b n @ v (two? v ? (go (v 1)) b)))
           (go s))
       (offset gr prev n rem)
        (: size (min (rem * n) (bpg // 4))
           lb (glast (min (ng - 1) (gr | (flex - 1))))
           s0 (gfirst (gr - gr % flex))
           (? (prev > 0 && prev < nb && gfb prev (prev + size) n >= 0) (gfb prev (prev + size) n)
              (gfb s0 lb size >= 0) (gfb s0 lb size)
              (gfb s0 lb n >= 0) (gfb s0 lb n)
              (gfb 0 lb n)))
       (table gr)
        (: lg (min (ng - 1) (gr | (flex - 1)))
           rem (lg - gr + 1)
           toff (? (gr % flex > 0 || lg < ng - 1) flex (lg % flex = 0) flex (lg % flex + 1))
           lb (glast lg)
           (grab where n) (gfb where (lb + 1) n @ b (b < 0 ? (oops "no room for a table") (mark u b n, b)))
           b1 (grab (offset gr (gr % flex > 0 ? (bbl (gr - 1) + 1) 0) 1 rem) 1)
           _ (pin bbl gr b1)
           b2 (grab (offset gr (gr % flex > 0 ? (ibl (gr - 1) + 1) (b1 + toff)) 1 rem) 1)
           _ (pin ibl gr b2)
           b3 (grab (offset gr (gr % flex > 0 ? (itl (gr - 1) + ib) (b2 + toff)) ib rem) ib)
           (pin itl gr b3))
       _ (foldl (_ \ gr \ table gr) 0 ^ng)
       overhead (used u 0 nb)

       ; --- inodes: the fields mke2fs writes; the checksum goes on last, over all 256 bytes ---
       (iput ino mode size links nblk flags iblock big)
        (: t stamp
           head (le mode 2 + le 0 2 + le (size & 4294967295) 4 + le t 4 + le t 4 + le t 4 + le 0 4
                 + le 0 2 + le links 2 + le (nblk * 8) 4 + le flags 4 + le 0 4)
           blk (iblock + zbytes (60 - #iblock))
           tail (le 0 4 + le 0 4 + le (size >> 32) 4 + le 0 4 + le 0 12)
           ext (big ? (le 32 2 + le 0 2 + le 0 12 + le t 4) "")
           (pin inodes ino (head + blk + tail + ext + zbytes (isz - 128 - #ext))))
       (ext-tree es)
        (le 62218 2 + le #es 2 + le 4 2 + le 0 2 + le 0 4
         + join "" (map (e \ e @ [l n p] (le l 4 + le n 2 + le (p >> 32) 2 + le (p & 4294967295) 4)) es))
       (isum ino s)
        (: big (rdle s 128 2 >= 4)
           z (at (big ? (at s 130 0 2) s) 124 0 2)
           c (crc (crc (crc seed (le ino 4)) (le 0 4)) z)
           y (at z 124 (c & 65535) 2)
           (big ? (at y 130 (c >> 16) 2) y))

       ; --- directories: entries, then the 12-byte tail with the block's checksum ---
       (dirent ino rec nm)
        (le ino 4 + le rec 2 + string #nm + string 2 + nm @ e (e + zbytes ((4 - #e % 4) % 4)))
       (dir ino es)
        ((join "" es @ s (s + zbytes (bs - 12 - #s))) @ b
          (b + le 0 4 + le 12 2 + string 0 + string 222 + le (crc (crc (crc seed (le ino 4)) (le 0 4)) b) 4))
       (newblk goal)
        ((zero u goal (nb - 1) @ b (b >= 0 ? b (zero u 0 (goal - 1)))) @ b
          (b < 0 ? (oops "no free block") (mark u b 1, b)))

       root (newblk 0)
       lpf (newblk 0)
       lpf2 (newblk (lpf + 1))
       lpf3 (newblk (lpf2 + 1))
       lpf4 (newblk (lpf3 + 1))
       _ (lpf4 = lpf + 3 ? 0 (oops "lost+found is not one run"))
       _ (bput img root (dir 2 [(dirent 2 12 ".") (dirent 2 12 "..") (dirent 11 (bs - 12 - 24) "lost+found")]))
       _ (bput img lpf (dir 11 [(dirent 11 12 ".") (dirent 2 (bs - 12 - 12) "..")]))
       _ (foldl (_ \ b \ bput img b (dir 11 [(le 0 4 + le (bs - 12) 2 + le 0 2)])) 0 [lpf2 lpf3 lpf4])
       _ (iput 2 16877 bs 3 1 524288 (ext-tree [[0 1 root]]) 1)
       _ (iput 11 16832 (4 * bs) 2 4 524288 (ext-tree [[0 4 lpf]]) 1)
       _ (iput 1 0 0 0 0 0 "" 0)

       ; --- the resize inode: a double-indirect block naming each growth block, and each growth
       ; block naming its backups in the groups that keep a superblock ---
       dind (newblk (db + rsv + 2 + ib))
       backups (filter (gr \ gr > 0 && super? gr) ^ng)
       rsvs (map (k \ 1 + db + k) ^rsv)
       ; growth block k sits at slot db + k, round the block
       _ (bput img dind (join "" (map (i \ ((i - db % apb + apb) % apb @ k (le (k < rsv ? (rsvs k) 0) 4))) ^apb)))
       _ (two? backups ? (foldl (_ \ gb \ bput img gb (join "" (map (gr \ le (gb + gr * bpg) 4) backups))) 0 rsvs) 0)
       _ (iput 7 33152 ((apb * apb + apb + 12) * bs) 1 (1 + rsv + rsv * #backups) 0 (zbytes 52 + le dind 4) 1)

       ; --- the journal: from the middle group's head, each free stretch taken as it comes ---
       jn (? (nb < 32768) 1024 (nb < 262144) 4096 (nb < 524288) 8192 (nb < 4194304) 16384
             (nb < 8388608) 32768 (nb < 16777216) 65536 (nb < 33554432) 131072 262144)
       (busy k) (k < ng && free k = 0 ? (busy (k + 1)) k)
       mg (nb // 2 // bpg)
       jst (? (mg > flex) (busy (mg - mg % flex) @ k (k = ng ? 0 k)) (mg > 0) (mg - 1) 0)
       jen ((mg > flex ? jst mg) @ m (m + 1 < ng ? (m + 1) m))
       jgr (foldl (b \ k \ (free k > free b ? k b)) jst (map (k \ jst + 1 + k) ^(jen - jst)))
       (stretch goal left)
        (? (left = 0) ()
           (zero u goal (nb - 1) @ b
             (? (b < 0) (stretch 0 left)
                ((meet u b left @ v (min left (min 32768 (two? v ? (v 0 - b) left)))) @ n
                  (mark u b n, [b n] . stretch (b + n) (left - n))))))
       jr (stretch (gfirst jgr) jn)
       _ (#jr > 4 ? (oops "the journal needs an extent tree") 0)
       jes (rev (foldl (a \ r \ ([(net (map (e \ e 1) a)) (r 1) (r 0)] . a)) () jr))
       jtree (ext-tree jes)
       _ (iput 8 33152 (jn * bs) 1 jn 524288 jtree 1)
       _ (bput img (jr 0 0) (be 3225106840 + be 4 + be 0 + be bs + be jn + be 1 + be 1 + zbytes 20 + uuid + be 1))

       ; --- the orphan file: each block a zero table and a tail, its checksum by its own number.
       ; past 2^21 blocks mke2fs's default is 2 blocks: its size macro, 2 << 20, divides first ---
       on (? (nb < 131072) 32 (nb < 2097152) (nb // bs) 2)
       ob (map (k \ newblk 0) ^on)
       _ (foldl (_ \ b \ bput img b (zbytes (bs - 8) + le 185649668 4
                  + le (crc (crc (crc (crc seed (le 12 4)) (le 0 4)) (le b 8)) (zbytes (bs - 8))) 4)) 0 ob)
       _ (ob (on - 1) = ob 0 + on - 1 ? 0 (oops "the orphan file is not one run"))
       _ (iput 12 33152 (on * bs) 1 on 524288 (ext-tree [[0 on (ob 0)]]) 1)

       ; --- the inode table's head, the bitmaps, the descriptors and the superblocks ---
       _ (foldl (_ \ i \ (string? (inodes i) ? 0 (pin inodes i (zbytes isz)))) 0 (map (k \ k + 1) ^10))
       _ (foldl (_ \ i \ poke img (itl 0 + (i - 1) * isz // bs) ((i - 1) * isz % bs) (isum i (inodes i)))
                0 (sort (keys inodes)))
       (ibits gr)
        (gr > 0 ? (zbytes (ipg // 8))
           (join "" (map (k \ string (foldl (x \ j \ (k * 8 + j < usedi ? (x | (1 << j)) x)) 0 ^8)) ^(ipg // 8))))
       (uninit gr) (gr < ng - 1 && used u (gfirst gr) (glast gr + 1) = 0)
       (desc gr)
        (: bc (uninit gr ? 0 (crc seed (bitmap u (gfirst gr) bpg nb)))
           ic (gr > 0 ? 0 (crc seed (ibits gr)))
           fi (gr > 0 ? ipg (ipg - usedi))
           fl ((uninit gr ? 2 0) | (gr > 0 ? 1 0) | 4)
           d (le (bbl gr) 4 + le (ibl gr) 4 + le (itl gr) 4 + le (free gr) 2 + le fi 2
              + le (gr = 0 ? 2 0) 2 + le fl 2 + le 0 4 + le (bc & 65535) 2 + le (ic & 65535) 2
              + le fi 2 + le 0 2 + le 0 24 + le (bc >> 16) 2 + le (ic >> 16) 2 + le 0 4)
           (at d 30 (crc (crc seed (le gr 4)) d & 65535) 2))
       descs (join "" (map desc ^ng))
       _ (foldl (_ \ gr \ (uninit gr ? 0 (bput img (bbl gr) (bitmap u (gfirst gr) bpg nb)))) 0 ^ng)
       _ (poke img (ibl 0) 0 (ibits 0 + ones (bs - ipg // 8)))
       kb (4 * #(keys img) + 4)
       (sb gr)
        (: s0 (foldl (s \ f \ at s (f 0) (f 1) (f 2)) (zbytes 1024)
               [[0 (ipg * ng) 4] [4 nb 4] [8 (g 'r) 4] [12 (nb - used u 0 nb) 4] [16 (ipg * ng - usedi) 4]
                [24 2 4] [28 2 4] [32 bpg 4] [36 bpg 4] [40 ipg 4] [48 stamp 4] [54 65535 2] [56 61267 2]
                [58 (gr = 0 ? 1 0) 2] [60 1 2] [64 stamp 4] [76 1 4] [84 fino 4] [88 isz 2] [90 gr 2] [92 4156 4]
                [96 8898 4] [100 1131 4] [206 rsv 2] [224 8 4] [252 1 1] [253 1 1] [254 64 2] [256 12 4]
                [264 stamp 4] [328 0 4] [332 (jn * bs) 4] [348 32 2] [350 32 2] [352 1 4] [372 4 1]
                [373 1 1] [376 kb 8] [584 (overhead + jn) 4] [624 seed 4] [640 12 4]])
           s1 (atb (atb (atb s0 104 uuid) 236 hseed) 268 jtree)
           (at s1 1020 (crc 4294967295 (snip s1 0 1020)) 4))
       _ (foldl (_ \ gr \ (? (super? gr)
                              (: b (gfirst gr)
                                 _ (gr = 0 ? (poke img 0 1024 (sb 0)) (bput img b (sb gr)))
                                 (foldl (_ \ k \ bput img (b + 1 + k) (snip descs (k * bs) (min #descs (k * bs + bs)))) 0 ^db))
                              0))
                0 ^ng)
       img)

   (ext4-image img nb)
    (join "" (map (b \ peep img b (zbytes bs)) ^nb))
   (ext4-write path img nb)
    (truncate path (nb * bs) 1 @ r (? (nom? r) (oops ("cannot size " + path))
      (each (sort (keys img))
        (b \ openfd path 4 @ fd (? (charm? fd && fd >= 0) (lseek fd (b * bs) 0, fdopen fd @ p (say p (img b), close p))
                                 (oops ("cannot write " + path)))))))
)
) ; module ext4
