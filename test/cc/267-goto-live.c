/* a goto to a C label is a jump inside the fn, not a tail call: a pointer param read only past
   the label (and past a call there) stays live along the goto's path. sqlite's resolveP2Values
   is the second shape. the answer is the exit status, so the bare-metal lanes run it too */

__attribute__((noinline)) static void touch(int *a) { (void)a; }

__attribute__((noinline)) static void outof_if(int *a, int *pm) {
    int n = *pm;
    while (1) {
        if (*a == 1) goto out;
        if (*a > n) n = *a;
        a--;
    }
out:
    touch(a);
    *pm = n;
}

__attribute__((noinline)) static void outof_switch(int *a, int *pm) {
    int n = *pm;
    while (1) {
        switch (*a) { case 1: goto out; default: if (*a > n) n = *a; break; }
        a--;
    }
out:
    touch(a);
    *pm = n;
}

__attribute__((noinline)) static void outof_nest(int *a, int rows, int *pm) {
    int n = *pm;
    for (int i = 0; i < rows; i++)
        for (int j = 0; j < 4; j++) {
            if (a[i * 4 + j] == 1) goto out;
            if (a[i * 4 + j] > n) n = a[i * 4 + j];
        }
out:
    touch(a);
    *pm = n;
}

int main(void) {
    int v[4] = { 1, 7, 3, 2 };
    int w[12] = { 2, 9, 4, 3, 5, 6, 8, 1, 11, 12, 13, 14 };
    int m1 = 5, m2 = 5, m3 = 5;
    outof_if(v + 3, &m1);
    outof_switch(v + 3, &m2);
    outof_nest(w, 3, &m3);
    return (m1 != 7) | (m2 != 7) << 1 | (m3 != 9) << 2;
}
