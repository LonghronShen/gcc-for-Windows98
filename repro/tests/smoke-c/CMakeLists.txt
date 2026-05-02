cmake_minimum_required(VERSION 3.16)
project(win98_smoke_c LANGUAGES C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

file(GLOB_RECURSE c_src
  ${CMAKE_CURRENT_LIST_DIR}/*.c
)

foreach(src IN LISTS c_src)
  get_filename_component(target ${src} NAME_WE)

  add_executable(${target} ${src})
  set_win98_output(${target})
  target_link_libraries(${target} PRIVATE ${MATH_LIB})
  target_link_libraries(${target} PRIVATE Threads::Threads)
  target_link_libraries(${target} PRIVATE ws2_32)

  add_executable(${target}-static ${src})
  set_target_properties(${target}-static PROPERTIES OUTPUT_NAME "${target}_static")
  set_win98_output(${target}-static)
  target_link_options(${target}-static PRIVATE -static)
  target_link_libraries(${target}-static PRIVATE ${MATH_LIB})
  target_link_libraries(${target}-static PRIVATE Threads::Threads)
  target_link_libraries(${target}-static PRIVATE ws2_32)
endforeach()
