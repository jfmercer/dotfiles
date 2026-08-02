#!/usr/bin/env bats
#
# Cross-file invariants. Nothing here tests a single file's behavior; each
# assertion is a contract between two files that no linter can see and that is
# currently held together by a comment.
#
# The repo's layout makes these unusually easy to break: the topic directories
# and bin/ are sourced and executed IN PLACE out of the source directory and are
# listed in .chezmoiignore, so they are invisible to `chezmoi diff` and
# `chezmoi status`. A mistake in that half of the tree surfaces at shell startup,
# not at apply time.

load helpers/stub.bash

# ------------------------------------------------- .chezmoiignore completeness

@test "every topic directory is listed in .chezmoiignore" {
    # A new topic dir that nobody adds here gets copied into $HOME on the next
    # apply -- silently, since it also still works in place. Derived from a glob
    # rather than hardcoded so this covers directories that do not exist yet.
    local dir missing=""
    for dir in "$REPO_ROOT"/*/; do
        # A topic directory is one holding *.zsh files sourced by dot_zshrc.
        compgen -G "${dir}*.zsh" >/dev/null || continue
        local name
        name="$(basename "$dir")"
        grep -qx "${name}/" "$REPO_ROOT/.chezmoiignore" || missing="$missing $name"
    done
    if [ -n "$missing" ]; then
        echo "topic directories missing from .chezmoiignore:$missing" >&2
        return 1
    fi
}

@test "bin, tests, scripts and the docs are in .chezmoiignore" {
    local entry
    for entry in "bin/" "tests/" "scripts/" "install.sh" "CLAUDE.md" "terminal/"; do
        if ! grep -qx -- "$entry" "$REPO_ROOT/.chezmoiignore"; then
            echo "'$entry' is not ignored; chezmoi apply would copy it into \$HOME" >&2
            return 1
        fi
    done
}

@test "the topic glob in dot_zshrc still matches the topic directories" {
    # dot_zshrc collects $DOTFILES/*/*.zsh. If that pattern is ever narrowed, the
    # .chezmoiignore test above keeps passing while nothing gets sourced.
    run grep -q 'config_files=(\$DOTFILES/\*/\*\.zsh)' "$REPO_ROOT/dot_zshrc"
    assert_success
}

# ------------------------------------------------------------------ bin/

@test "every bin script is executable and has a shebang" {
    local f bad=""
    for f in "$REPO_ROOT"/bin/*; do
        [ -f "$f" ] || continue
        [ -x "$f" ] || bad="$bad $(basename "$f"):not-executable"
        head -c 2 "$f" | grep -q '#!' || bad="$bad $(basename "$f"):no-shebang"
    done
    if [ -n "$bad" ]; then
        echo "problems in bin/:$bad" >&2
        return 1
    fi
}

@test "system/path.zsh puts the repo's bin directory on PATH" {
    # This is the only mechanism that makes anything in bin/ reachable. Without
    # it every git-* subcommand and `secret` itself silently vanish.
    run grep -q '\$DOTFILES/bin' "$REPO_ROOT/system/path.zsh"
    assert_success
}

# --------------------------------------------------------- zsh cache location

@test "the zsh cache directory matches in dot_zshrc and zsh/completion.zsh" {
    # CLAUDE.md: "compinit is invoked with an explicit -d for that reason; if you
    # change the path, change it in both". A mismatch splits the completion cache
    # across two directories and quietly slows every shell start.
    local expected='${XDG_CACHE_HOME:-$HOME/.cache}/zsh'
    for f in dot_zshrc zsh/completion.zsh; do
        if ! grep -qF -- "$expected" "$REPO_ROOT/$f"; then
            echo "$f does not use the shared cache path '$expected'" >&2
            return 1
        fi
    done
}

@test "the apply-time completions directory is on fpath before compinit" {
    # run_after_40_op_completions.sh writes into this directory; dot_zshrc must add
    # it to fpath, and must do so BEFORE compinit or the completions never load.
    local fpath_line compinit_line
    fpath_line="$(grep -n 'fpath=(\$_zsh_cache/completions' "$REPO_ROOT/dot_zshrc" | cut -d: -f1)"
    compinit_line="$(grep -n '^ *compinit ' "$REPO_ROOT/dot_zshrc" | head -1 | cut -d: -f1)"
    [ -n "$fpath_line" ] || { echo "dot_zshrc does not add \$_zsh_cache/completions to fpath" >&2; return 1; }
    [ -n "$compinit_line" ] || { echo "no compinit call found in dot_zshrc" >&2; return 1; }
    if [ "$fpath_line" -ge "$compinit_line" ]; then
        echo "fpath is extended at line $fpath_line, after compinit at $compinit_line" >&2
        return 1
    fi
}

@test "syntax-highlighting is sourced before history-substring-search" {
    # Required by zsh-history-substring-search's own README. Getting this backward
    # breaks the highlighting of matched history, subtly and without any error.
    local hl hs
    hl="$(grep -n 'zsh-syntax-highlighting.plugin.zsh' "$REPO_ROOT/dot_zshrc" | cut -d: -f1)"
    hs="$(grep -n 'zsh-history-substring-search.plugin.zsh' "$REPO_ROOT/dot_zshrc" | cut -d: -f1)"
    [ -n "$hl" ] && [ -n "$hs" ] || { echo "one of the two plugins is no longer sourced" >&2; return 1; }
    if [ "$hl" -ge "$hs" ]; then
        echo "syntax-highlighting (line $hl) must come before history-substring-search (line $hs)" >&2
        return 1
    fi
}

# ----------------------------------------------------------- externals pinning

@test "every external is pinned and checksummed" {
    # Duplicates one of bump-deps' invariants deliberately: bump-deps needs `gh`
    # and network access, so it is not run on the plain test path. These files are
    # sourced into every interactive shell; an unpinned entry is remote code
    # execution on a refresh timer.
    local ext="$REPO_ROOT/.chezmoiexternal.yaml"
    local urls shas
    urls="$(grep -c 'url:' "$ext")"
    shas="$(grep -c 'sha256:' "$ext")"
    assert_equal "$urls" "$shas"

    if grep -qE 'master\.tar\.gz|/HEAD/' "$ext"; then
        echo "an external is tracking a moving ref instead of a pinned commit" >&2
        return 1
    fi
}

@test "the chezmoi version floor does not exceed the version install.sh bootstraps" {
    # If the floor outruns the bootstrap, a fresh machine installs chezmoi and is
    # then refused by it. Same check bump-deps makes, without needing the network.
    local floor pinned
    floor="$(tr -d 'v \n' <"$REPO_ROOT/.chezmoiversion")"
    pinned="$(sed -n 's/^CHEZMOI_VERSION="v\{0,1\}\([^"]*\)"/\1/p' "$REPO_ROOT/install.sh")"
    [ -n "$pinned" ] || { echo "could not read CHEZMOI_VERSION from install.sh" >&2; return 1; }

    # Sort -V puts the lower version first; the floor must not be the higher one.
    local highest
    highest="$(printf '%s\n%s\n' "$floor" "$pinned" | sort -V | tail -1)"
    if [ "$highest" = "$floor" ] && [ "$floor" != "$pinned" ]; then
        echo ".chezmoiversion ($floor) exceeds install.sh CHEZMOI_VERSION ($pinned)" >&2
        return 1
    fi
}

# --------------------------------------------------------- tmux / herdr parity

@test "herdr's keybindings still mirror tmux's" {
    # dot_tmux.conf and dot_config/herdr/config.toml are deliberately kept aligned;
    # the mapping lives as comments in the herdr config. This is a curated table
    # rather than a parse of those comments, because several of them are prose
    # ("resurrect/continuum also saved pane contents ...") and not directives.
    local -a pairs=(
        'set -g prefix C-a|prefix = "ctrl+a"'
        'bind | split-window -h|split_vertical = "prefix+|"'
        'bind - split-window -v|split_horizontal = "prefix+minus"'
    )
    local pair tmux_side herdr_side
    for pair in "${pairs[@]}"; do
        tmux_side="${pair%%|*}"
        herdr_side="${pair#*|}"
        # The vertical-split pair contains a literal '|', so recover it explicitly.
        case "$pair" in
            'bind | split-window -h|'*)
                tmux_side='bind | split-window -h'
                herdr_side='split_vertical = "prefix+|"'
                ;;
        esac

        grep -qF -- "$tmux_side" "$REPO_ROOT/dot_tmux.conf" \
            || { echo "dot_tmux.conf no longer has: $tmux_side" >&2; return 1; }
        grep -qF -- "$herdr_side" "$REPO_ROOT/dot_config/herdr/config.toml" \
            || { echo "herdr config.toml no longer has: $herdr_side (tmux has: $tmux_side)" >&2; return 1; }
    done
}

@test "both tmux and herdr use vi keys in copy mode" {
    grep -qF 'mode-keys vi' "$REPO_ROOT/dot_tmux.conf" \
        || { echo "dot_tmux.conf no longer sets mode-keys vi" >&2; return 1; }
    grep -qiE 'vi' "$REPO_ROOT/dot_config/herdr/config.toml" \
        || { echo "herdr config.toml no longer mentions vi copy mode" >&2; return 1; }
}

# ------------------------------------------------------- ghostty / herdr launch

@test "Ghostty's initial-command points at a bin script that exists" {
    # Ghostty does not validate this path. If bin/ghostty-session is renamed or
    # removed, Ghostty silently falls back to a plain shell and never says why --
    # the feature just stops working and looks like herdr's fault.
    local cfg="$REPO_ROOT/dot_config/ghostty/config.tmpl"
    local line
    line="$(grep '^initial-command *=' "$cfg" || true)"
    [ -n "$line" ] || { echo "no initial-command in $cfg" >&2; return 1; }

    case "$line" in
        *bin/ghostty-session) ;;
        *) echo "initial-command no longer runs bin/ghostty-session: $line" >&2; return 1 ;;
    esac
    [ -x "$REPO_ROOT/bin/ghostty-session" ] \
        || { echo "bin/ghostty-session is missing or not executable" >&2; return 1; }
}

@test "Ghostty's initial-command resolves through the chezmoi source directory" {
    # It must be .chezmoi.sourceDir, not .chezmoi.homeDir: bin/ is in
    # .chezmoiignore and runs in place, so no copy of the script ever exists
    # under $HOME. A homeDir path renders fine and then never resolves.
    run grep -qF '{{ .chezmoi.sourceDir }}/bin/ghostty-session' \
        "$REPO_ROOT/dot_config/ghostty/config.tmpl"
    assert_success
}

# ------------------------------------------------------------- shell hygiene

@test "no topic file sets TERM unconditionally" {
    # CLAUDE.md: Ghostty, tmux and herdr each set TERM correctly, and a blanket
    # `export TERM=xterm-256color` used to overwrite all three.
    #
    # Anchored at column zero on purpose. zsh/exports.zsh does export TERM, but
    # only inside a guard that fires when zsh/terminfo loads and reports zero
    # capabilities -- i.e. when the entry is genuinely missing and there is
    # nothing to clobber. That is the sanctioned exception; an unindented,
    # unguarded export is the regression.
    local hits
    hits="$(grep -rn '^export TERM=' "$REPO_ROOT"/*/*.zsh "$REPO_ROOT/dot_zshrc" "$REPO_ROOT/dot_zshenv" 2>/dev/null || true)"
    if [ -n "$hits" ]; then
        echo "TERM is set unconditionally, overriding the terminal's own value:" >&2
        echo "$hits" >&2
        return 1
    fi
}

@test "no tracked file contains a literal export of a known secret variable" {
    # ~/.localrc is untracked and secrets come from the Keychain bundle. gitleaks
    # covers history; this is the cheap, fast guard against the specific mistake
    # of pasting a token into a topic file.
    local hits
    hits="$(grep -rnE '^[[:space:]]*export [A-Z_]*(TOKEN|SECRET|API_KEY|PASSWORD)=["'"'"']?[A-Za-z0-9_/+-]{16,}' \
        "$REPO_ROOT"/*/*.zsh "$REPO_ROOT/dot_zshrc" "$REPO_ROOT/dot_zshenv" 2>/dev/null || true)"
    if [ -n "$hits" ]; then
        echo "a literal secret appears to be committed:" >&2
        echo "$hits" >&2
        return 1
    fi
}
