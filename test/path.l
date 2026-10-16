; the shared path clips; cite, not borrow, since the corpus is one scope
(: lastslash (cite 'path 'lastslash)
   lastdot   (cite 'path 'lastdot)
   segs      (cite 'path 'segs)
   pclean    (cite 'path 'pclean)
   (p s lim) (pclean (segs s) lim))

(test
 ; --- lastslash: the index just past the last '/', 0 for none
 (4 = lastslash "a/b/c") (0 = lastslash "abc") (1 = lastslash "/x")
 (0 = lastslash "") (4 = lastslash "a/b/") (1 = lastslash "/")

 ; --- lastdot: the last '.' after that slash, #p for none; a dotted dir over an undotted leaf has none
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
 ; a stack, not a counter: a surviving '..' is not popped by the next
 ([".." "b"] = p "a/../../b" ())
 ([".." ".." "b"] = p "a/../../../b" ()))

(test
 ; --- pclean bounded: lim leading '..' may survive; one past it is refused, never clamped
 (["a" "c"] = p "/a/out/../c" 0)
 (["b"] = p "/a/../b" 0)
 (() = p "/a/../../etc" 0)
 (() = p "../x" 0)
 (() = p "/../etc/passwd" 0)
 ([".." "x"] = p "../x" 1)
 (() = p "../../x" 1)
 ([".." "x"] = p "a/../../x" 1)
 ; a file honestly named with dots is not an escape
 (["a..b"] = p "/a..b" 0)
 ; the root cleans to nothing too
 (() = p "/" 0) (() = p "" ()))
