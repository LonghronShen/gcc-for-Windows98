# GCC patch notes

## Current GCC 11.1.0 revalidation result

Confirmed patch targets:
1. Disable `_GLIBCXX_THREAD_ATEXIT_WIN32`
2. Remove XP+ DLL lifetime handling from `atexit_thread.cc`
3. Disable LFS / aligned allocation capability exposure for this repro branch
4. Force `quick_exit` / `at_quick_exit` detection off for the MSVCRT target surface

For GCC 11.1.0, the formal patch set currently consists of the four `0001`-`0004` patches listed in `patches/gcc/11.1.0/series.txt`.

---

## Patch backlog and engineering notes (as of 2026-04-14)

### Group A — thread atexit / XP+ API avoidance

#### A1. Disable `_GLIBCXX_THREAD_ATEXIT_WIN32`
Files:
- `libstdc++-v3/config/os/mingw32-w64/os_defines.h`
- `libstdc++-v3/config/os/newlib/os_defines.h`
Current scripted change:
- replace `#define _GLIBCXX_THREAD_ATEXIT_WIN32 1`
- with a Win98 repro comment disabling it
Patchability: **High** (direct line edit, should be a normal patch)

#### A2. Remove XP+ DLL lifetime handling from `atexit_thread.cc`
File:
- `libstdc++-v3/libsupc++/atexit_thread.cc`
Current scripted change:
- remove `windows.h` include block
- remove `HMODULE dll;`
- remove the `FreeLibrary` cleanup block
- remove the `GetModuleHandleExW` acquisition block
Patchability: **High** (stable semantic change, should be a proper patch)

---

### Group B — legacy runtime capability trimming

#### B1. Disable LFS / aligned allocation feature macros in `config.h.in`
File:
- `libstdc++-v3/config.h.in`
Current scripted changes:
- comment out:
	- `_GLIBCXX_USE_LFS`
	- `_GLIBCXX_HAVE_ALIGNED_ALLOC`
	- `_GLIBCXX_HAVE__ALIGNED_MALLOC`
Patchability: **High** (straightforward textual patch)

---

### Group C — quick-exit feature detection correction for MSVCRT

#### C1. Force `quick_exit` / `at_quick_exit` detection off
Files:
- `libstdc++-v3/config.h.in`
- `libstdc++-v3/crossconfig.m4`
- `libstdc++-v3/acinclude.m4`
- `libstdc++-v3/configure`
Current scripted changes:
- replace `HAVE_AT_QUICK_EXIT` / `HAVE_QUICK_EXIT` definitions with disabled comments
- replace `glibcxx_cv_func_*_use=yes` with `no`
- replace `ac_cv_func_* = yes` with `no`
Reason:
- after switching mingw-w64 to `msvcrt`, libstdc++ configure misdetected these APIs as available
- resulting `c++config.h` did not match the real target header surface
- GCC final failed in PCH generation for `bits/stdc++.h`
Patchability: **Medium**
- `config.h.in`, `crossconfig.m4`, and `acinclude.m4` are good patch targets.
- `configure` should ideally be regenerated, or patched only as a transitional measure.
Preferred long-term approach:
1. patch the authoritative m4/input files
2. regenerate `configure` in a reproducible way if needed
3. only patch `configure` directly if regeneration is intentionally avoided in this repro branch

---

### Group D — filesystem compatibility edits

#### D1. Comment one `__int128`-related line in fs_path headers
Files:
- `libstdc++-v3/include/experimental/bits/fs_path.h`
- `libstdc++-v3/include/bits/fs_path.h`
Current scripted behavior:
- comment the first matching non-comment line containing `__int128`
Revalidation result against the real GCC 11.1.0 tree:
- current `libstdc++-v3/include/experimental/bits/fs_path.h` contains no `__int128` match
- current `libstdc++-v3/include/bits/fs_path.h` contains no `__int128` match
- build logs show `fs_path.cc` / `cow-fs_path.cc` compiled in the successful GCC-final build, so there is no current direct evidence that an `fs_path` header edit is still required
Patchability: **Low / currently unproven**
- Current matching rule is heuristic and brittle.
- Before patchifying, identify the exact intended line(s) and the exact rationale.
Needed before conversion:
- capture the precise line(s) modified in the historically working source tree, if any
- explain why that line is disabled and what failure it prevents
- if no such line can be reproduced on GCC 11.1.0, drop D1 from the active patch target list

#### D2. Replace `mkdir(path, mode)` style usage with `mkdir(path)`
Files:
- `libstdc++-v3/src/c++17/fs_ops.cc`
- `libstdc++-v3/src/filesystem/ops.cc`
- related compatibility wrapper: `libstdc++-v3/src/filesystem/ops-common.h`
Original scripted assumption:
- replace specific `mkdir(..., perms::all)` call sites with one-argument `mkdir(...)`
Revalidation result against the real GCC 11.1.0 tree:
- the exact call sites assumed by the old script do **not** exist in this tree
- current code routes through `create_dir(...)` and then calls `posix::mkdir(p.c_str(), mode)`
- for Windows targets, `libstdc++-v3/src/filesystem/ops-common.h` already defines a compatibility wrapper:
	- `inline int mkdir(const wchar_t* path, mode_t) { return ::_wmkdir(path); }`
- build evidence also points the same way:
	- `logs/build-gcc-stage1.log`: `checking if mkdir takes one argument... no`
	- `logs/build-gcc.log`: `checking if mkdir takes one argument... no`
- so the two-argument call form is already intentionally adapted for Windows in the current tree and is not, by itself, evidence of a live incompatibility
Patchability: **Low / currently not justified**
- for GCC 11.1.0 this should not be converted into a patch unless a fresh, reproducible failure is captured against the real wrapper-based implementation
Current conclusion:
- treat old D2 as a stale script-era assumption, not a confirmed live patch target
- do not count `0005-adjust-filesystem-mkdir-signature.patch` as completed until new failure evidence proves a real patch is needed
