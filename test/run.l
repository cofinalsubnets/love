; hark and getenv, host only: (hark argv) answers (status . stdout), an errno nom, or 'badarg.
; no child reads stdin: it inherits the corpus pipe and would eat it
(hosted ? (test
  ; --- ran: exit 0, no output ---
  (two? (hark ["true"]))
  (0 = cap (hark ["true"]))
  (0 = sat >(hark ["true"]))             ; `true` writes nothing

  ; --- a nonzero exit code is reported as-is ---
  (1 = cap (hark ["false"]))

  ; --- stdout is captured (echo appends a newline) ---
  (hark ["echo" "hi"] @ r ((0 = cap r) && ("hi\n" = cup r)))

  ; --- multiple args are marshalled in order, with no shell in between ---
  (hark ["printf" "%s-%s" "ab" "cd"] @ r ("ab-cd" = cup r))

  ; --- a program that can't be spawned -> its errno's nom, not a chain ---
  ('enoent = (hark ["/no/such/prog-xyzzy"]))    ; abs path: ENOENT
  ('enoent = (hark ["no-such-prog-xyzzy"]))     ; PATH miss: ENOENT

  ; --- our-side misuse -> 'badarg, which is not a posix name ---
  ('badarg = (hark 0))                          ; empty argv (nil)
  ('badarg = (hark ["echo" 5]))                 ; 5 is not a string

  ; --- output larger than the initial buffer exercises the grow path ---
  (hark ["seq" "20000"] @ r ((0 = cap r) && (65536 < sat >r)))

  ; --- getenv: PATH is set; an unset name answers () ---
  (string? (getenv "PATH"))
  !(getenv "GWEN_DEFINITELY_UNSET_12345")) 0)
