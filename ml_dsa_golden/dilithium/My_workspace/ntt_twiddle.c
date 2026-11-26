/*
 * Write the forward NTT's twiddle factors to CSV, one stage per column.
 * A factor is written once per butterfly group, even if that group uses it
 * for several coefficient multiplications.
 *
 * Build from the repository root:
 *   cc -std=c99 -Wall -Wextra -Iref My_workspace/ntt_twiddle.c \
 *      ref/reduce.c -o ntt_twiddle
 * Run:
 *   ./ntt_twiddle [output.csv]
 */
#include <stdint.h>
#include <stdio.h>

#include "../ref/params.h"

enum { STAGE_COUNT = 8, MAX_TWIDDLES_PER_STAGE = N / 2 };

static int32_t twiddles[STAGE_COUNT][MAX_TWIDDLES_PER_STAGE];
static unsigned int twiddle_count[STAGE_COUNT];
static int capture_error;

/* ntt() calls this once when it selects a zeta for a butterfly group. */
static void record_twiddle(unsigned int butterfly_size, int32_t zeta) {
  unsigned int stage = 0;
  unsigned int size = N / 2;

  /* The forward NTT uses sizes 128, 64, ..., 1 for stages 1 through 8. */
  while(stage < STAGE_COUNT && size != butterfly_size) {
    size /= 2;
    ++stage;
  }

  /* Stage s selects 2^s factors. Reject unexpected loop changes. */
  if(stage == STAGE_COUNT || twiddle_count[stage] >= (1u << stage)) {
    capture_error = 1;
    return;
  }

  /* Keep the order in which ntt() selects factors within this stage. */
  twiddles[stage][twiddle_count[stage]] = zeta;
  ++twiddle_count[stage];
}

/* Enable the optional hook only for this copy of the reference NTT. */
#define NTT_TWIDDLE_HOOK(size, zeta) record_twiddle((size), (zeta))
#include "../ref/ntt.c"
#undef NTT_TWIDDLE_HOOK

static int write_csv(FILE *output) {
  unsigned int row, stage;

  /* Stage 8 has 128 factors, so the CSV needs 128 rows. */
  for(row = 0; row < MAX_TWIDDLES_PER_STAGE; ++row) {
    for(stage = 0; stage < STAGE_COUNT; ++stage) {
      /* Empty cells keep each stage in its own column. */
      if(stage > 0 && fputc(',', output) == EOF)
        return -1;
      if(row < twiddle_count[stage] &&
         fprintf(output, "%ld", (long)twiddles[stage][row]) < 0)
        return -1;
    }
    if(fputc('\n', output) == EOF)
      return -1;
  }
  return 0;
}

int main(int argc, char **argv) {
  const char *path = argc == 2 ? argv[1] : "ntt_twiddles.csv";
  int32_t coefficients[N] = {0};
  FILE *output;
  unsigned int stage;

  if(argc > 2) {
    fprintf(stderr, "Usage: %s [output.csv]\n", argv[0]);
    return 1;
  }

  /* The input can be zero: factor selection depends on the loop positions. */
  ntt(coefficients);

  /* The eight stages should select 1, 2, 4, ..., 128 factors. */
  for(stage = 0; stage < STAGE_COUNT; ++stage) {
    if(capture_error || twiddle_count[stage] != (1u << stage)) {
      fprintf(stderr, "Unexpected twiddle count in stage %u\n", stage + 1);
      return 1;
    }
  }

  output = fopen(path, "w");
  if(output == NULL) {
    perror(path);
    return 1;
  }

  if(write_csv(output) != 0) {
    perror(path);
    fclose(output);
    return 1;
  }
  if(fclose(output) == EOF) {
    perror(path);
    return 1;
  }
  return 0;
}
