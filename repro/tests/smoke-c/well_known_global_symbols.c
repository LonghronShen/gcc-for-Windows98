#include <time.h>
#include <stdlib.h>

int probe(void) {
  volatile long tz = _timezone;
  volatile int dl = _daylight;
  volatile char *zn = _tzname[0];
  volatile char **env = _environ;
  (void)tz;
  (void)dl;
  (void)zn;
  (void)env;
  return 0;
}
