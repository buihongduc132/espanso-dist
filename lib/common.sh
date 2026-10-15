#!/usr/bin/env bash
# =============================================================================
# common.sh — shared library for the bhd espanso trigger-pack installers.
#
# This file is SOURCED (never executed directly) by the platform-specific
# entry scripts:
#     install-linux.sh   install-macos.sh   install-windows.sh
#
# CONTRACT: the entry script MUST define these functions BEFORE sourcing me:
#   - detect_espanso_config_dir   (echoes the platform's config dir)
#   - find_espanso_binary         (echoes the espanso binary path or returns 1)
#   - install_espanso_platform    (installs espanso for this platform; no args)
#   - restart_espanso <esp_bin>   (stop/start/restart espanso for this platform)
#
# After defining those, the entry script ends with:
#   source "$(dirname "$0")/lib/common.sh"
# which runs the arg-parse + command dispatch at the bottom of this file.
#
# The platform functions may override ESPANSO_CONFIG_DIR / use env defaults.
# =============================================================================

# Sourced libs must not trip on `set -e` for benign command failures, but we
# do want pipefail + nounset where possible. Entry scripts already set these.
set -uo pipefail

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

# NOTE: all logging goes to stderr so stdout stays clean for captured output.
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
	[[ "${ASSUME_YES:-0}" == 1 ]] && default="y"
	if [[ "$default" == "y" ]]; then yn="[Y/n]"; else yn="[y/N]"; fi
	# Non-interactive OR assume-yes: skip the read, return the default
	if [[ "${NON_INTERACTIVE:-0}" == 1 ]] || [[ "${ASSUME_YES:-0}" == 1 ]]; then
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

get_espanso_version() { local b="${1:-}"; [[ -n "$b" ]] && "$b" --version 2>/dev/null | head -1 || echo "unknown"; }

# Resolve which espanso release tag to install: ESPANSO_VERSION or latest.
resolve_espanso_tag() {
	if [[ -n "${ESPANSO_VERSION:-}" ]]; then echo "$ESPANSO_VERSION"; return 0; fi
	local tag
	tag=$(http_get_text "${ESPANSO_RELEASE_API}/latest" 2>/dev/null | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"//;s/".*//')
	[[ -n "$tag" ]] && echo "$tag" || echo "v2.3.0"
}

# ─── ensure espanso present (install if missing + not skipped) ──────────────
# NOTE: calls install_espanso_platform(), which the entry script defines.
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
	if [[ "${SKIP_ESPANSO_INSTALL:-0}" == 1 ]]; then
		info "Skipping espanso install (--skip-espanso-install). Config will deploy but triggers won't fire."
		return 1
	fi

	if ! ask "espanso is not installed. Attempt to install it now?" "y"; then
		info "Skipping espanso install. Config will deploy anyway."
		return 1
	fi

	step "Install espanso"
	install_espanso_platform || { warn "espanso installation failed — continuing with config deploy only"; return 1; }

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
		# Silence BOTH streams: git prints "HEAD is now at..." to STDOUT, which
		# would corrupt the workdir path we echo below (captured via $(...)).
		( cd "$workdir" && git fetch --depth 1 origin main >/dev/null 2>&1 && git reset --hard origin/main >/dev/null 2>&1 ) \
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
		"  The clone may be incomplete. Try:  rm -rf $(dirname "$src_dir") && ./install-$(detect_os).sh --force"
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

	# Persist this installer (the dispatcher) for future self-updates.
	# If invoked via a platform entry script, copy that too for traceability.
	cp "$ENTRY_SCRIPT" "$config_dir/install.sh" 2>/dev/null || true
	chmod +x "$config_dir/install.sh" 2>/dev/null || true
}

write_default_config() {
	local config_file="$1"
	cat > "$config_file" <<'YAML'
search_shortcut: SHIFT+CTRL+E
toggle_key: RIGHT_CTRL
min_trigger_length: 1
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
	local src_dir=""
	local script_parent
	script_parent="$(cd "$SCRIPT_DIR" && pwd)"
	if [[ -d "$script_parent/match" && -n "$(find "$script_parent/match" -name '*.yml' 2>/dev/null | head -1)" && "$force" != "--force" ]]; then
		info "Using local package directory: $script_parent"
		src_dir="$script_parent"
	else
		local workdir="$config_dir/${CLONE_DIR_NAME}"
		[[ "$force" == "--force" && -d "$workdir" ]] && rm -rf "$workdir"
		src_dir="$(fetch_dist "$workdir")"
	fi

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

# ══════════════════════════════════════════════════════════════════════════════
# Arg parsing + dispatch (runs at source-time)
# ══════════════════════════════════════════════════════════════════════════════

# Default: assume the sourcing entry script path. Entry scripts set ENTRY_SCRIPT
# before sourcing; if they didn't, fall back to $0.
: "${ENTRY_SCRIPT:=$0}"

SKIP_ESPANSO_INSTALL=0
NON_INTERACTIVE=0
ASSUME_YES=0
COMMAND=""

# Parse all args first (so flags can appear before OR after the command).
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
			NL; CYAN "  bhd espanso trigger-pack installer ($(detect_os))"; NL
			echo "  Usage:"
			echo "    $(basename "$ENTRY_SCRIPT")                       Interactive install (espanso + config)"
			echo "    $(basename "$ENTRY_SCRIPT") --update [-f]         Pull + redeploy if newer"
			echo "    $(basename "$ENTRY_SCRIPT") --force               Force reinstall everything"
			echo "    $(basename "$ENTRY_SCRIPT") --version             Show installed version"
			echo "    $(basename "$ENTRY_SCRIPT") --uninstall           Remove trigger pack (keeps espanso)"
			echo "    $(basename "$ENTRY_SCRIPT") --skip-espanso-install  Don't try to install espanso"
			echo "    $(basename "$ENTRY_SCRIPT") --non-interactive     Skip prompts (use safe defaults)"
			echo "    $(basename "$ENTRY_SCRIPT") --yes [-y]            Assume yes to all prompts (CI)"
			NL
			echo "  Platform scripts:  install-linux.sh · install-macos.sh · install-windows.sh"
			echo "  Auto-router:       install.sh   (detects OS, execs the right one)"
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
