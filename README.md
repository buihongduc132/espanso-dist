# espanso-dist

Standalone espanso trigger pack — **15,000+ word family triggers** for fast typing, plus a one-shot installer that installs espanso itself and deploys the config on any OS.

> **Source of truth**: [espanso-config](https://github.com/buihongduc132/espanso-config)
> This repo is the published `dist/` artifact, regenerated via `mise run espanso-dist` then synced here.

## Quick Install (one command)

The installer does **everything**: installs espanso (if missing), clones this repo, deploys the config + 15k triggers, starts espanso, and verifies triggers loaded.

```bash
curl -sL https://raw.githubusercontent.com/buihongduc132/espanso-dist/main/install.sh | bash
```

For private repos / to avoid rate limits, set `GITHUB_TOKEN`:

```bash
GITHUB_TOKEN=ghp_xxx curl -sL https://raw.githubusercontent.com/buihongduc132/espanso-dist/main/install.sh | bash
```

### What the installer does (idempotent — safe to re-run)

1. **Detects OS + arch** (Linux / macOS / Windows) and routes to the matching
   platform installer (`install.sh` auto-detects and execs it).
2. **Installs espanso** if the binary is missing:
   - Linux: official install script → `.deb` → AppImage fallback
   - macOS: Homebrew → official `.zip`/`.dmg`, with `com.apple.quarantine` strip
   - Windows: official `Espanso-Win-Installer-x86_64.exe`
3. **Clones / pulls** this repo into `<config_dir>/espanso-dist-clone/`.
4. **Deploys** `match/*.yml` (flat) + `config/default.yml` to the platform's
   config dir (see [Config dirs](#config-directories-per-platform) below).
5. **Starts / restarts** espanso:
   - Linux: `systemctl --user restart espanso.service` (fallback: `nohup daemon`)
   - macOS: `espanso start`, and on the known launcher-timeout it falls back to a
     `daemon`-mode LaunchAgent (`RunAtLoad` + `KeepAlive`)
   - Windows: `espanso start` → `espanso daemon`
6. **Verifies** the trigger count loaded at runtime (`espanso match list`).

### Platform-specific installers

`install.sh` is a thin auto-detecting dispatcher. For explicit per-platform use
(or when piping `curl | bash` is not desirable), call the matching entry script
directly. All flags pass through unchanged.

| Script                | Platform | Config dir                                                        |
| --------------------- | -------- | ----------------------------------------------------------------- |
| `./install.sh`        | auto     | detects OS, execs the right one below                             |
| `./install-linux.sh`  | Linux    | `~/.config/espanso` (Flatpak sandbox path if present)             |
| `./install-macos.sh`  | macOS    | auto-detected via `espanso path`, else `~/.config/espanso`, else `~/Library/Application Support/espanso` |
| `./install-windows.sh`| Windows  | `%APPDATA%\espanso` (Git Bash / MSYS2 / Cygwin)                   |

The three entry scripts source `lib/common.sh`, which holds all the
platform-agnostic logic (clone, deploy, verify, idempotent `--update`). To
update to the latest triggers, re-run any of them with `--update` — it compares
the installed `.trigger-pack-version` against the remote `VERSION` and
re-deploys only when newer (or always, with `--force`).

```bash
# Linux explicit
curl -sL https://raw.githubusercontent.com/buihongduc132/espanso-dist/main/install-linux.sh | bash
# macOS explicit
curl -sL https://raw.githubusercontent.com/buihongduc132/espanso-dist/main/install-macos.sh | bash
```

> **Note (macOS):** the macOS installer ships fixes for the two known blockers —
> App Translocation (quarantine strip) and the `launcher` timeout (daemon-mode
> LaunchAgent fallback). See `flow/findings/2026-07-13_espanso_macos_install_blockers.md`
> in `espanso-config` for full details. After install, grant **Accessibility**
> (System Settings → Privacy & Security) to Espanso, then restart the worker
> (`pkill -f espanso` — the LaunchAgent auto-respawns it).

#### Config directories per platform

The installer writes to one canonical path per platform (overridable with
`ESPANSO_CONFIG_DIR`):

| OS      | Default config dir                                          |
| ------- | ---------------------------------------------------------- |
| Linux   | `~/.config/espanso`                                        |
| macOS   | what `espanso path` reports (auto), else `~/.config/espanso` |
| Windows | `%APPDATA%\espanso` (`~\AppData\Roaming\espanso`)          |

## Commands

| Command                                     | Description                                         |
| ------------------------------------------- | --------------------------------------------------- |
| `./install.sh`                              | Interactive install (espanso + config + verify)     |
| `./install.sh --update`                     | Pull + redeploy if a newer version exists           |
| `./install.sh --force`                      | Force full reinstall                                |
| `./install.sh --non-interactive`            | Skip all prompts, use defaults (for CI / scripts)   |
| `./install.sh --version`                    | Show installed version                              |
| `./install.sh --uninstall`                  | Remove the trigger pack (keeps the espanso binary)  |
| `./install.sh --skip-espanso-install`       | Deploy config only, don't install espanso           |
| `./install.sh --help`                       | Show help                                           |

## Self-Update

After the first install, the installer is saved to `~/.config/espanso/install.sh` for future updates:

```bash
# Interactive update
~/.config/espanso/install.sh --update

# Non-interactive (for cron / CI)
~/.config/espanso/install.sh --update --non-interactive
```

## Wire as a mise Task (optional)

Add to your `mise.toml` to keep the trigger pack in sync automatically:

```toml
[tasks.espanso-sync]
description = "Update bhd trigger-pack from GitHub"
run = "bash ~/.config/espanso/install.sh --update --non-interactive"
```

Then: `mise run espanso-sync`

## Env Overrides

| Variable                  | Description                              | Default                      |
| ------------------------- | ---------------------------------------- | ---------------------------- |
| `BHD_TRIGGER_PACK_REPO`   | Custom GitHub repo (`owner/name`)        | `buihongduc132/espanso-dist` |
| `ESPANSO_CONFIG_DIR`      | Custom espanso config dir                | auto-detected per OS         |
| `ESPANSO_VERSION`         | Pin espanso release tag (e.g. `v2.3.0`)  | latest release               |
| `GITHUB_TOKEN`            | GitHub token (private repos / rate limit)| none                         |

## Trigger Examples

| Trigger | Output    |
| ------- | --------- |
| `izt,`  | this is   |
| `smi,`  | something |
| `exql,` | exclude   |
| `pwj,`  | project   |
| `pwjs,` | projects  |
| `qle,`  | clear     |
| `qlep,` | cleared   |
| `qlei,` | clearing  |
| `hwl,`  | how long  |
| `fT,`   | if it     |

## File Structure

### This repo (espanso-dist)

```
espanso-dist/
├── install.sh                   # auto-detecting dispatcher (execs the platform script)
├── install-linux.sh             # Linux entry (sources lib/common.sh)
├── install-macos.sh             # macOS entry (sources lib/common.sh; ships macOS fixes)
├── install-windows.sh           # Windows entry (Git Bash; sources lib/common.sh)
├── lib/
│   └── common.sh                # shared library: clone, deploy, verify, --update
├── match/                       # flat tokenized .yml (deployment-ready, 340+ files)
├── espanso-install/             # iOS export / legacy format (290+ files)
├── config/
│   └── default.yml              # espanso runtime config
├── default.yml                  # same, at root (back-comat)
├── version.json                 # build metadata (git ref, timestamp, file count)
├── VERSION                      # version stamp (compared by --update)
└── MANIFEST.json                # trigger manifest
```

### Installed layout (`<config_dir>/`)

```
~/.config/espanso/               # Linux / macOS(XDG)   — Windows: %APPDATA%\espanso
├── conf/match/                  # empty (mirrors source-machine layout)
├── config/
│   └── default.yml              # espanso runtime config (keyboard, includes, backend)
├── deployed-version.json        # build metadata (version + timestamp)
├── espanso-install/             # iOS export / legacy format (290+ files)
│   └── *.yml
├── match/
│   ├── _word_families_*.yml     # word family triggers
│   ├── _exx_*.yml               # super-extended family triggers
│   ├── _phrases*.yml            # phrase triggers
│   ├── _1char.yml               # single-char foundations
│   ├── packages/                # empty (mirrors source-machine layout)
│   └── ...                      # 340+ match files, 15,000+ triggers
├── espanso-dist-clone/          # cached clone of this repo (for --update)
├── install.sh                   # saved installer for self-update
└── .trigger-pack-version        # installed version stamp
```


## License

MIT
