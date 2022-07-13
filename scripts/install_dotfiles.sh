#!/bin/bash

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

DOTFILES_REPO_HOST=${DOTFILES_REPO_HOST:-"https://github.com"}
DOTFILES_USER=${DOTFILES_USER:-"jfmercer"}
DOTFILES_REPO="${DOTFILES_REPO_HOST}/${DOTFILES_USER}/dotfiles"
# TODO: Change to master
DOTFILES_BRANCH=${DOTFILES_BRANCH:-"migrate-to-chezmoi"}
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
        touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress;
        xcodeCommandLineTools=$(/usr/sbin/softwareupdate --list 2>&1 | \
            /usr/bin/awk -F: '/Label: Command Line Tools for Xcode/ {print $NF}' | \
            /usr/bin/sed 's/^ *//' | \
            /usr/bin/tail -1)
        softwareupdate -i "$xcodeCommandLineTools" --agree-to-license;
    fi

    echo "Installing homebrew"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

if [ -d "${DOTFILES_DIR}" ]; then
  git_clean "${DOTFILES_DIR}" "${DOTFILES_REPO}" "${DOTFILES_BRANCH}"
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
