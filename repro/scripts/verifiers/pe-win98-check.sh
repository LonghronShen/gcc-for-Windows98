#!/usr/bin/env bash
# ============================================================================
# pe-win98-check.sh — Shared Win98 PE compatibility checker
# ============================================================================
# Can be SOURCED by other scripts or CALLED directly as a CLI tool.
#
# When sourced, provides:
#   pe_check_win98 <exe>
#     Inspects the PE binary at <exe> using objdump.
#     Returns:
#       0  — Win98 compatible (no forbidden imports, MajorOSVersion ≤ 4)
#       1  — incompatible (sets PE_CHECK_FAIL_REASON)
#       2  — not a PE / objdump failed (skip)
#     Sets these variables on every call:
#       PE_CHECK_RESULT      "pass" | "fail" | "skip"
#       PE_CHECK_FAIL_REASON  human-readable failure description (non-empty on fail)
#       PE_CHECK_BAD_IMPORT   the offending DLL name (non-empty if import failure)
#       PE_CHECK_OS_MAJOR     MajorOSVersion integer (empty if not found)
#       PE_CHECK_OS_MINOR     MinorOSVersion integer (empty if not found)
#
#   PE_FORBIDDEN_IMPORT_PATTERNS
#     Array of lower-case substring patterns that must not appear in DLL imports.
#
# When called directly:
#   pe-win98-check.sh <exe> [<exe2> ...]
#   Exit 0 if all pass; 1 if any fail.
# ============================================================================

# DLL name substrings (lower-cased) that must not appear in PE import tables.
PE_FORBIDDEN_IMPORT_PATTERNS=(
    "api-ms-win-"
    "ucrtbase.dll"
    "vcruntime"
)

# pe_check_win98 <exe>
# See header for return values and variable side-effects.
pe_check_win98() {
    local exe="$1"

    # Reset output variables.
    PE_CHECK_RESULT=""
    PE_CHECK_FAIL_REASON=""
    PE_CHECK_BAD_IMPORT=""
    PE_CHECK_OS_MAJOR=""
    PE_CHECK_OS_MINOR=""

    # Try to read the PE header with objdump.
    local dump
    if ! dump=$(objdump -p "$exe" 2>/dev/null); then
        PE_CHECK_RESULT="skip"
        return 2
    fi

    local fail=0

    # ── Import table check ───────────────────────────────────────────────────
    while IFS= read -r dll_name; do
        local dll_lc="${dll_name,,}"
        for pat in "${PE_FORBIDDEN_IMPORT_PATTERNS[@]}"; do
            if [[ "$dll_lc" == *"$pat"* ]]; then
                PE_CHECK_BAD_IMPORT="$dll_name"
                PE_CHECK_FAIL_REASON="forbidden import: $dll_name"
                fail=1
                break 2
            fi
        done
    done < <(printf '%s\n' "$dump" | awk '/DLL Name:/ {print $3}')

    # ── PE OS version check ──────────────────────────────────────────────────
    PE_CHECK_OS_MAJOR=$(printf '%s\n' "$dump" | awk '/MajorOSVersion/ {print $2; exit}')
    PE_CHECK_OS_MINOR=$(printf '%s\n' "$dump" | awk '/MinorOSVersion/ {print $2; exit}')

    if [[ -n "$PE_CHECK_OS_MAJOR" && "$PE_CHECK_OS_MAJOR" -gt 4 ]]; then
        local prev_reason="$PE_CHECK_FAIL_REASON"
        PE_CHECK_FAIL_REASON="MajorOSVersion=$PE_CHECK_OS_MAJOR (must be ≤ 4 for Win98)"
        [[ -n "$prev_reason" ]] && PE_CHECK_FAIL_REASON="$prev_reason; $PE_CHECK_FAIL_REASON"
        fail=1
    fi

    if [[ "$fail" -eq 0 ]]; then
        PE_CHECK_RESULT="pass"
        return 0
    else
        PE_CHECK_RESULT="fail"
        return 1
    fi
}

# ── Direct CLI usage ─────────────────────────────────────────────────────────
# Only run main logic when this script is executed directly, not sourced.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    if [[ $# -eq 0 ]]; then
        echo "Usage: $(basename "$0") <exe> [<exe2> ...]" >&2
        exit 1
    fi

    overall=0
    for exe in "$@"; do
        pe_check_win98 "$exe"
        rc=$?
        case "$rc" in
            0)
                ver=""
                [[ -n "$PE_CHECK_OS_MAJOR" ]] && ver="  OS=$PE_CHECK_OS_MAJOR.${PE_CHECK_OS_MINOR:-0}"
                echo "[PASS] $exe$ver"
                ;;
            1)
                echo "[FAIL] $exe — $PE_CHECK_FAIL_REASON"
                overall=1
                ;;
            2)
                echo "[SKIP] $exe (not a PE or objdump failed)"
                ;;
        esac
    done
    exit "$overall"
fi
