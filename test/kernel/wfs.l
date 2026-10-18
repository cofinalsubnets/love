; test/kernel/wfs.l -- the writable tree on inle. the shapes are the host's: an effect answers
; () | an errno nom | 'badarg, a value the value | () | a nom | 'badarg. kernel only;
; everything made here is unmade at the foot

(: (rd p) (open p "r" @ q (port? q ? (slurp q @ s (close q, s))))
   (wr p s) (open p "w" @ q (port? q ? (say q s, close q, 1) 0))
   d "/tmp/l-wfs"
   f (d + "/a")
   e (d + "/e")
 (test
   ; -- create: `w` and `a` under a live directory mint the file
   !(mkdir d 493)
   (wr f "five!")
   ("five!" = rd f)
   (5 = <(stat f))
   (1600000000000 < <>(stat f))                 ; born wearing the clock's date
   (32768 = 61440 & <>>(stat f))
   (elem "a" (readdir d))
   (open (d + "/b") "a" @ q (port? q ? (close q, 1) 0))
   (two? (stat (d + "/b")))
   !(port? (open "/no-such-dir/x" "w"))      ; an absent parent refuses
   ; -- unlink
   !(unlink (d + "/b"))
   (stat (d + "/b") = 'enoent)
   (nom? (unlink (d + "/b")))                   ; gone is a live errno
   ('eisdir = unlink d)
   ('badarg = unlink 7)
   ; -- mkdir/rmdir
   !(mkdir e 493)
   (16384 = 61440 & <>>(stat e))
   (readdir e = ())                         ; empty, told from absent by stat
   ('eexist = mkdir e 493)
   ('erofs = mkdir "src" 493)              ; the tree under /love is nobody's to write
   ('erofs = unlink "src/apps/json.l")
   ('erofs = rename "src/apps/json.l" (d + "/j"))
   ('erofs = chmod "src/apps/json.l" 384)
   ('erofs = rename "/proc" (d + "/q"))       ; nor carried off by a move above it
   ('erofs = rename "/proc/vt" (d + "/vt"))   ; a special row stays where its name is
   ('erofs = rename "/dev" (d + "/dev"))
   ('erofs = rename f "/proc/lift")            ; and is not replaced under a move
   ('erofs = rmdir "/proc")
   ('eexist = mkdir "/usr/bin" 493)      ; a baked prefix is a directory too
   ('enotdir = mkdir (f + "/x") 493)
   ('enoent = mkdir "/hole/x" 493)
   ('badarg = mkdir 7 493)
   (wr (e + "/k") "y")
   ('enotempty = rmdir e)
   !(unlink (e + "/k"))
   !(rmdir e)
   ('enoent = rmdir e)
   ('enotdir = rmdir f)
   ; -- rename: a target file is replaced under it
   !(rename f (d + "/z"))
   (stat f = 'enoent)
   (5 = <(stat (d + "/z")))
   (nom? (rename (d + "/ghost") f))             ; a missing source is a live errno
   ('badarg = rename 7 f)
   (wr f "yo")
   !(rename (d + "/z") f)
   ("five!" = rd f)
   ; a directory carries its children, and never moves into itself
   !(mkdir (d + "/dd") 493)
   (wr (d + "/dd/x") "1")
   !(rename (d + "/dd") (d + "/ee"))
   ("1" = rd (d + "/ee/x"))
   (stat (d + "/dd") = 'enoent)
   ('einval = rename d (d + "/in"))        ; a real einval: the name parts it from 'badarg
   ; -- chdir/cwd: /home is the boot cwd; the corpus stands at the tree's top
   ("/love" = cwd 0)
   !(chdir "src/apps/kore")
   ("/love/src/apps/kore" = cwd 0)
   (0 < #(rd "kore.l"))                       ; a relative path reads off the cwd
   (elem "kore.l" (readdir "."))
   !(chdir "..")
   ("/love/src/apps" = cwd 0)            ; .. unwinds ONE component
   ; back to the tree's top by hand: the corpus loads by relative path, so a cwd left elsewhere
   ; fails every later member as a missing file
   !(chdir "/love")
   ("/love" = cwd 0)
   (nom? (chdir f))                             ; a file is no cwd
   (nom? (chdir "/nope"))
   ('badarg = chdir 7)
   ; -- chmod and utime land, and stat reads them back
   !(chmod f 384)
   (384 = <>>(stat f) - 32768)
   !(utime f 1600000000000)
   (1600000000000 = <>(stat f))
   !(utime f ())
   (1600000000000 < <>(stat f))
   ('badarg = chmod 7 384)
   ('enoent = chmod (d + "/ghost") 384)
   ; -- the environment: a tablet behind the host's three doors; HOME and COLORTERM come
   ; from the boot
   ("/home" = getenv "HOME")
   ("truecolor" = getenv "COLORTERM")
   (getenv "WFS" = ())                      ; unset is the real ()
   !(setenv "WFS" "1")
   ("1" = getenv "WFS")
   !(setenv "WFS" "2")                  ; a re-set replaces: still one row
   ("2" = getenv "WFS")
   (elem "WFS=2" (environ 0))
   !(setenv "WFS2" "x")
   (4 = #(environ 0))
   !(setenv "WFS2" ())                  ; a non-string value unsets
   (getenv "WFS2" = ())
   (3 = #(environ 0))
   ('badarg = setenv 7 "x")
   (getenv 7 = ())
   ; -- which kernel this is
   ('inle = love-os)
   ("Inle" = os-uname love-os)
   ; -- symlinks: stat follows and readlink does not
   (wr f "five!")
   !(symlink f (d + "/ln"))
   ("five!" = rd (d + "/ln"))
   (5 = <(stat (d + "/ln")))                    ; and so does stat
   (f = readlink (d + "/ln"))
   ('einval = readlink f)                     ; a plain file is not a link
   ('enoent = readlink (d + "/nope"))
   ('eexist = symlink f (d + "/ln"))          ; one name, laid once
   (elem "ln" (readdir d))
   ; a target that is not there is still a link: the name resolves, the open does not
   !(symlink (d + "/gone") (d + "/dangle"))
   (d + "/gone" = readlink (d + "/dangle"))
   ('enoent = stat (d + "/dangle"))
   ; a link onto a link, and a pair that name each other
   !(symlink (d + "/ln") (d + "/ln2"))
   ("five!" = rd (d + "/ln2"))
   !(symlink (d + "/loopb") (d + "/loopa"))
   !(symlink (d + "/loopa") (d + "/loopb"))
   ('eloop = stat (d + "/loopa"))
   !(unlink (d + "/ln")) !(unlink (d + "/ln2")) !(unlink (d + "/dangle"))
   !(unlink (d + "/loopa")) !(unlink (d + "/loopb"))
   ('enoent = stat (d + "/ln"))
   ("five!" = rd f)                           ; unlinking the link left the file
   ; -- the tree and the tablet go back the way they came
   !(setenv "WFS" ())
   !(unlink f)
   !(unlink (d + "/ee/x"))
   !(rmdir (d + "/ee"))
   !(rmdir d)
   (stat d = 'enoent)))
