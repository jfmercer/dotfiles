#!/usr/bin/env bats
#
# bin/ghostty-session. This is Ghostty's `initial-command`, which means a bug
# here is not a bug in a convenience script -- it is a terminal that will not
# open. The property worth defending is therefore the boring one: *every* path
# through this script ends at a login shell, including the paths where herdr is
# missing, refuses to start, or exits non-zero.
#
# Two things make it testable at all:
#
#   - $SHELL is stubbed. The script exec's a login shell at every exit; without
#     a stub the suite would hand control to a real interactive zsh and hang.
#   - herdr_candidates() is a function, so a test can point the fallback search
#     somewhere harmless. Left alone it would find the real /opt/homebrew/bin/herdr
#     on a developer machine and attach the test run to a live session.

load helpers/stub.bash

setup() {
    setup_sandbox
    GS="$REPO_ROOT/bin/ghostty-session"

    # Both guards are inherited, and the suite is very likely being run from
    # inside a herdr pane -- which exports HERDR_ENV. Without this, every test
    # below takes the nesting guard and passes for the wrong reason locally
    # while behaving differently on a CI runner.
    unset HERDR_ENV HERDR_AUTOSTART

    make_stub fakeshell <<'STUB'
printf 'shell %s\n' "$*" >>"$STUB_LOG"
STUB
    SHELL="$STUB_BIN/fakeshell"
    export SHELL
}

# Stub herdr so it records how it was called. $HERDR_EXIT makes it fail.
stub_herdr() {
    make_stub herdr <<'STUB'
printf 'herdr argc=%d\n' "$#" >>"$STUB_LOG"
exit "${HERDR_EXIT:-0}"
STUB
}

assert_herdr_not_launched() {
    case "$(stub_calls)" in
        *herdr*)
            printf 'expected herdr NOT to be launched, but calls were:\n%s\n' "$(stub_calls)" >&2
            return 1
            ;;
    esac
}

# ------------------------------------------------------------- the happy path

@test "herdr is launched with no arguments, then the shell takes over" {
    # No arguments is the whole point: bare `herdr` is what means "launch or
    # attach". Passing a session name or `--no-session` would change which of
    # those two happens.
    stub_herdr
    run "$GS"
    assert_success
    assert_equal "$(stub_calls)" "$(printf 'herdr argc=0\nshell -l')"
}

@test "a clean herdr exit says nothing" {
    # Detaching is normal, not an error; only a non-zero exit is worth a line.
    stub_herdr
    run "$GS"
    assert_success
    assert_output_lacks "exited with status"
}

@test "a non-zero herdr exit is reported and still lands in a shell" {
    # `set -e` would abort here without the `|| rc=$?`, and Ghostty would close
    # the window on whatever error herdr had just printed.
    stub_herdr
    HERDR_EXIT=3 run "$GS"
    assert_success
    assert_output_contains "herdr exited with status 3"
    assert_equal "$(stub_calls)" "$(printf 'herdr argc=0\nshell -l')"
}

# ------------------------------------------------------------------- guards

@test "HERDR_ENV means we are already inside a pane, so herdr is not relaunched" {
    # herdr sets HERDR_ENV in every pane and its allow_nested is false, so a
    # nested launch would fail rather than nest. This keeps that from mattering.
    stub_herdr
    HERDR_ENV=1 run "$GS"
    assert_success
    assert_herdr_not_launched
    assert_equal "$(stub_calls)" "shell -l"
}

@test "HERDR_AUTOSTART=0 skips straight to a shell" {
    stub_herdr
    HERDR_AUTOSTART=0 run "$GS"
    assert_success
    assert_herdr_not_launched
}

@test "HERDR_AUTOSTART unset or any other value still launches herdr" {
    # The guard tests for exactly "0"; an empty or leftover value must not
    # silently disable the feature.
    stub_herdr
    HERDR_AUTOSTART=1 run "$GS"
    assert_success
    assert_output_lacks "not found"
    assert_equal "$(stub_calls)" "$(printf 'herdr argc=0\nshell -l')"
}

# --------------------------------------------------------------- resolving herdr

@test "herdr is found off PATH when the environment is bare" {
    # The reason this script exists: Ghostty is launched by the GUI with roughly
    # /usr/bin:/bin, so `command -v herdr` fails on a machine where herdr is
    # installed and working. Falling back to the known prefixes is what keeps a
    # Homebrew install reachable.
    local prefix="$BATS_TEST_TMPDIR/prefix"
    mkdir -p "$prefix"
    printf '#!/usr/bin/env bash\nprintf "herdr argc=%%d\\n" "$#" >>"$STUB_LOG"\n' >"$prefix/herdr"
    chmod +x "$prefix/herdr"

    run env PATH="$(only_stubs)" bash -c '
        source "$1"
        FOUND="$2/herdr"
        herdr_candidates() { printf "%s\n" "$FOUND"; }
        main
    ' _ "$GS" "$prefix"
    assert_success
    assert_equal "$(stub_calls)" "$(printf 'herdr argc=0\nshell -l')"
}

@test "no herdr anywhere is reported by name and still gives a shell" {
    run env PATH="$(only_stubs)" bash -c '
        source "$1"
        MISSING="$2/no-such-herdr"
        herdr_candidates() { printf "%s\n" "$MISSING"; }
        main
    ' _ "$GS" "$BATS_TEST_TMPDIR"
    assert_success
    assert_output_contains "herdr not found"
    assert_equal "$(stub_calls)" "shell -l"
}

@test "a candidate that exists but is not executable is skipped" {
    # An interrupted install or a bad permission fix should fall through to the
    # message and the shell, not to "permission denied" and a closed window.
    printf '#!/bin/sh\n' >"$BATS_TEST_TMPDIR/unexec-herdr"
    chmod 644 "$BATS_TEST_TMPDIR/unexec-herdr"

    run env PATH="$(only_stubs)" bash -c '
        source "$1"
        CAND="$2/unexec-herdr"
        herdr_candidates() { printf "%s\n" "$CAND"; }
        main
    ' _ "$GS" "$BATS_TEST_TMPDIR"
    assert_success
    assert_output_contains "herdr not found"
    assert_equal "$(stub_calls)" "shell -l"
}

# ------------------------------------------------------------------ the shell

@test "the login shell is \$SHELL, run as a login shell" {
    # -l matters: Ghostty would have started a login shell, and dropping it here
    # would give a fallback prompt with none of ~/.zprofile's environment.
    stub_herdr
    run "$GS"
    assert_success
    assert_output_lacks "not found"
    case "$(stub_calls)" in
        *"shell -l"*) ;;
        *) echo "the fallback shell was not run with -l: $(stub_calls)" >&2; return 1 ;;
    esac
}

@test "an empty SHELL does not produce an empty command" {
    # With SHELL="" and no default, exec_login_shell would exec "" and the
    # window would close instantly. This one is asserted against the source
    # rather than run: the default is a real login shell, so exercising the
    # branch would hand the suite an interactive zsh.
    grep -qF '${SHELL:-/bin/zsh}' "$GS" \
        || { echo "ghostty-session no longer defaults SHELL" >&2; return 1; }
}

# --------------------------------------------------------------- sourced-guard

@test "sourcing the script launches nothing" {
    stub_herdr
    run bash -c 'source "$1"; declare -f main >/dev/null && echo SOURCED_CLEAN' _ "$GS"
    assert_success
    assert_output_contains "SOURCED_CLEAN"
    assert_equal "$(stub_calls)" ""
}
