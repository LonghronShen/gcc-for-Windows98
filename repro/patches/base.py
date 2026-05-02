import difflib
import fnmatch
import subprocess
from pathlib import Path


class PatchSet:
    """Versioned patch set with file lookup, generation, and validation helpers."""

    # Optional glob patterns for supported versions, e.g. ("11.*", "12.0.*").
    supported_version_patterns: tuple[str, ...] = ()

    def __init__(self, name: str, version: str, source_dir: Path, patches_dir: Path):
        self.name = name
        self.version = version
        self.source_dir = Path(source_dir)
        self.patches_dir = Path(patches_dir)
        self.patches: list[Path] = []

    def find_file(self, pattern: str) -> Path | None:
        """Find a file under source_dir that matches a relative path suffix."""
        candidates = list(self.source_dir.rglob(pattern))
        if not candidates:
            return None
        for candidate in candidates:
            if str(candidate.relative_to(self.source_dir)).endswith(pattern):
                return candidate
        return candidates[0]

    def make_unified_diff(self, filename: str, old_lines: list[str], new_lines: list[str]) -> str:
        """Generate unified diff output for one file."""
        old_text = "".join(old_lines)
        new_text = "".join(new_lines)
        if old_text == new_text:
            return f"# No changes for {filename}\n"
        diff = difflib.unified_diff(
            old_lines,
            new_lines,
            fromfile=f"a/{filename}",
            tofile=f"b/{filename}",
        )
        return "".join(diff)

    def detect_applicability(self) -> bool:
        """Return whether this patch set can run on the source tree."""
        return self.source_dir.exists()

    def is_supported_version(self) -> bool:
        """Return whether current version is supported by this patch set."""
        if not self.supported_version_patterns:
            return True
        return any(fnmatch.fnmatch(self.version, pattern) for pattern in self.supported_version_patterns)

    def require_supported_version(self) -> None:
        """Raise if current version is unsupported."""
        if self.is_supported_version():
            return
        patterns = ", ".join(self.supported_version_patterns)
        raise ValueError(
            f"Unsupported {self.name} version '{self.version}'. Supported patterns: {patterns}"
        )

    def generate(self) -> list[Path]:
        """Generate patch files and return their paths."""
        raise NotImplementedError

    def validate(self) -> bool:
        """Validate generated patches against the source tree with git apply --check."""
        for patch_file in self.patches:
            result = subprocess.run(
                ["git", "apply", "--check", str(patch_file)],
                cwd=self.source_dir,
                capture_output=True,
                text=True,
            )
            if result.returncode != 0:
                print(f"VALIDATION FAILED: {patch_file}")
                print(result.stderr)
                return False
        return True

    def write_series(self, entries: list[str]) -> None:
        """Write a series.txt manifest for generated patches."""
        series_path = self.patches_dir / "series.txt"
        series_path.write_text("\n".join(entries) + "\n")
        print(f"  -> {series_path}")
