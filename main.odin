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

	// -- Render texture (everything draws here first) --
	target = rl.LoadRenderTexture(window_w, window_h)
	defer rl.UnloadRenderTexture(target)

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

		// Enter has uzo-term-specific side effects (effects + command detection)
		// before the VT sequence is sent; keep that case inline.
		if key == .ENTER {
			trigger_shake()
			trigger_explosion()
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
			}
		}
	}
}

// Inspect the just-submitted input line for `sudo` / `cd` / `ls` / `exit`
// triggers before clearing the buffer. Pulled out of `handle_input` so the
// switch above stays focused on key→VT-sequence mapping.
handle_command_line :: proc() {
	line := string(input_line[:input_line_len])
	if contains(line, "sudo") {
		on_sudo_detected()
	} else if len(line) > 0 {
		on_sudo_cleared()
	}
	if len(line) >= 2 && line[:2] == "cd" {
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

	update_idle()
	update_camera_fly()

	// ── Pass 1: draw everything to render texture ──
	rl.BeginTextureMode(target)

	// 3D background
	rl.ClearBackground(cfg.scene_bg)
	rl.BeginMode3D(camera)
	draw_3d_scene(elapsed)
	rl.EndMode3D()

	// Dir labels on cubes during cd fly (drawn in 2D using projected positions)
	draw_cd_labels()

	// 2D terminal overlay — fades out during cd fly so the 3D scene punches through
	fly := cam_fly_intensity()
	term_bg_alpha := u8(f32(cfg.term_bg.a) * (1.0 - fly * 0.92))
	rl.DrawRectangle(0, 0, window_w, window_h, {cfg.term_bg.r, cfg.term_bg.g, cfg.term_bg.b, term_bg_alpha})

	// Update render state — bail to just the background if it fails
	if gvt.term_render_update(&gterm) != .None {
		rl.EndTextureMode()
		draw_pass2(elapsed)
		return
	}

	colors, _ := gvt.term_render_colors(&gterm)
	cursor := gvt.term_render_cursor(&gterm)

	// Expose cursor state to effects
	cursor_x_g = cursor.x
	cursor_y_g = cursor.y
	cursor_visible_g = cursor.visible && cursor.in_viewport

	// Terminal cells — iterate rows + cells via the wrapper, fetch per-row
	// dirty flags directly from the underlying iterator handle.
	cursor_row_len = 0
	row_iter_h := gvt.term_row_iterator(&gterm)
	row_cells_h := gvt.term_row_cells_handle(&gterm)
	row_it := gvt.term_render_rows(&gterm)
	for row in gvt.render_row_next(&row_it) {
		dirty_row: bool
		if gvt.render_state_row_get(row_iter_h, .DIRTY, &dirty_row) == .SUCCESS && dirty_row {
			mark_row_born(row)
			mark_ls_row(row)
		}
		col_idx: u16 = 0
		for gvt.render_state_row_cells_next(row_cells_h) {
			// Capture cursor row text for command detection
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
			draw_cell(col_idx, row, row_cells_h, &colors)
			col_idx += 1
		}
	}

	// Cursor
	if cursor_visible_g {
		cx := f32(cursor.x) * f32(cell_w) + PADDING
		cy := f32(cursor.y) * f32(cell_h) + PADDING
		rl.DrawRectangle(i32(cx), i32(cy), cell_w, cell_h, cfg.cursor_color)
	}

	// Effects drawn on top of terminal cells
	update_glitch()
	update_ls_anim()
	draw_key_drops()
	draw_cursor_trail()
	update_draw_particles()
	draw_sudo_vignette()

	gvt.term_render_clean(&gterm)

	rl.EndTextureMode()

	draw_pass2(elapsed)
}

draw_pass2 :: proc(elapsed_in: f32) {
	elapsed := elapsed_in
	rl.SetShaderValue(shader, time_loc, &elapsed, .FLOAT)

	shake_offset := update_shake(elapsed)

	update_rhythm()

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
	rl.EndDrawing()
}

// ---------------------------------------------------------------------------
// 3D Background Scene
// ---------------------------------------------------------------------------

draw_3d_scene :: proc(t: f32) {
	// Slow-spinning grid of dim cubes — visible through the translucent terminal bg
	fly := cam_fly_intensity()
	for ix in -3 ..= 3 {
		for iz in -3 ..= 3 {
			x := f32(ix) * 2.5
			z := f32(iz) * 2.5 - 4
			y := math.sin(t * 0.6 + f32(ix + iz) * 0.8) * 0.4

			base_bright := f32(25 + int(15 * math.sin(t * 0.4 + f32(ix * iz) * 0.3)))
			// During cd fly, cubes glow much brighter
			bright := u8(base_bright + fly * (180.0 - base_bright))
			color := rl.Color{bright, bright, bright + 10, 0xff}

			sz := 0.6 + fly * 0.3 // slightly larger during fly
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
	// Gravity well + idle drift + ls race-in all offset text; background stays on grid
	gx, gy := gravity_offset(col, row)
	ix, iy := idle_drift_offset(col, row)
	ls_dx, ls_scale := ls_cell_offset(col, row)
	px := base_x + gx + ix + ls_dx
	py := base_y + gy + iy

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
	draw_sz := f32(font_size) * ls_scale
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

	// Resize window + render texture
	rl.SetWindowSize(window_w, window_h)
	rl.UnloadRenderTexture(target)
	target = rl.LoadRenderTexture(window_w, window_h)
	update_resolution()
}

update_resolution :: proc() {
	res := [2]f32{f32(window_w), f32(window_h)}
	rl.SetShaderValue(shader, resolution_loc, &res, .VEC2)
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

contains :: proc(s, sub: string) -> bool {
	if len(sub) > len(s) do return false
	for i in 0 ..= len(s) - len(sub) {
		if s[i:i + len(sub)] == sub do return true
	}
	return false
}

// Color and UTF-8 helpers now live in `ghosdin:render_rl` (`r.to_rl_color`,
// `r.encode_utf8`); local copies were removed to keep the helpers in one
// place.
