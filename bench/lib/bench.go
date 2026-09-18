// go benchmark harness -- mirrors bench/bench.l.
// bench(name, work) auto-scales the repetition count (doubling until the run
// clears MIN_MS), then times that count ONCE MORE and reports the second run --
// the scaling runs pay the fixed per-process costs (JIT warm-up, the heap's first
// growth), which otherwise ride on whichever power of two the doubling landed on.
// one line per bench, matching the other harnesses:
//
//	<name> <lang> <reps> <ms> <checksum>
//
// work is a nullary function returning a deterministic checksum. BENCH_LANG
// sets the label, default "go". Compiled together with each benches/<name>.go
// via `go run` -- there is exactly one main (in the bench file).
package main

import (
	"fmt"
	"os"
	"time"
)

const minMs = 200.0

func benchRun(work func() int64, reps int) (float64, int64) {
	t0 := time.Now()
	var chk int64
	for i := 0; i < reps; i++ {
		chk = work()
	}
	return float64(time.Since(t0)) / float64(time.Millisecond), chk
}

func bench(name string, work func() int64) {
	lang := os.Getenv("BENCH_LANG")
	if lang == "" {
		lang = "go"
	}
	reps := 1
	for {
		ms, chk := benchRun(work, reps)
		if ms >= minMs {
			ms, chk = benchRun(work, reps) // warm
			fmt.Printf("%s %s %d %.3f %d\n", name, lang, reps, ms, chk)
			break
		}
		reps *= 2
	}
}
