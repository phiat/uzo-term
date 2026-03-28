package uzo_term

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:os"
import "core:strconv"
import "core:strings"
import rl "vendor:raylib"

Effect_Config :: struct {
	shake_duration: f32,
	shake_intensity: f32,
	trail_fade: f32,
	gravity_radius: f32,
	gravity_strength: f32,
	warmth_decay: f32,
	warmth_per_key: f32,
	warmth_max: f32,
	glitch_duration_max: f32,
	glitch_scatter: int,
	idle_start_delay: f32,
	idle_drift_max: f32,
	cam_duration: f32,
	explode_count: int,
	// Palette
	term_bg: rl.Color,
	fg_color: rl.Color,
	cursor_color: rl.Color,
	accent_color: rl.Color,
	scene_bg: rl.Color,
}

cfg: Effect_Config

init_config :: proc() {
	cfg = {
		shake_duration      = 0.45,
		shake_intensity     = 5.0,
		trail_fade          = 0.28,
		gravity_radius      = 90.0,
		gravity_strength    = 3.5,
		warmth_decay        = 1.4,
		warmth_per_key      = 0.14,
		warmth_max          = 1.0,
		glitch_duration_max = 0.20,
		glitch_scatter      = 22,
		idle_start_delay    = 4.0,
		idle_drift_max      = 2.6,
		cam_duration        = 1.6,
		explode_count       = 20,
		term_bg             = {0x1d, 0x1f, 0x21, 0xe0},
		fg_color            = {0xc5, 0xc8, 0xc6, 0xff},
		cursor_color        = {0xc5, 0xc8, 0xc6, 0xcc},
		accent_color        = {0xcc, 0x00, 0x00, 0xff},
		scene_bg            = {0x10, 0x10, 0x18, 0xff},
	}
}

// HSV to RGB (h: 0..360, s: 0..1, v: 0..1) → rl.Color
hsv_to_color :: proc(h, s, v: f32, a: u8 = 0xff) -> rl.Color {
	c := v * s
	hp := h / 60.0
	x := c * (1.0 - abs(math.mod(hp, 2.0) - 1.0))
	m := v - c
	r1, g1, b1: f32
	switch {
	case hp < 1: r1 = c; g1 = x; b1 = 0
	case hp < 2: r1 = x; g1 = c; b1 = 0
	case hp < 3: r1 = 0; g1 = c; b1 = x
	case hp < 4: r1 = 0; g1 = x; b1 = c
	case hp < 5: r1 = x; g1 = 0; b1 = c
	case:        r1 = c; g1 = 0; b1 = x
	}
	return {u8((r1 + m) * 255), u8((g1 + m) * 255), u8((b1 + m) * 255), a}
}

randomize_config :: proc() {
	rf :: proc(lo, hi: f32) -> f32 { return lo + rand.float32() * (hi - lo) }
	cfg.shake_duration      = rf(0.12, 1.4)
	cfg.shake_intensity     = rf(1.0, 18.0)
	cfg.trail_fade          = rf(0.06, 0.9)
	cfg.gravity_radius      = rf(25.0, 220.0)
	cfg.gravity_strength    = rf(0.5, 14.0)
	cfg.warmth_decay        = rf(0.3, 5.0)
	cfg.warmth_per_key      = rf(0.03, 0.5)
	cfg.warmth_max          = rf(0.2, 1.0)
	cfg.glitch_duration_max = rf(0.04, 0.7)
	cfg.glitch_scatter      = 4 + rand.int_max(65)
	cfg.idle_start_delay    = rf(1.0, 12.0)
	cfg.idle_drift_max      = rf(0.4, 10.0)
	cfg.cam_duration        = rf(0.4, 3.5)
	cfg.explode_count       = 4 + rand.int_max(55)

	// Random palette — pick a base hue and derive everything from it
	hue := rand.float32() * 360.0
	accent_hue := math.mod(hue + 120.0 + rand.float32() * 120.0, 360.0)

	// Dark background: low value, slight saturation tint
	cfg.term_bg  = hsv_to_color(hue, rf(0.05, 0.3), rf(0.08, 0.16), 0xe0)
	cfg.scene_bg = hsv_to_color(hue, rf(0.1, 0.4), rf(0.04, 0.10), 0xff)

	// Foreground: high value, low-medium saturation
	cfg.fg_color     = hsv_to_color(hue, rf(0.02, 0.20), rf(0.72, 0.92), 0xff)
	cfg.cursor_color = hsv_to_color(hue, rf(0.02, 0.20), rf(0.72, 0.92), 0xcc)

	// Accent: saturated, offset hue
	cfg.accent_color = hsv_to_color(accent_hue, rf(0.6, 1.0), rf(0.6, 0.9), 0xff)
}

print_config :: proc() {
	fmt.eprintln("── effect config ──")
	fmt.eprintf("  shake:    dur=%.2f  intensity=%.1f\n", cfg.shake_duration, cfg.shake_intensity)
	fmt.eprintf("  trail:    fade=%.2f\n", cfg.trail_fade)
	fmt.eprintf("  gravity:  radius=%.0f  strength=%.1f\n", cfg.gravity_radius, cfg.gravity_strength)
	fmt.eprintf("  rhythm:   decay=%.1f  per_key=%.2f  max=%.1f\n", cfg.warmth_decay, cfg.warmth_per_key, cfg.warmth_max)
	fmt.eprintf("  glitch:   dur_max=%.2f  scatter=%d\n", cfg.glitch_duration_max, cfg.glitch_scatter)
	fmt.eprintf("  idle:     delay=%.1f  drift_max=%.1f\n", cfg.idle_start_delay, cfg.idle_drift_max)
	fmt.eprintf("  cam:      duration=%.1f\n", cfg.cam_duration)
	fmt.eprintf("  explode:  count=%d\n", cfg.explode_count)
	pc :: proc(name: string, c: rl.Color) {
		fmt.eprintf("  %s: #%02x%02x%02x (a=%02x)\n", name, c.r, c.g, c.b, c.a)
	}
	pc("term_bg ", cfg.term_bg)
	pc("fg      ", cfg.fg_color)
	pc("cursor  ", cfg.cursor_color)
	pc("accent  ", cfg.accent_color)
	pc("scene_bg", cfg.scene_bg)
}

parse_config_args :: proc() {
	if len(os.args) < 2 do return
	did_rand := false
	for arg in os.args[1:] {
		if arg == "--rand" {
			randomize_config()
			did_rand = true
			continue
		}
		if !strings.has_prefix(arg, "--") do continue
		rest := arg[2:]
		eq := strings.index(rest, "=")
		if eq < 0 do continue
		name := rest[:eq]
		val_str := rest[eq + 1:]

		fval, f_ok := strconv.parse_f64(val_str)
		ival, i_ok := strconv.parse_int(val_str)

		switch name {
		case "shake-duration":
			if f_ok do cfg.shake_duration = f32(fval)
		case "shake-intensity":
			if f_ok do cfg.shake_intensity = f32(fval)
		case "trail-fade":
			if f_ok do cfg.trail_fade = f32(fval)
		case "gravity-radius":
			if f_ok do cfg.gravity_radius = f32(fval)
		case "gravity-strength":
			if f_ok do cfg.gravity_strength = f32(fval)
		case "warmth-decay":
			if f_ok do cfg.warmth_decay = f32(fval)
		case "warmth-per-key":
			if f_ok do cfg.warmth_per_key = f32(fval)
		case "warmth-max":
			if f_ok do cfg.warmth_max = f32(fval)
		case "glitch-duration":
			if f_ok do cfg.glitch_duration_max = f32(fval)
		case "glitch-scatter":
			if i_ok do cfg.glitch_scatter = ival
		case "idle-delay":
			if f_ok do cfg.idle_start_delay = f32(fval)
		case "idle-drift":
			if f_ok do cfg.idle_drift_max = f32(fval)
		case "cam-duration":
			if f_ok do cfg.cam_duration = f32(fval)
		case "explode-count":
			if i_ok do cfg.explode_count = ival
		case:
			fmt.eprintf("unknown effect param: --%s\n", name)
		}
	}
	if did_rand {
		print_config()
	}
}
