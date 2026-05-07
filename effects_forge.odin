package uzo_term

import "core:math/rand"

// Forge sparks — when a build command (`make`, `cargo build`, `npm install`,
// …) is detected, embers fountain up from the bottom edge for the duration
// of the build window. Fade-in/out tails so the start and end feel less
// abrupt. Embers are drawn from the shared rising pool.

FORGE_FADE_IN  :: f32(0.5)
FORGE_FADE_OUT :: f32(2.0)

forge_timer:  f32 = 0
forge_active: bool

trigger_forge :: proc() {
	forge_active = true
	forge_timer = 0
}

forge_intensity :: proc() -> f32 {
	if !forge_active do return 0
	if forge_timer < FORGE_FADE_IN do return forge_timer / FORGE_FADE_IN
	remaining := cfg.forge_duration - forge_timer
	if remaining < FORGE_FADE_OUT do return max(0, remaining / FORGE_FADE_OUT)
	return 1.0
}

update_forge :: proc(dt: f32) {
	if !forge_active do return
	forge_timer += dt
	if forge_timer >= cfg.forge_duration {
		forge_active = false
		return
	}

	emit_rate := cfg.forge_emit_rate * forge_intensity()
	expected := emit_rate * dt
	n := int(expected)
	if rand.float32() < (expected - f32(n)) do n += 1
	bottom := f32(window_h) - 2
	for _ in 0 ..< n {
		x := rand.float32() * f32(window_w)
		emit_rising(.EMBER, x, bottom)
	}
}
