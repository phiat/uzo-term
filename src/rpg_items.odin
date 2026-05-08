package uzo_term

// Item table + drop logic (Phase 2 step j, uzo-9jw).
//
// Drops fire on every rpg-tracked Enter command at a base 5% chance,
// scaled by GOLD_DROP_CHANCE_PCT from the player's class skill tree. Item
// gold values are scaled by GOLD_DROP_VALUE_PCT.
//
// Inventory cap = INVENTORY_BASE_SLOTS + count of allocated ITEM_GRANT nodes
// on the player's current class tree. When the inventory is full, dropped
// items are auto-sold to gold immediately. Even if no item gets added, the
// player still earns gold value from the drop.

import "core:math/rand"
import rl "vendor:raylib"

Item_Id :: enum u16 {
	NONE,
	COIN_POUCH,
	GEM,
	KEY,
	POTION,
	SCROLL,
	RING,
	RUNE,
	AMULET,
}

Item_Def :: struct {
	name:   string,
	glyph:  rune, // single-rune label for inventory render
	value:  u32,  // base gold value before stat-mod multipliers
	weight: u16,  // rarity weight; higher = more common
}

@(private = "file")
item_table := [Item_Id]Item_Def {
	.NONE       = {name = "",         glyph = '.', value = 0,   weight = 0},
	.COIN_POUCH = {name = "Coin",     glyph = '$', value = 5,   weight = 100},
	.GEM        = {name = "Gem",      glyph = '*', value = 25,  weight = 60},
	.KEY        = {name = "Key",      glyph = '?', value = 15,  weight = 40},
	.POTION     = {name = "Potion",   glyph = '!', value = 30,  weight = 35},
	.SCROLL     = {name = "Scroll",   glyph = '%', value = 40,  weight = 25},
	.RING       = {name = "Ring",     glyph = 'o', value = 60,  weight = 18},
	.RUNE       = {name = "Rune",     glyph = '#', value = 80,  weight = 12},
	.AMULET     = {name = "Amulet",   glyph = 'O', value = 120, weight = 6},
}

@(private = "file") BASE_DROP_CHANCE :: f32(0.05) // 5% per command before stat-mods

// ---------------------------------------------------------------------------
// Inventory helpers
// ---------------------------------------------------------------------------

// Cap is base 4 + count of allocated ITEM_GRANT nodes on the current class.
inventory_capacity :: proc() -> int {
	cap_count := INVENTORY_BASE_SLOTS
	tree := &class_trees[rpg.class]
	for nid in 1 ..< SKILL_NODES_PER_TREE {
		if !tree.defined[nid] do continue
		if !rpg.allocated[rpg.class][nid] do continue
		if tree.nodes[nid].payload == .ITEM_GRANT do cap_count += 1
	}
	return min(cap_count, INVENTORY_MAX_SLOTS)
}

inventory_count :: #force_inline proc() -> int { return int(rpg.inventory_n) }

item_glyph :: #force_inline proc(id: Item_Id) -> rune { return item_table[id].glyph }
item_name  :: #force_inline proc(id: Item_Id) -> string { return item_table[id].name }
item_value :: #force_inline proc(id: Item_Id) -> u32 { return item_table[id].value }

// ---------------------------------------------------------------------------
// Drop logic
// ---------------------------------------------------------------------------

@(private = "file")
pick_random_item :: proc() -> Item_Id {
	total: u32 = 0
	for id in Item_Id {
		if id == .NONE do continue
		total += u32(item_table[id].weight)
	}
	roll := rand.uint32() % total
	cursor: u32 = 0
	for id in Item_Id {
		if id == .NONE do continue
		w := u32(item_table[id].weight)
		if roll < cursor + w do return id
		cursor += w
	}
	return .COIN_POUCH // unreachable
}

// Roll on every rpg-tracked Enter. Hits at BASE_DROP_CHANCE * chance_mult,
// then either pushes to inventory (if room) or auto-sells. Either way, the
// player gets the gold value of the item.
try_command_drop :: proc() {
	chance := BASE_DROP_CHANCE * stat_mult(rpg.class, .GOLD_DROP_CHANCE_PCT)
	if rand.float32() >= chance do return

	id := pick_random_item()
	def := item_table[id]
	gold := u32(f32(def.value) * stat_mult(rpg.class, .GOLD_DROP_VALUE_PCT))
	rpg.gold += gold

	added := false
	if int(rpg.inventory_n) < inventory_capacity() {
		rpg.inventory[rpg.inventory_n] = id
		rpg.inventory_n += 1
		added = true
	}

	// Toast text — show the item if it stuck, otherwise the auto-sell amount.
	if added {
		_, n := fmt_cstr(rpg.drop_toast_text[:],
			"+%s  +%d gold", def.name, gold)
		rpg.drop_toast_len = n
	} else {
		_, n := fmt_cstr(rpg.drop_toast_text[:],
			"+%d gold (full inv)", gold)
		rpg.drop_toast_len = n
	}
	rpg.drop_toast_t = DROP_TOAST_DURATION
}

// ---------------------------------------------------------------------------
// Drop toast render (called from draw_rpg_hud)
// ---------------------------------------------------------------------------

draw_drop_toast :: proc() {
	if rpg.drop_toast_t <= 0 || rpg.drop_toast_len == 0 do return
	t := rpg.drop_toast_t / DROP_TOAST_DURATION // 1 → 0
	eased := 1.0 - t * t
	rise := 36.0 * eased
	alpha := u8(clamp(t, 0, 1) * 255)

	cx := f32(cursor_x_g) * f32(cell_w) + PADDING
	cy := f32(cursor_y_g) * f32(cell_h) + PADDING - rise

	cs := cstring(&rpg.drop_toast_text[0])
	size: f32 = 18
	tw := rl.MeasureTextEx(font, cs, size, 1).x
	px := cx - tw * 0.5
	if px < 8 do px = 8
	if px + tw > f32(window_w) - 8 do px = f32(window_w) - tw - 8
	rl.DrawTextEx(font, cs, {px, cy}, size, 1,
		{cfg.accent_color.r, cfg.accent_color.g, cfg.accent_color.b, alpha})
}
