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

1. **Detects OS + arch** (Linux / macOS / Windows) and the espanso config dir.
2. **Installs espanso** if the binary is missing:
   - Linux: official install script → `.deb` → AppImage fallback
   - macOS: Homebrew → official `.zip`
   - Windows: official `Espanso-Win-Installer-x86_64.exe`
3. **Clones / pulls** this repo into `~/.config/espanso/espanso-dist-clone/`.
4. **Deploys** `match/*.yml` (flat) + `config/default.yml`.
5. **Starts / restarts** espanso (systemd on Linux, CLI on macOS/Windows).
6. **Verifies** the trigger count loaded at runtime.

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

```
~/.config/espanso/
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

## OS-Specific Paths

| OS      | Config directory                                          |
| ------- | -------------------------------------------------------- |
| Linux   | `~/.config/espanso/`                                      |
| macOS   | `~/Library/Application Support/espanso/`                  |
| Windows | `%APPDATA%\espanso\` (i.e. `~\AppData\Roaming\espanso\`) |


## License

MIT
