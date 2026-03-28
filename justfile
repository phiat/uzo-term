# uzo-term — terminal + render texture + shaders + 3D camera

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

# Build libghostty-vt (delegates to ghosdin)
build-lib:
    cd {{ghostty_dir}} && zig build -Demit-lib-vt=true -Doptimize=ReleaseFast

# Build uzo-term
build: build-lib
    odin build . -out:{{bin}} {{odin_flags}}

# Build + run (pass extra args: just run --rand)
run *ARGS: build
    ./{{bin}} {{ARGS}}

# Default
dev: run

# Debug build + run
debug: build-lib
    odin build . -out:{{bin}} -debug {{odin_flags}}
    ./{{bin}}

# Type-check only
check:
    odin check . -no-entry-point {{collection}}

# Clean
clean:
    rm -f {{bin}}
