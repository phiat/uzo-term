package uzo_term

import "core:math"
import rl "vendor:raylib"

// Spinning drum (alt-screen — TUI wraps around a horizontal cylinder).
//
// While the alt-screen is active (htop, vim, less, …) the terminal lifts off
// the flat plane and wraps around a cylinder laid on its side. Spin rate
// scales with smoothed dirty-row count (htop redraws fast → fast spin; idle
// vim → glide). Tumbles in/out over ~0.45 s as the screen toggles. A pause
// button overlay in the upper-right toggles auto-spin; left-button drag
// rotates manually.

DRUM_SLICES :: i32(64)

drum_mesh:   rl.Mesh
drum_model:  rl.Model
drum_loaded: bool

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

// Multiplier for "loud" cell-level effects (gravity pull, idle drift,
// shockwave, emerge tween, ls race-in, glitch scatter). Drops from 1.0
// when flat to 0.25 when the drum is fully up — keeps the wrapped TUI
// legible on the cylinder surface without disabling the effects entirely.
cell_effect_scale :: proc() -> f32 {
	return 1.0 - drum_t * 0.75
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
