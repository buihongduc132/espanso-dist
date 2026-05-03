# espanso-dist

Standalone espanso trigger pack — 13,000+ word family triggers for fast typing.
Install on any machine without cloning the source espanso-config repository.

> **Source of truth**: [espanso-config](https://github.com/buihongduc132/espanso-config)
> This repo is auto-generated from `word_version_tokenized/` via `mise run espanso-dist-push`.

## Quick Install

```bash
# Public access (set GITHUB_TOKEN for private repos)
GITHUB_TOKEN=ghp_xxx curl -sL https://raw.githubusercontent.com/buihongduc132/espanso-dist/main/install.sh | bash
```

## TUI Installer

The installer runs an interactive TUI that:

- **Detects OS** (Linux / macOS / Windows) and arch automatically
- **Locates espanso** binary and config dir (XDG, Flatpak, Homebrew, AppImage, etc.)
- **Raises clear errors** with troubleshooting hints when something is wrong
- **Suggests mise task** for future automated updates

```
╔══════════════════════════════════════════════════════════╗
║            bhd-trigger-pack  Installer                  ║
║            vlinux · x86_64 · espanso triggers            ║
╚══════════════════════════════════════════════════════════╝

━━━ System Detection ━━━
  ✔ OS:     linux (Linux)
  ✔ Arch:   x86_64
  ✔ Shell:  /bin/zsh
  ✔ Espanso binary:     ~/.local/bin/espanso
  ✔ Espanso version:    espanso 2.3.0
  ✔ HTTP client:        curl
```

## Commands

| Command                          | Description                                |
| -------------------------------- | ------------------------------------------ |
| `./install.sh`                   | Interactive TUI install                    |
| `./install.sh --update`          | Check for updates, download if newer       |
| `./install.sh --force`           | Force reinstall                            |
| `./install.sh --non-interactive` | Skip all prompts, use defaults             |
| `./install.sh --version`         | Show installed version                     |
| `./install.sh --uninstall`       | Remove all trigger pack files              |
| `./install.sh --mise`            | Print mise task snippet for future updates |

## Self-Update

After initial install, the installer saves itself for future updates:

```bash
# Update from saved installer
~/.config/espanso/install.sh --update

# Non-interactive (for scripts / CI)
~/.config/espanso/install.sh --update --non-interactive
```

## Wire as mise Task (Recommended)

The installer prints a ready-to-use mise task snippet. Add this to your `mise.toml`:

```toml
[tasks.espanso-sync]
description = "Update bhd-trigger-pack from GitHub"
run = "bash ~/.config/espanso/install.sh --update --non-interactive"
```

Then: `mise run espanso-sync`

## Env Overrides

| Variable                | Description                      | Default                      |
| ----------------------- | -------------------------------- | ---------------------------- |
| `BHD_TRIGGER_PACK_REPO` | Custom GitHub repo               | `buihongduc132/espanso-dist` |
| `ESPANSO_CONFIG_DIR`    | Custom espanso config dir        | auto-detected per OS         |
| `GITHUB_TOKEN`          | GitHub token (for private repos) | none                         |

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
├── config/
│   └── default.yml          # espanso config (keyboard, includes, backend)
├── match/
│   ├── _word_families_*.yml # word family triggers
│   ├── _exx_*.yml           # super-extended family triggers
│   ├── _phrases*.yml        # phrase triggers
│   ├── _1char.yml           # single-char foundations
│   └── ...                  # 290+ match files
├── install.sh               # saved installer for self-update
└── .trigger-pack-version    # installed version
```

## License

MIT
