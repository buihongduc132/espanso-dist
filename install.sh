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
# Supports three invocation modes:
#   1. Local checkout:  ./install.sh        (sibling install-<os>.sh + lib/)
#   2. Piped one-liner: curl ... | bash     (fetches platform script from GitHub)
#   3. Saved copy:      <config_dir>/install.sh   (after a prior install)
#
# One-liner:
#   curl -sL https://raw.githubusercontent.com/buihongduc132/espanso-dist/main/install.sh | bash
#
# For explicit per-platform use:
#   ./install-linux.sh     ./install-macos.sh     ./install-windows.sh
#
# Flags are passed through verbatim (--update, --force, --non-interactive,
# --skip-espanso-install, --version, --uninstall, --help).
# =============================================================================
set -uo pipefail   # not -e: we handle errors explicitly so the piped case works

GITHUB_REPO="${BHD_TRIGGER_PACK_REPO:-buihongduc132/espanso-dist}"
GITHUB_RAW="https://raw.githubusercontent.com/${GITHUB_REPO}/main"

detect_os() {
	case "$(uname -s)" in
		Linux*)  echo "linux" ;;
		Darwin*) echo "macos" ;;
		MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
		*)       echo "unknown:$(uname -s)" ;;
	esac
}

# Resolve the directory this script lives in (empty when piped via stdin).
script_source=""
if [[ -n "${BASH_SOURCE[0]:-}" && "${BASH_SOURCE[0]}" != "-bash" ]]; then
	# Follow symlinks to find the real location
	src="${BASH_SOURCE[0]}"
	while [[ -L "$src" ]]; do
		dir="$(cd -P "$(dirname "$src")" >/dev/null 2>&1 && pwd)"
		src="$(readlink "$src")"
		[[ "$src" != /* ]] && src="$dir/$src"
	done
	if [[ -f "$src" ]]; then
		script_source="$(cd -P "$(dirname "$src")" >/dev/null 2>&1 && pwd)"
	fi
fi

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
  curl -sL https://raw.githubusercontent.com/${GITHUB_REPO}/main/install.sh | bash

Env:  BHD_TRIGGER_PACK_REPO  ESPANSO_CONFIG_DIR  ESPANSO_VERSION  GITHUB_TOKEN
EOF
	exit 0
fi

os="$(detect_os)"
case "$os" in
	linux|macos|windows) ;;
	*)
		echo "ERROR: Unsupported OS: $(uname -s)" >&2
		echo "Install espanso manually: https://espanso.org/install/" >&2
		exit 1
		;;
esac

# ─── Find the platform entry script ──────────────────────────────────────────
# Case 1: local checkout — the platform script sits next to this dispatcher.
target=""
if [[ -n "$script_source" && -f "$script_source/install-$os.sh" ]]; then
	target="$script_source/install-$os.sh"
fi

# Case 2: saved copy in the espanso config dir (after a prior install) — the
# installer self-copies as install.sh; the platform scripts may not be there,
# so fall through to Case 3 (download).
if [[ -z "$target" ]]; then
	# Case 3: piped via curl (no local file) OR local copy missing the platform
	# scripts → download the platform entry script + lib/common.sh into a temp
	# dir from the raw GitHub URL, then run from there.
	tmp_dir="$(mktemp -d)"
	trap 'rm -rf "$tmp_dir"' EXIT

	echo "Downloading installer for $os..." >&2
	dl_ok=1
	if command -v curl &>/dev/null; then
		curl -fsSL "$GITHUB_RAW/install-$os.sh" -o "$tmp_dir/install-$os.sh" || dl_ok=0
		mkdir -p "$tmp_dir/lib"
		curl -fsSL "$GITHUB_RAW/lib/common.sh" -o "$tmp_dir/lib/common.sh" || dl_ok=0
	elif command -v wget &>/dev/null; then
		wget -q "$GITHUB_RAW/install-$os.sh" -O "$tmp_dir/install-$os.sh" || dl_ok=0
		mkdir -p "$tmp_dir/lib"
		wget -q "$GITHUB_RAW/lib/common.sh" -O "$tmp_dir/lib/common.sh" || dl_ok=0
	else
		echo "ERROR: need curl or wget to download the platform installer" >&2
		exit 1
	fi

	if [[ "$dl_ok" != 1 ]] || [[ ! -s "$tmp_dir/install-$os.sh" ]] || [[ ! -s "$tmp_dir/lib/common.sh" ]]; then
		echo "ERROR: failed to download installer from $GITHUB_RAW" >&2
		echo "Check network / repo access, or clone the repo and run ./install-$os.sh directly." >&2
		rm -rf "$tmp_dir"
		exit 1
	fi
	chmod +x "$tmp_dir/install-$os.sh"
	# Clear the trap so the temp dir persists through exec; the platform script
	# doesn't need cleanup of the installer itself (it re-clones into the config dir).
	trap - EXIT
	target="$tmp_dir/install-$os.sh"
fi

exec bash "$target" "$@"
