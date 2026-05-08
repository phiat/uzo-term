package uzo_term

import "core:math"
import rl "vendor:raylib"

// Mouse Field — sibling of cursor gravity well, anchored to the mouse pointer.
//
// While the mouse is moving, glyphs within mouse_field_repel_radius are pushed
// away. After mouse_field_dwell_seconds of stillness the signed mode lerps
// from +1 (repel) to -1 (attract) and glyphs within mouse_field_attract_radius
// are pulled in. The smoothing makes the flip read as a breathing field rather
// than a snap on every motion start/stop.

MOUSE_FIELD_SPEED_THRESHOLD :: 6.0 // px/sec — below this counts as motionless

mouse_field_state: struct {
	last_x:           f32,
	last_y:           f32,
	have_last:        bool,
	motionless_timer: f32, // seconds since speed dropped below threshold
	mode:             f32, // smoothed sign: +1 repel, -1 attract
	on_screen:        bool,
}

update_mouse_field :: proc() {
	dt := rl.GetFrameTime()
	st := &mouse_field_state

	st.on_screen = bool(rl.IsCursorOnScreen())
	if !st.on_screen {
		// Decay both timer and mode toward neutral so re-entry starts fresh.
		st.motionless_timer = 0
		st.mode = math.lerp(st.mode, f32(0), min(dt * cfg.mouse_field_smoothing, 1.0))
		st.have_last = false
		return
	}

	mp := rl.GetMousePosition()
	speed: f32 = 0
	if st.have_last && dt > 0 {
		dx := mp.x - st.last_x
		dy := mp.y - st.last_y
		speed = math.sqrt(dx * dx + dy * dy) / dt
	}
	st.last_x = mp.x
	st.last_y = mp.y
	st.have_last = true

	if speed > MOUSE_FIELD_SPEED_THRESHOLD {
		st.motionless_timer = 0
	} else {
		st.motionless_timer += dt
	}

	target: f32 = 1.0 // default to repel
	if st.motionless_timer >= cfg.mouse_field_dwell_seconds {
		target = -1.0
	}

	// Smoothly flip; clamp lerp factor so high smoothing values don't overshoot.
	t := min(dt * cfg.mouse_field_smoothing, 1.0)
	st.mode = math.lerp(st.mode, target, t)
}

mouse_field_offset :: proc(col, row: u16) -> (dx, dy: f32) {
	st := &mouse_field_state
	if !st.on_screen do return 0, 0
	if abs(st.mode) < 0.01 do return 0, 0

	// Pick radius/strength side based on current mode sign. Asymmetric so
	// repel is tight and snappy; attract is wider and gentler.
	radius:   f32
	strength: f32
	if st.mode > 0 {
		radius   = cfg.mouse_field_repel_radius
		strength = cfg.mouse_field_repel_strength
	} else {
		radius   = cfg.mouse_field_attract_radius
		strength = cfg.mouse_field_attract_strength
	}
	if radius <= 0 || strength <= 0 do return 0, 0

	cx := f32(col) * f32(cell_w) + PADDING + f32(cell_w) * 0.5
	cy := f32(row) * f32(cell_h) + PADDING + f32(cell_h) * 0.5
	vx := st.last_x - cx
	vy := st.last_y - cy
	dist_sq := vx * vx + vy * vy
	if dist_sq > radius * radius || dist_sq < 1 do return 0, 0
	dist := math.sqrt(dist_sq)
	t := 1.0 - dist / radius
	// Sign convention: mode > 0 pushes glyph AWAY from mouse (negate vector
	// toward mouse), mode < 0 pulls it TOWARD. Folding mode into mag handles
	// both, including the smoothed in-between values during a flip.
	mag := strength * t * t * -st.mode
	return vx / dist * mag, vy / dist * mag
}
