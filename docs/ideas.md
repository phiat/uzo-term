# uzo-term Effect Ideas

## Per-Keypress / Interaction

### 1. Ripple on keypress
Each keystroke spawns a circular ripple that expands outward from the key's glyph position on screen. Multiple keypresses stack. Could be a shader effect or drawn in 2D with fading rings.

### 2. Key trails / afterimage
Characters linger as ghost copies that fade out, sliding slightly downward or in the typing direction. Fast typists get a comet tail of characters.

### 3. Enter explosion
Instead of (or alongside) the shake — on Enter, the current line's glyphs burst outward as particles, then snap back into place in ~300ms. Like a rubber-band slingshot.

---

## Output / Command Detection

### 4. `ls` — glyphs rain down
When `ls` output appears, filenames don't just appear — they fall from the top of the screen into their final positions, Matrix-style. Directories could glow differently as they land.

### 5. `git` — commit graph in 3D background
When a `git log` or `git status` runs, the 3D background scene temporarily morphs into a floating DAG of commit nodes. Nodes pulse, edges connect with beams.

### 6. Error / non-zero exit — screen crack
When stderr output or a command fails, a crack/shatter overlay spreads from the cursor position. Could be done with a shader (voronoi fracture lines) that fades in a second.

### 7. `cd` — camera fly-through
On `cd`, the 3D background camera swoops — like flying through a tunnel into a new room. New "environment" could reflect the directory depth (deeper = darker/closer walls).

---

## Persistent / Ambient

### 8. Cursor gravity well
Nearby glyphs subtly warp toward the cursor, like a lens distortion around it. Could be done per-cell in the draw loop by offsetting render position slightly.

### 9. Line age decay
Older lines of output gradually desaturate or dim — recent output is bright, history fades toward gray. Gives a sense of "time" flowing through the terminal.

### 10. Idle mode — glyphs drift
After N seconds of inactivity, characters start slowly drifting from their grid positions with slight sine waves, like seaweed. First keypress snaps everything back.

---

## Round 2

### 11. Typing rhythm visualizer
Track inter-keypress timing. Fast bursts make the terminal glow warmer (orange/red), slow deliberate typing keeps it cool (blue/teal). The color bleeds into the background and fades back to neutral after a second of pause. Rewards flow state.

### 12. `sudo` — red alert mode
Detecting `sudo` in the input line triggers a subtle pulsing red vignette around the screen edges for the duration of the elevated session. Calm, not alarming — just a constant reminder you're in dangerous territory.

### 13. Scrollback depth fog
As you scroll up through history, a depth-of-field fog rolls in — distant lines get a slight blur and color shift toward the 3D background palette, as if you're peering through glass into the past. Scroll back down and it clears.

### 14. Character substitution glitch
On command output, certain characters briefly flicker through random glyphs before resolving to their final value — like a CRT scanning in. Duration proportional to line length. Could be per-line on arrival or global on a timer.

### 15. `ping` / long-running commands — heartbeat pulse
Detect commands that produce periodic output (ping, watch, tail -f). Each new output line triggers a single soft pulse — the whole terminal brightens slightly then fades. Output rhythm becomes visible as a heartbeat.
