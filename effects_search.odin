package uzo_term

import "core:math/rand"
import rl "vendor:raylib"

// Grep laser sweep — on `grep`/`rg`/`ag`/`find` etc., a thin red scanline
// sweeps top-to-bottom across the term overlay. Each frame, every visible
// row's text is checked against the search needle (literal substring match);
// rows that match get a brief red highlight + a few hot-white sparks when
// the laser passes.

SEARCH_NEEDLE_MAX :: 64

search_active:     bool
search_needle:     [SEARCH_NEEDLE_MAX]u8
search_needle_len: int
search_until:      f32
laser_y:           f32

search_row_buf:    [TERM_ROWS][TERM_COLS]u8
search_row_lens:   [TERM_ROWS]int
search_row_match:  [TERM_ROWS]bool
search_lock_until: [TERM_ROWS]f32

trigger_search :: proc(needle: string) {
	n := min(len(needle), SEARCH_NEEDLE_MAX)
	for i in 0 ..< n do search_needle[i] = needle[i]
	search_needle_len = n
	search_active = true
	search_until = elapsed_g + cfg.laser_duration
	laser_y = 0
	for i in 0 ..< TERM_ROWS {
		search_row_match[i] = false
		search_lock_until[i] = 0
	}
}

// Called from the draw_frame cell iteration, once per cell. Captures
// printable ASCII into the per-row buffer so search_scan_rows can match.
search_capture_cell :: proc(col, row: u16, cp: u32) {
	if !search_active do return
	if row >= TERM_ROWS do return
	if col == 0 do search_row_lens[row] = 0
	if cp >= 32 && cp < 127 && search_row_lens[row] < TERM_COLS {
		search_row_buf[row][search_row_lens[row]] = u8(cp)
		search_row_lens[row] += 1
	}
}

// Called once per frame after the cell iteration completes.
search_scan_rows :: proc() {
	if !search_active do return
	needle := string(search_needle[:search_needle_len])
	for r in 0 ..< TERM_ROWS {
		n := search_row_lens[r]
		if n == 0 {
			search_row_match[r] = false
			continue
		}
		text := string(search_row_buf[r][:n])
		search_row_match[r] = contains(text, needle)
	}
}

update_search :: proc(dt: f32) {
	if !search_active do return
	if elapsed_g >= search_until {
		search_active = false
		return
	}

	prev_y := laser_y
	laser_y += cfg.laser_speed * dt
	wrapped := false
	if laser_y > f32(window_h) {
		laser_y = 0
		wrapped = true
	}

	// Fire locks for rows the laser crossed during this dt.
	for r in 0 ..< TERM_ROWS {
		if !search_row_match[r] do continue
		row_y := f32(int(r) * int(cell_h)) + PADDING + f32(cell_h) * 0.5
		crossed := (prev_y <= row_y && laser_y >= row_y) ||
		           (wrapped && row_y < prev_y) ||
		           (wrapped && row_y <= laser_y)
		if !crossed do continue
		if search_lock_until[r] >= elapsed_g do continue
		search_lock_until[r] = elapsed_g + cfg.laser_lock_hold
		for _ in 0 ..< 3 {
			col := rand.int_max(int(TERM_COLS))
			px := f32(col * int(cell_w)) + PADDING + f32(cell_w) * 0.5
			emit_rising(.LASER, px, row_y)
		}
	}
}

// Drawn on `target` in pass-1b after the flat term overlay.
draw_search_overlay :: proc() {
	if !search_active do return

	// Active row locks — red highlight that fades over laser_lock_hold.
	for r in 0 ..< TERM_ROWS {
		if search_lock_until[r] <= elapsed_g do continue
		t := (search_lock_until[r] - elapsed_g) / cfg.laser_lock_hold
		a := u8(140.0 * t)
		rl.DrawRectangle(0, i32(r) * cell_h + PADDING, window_w, cell_h, {255, 70, 60, a})
	}

	// Scanline + soft aura.
	y := i32(laser_y)
	rl.DrawRectangle(0, y, window_w, 2, {255, 60, 50, 220})
	for i in 1 ..= 4 {
		falloff := u8(180.0 / f32(i * i))
		rl.DrawRectangle(0, y + i32(i * 2), window_w, 1, {255, 60, 50, falloff})
		rl.DrawRectangle(0, y - i32(i * 2), window_w, 1, {255, 60, 50, falloff})
	}
}
