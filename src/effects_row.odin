package uzo_term

// Per-row state — line-age decay + Z-emerge animation.
//
// Each row tracks the elapsed_g time of its last write (set by mark_row_born
// when libghostty-vt flags it dirty). Two effects feed off that:
//   - Line age: rows that haven't been touched in a while fade to a dimmer
//     shade (the stale output sinks back into the visual hierarchy).
//   - Z-emerge: newly-dirty rows tween in from depth (small, faded, lifted)
//     to their final position, so fresh output "lands" instead of popping.
//
// Both effects share the same row_birth/row_emerge_until vectors so they
// can't drift out of sync.

row_birth:        [TERM_ROWS]f32
row_ever_born:    [TERM_ROWS]bool
row_emerge_until: [TERM_ROWS]f32 // animation ends at this elapsed_g

mark_row_born :: proc(row: u16) {
	if row >= TERM_ROWS do return
	row_birth[row] = elapsed_g
	row_ever_born[row] = true
	// Restart emerge animation if the previous one has finished.
	if row_emerge_until[row] < elapsed_g {
		row_emerge_until[row] = elapsed_g + cfg.emerge_duration
	}
}

// Returns 0..255 brightness multiplier for a row's text.
row_fade_alpha :: proc(row: u16) -> u8 {
	if row >= TERM_ROWS || !row_ever_born[row] do return 0xff
	age := elapsed_g - row_birth[row]
	if age < 5.0 do return 0xff
	t := clamp((age - 5.0) / 9.0, 0.0, 1.0)
	return u8(255.0 * (1.0 - t * 0.58)) // fades to ~42% brightness
}

// Returns (dy, scale_mul, alpha_mul) for a row currently emerging.
emerge_offset :: proc(row: u16) -> (dy: f32, scale: f32, alpha: f32) {
	if row >= TERM_ROWS do return 0, 1.0, 1.0
	until := row_emerge_until[row]
	if until <= 0 || elapsed_g >= until do return 0, 1.0, 1.0
	t := 1.0 - (until - elapsed_g) / cfg.emerge_duration // 0→1 over the animation
	if t < 0 do t = 0
	if t > 1 do t = 1
	eased := ease_out_cubic(t)
	dy = (1.0 - eased) * cfg.emerge_rise_px
	scale = cfg.emerge_scale_min + (1.0 - cfg.emerge_scale_min) * eased
	alpha = 0.30 + 0.70 * eased
	return
}
