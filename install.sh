#!/bin/sh

# -e: exit on error
# -u: exit on unset variables
set -eu

log_color() {
  color_code="$1"
  shift

  printf "\033[${color_code}m%s\033[0m\n" "$*" >&2
}

log_red() {
  log_color "0;31" "$@"
}

log_blue() {
  log_color "0;34" "$@"
}

log_task() {
  log_blue "🔃" "$@"
}

log_error() {
  log_red "❌" "$@"
}

error() {
  log_error "$@"
  exit 1
}

# Pin the chezmoi version we bootstrap with. get.chezmoi.io is still trusted to
# serve an honest installer -- that is unavoidable for a bootstrap -- but pinning
# means a compromised endpoint cannot silently hand us a different chezmoi than
# the one this repo was tested against. Bump with: chezmoi --version
CHEZMOI_VERSION="v2.72.2"

# POSIX way to get script's dir: https://stackoverflow.com/a/29834779/12156188
# shellcheck disable=SC2312
script_dir="$(cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P)"

# Every network fetch below is retried. This script is the bootstrap, so it runs
# where a transient failure is most expensive -- a fresh machine, or CI, where
# the alternative is re-running the whole job. No new coupling: this script
# already requires the full source tree, since it ends by pointing chezmoi at it.
retry="${script_dir}/scripts/retry.sh"

if ! chezmoi="$(command -v chezmoi)"; then
  bin_dir="${HOME}/.local/bin"
  chezmoi="${bin_dir}/chezmoi"
  log_task "Installing chezmoi ${CHEZMOI_VERSION} to '${chezmoi}'"
  if command -v curl >/dev/null; then
    chezmoi_install_script="$("${retry}" 5 curl -fsSL --retry 5 --retry-all-errors --connect-timeout 15 https://get.chezmoi.io)"
  elif command -v wget >/dev/null; then
    chezmoi_install_script="$("${retry}" 5 wget --tries=5 --waitretry=2 --timeout=15 -qO- https://get.chezmoi.io)"
  else
    error "To install chezmoi, you must have curl or wget."
  fi
  # Retried separately from the fetch above: this runs upstream's installer,
  # which downloads the chezmoi binary itself over a connection our flags cannot
  # reach. That inner download is what 504'd on 2026-09-07 and 2026-09-14.
  "${retry}" 5 sh -c "${chezmoi_install_script}" -- -b "${bin_dir}" -t "${CHEZMOI_VERSION}"
  unset chezmoi_install_script bin_dir
fi

set -- init --source="${script_dir}"

if [ -n "${DOTFILES_ONE_SHOT-}" ]; then
  set -- "$@" --one-shot
else
  set -- "$@" --apply
fi

if [ -n "${DOTFILES_DEBUG-}" ]; then
  set -- "$@" --debug --verbose
fi

log_task "Running 'chezmoi $*'"
# replace current process with the retry wrapper, which then runs chezmoi
#
# Retried because .chezmoiexternal.yaml's 14 entries are fetched by chezmoi's
# own HTTP client, which has no retry option of its own -- `--refresh-externals`
# is the only related flag. A single 504 on any one of them used to fail the
# entire bootstrap, which is how `apply (macos-latest)` broke on 2026-09-14.
#
# Safe to retry because apply is idempotent, and this repo asserts that rather
# than assuming it: CI applies a second time and fails on any drift. A re-run
# skips whatever already succeeded. Kept at 3 attempts, not 5, because a genuine
# failure here re-runs the install scripts each time.
exec "${retry}" 3 "${chezmoi}" "$@"
