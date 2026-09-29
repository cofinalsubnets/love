; src/apps/kore/find.l -- find: walk the trees under the named paths, test each name
; against an expression, act on what matches. a toolbox file, no seat -- kore
; (src/apps/kore/kore.l) is its door. it rides the u-floor (udie, ubase, uatoi, umode)
; and post.l's glob for -name and -path.
;
; the surface:
;   find [-L] [PATH..] [EXPR]   PATH defaults to .
;   tests      -name pat  -iname pat  -path pat  -ipath pat  -type f|d|l  -empty
;              -newer FILE  -mtime N  -mmin N  -size N[cwbkMG]  -perm [-/]MODE
;              -true  -false   (N is +N more, -N less, N exactly)
;   actions    -print  -print0  -prune  -delete  -exec CMD.. ;  -exec CMD.. {} +
;   options    -maxdepth N  -mindepth N  -depth (-delete implies it)
;   operators  ( )  ! / -not  -a / -and (implicit between two primaries)  -o / -or
; an expression naming no action gets -print, exactly as GNU does; -a binds tighter
; than -o and both short-circuit.
;
; the walk sorts each directory. GNU hands out readdir order, which is the file
; system's business and not a promise anyone can repeat -- so `find | sort` is the
; only honest way to smoke us against it, and that is what test/kore/find.sh does.
; sorted is also what a build wants: the same tree cuts the same image twice.
;
; symlinks are not followed (GNU's -P, the default): each name is lstat'd once, a
; link answers l whatever it points at, and the walk does not descend through it. -L
; stats through links instead. a dangling link is still visited.
(module 'kore
(borrow 'glob) ; -name/-path
(borrow 'posix)

(:
   ; a path and one entry -> the child's path (a trailing / on the parent stays one /)
   (fi-join p b)
    (: n #p (? ((0 < n) && (p (n - 1) = 47)) (p + b) (p + "/" + b)))
   ; a stat tuple -> its type charm: f, d, l, or 0 for a thing that is none of the three
   (fi-type st)
    (? (atom? st) 0
       (: m (61440 & <>>st) (? (m = 16384) 100 (m = 32768) 102 (m = 40960) 108 0)))
   ; +N, -N or N -> [sign n], sign 1 more, -1 less, 0 exactly; () for no number
   (fi-num w)
    (: c (? (0 < #w) (w 0) 0) sg (? (c = 43) 1 (c = 45) -1 0)
       d (? (sg = 0) w (snip w 1 #w))
       (? (0 < #d && all digit? (chars d)) [sg (unum d)] ()))
   (fi-cmp nw v) (: sg <nw n <>nw (? (sg = 1) (n < v) (sg = -1) (v < n) (v = n)))

   ; -- the expression: words in, a tree out --
   ; every parse door answers (node rest) or () -- a node is never (), so presence
   ; carries in the shape and nothing needs a wrapper
   (fi-exec m acc)                              ; -exec's words, up to ; or {} +
    (? (atom? m) ()
       (<m = ";") (? (two? acc) [['exec (rev acc)] >m] ())
       (<m = "+" && two? acc && <acc = "{}") [['execs (rev >acc) (tablet 0)] >m]
       (fi-exec >m (<m . acc)))
   (fi-bad w) (udie 1 ("find: invalid argument " + w))
   (fi-prim ws)
    (? (atom? ws) ()
       (: a <ws m >ws
          (? (a = "-print") [['print] m]
             (a = "-print0") [['print0] m]
             (a = "-prune") [['prune] m]
             (a = "-delete") [['delete] m]
             (a = "-empty") [['empty] m]
             (a = "-true")  [['true] m]
             (a = "-false") [['false] m]
             (a = "-exec")  (fi-exec m ())
             (atom? m) ()
             (a = "-name") [['name <m] >m]
             (a = "-iname") [['name (lower <m) 1] >m]
             (a = "-path") [['path <m] >m]
             (a = "-ipath") [['path (lower <m) 1] >m]
             (a = "-type") [['type <m] >m]
             (a = "-newer") (: st (stat <m) (? (two? st) [['newer (st 3)] >m] (udie 1 ("find: '" + <m + "': No such file or directory"))))
             (a = "-mtime") (: n (fi-num <m) (? (two? n) [['age 86400000 n] >m] (fi-bad <m)))
             (a = "-mmin") (: n (fi-num <m) (? (two? n) [['age 60000 n] >m] (fi-bad <m)))
             (a = "-size")
              (: w <m k #w u (? (0 < k) (w (k - 1)) 0)
                 un (? (u = 99) 1 (u = 119) 2 (u = 98) 512 (u = 107) 1024 (u = 77) 1048576 (u = 71) 1073741824 0)
                 n (fi-num (? un (snip w 0 (k - 1)) w))
                 (? (two? n) [['size (? un un 512) n] >m] (fi-bad w)))
             (a = "-perm")
              (: w <m c (? (0 < #w) (w 0) 0) how (? (c = 45) 'all (c = 47) 'any 'exact)
                 v (umode (? (how = 'exact) w (snip w 1 #w)) 0 0 0)
                 (? (charm? v) [['perm how v] >m] (fi-bad w)))
             ())))
   (fi-not ws)
    (? (atom? ws) ()
       ((<ws = "!") || (<ws = "-not"))
        (: r (fi-not >ws) (? (two? r) [['not <r] <>r] ()))
       (<ws = "(")
        (: r (fi-or >ws)
           (? (atom? r) ()
              (: m <>r (? ((two? m) && (<m = ")")) [<r >m] ()))))
       (fi-prim ws))
   ; -a is implicit: any word that is not a closing sigil opens another and-arm
   (fi-and ws)
    (: r (fi-not ws)
       (? (atom? r) ()
          (: (go n m)
              (? (atom? m) [n m]
                 (: m2 (? ((<m = "-a") || (<m = "-and")) >m m)
                    (? ((atom? m2) || (<m2 = "-o") || (<m2 = "-or") || (<m2 = ")")) [n m]
                       (: r2 (fi-not m2)
                          (? (two? r2) (go ['and n <r2] <>r2) ())))))
             (go <r <>r))))
   (fi-or ws)
    (: r (fi-and ws)
       (? (atom? r) ()
          (: (go n m)
              (? ((two? m) && ((<m = "-o") || (<m = "-or")))
                 (: r2 (fi-and >m)
                    (? (two? r2) (go ['or n <r2] <>r2) ()))
                 [n m])
             (go <r <>r))))
   ; -maxdepth/-mindepth are global wherever they sit (GNU's reading too), so they
   ; come out of the word list before the grammar ever sees them
   (fi-depths ws maxd mind acc)
    (? (atom? ws) [(rev acc) maxd mind]
       (: a <ws
          (? ((a = "-maxdepth") && (two? >ws)) (fi-depths >>ws (uatoi <>ws) mind acc)
             ((a = "-mindepth") && (two? >ws)) (fi-depths >>ws maxd (uatoi <>ws) acc)
             (fi-depths >ws maxd mind (a . acc)))))
   ; the leading words that are neither a flag nor an open bracket are the paths
   (fi-paths as acc)
    (? (atom? as) [(rev acc) ()]
       (: a <as
          (? (((0 < tally a) && (a 0 = 45)) || (a = "(") || (a = "!"))
             [(rev acc) as]
             (fi-paths >as (a . acc)))))
   ; does the tree act, or only test -- the question that decides the added -print
   (fi-acts? e)
    (: k <e
       (? (elem k '(print print0 exec execs delete)) 1
          (k = 'not) (fi-acts? <>e)
          ((k = 'and) || (k = 'or)) (? (fi-acts? <>e) 1 (fi-acts? <>>e))
          0))

   ; -- the walk --
   ; st carries what a visit leaves behind: 112 the prune mark (cleared at every name,
   ; set by -prune), 101 the trouble mark (an -exec that would not run or said no, a
   ; -delete that failed), 'now the clock the ages are read against
   (fi-run st ws)
    (: _ (flush out)                            ; the child shares the port: say what we said
       pid (spawn ws)
       (? (nom? pid) (say err ("find: cannot run " + <ws), put err 10, pin st 101 1, 0)
          (? (wait pid) 0 1)))
   ; -exec .. {} +: the names gather and go in runs of 256, the rest at the end
   (fi-flush st e) (: x <>>e ps (peep x 'ps ()) _ (pin x 'ps ())
                      (? (two? ps) (? (fi-run st (<>e + rev ps)) 0 (pin st 101 1)) 0))
   ; the tree's -exec {} + nodes, to flush at the end
   (fi-execs e) (: k <e (? (k = 'execs) [e] (elem k '(and or)) (fi-execs <>e + fi-execs <>>e) (k = 'not) (fi-execs <>e) ()))
   (fi-eval e p base ty sb st)
    (: k <e
       (? (k = 'print) (say out p, put out 10, 1)
          (k = 'print0) (say out p, put out 0, 1)
          (k = 'name)  (match <>e (? <>>e (lower base) base))
          (k = 'path)  (match <>e (? <>>e (lower p) p))
          (k = 'type)  (: c <>e (? ((0 < tally c) && (ty = (c 0))) 1 0))
          (k = 'empty) (? (ty = 100) (? (two? (readdir p)) 0 1) (ty = 102) (? (<sb = 0) 1 0) 0)
          (k = 'newer) (? (two? sb && <>e < sb 3) 1 0)
          (k = 'age)   (? (two? sb) (fi-cmp <>>e ((st 'now - <>sb) // <>e + (? (<>e = 60000 && 0 < (st 'now - <>sb) % 60000) 1 0))) 0)
          (k = 'size)  (? (two? sb) (fi-cmp <>>e ((<sb + <>e - 1) // <>e)) 0)
          (k = 'perm)  (: v (4095 & <>>sb) w <>>e
                          (? (<>e = 'all) (? ((v & w) = w) 1 0)
                             (<>e = 'any) (? (w = 0 || 0 < (v & w)) 1 0)
                             (? (v = w) 1 0)))
          (k = 'prune) (pin st 112 1, 1)
          (k = 'delete) (: e2 (? (ty = 100) (rmdir p) (unlink p))
                           (? !e2 1 (say err ("find: cannot delete '" + p + "'"), put err 10, pin st 101 1, 0)))
          (k = 'true)  1
          (k = 'false) 0
          (k = 'not)   (? (fi-eval <>e p base ty sb st) 0 1)
          (k = 'and)   (? (fi-eval <>e p base ty sb st) (fi-eval <>>e p base ty sb st) 0)
          (k = 'or)    (? (fi-eval <>e p base ty sb st) 1 (fi-eval <>>e p base ty sb st))
          (k = 'exec)  (fi-run st (map (\ w (? (w = "{}") p w)) <>e))
          (k = 'execs) (: x <>>e _ (pin x 'ps (p . peep x 'ps ()))
                          _ (? (256 <= #(x 'ps)) (fi-flush st e) 0) 1)
          0))
   ; -depth says a directory after what is in it, as -delete must
   (fi-walk p depth e st maxd mind)
    (: sb (? (st 'L) (stat p) (lstat p))
       ty (fi-type sb)
       _ (pin st 112 0)
       (here _) (? (mind <= depth) (fi-eval e p (ubase p "") ty sb st) 0)
       _ (? (st 'depth) 0 (here 0))
       _ (? ((ty = 100) && (depth < maxd) && !(peep st 112 0))
            (each (sort (readdir p)) (b \ fi-walk (fi-join p b) (depth + 1) e st maxd mind))
            0)
       (? (st 'depth) (here 0) 0))

   (find-main as0)
    (: (has-delete? e) (: k <e (? (k = 'delete) 1 (elem k '(and or)) (? (has-delete? <>e) 1 (has-delete? <>>e)) (k = 'not) (has-delete? <>e) 0))
       L? (two? as0 && <as0 = "-L")
       as (? (two? as0 && (<as0 = "-L" || <as0 = "-P")) >as0 as0)
       sp (fi-paths as ())
       d (fi-depths <>sp 536870911 0 ())
       ws (filter (w \ !(w = "-depth")) <d) maxd <>d mind <>>d
       pr (? (two? ws) (fi-or ws) [['true] ()])
       _ (? ((two? pr) && (atom? <>pr)) ()
            (udie 1 "usage: find [-L] [PATH..] [EXPR]  -- see doc/misc/kore.md for the grammar"))
       e (? (fi-acts? <pr) <pr ['and <pr ['print]])
       st (tablet 0)
       _ (pins st 'now (clock 0) 'L (? L? 1 0) 'depth (? (elem "-depth" <d || has-delete? e) 1 0))
       ; a named path that is not there is find's one loud failure: it complains,
       ; the walk skips it, and the exit code remembers -- the rest still walk
       (there? p) ((string? (readlink p)) || (two? (stat p)))
       (go m) (? (atom? m) (each (fi-execs e) (x \ fi-flush st x), flush out, (? (peep st 101 0) 1 0))
                 ((? (there? <m) (fi-walk <m 0 e st maxd mind)
                         (say err ("find: '" + <m + "': No such file or directory"), put err 10, pin st 101 1)), go >m))
       (go (? (two? <sp) <sp '(".")))))
) ; module 'kore
