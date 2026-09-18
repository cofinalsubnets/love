// java benchmark harness -- mirrors bench/bench.l and the py/js/jl harnesses.
// bench(name, work) auto-scales the repetition count (doubling until one timed
// batch clears MIN_MS), then times that count ONCE MORE and reports the second run --
// the scaling runs pay the fixed per-process costs (JIT warm-up, the heap's first
// growth), which otherwise ride on whichever power of two the doubling landed on.
// one line per bench, matching the other harnesses:
//     <name> <lang> <reps> <ms> <checksum>
// work is a nullary LongSupplier returning a deterministic checksum. BENCH_LANG
// sets the label, default "java". Locale.ROOT keeps the decimal separator a dot.
import java.util.Locale;
import java.util.function.LongSupplier;

public class Bench {
    static final double MIN_MS = 200.0;
    static final String LANG;
    static {
        String l = System.getenv("BENCH_LANG");
        LANG = (l != null) ? l : "java";
    }

    static final class Run {                    // one timed window: its ms and its checksum
        final double ms; final long chk;
        Run(double ms, long chk) { this.ms = ms; this.chk = chk; }
    }

    static Run run(LongSupplier work, long reps) {
        long t0 = System.nanoTime();
        long chk = 0;
        for (long i = 0; i < reps; i++) chk = work.getAsLong();
        return new Run((System.nanoTime() - t0) / 1e6, chk);
    }

    public static void bench(String name, LongSupplier work) {
        long reps = 1;
        for (;;) {
            if (run(work, reps).ms >= MIN_MS) {
                Run r = run(work, reps);        // warm
                System.out.printf(Locale.ROOT, "%s %s %d %.3f %d%n",
                        name, LANG, reps, r.ms, r.chk);
                break;
            }
            reps *= 2;
        }
    }
}
