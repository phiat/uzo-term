package uzo_term

import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

// ls Race-In — after `ls` is entered, output rows get a per-cell
// race-in animation: each character starts off-screen left, races to
// its final position with a random delay, and overshoots/bounces into
// place via an ease-out-back curve.

LS_RACE_DURATION :: f32(0.38)

ls_anim_until:  f32 = -1
ls_cell_active: [TERM_ROWS][TERM_COLS]bool
ls_cell_timers: [TERM_ROWS][TERM_COLS]f32
ls_any_active:  bool

trigger_ls :: proc() {
	ls_anim_until = elapsed_g + 0.8
	for r in 0 ..< TERM_ROWS {
		for c in 0 ..< TERM_COLS {
			ls_cell_active[r][c] = false
		}
	}
	ls_any_active = false
}

// Called per dirty row during draw_frame — assigns random delays to new cells.
mark_ls_row :: proc(row: u16) {
	if ls_anim_until < 0 || elapsed_g > ls_anim_until do return
	if row >= TERM_ROWS do return
	for c in 0 ..< TERM_COLS {
		if !ls_cell_active[row][c] {
			ls_cell_active[row][c] = true
			base_delay := f32(c) * 0.003
			ls_cell_timers[row][c] = -(base_delay + rand.float32() * 0.35)
		}
	}
	ls_any_active = true
}

update_ls_anim :: proc() {
	if !ls_any_active do return
	dt := rl.GetFrameTime()
	still_active := false
	for r in 0 ..< TERM_ROWS {
		for c in 0 ..< TERM_COLS {
			if !ls_cell_active[r][c] do continue
			ls_cell_timers[r][c] += dt
			if ls_cell_timers[r][c] < LS_RACE_DURATION {
				still_active = true
			} else {
				ls_cell_active[r][c] = false
			}
		}
	}
	ls_any_active = still_active
}

// Returns x offset and font scale for a cell during the ls race-in.
ls_cell_offset :: proc(col, row: u16) -> (dx: f32, scale: f32) {
	if !ls_any_active do return 0, 1.0
	if row >= TERM_ROWS || col >= TERM_COLS do return 0, 1.0
	if !ls_cell_active[row][col] do return 0, 1.0

	t := ls_cell_timers[row][col]
	if t < 0 do return -f32(window_w + 100), 0.5

	// Ease-out-back: natural overshoot then settle
	p := t / LS_RACE_DURATION
	c1 :: f32(1.70158)
	c3 :: c1 + 1.0
	pm1 := p - 1.0
	eased := 1.0 + c3 * pm1 * pm1 * pm1 + c1 * pm1 * pm1

	start := -f32(window_w + 100)
	dx = start * (1.0 - eased)

	if p < 0.7 {
		scale = 0.6 + p * 0.57
	} else {
		bounce := (p - 0.7) / 0.3
		scale = 1.0 + math.sin(bounce * math.PI) * 0.25
	}
	return
}
