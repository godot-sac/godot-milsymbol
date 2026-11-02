"""Packs addons/milsymbol into a zip for users (the layout the Godot Asset Library expects: addons/milsymbol/ at the
root).

Takes the files git tracks under addons/milsymbol (so editor leftovers such as .import files never get in; without
git it walks the folder and skips them), adds LICENSE and THIRD_PARTY_NOTICES.md, and checks that the version
matches plugin.cfg.

Usage (from the repo root, any Python 3.9+):
    python tools/package_addon.py [--version 0.1.0] [--out build/package]
Without --version it uses the version in plugin.cfg. Check the result with tools/check_package.py.
"""
import argparse
import re
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ADDON = ROOT / "addons" / "milsymbol"
SKIPPED_SUFFIXES = {".import"}
# Fixed timestamp: the same sources give a byte-identical zip.
ZIP_DATE = (2026, 1, 1, 0, 0, 0)


def plugin_version() -> str:
    text = (ADDON / "plugin.cfg").read_text(encoding="utf-8")
    match = re.search(r'^version="([^"]+)"', text, re.M)
    return match.group(1) if match else ""


def addon_files() -> list[Path]:
    try:
        out = subprocess.run(["git", "ls-files", "-z", "addons/milsymbol"], cwd=ROOT, check=True,
                             capture_output=True).stdout.decode("utf-8")
        files = [ROOT / name for name in out.split("\0") if name]
    except (OSError, subprocess.CalledProcessError):
        files = [p for p in ADDON.rglob("*") if p.is_file()]
    return sorted(p for p in files if p.is_file() and p.suffix not in SKIPPED_SUFFIXES)


def untracked_files() -> list[str]:
    try:
        out = subprocess.run(["git", "ls-files", "--others", "--exclude-standard", "addons/milsymbol"], cwd=ROOT,
                             check=True, capture_output=True, text=True).stdout
    except (OSError, subprocess.CalledProcessError):
        return []
    return out.split()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--version", default="", help="defaults to the version in plugin.cfg")
    parser.add_argument("--out", type=Path, default=ROOT / "build" / "package")
    args = parser.parse_args()

    version = plugin_version()
    if args.version and args.version != version:
        print(f"version {args.version} does not match plugin.cfg ({version}); update plugin.cfg and CHANGELOG.md",
              file=sys.stderr)
        return 1
    untracked = untracked_files()
    if untracked:
        print("not packed (untracked, git add them first):\n  " + "\n  ".join(untracked), file=sys.stderr)

    files = [(path, path.relative_to(ROOT).as_posix()) for path in addon_files()]
    files.append((ROOT / "LICENSE", "addons/milsymbol/LICENSE"))
    files.append((ROOT / "THIRD_PARTY_NOTICES.md", "addons/milsymbol/THIRD_PARTY_NOTICES.md"))

    args.out.mkdir(parents=True, exist_ok=True)
    target = args.out / f"godot-milsymbol-{version}.zip"
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path, name in files:
            info = zipfile.ZipInfo(name, ZIP_DATE)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            archive.writestr(info, path.read_bytes())
    shown = target.relative_to(ROOT) if target.is_relative_to(ROOT) else target
    print(f"{shown.as_posix()}: {len(files)} files, {target.stat().st_size / 1e6:.2f} MB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
