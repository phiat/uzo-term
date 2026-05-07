package uzo_term

import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

// Exit / Doom Drip — "GAME OVER".
//
// When `exit` is typed, the terminal freezes and melts downward in column
// strips (like the classic Doom screen melt). Once everything has dripped
// off, a "GAME OVER" title pulses on a black screen. Any key closes.

EXIT_MAX_STRIPS :: 256

exit_active: bool
exit_phase:  int   // 0=grace, 1=dripping, 2=game over
exit_timer:  f32

exit_drip_offsets: [EXIT_MAX_STRIPS]f32
exit_drip_delays:  [EXIT_MAX_STRIPS]f32
exit_drip_speeds:  [EXIT_MAX_STRIPS]f32
exit_strip_count:  int

trigger_exit :: proc() {
	exit_active = true
	exit_phase = 0
	exit_timer = 0
}

// Called once after the grace period — initialises per-strip random delays/speeds.
init_exit_drip :: proc() {
	exit_strip_count = min(int(window_w) / int(cell_w), EXIT_MAX_STRIPS)
	prev_delay: f32 = rand.float32() * 0.25
	for i in 0 ..< exit_strip_count {
		// Random walk so adjacent columns are correlated (smooth wave front)
		prev_delay += (rand.float32() - 0.5) * 0.1
		prev_delay = clamp(prev_delay, 0.0, 0.7)
		exit_drip_delays[i] = prev_delay
		exit_drip_speeds[i] = 120.0 + rand.float32() * 180.0
		exit_drip_offsets[i] = 0
	}
}

// Returns true to keep running, false to quit.
update_exit_drip :: proc() -> bool {
	if !exit_active do return true
	dt := rl.GetFrameTime()
	exit_timer += dt

	if exit_phase == 2 {
		if rl.GetKeyPressed() != .KEY_NULL do return false
		return true
	}

	all_done := true
	for i in 0 ..< exit_strip_count {
		if exit_drip_offsets[i] >= f32(window_h) do continue
		all_done = false
		if exit_timer > exit_drip_delays[i] {
			exit_drip_offsets[i] += exit_drip_speeds[i] * dt
			exit_drip_speeds[i] += 350 * dt
		}
	}
	if all_done {
		exit_phase = 2
		exit_timer = 0
	}
	return true
}

draw_exit_drip :: proc() {
	elapsed_g = f32(rl.GetTime())
	strip_w := cell_w
	if strip_w < 1 do strip_w = 1

	rl.BeginDrawing()
	defer rl.EndDrawing()
	rl.ClearBackground({0, 0, 0, 0xff})

	for i in 0 ..< exit_strip_count {
		sx := f32(i * int(strip_w))
		offset := exit_drip_offsets[i]

		src := rl.Rectangle{sx, 0, f32(strip_w), -f32(window_h)}
		dst := rl.Rectangle{sx, offset, f32(strip_w), f32(window_h)}
		rl.DrawTexturePro(target.texture, src, dst, {0, 0}, 0, rl.WHITE)
	}

	if exit_phase == 2 {
		pulse := (math.sin(elapsed_g * 3.2) + 1.0) * 0.5
		alpha := u8(130 + pulse * 125)

		title: cstring = "GAME OVER"
		title_sz: i32 = 56
		tw := rl.MeasureText(title, title_sz)
		tx := (window_w - tw) / 2
		ty := window_h / 2 - 40

		rl.DrawText(title, tx + 2, ty + 2, title_sz, {cfg.accent_color.r / 4, cfg.accent_color.g / 4, cfg.accent_color.b / 4, alpha})
		rl.DrawText(title, tx, ty, title_sz, {cfg.accent_color.r, cfg.accent_color.g, cfg.accent_color.b, alpha})

		sub: cstring = "PRESS ANY KEY"
		sub_sz: i32 = 18
		sw := rl.MeasureText(sub, sub_sz)
		sub_alpha := u8(80 + pulse * 80)
		rl.DrawText(sub, (window_w - sw) / 2, ty + 75, sub_sz, {0x80, 0x80, 0x80, sub_alpha})
	}
}
