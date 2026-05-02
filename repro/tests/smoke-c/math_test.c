/*
 * math_test.c
 * 数学函数测试 - 已有测试
 */
#include <stdio.h>
#include <math.h>

int main(void) {
    /* Test various math functions available in msvcrt */
    double x = 2.0;
    
    if (fabs(sqrt(x) - 1.41421356) > 0.0001) {
        fprintf(stderr, "sqrt failed\n");
        return 1;
    }
    
    if (fabs(pow(x, 3.0) - 8.0) > 0.0001) {
        fprintf(stderr, "pow failed\n");
        return 1;
    }
    
    if (fabs(log(x) - 0.693147) > 0.0001) {
        fprintf(stderr, "log failed\n");
        return 1;
    }
    
    if (fabs(exp(x) - 7.389056) > 0.0001) {
        fprintf(stderr, "exp failed\n");
        return 1;
    }
    
    if (fabs(fabs(-x) - 2.0) > 0.0001) {
        fprintf(stderr, "fabs failed\n");
        return 1;
    }
    
    if (fabs(ceil(1.5) - 2.0) > 0.0001) {
        fprintf(stderr, "ceil failed\n");
        return 1;
    }
    
    if (fabs(floor(1.5) - 1.0) > 0.0001) {
        fprintf(stderr, "floor failed\n");
        return 1;
    }
    
    printf("math-test: PASS\n");
    return 0;
}
