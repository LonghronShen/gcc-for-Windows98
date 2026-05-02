/*
 * fstream_comprehensive_test.cpp
 * Comprehensive std::fstream test covering:
 *   - Binary read/write
 *   - Text mode
 *   - Append mode
 *   - tellg / tellp / seekg / seekp
 *   - Large (>4KB) writes
 *   - Error state handling
 *   - Multiple concurrent streams
 */
#include <fstream>
#include <iostream>
#include <string>
#include <vector>
#include <cstring>
#include <cstdlib>

static int failures = 0;

#define CHECK(cond, msg) do {                    \
    if (!(cond)) {                                \
        std::cerr << "FAIL: " << msg << std::endl; \
        failures++;                                \
    } else {                                       \
        std::cout << "  PASS: " << msg << std::endl; \
    }                                              \
} while(0)

// ---------------------------------------------------------------------------
// 1. Binary round-trip (struct)
// ---------------------------------------------------------------------------
struct Record {
    uint32_t id;
    double   value;
    char     tag[16];
};

void test_binary_struct() {
    std::cout << "[binary struct round-trip]" << std::endl;
    const char* path = "fstream_binary.dat";

    Record wr = {42, 3.14159, "pi"};
    {
        std::ofstream os(path, std::ios::binary);
        CHECK(os.is_open(), "open for binary write");
        os.write(reinterpret_cast<const char*>(&wr), sizeof(wr));
        CHECK(os.good(), "binary write ok");
    }

    Record rd;
    std::memset(&rd, 0, sizeof(rd));
    {
        std::ifstream is(path, std::ios::binary);
        CHECK(is.is_open(), "open for binary read");
        is.read(reinterpret_cast<char*>(&rd), sizeof(rd));
        CHECK(is.good(), "binary read ok");
    }

    CHECK(rd.id == 42,           "struct id=42");
    CHECK(rd.value == 3.14159,    "struct value=3.14159");
    CHECK(std::strcmp(rd.tag, "pi") == 0, "struct tag=pi");
    std::remove(path);
}

// ---------------------------------------------------------------------------
// 2. Large write (>4KB)
// ---------------------------------------------------------------------------
void test_large_write() {
    std::cout << "[large write >4KB]" << std::endl;
    const char* path = "fstream_large.txt";

    std::vector<char> data(8192, 'A');
    data[4095] = 'X';
    data.back() = '\n';

    {
        std::ofstream os(path, std::ios::binary);
        os.write(data.data(), data.size());
        CHECK(os.good(), "write 8192 bytes");
    }

    std::vector<char> back(data.size(), 0);
    {
        std::ifstream is(path, std::ios::binary);
        is.read(back.data(), back.size());
        CHECK(is.good(), "read 8192 bytes");
        CHECK(is.gcount() == 8192, "read exactly 8192 bytes");
    }

    CHECK(back[4095] == 'X', "content integrity at offset 4095");
    CHECK(back == data,      "full content match");
    std::remove(path);
}

// ---------------------------------------------------------------------------
// 3. Seek / tell
// ---------------------------------------------------------------------------
void test_seek_tell() {
    std::cout << "[seek / tell]" << std::endl;
    const char* path = "fstream_seek.txt";

    {
        std::ofstream os(path, std::ios::binary);
        os << "HelloWorld";
        CHECK(os.tellp() == 10, "tellp after write");
        os.seekp(5);
        os << "-";
        CHECK(os.good(), "seekp + overwrite");
    }

    {
        std::ifstream is(path, std::ios::binary);
        char buf[11] = {};
        is.read(buf, 10);
        CHECK(is.good(), "read after seek");
        CHECK(buf[5] == '-', "overwritten char at pos 5");
        // seek and re-read
        is.clear();
        is.seekg(0);
        CHECK(is.tellg() == 0, "tellg at start");
        is.seekg(5);
        CHECK(is.tellg() == 5, "tellg after seekg(5)");
        is.read(buf, 1);
        CHECK(buf[0] == '-', "seekg read at pos 5");
    }
    std::remove(path);
}

// ---------------------------------------------------------------------------
// 4. Append mode
// ---------------------------------------------------------------------------
void test_append() {
    std::cout << "[append mode]" << std::endl;
    const char* path = "fstream_append.txt";

    {
        std::ofstream os(path, std::ios::binary);
        os << "line1\n";
    }
    {
        std::ofstream os(path, std::ios::binary | std::ios::app);
        os << "line2\n";
    }

    {
        std::ifstream is(path);
        std::string l1, l2;
        std::getline(is, l1);
        std::getline(is, l2);
        CHECK(l1 == "line1", "first line preserved");
        CHECK(l2 == "line2", "second line appended");
    }
    std::remove(path);
}

// ---------------------------------------------------------------------------
// 5. Error state handling
// ---------------------------------------------------------------------------
void test_error_states() {
    std::cout << "[error state handling]" << std::endl;

    // Read from non-existent file
    {
        std::ifstream is("_nonexistent_file_xyz_.dat");
        CHECK(!is.good(), "fail on non-existent file");
        CHECK(is.fail(),  "failbit set");
    }

    // Write to a directory path (should fail)
    {
        std::ofstream os("/", std::ios::binary);
        CHECK(!os.is_open(), "cannot open directory as file");
    }
}

// ---------------------------------------------------------------------------
// 6. Multiple concurrent streams
// ---------------------------------------------------------------------------
void test_concurrent_streams() {
    std::cout << "[concurrent streams]" << std::endl;
    const char* path_a = "fstream_con_a.txt";
    const char* path_b = "fstream_con_b.txt";

    {
        std::ofstream a(path_a);
        std::ofstream b(path_b);
        a << "AAA";
        b << "BBB";
        CHECK(a.good(), "stream A write ok");
        CHECK(b.good(), "stream B write ok");
    }

    {
        std::ifstream a(path_a);
        std::ifstream b(path_b);
        std::string sa, sb;
        a >> sa;
        b >> sb;
        CHECK(sa == "AAA", "stream A content");
        CHECK(sb == "BBB", "stream B content");
    }
    std::remove(path_a);
    std::remove(path_b);
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------
int main() {
    std::cout << "=== fstream comprehensive test ===" << std::endl;

    test_binary_struct();
    test_large_write();
    test_seek_tell();
    test_append();
    test_error_states();
    test_concurrent_streams();

    std::cout << "=== done; failures=" << failures << " ===" << std::endl;
    return failures > 0 ? 1 : 0;
}
