# Rendering flow

Each frame is built in three named passes, each writing to a different surface. They run back-to-back from `draw_frame` in `src/main.odin`.

```
                  ┌───────────────────┐
  PTY cells ─────►│ draw_term_pass    │──► term_target  (RenderTexture)
                  └───────────────────┘
                              │
                              ▼ (sampled as drum texture)
                  ┌───────────────────┐
  3D camera   ──► │ draw_world_pass   │──► target       (RenderTexture)
  + drum      ──► │                   │
  + UI        ──► │                   │
                  └───────────────────┘
                              │
                              ▼
                  ┌───────────────────┐
  shimmer.fs ───► │ present_pass      │──► screen
  + shake/tint    │                   │
                  └───────────────────┘
```

## Pre-pass: simulation updates

Before any drawing, `draw_frame` runs the per-frame simulation tick — idle drift, mouse field, hyperlink hover detection, prompt-rise quiet timer, RPG XP/level, camera fly, PWD tint lerp, forge timer, shockwave timer, alt-screen detection, and drum tumble. Anything that all three passes need to read consistently is updated here.

```
elapsed_g  := rl.GetTime()      // shared clock for all effects
on_alt     := term_active_screen == .ALTERNATE
drum_set_alt(on_alt)
update_drum(dt)
```

`alt_screen_prev` tracks transitions into and out of alt-screen apps (vim, htop, less). On any transition the `input_line` buffer is cleared so command detection (typing `exit`, `cd`, `ls`, …) doesn't see stale chars typed inside the alt-screen app.

## Pass 1 — `draw_term_pass(dt)`

Renders the **flat terminal grid** to `term_target`.

Surface:
- `BeginTextureMode(term_target)` → `EndTextureMode` (deferred).
- Background: `cfg.term_bg` faded by `cam_fly_intensity` and tinted by `pwd_tint`. The `cd`-fly path drops bg alpha to ~8% so the 3D scene shows through.

Cell loop:
1. Iterate rows via `gvt.term_render_rows`. For each dirty row, `mark_row_born`, `mark_ls_row`, increment `drum_dirty_rows` (drives drum spin rate), reset error-quake scan, reset prompt-rise per-row state.
2. Iterate cells via `gvt.render_state_row_cells_next`. Per cell:
   - Capture first 16 cols into the error-quake scan buffer.
   - Capture cursor-row codepoints into `cursor_row_buf` (used for prompt detection / command parsing).
   - `whoosh_emit_cell` (clear effect particle emit).
   - `draw_cell` — the heart of cell rendering. Sums **eight** per-cell offset sources before drawing: gravity well, idle drift, mouse field, error quake, prompt rise, ls race-in, shockwave, emerge. Plus background, foreground, style (bold/underline/strikethrough), inverse, and search-laser highlight.
3. After the row's cells are drawn, run `quake_check_row` — fires the per-row shake if the leading word matches an error keyword.

Cursor + chrome (after the row loop):
- Cursor block.
- `draw_hyperlink_hover` — pointer-cursor + URI-run underline.
- Glitch substitution timers, ls animation, key drops, cursor trail, particles, rising-text overlay.

Outputs:
- `term_target` populated.
- `cursor_x_g`, `cursor_y_g`, `cursor_visible_g` set for downstream effects.
- `cursor_row_buf` populated for the *next* frame's command detection.

If `term_render_update` reports no fresh state, the cell loop is skipped but the bg fill still produces a valid `term_target`. Pass 2 and 3 proceed with whatever's already there (typically the previous frame's content).

## Pass 2 — `draw_world_pass(elapsed)`

Composites the 3D scene + drum + flat term overlay + UI to `target`.

Surface:
- `BeginTextureMode(target)` → `EndTextureMode`.
- Clear with `cfg.scene_bg`.

3D phase (`BeginMode3D(camera)`):
- `draw_3d_scene` — shardwall textured cubes when the drum is flat and `cd`-fly is idle; otherwise wireframe-cube grid that pumps brighter during `cd`-fly.
- `draw_drum_3d` — the alt-screen cylinder, sampling `term_target.texture` as its surface map.
- `EndMode3D`.

2D overlays in painter order:
1. `draw_cd_labels` — the `cd <dir>` text that flies past during the camera tween.
2. `draw_biome_overlay` — class-themed border underlay (post-Lv-10).
3. Flat term overlay — `term_target` blitted at the alpha given by `flat_visible_alpha()`. Fades to zero as the drum tumbles in.
4. `draw_search_overlay` — grep-laser sweep line + locked-row dimming.
5. `draw_drum_button` — the upper-right pause/play pill.
6. `draw_rpg_hud` — XP pill, drop toasts, spell overlays.
7. `draw_modal` — class-select.
8. `draw_skill_tree` — F10 overlay.
9. `draw_sudo_vignette` — red-pulse border when a `sudo` line is in flight.

Why this order: the flat term overlay sits **between** the 3D scene and the UI, so chrome (HUD, modal, tree, search) is always crisp on top of cells. The biome underlay is intentionally below the flat term overlay so it visibly thins through during `cd`-fly.

## Pass 3 — `present_pass(elapsed)`

Reads `target.texture`, runs the post-processing shader, writes to the screen.

```
BeginDrawing
  BeginShaderMode(shader)            # shaders/shimmer.fs
    DrawTextureRec(target, ..., shake_offset)
  EndShaderMode
  rhythm_tint() rectangle            # warm/cool tint over rendered scene
  draw_boot_overlay()                # CRT flash on launch (~650 ms)
EndDrawing
```

The shake offset (Enter / shockwave) is applied at this pass rather than per-cell so the entire composited frame shifts together — matches feel, much cheaper than offsetting every cell.

Rhythm tint and boot CRT flash sit *outside* the shader pass so they aren't sampled as if they were terminal content.

## Why three passes (not one)

Splitting into `term_target → target → screen` lets:

- The drum sample the flat terminal as its surface map (Pass 2 reads what Pass 1 wrote).
- The shader run over the *composite* (text + 3D scene + UI) rather than just the terminal — the shimmer/CRT effect uniformly distorts everything.
- Per-frame screen shake be a single texture offset instead of a per-cell offset.

The cost: two `RenderTexture2D` allocations sized to the window, recreated when font size changes (`apply_font_size` in main).

## Files

| File | Role |
|---|---|
| `src/main.odin` | `draw_frame`, the three pass procs, and `draw_cell` |
| `src/effects_*.odin` | Per-cell offset providers + per-frame chrome + simulation updates |
| `src/effects_drum.odin` | Cylinder mesh, alt-screen tumble state, `draw_drum_3d` |
| `src/effects_shardwall.odin` | Textured-cube backdrop drawn in `draw_3d_scene` |
| `shaders/shimmer.fs` | Post-processing shader sampled in `present_pass` |
| `src/rpg.odin` + `src/rpg_*.odin` | RPG HUD / modal / skill tree drawn from `draw_world_pass` |
