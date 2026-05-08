package uzo_term

// Map Pulse — Drifter, gated on skill-tree node 10 (Cartographer).
// Fires on every cd command: a brief expanding accent-color ring radiates
// from the cursor cell, reading as a 'reveal ping' on top of the scene.
//
// Owns its own ring timer + position. Tick lives in update_rpg via
// map_pulse_tick; draw lives in draw_rpg_hud via draw_map_pulse so the
// HUD pill stays on top.

import rl "vendor:raylib"

@(private = "file") DURATION  :: f32(0.55)
@(private = "file") MAX_RADIUS :: f32(260)

@(private = "file") pulse_t: f32
@(private = "file") pulse_x: f32
@(private = "file") pulse_y: f32

@(init, private = "file")
register_map_pulse :: proc "contextless" () {
	register_spell(Spell{
		name           = "Map Pulse",
		level_required = 1,           // gate is the node, not the level
		trigger        = .ON_COMMAND,
		match          = .CD_COMMAND,
		fire           = cast_map_pulse,
		class_gate     = .DRIFTER,
		node_gate      = 10,          // Cartographer
	})
}

@(private = "file")
cast_map_pulse :: proc() {
	pulse_t = DURATION
	pulse_x = f32(cursor_x_g) * f32(cell_w) + PADDING + f32(cell_w) * 0.5
	pulse_y = f32(cursor_y_g) * f32(cell_h) + PADDING + f32(cell_h) * 0.5
}

map_pulse_tick :: proc(dt: f32) {
	if pulse_t > 0 do pulse_t -= dt
}

draw_map_pulse :: proc() {
	if pulse_t <= 0 do return
	t := pulse_t / DURATION                  // 1 → 0
	progress := 1.0 - t                      // 0 → 1
	radius := 24.0 + progress * MAX_RADIUS
	a_outer := u8(t * 220)
	a_inner := u8(t * 140)
	col_outer := rl.Color{cfg.accent_color.r, cfg.accent_color.g, cfg.accent_color.b, a_outer}
	col_inner := rl.Color{cfg.accent_color.r, cfg.accent_color.g, cfg.accent_color.b, a_inner}
	rl.DrawRing({pulse_x, pulse_y}, radius - 2, radius, 0, 360, 64, col_outer)
	rl.DrawRing({pulse_x, pulse_y}, radius * 0.62 - 1, radius * 0.62, 0, 360, 48, col_inner)
}
