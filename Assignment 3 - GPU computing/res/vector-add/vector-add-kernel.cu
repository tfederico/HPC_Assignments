__global__ void vec_add_kernel(float *c, float *a, float *b, int n) {
    int i = 0;   // Oops! Something is not right here, please fix it!
    if (i < n) {
        c[i] = a[i] + b[i];
    }
}
