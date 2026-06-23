import java.util.function.LongUnaryOperator;

// closure / higher-order stress. checksum = sum of 3i for i in [0, N).
class Main {
    static final int N = 100000;

    static LongUnaryOperator twice(LongUnaryOperator f) {
        return x -> f.applyAsLong(f.applyAsLong(x));
    }

    static LongUnaryOperator adder(long i) {
        return x -> x + i;
    }

    static long work() {
        long s = 0;
        for (int i = 0; i < N; i++) {
            s += twice(adder(i)).applyAsLong(i);
        }
        return s;
    }

    public static void main(String[] a) {
        Bench.bench("closure", Main::work);
    }
}
