; lupa -- the magnifier: a hex editor and disassembler over one file, on the stage story and
; design share. two views of the same bytes: hex (offset, sixteen bytes, their text) and asm
; (address, bytes, the instruction in either dialect); the cursor is a byte in one and an
; instruction in the other, and a `:` line takes the commands. an ELF opens on its .text with
; its symbols named, anything else is bytes from 0.
;
;   hjkl / arrows  the cursor (a byte, or an instruction)      ^f ^b  a page   ^d ^u  the same
;   g G   the start and the end     d / tab  hex <-> asm     s  at&T <-> Intel     n  next match
;   0-9 a-f  (hex view) overwrite the nibble at the cursor    q  leave (when clean)
;   :w save   :q leave   :q! leave anyway   :wq   :g ADDR|SYM  go   :/ HEX|"text"  find
;
; every key is a pure step on the state and every frame a pure lay into a port, so the tool
; gates headless (test/host/lupa.l); only lupa-run ties the tty, on cli's stage, and the
; command line is cli's editor. the bytes never change under the cursor: an edit is a note in
; a tablet over the file's string, and :w lays the patched string back. the decoder is
; src/core/holo/decode.l and the two spellings src/core/holo/dialect.l's; another ISA joins
; by decoding its own bytes to the same item shape.
; usage: love lupa FILE
(module (lupa lupa-main lupa-run lupa-new lupa-key lupa-frame lupa-byte)
(use 'holo)
(:
 ;; --- the file, and an ELF's .text and symbols over it ------------------------------------
 ;; elf: () or {'toff 'taddr 'tsize 'syms 'names}: .text's file offset, address and size; syms
 ;; a tablet addr -> name; names a tablet name -> addr (the goto door)
 (elf? s) (#s > 64 && s 0 = 127 && s 1 = 69 && s 2 = 76 && s 3 = 70 && s 4 = 2)
 (hexd n) ("0123456789abcdef" n)
 (hex n w) (: (go k a) (? (k < 0) a (go (k - 1) (a + string (hexd ((n >> (4 * k)) & 15)))))
              (go (w - 1) ""))
 (hexn n) (: (go v a) (? (v = 0) (0 = #a ? "0" a) (go (v >> 4) (string (hexd (v & 15)) + a)))
              ("0x" + go n ""))
 (cstr s i) (: (go j) (? (j >= #s || s j = 0) j (go (j + 1))) (snip s i (go i)))
 (elf-text s)                                              ; -> (off addr size) of .text, or ()
  (: shoff (rle64 s 40) shnum (rle16 s 60) shstr (rle16 s 62)
     (sh i) (shoff + i * 64)
     (go strtab i) (? (i >= shnum) ()
                      (: h (sh i) nm (cstr s (strtab + rle32 s h))
                         (nm = ".text" ? [(rle64 s (h + 24)) (rle64 s (h + 16)) (rle64 s (h + 32))] (go strtab (i + 1)))))
     (shoff > 0 && shoff + shnum * 64 <= #s && shstr < shnum ? (go (rle64 s (sh shstr + 24)) 0) ()))
 (elf-syms s)                                              ; -> (addr->name name->addr)
  (: syms {} names {}
     _ (each (ld-syms "lupa" s)
             (\ r (: v (r 4) t (r 2) nm (r 0)
                     (? (v > 0 && (t = 2 || t = 1) && 0 < #nm) (pin syms v nm, pin names nm v) 0))))
     [syms names])
 (lupa-new s p)
  (: t (elf? s ? (elf-text s) ())
     e (? (two? t) (: sy (elf-syms s) {'toff <t 'taddr <>t 'tsize <>>t 'syms <sy 'names <>sy}) ())
     start (two? t ? <t 0)
     {'bytes s 'n #s 'path p 'edits {} 'cur start 'top start
      'mode (two? t ? 'asm 'hex) 'syn 'att 'in 'map 'cmd (ednew ()) 'msg "" 'dirty 0 'over 0
      'nib -1 'elf e 'find "" 'h 24})
 (elfed? d) (tablet? (d 'elf))
 (lupa-byte d i) (: v (peep (d 'edits) i -1) (v < 0 ? ((d 'bytes) i) v))
 (range a b) (map (i \ a + i) (jot (b - a)))
 (slice d a b) (string (map (i \ lupa-byte d i) (range a b)))
 (patched d) (slice d 0 (d 'n))
 ;; an offset's address and back: inside .text they part company, elsewhere they agree
 (addr d off) (: e (d 'elf) (? (elfed? d && e 'toff <= off < e 'toff + e 'tsize) (off - e 'toff + e 'taddr) off))
 (offset d a) (: e (d 'elf) (? (elfed? d && e 'taddr <= a < e 'taddr + e 'tsize) (a - e 'taddr + e 'toff) a))
 ;; the symbol an address falls in: "name" or "name+0x1c", "" when none within 64k below
 (symat d a)
  (? !(elfed? d) ""
     (: e (d 'elf)
        (go k) (? (k > 65536) ""
                  (: nm (peep (e 'syms) (a - k) "")
                     (? (0 < #nm) (k = 0 ? nm (nm + "+" + hexn k)) (go (k + 1)))))
        (go 0)))

 ;; --- the cursor and the window ----------------------------------------------------------
 (tell d s) (pin d 'msg s)
 (clamp d i) (? (i < 0) 0 (i >= d 'n) (d 'n - 1) i)
 ;; asm: one instruction at off, out of the patched bytes: -> (len . items)
 (insn d off) (x64-decode (slice d off (? (off + 16 < d 'n) (off + 16) (d 'n))) 0)
 (next-insn d off) (: r (insn d off) (clamp d (off + <r)))
 ;; the instruction before off: walk forward from a boundary above (the window's top, else a
 ;; little way back) and take the last one before off; if the walk never lands on off, the
 ;; shortest real decode from just above that does
 (prev-insn d off)
  (: anchor (? (d 'top < off) (d 'top) (off > 64) (off - 64) 0)
     (short k) (? (k > 15) (clamp d (off - 1))
                  (: b (off - k)
                     (? (b < 0) (clamp d (off - 1))
                        (: r (insn d b) (<r = k && <(<>r) = 'op ? b (short (k + 1)))))))
     (walk b last) (? (b >= off) (b = off ? last (short 1)) (walk (next-insn d b) b))
     (off = 0 ? 0 (walk anchor anchor)))
 ;; a row step in the hex view stays put at the file's edges, as vi's j and k do
 (row-move d n) (: t (d 'cur + n) (? (0 <= t < d 'n) (goto d t) d))
 (rows-of h) (h - 4 > 1 ? (h - 4) 1)
 ;; hex: the window is rows of 16 from a 16-aligned top; asm: rows of instructions from top
 (settle d h)
  (: rows (rows-of h) cur (d 'cur) top (d 'top)
     (? (d 'mode = 'hex)
        (: t0 (top - top % 16)
           t1 (? (cur < t0) (cur - cur % 16)
                 (cur >= t0 + rows * 16) (cur - cur % 16 - (rows - 1) * 16)
                 t0)
           (pin d 'top (t1 < 0 ? 0 t1)))
        (: t (? (cur < top) cur top)
           ;; walk the window: if the cursor is not among its rows, it becomes the top
           (seen k off) (? (k >= rows) 0 (off = cur) 1 (off >= d 'n) 0 (seen (k + 1) (next-insn d off)))
           (pin d 'top (seen 0 t ? t cur)))))
 (goto d off) (pin d 'cur (clamp d off))
 (move d n) (goto d (d 'cur + n))
 (step-insn d n) (goto d (n > 0 ? (next-insn d (d 'cur)) (prev-insn d (d 'cur))))
 (page d h k)
  (: rows (rows-of h)
     (? (d 'mode = 'hex) (move d (k * rows * 16))
        (: (go i off) (? (i = 0) off (go (i - 1) (k > 0 ? (next-insn d off) (prev-insn d off))))
           (goto d (go rows (d 'cur))))))

 ;; --- editing: a hex digit at the cursor, the high nibble first --------------------------
 (hexval c) (? (48 <= c <= 57) (c - 48) (97 <= c <= 102) (c - 87) -1)
 (poke d i v) (pins d 'dirty 1 'edits (pin (d 'edits) i v))
 (nibble d v)
  (: i (d 'cur) old (lupa-byte d i)
     (? (d 'nib < 0) (poke d i ((v << 4) | (old & 15)), pin d 'nib v)
        (poke d i ((d 'nib << 4) | v), pin d 'nib -1, move d 1)))
 (save d) (: q (open (d 'path) "w")
             (? (hot? q) (: _ (say q (patched d)) _ (close q) (pins d 'dirty 0 'msg ("wrote " + d 'path)))
                (tell d ("cannot write " + d 'path))))

 ;; --- find: a hex string or a "quoted text", from just past the cursor, wrapping --------
 (unhex h) (: t (string (filter (c \ !(c = 32)) (chars h)))
              (? (0 = #t || #t % 2 = 1 || !(foldl (\ a c (a && hexval c >= 0)) 1 (chars t))) ""
                 (string (map (\ i (hexval (t (2 * i)) * 16 + hexval (t (2 * i + 1)))) ^(#t // 2)))))
 (needle s) (? (#s >= 2 && s 0 = 34 && s (#s - 1) = 34) (snip s 1 (#s - 1)) (unhex s))
 (find d s)
  (: nd (needle s) n #nd
     (? (0 = n) (tell d "find: a hex string, or \"text\"")
        (: start (d 'cur + 1)
           (at? i) ((: (g k) (? (k >= n) 1 (lupa-byte d (i + k) = nd k) (g (k + 1)) 0)) 0)
           (go i left) (? (left = 0) -1 (i + n > d 'n) (go 0 left) (at? i) i (go (i + 1) (left - 1)))
           hit (go (start >= d 'n ? 0 start) (d 'n))
           (? (hit < 0) (tell d "not found") (pins d 'find s 'cur hit 'msg ("found at " + hexn (addr d hit)))))))

 ;; --- the command line: w q q! wq g / -----------------------------------------------------
 (words s) (filter (w \ 0 < #w) (split " " s))
 (joins l sep) (? !(two? l) "" (foldl (\ a s (a + sep + s)) <l >l))
 (hexnum s) (foldl (\ a c (a < 0 || hexval c < 0 ? -1 (a * 16 + hexval c))) 0 (chars s))
 (parse-addr d s)
  (: sym (elfed? d ? (peep ((d 'elf) 'names) s -1) -1)
     (? (sym >= 0) (offset d sym)
        (#s > 2 && s 0 = 48 && (s 1 = 120 || s 1 = 88)) (: v (hexnum (snip s 2 #s)) (v < 0 ? -1 (offset d v)))
        (: v (hexnum s) (v < 0 ? -1 (offset d v)))))
 (command d line)
  (: ws (words line) v (two? ws ? <ws "") arg (two? ws && two? >ws ? (joins >ws " ") "")
     (v @ "w" (save d)
          "q" (d 'dirty ? (tell d "unsaved edits: :w or :q!") (pin d 'over 1))
          "q!" (pin d 'over 1)
          "wq" (save d, pin d 'over 1)
          "g" (: a (parse-addr d arg) (a < 0 ? (tell d ("no such place: " + arg)) (goto d a, tell d "")))
          "/" (find d arg)
          (0 = #v ? d (tell d ("no such command: " + v)))))

 ;; --- the step: a key on the state -------------------------------------------------------
 (lupa-key d c) (: h (d 'h) hexmode (d 'mode = 'hex)
   (? (d 'in = 'cmd)
      (: t (d 'cmd) _ (edstep t c)
         (t 'ev @ 10 (pin d 'in 'map, command d (edtext t))
                  27 (pin d 'in 'map, tell d "")
                  d))
      (: _ (? (c = 58 || c = 27) 0 (pin d 'msg ""))
         (c @ (104 || -1) (hexmode ? (move d -1) (step-insn d -1))
              (108 || -2) (hexmode ? (move d 1) (step-insn d 1))
              (107 || -8) (hexmode ? (row-move d -16) (step-insn d -1))
              (106 || -9) (hexmode ? (row-move d 16) (step-insn d 1))
              6 (page d h 1)   2 (page d h -1)
              4 (page d h 1)   21 (page d h -1)
              (103 || -5) (goto d (elfed? d && !hexmode ? ((d 'elf) 'toff) 0))
              (71 || -6) (goto d (d 'n - 1))
              (100 || 9) (pins d 'mode (hexmode ? 'asm 'hex) 'nib -1)
              115 (pin d 'syn (d 'syn = 'att ? 'intel 'att))
              110 (0 < #(d 'find) ? (find d (d 'find)) (tell d "nothing to find again"))
              58 (pins d 'in 'cmd 'cmd (ednew ()) 'msg "")
              113 (d 'dirty ? (tell d "unsaved edits: :w or :q!") (pin d 'over 1))
              27 (pins d 'nib -1 'msg "")
              (? (hexmode && hexval c >= 0) (nibble d (hexval c)) d)))))

 ;; --- the frame ---------------------------------------------------------------------------
 (pad s n c) (#s < n ? (s + ((n - #s) (\ t (t + c)) "")) s)
 (fit s n c) (pad (#s > n ? (snip s 0 n) s) n c)
 (printable c) (32 <= c < 127 ? (string c) ".")
 ;; a hex row: 77 columns with its text, the text dropped on a narrower screen, the whole cut
 ;; to the screen; the cursor's cell is lit only when it is on the screen
 (hexrow d off w)
  (: n (d 'n) cur (d 'cur)
     hx (foldl (\ a i (a + (off + i < n ? (hex (lupa-byte d (off + i)) 2) "  ") + (i = 7 ? "  " " "))) "" ^16)
     tx (foldl (\ a i (a + (off + i < n ? (printable (lupa-byte d (off + i))) " "))) "" ^16)
     row (hex (addr d off) 8 + "  " + hx + (w < 78 ? "" ("|" + tx + "|")))
     k (cur - off)                                          ; the cursor's cell, if on this row
     col (10 + k * 3 + (k > 7 ? 1 0))
     (? (0 <= k < 16 && col + 2 <= w)
        (snip row 0 col + "\e[7m" + snip row col (col + 2) + "\e[0m" + fit (snip row (col + 2) #row) (w - col - 2) " ")
        (fit row w " ")))
 ;; an instruction's text in the chosen dialect, its targets named where a symbol covers them
 (named d o)
  (<o @ 'lbl (? !(charm? <>o) o
                (: s (symat d <>o) ['lbl (name (0 < #s ? s (hexn <>o)))]))
        'rip (? (nom? <>o) o
                (: s (symat d <>>o) ['rip (name (0 < #s ? s (hexn <>>o))) 0]))
        'ind ['ind (named d <>o)]
        'seg ['seg <>o (named d <>>o)]
        o)
 (insn-text d off ln its)
  (: base (addr d off)
     abs (map (\ it (<it = 'op ? ['op (it 1) (it 2) (map (o \ named d (dc-abs base 0 ln o)) (it 3))] it)) its)
     ls (lines ((d 'syn = 'att ? att-show intel-show) abs))
     ls2 (d 'syn = 'att ? ls >ls)                       ; past the .intel_syntax line
     (joins (map strip (filter (l \ 0 < #(strip l)) ls2)) "; "))
 (asmrow d off w)
  (: r (insn d off) ln <r its >r cur (off = d 'cur)
     bs (foldl (\ a i (a + (i < ln ? (hex (lupa-byte d (off + i)) 2) "  ") + " ")) "" ^7)
     s (symat d (addr d off)) sym (0 < #s && !(has? s "+") ? (s + ":") "")
     row (hex (addr d off) 8 + "  " + bs + (ln > 7 ? "+" " ") + " " + fit sym 14 " " + " " + insn-text d off ln its)
     [ln ((cur ? "\e[7m" "") + fit row w " " + (cur ? "\e[0m" ""))])
 (lupa-frame d w h) (: j (jug 0) rows (rows-of h) _ (pin d 'h h) _ (settle d h)
   e (d 'elf) hexmode (d 'mode = 'hex)
   title (" lupa: " + d 'path + (d 'dirty ? " [+]" "") + "  " + (hexmode ? "hex" "asm") + " " + show (d 'syn)
          + "  " + hexn (addr d (d 'cur)) + "/" + hexn (d 'n)
          + (elfed? d ? ("  .text " + hexn (e 'taddr) + " " + show (e 'tsize) + " bytes") ""))
   _ (say j ("\e[H\e[0m\e[7m" + fit title w " " + "\e[0m\e[K\r\n"))
   _ (? hexmode
        (each (jot rows) (\ k (: off (d 'top + k * 16)
                                 (say j ((off < d 'n ? (hexrow d off w) "") + "\e[0m\e[K\r\n")))))
        ((: (go k off) (? (k >= rows) 0
                          (: row (? (off < d 'n) (asmrow d off w) [1 ""])
                             _ (say j (<>row + "\e[0m\e[K\r\n"))
                             (go (k + 1) (off + <row)))))
         0 (d 'top)))
   cur (d 'cur) b (lupa-byte d cur) sym (symat d (addr d cur))
   about (" " + hexn (addr d cur) + "  byte " + hex b 2 + " " + show b + " " + printable b
          + (0 < #sym ? ("  " + sym) "") + (d 'nib >= 0 ? "  (high nibble set)" "")
          + (elfed? d ? "" "  (raw bytes)"))
   _ (say j (fit about w " " + "\e[K\r\n"))
   _ (say j (fit " hjkl move  ^f ^b page  g G ends  d hex/asm  s att/intel  0-9a-f edit  n again  :w :q :g ADDR :/ HEX  q quit" w " " + "\e[K\r\n"))
   _ (say j (d 'in @ 'cmd (fit (":" + edtext (d 'cmd)) w "" + "\e[K\e[?25h")
                        (fit (d 'msg) w " " + "\e[K\e[?25l")))
   (slurp j))

 ;; --- the runner: the tool on cli's stage ---------------------------------------------------
 (readf p) (: q (open p "r") (? (hot? q) (: t (slurp q) _ (close q) [1 t]) ()))
 (lupa-run p) (: r (readf p)
                 (? !(two? r) (puts ("lupa: cannot read " + p + "\n"), 1)
                    (0 = #(<>r)) (puts ("lupa: " + p + " is empty\n"), 1)
                    (: d (lupa-new <>r p)
                       (stage (w \ h \ lupa-frame d w h) (c \ lupa-key d c) (\ _ (d 'over))))))
 (lupa-main as) (two? as ? (lupa-run <as) (puts "usage: love lupa FILE\n", 1))
 _ (pins (from 'verbs 'tab) 'lupa lupa-main))
) ; module lupa
