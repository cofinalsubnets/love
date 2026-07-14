; crew/reef/reeftest.l -- the reef gate: a sandbox store driven end to end
; (record / log / diff, tips + snap + deps + the content addresses). runs under
; `make test_reef`: cat test/00-init.l $(reeffiles) THIS | out/host/ai -- host
; nifs (sha256, readdir, chdir), so it stays OFF the corpus like the other
; hostnif tests. the make target clears the sandbox first; cwd is the repo
; root, and everything here happens inside out/host/.reeftest.
(: _ (mkdir "out" 493) _ (mkdir "out/host" 493)
   _ (mkdir "out/host/.reeftest" 493)
   cd (chdir "out/host/.reeftest")
   _ (? (! cd) () (: _ (puts "reeftest: chdir failed\n") (quit 1)))
   ; the same-text equality for list-shaped store values
   (seq a b) ((show a) = (show b))
   ; the tree: two files, one ignored dir
   _ (mkdir "sub" 493)
   _ (rf-lay "a.txt" "one\ntwo\nthree\n")
   _ (rf-lay "sub/b.txt" "hello\n")
   _ (mkdir "junk" 493)
   _ (rf-lay "junk/x" "never\n")
   _ (rf-mk ())
   _ (rf-lay ".reef/ignore" "junk\n")
   p1 (reef-record "first")
   s1 (rf-snap ())
   again (reef-record "again"))

(assert
 (64 = (tally p1))                                     ; a real content address
 (seq (rf-tips ()) `(p1))                              ; the one tip
 (2 = (tally s1))                                      ; junk/ stayed out
 ("a.txt" = <<s1)                                      ; path-sorted
 ((rf-blob <><s1) = "one\ntwo\nthree\n")               ; the blob rides its hash
 (! again)                                             ; a clean tree records nothing
 (p1 = (sha256 <>(rf-look (".reef/patch/" + p1)))))    ; the id IS the file's hash

; mutate: one changed, one born, one dead
(: _ (rf-lay "a.txt" "one\ntwo point five\nthree\n")
   _ (rf-lay "c.txt" "born\n")
   _ (unlink "sub/b.txt")
   nd (reef-diff ())
   p2 (reef-record "second")
   f2 (rf-patch p2))

(assert
 (3 = nd)                                              ; diff saw all three
 (seq (rf-fld f2 'deps) `(p1))                         ; the context reads p1's writes
 (3 = (tally (rf-fld f2 'hunks)))
 (seq (rf-tips ()) `(p2))                              ; p1 is no longer maximal
 (! (member? "sub/b.txt" (: (go m acc) (? (two? m) (go >m (link <<m acc)) acc)
                            (go (rf-snap ()) ()))))    ; the death left the snap
 (0 = (reef-diff ())))                                 ; recorded = working again

; a patch of only births depends on nothing: a second tip (the DAG, locally)
(: _ (rf-lay "d.txt" "free\n")
   p3 (reef-record "third")
   f3 (rf-patch p3))

(assert
 (! (rf-fld f3 'deps))                                 ; no context anywhere
 (2 = (tally (rf-tips ())))                            ; two maximal patches
 (member? p2 (rf-tips ())) (member? p3 (rf-tips ()))
 (3 = (reef-log ())))                                  ; three patches told

(: _ (puts "reef: ok") _ (putc 10) 0)
