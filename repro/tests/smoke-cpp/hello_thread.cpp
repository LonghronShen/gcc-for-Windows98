#include <iostream>
#include <thread>

void thread_func() {
    std::cout << "Hello from std::thread!" << std::endl;
}

int main() {
    std::thread t(thread_func);
    t.join();
    std::cout << "Thread finished." << std::endl;
    return 0;
}
