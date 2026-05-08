package uzo_term

// Character / class-select modal — F8 toggles, Esc closes. Overlay only;
// the underlying scene keeps animating and PTY keeps flowing. Phase 1 ships
// the full UI shell with a class-picker; inventory shows placeholder slots
// for the Phase 2 items/equipment work (uzo-ad8) so the layout exists when
// real data lands.
//
// Hooks (one line each):
//   main.odin: F8 handler, modal input early-out, draw_modal in pass1b
//   rpg.odin:  update_modal(dt), record_class_det(best) on class change

import "core:fmt"
import rl "vendor:raylib"

RPG_Modal_Panel :: enum u8 {
	CLASS,
	INVENTORY,
}

RPG_Modal_State :: struct {
	open:         bool,
	panel:        RPG_Modal_Panel,
	picking:      bool, // true while waiting for 1-6 class pick
	class_hist:   [8]RPG_Class,
	class_hist_n: int,
}

modal: RPG_Modal_State

// ---------------------------------------------------------------------------
// Public hooks
// ---------------------------------------------------------------------------

on_modal_toggle :: proc() {
	modal.open = !modal.open
	if !modal.open do modal.picking = false
}

// Returns true if the key was consumed by the modal (caller should `continue`).
on_modal_input :: proc(key: rl.KeyboardKey) -> bool {
	if !modal.open do return false

	if key == .F8 || key == .ESCAPE {
		if modal.picking {
			modal.picking = false
			return true
		}
		modal.open = false
		return true
	}

	if modal.picking {
		idx := -1
		#partial switch key {
		case .ONE:   idx = 0
		case .TWO:   idx = 1
		case .THREE: idx = 2
		case .FOUR:  idx = 3
		case .FIVE:  idx = 4
		case .SIX:   idx = 5
		}
		if idx >= 0 {
			rpg.class = RPG_Class(idx)
			rpg.class_locked = true
			modal.picking = false
		}
		return true // swallow all keys while picking
	}

	if key == .R {
		rpg.class_locked = false
		modal.picking = true
		return true
	}

	if key == .TAB {
		modal.panel = modal.panel == .CLASS ? .INVENTORY : .CLASS
		return true
	}

	// Modal is open but key isn't consumed — let it fall through to the PTY.
	return false
}

update_modal :: proc(dt: f32) {
	// reserved for animations
}

record_class_det :: proc(c: RPG_Class) {
	if modal.class_hist_n < len(modal.class_hist) {
		modal.class_hist[modal.class_hist_n] = c
		modal.class_hist_n += 1
		return
	}
	for i in 0 ..< len(modal.class_hist) - 1 {
		modal.class_hist[i] = modal.class_hist[i + 1]
	}
	modal.class_hist[len(modal.class_hist) - 1] = c
}

// ---------------------------------------------------------------------------
// Render
// ---------------------------------------------------------------------------

@(private = "file") PANEL_W :: f32(620)
@(private = "file") PANEL_H :: f32(460)

@(private = "file")
draw_text :: proc(s: cstring, x, y: f32, size: f32, c: rl.Color) {
	rl.DrawTextEx(font, s, {x, y}, size, 1, c)
}

@(private = "file")
fmt_cs :: proc(buf: []u8, args: ..any) -> cstring {
	s := fmt.bprintf(buf[:len(buf) - 1], "%s", args[0]) if len(args) == 1 else fmt.bprintf(buf[:len(buf) - 1], args[0].(string), ..args[1:])
	buf[len(s)] = 0
	return cstring(&buf[0])
}

draw_modal :: proc() {
	if !modal.open do return

	panel_x := (f32(window_w) - PANEL_W) * 0.5
	panel_y := (f32(window_h) - PANEL_H) * 0.5

	fg     := rl.Color{cfg.fg_color.r, cfg.fg_color.g, cfg.fg_color.b, 230}
	accent := rl.Color{cfg.accent_color.r, cfg.accent_color.g, cfg.accent_color.b, 230}
	dim    := rl.Color{cfg.fg_color.r, cfg.fg_color.g, cfg.fg_color.b, 130}

	// Dim backdrop
	rl.DrawRectangle(0, 0, window_w, window_h, {0, 0, 0, 180})

	// Panel
	rl.DrawRectangleRec({panel_x, panel_y, PANEL_W, PANEL_H}, {15, 15, 22, 240})
	rl.DrawRectangleLinesEx({panel_x, panel_y, PANEL_W, PANEL_H}, 2,
		{cfg.accent_color.r, cfg.accent_color.g, cfg.accent_color.b, 220})

	// Header
	draw_text("CHARACTER  //  uzo-term RPG", panel_x + 16, panel_y + 12, 16, accent)
	draw_text("[F8 close]", panel_x + PANEL_W - 100, panel_y + 14, 12, dim)
	rl.DrawLineEx({panel_x + 8, panel_y + 38}, {panel_x + PANEL_W - 8, panel_y + 38}, 1, dim)

	col_l := panel_x + 16
	col_r := panel_x + PANEL_W * 0.5 + 8

	// === LEFT COLUMN — current class + picker ===
	y := panel_y + 52
	draw_text("CLASS", col_l, y, 14, accent)
	y += 22

	cls_buf: [64]u8
	cls_str := fmt.bprintf(cls_buf[:63], "> %s", class_name(rpg.class))
	cls_buf[len(cls_str)] = 0
	draw_text(cstring(&cls_buf[0]), col_l + 4, y, 16, fg)
	y += 22

	switch {
	case modal.picking:
		draw_text("  [PICKING - press 1-6]", col_l + 4, y, 12, accent)
		y += 16
		draw_text("  Esc to cancel", col_l + 4, y, 12, dim)
	case rpg.class_locked:
		draw_text("  [LOCKED]", col_l + 4, y, 12, dim)
		y += 16
		draw_text("  Reclass [press R]", col_l + 4, y, 12, dim)
	case:
		draw_text("  [auto-detect]", col_l + 4, y, 12, dim)
	}
	y += 28

	draw_text("CLASSES", col_l, y, 14, accent)
	y += 22
	for c in RPG_Class {
		idx := int(c) + 1
		line_buf: [48]u8
		marker := c == rpg.class ? ">" : " "
		line_str := fmt.bprintf(line_buf[:47], "%s [%d] %s", marker, idx, class_name(c))
		line_buf[len(line_str)] = 0
		col := c == rpg.class ? accent : (modal.picking ? fg : dim)
		draw_text(cstring(&line_buf[0]), col_l + 4, y, 14, col)
		y += 18
	}

	// === RIGHT COLUMN — stats + inventory ===
	y = panel_y + 52
	draw_text("STATS", col_r, y, 14, accent)
	y += 22

	have, need := current_level_progress()
	avg_xp: f32 = 0
	if rpg.commands_seen > 0 do avg_xp = f32(rpg.xp) / f32(rpg.commands_seen)

	draw_stat_line :: proc(x, y: f32, label, val: string, c: rl.Color) {
		lbuf: [32]u8
		copy(lbuf[:], label); lbuf[len(label)] = 0
		vbuf: [64]u8
		copy(vbuf[:], val);   vbuf[len(val)] = 0
		rl.DrawTextEx(font, cstring(&lbuf[0]), {x, y}, 13, 1, c)
		rl.DrawTextEx(font, cstring(&vbuf[0]), {x + 100, y}, 13, 1, c)
	}

	lvl_buf: [16]u8
	lvl_str := fmt.bprintf(lvl_buf[:15], "%d", rpg.level)
	draw_stat_line(col_r + 4, y, "Level", string(lvl_str), fg);  y += 18

	xp_buf: [40]u8
	xp_str := fmt.bprintf(xp_buf[:39], "%d / %d", have, need)
	draw_stat_line(col_r + 4, y, "XP", string(xp_str), fg);      y += 18

	cmds_buf: [16]u8
	cmds_str := fmt.bprintf(cmds_buf[:15], "%d", rpg.commands_seen)
	draw_stat_line(col_r + 4, y, "Commands", string(cmds_str), fg); y += 18

	avg_buf: [16]u8
	avg_str := fmt.bprintf(avg_buf[:15], "%.1f", avg_xp)
	draw_stat_line(col_r + 4, y, "Avg XP", string(avg_str), fg);    y += 18

	if modal.class_hist_n > 0 {
		hist_buf: [128]u8
		pos := 0
		for i in 0 ..< modal.class_hist_n {
			short := class_table[modal.class_hist[i]].short
			for j in 0 ..< len(short) {
				if pos >= len(hist_buf) - 4 do break
				hist_buf[pos] = short[j]; pos += 1
			}
			if i < modal.class_hist_n - 1 && pos < len(hist_buf) - 3 {
				hist_buf[pos] = ','; hist_buf[pos + 1] = ' '; pos += 2
			}
		}
		hist_buf[pos] = 0
		draw_stat_line(col_r + 4, y, "Det log", string(hist_buf[:pos]), dim); y += 18
	}

	y += 16
	draw_text("INVENTORY", col_r, y, 14, accent); y += 22

	gold_buf: [32]u8
	gold_str := fmt.bprintf(gold_buf[:31], "%d", rpg.gold)
	draw_stat_line(col_r + 4, y, "Gold", string(gold_str), fg); y += 18

	cap_now := inventory_capacity()
	count_buf: [32]u8
	count_str := fmt.bprintf(count_buf[:31], "%d / %d", inventory_count(), cap_now)
	draw_stat_line(col_r + 4, y, "Slots", string(count_str), fg); y += 22

	// List the items the player has actually picked up. Empty inventory shows
	// a quiet hint instead of a row of placeholders.
	if rpg.inventory_n == 0 {
		draw_text("(no items yet — drops fire on commands)", col_r + 4, y, 12, dim)
	} else {
		for i in 0 ..< int(rpg.inventory_n) {
			id := rpg.inventory[i]
			line_buf: [48]u8
			line_str := fmt.bprintf(line_buf[:47], "%c %s", item_glyph(id), item_name(id))
			line_buf[len(line_str)] = 0
			draw_text(cstring(&line_buf[0]), col_r + 4, y, 13, fg)
			y += 16
			if y > panel_y + PANEL_H - 50 do break
		}
	}

	// Footer
	foot_y := panel_y + PANEL_H - 28
	rl.DrawLineEx({panel_x + 8, foot_y - 6}, {panel_x + PANEL_W - 8, foot_y - 6}, 1, dim)

	foot: cstring
	switch {
	case modal.picking:        foot = "1-6: pick class    Esc: cancel"
	case rpg.class_locked:     foot = "R: reclass    Tab: panel    Esc/F8: close"
	case:                      foot = "Tab: panel    Esc/F8: close    (class auto-detects)"
	}
	draw_text(foot, panel_x + 16, foot_y, 12, dim)
}
