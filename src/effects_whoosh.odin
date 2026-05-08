package uzo_term

import "core:math"
import "core:math/rand"
import gvt "ghosdin:vendor/ghostty_vt"

// Clear whoosh-out — `clear` / `reset` / Ctrl+L flings every visible
// glyph radially outward from the screen centre. trigger_whoosh sets a
// flag; the next draw_frame iteration calls whoosh_emit_cell per cell
// to snapshot text glyphs into the rising pool. After iteration,
// whoosh_consume clears the flag so we don't re-emit on subsequent frames.

whoosh_pending: bool

trigger_whoosh :: proc() {
	whoosh_pending = true
}

whoosh_emit_cell :: proc(col, row: u16, row_cells_h: gvt.Render_State_Row_Cells) {
	if !whoosh_pending do return
	if rising_count >= MAX_RISING do return

	raw: gvt.Cell
	if gvt.render_state_row_cells_get(row_cells_h, .RAW, &raw) != .SUCCESS do return
	has: bool
	if gvt.cell_get(raw, .HAS_TEXT, &has) != .SUCCESS || !has do return
	cp: u32
	gvt.cell_get(raw, .CODEPOINT, &cp)
	if cp < 32 do return

	px := f32(col) * f32(cell_w) + f32(PADDING)
	py := f32(row) * f32(cell_h) + f32(PADDING)

	cx := f32(window_w) * 0.5
	cy := f32(window_h) * 0.5
	dx := px - cx + (rand.float32() - 0.5) * 4.0
	dy := py - cy + (rand.float32() - 0.5) * 4.0
	d := math.sqrt(dx * dx + dy * dy)
	if d < 1 do d = 1
	speed := cfg.whoosh_speed_min + rand.float32() * (cfg.whoosh_speed_max - cfg.whoosh_speed_min)

	p := &rising[rising_count]
	rising_count += 1
	p.kind = .WHOOSH
	p.pos = {px, py}
	p.vel = {dx / d * speed, dy / d * speed}
	p.life = 0.7 + rand.float32() * 0.35
	p.max_life = p.life
	p.cp = rune(cp)
	p.radius_base = 0
}

whoosh_consume :: proc() {
	whoosh_pending = false
}
