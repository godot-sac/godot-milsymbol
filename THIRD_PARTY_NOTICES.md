# Third-Party Notices

This project is a port of, and includes data derived from, milsymbol.
The repository also bundles GUT for running tests; GUT is a development tool and is
not part of the distributed addon (`addons/milsymbol/`).

## milsymbol

- Source: https://github.com/spatialillusions/milsymbol
- Version: 3.0.5

```
The MIT License (MIT)

Copyright (c) 2017 Måns Beckman - www.spatialillusions.com

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## GUT (Godot Unit Test) — development only

- Source: https://github.com/bitwes/Gut
- Version: 9.7.1
- Location: `addons/gut/` (full license in `addons/gut/LICENSE.md`)

```
The MIT License (MIT)

Copyright (c) 2018 Tom "Butch" Wesley
```

## Arimo font (glyph outlines in exported icon data)

Icon text labels in `addons/milsymbol/data/icons_*.json` are stored as vector outlines generated from
the Arimo font. The font itself is not distributed; it is a development dependency of `tools/export/`.

- Source: https://github.com/googlefonts/arimo (via npm `@fontsource/arimo` 5.3.0)
- License: SIL Open Font License 1.1

```
Copyright 2020 The Arimo Project Authors (https://github.com/googlefonts/arimo)
```

## opentype.js — development only

Used by `tools/export/text-to-path.mjs` to read glyph outlines. Not distributed.

- Source: https://github.com/opentypejs/opentype.js
- Version: 2.0.0
- License: MIT, Copyright (c) 2020 Frederik De Bleser
