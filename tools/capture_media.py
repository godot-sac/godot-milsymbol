"""Makes the README media from the tactical map demo: a 16 s GIF, the 1280 x 640 social preview image and the
256 x 256 add-on icon (from icon.svg). Runs tools/capture_media.gd in Godot (a window opens briefly) and builds the
GIF with Pillow.

Usage (from the repo root; needs Pillow: pip install pillow):
    python tools/capture_media.py --godot <path to the Godot executable> [--out build/media]
Writes tactical-map.gif, social-preview.png and icon-256.png to --out. The GIF and the social preview are release
assets, not committed (see docs/media.md).
"""
import argparse
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parent.parent
FPS = 10
GIF_SIZE = (960, 540)
COLORS = 96
TRANSPARENT = 255  # palette index outside the quantized colours


def godot(exe: str, *args: str) -> None:
    run = subprocess.run([exe, "--path", str(ROOT), *args], capture_output=True, text=True, encoding="utf-8",
                         errors="replace", timeout=300)
    errors = [line for line in (run.stdout + run.stderr).splitlines() if "ERROR" in line]
    if run.returncode != 0 or errors:
        sys.exit(f"Godot failed ({' '.join(args[:4])}):\n" + "\n".join(errors or [run.stderr[-2000:]]))


def make_gif(frames_dir: Path, target: Path) -> None:
    frames = [Image.open(p).convert("RGB").resize(GIF_SIZE, Image.Resampling.LANCZOS)
              for p in sorted(frames_dir.glob("frame*.png"))]
    if not frames:
        sys.exit("no frames were written")
    # One palette for the whole GIF, taken from the overview, the zoomed view with the selection and the light map.
    picks = [frames[len(frames) // 4], frames[int(len(frames) * 0.45)], frames[-1]]
    sample = Image.new("RGB", (GIF_SIZE[0], GIF_SIZE[1] * len(picks)))
    for i, frame in enumerate(picks):
        sample.paste(frame, (0, GIF_SIZE[1] * i))
    palette = sample.quantize(colors=COLORS, method=Image.Quantize.MEDIANCUT)
    images = [f.quantize(palette=palette, dither=Image.Dither.NONE) for f in frames]
    # Units move all over the map, so the changed rectangle of a frame is nearly the whole frame. Pixels that did
    # not change are written as the transparent colour instead: long runs of one index compress well.
    out = [images[0]]
    for previous, current in zip(images, images[1:]):
        changed = ImageChops.difference(indices(previous), indices(current)).point(lambda v: 255 if v else 0)
        frame = Image.new("P", GIF_SIZE, TRANSPARENT)
        frame.putpalette(palette.getpalette())
        frame.paste(current, mask=changed)
        out.append(frame)
    out[0].save(target, save_all=True, append_images=out[1:], duration=1000 // FPS, loop=0, disposal=1,
                transparency=TRANSPARENT, optimize=False)


def indices(image: Image.Image) -> Image.Image:
    return Image.frombytes("L", image.size, image.tobytes())


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--godot", required=True)
    parser.add_argument("--out", type=Path, default=ROOT / "build" / "media")
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)

    godot(args.godot, "--headless", "--import")
    godot(args.godot, "--headless", "-s", "res://tools/capture_media.gd", "--", "--icon", str(out / "icon-256.png"))
    godot(args.godot, "--resolution", "1280x640", "-s", "res://tools/capture_media.gd", "--",
          "--social", str(out / "social-preview.png"))
    with tempfile.TemporaryDirectory(prefix="gms-media-") as tmp:
        godot(args.godot, "--fixed-fps", str(FPS), "--write-movie", str(Path(tmp) / "frame.png"),
              "-s", "res://tools/capture_media.gd", "--", "--tour", "--size", "%dx%d" % GIF_SIZE)
        make_gif(Path(tmp), out / "tactical-map.gif")
    for name in ["tactical-map.gif", "social-preview.png", "icon-256.png"]:
        print(f"{out / name}: {(out / name).stat().st_size / 1e6:.2f} MB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
