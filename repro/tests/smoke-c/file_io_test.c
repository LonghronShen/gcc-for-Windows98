/*
 * file_io_test.c
 * 文件操作测试 - 已有测试
 */
#include <stdio.h>
#include <string.h>

int main(void) {
    const char *filename = "smoke_test_file.txt";
    const char *expected = "Win98-file-io-test-data";
    char buffer[256];
    FILE *fp;
    
    /* Write test */
    fp = fopen(filename, "w");
    if (!fp) {
        perror("fopen write");
        return 1;
    }
    fprintf(fp, "%s", expected);
    fclose(fp);
    
    /* Read test */
    fp = fopen(filename, "r");
    if (!fp) {
        perror("fopen read");
        return 1;
    }
    if (!fgets(buffer, sizeof(buffer), fp)) {
        perror("fgets");
        fclose(fp);
        return 1;
    }
    fclose(fp);
    
    /* Verify */
    if (strcmp(buffer, expected) != 0) {
        fprintf(stderr, "Data mismatch: expected '%s', got '%s'\n", expected, buffer);
        return 1;
    }
    
    /* Cleanup */
    remove(filename);
    
    printf("file-io-test: PASS\n");
    return 0;
}
