cmake_minimum_required(VERSION 3.16)
project(win98_smoke_cpp LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

file(GLOB_RECURSE cpp_src
  ${CMAKE_CURRENT_LIST_DIR}/*.cpp
)

foreach(src IN LISTS cpp_src)
  get_filename_component(target ${src} NAME_WE)

  add_executable(${target} ${src})
  set_win98_output(${target})
  target_link_libraries(${target} PRIVATE Threads::Threads)

  add_executable(${target}-static ${src})
  set_target_properties(${target}-static PROPERTIES OUTPUT_NAME "${target}_static")
  set_win98_output(${target}-static)
  target_link_options(${target}-static PRIVATE -static-libgcc -static-libstdc++)
  target_link_libraries(${target}-static PRIVATE Threads::Threads)
endforeach()
