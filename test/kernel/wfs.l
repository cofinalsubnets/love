; The writable tree, inle's rung 2 (doc/misc/inle.md): create, mkdir, rmdir, unlink,
; rename, chdir/cwd -- plus chmod and utime, which kore's cp and touch ride -- and
; the environment (getenv setenv environ), a tablet in the kernel's boot text. The
; shapes are doc/misc/posix.md's and the host's exactly: an effect answers () ok |
; an errno nom | 'badarg misuse; a value answers the value | () | a nom | 'badarg.
; test/host/fs.l holds sibling laws against the real tree.
;
; kernel only -- test/kernel/all.l's roster, never $t: on the host these paths are the real
; filesystem. Everything made here is unmade at the foot, so the corpus behind
; reads the tree as this file found it.
;
; the `:` has a body -- the assert itself -- so the helpers stay local; and each
; law is its own assert argument, since assert maps over its args and a `do` would
; report only the last one.

(: (rd p) (: q (open p "r") (? (port? q) (: s (slurp q) _ (close q) s) ()))
   (wr p s) (: q (open p "w") (? (port? q) (: _ (say q s) _ (close q) 1) 0))
   d "/tmp/l-wfs"
   f (d + "/a")
   e (d + "/e")
 (assert
   ; -- create: `w` under a live directory mints the file; `a` does too --
   !(mkdir d 493)
   (wr f "five!")
   (= "five!" (rd f))
   (= 5 <(stat f))
   (< 1600000000000 <>(stat f))                 ; born wearing the clock's date
   (= 32768 (& 61440 <>>(stat f)))
   (member? "a" (readdir d))
   (: q (open (d + "/b") "a") (? (port? q) (: _ (close q) 1) 0))
   (two? (stat (d + "/b")))
   (! (port? (open "/no-such-dir/x" "w")))      ; an absent parent refuses
   ; -- unlink: the entry leaves the tree; absence and misuse answer the host's way --
   !(unlink (d + "/b"))
   ((stat (d + "/b")) = 'enoent)
   (nom? (unlink (d + "/b")))                   ; gone is a live errno
   ('eisdir = (unlink d))                     ; a directory refuses
   ('badarg = (unlink 7))                     ; misuse
   ; -- mkdir/rmdir: a directory is a thing now, empty and stattable --
   !(mkdir e 493)
   (= 16384 (& 61440 <>>(stat e)))
   ((readdir e) = ())                         ; empty, told from absent by stat
   ('eexist = (mkdir e 493))                  ; again
   ('eexist = (mkdir "apps" 493))             ; a baked prefix is a directory too
   ('enotdir = (mkdir (f + "/x") 493))       ; under a file
   ('enoent = (mkdir "/hole/x" 493))         ; under a hole
   ('badarg = (mkdir 7 493))
   (wr (e + "/k") "y")
   ('enotempty = (rmdir e))                   ; occupied
   !(unlink (e + "/k"))
   !(rmdir e)
   ('enoent = (rmdir e))                      ; and gone
   ('enotdir = (rmdir f))                     ; a file was never a directory
   ; -- rename: a file moves whole; a target file is replaced under it --
   !(rename f (d + "/z"))
   ((stat f) = 'enoent)
   (= 5 <(stat (d + "/z")))
   (nom? (rename (d + "/ghost") f))             ; a missing source is a live errno
   ('badarg = (rename 7 f))
   (wr f "yo")
   !(rename (d + "/z") f)
   (= "five!" (rd f))
   ; a directory carries its children, and never moves into itself
   !(mkdir (d + "/dd") 493)
   (wr (d + "/dd/x") "1")
   !(rename (d + "/dd") (d + "/ee"))
   (= "1" (rd (d + "/ee/x")))
   ((stat (d + "/dd")) = 'enoent)
   ('einval = (rename d (d + "/in")))        ; a real einval: the name parts it from 'badarg
   ; -- chdir/cwd: the cwd is a kernel string; "/" is the boot seat --
   (= "/" (cwd 0))
   !(chdir "apps/kore")
   (= "/apps/kore" (cwd 0))
   (< 0 (tally (rd "kore.l")))                  ; a relative path reads off the cwd
   (member? "kore.l" (readdir "."))
   !(chdir "..")
   (= "/apps" (cwd 0))                      ; .. unwinds ONE component
   ; ⚠ the seat has to go back to / by hand. this file is one member of a corpus the
   ; runner loads by RELATIVE path, so a cwd left anywhere else takes every member
   ; after this one down with a no-corpus-member -- which reads as a missing file
   ; and not as the walk that moved.
   !(chdir "/")
   (= "/" (cwd 0))
   (nom? (chdir f))                             ; a file is no seat
   (nom? (chdir "/nope"))
   ('badarg = (chdir 7))
   ; -- chmod and utime: the bits and the date land, and stat reads them back --
   !(chmod f 384)
   (= 384 (- <>>(stat f) 32768))
   !(utime f 1600000000000)
   (= 1600000000000 <>(stat f))
   !(utime f ())
   (< 1600000000000 <>(stat f))
   ('badarg = (chmod 7 384))
   ('enoent = (chmod (d + "/ghost") 384))
   ; -- the environment: a tablet behind the host's three doors --
   ((getenv "WFS") = ())                      ; unset is the real ()
   !(setenv "WFS" "1")
   (= "1" (getenv "WFS"))
   !(setenv "WFS" "2")                  ; a re-set replaces: still one row
   (= "2" (getenv "WFS"))
   (member? "WFS=2" (environ 0))
   !(setenv "WFS2" "x")
   (= 2 (tally (environ 0)))
   !(setenv "WFS2" ())                  ; a non-string value unsets
   ((getenv "WFS2") = ())
   (= 1 (tally (environ 0)))
   ('badarg = (setenv 7 "x"))
   ((getenv 7) = ())
   ; -- which kernel this is: the name a hosted seat probes for, said outright here --
   (= 'inle love-os)
   (= "Inle" (peep os-uname love-os ()))
   ; -- symlinks: a name for a name, and the one door /usr/bin is laid through --
   ; stat FOLLOWS and readlink does not, which is what lets a link be seen at all.
   (wr f "five!")
   !(symlink f (d + "/ln"))
   (= "five!" (rd (d + "/ln")))                 ; open follows
   (= 5 <(stat (d + "/ln")))                    ; and so does stat
   (= f (readlink (d + "/ln")))                 ; readlink does not
   ('einval = (readlink f))                     ; a plain file is not a link
   ('enoent = (readlink (d + "/nope")))
   ('eexist = (symlink f (d + "/ln")))          ; one name, laid once
   (member? "ln" (readdir d))
   ; a target that is not there is still a link: the name resolves, the open does not
   !(symlink (d + "/gone") (d + "/dangle"))
   (= (d + "/gone") (readlink (d + "/dangle")))
   ('enoent = (stat (d + "/dangle")))
   ; a link onto a link, and a pair that name each other
   !(symlink (d + "/ln") (d + "/ln2"))
   (= "five!" (rd (d + "/ln2")))
   !(symlink (d + "/loopb") (d + "/loopa"))
   !(symlink (d + "/loopa") (d + "/loopb"))
   ('eloop = (stat (d + "/loopa")))
   !(unlink (d + "/ln")) !(unlink (d + "/ln2")) !(unlink (d + "/dangle"))
   !(unlink (d + "/loopa")) !(unlink (d + "/loopb"))
   ('enoent = (stat (d + "/ln")))
   (= "five!" (rd f))                           ; unlinking the link left the file
   ; -- and the tree (and the tablet) go back the way they came --
   !(setenv "WFS" ())
   !(unlink f)
   !(unlink (d + "/ee/x"))
   !(rmdir (d + "/ee"))
   !(rmdir d)
   ((stat d) = 'enoent)))
