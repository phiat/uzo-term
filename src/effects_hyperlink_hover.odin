package uzo_term

import rl "vendor:raylib"

// OSC 8 hyperlink hover affordance: when the mouse is over a cell carrying a
// hyperlink URI, swap the OS cursor to a pointing hand and draw a bright
// underline across the full URI run (walked left/right while neighboring
// cells share the same URI). Pairs with handle_hyperlink_click — the same
// Ctrl+Click semantics still apply.

hyperlink_hover_state: struct {
	has:           bool,
	row:           u16,
	col_start:     u16,
	col_end:       u16, // inclusive
	prev_had:      bool,
}

update_hyperlink_hover :: proc() {
	st := &hyperlink_hover_state
	st.has = false

	defer {
		// Only manage the OS cursor on transitions so we don't fight other
		// systems that might set a cursor in the future.
		if st.has && !st.prev_had {
			rl.SetMouseCursor(.POINTING_HAND)
		} else if !st.has && st.prev_had {
			rl.SetMouseCursor(.DEFAULT)
		}
		st.prev_had = st.has
	}

	if !rl.IsCursorOnScreen() do return
	col, row, ok := mouse_to_cell(rl.GetMousePosition())
	if !ok do return

	buf: [4096]u8
	uri, has := hyperlink_at(col, row, buf[:])
	if !has do return

	// Walk along the same row while the URI matches. Hyperlinks could in
	// principle span multiple rows; in practice they don't, and limiting to
	// one row keeps the highlight visually clean.
	cmp: [4096]u8
	start := col
	for c := i32(col) - 1; c >= 0; c -= 1 {
		u, h := hyperlink_at(u16(c), row, cmp[:])
		if !h || u != uri do break
		start = u16(c)
	}
	end := col
	for c := i32(col) + 1; c < TERM_COLS; c += 1 {
		u, h := hyperlink_at(u16(c), row, cmp[:])
		if !h || u != uri do break
		end = u16(c)
	}

	st.has = true
	st.row = row
	st.col_start = start
	st.col_end = end
}

// Draws a bright underline + soft box outline over the hovered URI run.
// Call inside the term_target pass so it composites with the shaders.
draw_hyperlink_hover :: proc() {
	st := &hyperlink_hover_state
	if !st.has do return
	x := i32(f32(st.col_start) * f32(cell_w) + PADDING)
	y := i32(f32(st.row) * f32(cell_h) + PADDING)
	w := i32(f32(st.col_end - st.col_start + 1) * f32(cell_w))
	ac := cfg.accent_color
	rl.DrawRectangle(x, y + cell_h - 2, w, 2, ac)
	rl.DrawRectangleLines(x, y, w, cell_h, {ac.r, ac.g, ac.b, 0x44})
}
