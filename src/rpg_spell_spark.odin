package uzo_term

// Lv 2 — Spark on Command
// Every Enter spawns a small ember burst from the cursor. Reuses the rising
// particle pool (EMBER kind) so this spell is essentially free.

@(init, private = "file")
register_spark :: proc "contextless" () {
	register_spell(Spell{
		name           = "Spark on Command",
		level_required = 2,
		trigger        = .ON_COMMAND,
		match          = .ANY,
		fire           = cast_spark,
	})
}

@(private = "file")
cast_spark :: proc() {
	cx := f32(cursor_x_g) * f32(cell_w) + PADDING + f32(cell_w) * 0.5
	cy := f32(cursor_y_g) * f32(cell_h) + PADDING + f32(cell_h) * 0.5
	for _ in 0 ..< 5 do emit_rising(.EMBER, cx, cy)
}
