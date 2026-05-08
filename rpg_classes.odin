package uzo_term

// Class table — single source of truth for class names, CLI short names,
// Lv 10 biome-shift colors, and the verb sets that classify_verb maps to.
//
// To add a class:
//   1. Append to RPG_Class enum (rpg.odin)
//   2. Append a matching Class_Def below at the same enum position

import rl "vendor:raylib"

Class_Def :: struct {
	name:  string,    // shown in HUD + class-change toast
	short: string,    // CLI form for --rpg-class=<short>
	biome: rl.Color,  // Lv 10 biome shift target (cfg.scene_bg)
	verbs: []string,  // exact-match command verbs that classify here
}

@(private = "file") drifter_verbs    := []string{"cd", "ls", "pwd", "pushd", "popd", "tree"}
@(private = "file") cowboy_verbs     := []string{"git", "gh", "tig", "lazygit", "gitk"}
@(private = "file") spider_verbs     := []string{"grep", "rg", "ag", "find", "ack", "fgrep", "egrep", "awk"}
@(private = "file") wizard_verbs     := []string{"vim", "nvim", "nano", "emacs", "vi", "ed", "helix", "hx"}
@(private = "file") operator_verbs   := []string{"make", "cargo", "go", "npm", "yarn", "pnpm", "just", "ninja", "cmake", "zig", "odin", "tsc", "gradle"}
@(private = "file") icebreaker_verbs := []string{"rm", "sudo", "doas", "kill", "pkill", "killall", "chmod", "chown"}

class_table := [RPG_Class]Class_Def {
	.DRIFTER        = {name = "Drifter",        short = "drifter",    biome = {18, 14, 6, 255},  verbs = drifter_verbs},
	.CONSOLE_COWBOY = {name = "Console Cowboy", short = "cowboy",     biome = {2, 18, 8, 255},   verbs = cowboy_verbs},
	.SPIDER         = {name = "Spider",         short = "spider",     biome = {12, 4, 18, 255},  verbs = spider_verbs},
	.TECHNO_WIZARD  = {name = "Techno-Wizard",  short = "wizard",     biome = {18, 4, 14, 255},  verbs = wizard_verbs},
	.OPERATOR       = {name = "Operator",       short = "operator",   biome = {6, 12, 16, 255},  verbs = operator_verbs},
	.ICE_BREAKER    = {name = "Ice-Breaker",    short = "icebreaker", biome = {18, 6, 4, 255},   verbs = icebreaker_verbs},
}

class_name :: proc(c: RPG_Class) -> string {
	return class_table[c].name
}

biome_for_class :: proc(c: RPG_Class) -> rl.Color {
	return class_table[c].biome
}

// Map a stripped command verb to its owning class. Returns DRIFTER as a
// fallback so unmatched / pure-navigation use classifies cleanly.
classify_verb :: proc(verb: string) -> RPG_Class {
	for def, c in class_table {
		for v in def.verbs {
			if verb == v do return c
		}
	}
	return .DRIFTER
}

// Pin class via --rpg-class=<short>. Returns false if no match.
rpg_set_class_by_name :: proc(name: string) -> bool {
	for def, c in class_table {
		if def.short == name {
			rpg.class = c
			rpg.class_locked = true
			return true
		}
	}
	return false
}
