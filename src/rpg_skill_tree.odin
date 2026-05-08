package uzo_term

// Skill tree subsystem (Phase 2, uzo-ad8).
//
// File layout (all in package uzo_term):
//   rpg_skill_tree.odin       — this file: state, render, input, allocation
//   rpg_tree_<class>.odin     — one file per class, fills class_trees[c]
//                               via @(init). Like the spells, classes are
//                               opt-in: an unfilled tree just renders empty.
//
// Adding a class tree:    create rpg_tree_<class>.odin (no central edits)
// Adding a node payload:  extend Skill_Payload_Kind + apply_node_effect
//
// Layout:
//   Tree-space units are unbounded; render fits all node positions plus
//   padding into the viewport. Class starter (id 0) is always at (0, 0)
//   and is implicitly allocated — never stored in rpg.allocated.
//
// Input model (F10 toggles):
//   arrows  — pan focus to nearest node in that direction
//   Enter   — allocate focused node (if available + skill_points > 0)
//   R       — refund focused node (cascades dependents)
//   Esc     — close

import "core:math"
import rl "vendor:raylib"

// ---------------------------------------------------------------------------
// Data shape
// ---------------------------------------------------------------------------

Skill_Node_Kind :: enum u8 {
	STARTER,  // ★ — class starter, id 0, always allocated
	SMALL,    // ● filled when allocated, ○ when locked, ◉ when available
	NOTABLE,  // ◆ instead of ●; bigger effect
	CAPSTONE, // ✦ — branch tip / central capstone
}

Skill_Payload_Kind :: enum u8 {
	NONE,
	STAT_MOD,     // payload_id = Stat_Effect; payload_value = scalar
	SPELL_UNLOCK, // payload_id = index into spells_registry (Phase 3 wire)
	ITEM_GRANT,   // payload_id = item table index (Phase 2 step j)
}

// Tags a STAT_MOD node by which gameplay scalar it tweaks. Adding one is
// a 3-step task: append here, sum it where the value is read (e.g.
// idle_drift_mult), tag the relevant Skill_Node payload_id.
Stat_Effect :: enum u16 {
	NONE,
	IDLE_DRIFT_PCT,        // additive % to cfg.idle_drift_max
	SHAKE_PCT,             // additive % to shake amplitude (negative reduces)
	GRAVITY_PCT,
	TRAIL_LIFE_PCT,
	GOLD_DROP_VALUE_PCT,
	GOLD_DROP_CHANCE_PCT,
	XP_PER_CMD_BONUS,      // flat bonus added to XP_PER_ENTER
	DRUM_DURATION_PCT,
	XP_GAIN_PCT,           // multiplier applied to all XP earned
	SEARCH_BRIGHTNESS_PCT,
}

// Compact node literal — authored once in rpg_tree_<class>.odin.
Skill_Node :: struct {
	id:            u8,
	kind:          Skill_Node_Kind,
	branch:        u8, // 0..3 (or 255 for starter / central capstone)
	x, y:          f32,
	prereqs:       bit_set[0 ..< SKILL_NODES_PER_TREE; u32],
	name:          string,
	desc:          string,
	payload:       Skill_Payload_Kind,
	payload_id:    u16,
	payload_value: f32,
}

Skill_Tree :: struct {
	nodes: [SKILL_NODES_PER_TREE]Skill_Node,
	// True for any id that has been authored (so unauthored class trees
	// render as 'just the starter' without spurious zeroed nodes).
	defined: [SKILL_NODES_PER_TREE]bool,
}

class_trees: [RPG_Class]Skill_Tree

// Called from rpg_tree_<class>.odin's @(init) hook to install one node.
// Marked contextless so it can be invoked from @(init) procs.
register_skill_node :: proc "contextless" (c: RPG_Class, n: Skill_Node) {
	if int(n.id) >= SKILL_NODES_PER_TREE do return
	class_trees[c].nodes[n.id] = n
	class_trees[c].defined[n.id] = true
}

// ---------------------------------------------------------------------------
// Allocation state + helpers
// ---------------------------------------------------------------------------

node_allocated :: proc(c: RPG_Class, id: u8) -> bool {
	if id == 0 do return true // starter implicit
	return rpg.allocated[c][id]
}

// A node is available if any of its prereqs is allocated. Starter has no
// prereqs and is always allocated, so its neighbors fall out naturally.
node_available :: proc(c: RPG_Class, id: u8) -> bool {
	if id == 0 do return false // already allocated
	if !class_trees[c].defined[id] do return false
	if node_allocated(c, id) do return false
	prereqs := class_trees[c].nodes[id].prereqs
	if prereqs == {} do return false
	for p in 0 ..< SKILL_NODES_PER_TREE {
		if p in prereqs && node_allocated(c, u8(p)) do return true
	}
	return false
}

allocate_node :: proc(c: RPG_Class, id: u8) -> bool {
	if rpg.skill_points == 0 do return false
	if !node_available(c, id) do return false
	rpg.allocated[c][id] = true
	rpg.skill_points -= 1
	return true
}

// Sum every allocated STAT_MOD node's payload_value for one Stat_Effect on
// the player's current class tree. Use this everywhere a scalar tweak
// reads a config value: e.g. f := cfg.x * (1 + sum_stat_mod(..., .X_PCT)).
sum_stat_mod :: proc(c: RPG_Class, effect: Stat_Effect) -> f32 {
	if !rpg_active do return 0
	sum: f32 = 0
	tree := &class_trees[c]
	for nid in 1 ..< SKILL_NODES_PER_TREE {
		if !tree.defined[nid] do continue
		if !rpg.allocated[c][nid] do continue
		n := tree.nodes[nid]
		if n.payload != .STAT_MOD do continue
		if Stat_Effect(n.payload_id) != effect do continue
		sum += n.payload_value
	}
	return sum
}

// Refund a node and any dependents whose only path back to the starter
// went through it. Implemented as: clear the node, then BFS from starter
// over still-allocated nodes — anything not reached gets refunded too.
refund_node :: proc(c: RPG_Class, id: u8) -> int {
	if id == 0 do return 0
	if !node_allocated(c, id) do return 0
	rpg.allocated[c][id] = false

	reached: [SKILL_NODES_PER_TREE]bool
	reached[0] = true
	// Repeated sweep until no change; 30 nodes makes this trivial.
	for {
		grew := false
		for nid in 1 ..< SKILL_NODES_PER_TREE {
			if reached[nid] do continue
			if !rpg.allocated[c][nid] do continue
			if !class_trees[c].defined[nid] do continue
			for pid in 0 ..< SKILL_NODES_PER_TREE {
				if pid in class_trees[c].nodes[nid].prereqs && reached[pid] {
					reached[nid] = true
					grew = true
					break
				}
			}
		}
		if !grew do break
	}

	refunded := 1
	for nid in 1 ..< SKILL_NODES_PER_TREE {
		if rpg.allocated[c][nid] && !reached[nid] {
			rpg.allocated[c][nid] = false
			refunded += 1
		}
	}
	rpg.skill_points += u16(refunded)
	return refunded
}

// ---------------------------------------------------------------------------
// UI state
// ---------------------------------------------------------------------------

skill_tree_open: bool
skill_tree_focus: u8 // currently-focused node id

on_skill_tree_toggle :: proc() {
	if !rpg_active do return
	skill_tree_open = !skill_tree_open
	if skill_tree_open do skill_tree_focus = 0
}

// Returns true if the key was consumed.
on_skill_tree_input :: proc(key: rl.KeyboardKey) -> bool {
	if !skill_tree_open do return false
	#partial switch key {
	case .ESCAPE:
		skill_tree_open = false
		return true
	case .ENTER:
		allocate_node(rpg.class, skill_tree_focus)
		return true
	case .R:
		refund_node(rpg.class, skill_tree_focus)
		return true
	case .UP, .DOWN, .LEFT, .RIGHT:
		move_focus(key)
		return true
	}
	return false
}

@(private = "file")
move_focus :: proc(key: rl.KeyboardKey) {
	tree := &class_trees[rpg.class]
	if !tree.defined[skill_tree_focus] && skill_tree_focus != 0 do return

	cur := tree.nodes[skill_tree_focus]
	best_id := skill_tree_focus
	best_score := f32(1e9)
	for nid in 0 ..< SKILL_NODES_PER_TREE {
		if u8(nid) == skill_tree_focus do continue
		if !tree.defined[nid] && nid != 0 do continue
		n := tree.nodes[nid]
		dx := n.x - cur.x
		dy := n.y - cur.y
		// Direction filter — pick the dominant-axis match for the key.
		ok: bool
		#partial switch key {
		case .UP:    ok = dy < -0.1 && abs(dy) >= abs(dx)
		case .DOWN:  ok = dy > 0.1 && abs(dy) >= abs(dx)
		case .LEFT:  ok = dx < -0.1 && abs(dx) >= abs(dy)
		case .RIGHT: ok = dx > 0.1 && abs(dx) >= abs(dy)
		}
		if !ok do continue
		score := dx * dx + dy * dy
		if score < best_score {
			best_score = score
			best_id = u8(nid)
		}
	}
	skill_tree_focus = best_id
}

// ---------------------------------------------------------------------------
// Render
// ---------------------------------------------------------------------------

@(private = "file")
node_glyph :: proc(n: Skill_Node, allocated, available: bool) -> cstring {
	switch n.kind {
	case .STARTER:  return "*"
	case .SMALL:    return allocated ? "@" : (available ? "o" : ".")
	case .NOTABLE:  return allocated ? "#" : (available ? "o" : ".")
	case .CAPSTONE: return allocated ? "&" : (available ? "o" : ".")
	}
	return "."
}

@(private = "file")
tree_bounds :: proc(tree: ^Skill_Tree) -> (minx, miny, maxx, maxy: f32) {
	minx, miny, maxx, maxy = 0, 0, 0, 0 // starter at origin
	for nid in 0 ..< SKILL_NODES_PER_TREE {
		if !tree.defined[nid] && nid != 0 do continue
		n := tree.nodes[nid]
		if n.x < minx do minx = n.x
		if n.y < miny do miny = n.y
		if n.x > maxx do maxx = n.x
		if n.y > maxy do maxy = n.y
	}
	if maxx - minx < 1 { minx -= 1; maxx += 1 }
	if maxy - miny < 1 { miny -= 1; maxy += 1 }
	return
}

draw_skill_tree :: proc() {
	if !skill_tree_open do return
	if !rpg_active do return

	// Translucent dark backdrop — scene keeps animating beneath.
	rl.DrawRectangle(0, 0, i32(window_w), i32(window_h), {0, 0, 0, 200})

	c := rpg.class
	tree := &class_trees[c]
	accent := cfg.accent_color

	// Top header bar
	header_buf: [96]u8
	header_cs, _ := fmt_cstr(header_buf[:],
		" %s   Lv %d   %d unspent ",
		class_name(c), rpg.level, rpg.skill_points)
	header_sz: f32 = 22
	header_w := rl.MeasureTextEx(font, header_cs, header_sz, 1).x
	header_x := (f32(window_w) - header_w) * 0.5
	header_y := f32(20)
	rl.DrawRectangleRec({header_x - 14, header_y - 6, header_w + 28, header_sz + 12},
		{0, 0, 0, 220})
	rl.DrawRectangleLinesEx({header_x - 14, header_y - 6, header_w + 28, header_sz + 12},
		1, {accent.r, accent.g, accent.b, 220})
	rl.DrawTextEx(font, header_cs, {header_x, header_y}, header_sz, 1,
		{cfg.fg_color.r, cfg.fg_color.g, cfg.fg_color.b, 240})

	// Footer hint
	footer_cs: cstring = " [Enter] allocate   [R] refund   [arrows] navigate   [Esc / F10] close "
	footer_sz: f32 = 16
	footer_w := rl.MeasureTextEx(font, footer_cs, footer_sz, 1).x
	footer_x := (f32(window_w) - footer_w) * 0.5
	footer_y := f32(window_h) - 36
	rl.DrawTextEx(font, footer_cs, {footer_x, footer_y}, footer_sz, 1,
		{cfg.fg_color.r, cfg.fg_color.g, cfg.fg_color.b, 200})

	// Tree-space → screen-space transform.
	minx, miny, maxx, maxy := tree_bounds(tree)
	margin: f32 = 80
	avail_w := f32(window_w) - 2 * margin
	avail_h := f32(window_h) - 2 * margin - 80 // header + footer space
	tree_w := maxx - minx
	tree_h := maxy - miny
	scale := min(avail_w / tree_w, avail_h / tree_h)
	if scale > 80 do scale = 80
	cx := f32(window_w) * 0.5
	cy := f32(window_h) * 0.5 + 10
	mx := (minx + maxx) * 0.5
	my := (miny + maxy) * 0.5

	// Edges first — drawn behind nodes.
	edge_col := rl.Color{accent.r, accent.g, accent.b, 90}
	for nid in 0 ..< SKILL_NODES_PER_TREE {
		if !tree.defined[nid] && nid != 0 do continue
		n := tree.nodes[nid]
		nx := cx + (n.x - mx) * scale
		ny := cy + (n.y - my) * scale
		for pid in 0 ..< SKILL_NODES_PER_TREE {
			if !(pid in n.prereqs) do continue
			if !tree.defined[pid] && pid != 0 do continue
			p := tree.nodes[pid]
			px := cx + (p.x - mx) * scale
			py := cy + (p.y - my) * scale
			lit := node_allocated(c, u8(nid)) && node_allocated(c, u8(pid))
			col := lit ? rl.Color{accent.r, accent.g, accent.b, 220} : edge_col
			rl.DrawLineEx({px, py}, {nx, ny}, lit ? 2 : 1, col)
		}
	}

	// Nodes
	pulse := 0.5 + 0.5 * math.sin(f32(elapsed_g) * 4.5)
	glyph_sz: f32 = 28
	for nid in 0 ..< SKILL_NODES_PER_TREE {
		if !tree.defined[nid] && nid != 0 do continue
		n := tree.nodes[nid]
		nx := cx + (n.x - mx) * scale
		ny := cy + (n.y - my) * scale
		alloc := node_allocated(c, u8(nid))
		avail := node_available(c, u8(nid))
		gs := glyph_sz
		if n.kind == .NOTABLE  do gs = 32
		if n.kind == .CAPSTONE do gs = 36
		if n.kind == .STARTER  do gs = 36

		// Color: allocated = full accent, available = pulsing accent, locked = dim.
		col: rl.Color
		if alloc {
			col = {accent.r, accent.g, accent.b, 240}
		} else if avail {
			a := u8(140 + pulse * 100)
			col = {accent.r, accent.g, accent.b, a}
		} else {
			col = {200, 200, 220, 110}
		}

		cs := node_glyph(n, alloc, avail)
		gw := rl.MeasureTextEx(font, cs, gs, 1).x
		rl.DrawTextEx(font, cs, {nx - gw * 0.5, ny - gs * 0.5}, gs, 1, col)

		// Focus ring — a bracketed [ X ] around the focused node.
		if u8(nid) == skill_tree_focus {
			ring_a := u8(160 + pulse * 80)
			ring_col := rl.Color{accent.r, accent.g, accent.b, ring_a}
			r := gs * 0.85
			rl.DrawRectangleLinesEx({nx - r, ny - r, 2 * r, 2 * r}, 2, ring_col)
		}
	}

	// Tooltip for the focused node
	if tree.defined[skill_tree_focus] || skill_tree_focus == 0 {
		n := tree.nodes[skill_tree_focus]
		if len(n.name) == 0 && skill_tree_focus == 0 {
			n.name = class_name(c)
			n.desc = "Class starter"
		}
		if len(n.name) > 0 {
			tip_buf: [128]u8
			tip_cs, _ := fmt_cstr(tip_buf[:], " %s — %s ", n.name, n.desc)
			tip_sz: f32 = 18
			tip_w := rl.MeasureTextEx(font, tip_cs, tip_sz, 1).x
			tx := (f32(window_w) - tip_w) * 0.5
			ty := f32(window_h) - 70
			rl.DrawRectangleRec({tx - 12, ty - 6, tip_w + 24, tip_sz + 12}, {0, 0, 0, 200})
			rl.DrawRectangleLinesEx({tx - 12, ty - 6, tip_w + 24, tip_sz + 12}, 1,
				{accent.r, accent.g, accent.b, 180})
			rl.DrawTextEx(font, tip_cs, {tx, ty}, tip_sz, 1,
				{cfg.fg_color.r, cfg.fg_color.g, cfg.fg_color.b, 230})
		}
	}
}
