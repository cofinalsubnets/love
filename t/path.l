; the path clips in 'glob -- the one scan five callers used to each write out.
; the faces stay with their callers (make's $(dir) answers "./" where posix's
; dirname answers "."), so what is lawed here is only the shared mechanism.
; cite, not borrow: the corpus is one scope, so a splice would land glob's whole
; export list -- match, ones -- on every file after this one (t/cells.l's law).
(: lastslash (cite 'glob 'lastslash)
   lastdot   (cite 'glob 'lastdot)
   segs      (cite 'glob 'segs)
   pclean    (cite 'glob 'pclean)
   (p s lim) (pclean (segs s) lim))

(test
 ; --- lastslash: the index just past the last '/', 0 for none
 (4 = lastslash "a/b/c") (0 = lastslash "abc") (1 = lastslash "/x")
 (0 = lastslash "") (4 = lastslash "a/b/") (1 = lastslash "/")

 ; --- lastdot: the last '.' AFTER that slash, #p for none. a dotted directory
 ; over an undotted leaf has no suffix, which is the arm a bare scan gets wrong.
 (3 = lastdot "a/b.c") (3 = lastdot "abc") (5 = lastdot "a.b/c")
 (1 = lastdot "x.") (0 = lastdot "") (2 = lastdot "a/.x")

 ; --- segs: components, every empty dropped
 (["a" "b"] = segs "/a//b/") ([".." ".." "b"] = segs "../../b")
 (() = segs "/") (() = segs "") (["a"] = segs "a"))

(test
 ; --- pclean unbounded: the shell's face, where a leading '..' survives
 ([".." ".." "b"] = p "../../b" ())
 (["b"] = p "a/../b" ())
 (["x" "y"] = p "./x/./y" ())
 ; the arm that makes it a stack and not a counter: a surviving '..' must not be
 ; popped by the next one.
 ([".." "b"] = p "a/../../b" ())
 ([".." ".." "b"] = p "a/../../../b" ()))

(test
 ; --- pclean bounded: lim is how many leading '..' may survive, and one past it
 ; is a REFUSAL, never a clamp -- a clamped path silently names a different file.
 (["a" "c"] = p "/a/b/../c" 0)
 (["b"] = p "/a/../b" 0)
 (() = p "/a/../../etc" 0)
 (() = p "../x" 0)
 (() = p "/../etc/passwd" 0)
 ([".." "x"] = p "../x" 1)
 (() = p "../../x" 1)
 ([".." "x"] = p "a/../../x" 1)
 ; a file honestly named with dots is not an escape
 (["a..b"] = p "/a..b" 0)
 ; and the root itself cleans to nothing, which is not a refusal -- a caller that
 ; must tell them apart asks whether it handed anything in.
 (() = p "/" 0) (() = p "" ()))
