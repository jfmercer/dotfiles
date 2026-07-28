"""Load bin/bump-deps as a module and build throwaway repos to point it at.

Two problems to solve.

`bin/bump-deps` is named with a hyphen and has no .py extension, so `import` will
not find it. It is loaded here by file path instead.

It also resolves everything relative to a module-level ``REPO`` constant computed
from ``__file__``, and its editing functions write in place. Tests therefore build
a miniature repo in a temp directory -- containing only the four files that hold
pins -- and repoint ``REPO`` at it. Nothing in the real tree is touched, and the
fixtures can be corrupted freely to reach the invariant-violation branches, which
are otherwise unreachable without breaking the actual repo.
"""

from __future__ import annotations

import contextlib
import importlib.machinery
import importlib.util
import os
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

# Every VERSION pin whose file is CI must appear here, or gather() raises
# "pattern not found" -- which is the intended coupling: registering a new pin in
# bump-deps should require saying what a correct file looks like.
CI_YAML = """\
name: 'CI'
jobs:
  lint:
    steps:
      - uses: actions/checkout@v7.0.1
      - name: Install shellcheck
        env:
          SHELLCHECK_VERSION: v0.11.0
        run: shellcheck --version
  test:
    steps:
      - name: Install bats-core
        env:
          BATS_VERSION: v1.14.0
        run: bats --version
  secrets:
    steps:
      - uses: actions/checkout@v7.0.1
      - uses: gitleaks/gitleaks-action@v3.0.0
"""

LINUX_TMPL = """\
{{- if (eq .chezmoi.os "linux") -}}
#!/usr/bin/env bash
LAZYGIT_VERSION="0.58.0"
RUSTUP_INIT_SHA256="0000000000000000000000000000000000000000000000000000000000000000"
EZA_KEY_FPR="AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
{{- end -}}
"""

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
    """Look a pin up by name across all three registries."""
    for group in (bump_deps.VERSION_PINS, bump_deps.CONTENT_PINS, bump_deps.ANCHOR_PINS):
        for entry in group:
            if entry["name"] == name:
                return entry
    raise KeyError(name)
