# love on the playdate: the rune workbench

the rune CAS (crew/rune/) riding the crank. crank (or left/right) picks a
card, up/down turns the dial n, A differentiates the view, B factors it --
Zassenhaus under a button, every answer exact. cas.l is the whole demo;
main.c is the love frontend glue (the console is a quay cb, 50x30 cells of
the 8x8 CGA font, blitted to the 1-bit LCD each frame).

    make -C port/playdate        # out/playdate/love.pdx (device + simulator)
    make -C port/playdate sim    # run it in the Playdate Simulator

the DEVICE half is compiled by **mooncc** (`-t thumb2sp`: the STM32F746's FPU
is single-precision, so f64 arithmetic softens to the same `__aeabi_*` libgcc
helpers Panic's toolchain uses -- gated bit-exact by `make test_thumb2sp`,
and `la` rides pooled ABS32 words since the loader relocates words, never a
MOVW/MOVT pair). only pdglue.c (the pd_api.h owner: the SDK flattened to a
word-only seam -- no float ABI, no variadics cross to moon code) and the
SDK's setup.c ride arm-none-eabi-gcc. needs PLAYDATE_SDK_PATH (pdc + C_API +
simulator); the simulator pdex.so stays a host gcc shared object, so
`make sim` alone needs no cross tools.

based on Panic's "Hello World" C API example by Dave Hayden.
