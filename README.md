# Mermaid Madness

A top-down pirate sailing game for the [Playdate](https://play.date), built on
[Noble Engine](https://github.com/NobleRobot/NobleEngine) with
[pdParticles](https://codeberg.org/PossiblyAxolotl/pdParticles) for the wake and
explosions.

You sail a large open sea, the camera scrolls with your ship, and enemy vessels
appear at ever-shorter intervals as the voyage wears on.

## Controls

- **Crank** — steer the helm. Cranking turns the ship like a wheel.
- **Up / Down** — trim the sails: raise or lower your speed.
- **Left / Right** — charge a broadside to **port** / **starboard**. Hold to build
  power; a dotted line locks onto the nearest enemy on that side. Release to fire.
- **Ⓐ** — start / restart.

Off-screen enemies are flagged by arrows pinned to the edge of the screen.

## Project layout

```
source/
  main.lua              Entry point: imports, refresh rate, Noble.new(TitleScene)
  pdxinfo               Bundle metadata
  scenes/
    TitleScene.lua      Start screen
    GameScene.lua       Sailing + combat: input, camera, spawning, HUD, arrows
  scripts/
    Config.lua          All tuning values
    Utils.lua           Math + dotted-line helpers
    Ship.lua            Player ship (movement, wake particles, drawing)
    Enemy.lua           Chasing enemy ship
    Tridentball.lua     Projectile
  libraries/
    noble/              Noble Engine   (fetched — see below)
    pdParticles.lua     pdParticles    (fetched — see below)
tools/
  fetch-deps.sh         Pulls Noble + pdParticles into source/libraries/
.github/workflows/
  build.yml             CI/CD: compile the .pdx, release on tags
```

### A note on the rendering approach

Everything is drawn in immediate mode inside `GameScene:update()`. Noble runs the
scene's `update()` *after* its sprite/background pass, so drawing there composites
cleanly on top of the cleared background. World objects are drawn with a camera
draw-offset (`playdate.graphics.setDrawOffset`); the HUD, targeting line and
off-screen arrows are drawn afterward with the offset reset to zero. This plays
nicely with pdParticles, which draws immediately rather than through sprites.

## Getting the dependencies

The engine and particle library aren't committed to this repo. Get them either way:

**Option A — run the fetch script (simplest):**

```sh
bash tools/fetch-deps.sh
```

**Option B — use the Noble submodule + fetch the particle file:**

```sh
git submodule update --init --recursive
curl -fsSL -o source/libraries/pdParticles.lua \
  https://codeberg.org/PossiblyAxolotl/pdParticles/raw/branch/main/pdParticles.lua
```

## Build & run locally

With the [Playdate SDK](https://play.date/dev/) installed (`pdc` on your `PATH`):

```sh
bash tools/fetch-deps.sh          # once, to pull dependencies
pdc source Tridentade.pdx         # compile
open Tridentade.pdx               # macOS: opens in the Simulator
# or: PlaydateSimulator Tridentade.pdx
```

## CI/CD

`.github/workflows/build.yml` runs on every push/PR:

1. Checks out the repo (recursing submodules).
2. Runs `tools/fetch-deps.sh` to ensure Noble + pdParticles are present.
3. Installs the SDK with [`pd-rs/get-playdate-sdk`](https://github.com/marketplace/actions/get-playdate-sdk),
   which puts `pdc` on the `PATH` and sets `$PLAYDATE_SDK_PATH`.
4. Compiles with `pdc` and uploads `Tridentade.pdx.zip` as a build artifact.

Pushing a tag like `v1.0` additionally publishes the `.pdx.zip` to a GitHub Release.

### Pinning versions

`fetch-deps.sh` honors `NOBLE_REF` and `PARTICLES_REF` env vars (branch, tag, or —
for Noble — anything `git clone --branch` accepts). For reproducible CI, set these
to specific tags/commits in the workflow, e.g.:

```yaml
- name: Fetch engine + libraries
  run: bash tools/fetch-deps.sh
  env:
    NOBLE_REF: main
    PARTICLES_REF: main
```

If the `pd-rs/get-playdate-sdk@0.5.0` pin ever fails, try `@0.4` or `@latest`.

## Tuning

Nearly every knob — world size, ship speed, turn feel, spawn ramp, trident power —
lives in `source/scripts/Config.lua`.
