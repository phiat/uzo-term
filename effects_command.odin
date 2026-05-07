package uzo_term

import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

// Command- and key-triggered transient effects: Enter explosion, Enter
// shockwave, cd camera fly, ls race-in, key raindrop, exit doom drip.

// ---------------------------------------------------------------------------
// Enter Explosion (Particles)
// ---------------------------------------------------------------------------

MAX_PARTICLES :: 128

Particle :: struct {
	pos:      rl.Vector2,
	vel:      rl.Vector2,
	life:     f32,
	max_life: f32,
	cp:       rune,
	color:    rl.Color,
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
// cd Camera Fly-Through
// ---------------------------------------------------------------------------
//
// Typing a `cd` command triggers a quick camera swoop: the viewpoint rushes
// forward into the 3D scene then eases back to its origin, like stepping
// through a portal into a new room.

cam_anim_t:     f32 = -1
cam_origin_pos: rl.Vector3
cam_zoom_pos:   rl.Vector3
cam_origin_fov: f32
cam_zoom_fov:   f32
cam_fade:       f32 // lingers after animation ends, decays to 0

// Directory name shown on cubes during the fly
cd_dir_buf: [128]u8
cd_dir_len: int

trigger_cd_fly :: proc(dir: string = "~") {
	// Strip trailing slashes, then take last path component
	trimmed := dir
	for len(trimmed) > 1 && trimmed[len(trimmed) - 1] == '/' {
		trimmed = trimmed[:len(trimmed) - 1]
	}
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
	fov_punch := math.sin(t * math.PI) * 0.4
	fov_lerp := cam_origin_fov + (cam_zoom_fov - cam_origin_fov) * s
	camera.fovy = fov_lerp * (1.0 - fov_punch)
}

// 0..1 during fly and fade-out tail.
cam_fly_intensity :: proc() -> f32 {
	if cam_fade > 0 {
		cam_fade = max(0, cam_fade - rl.GetFrameTime() * 1.2)
	}
	if cam_anim_t >= 0 do return min(cam_anim_t * 3.0, 1.0)
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
			if screen.x < -100 || screen.x > f32(window_w + 100) do continue
			if screen.y < -100 || screen.y > f32(window_h + 100) do continue

			dx := x - camera.position[0]
			dy := y - camera.position[1]
			dz := z - camera.position[2]
			depth := math.sqrt(dx * dx + dy * dy + dz * dz)
			if depth < 0.5 do continue
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

ls_anim_until:  f32 = -1
ls_cell_active: [TERM_ROWS][TERM_COLS]bool
ls_cell_timers: [TERM_ROWS][TERM_COLS]f32
ls_any_active:  bool

trigger_ls :: proc() {
	ls_anim_until = elapsed_g + 0.8
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
				ls_cell_active[r][c] = false
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
	if t < 0 do return -f32(window_w + 100), 0.5

	// Ease-out-back: natural overshoot then settle
	p := t / LS_RACE_DURATION
	c1 :: f32(1.70158)
	c3 :: c1 + 1.0
	pm1 := p - 1.0
	eased := 1.0 + c3 * pm1 * pm1 * pm1 + c1 * pm1 * pm1

	start := -f32(window_w + 100)
	dx = start * (1.0 - eased)

	if p < 0.7 {
		scale = 0.6 + p * 0.57
	} else {
		bounce := (p - 0.7) / 0.3
		scale = 1.0 + math.sin(bounce * math.PI) * 0.25
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

// ---------------------------------------------------------------------------
// Exit / Doom Drip — "GAME OVER"
// ---------------------------------------------------------------------------
//
// When "exit" is typed, the terminal freezes and melts downward in column
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
