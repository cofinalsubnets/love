import java.util.function.LongUnaryOperator;
// closures escape into an array, then applied through it (non-inlinable). checksum = sum 3i.
class Main {
    static final int N = 100000;
    static LongUnaryOperator twice(LongUnaryOperator f) {
        return x -> f.applyAsLong(f.applyAsLong(x));
    }
    static LongUnaryOperator adder(long i) {
        return x -> x + i;
    }
    static long work() {
        LongUnaryOperator[] fns = new LongUnaryOperator[N];
        for (int i = 0; i < N; i++) fns[i] = twice(adder(i));
        long s = 0;
        for (int i = 0; i < N; i++) s += fns[i].applyAsLong(i);
        return s;
    }
    public static void main(String[] a) {
        Bench.bench("closure", Main::work);
    }
}
