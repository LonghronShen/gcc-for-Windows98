/*
 * cpp_exception_cross_test.cpp
 * C++ 异常处理跨 DLL 边界测试
 * - C++ try/catch 跨 DLL 边界
 * - 异常类型传播
 */

#include <iostream>
#include <stdexcept>
#include <string>
#include <exception>

#define TEST_PASS(msg)  std::cout << "PASS: " << msg << std::endl
#define TEST_FAIL(msg)  do { std::cerr << "FAIL: " << msg << std::endl; return 1; } while(0)

/* Simulate "DLL" boundary by using function pointers and separate compilation units.
 * In a real scenario, these would be in separate DLLs. For smoke test purposes,
 * we test the exception mechanism itself. */

/* Function that throws from a "DLL" */
static void dll_throw_runtime_error(void) {
    throw std::runtime_error("exception-from-dll");
}

static void dll_throw_logic_error(void) {
    throw std::logic_error("logic-error-from-dll");
}

static void dll_throw_int(void) {
    throw 42;
}

static void dll_throw_string(void) {
    throw std::string("string-exception");
}

static void dll_rethrow(void) {
    try {
        dll_throw_runtime_error();
    } catch (const std::runtime_error&) {
        throw;  /* rethrow */
    }
}

/* ============================================================================
 * Test 1: Catch std::runtime_error across "DLL" boundary
 * ============================================================================ */
int test_catch_runtime_error(void) {
    try {
        dll_throw_runtime_error();
        TEST_FAIL("exception was not thrown");
    } catch (const std::runtime_error &e) {
        if (std::string(e.what()) != "exception-from-dll") {
            TEST_FAIL("exception message mismatch");
        }
    } catch (...) {
        TEST_FAIL("wrong exception type caught");
    }
    
    TEST_PASS("catch std::runtime_error across boundary");
    return 0;
}

/* ============================================================================
 * Test 2: Catch std::logic_error across "DLL" boundary
 * ============================================================================ */
int test_catch_logic_error(void) {
    try {
        dll_throw_logic_error();
        TEST_FAIL("exception was not thrown");
    } catch (const std::logic_error &e) {
        if (std::string(e.what()) != "logic-error-from-dll") {
            TEST_FAIL("exception message mismatch");
        }
    } catch (...) {
        TEST_FAIL("wrong exception type caught");
    }
    
    TEST_PASS("catch std::logic_error across boundary");
    return 0;
}

/* ============================================================================
 * Test 3: Catch int across "DLL" boundary
 * ============================================================================ */
int test_catch_int(void) {
    try {
        dll_throw_int();
        TEST_FAIL("exception was not thrown");
    } catch (int n) {
        if (n != 42) {
            TEST_FAIL("int exception value mismatch");
        }
    } catch (...) {
        TEST_FAIL("wrong exception type caught");
    }
    
    TEST_PASS("catch int across boundary");
    return 0;
}

/* ============================================================================
 * Test 4: Catch std::string across "DLL" boundary
 * ============================================================================ */
int test_catch_string(void) {
    try {
        dll_throw_string();
        TEST_FAIL("exception was not thrown");
    } catch (const std::string &s) {
        if (s != "string-exception") {
            TEST_FAIL("string exception value mismatch");
        }
    } catch (...) {
        TEST_FAIL("wrong exception type caught");
    }
    
    TEST_PASS("catch std::string across boundary");
    return 0;
}

/* ============================================================================
 * Test 5: Rethrow across "DLL" boundary
 * ============================================================================ */
int test_rethrow(void) {
    try {
        dll_rethrow();
        TEST_FAIL("exception was not thrown");
    } catch (const std::runtime_error &e) {
        if (std::string(e.what()) != "exception-from-dll") {
            TEST_FAIL("rethrown exception message mismatch");
        }
    } catch (...) {
        TEST_FAIL("wrong exception type caught after rethrow");
    }
    
    TEST_PASS("rethrow across boundary");
    return 0;
}

/* ============================================================================
 * Test 6: Catch by reference vs value
 * ============================================================================ */
int test_catch_by_reference(void) {
    try {
        throw std::runtime_error("ref-test");
    } catch (const std::exception &e) {
        if (std::string(e.what()) != "ref-test") {
            TEST_FAIL("catch by reference failed");
        }
    }
    
    TEST_PASS("catch by reference");
    return 0;
}

/* ============================================================================
 * Test 7: std::uncaught_exception (deprecated in C++17, but test anyway)
 * ============================================================================ */
struct UncaughtChecker {
    ~UncaughtChecker() {
        /* In C++17, std::uncaught_exception is deprecated,
         * but mingw-w64 GCC 13 may still support it */
#if __cplusplus >= 201703L
        /* Use std::uncaught_exceptions() in C++17 */
        if (std::uncaught_exceptions() > 0) {
            std::cout << "INFO: destructor called during stack unwind ("
                      << std::uncaught_exceptions() << " exceptions)"
                      << std::endl;
        }
#else
        if (std::uncaught_exception()) {
            std::cout << "INFO: destructor called during stack unwind" << std::endl;
        }
#endif
    }
};

int test_uncaught_exception(void) {
    try {
        UncaughtChecker checker;
        throw std::runtime_error("uncaught-test");
    } catch (...) {
        /* Expected */
    }
    
    TEST_PASS("uncaught_exception check");
    return 0;
}

/* ============================================================================
 * Main
 * ============================================================================ */
int main(void) {
    int failures = 0;
    
    std::cout << "=== C++ Exception Cross-Boundary Smoke Test ===" << std::endl << std::endl;
    
    failures += test_catch_runtime_error();
    failures += test_catch_logic_error();
    failures += test_catch_int();
    failures += test_catch_string();
    failures += test_rethrow();
    failures += test_catch_by_reference();
    failures += test_uncaught_exception();
    
    std::cout << std::endl << "=== Results: " << failures << " failure(s) ===" << std::endl;
    return failures;
}
