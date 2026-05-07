package uzo_term

import "core:math"
import "core:math/rand"
import gvt "ghosdin:vendor/ghostty_vt"
import rl "vendor:raylib"

// Shared rising particle pool used by the forge (build commands), kill
// smoke, the clear "whoosh-out", and the grep laser sparks. One pool keeps
// the per-frame update loop simple and bounds the total particle budget.

// ---------------------------------------------------------------------------
// Pool
// ---------------------------------------------------------------------------

Rising_Kind :: enum {
	EMBER,  // forge — bright orange spark rising fast
	SMOKE,  // kill — soft grey expanding cloud rising slow
	WHOOSH, // clear — glyph flung radially outward from screen center
	LASER,  // grep match — hot white-pink quick spark
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
	case .LASER:
		p.vel = {(rand.float32() - 0.5) * 90, -50 - rand.float32() * 110}
		p.life = 0.45 + rand.float32() * 0.35
		p.radius_base = 1.4 + rand.float32() * 1.4
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
		case .EMBER, .SMOKE, .LASER:
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
		case .LASER:
			a := u8(255.0 * t)
			radius := p.radius_base * (0.6 + 0.4 * t)
			rl.DrawCircleV(p.pos, radius, {255, 220, 210, a})
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
