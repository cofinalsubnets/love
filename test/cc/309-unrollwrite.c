/* a small counted loop whose body writes its own counter is not unrolled: each copy would
 * read k as its literal. the exit sums what the loops leave, 34 */
int main(void) {
	int s = 0, t = 0, u = 0, w = 0;
	for (int k = 0; k < 8; k++) { s += k; k++; }
	for (int k = 0; k < 8; k++) { t += k; if (k == 2) k = 6; }
	for (int k = 0; k < 6; k++) { u = u * 3 + k; k += 1; }
	for (int k = 0; k < 4; k++) { w += k; ++k; }
	return s + t + u + w; }
