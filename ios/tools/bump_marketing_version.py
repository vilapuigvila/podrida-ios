#!/usr/bin/env python3
"""Bumps the patch component of MARKETING_VERSION in ios/project.yml.

Run by .github/workflows/testflight.yml before each release archive, so every
TestFlight upload ships a new version (e.g. 1.0.0 -> 1.0.1). `xcodegen
generate` has to run afterward to carry the bump into project.pbxproj. Prints
the new version on stdout.
"""
import re
import sys
from pathlib import Path

PROJECT_YML = Path(__file__).resolve().parent.parent / "project.yml"


def main() -> None:
    text = PROJECT_YML.read_text()
    match = re.search(r'MARKETING_VERSION: "(\d+)\.(\d+)\.(\d+)"', text)
    if not match:
        sys.exit("MARKETING_VERSION not found in project.yml as X.Y.Z")
    major, minor, patch = match.groups()
    new_version = f"{major}.{minor}.{int(patch) + 1}"
    old_line, new_line = match.group(0), f'MARKETING_VERSION: "{new_version}"'
    if text.count(old_line) != 1:
        sys.exit(f"expected exactly one {old_line!r} in project.yml")
    PROJECT_YML.write_text(text.replace(old_line, new_line))
    print(new_version)


if __name__ == "__main__":
    main()
