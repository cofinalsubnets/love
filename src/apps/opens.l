; opens -- what the phone's app opens: a command kept in the nest, the app's own where none is.
;   love opens [WORD [ARG ..]]   a verb and its arguments from the next start on; alone, says which
;   love opens --default         the app's own again
; the app's entry asks (opens-get 0), and runs it where (opens-ok? ws)
(module (opens opens-main opens-usage opens-file opens-get opens-set opens-ok? opens-word)
(borrow '(posix cli))
(:
 opens-usage "usage: love opens [WORD [ARG ..] | --default]"
 (opens-file _) (cite 'path 'nest 0 + "/etc/opens")
 (slurp-file p) (open p "r" @ q (hot? q ? (slurp q @ s (close q, s)) ()))
 ; the words kept, one a line; () none
 (opens-get _) (slurp-file (opens-file 0) @ t (string? t ? (filter (w \ 0 < #w) (split "\n" t)) ()))
 (opens-ok? ws) (two? ws && all (w \ 0 < #w && !(elem 10 w)) ws && lit? (cite 'verbs 'word <ws) ? 1 0)
 (opens-set ws) (: p (opens-file 0) _ (mkdir (cite 'path 'nest 0) 493) _ (mkdir (snip p 0 (#p - 6)) 493)
   (? (atom? ws) (unlink p)
      (: q (open p "w") (hot? q ? (say q (foldl (a \ w \ a + w + "\n") "" ws), close q, 0) 1))))
 ; a console's word: opens "lush", opens "play court", opens "" the app's own again
 (opens-word t) (: ws (filter (w \ 0 < #w) (split " " t))
   (? (atom? ws) (opens-set (), "the app's own")
      (opens-ok? ws) (opens-set ws, t)
      (<ws + " is no verb here")))
 (opens-main as)
  (? (atom? as) (puts (foldl (a \ w \ a + (a = "" ? "" " ") + w) "" (opens-get 0 @ () ["(the app's own)"] ws ws) + "\n"), flush out, 0)
     (<as = "--default") (opens-set (), 0)
     (opens-ok? as) (opens-set as)
     (say err ("opens: " + <as + " is no verb here\n"), flush err, 2))
 _ (pins (cite 'verbs 'tab) 'opens (udoor 'opens opens-main opens-usage 0 99)))
) ; module opens
