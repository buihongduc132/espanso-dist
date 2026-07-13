#!/usr/bin/env bash
# =============================================================================
# install-macos.sh — macOS entry point for the bhd espanso trigger-pack installer.
#
# Defines the 4 platform-specific functions required by lib/common.sh, then
# sources it to run arg-parse + command dispatch.
#
# Config dir (auto-detected, one stable path thereafter):
#   - $ESPANSO_CONFIG_DIR override (highest priority), else
#   - what `espanso path` reports as Config (if a binary exists + writable), else
#   - $HOME/.config/espanso (XDG, consistent with Linux), else
#   - $HOME/Library/Application Support/espanso (official macOS default)
#
# macOS-specific fixes baked in (see flow/findings/2026-07-13_espanso_macos_install_blockers.md):
#   - Quarantine: extracted Espanso.app is checked for com.apple.quarantine;
#     stripped best-effort (SIP may block — surfaced clearly if so).
#   - Restart: the GUI `launcher` hangs on some machines ("unable to start
#     service: timed out"). We try `espanso start`, and on timeout fall back to
#     a LaunchAgent that runs `espanso daemon` with RunAtLoad + KeepAlive.
#
# Usage:
#   ./install-macos.sh                # interactive install
#   ./install-macos.sh --update       # pull + redeploy if newer (idempotent)
#   ./install-macos.sh --force        # full reinstall
#   ./install-macos.sh --skip-espanso-install --non-interactive   # config only
# =============================================================================
set -euo pipefail
ENTRY_SCRIPT="$0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── detect_espanso_config_dir (auto-detect) ─────────────────────────────────
detect_espanso_config_dir() {
	# 1. Explicit override always wins
	if [[ -n "${ESPANSO_CONFIG_DIR:-}" ]]; then echo "$ESPANSO_CONFIG_DIR"; return 0; fi

	# 2. Ask an existing espanso binary where it reads config from.
	#    This matters because on macOS the active path varies by install method
	#    (Homebrew/CLI → ~/.config/espanso; signed .app → ~/Library/Application Support/espanso).
	local bin
	if bin="$(command -v espanso 2>/dev/null)" || bin="$(_mac_find_binary_fast 2>/dev/null)"; then
		local reported
		reported=$("$bin" path 2>/dev/null | awk -F': ' '/^Config:/ {print $2; exit}')
		if [[ -n "$reported" ]]; then
			# Resolve ~ / $HOME and confirm writable (or creatable)
			reported="${reported/#\~/$HOME}"
			if mkdir -p "$reported" 2>/dev/null && [[ -w "$reported" ]]; then
				echo "$reported"; return 0
			fi
		fi
	fi

	# 3. XDG default (keeps Linux/macOS paths identical when possible)
	if mkdir -p "$HOME/.config/espanso" 2>/dev/null; then
		echo "$HOME/.config/espanso"; return 0
	fi

	# 4. Official macOS default
	echo "$HOME/Library/Application Support/espanso"
}

# internal helper (used before find_espanso_binary is fully defined)
_mac_find_binary_fast() {
	local p
	for p in "/Applications/Espanso.app/Contents/MacOS/espanso" \
	         "$HOME/Applications/Espanso.app/Contents/MacOS/espanso" \
	         "/usr/local/bin/espanso" \
	         "$HOME/.local/bin/espanso"; do
		[[ -x "$p" ]] && { echo "$p"; return 0; }
	done
	return 1
}

# ─── find_espanso_binary ─────────────────────────────────────────────────────
find_espanso_binary() {
	local paths candidate
	paths=(
		"/Applications/Espanso.app/Contents/MacOS/espanso"
		"$HOME/Applications/Espanso.app/Contents/MacOS/espanso"
		"$HOME/.local/bin/espanso"
		"/usr/local/bin/espanso"
		"$(brew --prefix 2>/dev/null || echo /opt/homebrew)/bin/espanso"
		"/Applications/espanso/usr/bin/espanso"
		"$HOME/Applications/espanso/usr/bin/espanso"
	)
	command -v espanso &>/dev/null && { command -v espanso; return 0; }
	for candidate in "${paths[@]}"; do
		if [[ -x "$candidate" ]]; then echo "$candidate"; return 0; fi
	done
	return 1
}

# ─── install_espanso_platform ────────────────────────────────────────────────
install_espanso_platform() {
	info "Installing espanso on macOS..."
	# Method 1: Homebrew
	if command -v brew &>/dev/null; then
		if brew install espanso; then ok "espanso installed via Homebrew"; hash -r 2>/dev/null || true; return 0; fi
		warn "brew install failed"
	fi
	# Method 2: official zip → .app
	local tag; tag=$(resolve_espanso_tag)
	local tmpdir; tmpdir=$(mktemp -d)
	local zip_url
	zip_url=$(http_get_text "${ESPANSO_RELEASE_API}/tags/${tag}" 2>/dev/null \
	          | grep '"browser_download_url"' | grep 'Espanso-Mac-Universal.zip' \
	          | head -1 | sed 's/.*"browser_download_url": *"//;s/".*//')
	if [[ -n "$zip_url" ]]; then
		info "  Downloading $zip_url"
		http_get "$zip_url" "$tmpdir/espanso.zip"
		unzip -o "$tmpdir/espanso.zip" -d "$tmpdir/" >/dev/null
		# The Mac Universal release is a zip wrapping Espanso.dmg
		local app_src=""
		[[ -d "$tmpdir/Espanso.app" ]] && app_src="$tmpdir/Espanso.app"
		if [[ -z "$app_src" ]]; then
			# zip contained a .dmg — mount + extract
			local dmg; dmg=$(find "$tmpdir" -name '*.dmg' 2>/dev/null | head -1)
			if [[ -n "$dmg" ]]; then
				local mnt; mnt=$(mktemp -d)
				hdiutil attach "$dmg" -nobrowse -readonly -mountpoint "$mnt" >/dev/null 2>&1 || true
				[[ -d "$mnt/Espanso.app" ]] && app_src="$mnt/Espanso.app"
			fi
		fi
		if [[ -n "$app_src" ]]; then
			# Place into /Applications (preferred) or ~/Applications
			local dest="/Applications"
			if ! cp -R "$app_src" "$dest/" 2>/dev/null; then
				dest="$HOME/Applications"; mkdir -p "$dest"; cp -R "$app_src" "$dest/"
			fi
			ok "Espanso.app installed → $dest/Espanso.app"
			_mac_strip_quarantine "$dest/Espanso.app"
			# Register CLI path
			local bin="$dest/Espanso.app/Contents/MacOS/espanso"
			[[ -x "$bin" ]] || bin="$HOME/Applications/Espanso.app/Contents/MacOS/espanso"
			mkdir -p "$HOME/.local/bin"
			ln -sf "$bin" "$HOME/.local/bin/espanso" 2>/dev/null || true
			hash -r 2>/dev/null || true
			export PATH="$HOME/.local/bin:$PATH"
			rm -rf "$tmpdir"
			return 0
		fi
		rm -rf "$tmpdir"
	fi
	die "Could not install espanso on macOS" \
	    "  Manual install: https://github.com/espanso/espanso/releases/tag/${tag}\n  Or: brew install espanso"
}

# Best-effort quarantine strip. SIP may block xattr even as root; we surface that.
_mac_strip_quarantine() {
	local app="$1"
	if ! xattr -lr "$app" 2>/dev/null | grep -q 'com.apple.quarantine'; then
		return 0   # already clean
	fi
	info "  Espanso.app is quarantined (browser download) — stripping com.apple.quarantine..."
	if xattr -dr com.apple.quarantine "$app" 2>/dev/null; then
		ok "Quarantine stripped (user-level xattr)"
	elif sudo -n xattr -dr com.apple.quarantine "$app" 2>/dev/null; then
		ok "Quarantine stripped (via sudo)"
	else
		# Try sudo interactively (only in interactive mode)
		if [[ "${NON_INTERACTIVE:-0}" != 1 ]] && ask "Quarantine removal needs sudo. Run 'sudo xattr -dr'?" "y"; then
			if sudo xattr -dr com.apple.quarantine "$app" 2>/dev/null; then
				ok "Quarantine stripped (via sudo)"
			else
				warn "SIP blocked quarantine removal (EPERM even as root)."
				warn "Workaround: the app may App-Translocate. See flow/findings/2026-07-13_espanso_macos_install_blockers.md"
			fi
		else
			warn "Could not auto-strip quarantine. If triggers fail to fire after granting Accessibility,"
			warn "re-extract from the DMG (curl+unzip do not set quarantine) — see the finding doc."
		fi
	fi
}

# ─── restart_espanso ─────────────────────────────────────────────────────────
restart_espanso() {
	local esp_bin="$1"
	info "Restarting espanso..."

	"$esp_bin" stop 2>/dev/null || true
	sleep 1

	# Try the normal `espanso start` first.
	if "$esp_bin" start 2>/dev/null; then
		ok "Started via espanso cli"
		return 0
	fi
	warn "espanso start did not return success (common on macOS when the launcher times out)."
	warn "Falling back to LaunchAgent in daemon mode..."

	# Fallback: a LaunchAgent running `espanso daemon` (proven to work where the
	# launcher hangs). Re-register service + patch the plist, then load it.
	"$esp_bin" service register 2>/dev/null || true
	local plist="$HOME/Library/LaunchAgents/com.federicoterzi.espanso.plist"
	_mac_write_daemon_plist "$plist" "$esp_bin"

	launchctl unload "$plist" 2>/dev/null || true
	pkill -9 -f "espanso" 2>/dev/null || true
	sleep 1
	if launchctl load "$plist" 2>/dev/null; then
		sleep 4
		if "$esp_bin" status 2>/dev/null | grep -qi "running"; then
			ok "Started via LaunchAgent (daemon mode)"
			return 0
		fi
	fi
	warn "LaunchAgent start did not confirm running. Check:  $esp_bin log"
	return 0
}

# Write a LaunchAgent plist that runs `espanso daemon` (not launcher), with
# RunAtLoad + KeepAlive so espanso survives reboot and auto-restarts.
_mac_write_daemon_plist() {
	local plist="$1" esp_bin="$2"
	mkdir -p "$(dirname "$plist")"
	cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.federicoterzi.espanso</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$HOME/.local/bin</string>
    </dict>
    <key>ProgramArguments</key>
    <array>
        <string>$esp_bin</string>
        <string>daemon</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ThrottleInterval</key>
    <integer>10</integer>
    <key>StandardErrorPath</key>
    <string>/tmp/espanso.err</string>
    <key>StandardOutPath</key>
    <string>/tmp/espanso.out</string>
</dict>
</plist>
PLIST
}

# ─── source shared library (runs arg-parse + dispatch) ──────────────────────
source "$SCRIPT_DIR/lib/common.sh"
