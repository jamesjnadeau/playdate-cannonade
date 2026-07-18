# libraries/

External dependencies live here. They are **not** committed to the repo — fetch
them before building:

```sh
bash ../../tools/fetch-deps.sh
```

That populates:

- `noble/` — Noble Engine (from https://github.com/NobleRobot/NobleEngine)
- `pdParticles.lua` — pdParticles (from https://codeberg.org/PossiblyAxolotl/pdParticles)

Alternatively, add Noble as a git submodule (see the top-level `.gitmodules`) and
download `pdParticles.lua` manually.
