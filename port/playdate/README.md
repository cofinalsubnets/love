# love on the playdate: the rune workbench

the rune CAS (crew/rune/) riding the crank. crank (or left/right) picks a
card, up/down turns the dial n, A differentiates the view, B factors it --
Zassenhaus under a button, every answer exact. cas.l is the whole demo;
main.c is the love frontend glue (the console is a quay cb, 50x30 cells of
the 8x8 CGA font, blitted to the 1-bit LCD each frame).

    make -C port/playdate        # out/playdate/love.pdx (device + simulator)
    make -C port/playdate sim    # run it in the Playdate Simulator

needs PLAYDATE_SDK_PATH (pdc + C_API + simulator) and arm-none-eabi-gcc for
the device half; `make sim` alone needs no cross tools.

based on Panic's "Hello World" C API example by Dave Hayden.
