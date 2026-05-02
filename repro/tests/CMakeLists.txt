cmake_minimum_required(VERSION 3.16)
project(win98_smoke_tests LANGUAGES C CXX)

find_package(Threads REQUIRED)
find_library(MATH_LIB m)

function(set_win98_output target)
  set_target_properties(${target} PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/out"
  )
endfunction()

add_subdirectory(smoke-c)
add_subdirectory(smoke-cpp)
