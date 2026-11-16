# film_recipes

The film recipe engine of Carrete. Recipes are data: they live in a versioned
JSON file, are validated against a schema and are turned into the exact float
values the shader of `shaders/film.frag` expects.

The package is pure Dart. It runs in the app, in the tests and in the tools
without pulling Flutter in.

## The format of a recipe

`assets/recipes.json` holds every film of the app:

```json
{
  "schemaVersion": 1,
  "recipesVersion": "2026.11.1",
  "recipes": [
    {
      "id": "verano-98",
      "name": { "es": "Verano 98", "ca": "Estiu 98", "en": "Summer 98" },
      "description": {
        "es": "Negativo de color cálido, grano fino y una fuga de luz suave.",
        "ca": "Negatiu de color càlid, gra fi i una fuita de llum suau.",
        "en": "Warm colour negative with fine grain and a soft light leak."
      },
      "kind": "color",
      "defaults": { "format": "3:2", "dateStamp": false, "whiteFrame": false },
      "exposure": 0.12,
      "saturation": 1.08,
      "matrix": [1.06, -0.03, -0.02, -0.02, 1.02, 0.01, -0.01, -0.06, 0.93],
      "shadowTint": [0.014, 0.0, -0.012],
      "highlightTint": [0.03, 0.008, -0.026],
      "curve": {
        "master": [[0, 0.045], [0.25, 0.27], [0.5, 0.52], [0.75, 0.77], [1, 0.965]],
        "r": [[0, 0.04], [0.25, 0.28], [0.5, 0.53], [0.75, 0.78], [1, 0.97]],
        "g": [[0, 0.05], [0.25, 0.27], [0.5, 0.52], [0.75, 0.765], [1, 0.96]],
        "b": [[0, 0.06], [0.25, 0.28], [0.5, 0.515], [0.75, 0.755], [1, 0.95]]
      },
      "grain": { "amount": 0.32, "size": 1.1 },
      "halation": { "amount": 0.32, "threshold": 0.78, "radius": 0.012, "color": [1, 0.35, 0.15] },
      "leak": { "amount": 0.22, "position": [0.95, 0.12], "radius": 0.45, "color": [1, 0.42, 0.12] },
      "vignette": { "amount": 0.26, "softness": 0.62 },
      "wbDrift": 0.012
    }
  ]
}
```

Every field is optional except `id`, `name` and `description`, and every one of
them has a default, so a recipe only writes what it wants to change. The
ranges are hard limits and the validator reports all of them at once, each one
with the path where it was found:

```
recipes[2].grain.amount: 1.4 is above the maximum 1
```

| Field | Range | Default |
| --- | --- | --- |
| `id` | `^[a-z0-9-]{2,40}$`, unique | required |
| `name`, `description` | `{es, ca, en}`, none empty | required |
| `kind` | `color` or `bw` | `color` |
| `defaults.format` | `3:2`, `4:3`, `1:1`, `16:9` | `3:2` |
| `defaults.dateStamp` | boolean | `false` |
| `defaults.whiteFrame` | boolean | `false` |
| `exposure` | -2..2 stops | 0 |
| `saturation` | 0..2 | 1 |
| `matrix` | 9 numbers, row major, -2..2 | identity |
| `shadowTint`, `highlightTint` | 3 numbers, -0.2..0.2 | `[0, 0, 0]` |
| `curve.master`, `curve.r/g/b` | 2..16 points `[x, y]` | `[[0,0],[1,1]]` |
| `grain.amount` | 0..1 | 0 |
| `grain.size` | 0.25..4 | 1 |
| `halation.amount`, `halation.threshold` | 0..1 | 0, 0.75 |
| `halation.radius` | 0..0.05 of the short side | 0.01 |
| `halation.color`, `leak.color` | 3 numbers, 0..1 | `[1,0.35,0.15]`, `[1,0.45,0.1]` |
| `leak.amount` | 0..1 | 0 |
| `leak.position` | 2 numbers, 0..1 of the frame | `[0.9, 0.1]` |
| `leak.radius` | 0.05..1.5 of the short side | 0.4 |
| `vignette.amount`, `vignette.softness` | 0..1 | 0, 0.5 |
| `wbDrift` | 0..0.1 | 0 |
| `bandColor` | `#RRGGBB`, the colour of the band of the cartridge | derived by the app from the look |
| `notes` | free text, ignored by the engine | none |

`bandColor` is optional and was added in `recipesVersion` 2026.11.3 without
changing `schemaVersion` (a book without it stays valid): the app uses it for
the band of the cartridge and, when it is missing, derives a colour from the
look of the film. The ten films of the book each name one, with a different
hue family.

A curve needs at least two points, its x must grow strictly from 0 to 1 and
every y must be between 0 and 1. Unknown keys are an error everywhere.

The rules live in `lib/src/validation.dart` and are mirrored in
`schema/recipes.schema.json` (JSON Schema draft 2020-12) for the editors. Two
rules cannot be written in JSON Schema and are only checked by the validator:
the x of the curve points must grow strictly, and the last point of a curve
must end at x = 1. The ids of the book must also be unique, which JSON Schema
cannot write either.

## How to add a film

1. Add the recipe to `assets/recipes.json`, with its name and its description
   in Spanish, Catalan and English. Never use the name of a film or a camera
   maker.
2. Run the tests: `dart test`. The validator checks the new recipe and the
   schema test checks that the validator and the schema still agree.
3. Update the golden images: `dart run tool/update_goldens.dart`.
4. Look at the new images in `test/goldens/` and check that the film looks the
   way it should.

Adding a film never touches the code.

## The public API

```dart
// Reading the book.
final RecipeBook book = RecipeBook.parse(json);   // throws RecipeFormatException
final RecipeBookResult result = RecipeBook.tryParse(json);  // never throws
final Recipe? recipe = book.byId('verano-98');

// Resolving a look.
final ResolvedLook look = resolve(
  recipe,
  intensity: 1,                 // 0 = the photo, 1 = the film
  overrides: const LookOverrides(grain: 0.5),
  shotSeed: 42,                 // 0 = no white balance drift
);

// Feeding the shader.
final List<double> uniforms = shaderUniforms(look, seed: 0.37);
final Uint8List curve = curveRgba(look);   // the 256x1 texture of `uCurve`
```

`resolve` interpolates every value between the neutral look and the recipe.
The curves are interpolated entry by entry once both are in their 256 entry
lookup table. A film of kind `bw` always ends at zero saturation, and it still
starts at one, so the intensity slides from the colour photo to the black and
white one.

The white balance drift comes from a small integer hash of the seed: each
channel gets its own multiplier of `1 +/- wbDrift`, which is folded into the
diagonal of the colour matrix. The same seed always drifts the same way and a
seed of zero drifts not at all.

`shaderUniforms` returns the 37 floats of the slots 2 to 38 of
`shaders/film.frag`, in the order the shader reads them. The slots 0 and 1
hold the size of the frame and are set by the app.

## The golden images

`lib/src/reference_renderer.dart` is a CPU port of `main()` in
`shaders/film.frag` in paint mode, block by block. The golden test renders
every recipe at full strength and at half strength over the chart of
`lib/src/test_chart.dart` and compares the result with the PNG of
`test/goldens/`.

The test fails when a channel moves by more than one level or when the mean
difference goes over 0.05, which only happens when the look of a recipe
changes. When the change was wanted, run:

```sh
dart run tool/update_goldens.dart
```

It writes `test/goldens/<id>_<intensity>.png` for every recipe and
`test/goldens/hashes.json` with the SHA-256 of the raw RGBA bytes of each
image.

The shader runs on 32 bit floats and the port on doubles, so the grain may
differ in the last bits between platforms. That is why the test allows a
difference of one level and reports whether the hash is exactly the same.

## The commands

```sh
dart pub get
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
dart test
```

## The dependencies

The package has no runtime dependency. The tools and the tests use `test`,
`lints`, `json_schema` (Boost Software License 1.0), `image` and `crypto`
(all BSD 3-Clause).
