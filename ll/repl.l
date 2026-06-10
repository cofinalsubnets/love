; the read-eval-print loop and its multi-line line editor. loaded after
; boot.l by the interactive frontends (host and kernel).
;
; parsing is delegated to the C reader: the editor's flattened charlist
; becomes a synthetic input port via (strin cl), and (fread port e) walks
; it one datum at a time. fread returns the datum on success; its eof-bit
; conditions route through the trap continuation, whose default delivers
; the sentinel `e` on clean EOF and the port itself on eof-more (input
; ends inside an unfinished form). that lets parseall distinguish "all
; done" from "keep editing" -- parseall is the lisp-visible face of the
; eof bit, and a global `trap` function takes over that dispatch.
;
; the editor buffer is a four-zipper threaded positionally through
; the editor functions: u (lines above the cursor, reversed), l (chars
; left of cursor on the current line, reversed), r (chars at/after
; cursor on the current line, in order), d (lines below). state is
; passed through helpers in CPS so no table is allocated per
; keystroke. on each tick the whole multi-line input is redrawn from
; the prompt's row via relative cursor motion; the loop tracks rows
; above the cursor from the previous render so terminal scrolling
; doesn't desync.
;
; command history is a parallel zipper (hu, hd) over previously-
; submitted buffer states. when the buffer cursor is on the top line,
; up navigates history toward older; mirrored for down. on first edit
; to a recalled entry, the pristine version is restored to its slot
; and the buffer becomes a new entry, so the original survives.
(: m (nom 0) eofsym (nom 0)

   (revcat a b) (foldl (flip X) b a)

   ; drain a charlist into a list of all the datums it holds. returns m
   ; if the input ends inside an unfinished form; otherwise the (possibly
   ; empty) list of parsed datums.
   (parseall cl)
     (: p (strin cl)
        (loop acc)
          (: r (fread p eofsym)
             (? (= r p)      m                 ; port == port: g_status_more
                (= r eofsym) (revcat acc 0)    ; clean EOF: emit in source order
                (loop (X r acc))))
        (loop 0))

   ; --- editor ---

   ; intersperse a list of charlists with newlines, in order
   (joinln ls)
     (? (twop ls)
        (? (twop (B ls))
           (cat (A ls) (X 10 (joinln (B ls))))
           (A ls))
        0)

   ; flatten the editor state into one charlist suitable for parseall
   (flatten u l r d)
     (joinln (revcat u (X (revcat l r) d)))

   ; walk xs forward taking n chars into acc (reversed); when done
   ; call k with (rev (take n xs)) and (drop n xs). stops cleanly at
   ; end-of-xs even if n exceeds the list length.
   (splitat k acc n xs)
     (? (&& (twop xs) (< 0 n)) (splitat k (X (A xs) acc) (- n 1) (B xs))
        (k acc xs))

   ; map non-printables to space; otherwise pass through
   (prc c) (putc (? (&& (<= 32 c) (< c 127)) c 32))

   ; CPS editor primitives. each takes the loop as continuation k
   ; and forwards a new (u l r d) to it; helpers are no-ops at their
   ; boundary. left/right wrap across lines; bsp at column 0 merges
   ; the current line onto the previous; del at end-of-line splices
   ; the next line on. up/down preserve column, clamped to the
   ; destination line's length.
   (edleft k u l r d)
     (? (twop l) (k u (B l) (X (A l) r) d)
        (twop u) (k (B u) (rev (A u)) 0 (X (revcat l r) d))
        (k u l r d))
   (edright k u l r d)
     (? (twop r) (k u (X (A r) l) (B r) d)
        (twop d) (k (X (revcat l r) u) 0 (A d) (B d))
        (k u l r d))
   (edbsp k u l r d)
     (? (twop l) (k u (B l) r d)
        (twop u) (k (B u) (rev (A u)) r d)
        (k u l r d))
   (eddel k u l r d)
     (? (twop r) (k u l (B r) d)
        (twop d) (k u l (A d) (B d))
        (k u l r d))
   (edhome k u l r d) (k u 0 (revcat l r) d)
   (edend  k u l r d) (k u (revcat r l) 0 d)
   ; edtop / edbot jump across the whole buffer: cursor at the start of
   ; the topmost line / end of the bottommost line. on a single-line
   ; buffer they degenerate to edhome / edend.
   (edtop k u l r d)
     (? (twop u) (: ru (rev u)
                  (k 0 0 (A ru) (cat (B ru) (X (revcat l r) d))))
        (k u 0 (revcat l r) d))
   (edbot k u l r d)
     (? (twop d) (: rd (rev d)
                  (k (cat (B rd) (X (revcat l r) u)) (revcat (A rd) 0) 0 0))
        (k u (revcat r l) 0 d))
   (edup k u l r d)
     (? (twop u) (splitat (\ ll rr (k (B u) ll rr (X (revcat l r) d)))
                          0 (hash l) (A u))
        (k u l r d))
   (eddown k u l r d)
     (? (twop d) (splitat (\ ll rr (k (X (revcat l r) u) ll rr (B d)))
                          0 (hash l) (A d))
        (k u l r d))

   ; --- history zipper ---

   ; pack the buffer's four halves into one slot for history storage.
   (mkframe u l r d) (X u (X l (X r d)))

   ; if cur holds a pristine recall, restore it at its slot in hu;
   ; called before any mutating edit so the original survives.
   (detach hu cur) (? (twop cur) (X cur hu) hu)

   ; predicates over the buffer used by the history navigation rules
   ; below: empty buffers don't get pushed during normal nav, and
   ; off-the-end nav only pushes when the buffer parses to a value.
   (emptybuf u l r d) (&& (nilp u) (nilp l) (nilp r) (nilp d))
   (parses u l r d)   (twop (parseall (flatten u l r d)))

   ; up/down through the history zipper. on a normal pop, push the
   ; current buffer onto the other side (skipping if empty); if the
   ; other side is empty (hu or hd) but we're on a real recall (cur
   ; non-nil) and the buffer parses, push and scroll into a fresh
   ; empty line.
   (uphist k u l r d hu hd cur)
     (? (twop hu)
        (: e (A hu)
           nhd (? (emptybuf u l r d) hd (X (mkframe u l r d) hd))
           (k (A e) (A (B e)) (A (B (B e))) (B (B (B e))) (B hu) nhd e))
        (&& (twop cur) (parses u l r d))
        (: nhd (X (mkframe u l r d) hd)
           (k 0 0 0 0 hu nhd 0))
        (k u l r d hu hd cur))
   (downhist k u l r d hu hd cur)
     (? (twop hd)
        (: e (A hd)
           nhu (? (emptybuf u l r d) hu (X (mkframe u l r d) hu))
           (k (A e) (A (B e)) (A (B (B e))) (B (B (B e))) nhu (B hd) e))
        (&& (twop cur) (parses u l r d))
        (: nhu (X (mkframe u l r d) hu)
           (k 0 0 0 0 nhu hd 0))
        (k u l r d hu hd cur))

   ; map a raw byte (or escape sequence) to an event code:
   ; printable >0; -1 left, -2 right, -3 bsp, -4 del, -5 home,
   ; -6 end, -7 quit, -8 up, -9 down, -10 buffer top, -11 buffer end;
   ; 10 = enter.
   ;
   ; after `ESC [ 1` there are two shapes: `~` is plain Home; `; M F`
   ; carries a modifier digit M (5=ctrl, 2=shift, ...) and a final byte
   ; F. modified Home/End jump to buffer top/end; modified arrows fold
   ; back to plain arrow events (we don't act on the modifier).
   (edesc1 c) (? (= c 126) -5
                 (= c 59)  (: _ (getc 0)
                              d (getc 0)
                              (? (= d 72) -10 (= d 70) -11
                                 (= d 65)  -8 (= d 66)  -9
                                 (= d 67)  -2 (= d 68)  -1 0)))
   (edesc x) (? !(= 91 (getc 0)) 0
     (: c (getc 0)
        (? (= c 68) -1 (= c 67) -2
           (= c 65) -8 (= c 66) -9
           (= c 72) -5 (= c 70) -6
           (= c 49) (edesc1 (getc 0))
           (= c 55) (: _ (getc 0) -5)
           (|| (= c 52) (= c 56)) (: _ (getc 0) -6)
           (= c 51) (: _ (getc 0) -4) 0)))
   (edev x) (: c (getc 0)
     (? (|| (= c -1) (= c 4)) -7
        (= c 3) -12
        (|| (= c 13) (= c 10)) 10
        (|| (= c 8) (= c 127)) -3
        (= c 1) -5 (= c 5) -6 (= c 27) (edesc 0)
        (&& (<= 32 c) (< c 127) c)))

   ; redraw the buffer in place. pra is "rows above the cursor from
   ; the previous render" -- we move up that many rows first so we
   ; land back on the prompt's row. all motion is relative: nothing
   ; depends on a saved absolute cursor, so the terminal scrolling
   ; (when the buffer reaches the last row) doesn't desync us. pl is
   ; the prompt's column; the topmost line shares it, subsequent
   ; lines start at column 0.
   (edrender pl pra u l r d)
     (: _ (? (< 0 pra) (do (putc 27) (putc 91) (putn pra 10) (putc 65)) 0)
        _ (putc 13)
        _ (? (< 0 pl)  (do (putc 27) (putc 91) (putn pl 10)  (putc 67)) 0)
        _ (putc 27) _ (putc 91) _ (putc 74) ; clear to end of screen
        _ (each (rev u) (\ ln (do (each ln prc) (putc 10))))
        _ (each (revcat l r) prc)
        _ (each d (\ ln (do (putc 10) (each ln prc))))
        ld (hash d)
        col (+ (? (twop u) 0 pl) (hash l))
        _ (? (< 0 ld) (do (putc 27) (putc 91) (putn ld 10) (putc 65)) 0)
        _ (putc 13)
        _ (? (< 0 col) (do (putc 27) (putc 91) (putn col 10) (putc 67)) 0)
        (fflush out))

   ps1 ";;; "

   ; print the prompt, then dispatch events until ^D or until enter
   ; at end-of-buffer with the buffer fully parsed. enter always
   ; splits the current line at the cursor; only when the cursor is
   ; at end-of-buffer do we try parseall, which may yield multiple
   ; datums on one line. returns eofsym on ^D, otherwise
   ; (X vs (X nhu nhd)) so the repl can thread history.
   ;
   ; the loop carries pra = rows above the cursor as of the previous
   ; render. edrender uses pra to move back up to the prompt's row
   ; before redrawing, so we never rely on a saved absolute cursor
   ; position -- terminal scrolling stays consistent. since nothing
   ; between renders moves the cursor (no putc except in the submit
   ; branch which exits), the next render's pra is always (pin u) of
   ; the CURRENT frame, regardless of how the state transitions; we
   ; cache it as npra and route every recursion through it.
   ;
   ; kloop wraps the CPS helpers for non-mutating motion; kedit does
   ; the same for mutating ops (backspace, delete) and applies detach
   ; on the way. khist is the continuation used by uphist/downhist
   ; for history navigation. cur is the pristine frame of the
   ; currently-recalled entry, or 0 if the buffer is a free edit.
   (edline hu hd)
     (: pr ps1
        _ (puts pr)
        pl (hash pr)
        (loop pra u l r d hu hd cur)
          (: _ (edrender pl pra u l r d)
             c (edev 0)
             npra (hash u)
             (kloop uu ll rr dd) (loop npra uu ll rr dd hu hd cur)
             (kedit uu ll rr dd) (loop npra uu ll rr dd (detach hu cur) hd 0)
             (khist uu ll rr dd nhu nhd ncur) (loop npra uu ll rr dd nhu nhd ncur)
             (? (= c -7) eofsym
                (= c 10) (: nu (X (rev l) u)
                            (? (&& (nilp r) (nilp d))
                               (: vs (parseall (flatten nu 0 r d))
                                  (? (= vs m)
                                     (loop npra nu 0 r d (detach hu cur) hd 0)
                                     (: _ (putc 10)
                                        nhu (? (nilp vs) (revcat hd (detach hu cur))
                                               (twop cur) (revcat hd (X cur hu))
                                               (revcat hd (X (mkframe u l r d) hu)))
                                        (X vs (X nhu 0)))))
                               (loop npra nu 0 r d (detach hu cur) hd 0)))
                (< 0 c)  (loop npra u (X c l) r d (detach hu cur) hd 0)
                (= c -1) (edleft  kloop u l r d)
                (= c -2) (edright kloop u l r d)
                (= c -3) (edbsp   kedit u l r d)
                (= c -4) (eddel   kedit u l r d)
                (= c -5) (edhome  kloop u l r d)
                (= c -6) (edend   kloop u l r d)
                (= c -8) (? (twop u) (edup    kloop u l r d)
                            (uphist   khist u l r d hu hd cur))
                (= c -9) (? (twop d) (eddown  kloop u l r d)
                            (downhist khist u l r d hu hd cur))
                (= c -10) (edtop kloop u l r d)
                (= c -11) (edbot kloop u l r d)
                (= c -12) (: _ (puts "^C") _ (putc 10)
                             (? (emptybuf u l r d) eofsym (edline hu hd)))
                (loop npra u l r d hu hd cur)))
        (loop 0 0 0 0 0 hu hd 0))

   ; evaluate a single parsed datum cooperatively. (ev v) is spawned as a
   ; worker; the main task polls done?/key? and yields. on Ctrl+C (byte 3)
   ; the worker is killed; any other byte is silently dropped (matches most
   ; shells). prints the result (or ^C) before returning -1; caller adds
   ; the trailing newline.
   ;
   ; this poll is the repl's control-flow seam under the trap model: a
   ; worker that scares is terminated by the default trap and done? flips,
   ; so the repl survives evaluation errors by construction. a global
   ; `trap` function gets control at the scare (condition data on struct g)
   ; BEFORE the task dies; either way done?/key? is where the repl resumes.
   (do_eval v)
     (: pid (spawn ev v)
        (poll _)
          (? (done? pid) (: r (wait pid) _ (putx r) -1)
             (key? 0)    (: c (getc 0)
                            (? (= c 3) (do (puts "^C") (kill pid) -1)
                               (poll 0)))
             (do (yield 0) (poll 0)))
        (poll 0))

   ; the outer (: ...) has no trailing body expression: every binding
   ; defined inside it becomes a global, which lets t/repl.l drive the
   ; editor and parser directly. the host and kernel frontends call
   ; (repl 0 0) explicitly to start the loop.
   (repl hu hd)
     (: r (edline hu hd)
        (? (= r eofsym) 0
           (: vs  (A r)
              nhu (AB r)
              nhd (BB r)
              _ (each vs (\ v (: _ (do_eval v) (putc 10))))
              (repl nhu nhd)))))
