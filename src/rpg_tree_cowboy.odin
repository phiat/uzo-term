package uzo_term

// Console Cowboy skill tree (Phase 2, uzo-ad8 / uzo-7wc).
//
// Theme: git/gh/lazygit power user. Biome is matrix-green; nodes lean into
// version-control vocabulary.
//
// Branches:
//   N — HISTORY  (commit, blame, log; +XP_PER_CMD, steadier glyphs)
//   E — MERGE    (branch, rebase, conflict; +gold drops, less shake)
//   S — REMOTE   (fetch, push, pull; +XP gains on cmds, smoother trail)
//   W — UNDO     (revert, stash, reflog; -gravity/-drum, inventory bumps)
//
// All STAT_MOD nodes carry an explicit payload_id (Stat_Effect tag) — the
// Drifter tree shipped with several missing tags that silently bound to
// .NONE; cross-check each node's desc against the enum when adding new ones.

@(init, private = "file")
register_cowboy_tree :: proc "contextless" () {
	C :: RPG_Class.CONSOLE_COWBOY

	// Starter — id 0, implicit. Authoring the name lets the tooltip read it.
	register_skill_node(C, Skill_Node{
		id     = 0,
		kind   = .STARTER,
		branch = 255,
		x      = 0,
		y      = 0,
		name   = "Console Cowboy",
		desc   = "Class starter — pre-allocated.",
	})

	// ---- NORTH branch — HISTORY ----
	register_skill_node(C, Skill_Node{
		id = 1, kind = .SMALL, branch = 0, x = 0, y = -1,
		prereqs = {0},
		name       = "First Commit",
		desc       = "XP per command +3.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.XP_PER_CMD_BONUS), payload_value = 3,
	})
	register_skill_node(C, Skill_Node{
		id = 5, kind = .SMALL, branch = 0, x = 0, y = -2,
		prereqs = {1},
		name       = "Annotated",
		desc       = "XP per command +3 (stacking).",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.XP_PER_CMD_BONUS), payload_value = 3,
	})
	register_skill_node(C, Skill_Node{
		id = 9, kind = .NOTABLE, branch = 0, x = 0, y = -3,
		prereqs = {5},
		name    = "Spelunker",
		desc    = "Unlock spell: Blame Trace — git blame casts a glyph spotlight.",
		payload = .SPELL_UNLOCK,
	})
	register_skill_node(C, Skill_Node{
		id = 13, kind = .SMALL, branch = 0, x = 0, y = -4,
		prereqs = {9},
		name       = "Log Reader",
		desc       = "Trail particles last +20%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.TRAIL_LIFE_PCT), payload_value = 0.20,
	})
	register_skill_node(C, Skill_Node{
		id = 17, kind = .SMALL, branch = 0, x = 0, y = -5,
		prereqs = {13},
		name       = "Patient Author",
		desc       = "Idle drift -10% (steadier glyphs).",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.IDLE_DRIFT_PCT), payload_value = -0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 21, kind = .NOTABLE, branch = 0, x = 0, y = -6,
		prereqs = {17},
		name    = "Archeologist",
		desc    = "cd-fly reveals an extra cube of context.",
	})
	register_skill_node(C, Skill_Node{
		id = 25, kind = .CAPSTONE, branch = 0, x = 0, y = -7,
		prereqs = {21},
		name       = "Historian",
		desc       = "XP per command +10 — the long game pays.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.XP_PER_CMD_BONUS), payload_value = 10,
	})

	// ---- EAST branch — MERGE ----
	register_skill_node(C, Skill_Node{
		id = 2, kind = .SMALL, branch = 1, x = 1, y = 0,
		prereqs = {0},
		name       = "Brancher",
		desc       = "Gold drop value +10%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.GOLD_DROP_VALUE_PCT), payload_value = 0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 6, kind = .SMALL, branch = 1, x = 2, y = 0,
		prereqs = {2},
		name       = "Rebaser",
		desc       = "Drum-up duration -10%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.DRUM_DURATION_PCT), payload_value = -0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 10, kind = .NOTABLE, branch = 1, x = 3, y = 0,
		prereqs = {6},
		name    = "Conflict Resolver",
		desc    = "Unlock spell: Resolve Pulse — merge conflicts ripple gold.",
		payload = .SPELL_UNLOCK,
	})
	register_skill_node(C, Skill_Node{
		id = 14, kind = .SMALL, branch = 1, x = 4, y = 0,
		prereqs = {10},
		name       = "Cherry Picker",
		desc       = "Gold drop chance +5%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.GOLD_DROP_CHANCE_PCT), payload_value = 0.05,
	})
	register_skill_node(C, Skill_Node{
		id = 18, kind = .SMALL, branch = 1, x = 5, y = 0,
		prereqs = {14},
		name       = "Squasher",
		desc       = "Shake amplitude -10%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.SHAKE_PCT), payload_value = -0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 22, kind = .NOTABLE, branch = 1, x = 6, y = 0,
		prereqs = {18},
		name       = "Maintainer",
		desc       = "Search highlight brightness +20%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.SEARCH_BRIGHTNESS_PCT), payload_value = 0.20,
	})
	register_skill_node(C, Skill_Node{
		id = 26, kind = .CAPSTONE, branch = 1, x = 7, y = 0,
		prereqs = {22},
		name       = "Lord of Branches",
		desc       = "Gold drop chance +20%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.GOLD_DROP_CHANCE_PCT), payload_value = 0.20,
	})

	// ---- SOUTH branch — REMOTE ----
	register_skill_node(C, Skill_Node{
		id = 3, kind = .SMALL, branch = 2, x = 0, y = 1,
		prereqs = {0},
		name       = "Connection",
		desc       = "Trail particles last +10%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.TRAIL_LIFE_PCT), payload_value = 0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 7, kind = .SMALL, branch = 2, x = 0, y = 2,
		prereqs = {3},
		name       = "Synchronized",
		desc       = "Trail particles last +10% (stacking).",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.TRAIL_LIFE_PCT), payload_value = 0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 11, kind = .NOTABLE, branch = 2, x = 0, y = 3,
		prereqs = {7},
		name    = "Mirror",
		desc    = "Unlock spell: Echo Push — git push casts a mirror flash.",
		payload = .SPELL_UNLOCK,
	})
	register_skill_node(C, Skill_Node{
		id = 15, kind = .SMALL, branch = 2, x = 0, y = 4,
		prereqs = {11},
		name       = "Stable Link",
		desc       = "Shake amplitude -10%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.SHAKE_PCT), payload_value = -0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 19, kind = .SMALL, branch = 2, x = 0, y = 5,
		prereqs = {15},
		name       = "Quick Fetch",
		desc       = "XP gains +10%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.XP_GAIN_PCT), payload_value = 0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 23, kind = .NOTABLE, branch = 2, x = 0, y = 6,
		prereqs = {19},
		name    = "Network Admin",
		desc    = "git status output pulses with class accent.",
	})
	register_skill_node(C, Skill_Node{
		id = 27, kind = .CAPSTONE, branch = 2, x = 0, y = 7,
		prereqs = {23},
		name       = "Always Online",
		desc       = "XP gains +30%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.XP_GAIN_PCT), payload_value = 0.30,
	})

	// ---- WEST branch — UNDO ----
	register_skill_node(C, Skill_Node{
		id = 4, kind = .SMALL, branch = 3, x = -1, y = 0,
		prereqs = {0},
		name    = "Pocket Stash",
		desc    = "Inventory +1 slot.",
		payload = .ITEM_GRANT,
	})
	register_skill_node(C, Skill_Node{
		id = 8, kind = .SMALL, branch = 3, x = -2, y = 0,
		prereqs = {4},
		name       = "Reverted",
		desc       = "Shake amplitude -10%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.SHAKE_PCT), payload_value = -0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 12, kind = .NOTABLE, branch = 3, x = -3, y = 0,
		prereqs = {8},
		name    = "Time Walker",
		desc    = "Unlock spell: Reflog Rewind — winds the trail backward.",
		payload = .SPELL_UNLOCK,
	})
	register_skill_node(C, Skill_Node{
		id = 16, kind = .SMALL, branch = 3, x = -4, y = 0,
		prereqs = {12},
		name       = "Cached",
		desc       = "Gravity strength -10%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.GRAVITY_PCT), payload_value = -0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 20, kind = .SMALL, branch = 3, x = -5, y = 0,
		prereqs = {16},
		name       = "Reset Zero",
		desc       = "Drum-up duration -10%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.DRUM_DURATION_PCT), payload_value = -0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 24, kind = .NOTABLE, branch = 3, x = -6, y = 0,
		prereqs = {20},
		name       = "Recoverer",
		desc       = "Idle drift -20% — steadier hands after rollback.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.IDLE_DRIFT_PCT), payload_value = -0.20,
	})
	register_skill_node(C, Skill_Node{
		id = 28, kind = .CAPSTONE, branch = 3, x = -7, y = 0,
		prereqs = {24},
		name       = "Time Master",
		desc       = "Gravity strength -50% — float through history.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.GRAVITY_PCT), payload_value = -0.50,
	})

	// ---- Central capstone — gated on any first-tier branch node ----
	register_skill_node(C, Skill_Node{
		id = 29, kind = .CAPSTONE, branch = 255, x = 1.4, y = -1.4,
		prereqs = {1, 2, 3, 4},
		name       = "The Maintainer",
		desc       = "XP gains +50%. Stacks with every branch capstone.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.XP_GAIN_PCT), payload_value = 0.50,
	})
}
