# uzo-term — terminal + render texture + shaders + 3D camera
#
# Quickstart:
#   just                  # show all recipes
#   just run              # build + run
#   just run --rand       # build + run with randomized effect tunables
#   just play cowboy      # launch as a specific RPG class
#   just play spider --rand
#   just check            # type-check only (no link)
#   just fmt              # format all sources in place

set dotenv-load := false

ghosdin_dir   := "../ghosdin"
ghostty_dir   := ghosdin_dir / "ghostty"
lib_dir       := ghostty_dir / "zig-out/lib"
collection    := "-collection:ghosdin=" + ghosdin_dir
odin_flags    := collection + " -extra-linker-flags:\"-L" + lib_dir + " -lghostty-vt\""
bin           := "uzo-term_bin"
export LD_LIBRARY_PATH := lib_dir

# List available recipes
default:
    @just --list

# ----------------------------------------------------------------------------
# Build
# ----------------------------------------------------------------------------

# Build libghostty-vt (delegates to ghosdin)
build-lib:
    cd {{ghostty_dir}} && zig build -Demit-lib-vt=true -Doptimize=ReleaseFast

# Build uzo-term
build: build-lib
    odin build src -out:{{bin}} {{odin_flags}}

# Optimized release build (-o:speed)
release: build-lib
    odin build src -out:{{bin}} -o:speed {{odin_flags}}

# Debug build (no optimization, debug symbols, runtime bounds checks)
build-debug: build-lib
    odin build src -out:{{bin}} -debug {{odin_flags}}

# Type-check only — fast (no link, no codegen)
check:
    odin check src -no-entry-point {{collection}}

# Format all sources in place (uses odinfmt)
fmt:
    odinfmt -w src

# ----------------------------------------------------------------------------
# Run
# ----------------------------------------------------------------------------

# Build + run (forwards extra args: just run --rand --shake-intensity=12)
run *ARGS: build
    ./{{bin}} {{ARGS}}

# Build + run with randomized effect tunables
rand: build
    ./{{bin}} --rand

# Launch as a specific RPG class (drifter|cowboy|spider|wizard|operator|icebreaker)
# Example: just play cowboy --rand
play CLASS *ARGS: build
    ./{{bin}} --rpg-class={{CLASS}} {{ARGS}}

# Debug build + run with extra args
debug *ARGS: build-debug
    ./{{bin}} {{ARGS}}

# ----------------------------------------------------------------------------
# Clean
# ----------------------------------------------------------------------------

# Remove the uzo-term binary
clean:
    rm -f {{bin}}

# Remove uzo-term binary AND libghostty-vt build artifacts
clean-all: clean
    rm -rf {{ghostty_dir}}/zig-out {{ghostty_dir}}/.zig-cache

# Wipe binary and build fresh (leaves lib alone)
rebuild: clean build
