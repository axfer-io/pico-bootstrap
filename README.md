# pico-bootstrap

Embedded systems · Control · Debugging ⚙️  
One script to make a machine ready for real firmware work 🚀

---

## Overview

This repository provides a **single bootstrap script** to set up a complete
Raspberry Pi Pico firmware development environment on a fresh Linux machine.

It installs and configures:
- System dependencies (CMake, Ninja, ARM GCC, GDB)
- Raspberry Pi Pico SDK and related repositories
- `picotool`
- OpenOCD (Raspberry Pi fork, built from source)
- Personal tooling via **`pico-tools`**

After running the installer, the system is ready for **build / flash / debug**
using SWD (no BOOTSEL workflows).

---

## Supported OS

| OS | Script | Notes |
|----|--------|-------|
| Pop!_OS / Ubuntu / Debian | `install.sh` | Requires `sudo` |
| Windows 11 | `install.ps1` | No admin required (uses Scoop) |

---

## What Gets Installed

### Toolchains & Core Tools
- `gcc-arm-none-eabi`
- `gdb-multiarch`
- `cmake`
- `ninja`

### Raspberry Pi Repositories
- `pico-sdk`
- `pico-extras`
- `pico-playground`
- `pico-examples`
- `picotool`

### Debugging
- OpenOCD (Raspberry Pi fork, compiled from source)

### Personal Tooling
- `pico-tools` cloned into:
  ```
  ~/pico/tools
  ```

---

## Installation

### Linux (Ubuntu / Debian / Pop!_OS)

```bash
git clone https://github.com/axfer-io/pico-bootstrap.git
cd pico-bootstrap
chmod +x install.sh
./install.sh
```

### Windows 11

Open **PowerShell** (no admin needed) and run:

```powershell
git clone https://github.com/axfer-io/pico-bootstrap.git
cd pico-bootstrap
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser   # once, if not already set
.\install.ps1
```

`install.ps1` installs [Scoop](https://scoop.sh/) automatically if it is not
already present and uses it to install all required packages.

---

Both scripts are **idempotent**:
- Safe to run multiple times
- Updates existing repos when possible
- Does not duplicate environment variables

---

## Installed Layout

After installation:

```text
~/pico/
├── pico-sdk
├── pico-extras
├── pico-playground
├── pico-examples
├── picotool
├── openocd
└── tools/
    ├── flash.sh
    ├── pico-openocd.sh
    ├── doctor.sh
    ├── README.md
    └── README_TROUBLESHOOT.md
```

---

## Environment Variables

### Linux — appended to `~/.bashrc`

```bash
export PICO_SDK_PATH="$HOME/pico/pico-sdk"
export PICO_EXAMPLES_PATH="$HOME/pico/pico-examples"
export PICO_EXTRAS_PATH="$HOME/pico/pico-extras"
export PICO_PLAYGROUND_PATH="$HOME/pico/pico-playground"
export PATH="$HOME/pico/tools:$PATH"
```

Reload: `source ~/.bashrc`

### Windows 11 — set as User environment variables + PowerShell profile

```powershell
$env:PICO_SDK_PATH        = "$HOME\pico\pico-sdk"
$env:PICO_EXAMPLES_PATH   = "$HOME\pico\pico-examples"
$env:PICO_EXTRAS_PATH     = "$HOME\pico\pico-extras"
$env:PICO_PLAYGROUND_PATH = "$HOME\pico\pico-playground"
$env:PATH                 = "$HOME\pico\tools;$env:PATH"
```

Reload: `. $PROFILE`

---

## Verification

Run the automated diagnostic:

```bash
doctor.sh
```

Or manually verify:

```bash
cmake --version
ninja --version
arm-none-eabi-gcc --version
openocd --version
picotool version
```

---

## Workflow After Install

Typical daily loop:

```bash
cmake --preset <board>-debug
cmake --build --preset flash-<board>-debug
```

Start OpenOCD for debugging:

```bash
pico-openocd.sh
```

Attach via:
- `gdb-multiarch`
- Neovim + nvim-dap
- Any GDB frontend

---

## Design Philosophy

- Bootstrap once, work fast forever
- Tooling lives outside firmware repos
- Debug via SWD, not mass-storage hacks
- Explicit configuration over hidden automation

If your workflow still needs BOOTSEL, something is missing.

---

## Author

**axfer-io**  
Embedded systems · Control · Debugging

---

## License

MIT
