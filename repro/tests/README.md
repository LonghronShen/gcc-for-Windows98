# Smoke Tests — gcc-for-Windows98

CMake-based smoke test suite verifying the gcc-for-Windows98 cross and native toolchains.

Tests run inside the `consumer` Docker container, which has both toolchains installed and Wine configured for executing Windows binaries.

## Test Suite Layout

```
tests/
├── CMakeLists.txt           # Top-level CMake project
├── smoke-c/                 # C smoke tests
│   ├── CMakeLists.txt
│   ├── hello_world.c
│   ├── hello_pthread.c
│   ├── thread_test.c
│   ├── exception_test.c
│   ├── file_io_test.c
│   ├── floating_point_test.c
│   ├── math_test.c
│   ├── link_compare_test.c
│   ├── ucrt_leak_test.c
│   ├── win98_api_compat_test.c
│   └── winsock_test.c
└── smoke-cpp/               # C++ smoke tests
    ├── CMakeLists.txt
    ├── hello.cpp
    ├── hello_cpp.cpp
    ├── hello_exception.cpp
    ├── hello_fstream.cpp
    ├── hello_iostream.cpp
    ├── hello_thread.cpp
    ├── cpp_exception_test.cpp
    ├── cpp_exception_cross_test.cpp
    ├── cpp_stl_compat_test.cpp
    └── fstream_comprehensive_test.cpp
```

## What the Tests Verify

All tests are validated across three dimensions:

1. **Compilation** — Each test must compile and link successfully with both the cross toolchain and the native toolchain (via CMake + Ninja).
2. **PE compatibility** — Every built `.exe` must pass the Win98 PE compatibility check: no forbidden import patterns (UCRT, api-ms-win, vcruntime), and `MajorOSVersion ≤ 4` in the PE optional header.
3. **Execution** — Every built `.exe` must run successfully under Wine (exit code 0).

## How Tests Are Run

Tests are not run manually. They are executed by `scripts/run-smoke-pipeline.sh`, which orchestrates three phases:

- **Phase 1** (`smoke-verify-layout.sh`): Verify toolchain directory layout and key binaries exist
- **Phase 2** (`smoke-check-native-pe.sh`): Win98 PE compatibility check on native toolchain binaries themselves
- **Phase 3a** (`smoke-cmake-build.sh cross N`): CMake+Ninja build with the cross toolchain, PE check, Wine run
- **Phase 3b** (`smoke-cmake-build.sh native N`): CMake+Ninja build with the native toolchain, PE check, Wine run

The consumer container is the required execution environment:

```bash
docker compose up -d consumer
./scripts/run-smoke-pipeline.sh --jobs 4
```
