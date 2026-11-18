#include <errno.h>
#include <linux/perf_event.h>
#include <stdint.h>
#include <sys/syscall.h>
#include <unistd.h>

// Initialize a new CPU instructions counter. Returns its file descriptor or `-errno`.
int32_t metabench_instr_count_open(void) {
  struct perf_event_attr attr = {
    .type = PERF_TYPE_HARDWARE,
    .size = sizeof attr,
    .config = PERF_COUNT_HW_INSTRUCTIONS,
    .exclude_kernel = 1,
    .exclude_hv = 1,
  };
  int fd = (int)syscall(SYS_perf_event_open, &attr, 0, -1, -1, PERF_FLAG_FD_CLOEXEC);
  return fd < 0 ? -errno : fd;
}

// Returns the count of the counter with descriptor `fd`, or `-errno`.
int64_t metabench_instr_count_read(int32_t fd) {
  uint64_t count;
  ssize_t n = read(fd, &count, sizeof count);
  if (n != (ssize_t)sizeof count) return -(int64_t)(n < 0 ? errno : EIO);
  return (int64_t)count;
}

// Close the counter with descriptor `fd`. Returns 0, or `-errno`.
int32_t metabench_instr_count_close(int32_t fd) {
  return close(fd) == 0 ? 0 : -errno;
}
