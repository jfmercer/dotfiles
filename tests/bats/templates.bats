#!/usr/bin/env bats
#
# The chezmoi templates. Every regression guarded here has already happened once
# or is one character away from happening:
#
#   - `.chezmoi.yaml.tmpl` uses `{{/* */}}` comments because a bare `#` is
#     emitted verbatim into the rendered YAML and the whitespace-stripping
#     delimiters swallow its newline -- which is how `verbose` spent years
#     sitting inside a comment, doing nothing.
#   - `dot_gitconfig.tmpl` must reach `work` with `get . "work"`, not `.work`:
#     chezmoi reads the *generated* ~/.config/chezmoi/chezmoi.yaml, which on a
#     machine that predates the key has no `work` entry at all, and `.work`
#     against a map with no such key is a hard template error.

load helpers/stub.bash

setup() {
    if ! command -v chezmoi >/dev/null 2>&1; then
        skip "chezmoi not installed"
    fi
    CM=(chezmoi --source "$REPO_ROOT")
}

# Render a template file with an explicit config, so the data map is exactly what
# the test says it is rather than whatever this machine happens to be configured
# with.
render_with() {
    local config="$1" tmpl="$2"
    "${CM[@]}" execute-template --config "$config" <"$tmpl"
}

write_config() {
    local dest="$1"
    shift
    {
        printf 'data:\n'
        printf '  %s\n' "$@"
    } >"$dest"
}

# ------------------------------------------------------- .chezmoi.yaml.tmpl

@test "the config template renders" {
    run "${CM[@]}" execute-template --init <"$REPO_ROOT/.chezmoi.yaml.tmpl"
    assert_success
}

@test "top-level config keys are live, not swallowed into a comment" {
    "${CM[@]}" execute-template --init <"$REPO_ROOT/.chezmoi.yaml.tmpl" \
        >"$BATS_TEST_TMPDIR/rendered.yaml"

    # Anchored so a key glued onto the end of a `#` comment line -- the exact
    # historical failure -- does not match. The value is deliberately not
    # asserted: `verbose` is intentionally false, and this test is about the key
    # being a real key.
    for key in verbose data diff; do
        if ! grep -qE "^${key}:" "$BATS_TEST_TMPDIR/rendered.yaml"; then
            printf 'key %s is not a top-level key in the rendered config:\n%s\n' \
                "$key" "$(cat "$BATS_TEST_TMPDIR/rendered.yaml")" >&2
            return 1
        fi
    done
}

@test "no rendered config line is a comment with a key glued onto it" {
    # The failure mode is a `#` comment whose trailing newline was stripped, so
    # the next directive ends up on the comment's line. Legitimate comments exist
    # in this file, so the assertion is specifically "no commented line also
    # carries something that looks like a top-level key".
    "${CM[@]}" execute-template --init <"$REPO_ROOT/.chezmoi.yaml.tmpl" \
        >"$BATS_TEST_TMPDIR/rendered.yaml"
    run grep -nE '^#.*[^ ][a-z_]+: ' "$BATS_TEST_TMPDIR/rendered.yaml"
    if [ "$status" -eq 0 ]; then
        printf 'a comment line appears to have swallowed a key:\n%s\n' "$output" >&2
        return 1
    fi
}

@test "every documented data key survives into chezmoi's template data" {
    # Feeding the rendered config back to chezmoi proves two things at once: the
    # YAML parses, and the `data:` block actually surfaces as template variables.
    # That is the file's entire job.
    "${CM[@]}" execute-template --init <"$REPO_ROOT/.chezmoi.yaml.tmpl" \
        >"$BATS_TEST_TMPDIR/generated.yaml"

    for key in email install_mac_apps install_linux_apps set_git_to_ssh work osid; do
        run "${CM[@]}" execute-template --config "$BATS_TEST_TMPDIR/generated.yaml" \
            "{{ get . \"$key\" }}"
        assert_success
        if [ -z "$output" ]; then
            echo "data key '$key' rendered empty" >&2
            return 1
        fi
    done
}

# ------------------------------------------------------- dot_gitconfig.tmpl

@test "gitconfig includes ~/.gitconfig.work on a work machine" {
    write_config "$BATS_TEST_TMPDIR/work.yaml" 'email: "a@b.c"' 'work: true'
    run render_with "$BATS_TEST_TMPDIR/work.yaml" "$REPO_ROOT/dot_gitconfig.tmpl"
    assert_success
    assert_output_contains "path = ~/.gitconfig.work"
}

@test "gitconfig omits the work include on a personal machine" {
    write_config "$BATS_TEST_TMPDIR/home.yaml" 'email: "a@b.c"' 'work: false'
    run render_with "$BATS_TEST_TMPDIR/home.yaml" "$REPO_ROOT/dot_gitconfig.tmpl"
    assert_success
    assert_output_lacks ".gitconfig.work"
}

@test "gitconfig renders when 'work' is absent from the data map entirely" {
    # THE regression this file's `get . "work"` exists for. chezmoi reads the
    # generated ~/.config/chezmoi/chezmoi.yaml, not the .tmpl, so a machine
    # initialized before `work` was added has no such key. A naive `.work` here
    # is not "falsy", it is a hard error -- and it would break git config on
    # every existing machine until someone re-ran `chezmoi init`.
    write_config "$BATS_TEST_TMPDIR/legacy.yaml" 'email: "a@b.c"'
    run render_with "$BATS_TEST_TMPDIR/legacy.yaml" "$REPO_ROOT/dot_gitconfig.tmpl"
    assert_success
    assert_output_lacks ".gitconfig.work"
    # Still a usable gitconfig, not a truncated one.
    assert_output_contains "email = a@b.c"
}

# ------------------------------------------------------- homebrew template

HOMEBREW_TMPL=".chezmoiscripts/darwin/run_onchange_before_10_homebrew.sh.tmpl"

# Extract the quoted entries of a `{{ $name := list ... }}` block from the
# template source. Parsed from source rather than from rendered output so this
# runs on the Linux half of the matrix too, where the template renders empty.
template_list() {
    local var="$1"
    awk -v var="$var" '
        index($0, "$" var " := list") { collecting = 1 }
        collecting {
            while (match($0, /"[^"]+"/)) {
                print substr($0, RSTART + 1, RLENGTH - 2)
                $0 = substr($0, RSTART + RLENGTH)
            }
            if (index($0, "}}")) { collecting = 0 }
        }
    ' "$REPO_ROOT/$HOMEBREW_TMPL"
}

@test "the template list parser actually finds entries" {
    # $casks is empty today, so the disjointness test below would pass even if
    # template_list silently returned nothing. Anchor it against $brews, which is
    # never empty.
    local n
    n="$(template_list brews | wc -l | tr -d ' ')"
    if [ "$n" -lt 10 ]; then
        echo "template_list brews found only $n entries; the parser is broken" >&2
        return 1
    fi
}

@test "casks_no_sha is disjoint from casks" {
    # Anything in both lists would be installed twice, the second time with
    # --require-sha dropped -- silently downgrading a cask that does have a
    # checksum. The no-sha list is meant to shrink over time, so this catches an
    # entry moved to \$casks but not deleted from \$casks_no_sha.
    local overlap
    overlap="$(comm -12 <(template_list casks | sort -u) <(template_list casks_no_sha | sort -u))"
    if [ -n "$overlap" ]; then
        printf 'these casks are in BOTH lists:\n%s\n' "$overlap" >&2
        return 1
    fi
}

@test "HOMEBREW_CASK_OPTS is identical in the apply script and the shell exports" {
    # Kept in sync by a comment only. If they drift, casks installed at apply time
    # land somewhere different from casks installed from an interactive shell, and
    # one of the two silently stops enforcing --require-sha.
    local from_tmpl from_zsh
    from_tmpl="$(grep -h 'HOMEBREW_CASK_OPTS=' "$REPO_ROOT/$HOMEBREW_TMPL" | grep '^export ' | head -1)"
    from_zsh="$(grep -h '^export HOMEBREW_CASK_OPTS=' "$REPO_ROOT/homebrew/exports.zsh" | head -1)"

    [ -n "$from_tmpl" ] || { echo "no exported HOMEBREW_CASK_OPTS in $HOMEBREW_TMPL" >&2; return 1; }
    [ -n "$from_zsh" ] || { echo "no HOMEBREW_CASK_OPTS in homebrew/exports.zsh" >&2; return 1; }
    assert_equal "$from_tmpl" "$from_zsh"
}

@test "the apply-time cask options still require a checksum" {
    run grep -q -- '--require-sha' "$REPO_ROOT/homebrew/exports.zsh"
    assert_success
}

# ------------------------------------------------------- all script templates

@test "every chezmoiscripts template renders without error" {
    local tmpl rc=0
    while read -r tmpl; do
        if ! "${CM[@]}" execute-template <"$tmpl" >/dev/null 2>"$BATS_TEST_TMPDIR/err"; then
            printf 'FAILED to render %s:\n%s\n' "$tmpl" "$(cat "$BATS_TEST_TMPDIR/err")" >&2
            rc=1
        fi
    done < <(find "$REPO_ROOT/.chezmoiscripts" -name '*.tmpl')
    return "$rc"
}
