package uzo_term

// Pure helpers shared across the codebase: string scanning, command
// classification, and tiny math/hash utilities.

import "core:fmt"

// ---------------------------------------------------------------------------
// Math
// ---------------------------------------------------------------------------

ease_out_cubic :: proc(t: f32) -> f32 {
	x := 1.0 - t
	return 1.0 - x * x * x
}

// ---------------------------------------------------------------------------
// Drawing helpers
// ---------------------------------------------------------------------------

// Format into a stack buffer and return a cstring valid for the buffer's
// lifetime, plus the byte length (excluding null terminator). Reserves the
// last byte for the terminator. Pattern:
//
//   buf: [64]u8
//   cs, _ := fmt_cstr(buf[:], "Lv %d  %s", level, class_name)
//   rl.DrawTextEx(font, cs, ...)
fmt_cstr :: #force_inline proc(buf: []u8, format: string, args: ..any) -> (cstring, int) {
	if len(buf) == 0 do return cstring(nil), 0
	s := fmt.bprintf(buf[:len(buf) - 1], format, ..args)
	buf[len(s)] = 0
	return cstring(&buf[0]), len(s)
}

// ---------------------------------------------------------------------------
// Hashing
// ---------------------------------------------------------------------------

fnv1a_32 :: proc(s: string) -> u32 {
	h: u32 = 2166136261
	for b in transmute([]u8)s {
		h = (h ~ u32(b)) * 16777619
	}
	return h
}

// ---------------------------------------------------------------------------
// String scanning
// ---------------------------------------------------------------------------

contains :: proc(s, sub: string) -> bool {
	if len(sub) > len(s) do return false
	for i in 0 ..= len(s) - len(sub) {
		if s[i:i + len(sub)] == sub do return true
	}
	return false
}

// Strip a shell prompt prefix by finding the last "$ " / "# " / "% " / "> ".
// Returns the input unchanged if no prompt-looking suffix is found.
strip_prompt :: proc(s: string) -> string {
	for i := len(s) - 2; i >= 0; i -= 1 {
		if s[i + 1] != ' ' do continue
		c := s[i]
		if c == '$' || c == '#' || c == '%' || c == '>' {
			return s[i + 2:]
		}
	}
	return s
}

// First whitespace-trimmed word, with any leading path prefix stripped:
// "/usr/bin/make" → "make", "  cargo build" → "cargo".
first_command :: proc(line: string) -> string {
	s := line
	for len(s) > 0 && s[0] == ' ' do s = s[1:]
	end := 0
	for end < len(s) && s[end] != ' ' do end += 1
	first := s[:end]
	last_slash := -1
	for i in 0 ..< len(first) {
		if first[i] == '/' do last_slash = i
	}
	return first[last_slash + 1:]
}

// ---------------------------------------------------------------------------
// Command classification
// ---------------------------------------------------------------------------

// True if the input line looks like a build / compile / install command.
// Covers: make / just / ninja / bazel / cmake / gcc / clang / mvn / gradle /
// tsc directly; plus anything that takes ` build`, ` install`, or ` compile`
// as a subcommand (cargo build, go build, npm install, odin build, zig build,
// dotnet build, swift build, pip install, …).
is_build_command :: proc(line: string) -> bool {
	cmd := first_command(line)
	if cmd == "" do return false

	BUILD_LEADERS :: []string {
		"make", "just", "ninja", "bazel", "cmake", "ctest",
		"gcc", "clang", "g++", "cc", "c++",
		"mvn", "gradle", "tsc", "esbuild", "webpack", "rollup",
		"ld", "ar", "ranlib",
	}
	for leader in BUILD_LEADERS {
		if cmd == leader do return true
	}

	return contains(line, " build") || contains(line, " install") || contains(line, " compile")
}

// True for kill / pkill / killall (or any path-prefixed variant).
is_kill_command :: proc(line: string) -> bool {
	cmd := first_command(line)
	return cmd == "kill" || cmd == "pkill" || cmd == "killall"
}

// True for grep / rg / ag / find / ack (or any path-prefixed variant).
is_search_command :: proc(line: string) -> bool {
	cmd := first_command(line)
	return cmd == "grep" || cmd == "rg" || cmd == "ag" || cmd == "find" ||
	       cmd == "ack" || cmd == "fgrep" || cmd == "egrep"
}

// Pull a literal search needle out of a search command line: skip the
// command word and any flag tokens (-X / --foo), then take the next word
// (stripping surrounding quotes). Returns ("", false) if no needle found.
extract_search_needle :: proc(line: string) -> (string, bool) {
	s := line
	for len(s) > 0 && s[0] == ' ' do s = s[1:]
	end := 0
	for end < len(s) && s[end] != ' ' do end += 1
	s = s[end:]
	for len(s) > 0 {
		for len(s) > 0 && s[0] == ' ' do s = s[1:]
		if len(s) == 0 do break
		if s[0] == '-' {
			end = 0
			for end < len(s) && s[end] != ' ' do end += 1
			s = s[end:]
			continue
		}
		if s[0] == '"' || s[0] == '\'' {
			quote := s[0]
			s = s[1:]
			end = 0
			for end < len(s) && s[end] != quote do end += 1
			return s[:end], end > 0
		}
		end = 0
		for end < len(s) && s[end] != ' ' do end += 1
		return s[:end], end > 0
	}
	return "", false
}
