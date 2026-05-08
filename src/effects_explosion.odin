package uzo_term

import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

// Enter explosion — pressing Enter scatters glyph particles outward from
// the cursor's row, falling under gravity. A small one-shot burst tied to
// command submission.

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
