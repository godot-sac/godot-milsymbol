"""Installs a package made by tools/package_addon.py into a new, empty Godot project and uses it there: renders
symbols (number and letter SIDCs), builds a control measure, and runs a TacticalMap2D with units and graphics for a
few frames. The check that a user who only has the zip gets a working addon (global classes registered, data files
found, no script errors).

Usage (from the repo root, any Python 3.9+):
    python tools/check_package.py build/package/godot-milsymbol-0.1.0.zip --godot <path to the Godot executable>
Prints a PACKAGE_CHECK line; exit code 1 on failure.
"""
import argparse
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

PROJECT = """config_version=5

[application]
config/name="godot-milsymbol package check"

[editor_plugins]
enabled=PackedStringArray("res://addons/milsymbol/plugin.cfg")
"""

SMOKE = """extends SceneTree

var _ok := true


func _check(condition: bool, what: String) -> void:
	if not condition:
		print("failed: ", what)
		_ok = false


func _initialize() -> void:
	var render := MilSymbol.render("10031000161211000000")
	_check(render.valid and render.to_image() != null, "MilSymbol.render")
	_check(MilSymbol.create_texture("SFGPUCI----D---", {"size": 40}) != null, "2525C letter SIDC texture")
	var shape := MilGraphic.build("10032500001403000000",
			PackedVector2Array([Vector2(0, 0), Vector2(300, 20)]), {"T": "BLUE"})
	_check(shape != null and shape.valid, "MilGraphic.build")
	_check(MilGraphicRenderer.to_image(shape) != null, "MilGraphicRenderer.to_image")

	var map := TacticalMap2D.new()
	map.size = Vector2(800, 600)
	root.add_child(map)
	map.center_on(39.93, 32.86, 50.0)
	map.add_layer("Friendly")
	map.add_unit("A", "10031000151211000000", 39.94, 32.85, "A COY", "Friendly")
	map.add_unit("B", "10061000001211000000", 39.92, 32.88, "B", "Friendly")
	map.add_graphic("OBJ", "10032500001517000000", PackedVector2Array(
			[Vector2(32.90, 39.95), Vector2(32.95, 39.95), Vector2(32.95, 39.92)]), {"T": "STEEL"})
	await process_frame
	await process_frame
	map.move_unit("A", 39.945, 32.855)
	await process_frame
	_check(map.get_unit_count() == 2, "TacticalMap2D units")
	_check(map.has_graphic("OBJ") and map.get_graphic_shape("OBJ") != null, "TacticalMap2D graphic")
	print("rendered: ", render.size, "  map units: ", map.get_unit_count())
	print("PACKAGE_CHECK ", "ok" if _ok else "FAILED")
	quit(0 if _ok else 1)
"""


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("package", type=Path)
    parser.add_argument("--godot", required=True)
    args = parser.parse_args()

    with tempfile.TemporaryDirectory(prefix="gms-package-") as tmp:
        project = Path(tmp)
        (project / "project.godot").write_text(PROJECT, encoding="utf-8")
        (project / "smoke.gd").write_text(SMOKE, encoding="utf-8")
        with zipfile.ZipFile(args.package) as archive:
            archive.extractall(project)
        first = subprocess.run([args.godot, "--headless", "--path", str(project), "--import"],
                               capture_output=True, text=True, encoding="utf-8", errors="replace")
        print(f"first import: exit {first.returncode}")
        run = subprocess.run([args.godot, "--headless", "--path", str(project), "-s", "res://smoke.gd"],
                             capture_output=True, text=True, encoding="utf-8", errors="replace")
        print(run.stdout.strip())
        # Script errors are not fatal to Godot, so the logs are checked too.
        errors = [line for line in (first.stdout + first.stderr + run.stdout + run.stderr).splitlines()
                  if "ERROR" in line or "WARNING" in line]
        if errors:
            print("errors / warnings:\n  " + "\n  ".join(errors[:40]), file=sys.stderr)
        if first.returncode != 0 or run.returncode != 0 or errors or "PACKAGE_CHECK ok" not in run.stdout:
            if "PACKAGE_CHECK FAILED" not in run.stdout:
                print("PACKAGE_CHECK FAILED")
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
