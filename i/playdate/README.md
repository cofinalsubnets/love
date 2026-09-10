# love on the playdate: the rune workbench

the rune CAS (apps/rune.l) riding the crank. crank (or left/right) picks a
card, up/down turns the dial n, A differentiates the view, B factors it --
Zassenhaus under a button, every answer exact. cas.l is the whole demo;
main.c is the love frontend glue (the console is a quay cb, 50x30 cells of
the 8x8 CGA font, blitted to the 1-bit LCD each frame).

    make -C i/playdate        # out/playdate/love.pdx (device + simulator)
    make -C i/playdate sim    # run it in the Playdate Simulator

**nothing foreign compiles or links the device half.** mooncc `-t thumb2sp`
builds every object, pdglue.c included -- it owns pd_api.h and flattens the SDK
to a word-only seam, and it stands in for the SDK's setup.c (the entry and the
malloc trio) -- and our own linker binds them: `-Ttext 0` because link_map.ld
names no address at all, `--emit-relocs` so the ABS32 sites survive for the
loader to slide, `-nostdlib` because six moonlibc members and rt.c beside them
are the whole runtime this seat wants. The STM32F746's FPU is single-precision,
so f64 arithmetic softens to the `__aeabi_*` calls rt.c answers, gated bit-exact
by `make test_thumb2sp`; `la` rides pooled ABS32 words, which is what makes the
relocation table complete (a MOVW/MOVT pair is an absolute no loader slides by
adding to a word). PLAYDATE_SDK_PATH is wanted for the C_API headers and for
pdc, which bundles the .pdx. The simulator pdex.so stays a host gcc shared
object -- there setup.c is the SDK's again -- so `make sim` needs no cross tools.

based on Panic's "Hello World" C API example by Dave Hayden.
