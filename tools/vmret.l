#!/usr/bin/env ll
; vmret.l -- flag g_vm_* VM-instruction handlers that contain a `ret`.
;
; Port of tools/vmret.py (see it for the full rationale). The ll VM is
; threaded: every g_vm_* opcode handler should tail-jump to the next, never
; emit an ordinary `ret`. This tool disassembles an ELF (shelling out to
; objdump / llvm-objdump via the `run` nif) and reports every g_vm_* function
; whose body still contains a `ret` -- a first-pass heuristic, expect false
; positives. It is cross-arch: it reads e_machine and picks a per-arch return
; mnemonic, preferring multi-target llvm-objdump for non-x86 images.
;
; Usage: ll vmret.l ELF [--prefix PREFIX] [--objdump PATH]
; Exit:  0 = all clean, 1 = suspects found, 2 = usage/tool error.
;
; This needs the host-only `run`/`getenv` nifs (subprocess + environment).

(: (die m)   (: _ (fputs err "vmret: ") _ (fputs err m) _ (fputs err "\n") (exit 2))
   (usage 0) (: _ (fputs out "usage: vmret.l ELF [--prefix PREFIX] [--objdump PATH]\n") (exit 0)))

; --- character classes + cursors over a line (string s) --------------
; ws = Python \s within a line (space tab cr ff vtab); hex = [0-9a-fA-F].
(: (ws?  c) (any (\ x (= x c)) (L 32 9 13 12 11))
   (hex? c) (? (&& (>= c 48)  (<= c 57))  1
            (? (&& (>= c 97)  (<= c 102)) 1
               (&& (>= c 65)  (<= c 70))))
   (skip-ws    s i) (? (< i (pin s)) (? (ws?  (get 0 i s)) (skip-ws    s (+ i 1)) i) i)
   (skip-hex   s i) (? (< i (pin s)) (? (hex? (get 0 i s)) (skip-hex   s (+ i 1)) i) i)
   (skip-nonws s i) (? (< i (pin s)) (? (ws?  (get 0 i s)) i (skip-nonws s (+ i 1))) i)
   ; one past the last non-ws char (0 if the line is all whitespace).
   (trim-end s) ((: (f i e) (? (< i (pin s)) (f (+ i 1) (? (ws? (get 0 i s)) e (+ i 1))) e)) 0 0)
   (prefix? p s) (= p (ssub s 0 (pin p)))
   (dash? a) (&& (< 0 (pin a)) (= 45 (get 0 0 a))))

; --- line classifiers (the three vmret.py regexes, by hand) -----------
; HEADER_RE  ^\s*[0-9a-fA-F]+\s+<(.+)>:\s*$  -> the captured name, else 0.
(: (parse-header line)
   (: i (skip-ws line 0)
      j (skip-hex line i)
      (? (= j i) 0                                       ; need >=1 hex digit
         (: k (skip-ws line j)
            (? (= k j) 0                                  ; need >=1 space
               (? (= 60 (get 0 k line))                   ; '<'
                  (: e (trim-end line)
                     (? (&& (>= e (+ k 4))                 ; room for "<x>:"
                            (&& (= 58 (get 0 (- e 1) line)) ; ':' at end
                                (= 62 (get 0 (- e 2) line)))) ; '>' before it
                        (ssub line (+ k 1) (- e 2))         ; the (.+) name
                        0))
                  0))))))

; INSN_RE  ^\s*([0-9a-fA-F]+):\s+(.*)$  -> (addr . text), else 0.
(: (parse-insn line)
   (: i (skip-ws line 0)
      j (skip-hex line i)
      (? (&& (> j i) (= 58 (get 0 j line)))               ; hexrun then ':'
         (: k (skip-ws line (+ j 1))
            (? (> k (+ j 1))                                ; need >=1 ws after ':'
               (X (ssub line i j) (ssub line k (pin line)))
               0))
         0)))

; --- mnemonic = first whitespace token that isn't an x86 prefix -------
(: PREFIXES (L "rep" "repz" "repe" "repnz" "repne" "lock" "bnd" "notrack" "data16")
   (mnemonic text)
   ((: (f i)
       (: ts (skip-ws text i)
          (? (< ts (pin text))
             (: te (skip-nonws text ts)
                w  (ssub text ts te)
                (? (any (\ p (= p w)) PREFIXES) (f te) w))
             "")))
    0))

; --- per-arch return-mnemonic matchers --------------------------------
; x86: ^l?ret[a-z]*$ (ret/retq/lret/...; not iret). arm: ^ret(aa|ab)?$.
; riscv64/loongarch64: exactly ret. (iret/eret/sret/mret/ertn never match.)
(: (lower? s i) (? (< i (pin s)) (: c (get 0 i s) (? (&& (>= c 97) (<= c 122)) (lower? s (+ i 1)) 0)) 1)
   (ret-tail? r) (&& (prefix? "ret" r) (lower? r 3))
   (retx?  m) (|| (ret-tail? m) (&& (= 108 (get 0 0 m)) (ret-tail? (ssub m 1 (pin m)))))
   (reta?  m) (|| (= m "ret") (|| (= m "retaa") (= m "retab")))
   (reteq? m) (= m "ret"))

; --- split a string on '\n' into a list of lines ---------------------
(: (lines s)
   ((: (f start i)
       (? (< i (pin s))
          (? (= 10 (get 0 i s)) (X (ssub s start i) (f (+ i 1) (+ i 1))) (f start (+ i 1)))
          (? (< start i) (L (ssub s start i)) 0)))
    0 0))

; --- ELF64 symbol sizes: bound each function to its real extent -------
; The text scan charges any `ret` in inter-function padding to the nearest
; preceding <name>: header (e.g. a stray aligned `ret` after a clean tail-jump).
; Reading each FUNC symbol's st_size from .symtab lets us drop instructions past
; a function's [start, start+size). ELF64 LE is asserted in the driver below.
; Addresses can be high-half (a kernel image links at 0xffffffff80000000), which
; overflows a fixnum -- so u64/BIG/hex->int use `+`/`*` (which promote to bignum),
; never bitwise `<<`/`|` (which would not), keeping the values exact.
(: (hex->int s) ((: (f i acc)
                    (? (< i (pin s))
                       (: c (get 0 i s)
                          v (? (&& (>= c 48) (<= c 57))  (- c 48)
                            (? (&& (>= c 97) (<= c 102)) (- c 87)
                            (? (&& (>= c 65) (<= c 70))  (- c 55) 0)))
                          (f (+ i 1) (+ (* acc 16) v)))
                       acc))
                 0 0)
   BIG (* 4294967296 4294967296)                          ; 2^64: above any real address
   (parse-header-addr line)                               ; the <addr> before <name>:, as an int
     (: i (skip-ws line 0) j (skip-hex line i)
        (? (= j i) 0 (hex->int (ssub line i j))))
   (u8  d i) (get 0 i d)                                  ; little-endian fixed-width readers
   (u16 d i) (| (u8  d i) (<< (u8  d (+ i 1)) 8))
   (u32 d i) (| (u16 d i) (<< (u16 d (+ i 2)) 16))
   (u64 d i) (+ (u32 d i) (* (u32 d (+ i 4)) 4294967296))   ; `+`/`*` so a high-half addr promotes to bignum
   (find-symtab d base ent n k)                           ; SHT_SYMTAB (2) -> (off . size), else 0
     (? (< k n)
        (: sh (+ base (* k ent))
           (? (= 2 (u32 d (+ sh 4))) (X (u64 d (+ sh 24)) (u64 d (+ sh 32)))
              (find-symtab d base ent n (+ k 1))))
        0)
   (collect-syms d off n k m)                             ; Elf64_Sym (24 B): value -> size, sized FUNCs
     (? (< k n)
        (: p (+ off (* k 24)) info (u8 d (+ p 4)) val (u64 d (+ p 8)) sz (u64 d (+ p 16))
           (collect-syms d off n (+ k 1)
              (? (&& (= 2 (& info 15)) (< 0 sz)) (put val sz m) m)))
        m)
   (symtab-sizes d)                                       ; -> map: fn start address -> byte size
     (: st (find-symtab d (u64 d 40) (u16 d 58) (u16 d 60) 0)  ; e_shoff / e_shentsize / e_shnum
        (? st (collect-syms d (A st) (// (B st) 24) 0 %()) %())))

; --- the scan (vmret.py scan(), grouping by function header) ----------
; close the current watched function: flag it iff it collected any rets.
(: (close name watching rets flagged)
   (? (&& watching (twop rets)) (X (X name (rev rets)) flagged) flagged))

; -> (flagged . total), where flagged = ((name . rets) ...), total = count of
; prefix* functions seen. prefix, the ret matcher, and a function-start -> size
; map are captured. lim = end of the current function's symtab extent; a `ret`
; at or past it is padding (an orphan in the gap before the next symbol), not
; the function's -- so it does not count. unsized symbols -> lim BIG (old behavior).
(: (scan-all ls prefix ret? sizes)
   ((: (loop ls name watching lim rets flagged total)
       (? (twop ls)
          (: line (A ls)
             rest (B ls)
             h    (parse-header line)
             (? h
                (? (prefix? "." h)                              ; local label: stay inside
                   (loop rest name watching lim rets flagged total)
                   (: fl2  (close name watching rets flagged)   ; real header: close, open new
                      w2   (prefix? prefix h)
                      ha   (parse-header-addr line)
                      sz   (get 0 ha sizes)                     ; symtab size, 0 if absent
                      lim2 (? (< 0 sz) (+ ha sz) BIG)           ; extent end, or unbounded
                      (loop rest h w2 lim2 0 fl2 (? w2 (+ total 1) total))))
                (: ins (? watching (parse-insn line) 0)         ; instruction: maybe a ret
                   (? (&& ins (< (hex->int (A ins)) lim) (ret? (mnemonic (B ins))))
                      (loop rest name watching lim (X (A ins) rets) flagged total)
                      (loop rest name watching lim rets flagged total)))))
          (X (close name watching rets flagged) total)))
    ls 0 0 BIG 0 0 0))

; --- report helpers --------------------------------------------------
(: (basename p) ((: (f i last) (? (< i (pin p)) (f (+ i 1) (? (= 47 (get 0 i p)) (+ i 1) last)) (ssub p last (pin p)))) 0 0)
   (spaces n)    (? (< 0 n) (scat " " (spaces (- n 1))) "")
   (str< a b)    ((: (f i) (? (>= i (pin a)) (< (pin a) (pin b))
                            (? (>= i (pin b)) 0
                               (: ca (get 0 i a) cb (get 0 i b)
                                  (? (< ca cb) 1 (? (> ca cb) 0 (f (+ i 1)))))))) 0)
   (maxlen fl)   (foldl (\ m e (: l (pin (A e)) (? (< m l) l m))) 0 fl)
   (join-rets rs) (? (twop rs)
                     (? (twop (B rs)) (scat (scat "0x" (A rs)) (scat ", " (join-rets (B rs))))
                                        (scat "0x" (A rs)))
                     ""))

; sort the flagged entries by function name (ascending), matching .py.
(: (emerge a b) (? (twop a) (? (twop b)
                     (? (str< (A (A a)) (A (A b)))
                        (X (A a) (emerge (B a) b)) (X (A b) (emerge a (B b))))
                     a) b)
   (esort l) (? (twop (B l)) (: n (>> (pin l) 1) (emerge (esort (take n l)) (esort (drop n l)))) l))

; --- argument parsing ------------------------------------------------
(: (parse-args args path prefix od)
   (? (twop args)
      (: a (A args)
         (? (= a "--prefix")
            (? (twop (B args)) (parse-args (B (B args)) path (A (B args)) od) (die "missing argument for --prefix"))
         (? (= a "--objdump")
            (? (twop (B args)) (parse-args (B (B args)) path prefix (A (B args))) (die "missing argument for --objdump"))
         (? (|| (= a "-h") (= a "--help")) (usage 0)
         (? (dash? a) (die (scat "unknown option: " a))
         (? path (die (scat "unexpected argument: " a))
            (parse-args (B args) a prefix od)))))))
      (L path prefix od)))

; --- try candidate disassemblers in order ----------------------------
; (run ...) returns (status . output) when the tool ran, else a fixnum errno
; (spawn failed -> try the next). -> (cand status . output) or 0 if exhausted.
(: (try-cands cs elf)
   (? (twop cs)
      (: r (run (L (A cs) "-d" "--no-show-raw-insn" elf))
         (? (twop r) (X (A cs) r) (try-cands (B cs) elf)))
      0))

; --- driver ----------------------------------------------------------
(: parsed   (parse-args (B argv) 0 "g_vm_" 0)
   path     (A parsed)
   prefix   (A (B parsed))
   od       (A (B (B parsed)))
   _        (? path 0 (die "usage: vmret.l ELF [--prefix PREFIX] [--objdump PATH]"))
   base     (basename path)
   port     (open path "r")
   _        (? port 0 (die (scat "cannot open " path)))
   hdr      (slurp port)                                 ; whole image: e_ident/e_machine + .symtab
   _        (close port)
   _        (? (&& (= 127 (get 0 0 hdr)) (&& (= 69 (get 0 1 hdr)) (&& (= 76 (get 0 2 hdr)) (= 70 (get 0 3 hdr))))) 0
               (die (scat path ": not an ELF file")))
   _        (? (&& (= 2 (get 0 4 hdr)) (= 1 (get 0 5 hdr))) 0
               (die (scat path ": not ELF64 little-endian")))
   sizes    (symtab-sizes hdr)                           ; function start address -> byte size
   mach     (| (get 0 18 hdr) (<< (get 0 19 hdr) 8))
   x86?     (= mach 62)
   known?   (|| x86? (|| (= mach 183) (|| (= mach 243) (= mach 258))))
   ret?     (? x86? retx? (? (= mach 183) reta? (? (|| (= mach 243) (= mach 258)) reteq? retx?)))
   _        (? known? 0
               (: _ (fputs err "vmret: note: ") _ (fputs err base)
                  _ (fputs err " is an unrecognized arch (0x") _ (fputn err mach 16)
                  _ (fputs err "); falling back to the generic `ret` matcher\n") 0))
   ; objdump preference: GNU objdump for x86 (host-arch), llvm-objdump for the
   ; cross arches; an explicit --objdump or $OBJDUMP wins. execvp does the PATH
   ; search, so a candidate that isn't found just spawn-fails -> next one.
   cands    (filter id (L od (getenv "OBJDUMP")
                          (? x86? "objdump" "llvm-objdump") (? x86? "llvm-objdump" "objdump")))
   chosen   (try-cands cands path)
   _        (? chosen 0 (die "no disassembler found (tried llvm-objdump, objdump); pass --objdump"))
   status   (A (B chosen))
   output   (B (B chosen))
   _        (? (= 0 status) 0 (die (scat (scat (A chosen) " failed: status ") (inspect status))))
   scanned  (scan-all (lines output) prefix ret? sizes)
   flagged  (A scanned)
   total    (B scanned)
   ; --- the report (byte-for-byte the same shape as vmret.py) ---
   (? (= 0 total)
      (: _ (fputs err "vmret: no ") _ (fputs err prefix) _ (fputs err "* functions found in ")
         _ (fputs err base) _ (fputs err " (stripped binary?)\n") (exit 2))
   (? (twop flagged)
      (: k      (pin flagged)
         width  (maxlen flagged)
         sorted (esort flagged)
         _ (fputs out base) _ (fputs out ": ") _ (fputn out k 10) _ (fputs out " of ")
         _ (fputn out total 10) _ (fputs out " ") _ (fputs out prefix)
         _ (fputs out "* functions contain a ret (TCO suspects):\n")
         _ (each sorted (\ e
              (: name (A e) rets (B e)
                 _ (fputs out "  ") _ (fputs out name) _ (fputs out (spaces (- width (pin name))))
                 _ (fputs out "  ret @ ") _ (fputs out (join-rets rets)) _ (fputc out 10) 0)))
         (exit 1))
      (: _ (fputs out base) _ (fputs out ": all ") _ (fputn out total 10) _ (fputs out " ")
         _ (fputs out prefix) _ (fputs out "* functions are ret-free\n") (exit 0)))))
