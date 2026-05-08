package uzo_term

// Biome overlays — once Lv 10 fires biome shift, each class gets a permanent
// ambient underlay (sinwave ribbons, geometric motifs, etc.) bordering the
// screen. The dispatcher reads the per-class draw proc out of biome_table;
// biomes are drawn from draw_pass1b, AFTER all cell content but BEFORE the
// HUD pill, so they sit visually under the HUD but over the term layer.
//
// Each biome lives in rpg_biome_<class>.odin. To add one:
//   1. Implement draw_<class>_biome()
//   2. Register it via @(init): register_biome(.YOUR_CLASS, draw_..._biome)
// No central edits required; unregistered classes simply render no overlay.

biome_table: [RPG_Class]proc()

// Called from each rpg_biome_<class>.odin's @(init) hook. Marked contextless
// so it can be invoked from @(init) procs (which Odin requires to be
// contextless).
register_biome :: proc "contextless" (c: RPG_Class, fn: proc()) {
	biome_table[c] = fn
}

draw_biome_overlay :: proc() {
	if !rpg.biome_shifted do return
	if fn := biome_table[rpg.class]; fn != nil do fn()
}
