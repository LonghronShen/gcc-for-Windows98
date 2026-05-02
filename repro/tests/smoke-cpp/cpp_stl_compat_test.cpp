/*
 * cpp_stl_compat_test.cpp
 * C++ STL 兼容性测试
 * - std::string、std::vector、std::map 基本操作
 * - std::thread 使用 pthreads-w32 实现
 * - std::fstream 文件操作
 * - std::list, std::deque, std::set 基本操作
 */

#include <iostream>
#include <string>
#include <vector>
#include <map>
#include <list>
#include <deque>
#include <set>
#include <fstream>
#include <thread>
#include <mutex>
#include <algorithm>
#include <numeric>

#define TEST_PASS(msg)  std::cout << "PASS: " << msg << std::endl
#define TEST_FAIL(msg)  do { std::cerr << "FAIL: " << msg << std::endl; return 1; } while(0)

static std::mutex g_mutex;
static int g_thread_counter = 0;

/* ============================================================================
 * Test 1: std::string
 * ============================================================================ */
int test_string(void) {
    std::string s1 = "Hello";
    std::string s2 = "World";
    std::string s3 = s1 + " " + s2;
    
    if (s3 != "Hello World") {
        TEST_FAIL("std::string concatenation failed");
    }
    
    if (s3.length() != 11) {
        TEST_FAIL("std::string length incorrect");
    }
    
    if (s3.find("World") == std::string::npos) {
        TEST_FAIL("std::string find failed");
    }
    
    s3.replace(6, 5, "Win98");
    if (s3 != "Hello Win98") {
        TEST_FAIL("std::string replace failed");
    }
    
    TEST_PASS("std::string operations");
    return 0;
}

/* ============================================================================
 * Test 2: std::vector
 * ============================================================================ */
int test_vector(void) {
    std::vector<int> v;
    for (int i = 0; i < 100; i++) {
        v.push_back(i);
    }
    
    if (v.size() != 100) {
        TEST_FAIL("std::vector size incorrect");
    }
    
    int sum = std::accumulate(v.begin(), v.end(), 0);
    if (sum != 4950) {
        TEST_FAIL("std::vector accumulate failed");
    }
    
    auto it = std::find(v.begin(), v.end(), 50);
    if (it == v.end() || *it != 50) {
        TEST_FAIL("std::vector find failed");
    }
    
    v.erase(v.begin() + 25);
    if (v.size() != 99) {
        TEST_FAIL("std::vector erase failed");
    }
    
    TEST_PASS("std::vector operations");
    return 0;
}

/* ============================================================================
 * Test 3: std::map
 * ============================================================================ */
int test_map(void) {
    std::map<std::string, int> m;
    m["one"] = 1;
    m["two"] = 2;
    m["three"] = 3;
    
    if (m.size() != 3) {
        TEST_FAIL("std::map size incorrect");
    }
    
    if (m["two"] != 2) {
        TEST_FAIL("std::map access failed");
    }
    
    auto it = m.find("three");
    if (it == m.end() || it->second != 3) {
        TEST_FAIL("std::map find failed");
    }
    
    m.erase("one");
    if (m.size() != 2) {
        TEST_FAIL("std::map erase failed");
    }
    
    TEST_PASS("std::map operations");
    return 0;
}

/* ============================================================================
 * Test 4: std::list
 * ============================================================================ */
int test_list(void) {
    std::list<int> lst = {3, 1, 4, 1, 5, 9, 2, 6};
    
    lst.sort();
    
    std::vector<int> expected = {1, 1, 2, 3, 4, 5, 6, 9};
    if (lst.size() != expected.size()) {
        TEST_FAIL("std::list size incorrect after sort");
    }
    
    auto lit = lst.begin();
    for (size_t i = 0; i < expected.size(); i++, ++lit) {
        if (lit == lst.end() || *lit != expected[i]) {
            TEST_FAIL("std::list sort result incorrect");
        }
    }
    
    lst.unique();
    if (lst.size() != 7) {
        TEST_FAIL("std::list unique failed");
    }
    
    TEST_PASS("std::list operations");
    return 0;
}

/* ============================================================================
 * Test 5: std::deque
 * ============================================================================ */
int test_deque(void) {
    std::deque<int> dq;
    
    for (int i = 0; i < 50; i++) {
        dq.push_back(i);
        dq.push_front(-i);
    }
    
    if (dq.size() != 100) {
        TEST_FAIL("std::deque size incorrect");
    }
    
    if (dq.front() != -49 || dq.back() != 49) {
        TEST_FAIL("std::deque front/back incorrect");
    }
    
    dq.pop_front();
    dq.pop_back();
    if (dq.size() != 98) {
        TEST_FAIL("std::deque pop failed");
    }
    
    TEST_PASS("std::deque operations");
    return 0;
}

/* ============================================================================
 * Test 6: std::set
 * ============================================================================ */
int test_set(void) {
    std::set<int> s;
    s.insert(5);
    s.insert(2);
    s.insert(8);
    s.insert(2);  /* duplicate */
    
    if (s.size() != 3) {
        TEST_FAIL("std::set size incorrect (duplicate not rejected)");
    }
    
    if (s.count(2) != 1 || s.count(99) != 0) {
        TEST_FAIL("std::set count failed");
    }
    
    auto it = s.lower_bound(5);
    if (it == s.end() || *it != 5) {
        TEST_FAIL("std::set lower_bound failed");
    }
    
    TEST_PASS("std::set operations");
    return 0;
}

/* ============================================================================
 * Test 7: std::fstream
 * ============================================================================ */
int test_fstream(void) {
    const char *filename = "stl_fstream_test.txt";
    const std::string expected = "STL-fstream-test-data-line1\nline2\nline3";
    
    /* Write */
    {
        std::ofstream out(filename, std::ios::binary);
        if (!out) {
            TEST_FAIL("std::ofstream open failed");
        }
        out << expected;
        if (!out.good()) {
            TEST_FAIL("std::ofstream write failed");
        }
    }
    
    /* Read */
    {
        std::ifstream in(filename, std::ios::binary);
        if (!in) {
            remove(filename);
            TEST_FAIL("std::ifstream open failed");
        }
        
        std::string content((std::istreambuf_iterator<char>(in)),
                             std::istreambuf_iterator<char>());
        if (content != expected) {
            remove(filename);
            TEST_FAIL("std::ifstream read mismatch");
        }
    }
    
    remove(filename);
    TEST_PASS("std::fstream operations");
    return 0;
}

/* ============================================================================
 * Test 8: std::thread with pthreads-w32
 * ============================================================================ */
void thread_worker(int id) {
    std::lock_guard<std::mutex> lock(g_mutex);
    g_thread_counter++;
}

int test_thread(void) {
    const int num_threads = 4;
    std::thread threads[num_threads];
    
    g_thread_counter = 0;
    
    for (int i = 0; i < num_threads; i++) {
        threads[i] = std::thread(thread_worker, i);
    }
    
    for (int i = 0; i < num_threads; i++) {
        threads[i].join();
    }
    
    if (g_thread_counter != num_threads) {
        TEST_FAIL("std::thread counter mismatch");
    }
    
    TEST_PASS("std::thread operations");
    return 0;
}

/* ============================================================================
 * Main
 * ============================================================================ */
int main(void) {
    int failures = 0;
    
    std::cout << "=== C++ STL Compatibility Smoke Test ===" << std::endl << std::endl;
    
    failures += test_string();
    failures += test_vector();
    failures += test_map();
    failures += test_list();
    failures += test_deque();
    failures += test_set();
    failures += test_fstream();
    failures += test_thread();
    
    std::cout << std::endl << "=== Results: " << failures << " failure(s) ===" << std::endl;
    return failures;
}
