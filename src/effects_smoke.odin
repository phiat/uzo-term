package uzo_term

import "core:math/rand"

// Kill smoke plume — `kill`/`pkill`/`killall` (and Ctrl+C) puff a soft
// grey cloud at the cursor row. Particles come from the shared rising
// pool with the SMOKE kind (slow drift up, expanding radius).

trigger_smoke :: proc() {
	base_x := f32(cursor_x_g) * f32(cell_w) + f32(PADDING)
	base_y := f32(cursor_y_g) * f32(cell_h) + f32(PADDING) + f32(cell_h) / 2
	for _ in 0 ..< cfg.smoke_count {
		x := base_x + (rand.float32() - 0.5) * f32(cell_w) * cfg.smoke_spread
		y := base_y + (rand.float32() - 0.5) * f32(cell_h)
		emit_rising(.SMOKE, x, y)
	}
}
