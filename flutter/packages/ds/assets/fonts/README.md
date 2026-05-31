# Pretendard fonts

ANDS v2.0 uses Pretendard. Four weights are bundled (declared in `pubspec.yaml`):

| Weight | File |
|--------|------|
| 400 Regular | `Pretendard-Regular.otf` |
| 500 Medium | `Pretendard-Medium.otf` |
| 600 SemiBold | `Pretendard-SemiBold.otf` |
| 700 Bold | `Pretendard-Bold.otf` |

Only 400/500/600/700 are registered. Do NOT add 800 (ExtraBold): an unregistered
weight degrades to a synthetic/fallback render rather than the real glyph.

## Re-sourcing

If the files are missing, fetch the static OTF set from the official release:

- https://github.com/orioncactus/pretendard/releases (download `Pretendard-*.otf`)

Place the four files above into this directory. Font absence does not block
`flutter analyze`/`flutter test` (text falls back to the platform font), but the
real Pretendard render requires these assets.
