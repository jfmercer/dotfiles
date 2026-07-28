# Helpers for the bats suites: a PATH sandbox and executable stubs.
#
# Why stubs at all: the two scripts worth testing here shell out to commands that
# either do not exist on Linux (`security`, which is macOS-only) or would have
# real side effects (`herdr pane run`, which types into live panes). Stubbing them
# is what lets the whole suite run on both CI runners and lets a test assert what
# the script *tried* to do, not just what it printed.

# Repo root, derived rather than assumed, so a suite can be run from anywhere.
REPO_ROOT="$(cd -P -- "${BATS_TEST_DIRNAME}/../.." && pwd -P)"
export REPO_ROOT

# Create a per-test stub directory at the FRONT of PATH.
#
# $STUB_BIN  where make_stub writes
# $STUB_LOG  a shared log file; stubs append to it and tests read it back
setup_sandbox() {
    STUB_BIN="$BATS_TEST_TMPDIR/bin"
    STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
    mkdir -p "$STUB_BIN"
    : >"$STUB_LOG"
    PATH="$STUB_BIN:$PATH"
    export PATH STUB_BIN STUB_LOG
}

# make_stub <name>   -- body read from stdin, appended after a bash shebang.
# The body can use $STUB_LOG (exported) to record its arguments.
make_stub() {
    local name="$1"
    {
        printf '#!/usr/bin/env bash\n'
        cat
    } >"$STUB_BIN/$name"
    chmod +x "$STUB_BIN/$name"
}

# Print a PATH containing nothing but the stub directory, so
# `command -v <anything unstubbed>` fails. This is how the "dependency not
# installed" branches are exercised deterministically: testing for a command's
# absence by editing a real PATH is not reproducible, since jq lives in /usr/bin
# on Ubuntu but /opt/homebrew/bin on macOS.
#
# Use it per-invocation, not by assigning to the test shell's PATH:
#
#     run env PATH="$(only_stubs)" "$SCRIPT"
#
# bats' own post-test cleanup shells out to rm, so a truncated PATH in the test
# shell breaks the harness rather than the code under test.
#
# `env`, `bash` and `cat` are symlinked in regardless -- without them a
# `#!/usr/bin/env bash` script cannot start at all, and the test would be
# measuring the shebang failing instead of the branch under test. Name any other
# command that should stay reachable as an argument.
only_stubs() {
    local tool src
    for tool in env bash cat "$@"; do
        src="$(command -v "$tool" 2>/dev/null)" || continue
        # Skip builtins, for which command -v prints a bare name, not a path.
        case "$src" in /*) ;; *) continue ;; esac
        [ -e "$STUB_BIN/$tool" ] || ln -s "$src" "$STUB_BIN/$tool"
    done
    printf '%s' "$STUB_BIN"
}

# Every line the stubs logged, in order.
stub_calls() {
    cat "$STUB_LOG"
}

assert_success() {
    if [ "$status" -ne 0 ]; then
        printf 'expected success, got exit %s\noutput: %s\n' "$status" "$output" >&2
        return 1
    fi
}

assert_failure() {
    if [ "$status" -eq 0 ]; then
        printf 'expected failure, got exit 0\noutput: %s\n' "$output" >&2
        return 1
    fi
}

# assert_output_contains <substring>
assert_output_contains() {
    case "$output" in
        *"$1"*) ;;
        *)
            printf 'expected output to contain: %s\nactual output: %s\n' "$1" "$output" >&2
            return 1
            ;;
    esac
}

# assert_output_lacks <substring> -- for the secrecy assertions, where the point
# is that a value must NOT be echoed.
assert_output_lacks() {
    case "$output" in
        *"$1"*)
            printf 'expected output NOT to contain: %s\nactual output: %s\n' "$1" "$output" >&2
            return 1
            ;;
    esac
}

# assert_equal <actual> <expected>
assert_equal() {
    if [ "$1" != "$2" ]; then
        printf 'not equal:\n  actual:   %q\n  expected: %q\n' "$1" "$2" >&2
        return 1
    fi
}
