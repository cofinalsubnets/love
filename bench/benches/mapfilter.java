// square every element of 0..9999, keep the even squares, sum them.
// checksum = 166616670000.
class Main {
    static final int N = 10000;

    static long work() {
        long s = 0;
        for (int i = 0; i < N; i++) {
            long sq = (long) i * i;
            if (sq % 2 == 0) {
                s += sq;
            }
        }
        return s;
    }

    public static void main(String[] a) {
        Bench.bench("mapfilter", Main::work);
    }
}
