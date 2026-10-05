; test/kernel/hostfs.l -- /mnt/host, the seat's own files: the page's folder or storage, a
; directory under node (inle.mjs --host). every door the ramfs has, answered across the
; seat in the host's own shapes; a seat with no files of its own lays no mount, and the laws
; skip with a word. kept.txt is left behind on purpose: the gate reads it off the host side.
(stat "/mnt/host" @ st
 (!(two? st) ? (puts "hostfs: no mount here, laws skipped", putc 10, ())
  (: (rd p) (open p "r" @ q (port? q ? (slurp q @ s (close q, s))))
     (wr p s) (open p "w" @ q (port? q ? (say q s, close q, 1) 0))
     d "/mnt/host/l-hostfs"
     f (d + "/a")
     e (d + "/e")
   (test
     (16384 = 61440 & <>>st)                    ; the mount is a directory
     (elem "host" (readdir "/mnt"))
     ; -- create, read, the stat's shape --
     !(mkdir d 493)
     (16384 = 61440 & <>>(stat d))
     (wr f "five!")
     ("five!" = rd f)
     (5 = <(stat f))
     (32768 = 61440 & <>>(stat f))
     (1600000000000 < <>(stat f))
     (elem "a" (readdir d))
     ; -- append, a write in place, a truncate that cuts and one that stretches --
     (open f "a" @ q (port? q ? (say q "!!", close q, 1) 0))
     ("five!!!" = rd f)
     (uwrite-at f 1 "IV")
     ("fIVe!!!" = rd f)
     !(truncate f 3 0)
     ("fIV" = rd f)
     !(truncate f 5 0)
     ((string [102 73 86 0 0]) = rd f)
     (openfd f 0 @ fd (5 = lseek fd 0 2 && 1 = lseek fd 1 0 && !(close fd)))
     ; -- absence, and the doors that refuse --
     ('enoent = stat (d + "/none"))
     !(port? (open (d + "/none") "r"))
     !(port? (open (d + "/no/x") "w"))          ; an absent parent refuses
     ('eexist = mkdir d 493)
     ('eisdir = unlink d)
     ; -- rename: a file moves, lands on a file, a directory carries its children --
     !(mkdir e 493)
     (wr (e + "/x") "1")
     ('enotempty = rmdir e)
     !(rename f (d + "/z"))
     ('enoent = stat f)
     (wr f "yo")
     !(rename (d + "/z") f)
     ((string [102 73 86 0 0]) = rd f)
     !(rename e (d + "/ee"))
     ("1" = rd (d + "/ee/x"))
     ('exdev = rename "/tmp" (d + "/t"))        ; not across the mount
     ; -- the mount itself stays, and keeps no links --
     ('eexist = mkdir "/mnt/host" 493)
     ('eisdir = unlink "/mnt/host")
     ('erofs = rmdir "/mnt/host")
     ('eperm = symlink "a" (d + "/l"))
     ; -- a seat under the mount: relative paths read off it --
     !(chdir d)
     ("/mnt/host/l-hostfs" = cwd 0)
     (elem "a" (readdir "."))
     !(chdir "/love")
     ; -- the foot: everything unmade but kept.txt, the gate's to read --
     !(unlink (d + "/ee/x"))
     !(rmdir (d + "/ee"))
     !(unlink f)
     !(rmdir d)
     ('enoent = stat d)
     (wr "/mnt/host/kept.txt" "the seat keeps this\n")))))
