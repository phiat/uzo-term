package uzo_term

import rl "vendor:raylib"

// Key Raindrop — each keypress spawns a glyph that starts large and
// semi-transparent (as if close to the viewer / falling from the sky)
// and shrinks to opaque as it lands at the cursor position.

KEY_DROP_MAX      :: 16
KEY_DROP_DURATION :: f32(0.38)

Key_Drop :: struct {
	x:     f32,
	y:     f32,
	cp:    rune,
	timer: f32,
	alive: bool,
}

key_drops:     [KEY_DROP_MAX]Key_Drop
key_drop_head: int

trigger_key_drop :: proc(cp: rune) {
	d := &key_drops[key_drop_head]
	d.x = f32(cursor_x_g) * f32(cell_w) + PADDING
	d.y = f32(cursor_y_g) * f32(cell_h) + PADDING
	d.cp = cp
	d.timer = 0
	d.alive = true
	key_drop_head = (key_drop_head + 1) % KEY_DROP_MAX
}

draw_key_drops :: proc() {
	dt := rl.GetFrameTime()
	for i in 0 ..< KEY_DROP_MAX {
		d := &key_drops[i]
		if !d.alive do continue
		d.timer += dt
		if d.timer >= KEY_DROP_DURATION {
			d.alive = false
			continue
		}
		t := d.timer / KEY_DROP_DURATION

		// Scale: starts very large (close to viewer), shrinks to land
		inv := 1.0 - t
		scale := 6.0 * inv * inv * inv + 1.0

		center_x := f32(window_w) * 0.5
		center_y := f32(window_h) * 0.25
		land_x := d.x
		land_y := d.y
		cur_x := center_x + (land_x - center_x) * t * t
		cur_y := center_y + (land_y - center_y) * t * t

		alpha := u8(20 + t * t * 235)

		sz := f32(font_size) * scale
		cx := cur_x - sz * 0.3
		cy := cur_y - sz * 0.35

		rl.DrawTextCodepoint(font, d.cp, {cx, cy}, sz, {cfg.fg_color.r, cfg.fg_color.g, cfg.fg_color.b, alpha})
	}
}
