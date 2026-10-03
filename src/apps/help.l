; help -- the code, found by what it says: every line of every text file under /love, the tree
; this binary carries, narrowed as it is typed at (seek.l). enter opens the line in vi, and
; :q comes back to the list; esc leaves. /love is read-only, so a :w there is refused.
;   love help [WORD..]     the words start the query; not a terminal, the lines that match
;                          print as path:line: text, as grep -n would
(module (help help-main help-lines)
(borrow 'posix)
(borrow 'seek)
(:
 help-root "/love"
 ; every file under p, in name order
 (help-walk p) (readdir p @ ns (atom? ns ? [p] (catmap (n \ help-walk (p + "/" + n)) (sort ns))))
 (help-split s) (cite 'kore 'usplit 10 s @ ls (two? ls && #(last ls) = 0 ? (butlast ls) ls))
 ; [path line text] per line, numbered from 1; a file holding a NUL is not text
 (help-lines root)
  (catmap (f \ uread f @
             [1 s] (? (0 <= subidx s (string 0) 0) ()
                      (help-split s @ ls (map (p \ [f (<p + 1) >p]) (zip ^#ls ls))))
             ())
          (help-walk root))
 (help-rel f) (starts? f (help-root + "/") ? (snip f (#help-root + 1) #f) f)
 (help-label it) (help-rel (it 0) + ":" + show (it 1) + ": "
                  + string (map (c \ c = 9 ? 32 c) (chars (it 2))))
 (help-vi it)
  (uread (it 0) @ [1 s] ((cite 'vi 'vi-buffer) (help-split s) (it 0) 0 (it 1)) 0)
 (help-loop d) (seek-run d @ it (two? it ? (help-vi it, help-loop d) 0))
 help-usage "usage: love help [WORD..]   the code under /love, found by what it says"
 (help-main as)
  (: q (foldl (a \ w \ a + (0 < #a ? " " "") + w) "" as)
     d (seek-new (help-lines help-root) (it \ it 2) help-label "help")
     _ (0 < #q ? (seek-q d q) d)
     (? (two? (tty 1)) (help-loop d)
        (0 = #q) (say err (help-usage + "\n"), 1)
        (each (d 'hits) (it \ puts (help-label it + "\n")), 0)))
 _ (pins (cite 'verbs 'tab) 'help (udoor 'help help-main help-usage 1 1)))
) ; module help
