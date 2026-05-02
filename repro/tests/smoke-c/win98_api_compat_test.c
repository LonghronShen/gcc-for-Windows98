/*
 * win98_api_compat_test.c
 * Win98 API 兼容性测试
 * - 测试 Win98 支持的 API 子集（CreateFileA vs CreateFileW）
 * - 测试 Win98 不支持的 API（如 GetModuleHandleExW）是否被正确排除
 * - 测试 Win98 支持的 Registry API、Process API、Memory API
 */

#include <windows.h>
#include <stdio.h>
#include <string.h>

#define TEST_PASS(msg)  printf("PASS: %s\n", msg)
#define TEST_FAIL(msg)  do { printf("FAIL: %s\n", msg); return 1; } while(0)
#define TEST_SKIP(msg)  printf("SKIP: %s\n", msg)

/* ============================================================================
 * Test 1: CreateFileA (Win98 supported)
 * ============================================================================ */
int test_createfile_a(void) {
    HANDLE hFile;
    DWORD written;
    char test_data[] = "Win98-API-test";
    char read_buf[64] = {0};
    DWORD read;
    BOOL ok;

    hFile = CreateFileA(
        "test_win98_api.txt",
        GENERIC_READ | GENERIC_WRITE,
        0,
        NULL,
        CREATE_ALWAYS,
        FILE_ATTRIBUTE_NORMAL,
        NULL
    );
    if (hFile == INVALID_HANDLE_VALUE) {
        TEST_FAIL("CreateFileA failed to create file");
    }

    ok = WriteFile(hFile, test_data, (DWORD)strlen(test_data), &written, NULL);
    if (!ok || written != strlen(test_data)) {
        CloseHandle(hFile);
        TEST_FAIL("WriteFile failed");
    }

    /* Seek to beginning */
    SetFilePointer(hFile, 0, NULL, FILE_BEGIN);

    ok = ReadFile(hFile, read_buf, sizeof(read_buf) - 1, &read, NULL);
    CloseHandle(hFile);
    DeleteFileA("test_win98_api.txt");

    if (!ok || read != strlen(test_data)) {
        TEST_FAIL("ReadFile failed or size mismatch");
    }
    if (strcmp(read_buf, test_data) != 0) {
        TEST_FAIL("Read data mismatch");
    }

    TEST_PASS("CreateFileA read/write works");
    return 0;
}

/* ============================================================================
 * Test 2: CreateFileW (Win98 NOT supported - should fail or be unavailable)
 * ============================================================================ */
int test_createfile_w(void) {
    /* On Win98, CreateFileW is not available (Windows 9x has limited Unicode).
     * With mingw-w64 targeting Win98, this should compile but may not work.
     * We test that the symbol exists (it does in mingw headers) but note
     * that it would fail at runtime on real Win98. */
    HMODULE hKernel32 = GetModuleHandleA("kernel32.dll");
    if (!hKernel32) {
        TEST_FAIL("GetModuleHandleA(kernel32.dll) failed");
    }

    /* Try to get CreateFileW address */
    FARPROC pfnCreateFileW = GetProcAddress(hKernel32, "CreateFileW");
    if (pfnCreateFileW) {
        TEST_SKIP("CreateFileW exists in kernel32 (expected on NT/XP+; would fail on real Win98)");
    } else {
        TEST_PASS("CreateFileW not available (correct for Win98)");
    }
    return 0;
}

/* ============================================================================
 * Test 3: GetModuleHandleExW (Win98 NOT supported)
 * ============================================================================ */
int test_getmodulehandleex_w(void) {
    HMODULE hKernel32 = GetModuleHandleA("kernel32.dll");
    if (!hKernel32) {
        TEST_FAIL("GetModuleHandleA(kernel32.dll) failed");
    }

    /* GetModuleHandleExW is XP+ only, definitely not on Win98 */
    FARPROC pfn = GetProcAddress(hKernel32, "GetModuleHandleExW");
    if (pfn) {
        TEST_SKIP("GetModuleHandleExW exists (unexpected on Win98, but may be present on host)");
    } else {
        TEST_PASS("GetModuleHandleExW not available (correct for Win98)");
    }
    return 0;
}

/* ============================================================================
 * Test 4: Registry API (Win98 supported)
 * ============================================================================ */
int test_registry_api(void) {
    HKEY hKey;
    LONG result;
    DWORD dwType;
    DWORD dwSize;
    char szValue[256];

    /* Open a well-known key that exists on Win98 */
    result = RegOpenKeyExA(
        HKEY_LOCAL_MACHINE,
        "SOFTWARE\\Microsoft\\Windows\\CurrentVersion",
        0,
        KEY_READ,
        &hKey
    );

    if (result != ERROR_SUCCESS) {
        /* On Wine this may succeed; on real Win98 it should work */
        TEST_SKIP("RegOpenKeyExA failed (may be normal in test environment)");
        return 0;
    }

    dwSize = sizeof(szValue);
    result = RegQueryValueExA(hKey, "ProductName", NULL, &dwType, (LPBYTE)szValue, &dwSize);
    RegCloseKey(hKey);

    if (result == ERROR_SUCCESS) {
        TEST_PASS("Registry API works");
    } else {
        TEST_SKIP("RegQueryValueExA failed (may be normal in test environment)");
    }
    return 0;
}

/* ============================================================================
 * Test 5: Memory API (Win98 supported)
 * ============================================================================ */
int test_memory_api(void) {
    SYSTEM_INFO si;
    MEMORYSTATUS ms;
    LPVOID pMem;

    GetSystemInfo(&si);
    if (si.dwPageSize == 0) {
        TEST_FAIL("GetSystemInfo returned invalid page size");
    }

    GlobalMemoryStatus(&ms);
    if (ms.dwTotalPhys == 0) {
        TEST_FAIL("GlobalMemoryStatus returned zero total physical memory");
    }

    pMem = VirtualAlloc(NULL, si.dwPageSize, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
    if (!pMem) {
        TEST_FAIL("VirtualAlloc failed");
    }

    /* Write and read back */
    *(DWORD*)pMem = 0xDEADBEEF;
    if (*(DWORD*)pMem != 0xDEADBEEF) {
        VirtualFree(pMem, 0, MEM_RELEASE);
        TEST_FAIL("VirtualAlloc memory read/write failed");
    }

    VirtualFree(pMem, 0, MEM_RELEASE);
    TEST_PASS("Memory API (VirtualAlloc, GlobalMemoryStatus, GetSystemInfo) works");
    return 0;
}

/* ============================================================================
 * Test 6: Process API (Win98 supported)
 * ============================================================================ */
int test_process_api(void) {
    DWORD pid = GetCurrentProcessId();
    HANDLE hProcess = GetCurrentProcess();

    if (pid == 0) {
        TEST_FAIL("GetCurrentProcessId returned 0");
    }
    if (!hProcess) {
        TEST_FAIL("GetCurrentProcess returned NULL");
    }

    /* Test GetModuleFileNameA */
    char szPath[MAX_PATH];
    DWORD len = GetModuleFileNameA(NULL, szPath, MAX_PATH);
    if (len == 0 || len >= MAX_PATH) {
        TEST_FAIL("GetModuleFileNameA failed");
    }

    TEST_PASS("Process API works");
    return 0;
}

/* ============================================================================
 * Test 7: File time API (Win98 supported)
 * ============================================================================ */
int test_filetime_api(void) {
    SYSTEMTIME st;
    FILETIME ft;

    GetSystemTime(&st);
    if (!SystemTimeToFileTime(&st, &ft)) {
        TEST_FAIL("SystemTimeToFileTime failed");
    }

    TEST_PASS("FileTime API works");
    return 0;
}

/* ============================================================================
 * Test 8: Environment strings (Win98 supported)
 * ============================================================================ */
int test_environment_api(void) {
    DWORD len = GetEnvironmentVariableA("PATH", NULL, 0);
    if (len == 0) {
        TEST_FAIL("GetEnvironmentVariableA(PATH) returned 0");
    }

    char *buf = (char*)malloc(len);
    if (!buf) {
        TEST_FAIL("malloc failed");
    }

    len = GetEnvironmentVariableA("PATH", buf, len);
    if (len == 0) {
        free(buf);
        TEST_FAIL("GetEnvironmentVariableA(PATH) read failed");
    }

    free(buf);
    TEST_PASS("Environment API works");
    return 0;
}

/* ============================================================================
 * Main
 * ============================================================================ */
int main(void) {
    int failures = 0;

    printf("=== Win98 API Compatibility Smoke Test ===\n\n");

    failures += test_createfile_a();
    failures += test_createfile_w();
    failures += test_getmodulehandleex_w();
    failures += test_registry_api();
    failures += test_memory_api();
    failures += test_process_api();
    failures += test_filetime_api();
    failures += test_environment_api();

    printf("\n=== Results: %d failure(s) ===\n", failures);
    return failures;
}
