package uzo_term

import "core:math"
import rl "vendor:raylib"

// Boot-up CRT power-on flash (one-shot).
//
// On first frame, the screen "powers on" like a CRT: black bars at top and
// bottom shrink (image starts as a thin slit and expands vertically), a
// bright sweep line travels top→bottom, and an initial bright flash decays
// in the first ~120 ms. After ~boot_duration seconds it goes dormant and
// stays dormant for the rest of the session.

boot_t:      f32 = 0
boot_active: bool = true

update_boot :: proc(dt: f32) {
	if !boot_active do return
	boot_t += dt / cfg.boot_duration
	if boot_t >= 1.0 {
		boot_t = 1.0
		boot_active = false
	}
}

draw_boot_overlay :: proc() {
	if boot_t >= 1.0 do return // dormant for the rest of the session

	t := boot_t

	// Phase 1 (0..45%): black bars at top+bottom shrink — image starts as a
	// thin horizontal slit and expands vertically (classic CRT power-on).
	squeeze := 1.0 - ease_out_cubic(min(t / 0.45, 1.0))
	bar_h := i32(f32(window_h) * 0.5 * squeeze)
	if bar_h > 0 {
		rl.DrawRectangle(0, 0, window_w, bar_h, {0, 0, 0, 255})
		rl.DrawRectangle(0, window_h - bar_h, window_w, bar_h, {0, 0, 0, 255})
	}

	// Bright sweep line travelling top→bottom across the full duration.
	sweep_y := i32(f32(window_h) * t)
	for i in -3 ..= 3 {
		d := i if i >= 0 else -i
		a := u8(220 / (1 + i32(d * d)))
		y := sweep_y + i32(i * 3)
		if y >= 0 && y < window_h {
			rl.DrawRectangle(0, y, window_w, 2, {200, 240, 255, a})
		}
	}

	// Initial bright flash decays in the first ~120 ms.
	flash_t := min(t / 0.18, 1.0)
	flash_a := u8(220.0 * math.pow(1.0 - flash_t, 3))
	if flash_a > 0 {
		rl.DrawRectangle(0, 0, window_w, window_h, {220, 240, 255, flash_a})
	}
}
