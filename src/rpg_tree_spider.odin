package uzo_term

// Spider skill tree (Phase 2, uzo-ad8).
//
// Theme: grep / rg / find / awk / ack — the pattern-matching web crawler.
// Biome is violet web; nodes lean into search/reveal/pattern vocabulary.
//
// Branches:
//   N — REVEAL    (brightness, illumination; +SEARCH_BRIGHTNESS, +trail life)
//   E — PATTERN   (regex, capture; +XP_PER_CMD ladder)
//   S — CRAWL     (recursion, depth; -gravity/-shake, smoother nav)
//   W — INDEX     (cache, history; +XP_GAIN, gold chance, inventory)
//
// All STAT_MOD nodes carry an explicit payload_id (Stat_Effect tag) — the
// Drifter tree shipped with several missing tags that silently bound to
// .NONE; cross-check each node's desc against the enum when adding new ones.

@(init, private = "file")
register_spider_tree :: proc "contextless" () {
	C :: RPG_Class.SPIDER

	// Starter — id 0, implicit.
	register_skill_node(C, Skill_Node{
		id     = 0,
		kind   = .STARTER,
		branch = 255,
		x      = 0,
		y      = 0,
		name   = "Spider",
		desc   = "Class starter — pre-allocated.",
	})

	// ---- NORTH branch — REVEAL ----
	register_skill_node(C, Skill_Node{
		id = 1, kind = .SMALL, branch = 0, x = 0, y = -1,
		prereqs = {0},
		name       = "Sharp Eye",
		desc       = "Search highlight brightness +20%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.SEARCH_BRIGHTNESS_PCT), payload_value = 0.20,
	})
	register_skill_node(C, Skill_Node{
		id = 5, kind = .SMALL, branch = 0, x = 0, y = -2,
		prereqs = {1},
		name       = "Spotlight",
		desc       = "Search highlight brightness +20% (stacking).",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.SEARCH_BRIGHTNESS_PCT), payload_value = 0.20,
	})
	register_skill_node(C, Skill_Node{
		id = 9, kind = .NOTABLE, branch = 0, x = 0, y = -3,
		prereqs = {5},
		name    = "Webwalker",
		desc    = "Unlock spell: Web Cast — radial reveal pulse on grep.",
		payload = .SPELL_UNLOCK,
	})
	register_skill_node(C, Skill_Node{
		id = 13, kind = .SMALL, branch = 0, x = 0, y = -4,
		prereqs = {9},
		name       = "Lantern",
		desc       = "Trail particles last +20%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.TRAIL_LIFE_PCT), payload_value = 0.20,
	})
	register_skill_node(C, Skill_Node{
		id = 17, kind = .SMALL, branch = 0, x = 0, y = -5,
		prereqs = {13},
		name       = "Glare",
		desc       = "Idle drift -10% (steadier focus).",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.IDLE_DRIFT_PCT), payload_value = -0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 21, kind = .NOTABLE, branch = 0, x = 0, y = -6,
		prereqs = {17},
		name    = "X-Ray",
		desc    = "find/grep results pulse with class accent.",
	})
	register_skill_node(C, Skill_Node{
		id = 25, kind = .CAPSTONE, branch = 0, x = 0, y = -7,
		prereqs = {21},
		name       = "Eight Eyes",
		desc       = "Search highlight brightness +50%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.SEARCH_BRIGHTNESS_PCT), payload_value = 0.50,
	})

	// ---- EAST branch — PATTERN ----
	register_skill_node(C, Skill_Node{
		id = 2, kind = .SMALL, branch = 1, x = 1, y = 0,
		prereqs = {0},
		name       = "Pattern Sense",
		desc       = "XP per command +3.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.XP_PER_CMD_BONUS), payload_value = 3,
	})
	register_skill_node(C, Skill_Node{
		id = 6, kind = .SMALL, branch = 1, x = 2, y = 0,
		prereqs = {2},
		name       = "Capture Group",
		desc       = "XP per command +3 (stacking).",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.XP_PER_CMD_BONUS), payload_value = 3,
	})
	register_skill_node(C, Skill_Node{
		id = 10, kind = .NOTABLE, branch = 1, x = 3, y = 0,
		prereqs = {6},
		name    = "Engine",
		desc    = "Unlock spell: Match Storm — every match flares.",
		payload = .SPELL_UNLOCK,
	})
	register_skill_node(C, Skill_Node{
		id = 14, kind = .SMALL, branch = 1, x = 4, y = 0,
		prereqs = {10},
		name       = "Greedy",
		desc       = "Gold drop value +10%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.GOLD_DROP_VALUE_PCT), payload_value = 0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 18, kind = .SMALL, branch = 1, x = 5, y = 0,
		prereqs = {14},
		name       = "Lazy",
		desc       = "Drum-up duration -10%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.DRUM_DURATION_PCT), payload_value = -0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 22, kind = .NOTABLE, branch = 1, x = 6, y = 0,
		prereqs = {18},
		name    = "Compiler",
		desc    = "ls/find output gains a soft glow.",
	})
	register_skill_node(C, Skill_Node{
		id = 26, kind = .CAPSTONE, branch = 1, x = 7, y = 0,
		prereqs = {22},
		name       = "Engine Master",
		desc       = "XP per command +10.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.XP_PER_CMD_BONUS), payload_value = 10,
	})

	// ---- SOUTH branch — CRAWL ----
	register_skill_node(C, Skill_Node{
		id = 3, kind = .SMALL, branch = 2, x = 0, y = 1,
		prereqs = {0},
		name       = "Step In",
		desc       = "Idle drift -5%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.IDLE_DRIFT_PCT), payload_value = -0.05,
	})
	register_skill_node(C, Skill_Node{
		id = 7, kind = .SMALL, branch = 2, x = 0, y = 2,
		prereqs = {3},
		name       = "Sticky Feet",
		desc       = "Shake amplitude -10%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.SHAKE_PCT), payload_value = -0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 11, kind = .NOTABLE, branch = 2, x = 0, y = 3,
		prereqs = {7},
		name    = "Net",
		desc    = "Unlock spell: Crawl Net — find casts a grid overlay.",
		payload = .SPELL_UNLOCK,
	})
	register_skill_node(C, Skill_Node{
		id = 15, kind = .SMALL, branch = 2, x = 0, y = 4,
		prereqs = {11},
		name       = "Long Reach",
		desc       = "Gravity strength -10%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.GRAVITY_PCT), payload_value = -0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 19, kind = .SMALL, branch = 2, x = 0, y = 5,
		prereqs = {15},
		name       = "Deep Dive",
		desc       = "Trail particles last +10%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.TRAIL_LIFE_PCT), payload_value = 0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 23, kind = .NOTABLE, branch = 2, x = 0, y = 6,
		prereqs = {19},
		name    = "Multi-Leg",
		desc    = "cd-fly transition shorter — quicker recursion.",
	})
	register_skill_node(C, Skill_Node{
		id = 27, kind = .CAPSTONE, branch = 2, x = 0, y = 7,
		prereqs = {23},
		name       = "Recursive",
		desc       = "XP gains +30%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.XP_GAIN_PCT), payload_value = 0.30,
	})

	// ---- WEST branch — INDEX ----
	register_skill_node(C, Skill_Node{
		id = 4, kind = .SMALL, branch = 3, x = -1, y = 0,
		prereqs = {0},
		name    = "Pocket",
		desc    = "Inventory +1 slot.",
		payload = .ITEM_GRANT,
	})
	register_skill_node(C, Skill_Node{
		id = 8, kind = .SMALL, branch = 3, x = -2, y = 0,
		prereqs = {4},
		name       = "Quick Lookup",
		desc       = "XP gains +5%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.XP_GAIN_PCT), payload_value = 0.05,
	})
	register_skill_node(C, Skill_Node{
		id = 12, kind = .NOTABLE, branch = 3, x = -3, y = 0,
		prereqs = {8},
		name    = "Inverted Index",
		desc    = "Unlock spell: Index Pulse — instant ls glow.",
		payload = .SPELL_UNLOCK,
	})
	register_skill_node(C, Skill_Node{
		id = 16, kind = .SMALL, branch = 3, x = -4, y = 0,
		prereqs = {12},
		name       = "Hash",
		desc       = "Gravity strength -10%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.GRAVITY_PCT), payload_value = -0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 20, kind = .SMALL, branch = 3, x = -5, y = 0,
		prereqs = {16},
		name       = "Cache",
		desc       = "Drum-up duration -10%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.DRUM_DURATION_PCT), payload_value = -0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 24, kind = .NOTABLE, branch = 3, x = -6, y = 0,
		prereqs = {20},
		name       = "Memory Net",
		desc       = "Gold drop value +20%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.GOLD_DROP_VALUE_PCT), payload_value = 0.20,
	})
	register_skill_node(C, Skill_Node{
		id = 28, kind = .CAPSTONE, branch = 3, x = -7, y = 0,
		prereqs = {24},
		name       = "Total Recall",
		desc       = "Gold drop chance +30%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.GOLD_DROP_CHANCE_PCT), payload_value = 0.30,
	})

	// ---- Central capstone — gated on any first-tier branch node ----
	register_skill_node(C, Skill_Node{
		id = 29, kind = .CAPSTONE, branch = 255, x = 1.4, y = -1.4,
		prereqs = {1, 2, 3, 4},
		name       = "Web Mind",
		desc       = "XP gains +50%. Stacks with every branch capstone.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.XP_GAIN_PCT), payload_value = 0.50,
	})
}
