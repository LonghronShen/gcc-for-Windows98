/*
 * cpp_exception_test.cpp
 * C++ 异常测试 - 已有测试
 */
#include <exception>
#include <iostream>
#include <stdexcept>
#include <string>

static std::string do_throw() {
    throw std::runtime_error("exception-ok");
}

int main() {
    try {
        (void)do_throw();
        std::cerr << "no-throw" << std::endl;
        return 2;
    } catch (const std::runtime_error &e) {
        std::cout << e.what() << std::endl;
        return 0;
    } catch (...) {
        std::cerr << "wrong-exception" << std::endl;
        return 3;
    }
}
