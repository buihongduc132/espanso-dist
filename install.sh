#!/usr/bin/env bash
# =============================================================================
# install.sh — TUI Installer for bhd-trigger-pack
#
# Usage:
#   curl -sL https://raw.githubusercontent.com/bhd/espanso-dist/main/install.sh | bash
#   ./install.sh                  # interactive install (TUI)
#   ./install.sh --update         # check + update if newer
#   ./install.sh --force          # force reinstall
#   ./install.sh --version        # show installed version
#   ./install.sh --uninstall      # remove all files
#   ./install.sh --mise           # print mise task snippet for future updates
#   ./install.sh --non-interactive # skip TUI, use all defaults
#
# Env:
#   BHD_TRIGGER_PACK_REPO   Override GitHub repo (default: bhd/espanso-dist)
#   ESPANSO_CONFIG_DIR       Override espanso config dir (auto-detected)
# =============================================================================
set -euo pipefail

# ─── Configuration ──────────────────────────────────────────────────────────
GITHUB_REPO="${BHD_TRIGGER_PACK_REPO:-buihongduc132/espanso-dist}"
GITHUB_RAW="https://raw.githubusercontent.com/${GITHUB_REPO}/main"
GITHUB_API="https://api.github.com/repos/${GITHUB_REPO}"
LOCAL_INSTALL_SH="" # set after we know config dir

# ─── TUI Colors & Helpers ──────────────────────────────────────────────────
# Detect terminal color support
if [[ -t 1 ]] && command -v tput &>/dev/null && [[ $(tput colors 2>/dev/null || echo 0) -ge 8 ]]; then
	HAS_COLOR=1
else
	HAS_COLOR=0
fi

C() { [[ "$HAS_COLOR" == 1 ]] && echo -en "$1" || true; }
R() { C '\033[0m'; } # reset
RED() {
	C '\033[0;31m'
	echo -n "$*"
	R
}
GREEN() {
	C '\033[0;32m'
	echo -n "$*"
	R
}
YELLOW() {
	C '\033[1;33m'
	echo -n "$*"
	R
}
BLUE() {
	C '\033[0;34m'
	echo -n "$*"
	R
}
CYAN() {
	C '\033[0;36m'
	echo -n "$*"
	R
}
DIM() {
	C '\033[2m'
	echo -n "$*"
	R
}
BOLD() {
	C '\033[1m'
	echo -n "$*"
	R
}

NL() { echo ""; }

# Logging with TUI flavor
info() {
	BLUE "  ● "
	echo "$*"
}
ok() {
	GREEN "  ✔ "
	echo "$*"
}
warn() {
	YELLOW "  ⚠ "
	echo "$*"
}
err() {
	RED "  ✘ "
	echo "$*"
	NL
}

# Die with troubleshooting hint
die() {
	NL
	RED "  ✘ ERROR: "
	echo "$1"
	NL
	if [[ -n "${2:-}" ]]; then
		YELLOW "  💡 Troubleshooting:"
		NL
		echo "$2"
	fi
	NL
	exit 1
}

# Step header
step() {
	NL
	CYAN "━━━ "
	BOLD "$1"
	CYAN " ━━━"
	NL
}

# Progress spinner (simple dots)
progress() {
	local msg="$1" cmd="$2"
	BLUE "  ◌ "
	echo -n "$msg"
	local output
	if output=$("$cmd" 2>&1); then
		C '\r'
		GREEN "  ✔ "
		echo "$msg"
		return 0
	else
		C '\r'
		RED "  ✘ "
		echo "$msg"
		echo "    $output" | head -5
		return 1
	fi
}

# Ask user (returns 0 for yes, 1 for no)
ask() {
	local prompt="${1:-Continue?}"
	local default="${2:-y}"
	local yn
	if [[ "$default" == "y" ]]; then
		yn="[Y/n]"
	else
		yn="[y/N]"
	fi
	echo -n "  ? $prompt $yn "
	if [[ "${NON_INTERACTIVE:-0}" == "1" ]]; then
		echo "$default"
		[[ "$default" == "y" ]]
		return
	fi
	read -r answer
	case "$answer" in
	y | Y | yes | YES) return 0 ;;
	n | N | no | NO) return 1 ;;
	*) [[ "$default" == "y" ]] && return 0 || return 1 ;;
	esac
}

# ─── OS Detection ──────────────────────────────────────────────────────────
detect_os() {
	local uname_s
	uname_s="$(uname -s)"
	case "$uname_s" in
	Linux*) echo "linux" ;;
	Darwin*) echo "macos" ;;
	MINGW* | MSYS* | CYGWIN*) echo "windows" ;;
	*) echo "unknown:$uname_s" ;;
	esac
}

detect_arch() {
	local uname_m
	uname_m="$(uname -m)"
	case "$uname_m" in
	x86_64 | amd64) echo "x86_64" ;;
	aarch64 | arm64) echo "arm64" ;;
	*) echo "$uname_m" ;;
	esac
}

# ─── Espanso Location Detection ────────────────────────────────────────────
detect_espanso_config_dir() {
	# 1. Explicit override
	if [[ -n "${ESPANSO_CONFIG_DIR:-}" ]]; then
		if [[ -d "$ESPANSO_CONFIG_DIR" ]]; then
			echo "$ESPANSO_CONFIG_DIR"
			return 0
		fi
		# Return it anyway — we'll validate later
		echo "$ESPANSO_CONFIG_DIR"
		return 0
	fi

	local os
	os="$(detect_os)"

	case "$os" in
	linux)
		# Standard XDG
		if [[ -d "$HOME/.config/espanso" ]]; then
			echo "$HOME/.config/espanso"
			return 0
		fi
		# Flatpak
		if [[ -d "$HOME/.var/app/com.mtxc.espanso/config/espanso" ]]; then
			echo "$HOME/.var/app/com.mtxc.espanso/config/espanso"
			return 0
		fi
		echo "$HOME/.config/espanso"
		;;
	macos)
		if [[ -d "$HOME/Library/Application Support/espanso" ]]; then
			echo "$HOME/Library/Application Support/espanso"
			return 0
		fi
		echo "$HOME/Library/Application Support/espanso"
		;;
	windows)
		local appdata="${APPDATA:-$HOME/AppData/Roaming}"
		if [[ -d "$appdata/espanso" ]]; then
			echo "$appdata/espanso"
			return 0
		fi
		echo "$appdata/espanso"
		;;
	*)
		echo "$HOME/.config/espanso"
		;;
	esac
}

find_espanso_binary() {
	local os arch paths candidate
	os="$(detect_os)"
	arch="$(detect_arch)"

	# OS-specific paths
	case "$os" in
	linux)
		paths=(
			"$HOME/Applications/espanso/usr/bin/espanso"
			"$HOME/.local/bin/espanso"
			"/usr/bin/espanso"
			"/usr/local/bin/espanso"
			"/snap/bin/espanso"
		)
		# Flatpak
		if [[ -x "/usr/bin/flatpak" ]]; then
			local fp_location
			fp_location=$(flatpak list --columns=app 2>/dev/null | grep -i espanso | head -1 | xargs -I{} flatpak info --show-location {} 2>/dev/null) || true
			[[ -n "$fp_location" ]] && paths+=("$fp_location/bin/espanso")
		fi
		;;
	macos)
		paths=(
			"$HOME/Applications/espanso/usr/bin/espanso"
			"/Applications/espanso/usr/bin/espanso"
			"$HOME/.local/bin/espanso"
			"/usr/local/bin/espanso"
			"$(brew --prefix 2>/dev/null || echo /opt/homebrew)/bin/espanso"
		)
		;;
	windows)
		local localbin="${LOCALAPPDATA:-$HOME/AppData/Local}"
		paths=(
			"$localbin/Programs/espanso/espanso.exe"
			"$localbin/Programs/Espanso/espanso.exe"
			"$HOME/.local/bin/espanso.exe"
		)
		;;
	*)
		paths=()
		;;
	esac

	# Check PATH
	if command -v espanso &>/dev/null; then
		echo "$(command -v espanso)"
		return 0
	fi

	# Check known paths
	for candidate in "${paths[@]}"; do
		if [[ -x "$candidate" ]]; then
			echo "$candidate"
			return 0
		fi
	done

	return 1
}

get_espanso_version() {
	local bin="$1"
	"$bin" --version 2>/dev/null | head -1 || echo "unknown"
}

# ─── Download Helpers ──────────────────────────────────────────────────────
has_curl() { command -v curl &>/dev/null; }
has_wget() { command -v wget &>/dev/null; }

http_get() {
	local url="$1" output="$2"
	if has_curl; then
		curl -fsSL "$url" -o "$output"
	elif has_wget; then
		wget -q "$url" -O "$output"
	else
		die "No HTTP client found" \
			"  Install curl:  sudo apt install curl     (Debian/Ubuntu)\n  Install curl:  sudo dnf install curl     (Fedora)\n  Install curl:  brew install curl            (macOS)"
	fi
}

http_get_text() {
	local url="$1"
	if has_curl; then
		curl -fsSL "$url" 2>/dev/null
	elif has_wget; then
		wget -qO- "$url" 2>/dev/null
	else
		return 1
	fi
}

get_remote_version() {
	local ver
	ver=$(http_get_text "${GITHUB_RAW}/VERSION" 2>/dev/null) && [[ -n "$ver" ]] && {
		echo "$ver"
		return 0
	}
	ver=$(http_get_text "${GITHUB_API}/releases/latest" 2>/dev/null | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"//;s/".*//') && [[ -n "$ver" ]] && {
		echo "$ver"
		return 0
	}
	echo "unknown"
}

get_local_version() {
	local config_dir="$1"
	local vf="$config_dir/.trigger-pack-version"
	if [[ -f "$vf" ]]; then cat "$vf"; else echo "none"; fi
}

# ─── Download Release ──────────────────────────────────────────────────────
download_pack() {
	local dest_dir="$1"
	local tmpdir
	tmpdir="$(mktemp -d)"
	trap "rm -rf '$tmpdir'" RETURN

	# Try release tarball first
	local download_url
	download_url=$(http_get_text "${GITHUB_API}/releases/latest" 2>/dev/null | grep '"browser_download_url"' | grep '\.tar\.gz' | head -1 | sed 's/.*"browser_download_url": *"//;s/".*//' || true)

	if [[ -n "$download_url" ]]; then
		info "Downloading release tarball..."
		http_get "$download_url" "$tmpdir/pack.tar.gz"
		tar -xzf "$tmpdir/pack.tar.gz" -C "$tmpdir"
	else
		# Fallback: individual files from main branch
		info "Downloading from main branch..."
		download_individual_files "$tmpdir"
	fi

	# Validate
	if [[ ! -d "$tmpdir/match" ]] && [[ ! -f "$tmpdir/default.yml" ]]; then
		die "Download produced no match files" \
			"  1. Check the repo exists:  https://github.com/${GITHUB_REPO}\n  2. Check your network / proxy settings\n  3. Try with explicit repo:\n       BHD_TRIGGER_PACK_REPO=owner/repo ./install.sh"
	fi

	# If match/ is missing but .yml files are at root, move them
	if [[ ! -d "$tmpdir/match" ]] && ls "$tmpdir"/*.yml &>/dev/null 2>&1; then
		mkdir -p "$tmpdir/match"
		mv "$tmpdir"/*.yml "$tmpdir/match/"
	fi

	echo "$tmpdir"
}

download_individual_files() {
	local tmpdir="$1"
	local match_dir="$tmpdir/match"
	mkdir -p "$match_dir"

	# Get file tree from GitHub API
	local files
	files=$(http_get_text "${GITHUB_API}/git/trees/main?recursive=1" 2>/dev/null | grep -o '"path": "match/[^"]*\.yml"' | sed 's/"path": "//;s/"//' || true)

	if [[ -n "$files" ]]; then
		local count=0 total
		total=$(echo "$files" | wc -l | tr -d ' ')
		while IFS= read -r f; do
			[[ -z "$f" ]] && continue
			count=$((count + 1))
			# Progress every 50 files
			if [[ $((count % 50)) -eq 0 ]]; then
				C '\r'
				BLUE "  ◌ "
				echo -n "Downloading $count/$total files..."
			fi
			http_get "${GITHUB_RAW}/$f" "$tmpdir/$f"
		done <<<"$files"
		C '\r'
		ok "Downloaded $count match files"
	else
		# Last resort: parse _index.yml
		local index
		index=$(http_get_text "${GITHUB_RAW}/match/_index.yml" 2>/dev/null || true)
		if [[ -n "$index" ]]; then
			local imports
			imports=$(echo "$index" | grep -oP '[\w/]+\.yml' | sort -u || true)
			local count=0
			while IFS= read -r f; do
				[[ -z "$f" ]] && continue
				http_get "${GITHUB_RAW}/match/$f" "$match_dir/$f"
				count=$((count + 1))
			done <<<"$imports"
			ok "Downloaded $count match files from index"
		else
			die "Cannot fetch file list from GitHub" \
				"  1. Verify repo is public or you have access: ${GITHUB_REPO}\n  2. Check GitHub API rate limit:  https://api.github.com/rate_limit\n  3. If private repo, set GITHUB_TOKEN env var"
		fi
	fi

	# Download config
	http_get "${GITHUB_RAW}/default.yml" "$tmpdir/default.yml"
}

# ─── Deploy ────────────────────────────────────────────────────────────────
deploy_files() {
	local src_dir="$1" config_dir="$2"
	local match_dir="$config_dir/match"
	local config_file="$config_dir/config/default.yml"

	# Deploy match files (flat — merge subdirectories)
	info "Deploying match files to $match_dir/ ..."
	rm -rf "$match_dir"
	mkdir -p "$match_dir"

	local deployed=0
	while IFS= read -r -d '' f; do
		[[ "$f" == *.backup_* ]] && continue
		cp "$f" "$match_dir/"
		deployed=$((deployed + 1))
	done < <(find "$src_dir/match" -name '*.yml' -print0 2>/dev/null)

	if [[ $deployed -eq 0 ]]; then
		die "No .yml files found in downloaded match/" \
			"  The download may have failed silently.\n  Try:  rm -rf /tmp/espanso-install-* && ./install.sh --force"
	fi
	ok "Deployed $deployed match files"

	# Deploy config
	info "Writing espanso config..."
	mkdir -p "$config_dir/config"
	if [[ -f "$src_dir/default.yml" ]]; then
		cp "$src_dir/default.yml" "$config_file"
	else
		write_default_config "$config_file"
	fi
	ok "Config → $config_file"

	# Save version
	local version
	version="$(get_remote_version)"
	echo "$version" >"$config_dir/.trigger-pack-version"
	ok "Version: $version"

	# Save installer for self-update
	cp "$0" "$config_dir/install.sh"
	chmod +x "$config_dir/install.sh"
	LOCAL_INSTALL_SH="$config_dir/install.sh"
}

write_default_config() {
	local config_file="$1"
	cat >"$config_file" <<'YAML'
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

# ─── Restart & Verify ─────────────────────────────────────────────────────
restart_espanso() {
	local esp_bin="$1"
	local os
	os="$(detect_os)"

	info "Restarting espanso..."

	if [[ "$os" == "linux" ]] && systemctl --user is-enabled espanso.service &>/dev/null 2>&1; then
		systemctl --user restart espanso.service
		sleep 1
		if systemctl --user is-active espanso.service &>/dev/null; then
			ok "Restarted via systemd"
			return 0
		fi
		# systemd failed — try manual
		warn "systemd restart failed, trying manual restart..."
	fi

	if [[ "$os" == "macos" ]]; then
		# macOS: use espanso cli or launchctl
		"$esp_bin" restart 2>/dev/null && {
			ok "Restarted via espanso cli"
			return 0
		}
		warn "espanso restart failed — may need manual restart"
		return 0
	fi

	# Generic: stop + daemon
	"$esp_bin" stop 2>/dev/null || true
	sleep 0.5
	nohup "$esp_bin" daemon &>/dev/null
	sleep 1

	if "$esp_bin" status &>/dev/null 2>&1; then
		ok "Restarted via daemon"
	else
		warn "espanso may not be running — check manually"
	fi
}

verify_install() {
	local esp_bin="$1"
	info "Verifying installation..."

	local match_count=0
	if command -v python3 &>/dev/null; then
		match_count=$("$esp_bin" match list --json 2>/dev/null | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(len(d))
except:
    print(0)
" 2>/dev/null || echo "0")
	else
		# Fallback: count lines
		match_count=$("$esp_bin" match list 2>/dev/null | wc -l | tr -d ' ' || echo "0")
	fi

	if [[ "$match_count" -gt 100 ]]; then
		ok "Loaded $(BOLD "$match_count") triggers"
		return 0
	else
		warn "Only $match_count triggers loaded (expected 10,000+)"
		return 1
	fi
}

# ─── Mise Task Suggestion ──────────────────────────────────────────────────
suggest_mise_task() {
	local config_dir="$1"
	local install_sh="$config_dir/install.sh"
	local mise_path
	mise_path="$(command -v mise 2>/dev/null || echo "")"

	NL
	CYAN "━━━ "
	BOLD "mise Integration"
	CYAN " ━━━"
	NL

	if [[ -n "$mise_path" ]]; then
		ok "mise detected at $mise_path"
	else
		DIM "  (mise not found — install from https://mise.jdx.dev/)"
	fi
	NL

	echo '  Add to your mise.toml (usually ~/.config/mise/config.toml or project root):'
	NL
	DIM '  ─────────────────────────────────────────────'
	echo '  [tasks.espanso-sync]'
	echo '  description = "Update bhd-trigger-pack from GitHub"'
	echo '  run = "bash '"$install_sh"' --update --non-interactive"'
	DIM '  ─────────────────────────────────────────────'
	NL
	echo '  Then run:  mise run espanso-sync'
	NL
}

# ─── Pre-flight Checks ─────────────────────────────────────────────────────
preflight() {
	local os arch
	os="$(detect_os)"
	arch="$(detect_arch)"

	step "System Detection"
	ok "OS:     $(BOLD "$os") ($(uname -s))"
	ok "Arch:   $(BOLD "$arch")"
	ok "Shell:  $(BOLD "${SHELL:-unknown}")"

	local config_dir
	config_dir="$(detect_espanso_config_dir)"

	if [[ -d "$config_dir" ]]; then
		ok "Espanso config dir: $(DIM "$config_dir")"
	else
		info "Espanso config dir: $(DIM "$config_dir") $(DIM "(will be created)")"
	fi

	local esp_bin=""
	if esp_bin="$(find_espanso_binary)"; then
		local esp_ver
		esp_ver="$(get_espanso_version "$esp_bin")"
		ok "Espanso binary:     $(DIM "$esp_bin")"
		ok "Espanso version:    $(BOLD "$esp_ver")"
	else
		warn "Espanso binary:    NOT FOUND"
	fi

	local has_http="no"
	has_curl && has_http="curl" || { has_wget && has_http="wget" || true; }
	if [[ "$has_http" != "no" ]]; then
		ok "HTTP client:        $(BOLD "$has_http")"
	else
		warn "HTTP client:       NOT FOUND"
	fi

	# Warn if issues found
	if [[ -z "$esp_bin" ]]; then
		NL
		YELLOW "  ┌──────────────────────────────────────────────────────────┐"
		YELLOW "  │  espanso is NOT installed on this system.               │"
		YELLOW "  │  The trigger files will still be deployed, but          │"
		YELLOW "  │  espanso must be installed separately to use them.      │"
		YELLOW "  └──────────────────────────────────────────────────────────┘"
		NL

		local install_hint=""
		case "$os" in
		linux)
			install_hint="  sudo apt install espanso         # Debian/Ubuntu\n  sudo dnf install espanso         # Fedora\n  Or download AppImage:\n  https://github.com/espanso/espanso/releases"
			;;
		macos)
			install_hint="  brew install espanso\n  Or download from:\n  https://github.com/espanso/espanso/releases"
			;;
		windows)
			install_hint="  scoop install espanso\n  Or:\n  winget install espanso\n  Or download from:\n  https://github.com/espanso/espanso/releases"
			;;
		esac

		YELLOW "  💡 Install espanso:"
		NL
		echo -e "$install_hint"
		NL

		if ! ask "Continue installing trigger files anyway?" "n"; then
			NL
			info "Cancelled. Install espanso first, then re-run this script."
			NL
			exit 0
		fi
	fi

	if [[ "$has_http" == "no" ]]; then
		die "No HTTP client (curl/wget) available" \
			"  Install curl:\n  sudo apt install curl   (Debian/Ubuntu)\n  sudo dnf install curl   (Fedora)\n  brew install curl          (macOS)"
	fi

	echo "$config_dir"
}

# ─── Main Commands ──────────────────────────────────────────────────────────

cmd_install() {
	NL
	CYAN "╔══════════════════════════════════════════════════════════╗"
	CYAN "║            bhd-trigger-pack  Installer                  ║"
	CYAN "║            v$(detect_os) · $(detect_arch) · espanso triggers            ║"
	CYAN "╚══════════════════════════════════════════════════════════╝"

	# Pre-flight
	local config_dir
	config_dir="$(preflight)"

	# Download
	step "Download"
	local tmpdir
	tmpdir="$(download_pack)"

	# Deploy
	step "Deploy"
	deploy_files "$tmpdir" "$config_dir"

	# Restart (if espanso found)
	local esp_bin
	if esp_bin="$(find_espanso_binary 2>/dev/null || true)"; then
		step "Restart espanso"
		restart_espanso "$esp_bin"
	fi

	# Verify
	if [[ -n "${esp_bin:-}" ]]; then
		step "Verify"
		verify_install "$esp_bin" || true
	fi

	# Mise suggestion
	suggest_mise_task "$config_dir"

	# Done
	NL
	GREEN "  ═══════════════════════════════════════════════════════"
	GREEN "  ✔  bhd-trigger-pack installed successfully!"
	GREEN "  ═══════════════════════════════════════════════════════"
	NL
	DIM "  Trigger files:  $config_dir/match/  ($deployed files)"
	DIM "  Espanso config: $config_dir/config/default.yml"
	NL
	echo "  Update later:   $config_dir/install.sh --update"
	echo "  Uninstall:      $config_dir/install.sh --uninstall"
	echo "  Mise task:      see snippet above"
	NL
}

cmd_update() {
	local force="${1:-}"
	local config_dir
	config_dir="$(detect_espanso_config_dir)"

	local local_ver remote_ver
	local_ver="$(get_local_version "$config_dir")"
	remote_ver="$(get_remote_version)"

	NL
	BLUE "  ● "
	echo "bhd-trigger-pack update check"
	NL
	DIM "  Local:  "
	echo "$local_ver"
	DIM "  Remote: "
	echo "$remote_ver"
	NL

	if [[ "$local_ver" == "$remote_ver" ]] && [[ "$force" != "--force" ]]; then
		ok "Already up-to-date. Use --force to reinstall."
		NL
		exit 0
	fi

	if [[ "$local_ver" == "none" ]]; then
		info "No existing installation found. Running fresh install..."
		cmd_install
		return
	fi

	info "Updating: $local_ver → $remote_ver"

	# Download + deploy
	local tmpdir
	tmpdir="$(download_pack)"
	deploy_files "$tmpdir" "$config_dir"

	# Restart if possible
	local esp_bin
	if esp_bin="$(find_espanso_binary 2>/dev/null || true)"; then
		restart_espanso "$esp_bin"
		verify_install "$esp_bin" || true
	fi

	NL
	ok "Updated to $remote_ver"
	NL
}

cmd_version() {
	local config_dir
	config_dir="$(detect_espanso_config_dir)"
	local ver
	ver="$(get_local_version "$config_dir")"
	echo "bhd-trigger-pack v$ver"
	echo "Source: https://github.com/${GITHUB_REPO}"
}

cmd_uninstall() {
	local config_dir
	config_dir="$(detect_espanso_config_dir)"
	local match_dir="$config_dir/match"
	local config_file="$config_dir/config/default.yml"
	local version_file="$config_dir/.trigger-pack-version"
	local install_sh="$config_dir/install.sh"

	NL
	YELLOW "  ⚠  This will remove all bhd-trigger-pack files:"
	NL
	DIM "    $match_dir/"
	DIM "    $config_file"
	DIM "    $version_file"
	DIM "    $install_sh"
	NL

	if ! ask "Remove all trigger pack files?" "n"; then
		info "Cancelled."
		NL
		exit 0
	fi

	rm -rf "$match_dir"
	rm -f "$config_file"
	rm -f "$version_file"
	rm -f "$install_sh"

	ok "Removed all files"

	local esp_bin
	if esp_bin="$(find_espanso_binary 2>/dev/null || true)"; then
		restart_espanso "$esp_bin" 2>/dev/null || true
		ok "Restarted espanso (triggers cleared)"
	fi
	NL
}

cmd_mise() {
	local config_dir
	config_dir="${1:-$(detect_espanso_config_dir)}"
	suggest_mise_task "$config_dir"
}

# ─── Entry Point ────────────────────────────────────────────────────────────
case "${1:-}" in
--update | -u)
	cmd_update "${2:-}"
	;;
--force | -f)
	cmd_update "--force"
	;;
--version | -v)
	cmd_version
	;;
--uninstall)
	cmd_uninstall
	;;
--mise)
	cmd_mise "${2:-}"
	;;
--non-interactive)
	NON_INTERACTIVE=1
	shift
	case "${1:-}" in
	--update | -u) cmd_update "${2:-}" ;;
	--force | -f) cmd_update "--force" ;;
	"") cmd_install ;;
	*) die "Unknown command with --non-interactive: $1" ;;
	esac
	;;
--help | -h)
	NL
	CYAN "  bhd-trigger-pack Installer"
	NL
	echo "  Usage:"
	echo "    ./install.sh                  Interactive install (TUI)"
	echo "    ./install.sh --update         Update if newer version available"
	echo "    ./install.sh --force           Force reinstall"
	echo "    ./install.sh --version         Show installed version"
	echo "    ./install.sh --uninstall       Remove all files"
	echo "    ./install.sh --mise            Show mise task snippet"
	echo "    ./install.sh --non-interactive Skip all prompts (use defaults)"
	NL
	echo "  One-liner install:"
	echo "    curl -sL ${GITHUB_RAW}/install.sh | bash"
	NL
	echo "  Env overrides:"
	echo "    BHD_TRIGGER_PACK_REPO=owner/repo  Custom GitHub repo"
	echo "    ESPANSO_CONFIG_DIR=/path          Custom espanso config dir"
	echo "    GITHUB_TOKEN=ghp_xxx              For private repos"
	NL
	;;
"")
	cmd_install
	;;
*)
	die "Unknown command: $1" \
		"  Run with --help to see available commands"
	;;
esac
