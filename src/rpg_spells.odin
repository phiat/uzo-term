package uzo_term

// Spell registry & dispatcher. Each spell lives in its own rpg_spell_<name>.odin
// file and registers itself via @(init); this file owns only the data shape,
// the registry storage, and the per-trigger dispatch loops.
//
// Adding a new spell:
//   1. Create rpg_spell_<name>.odin
//   2. Define a file-private cast_<name> proc
//   3. Add @(init) register_<name> proc that calls register_spell(...) with
//      the appropriate level_required, trigger, match, and cast pointer
//
// Adding a new trigger or match kind:
//   1. Extend Spell_Trigger or Spell_Match enum here
//   2. Wire the dispatch / spell_match_satisfied switch below
//   3. Existing spells keep working because the new variant is opt-in

// Where in the lifecycle this spell fires.
Spell_Trigger :: enum u8 {
	ON_COMMAND,   // every Enter — refined by Spell_Match
	ON_LEVEL_UP,  // fires once when rpg.level first crosses level_required
}

// Narrows ON_COMMAND triggers to specific command shapes.
// ANY means 'fires on every command'.
Spell_Match :: enum u8 {
	ANY,
	CD_COMMAND,
	BUILD_COMMAND,
	SEARCH_COMMAND,
	KILL_COMMAND,
}

Spell :: struct {
	name:           string,
	level_required: u16,
	trigger:        Spell_Trigger,
	match:          Spell_Match,
	fire:           proc(),
	// ON_LEVEL_UP spells should set this true (otherwise they re-fire on every
	// keypress past the threshold). ON_COMMAND spells can opt in for once-only
	// behavior. dispatch_levelup_spells force-marks ON_LEVEL_UP fires done as
	// a safety net so a forgotten one_shot=true can't spam.
	one_shot:       bool,
	// Runtime state
	cast_done: bool,
}

MAX_SPELLS :: 128
spells_registry: [MAX_SPELLS]Spell
spells_count:    int

// Called from each rpg_spell_<name>.odin's @(init) hook. Order is irrelevant
// — dispatch only depends on level_required + trigger + match. Marked
// contextless so it can be invoked from @(init) procs (which Odin requires
// to be contextless).
register_spell :: proc "contextless" (s: Spell) {
	if spells_count >= MAX_SPELLS do return
	spells_registry[spells_count] = s
	spells_count += 1
}

// Reset all per-spell runtime state. Called from rpg_reset.
reset_spell_state :: proc() {
	for i in 0 ..< spells_count {
		spells_registry[i].cast_done = false
	}
}

// ---------------------------------------------------------------------------
// Dispatch
// ---------------------------------------------------------------------------

@(private = "file")
spell_match_satisfied :: proc(m: Spell_Match, line: string) -> bool {
	switch m {
	case .ANY:            return true
	case .CD_COMMAND:     return first_command(line) == "cd"
	case .BUILD_COMMAND:  return is_build_command(line)
	case .SEARCH_COMMAND: return is_search_command(line)
	case .KILL_COMMAND:   return is_kill_command(line)
	}
	return false
}

dispatch_command_spells :: proc(line: string) {
	for i in 0 ..< spells_count {
		s := &spells_registry[i]
		if s.trigger != .ON_COMMAND do continue
		if rpg.level < s.level_required do continue
		if s.one_shot && s.cast_done do continue
		if !spell_match_satisfied(s.match, line) do continue
		s.fire()
		if s.one_shot do s.cast_done = true
	}
}

// Fired once per level-up tick from check_level_up. Walks all ON_LEVEL_UP
// spells and casts those newly unlocked.
dispatch_levelup_spells :: proc() {
	for i in 0 ..< spells_count {
		s := &spells_registry[i]
		if s.trigger != .ON_LEVEL_UP do continue
		if rpg.level < s.level_required do continue
		if s.cast_done do continue
		s.fire()
		s.cast_done = true
	}
}
