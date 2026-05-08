# uzo-term

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Odin](https://img.shields.io/badge/odin-nightly-orange.svg)](https://odin-lang.org/)
[![Zig](https://img.shields.io/badge/zig-0.15.2-f7a41d.svg)](https://ziglang.org/)
[![raylib](https://img.shields.io/badge/raylib-5.5-white.svg)](https://www.raylib.com/)
[![Built on ghosdin](https://img.shields.io/badge/built%20on-ghosdin-7a5cff.svg)](https://github.com/phiat/ghosdin)
[![Platform](https://img.shields.io/badge/platform-linux-lightgrey.svg)](#)

<p align="center">
  <img src="docs/media/uzo-term-demo.gif" alt="uzo-term demo" width="720">
</p>

A graphical terminal emulator with visual effects and a built-in RPG progression layer, on [ghostty-vt](https://github.com/ghostty-org/ghostty) + [raylib](https://www.raylib.com/) in [Odin](https://odin-lang.org/).

## Effects

Boot CRT flash, screen shake, Enter shockwave + glyph explosion, key raindrops, cursor trail + gravity well, mouse field (repel-on-motion / attract-on-dwell), typing rhythm warmth, idle drift, line-age decay, character glitch, PWD tint, `cd` fly-through, forge sparks (build), kill smoke, clear whoosh, grep laser sweep, `ls` race-in, sudo vignette, exit doom-drip, alt-screen spinning drum (htop/vim/less), shardwall textured-cube backdrop, shimmer + CRT shader.

## Input

| Action | Key |
|--------|-----|
| Paste | Ctrl+Shift+V (bracketed-paste-aware) |
| Open OSC 8 hyperlink | Ctrl+Click (https/http/mailto/ftp) |
| Drum drag / pause | Left-drag while alt-screen / pause button upper-right |
| Toggle RPG layer | F9 |
| Font zoom | Ctrl++ / Ctrl+- / Ctrl+0 |

## RPG layer

Default-on. XP on every char + Enter; class auto-detects from your last 50 commands into one of six Neuromancer/Rifts classes (Drifter, Console Cowboy, Spider, Techno-Wizard, Operator, Ice-Breaker). Curve targets ~Lv 10 in 5 min, ~Lv 100 in ~90 min of normal use. HUD pill in the bottom-right.

Early-level spells: Spark on Command (Lv 2), Teleport (Lv 5, on `cd`), Biome Shift (Lv 10). Phase 2 (planned): per-class skill trees.

## Configuration

```
just run --rand                       # randomize all effects + palette
just run --shake-intensity=15
just run --no-rpg                     # disable RPG layer
just run --rpg-class=cowboy           # pin a class
./uzo-term_bin --help                 # full flag list
```

## Build

Requires Odin (nightly), Zig 0.15.2 (`.mise.toml`-pinned), raylib, and a sibling clone of [ghosdin](https://github.com/phiat/ghosdin) at `../ghosdin`.

```
git clone https://github.com/phiat/ghosdin.git ../ghosdin
just build    # build libghostty-vt + uzo-term
just run
just check
```

Binary writes to repo root and runs from there so `shaders/` and `fonts/` resolve.

### Fonts

Prefers JetBrains Mono Nerd Font; falls back to system paths or raylib default. Drop the TTF into `fonts/` (gitignored) to use without system install:

```
mkdir -p fonts
curl -L -o fonts/JetBrainsMonoNerdFont-Regular.ttf \
  https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/JetBrainsMono/Ligatures/Regular/JetBrainsMonoNerdFont-Regular.ttf
```

## Layout

```
src/
  main.odin               PTY, input, rendering, 3D scene
  config.odin             Effect_Config, --rand, CLI parsing
  util.odin               Pure helpers
  effects.odin            Ambient: shake, trail, gravity, rhythm, glitch, idle
  effects_<feature>.odin  One file per effect (boot, drum, forge, search, …)
  rpg.odin                RPG state + XP/level + HUD
  rpg_classes.odin        Class table
  rpg_spells.odin         Spell struct + registry + dispatcher
  rpg_spell_<name>.odin   One file per spell, self-registers via @(init)
shaders/                  Post-processing GLSL
docs/                     Design notes
```

**Adding a spell**: create one new `src/rpg_spell_<name>.odin`. **Adding a class**: append to the `RPG_Class` enum + `class_table` entry.
