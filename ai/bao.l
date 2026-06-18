; bao -- the shell core: the read-eval-print loop, its multi-line line editor,
; the stream shell (zev/zevs/charms), the floor handler (welp), and the host-only
; pty wrapper (wrap). bao is the BAKED shell core for all three frontends -- the
; host (out/host/ai), the freestanding kernel (kmain.c), and the ai0 bootstrap
; self-test -- loaded after the prel. (It was repl.l; the editor/repl internals
; used to LEAK as user-visible book globals because the corpus tested them by
; name. Now the editor + repl + the pty wrapper live inside one closure, so only
; the entry points -- shell, welp, edraw, wrap, bao, plus the stream shell
; zev/zevs/charms -- are book globals.)
;
; parsing is delegated to the C reader: the editor's flattened charlist is
; implicitly parenthesized and read as ONE expression via (sip ..) + read
; -- a line `x y z` is the application (x y z), and infix works at the
; prompt (factored at compile time by opfix; reading is structural).
; read's more-bit conditions route through the help continuation, whose
; default delivers the port itself on more (input ends inside an unfinished
; SHAPE -- an unclosed paren or string; a trailing operator is a complete
; datum that folds to a partial). that lets parseall distinguish "submit"
; from "keep editing" -- parseall is the lisp-visible face of the more bit;
; a global `help` takes over that dispatch.
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

; charms: the global character construction -- the LAZY charlist. a charm is
; a sat (a non-negative fixnum); a CHARS is a bare charlist (eager, ends at
; 0); a CHARMS is the colist: (cap cs) is a charm, (cup cs) is a top, and
; the tail forced with the empty -- ((cup cs) ()) -- types as charms + 0,
; the coproduct, 0 the end (the floor as the nil injection). consumers
; dispatch on KIND: two? is a cell, anything else the end. `charms` is also
; the canonical lift into the construction: chars lift cell by cell, a port
; (the HOT charms) pulls one byte per force (-1 ends it), charms pass
; through, the end lifts to itself. charms->chars realizes a finite charms.
; NB the cell test dispatches on the TAIL's kind -- a chain or nil is chars,
; anything else is taken as the forcing top. (lit? is no use here: it is
; hot-based and answers true for every heap value, chains included -- the
; lit?-spans-bands pin.)
(: (charms s)
   (? (two? s) (: t (cup s)
                  (? (two? t) (link (cap s) (\ u (charms t)))   ; chars: lift, lazy tail
                     (nil? t) (link (cap s) (\ u ()))           ; the last chars cell
                     s))                                        ; a top tail: charms already
      (hot? s) (: c (fgetc s)                                ; a port is the hot charms
                     (? (= c -1) () (link c (\ u (charms s)))))
      ())
   (charms->chars s)
   (: cs (charms s)
      (? (two? cs) (link (cap cs) (charms->chars ((cup cs) ()))) 0)))
; zev: charms -> top, the reverse shell of the compiler -- the lane every
; shell ultimately feeds into. takes the global construction (anything the
; `charms` lift takes: chars, a port, charms proper), reads ONE form from it
; (structurally -- the reader knows no operators) and sends it through the
; same core as ev (opfix, wev, ana, cata): the full hull charms -> top in
; one call. nothing readable -- empty input or an unfinished shape -- is
; nothing. the C reader pulls from a port, so zev realizes the (finite)
; charms first; the lazy-pull seam is where the lisp reader lands next.
(: (zev s)
   (: p (sip (charms->chars s)) e (nom 0) r (read p e)
      (? (id? r e) 0 (id? r p) 0 (ev r))))
; zevs: the stream shell -- a port is the LAZY charms, and zevs drinks it:
; read and eval every form until the stream ends (eof, or input ends inside
; an unfinished shape); the value is the last form's. ev late-binds through
; the book ((ev 'ev r)) so the one definition drives both of ai0's passes
; (c0 first, the hatched ev' second); the host's stdin runner and the
; ai0/kernel corpus runners are all this function now.
(: (zevs p)
   ((: (g e z) (: r (read p e)
       (? (id? r e) z (id? r p) z (g e (ev 'ev r)))))
    (nom 0) 0))

; --- the shell core: editor + repl + welp + the pty wrapper, all closure-private.
; the body of this (: ..) returns the public entry points as a list, defglob'd
; below; everything else (the ed* editor, parseall, do_eval, the history zipper,
; pump/waitfor, the raw-line decode) stays inside this scope, OFF the global book.
(: _                                ; the export-list holder: `_` never leaks to the book
 (: m (nom 0) eofsym (nom 0)

   (revcat a b) (foldl (flip link) b a)

   ; parse a charlist as ONE expression: the line is implicitly parenthesized,
   ; so `x y z` reads as (x y z) -- a single application -- and infix works at
   ; the prompt (`1 = 1` factors to ((= 1 1)) = 1). a lone value is unchanged
   ; by (f) == f. returns m if the input ends inside an unfinished shape
   ; (an unclosed paren or string), 0 for a blank line, else a one-form list.
   (parseall cl)
     (: p (sip (link 40 (cat cl (L 41))))
        r (read p eofsym)
        (? (= r p)      m                  ; ends inside an unfinished form
           (= r eofsym) 0                  ; unreachable: the wrap always closes
           (id? r ())   0                  ; blank line reads 0 (the wrapped empty form)
           (L r)))

   ; --- editor ---

   ; intersperse a list of charlists with newlines, in order
   (joinln ls)
     (? (two? ls)
        (? (two? (cup ls))
           (cat (cap ls) (link 10 (joinln (cup ls))))
           (cap ls))
        0)

   ; flatten the editor state into one charlist suitable for parseall
   (flatten u l r d)
     (joinln (revcat u (link (revcat l r) d)))

   ; walk xs forward taking n chars into acc (reversed); when done
   ; call k with (rev (take n xs)) and (drop n xs). stops cleanly at
   ; end-of-xs even if n exceeds the list length.
   (splitat k acc n xs)
     (? (&& (two? xs) (< 0 n)) (splitat k (link (cap xs) acc) (- n 1) (cup xs))
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
     (? (two? l) (k u (cup l) (link (cap l) r) d)
        (two? u) (k (cup u) (rev (cap u)) 0 (link (revcat l r) d))
        (k u l r d))
   (edright k u l r d)
     (? (two? r) (k u (link (cap r) l) (cup r) d)
        (two? d) (k (link (revcat l r) u) 0 (cap d) (cup d))
        (k u l r d))
   (edbsp k u l r d)
     (? (two? l) (k u (cup l) r d)
        (two? u) (k (cup u) (rev (cap u)) r d)
        (k u l r d))
   (eddel k u l r d)
     (? (two? r) (k u l (cup r) d)
        (two? d) (k u l (cap d) (cup d))
        (k u l r d))
   (edhome k u l r d) (k u 0 (revcat l r) d)
   (edend  k u l r d) (k u (revcat r l) 0 d)
   ; edtop / edbot jump across the whole buffer: cursor at the start of
   ; the topmost line / end of the bottommost line. on a single-line
   ; buffer they degenerate to edhome / edend.
   (edtop k u l r d)
     (? (two? u) (: ru (rev u)
                  (k 0 0 (cap ru) (cat (cup ru) (link (revcat l r) d))))
        (k u 0 (revcat l r) d))
   (edbot k u l r d)
     (? (two? d) (: rd (rev d)
                  (k (cat (cup rd) (link (revcat l r) u)) (revcat (cap rd) 0) 0 0))
        (k u (revcat r l) 0 d))
   (edup k u l r d)
     (? (two? u) (splitat (\ lz rr (k (cup u) lz rr (link (revcat l r) d)))
                          0 (tally l) (cap u))
        (k u l r d))
   (eddown k u l r d)
     (? (two? d) (splitat (\ lz rr (k (link (revcat l r) u) lz rr (cup d)))
                          0 (tally l) (cap d))
        (k u l r d))

   ; --- history zipper ---

   ; pack the buffer's four halves into one slot for history storage.
   (mkframe u l r d) (link u (link l (link r d)))

   ; if cur holds a pristine recall, restore it at its slot in hu;
   ; called before any mutating edit so the original survives.
   (detach hu cur) (? (two? cur) (link cur hu) hu)

   ; predicates over the buffer used by the history navigation rules
   ; below: empty buffers don't get pushed during normal nav, and
   ; off-the-end nav only pushes when the buffer parses to a value.
   (emptybuf u l r d) (&& (nil? u) (nil? l) (nil? r) (nil? d))
   (parses u l r d)   (two? (parseall (flatten u l r d)))

   ; up/down through the history zipper. on a normal pop, push the
   ; current buffer onto the other side (skipping if empty); if the
   ; other side is empty (hu or hd) but we're on a real recall (cur
   ; non-nil) and the buffer parses, push and scroll into a fresh
   ; empty line.
   (uphist k u l r d hu hd cur)
     (? (two? hu)
        (: e (cap hu)
           nhd (? (emptybuf u l r d) hd (link (mkframe u l r d) hd))
           (k (cap e) (cap (cup e)) (cap (cup (cup e))) (cup (cup (cup e))) (cup hu) nhd e))
        (&& (two? cur) (parses u l r d))
        (: nhd (link (mkframe u l r d) hd)
           (k 0 0 0 0 hu nhd 0))
        (k u l r d hu hd cur))
   (downhist k u l r d hu hd cur)
     (? (two? hd)
        (: e (cap hd)
           nhu (? (emptybuf u l r d) hu (link (mkframe u l r d) hu))
           (k (cap e) (cap (cup e)) (cap (cup (cup e))) (cup (cup (cup e))) nhu (cup hd) e))
        (&& (two? cur) (parses u l r d))
        (: nhu (link (mkframe u l r d) hu)
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
     (: _ (? (< 0 pra) (do (putc 27) (putc 91) (putn pra) (putc 65)) 0)
        _ (putc 13)
        _ (? (< 0 pl)  (do (putc 27) (putc 91) (putn pl)  (putc 67)) 0)
        _ (putc 27) _ (putc 91) _ (putc 74) ; clear to end of screen
        _ (each (rev u) (\ ln (do (each ln prc) (putc 10))))
        _ (each (revcat l r) prc)
        _ (each d (\ ln (do (putc 10) (each ln prc))))
        ld (tally d)
        col (+ (? (two? u) 0 pl) (tally l))
        _ (? (< 0 ld) (do (putc 27) (putc 91) (putn ld) (putc 65)) 0)
        _ (putc 13)
        _ (? (< 0 col) (do (putc 27) (putc 91) (putn col) (putc 67)) 0)
        (fflush out))

   ps1 "> "

   ; print the prompt, then dispatch events until ^D or until enter
   ; at end-of-buffer with the buffer fully parsed. enter always
   ; splits the current line at the cursor; only when the cursor is
   ; at end-of-buffer do we try parseall, which reads the buffer as
   ; one expression. returns eofsym on ^D, otherwise
   ; (X vs (X nhu nhd)) so the repl can thread history.
   ;
   ; the loop carries pra = rows above the cursor as of the previous
   ; render. edrender uses pra to move back up to the prompt's row
   ; before redrawing, so we never rely on a saved absolute cursor
   ; position -- terminal scrolling stays consistent. since nothing
   ; between renders moves the cursor (no putc except in the submit
   ; branch which exits), the next render's pra is always (tally u) of
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
        pl (tally pr)
        (loop pra u l r d hu hd cur)
          (: _ (edrender pl pra u l r d)
             c (edev 0)
             npra (tally u)
             (kloop uu lz rr dd) (loop npra uu lz rr dd hu hd cur)
             (kedit uu lz rr dd) (loop npra uu lz rr dd (detach hu cur) hd 0)
             (khist uu lz rr dd nhu nhd ncur) (loop npra uu lz rr dd nhu nhd ncur)
             (? (= c -7) eofsym
                ; enter CASHES the buffer wherever the cursor sits, as long as
                ; it parses complete; only an unfinished shape splits the line
                ; at the cursor and keeps editing. on submit the buffer goes to
                ; the END of history (the zipper re-merged in original order --
                ; an edited recall's pristine original was already restored by
                ; detach at the first edit), capped at 100 entries.
                (= c 10) (: vs (parseall (flatten u l r d))
                            (? (= vs m)
                               (loop npra (link (rev l) u) 0 r d (detach hu cur) hd 0)
                               (: _ (? (two? d) (: _ (putc 27) _ (putc 91) _ (putn (tally d)) (putc 66)) 0)
                                  _ (putc 10)
                                  nhu (? (nil? vs) (revcat hd (detach hu cur))
                                         (take 100 (link (mkframe u l r d) (revcat hd (detach hu cur)))))
                                  (link vs (link nhu 0)))))
                (< 0 c)  (loop npra u (link c l) r d (detach hu cur) hd 0)
                (= c -1) (edleft  kloop u l r d)
                (= c -2) (edright kloop u l r d)
                (= c -3) (edbsp   kedit u l r d)
                (= c -4) (eddel   kedit u l r d)
                (= c -5) (edhome  kloop u l r d)
                (= c -6) (edend   kloop u l r d)
                (= c -8) (? (two? u) (edup    kloop u l r d)
                            (uphist   khist u l r d hu hd cur))
                (= c -9) (? (two? d) (eddown  kloop u l r d)
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
   ; this poll is the repl's control-flow seam under the help model: a
   ; worker that scares is terminated by the default help and done? flips,
   ; so the repl survives evaluation errors by construction. a global
   ; `help` function gets control at the scare (condition data on struct g)
   ; BEFORE the task dies; either way done?/key? is where the repl resumes.
   (do_eval v)
     (: pid (spawn ev v)
        (poll _)
          (? (done? pid) (: r (wait pid) _ (putx r) -1)   ; the answer
             (key? 0)    (: c (getc 0)
                            (? (= c 3) (do (puts "^C") (hush pid) -1)
                               (poll 0)))
             (do (yield 0) (poll 0)))
        (poll 0))

   ; the read-eval-print loop proper. the host and kernel frontends start the
   ; shell via (shell 0), which calls (repl 0 0).
   (repl hu hd)
     (: r (edline hu hd)
        (? (= r eofsym) 0
           (: vs  (cap r)
              nhu (caup r)
              nhd (cuup r)
              _ (each vs (\ v (: _ (do_eval v) (putc 10))))
              (repl nhu nhd))))

   ; welp -- the floor handler, help that has given up: keep the read protocol
   ; (incomplete -> the port back, eof -> the sentinel) and answer the zero
   ; point on a bare scare. this is the fromempty the introductions (scare,
   ; missing) never named: from any condition, a value -- and the value of the
   ; absorbed condition is the point, the held inhabitant of nothing, so
   ; (i love you) stays 1. any policy that runs out of cases delegates here:
   ; (\ s a b (? (mine? a) .. (welp s a b))). the point is captured HERE,
   ; helpless at load -- the body cannot say (:), since reading the missing
   ; head under an installed help would recurse.
   welp
     (: zp (:)
        (\ s a b (? (eof? s) b (more? s) a zp)))

   ; the shell's default help: a bare scare prints its condition -- ;; a b --
   ; with an honest face, then welps to the point so the session survives
   ; every raise (the answer must be a unit: a number would exponentiate under
   ; a numeral). every other status -- the more bits -- welps straight through,
   ; reproducing the read protocol exactly. (helpless, the C default is
   ; terminal and wears the oom banner.)
   shell-help
     (\ s a b
        (? (scare? s) (: _ (puts ";; ") _ (putx a) _ (puts " ") _ (putx b) _ (putc 10) (welp s a b))
           (welp s a b)))

   ; the interactive entry: install shell-help IF no help is present (the
   ; check and the define both go through ev -- a live read and a top-level
   ; pin -- since closures capture their free globals at creation and the
   ; book itself is pulled). file mode never comes through here, so scripts
   ; keep the helpless (terminal) law.
   (shell _)
     (: _ (? (ev (\ help)) 0 (ev (list (\ :) (\ help) shell-help)))
        _ (puts (";3 ai " + ai-version + "\n"))
        (repl 0 0))

   ; --- the host-only pty wrapper (wrap) ---
   ; reachable from the bao prompt to pty-wrap a host program -- (wrap (L
   ; "python3")). it uses the pty nifs (ptyrun, reap) which live in host/pty.c
   ; and are NOT present in ai0 or the kernel; bao is baked into both, so the
   ; references are DEFERRED to call time through (ev 'ptyrun) / (ev 'reap)
   ; -- quoted symbols are inert data at bake time (no missing-name fires), and
   ; wrap is never CALLED on those frontends. on the host they resolve to the
   ; live nifs. NOTE: drives the real in/out tty fds, so it is exercised
   ; manually (the in-process gate covers the master read/write lanes; see
   ; boot/pty.l).

   ; pump bytes from port `src` to port `dst`, one at a time, until src hits EOF
   ; (fgetc -> -1); fflush after each byte keeps the far side prompt. (Same shape as
   ; aineko's pump -- prel stays socket/pty-free, so each app carries its own.)
   (pump src dst) (: ch (fgetc src) (? (= ch -1) 0 (: _ (fputc dst ch) _ (fflush dst) (pump src dst))))

   ; poll a non-blocking (reap pid) to its exited PAIR. the pair is told from
   ; still-running (0) STRUCTURALLY (two?), never by net: the status pair (0)
   ; nets blue, so ! / non can't tell it from 0 -- only two? can.
   (waitfor pid) (: s ((ev 'reap) pid) (? (two? s) s (= 0 s) (do (sleep 2) (waitfor pid)) s))

   ; (wrap argv) -- run argv on a fresh pty and become a TRANSPARENT bidirectional
   ; pump: stdin -> the child, the child's output -> stdout, both live at once
   ; (the two pumps park on different fds and interleave through the cooperative
   ; scheduler, like aineko). The teardown differs from aineko's SYMMETRIC network
   ; pump, though: a wrapped PROCESS can exit while stdin is still open, so the
   ; child's death is the primary signal -- master->stdout runs HERE and ends on
   ; master EOF (the child gone); the stdin->master side runs in `up` and, on the
   ; user's own EOF, forwards VEOF (byte 4) so a canonical child exits. funnel
   ; through one death: when master EOF lands, join `up` -- wait if it already
   ; finished (user EOF first), else hush it (still parked on stdin; the child is
   ; dead so dropping pending input is correct, not aineko's data-loss case).
   ; returns the child's exited status pair, or ptyrun's errno fixnum on spawn
   ; failure.
   (wrap argv)
     (: r ((ev 'ptyrun) argv)
        (? (two? r)
           (: pid (cap r) m (cup r)
              up (spawn (\ _ (: _ (pump in m) (fputc m 4))) 0)   ; stdin -> child; VEOF on user EOF
              _ (pump m out)                                      ; child -> stdout; ends when the child dies
              _ (? (done? up) (wait up) (hush up))                ; join the input pump through the one death
              _ (fflush out)
              _ (close m)
              (waitfor pid))                                      ; reap the child
           r))

   ; --- the raw-line editor (bao's own line reader) ---
   ; repl's `edline` is wrong for wrapping a host program: it parses the buffer
   ; as ai forms (submits only when it reads complete) and prints its own `> `. a
   ; wrapped program (bash, python) wants the RAW bytes, submitted on Enter no
   ; matter what. So bao reads its own line -- reusing the PURE zipper primitives
   ; (edleft/edright/edbsp/eddel/edhome/edend/revcat/edrender, all in/out-free for
   ; the logic), but with PORT-PARAMETERIZED event decode so the input is any
   ; port: `in` for the tty, a (sip ..) for tests.
   ;
   ; bev/besc/besc1 are edev/edesc/edesc1, reading (fgetc ip) instead of the
   ; global getc -- event codes are identical (printable >0; -1 left, -2 right,
   ; -3 bsp, -4 del, -5 home, -6 end, -7 quit/EOF; 10 = enter; up/down/^C ignored
   ; by a single-line reader).
   (besc1 ip c) (? (= c 126) -5
                   (= c 59) (: _ (fgetc ip) d (fgetc ip)
                              (? (= d 72) -5 (= d 70) -6 (= d 65) -8 (= d 66) -9
                                 (= d 67) -2 (= d 68) -1 0)))
   (besc ip) (? !(= 91 (fgetc ip)) 0
     (: c (fgetc ip)
        (? (= c 68) -1 (= c 67) -2 (= c 65) -8 (= c 66) -9 (= c 72) -5 (= c 70) -6
           (= c 49) (besc1 ip (fgetc ip))
           (= c 55) (: _ (fgetc ip) -5)
           (|| (= c 52) (= c 56)) (: _ (fgetc ip) -6)
           (= c 51) (: _ (fgetc ip) -4) 0)))
   (bev ip) (: c (fgetc ip)
     (? (|| (= c -1) (= c 4)) -7
        (= c 3) -12
        (|| (= c 13) (= c 10)) 10
        (|| (= c 8) (= c 127)) -3
        (= c 1) -5 (= c 5) -6 (= c 27) (besc ip)
        (&& (<= 32 c) (< c 127) c)))

   ; (edraw ip pr) -- read ONE line off port `ip`, with in-line editing, prompt pr
   ; echoed to out. Enter submits the raw line (its bytes, in order); ^D / port EOF
   ; returns eofsym. single line, no history, no parseall -- the text goes straight
   ; back to the caller (bao's wrapper feeds it to a child). the buffer is the
   ; (l . r) halves of the zipper with the line count (u d) pinned empty, so the
   ; single-line primitives drive it unchanged.
   (edraw ip pr)
     (: _ (puts pr) pl (tally pr)
        (loop l r)
          (: _ (edrender pl 0 0 l r 0)
             c (bev ip)
             (km uu ll rr dd) (loop ll rr)         ; motion: edleft/.. give (k u l r d), keep l r
             (? (= c -7) eofsym                     ; ^D / EOF -> the sentinel
                (= c 10) (: _ (putc 10) (revcat l r)); Enter -> submit the raw line, in order
                (< 0 c)  (loop (link c l) r)         ; insert a printable
                (= c -1) (edleft  km 0 l r 0)
                (= c -2) (edright km 0 l r 0)
                (= c -3) (edbsp   km 0 l r 0)
                (= c -4) (eddel   km 0 l r 0)
                (= c -5) (edhome  km 0 l r 0)
                (= c -6) (edend   km 0 l r 0)
                (loop l r)))                         ; up/down/^C/unknown: ignore in a line reader
        (loop 0 0))

   ; (bao a) -- the interactive entry the host frontend launches. `(bao 0)` is
   ; exactly the baked shell (an arg is taken: ai has no nullary calls); `(bao 'test)`
   ; runs the private unit battery (boot/baotest.l gates it -- the selftest stays
   ; closure-private, off the book). `wrap` is reachable from the bao prompt; the
   ; editor-as-line-reader (edraw) and the debug `help` are the later modes (crew/bao.md).
   (bao a) (? (= a 'test) (bao-selftest 0) (shell 0))

   ; --- the editor self-test, run from inside the closure (so it reaches the
   ; private ed* / parseall / history helpers that USED to be corpus globals).
   ; it cannot USE the test harness `assert` (a macro absent at bake time, when
   ; this closure compiles), so it instead COMPUTES the whole battery of boolean
   ; checks and returns them as a flat list; boot/baotest.l (a bao-loaded test)
   ; gates that list through the real `assert`. k4/k7 pack the CPS continuation's
   ; (u l r d [hu hd cur]) arguments into a comparable list, exactly as the old
   ; test/repl.l did. (the formerly-leaked names are now reached HERE, not in the
   ; corpus -- that is the namespace cleanup.)
   (k4 u l r d) (link u (link l (link r d)))
   (k7 u l r d hu hd cur) (link u (link l (link r (link d (link hu (link hd cur))))))
   (bao-selftest _) (L
     ; --- edleft / edright / edbsp / eddel / edhome / edend ---
     (= (k4 0 '(1) '(2 3) 0) (edleft k4 0 '(2 1) '(3) 0))
     (= (k4 0 '(2 1) 0 (link '(3) 0)) (edleft k4 (link '(1 2) 0) 0 '(3) 0))
     (= (k4 0 0 '(1 2) 0) (edleft k4 0 0 '(1 2) 0))
     (= (k4 0 '(1) '(2 3) 0) (edright k4 0 0 '(1 2 3) 0))
     (= (k4 (link '(1 2) 0) 0 '(3 4) 0) (edright k4 0 '(2 1) 0 (link '(3 4) 0)))
     (= (k4 0 '(2 1) 0 0) (edright k4 0 '(2 1) 0 0))
     (= (k4 0 '(1) '(3) 0) (edbsp k4 0 '(2 1) '(3) 0))
     (= (k4 0 '(2 1) '(3) 0) (edbsp k4 (link '(1 2) 0) 0 '(3) 0))
     (= (k4 0 0 '(1) 0) (edbsp k4 0 0 '(1) 0))
     (= (k4 0 '(1) '(3) 0) (eddel k4 0 '(1) '(2 3) 0))
     (= (k4 0 '(1) '(2 3) 0) (eddel k4 0 '(1) 0 (link '(2 3) 0)))
     (= (k4 0 '(1) 0 0) (eddel k4 0 '(1) 0 0))
     (= (k4 0 0 '(1 2 3) 0) (edhome k4 0 '(2 1) '(3) 0))
     (= (k4 0 '(3 2 1) 0 0) (edend k4 0 '(2 1) '(3) 0))
     ; --- edtop / edbot ---
     (= (k4 0 0 '(1 2 3) 0) (edtop k4 0 '(2 1) '(3) 0))
     (= (k4 0 '(3 2 1) 0 0) (edbot k4 0 '(2 1) '(3) 0))
     (= (k4 0 0 '(1) (link '(2) (link '(3) 0))) (edtop k4 (link '(2) (link '(1) 0)) '(3) 0 0))
     (= (k4 (link '(2) (link '(1) 0)) '(3) 0 0) (edbot k4 0 '(1) 0 (link '(2) (link '(3) 0))))
     (= (k4 0 0 '(1) (link '(8 9) (link '(4) 0))) (edtop k4 (link '(1) 0) '(8) '(9) (link '(4) 0)))
     ; --- edup / eddown ---
     (= (k4 0 '(1) '(2 3 4) (link '(5 6) 0)) (edup k4 (link '(1 2 3 4) 0) '(5) '(6) 0))
     (= (k4 0 '(2 1) 0 (link '(3 4 5 6) 0)) (edup k4 (link '(1 2) 0) '(4 3) '(5 6) 0))
     (= (k4 0 '(1) '(2) 0) (edup k4 0 '(1) '(2) 0))
     (= (k4 (link '(5 6) 0) '(1) '(2 3 4) 0) (eddown k4 0 '(5) '(6) (link '(1 2 3 4) 0)))
     (= (k4 0 '(1) '(2) 0) (eddown k4 0 '(1) '(2) 0))
     ; --- joinln / flatten / splitat ---
     (= 0 (joinln 0))
     (= '(1 2 3) (joinln (link '(1 2 3) 0)))
     (= '(1 10 2) (joinln (link '(1) (link '(2) 0))))
     (= '(1 2 10 3 10 4 5) (joinln (link '(1 2) (link '(3) (link '(4 5) 0)))))
     (= '(1 2 3) (flatten 0 '(2 1) '(3) 0))
     (= '(1 10 2) (flatten (link '(1) 0) '(2) 0 0))
     (= '(1 10 2 10 3) (flatten (link '(1) 0) '(2) 0 (link '(3) 0)))
     (= (link '(2 1) '(3 4)) (splitat link 0 2 '(1 2 3 4)))
     (= (link '(2 1) 0) (splitat link 0 5 '(1 2)))
     (= (link 0 '(1 2 3)) (splitat link 0 0 '(1 2 3)))
     ; --- mkframe / detach / emptybuf / parses ---
     (= (link 0 (link '(1) (link 0 0))) (mkframe 0 '(1) 0 0))
     (= (link (link '(1) 0) (link '(2 3) (link '(4) (link '(5) 0))))
        (mkframe (link '(1) 0) '(2 3) '(4) (link '(5) 0)))
     (= 0 (detach 0 0))
     (: cur (mkframe 0 '(1) 0 0) (= (link cur 0) (detach 0 cur)))
     (: cur (mkframe 0 '(1) 0 0) old (mkframe 0 '(9) 0 0)
        (= (link cur (link old 0)) (detach (link old 0) cur)))
     (emptybuf 0 0 0 0)
     !(emptybuf 0 '(1) 0 0)
     !(emptybuf (link '(1) 0) 0 0 0)
     !(emptybuf 0 0 '(1) 0)
     !(emptybuf 0 0 0 (link '(1) 0))
     (parses 0 (link 49 0) 0 0)
     !(parses 0 0 0 0)
     !(parses 0 (link 40 0) 0 0)
     (parses (link (link 40 0) 0) (link 41 0) 0 0)
     ; --- uphist / downhist ---
     (: cur (mkframe 0 '(1) 0 0) old (mkframe 0 '(9) 0 0)
        (= (k7 0 '(9) 0 0 0 (link cur 0) old) (uphist k7 0 '(1) 0 0 (link old 0) 0 cur)))
     (: old (mkframe 0 '(9) 0 0)
        (= (k7 0 '(9) 0 0 0 0 old) (uphist k7 0 0 0 0 (link old 0) 0 0)))
     (: cur (mkframe 0 (link 49 0) 0 0)
        (= (k7 0 0 0 0 0 (link cur 0) 0) (uphist k7 0 (link 49 0) 0 0 0 0 cur)))
     (: cur (mkframe 0 (link 40 0) 0 0)
        (= (k7 0 (link 40 0) 0 0 0 0 cur) (uphist k7 0 (link 40 0) 0 0 0 0 cur)))
     (= (k7 0 (link 49 0) 0 0 0 0 0) (uphist k7 0 (link 49 0) 0 0 0 0 0))
     (: cur (mkframe 0 '(1) 0 0) new (mkframe 0 '(9) 0 0)
        (= (k7 0 '(9) 0 0 (link cur 0) 0 new) (downhist k7 0 '(1) 0 0 0 (link new 0) cur)))
     (: new (mkframe 0 '(9) 0 0)
        (= (k7 0 '(9) 0 0 0 0 new) (downhist k7 0 0 0 0 0 (link new 0) 0)))
     (: cur (mkframe 0 (link 49 0) 0 0)
        (= (k7 0 0 0 0 (link cur 0) 0 0) (downhist k7 0 (link 49 0) 0 0 0 0 cur)))
     ; --- parseall: a line is ONE expression; floats; the more-sentinel ---
     (= '((1 2 3)) (parseall '(49 32 50 32 51)))
     (= '(((1 2))) (parseall '(40 49 32 50 41)))
     (= 0 (parseall 0))
     !(two? (parseall '(40 49)))
     (= 1.5 (cap (cap (parseall '(49 46 53)))))
     (= 1000.0 (cap (cap (parseall '(49 101 51)))))
     (nom? (cap (cap (parseall '(49 46 50 46 51)))))
     ; the more-sentinel: an unclosed shape is m (not two?); a complete datum is
     (nil? (two? (parseall (cat (L 40 43 32 49) 0))))   ; "(+ 1" unclosed
     (two? (parseall (cat (L 49 32 43) 0)))             ; "1 +" complete (the curry partial)
     (two? (parseall (cat (L 49 32 63 32 39 97) 0)))    ; "1 ? 'a" complete (curried cond)
     (two? (parseall (cat (L 40 43 32 49 32 50 41) 0))) ; "(+ 1 2)" closed
     (two? (parseall (cat (L 49 32 61 32 49) 0))))      ; "1 = 1"

   ; the body: the public entry points, defglob'd below. everything above stays
   ; closure-private (off the book), which is what stops the ed* editor + repl
   ; internals from leaking into (names ()).
   (L shell welp edraw wrap bao))

 ; defglob the public surface out of the export list (book is mopped post-egg, so
 ; a top-level body-less (: ..) is the only way to add a global; the privates above
 ; -- including bao-selftest, reached via (bao 'test) -- never reach it). the holder
 ; is `_` (the previous line's value, by the sequence law), so it never leaks either.
 shell (cap _)
 welp  (cap (cup _))
 edraw (cap (cup (cup _)))
 wrap  (cap (cup (cup (cup _))))
 bao   (cap (cup (cup (cup (cup _))))))

; bao.l is DEFINE-ONLY -- loading it (egg-bake or `-l ai/bao.l`) installs the shell
; core but does NOT launch. The frontend launches: host/main.c evals `(bao 0)` on a
; tty (so `ai` on a terminal is the bao shell), a pipe stays the bare stdin runner
; `(zevs in)`, and the kernel calls `(shell 0)`. Define-only is what makes bao
; loadable for tests (load the defs, read piped forms with the bare reader).
