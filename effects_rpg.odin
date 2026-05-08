package uzo_term

// RPG layer — XP from typing & commands, levels, class auto-detection,
// bottom-right HUD, level-up particle burst, periodic class re-roll.
// Phase 1: session-scoped (no persistence). Phase 2 will add the
// per-class skill trees (uzo-ad8). Module is single-file and
// self-contained; the only public hooks live in this file.

import "core:fmt"
import rl "vendor:raylib"

// ---------------------------------------------------------------------------
// Public toggle + tunables
// ---------------------------------------------------------------------------

rpg_active: bool = true // default-on; --no-rpg flag flips off, F9 toggles

// XP economy. Tuned to hit Lv 10 in ~5 min and Lv 100 in ~90 min at
// average human typing speed. Curve: xp_to_next(n) = LEVEL_BASE + LEVEL_SLOPE*n.
@(private = "file") XP_PER_CHAR        :: 1
@(private = "file") XP_PER_ENTER       :: 10
@(private = "file") LEVEL_BASE         :: 100
@(private = "file") LEVEL_SLOPE        :: 5
@(private = "file") CLASS_RECHECK_EVERY :: 10  // re-evaluate every N commands once enough data
@(private = "file") CLASS_THRESHOLD    :: f32(0.40) // dominant verb must be ≥40% of last 50

// ---------------------------------------------------------------------------
// Classes (Neuromancer / Rifts flavor)
// ---------------------------------------------------------------------------

RPG_Class :: enum u8 {
	DRIFTER,         // cd / ls / pwd / pushd
	CONSOLE_COWBOY,  // git*
	SPIDER,          // grep / rg / find / ack / awk
	TECHNO_WIZARD,   // vim / nvim / nano / emacs
	OPERATOR,        // make / cargo / go / npm
	ICE_BREAKER,     // rm / sudo / kill / chmod
}

class_name :: proc(c: RPG_Class) -> string {
	switch c {
	case .DRIFTER:        return "Drifter"
	case .CONSOLE_COWBOY: return "Console Cowboy"
	case .SPIDER:         return "Spider"
	case .TECHNO_WIZARD:  return "Techno-Wizard"
	case .OPERATOR:       return "Operator"
	case .ICE_BREAKER:    return "Ice-Breaker"
	}
	return "Drifter"
}

// Map the first verb of a command line to its class. Returns DRIFTER as a
// fallback so the bias towards 'navigation' makes pure cd/ls sessions
// classify cleanly.
@(private = "file")
classify_verb :: proc(verb: string) -> RPG_Class {
	if len(verb) >= 3 && verb[:3] == "git" do return .CONSOLE_COWBOY
	switch verb {
	case "grep", "rg", "ag", "find", "ack", "fgrep", "egrep", "awk":
		return .SPIDER
	case "vim", "nvim", "nano", "emacs", "vi", "ed":
		return .TECHNO_WIZARD
	case "make", "cargo", "go", "npm", "yarn", "pnpm",
	     "just", "ninja", "cmake", "zig", "odin", "tsc":
		return .OPERATOR
	case "rm", "sudo", "doas", "kill", "pkill", "killall", "chmod", "chown":
		return .ICE_BREAKER
	case "cd", "ls", "pwd", "pushd", "popd", "tree":
		return .DRIFTER
	}
	return .DRIFTER
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

@(private = "file") COMMAND_LOG_LEN :: 50

@(private = "file")
Command_Tally :: struct {
	cmd:     [16]u8,
	cmd_len: int,
}

RPG_State :: struct {
	xp:                u64,
	level:             u16,
	class:             RPG_Class,
	class_locked:      bool, // user pinned a class via --rpg-class
	command_log:       [COMMAND_LOG_LEN]Command_Tally,
	command_log_head:  int,
	commands_seen:     u32,
	level_up_flash_t:  f32,
	level_up_text_buf: [32]u8,
	level_up_text_len: int,
	class_toast_t:     f32,
	class_toast_text:  [48]u8,
	class_toast_len:   int,
}

rpg: RPG_State

init_rpg :: proc() {
	rpg.level = 1
	rpg.class = .DRIFTER
}

// ---------------------------------------------------------------------------
// Level curve
// ---------------------------------------------------------------------------

// XP needed to advance from `level` to `level + 1`.
xp_to_next :: proc(level: u16) -> u64 {
	return u64(LEVEL_BASE + LEVEL_SLOPE * int(level))
}

// Total XP required to first reach `level` (level 1 = 0).
cumulative_xp :: proc(level: u16) -> u64 {
	if level <= 1 do return 0
	sum: u64 = 0
	for n in u16(1) ..< level {
		sum += xp_to_next(n)
	}
	return sum
}

// XP earned within the current level + XP needed to fill it.
current_level_progress :: proc() -> (have, need: u64) {
	need = xp_to_next(rpg.level)
	have = rpg.xp - cumulative_xp(rpg.level)
	return
}

// ---------------------------------------------------------------------------
// XP grant hooks (called from main.odin)
// ---------------------------------------------------------------------------

on_rpg_keypress :: proc(ch: rune) {
	if !rpg_active do return
	if ch < 32 || ch > 126 do return // printable ASCII only — avoids modifier double-counts
	rpg.xp += XP_PER_CHAR
	check_level_up()
}

on_rpg_command :: proc(line: string) {
	if !rpg_active do return
	rpg.xp += XP_PER_ENTER

	cmd := first_command(line)
	if len(cmd) > 0 {
		slot := &rpg.command_log[rpg.command_log_head]
		n := min(len(cmd), len(slot.cmd))
		for i in 0 ..< n do slot.cmd[i] = cmd[i]
		slot.cmd_len = n
		rpg.command_log_head = (rpg.command_log_head + 1) % COMMAND_LOG_LEN
		rpg.commands_seen += 1
	}

	if !rpg.class_locked &&
	   rpg.commands_seen >= 5 &&
	   rpg.commands_seen % CLASS_RECHECK_EVERY == 0 {
		try_reclassify()
	}

	check_level_up()
}

@(private = "file")
check_level_up :: proc() {
	for rpg.xp >= cumulative_xp(rpg.level + 1) {
		rpg.level += 1
		trigger_level_up()
	}
}

@(private = "file")
trigger_level_up :: proc() {
	rpg.level_up_flash_t = 1.5
	trigger_shake()

	txt := fmt.bprintf(rpg.level_up_text_buf[:len(rpg.level_up_text_buf) - 1], "LEVEL %d", rpg.level)
	rpg.level_up_text_len = len(txt)
	rpg.level_up_text_buf[rpg.level_up_text_len] = 0

	cx := f32(cursor_x_g) * f32(cell_w) + PADDING + f32(cell_w) * 0.5
	cy := f32(cursor_y_g) * f32(cell_h) + PADDING + f32(cell_h) * 0.5
	for _ in 0 ..< 8 {
		emit_rising(.LASER, cx, cy)
	}
}

// ---------------------------------------------------------------------------
// Class detection
// ---------------------------------------------------------------------------

@(private = "file")
try_reclassify :: proc() {
	counts: [6]int
	total := 0
	for i in 0 ..< COMMAND_LOG_LEN {
		slot := &rpg.command_log[i]
		if slot.cmd_len == 0 do continue
		verb := string(slot.cmd[:slot.cmd_len])
		counts[int(classify_verb(verb))] += 1
		total += 1
	}
	if total < 5 do return

	best := rpg.class
	best_count := 0
	for i in 0 ..< 6 {
		if counts[i] > best_count {
			best_count = counts[i]
			best = RPG_Class(i)
		}
	}
	if f32(best_count) / f32(total) < CLASS_THRESHOLD do return
	if best == rpg.class do return

	rpg.class = best
	txt := fmt.bprintf(rpg.class_toast_text[:len(rpg.class_toast_text) - 1],
		"You have become a %s.", class_name(best))
	rpg.class_toast_len = len(txt)
	rpg.class_toast_text[rpg.class_toast_len] = 0
	rpg.class_toast_t = 3.0
}

// ---------------------------------------------------------------------------
// Frame update + draw
// ---------------------------------------------------------------------------

update_rpg :: proc(dt: f32) {
	if !rpg_active do return
	if rpg.level_up_flash_t > 0 do rpg.level_up_flash_t -= dt
	if rpg.class_toast_t > 0 do rpg.class_toast_t -= dt
}

@(private = "file")
draw_xp_bar :: proc(x, y, w, h: f32, progress: f32) {
	bg := rl.Color{40, 40, 50, 200}
	fg := rl.Color{cfg.accent_color.r, cfg.accent_color.g, cfg.accent_color.b, 240}
	rl.DrawRectangleRec({x, y, w, h}, bg)
	fill := w * clamp(progress, 0, 1)
	if fill > 0 {
		rl.DrawRectangleRec({x, y, fill, h}, fg)
	}
	rl.DrawRectangleLinesEx({x, y, w, h}, 1, {cfg.accent_color.r, cfg.accent_color.g, cfg.accent_color.b, 180})
}

draw_rpg_hud :: proc() {
	if !rpg_active do return

	// HUD pill — bottom-right, 12px margin from each edge.
	margin: f32 = 12
	width:  f32 = 260
	height: f32 = 22
	x := f32(window_w) - width - margin
	y := f32(window_h) - height - margin

	rl.DrawRectangleRec({x, y, width, height}, {0, 0, 0, 170})
	rl.DrawRectangleLinesEx({x, y, width, height}, 1,
		{cfg.accent_color.r, cfg.accent_color.g, cfg.accent_color.b, 200})

	have, need := current_level_progress()

	// Left text: "Lv 7  Console Cowboy"
	left_buf: [64]u8
	left_str := fmt.bprintf(left_buf[:len(left_buf) - 1],
		"Lv %d  %s", rpg.level, class_name(rpg.class))
	left_buf[len(left_str)] = 0
	left_cs := cstring(&left_buf[0])

	// Right text: "320/450"
	right_buf: [32]u8
	right_str := fmt.bprintf(right_buf[:len(right_buf) - 1], "%d/%d", have, need)
	right_buf[len(right_str)] = 0
	right_cs := cstring(&right_buf[0])

	font_sz: f32 = 14
	tcol := rl.Color{cfg.fg_color.r, cfg.fg_color.g, cfg.fg_color.b, 230}
	rl.DrawTextEx(font, left_cs, {x + 8, y + 4}, font_sz, 1, tcol)

	right_w := rl.MeasureTextEx(font, right_cs, font_sz, 1).x
	rl.DrawTextEx(font, right_cs, {x + width - right_w - 8, y + 4}, font_sz, 1, tcol)

	// XP bar runs along the bottom 4px strip of the HUD pill.
	progress := f32(have) / f32(need)
	draw_xp_bar(x + 1, y + height - 4, width - 2, 3, progress)

	// Level-up rising 'LEVEL N' text — 1.5s tween rising from cursor.
	if rpg.level_up_flash_t > 0 && rpg.level_up_text_len > 0 {
		t := rpg.level_up_flash_t / 1.5 // 1 → 0
		eased := 1.0 - t * t            // 0 → 1
		rise := 60.0 * eased
		alpha := u8(t * 255)

		cx := f32(cursor_x_g) * f32(cell_w) + PADDING
		cy := f32(cursor_y_g) * f32(cell_h) + PADDING - rise

		size: f32 = 28
		cs := cstring(&rpg.level_up_text_buf[0])
		tw := rl.MeasureTextEx(font, cs, size, 1).x
		// Centered horizontally on cursor, clamped to window
		px := cx - tw * 0.5
		if px < 8 do px = 8
		if px + tw > f32(window_w) - 8 do px = f32(window_w) - tw - 8
		rl.DrawTextEx(font, cs, {px, cy}, size, 1, {255, 240, 120, alpha})
	}

	// Class toast — 3s, centered horizontally near top third.
	if rpg.class_toast_t > 0 && rpg.class_toast_len > 0 {
		t := rpg.class_toast_t / 3.0          // 1 → 0
		alpha_f := t < 0.85 ? t / 0.85 : 1.0  // ease in fast, hold, fade
		alpha := u8(clamp(alpha_f, 0, 1) * 240)

		cs := cstring(&rpg.class_toast_text[0])
		size: f32 = 20
		tw := rl.MeasureTextEx(font, cs, size, 1).x
		tx := (f32(window_w) - tw) * 0.5
		ty := f32(window_h) * 0.28

		pad: f32 = 10
		bg_a := u8(clamp(alpha_f, 0, 1) * 180)
		rl.DrawRectangleRec({tx - pad, ty - pad, tw + 2 * pad, size + 2 * pad},
			{0, 0, 0, bg_a})
		rl.DrawTextEx(font, cs, {tx, ty}, size, 1,
			{cfg.accent_color.r, cfg.accent_color.g, cfg.accent_color.b, alpha})
	}
}

// ---------------------------------------------------------------------------
// CLI / runtime control
// ---------------------------------------------------------------------------

// Override class via --rpg-class=name. Returns false on unknown name so the
// caller can warn.
rpg_set_class_by_name :: proc(name: string) -> bool {
	switch name {
	case "drifter":     rpg.class = .DRIFTER
	case "cowboy":      rpg.class = .CONSOLE_COWBOY
	case "spider":      rpg.class = .SPIDER
	case "wizard":      rpg.class = .TECHNO_WIZARD
	case "operator":    rpg.class = .OPERATOR
	case "icebreaker":  rpg.class = .ICE_BREAKER
	case:               return false
	}
	rpg.class_locked = true
	return true
}

rpg_reset :: proc() {
	rpg = {}
	init_rpg()
}
