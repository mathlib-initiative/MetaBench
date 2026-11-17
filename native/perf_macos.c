#include <errno.h>
#include <stddef.h>
#include <stdint.h>

// `thread_selfcounts` is not declared publicly in the macOS SDK:
//
// Its implementation is in:
// https://github.com/apple-oss-distributions/xnu/blob/xnu-12377.121.6/bsd/kern/sys_recount.c#L174-L192
//
// In our case (kind = THSC_CPI = 1) `thread_selfcounts` uses `struct thsc_cpi`:
// https://github.com/apple-oss-distributions/xnu/blob/ac9718fb1af618d5ce8678d0dc6e8a58f252216f/bsd/kern/sys_recount.c#L113-L116
//
// `struct thsc_cpi` is defined at:
// https://github.com/apple-oss-distributions/xnu/blob/ac9718fb1af618d5ce8678d0dc6e8a58f252216f/bsd/sys/resource_private.h#L76
struct thsc_cpi {
  uint64_t tcpi_instructions;
  uint64_t tcpi_cycles;
};
int thread_selfcounts(uint32_t kind, void *dst, size_t size);

// For compatibility with the Linux API.
int32_t metabench_instr_count_open(void) {
  return 0;
}

// Return the number of CPU instructions since the current thread started or `-errno`. `fd` is unused.
int64_t metabench_instr_count_read(int32_t fd) {
  (void)fd;
  struct thsc_cpi counts = {0};
  if (thread_selfcounts(1, &counts, sizeof counts) != 0) return -(int64_t)errno;
  // Report a 0 count as an error.
  if (counts.tcpi_instructions == 0) return -(int64_t)ENOTSUP;
  return (int64_t)counts.tcpi_instructions;
}

// For compatibility with the Linux API.
int32_t metabench_instr_count_close(int32_t fd) {
  (void)fd;
  return 0;
}
