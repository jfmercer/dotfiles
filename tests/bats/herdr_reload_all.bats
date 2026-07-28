#!/usr/bin/env bats
#
# bin/herdr-reload-all. Two things are worth defending here.
#
# 1. The JSON-envelope branching exists only to turn one confusing failure
#    ("protocol_mismatch" after `brew upgrade herdr`) into an actionable message.
#    That branch has never been exercised by anything but the real failure.
# 2. Agent panes must never be reloaded -- typing `reload` into a running agent's
#    prompt is the bug the `select(.agent == null)` filter prevents. That is a
#    safety property, and it is asserted below by pane id.
#
# `herdr` is stubbed because the real one drives live panes. `jq` is NOT stubbed:
# the script's behavior is largely its jq filters, so stubbing jq would test
# nothing. jq is a Homebrew brew here and present on both CI runners.

load helpers/stub.bash

setup() {
    setup_sandbox
    HRA="$REPO_ROOT/bin/herdr-reload-all"
    if ! command -v jq >/dev/null 2>&1; then
        skip "jq not installed"
    fi
}

# Stub herdr so `pane list` echoes a canned envelope and `pane run` records the
# pane id it was asked to reload. $FAIL_PANE makes one reload fail.
stub_herdr() {
    local envelope="$1"
    printf '%s' "$envelope" >"$BATS_TEST_TMPDIR/envelope.json"
    make_stub herdr <<'STUB'
set -u
case "${1:-} ${2:-}" in
    "pane list")
        cat "$BATS_TEST_TMPDIR/envelope.json"
        ;;
    "pane run")
        printf 'run %s\n' "$3" >>"$STUB_LOG"
        if [ "${FAIL_PANE-}" = "$3" ]; then
            echo "herdr: pane $3 is gone" >&2
            exit 1
        fi
        ;;
    *)
        echo "fake herdr: unhandled '$*'" >&2
        exit 2
        ;;
esac
STUB
    export BATS_TEST_TMPDIR
}

# The pane ids that were actually reloaded, in order.
reloaded_panes() {
    sed -n 's/^run //p' "$STUB_LOG"
}

assert_nothing_reloaded() {
    if [ -n "$(reloaded_panes)" ]; then
        printf 'expected no reloads, but got:\n%s\n' "$(reloaded_panes)" >&2
        return 1
    fi
}

# ------------------------------------------------------------ error envelopes

@test "protocol_mismatch explains the fix instead of leaking JSON" {
    stub_herdr '{"error":{"code":"protocol_mismatch","message":"version 7 != 6"}}'
    run "$HRA"
    assert_failure
    assert_output_contains "herdr CLI is newer than the running server"
    # The actionable part: the exact commands to run.
    assert_output_contains "herdr server stop && herdr"
    # And the reason this script does not run them itself.
    assert_output_contains "exits every pane process (shells AND agents)"
    # Raw JSON must not reach the user; that was the whole point of the branch.
    assert_output_lacks '{"error"'
}

@test "protocol_mismatch reloads nothing" {
    stub_herdr '{"error":{"code":"protocol_mismatch","message":"x"}}'
    run "$HRA"
    assert_failure
    assert_nothing_reloaded
}

@test "an unrecognized error code reports both code and message" {
    stub_herdr '{"error":{"code":"server_unreachable","message":"connection refused"}}'
    run "$HRA"
    assert_failure
    assert_output_contains "herdr pane list failed (server_unreachable)"
    assert_output_contains "connection refused"
    assert_nothing_reloaded
}

@test "an error code with no message still fails cleanly" {
    stub_herdr '{"error":{"code":"weird"}}'
    run "$HRA"
    assert_failure
    assert_output_contains "herdr pane list failed (weird)"
}

@test "non-JSON output is reported, not leaked as a jq parse error" {
    # Regression test for a real defect this suite found: the `|| true` on the
    # err_code line guards only that one jq call. Plain-text output from
    # `herdr pane list` used to pass it as an empty code, then die in the reload
    # pipeline with a raw "jq: parse error" and exit 5 via pipefail.
    stub_herdr 'herdr: something went wrong'
    run "$HRA"
    assert_failure
    assert_output_contains "not a JSON envelope"
    assert_output_contains "herdr: something went wrong"
    assert_output_lacks "jq: parse error"
    assert_nothing_reloaded
}

@test "a JSON body that is not an envelope is reported" {
    # Valid JSON, but neither .result nor .error -- e.g. a protocol change.
    stub_herdr '{"panes":[]}'
    run "$HRA"
    assert_failure
    assert_output_contains "not a JSON envelope"
}

@test "bare JSON null is reported rather than iterated" {
    stub_herdr 'null'
    run "$HRA"
    assert_failure
    assert_output_contains "not a JSON envelope"
}

@test "a result envelope with no panes key succeeds without reloading" {
    # `.result.panes[]` on a missing key is a jq error, which pipefail would turn
    # into a nonzero exit. The `// []` guard makes this a quiet no-op instead.
    stub_herdr '{"result":{}}'
    run "$HRA"
    assert_success
    assert_nothing_reloaded
}

# -------------------------------------------------------------- the happy path

@test "only non-agent panes are reloaded" {
    stub_herdr '{"result":{"panes":[
        {"pane_id":"p1","agent":null},
        {"pane_id":"p2","agent":"claude"},
        {"pane_id":"p3","agent":null},
        {"pane_id":"p4","agent":"codex"}
    ]}}'
    run "$HRA"
    assert_success

    # Exactly the shell panes, in order. If this ever includes p2 or p4, the
    # script has typed "reload" into a live agent's prompt.
    assert_equal "$(reloaded_panes)" "$(printf 'p1\np3')"
}

@test "a pane list containing only agents reloads nothing and succeeds" {
    stub_herdr '{"result":{"panes":[{"pane_id":"a1","agent":"claude"}]}}'
    run "$HRA"
    assert_success
    assert_nothing_reloaded
}

@test "an empty pane list succeeds" {
    stub_herdr '{"result":{"panes":[]}}'
    run "$HRA"
    assert_success
    assert_nothing_reloaded
}

@test "one failing reload warns but does not stop the others" {
    stub_herdr '{"result":{"panes":[
        {"pane_id":"p1","agent":null},
        {"pane_id":"p2","agent":null},
        {"pane_id":"p3","agent":null}
    ]}}'
    FAIL_PANE=p2 run "$HRA"
    assert_success
    assert_output_contains "WARN: could not reload p2"
    # p3 must still have been attempted -- a bare `set -e` would have stopped at p2.
    assert_equal "$(reloaded_panes)" "$(printf 'p1\np2\np3')"
}

# ------------------------------------------------------------ missing deps

@test "a missing herdr is reported by name" {
    run env PATH="$(only_stubs)" "$HRA"
    assert_failure
    assert_output_contains "herdr not found on PATH"
}

@test "a missing jq is reported by name" {
    # The stub dir now holds herdr but no jq, so this reaches the second check.
    stub_herdr '{"result":{"panes":[]}}'
    run env PATH="$(only_stubs)" "$HRA"
    assert_failure
    assert_output_contains "jq not found on PATH"
}

# ------------------------------------------------------------ sourced-guard

@test "sourcing the script does not reload anything" {
    # The dependency checks and the reload live inside main() so that tests can
    # source this file with neither herdr nor jq present. If they crept back to
    # the top level, this would fail.
    stub_herdr '{"result":{"panes":[{"pane_id":"p1","agent":null}]}}'
    run bash -c 'source "$1"; declare -f main >/dev/null && echo SOURCED_CLEAN' _ "$HRA"
    assert_success
    assert_output_contains "SOURCED_CLEAN"
    assert_nothing_reloaded
}
