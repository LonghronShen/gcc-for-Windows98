#include <stdio.h>
#include <time.h>

int main() {
    time_t t = time(NULL);
    printf("Current time: %s", ctime(&t));

    long timezone_value = _timezone;
    printf("Timezone: %ld seconds\n", timezone_value);

    return 0;
}