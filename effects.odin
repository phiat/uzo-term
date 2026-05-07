package uzo_term

import "core:math"
import "core:math/rand"
import gvt "ghosdin:vendor/ghostty_vt"
import rl "vendor:raylib"

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
	x: f32,
	y: f32,
	age: f32,
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
// Enter Explosion (Particles)
// ---------------------------------------------------------------------------

MAX_PARTICLES :: 128

Particle :: struct {
	pos: rl.Vector2,
	vel: rl.Vector2,
	life: f32,
	max_life: f32,
	cp: rune,
	color: rl.Color,
}

particles:      [MAX_PARTICLES]Particle
particle_count: int

trigger_explosion :: proc() {
	base_y := f32(cursor_y_g) * f32(cell_h) + PADDING
	for _ in 0 ..< cfg.explode_count {
		if particle_count >= MAX_PARTICLES do break
		// Spread particles along the current line up to the cursor
		col := rand.float32() * f32(cursor_x_g + 1)
		px := col * f32(cell_w) + PADDING
		angle := rand.float32() * math.PI * 2
		speed := 55.0 + rand.float32() * 160.0
		life := 0.22 + rand.float32() * 0.32
		particles[particle_count] = {
			pos      = {px, base_y},
			vel      = {math.cos(angle) * speed, math.sin(angle) * speed - 50},
			life     = life,
			max_life = life,
			cp       = rune(rand.int_max(94) + 33),
			color    = cfg.fg_color,
		}
		particle_count += 1
	}
}

update_draw_particles :: proc() {
	dt := rl.GetFrameTime()
	new_count := 0
	for i in 0 ..< particle_count {
		p := &particles[i]
		p.life -= dt
		if p.life <= 0 do continue
		p.pos.x += p.vel.x * dt
		p.pos.y += p.vel.y * dt
		p.vel.y += 280 * dt // gravity
		t := p.life / p.max_life
		p.color.a = u8(t * 210)
		sz := f32(font_size) * (0.45 + t * 0.55)
		rl.DrawTextCodepoint(font, p.cp, p.pos, sz, p.color)
		particles[new_count] = particles[i]
		new_count += 1
	}
	particle_count = new_count
}

// ---------------------------------------------------------------------------
// Shared time (set once per frame at the top of draw_frame)
// ---------------------------------------------------------------------------

elapsed_g: f32

// ---------------------------------------------------------------------------
// Idle Drift
// ---------------------------------------------------------------------------
//
// After IDLE_START_DELAY seconds of no keypresses every glyph drifts gently
// on a per-cell sine wave.  Any keypress immediately begins snapping back.

idle_timer: f32
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

row_birth: [TERM_ROWS]f32
row_ever_born: [TERM_ROWS]bool

mark_row_born :: proc(row: u16) {
	if row >= TERM_ROWS do return
	row_birth[row] = elapsed_g
	row_ever_born[row] = true
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
// cd Camera Fly-Through
// ---------------------------------------------------------------------------
//
// Typing a `cd` command triggers a quick camera swoop: the viewpoint rushes
// forward into the 3D scene then eases back to its origin, like stepping
// through a portal into a new room.

cam_anim_t: f32 = -1
cam_origin_pos: rl.Vector3
cam_zoom_pos: rl.Vector3
cam_origin_fov: f32
cam_zoom_fov: f32
cam_fade: f32 // lingers after animation ends, decays to 0

// Directory name shown on cubes during the fly
cd_dir_buf: [128]u8
cd_dir_len: int

trigger_cd_fly :: proc(dir: string = "~") {
	// Strip trailing slashes, then take last path component
	trimmed := dir
	for len(trimmed) > 1 && trimmed[len(trimmed) - 1] == '/' {
		trimmed = trimmed[:len(trimmed) - 1]
	}
	// Find last slash in trimmed
	display := trimmed
	for i := len(trimmed) - 1; i >= 0; i -= 1 {
		if trimmed[i] == '/' {
			if i < len(trimmed) - 1 {
				display = trimmed[i + 1:]
			}
			break
		}
	}
	if len(display) == 0 do display = "/"

	n := min(len(display), len(cd_dir_buf) - 1)
	for i in 0 ..< n {
		cd_dir_buf[i] = display[i]
	}
	cd_dir_buf[n] = 0
	cd_dir_len = n
	cam_anim_t = 0
	cam_origin_pos = camera.position
	cam_origin_fov = camera.fovy
	// Fly to a new random viewpoint — each cd changes the perspective
	angle := rand.float32() * math.PI * 2
	radius := 4.0 + rand.float32() * 6.0
	height := 1.5 + rand.float32() * 5.0
	cam_zoom_pos = {
		math.cos(angle) * radius,
		height,
		math.sin(angle) * radius,
	}
	// Zoom FOV: narrow in then settle at a new FOV
	cam_zoom_fov = 25.0 + rand.float32() * 35.0
}

update_camera_fly :: proc() {
	if cam_anim_t < 0 do return
	dt := rl.GetFrameTime()
	cam_anim_t += dt / cfg.cam_duration // advances 0→1
	if cam_anim_t >= 1.0 {
		cam_anim_t = -1
		cam_fade = 1.0 // start fade-out tail
		camera.position = cam_zoom_pos
		camera.fovy = cam_zoom_fov
		cam_origin_pos = cam_zoom_pos
		cam_origin_fov = cam_zoom_fov
		return
	}
	// Ease-out cubic: fast start, smooth deceleration into destination
	t := cam_anim_t
	s := 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t)
	camera.position[0] = cam_origin_pos[0] + (cam_zoom_pos[0] - cam_origin_pos[0]) * s
	camera.position[1] = cam_origin_pos[1] + (cam_zoom_pos[1] - cam_origin_pos[1]) * s
	camera.position[2] = cam_origin_pos[2] + (cam_zoom_pos[2] - cam_origin_pos[2]) * s

	// FOV: punch narrow mid-flight then ease to destination
	// At t=0.3, FOV dips to 60% of origin (zoom punch), then settles to target
	fov_punch := math.sin(t * math.PI) * 0.4 // 0→0.4→0 bump
	fov_lerp := cam_origin_fov + (cam_zoom_fov - cam_origin_fov) * s
	camera.fovy = fov_lerp * (1.0 - fov_punch)
}

// 0..1 during fly and fade-out tail.
// Used to fade the terminal BG and brighten cubes.
cam_fly_intensity :: proc() -> f32 {
	// Decay fade tail each frame
	if cam_fade > 0 {
		cam_fade = max(0, cam_fade - rl.GetFrameTime() * 1.2)
	}
	// During active animation: ramp up fast
	if cam_anim_t >= 0 do return min(cam_anim_t * 3.0, 1.0)
	// After animation: fade tail
	return cam_fade
}

// Draw the cd target dir on cube positions — call after EndMode3D, before terminal overlay.
draw_cd_labels :: proc() {
	fly := cam_fly_intensity()
	if fly < 0.05 || cd_dir_len == 0 do return

	label := cstring(&cd_dir_buf[0])
	alpha := u8(fly * 240)
	t := elapsed_g

	for ix in -2 ..= 2 {
		for iz in -2 ..= 2 {
			x := f32(ix) * 2.5
			z := f32(iz) * 2.5 - 4
			y := math.sin(t * 0.6 + f32(ix + iz) * 0.8) * 0.4 + 0.5

			screen := rl.GetWorldToScreen({x, y, z}, camera)
			// Skip if behind camera or off screen
			if screen.x < -100 || screen.x > f32(window_w + 100) do continue
			if screen.y < -100 || screen.y > f32(window_h + 100) do continue

			// Size varies by depth — closer cubes get bigger text
			dx := x - camera.position[0]
			dy := y - camera.position[1]
			dz := z - camera.position[2]
			depth := math.sqrt(dx * dx + dy * dy + dz * dz)
			if depth < 0.5 do continue // too close, skip
			sz := i32(clamp(350.0 / depth, 10, 48))

			fsz := f32(sz)
			tw := rl.MeasureTextEx(font, label, fsz, 1).x
			pos := rl.Vector2{screen.x - tw * 0.5, screen.y - fsz * 0.5}

			rl.DrawTextEx(font, label, pos, fsz, 1,
				{cfg.fg_color.r, cfg.fg_color.g, cfg.fg_color.b, alpha})
		}
	}
}

// ---------------------------------------------------------------------------
// ls Race-In
// ---------------------------------------------------------------------------
//
// After "ls" is entered, output rows get a per-cell race-in animation:
// each character starts off-screen left, races to its final position with
// a random delay, and overshoots/bounces into place (squish & expand).

LS_RACE_DURATION :: f32(0.38)

ls_anim_until: f32 = -1
ls_cell_active: [TERM_ROWS][TERM_COLS]bool
ls_cell_timers: [TERM_ROWS][TERM_COLS]f32
ls_any_active: bool

trigger_ls :: proc() {
	ls_anim_until = elapsed_g + 0.8 // animate dirty rows for 0.8s after ls
	// Clear previous animation state
	for r in 0 ..< TERM_ROWS {
		for c in 0 ..< TERM_COLS {
			ls_cell_active[r][c] = false
		}
	}
	ls_any_active = false
}

// Called per dirty row during draw_frame — assigns random delays to new cells.
mark_ls_row :: proc(row: u16) {
	if ls_anim_until < 0 || elapsed_g > ls_anim_until do return
	if row >= TERM_ROWS do return
	for c in 0 ..< TERM_COLS {
		if !ls_cell_active[row][c] {
			ls_cell_active[row][c] = true
			// Random delay: earlier columns tend to start sooner for a wave effect
			base_delay := f32(c) * 0.003
			ls_cell_timers[row][c] = -(base_delay + rand.float32() * 0.35)
		}
	}
	ls_any_active = true
}

update_ls_anim :: proc() {
	if !ls_any_active do return
	dt := rl.GetFrameTime()
	still_active := false
	for r in 0 ..< TERM_ROWS {
		for c in 0 ..< TERM_COLS {
			if !ls_cell_active[r][c] do continue
			ls_cell_timers[r][c] += dt
			if ls_cell_timers[r][c] < LS_RACE_DURATION {
				still_active = true
			} else {
				ls_cell_active[r][c] = false // animation done
			}
		}
	}
	ls_any_active = still_active
}

// Returns x offset and font scale for a cell during the ls race-in.
ls_cell_offset :: proc(col, row: u16) -> (dx: f32, scale: f32) {
	if !ls_any_active do return 0, 1.0
	if row >= TERM_ROWS || col >= TERM_COLS do return 0, 1.0
	if !ls_cell_active[row][col] do return 0, 1.0

	t := ls_cell_timers[row][col]
	if t < 0 do return -f32(window_w + 100), 0.5 // not started yet — off-screen, squished

	// Ease-out-back: natural overshoot then settle
	p := t / LS_RACE_DURATION // 0→1
	c1 :: f32(1.70158)
	c3 :: c1 + 1.0
	pm1 := p - 1.0
	eased := 1.0 + c3 * pm1 * pm1 * pm1 + c1 * pm1 * pm1

	// X offset: starts far left, races to 0 with overshoot
	start := -f32(window_w + 100)
	dx = start * (1.0 - eased)

	// Scale: squished while racing, overshoots large on arrival, settles to 1.0
	if p < 0.7 {
		scale = 0.6 + p * 0.57 // 0.6 → 1.0
	} else {
		bounce := (p - 0.7) / 0.3 // 0→1
		scale = 1.0 + math.sin(bounce * math.PI) * 0.25 // overshoot to 1.25, back to 1.0
	}
	return
}

// ---------------------------------------------------------------------------
// Key Raindrop
// ---------------------------------------------------------------------------
//
// Each keypress spawns a "raindrop" — the character starts large and
// semi-transparent (as if close to the viewer / falling from the sky),
// then shrinks and becomes opaque as it lands at the cursor position.

KEY_DROP_MAX :: 16
KEY_DROP_DURATION :: f32(0.38)

Key_Drop :: struct {
	x: f32,
	y: f32,
	cp: rune,
	timer: f32,
	alive: bool,
}

key_drops: [KEY_DROP_MAX]Key_Drop
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
		t := d.timer / KEY_DROP_DURATION // 0→1

		// Scale: starts very large (close to viewer), shrinks to land
		inv := 1.0 - t
		scale := 6.0 * inv * inv * inv + 1.0 // 7.0→1.0 cubic ease

		// Lerp from screen centre to cursor position as it falls
		center_x := f32(window_w) * 0.5
		center_y := f32(window_h) * 0.25 // start from upper-centre
		land_x := d.x
		land_y := d.y
		cur_x := center_x + (land_x - center_x) * t * t // accelerate toward target
		cur_y := center_y + (land_y - center_y) * t * t

		// Alpha: very ghostly at start, solid on landing
		alpha := u8(20 + t * t * 235)

		sz := f32(font_size) * scale
		cx := cur_x - sz * 0.3
		cy := cur_y - sz * 0.35

		rl.DrawTextCodepoint(font, d.cp, {cx, cy}, sz, {cfg.fg_color.r, cfg.fg_color.g, cfg.fg_color.b, alpha})
	}
}

// ---------------------------------------------------------------------------
// Exit / Doom Drip — "GAME OVER"
// ---------------------------------------------------------------------------
//
// When "exit" is typed, the terminal freezes and melts downward in column
// strips (like the classic Doom screen melt). Once everything has dripped
// off, a "GAME OVER" title pulses on a black screen. Any key closes.

EXIT_MAX_STRIPS :: 256

exit_active: bool
exit_phase:  int   // 0=grace (still rendering terminal), 1=dripping, 2=game over
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
		// Game over screen — any key closes
		if rl.GetKeyPressed() != .KEY_NULL do return false
		return true
	}

	// Phase 1: dripping
	all_done := true
	for i in 0 ..< exit_strip_count {
		if exit_drip_offsets[i] >= f32(window_h) do continue
		all_done = false
		if exit_timer > exit_drip_delays[i] {
			exit_drip_offsets[i] += exit_drip_speeds[i] * dt
			exit_drip_speeds[i] += 350 * dt // gravity acceleration
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

	// "GAME OVER" text once drip is done
	if exit_phase == 2 {
		pulse := (math.sin(elapsed_g * 3.2) + 1.0) * 0.5
		alpha := u8(130 + pulse * 125)

		title: cstring = "GAME OVER"
		title_sz: i32 = 56
		tw := rl.MeasureText(title, title_sz)
		tx := (window_w - tw) / 2
		ty := window_h / 2 - 40

		// Shadow
		rl.DrawText(title, tx + 2, ty + 2, title_sz, {cfg.accent_color.r / 4, cfg.accent_color.g / 4, cfg.accent_color.b / 4, alpha})
		// Main
		rl.DrawText(title, tx, ty, title_sz, {cfg.accent_color.r, cfg.accent_color.g, cfg.accent_color.b, alpha})

		sub: cstring = "PRESS ANY KEY"
		sub_sz: i32 = 18
		sw := rl.MeasureText(sub, sub_sz)
		sub_alpha := u8(80 + pulse * 80)
		rl.DrawText(sub, (window_w - sw) / 2, ty + 75, sub_sz, {0x80, 0x80, 0x80, sub_alpha})
	}
}

// ---------------------------------------------------------------------------
// Boot-up CRT power-on flash (one-shot)
// ---------------------------------------------------------------------------

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

ease_out_cubic :: proc(t: f32) -> f32 {
	x := 1.0 - t
	return 1.0 - x * x * x
}

// ---------------------------------------------------------------------------
// PWD-tinted scene
// ---------------------------------------------------------------------------
//
// Hash the active working directory to a stable hue and gently tint the 3D
// cubes + terminal background by it, so each directory has its own visual
// signature. Driven by libghostty-vt's PWD reporting (OSC 7), so the effect
// only fires for shells that emit it (zsh / bash with vte hooks / etc.); on
// shells that don't, we just stay neutral.

pwd_hue_target:  f32 = -1 // -1 = no PWD seen yet
pwd_hue_current: f32 = 0
pwd_last_hash:   u32 = 0

@(private = "file")
fnv1a_32 :: proc(s: string) -> u32 {
	h: u32 = 2166136261
	for b in transmute([]u8)s {
		h = (h ~ u32(b)) * 16777619
	}
	return h
}

update_pwd_tint :: proc(dt: f32) {
	pwd := gvt.term_pwd(&gterm)
	if len(pwd) > 0 {
		h := fnv1a_32(pwd)
		if h != pwd_last_hash {
			pwd_last_hash = h
			pwd_hue_target = f32(h % 360)
			// First-ever pwd: snap rather than sweep through every hue.
			if pwd_hue_current == 0 && pwd_hue_target != 0 {
				pwd_hue_current = pwd_hue_target
			}
		}
	}
	if pwd_hue_target < 0 do return

	// Lerp toward target along the shorter arc around the hue wheel.
	diff := pwd_hue_target - pwd_hue_current
	if diff > 180 do diff -= 360
	else if diff < -180 do diff += 360
	pwd_hue_current += diff * min(dt * cfg.pwd_hue_lerp_rate, 1.0)
	if pwd_hue_current < 0 do pwd_hue_current += 360
	else if pwd_hue_current >= 360 do pwd_hue_current -= 360
}

// Mix `base` toward the PWD-derived accent at the given strength (0..1).
// Returns `base` unchanged when no PWD has been seen.
pwd_tint :: proc(base: rl.Color, strength: f32) -> rl.Color {
	if pwd_hue_target < 0 do return base
	accent := rl.ColorFromHSV(pwd_hue_current, 0.65, 1.0)
	inv := 1.0 - strength
	return rl.Color {
		u8(f32(base.r) * inv + f32(accent.r) * strength),
		u8(f32(base.g) * inv + f32(accent.g) * strength),
		u8(f32(base.b) * inv + f32(accent.b) * strength),
		base.a,
	}
}

// ---------------------------------------------------------------------------
// Rising particles (forge embers + kill smoke share one pool)
// ---------------------------------------------------------------------------

Rising_Kind :: enum {
	EMBER,  // forge — bright orange spark rising fast
	SMOKE,  // kill — soft grey expanding cloud rising slow
	WHOOSH, // clear — glyph flung radially outward from screen center
}

Rising_Particle :: struct {
	pos, vel:    rl.Vector2,
	life:        f32,
	max_life:    f32,
	kind:        Rising_Kind,
	radius_base: f32,
	cp:          rune, // WHOOSH only — codepoint to draw
}

MAX_RISING :: 1024
rising:       [MAX_RISING]Rising_Particle
rising_count: int

emit_rising :: proc(kind: Rising_Kind, x, y: f32) {
	if rising_count >= MAX_RISING do return
	p := &rising[rising_count]
	rising_count += 1

	p.kind = kind
	p.pos = {x, y}
	#partial switch kind {
	case .EMBER:
		p.vel = {(rand.float32() - 0.5) * 30, -45 - rand.float32() * 70}
		p.life = 1.4 + rand.float32() * 1.2
		p.radius_base = 1.2 + rand.float32() * 1.6
	case .SMOKE:
		p.vel = {(rand.float32() - 0.5) * 14, -22 - rand.float32() * 30}
		p.life = 1.6 + rand.float32() * 1.2
		p.radius_base = 4.0 + rand.float32() * 5.0
	}
	p.max_life = p.life
}

update_draw_rising :: proc() {
	dt := rl.GetFrameTime()
	new_count := 0
	for i in 0 ..< rising_count {
		p := &rising[i]
		p.life -= dt
		if p.life <= 0 do continue

		switch p.kind {
		case .EMBER, .SMOKE:
			// Slight horizontal drag, no gravity (these rise).
			p.vel.x *= 1.0 - 3.0 * dt
		case .WHOOSH:
			// Both-axis drag, no gravity — radial fling decays smoothly.
			drag := 1.0 - 2.5 * dt
			p.vel.x *= drag
			p.vel.y *= drag
		}
		p.pos.x += p.vel.x * dt
		p.pos.y += p.vel.y * dt

		t := p.life / p.max_life
		switch p.kind {
		case .EMBER:
			r: u8 = 255
			g := u8(60 + 195.0 * t * t)
			b := u8(40.0 * t)
			a := u8(220.0 * t)
			radius := p.radius_base * (0.55 + 0.45 * t)
			rl.DrawCircleV(p.pos, radius, {r, g, b, a})
		case .SMOKE:
			// Light blue-grey so the plume reads against a dark bg.
			r := u8(170 + 50.0 * t)
			g := u8(175 + 50.0 * t)
			b := u8(190 + 50.0 * t)
			a := u8(252.0 * t)
			radius := p.radius_base * (1.0 + 1.4 * (1.0 - t))
			rl.DrawCircleV(p.pos, radius, {r, g, b, a})
		case .WHOOSH:
			a := u8(255.0 * t)
			rl.DrawTextCodepoint(font, p.cp, p.pos, f32(font_size),
				{cfg.fg_color.r, cfg.fg_color.g, cfg.fg_color.b, a})
		}

		rising[new_count] = rising[i]
		new_count += 1
	}
	rising_count = new_count
}

// ---------------------------------------------------------------------------
// Forge sparks (build commands)
// ---------------------------------------------------------------------------

FORGE_FADE_IN  :: f32(0.5)
FORGE_FADE_OUT :: f32(2.0)

forge_timer:  f32 = 0
forge_active: bool

trigger_forge :: proc() {
	forge_active = true
	forge_timer = 0
}

forge_intensity :: proc() -> f32 {
	if !forge_active do return 0
	if forge_timer < FORGE_FADE_IN do return forge_timer / FORGE_FADE_IN
	remaining := cfg.forge_duration - forge_timer
	if remaining < FORGE_FADE_OUT do return max(0, remaining / FORGE_FADE_OUT)
	return 1.0
}

update_forge :: proc(dt: f32) {
	if !forge_active do return
	forge_timer += dt
	if forge_timer >= cfg.forge_duration {
		forge_active = false
		return
	}

	// Emit embers from random x positions along the bottom edge.
	emit_rate := cfg.forge_emit_rate * forge_intensity()
	expected := emit_rate * dt
	n := int(expected)
	if rand.float32() < (expected - f32(n)) do n += 1
	bottom := f32(window_h) - 2
	for _ in 0 ..< n {
		x := rand.float32() * f32(window_w)
		emit_rising(.EMBER, x, bottom)
	}
}

// ---------------------------------------------------------------------------
// Kill smoke plume (kill / pkill / killall / Ctrl+C)
// ---------------------------------------------------------------------------

trigger_smoke :: proc() {
	base_x := f32(cursor_x_g) * f32(cell_w) + f32(PADDING)
	base_y := f32(cursor_y_g) * f32(cell_h) + f32(PADDING) + f32(cell_h) / 2
	for _ in 0 ..< cfg.smoke_count {
		x := base_x + (rand.float32() - 0.5) * f32(cell_w) * cfg.smoke_spread
		y := base_y + (rand.float32() - 0.5) * f32(cell_h)
		emit_rising(.SMOKE, x, y)
	}
}

// ---------------------------------------------------------------------------
// Enter shockwave (horizontal ripple sweeping downward from cursor row)
// ---------------------------------------------------------------------------

shockwave_t:         f32 = 1.0
shockwave_start_row: i32 = 0

trigger_shockwave :: proc() {
	shockwave_t = 0
	shockwave_start_row = i32(cursor_y_g)
}

update_shockwave :: proc(dt: f32) {
	if shockwave_t >= 1.0 do return
	shockwave_t = min(1.0, shockwave_t + dt / cfg.shockwave_duration)
}

// Returns horizontal pixel offset for `row` as the shock wave passes.
shockwave_offset :: proc(row: u16) -> f32 {
	if shockwave_t >= 1.0 do return 0
	eased := ease_out_cubic(shockwave_t)
	front := f32(shockwave_start_row) + eased * f32(TERM_ROWS)
	d := f32(row) - front
	sigma := cfg.shockwave_sigma
	envelope := math.exp(-(d * d) / (2 * sigma * sigma))
	amp := cfg.shockwave_amp * (1.0 - shockwave_t) * envelope
	return amp * math.sin(d / cfg.shockwave_wavelength * 2 * math.PI)
}

// ---------------------------------------------------------------------------
// Clear whoosh-out — every visible glyph flies radially outward from center
// ---------------------------------------------------------------------------
//
// trigger_whoosh sets a flag; the next draw_frame iteration calls
// whoosh_emit_cell per cell to snapshot text glyphs into the rising pool.
// After iteration, whoosh_consume clears the flag.

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

// ---------------------------------------------------------------------------
// Spinning drum (alt-screen — TUI wraps around vertical cylinder)
// ---------------------------------------------------------------------------
//
// While the alt-screen is active (htop, vim, less, …) the terminal lifts off
// the flat plane and wraps around a vertical cylinder centered in the world.
// Spin rate scales with smoothed dirty-row count (htop redraws fast → fast
// spin; idle vim → glide). Tumbles in/out over ~0.45 s as the screen toggles.

DRUM_SLICES :: i32(64)

drum_mesh:    rl.Mesh
drum_model:   rl.Model
drum_loaded:  bool

drum_t:        f32 = 0 // 0 = flat, 1 = drum
drum_target_t: f32 = 0
drum_angle:    f32 = 0
drum_density:  f32 = 0
drum_active:   bool

drum_dirty_rows: int // counter accumulated by main during cell iteration

drum_dragging:    bool
drum_drag_last_y: f32
drum_paused:      bool

// Pause button box (upper-right corner of the window).
DRUM_BTN_SIZE   :: i32(28)
DRUM_BTN_MARGIN :: i32(8)

drum_btn_rect :: proc() -> rl.Rectangle {
	return rl.Rectangle {
		f32(window_w - DRUM_BTN_SIZE - DRUM_BTN_MARGIN),
		f32(DRUM_BTN_MARGIN),
		f32(DRUM_BTN_SIZE),
		f32(DRUM_BTN_SIZE),
	}
}

drum_btn_hit :: proc(p: rl.Vector2) -> bool {
	r := drum_btn_rect()
	return p.x >= r.x && p.x < r.x + r.width && p.y >= r.y && p.y < r.y + r.height
}

init_drum :: proc() {
	drum_mesh = rl.GenMeshCylinder(cfg.drum_radius, cfg.drum_length, DRUM_SLICES)

	// Lay the cylinder on its side: rotate -90° around Z (axis +Y → +X),
	// translate so it's centered on the world origin.
	// UVs are left at GenMeshCylinder defaults — on the laid-on-side cylinder
	// the default mapping rotates the TUI 90° CW relative to "cols along
	// length", which is the orientation we want.
	n := int(drum_mesh.vertexCount)
	half := cfg.drum_length * 0.5
	for i in 0 ..< n {
		px := drum_mesh.vertices[i * 3 + 0]
		py := drum_mesh.vertices[i * 3 + 1]
		// (x, y) → (y, -x), then -half along X to center
		drum_mesh.vertices[i * 3 + 0] = py - half
		drum_mesh.vertices[i * 3 + 1] = -px

		if drum_mesh.normals != nil {
			nx := drum_mesh.normals[i * 3 + 0]
			ny := drum_mesh.normals[i * 3 + 1]
			drum_mesh.normals[i * 3 + 0] = ny
			drum_mesh.normals[i * 3 + 1] = -nx
		}
	}
	rl.UpdateMeshBuffer(drum_mesh, 0, drum_mesh.vertices, i32(n) * 3 * size_of(f32), 0)
	if drum_mesh.normals != nil {
		rl.UpdateMeshBuffer(drum_mesh, 2, drum_mesh.normals, i32(n) * 3 * size_of(f32), 0)
	}

	drum_model = rl.LoadModelFromMesh(drum_mesh)
	drum_loaded = true
}

destroy_drum :: proc() {
	if drum_loaded {
		rl.UnloadModel(drum_model) // also frees mesh
		drum_loaded = false
	}
}

drum_set_alt :: proc(alt: bool) {
	drum_target_t = alt ? 1.0 : 0.0
	if !alt do drum_paused = false // forget pause state when leaving alt-screen
}

update_drum :: proc(dt: f32) {
	rate := dt / cfg.drum_tumble_duration
	if drum_t < drum_target_t {
		drum_t = min(drum_target_t, drum_t + rate)
	} else if drum_t > drum_target_t {
		drum_t = max(drum_target_t, drum_t - rate)
	}
	drum_active = drum_t > 0.001

	target_density := f32(drum_dirty_rows)
	drum_density += (target_density - drum_density) * min(dt * 3.5, 1.0)
	drum_dirty_rows = 0

	// Skip auto-spin while dragging or paused — the user is in control.
	if drum_target_t > 0 && !drum_dragging && !drum_paused {
		spin_rate := cfg.drum_base_spin + drum_density * cfg.drum_density_gain
		drum_angle += spin_rate * dt
	}
}

// Mouse-grab rotation + pause button. Plain left-button drag while the
// drum is active rotates it around its X axis: drag down → drum rolls
// forward (visible front comes toward camera and down). Clicking the
// pause button in the upper-right corner toggles auto-spin without
// starting a drag. Ctrl+Click is reserved for OSC 8 hyperlinks.
handle_drum_drag :: proc() {
	if !drum_active {
		drum_dragging = false
		return
	}

	mouse := rl.GetMousePosition()

	if rl.IsMouseButtonPressed(.LEFT) {
		ctrl := rl.IsKeyDown(.LEFT_CONTROL) || rl.IsKeyDown(.RIGHT_CONTROL)
		if !ctrl {
			if drum_btn_hit(mouse) {
				drum_paused = !drum_paused
			} else {
				drum_dragging = true
				drum_drag_last_y = mouse.y
			}
		}
	}

	if rl.IsMouseButtonReleased(.LEFT) {
		drum_dragging = false
	}

	if drum_dragging && rl.IsMouseButtonDown(.LEFT) {
		dy := mouse.y - drum_drag_last_y
		drum_drag_last_y = mouse.y
		// Spin axis is {-1, 0, 0} so positive drum_angle rolls the front
		// upward. To make "drag down" feel like grabbing the front and
		// pulling it down, decrement the angle when the mouse moves down.
		drum_angle -= dy * cfg.drum_drag_sensitivity
	}
}

// Renders the pause/play button in the upper-right corner. Fades in with
// the drum's tumble alpha. Call after the drum is rendered onto target.
draw_drum_button :: proc() {
	if !drum_active do return
	a := drum_visible_alpha()
	if a < 0.05 do return

	r := drum_btn_rect()
	hover := drum_btn_hit(rl.GetMousePosition())

	bg_a := u8(180.0 * a)
	if hover do bg_a = u8(220.0 * a)
	rl.DrawRectangleRec(r, {30, 32, 36, bg_a})
	rl.DrawRectangleLinesEx(r, 1, {cfg.fg_color.r, cfg.fg_color.g, cfg.fg_color.b, u8(180.0 * a)})

	icon_a := u8(255.0 * a)
	icon_color := rl.Color{cfg.fg_color.r, cfg.fg_color.g, cfg.fg_color.b, icon_a}
	cx := r.x + r.width * 0.5
	cy := r.y + r.height * 0.5

	if drum_paused {
		// Play icon — right-pointing triangle (raylib expects CCW vertices for visible front)
		w := r.width * 0.32
		h := r.height * 0.40
		v1 := rl.Vector2{cx - w * 0.5, cy - h}
		v2 := rl.Vector2{cx - w * 0.5, cy + h}
		v3 := rl.Vector2{cx + w * 0.6, cy}
		rl.DrawTriangle(v1, v2, v3, icon_color)
	} else {
		// Pause icon — two vertical bars
		bar_w := r.width * 0.18
		bar_h := r.height * 0.50
		gap := r.width * 0.10
		left := rl.Rectangle{cx - gap - bar_w, cy - bar_h * 0.5, bar_w, bar_h}
		right := rl.Rectangle{cx + gap, cy - bar_h * 0.5, bar_w, bar_h}
		rl.DrawRectangleRec(left, icon_color)
		rl.DrawRectangleRec(right, icon_color)
	}
}

drum_visible_alpha :: proc() -> f32 {
	return ease_out_cubic(drum_t)
}

flat_visible_alpha :: proc() -> f32 {
	return 1.0 - drum_visible_alpha()
}

draw_drum_3d :: proc(term_tex: rl.Texture2D) {
	if !drum_active || !drum_loaded do return

	// Rebind texture each frame (term_target may change on font resize).
	drum_model.materials[0].maps[rl.MaterialMapIndex.ALBEDO].texture = term_tex

	a := u8(255.0 * drum_visible_alpha())
	angle_deg := drum_angle * 180.0 / math.PI
	// Mesh is centered at origin. Spin around -X so the visible front face
	// rolls upward (content scrolls up like a teleprompter).
	rl.DrawModelEx(drum_model, {0, 0, 0}, {-1, 0, 0}, angle_deg, {1, 1, 1}, {255, 255, 255, a})
}
