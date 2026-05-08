package uzo_term

import gvt "ghosdin:vendor/ghostty_vt"
import rl "vendor:raylib"

// PWD-tinted scene.
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
