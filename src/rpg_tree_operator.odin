package uzo_term

// Operator skill tree (Phase 2, uzo-ad8 / uzo-0wq).
//
// Theme: make/cargo/go/npm/zig/odin/just/ninja/cmake/gradle — the build-tool
// power user. Biome is steel blue; nodes lean into compile/watch/cache talk.
//
// Branches:
//   N — SPEED  (parallel jobs, ccache; -drum duration ladder)
//   E — WATCH  (file watcher, hot reload; +trail life, +XP gains)
//   S — DEPS   (lockfile, resolver; -shake / -gravity, gold value)
//   W — CACHE  (build cache, sccache; +XP_GAIN, drum duration, inventory)
//
// All STAT_MOD nodes carry an explicit payload_id (Stat_Effect tag) — the
// Drifter tree shipped with several missing tags that silently bound to
// .NONE; cross-check each node's desc against the enum when adding new ones.

@(init, private = "file")
register_operator_tree :: proc "contextless" () {
	C :: RPG_Class.OPERATOR

	// Starter — id 0, implicit.
	register_skill_node(C, Skill_Node{
		id     = 0,
		kind   = .STARTER,
		branch = 255,
		x      = 0,
		y      = 0,
		name   = "Operator",
		desc   = "Class starter — pre-allocated.",
	})

	// ---- NORTH branch — SPEED ----
	register_skill_node(C, Skill_Node{
		id = 1, kind = .SMALL, branch = 0, x = 0, y = -1,
		prereqs = {0},
		name       = "Parallel Job",
		desc       = "Drum-up duration -10%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.DRUM_DURATION_PCT), payload_value = -0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 5, kind = .SMALL, branch = 0, x = 0, y = -2,
		prereqs = {1},
		name       = "More Cores",
		desc       = "Drum-up duration -10% (stacking).",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.DRUM_DURATION_PCT), payload_value = -0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 9, kind = .NOTABLE, branch = 0, x = 0, y = -3,
		prereqs = {5},
		name    = "ccache",
		desc    = "Unlock spell: Speed Boost — build commands fire faster anim.",
		payload = .SPELL_UNLOCK,
	})
	register_skill_node(C, Skill_Node{
		id = 13, kind = .SMALL, branch = 0, x = 0, y = -4,
		prereqs = {9},
		name       = "Optimized",
		desc       = "XP per command +3.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.XP_PER_CMD_BONUS), payload_value = 3,
	})
	register_skill_node(C, Skill_Node{
		id = 17, kind = .SMALL, branch = 0, x = 0, y = -5,
		prereqs = {13},
		name       = "JIT",
		desc       = "Idle drift -10%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.IDLE_DRIFT_PCT), payload_value = -0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 21, kind = .NOTABLE, branch = 0, x = 0, y = -6,
		prereqs = {17},
		name    = "Profiler",
		desc    = "Build commands pulse with class accent.",
	})
	register_skill_node(C, Skill_Node{
		id = 25, kind = .CAPSTONE, branch = 0, x = 0, y = -7,
		prereqs = {21},
		name       = "Light Speed",
		desc       = "Drum-up duration -50%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.DRUM_DURATION_PCT), payload_value = -0.50,
	})

	// ---- EAST branch — WATCH ----
	register_skill_node(C, Skill_Node{
		id = 2, kind = .SMALL, branch = 1, x = 1, y = 0,
		prereqs = {0},
		name       = "File Watcher",
		desc       = "Trail particles last +10%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.TRAIL_LIFE_PCT), payload_value = 0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 6, kind = .SMALL, branch = 1, x = 2, y = 0,
		prereqs = {2},
		name       = "Hot Reload",
		desc       = "Trail particles last +10% (stacking).",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.TRAIL_LIFE_PCT), payload_value = 0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 10, kind = .NOTABLE, branch = 1, x = 3, y = 0,
		prereqs = {6},
		name    = "Incremental",
		desc    = "Unlock spell: Watch Pulse — file change ripples accent.",
		payload = .SPELL_UNLOCK,
	})
	register_skill_node(C, Skill_Node{
		id = 14, kind = .SMALL, branch = 1, x = 4, y = 0,
		prereqs = {10},
		name       = "Rebuild",
		desc       = "XP gains +5%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.XP_GAIN_PCT), payload_value = 0.05,
	})
	register_skill_node(C, Skill_Node{
		id = 18, kind = .SMALL, branch = 1, x = 5, y = 0,
		prereqs = {14},
		name       = "Notify",
		desc       = "Shake amplitude -10%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.SHAKE_PCT), payload_value = -0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 22, kind = .NOTABLE, branch = 1, x = 6, y = 0,
		prereqs = {18},
		name    = "Live Reload",
		desc    = "Build commands trigger glyph shimmer.",
	})
	register_skill_node(C, Skill_Node{
		id = 26, kind = .CAPSTONE, branch = 1, x = 7, y = 0,
		prereqs = {22},
		name       = "Always Watching",
		desc       = "XP gains +30%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.XP_GAIN_PCT), payload_value = 0.30,
	})

	// ---- SOUTH branch — DEPS ----
	register_skill_node(C, Skill_Node{
		id = 3, kind = .SMALL, branch = 2, x = 0, y = 1,
		prereqs = {0},
		name       = "Lockfile",
		desc       = "Shake amplitude -10%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.SHAKE_PCT), payload_value = -0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 7, kind = .SMALL, branch = 2, x = 0, y = 2,
		prereqs = {3},
		name       = "Versioned",
		desc       = "Shake amplitude -10% (stacking).",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.SHAKE_PCT), payload_value = -0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 11, kind = .NOTABLE, branch = 2, x = 0, y = 3,
		prereqs = {7},
		name    = "Resolver",
		desc    = "Unlock spell: Dependency Graph — npm install ripples.",
		payload = .SPELL_UNLOCK,
	})
	register_skill_node(C, Skill_Node{
		id = 15, kind = .SMALL, branch = 2, x = 0, y = 4,
		prereqs = {11},
		name       = "Pinned",
		desc       = "Gravity strength -10%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.GRAVITY_PCT), payload_value = -0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 19, kind = .SMALL, branch = 2, x = 0, y = 5,
		prereqs = {15},
		name       = "Audit",
		desc       = "Gold drop value +10%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.GOLD_DROP_VALUE_PCT), payload_value = 0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 23, kind = .NOTABLE, branch = 2, x = 0, y = 6,
		prereqs = {19},
		name       = "Offline",
		desc       = "Idle drift -10% — no network jitter.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.IDLE_DRIFT_PCT), payload_value = -0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 27, kind = .CAPSTONE, branch = 2, x = 0, y = 7,
		prereqs = {23},
		name       = "All Resolved",
		desc       = "Gravity strength -50%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.GRAVITY_PCT), payload_value = -0.50,
	})

	// ---- WEST branch — CACHE ----
	register_skill_node(C, Skill_Node{
		id = 4, kind = .SMALL, branch = 3, x = -1, y = 0,
		prereqs = {0},
		name    = "Build Cache",
		desc    = "Inventory +1 slot.",
		payload = .ITEM_GRANT,
	})
	register_skill_node(C, Skill_Node{
		id = 8, kind = .SMALL, branch = 3, x = -2, y = 0,
		prereqs = {4},
		name       = "sccache",
		desc       = "XP gains +5%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.XP_GAIN_PCT), payload_value = 0.05,
	})
	register_skill_node(C, Skill_Node{
		id = 12, kind = .NOTABLE, branch = 3, x = -3, y = 0,
		prereqs = {8},
		name    = "Cached Hit",
		desc    = "Unlock spell: Cache Pulse — recompile flashes mute green.",
		payload = .SPELL_UNLOCK,
	})
	register_skill_node(C, Skill_Node{
		id = 16, kind = .SMALL, branch = 3, x = -4, y = 0,
		prereqs = {12},
		name       = "Tar Pit",
		desc       = "Drum-up duration -10%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.DRUM_DURATION_PCT), payload_value = -0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 20, kind = .SMALL, branch = 3, x = -5, y = 0,
		prereqs = {16},
		name       = "Memoized",
		desc       = "Drum-up duration -10% (stacking).",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.DRUM_DURATION_PCT), payload_value = -0.10,
	})
	register_skill_node(C, Skill_Node{
		id = 24, kind = .NOTABLE, branch = 3, x = -6, y = 0,
		prereqs = {20},
		name    = "Reuse",
		desc    = "Build cells render brighter (cosmetic).",
	})
	register_skill_node(C, Skill_Node{
		id = 28, kind = .CAPSTONE, branch = 3, x = -7, y = 0,
		prereqs = {24},
		name       = "Total Cache",
		desc       = "Gold drop chance +30%.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.GOLD_DROP_CHANCE_PCT), payload_value = 0.30,
	})

	// ---- Central capstone — gated on any first-tier branch node ----
	register_skill_node(C, Skill_Node{
		id = 29, kind = .CAPSTONE, branch = 255, x = 1.4, y = -1.4,
		prereqs = {1, 2, 3, 4},
		name       = "Master Builder",
		desc       = "XP gains +50%. Stacks with every branch capstone.",
		payload    = .STAT_MOD,
		payload_id = u16(Stat_Effect.XP_GAIN_PCT), payload_value = 0.50,
	})
}
