package uzo_term

// Lv 10 — Biome Shift
// First-time-only palette change — cfg.scene_bg jumps to a class-themed
// color (amber Drifter, matrix-green Cowboy, web-violet Spider, neon-pink
// Wizard, steel-blue Operator, rust-red Ice-Breaker). Persists for the
// session. Phase 2 will expand this with a smooth palette tween and a
// per-class biome that retunes during Class change toasts.

@(init, private = "file")
register_biome_shift :: proc "contextless" () {
	register_spell(Spell{
		name           = "Biome Shift",
		level_required = 10,
		trigger        = .ON_LEVEL_UP,
		match          = .ANY,
		fire           = cast_biome_shift,
		one_shot       = true,
	})
}

@(private = "file")
cast_biome_shift :: proc() {
	cfg.scene_bg = biome_for_class(rpg.class)
}
