package uzo_term

import "core:math"
import gvt "ghosdin:vendor/ghostty_vt"
import rl "vendor:raylib"

// Scene-wide effects that don't belong to a specific cell or row:
// the boot-up CRT power-on flash and the per-PWD hue tint.

// ---------------------------------------------------------------------------
// Boot-up CRT power-on flash (one-shot)
// ---------------------------------------------------------------------------

boot_t:      f32 = 0
boot_active: bool = true

update_boot :: proc(dt: f32) {
	if !boot_active do return
	boot_t += dt / cfg.boot_duration
	if boot_t >= 1.0 {
		boot_t = 1.0
		boot_active = false
	}
}

draw_boot_overlay :: proc() {
	if boot_t >= 1.0 do return // dormant for the rest of the session

	t := boot_t

	// Phase 1 (0..45%): black bars at top+bottom shrink — image starts as a
	// thin horizontal slit and expands vertically (classic CRT power-on).
	squeeze := 1.0 - ease_out_cubic(min(t / 0.45, 1.0))
	bar_h := i32(f32(window_h) * 0.5 * squeeze)
	if bar_h > 0 {
		rl.DrawRectangle(0, 0, window_w, bar_h, {0, 0, 0, 255})
		rl.DrawRectangle(0, window_h - bar_h, window_w, bar_h, {0, 0, 0, 255})
	}

	// Bright sweep line travelling top→bottom across the full duration.
	sweep_y := i32(f32(window_h) * t)
	for i in -3 ..= 3 {
		d := i if i >= 0 else -i
		a := u8(220 / (1 + i32(d * d)))
		y := sweep_y + i32(i * 3)
		if y >= 0 && y < window_h {
			rl.DrawRectangle(0, y, window_w, 2, {200, 240, 255, a})
		}
	}

	// Initial bright flash decays in the first ~120 ms.
	flash_t := min(t / 0.18, 1.0)
	flash_a := u8(220.0 * math.pow(1.0 - flash_t, 3))
	if flash_a > 0 {
		rl.DrawRectangle(0, 0, window_w, window_h, {220, 240, 255, flash_a})
	}
}

// ---------------------------------------------------------------------------
// PWD-tinted scene
// ---------------------------------------------------------------------------
//
// Hash the active working directory to a stable hue and gently tint the 3D
// cubes + terminal background by it, so each directory has its own visual
// signature. Driven by libghostty-vt's PWD reporting (OSC 7), so the effect
// only fires for shells that emit it (zsh / bash with vte hooks / etc.); on
// shells that don't, we just stay neutral.

pwd_hue_target:  f32 = -1 // -1 = no PWD seen yet
pwd_hue_current: f32 = 0
pwd_last_hash:   u32 = 0

update_pwd_tint :: proc(dt: f32) {
	pwd := gvt.term_pwd(&gterm)
	if len(pwd) > 0 {
		h := fnv1a_32(pwd)
		if h != pwd_last_hash {
			pwd_last_hash = h
			pwd_hue_target = f32(h % 360)
			// First-ever pwd: snap rather than sweep through every hue.
			if pwd_hue_current == 0 && pwd_hue_target != 0 {
				pwd_hue_current = pwd_hue_target
			}
		}
	}
	if pwd_hue_target < 0 do return

	// Lerp toward target along the shorter arc around the hue wheel.
	diff := pwd_hue_target - pwd_hue_current
	if diff > 180 do diff -= 360
	else if diff < -180 do diff += 360
	pwd_hue_current += diff * min(dt * cfg.pwd_hue_lerp_rate, 1.0)
	if pwd_hue_current < 0 do pwd_hue_current += 360
	else if pwd_hue_current >= 360 do pwd_hue_current -= 360
}

// Mix `base` toward the PWD-derived accent at the given strength (0..1).
// Returns `base` unchanged when no PWD has been seen.
pwd_tint :: proc(base: rl.Color, strength: f32) -> rl.Color {
	if pwd_hue_target < 0 do return base
	accent := rl.ColorFromHSV(pwd_hue_current, 0.65, 1.0)
	inv := 1.0 - strength
	return rl.Color {
		u8(f32(base.r) * inv + f32(accent.r) * strength),
		u8(f32(base.g) * inv + f32(accent.g) * strength),
		u8(f32(base.b) * inv + f32(accent.b) * strength),
		base.a,
	}
}
