/*
 * floating_point_test.c
 * 浮点运算测试 - 已有测试
 */
#include <stdio.h>
#include <math.h>

int main(void) {
    double a = 3.141592653589793;
    double b = 2.718281828459045;
    
    double sum = a + b;
    double diff = a - b;
    double prod = a * b;
    double quot = a / b;
    
    /* Check basic operations */
    if (fabs(sum - 5.859874482) > 0.0001) {
        fprintf(stderr, "Addition failed\n");
        return 1;
    }
    
    if (fabs(diff - 0.423310825) > 0.0001) {
        fprintf(stderr, "Subtraction failed\n");
        return 1;
    }
    
    if (fabs(prod - 8.539734222) > 0.0001) {
        fprintf(stderr, "Multiplication failed\n");
        return 1;
    }
    
    if (fabs(quot - 1.155727349) > 0.0001) {
        fprintf(stderr, "Division failed\n");
        return 1;
    }
    
    /* Check math functions */
    if (fabs(sin(a)) > 0.0001) {
        fprintf(stderr, "sin(pi) failed\n");
        return 1;
    }
    
    if (fabs(cos(a) - (-1.0)) > 0.0001) {
        fprintf(stderr, "cos(pi) failed\n");
        return 1;
    }
    
    printf("floating-point-test: PASS\n");
    return 0;
}
