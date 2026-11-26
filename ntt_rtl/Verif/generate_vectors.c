#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include "ntt.h"

// A fixed seed makes failures reproducible while keeping both polynomials random.
static uint32_t random_word(uint32_t *state) {
    uint32_t x = *state;
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    return *state = x;
}

int main(int argc, char **argv) {
    if (argc != 2) {
        fprintf(stderr, "usage: %s output.csv\n", argv[0]);
        return 2;
    }

    FILE *out = fopen(argv[1], "w");
    if (!out) {
        perror(argv[1]);
        return 1;
    }

    uint32_t seed = 0x4e545432u;
    fprintf(out, "vector,index,input,expected\n");
    for (int vector = 0; vector < 2; ++vector) {
        int32_t input[N], transformed[N];
        for (int i = 0; i < N; ++i)
            transformed[i] = input[i] = (int32_t)(random_word(&seed) & 1u);

        // Call the actual Dilithium reference implementation linked by Makefile.
        ntt(transformed);
        for (int i = 0; i < N; ++i)
            fprintf(out, "%d,%d,%d,%d\n", vector, i, input[i], transformed[i]);
    }

    if (fclose(out) != 0) {
        perror("closing CSV");
        return 1;
    }
    return 0;
}
