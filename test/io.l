; the port nifs on an explicit port, and open/close for fd-backed ports

(test
  ; in and out are heap ports, so show renders an address
  (string? (show in))
  (string? (show out))
  (0 < sat (show in))
  (0 < sat (show out))

  ; unget + get roundtrip on stdin -- one top-level form, or the repl eats the pushback
  (: (rt c) (unsee in c, see in)
   (65 = rt 65                                ; `&&`, not `do`: do answers its last
    && 32 = rt 32                             ; operand and the rest go unchecked
    && 255 = rt 255))

  ; the pair after a real read, on a tap: a real read of `in` eats the corpus
  (tap '(120 121) @ t           ; a tap taps a charlist -- (tap "xy") is the empty one
   (see t,
    (99 = unsee t 99
     && 99 = see t
     && 121 = see t   ; ..and y is still there, unshifted by the detour
     && -1 = see t))) ; ..and the end is still the end

  ; a non-port reads as an empty stream, so a read-until-(-1) loop over one ends
  (-1 = see 42)
  (-1 = see "notaport")

  ; port? passes every port shape and nothing else
  (port? in)
  (port? out)
  (port? (tap "x"))
  (port? (jug 0))
  !(port? 42)
  !(port? "notaport")
  !(port? ())
  !(port? (x \ x))
  !(port? (cask 4))
  ; slurp of a non-port drains as the empty stream; every drain lands text
  ("" = slurp 42)   (string? (slurp 42))
  ("" = slurp ())
  (slurp (tap "") = slurp 42)

  ; file roundtrip through /tmp; the clock payload keeps a stale file from passing
  (files ? (: txt (show (clock 0))
     wp (open "/tmp/l-io-test" "w")
     _ (say wp txt)
     _ (close wp)
     rp (open "/tmp/l-io-test" "r")
     (slurp acc) (see rp @ c (c = -1 ? (rev acc) (slurp (c . acc))))
     rd (string (slurp 0))
     (close rp,
      txt = rd)) 1)

  ; --- chug and unchug: the run, and the run put back; on a file, never `in` ---
  (files ? (: pth "/tmp/l-io-unchug"
     wp (open pth "w") _ (say wp "abcdefghij") _ (close wp)
     p (open pth "r")
     c (see p) _ (unsee p c)
     whole (chug p)                     ; the pushback byte, then the whole run
     back4 (unchug p 4)
     tail4 (chug p)                     ; ..and the run is those four, unshifted
     backall (unchug p 99)              ; an over-ask clamps to what was drained
     again (chug p)
     back10 (unchug p 99)
     fwd3 (unchug p -3)                 ; a negative take steps the position forward
     rest7 (chug p)
     (close p,
      ; &&, not `do`: do answers its last clause alone
      ("abcdefghij" = whole
       && 4 = back4    && "ghij" = tail4
       && 10 = backall && "abcdefghij" = again
       && 10 = back10  && 3 = fwd3      && "defghij" = rest7))) 1)
  ; nothing to give back is 0, never a scare; the count is the caller's only check
  (0 = unchug (tap '(120 121)) 4)
  (0 = unchug 42 4)
  (0 = unchug "notaport" 4)
  (0 = unchug in 0)                   ; the count refuses before the port is touched
  ; never a nonzero unchug of `in`: the suite is fed on stdin, so it would eat its own source
  (0 = unchug (tap '(120 121)) -2)

  ; --- tap: a charlist-backed read-only port ---
  (string? (show (tap 0)))
  (0 < sat (show (tap 0)))
  ; each call allocates a fresh port object
  (: p (tap 0) q (tap 0) (p != q))
  ; a charm outside 0..255 lands as its low byte, so a -1 cannot forge the end
  (tap '(300 -1 65) @ p
   (44 = see p && 255 = see p && 65 = see p && -1 = see p))
  ; counted by forcing, never by tally: a flow is lazy past its first run
  (: (fw cl n) (two? cl ? (fw (>cl @ t (lit? t ? (t ()) t)) (n + 1)) n)
     (2 = (fw (flow (tap '(-1 65))) 0)))

  ; --- once: the promise ---
  ; runs at most once and remembers, fired with the unit; the witness is a count the body bumps
  (: c {}
     th (once (u \ peep c 0 0 @ k (pin c 0 (k + 1), k)))
     a (th ()) b (th ()) d (th ())
     (a = b && b = d && 1 = peep c 0 0))
  ; a promise of () still forces once, though a pinned () reads like an unforced slot
  (: c {}
     th (once (u \ (pin c 0 (peep c 0 0 + 1), ())))
     (th (), th (),
      !(th ()) && 1 = peep c 0 0))

  ; --- flow: a port as a charlist whose tail is a promise of the next gulp ---
  (: p (tap '(40 49 32 50 41))                          ; "(1 2)"
     r (sound (flow p))
     (two? r && '(1 2) = <r))
  ; a run's cells are ordinary conses; a flow ends in a promise or ()
  (flow (tap '(97 98)) @ f
   (97 = <f && 98 = <>f && (lit? >>f || !(>>f))))
  ; an empty port is the empty charlist, not a promise of one
  !(flow (tap ()))
  ; a position forced twice answers the same; the unget gives the port something left to give
  (: p (tap '(97)) f (flow p) t >f
     _ (unsee p 98)
     x (t ()) y (t ())
     ; x's tail is a promise, so it is not '(98) by `=`
     (lit? t && 98 = <x && x = y))

  ; --- sound: one datum per call, off text ---
  ; single datum: symbol, list, quoted form, string literal
  ('a = <(sound '(97)))           ; "a"
  (<(sound '(40 49 32 50 41)) @ d ; "(1 2)"
   (two? d && 1 = <d && 2 = <>d))
  (<(sound '(39 49)) @ d                           ; "'1" -> (` 1)
   (two? d && 1 = <>d))
  (string (104 . 105 . 0) = <(sound '(34 104 105 34)))   ; "hi"

  ; sequential reads thread the residue; the last one is the clean end
  (: a (sound '(49 32 50 32 51))                        ; "1 2 3"
     b (sound >a) c (sound >b)
     (1 = <a && 2 = <b && 3 = <c && !(sound >c)))

  ; whitespace and ;-comments are skipped between datums
  (1 = <(sound '(32 32 49 32 32)))            ; "  1  "
  (2 = <(sound '(59 32 99 109 116 10 50)))    ; "; cmt\n2"

  ; a bare close-paren at top level is a clean end
  !(sound '(41))                                  ; ")"

  ; --- torn: the text ran out inside a shape ---
  ('torn = sound '(34 97))                            ; unterminated string
  ('torn = sound '(39))                               ; dangling quote

  ; torn and the clean end are distinct
  ('torn != sound ())

  ; a torn read resumes: hand back the same text with the rest appended
  (sound ('(40 49) + '(32 50 41)) @ r (two? r && '(1 2) = <r))

  ; mixed sequence, residue threaded: "() 1"
  (: a (sound '(40 41 32 49)) b (sound >a)
     (!<a && 1 = <b && !(sound >b)))

  ; sound forces an unforced tail and reads on, so a closure handed to it is called
  (sound (once (u \ map "(1 2)" ^5)) @ r
   (two? r && '(1 2) = <r)))
