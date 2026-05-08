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
	// Boot CRT flash
	boot_duration: f32,
	// PWD-tinted scene
	pwd_hue_lerp_rate: f32,
	pwd_tint_bg: f32,
	pwd_tint_cube: f32,
	// Forge sparks (build commands)
	forge_duration: f32,
	forge_emit_rate: f32,
	// Kill smoke plume
	smoke_count: int,
	smoke_spread: f32, // in cell-widths
	// Enter shockwave
	shockwave_duration: f32,
	shockwave_amp: f32,
	shockwave_sigma: f32,
	shockwave_wavelength: f32,
	// Drum (alt-screen TUI cylinder)
	drum_tumble_duration: f32,
	drum_base_spin: f32,
	drum_density_gain: f32,
	drum_radius: f32,
	drum_length: f32,
	drum_drag_sensitivity: f32, // rad per pixel of mouse-Y drag
	// Clear whoosh-out
	whoosh_speed_min: f32,
	whoosh_speed_max: f32,
	// Z-emerge — newly-dirty rows tween in from depth
	emerge_duration: f32,
	emerge_rise_px:  f32,
	emerge_scale_min: f32,
	// Grep laser sweep
	laser_duration: f32,
	laser_speed:    f32, // pixels per second
	laser_lock_hold: f32,
	// Mouse field (repel-on-motion, attract-on-dwell)
	mouse_field_enabled:          bool,
	mouse_field_repel_strength:   f32,
	mouse_field_attract_strength: f32,
	mouse_field_repel_radius:     f32,
	mouse_field_attract_radius:   f32,
	mouse_field_dwell_seconds:    f32,
	mouse_field_smoothing:        f32, // higher = faster mode flip
	// Error gutter quake (per-row shake on error keywords at col 0)
	error_quake_enabled:  bool,
	error_quake_duration: f32,
	error_quake_amp:      f32, // pixels
	error_quake_freq:     f32, // rad/s
	// Prompt rise (row rises from below after PTY goes quiet)
	prompt_rise_enabled:    bool,
	prompt_rise_quiet_secs: f32, // PTY-quiet threshold before firing
	prompt_rise_duration:   f32,
	prompt_rise_offset_px:  f32,
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
		shake_duration       = 0.45,
		shake_intensity      = 5.0,
		trail_fade           = 0.28,
		gravity_radius       = 90.0,
		gravity_strength     = 3.5,
		warmth_decay         = 1.4,
		warmth_per_key       = 0.14,
		warmth_max           = 1.0,
		glitch_duration_max  = 0.20,
		glitch_scatter       = 22,
		idle_start_delay     = 4.0,
		idle_drift_max       = 2.6,
		cam_duration         = 1.6,
		explode_count        = 20,
		boot_duration        = 0.85,
		pwd_hue_lerp_rate    = 4.0,
		pwd_tint_bg          = 0.10,
		pwd_tint_cube        = 0.30,
		forge_duration       = 7.0,
		forge_emit_rate      = 28.0,
		smoke_count          = 36,
		smoke_spread         = 5.0,
		shockwave_duration   = 0.45,
		shockwave_amp        = 8.0,
		shockwave_sigma      = 2.5,
		shockwave_wavelength = 3.0,
		drum_tumble_duration = 0.45,
		drum_base_spin       = 0.18,
		drum_density_gain    = 0.045,
		drum_radius           = 4.32,
		drum_length           = 8.1,
		drum_drag_sensitivity = 0.012,
		whoosh_speed_min     = 220.0,
		whoosh_speed_max     = 500.0,
		emerge_duration      = 0.32,
		emerge_rise_px       = 14.0,
		emerge_scale_min     = 0.55,
		laser_duration       = 2.5,
		laser_speed          = 450.0,
		laser_lock_hold      = 0.35,
		mouse_field_enabled          = true,
		mouse_field_repel_strength   = 6.75,
		mouse_field_attract_strength = 2.2,
		mouse_field_repel_radius     = 120.0,
		mouse_field_attract_radius   = 396.0,
		mouse_field_dwell_seconds    = 2.0,
		mouse_field_smoothing        = 2.5,
		error_quake_enabled  = true,
		error_quake_duration = 0.30,
		error_quake_amp      = 4.0,
		error_quake_freq     = 95.0,
		prompt_rise_enabled    = true,
		prompt_rise_quiet_secs = 0.06,
		prompt_rise_duration   = 0.18,
		prompt_rise_offset_px  = 30.0,
		term_bg              = {0x1d, 0x1f, 0x21, 0xe0},
		fg_color             = {0xc5, 0xc8, 0xc6, 0xff},
		cursor_color         = {0xc5, 0xc8, 0xc6, 0xcc},
		accent_color         = {0xcc, 0x00, 0x00, 0xff},
		scene_bg             = {0x10, 0x10, 0x18, 0xff},
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
	cfg.shake_duration       = rf(0.12, 1.4)
	cfg.shake_intensity      = rf(1.0, 18.0)
	cfg.trail_fade           = rf(0.06, 0.9)
	cfg.gravity_radius       = rf(25.0, 220.0)
	cfg.gravity_strength     = rf(0.5, 14.0)
	cfg.warmth_decay         = rf(0.3, 5.0)
	cfg.warmth_per_key       = rf(0.03, 0.5)
	cfg.warmth_max           = rf(0.2, 1.0)
	cfg.glitch_duration_max  = rf(0.04, 0.7)
	cfg.glitch_scatter       = 4 + rand.int_max(65)
	cfg.idle_start_delay     = rf(1.0, 12.0)
	cfg.idle_drift_max       = rf(0.4, 10.0)
	cfg.cam_duration         = rf(0.4, 3.5)
	cfg.explode_count        = 4 + rand.int_max(55)
	cfg.boot_duration        = rf(0.4, 1.6)
	cfg.pwd_hue_lerp_rate    = rf(1.0, 9.0)
	cfg.pwd_tint_bg          = rf(0.0, 0.25)
	cfg.pwd_tint_cube        = rf(0.05, 0.55)
	cfg.forge_duration       = rf(3.0, 12.0)
	cfg.forge_emit_rate      = rf(12.0, 55.0)
	cfg.smoke_count          = 14 + rand.int_max(45)
	cfg.smoke_spread         = rf(2.0, 8.0)
	cfg.shockwave_duration   = rf(0.20, 0.90)
	cfg.shockwave_amp        = rf(2.0, 18.0)
	cfg.shockwave_sigma      = rf(1.0, 5.0)
	cfg.shockwave_wavelength = rf(1.5, 6.0)
	cfg.drum_tumble_duration = rf(0.20, 1.10)
	cfg.drum_base_spin       = rf(0.04, 0.70)
	cfg.drum_density_gain    = rf(0.005, 0.12)
	cfg.drum_radius           = rf(2.0, 4.5)
	cfg.drum_length           = rf(5.0, 11.0)
	// drum_drag_sensitivity stays at default — randomization unhelpful here
	cfg.whoosh_speed_min     = rf(120.0, 280.0)
	cfg.whoosh_speed_max     = cfg.whoosh_speed_min + rf(80.0, 360.0)
	cfg.emerge_duration      = rf(0.18, 0.65)
	cfg.emerge_rise_px       = rf(4.0, 30.0)
	cfg.emerge_scale_min     = rf(0.30, 0.85)
	cfg.laser_duration       = rf(3.0, 9.0)
	cfg.laser_speed          = rf(180.0, 900.0)
	cfg.laser_lock_hold      = rf(0.20, 0.70)
	cfg.mouse_field_repel_strength   = rf(2.0, 8.0)
	cfg.mouse_field_attract_strength = rf(1.0, 4.0)
	cfg.mouse_field_repel_radius     = rf(70.0, 180.0)
	cfg.mouse_field_attract_radius   = rf(180.0, 380.0)
	cfg.mouse_field_dwell_seconds    = rf(0.8, 2.4)
	cfg.mouse_field_smoothing        = rf(1.5, 4.0)
	cfg.error_quake_duration = rf(0.18, 0.55)
	cfg.error_quake_amp      = rf(2.0, 8.0)
	cfg.error_quake_freq     = rf(60.0, 140.0)
	cfg.prompt_rise_quiet_secs = rf(0.04, 0.12)
	cfg.prompt_rise_duration   = rf(0.12, 0.30)
	cfg.prompt_rise_offset_px  = rf(14.0, 50.0)

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
	fmt.eprintf("  shake:     dur=%.2f  intensity=%.1f\n", cfg.shake_duration, cfg.shake_intensity)
	fmt.eprintf("  trail:     fade=%.2f\n", cfg.trail_fade)
	fmt.eprintf("  gravity:   radius=%.0f  strength=%.1f\n", cfg.gravity_radius, cfg.gravity_strength)
	fmt.eprintf("  rhythm:    decay=%.1f  per_key=%.2f  max=%.1f\n", cfg.warmth_decay, cfg.warmth_per_key, cfg.warmth_max)
	fmt.eprintf("  glitch:    dur_max=%.2f  scatter=%d\n", cfg.glitch_duration_max, cfg.glitch_scatter)
	fmt.eprintf("  idle:      delay=%.1f  drift_max=%.1f\n", cfg.idle_start_delay, cfg.idle_drift_max)
	fmt.eprintf("  cam:       duration=%.1f\n", cfg.cam_duration)
	fmt.eprintf("  explode:   count=%d\n", cfg.explode_count)
	fmt.eprintf("  boot:      duration=%.2f\n", cfg.boot_duration)
	fmt.eprintf("  pwd:       hue_lerp=%.2f  tint_bg=%.2f  tint_cube=%.2f\n",
		cfg.pwd_hue_lerp_rate, cfg.pwd_tint_bg, cfg.pwd_tint_cube)
	fmt.eprintf("  forge:     duration=%.1f  emit_rate=%.1f\n", cfg.forge_duration, cfg.forge_emit_rate)
	fmt.eprintf("  smoke:     count=%d  spread=%.1f\n", cfg.smoke_count, cfg.smoke_spread)
	fmt.eprintf("  shockwave: dur=%.2f  amp=%.1f  sigma=%.1f  wavelength=%.1f\n",
		cfg.shockwave_duration, cfg.shockwave_amp, cfg.shockwave_sigma, cfg.shockwave_wavelength)
	fmt.eprintf("  drum:      tumble=%.2f  spin=%.2f  density_gain=%.3f  r=%.2f  len=%.2f\n",
		cfg.drum_tumble_duration, cfg.drum_base_spin, cfg.drum_density_gain,
		cfg.drum_radius, cfg.drum_length)
	fmt.eprintf("  whoosh:    speed=%.0f..%.0f\n", cfg.whoosh_speed_min, cfg.whoosh_speed_max)
	fmt.eprintf("  emerge:    dur=%.2f  rise=%.1f  scale_min=%.2f\n",
		cfg.emerge_duration, cfg.emerge_rise_px, cfg.emerge_scale_min)
	fmt.eprintf("  laser:     dur=%.2f  speed=%.0f  lock_hold=%.2f\n",
		cfg.laser_duration, cfg.laser_speed, cfg.laser_lock_hold)
	fmt.eprintf("  mouse:     repel(s=%.1f r=%.0f)  attract(s=%.1f r=%.0f)  dwell=%.2f  smooth=%.2f  on=%v\n",
		cfg.mouse_field_repel_strength, cfg.mouse_field_repel_radius,
		cfg.mouse_field_attract_strength, cfg.mouse_field_attract_radius,
		cfg.mouse_field_dwell_seconds, cfg.mouse_field_smoothing, cfg.mouse_field_enabled)
	fmt.eprintf("  err-quake: dur=%.2f  amp=%.1f  freq=%.0f  on=%v\n",
		cfg.error_quake_duration, cfg.error_quake_amp, cfg.error_quake_freq, cfg.error_quake_enabled)
	fmt.eprintf("  prompt:    rise quiet=%.2f  dur=%.2f  offset=%.0f  on=%v\n",
		cfg.prompt_rise_quiet_secs, cfg.prompt_rise_duration, cfg.prompt_rise_offset_px, cfg.prompt_rise_enabled)
	pc :: proc(name: string, c: rl.Color) {
		fmt.eprintf("  %s: #%02x%02x%02x (a=%02x)\n", name, c.r, c.g, c.b, c.a)
	}
	pc("term_bg  ", cfg.term_bg)
	pc("fg       ", cfg.fg_color)
	pc("cursor   ", cfg.cursor_color)
	pc("accent   ", cfg.accent_color)
	pc("scene_bg ", cfg.scene_bg)
}

print_help :: proc() {
	fmt.eprintln("uzo-term — graphical terminal with effects")
	fmt.eprintln()
	fmt.eprintln("Usage: uzo-term [flags]")
	fmt.eprintln()
	fmt.eprintln("Flags:")
	fmt.eprintln("  --help              Show this help and exit")
	fmt.eprintln("  --rand              Randomize all effect tunables (and print them)")
	fmt.eprintln("  --no-rpg            Disable the RPG layer (default: on; F9 toggles at runtime)")
	fmt.eprintln("  --rpg-reset         Clear RPG state on launch")
	fmt.eprintln("  --rpg-class=NAME    Pin class: drifter|cowboy|spider|wizard|operator|icebreaker")
	fmt.eprintln("  --no-mouse-field    Disable mouse repel/attract field")
	fmt.eprintln("  --no-error-quake    Disable per-row shake on error keywords")
	fmt.eprintln("  --no-prompt-rise    Disable prompt-rise-from-below effect")
	fmt.eprintln()
	fmt.eprintln("Per-param overrides (--name=value):")
	fmt.eprintln("  shake-duration, shake-intensity")
	fmt.eprintln("  trail-fade")
	fmt.eprintln("  gravity-radius, gravity-strength")
	fmt.eprintln("  warmth-decay, warmth-per-key, warmth-max")
	fmt.eprintln("  glitch-duration, glitch-scatter")
	fmt.eprintln("  idle-delay, idle-drift")
	fmt.eprintln("  cam-duration")
	fmt.eprintln("  explode-count")
	fmt.eprintln("  boot-duration")
	fmt.eprintln("  pwd-hue-lerp, pwd-tint-bg, pwd-tint-cube")
	fmt.eprintln("  forge-duration, forge-emit-rate")
	fmt.eprintln("  smoke-count, smoke-spread")
	fmt.eprintln("  shockwave-duration, shockwave-amp, shockwave-sigma, shockwave-wavelength")
	fmt.eprintln("  drum-tumble, drum-spin, drum-density-gain, drum-radius, drum-length, drum-drag")
	fmt.eprintln("  whoosh-speed-min, whoosh-speed-max")
	fmt.eprintln("  emerge-duration, emerge-rise, emerge-scale-min")
	fmt.eprintln("  laser-duration, laser-speed, laser-lock-hold")
	fmt.eprintln("  mouse-field-repel-strength, mouse-field-attract-strength")
	fmt.eprintln("  mouse-field-repel-radius, mouse-field-attract-radius")
	fmt.eprintln("  mouse-field-dwell, mouse-field-smoothing")
	fmt.eprintln()
	fmt.eprintln("Examples:")
	fmt.eprintln("  uzo-term --rand")
	fmt.eprintln("  uzo-term --shake-intensity=12 --pwd-tint-cube=0.5")
}

parse_config_args :: proc() {
	if len(os.args) < 2 do return
	did_rand := false
	for arg in os.args[1:] {
		if arg == "--help" || arg == "-h" {
			print_help()
			os.exit(0)
		}
		if arg == "--rand" {
			randomize_config()
			did_rand = true
			continue
		}
		// Boolean / no-value RPG flags handled before the --name=value parser.
		if arg == "--no-rpg" {
			rpg_active = false
			continue
		}
		if arg == "--rpg-reset" {
			rpg_reset()
			continue
		}
		if arg == "--no-mouse-field" {
			cfg.mouse_field_enabled = false
			continue
		}
		if arg == "--no-error-quake" {
			cfg.error_quake_enabled = false
			continue
		}
		if arg == "--no-prompt-rise" {
			cfg.prompt_rise_enabled = false
			continue
		}
		if !strings.has_prefix(arg, "--") {
			fmt.eprintf("ignored arg (expected --name=value): %s\n", arg)
			continue
		}
		rest := arg[2:]
		eq := strings.index(rest, "=")
		if eq < 0 {
			fmt.eprintf("malformed flag (expected --name=value): %s\n", arg)
			continue
		}
		name := rest[:eq]
		val_str := rest[eq + 1:]

		// String-valued flags routed before the numeric switch.
		if name == "rpg-class" {
			if !rpg_set_class_by_name(val_str) {
				fmt.eprintf("unknown class for --rpg-class: %s (drifter|cowboy|spider|wizard|operator|icebreaker)\n", val_str)
			}
			continue
		}

		fval, f_ok := strconv.parse_f64(val_str)
		ival, i_ok := strconv.parse_int(val_str)

		switch name {
		case "shake-duration":       if f_ok do cfg.shake_duration       = f32(fval)
		case "shake-intensity":      if f_ok do cfg.shake_intensity      = f32(fval)
		case "trail-fade":           if f_ok do cfg.trail_fade           = f32(fval)
		case "gravity-radius":       if f_ok do cfg.gravity_radius       = f32(fval)
		case "gravity-strength":     if f_ok do cfg.gravity_strength     = f32(fval)
		case "warmth-decay":         if f_ok do cfg.warmth_decay         = f32(fval)
		case "warmth-per-key":       if f_ok do cfg.warmth_per_key       = f32(fval)
		case "warmth-max":           if f_ok do cfg.warmth_max           = f32(fval)
		case "glitch-duration":      if f_ok do cfg.glitch_duration_max  = f32(fval)
		case "glitch-scatter":       if i_ok do cfg.glitch_scatter       = ival
		case "idle-delay":           if f_ok do cfg.idle_start_delay     = f32(fval)
		case "idle-drift":           if f_ok do cfg.idle_drift_max       = f32(fval)
		case "cam-duration":         if f_ok do cfg.cam_duration         = f32(fval)
		case "explode-count":        if i_ok do cfg.explode_count        = ival
		case "boot-duration":        if f_ok do cfg.boot_duration        = f32(fval)
		case "pwd-hue-lerp":         if f_ok do cfg.pwd_hue_lerp_rate    = f32(fval)
		case "pwd-tint-bg":          if f_ok do cfg.pwd_tint_bg          = f32(fval)
		case "pwd-tint-cube":        if f_ok do cfg.pwd_tint_cube        = f32(fval)
		case "forge-duration":       if f_ok do cfg.forge_duration       = f32(fval)
		case "forge-emit-rate":      if f_ok do cfg.forge_emit_rate      = f32(fval)
		case "smoke-count":          if i_ok do cfg.smoke_count          = ival
		case "smoke-spread":         if f_ok do cfg.smoke_spread         = f32(fval)
		case "shockwave-duration":   if f_ok do cfg.shockwave_duration   = f32(fval)
		case "shockwave-amp":        if f_ok do cfg.shockwave_amp        = f32(fval)
		case "shockwave-sigma":      if f_ok do cfg.shockwave_sigma      = f32(fval)
		case "shockwave-wavelength": if f_ok do cfg.shockwave_wavelength = f32(fval)
		case "drum-tumble":          if f_ok do cfg.drum_tumble_duration = f32(fval)
		case "drum-spin":            if f_ok do cfg.drum_base_spin       = f32(fval)
		case "drum-density-gain":    if f_ok do cfg.drum_density_gain    = f32(fval)
		case "drum-radius":          if f_ok do cfg.drum_radius           = f32(fval)
		case "drum-length":          if f_ok do cfg.drum_length           = f32(fval)
		case "drum-drag":            if f_ok do cfg.drum_drag_sensitivity = f32(fval)
		case "whoosh-speed-min":     if f_ok do cfg.whoosh_speed_min     = f32(fval)
		case "whoosh-speed-max":     if f_ok do cfg.whoosh_speed_max     = f32(fval)
		case "emerge-duration":      if f_ok do cfg.emerge_duration      = f32(fval)
		case "emerge-rise":          if f_ok do cfg.emerge_rise_px       = f32(fval)
		case "emerge-scale-min":     if f_ok do cfg.emerge_scale_min     = f32(fval)
		case "laser-duration":       if f_ok do cfg.laser_duration       = f32(fval)
		case "laser-speed":          if f_ok do cfg.laser_speed          = f32(fval)
		case "laser-lock-hold":      if f_ok do cfg.laser_lock_hold      = f32(fval)
		case "mouse-field-repel-strength":   if f_ok do cfg.mouse_field_repel_strength   = f32(fval)
		case "mouse-field-attract-strength": if f_ok do cfg.mouse_field_attract_strength = f32(fval)
		case "mouse-field-repel-radius":     if f_ok do cfg.mouse_field_repel_radius     = f32(fval)
		case "mouse-field-attract-radius":   if f_ok do cfg.mouse_field_attract_radius   = f32(fval)
		case "mouse-field-dwell":            if f_ok do cfg.mouse_field_dwell_seconds    = f32(fval)
		case "mouse-field-smoothing":        if f_ok do cfg.mouse_field_smoothing        = f32(fval)
		case "error-quake-duration": if f_ok do cfg.error_quake_duration = f32(fval)
		case "error-quake-amp":      if f_ok do cfg.error_quake_amp      = f32(fval)
		case "error-quake-freq":     if f_ok do cfg.error_quake_freq     = f32(fval)
		case "prompt-rise-quiet":    if f_ok do cfg.prompt_rise_quiet_secs = f32(fval)
		case "prompt-rise-duration": if f_ok do cfg.prompt_rise_duration   = f32(fval)
		case "prompt-rise-offset":   if f_ok do cfg.prompt_rise_offset_px  = f32(fval)
		case:
			fmt.eprintf("unknown effect param: --%s (try --help)\n", name)
		}
	}
	if did_rand {
		print_config()
	}
}
