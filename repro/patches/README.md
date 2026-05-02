# Win98 Compatibility Patch Set

This directory contains patch files for building a **Windows 98 compatible GCC toolchain**.

Patches are dynamically generated from modified source trees by `generate-patches.py` and applied
to the fetched sources before each build phase.

## Directory Structure

```
patches/
├── generate-patches.py    # Patch generation tool
├── base.py                # PatchSet base class
├── gcc/
│   ├── patch.py           # GCCPatchSet implementation
│   └── 11.1.0/
│       ├── series.txt
│       ├── 0001-disable-thread-atexit-win32.patch
│       ├── 0002-remove-atexit-thread-dll-handling.patch
│       ├── 0003-disable-lfs-and-aligned-alloc.patch
│       └── 0004-fix-msvcrt-quick-exit-detection.patch
├── mingw-w64/
│   ├── patch.py           # MinGW_W64PatchSet implementation
│   └── master/
│       ├── series.txt
│       └── 0001-ucrt-default-to-msvcrt.patch
└── pthread9x/
    ├── patch.py           # Pthread9xPatchSet implementation
    └── master/
        ├── series.txt
        └── 0001-fix-static-linking-dllimport.patch
```

## Patch Descriptions

### GCC Patches (11.1.0)

| Patch | Description |
|-------|-------------|
| `0001-disable-thread-atexit-win32.patch` | Disables `_GLIBCXX_THREAD_ATEXIT_WIN32` to avoid Win98-incompatible thread-local storage dependencies in `atexit` |
| `0002-remove-atexit-thread-dll-handling.patch` | Removes Windows DLL handle tracking (`HMODULE`, `FreeLibrary`, `GetModuleHandleExW`) from `atexit_thread.cc` |
| `0003-disable-lfs-and-aligned-alloc.patch` | Disables `_GLIBCXX_USE_LFS`, `_GLIBCXX_HAVE_ALIGNED_ALLOC`, and `_GLIBCXX_HAVE__ALIGNED_MALLOC` in `config.h.in` |
| `0004-fix-msvcrt-quick-exit-detection.patch` | Disables `at_quick_exit`/`quick_exit` detection and related cache probes in libstdc++ configure inputs |
| `0005-fix-windows-h-abort-macro-conflict.patch` | Wraps `#include <windows.h>` in 4 GCC source files with `#pragma push_macro("abort")` / `#pragma pop_macro("abort")` to prevent GCC's `abort()` macro (defined in `system.h` as `fancy_abort(...)`) from conflicting with COM virtual method declarations named `abort` in `msxml.h` (pulled in via `windows.h` → `urlmon.h`) |

### mingw-w64 Patches (master)

| Patch | Description |
|-------|-------------|
| `0001-ucrt-default-to-msvcrt.patch` | Changes the default CRT in `configure.ac` from `ucrt` to `msvcrt-os`, ensuring built libraries link to `msvcrt.dll` (Win98 compatible) |

### pthread9x Patches (master)

| Patch | Description |
|-------|-------------|
| `0001-fix-static-linking-dllimport.patch` | Fixes `dllimport` attributes that cause link errors with `-static` builds |

## Usage

### Generate Patches

```bash
# From repro/ directory (generates from current sources in src/)
python3 patches/generate-patches.py --gcc-version=11.1.0 --source-dir=src/gcc
python3 patches/generate-patches.py --mingw-w64-version=master --source-dir=src/mingw-w64
python3 patches/generate-patches.py --pthread9x-version=master --source-dir=src/pthread9x
```

Patch generation is also triggered automatically during the build when `--generate-patches` is passed to `build.sh` or `run-toolchain-build.sh`.

### Apply Patches

```bash
# Apply patches to a source tree (called automatically by build scripts)
scripts/apply-patches.sh gcc 11.1.0
scripts/apply-patches.sh mingw-w64 master
scripts/apply-patches.sh pthread9x master
```

Patches are applied in the order listed in each component's `series.txt`.

## Design Principles

- **Dynamic generation**: Patches are generated from current source code via `generate-patches.py`; regeneration is always possible after modifying sources.
- **Validated application**: `apply-patches.sh` validates each patch with `git apply --check` before applying; stops on the first failure.
- **Versioned output**: Patch directories are named by component version (e.g., `gcc/11.1.0/`) so multiple GCC versions can coexist.
- **Minimal surface**: Each patch is as small and targeted as possible — one concern per patch.

## Why These Patches Are Needed

**UCRT vs MSVCRT**: Windows 98 ships `msvcrt.dll` but not UCRT. mingw-w64 defaults to UCRT in recent versions; the patch reverts this to `msvcrt-os`.

**`_GLIBCXX_THREAD_ATEXIT_WIN32`**: GCC's thread-local `atexit` implementation calls `GetModuleHandleExW`, a Vista+ API. Disabling this macro avoids a hard dependency on Vista+.

**`at_quick_exit` / `quick_exit`**: C11 features absent from Win98's `msvcrt.dll`; disabling their configure-time detection prevents incorrect build-time activation.

**`_GLIBCXX_USE_LFS` / `aligned_alloc`**: Large-file-support and aligned-allocation APIs are not present in Win98's CRT; disabling them prevents linker failures.

**pthread9x static linking**: The upstream pthread9x library uses `__declspec(dllimport)` attributes that break static builds; the patch removes them.


# Generate and validate
python3 patches/generate-patches.py --gcc-version=11.1.0 --validate
```

### Apply Patches with One Command

```bash
# Apply all patches
scripts/apply-patches.sh all

# Apply specific component
scripts/apply-patches.sh gcc 11.1.0
scripts/apply-patches.sh mingw-w64 master
```

## Design Principles

- **Dynamic Generation**: All patches are dynamically generated from the current source code using `generate-patches.py`, supporting regeneration after source updates
- **Bidirectional Compatibility**: The patch generator can infer the original code from already patched sources, ensuring idempotency
- **Validation Mechanism**: Each patch is validated with `git apply --check`; the process stops on failure
- **series.txt**: Patches are applied in the order specified by `series.txt` to ensure correct dependency sequencing
- **Version Gating**: Patch generation enforces supported version patterns per component

### Supported Version Patterns

- `gcc`: `11.*`
- `mingw-w64`: `master`

## Technical Background

### Why Are These Patches Needed?

**UCRT vs MSVCRT**
- UCRT (Universal C Runtime) is the modern C runtime for Windows 10+
- MSVCRT is the legacy C runtime for Windows 98/XP/Vista/7/8
- Win98 does not support UCRT; the toolchain must fall back to MSVCRT

**_GLIBCXX_THREAD_ATEXIT_WIN32**
- GCC's thread-local storage `atexit` implementation depends on Windows Vista+ APIs (`GetModuleHandleExW`)
- Win98 does not support these APIs, so this must be disabled

**at_quick_exit / quick_exit**
- C11 features not supported by Win98's msvcrt.dll
- Detection must be explicitly disabled to avoid incorrect build-time activation
