# Golden Tests

Golden images live under `goldens/ci/` and are the canonical baselines used by
CI (`flutter test` on the GitHub Actions runner).

## Regenerating goldens

```sh
fvm flutter test --update-goldens
```

**Only regenerate on the canonical CI runner, not locally.** Font rendering
(subpixel hinting, fallback glyph selection) differs between macOS, Linux, and
the CI image. Regenerating locally produces a baseline that will fail on CI and
vice-versa. After a visual inspection confirms the new output is correct, commit
the updated PNGs from a CI artifact and open a dedicated "update goldens" PR.

Regenerating locally to iterate on a component is fine, but never commit those
local PNGs as the new baseline — the CI environment is the single source of
truth for committed golden files.
