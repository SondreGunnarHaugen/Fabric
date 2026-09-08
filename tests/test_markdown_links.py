"""
test_markdown_links.py

Checks that every local file link and image reference used across the
repo's Markdown docs actually points to a file that exists on disk.
External links (http/https/mailto/ftp) and same-page anchors (#section)
are skipped, since there's nothing on disk to check for those.

This script auto-detects the repo root by walking upward from its own
location until it finds a .git folder — it can be placed anywhere inside
the repo (root, tests/, scripts/, etc.) without any changes.

Run as a pytest test:
    pytest test_markdown_links.py -v

Run as a standalone script (no pytest required):
    python test_markdown_links.py
    python test_markdown_links.py --root /path/to/repo
"""

from __future__ import annotations

import argparse
import re
import sys
import urllib.parse
from dataclasses import dataclass
from pathlib import Path

import pytest


def find_repo_root(start: Path, marker: str = ".git") -> Path:
    """Walk upward from `start` until a directory containing `marker` is found.

    This lets the script live anywhere inside the repo (root, tests/,
    scripts/, etc.) without needing to assume its own location relative
    to the repo root — it finds the root itself instead.

    Args:
        start: Directory to start searching from (typically this file's folder).
        marker: Name of a file/folder that identifies the repo root.

    Returns:
        The resolved repo root path. Falls back to `start` itself if no
        marker is found above it (e.g. the repo has no .git folder yet).
    """
    current = start.resolve()
    for candidate in (current, *current.parents):
        if (candidate / marker).exists():
            return candidate
    print(
        f"Warning: could not find a '{marker}' folder above {start}; "
        f"falling back to {start} as the repo root.",
        file=sys.stderr,
    )
    return current


# Repo root is discovered by walking up from this file's location until a
# .git folder is found, so this script works no matter which folder it's
# placed in (repo root, tests/, scripts/, etc.).
REPO_ROOT = find_repo_root(Path(__file__).resolve().parent)

# Skipped when walking the repo for .md files (exact name matches).
IGNORED_DIRS = {".git", ".venv", "venv", "node_modules", "__pycache__"}

# Matches both [text](target "optional title") and ![alt](target "optional title")
LINK_PATTERN = re.compile(r"!?\[[^\]]*\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")

# Link targets starting with any of these are treated as external and skipped.
EXTERNAL_SCHEMES = ("http://", "https://", "mailto:", "tel:", "ftp://")


@dataclass
class BrokenLink:
    """A single link found in a Markdown file that does not resolve to a real file."""

    source_file: Path
    raw_link: str
    resolved_path: Path

    def __str__(self) -> str:
        try:
            src = self.source_file.relative_to(REPO_ROOT)
        except ValueError:
            src = self.source_file
        return f"{src} -> '{self.raw_link}' (resolved: {self.resolved_path})"


def find_markdown_files(root: Path) -> list[Path]:
    """Recursively find all .md files under root, skipping ignored directories.

    Args:
        root: Directory to search from.

    Returns:
        List of paths to every .md file found.
    """
    return [
        p
        for p in root.rglob("*.md")
        if not any(
            part in IGNORED_DIRS or (part.startswith(".") and part not in (".", ".."))
            for part in p.relative_to(root).parts[:-1]  # exclude the filename itself
        )
    ]


def extract_local_links(text: str) -> list[str]:
    """Return every link/image target in text that isn't external or a bare anchor.

    Args:
        text: Raw contents of a Markdown file.

    Returns:
        List of raw link targets (still possibly containing a '#fragment' suffix).
    """
    targets = []
    for match in LINK_PATTERN.finditer(text):
        target = match.group(1).strip()
        if not target:
            continue
        if target.startswith(EXTERNAL_SCHEMES):
            continue
        if target.startswith("#"):
            # Same-page anchor, e.g. [back to top](#top) - nothing on disk to check.
            continue
        targets.append(target)
    return targets


def resolve_link(source_file: Path, raw_link: str) -> Path:
    """Resolve a Markdown link relative to the file it was found in.

    Strips any trailing '#anchor' and URL-decodes the path (e.g. %20 -> space)
    before it's checked against the filesystem.

    Args:
        source_file: The Markdown file the link was found in.
        raw_link: The raw link target as written in the file.

    Returns:
        Absolute, resolved path the link is expected to point to.
    """
    path_part = raw_link.split("#", 1)[0]
    path_part = urllib.parse.unquote(path_part)
    return (source_file.parent / path_part).resolve()


def find_broken_links(root: Path) -> list[BrokenLink]:
    """Scan every Markdown file under root and return links that don't resolve.

    Args:
        root: Repo root (or any directory) to scan.

    Returns:
        List of BrokenLink entries, one per broken link/image reference found.
    """
    broken: list[BrokenLink] = []
    for md_file in find_markdown_files(root):
        text = md_file.read_text(encoding="utf-8", errors="replace")
        for raw_link in extract_local_links(text):
            resolved = resolve_link(md_file, raw_link)
            if not resolved.exists():
                broken.append(BrokenLink(md_file, raw_link, resolved))
    return broken


# ---------------------------------------------------------------------------
# Pytest entrypoint
# ---------------------------------------------------------------------------


def test_all_markdown_links_resolve_to_existing_files() -> None:
    """Fails with the full list of broken links if any is found in the repo.

    External links (http/https/mailto/ftp) and same-page anchors are ignored;
    only local file/image references are checked against the filesystem.
    """
    broken = find_broken_links(REPO_ROOT)
    if broken:
        details = "\n".join(f"  - {b}" for b in broken)
        pytest.fail(
            f"Found {len(broken)} broken local link(s) in the repo:\n{details}",
            pytrace=False,
        )


# ---------------------------------------------------------------------------
# Standalone CLI entrypoint
# ---------------------------------------------------------------------------


def parse_args() -> argparse.Namespace:
    """Parse command-line arguments for standalone use."""
    parser = argparse.ArgumentParser(
        description="Check that all local Markdown links/images point to files that exist."
    )
    parser.add_argument(
        "--root",
        type=Path,
        default=REPO_ROOT,
        help="Repo root to scan (default: folder this script lives in).",
    )
    return parser.parse_args()


def main() -> int:
    """Entrypoint for running this file directly with `python test_markdown_links.py`.

    Returns:
        0 if every link resolved, 1 if any broken link was found.
    """
    args = parse_args()
    broken = find_broken_links(args.root)

    if not broken:
        print("All local links and image references resolved successfully.")
        return 0

    print(f"ERROR: Found {len(broken)} broken local link(s):\n")
    for b in broken:
        print(f"  - {b}")
    return 1


if __name__ == "__main__":
    sys.exit(main())