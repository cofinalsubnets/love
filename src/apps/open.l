; open -- a link or a file, handed to what the system opens it with: xdg-open on linux and the
; bsds, macos's open, and under android's bridge a view intent through its door (LOVE_DROID)
;   love open URL|FILE
; android lends another app none of this one's files, so there only a link opens
(module (open open-main open-link?)
(borrow 'posix)
(borrow 'droid)
(:
 open-usage "usage: love open URL|FILE   in what the system opens it with (under android, a link)"
 ; a scheme of two or more and its colon: "c:" is a dos path, not a link
 (open-link? x)
  (: (go i) (i < #x && (x i @ c (65 <= c <= 90 || 97 <= c <= 122 || 0 < i && (48 <= c <= 57 || c = 43 || c = 45 || c = 46)))
              ? (go (i + 1)) (1 < i < #x && x i = 58))
     (go 0))
 (open-run p x) (spawn [p x] @ k (wait k @ c (c = 127 ? (udie 1 ("open: no " + p + " here")) c)))
 (open-droid x)
  (: _ (open-link? x ? 0 (udie 1 "open: under android only a link opens: another app can't read this one's files"))
     s (jni-open 0 @ s (hot? s ? s (udie 1 "open: the bridge's door is gone")))
     r (droid-view s x)
     (close s, two? r ? (udie 1 ("open: " + r 1)) 0))
 (open-main as)
  (as @ [x] (? (getenv "LOVE_DROID" @ p (string? p && 0 < #p)) (open-droid x)
               (love-os = 'macos) (open-run "open" x)
               (elem love-os ['linux 'freebsd 'netbsd]) (open-run "xdg-open" x)
               (udie 1 ("open: nothing opens things on " + show love-os)))
        _ (udie 2 open-usage))
 _ (pins (cite 'verbs 'tab) 'open (udoor 'open open-main open-usage 1 1)))
) ; module open
