package uzo_term

import "core:math"
import gvt "ghosdin:vendor/ghostty_vt"

// Per-row micro-shake when a freshly-written row begins with an error keyword.
// Detection is column-anchored (after optional leading whitespace) to avoid
// firing on the word "error" appearing mid-prose.
//
// Scan integrates with the existing per-row cell iteration in draw_pass1a:
//   - quake_scan_reset(row)  — call when a row is marked dirty
//   - quake_scan_cell(row, col, byte) — call per cell (col < QUAKE_SCAN_LEN)
//   - quake_check_row(row)   — call once after the row's cells have iterated

QUAKE_SCAN_LEN :: 16

quake_scan_buf: [TERM_ROWS][QUAKE_SCAN_LEN]u8
row_quake_until: [TERM_ROWS]f32

quake_scan_reset :: proc(row: u16) {
	if row >= TERM_ROWS do return
	for i in 0 ..< QUAKE_SCAN_LEN do quake_scan_buf[row][i] = 0
}

quake_scan_cell :: proc(row: u16, col: u16, row_cells_h: gvt.Render_State_Row_Cells) {
	if row >= TERM_ROWS || col >= QUAKE_SCAN_LEN do return
	raw: gvt.Cell
	if gvt.render_state_row_cells_get(row_cells_h, .RAW, &raw) != .SUCCESS do return
	has: bool
	if gvt.cell_get(raw, .HAS_TEXT, &has) != .SUCCESS || !has do return
	cp: u32
	if gvt.cell_get(raw, .CODEPOINT, &cp) != .SUCCESS do return
	if cp >= 32 && cp < 128 {
		quake_scan_buf[row][col] = u8(cp)
	}
}

// Patterns checked at column 0 (after optional leading whitespace), case-
// insensitive. Kept minimal to limit false positives — extend cautiously.
@(private = "file")
quake_patterns := []string{"error", "fatal", "panic", "fail", "traceback"}

@(private = "file")
ascii_lower :: proc(b: u8) -> u8 {
	if b >= 'A' && b <= 'Z' do return b + 32
	return b
}

@(private = "file")
match_pattern :: proc(buf: []u8, pat: string) -> bool {
	if len(buf) < len(pat) do return false
	for i in 0 ..< len(pat) {
		if ascii_lower(buf[i]) != pat[i] do return false
	}
	return true
}

quake_check_row :: proc(row: u16) {
	if !cfg.error_quake_enabled do return
	if row >= TERM_ROWS do return
	buf := quake_scan_buf[row][:]
	// Skip leading ASCII whitespace.
	i := 0
	for i < len(buf) && (buf[i] == ' ' || buf[i] == '\t') do i += 1
	if i >= len(buf) do return
	for pat in quake_patterns {
		if match_pattern(buf[i:], pat) {
			row_quake_until[row] = elapsed_g + cfg.error_quake_duration
			return
		}
	}
}

error_quake_offset :: proc(row: u16) -> (dx: f32) {
	if row >= TERM_ROWS do return 0
	until := row_quake_until[row]
	if until <= 0 || elapsed_g >= until do return 0
	if cfg.error_quake_duration <= 0 do return 0
	t := (until - elapsed_g) / cfg.error_quake_duration // 1 → 0
	if t < 0 do t = 0
	if t > 1 do t = 1
	phase := elapsed_g * cfg.error_quake_freq + f32(row) * 0.73
	return cfg.error_quake_amp * t * math.sin(phase)
}
