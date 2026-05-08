package uzo_term

// Drifter biome — gentle sinwave ribbons along the top and bottom edges of
// the screen, in hot amber. Two waves of slightly different frequencies and
// phases for parallax. Animates continuously off elapsed_g; persists for
// the rest of the session once Lv 10 biome shift triggers.

import "core:math"
import rl "vendor:raylib"

@(private = "file") DRIFTER_AMBER     := rl.Color{255, 200, 80, 90}
@(private = "file") DRIFTER_AMBER_DIM := rl.Color{255, 180, 60, 50}
@(private = "file") SAMPLES           :: 64

@(init, private = "file")
register_drifter_biome :: proc "contextless" () {
	register_biome(.DRIFTER, draw_drifter_biome)
}

@(private = "file")
draw_drifter_biome :: proc() {
	w := f32(window_w)
	t := elapsed_g

	// Top ribbon — primary wave at fixed inset from top edge.
	top_y := f32(18)
	for i in 0 ..< SAMPLES {
		x0 := f32(i) * w / f32(SAMPLES)
		x1 := f32(i + 1) * w / f32(SAMPLES)
		y0 := top_y + math.sin(x0 * 0.018 + t * 0.55) * 7
		y1 := top_y + math.sin(x1 * 0.018 + t * 0.55) * 7
		rl.DrawLineEx({x0, y0}, {x1, y1}, 2, DRIFTER_AMBER)
	}
	// Top echo — slower, lower frequency, dimmer, slight phase offset.
	for i in 0 ..< SAMPLES {
		x0 := f32(i) * w / f32(SAMPLES)
		x1 := f32(i + 1) * w / f32(SAMPLES)
		y0 := top_y + 6 + math.sin(x0 * 0.012 + t * 0.32 + 1.7) * 5
		y1 := top_y + 6 + math.sin(x1 * 0.012 + t * 0.32 + 1.7) * 5
		rl.DrawLineEx({x0, y0}, {x1, y1}, 1, DRIFTER_AMBER_DIM)
	}

	// Bottom ribbon — counter-phase, mirrors the top so the screen feels
	// horizon-bracketed.
	bot_y := f32(window_h) - 18
	for i in 0 ..< SAMPLES {
		x0 := f32(i) * w / f32(SAMPLES)
		x1 := f32(i + 1) * w / f32(SAMPLES)
		y0 := bot_y + math.sin(x0 * 0.018 + t * 0.55 + math.PI) * 7
		y1 := bot_y + math.sin(x1 * 0.018 + t * 0.55 + math.PI) * 7
		rl.DrawLineEx({x0, y0}, {x1, y1}, 2, DRIFTER_AMBER)
	}
	for i in 0 ..< SAMPLES {
		x0 := f32(i) * w / f32(SAMPLES)
		x1 := f32(i + 1) * w / f32(SAMPLES)
		y0 := bot_y - 6 + math.sin(x0 * 0.012 + t * 0.32 + math.PI + 1.7) * 5
		y1 := bot_y - 6 + math.sin(x1 * 0.012 + t * 0.32 + math.PI + 1.7) * 5
		rl.DrawLineEx({x0, y0}, {x1, y1}, 1, DRIFTER_AMBER_DIM)
	}
}
