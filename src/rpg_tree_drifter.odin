package uzo_term

// Drifter skill tree (Phase 2, uzo-ad8).
//
// Theme: wandering navigator — cd, ls, pwd, pushd, popd, tree.
// Branches radiate from a central starter:
//   N — Movement / idle drift
//   E — Discovery / reveals
//   S — Stability / defense
//   W — Economy / gold + inventory
//
// Layout convention (tree-space units):
//   Starter at (0, 0).
//   Each branch occupies 6 small/notable nodes at distance 1..6, plus a
//   capstone at distance 7. Central capstone sits at NE diagonal (1.2, -1.2)
//   and gates on any first-tier node.
//
// Tweaking values is fine — node ids and prereqs must stay stable so saved
// allocations migrate cleanly.

@(init, private = "file")
register_drifter_tree :: proc "contextless" () {
	C :: RPG_Class.DRIFTER

	// Starter — id 0, implicit. Authoring it lets the tooltip read its name.
	register_skill_node(C, Skill_Node{
		id     = 0,
		kind   = .STARTER,
		branch = 255,
		x      = 0,
		y      = 0,
		name   = "Drifter",
		desc   = "Class starter — pre-allocated.",
	})

	// ---- NORTH branch — Movement / idle drift ----
	register_skill_node(C, Skill_Node{
		id = 1, kind = .SMALL, branch = 0, x = 0, y = -1,
		prereqs = {0},
		name    = "Light Step",
		desc    = "Idle drift amplitude +10%.",
		payload = .STAT_MOD, payload_value = 0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 5, kind = .SMALL, branch = 0, x = 0, y = -2,
		prereqs = {1},
		name    = "Tread Lightly",
		desc    = "Idle drift amplitude +10% (stacking).",
		payload = .STAT_MOD, payload_value = 0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 9, kind = .NOTABLE, branch = 0, x = 0, y = -3,
		prereqs = {5},
		name    = "Wandering Eye",
		desc    = "cd-fly reveals an extra cube.",
	})
	register_skill_node(C, Skill_Node{
		id = 13, kind = .SMALL, branch = 0, x = 0, y = -4,
		prereqs = {9},
		name    = "Pathfinder",
		desc    = "pwd output sparkles briefly.",
	})
	register_skill_node(C, Skill_Node{
		id = 17, kind = .SMALL, branch = 0, x = 0, y = -5,
		prereqs = {13},
		name    = "Trail Blazer",
		desc    = "Trail particles last +20%.",
		payload = .STAT_MOD, payload_value = 0.20,
	})
	register_skill_node(C, Skill_Node{
		id = 21, kind = .NOTABLE, branch = 0, x = 0, y = -6,
		prereqs = {17},
		name    = "Wayfinder",
		desc    = "cd commands trigger a directional shimmer.",
	})
	register_skill_node(C, Skill_Node{
		id = 25, kind = .CAPSTONE, branch = 0, x = 0, y = -7,
		prereqs = {21},
		name    = "Open Road",
		desc    = "Idle drift doubled, persistent across the session.",
	})

	// ---- EAST branch — Discovery / reveals ----
	register_skill_node(C, Skill_Node{
		id = 2, kind = .SMALL, branch = 1, x = 1, y = 0,
		prereqs = {0},
		name    = "Sharp Eye",
		desc    = "Search highlight brightness +20%.",
		payload = .STAT_MOD, payload_value = 0.20,
	})
	register_skill_node(C, Skill_Node{
		id = 6, kind = .SMALL, branch = 1, x = 2, y = 0,
		prereqs = {2},
		name    = "Look Closer",
		desc    = "ls output gains a soft glow.",
	})
	register_skill_node(C, Skill_Node{
		id = 10, kind = .NOTABLE, branch = 1, x = 3, y = 0,
		prereqs = {6},
		name    = "Cartographer",
		desc    = "Unlock spell: Map Pulse — wide reveal ping.",
		payload = .SPELL_UNLOCK,
	})
	register_skill_node(C, Skill_Node{
		id = 14, kind = .SMALL, branch = 1, x = 4, y = 0,
		prereqs = {10},
		name    = "Direction Sense",
		desc    = "cd briefly shows a compass overlay.",
	})
	register_skill_node(C, Skill_Node{
		id = 18, kind = .SMALL, branch = 1, x = 5, y = 0,
		prereqs = {14},
		name    = "Curio Hunter",
		desc    = "Gold drop value +10%.",
		payload = .STAT_MOD, payload_value = 0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 22, kind = .NOTABLE, branch = 1, x = 6, y = 0,
		prereqs = {18},
		name    = "Hidden Path",
		desc    = "find/grep results pulse with class accent.",
	})
	register_skill_node(C, Skill_Node{
		id = 26, kind = .CAPSTONE, branch = 1, x = 7, y = 0,
		prereqs = {22},
		name    = "Trailmaster",
		desc    = "Gold drop chance doubled.",
	})

	// ---- SOUTH branch — Stability / defense ----
	register_skill_node(C, Skill_Node{
		id = 3, kind = .SMALL, branch = 2, x = 0, y = 1,
		prereqs = {0},
		name    = "Steady Step",
		desc    = "Shake amplitude -10%.",
		payload = .STAT_MOD, payload_value = -0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 7, kind = .SMALL, branch = 2, x = 0, y = 2,
		prereqs = {3},
		name    = "Bracing",
		desc    = "Shake amplitude -10% (stacking).",
		payload = .STAT_MOD, payload_value = -0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 11, kind = .NOTABLE, branch = 2, x = 0, y = 3,
		prereqs = {7},
		name    = "Stillness",
		desc    = "Unlock spell: Calm — silences shake briefly.",
		payload = .SPELL_UNLOCK,
	})
	register_skill_node(C, Skill_Node{
		id = 15, kind = .SMALL, branch = 2, x = 0, y = 4,
		prereqs = {11},
		name    = "Anchored",
		desc    = "Gravity strength -20%.",
		payload = .STAT_MOD, payload_value = -0.20,
	})
	register_skill_node(C, Skill_Node{
		id = 19, kind = .SMALL, branch = 2, x = 0, y = 5,
		prereqs = {15},
		name    = "Quiet Mind",
		desc    = "Drum-up duration -10%.",
		payload = .STAT_MOD, payload_value = -0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 23, kind = .NOTABLE, branch = 2, x = 0, y = 6,
		prereqs = {19},
		name    = "Settled",
		desc    = "Emerge animation completes faster.",
	})
	register_skill_node(C, Skill_Node{
		id = 27, kind = .CAPSTONE, branch = 2, x = 0, y = 7,
		prereqs = {23},
		name    = "Unmoved",
		desc    = "Shake and gravity reduced by half.",
	})

	// ---- WEST branch — Economy / gold + inventory ----
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
		name    = "Salvager",
		desc    = "Gold drop chance +5%.",
		payload = .STAT_MOD, payload_value = 0.05,
	})
	register_skill_node(C, Skill_Node{
		id = 12, kind = .NOTABLE, branch = 3, x = -3, y = 0,
		prereqs = {8},
		name    = "Wages",
		desc    = "XP per command +5.",
		payload = .STAT_MOD, payload_value = 5,
	})
	register_skill_node(C, Skill_Node{
		id = 16, kind = .SMALL, branch = 3, x = -4, y = 0,
		prereqs = {12},
		name    = "Coinpouch",
		desc    = "Gold drop value +10%.",
		payload = .STAT_MOD, payload_value = 0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 20, kind = .SMALL, branch = 3, x = -5, y = 0,
		prereqs = {16},
		name    = "Quartermaster",
		desc    = "Inventory +1 slot.",
		payload = .ITEM_GRANT,
	})
	register_skill_node(C, Skill_Node{
		id = 24, kind = .NOTABLE, branch = 3, x = -6, y = 0,
		prereqs = {20},
		name    = "Merchant's Eye",
		desc    = "Gold drop chance +10%.",
		payload = .STAT_MOD, payload_value = 0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 28, kind = .CAPSTONE, branch = 3, x = -7, y = 0,
		prereqs = {24},
		name    = "Treasure Hunter",
		desc    = "Gold drop chance tripled.",
	})

	// ---- Central capstone — gated on any first-tier branch node ----
	register_skill_node(C, Skill_Node{
		id = 29, kind = .CAPSTONE, branch = 255, x = 1.4, y = -1.4,
		prereqs = {1, 2, 3, 4},
		name    = "Vagabond",
		desc    = "XP gains +50%. Stacks with all other multipliers.",
	})
}
