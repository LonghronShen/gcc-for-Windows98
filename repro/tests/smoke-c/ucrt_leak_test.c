/*
 * ucrt_leak_test.c
 * UCRT 泄漏检测测试
 * 编译后检查 PE 导入表，确保只链接 msvcrt.dll
 * 确保没有 ucrtbase.dll、api-ms-win-*.dll
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

/* Use only msvcrt APIs - no UCRT-specific functions */
int main(void) {
    /* Basic stdio test */
    printf("ucrt-leak-test: hello\n");
    
    /* Basic string test (msvcrt has these) */
    char buf[256];
    strcpy(buf, "test-string");
    strcat(buf, "-append");
    
    if (strcmp(buf, "test-string-append") != 0) {
        fprintf(stderr, "string op failed\n");
        return 1;
    }
    
    /* Basic math test (msvcrt has these) */
    double result = sin(1.0) + cos(1.0);
    if (result < 0.0 || result > 2.0) {
        fprintf(stderr, "math op failed\n");
        return 1;
    }
    
    /* malloc/free (msvcrt) */
    void *p = malloc(1024);
    if (!p) {
        fprintf(stderr, "malloc failed\n");
        return 1;
    }
    memset(p, 0, 1024);
    free(p);
    
    /* fopen/fclose (msvcrt) */
    FILE *f = fopen("ucrt_test_file.txt", "w");
    if (!f) {
        fprintf(stderr, "fopen failed\n");
        return 1;
    }
    fprintf(f, "test-data\n");
    fclose(f);
    remove("ucrt_test_file.txt");
    
    printf("ucrt-leak-test: PASS\n");
    return 0;
}
