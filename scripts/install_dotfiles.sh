#!/usr/bin/env bash

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

log_manual_action() {
  log_red "⚠️" "$@"
}

log_error() {
  log_red "❌" "$@"
}

error() {
  log_error "$@"
  exit 1
}

fancy_echo() {
  local fmt="$1"; shift

  # shellcheck disable=SC2059
  printf "\n$fmt\n" "$@"
}

# OS detection
function is_macos() {
  [[ "$OSTYPE" =~ ^darwin ]] || return 1
}

# TODO: Use for Debian package installs
# sudo() {
#   # shellcheck disable=SC2312
#   if [ "$(id -u)" -eq 0 ]; then
#     "$@"
#   else
#     if ! command sudo --non-interactive true 2>/dev/null; then
#       log_manual_action "Root privileges are required, please enter your password below"
#       command sudo --validate
#     fi
#     command sudo "$@"
#   fi
# }

# DESTRUCTIVE: discards local commits and untracked files. Only reached when
# DOTFILES_FORCE_RESET is set -- see git_update below.
git_clean() {
  # path=$(readlink -f "$1")
  path="$1"
  remote="$2"
  branch="$3"

  log_task "Cleaning '${path}' with '${remote}' at branch '${branch}'"
  git="git -C ${path}"
  ${git} checkout -B "${branch}"
  ${git} fetch "${remote}" "${branch}"
  ${git} reset --hard FETCH_HEAD
  ${git} clean -fdx
  unset path remote branch git
}

# Bring an existing source directory up to date without destroying work.
# Refuses to touch a dirty tree unless DOTFILES_FORCE_RESET is set.
git_update() {
  path="$1"
  remote="$2"
  branch="$3"
  git="git -C ${path}"

  if [ -n "${DOTFILES_FORCE_RESET-}" ]; then
    git_clean "${path}" "${remote}" "${branch}"
    unset path remote branch git
    return
  fi

  # shellcheck disable=SC2312
  if [ -n "$(${git} status --porcelain)" ]; then
    log_error "'${path}' has local changes:"
    ${git} status --short >&2
    error "Refusing to overwrite them. Commit or stash first, or re-run with DOTFILES_FORCE_RESET=1 to discard."
  fi

  log_task "Updating '${path}' from '${remote}' at branch '${branch}'"
  ${git} fetch "${remote}" "${branch}"
  if ! ${git} merge --ff-only FETCH_HEAD; then
    error "'${path}' has diverged from ${remote}/${branch}. Reconcile it, or re-run with DOTFILES_FORCE_RESET=1 to discard local commits."
  fi
  unset path remote branch git
}

DOTFILES_REPO_HOST=${DOTFILES_REPO_HOST:-"https://github.com"}
DOTFILES_USER=${DOTFILES_USER:-"jfmercer"}
DOTFILES_REPO="${DOTFILES_REPO_HOST}/${DOTFILES_USER}/dotfiles"
# TODO: Change to master
DOTFILES_BRANCH=${DOTFILES_BRANCH:-"master"}
DOTFILES_DIR="${HOME}/.local/share/chezmoi"

# TODO: Setup Debian package installs
# if ! command -v git >/dev/null 2>&1; then
#   log_task "Installing git"
#   sudo apt update
#   sudo apt install git --yes
# fi

# macOS Install Homebrew
# This will request the install of Xcode Command Line Tools if necessary
# credit: https://github.com/palantir/jamf-pro-scripts/blob/main/scripts/Install%20Xcode%20Command%20Line%20Tools.sh
if [[ $(command -v brew) == "" ]] && is_macos; then
    # Ask for the administrator password upfront
    sudo -v

    # Keep-alive: update existing `sudo` time stamp until `install_dotfiles.sh` has finished
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

    if pkgutil --pkg-info com.apple.pkg.CLTools_Executables >/dev/null 2>&1; then
        echo "Xcode CLI tools OK"
    else
        echo "Xcode CLI tools not found. Installing them..."
        # softwareupdate looks for this marker to offer the CLI tools package.
        cli_tools_lock=/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
        touch "$cli_tools_lock"
        xcodeCommandLineTools=$(/usr/sbin/softwareupdate --list 2>&1 | \
            /usr/bin/awk -F: '/Label: Command Line Tools for Xcode/ {print $NF}' | \
            /usr/bin/sed 's/^ *//' | \
            /usr/bin/tail -1)
        softwareupdate -i "$xcodeCommandLineTools" --agree-to-license;

        # Verify rather than assume. softwareupdate can exit 0 having installed
        # nothing (e.g. empty label, network failure), and Homebrew's installer
        # below then fails in a much less obvious way.
        if ! /usr/bin/xcode-select --print-path >/dev/null 2>&1 \
           || ! pkgutil --pkg-info com.apple.pkg.CLTools_Executables >/dev/null 2>&1; then
            rm -f "$cli_tools_lock"
            error "Xcode Command Line Tools install failed. Install them with 'xcode-select --install' and re-run."
        fi

        # Leaving this behind confuses later softwareupdate runs.
        rm -f "$cli_tools_lock"
        unset cli_tools_lock
        echo "Installed Xcode Command Line Tools."
    fi

    echo "Installing homebrew"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Put brew on PATH for the rest of this process. Homebrew's installer does not
# touch the calling shell, and on Apple Silicon /opt/homebrew/bin is not on the
# default PATH -- so without this the `brew bundle` in
# .chezmoiscripts/darwin/run_onchange_before_10_homebrew.sh.tmpl fails with
# "command not found" and aborts the whole `chezmoi apply` we exec into below.
# Deliberately outside the install guard above: brew may already be installed
# but still absent from this shell's PATH.
for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
  if [ -x "${brew_bin}" ]; then
    eval "$("${brew_bin}" shellenv)"
    break
  fi
done
unset brew_bin

if [ -d "${DOTFILES_DIR}" ]; then
  git_update "${DOTFILES_DIR}" "${DOTFILES_REPO}" "${DOTFILES_BRANCH}"
else
  log_task "Cloning '${DOTFILES_REPO}' at branch '${DOTFILES_BRANCH}' to '${DOTFILES_DIR}'"
  git clone --branch "${DOTFILES_BRANCH}" "${DOTFILES_REPO}" "${DOTFILES_DIR}"
fi

if [ -f "${DOTFILES_DIR}/install.sh" ]; then
  INSTALL_SCRIPT="${DOTFILES_DIR}/install.sh"
elif [ -f "${DOTFILES_DIR}/install" ]; then
  INSTALL_SCRIPT="${DOTFILES_DIR}/install"
else
  error "No install script found in the dotfiles."
fi

log_task "Running '${INSTALL_SCRIPT}'"
exec "${INSTALL_SCRIPT}"
