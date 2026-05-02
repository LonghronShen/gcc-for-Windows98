/*
 * thread_test.c
 * 线程测试（使用 pthreads-w32）- 已有测试
 */
#include <pthread.h>
#include <stdio.h>
#include <unistd.h>

void* thread_func(void* arg) {
    printf("Hello from pthread!\n");
    return NULL;
}

int main() {
    pthread_t thread;
    if (pthread_create(&thread, NULL, thread_func, NULL) != 0) {
        perror("pthread_create");
        return 1;
    }
    pthread_join(thread, NULL);
    printf("Thread finished.\n");
    return 0;
}
