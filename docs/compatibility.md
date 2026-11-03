# Compatibility

What was actually run, per add-on version, Godot version and platform. "Not tested" means exactly that: it may
work, but nobody has checked. Reports for other combinations are welcome (open an issue with the output of the
package check below).

| godot-milsymbol | Godot | Platform | Tests (GUT) | Package in an empty project | Demo | Checked on |
|---|---|---|---|---|---|---|
| 0.1.0 | 4.7.2 stable | Windows 11, x86_64 (Vulkan, NVIDIA) | ✓ 95/95 | ✓ | ✓ every demo scene; windowed, media capture | 2026-11-03 |
| 0.1.0 | 4.7.2 stable | Linux: Ubuntu 24.04 in WSL2, x86_64 | ✓ 95/95 | ✓ | ✓ every demo scene headless; getting-started guide windowed under WSLg (software Vulkan) | 2026-11-03 |
| 0.1.0 | 4.7.2 stable | Windows (`windows-latest`), Linux (`ubuntu-22.04`) in CI | configured, not run yet | configured (Linux) | – | – |
| any | 4.3 – 4.6 | any | not tested | not tested | not tested | – |
| any | any | macOS, Android, iOS, Web | not tested | not tested | not tested | – |

Notes:
- The add-on is pure GDScript with JSON data files; it has no native libraries, so there is nothing
  platform-specific to build. Rendering uses `Image.load_svg_from_string()`, `MultiMeshInstance2D` and a small
  canvas shader, which exist in every Godot 4 version, but the code uses 4.x syntax and APIs added up to 4.7
  without checking older versions.
- Renderers: the tests and the package check run headless (dummy renderer); the demo was run with Forward+
  (Vulkan). Compatibility (OpenGL) and Mobile were not tried.
- The .NET build of Godot was not tried; nothing in the add-on depends on C#.

## How to check a combination

From a clone of the repository, with the Godot executable you want to check:

```sh
python tools/package_addon.py
python tools/check_package.py build/package/godot-milsymbol-<version>.zip --godot <path to Godot>
godot --headless --path . --import
godot --headless --path . -s addons/gut/gut_cmdln.gd
```

`check_package.py` installs the zip into a new, empty project, renders symbols and a control measure and runs a
`TacticalMap2D` for a few frames; it prints `PACKAGE_CHECK ok` and fails on any `ERROR` or `WARNING` line.
