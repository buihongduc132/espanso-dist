#!/usr/bin/env bash
# =============================================================================
# install.sh — Auto-detecting dispatcher for the bhd espanso trigger-pack installer.
#
# This thin wrapper detects the OS and execs the platform-specific entry script:
#   - linux   → install-linux.sh
#   - macos   → install-macos.sh
#   - windows → install-windows.sh   (Git Bash / MSYS2 / Cygwin)
#
# Each platform script sources lib/common.sh (shared fetch/deploy/verify logic,
# idempotent update via --update). Run this dispatcher any number of times — it
# always routes to the same platform script and is safe to re-run.
#
# Preserves the one-liner install flow:
#   curl -sL https://raw.githubusercontent.com/buihongduc132/espanso-dist/main/install.sh | bash
#
# For explicit per-platform use:
#   ./install-linux.sh     ./install-macos.sh     ./install-windows.sh
#
# Flags are passed through verbatim (--update, --force, --non-interactive,
# --skip-espanso-install, --version, --uninstall, --help).
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

detect_os() {
	case "$(uname -s)" in
		Linux*)  echo "linux" ;;
		Darwin*) echo "macos" ;;
		MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
		*)       echo "unknown:$(uname -s)" ;;
	esac
}

# --help here only covers the dispatcher; full help comes from the platform script.
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
	cat <<EOF
bhd espanso trigger-pack — installer dispatcher

Detects the OS and runs the matching platform installer. All flags are
forwarded to it.

Usage:
  ./install.sh                         Auto-detect OS + install (interactive)
  ./install.sh --update                Pull + redeploy if newer (idempotent)
  ./install.sh --force                 Force reinstall
  ./install.sh --version               Show installed version
  ./install.sh --uninstall             Remove trigger pack (keeps espanso)
  ./install.sh --non-interactive       Skip prompts (CI / scripts)
  ./install.sh --skip-espanso-install  Deploy config only
  ./install.sh --help                  This message

Explicit per-platform entry points (same flags):
  ./install-linux.sh     # Linux    (config: ~/.config/espanso)
  ./install-macos.sh     # macOS    (config: auto-detected via \`espanso path\`)
  ./install-windows.sh   # Windows  (config: %APPDATA%\\espanso, Git Bash)

One-liner:
  curl -sL https://raw.githubusercontent.com/buihongduc132/espanso-dist/main/install.sh | bash

Env:  BHD_TRIGGER_PACK_REPO  ESPANSO_CONFIG_DIR  ESPANSO_VERSION  GITHUB_TOKEN
EOF
	exit 0
fi

os="$(detect_os)"
case "$os" in
	linux)   target="$SCRIPT_DIR/install-linux.sh" ;;
	macos)   target="$SCRIPT_DIR/install-macos.sh" ;;
	windows) target="$SCRIPT_DIR/install-windows.sh" ;;
	*)
		echo "ERROR: Unsupported OS: $(uname -s)" >&2
		echo "Install espanso manually: https://espanso.org/install/" >&2
		exit 1
		;;
esac

if [[ ! -f "$target" ]]; then
	echo "ERROR: Platform installer not found: $target" >&2
	echo "This dispatcher expects install-$os.sh + lib/common.sh alongside it." >&2
	exit 1
fi

exec bash "$target" "$@"
