package uzo_term

// RPG subsystem — core state, XP/level math, frame integration, public hooks.
//
// File layout (all in package uzo_term):
//   rpg.odin                 — this file: state, XP/level, frame integration
//   rpg_classes.odin         — class enum + table (name, biome, verbs)
//   rpg_spells.odin          — Spell struct, registry, dispatcher
//   rpg_spell_<name>.odin    — one file per spell, self-registers via @(init)
//
// Adding a spell:    create rpg_spell_<name>.odin (no central edits)
// Adding a class:    append to RPG_Class enum + class_table at same index
// Adding a stat:     edit RPG_State struct
//
// Phase 2 (uzo-ad8) will add rpg_skill_tree.odin + rpg_tree_<class>.odin,
// at which point Spell.level_required can be supplemented with a node_id
// gate without breaking existing spells.

import "core:fmt"
import rl "vendor:raylib"

// ---------------------------------------------------------------------------
// Public toggle + tunables
// ---------------------------------------------------------------------------

rpg_active: bool = true // default-on; --no-rpg flips, F9 toggles

@(private = "file") XP_PER_CHAR         :: 1
@(private = "file") XP_PER_ENTER        :: 10
@(private = "file") LEVEL_BASE          :: 100
@(private = "file") LEVEL_SLOPE         :: 5
@(private = "file") CLASS_RECHECK_EVERY :: 10
@(private = "file") CLASS_THRESHOLD     :: f32(0.40)

// ---------------------------------------------------------------------------
// Classes (table lives in rpg_classes.odin)
// ---------------------------------------------------------------------------

RPG_Class :: enum u8 {
	DRIFTER,
	CONSOLE_COWBOY,
	SPIDER,
	TECHNO_WIZARD,
	OPERATOR,
	ICE_BREAKER,
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

@(private = "file") COMMAND_LOG_LEN :: 50

// Phase 2 — skill tree + economy. Fixed at 30 nodes per tree per uzo-ad8.
SKILL_NODES_PER_TREE :: 30

@(private = "file")
Command_Tally :: struct {
	cmd:     [16]u8,
	cmd_len: int,
}

RPG_State :: struct {
	xp:                u64,
	level:             u16,
	class:             RPG_Class,
	class_locked:      bool,
	command_log:       [COMMAND_LOG_LEN]Command_Tally,
	command_log_head:  int,
	commands_seen:     u32,
	level_up_flash_t:  f32,
	level_up_text_buf: [32]u8,
	level_up_text_len: int,
	class_toast_t:     f32,
	class_toast_text:  [48]u8,
	class_toast_len:   int,
	biome_shifted:     bool, // set by Lv 10 biome shift; gates draw_biome_overlay

	// Phase 2 (uzo-ad8) — earned 1 per level-up, spent on skill_tree nodes.
	// allocated[class] is the per-tree bool array (30 nodes, indexed by node id).
	// Class-starter (id 0) is implicitly allocated and not stored here.
	skill_points: u16,
	allocated:    [RPG_Class][SKILL_NODES_PER_TREE]bool,
	gold:         u32,
}

rpg: RPG_State

init_rpg :: proc() {
	rpg.level = 1
	rpg.class = .DRIFTER
}

rpg_reset :: proc() {
	rpg = {}
	init_rpg()
	reset_spell_state()
}

// ---------------------------------------------------------------------------
// Level curve
// ---------------------------------------------------------------------------

xp_to_next :: proc(level: u16) -> u64 {
	return u64(LEVEL_BASE + LEVEL_SLOPE * int(level))
}

cumulative_xp :: proc(level: u16) -> u64 {
	if level <= 1 do return 0
	sum: u64 = 0
	for n in u16(1) ..< level {
		sum += xp_to_next(n)
	}
	return sum
}

current_level_progress :: proc() -> (have, need: u64) {
	need = xp_to_next(rpg.level)
	have = rpg.xp - cumulative_xp(rpg.level)
	return
}

// ---------------------------------------------------------------------------
// Public hooks (called from main.odin)
// ---------------------------------------------------------------------------

on_rpg_keypress :: proc(ch: rune) {
	if !rpg_active do return
	// Skip C0/C1 control codes + DEL; everything else (including non-ASCII
	// printable codepoints — emoji, CJK, etc.) earns XP.
	if ch < 32 || (ch >= 127 && ch <= 159) do return
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

	dispatch_command_spells(line)
	check_level_up()
}

@(private = "file")
check_level_up :: proc() {
	for rpg.xp >= cumulative_xp(rpg.level + 1) {
		rpg.level += 1
		rpg.skill_points += 1
		trigger_level_up()
		dispatch_levelup_spells()
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
	// Sized to the enum so adding a class doesn't require touching this loop.
	counts: [RPG_Class]int
	total := 0
	for i in 0 ..< COMMAND_LOG_LEN {
		slot := &rpg.command_log[i]
		if slot.cmd_len == 0 do continue
		verb := string(slot.cmd[:slot.cmd_len])
		counts[classify_verb(verb)] += 1
		total += 1
	}
	if total < 5 do return

	best := rpg.class
	best_count := 0
	for c in RPG_Class {
		if counts[c] > best_count {
			best_count = counts[c]
			best = c
		}
	}
	if f32(best_count) / f32(total) < CLASS_THRESHOLD do return
	if best == rpg.class do return

	rpg.class = best
	record_class_det(best)
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
	teleport_tick(dt)
	map_pulse_tick(dt)
	update_modal(dt)
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

	// Spell-owned full-screen overlays render first so the HUD pill stays on top.
	// (Biome underlay is drawn earlier, in draw_pass1b, so it sits behind cells.)
	draw_teleport_flash()
	draw_map_pulse()

	margin_x: f32 = 12
	margin_y: f32 = 42 // 12 base + 30 lift
	width:    f32 = 416
	height:   f32 = 35
	x := f32(window_w) - width - margin_x
	y := f32(window_h) - height - margin_y

	rl.DrawRectangleRec({x, y, width, height}, {0, 0, 0, 170})
	rl.DrawRectangleLinesEx({x, y, width, height}, 1,
		{cfg.accent_color.r, cfg.accent_color.g, cfg.accent_color.b, 200})

	have, need := current_level_progress()

	left_buf: [64]u8
	left_str := fmt.bprintf(left_buf[:len(left_buf) - 1],
		"Lv %d  %s", rpg.level, class_name(rpg.class))
	left_buf[len(left_str)] = 0
	left_cs := cstring(&left_buf[0])

	right_buf: [32]u8
	right_str := fmt.bprintf(right_buf[:len(right_buf) - 1], "%d/%d", have, need)
	right_buf[len(right_str)] = 0
	right_cs := cstring(&right_buf[0])

	font_sz: f32 = 22
	tcol := rl.Color{cfg.fg_color.r, cfg.fg_color.g, cfg.fg_color.b, 230}
	rl.DrawTextEx(font, left_cs, {x + 13, y + 6}, font_sz, 2, tcol)

	right_w := rl.MeasureTextEx(font, right_cs, font_sz, 2).x
	rl.DrawTextEx(font, right_cs, {x + width - right_w - 13, y + 6}, font_sz, 2, tcol)

	progress := f32(have) / f32(need)
	draw_xp_bar(x + 2, y + height - 6, width - 4, 5, progress)

	// Level-up rising 'LEVEL N' text — 1.5s tween rising from cursor.
	if rpg.level_up_flash_t > 0 && rpg.level_up_text_len > 0 {
		t := rpg.level_up_flash_t / 1.5
		eased := 1.0 - t * t
		rise := 60.0 * eased
		alpha := u8(t * 255)

		cx := f32(cursor_x_g) * f32(cell_w) + PADDING
		cy := f32(cursor_y_g) * f32(cell_h) + PADDING - rise

		size: f32 = 28
		cs := cstring(&rpg.level_up_text_buf[0])
		tw := rl.MeasureTextEx(font, cs, size, 1).x
		px := cx - tw * 0.5
		if px < 8 do px = 8
		if px + tw > f32(window_w) - 8 do px = f32(window_w) - tw - 8
		rl.DrawTextEx(font, cs, {px, cy}, size, 1, {255, 240, 120, alpha})
	}

	// Class toast — 3s, centered horizontally near top third.
	if rpg.class_toast_t > 0 && rpg.class_toast_len > 0 {
		t := rpg.class_toast_t / 3.0
		alpha_f := t < 0.85 ? t / 0.85 : 1.0
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
