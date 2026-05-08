package uzo_term

// Lv 5 — Teleport
// cd commands trigger a 0.30s symmetric whiteout flash + 24 LASER particles
// radiating from the cursor. The whiteout is drawn during draw_rpg_hud,
// underneath the HUD pill so the level/class info stays readable.
//
// Owns its own flash timer; tick lives in update_rpg via teleport_tick.

import rl "vendor:raylib"

@(private = "file") FLASH_DURATION :: f32(0.30)

@(private = "file") flash_t: f32

@(init, private = "file")
register_teleport :: proc "contextless" () {
	register_spell(Spell{
		name           = "Teleport",
		level_required = 5,
		trigger        = .ON_COMMAND,
		match          = .CD_COMMAND,
		fire           = cast_teleport,
		tick           = teleport_tick,
		draw           = draw_teleport_flash,
	})
}

@(private = "file")
cast_teleport :: proc() {
	flash_t = FLASH_DURATION
	cx := f32(cursor_x_g) * f32(cell_w) + PADDING + f32(cell_w) * 0.5
	cy := f32(cursor_y_g) * f32(cell_h) + PADDING + f32(cell_h) * 0.5
	for _ in 0 ..< 24 do emit_rising(.LASER, cx, cy)
}

@(private = "file")
teleport_tick :: proc(dt: f32) {
	if flash_t > 0 do flash_t -= dt
}

@(private = "file")
draw_teleport_flash :: proc() {
	if flash_t <= 0 do return
	t := flash_t / FLASH_DURATION
	pulse := 1.0 - (2.0 * t - 1.0) * (2.0 * t - 1.0) // sin-like, peaks mid-flash
	alpha := u8(clamp(pulse, 0, 1) * 180)
	rl.DrawRectangle(0, 0, window_w, window_h, {255, 255, 255, alpha})
}
