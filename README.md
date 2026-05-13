# SlashX Media Suite Launcher

**Cross-platform unified launcher for AV-Encoder-Suite & Photo-Encoder-Suite — Termux (Android), Linux, macOS and Windows**

> Single-entry-point menu launcher that installs, updates and runs both encoder suites from one place. Auto-detects OS, manages git clones, and provides quick access to launchers, tools and tests — v4.1.1

---

## Features

- **One launcher for both suites**: AV-Encoder-Suite (video) and Photo-Encoder-Suite (photo)
- **Cross-platform**: bash for Termux/Linux/macOS, PowerShell 5.1+ for Windows
- **Git management built-in**: install or update both suites with a single keystroke (`git pull --ff-only` with conflict detection)
- **Repo status panel**: branch, last commit, local changes, ahead/behind tracking — at a glance
- **Auto-detection**: Termux / Linux distro / macOS / Windows / Git Bash / MSYS2 / Cygwin
- **Mapped tools & tests submenu**: aggregates all `.sh` / `.ps1` scripts from `tools/` and `tests/` of both suites into one navigable menu
- **Safe subprocess isolation**: child scripts run in subshells (bash) or isolated `pwsh -NoProfile` processes (PowerShell) — `exit` / `cd` / env mutations in child scripts cannot poison the launcher
- **TTY-aware output**: ANSI colors and `clear` are auto-suppressed when stdout is redirected (pipe-safe)
- **UTF-8 console**: PowerShell forces UTF-8 console encoding to fix box-drawing chars and diacritics on Windows
- **Signal-safe**: SIGINT (Ctrl+C) trap on bash, try/finally on PowerShell — clean exit with no terminal corruption
- **CLI flags**: `--help` / `--version` on both variants
- **Debug mode**: `SLASHX_DEBUG=1` environment flag for verbose logging

---

## Platforms

| Platform | Script | Requirements |
|----------|--------|--------------|
| **Termux (Android)** | `slashx_launcher.sh` | bash 4+, git |
| **Linux** | `slashx_launcher.sh` | bash 4+, git |
| **macOS** | `slashx_launcher.sh` | `brew install bash git` |
| **Windows** | `slashx_launcher.ps1` | PowerShell 5.1+ or PowerShell 7+, git |

---

## Project Structure

```
Media-Suite-Launcher/
├── src/
│   ├── slashx_launcher.sh        # Bash launcher (Termux/Linux/macOS)
│   └── slashx_launcher.ps1       # PowerShell launcher (Windows)
├── docs/
│   ├── launcher_info.txt         # Full setup & usage documentation
│   └── launcher_changelog.txt    # Version history
├── AV-Encoder-Suite/             # Cloned by [5] — gitignored
├── Photo-Encoder-Suite/          # Cloned by [5] — gitignored
├── .gitignore
├── LICENSE
└── README.md
```

The launcher lives in `src/` but **clones AV/Photo one level up** (in the repo root). This keeps the launcher's own git history clean while letting both suites coexist as siblings.

---

## Requirements

### Termux (Android)

```bash
pkg update -y
pkg install git bash -y
```

### Linux (Debian / Ubuntu / Fedora / Arch)

```bash
# Debian / Ubuntu
sudo apt install bash git

# Fedora
sudo dnf install bash git

# Arch Linux
sudo pacman -S bash git
```

### macOS

```bash
# Required: bash 4+ (Apple ships bash 3.2)
brew install bash git
```

### Windows

- **PowerShell 5.1+** (included in Windows 10/11) or **PowerShell 7+**
- **Git** — `winget install Git.Git` or download from [git-scm.com](https://git-scm.com)

---

## Quick Start

### Step 1: Clone this launcher

```bash
git clone https://github.com/SlashX/Media-Suite-Launcher.git
cd Media-Suite-Launcher
```

### Step 2 (Termux / Linux / macOS): Set permissions and run

```bash
chmod +x src/slashx_launcher.sh
./src/slashx_launcher.sh
```

### Step 2 (Windows): Run

```powershell
# Allow script execution (run once)
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned

.\src\slashx_launcher.ps1
```

### Step 3: Install AV and Photo suites

From the main menu, press **[5] Install / Update Suite (Git)** — both suites will be cloned next to the launcher (as siblings of `src/`).

### Step 4: Use them

- **[1]** Launch AV-Encoder-Suite (video conversion)
- **[2]** Launch Photo-Encoder-Suite (photo conversion)
- **[3]** Run any tool from `tools/` of either suite
- **[4]** Run any test from `tests/` of either suite
- **[5]** Re-run install/update at any time
- **[6]** Check repo status (branch, commits, modifications)

---

## Menu Options

| Option | Description |
|--------|-------------|
| 1 | Video Processing — runs AV-Encoder-Suite launcher |
| 2 | Photo Processing — runs Photo-Encoder-Suite launcher |
| 3 | Tools & Updaters (Mapped) — aggregated submenu of all `tools/*.sh` (or `.ps1`) |
| 4 | Tests & Diagnostics (Mapped) — aggregated submenu of all `tests/*.sh` (or `.ps1`) |
| 5 | Install / Update Suite (Git) — clones if missing, `git pull --ff-only` if present |
| 6 | Repo Status — branch, last commit, local changes, ahead/behind |
| 0 | Exit |

---

## CLI Flags

```bash
./src/slashx_launcher.sh --help        # show usage
./src/slashx_launcher.sh --version     # show version

# Equivalent
./src/slashx_launcher.sh -h
./src/slashx_launcher.sh -v
./src/slashx_launcher.sh help
./src/slashx_launcher.sh version
```

```powershell
.\src\slashx_launcher.ps1 -Help
.\src\slashx_launcher.ps1 -Version
```

---

## Debug Mode

Enable verbose logging via environment variable:

```bash
# Termux / Linux / macOS
SLASHX_DEBUG=1 ./src/slashx_launcher.sh

# Windows PowerShell
$env:SLASHX_DEBUG = '1'
.\src\slashx_launcher.ps1
```

When enabled, the menu shows `Debug : ON` and child script invocations log their target path and CWD.

---

## How It Works

### Path Resolution

The launcher resolves two key directories at start:

- `SCRIPT_DIR` — where the launcher itself lives (`Media-Suite-Launcher/src/`)
- `BASE_DIR` — one level up (`Media-Suite-Launcher/`), where AV/Photo are cloned

This separation keeps the launcher repo clean (only `src/`, `docs/`, README, etc. are versioned) while letting both encoder suites live as sibling folders.

### Subprocess Isolation

When you launch a sub-script (option 1, 2, 3 or 4), the launcher runs it in an isolated context:

- **Bash**: `( cd "$BASE_DIR/$root" || exit 1; bash "$target" )` — subshell isolates `cd`, `exit` and exported variables
- **PowerShell**: `& $psExe -NoProfile -ExecutionPolicy Bypass -File $ScriptPath` — runs in a new process

This means a sub-script cannot accidentally exit the launcher, change its CWD, or leak environment variables back.

### Git Operations

- **First run of [5]**: `git clone` for each suite
- **Subsequent runs of [5]**: `git pull --ff-only` (refuses merge if there are local commits, prevents accidental merges)
- **Option [6]** runs `git fetch --quiet` (silent, best-effort) plus `git rev-list --left-right --count` to show ahead/behind status

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `git: command not found` | Install git: see Requirements above |
| `Permission denied` on `.sh` | `chmod +x src/slashx_launcher.sh` |
| Box-drawing chars or diacritics broken on Windows CMD | The PS1 forces UTF-8 console encoding automatically. If you still see garbled output, ensure you're using PowerShell (not legacy `cmd.exe`) |
| PS1 script blocked | `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned` |
| `bash: bad substitution` on macOS | Apple's bash 3.2 — install bash 4+: `brew install bash` |
| `[!] Update esuat — conflict local` | You have uncommitted changes in `AV-Encoder-Suite/` or `Photo-Encoder-Suite/`. Run `git -C AV-Encoder-Suite status` and either commit/stash or revert |
| Submenu shows "No `.sh` files found" but suites are installed | The submenu shows `.sh` on bash launcher and `.ps1` on PS launcher. If you're on Windows, run the `.ps1` variant |

---

## License

[MIT License](LICENSE) — free to use, modify and distribute.

---

## Support

If you find this project useful, consider a small donation — it helps keep the development going!

[💙 Donate via PayPal](https://paypal.me/TiberiuDobrescu)

---

## Related Projects

- [AV-Encoder-Suite](https://github.com/SlashX/AV-Encoder-Suite) — Video encoding suite (x265, x264, AV1, DNxHR + HW: NVENC, QSV, VAAPI, AMF, VideoToolbox, MediaCodec)
- [Photo-Encoder-Suite](https://github.com/SlashX/Photo-Encoder-Suite) — Photo encoding suite (AVIF, WEBP, JPEG, HEIC, PNG, JXL + Ultra HDR, DJI metadata, Motion Photo)

---

## Changelog

See [docs/launcher_changelog.txt](docs/launcher_changelog.txt) for full version history.

Current: **v4.1.1** — production-ready cross-platform launcher | bash (Termux/Linux/macOS) + PS1 (Windows)
