# Media

Pictures used by the README, the GitHub page and the Godot Asset Library, and how to make them again.

| File | Size | Where it lives | Used by |
|---|---|---|---|
| `tactical-map.gif` | 960 × 540, 16 s, ~3.3 MB | **release asset** (not in git) | README (top) |
| `social-preview.png` | 1280 × 640, ~0.2 MB | **uploaded in the GitHub repository settings** (Settings > General > Social preview; not in git) | link previews |
| `docs/images/icon-256.png` | 256 × 256 | git | Asset Library icon |
| `icon.svg` | 128 × 128 | git | source of the icon; also the demo project's icon |
| `docs/images/getting-started.png` | 1152 × 648 | git | [getting-started.md](getting-started.md) |
| `docs/images/tactical-map.png`, `control-measures.png` | | git | README, [tactical-map.md](tactical-map.md) |

The GIF is kept out of git so that the repository stays small when it is made again. Attach it to every
release (`gh release upload v<version> build/media/tactical-map.gif`); the README links to the asset of the
latest release.

## Making them

```sh
pip install pillow
python tools/capture_media.py --godot <path to Godot>
```

This runs `tools/capture_media.gd` (a Godot window opens for about 20 s) and writes `tactical-map.gif`,
`social-preview.png` and `icon-256.png` to `build/media/`. The GIF is a scripted tour of the tactical map demo
(`demo/tactical_map.tscn`): overview with moving units, zoom to the 1st brigade with two units selected, the
control measure layer switched off and on, then the light map style. The social preview is the same scenario
at 1280 × 640 with a title bar. Copy `icon-256.png` to `docs/images/` after changing `icon.svg`.

`docs/images/getting-started.png` is the scene of the getting-started guide, recorded with
`--write-movie` from a project made as the guide describes.
