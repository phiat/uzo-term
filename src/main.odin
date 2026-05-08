package uzo_term

// uzo-term — graphical terminal with render-texture pipeline, 3D camera,
// and post-processing shaders.  Built on ghostty-vt + raylib.
//
// Everything is drawn to a RenderTexture2D first, then composited to
// screen through a shader pass (shimmer by default).  A 3D camera draws
// a background scene; the terminal is overlaid in 2D.

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:math"
import "core:strings"
import "core:sys/posix"
import p "ghosdin:pty"
import r "ghosdin:render_rl"
import gvt "ghosdin:vendor/ghostty_vt"
import rl "vendor:raylib"

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------

TERM_COLS :: 100
TERM_ROWS :: 35
DEFAULT_FONT_SIZE :: 16
MAX_SCROLLBACK :: 5000
PADDING :: 4
FONT_SIZE_MIN :: 8
FONT_SIZE_MAX :: 40

// ---------------------------------------------------------------------------
// Palette
// ---------------------------------------------------------------------------

// Default palette lives in config.odin (cfg.term_bg, cfg.fg_color, etc.)

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

gterm:         gvt.Term
pty:           p.Pty
font:          rl.Font
read_buf:      [65536]u8
session_ended: bool


// Font scaling state
font_size: i32 = DEFAULT_FONT_SIZE
cell_w: i32 = 9
cell_h: i32 = 18
window_w: i32
window_h: i32
font_path: cstring // remember which path worked for reloads

// Render-texture + shader state
target: rl.RenderTexture2D
term_target: rl.RenderTexture2D // terminal-only RT (texture source for the drum)
shader: rl.Shader
time_loc: rl.ShaderLocationIndex
resolution_loc: rl.ShaderLocationIndex

// Cursor state (globals so effects.odin can read them)
cursor_x_g:       u16
cursor_y_g:       u16
cursor_visible_g: bool

// Input line buffer for command detection (sudo, etc.)
input_line:     [256]u8
input_line_len: int

// Last rendered cursor row text (captures tab-completed content)
cursor_row_buf: [256]u8
cursor_row_len: int

// 3D camera
camera: rl.Camera3D

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

main :: proc() {
	// -- Effect config (before anything else so --rand seeds early) --
	init_config()
	init_rpg()
	parse_config_args()

	// -- Init ghostty-vt terminal (wrapper handles render-state alloc + teardown atomically) --
	t, terr := gvt.term_init(TERM_COLS, TERM_ROWS, MAX_SCROLLBACK)
	if terr != .None {
		fmt.eprintln("Failed to create terminal:", terr)
		return
	}
	gterm = t
	defer gvt.term_destroy(&gterm)

	// Install write_pty callback
	write_pty_cb :: proc "c" (
		_terminal: gvt.Terminal,
		userdata: rawptr,
		data: [^]u8,
		length: c.size_t,
	) {
		context = #force_no_inline runtime.default_context()
		pt := cast(^p.Pty)userdata
		p.write_bytes(pt, data[:length])
	}
	gvt.term_set(&gterm, .WRITE_PTY, rawptr(write_pty_cb))
	gvt.term_set(&gterm, .USERDATA, rawptr(&pty))

	// Device attributes callback — vim sends CSI c to query this
	da_cb :: proc "c" (
		_terminal: gvt.Terminal,
		_userdata: rawptr,
		out_attrs: ^gvt.Device_Attributes,
	) -> bool {
		out_attrs.primary.conformance_level = 4 // VT400
		out_attrs.primary.num_features = 0
		out_attrs.secondary.device_type = 0
		out_attrs.secondary.firmware_version = 1
		out_attrs.secondary.rom_cartridge = 0
		out_attrs.tertiary.unit_id = 0
		return true
	}
	gvt.term_set(&gterm, .DEVICE_ATTRIBUTES, rawptr(da_cb))

	// Size callback — vim sends CSI 14/18 t to query terminal size
	size_cb :: proc "c" (
		_terminal: gvt.Terminal,
		_userdata: rawptr,
		out_size: ^gvt.Size_Report_Size,
	) -> bool {
		out_size.rows = TERM_ROWS
		out_size.columns = TERM_COLS
		out_size.cell_width = u32(cell_w)
		out_size.cell_height = u32(cell_h)
		return true
	}
	gvt.term_set(&gterm, .SIZE, rawptr(size_cb))

	if rerr := gvt.term_ensure_render(&gterm); rerr != .None {
		fmt.eprintln("Failed to allocate render state:", rerr)
		return
	}

	// -- Spawn PTY --
	shell := p.get_default_shell()
	ok: bool
	pty, ok = p.spawn(shell, TERM_COLS, TERM_ROWS)
	if !ok {
		fmt.eprintln("Failed to spawn PTY")
		return
	}
	defer p.destroy(&pty)
	p.resize(&pty, TERM_COLS, TERM_ROWS)

	// -- Init raylib --
	window_w = TERM_COLS * cell_w + PADDING * 2
	window_h = TERM_ROWS * cell_h + PADDING * 2
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(window_w, window_h, "uzo-term")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	// Load monospace font — prefer JetBrains Mono NF
	load_font()
	defer rl.UnloadFont(font)

	// -- Render textures (terminal first, then composite) --
	target = rl.LoadRenderTexture(window_w, window_h)
	defer rl.UnloadRenderTexture(target)
	term_target = rl.LoadRenderTexture(window_w, window_h)
	defer rl.UnloadRenderTexture(term_target)

	// -- Drum mesh (cylinder for alt-screen TUI) --
	init_drum()
	defer destroy_drum()

	// -- Post-processing shader --
	shader = rl.LoadShader(nil, "shaders/shimmer.fs")
	defer rl.UnloadShader(shader)
	time_loc = auto_cast rl.GetShaderLocation(shader, "time")
	resolution_loc = auto_cast rl.GetShaderLocation(shader, "resolution")
	update_resolution()

	// -- 3D camera --
	camera = rl.Camera3D {
		position   = {0, 5, 10},
		target     = {0, 0, 0},
		up         = {0, 1, 0},
		fovy       = 45,
		projection = .PERSPECTIVE,
	}

	// -- Main loop --
	for !rl.WindowShouldClose() {
		if exit_active {
			dt := rl.GetFrameTime()
			exit_timer += dt

			if exit_phase == 0 {
				// Grace period — keep rendering so "exit" appears in terminal
				pump_pty()
				draw_frame()
				if exit_timer > 0.2 {
					exit_phase = 1
					exit_timer = 0
					init_exit_drip()
				}
			} else {
				if !update_exit_drip() do break
				draw_exit_drip()
			}
		} else {
			pump_pty()
			handle_input()
			handle_hyperlink_click()
			handle_drum_drag()
			draw_frame()
		}
	}
}

// ---------------------------------------------------------------------------
// PTY I/O
// ---------------------------------------------------------------------------

pump_pty :: proc() {
	if session_ended do return
	data, eof := p.drain(&pty, read_buf[:])
	if len(data) > 0 {
		gvt.term_write_bytes(&gterm, data)
		trigger_glitch()
	}
	if eof do session_ended = true
}

// ---------------------------------------------------------------------------
// Keyboard Input
// ---------------------------------------------------------------------------

handle_input :: proc() {
	for {
		ch := rl.GetCharPressed()
		if ch == 0 do break
		buf: [4]u8
		n := r.encode_utf8(buf[:], ch)
		p.write_bytes(&pty, buf[:n])
		on_keypress_rhythm()
		on_rpg_keypress(ch)
		reset_idle()
		trigger_key_drop(ch)
		push_trail_point(
			f32(cursor_x_g) * f32(cell_w) + PADDING,
			f32(cursor_y_g) * f32(cell_h) + PADDING,
		)
		// Append printable ASCII to input line for command detection
		if ch < 128 && input_line_len < len(input_line) - 1 {
			input_line[input_line_len] = u8(ch)
			input_line_len += 1
		}
	}

	for {
		key := rl.GetKeyPressed()
		if key == .KEY_NULL do break

		ctrl := rl.IsKeyDown(.LEFT_CONTROL) || rl.IsKeyDown(.RIGHT_CONTROL)

		// Ctrl+/- for font zoom
		if ctrl {
			if key == .EQUAL || key == .KP_ADD { 	// = / + key
				change_font_size(2)
				continue
			}
			if key == .MINUS || key == .KP_SUBTRACT {
				change_font_size(-2)
				continue
			}
			if key == .ZERO { 	// Ctrl+0 resets
				font_size = DEFAULT_FONT_SIZE
				apply_font_size()
				continue
			}
		}

		shift := rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)

		// F9 toggles the RPG layer at runtime (state is preserved).
		if key == .F9 {
			rpg_active = !rpg_active
			continue
		}

		// Ctrl+Shift+V: paste from system clipboard via libghostty-vt's encoder
		// (handles bracketed-paste wrapping + unsafe byte stripping).
		if ctrl && shift && key == .V {
			paste_clipboard()
			continue
		}

		// Enter has uzo-term-specific side effects (effects + command detection)
		// before the VT sequence is sent; keep that case inline.
		if key == .ENTER {
			trigger_shake()
			trigger_explosion()
			trigger_shockwave()
			reset_idle()
			handle_command_line()
			input_line_len = 0
			p.write_string(&pty, "\r")
			continue
		}
		if key == .BACKSPACE {
			if input_line_len > 0 do input_line_len -= 1
			p.write_string(&pty, "\x7f")
			continue
		}

		if seq := r.key_to_vt_sequence(key); seq != "" {
			p.write_string(&pty, seq)
			continue
		}
		if ctrl {
			if b, ok := r.ctrl_byte(key); ok {
				p.write_byte(&pty, b)
				if key == .C {
					trigger_smoke()
				} else if key == .L {
					trigger_whoosh()
				}
			}
		}
	}
}

// Inspect the just-submitted input line for `sudo` / `cd` / `ls` / `exit`
// triggers before clearing the buffer. Pulled out of `handle_input` so the
// switch above stays focused on key→VT-sequence mapping.
handle_command_line :: proc() {
	line := string(input_line[:input_line_len])
	// History recall (Up-arrow) doesn't populate input_line, so fall back to
	// the cursor row with the shell prompt stripped. Catches re-runs that
	// would otherwise miss every command-detection trigger.
	if input_line_len == 0 {
		line = strip_prompt(string(cursor_row_buf[:cursor_row_len]))
	}
	on_rpg_command(line)
	if contains(line, "sudo") {
		on_sudo_detected()
	} else if len(line) > 0 {
		on_sudo_cleared()
	}
	if is_build_command(line) {
		trigger_forge()
	}
	if is_kill_command(line) {
		trigger_smoke()
	}
	if line == "clear" || line == "reset" {
		trigger_whoosh()
	}
	if is_search_command(line) {
		needle, ok := extract_search_needle(line)
		if ok && len(needle) > 0 {
			trigger_search(needle)
		}
	}
	if len(line) >= 2 && line[:2] == "cd" && (len(line) == 2 || line[2] == ' ') {
		dir := "~"
		row_text := string(cursor_row_buf[:cursor_row_len])
		cd_pos := -1
		for i in 0 ..= max(0, len(row_text) - 3) {
			if row_text[i:i + 3] == "cd " {
				cd_pos = i + 3
			}
		}
		if cd_pos >= 0 && cd_pos < len(row_text) {
			end := len(row_text)
			for end > cd_pos && row_text[end - 1] == ' ' do end -= 1
			if end > cd_pos do dir = row_text[cd_pos:end]
		} else if len(line) > 3 {
			dir = line[3:]
		}
		trigger_cd_fly(dir)
	}
	if len(line) >= 2 && line[:2] == "ls" && (len(line) == 2 || line[2] == ' ') {
		trigger_ls()
	}
	if line == "exit" {
		trigger_exit()
	}
}

// ---------------------------------------------------------------------------
// Rendering
// ---------------------------------------------------------------------------

draw_frame :: proc() {
	elapsed := f32(rl.GetTime())
	elapsed_g = elapsed // shared with effects

	dt := rl.GetFrameTime()
	update_idle()
	update_rpg(dt)
	update_camera_fly()
	update_pwd_tint(dt)
	update_forge(dt)
	update_shockwave(dt)

	// Drum (alt-screen) tumble + spin
	drum_set_alt(gvt.term_active_screen(&gterm) == .ALTERNATE)
	update_drum(dt)

	fly := cam_fly_intensity()
	term_bg_alpha := u8(f32(cfg.term_bg.a) * (1.0 - fly * 0.92))
	bg_tinted := pwd_tint(cfg.term_bg, cfg.pwd_tint_bg)

	// ── Pass 1a: render terminal cells to term_target (texture source for drum) ──
	rl.BeginTextureMode(term_target)
	rl.ClearBackground(rl.BLANK)
	rl.DrawRectangle(0, 0, window_w, window_h, {bg_tinted.r, bg_tinted.g, bg_tinted.b, term_bg_alpha})

	if gvt.term_render_update(&gterm) != .None {
		rl.EndTextureMode()
		draw_pass1b(elapsed)
		draw_pass2(elapsed)
		return
	}

	colors, _ := gvt.term_render_colors(&gterm)
	cursor := gvt.term_render_cursor(&gterm)
	cursor_x_g = cursor.x
	cursor_y_g = cursor.y
	cursor_visible_g = cursor.visible && cursor.in_viewport

	cursor_row_len = 0
	row_iter_h := gvt.term_row_iterator(&gterm)
	row_cells_h := gvt.term_row_cells_handle(&gterm)
	row_it := gvt.term_render_rows(&gterm)
	for row in gvt.render_row_next(&row_it) {
		dirty_row: bool
		if gvt.render_state_row_get(row_iter_h, .DIRTY, &dirty_row) == .SUCCESS && dirty_row {
			mark_row_born(row)
			mark_ls_row(row)
			drum_dirty_rows += 1
		}
		col_idx: u16 = 0
		for gvt.render_state_row_cells_next(row_cells_h) {
			if row == cursor.y && cursor_row_len < len(cursor_row_buf) - 1 {
				raw: gvt.Cell
				if gvt.render_state_row_cells_get(row_cells_h, .RAW, &raw) == .SUCCESS {
					has: bool
					cp: u32
					gvt.cell_get(raw, .HAS_TEXT, &has)
					if has {
						gvt.cell_get(raw, .CODEPOINT, &cp)
						if cp >= 32 && cp < 128 {
							cursor_row_buf[cursor_row_len] = u8(cp)
							cursor_row_len += 1
						}
					}
				}
			}
			whoosh_emit_cell(col_idx, row, row_cells_h)
			draw_cell(col_idx, row, row_cells_h, &colors)
			col_idx += 1
		}
	}
	whoosh_consume()
	search_scan_rows()
	update_search(dt)

	if cursor_visible_g {
		cx := f32(cursor.x) * f32(cell_w) + PADDING
		cy := f32(cursor.y) * f32(cell_h) + PADDING
		rl.DrawRectangle(i32(cx), i32(cy), cell_w, cell_h, cfg.cursor_color)
	}

	update_glitch()
	update_ls_anim()
	draw_key_drops()
	draw_cursor_trail()
	update_draw_particles()
	update_draw_rising()

	gvt.term_render_clean(&gterm)
	rl.EndTextureMode()

	// ── Pass 1b: 3D scene + drum + flat term overlay → target ──
	draw_pass1b(elapsed)

	draw_pass2(elapsed)
}

// Composites the 3D scene, the drum (alt-screen), and the flat terminal
// overlay onto `target`. Split out so the early-return path on render-update
// failure can still produce a valid frame.
draw_pass1b :: proc(elapsed: f32) {
	rl.BeginTextureMode(target)
	rl.ClearBackground(cfg.scene_bg)

	rl.BeginMode3D(camera)
	draw_3d_scene(elapsed)
	draw_drum_3d(term_target.texture)
	rl.EndMode3D()

	draw_cd_labels()

	// Flat terminal overlay — fades out as the drum tumbles in
	flat_a := u8(255.0 * flat_visible_alpha())
	if flat_a > 0 {
		rl.DrawTextureRec(
			term_target.texture,
			{0, 0, f32(window_w), -f32(window_h)},
			{0, 0},
			{255, 255, 255, flat_a},
		)
	}

	draw_search_overlay()
	draw_drum_button()
	draw_rpg_hud()
	draw_sudo_vignette()
	rl.EndTextureMode()
}

draw_pass2 :: proc(elapsed_in: f32) {
	elapsed := elapsed_in
	rl.SetShaderValue(shader, time_loc, &elapsed, .FLOAT)

	shake_offset := update_shake(elapsed)

	update_rhythm()
	update_boot(rl.GetFrameTime())

	rl.BeginDrawing()
	rl.ClearBackground({0, 0, 0, 0xff})
	rl.BeginShaderMode(shader)
	// Render textures are vertically flipped in raylib
	rl.DrawTextureRec(
		target.texture,
		{0, 0, f32(window_w), -f32(window_h)},
		shake_offset,
		rl.WHITE,
	)
	rl.EndShaderMode()
	// Rhythm tint overlaid after shader pass
	tint := rhythm_tint()
	if tint.a > 0 {
		rl.DrawRectangle(0, 0, window_w, window_h, tint)
	}
	// Boot-up CRT flash on top of everything (no-op after first ~650 ms)
	draw_boot_overlay()
	rl.EndDrawing()
}

// ---------------------------------------------------------------------------
// 3D Background Scene
// ---------------------------------------------------------------------------

draw_3d_scene :: proc(t: f32) {
	fly := cam_fly_intensity()
	// Fall back to wireframes when:
	//   - drum is up: shardwall cubes occlude the cylinder via the depth buffer
	//   - cd-fly is active: term_target's bg alpha drops to ~8% so the 3D
	//     scene shows through — and since the shardwall samples term_target
	//     as its cube texture, the cubes fade along with the backdrop and
	//     leave only floating cell glyphs. The wireframe loop below is
	//     brightness-pumped by fly intensity, so the cubes punch out instead.
	if shardwall_active && drum_t < 0.05 && fly < 0.05 {
		draw_shardwall(t)
		return
	}

	// Fallback: slow-spinning grid of dim wireframe cubes (legacy look).
	for ix in -3 ..= 3 {
		for iz in -3 ..= 3 {
			x := f32(ix) * 2.5
			z := f32(iz) * 2.5 - 4
			y := math.sin(t * 0.6 + f32(ix + iz) * 0.8) * 0.4

			base_bright := f32(25 + int(15 * math.sin(t * 0.4 + f32(ix * iz) * 0.3)))
			bright := u8(base_bright + fly * (180.0 - base_bright))
			color := pwd_tint(rl.Color{bright, bright, bright + 10, 0xff}, cfg.pwd_tint_cube)

			sz := 0.6 + fly * 0.3
			rl.DrawCubeWires({x, y, z}, sz, sz, sz, color)
		}
	}
}

// ---------------------------------------------------------------------------
// Cell Rendering
// ---------------------------------------------------------------------------

draw_cell :: proc(col: u16, row: u16, row_cells_h: gvt.Render_State_Row_Cells, colors: ^gvt.Render_State_Colors) {
	base_x := f32(col) * f32(cell_w) + PADDING
	base_y := f32(row) * f32(cell_h) + PADDING
	// Gravity well + idle drift + ls race-in all offset text; background stays on grid.
	// Cell-level "loud" effects scale down to 25% strength while the drum is up so
	// the wrapped TUI stays legible on the cylinder surface.
	scale := cell_effect_scale()
	gx, gy := gravity_offset(col, row)
	ix, iy := idle_drift_offset(col, row)
	ls_dx, ls_scale := ls_cell_offset(col, row)
	sw_dx := shockwave_offset(row)
	em_dy, em_scale, em_alpha := emerge_offset(row)
	gx *= scale; gy *= scale
	ix *= scale; iy *= scale
	ls_dx *= scale
	sw_dx *= scale
	em_dy *= scale
	px := base_x + gx + ix + ls_dx + sw_dx
	py := base_y + gy + iy + em_dy

	bg_rgb: gvt.Color_Rgb
	if gvt.render_state_row_cells_get(row_cells_h, .BG_COLOR, &bg_rgb) == .SUCCESS {
		rl.DrawRectangle(i32(base_x), i32(base_y), cell_w, cell_h, r.to_rl_color(bg_rgb))
	}

	raw_cell: gvt.Cell
	if gvt.render_state_row_cells_get(row_cells_h, .RAW, &raw_cell) != .SUCCESS do return

	has_text: bool
	if gvt.cell_get(raw_cell, .HAS_TEXT, &has_text) != .SUCCESS do return
	if !has_text do return

	cp: u32
	gvt.cell_get(raw_cell, .CODEPOINT, &cp)
	search_capture_cell(col, row, cp)
	if cp == 0 || cp < 32 do return

	fg_rgb: gvt.Color_Rgb
	fg_color: rl.Color
	if gvt.render_state_row_cells_get(row_cells_h, .FG_COLOR, &fg_rgb) == .SUCCESS {
		fg_color = r.to_rl_color(fg_rgb)
	} else if colors.foreground.r != 0 || colors.foreground.g != 0 || colors.foreground.b != 0 {
		fg_color = r.to_rl_color(colors.foreground)
	} else {
		fg_color = cfg.fg_color
	}

	style: gvt.Style
	style.size = size_of(gvt.Style)
	if gvt.render_state_row_cells_get(row_cells_h, .STYLE, &style) == .SUCCESS {
		if style.bold {
			fg_color.r = u8(min(255, int(fg_color.r) + 40))
			fg_color.g = u8(min(255, int(fg_color.g) + 40))
			fg_color.b = u8(min(255, int(fg_color.b) + 40))
		}
		if style.underline != 0 {
			rl.DrawLine(
				i32(px),
				i32(py) + cell_h - 1,
				i32(px) + cell_w,
				i32(py) + cell_h - 1,
				fg_color,
			)
		}
		if style.strikethrough {
			rl.DrawLine(
				i32(px),
				i32(py) + cell_h / 2,
				i32(px) + cell_w,
				i32(py) + cell_h / 2,
				fg_color,
			)
		}
	}

	// Line age: fade rows that haven't had fresh output recently
	age_a := row_fade_alpha(row)
	if age_a < 0xff {
		fg_color.a = age_a
	}

	draw_cp := rune(cp)
	if gc, ok := glitch_codepoint(col, row); ok {
		draw_cp = gc
	}
	draw_sz := f32(font_size) * ls_scale * em_scale
	if em_alpha < 1.0 {
		fg_color.a = u8(f32(fg_color.a) * em_alpha)
	}
	rl.DrawTextCodepoint(font, draw_cp, {px, py}, draw_sz, fg_color)
}

// ---------------------------------------------------------------------------
// Font & Window Scaling
// ---------------------------------------------------------------------------

FONT_PATHS :: []cstring {
	"/usr/share/fonts/truetype/jetbrains-mono/JetBrainsMonoNerdFont-Regular.ttf",
	"/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf",
	"/usr/local/share/fonts/JetBrainsMonoNerdFont-Regular.ttf",
	"fonts/JetBrainsMonoNerdFont-Regular.ttf",
	"/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
	"/usr/share/fonts/TTF/DejaVuSansMono.ttf",
}

load_font :: proc() {
	if font_path != nil {
		font = rl.LoadFontEx(font_path, font_size, nil, 0)
		if font.texture.id != 0 do return
	}
	for path in FONT_PATHS {
		font = rl.LoadFontEx(path, font_size, nil, 0)
		if font.texture.id != 0 {
			font_path = path
			return
		}
	}
	font = rl.GetFontDefault()
}

change_font_size :: proc(delta: i32) {
	font_size = clamp(font_size + delta, FONT_SIZE_MIN, FONT_SIZE_MAX)
	apply_font_size()
}

apply_font_size :: proc() {
	// Derive cell metrics from font size (roughly 9:18 ratio at size 16)
	cell_h = font_size + 2
	cell_w = (cell_h + 1) / 2
	window_w = TERM_COLS * cell_w + PADDING * 2
	window_h = TERM_ROWS * cell_h + PADDING * 2

	// Reload font at new size
	rl.UnloadFont(font)
	load_font()

	// Resize window + render textures
	rl.SetWindowSize(window_w, window_h)
	rl.UnloadRenderTexture(target)
	target = rl.LoadRenderTexture(window_w, window_h)
	rl.UnloadRenderTexture(term_target)
	term_target = rl.LoadRenderTexture(window_w, window_h)
	update_resolution()
}

update_resolution :: proc() {
	res := [2]f32{f32(window_w), f32(window_h)}
	rl.SetShaderValue(shader, resolution_loc, &res, .VEC2)
}

// ---------------------------------------------------------------------------
// Paste (Ctrl+Shift+V)
// ---------------------------------------------------------------------------

paste_clipboard :: proc() {
	cstr := rl.GetClipboardText()
	if cstr == nil do return
	src := string(cstr)
	if len(src) == 0 do return

	// paste_encode mutates the data buffer in place; copy first.
	data_buf := make([]u8, len(src))
	defer delete(data_buf)
	copy(data_buf, transmute([]u8)src)

	bracketed := gvt.term_mode_get(&gterm, gvt.MODE_BRACKETED_PASTE)

	// Output adds at most 12 bytes of bracketed-paste wrap; +32 is plenty.
	out_buf := make([]u8, len(src) + 32)
	defer delete(out_buf)

	written: c.size_t
	res := gvt.paste_encode(
		raw_data(data_buf), c.size_t(len(data_buf)),
		bracketed,
		raw_data(out_buf), c.size_t(len(out_buf)),
		&written,
	)
	if res != .SUCCESS || written == 0 do return
	p.write_bytes(&pty, out_buf[:written])
}

// ---------------------------------------------------------------------------
// Hyperlink click-through (OSC 8) — Ctrl+Click
// ---------------------------------------------------------------------------

// Translate a mouse position to active-screen cell coordinates. Returns false
// if the position falls outside the terminal grid.
mouse_to_cell :: proc(mp: rl.Vector2) -> (col: u16, row: u16, ok: bool) {
	col_f := (mp.x - PADDING) / f32(cell_w)
	row_f := (mp.y - PADDING) / f32(cell_h)
	if col_f < 0 || row_f < 0 do return 0, 0, false
	if col_f >= TERM_COLS || row_f >= TERM_ROWS do return 0, 0, false
	return u16(col_f), u16(row_f), true
}

// If the cell under (col, row) carries an OSC 8 hyperlink, return its URI
// in `buf` and the byte length. Returns ok=false otherwise.
hyperlink_at :: proc(col, row: u16, buf: []u8) -> (uri: string, ok: bool) {
	pt := gvt.Point{tag = .ACTIVE, value = {coordinate = {x = col, y = u32(row)}}}
	ref := gvt.Grid_Ref{size = size_of(gvt.Grid_Ref)}
	if gvt.terminal_grid_ref(gterm.handle, pt, &ref) != .SUCCESS do return "", false

	out_len: c.size_t
	res := gvt.grid_ref_hyperlink_uri(&ref, raw_data(buf), c.size_t(len(buf)), &out_len)
	if res != .SUCCESS || out_len == 0 do return "", false
	return string(buf[:out_len]), true
}

handle_hyperlink_click :: proc() {
	if !rl.IsMouseButtonPressed(.LEFT) do return
	ctrl := rl.IsKeyDown(.LEFT_CONTROL) || rl.IsKeyDown(.RIGHT_CONTROL)
	if !ctrl do return

	col, row, ok := mouse_to_cell(rl.GetMousePosition())
	if !ok do return

	buf: [4096]u8
	uri, has := hyperlink_at(col, row, buf[:])
	if !has do return
	if !uri_scheme_allowed(uri) do return
	open_url(uri)
}

// OSC 8 URIs come from terminal output and may be attacker-controlled.
// Restrict click-through to schemes that xdg-open should reasonably handle
// for end-user navigation; reject file:, javascript:, data:, and anything
// else that could turn into local file disclosure or code execution.
uri_scheme_allowed :: proc(uri: string) -> bool {
	allowed := []string{"http://", "https://", "mailto:", "ftp://", "ftps://"}
	for prefix in allowed {
		if len(uri) >= len(prefix) && uri[:len(prefix)] == prefix do return true
	}
	return false
}

// Spawn `xdg-open <url>` without going through a shell. posix_spawnp returns
// immediately; we don't wait for the child (xdg-open backgrounds itself).
// Inherit the parent environment — xdg-open relies on DISPLAY / WAYLAND_DISPLAY
// / XDG_* / PATH to locate a browser.
open_url :: proc(url: string) {
	url_c, err := strings.clone_to_cstring(url)
	if err != nil do return
	defer delete(url_c)

	argv := [3]cstring{"xdg-open", url_c, nil}
	pid: posix.pid_t
	posix.posix_spawnp(&pid, "xdg-open", nil, nil, raw_data(&argv), posix.environ)
}

// Color and UTF-8 helpers live in `ghosdin:render_rl` (`r.to_rl_color`,
// `r.encode_utf8`). String + command-classification helpers live in
// `util.odin`.
