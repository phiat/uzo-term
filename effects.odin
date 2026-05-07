package uzo_term

import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

// Ambient and cell-level effects that are always (or almost-always) running.
// Command-triggered transients live in effects_command.odin; the shared
// rising-particle pool lives in effects_particles.odin; scene-wide tints
// (boot CRT, PWD hue) live in effects_scene.odin; the alt-screen drum lives
// in effects_drum.odin; the grep laser sweep lives in effects_search.odin.

// ---------------------------------------------------------------------------
// Shared time (set once per frame at the top of draw_frame)
// ---------------------------------------------------------------------------

elapsed_g: f32

// ---------------------------------------------------------------------------
// Screen Shake
// ---------------------------------------------------------------------------

shake_timer: f32

trigger_shake :: proc() {
	shake_timer = cfg.shake_duration
}

update_shake :: proc(elapsed: f32) -> rl.Vector2 {
	dt := rl.GetFrameTime()
	if shake_timer <= 0 do return {}
	shake_timer -= dt
	t := shake_timer / cfg.shake_duration
	mag := cfg.shake_intensity * t
	return {mag * math.sin(elapsed * 127.1), mag * math.cos(elapsed * 71.7)}
}

// ---------------------------------------------------------------------------
// Cursor Trail / Afterimage
// ---------------------------------------------------------------------------

TRAIL_LEN :: 12 // compile-time (array size)

Trail_Point :: struct {
	x:     f32,
	y:     f32,
	age:   f32,
	alive: bool,
}

cursor_trail: [TRAIL_LEN]Trail_Point
trail_head:   int

push_trail_point :: proc(x, y: f32) {
	cursor_trail[trail_head] = {x, y, 0, true}
	trail_head = (trail_head + 1) % TRAIL_LEN
}

draw_cursor_trail :: proc() {
	dt := rl.GetFrameTime()
	for i in 0 ..< TRAIL_LEN {
		pt := &cursor_trail[i]
		if !pt.alive do continue
		pt.age += dt
		if pt.age >= cfg.trail_fade {
			pt.alive = false
			continue
		}
		t := 1.0 - pt.age / cfg.trail_fade
		alpha := u8(t * 65)
		rl.DrawRectangleLines(i32(pt.x), i32(pt.y), cell_w, cell_h, {cfg.fg_color.r, cfg.fg_color.g, cfg.fg_color.b, alpha})
	}
}

// ---------------------------------------------------------------------------
// Cursor Gravity Well
// ---------------------------------------------------------------------------

// Returns a pixel offset to pull a glyph toward the cursor.
// Call before drawing the glyph; apply to the text position only.
gravity_offset :: proc(col, row: u16) -> (dx, dy: f32) {
	if !cursor_visible_g do return 0, 0
	gx := f32(cursor_x_g) * f32(cell_w) + PADDING + f32(cell_w) * 0.5
	gy := f32(cursor_y_g) * f32(cell_h) + PADDING + f32(cell_h) * 0.5
	cx := f32(col) * f32(cell_w) + PADDING + f32(cell_w) * 0.5
	cy := f32(row) * f32(cell_h) + PADDING + f32(cell_h) * 0.5
	vx := gx - cx
	vy := gy - cy
	dist_sq := vx * vx + vy * vy
	if dist_sq > cfg.gravity_radius * cfg.gravity_radius || dist_sq < 1 do return 0, 0
	dist := math.sqrt(dist_sq)
	t := 1.0 - dist / cfg.gravity_radius
	mag := cfg.gravity_strength * t * t
	return vx / dist * mag, vy / dist * mag
}

// ---------------------------------------------------------------------------
// Typing Rhythm Visualizer
// ---------------------------------------------------------------------------

warmth: f32

on_keypress_rhythm :: proc() {
	warmth = min(warmth + cfg.warmth_per_key, cfg.warmth_max)
}

update_rhythm :: proc() {
	warmth = max(0, warmth - cfg.warmth_decay * rl.GetFrameTime())
}

// A soft warm/cool tint drawn over the render texture each frame.
rhythm_tint :: proc() -> rl.Color {
	if warmth < 0.01 do return {0, 0, 0, 0}
	alpha := u8(warmth * 30)
	r := u8(warmth * 55)
	b := u8((1.0 - warmth) * 22)
	return {r, 4, b, alpha}
}

// ---------------------------------------------------------------------------
// Sudo Vignette
// ---------------------------------------------------------------------------

sudo_active:  bool
sudo_pulse_t: f32

on_sudo_detected :: proc() { sudo_active = true }
on_sudo_cleared  :: proc() { sudo_active = false }

draw_sudo_vignette :: proc() {
	if !sudo_active do return
	sudo_pulse_t += rl.GetFrameTime() * 2.2
	pulse := (math.sin(sudo_pulse_t) + 1.0) * 0.5 // 0..1
	alpha := u8(22 + pulse * 48)
	thick: i32 = 14
	ac := rl.Color{cfg.accent_color.r, cfg.accent_color.g, cfg.accent_color.b, alpha}
	rl.DrawRectangle(0, 0, window_w, thick, ac)
	rl.DrawRectangle(0, window_h - thick, window_w, thick, ac)
	rl.DrawRectangle(0, 0, thick, window_h, ac)
	rl.DrawRectangle(window_w - thick, 0, thick, window_h, ac)
}

// ---------------------------------------------------------------------------
// Character Glitch / Substitution
// ---------------------------------------------------------------------------

glitch_timers: [TERM_ROWS][TERM_COLS]f32
glitch_chars:  [TERM_ROWS][TERM_COLS]rune

// Called when new PTY output arrives — scatters glitch timers with fixed chars.
trigger_glitch :: proc() {
	for _ in 0 ..< cfg.glitch_scatter {
		r := rand.int_max(TERM_ROWS)
		c := rand.int_max(TERM_COLS)
		glitch_timers[r][c] = 0.04 + rand.float32() * (cfg.glitch_duration_max - 0.04)
		glitch_chars[r][c] = rune(rand.int_max(94) + 33)
	}
}

update_glitch :: proc() {
	dt := rl.GetFrameTime()
	for r in 0 ..< TERM_ROWS {
		for c in 0 ..< TERM_COLS {
			if glitch_timers[r][c] > 0 do glitch_timers[r][c] -= dt
		}
	}
}

// Returns the stored substitute codepoint if this cell is currently glitching.
glitch_codepoint :: proc(col, row: u16) -> (rune, bool) {
	if col >= TERM_COLS || row >= TERM_ROWS do return 0, false
	if glitch_timers[row][col] <= 0 do return 0, false
	return glitch_chars[row][col], true
}

// ---------------------------------------------------------------------------
// Idle Drift
// ---------------------------------------------------------------------------
//
// After IDLE_START_DELAY seconds of no keypresses every glyph drifts gently
// on a per-cell sine wave.  Any keypress immediately begins snapping back.

idle_timer:    f32
idle_strength: f32

reset_idle :: proc() {
	idle_timer = 0
}

update_idle :: proc() {
	dt := rl.GetFrameTime()
	idle_timer += dt
	if idle_timer > cfg.idle_start_delay {
		idle_strength = min(idle_strength + dt * 0.28, 1.0)
	} else {
		idle_strength = max(0, idle_strength - dt * 5.5)
	}
}

idle_drift_offset :: proc(col, row: u16) -> (dx, dy: f32) {
	if idle_strength <= 0 do return 0, 0
	phase := f32(col) * 0.73 + f32(row) * 1.27
	dx = math.sin(elapsed_g * 0.68 + phase) * cfg.idle_drift_max * idle_strength
	dy = math.cos(elapsed_g * 0.51 + phase * 0.88) * cfg.idle_drift_max * idle_strength * 0.65
	return
}

// ---------------------------------------------------------------------------
// Line Age Decay
// ---------------------------------------------------------------------------
//
// Each row tracks the last time it was written (marked dirty by the terminal).
// Rows that haven't changed in a while fade to a dimmer shade.

row_birth:     [TERM_ROWS]f32
row_ever_born: [TERM_ROWS]bool

mark_row_born :: proc(row: u16) {
	if row >= TERM_ROWS do return
	row_birth[row] = elapsed_g
	row_ever_born[row] = true
	// Restart emerge animation if the previous one has finished.
	if row_emerge_until[row] < elapsed_g {
		row_emerge_until[row] = elapsed_g + cfg.emerge_duration
	}
}

// Returns 0..255 brightness multiplier for a row's text.
row_fade_alpha :: proc(row: u16) -> u8 {
	if row >= TERM_ROWS || !row_ever_born[row] do return 0xff
	age := elapsed_g - row_birth[row]
	if age < 5.0 do return 0xff
	t := clamp((age - 5.0) / 9.0, 0.0, 1.0)
	return u8(255.0 * (1.0 - t * 0.58)) // fades to ~42% brightness
}

// ---------------------------------------------------------------------------
// Z-emerge — newly-dirty rows tween in from depth (scale + alpha + rise)
// ---------------------------------------------------------------------------

row_emerge_until: [TERM_ROWS]f32 // animation ends at this elapsed_g

// Returns (dy, scale_mul, alpha_mul) for a row currently emerging.
emerge_offset :: proc(row: u16) -> (dy: f32, scale: f32, alpha: f32) {
	if row >= TERM_ROWS do return 0, 1.0, 1.0
	until := row_emerge_until[row]
	if until <= 0 || elapsed_g >= until do return 0, 1.0, 1.0
	t := 1.0 - (until - elapsed_g) / cfg.emerge_duration // 0→1 over the animation
	if t < 0 do t = 0
	if t > 1 do t = 1
	eased := ease_out_cubic(t)
	dy = (1.0 - eased) * cfg.emerge_rise_px
	scale = cfg.emerge_scale_min + (1.0 - cfg.emerge_scale_min) * eased
	alpha = 0.30 + 0.70 * eased
	return
}
