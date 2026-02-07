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

- Pop!_OS
- Ubuntu
- Debian-based distributions

> Requires sudo privileges and internet access.

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

Clone this repository and run the installer:

```bash
git clone https://github.com/axfer-io/pico-bootstrap.git
cd pico-bootstrap
chmod +x install.sh
./install.sh
```

The script is **idempotent**:
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

The installer appends the following to `~/.bashrc` (if missing):

```bash
export PICO_SDK_PATH="$HOME/pico/pico-sdk"
export PICO_EXAMPLES_PATH="$HOME/pico/pico-examples"
export PICO_EXTRAS_PATH="$HOME/pico/pico-extras"
export PICO_PLAYGROUND_PATH="$HOME/pico/pico-playground"
export PATH="$HOME/pico/tools:$PATH"
```

Reload your shell after installation:

```bash
source ~/.bashrc
```

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
