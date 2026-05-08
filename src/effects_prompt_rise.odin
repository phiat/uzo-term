package uzo_term

import gvt "ghosdin:vendor/ghostty_vt"
import rl "vendor:raylib"

// Prompt-rise: when the PTY has been quiet for prompt_rise_quiet_secs, the row
// the cursor is sitting on tweens up from prompt_rise_offset_px below its
// final y over prompt_rise_duration with an ease-out cubic.
//
// "Prompt" is detected as a quiet edge rather than by content: the shell
// finished printing, the cursor settled. This avoids false fires on every
// newline (the heuristic the issue originally proposed) while needing no
// shell integration (OSC 133). Suppressed on the alt-screen so pagers /
// htop / vim don't trigger it.
//
// One-shot per quiet edge: the rise fires once when quiet crosses the
// threshold, and re-arms only when the next byte arrives. If the cursor
// happens to settle on a row that was just risen we tolerate a re-rise,
// since by definition that row is now showing a new prompt.

prompt_rise_state: struct {
	quiet_t:        f32,
	armed_to_fire:  bool, // true after PTY went active; arms the next quiet-edge fire
	on_alt:         bool,
}

row_prompt_rise_until: [TERM_ROWS]f32

// Called from pump_pty whenever bytes arrive from the PTY.
on_pty_bytes :: proc() {
	st := &prompt_rise_state
	st.quiet_t = 0
	st.armed_to_fire = true
}

update_prompt_rise :: proc() {
	if !cfg.prompt_rise_enabled do return
	st := &prompt_rise_state
	st.on_alt = gvt.term_active_screen(&gterm) == .ALTERNATE
	if st.on_alt {
		// Don't rise prompts inside vim/htop/less; their cursor activity
		// during alt-screen sessions doesn't represent a shell prompt.
		st.quiet_t = 0
		return
	}
	dt := rl.GetFrameTime()
	st.quiet_t += dt
	if !st.armed_to_fire do return
	if st.quiet_t < cfg.prompt_rise_quiet_secs do return
	if !cursor_visible_g do return
	if cursor_y_g >= TERM_ROWS do return
	row_prompt_rise_until[cursor_y_g] = elapsed_g + cfg.prompt_rise_duration
	st.armed_to_fire = false
}

// Reset the per-row rise timer when the row is rewritten — keeps us from
// stacking offsets if the row dirty-fires again mid-rise.
on_row_dirty_prompt_rise :: proc(row: u16) {
	if row >= TERM_ROWS do return
	row_prompt_rise_until[row] = 0
}

prompt_rise_offset :: proc(row: u16) -> (dy: f32) {
	if row >= TERM_ROWS do return 0
	until := row_prompt_rise_until[row]
	if until <= 0 || elapsed_g >= until do return 0
	if cfg.prompt_rise_duration <= 0 do return 0
	t := 1.0 - (until - elapsed_g) / cfg.prompt_rise_duration // 0 → 1
	if t < 0 do t = 0
	if t > 1 do t = 1
	eased := ease_out_cubic(t)
	return (1.0 - eased) * cfg.prompt_rise_offset_px
}
