package uzo_term

import "core:math/rand"
import rl "vendor:raylib"

// Shared rising-particle pool used by the forge (build commands), kill
// smoke, the clear "whoosh-out", and the grep laser sparks. One pool
// keeps the per-frame update loop simple and bounds the total particle
// budget. Per-effect emitters live in their own files.

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
