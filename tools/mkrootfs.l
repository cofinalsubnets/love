; tools/mkrootfs.l -- pack the machine's own files (inle/rootfs/) as a ustar: the kernel's
; second initrd, walked at the root of every inle boot where the tree's is walked
; under /proc/src.
;
;   love tools/mkrootfs.l DIR out.tar
;
; the walk is sorted and every mtime pinned to 0, tools/selfpack.l's law, so the same files
; lay the same bytes; the top rides as `rootfs`, stripped by the kernel's walk the way
; the tree's top is.
(borrow "apps/gz.l")             ; tar's own borrow, named by path the way selfpack does
(borrow "apps/tar.l")
(borrow 'posix)
(: (rf-die m) (say err ("mkrootfs: " + m + "\n"), quit 1)
   ; re-home the entries under top; the walk is sorted, so order holds
   (rf-home es top acc)
    (? (one? es) (rev acc)
       (: e <es
          _ (pin e 'nom (top + "/" + tar-get e 'nom ""))
          (rf-home >es top (e . acc))))
   (rf-main av)
    (? (2 != tally av) (rf-die "usage: love tools/mkrootfs.l DIR out.tar")
       (: dir <av
          out (av 1)
          g (tar-gather dir "")
          _ (!g ? (rf-die ("cannot read " + dir)))
          te (tar-entry "rootfs" 'dir "")
          _ (pin te 'mode (tar-get <(<>g) 'mode 493))
          a (tar-pack (tar-level (te . rf-home >(<>g) "rootfs" ()) 0))
          _ (!a ? (rf-die "cannot pack"))
          q (open out "w")
          _ (!(hot? q) ? (rf-die ("cannot write " + out)))
          _ (say q a)
          (close q, 0)))
   (rf-main >argv))
