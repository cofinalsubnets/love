int q = 40;
int *p = &q;
int arr[3] = {1, 2, 3};
int *ap = arr;
int main() { return *p + ap[1] + ap[2]; }
