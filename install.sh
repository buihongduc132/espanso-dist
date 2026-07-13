#!/usr/bin/env bash
# =============================================================================
# install.sh — One-shot installer for the bhd espanso trigger pack
#
# What it does (all steps idempotent, safe to re-run):
#   1. Detect OS + arch (linux / macos / windows)
#   2. Install espanso binary if missing (official GitHub release assets)
#   3. Clone / pull the dist repo (match files + config)
#   4. Deploy match/*.yml + config/default.yml to the espanso config dir
#   5. Start / restart espanso and verify triggers loaded
#
# Usage:
#   curl -sL https://raw.githubusercontent.com/buihongduc132/espanso-dist/main/install.sh | bash
#   ./install.sh                  # interactive install
#   ./install.sh --update         # pull + redeploy if newer version
#   ./install.sh --force          # force reinstall everything
#   ./install.sh --non-interactive # skip prompts, use defaults
#   ./install.sh --version        # show installed version
#   ./install.sh --uninstall      # remove trigger pack (keeps espanso)
#   ./install.sh --skip-espanso-install  # don't try to install espanso
#
# Env overrides:
#   BHD_TRIGGER_PACK_REPO   GitHub repo (default: buihongduc132/espanso-dist)
#   ESPANSO_CONFIG_DIR      Custom espanso config dir (auto-detected per OS)
#   ESPANSO_VERSION         Pin espanso release (default: latest, e.g. v2.3.0)
#   GITHUB_TOKEN            For private repos / rate limits
# =============================================================================
set -euo pipefail

# ─── Configuration ──────────────────────────────────────────────────────────
GITHUB_REPO="${BHD_TRIGGER_PACK_REPO:-buihongduc132/espanso-dist}"
GITHUB_RAW="https://raw.githubusercontent.com/${GITHUB_REPO}/main"
GITHUB_API="https://api.github.com/repos/${GITHUB_REPO}"
ESPANSO_RELEASE_API="https://api.github.com/repos/espanso/espanso/releases"
CLONE_DIR_NAME="espanso-dist-clone"

# Auth header for private repos / rate limits
AUTH_HEADER=""
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
	AUTH_HEADER="-H \"Authorization: token ${GITHUB_TOKEN}\""
fi

# ─── Colors & Logging ───────────────────────────────────────────────────────
if [[ -t 1 ]] && command -v tput &>/dev/null && [[ $(tput colors 2>/dev/null || echo 0) -ge 8 ]]; then
	HAS_COLOR=1
else
	HAS_COLOR=0
fi
C() { [[ "$HAS_COLOR" == 1 ]] && echo -en "$1" >&2 || true; }
R() { C '\033[0m'; }
RED()     { C '\033[0;31m'; echo -n "$*" >&2; R; }
GREEN()   { C '\033[0;32m'; echo -n "$*" >&2; R; }
YELLOW()  { C '\033[1;33m'; echo -n "$*" >&2; R; }
BLUE()    { C '\033[0;34m'; echo -n "$*" >&2; R; }
CYAN()    { C '\033[0;36m'; echo -n "$*" >&2; R; }
DIM()     { C '\033[2m';   echo -n "$*" >&2; R; }
BOLD()    { C '\033[1m';   echo -n "$*" >&2; R; }
NL() { echo "" >&2; }

# NOTE: all logging goes to stderr so stdout stays clean for captured output
# (e.g. fetch_dist returns a path via stdout).
info()  { BLUE "  ● "; echo "$*" >&2; }
ok()    { GREEN "  ✔ "; echo "$*" >&2; }
warn()  { YELLOW "  ⚠ "; echo "$*" >&2; }
err()   { RED "  ✘ "; echo "$*" >&2; NL; }
die()   { NL; RED "  ✘ ERROR: "; echo "$1" >&2; NL
          [[ -n "${2:-}" ]] && { YELLOW "  💡 Troubleshooting:"; NL; echo "$2" >&2; }
          NL; exit 1; }
step()  { NL; CYAN "━━━ "; BOLD "$1"; CYAN " ━━━"; NL; }

ask() {
	local prompt="${1:-Continue?}" default="${2:-y}" yn answer
	# --yes / ASSUME_YES forces "yes" to every prompt (for CI / scripted uninstall)
	[[ "${ASSUME_YES:-0}" == "1" ]] && default="y"
	if [[ "$default" == "y" ]]; then yn="[Y/n]"; else yn="[y/N]"; fi
	# Non-interactive OR assume-yes: skip the read, return the default
	if [[ "${NON_INTERACTIVE:-0}" == "1" ]] || [[ "${ASSUME_YES:-0}" == "1" ]]; then
		[[ "$default" == "y" ]] && return 0 || return 1
	fi
	echo -n "  ? $prompt $yn " >&2
	read -r answer
	case "$answer" in
		y|Y|yes|YES) return 0 ;;
		n|N|no|NO)   return 1 ;;
		*) [[ "$default" == "y" ]] && return 0 || return 1 ;;
	esac
}

# ─── OS / Arch Detection ────────────────────────────────────────────────────
detect_os() {
	case "$(uname -s)" in
		Linux*)  echo "linux" ;;
		Darwin*) echo "macos" ;;
		MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
		*)       echo "unknown:$(uname -s)" ;;
	esac
}
detect_arch() {
	case "$(uname -m)" in
		x86_64|amd64) echo "x86_64" ;;
		aarch64|arm64) echo "arm64" ;;
		*) echo "$(uname -m)" ;;
	esac
}

# ─── HTTP helpers ───────────────────────────────────────────────────────────
has_curl() { command -v curl &>/dev/null; }
has_wget() { command -v wget &>/dev/null; }

http_get() {  # url  output_file
	local url="$1" output="$2"
	if has_curl; then curl -fsSL ${AUTH_HEADER:+-H "Authorization: token ${GITHUB_TOKEN}"} "$url" -o "$output"
	elif has_wget; then wget -q ${AUTH_HEADER:+--header="Authorization: token ${GITHUB_TOKEN}"} "$url" -O "$output"
	else die "No HTTP client found" "  Install curl:  apt install curl / brew install curl / pacman -S curl"
	fi
}
http_get_text() {  # url  -> stdout
	local url="$1"
	if has_curl; then curl -fsSL ${AUTH_HEADER:+-H "Authorization: token ${GITHUB_TOKEN}"} "$url" 2>/dev/null
	elif has_wget; then wget -qO- ${AUTH_HEADER:+--header="Authorization: token ${GITHUB_TOKEN}"} "$url" 2>/dev/null
	else return 1
	fi
}
require_http() {
	has_curl || has_wget || die "No HTTP client (curl/wget)" \
		"  sudo apt install curl   (Debian/Ubuntu)\n  sudo dnf install curl   (Fedora)\n  brew install curl          (macOS)\n  scoop install curl        (Windows)"
}

# ─── Espanso binary detection ───────────────────────────────────────────────
find_espanso_binary() {
	local os paths candidate
	os="$(detect_os)"
	case "$os" in
		linux)
			paths=(
				"$HOME/Applications/espanso/usr/bin/espanso"
				"$HOME/.local/bin/espanso"
				"/usr/bin/espanso"
				"/usr/local/bin/espanso"
				"/snap/bin/espanso"
			) ;;
		macos)
			# On macOS espanso ships as Espanso.app; the CLI binary lives at
			# Espanso.app/Contents/MacOS/espanso. Homebrew cask → /Applications,
			# manual install → /Applications or ~/Applications.
			paths=(
				"/Applications/Espanso.app/Contents/MacOS/espanso"
				"$HOME/Applications/Espanso.app/Contents/MacOS/espanso"
				"$HOME/.local/bin/espanso"
				"/usr/local/bin/espanso"
				"$(brew --prefix 2>/dev/null || echo /opt/homebrew)/bin/espanso"
				# Legacy AppImage-style layout (rare on macOS)
				"/Applications/espanso/usr/bin/espanso"
				"$HOME/Applications/espanso/usr/bin/espanso"
			) ;;
		windows)
			local localbin="${LOCALAPPDATA:-$HOME/AppData/Local}"
			paths=(
				"$localbin/Programs/Espanso/Espanso.exe"
				"$localbin/Programs/espanso/espanso.exe"
				"$HOME/.local/bin/espanso.exe"
			) ;;
		*) paths=() ;;
	esac
	command -v espanso &>/dev/null && { command -v espanso; return 0; }
	for candidate in "${paths[@]}"; do
		if [[ -x "$candidate" ]]; then echo "$candidate"; return 0; fi
	done
	return 1
}
get_espanso_version() { local b="${1:-}"; [[ -n "$b" ]] && "$b" --version 2>/dev/null | head -1 || echo "unknown"; }

# ─── Espanso config dir detection ───────────────────────────────────────────
detect_espanso_config_dir() {
	if [[ -n "${ESPANSO_CONFIG_DIR:-}" ]]; then echo "$ESPANSO_CONFIG_DIR"; return 0; fi
	local os; os="$(detect_os)"
	case "$os" in
		linux)
			[[ -d "$HOME/.var/app/com.mtxc.espanso/config/espanso" ]] && { echo "$HOME/.var/app/com.mtxc.espanso/config/espanso"; return 0; }
			echo "$HOME/.config/espanso" ;;
		macos) echo "$HOME/Library/Application Support/espanso" ;;
		windows)
			local appdata="${APPDATA:-$HOME/AppData/Roaming}"; echo "$appdata/espanso" ;;
		*) echo "$HOME/.config/espanso" ;;
	esac
}

# ══════════════════════════════════════════════════════════════════════════════
# ESPANSO INSTALLATION (the new capability — installs espanso itself)
# ══════════════════════════════════════════════════════════════════════════════

# Resolve which espanso release tag to install: ESPANSO_VERSION or latest.
resolve_espanso_tag() {
	if [[ -n "${ESPANSO_VERSION:-}" ]]; then echo "$ESPANSO_VERSION"; return 0; fi
	local tag
	tag=$(http_get_text "${ESPANSO_RELEASE_API}/latest" 2>/dev/null | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"//;s/".*//')
	[[ -n "$tag" ]] && echo "$tag" || echo "v2.3.0"
}

install_espanso() {
	local os; os="$(detect_os)"
	case "$os" in
		linux)   install_espanso_linux ;;
		macos)   install_espanso_macos ;;
		windows) install_espanso_windows ;;
		*) die "Unsupported OS for auto-install: $os" \
		     "  Install espanso manually: https://espanso.org/install/" ;;
	esac
}

install_espanso_linux() {
	info "Installing espanso on Linux..."
	local tag; tag=$(resolve_espanso_tag)
	info "  Release: $tag"

	# Method 1: official install script (downloads AppImage + registers systemd). Most reliable.
	if command -v systemctl &>/dev/null; then
		info "  Using official espanso install script (AppImage)..."
		if bash <(curl -fsSL "https://raw.githubusercontent.com/federico-terzi/espanso/${tag}/install/install.sh" 2>/dev/null \
		          || curl -fsSL "https://raw.githubusercontent.com/federico-terzi/espanso/master/install/install.sh"); then
			ok "espanso installed via official install script"
			# Reload PATH so `espanso` resolves immediately
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

install_espanso_macos() {
	info "Installing espanso on macOS..."
	# Method 1: Homebrew
	if command -v brew &>/dev/null; then
		if brew install espanso; then ok "espanso installed via Homebrew"; hash -r 2>/dev/null || true; return 0; fi
		warn "brew install failed"
	fi
	# Method 2: official zip
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
		# Move Espanso.app to /Applications
		if [[ -d "$tmpdir/Espanso.app" ]]; then
			cp -R "$tmpdir/Espanso.app" /Applications/ 2>/dev/null || cp -R "$tmpdir/Espanso.app" "$HOME/Applications/" 2>/dev/null
			ok "Espanso.app installed"
			# Register path
			local bin="/Applications/Espanso.app/Contents/MacOS/Espanso"
			[[ -x "$bin" ]] || bin="$HOME/Applications/Espanso.app/Contents/MacOS/Espanso"
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

install_espanso_windows() {
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

# ══════════════════════════════════════════════════════════════════════════════
# DIST DOWNLOAD (clone / pull the trigger-pack repo)
# ══════════════════════════════════════════════════════════════════════════════

# Clone or update the dist repo into a working dir; echo the dir path.
fetch_dist() {
	local workdir="$1"
	local clone_url="https://github.com/${GITHUB_REPO}.git"
	if [[ -n "${GITHUB_TOKEN:-}" ]]; then
		clone_url="https://${GITHUB_TOKEN}@github.com/${GITHUB_REPO}.git"
	fi

	if [[ -d "$workdir/.git" ]]; then
		info "Updating existing clone: $workdir"
		( cd "$workdir" && git fetch --depth 1 origin main 2>/dev/null && git reset --hard origin/main 2>/dev/null ) \
			|| warn "git update failed (continuing with local copy)"
	else
		info "Cloning ${GITHUB_REPO} → $workdir"
		git clone --depth 1 "$clone_url" "$workdir" || die "git clone failed" \
			"  Check network / repo access: https://github.com/${GITHUB_REPO}\n  For private repos set GITHUB_TOKEN"
	fi
	echo "$workdir"
}

# ─── Deploy config + match files ────────────────────────────────────────────
deploy_files() {
	local src_dir="$1" config_dir="$2"
	local match_dir="$config_dir/match"
	local config_file="$config_dir/config/default.yml"

	# ── match/ (flat .yml files) ──────────────────────────────
	info "Deploying match files → $match_dir/"
	rm -rf "$match_dir"
	mkdir -p "$match_dir/packages"   # empty dir, mirrors source-machine layout
	local deployed=0 f
	while IFS= read -r -d '' f; do
		[[ "$f" == *.backup_* ]] && continue
		cp "$f" "$match_dir/"
		deployed=$((deployed + 1))
	done < <(find "$src_dir/match" -name '*.yml' -print0 2>/dev/null)
	[[ "$deployed" -gt 0 ]] || die "No .yml files in $src_dir/match/" \
		"  The clone may be incomplete. Try:  rm -rf $(dirname "$src_dir") && ./install.sh --force"
	ok "Deployed $deployed match files"

	# ── espanso-install/ (iOS export / legacy format) ─────────
	local install_dir="$config_dir/espanso-install"
	if [[ -d "$src_dir/espanso-install" ]]; then
		info "Deploying espanso-install/ → $install_dir/"
		rm -rf "$install_dir"
		mkdir -p "$install_dir"
		local inst_count=0
		while IFS= read -r -d '' f; do
			[[ "$f" == *.backup_* ]] && continue
			cp "$f" "$install_dir/"
			inst_count=$((inst_count + 1))
		done < <(find "$src_dir/espanso-install" -name '*.yml' -print0 2>/dev/null)
		ok "Deployed $inst_count espanso-install files"
	else
		# Empty placeholder so the dir structure matches the source machine
		mkdir -p "$install_dir"
	fi

	# ── conf/match/ (empty, mirrors source-machine layout) ────
	mkdir -p "$config_dir/conf/match"

	# ── config/default.yml ────────────────────────────────────
	info "Writing espanso config..."
	mkdir -p "$config_dir/config"
	if [[ -f "$src_dir/default.yml" ]]; then
		cp "$src_dir/default.yml" "$config_file"
	elif [[ -f "$src_dir/config/default.yml" ]]; then
		cp "$src_dir/config/default.yml" "$config_file"
	else
		write_default_config "$config_file"
	fi
	ok "Config → $config_file"

	# ── deployed-version.json (mirrors source machine) ────────
	if [[ -f "$src_dir/version.json" ]]; then
		cp "$src_dir/version.json" "$config_dir/deployed-version.json"
	else
		local version; version=$(http_get_text "${GITHUB_RAW}/VERSION" 2>/dev/null || echo "$(date -u +%Y%m%d%H%M%S)")
		printf '{\n  "version": "%s",\n  "source": "espanso-dist"\n}\n' "$version" > "$config_dir/deployed-version.json"
	fi

	# Record installed version
	local version="unknown"
	version=$(http_get_text "${GITHUB_RAW}/VERSION" 2>/dev/null || echo "$(date -u +%Y%m%d%H%M%S)")
	echo "$version" > "$config_dir/.trigger-pack-version"

	# Persist this installer for future self-updates
	cp "$0" "$config_dir/install.sh" 2>/dev/null || true
	chmod +x "$config_dir/install.sh" 2>/dev/null || true
}

write_default_config() {
	local config_file="$1"
	cat > "$config_file" <<'YAML'
search_shortcut: SHIFT+CTRL+E
toggle_key: RIGHT_CTRL
min_trigger_length: 1
backend: Inject
inject_delay: 0
undo_backspace: false
search_trigger: ::sea
use_standard_includes: false
extra_includes:
  - ../match/*.yml

keyboard_layout:
  layout: us
YAML
}

# ─── Start / restart espanso ────────────────────────────────────────────────
restart_espanso() {
	local esp_bin="$1"
	local os; os="$(detect_os)"
	info "Restarting espanso..."

	# Linux: prefer systemd if available
	if [[ "$os" == "linux" ]] && command -v systemctl &>/dev/null; then
		if systemctl --user is-enabled espanso.service &>/dev/null 2>&1; then
			systemctl --user restart espanso.service && { ok "Restarted via systemd"; return 0; } \
				|| warn "systemd restart failed"
		fi
	fi

	# macOS: espanso start/stop via CLI, fall back to launching the .app
	if [[ "$os" == "macos" ]]; then
		"$esp_bin" stop 2>/dev/null || true
		sleep 1
		if "$esp_bin" start 2>/dev/null; then
			ok "Started via espanso cli"; return 0
		fi
		# Fallback: launch the .app bundle directly via open
		local app_path=""
		case "$esp_bin" in
			*/Espanso.app/Contents/MacOS/espanso) app_path="${esp_bin%/Contents/MacOS/espanso}" ;;
		esac
		if [[ -n "$app_path" ]] && command -v open &>/dev/null; then
			open "$app_path" 2>/dev/null && { ok "Launched $app_path"; sleep 2; return 0; }
		fi
		warn "espanso start failed — open Espanso.app manually from /Applications/"
		return 0
	fi

	# Generic / Windows: stop + daemon
	"$esp_bin" stop 2>/dev/null || true
	sleep 0.5
	if [[ "$os" == "windows" ]]; then
		"$esp_bin" start 2>/dev/null || "$esp_bin" daemon 2>/dev/null || true
	else
		nohup "$esp_bin" daemon &>/dev/null &
	fi
	sleep 1
	"$esp_bin" status &>/dev/null && ok "Restarted via daemon" || warn "espanso may not be running — check logs"
}

verify_install() {
	local esp_bin="$1"
	info "Verifying installation..."
	local match_count=0
	if command -v python3 &>/dev/null; then
		match_count=$("$esp_bin" match list --json 2>/dev/null | python3 -c "import json,sys
try:
    d=json.load(sys.stdin); print(len(d))
except: print(0)" 2>/dev/null || echo 0)
	else
		match_count=$("$esp_bin" match list 2>/dev/null | wc -l | tr -d ' ' || echo 0)
	fi
	if [[ "$match_count" -gt 100 ]]; then
		ok "Loaded $(BOLD "$match_count") triggers"
		return 0
	else
		warn "Only $match_count triggers loaded (expected 10,000+)"
		warn "Check:  $esp_bin log"
		return 1
	fi
}

# ─── Preflight ──────────────────────────────────────────────────────────────
preflight() {
	local os arch; os="$(detect_os)"; arch="$(detect_arch)"
	step "System Detection"
	ok "OS:     $(BOLD "$os") ($(uname -s))"
	ok "Arch:   $(BOLD "$arch")"
	ok "Shell:  $(BOLD "${SHELL:-unknown}")"

	local config_dir; config_dir="$(detect_espanso_config_dir)"
	[[ -d "$config_dir" ]] && ok "Config dir: $(DIM "$config_dir")" || info "Config dir: $(DIM "$config_dir") (will be created)"

	require_http
	ok "HTTP client: $(BOLD "$(has_curl && echo curl || echo wget)")"

	# git required for clone strategy
	if command -v git &>/dev/null; then ok "git: $(BOLD "$(git --version 2>/dev/null | head -1)")"
	else warn "git not found — required to clone trigger pack. Install: apt/brew install git"; fi

	echo "$config_dir"
}

# ─── ensure espanso present (install if missing + not skipped) ──────────────
ensure_espanso() {
	local esp_bin
	if esp_bin="$(find_espanso_binary 2>/dev/null || true)"; then
		local ver; ver="$(get_espanso_version "$esp_bin")"
		ok "Espanso binary:  $(DIM "$esp_bin")"
		ok "Espanso version: $(BOLD "$ver")"
		echo "$esp_bin"
		return 0
	fi

	# espanso missing
	warn "Espanso binary: NOT FOUND"
	if [[ "${SKIP_ESPANSO_INSTALL:-0}" == "1" ]]; then
		info "Skipping espanso install (--skip-espanso-install). Config will deploy but triggers won't fire."
		return 1
	fi

	if ! ask "espanso is not installed. Attempt to install it now?" "y"; then
		info "Skipping espanso install. Config will deploy anyway."
		return 1
	fi

	step "Install espanso"
	install_espanso || { warn "espanso installation failed — continuing with config deploy only"; return 1; }

	# Re-detect after install
	if esp_bin="$(find_espanso_binary 2>/dev/null || true)"; then
		ok "Espanso now available: $(DIM "$esp_bin")"
		echo "$esp_bin"
		return 0
	fi
	warn "espanso installed but binary not on PATH yet (open a new shell). Config will deploy anyway."
	return 1
}

# ══════════════════════════════════════════════════════════════════════════════
# Commands
# ══════════════════════════════════════════════════════════════════════════════

cmd_install() {
	local force="${1:-}"
	NL
	CYAN "╔══════════════════════════════════════════════════════════╗"; CYAN "║"
	CYAN "║"; BOLD "        bhd espanso trigger-pack — installer";            CYAN "║"
	CYAN "║"; DIM "   $(detect_os) · $(detect_arch) · espanso + 15k triggers"; CYAN "║"
	CYAN "╚══════════════════════════════════════════════════════════╝"

	local config_dir; config_dir="$(preflight)"

	# 1. espanso binary
	step "Espanso Binary"
	local esp_bin=""; esp_bin="$(ensure_espanso || true)"

	# 2. Fetch dist
	step "Fetch Trigger Pack"
	local workdir="$config_dir/${CLONE_DIR_NAME}"
	[[ "$force" == "--force" && -d "$workdir" ]] && rm -rf "$workdir"
	local src_dir; src_dir="$(fetch_dist "$workdir")"

	# 3. Deploy
	step "Deploy Config"
	deploy_files "$src_dir" "$config_dir"

	# 4. Start + verify
	if [[ -n "$esp_bin" ]]; then
		step "Start espanso"
		restart_espanso "$esp_bin" || true
		step "Verify"
		verify_install "$esp_bin" || true
	else
		warn "Skipping start/verify (espanso not available). Install espanso then run: espanso start"
	fi

	# Done
	NL
	GREEN "  ═══════════════════════════════════════════════════════"; echo >&2
	GREEN "  ✔  Trigger pack installed successfully!";               echo >&2
	GREEN "  ═══════════════════════════════════════════════════════"; echo >&2
	NL
	DIM "  Config dir:  $config_dir/"
	DIM "  Match files: $config_dir/match/"
	DIM "  Config:      $config_dir/config/default.yml"
	NL
	echo "  Update later:  $config_dir/install.sh --update" >&2
	echo "  Uninstall:     $config_dir/install.sh --uninstall" >&2
	NL
}

cmd_update() {
	local force="${1:-}"
	local config_dir; config_dir="$(detect_espanso_config_dir)"
	local local_ver remote_ver
	local_ver=$( [[ -f "$config_dir/.trigger-pack-version" ]] && cat "$config_dir/.trigger-pack-version" || echo "none" )
	remote_ver=$(http_get_text "${GITHUB_RAW}/VERSION" 2>/dev/null || echo "unknown")

	NL; BLUE "  ● "; echo "Trigger pack update check"; NL
	DIM "  Local:  "; echo "$local_ver"
	DIM "  Remote: "; echo "$remote_ver"; NL

	if [[ "$local_ver" == "$remote_ver" && "$force" != "--force" ]]; then
		ok "Already up-to-date. Use --force to reinstall."; NL; exit 0
	fi
	[[ "$local_ver" == "none" ]] && { info "No existing install — running fresh install."; cmd_install "$force"; return; }

	info "Updating: $local_ver → $remote_ver"
	local workdir="$config_dir/${CLONE_DIR_NAME}"
	[[ "$force" == "--force" && -d "$workdir" ]] && rm -rf "$workdir"
	local src_dir; src_dir="$(fetch_dist "$workdir")"
	deploy_files "$src_dir" "$config_dir"

	local esp_bin
	if esp_bin="$(find_espanso_binary 2>/dev/null || true)"; then
		restart_espanso "$esp_bin" || true
		verify_install "$esp_bin" || true
	fi
	NL; ok "Updated to $remote_ver"; NL
}

cmd_version() {
	local config_dir; config_dir="$(detect_espanso_config_dir)"
	local ver; ver=$( [[ -f "$config_dir/.trigger-pack-version" ]] && cat "$config_dir/.trigger-pack-version" || echo "none" )
	echo "bhd-trigger-pack v$ver"
	echo "Source: https://github.com/${GITHUB_REPO}"
}

cmd_uninstall() {
	local config_dir; config_dir="$(detect_espanso_config_dir)"
	NL; YELLOW "  ⚠  This removes the trigger pack (keeps espanso binary):"; NL
	DIM "    $config_dir/match/"
	DIM "    $config_dir/${CLONE_DIR_NAME}/"
	DIM "    $config_dir/.trigger-pack-version"
	NL
	ask "Remove all trigger pack files?" "n" || { info "Cancelled."; NL; exit 0; }
	rm -rf "$config_dir/match" "$config_dir/${CLONE_DIR_NAME}" "$config_dir/.trigger-pack-version"
	ok "Removed trigger pack files"
	local esp_bin
	if esp_bin="$(find_espanso_binary 2>/dev/null || true)"; then
		restart_espanso "$esp_bin" 2>/dev/null || true
		ok "Restarted espanso (triggers cleared)"
	fi
	NL
}

# ─── Entry point ────────────────────────────────────────────────────────────
SKIP_ESPANSO_INSTALL=0
NON_INTERACTIVE=0
ASSUME_YES=0
COMMAND=""

# Parse all args first (so flags can appear before OR after the command,
# e.g. `--uninstall --yes` works the same as `--yes --uninstall`).
while [[ $# -gt 0 ]]; do
	case "$1" in
		--skip-espanso-install) SKIP_ESPANSO_INSTALL=1; shift ;;
		--non-interactive)      NON_INTERACTIVE=1; shift ;;
		--yes|-y)               ASSUME_YES=1; shift ;;
		--update|-u)            COMMAND="update"; shift; [[ $# -gt 0 && "$1" != -* ]] && { UPDATE_FORCE="$1"; shift; } || UPDATE_FORCE="" ;;
		--force|-f)             COMMAND="install"; INSTALL_FORCE="--force"; shift ;;
		--version|-v)           COMMAND="version"; shift ;;
		--uninstall)            COMMAND="uninstall"; shift ;;
		--help|-h)
			NL; CYAN "  bhd espanso trigger-pack installer"; NL
			echo "  Usage:"
			echo "    ./install.sh                       Interactive install (espanso + config)"
			echo "    ./install.sh --update [-f]         Pull + redeploy if newer"
			echo "    ./install.sh --force               Force reinstall everything"
			echo "    ./install.sh --version             Show installed version"
			echo "    ./install.sh --uninstall           Remove trigger pack (keeps espanso)"
			echo "    ./install.sh --skip-espanso-install  Don't try to install espanso"
			echo "    ./install.sh --non-interactive     Skip prompts (use safe defaults)"
			echo "    ./install.sh --yes [-y]            Assume yes to all prompts (CI)"
			NL
			echo "  One-liner:  curl -sL https://raw.githubusercontent.com/${GITHUB_REPO}/main/install.sh | bash"
			NL
			echo "  Env:  BHD_TRIGGER_PACK_REPO  ESPANSO_CONFIG_DIR  ESPANSO_VERSION  GITHUB_TOKEN"
			NL; exit 0 ;;
		"") shift ;;
		*) die "Unknown command: $1" "  Run with --help to see available commands" ;;
	esac
done

case "${COMMAND:-install}" in
	install)   cmd_install "${INSTALL_FORCE:-}" ;;
	update)    cmd_update "${UPDATE_FORCE:-}" ;;
	version)   cmd_version ;;
	uninstall) cmd_uninstall ;;
esac
