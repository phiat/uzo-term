package uzo_term

// Techno-Wizard skill tree (Phase 2, uzo-ad8 / uzo-qzg).
//
// Theme: vim/nvim/emacs/nano/helix — keystroke-economy editor power user.
// Biome is neon pink; nodes lean into motion/command/macro vocabulary.
//
// Branches:
//   N — MOTION   (hjkl/word/zen; -idle drift, -shake, +trail life)
//   E — COMMAND  (ex mode, registers; +XP_PER_CMD ladder)
//   S — MACRO    (record/replay/dot; +trail life, +XP gains)
//   W — FORMAT   (=/gq/indent; -gravity, gold chance, inventory)
//
// All STAT_MOD nodes carry an explicit payload_id (Stat_Effect tag) — the
// Drifter tree shipped with several missing tags that silently bound to
// .NONE; cross-check each node's desc against the enum when adding new ones.

@(init, private = "file")
register_wizard_tree :: proc "contextless" () {
	C :: RPG_Class.TECHNO_WIZARD

	// Starter — id 0, implicit.
	register_skill_node(C, Skill_Node{
		id     = 0,
		kind   = .STARTER,
		branch = 255,
		x      = 0,
		y      = 0,
		name   = "Techno-Wizard",
		desc   = "Class starter — pre-allocated.",
	})

	// ---- NORTH branch — MOTION ----
	register_skill_node(C, Skill_Node{
		id = 1, kind = .SMALL, branch = 0, x = 0, y = -1,
		prereqs = {0},
		name       = "Quick Step",
		desc       = "Idle drift -10% (steadier hands).",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.IDLE_DRIFT_PCT), payload_value = -0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 5, kind = .SMALL, branch = 0, x = 0, y = -2,
		prereqs = {1},
		name       = "Fluent",
		desc       = "Idle drift -10% (stacking).",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.IDLE_DRIFT_PCT), payload_value = -0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 9, kind = .NOTABLE, branch = 0, x = 0, y = -3,
		prereqs = {5},
		name    = "Vimancer",
		desc    = "Unlock spell: Motion Trail — hjkl leaves visible trail.",
		payload = .SPELL_UNLOCK,
	})
	register_skill_node(C, Skill_Node{
		id = 13, kind = .SMALL, branch = 0, x = 0, y = -4,
		prereqs = {9},
		name       = "Easymotion",
		desc       = "Trail particles last +20%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.TRAIL_LIFE_PCT), payload_value = 0.20,
	})
	register_skill_node(C, Skill_Node{
		id = 17, kind = .SMALL, branch = 0, x = 0, y = -5,
		prereqs = {13},
		name       = "Light Cursor",
		desc       = "Shake amplitude -10%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.SHAKE_PCT), payload_value = -0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 21, kind = .NOTABLE, branch = 0, x = 0, y = -6,
		prereqs = {17},
		name    = "Telekinetic",
		desc    = "Cursor leaves a glow on rapid moves.",
	})
	register_skill_node(C, Skill_Node{
		id = 25, kind = .CAPSTONE, branch = 0, x = 0, y = -7,
		prereqs = {21},
		name       = "Movement Master",
		desc       = "Idle drift -50% — zen calm.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.IDLE_DRIFT_PCT), payload_value = -0.50,
	})

	// ---- EAST branch — COMMAND ----
	register_skill_node(C, Skill_Node{
		id = 2, kind = .SMALL, branch = 1, x = 1, y = 0,
		prereqs = {0},
		name       = "Ex Mode",
		desc       = "XP per command +3.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.XP_PER_CMD_BONUS), payload_value = 3,
	})
	register_skill_node(C, Skill_Node{
		id = 6, kind = .SMALL, branch = 1, x = 2, y = 0,
		prereqs = {2},
		name       = "Register",
		desc       = "XP per command +3 (stacking).",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.XP_PER_CMD_BONUS), payload_value = 3,
	})
	register_skill_node(C, Skill_Node{
		id = 10, kind = .NOTABLE, branch = 1, x = 3, y = 0,
		prereqs = {6},
		name    = "Commander",
		desc    = "Unlock spell: Command Pulse — :command flashes accent.",
		payload = .SPELL_UNLOCK,
	})
	register_skill_node(C, Skill_Node{
		id = 14, kind = .SMALL, branch = 1, x = 4, y = 0,
		prereqs = {10},
		name       = "Substitute",
		desc       = "Drum-up duration -10%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.DRUM_DURATION_PCT), payload_value = -0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 18, kind = .SMALL, branch = 1, x = 5, y = 0,
		prereqs = {14},
		name       = "Global",
		desc       = "Gold drop value +10%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.GOLD_DROP_VALUE_PCT), payload_value = 0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 22, kind = .NOTABLE, branch = 1, x = 6, y = 0,
		prereqs = {18},
		name       = "Quickfix",
		desc       = "Search highlight brightness +20%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.SEARCH_BRIGHTNESS_PCT), payload_value = 0.20,
	})
	register_skill_node(C, Skill_Node{
		id = 26, kind = .CAPSTONE, branch = 1, x = 7, y = 0,
		prereqs = {22},
		name       = "Command Master",
		desc       = "XP per command +10.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.XP_PER_CMD_BONUS), payload_value = 10,
	})

	// ---- SOUTH branch — MACRO ----
	register_skill_node(C, Skill_Node{
		id = 3, kind = .SMALL, branch = 2, x = 0, y = 1,
		prereqs = {0},
		name       = "Recorder",
		desc       = "Trail particles last +10%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.TRAIL_LIFE_PCT), payload_value = 0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 7, kind = .SMALL, branch = 2, x = 0, y = 2,
		prereqs = {3},
		name       = "Replayer",
		desc       = "Trail particles last +10% (stacking).",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.TRAIL_LIFE_PCT), payload_value = 0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 11, kind = .NOTABLE, branch = 2, x = 0, y = 3,
		prereqs = {7},
		name    = "Looper",
		desc    = "Unlock spell: Macro Echo — q@q replays a glyph trail.",
		payload = .SPELL_UNLOCK,
	})
	register_skill_node(C, Skill_Node{
		id = 15, kind = .SMALL, branch = 2, x = 0, y = 4,
		prereqs = {11},
		name       = "Rerun",
		desc       = "Drum-up duration -10%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.DRUM_DURATION_PCT), payload_value = -0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 19, kind = .SMALL, branch = 2, x = 0, y = 5,
		prereqs = {15},
		name       = "Dot",
		desc       = "XP gains +10%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.XP_GAIN_PCT), payload_value = 0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 23, kind = .NOTABLE, branch = 2, x = 0, y = 6,
		prereqs = {19},
		name    = "Multitool",
		desc    = "Drum-mute fires on macro replay too.",
	})
	register_skill_node(C, Skill_Node{
		id = 27, kind = .CAPSTONE, branch = 2, x = 0, y = 7,
		prereqs = {23},
		name       = "Eternal Macro",
		desc       = "XP gains +30%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.XP_GAIN_PCT), payload_value = 0.30,
	})

	// ---- WEST branch — FORMAT ----
	register_skill_node(C, Skill_Node{
		id = 4, kind = .SMALL, branch = 3, x = -1, y = 0,
		prereqs = {0},
		name    = "Tidy",
		desc    = "Inventory +1 slot.",
		payload = .ITEM_GRANT,
	})
	register_skill_node(C, Skill_Node{
		id = 8, kind = .SMALL, branch = 3, x = -2, y = 0,
		prereqs = {4},
		name       = "Aligned",
		desc       = "Shake amplitude -10%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.SHAKE_PCT), payload_value = -0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 12, kind = .NOTABLE, branch = 3, x = -3, y = 0,
		prereqs = {8},
		name    = "Reformatter",
		desc    = "Unlock spell: Format Sweep — gq sweeps cells into line.",
		payload = .SPELL_UNLOCK,
	})
	register_skill_node(C, Skill_Node{
		id = 16, kind = .SMALL, branch = 3, x = -4, y = 0,
		prereqs = {12},
		name       = "Indented",
		desc       = "Gravity strength -10%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.GRAVITY_PCT), payload_value = -0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 20, kind = .SMALL, branch = 3, x = -5, y = 0,
		prereqs = {16},
		name       = "Lined Up",
		desc       = "Gravity strength -10% (stacking).",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.GRAVITY_PCT), payload_value = -0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 24, kind = .NOTABLE, branch = 3, x = -6, y = 0,
		prereqs = {20},
		name    = "Beautiful",
		desc    = "Cells render with a baseline glow.",
	})
	register_skill_node(C, Skill_Node{
		id = 28, kind = .CAPSTONE, branch = 3, x = -7, y = 0,
		prereqs = {24},
		name       = "Code Sculptor",
		desc       = "Gold drop chance +30%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.GOLD_DROP_CHANCE_PCT), payload_value = 0.30,
	})

	// ---- Central capstone — gated on any first-tier branch node ----
	register_skill_node(C, Skill_Node{
		id = 29, kind = .CAPSTONE, branch = 255, x = 1.4, y = -1.4,
		prereqs = {1, 2, 3, 4},
		name       = "The Chosen Editor",
		desc       = "XP gains +50%. Stacks with every branch capstone.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.XP_GAIN_PCT), payload_value = 0.50,
	})
}
