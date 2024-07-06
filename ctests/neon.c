#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef __ARM_NEON
#include <arm_neon.h>
#endif

void add_vectors_neon(double *a, double *b, double *c, int n) {
#ifdef __ARM_NEON
    int i;
    for (i = 0; i < n; i += 2) {
        float64x2_t va = vld1q_f64(&a[i]);
        float64x2_t vb = vld1q_f64(&b[i]);
        float64x2_t vc = vaddq_f64(va, vb);
        vst1q_f64(&c[i], vc);
    }
#endif
}

void add_vectors_scalar(double *a, double *b, double *c, int n) {
    for (int i = 0; i < n; i++) {
        c[i] = a[i] + b[i];
    }
}

int main(int argc, char **argv) {
    const int n = 8;
    double a[n] = {1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0};
    double b[n] = {8.0, 7.0, 6.0, 5.0, 4.0, 3.0, 2.0, 1.0};
    double c[n];


#ifdef __ARM_NEON
printf("using neon\n");
        add_vectors_neon(a, b, c, n);
#else
        fprintf(stderr, "NEON is not supported on this platform.\n");
        add_vectors_scalar(a, b, c, n);
#endif

    printf("Result: ");
    for (int i = 0; i < n; i++) {
        printf("%f ", c[i]);
    }
    printf("\n");

    return 0;
}
