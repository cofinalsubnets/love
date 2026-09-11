# i/lib -- love as a library

A seat like every other in `i/`, except that the machine on the other side is
another program instead of another board. `i/playdate` is the closest relative:
it too owns no `main`, hands love a heap and a console it did not choose, and
drives the session by calling in. The difference is only that the caller may be
written in something other than C.

    make -C i/lib          # b/liblv.a and b/liblv.so
    make -C i/lib demo     # the C host, and the two-session probe
    make -C i/lib rust     # the same program in rust
    make -C i/lib go       # ..and in go

## the surface

`lv.h` is the whole public header: 25 functions, an opaque `struct lv`, no
`word`, no `struct ai`. Three decisions shape it and all three come from the
runtime rather than from taste.

**A value is a stack index, never a pointer.** The collector is a Cheney copier
(`l/gc.c`), so every heap address moves at the next allocation. love already
keeps a stack the collector walks, so the FFI hands out slots in it -- Lua's
answer, reached for Lua's reason. The one consequence a host must know is that
`lv_tostr` borrows bytes that die on the next call; `lv_strcpy` is the door that
copies, and the rust and go wrappers expose only that one.

**A scare is a return code.** love encodes its condition in the low bits of the
state pointer (`ai_code_of`), so a raise unwinds to C as `-1` with the session
still readable. No `setjmp`, no unwinding through foreign frames -- which is
most of what makes embedding a runtime unpleasant from rust or go.

**A host callback is an immortal cell carrying a slot number.** `ai_defn` asks
for immortal values, and an image bakes a nif as an index rather than an
address, so a raw function pointer in the heap could not survive a wake. The
trampoline reads its own `Ip[1]` and looks the host function up in a table --
`lvm_cur`'s own shape, the one `i/playdate`'s `cur_set` uses.

## what the tree already had

Very nearly all of it. `b/liblove.a` has existed as a build product for as long
as `t/front` has; `t/front/main.c` is an embedding in every respect but its
name, and `i/playdate/main.c` drives a session from a frame callback. What was
missing was not machinery but a narrow header, a seat that routes output to the
caller instead of to a console, and marshalling in both directions.

## measured

x64, gcc, this tree, the demo programs in this folder.

| | |
|---|---|
| `b/liblv.o` (core + seat, one object) | 2.7 MB, ~280 KB of text |
| `b/liblv.so`, exports trimmed | 1.7 MB, 26 dynamic symbols |
| open, baking the egg | 550-700 ms |
| open, waking a saved image | 3 ms |
| a saved image | 516 KB |
| `lv_apply` of a 2-argument love closure, from C | 0.36-0.44 us |
| the same from rust | 0.37 us |
| the same from go (cgo) | 0.56 us |
| love calling back into go | 0.80 us |

The seat the runtime asks of a linked-in love is 18 symbols plus `mem*`/`strlen`
and `mmap`/`mprotect`/`munmap`/`sysconf` -- `nm` on the archive names them.
`seat.c` answers all of them in 70 lines.

## things found on the way

**An image belongs to the binary that baked it.** `ai_image_load` refuses an
image laid by a different link and answers NULL, and `lv_open` then falls back
to the egg bake -- correct, and 200x slower in silence. An embedder that ships
an image must fail loudly instead, or the first relink turns a 3 ms open into
half a second and nothing says so.

**The runtime ships partially linked, and that is the whole build story.**
`ai_typ` reads nine one-instruction functions as an array (`love.c`'s DSENT), so
they must lie at a fixed stride, and the ambient `ld` only does that under
`l/love_data.ld`. Laying the tiling in OUR build with `ld -r` settles it inside
the object -- `.love.data` comes out one 9x16 section and the final link places
it whole, offsets already right. So an embedder keeps the fast `ai_typ` and
carries no linker script: the alternative, `-Dai_data_section=0`, buys the same
freedom by putting a comparison chain on the path every value dispatch takes.

**`__start_love_nifs` needs keeping, twice over.** Nothing references a
`love_nifs` row -- the bracket is how they are found -- so it falls to two
different collectors. An ARCHIVE never pulls the member in the first place,
which is why the deliverable is an object; and `--gc-sections`, which rust
passes, drops the section even from an object. The second wants
SHF_GNU_RETAIN, so `LvNif` carries `retain` on the ambient-cc lane only --
mooncc and holo collect nothing and are not asked to parse it.

**Two sessions in one process work.** `i/lib/two.c` opens two, defines a
different `x` in each, churns half a million words through one and reads the
other back intact. What is genuinely process-global is smaller than it looks:
`ai_system` (read only by inle's `/proc`), the three static console ports, and
-- in this spike -- `lv.c`'s `live` pointer, which the trampoline uses to find
its table. That last one is the only real blocker to a supported multi-session
API, and it is a table keyed by the session rather than a global.

**`cook` could not resolve a `../..`-prefixed target**, which is how every port
makefile in the tree came to be GNU make only in practice. Two bugs, both fixed
in the commit after this one: a rule whose target began with a dot was dropped
on the way to dropping `.PHONY`, and `CURDIR` was never seeded. What is left is
`$(foreach ...$(eval ...))` -- cook recognizes `$(eval)` only as a whole line --
so `make -C i/lib` now runs under cook and `make -C i/mps2` still does not.

## not done

- `lv_apply` builds a form and hands it to `ai_eval_`, so every call compiles a
  two-cell application. The runtime has the stackless call-out bridge already
  (`callout_drive`, `l/ev.c`) and an `ai_apply_` exported beside `ai_eval_`
  would skip the compile. Price it before believing it matters: 0.4 us is
  already under a cgo crossing.
- No foreign pointer kind. A host handle has to be a fixnum index into a
  host-side table, because `KSun` is a boxed `intptr_t` that orders as a
  *number* -- `net`, `=` and `sort` would all read a pointer as arithmetic. A
  real userdata kind is a `mx.l` change and touches the collector, the printer
  and `cmp3`.
- No tablet door, no tray door: a host can pass lists and strings and nothing
  else compound.
- `lv_eval` recovers from a scare in C (the depth is restored and the status
  bits are stripped once the condition is read). love's own `trap` in
  `l/boot/post.l` is the better catcher, and a production `lv_eval` should
  wrap the form in it rather than re-entering a scared state from outside.
- No gate. Nothing here runs under `make test`.
