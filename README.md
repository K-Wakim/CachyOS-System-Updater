# CachyOS System Updater

A one-command system update script for [CachyOS](https://cachyos.org/) (and other Arch-based distros), available for both the [fish shell](https://fishshell.com/) and bash.

One command updates your system packages, AUR packages, flatpaks and snaps, removes orphaned packages, cleans the package cache, and then offers to shut down or reboot. Every step can be automated or disabled, and settings are changed from the terminal rather than by editing the script.

By Kamal Wakim

## TODO
I can't thing of anything left to do. If I think of something I will update

## Features

- Updates official repo packages with `pacman`
- Updates AUR packages with `paru` or `yay`, whichever is installed (or your choice if both are)
- Updates flatpaks, and optionally reinstalls [Vencord](https://vencord.dev/) when Discord was updated
- Updates snaps
- Skips flatpak and snap updates automatically when they aren't installed
- Removes orphaned packages, either automatically or after asking you
- Cleans the package cache, either automatically or after asking you
- Offers to shut down, reboot, or stay running when it finishes
- Optional per-run log files
- Every feature can be turned off, and settings persist across terminals and reboots

## Choosing a version

Both versions have the same features, settings and commands. Install **only one of them**, since both define `update_system`, `upd` and `updcfg`.

| | Fish version (`fish/`) | Bash version (`bash/`) |
| --- | --- | --- |
| Best for | fish users who like everything as fish functions | bash users, or anyone who wants a single file that can also run as an executable from any shell |
| Installed as | Functions in `~/.config/fish/functions/` | One file, sourced from `~/.bashrc` (or installed as an executable) |
| Settings stored in | Fish universal variables (`update_system_<setting>`) | `~/.config/update_system/config` |
| Logs stored in | `~/.config/update_system.log/` | `~/.config/update_system.log/` |
| Shortcut files | `upd.fish`, `updcfg.fish` | None, `upd` and `updcfg` are defined inside `update_system.sh` |

The two versions keep separate settings, so changing one never affects the other, and settings aren't carried over when you switch.

## Requirements

| Requirement | Needed for |
| --- | --- |
| fish shell (fish version) or bash 4+ (bash version) | Running the script. CachyOS and Arch ship bash 5. |
| `pacman` and `sudo` | Everything |
| `paru` or `yay` | AUR updates (optional; without one, only official repos are updated) |
| `flatpak` | Flatpak updates (optional; skipped automatically if not installed) |
| `snap` | Snap updates (optional; skipped automatically if not installed) |
| `paccache` (from `pacman-contrib`) | Cache cleaning |
| `curl` | Reinstalling Vencord (optional) |

## Installation

### Fish version

Fish loads functions automatically from `~/.config/fish/functions/`, where each file is named after the function it defines. Copy the script and the two shortcut files there:

```fish
cp fish/update_system.fish fish/upd.fish fish/updcfg.fish ~/.config/fish/functions/
```

Then open a new terminal.

### Bash version

Add one line to your `~/.bashrc` that sources the script from wherever you keep the project, replacing the path with the real one:

```bash
source /path/to/update_system/bash/update_system.sh
```

Then open a new terminal (or run `source ~/.bashrc`). Sourcing only defines the commands `update_system`, `upd` and `updcfg`, and nothing runs until you call one. Since `~/.bashrc` points at the project file, changes to the script apply to new terminals without reinstalling anything.

**Alternative: install it as an executable.** Use this if you'd rather not source it, or want to run it from another shell such as fish or zsh. Copy it into a folder on your `PATH` and add symlinks for the shortcuts:

```bash
install -Dm755 bash/update_system.sh ~/.local/bin/update_system
ln -s update_system ~/.local/bin/upd
ln -s update_system ~/.local/bin/updcfg
```

The script checks the name it was started under, so a link called `upd` runs the update and a link called `updcfg` opens the settings. Make sure `~/.local/bin` is on your `PATH` (check with `echo $PATH`). If it isn't, add this line to your `~/.bashrc`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Either way, run the script as your normal user and don't put `sudo` in front of it. It calls `sudo` itself for the steps that need it, and running the whole thing as root would put your settings and logs in root's home folder.

You can skip `upd.fish` and `updcfg.fish` in the fish version if you don't want the shortcuts. See [Shortcuts](#shortcuts).

## Usage

```bash
update_system
```

This runs the following steps in order:

1. **System + AUR update**: `paru -Syu` or `yay -Syu` if a helper is installed, otherwise `pacman -Syu`. This runs with `--noconfirm`, so it does not ask for confirmation. If it fails, the script stops.
2. **Flatpak update**: `flatpak update -y`. If Discord was among the updated flatpaks, Vencord is reinstalled.
3. **Snap update**: `snap refresh`.
4. **Orphan removal**: lists orphaned packages and removes them (automatically or after a prompt, depending on settings).
5. **Cache cleaning**: runs `pacman -Scc` and `paccache -ruk0` (automatically or after a prompt, depending on settings).
6. **Post-update action**: asks whether to shut down, reboot, or stay running.

### Options

| Command | What it does |
| --- | --- |
| `update_system` | Run the update |
| `update_system -h`, `-help`, `--help`, `help` | Show help |
| `update_system --config [...]` | Change settings (see [Configuration](#configuration)) |

Unrecognized options print the help text and exit without updating.

If `flatpak` or `snap` isn't installed, that step prints a short notice and is skipped, so you don't need to disable it yourself.

## Shortcuts

Two short commands are included:

| Command | Same as |
| --- | --- |
| `upd` | `update_system` |
| `updcfg` | `update_system --config` |

Both pass any arguments through, so `upd --help` and `updcfg show` work.

**Custom names, fish version:** fish only autoloads a file from `~/.config/fish/functions/` when it is named after the function it defines, so each shortcut has its own file. To add your own, create a file named after the new function, for example `~/.config/fish/functions/up.fish`:

```fish
function up
    update_system $argv
end
```

Alternatively, put several functions in one file in `~/.config/fish/conf.d/`, which fish runs at every startup whatever the file is called.

**Custom names, bash version:** `upd` and `updcfg` are defined inside `update_system.sh`. For your own name, add an alias in `~/.bashrc` after the `source` line, or, if you installed it as an executable, another symlink:

```bash
alias up='update_system'                              # an alias in ~/.bashrc
ln -s update_system ~/.local/bin/up                   # or a symlink next to the executable
```

**Why `upd` and not `update`:** CachyOS's shell configuration already defines an `update` command (it ranks mirrors and then runs your AUR helper), and functions and aliases take priority over a fish autoloaded function or a program in `~/.local/bin`, and a function you source in `~/.bashrc` could be overridden by a later definition. Use `type NAME` to check whether a name is already taken.

## Configuration

```bash
update_system --config                 # interactive menu
update_system --config show            # print current settings
update_system --config set KEY VALUE   # change one setting
update_system --config reset           # restore all defaults
updcfg dellog                          # delete log files
update_system --config help            # show usage
```

`updcfg` is a shortcut for `update_system --config`, so `updcfg show` works too.

The interactive menu lists every setting with a number. Type a number to toggle that setting (the AUR helper cycles through its options), press Enter to finish, or type `h` for help.

Settings persist across terminals and reboots, and anything you haven't changed uses its default. See [Choosing a version](#choosing-a-version) for where each version stores them. In the bash version the config file is plain `key=value` lines that you can edit by hand, though the commands above validate your input for you (it also honors `$XDG_CONFIG_HOME`).

### Settings

For the `disable_*` settings, `true` means the feature is turned **off**.

| Setting | Default | Description |
| --- | --- | --- |
| `auto_remove_orphans` | `true` | Remove orphan packages without asking |
| `auto_clean_cache` | `true` | Clean the package cache without asking |
| `disable_remove_orphans` | `false` | Skip orphan removal entirely |
| `disable_clean_cache` | `false` | Skip cache cleaning entirely |
| `disable_flatpak_updates` | `false` | Skip flatpak updates (this also skips the Vencord step) |
| `disable_vencord_reinstall` | `false` | Don't reinstall Vencord after a Discord update |
| `disable_snap_updates` | `false` | Skip snap updates |
| `disable_AUR_updates` | `false` | Skip AUR updates and update official repos only |
| `disable_logs` | `true` | Don't write a log file |
| `aur_helper` | `auto` | `auto`, `paru` or `yay` |

When an `auto_*` setting is `false`, the script asks `y/N` before doing that step.

### AUR helper

With `auto`, the script uses `paru` if it's installed and `yay` otherwise. If your chosen helper isn't installed, it falls back to whichever one is. If neither is installed, it updates the official repos only.

The `aur_helper` setting is locked unless both `paru` and `yay` are installed, since there's nothing to choose otherwise. The menu shows it as locked, and `update_system --config set aur_helper ...` is rejected.

### Examples

```bash
# Be asked before orphans are removed
update_system --config set auto_remove_orphans false

# Turn on logging
update_system --config set disable_logs false

# Stop reinstalling Vencord after Discord updates
update_system --config set disable_vencord_reinstall true

# Always use yay (only possible when both helpers are installed)
update_system --config set aur_helper yay
```

## Logging

With `disable_logs` set to `false`, each run's output is shown on screen and also written to a timestamped file, for example `2026-11-05_14-30-00.log`. Both versions store logs in `~/.config/update_system.log/`. To change the location, edit the `log_dir` assignment in the `update_system` function of the relevant script.

Delete saved logs with `updcfg dellog`. The command lists the log files and asks for confirmation before deleting them.

Things to know about logging:

- Because output is piped through `tee`, `pacman` and AUR helpers no longer see a terminal, so they drop colors and live progress bars. The log can also contain progress-bar clutter.
  
## Things to know

- **Updates are unattended.** The system and flatpak updates run with `--noconfirm` / `-y`, so you aren't asked before packages are installed or upgraded.
- **Orphan removal is automatic by default.** Packages such as `lib32-*` libraries can show up as orphans even though a game or Wine setup still uses them. Set `auto_remove_orphans` to `false` if you want to review the list first.
- **The cache is wiped completely.** `pacman -Scc` deletes all cached packages, including the installed versions, so you can't quickly downgrade a package from the cache after an update breaks something.
- **Vencord is installed from a remote script.** When Discord is updated, the script downloads and runs the installer from `https://vencord.dev/install.sh`. Disable this with `disable_vencord_reinstall` if you'd rather not run it automatically.
- **Mirror errors are not a script problem.** Errors such as `404` when downloading `.db` files come from an out-of-date mirror. Refreshing your mirrors with `sudo cachyos-rate-mirrors` usually fixes it.

## Uninstalling

Fish version:

```fish
update_system --config reset
rm ~/.config/fish/functions/{update_system,upd,updcfg}.fish
```

Bash version: remove the `source` line from `~/.bashrc`, then delete the settings:

```bash
rm -r ~/.config/update_system
```

If you installed it as an executable instead, also run `rm ~/.local/bin/{update_system,upd,updcfg}`.

Log files, if any, are in the folder listed under [Choosing a version](#choosing-a-version) and can be deleted separately.

## Project layout

```text
.
├── README.md
├── fish/
│   ├── update_system.fish
│   ├── upd.fish
│   └── updcfg.fish
└── bash/
    └── update_system.sh
```
