#!/usr/bin/env bats
#
# bin/secret. Two layers:
#
#   1. shell_quote called directly, round-tripped through `eval` in bash AND zsh.
#      This is the highest-value test in the repo: its output is eval'd by every
#      interactive shell via `eval "$(secret env)"` in ~/.localrc.
#   2. the CLI end to end against a fake `security` (see helpers/keychain.bash).

load helpers/stub.bash
load helpers/keychain.bash
load helpers/values.bash

setup() {
    setup_sandbox
    # Throwaway names, so even a bypassed stub cannot reach a real Keychain item.
    export SECRET_ACCOUNT="bats-account"
    export SECRET_ENV_NAME="bats-shell-env"
    install_fake_security
    SECRET="$REPO_ROOT/bin/secret"
}

# --------------------------------------------------------------- layer 1

# Call shell_quote in a subprocess. bin/secret sets `set -euo pipefail` and
# IFS=$'\n\t' at top level, which would leak into the bats shell if sourced
# directly -- so source it inside `bash -c` instead.
#
# $0 is "_" there while BASH_SOURCE[0] is the script path, so the sourced-guard
# correctly declines to run main().
shell_quote_of() {
    bash -c 'source "$1"; shell_quote "$2"' _ "$REPO_ROOT/bin/secret" "$1"
}

# Quote a value, eval it in $1, and compare the result byte for byte.
# Compared via files rather than $(...) because command substitution strips
# trailing newlines and one of the values ends in one.
assert_roundtrip() {
    local shell="$1" value="$2" quoted
    quoted="$(shell_quote_of "$value")"
    printf '%s' "$value" >"$BATS_TEST_TMPDIR/want"
    "$shell" -c "printf '%s' $quoted" >"$BATS_TEST_TMPDIR/got" 2>"$BATS_TEST_TMPDIR/err"
    if ! cmp -s "$BATS_TEST_TMPDIR/want" "$BATS_TEST_TMPDIR/got"; then
        printf 'round-trip through %s failed\n  value:  %q\n  quoted: %s\n  got:    %q\n  stderr: %s\n' \
            "$shell" "$value" "$quoted" "$(cat "$BATS_TEST_TMPDIR/got")" \
            "$(cat "$BATS_TEST_TMPDIR/err")" >&2
        return 1
    fi
}

@test "shell_quote: every adversarial value round-trips through bash eval" {
    load_adversarial_values
    for v in "${ADVERSARIAL[@]}"; do
        assert_roundtrip bash "$v"
    done
}

@test "shell_quote: every adversarial value round-trips through zsh eval" {
    # zsh is the shell that actually eval's the bundle. bin/secret:77-78 rejects
    # printf %q precisely because its $'...' output is not portable, and only a
    # second-shell test can defend that reasoning.
    if ! command -v zsh >/dev/null 2>&1; then
        skip "zsh not installed"
    fi
    load_adversarial_values
    for v in "${ADVERSARIAL[@]}"; do
        assert_roundtrip zsh "$v"
    done
}

@test "shell_quote: output is always fully single-quoted" {
    # A structural check independent of eval: the result must start and end with a
    # single quote, so nothing can ever be interpreted before eval reaches it.
    load_adversarial_values
    for v in "${ADVERSARIAL[@]}"; do
        local q
        q="$(shell_quote_of "$v")"
        [[ "$q" == "'"* ]] || { echo "not left-quoted: $q" >&2; return 1; }
        [[ "$q" == *"'" ]] || { echo "not right-quoted: $q" >&2; return 1; }
    done
}

@test "shell_quote: an empty value still produces a valid empty literal" {
    run shell_quote_of ""
    assert_success
    assert_equal "$output" "''"
}

# --------------------------------------------------------------- layer 2: CRUD

@test "set then get round-trips a value" {
    run bash -c "printf 'sekrit-value' | '$SECRET' set my_token"
    assert_success
    assert_output_contains "Stored 'my_token'"

    run "$SECRET" get my_token
    assert_success
    assert_equal "$output" "sekrit-value"
}

@test "get on a missing name fails with a useful message" {
    run "$SECRET" get nope
    assert_failure
    assert_output_contains "no secret named 'nope'"
}

@test "set refuses an empty value and stores nothing" {
    run bash -c "printf '' | '$SECRET' set my_token"
    assert_failure
    assert_output_contains "empty value; nothing stored"
    assert_no_writes
}

@test "rm deletes, and a second rm fails" {
    printf 'v' | "$SECRET" set doomed
    run "$SECRET" rm doomed
    assert_success
    assert_output_contains "Deleted 'doomed'"

    run "$SECRET" rm doomed
    assert_failure
    assert_output_contains "no secret named 'doomed'"
}

@test "delete is accepted as an alias for rm" {
    printf 'v' | "$SECRET" set doomed
    run "$SECRET" delete doomed
    assert_success
    assert_output_contains "Deleted 'doomed'"
}

@test "rotate on a missing name refuses and points at 'secret set'" {
    run bash -c "printf 'new' | '$SECRET' rotate ghost"
    assert_failure
    assert_output_contains "no secret named 'ghost' to rotate"
    assert_output_contains "use 'secret set' to create it"
    assert_no_writes
}

@test "rotate replaces an existing value" {
    printf 'old' | "$SECRET" set pat
    run bash -c "printf 'new' | '$SECRET' rotate pat"
    assert_success
    assert_output_contains "Rotated 'pat'"
    run "$SECRET" get pat
    assert_equal "$output" "new"
}

@test "SECRET_ACCOUNT scopes items to an account" {
    printf 'a-value' | "$SECRET" set shared
    SECRET_ACCOUNT=other run "$SECRET" get shared
    assert_failure
    assert_output_contains "no secret named 'shared'"
}

# --------------------------------------------------------- layer 2: env bundle

@test "env on a missing bundle explains how to create one" {
    run "$SECRET" env
    assert_failure
    assert_output_contains "no env bundle 'bats-shell-env'"
    assert_output_contains "secret env-edit"
}

@test "env-import composes a bundle from existing secrets" {
    seed_secret snyk_api_key 'snyk-abc'
    seed_secret github_pat 'ghp-xyz'

    run bash -c "printf 'SNYK_TOKEN=snyk_api_key\nGITHUB_TOKEN=github_pat\n' | '$SECRET' env-import"
    assert_success
    assert_output_contains "Imported 2 secret(s)"
    assert_output_contains "+ SNYK_TOKEN <- snyk_api_key"
}

@test "env-import never prints the values it imports" {
    # The progress lines are the reason this matters: they name the variables, so
    # it would be easy to "helpfully" include the values and leak them into a
    # terminal scrollback or CI log.
    seed_secret snyk_api_key 'snyk-abc-do-not-print'
    run bash -c "printf 'SNYK_TOKEN=snyk_api_key\n' | '$SECRET' env-import"
    assert_success
    assert_output_lacks 'snyk-abc-do-not-print'
}

@test "env-import rejects a malformed mapping" {
    run bash -c "printf 'NOT_A_MAPPING\n' | '$SECRET' env-import"
    assert_failure
    assert_output_contains "malformed mapping (expected VAR=item)"
    assert_no_writes
}

@test "env-import aborts before storing when an item is missing" {
    seed_secret good_item 'fine'
    run bash -c "printf 'GOOD=good_item\nBAD=absent_item\n' | '$SECRET' env-import"
    assert_failure
    assert_output_contains "no secret named 'absent_item'"
    # The first mapping resolved, so a naive implementation could have written a
    # half-built bundle. It must not.
    assert_no_writes
}

@test "env-import with no mappings on stdin stores nothing" {
    run bash -c "printf '' | '$SECRET' env-import"
    assert_failure
    assert_output_contains "no mappings on stdin"
    assert_no_writes
}

@test "env-import skips blank and comment lines" {
    seed_secret item_a 'a'
    run bash -c "printf '\n# a comment\nA=item_a\n' | '$SECRET' env-import"
    assert_success
    assert_output_contains "Imported 1 secret(s)"
}

@test "env-edit with an unchanged file leaves the bundle untouched" {
    run env EDITOR=true "$SECRET" env-edit
    assert_success
    assert_output_contains "No changes"
    assert_no_writes
}

@test "env-edit refuses to store an emptied bundle" {
    make_stub fake-editor <<'STUB'
: >"$1"
STUB
    run env EDITOR=fake-editor "$SECRET" env-edit
    assert_failure
    assert_output_contains "bundle is empty; refusing to store it"
    assert_no_writes
}

@test "env-edit stores the bundle and counts the export lines" {
    make_stub fake-editor <<'STUB'
printf "export ONE='1'\nexport TWO='2'\n# not an export\n" >>"$1"
STUB
    run env EDITOR=fake-editor "$SECRET" env-edit
    assert_success
    assert_output_contains "Stored env bundle 'bats-shell-env' (2 export lines)"

    run "$SECRET" env
    assert_success
    assert_output_contains "export ONE='1'"
}

@test "env-edit leaves no temp file behind" {
    make_stub fake-editor <<'STUB'
printf "export ONE='1'\n" >>"$1"
# Record the temp file's path and mode while it is still alive.
printf '%s\n' "$1" >"$BATS_TEST_TMPDIR/tmppath"
ls -l "$1" | cut -c1-10 >"$BATS_TEST_TMPDIR/tmpmode"
STUB
    TMPDIR="$BATS_TEST_TMPDIR" run env EDITOR=fake-editor "$SECRET" env-edit
    assert_success

    local leaked
    leaked="$(cat "$BATS_TEST_TMPDIR/tmppath")"
    [ ! -e "$leaked" ] || { echo "temp file survived: $leaked" >&2; return 1; }

    # Values touch disk only as a mode-0600 file; anything wider would expose them
    # to every other user on the machine for the duration of the edit.
    assert_equal "$(cat "$BATS_TEST_TMPDIR/tmpmode")" "-rw-------"
}

@test "full circuit: adversarial values survive env-import -> env -> eval" {
    # The property that matters in production: whatever is in the Keychain comes
    # back out of `eval "$(secret env)"` byte-identical.
    load_adversarial_values

    local -a names=()
    local i=0 v
    for v in "${ADVERSARIAL[@]}"; do
        seed_secret "item_$i" "$v"
        names+=("VAL_$i")
        printf 'VAL_%s=item_%s\n' "$i" "$i" >>"$BATS_TEST_TMPDIR/mappings"
        i=$((i + 1))
    done

    run bash -c "'$SECRET' env-import < '$BATS_TEST_TMPDIR/mappings'"
    assert_success

    # Eval the bundle and dump each variable to its own file, NUL-free and
    # newline-free framing so an embedded newline cannot be mistaken for a
    # delimiter.
    for shell in bash zsh; do
        command -v "$shell" >/dev/null 2>&1 || continue
        i=0
        for v in "${ADVERSARIAL[@]}"; do
            "$shell" -c "eval \"\$('$SECRET' env)\"; printf '%s' \"\$VAL_$i\"" \
                >"$BATS_TEST_TMPDIR/got"
            printf '%s' "$v" >"$BATS_TEST_TMPDIR/want"
            if ! cmp -s "$BATS_TEST_TMPDIR/want" "$BATS_TEST_TMPDIR/got"; then
                printf '%s: VAL_%s did not survive\n  want: %q\n  got:  %q\n' \
                    "$shell" "$i" "$v" "$(cat "$BATS_TEST_TMPDIR/got")" >&2
                return 1
            fi
            i=$((i + 1))
        done
    done
}

@test "full circuit: eval of the bundle has no side effects beyond assignment" {
    # A value like ';rm -rf /' or '`id`' escaping its quotes would show up here as
    # an extra command running. Prove the eval produces no output of its own.
    seed_secret nasty ';echo PWNED; `echo ALSO_PWNED`'
    printf 'NASTY=nasty\n' | "$SECRET" env-import >/dev/null 2>&1

    run bash -c "eval \"\$('$SECRET' env)\" 2>&1"
    assert_success
    assert_output_lacks PWNED
    assert_equal "$output" ""
}

# --------------------------------------------------------------- layer 2: CLI

@test "no arguments prints usage and succeeds" {
    run "$SECRET"
    assert_success
    assert_output_contains "secret set <name>"
    assert_output_contains "THE ENV BUNDLE"
}

@test "an unknown subcommand prints usage and fails" {
    run "$SECRET" bogus
    assert_failure
    assert_output_contains "unknown subcommand: bogus"
    assert_output_contains "secret get <name>"
}

@test "get with no name fails with its usage line" {
    run "$SECRET" get
    assert_failure
    assert_output_contains "usage: secret get <name>"
}
