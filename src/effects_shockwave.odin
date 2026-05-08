package uzo_term

import "core:math"

// Enter shockwave — horizontal ripple that sweeps downward from the
// cursor's row when Enter is pressed, jiggling each row's text along
// the X axis as the wave front passes.

shockwave_t:         f32 = 1.0
shockwave_start_row: i32 = 0

trigger_shockwave :: proc() {
	shockwave_t = 0
	shockwave_start_row = i32(cursor_y_g)
}

update_shockwave :: proc(dt: f32) {
	if shockwave_t >= 1.0 do return
	shockwave_t = min(1.0, shockwave_t + dt / cfg.shockwave_duration)
}

// Returns horizontal pixel offset for `row` as the shock wave passes.
shockwave_offset :: proc(row: u16) -> f32 {
	if shockwave_t >= 1.0 do return 0
	eased := ease_out_cubic(shockwave_t)
	front := f32(shockwave_start_row) + eased * f32(TERM_ROWS)
	d := f32(row) - front
	sigma := cfg.shockwave_sigma
	envelope := math.exp(-(d * d) / (2 * sigma * sigma))
	amp := cfg.shockwave_amp * (1.0 - shockwave_t) * envelope
	return amp * math.sin(d / cfg.shockwave_wavelength * 2 * math.PI)
}
