package uzo_term

// Biome overlays — once Lv 10 fires biome shift, each class gets a permanent
// ambient underlay (sinwave ribbons, geometric motifs, etc.) bordering the
// screen. The dispatcher dispatches to a per-class draw proc; biomes are
// drawn from draw_rpg_hud, AFTER all cell content but BEFORE the HUD pill,
// so they sit visually under the HUD but over the term layer.
//
// Each biome lives in rpg_biome_<class>.odin. To add one:
//   1. Implement draw_<class>_biome()
//   2. Wire it into the switch below

draw_biome_overlay :: proc() {
	if !rpg.biome_shifted do return
	switch rpg.class {
	case .DRIFTER:        draw_drifter_biome()
	case .CONSOLE_COWBOY: // TODO: matrix-rain columns
	case .SPIDER:         // TODO: web lines from corners
	case .TECHNO_WIZARD:  // TODO: rune scroll
	case .OPERATOR:       // TODO: gear corners
	case .ICE_BREAKER:    // TODO: ice cracks
	}
}
