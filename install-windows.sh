#!/usr/bin/env bash
# =============================================================================
# install-windows.sh — Windows entry point for the bhd espanso trigger-pack installer.
# Runs under Git Bash / MSYS2 / Cygwin (espanso ships an NSIS .exe installer).
#
# Defines the 4 platform-specific functions required by lib/common.sh, then
# sources it to run arg-parse + command dispatch.
#
# Config dir (single canonical path on Windows):
#   - $ESPANSO_CONFIG_DIR override, else
#   - %APPDATA%\espanso  (i.e. $HOME/AppData/Roaming/espanso)
#
# Usage (Git Bash):
#   ./install-windows.sh                # interactive install
#   ./install-windows.sh --update       # pull + redeploy if newer (idempotent)
#   ./install-windows.sh --force        # full reinstall
#   ./install-windows.sh --non-interactive --skip-espanso-install   # config only
# =============================================================================
set -euo pipefail
ENTRY_SCRIPT="$0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── detect_espanso_config_dir ───────────────────────────────────────────────
detect_espanso_config_dir() {
	if [[ -n "${ESPANSO_CONFIG_DIR:-}" ]]; then echo "$ESPANSO_CONFIG_DIR"; return 0; fi
	local appdata="${APPDATA:-$HOME/AppData/Roaming}"
	echo "$appdata/espanso"
}

# ─── find_espanso_binary ─────────────────────────────────────────────────────
find_espanso_binary() {
	local localbin="${LOCALAPPDATA:-$HOME/AppData/Local}"
	local paths candidate
	paths=(
		"$localbin/Programs/Espanso/Espanso.exe"
		"$localbin/Programs/espanso/espanso.exe"
		"$HOME/.local/bin/espanso.exe"
	)
	command -v espanso &>/dev/null && { command -v espanso; return 0; }
	for candidate in "${paths[@]}"; do
		if [[ -x "$candidate" ]]; then echo "$candidate"; return 0; fi
	done
	return 1
}

# ─── install_espanso_platform ────────────────────────────────────────────────
install_espanso_platform() {
	info "Installing espanso on Windows..."
	local tag; tag=$(resolve_espanso_tag)
	local tmpdir; tmpdir=$(mktemp -d)
	local exe_url
	exe_url=$(http_get_text "${ESPANSO_RELEASE_API}/tags/${tag}" 2>/dev/null \
	         | grep '"browser_download_url"' | grep 'Espanso-Win-Installer-x86_64.exe' \
	         | head -1 | sed 's/.*"browser_download_url": *"//;s/".*//')
	if [[ -z "$exe_url" ]]; then
		die "Could not find espanso Windows installer for $tag" \
		    "  Download manually: https://github.com/espanso/espanso/releases/tag/${tag}"
	fi
	info "  Downloading $exe_url"
	http_get "$exe_url" "$tmpdir/espanso-setup.exe"
	# Run the NSIS installer. /S = silent, /D=dir optional.
	# In a non-admin Git Bash session this installs per-user.
	if cmd.exe //c "$tmpdir\\espanso-setup.exe /S" 2>/dev/null; then
		ok "espanso installed via setup.exe"
	else
		# Fallback: try running without silent flag (may show GUI installer)
		warn "silent install failed — trying interactive installer..."
		cmd.exe //c "start '' '$tmpdir\\espanso-setup.exe'" 2>/dev/null || true
		warn "If a GUI installer appeared, complete it, then re-run this script."
	fi
	rm -rf "$tmpdir"
	# espanso installs to %LOCALAPPDATA%\Programs\Espanso\ ; it auto-adds to PATH after shell restart
	export PATH="${LOCALAPPDATA:-$HOME/AppData/Local}/Programs/Espanso:$PATH"
	hash -r 2>/dev/null || true
}

# ─── restart_espanso ─────────────────────────────────────────────────────────
restart_espanso() {
	local esp_bin="$1"
	info "Restarting espanso..."
	"$esp_bin" stop 2>/dev/null || true
	sleep 0.5
	if "$esp_bin" start 2>/dev/null; then
		ok "Started via espanso cli"
	elif "$esp_bin" daemon 2>/dev/null; then
		ok "Started via espanso daemon"
	else
		warn "espanso may not be running — check logs:  $esp_bin log"
	fi
	sleep 1
	"$esp_bin" status &>/dev/null && ok "espanso is running" || true
}

# ─── source shared library (runs arg-parse + dispatch) ──────────────────────
source "$SCRIPT_DIR/lib/common.sh"
