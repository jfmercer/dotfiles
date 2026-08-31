"""Load bin/bump-deps as a module and build throwaway repos to point it at.

Two problems to solve.

`bin/bump-deps` is named with a hyphen and has no .py extension, so `import` will
not find it. It is loaded here by file path instead.

It also resolves everything relative to a module-level ``REPO`` constant computed
from ``__file__``, and its editing functions write in place. Tests therefore build
a miniature repo in a temp directory -- containing only the five files that hold
pins -- and repoint ``REPO`` at it. Nothing in the real tree is touched, and the
fixtures can be corrupted freely to reach the invariant-violation branches, which
are otherwise unreachable without breaking the actual repo.
"""

from __future__ import annotations

import contextlib
import importlib.machinery
import importlib.util
import os
import re
import sys
import tempfile

TESTS_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(os.path.dirname(TESTS_DIR))
BUMP_DEPS = os.path.join(REPO_ROOT, "bin", "bump-deps")


def load_bump_deps():
    """Import bin/bump-deps under the name 'bump_deps'."""
    if "bump_deps" in sys.modules:
        return sys.modules["bump_deps"]
    spec = importlib.util.spec_from_loader(
        "bump_deps",
        importlib.machinery.SourceFileLoader("bump_deps", BUMP_DEPS),
    )
    module = importlib.util.module_from_spec(spec)
    sys.modules["bump_deps"] = module
    spec.loader.exec_module(module)
    return module


bump_deps = load_bump_deps()


# --------------------------------------------------------------- fixture text
#
# Deliberately miniature rather than copies of the real files: a fixture that
# tracks the real content would have to be updated every time a pin moves, and
# would stop being a fixed, known-good baseline.

INSTALL_SH = """\
#!/bin/sh
set -eu
CHEZMOI_VERSION="v2.71.1"
echo "installing ${CHEZMOI_VERSION}"
"""

# Every VERSION and ACTION pin whose file is CI must appear here, or gather()
# raises "pattern not found" -- which is the intended coupling: registering a new
# pin in bump-deps should require saying what a correct file looks like.
#
# The action pins are commit SHAs with a `# vX.Y.Z` comment, matching the real
# tree. Made-up but well-formed 40-hex values: the ACTION tests never hit the
# network, and a fixture carrying the real SHAs would need editing every time
# upstream cuts a release.
CHECKOUT_SHA = "a" * 40
GITLEAKS_SHA = "b" * 40

CI_YAML = f"""\
name: 'CI'
jobs:
  lint:
    steps:
      - uses: actions/checkout@{CHECKOUT_SHA} # v7.0.1
      - name: Install shellcheck
        env:
          SHELLCHECK_VERSION: v0.11.0
        run: shellcheck --version
  workflows:
    steps:
      - name: Install shellcheck
        env:
          SHELLCHECK_VERSION: v0.11.0
        run: shellcheck --version
      - name: Install actionlint
        env:
          ACTIONLINT_VERSION: v1.7.12
        run: actionlint --version
      - name: Install zizmor
        env:
          ZIZMOR_VERSION: v1.28.0
        run: zizmor --version
  test:
    steps:
      - name: Install bats-core
        env:
          BATS_VERSION: v1.14.0
        run: bats --version
      - name: Install ruff
        env:
          RUFF_VERSION: 0.16.0
        run: ruff --version
  secrets:
    steps:
      - uses: actions/checkout@{CHECKOUT_SHA} # v7.0.1
      - uses: gitleaks/gitleaks-action@{GITLEAKS_SHA} # v3.0.0
"""

# actions/checkout is pinned in both workflows, which is the whole reason ACTION
# pins carry a list of files. A fixture with only ci.yaml would let a regression
# that silently ignores the second file pass.
DEPS_YAML = f"""\
name: 'Dependency staleness'
jobs:
  check:
    steps:
      - uses: actions/checkout@{CHECKOUT_SHA} # v7.0.1
"""

# rustup is a VERSION pin carrying two derived checksums, so the fixture has to
# show all three: check_invariants() compares the set of *_SHA256* assignments
# here against the `hashes` entries registered for the pin, in both directions,
# and apply_versions() rewrites them together. A fixture with only the version
# would make both halves of that unreachable.
LINUX_TMPL = """\
{{- if (eq .chezmoi.os "linux") -}}
#!/usr/bin/env bash
LAZYGIT_VERSION="0.58.0"
HUNK_VERSION="0.1.0"
RUSTUP_VERSION="1.28.0"
RUSTUP_INIT_SHA256_X86_64="0000000000000000000000000000000000000000000000000000000000000000"
RUSTUP_INIT_SHA256_AARCH64="1111111111111111111111111111111111111111111111111111111111111111"
EZA_KEY_FPR="AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
CHARM_KEY_FPR="AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
{{- end -}}
"""

# Read back out of the fixture rather than restated beside it: a test that wants
# to say "the version the fixture pins" should not be able to disagree with the
# fixture, and 64-character literals repeated in two files drift silently.
RUSTUP_VERSION_PIN = re.search(r'RUSTUP_VERSION="([^"]+)"', LINUX_TMPL).group(1)
RUSTUP_X86_SHA = re.search(r'RUSTUP_INIT_SHA256_X86_64="([0-9a-f]+)"', LINUX_TMPL).group(1)
RUSTUP_ARM_SHA = re.search(r'RUSTUP_INIT_SHA256_AARCH64="([0-9a-f]+)"', LINUX_TMPL).group(1)

EXTERNALS_YAML = """\
# Upstream code fetched by chezmoi. Every entry is pinned and checksummed.
#
# WHY: these files are sourced into every interactive shell.

# vim plugin manager
".vim/autoload/plug.vim":
    type: "file"
    url: "https://raw.githubusercontent.com/junegunn/vim-plug/0.14.0/plug.vim"
    refreshPeriod: "168h"
    checksum:
        sha256: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

# zsh plugins
# sindresorhus/pure @ 2026-07-16 (nearest tag: v1.28.3)
".local/zsh-plugins/pure":
    type: "archive"
    url: "https://github.com/sindresorhus/pure/archive/1111111111111111111111111111111111111111.tar.gz"
    exact: true
    stripComponents: 1
    checksum:
        sha256: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
# zsh-users/zsh-z @ 2024-01-01 (nearest tag: v1.9.0)
".local/zsh-plugins/zsh-z":
    type: "archive"
    url: "https://github.com/agkozak/zsh-z/archive/2222222222222222222222222222222222222222.tar.gz"
    exact: true
    stripComponents: 1
    checksum:
        sha256: "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
"""

VERSION_FLOOR = "v2.71.1\n"

FIXTURES = {
    "install.sh": INSTALL_SH,
    ".github/workflows/ci.yaml": CI_YAML,
    ".github/workflows/deps.yaml": DEPS_YAML,
    ".chezmoiscripts/linux/run_onchange_before_10_installs.sh.tmpl": LINUX_TMPL,
    ".chezmoiexternal.yaml": EXTERNALS_YAML,
    ".chezmoiversion": VERSION_FLOOR,
}


@contextlib.contextmanager
def fixture_repo(**overrides):
    """Build a temp repo of pinned files and point bump_deps.REPO at it.

    Keyword arguments override a fixture's whole content, which is how the
    invariant tests produce a deliberately broken tree:

        with fixture_repo(**{".chezmoiversion": "v9.9.9\\n"}) as repo:
            ...
    """
    contents = dict(FIXTURES)
    contents.update(overrides)
    original = bump_deps.REPO
    with tempfile.TemporaryDirectory() as tmp:
        for rel, text in contents.items():
            dest = os.path.join(tmp, rel)
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            with open(dest, "w", encoding="utf-8") as fh:
                fh.write(text)
        bump_deps.REPO = tmp
        try:
            yield tmp
        finally:
            bump_deps.REPO = original


def read(repo: str, rel: str) -> str:
    with open(os.path.join(repo, rel), encoding="utf-8") as fh:
        return fh.read()


def pin(name: str) -> dict:
    """Look a pin up by name across all four registries."""
    for group in ALL_REGISTRIES:
        for entry in group:
            if entry["name"] == name:
                return entry
    raise KeyError(name)


# Every registry, in one place, so a test that sweeps "all pins" picks up a newly
# added class automatically instead of silently continuing to check three of four.
ALL_REGISTRIES = (
    bump_deps.VERSION_PINS,
    bump_deps.ACTION_PINS,
    bump_deps.CONTENT_PINS,
    bump_deps.ANCHOR_PINS,
)

# The registries whose pins replace_value() edits -- i.e. everything except
# ACTION, which has two capture groups and its own rewriter.
SINGLE_GROUP_REGISTRIES = (
    bump_deps.VERSION_PINS,
    bump_deps.CONTENT_PINS,
    bump_deps.ANCHOR_PINS,
)
