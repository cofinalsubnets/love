// mandelbrot escape counts over a 64x64 grid (IEEE double).
class Main {
    static long mand(double cx, double cy) {
        double zx = 0.0, zy = 0.0;
        int it = 0;
        while (it < 100 && zx * zx + zy * zy <= 4.0) {
            double nzx = zx * zx - zy * zy + cx;
            double nzy = 2.0 * zx * zy + cy;
            zx = nzx;
            zy = nzy;
            it += 1;
        }
        return it;
    }

    static long work() {
        long s = 0;
        for (int px = 0; px < 64; px++) {
            for (int py = 0; py < 64; py++) {
                s += mand(-2.0 + px * 0.046875, -1.5 + py * 0.046875);
            }
        }
        return s;
    }

    public static void main(String[] a) {
        Bench.bench("float", Main::work);
    }
}
