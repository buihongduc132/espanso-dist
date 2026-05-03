# bhd-trigger-pack

Standalone espanso trigger pack — 12,000+ word family triggers for fast typing.
Install without cloning the source repository.

## Quick Install

```bash
curl -sL https://raw.githubusercontent.com/bhd/bhd-trigger-pack/main/install.sh | bash
```

## What's Included

- **12,000+ triggers** covering common words, word families, phrases, and shortcuts
- **Comma-tokenized** triggers (e.g., `exql,` → "exclude", `izt,` → "this is")
- **Pre-configured** espanso settings (Inject backend, keyboard layout, toggle key)

## Requirements

- [espanso](https://espanso.org/) v2.x installed and running
- `curl` or `wget` for downloading

## Commands

| Command                    | Description                          |
| -------------------------- | ------------------------------------ |
| `./install.sh`             | Fresh install                        |
| `./install.sh --update`    | Check for updates, download if newer |
| `./install.sh --force`     | Force reinstall                      |
| `./install.sh --version`   | Show installed version               |
| `./install.sh --uninstall` | Remove all files                     |

## Self-Update

After initial install, the installer is saved to `~/.config/espanso/install.sh`:

```bash
# Update from saved installer
~/.config/espanso/install.sh --update

# Or one-liner (always latest)
curl -sL https://raw.githubusercontent.com/bhd/bhd-trigger-pack/main/install.sh | bash -s -- --update
```

## Manual Install

```bash
# Clone and copy
git clone https://github.com/bhd/bhd-trigger-pack.git /tmp/bhd-trigger-pack
mkdir -p ~/.config/espanso/match
cp /tmp/bhd-trigger-pack/match/*.yml ~/.config/espanso/match/
mkdir -p ~/.config/espanso/config
cp /tmp/bhd-trigger-pack/default.yml ~/.config/espanso/config/default.yml
espanso restart
```

## Custom Repository

```bash
BHD_TRIGGER_PACK_REPO=yourname/your-fork ./install.sh
```

## Trigger Examples

| Trigger | Output    |
| ------- | --------- |
| `izt,`  | this is   |
| `smi,`  | something |
| `exql,` | exclude   |
| `pwj,`  | project   |
| `pwjs,` | projects  |
| `qle,`  | clear     |
| `qles,` | clears    |
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
