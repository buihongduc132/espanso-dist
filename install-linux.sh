#!/usr/bin/env bash
# =============================================================================
# install-linux.sh — Linux entry point for the bhd espanso trigger-pack installer.
#
# Defines the 4 platform-specific functions required by lib/common.sh, then
# sources it to run arg-parse + command dispatch.
#
# Config dir (single canonical path on Linux):
#   - $ESPANSO_CONFIG_DIR override, else
#   - Flatpak: $HOME/.var/app/com.mtxc.espanso/config/espanso (if it exists), else
#   - XDG:     $HOME/.config/espanso
#
# Usage:
#   ./install-linux.sh                # interactive install
#   ./install-linux.sh --update       # pull + redeploy if newer (idempotent)
#   ./install-linux.sh --force        # full reinstall
#   ./install-linux.sh --non-interactive --skip-espanso-install   # config only
# =============================================================================
set -euo pipefail
ENTRY_SCRIPT="$0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── detect_espanso_config_dir ───────────────────────────────────────────────
detect_espanso_config_dir() {
	if [[ -n "${ESPANSO_CONFIG_DIR:-}" ]]; then echo "$ESPANSO_CONFIG_DIR"; return 0; fi
	# Flatpak install keeps config under the sandbox path
	if [[ -d "$HOME/.var/app/com.mtxc.espanso/config/espanso" ]]; then
		echo "$HOME/.var/app/com.mtxc.espanso/config/espanso"; return 0
	fi
	echo "$HOME/.config/espanso"
}

# ─── find_espanso_binary ─────────────────────────────────────────────────────
find_espanso_binary() {
	local paths candidate
	paths=(
		"$HOME/Applications/espanso/usr/bin/espanso"
		"$HOME/.local/bin/espanso"
		"/usr/bin/espanso"
		"/usr/local/bin/espanso"
		"/snap/bin/espanso"
	)
	command -v espanso &>/dev/null && { command -v espanso; return 0; }
	for candidate in "${paths[@]}"; do
		if [[ -x "$candidate" ]]; then echo "$candidate"; return 0; fi
	done
	return 1
}

# ─── install_espanso_platform ────────────────────────────────────────────────
install_espanso_platform() {
	info "Installing espanso on Linux..."
	local tag; tag=$(resolve_espanso_tag)
	info "  Release: $tag"

	# Method 1: official install script (downloads AppImage + registers systemd). Most reliable.
	if command -v systemctl &>/dev/null; then
		info "  Using official espanso install script (AppImage)..."
		if bash <(curl -fsSL "https://raw.githubusercontent.com/federico-terzi/espanso/${tag}/install/install.sh" 2>/dev/null \
		          || curl -fsSL "https://raw.githubusercontent.com/federico-terzi/espanso/master/install/install.sh"); then
			ok "espanso installed via official install script"
			hash -r 2>/dev/null || true
			export PATH="$HOME/.local/bin:$HOME/Applications/espanso/usr/bin:$PATH"
			return 0
		fi
		warn "official install script failed, trying .deb fallback..."
	fi

	# Method 2: .deb package (Debian/Ubuntu)
	if command -v dpkg &>/dev/null; then
		local tmpdir; tmpdir=$(mktemp -d)
		local deb_url
		# Prefer wayland variant (works on both Wayland + X11); fall back to X11
		deb_url=$(http_get_text "${ESPANSO_RELEASE_API}/tags/${tag}" 2>/dev/null \
		          | grep '"browser_download_url"' | grep 'espanso-debian-wayland-amd64.deb' \
		          | head -1 | sed 's/.*"browser_download_url": *"//;s/".*//')
		[[ -z "$deb_url" ]] && deb_url=$(http_get_text "${ESPANSO_RELEASE_API}/tags/${tag}" 2>/dev/null \
		          | grep '"browser_download_url"' | grep 'espanso-debian-x11-amd64.deb' \
		          | head -1 | sed 's/.*"browser_download_url": *"//;s/".*//')
		if [[ -n "$deb_url" ]]; then
			info "  Downloading $deb_url"
			http_get "$deb_url" "$tmpdir/espanso.deb"
			if sudo dpkg -i "$tmpdir/espanso.deb" 2>/dev/null || { sudo apt-get install -f -y && sudo dpkg -i "$tmpdir/espanso.deb"; }; then
				ok "espanso installed via .deb"
				rm -rf "$tmpdir"
				hash -r 2>/dev/null || true
				return 0
			fi
			warn ".deb install failed"
			rm -rf "$tmpdir"
		fi
	fi

	# Method 3: AppImage direct (portable, no sudo)
	local tmpdir; tmpdir=$(mktemp -d)
	local appimage_url
	appimage_url=$(http_get_text "${ESPANSO_RELEASE_API}/tags/${tag}" 2>/dev/null \
	               | grep '"browser_download_url"' | grep 'Espanso-X11.AppImage' \
	               | head -1 | sed 's/.*"browser_download_url": *"//;s/".*//')
	if [[ -n "$appimage_url" ]]; then
		info "  Downloading portable AppImage..."
		http_get "$appimage_url" "$tmpdir/Espanso.AppImage"
		chmod +x "$tmpdir/Espanso.AppImage"
		mkdir -p "$HOME/.local/bin"
		mv "$tmpdir/Espanso.AppImage" "$HOME/.local/bin/espanso"
		chmod +x "$HOME/.local/bin/espanso"
		ok "AppImage installed → $HOME/.local/bin/espanso"
		ok "Run:  espanso service register  (then systemctl --user start espanso)"
		rm -rf "$tmpdir"
		hash -r 2>/dev/null || true
		export PATH="$HOME/.local/bin:$PATH"
		return 0
	fi

	die "Could not install espanso on Linux" \
	    "  Manual install: https://github.com/espanso/espanso/releases/tag/${tag}\n  Or: sudo apt install espanso"
}

# ─── restart_espanso ─────────────────────────────────────────────────────────
restart_espanso() {
	local esp_bin="$1"
	info "Restarting espanso..."

	# Prefer systemd if espanso.service is registered
	if command -v systemctl &>/dev/null; then
		if systemctl --user is-enabled espanso.service &>/dev/null 2>&1; then
			systemctl --user restart espanso.service && { ok "Restarted via systemd"; return 0; } \
				|| warn "systemd restart failed"
		fi
	fi

	# Fallback: bare daemon
	"$esp_bin" stop 2>/dev/null || true
	sleep 0.5
	nohup "$esp_bin" daemon &>/dev/null &
	sleep 1
	"$esp_bin" status &>/dev/null && ok "Restarted via daemon" || warn "espanso may not be running — check logs"
}

# ─── source shared library (runs arg-parse + dispatch) ──────────────────────
source "$SCRIPT_DIR/lib/common.sh"
