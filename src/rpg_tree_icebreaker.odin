package uzo_term

// Ice-Breaker skill tree (Phase 2, uzo-ad8).
//
// Theme: rm/sudo/kill/chmod/chown — the destructive-ops specialist.
// Biome is rust red; nodes lean into cleave / override / lockpick talk.
//
// Branches:
//   N — CLEAVE    (force-delete, destroy; -shake (steady hands), +XP_PER_CMD)
//   E — OVERRIDE  (sudo, escalate; +XP gains, +search brightness)
//   S — LOCKPICK  (chmod, chown, access; -gravity, gold value)
//   W — FROST     (preserve, freeze; -drum duration, -idle drift, inventory)
//
// All STAT_MOD nodes carry an explicit payload_id (Stat_Effect tag) — the
// Drifter tree shipped with several missing tags that silently bound to
// .NONE; cross-check each node's desc against the enum when adding new ones.

@(init, private = "file")
register_icebreaker_tree :: proc "contextless" () {
	C :: RPG_Class.ICE_BREAKER

	// Starter — id 0, implicit.
	register_skill_node(C, Skill_Node{
		id     = 0,
		kind   = .STARTER,
		branch = 255,
		x      = 0,
		y      = 0,
		name   = "Ice-Breaker",
		desc   = "Class starter — pre-allocated.",
	})

	// ---- NORTH branch — CLEAVE ----
	register_skill_node(C, Skill_Node{
		id = 1, kind = .SMALL, branch = 0, x = 0, y = -1,
		prereqs = {0},
		name       = "Steady Strike",
		desc       = "Shake amplitude -10%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.SHAKE_PCT), payload_value = -0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 5, kind = .SMALL, branch = 0, x = 0, y = -2,
		prereqs = {1},
		name       = "Sure Hand",
		desc       = "Shake amplitude -10% (stacking).",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.SHAKE_PCT), payload_value = -0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 9, kind = .NOTABLE, branch = 0, x = 0, y = -3,
		prereqs = {5},
		name    = "Cleaver",
		desc    = "Unlock spell: Cleave Strike — rm casts a glyph slash.",
		payload = .SPELL_UNLOCK,
	})
	register_skill_node(C, Skill_Node{
		id = 13, kind = .SMALL, branch = 0, x = 0, y = -4,
		prereqs = {9},
		name       = "Heavy Blow",
		desc       = "XP per command +3.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.XP_PER_CMD_BONUS), payload_value = 3,
	})
	register_skill_node(C, Skill_Node{
		id = 17, kind = .SMALL, branch = 0, x = 0, y = -5,
		prereqs = {13},
		name       = "Reaper",
		desc       = "XP per command +3 (stacking).",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.XP_PER_CMD_BONUS), payload_value = 3,
	})
	register_skill_node(C, Skill_Node{
		id = 21, kind = .NOTABLE, branch = 0, x = 0, y = -6,
		prereqs = {17},
		name    = "Cataclysm",
		desc    = "rm/kill commands trigger an extended shockwave.",
	})
	register_skill_node(C, Skill_Node{
		id = 25, kind = .CAPSTONE, branch = 0, x = 0, y = -7,
		prereqs = {21},
		name       = "Annihilator",
		desc       = "XP per command +10.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.XP_PER_CMD_BONUS), payload_value = 10,
	})

	// ---- EAST branch — OVERRIDE ----
	register_skill_node(C, Skill_Node{
		id = 2, kind = .SMALL, branch = 1, x = 1, y = 0,
		prereqs = {0},
		name       = "Privilege",
		desc       = "XP gains +5%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.XP_GAIN_PCT), payload_value = 0.05,
	})
	register_skill_node(C, Skill_Node{
		id = 6, kind = .SMALL, branch = 1, x = 2, y = 0,
		prereqs = {2},
		name       = "Sudoer",
		desc       = "XP gains +5% (stacking).",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.XP_GAIN_PCT), payload_value = 0.05,
	})
	register_skill_node(C, Skill_Node{
		id = 10, kind = .NOTABLE, branch = 1, x = 3, y = 0,
		prereqs = {6},
		name    = "Override",
		desc    = "Unlock spell: Override Pulse — sudo invocation flares red.",
		payload = .SPELL_UNLOCK,
	})
	register_skill_node(C, Skill_Node{
		id = 14, kind = .SMALL, branch = 1, x = 4, y = 0,
		prereqs = {10},
		name       = "Bypass",
		desc       = "Search highlight brightness +20%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.SEARCH_BRIGHTNESS_PCT), payload_value = 0.20,
	})
	register_skill_node(C, Skill_Node{
		id = 18, kind = .SMALL, branch = 1, x = 5, y = 0,
		prereqs = {14},
		name       = "Escalate",
		desc       = "XP gains +10%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.XP_GAIN_PCT), payload_value = 0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 22, kind = .NOTABLE, branch = 1, x = 6, y = 0,
		prereqs = {18},
		name    = "Root Access",
		desc    = "sudo commands pulse the vignette stronger.",
	})
	register_skill_node(C, Skill_Node{
		id = 26, kind = .CAPSTONE, branch = 1, x = 7, y = 0,
		prereqs = {22},
		name       = "Sovereign",
		desc       = "XP gains +30%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.XP_GAIN_PCT), payload_value = 0.30,
	})

	// ---- SOUTH branch — LOCKPICK ----
	register_skill_node(C, Skill_Node{
		id = 3, kind = .SMALL, branch = 2, x = 0, y = 1,
		prereqs = {0},
		name       = "Pry",
		desc       = "Gravity strength -10%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.GRAVITY_PCT), payload_value = -0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 7, kind = .SMALL, branch = 2, x = 0, y = 2,
		prereqs = {3},
		name       = "Pick",
		desc       = "Gravity strength -10% (stacking).",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.GRAVITY_PCT), payload_value = -0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 11, kind = .NOTABLE, branch = 2, x = 0, y = 3,
		prereqs = {7},
		name    = "Locksmith",
		desc    = "Unlock spell: Lockpick Pulse — chmod casts an unlock chime.",
		payload = .SPELL_UNLOCK,
	})
	register_skill_node(C, Skill_Node{
		id = 15, kind = .SMALL, branch = 2, x = 0, y = 4,
		prereqs = {11},
		name       = "Tumbler",
		desc       = "Gold drop value +10%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.GOLD_DROP_VALUE_PCT), payload_value = 0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 19, kind = .SMALL, branch = 2, x = 0, y = 5,
		prereqs = {15},
		name       = "Master Key",
		desc       = "Gold drop chance +5%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.GOLD_DROP_CHANCE_PCT), payload_value = 0.05,
	})
	register_skill_node(C, Skill_Node{
		id = 23, kind = .NOTABLE, branch = 2, x = 0, y = 6,
		prereqs = {19},
		name    = "Vault Cracker",
		desc    = "chmod outputs pulse with class accent.",
	})
	register_skill_node(C, Skill_Node{
		id = 27, kind = .CAPSTONE, branch = 2, x = 0, y = 7,
		prereqs = {23},
		name       = "Skeleton Key",
		desc       = "Gold drop chance +30%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.GOLD_DROP_CHANCE_PCT), payload_value = 0.30,
	})

	// ---- WEST branch — FROST ----
	register_skill_node(C, Skill_Node{
		id = 4, kind = .SMALL, branch = 3, x = -1, y = 0,
		prereqs = {0},
		name    = "Cold Storage",
		desc    = "Inventory +1 slot.",
		payload = .ITEM_GRANT,
	})
	register_skill_node(C, Skill_Node{
		id = 8, kind = .SMALL, branch = 3, x = -2, y = 0,
		prereqs = {4},
		name       = "Slow Tempo",
		desc       = "Drum-up duration -10%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.DRUM_DURATION_PCT), payload_value = -0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 12, kind = .NOTABLE, branch = 3, x = -3, y = 0,
		prereqs = {8},
		name    = "Frostbinder",
		desc    = "Unlock spell: Frost Bind — kill commands freeze a glyph.",
		payload = .SPELL_UNLOCK,
	})
	register_skill_node(C, Skill_Node{
		id = 16, kind = .SMALL, branch = 3, x = -4, y = 0,
		prereqs = {12},
		name       = "Iceblock",
		desc       = "Idle drift -10%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.IDLE_DRIFT_PCT), payload_value = -0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 20, kind = .SMALL, branch = 3, x = -5, y = 0,
		prereqs = {16},
		name       = "Glacier",
		desc       = "Idle drift -10% (stacking).",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.IDLE_DRIFT_PCT), payload_value = -0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 24, kind = .NOTABLE, branch = 3, x = -6, y = 0,
		prereqs = {20},
		name       = "Permafrost",
		desc       = "Trail particles last +20% — frozen afterimages linger.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.TRAIL_LIFE_PCT), payload_value = 0.20,
	})
	register_skill_node(C, Skill_Node{
		id = 28, kind = .CAPSTONE, branch = 3, x = -7, y = 0,
		prereqs = {24},
		name       = "Absolute Zero",
		desc       = "Drum-up duration -50%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.DRUM_DURATION_PCT), payload_value = -0.50,
	})

	// ---- Central capstone — gated on any first-tier branch node ----
	register_skill_node(C, Skill_Node{
		id = 29, kind = .CAPSTONE, branch = 255, x = 1.4, y = -1.4,
		prereqs = {1, 2, 3, 4},
		name       = "Glacier Lord",
		desc       = "XP gains +50%. Stacks with every branch capstone.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.XP_GAIN_PCT), payload_value = 0.50,
	})
}
