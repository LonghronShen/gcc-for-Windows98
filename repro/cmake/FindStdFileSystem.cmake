# SPDX-License-Identifier: GPL-3.0-or-later SPDX-FileCopyrightText: 2018 Rolf
# Eike Beer <eike@sf-mail.de>.

# find out if std::filesystem can be used

include(CMakePushCheckState)

set(FS_TESTCODE "
  #if defined(CXX17_FILESYSTEM) || defined (CXX17_FILESYSTEM_LIBFS)
  #include <filesystem>
  #elif defined(CXX11_EXP_FILESYSTEM) || defined (CXX11_EXP_FILESYSTEM_LIBFS)
  #include <experimental/filesystem>
  namespace std {
    namespace filesystem {
      using experimental::filesystem::is_regular_file;
    }
  }
  #endif

  #ifdef __APPLE__
  #include <Availability.h> // for deployment target to support pre-catalina targets without std::fs 
  #endif
  #if ((defined(_MSVC_LANG) && _MSVC_LANG >= 201703L) || (defined(__cplusplus) && __cplusplus >= 201703L)) && defined(__has_include)
  #if __has_include(<filesystem>) && (!defined(__MAC_OS_X_VERSION_MIN_REQUIRED) || __MAC_OS_X_VERSION_MIN_REQUIRED >= 101500)
  #define GHC_USE_STD_FS
  namespace fs = std::filesystem;
  #endif
  #endif
  #ifndef GHC_USE_STD_FS
  #include <ghc/filesystem.hpp>
  namespace fs = ghc::filesystem;
  #endif

  int main(void) {
    return fs::is_regular_file(\"/\") ? 0 : 1;
  }
")

if(CMAKE_CXX_STANDARD LESS 17)
  set(OLD_STANDARD "${CMAKE_CXX_STANDARD}")
  set(CMAKE_CXX_STANDARD 17)
endif()

cmake_push_check_state(RESET)
check_cxx_source_compiles("${FS_TESTCODE}" CXX17_FILESYSTEM)
if(NOT CXX17_FILESYSTEM)
  set(CMAKE_REQUIRED_LIBRARIES stdc++fs)
  check_cxx_source_compiles("${FS_TESTCODE}" CXX17_FILESYSTEM_LIBFS)
  cmake_reset_check_state()
endif()

if(OLD_STANDARD)
  if(NOT CXX17_FILESYSTEM AND NOT CXX17_FILESYSTEM_LIBFS)
    set(CMAKE_CXX_STANDARD ${OLD_STANDARD})
  endif()
  unset(OLD_STANDARD)
endif()

if(NOT CXX17_FILESYSTEM AND NOT CXX17_FILESYSTEM_LIBFS)
  check_cxx_source_compiles("${FS_TESTCODE}" CXX11_EXP_FILESYSTEM)
  if(NOT CXX11_EXP_FILESYSTEM)
    set(CMAKE_REQUIRED_LIBRARIES stdc++fs)
    check_cxx_source_compiles("${FS_TESTCODE}" CXX11_EXP_FILESYSTEM_LIBFS)
  endif()

  include(FetchContent)

  # ghc_filesystem
  FetchContent_Declare(ghc_filesystem
    GIT_REPOSITORY https://github.com/gulrak/filesystem.git
    GIT_TAG master)

  FetchContent_GetProperties(ghc_filesystem)
  if(NOT ghc_filesystem_POPULATED)
    FetchContent_Populate(ghc_filesystem)
    include_directories(${ghc_filesystem_SOURCE_DIR}/include)
  endif()

  configure_file("${CMAKE_CURRENT_SOURCE_DIR}/cmake/filesystem.hxx.in"
                 "${CMAKE_BINARY_DIR}/filesystem" @ONLY)
endif()
cmake_pop_check_state()

if(CXX17_FILESYSTEM_LIBFS OR CXX11_EXP_FILESYSTEM_LIBFS)
  set(CXX_FILESYSTEM_LIBS stdc++fs)
endif()

unset(FS_TESTCODE)
