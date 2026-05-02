/*
 * link_compare_test.c
 * 静态/动态链接对比测试
 * 同一程序分别静态链接和动态链接 libgcc/libstdc++
 * 比较 PE 大小和依赖差异
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

/* A non-trivial C program that uses libgcc features */
static double compute_something(double x) {
    return sin(x) * cos(x) + log(x + 1.0) + exp(-x);
}

static int string_ops(void) {
    char *s = strdup("hello");
    if (!s) return 1;
    
    char *t = malloc(strlen(s) + 10);
    if (!t) {
        free(s);
        return 1;
    }
    
    strcpy(t, s);
    strcat(t, "-world");
    
    int result = (strcmp(t, "hello-world") == 0) ? 0 : 1;
    
    free(s);
    free(t);
    return result;
}

static int float_ops(void) {
    double values[] = {1.0, 2.0, 3.0, 4.0, 5.0};
    double sum = 0.0;
    
    for (size_t i = 0; i < sizeof(values)/sizeof(values[0]); i++) {
        sum += compute_something(values[i]);
    }
    
    return (sum > 0.0) ? 0 : 1;
}

int main(void) {
    printf("link-compare-test: starting\n");
    
    if (string_ops() != 0) {
        fprintf(stderr, "string ops failed\n");
        return 1;
    }
    
    if (float_ops() != 0) {
        fprintf(stderr, "float ops failed\n");
        return 1;
    }
    
    printf("link-compare-test: PASS\n");
    return 0;
}
