#!/usr/bin/env bash
set -euo pipefail

# ---- Config ----
PICO_DIR="${HOME}/pico"
TOOLS_DIR="${PICO_DIR}/tools"

# Repo real (cuando ya exista)
PICO_TOOLS_REPO="https://github.com/axfer-io/pico-tools.git"

# OpenOCD build opts (Raspberry Pi fork)
OPENOCD_CFG_OPTS="--enable-internal-jimtcl --enable-picoprobe --enable-ftdi --enable-stlink --enable-sysfsgpio --enable-bcm2835gpio --disable-werror"

# ---- Helpers ----
append_if_missing() {
  local line="$1"
  local file="$2"
  grep -qxF "$line" "$file" 2>/dev/null || echo "$line" >> "$file"
}

ensure_dir() { mkdir -p "$1"; }

# ---- Packages ----
echo "==> Installing packages..."
sudo apt-get update
sudo apt-get install -y \
  build-essential git cmake ninja-build \
  gcc-arm-none-eabi gdb-multiarch \
  libtool pkg-config \
  libusb-1.0-0-dev \
  automake autoconf texinfo \
  libftdi-dev libncurses-dev usbutils

# ---- Workspace ----
ensure_dir "$PICO_DIR"
cd "$PICO_DIR"

# ---- Pico repos ----
echo "==> Cloning Raspberry Pi Pico repos (if missing)..."
[[ -d pico-sdk ]]        || git clone https://github.com/raspberrypi/pico-sdk --recurse-submodules
[[ -d pico-extras ]]     || git clone https://github.com/raspberrypi/pico-extras --recurse-submodules
[[ -d pico-playground ]] || git clone https://github.com/raspberrypi/pico-playground --recurse-submodules
[[ -d pico-examples ]]   || git clone https://github.com/raspberrypi/pico-examples.git
[[ -d picotool ]]        || git clone https://github.com/raspberrypi/picotool --recurse-submodules

# ---- Build picotool ----
echo "==> Building picotool..."
cd "$PICO_DIR/picotool"
# opcional: actualizar si ya existe
git pull --ff-only 2>/dev/null || true
ensure_dir build
cd build
cmake .. -G Ninja
cmake --build .
sudo cmake --install . || true

# ---- Export env vars ----
echo "==> Setting environment variables in ~/.bashrc..."
BASHRC="${HOME}/.bashrc"
append_if_missing 'export PICO_SDK_PATH="$HOME/pico/pico-sdk"' "$BASHRC"
append_if_missing 'export PICO_EXAMPLES_PATH="$HOME/pico/pico-examples"' "$BASHRC"
append_if_missing 'export PICO_EXTRAS_PATH="$HOME/pico/pico-extras"' "$BASHRC"
append_if_missing 'export PICO_PLAYGROUND_PATH="$HOME/pico/pico-playground"' "$BASHRC"

# (Opcional) agrega tools al PATH para invocar scripts sin ruta completa
append_if_missing 'export PATH="$HOME/pico/tools:$PATH"' "$BASHRC"

# ---- OpenOCD (Raspberry fork) ----
echo "==> Cloning & building OpenOCD (raspberrypi/openocd) if missing..."
cd "$PICO_DIR"
if [[ -d openocd/.git ]]; then
  cd openocd
  git pull --ff-only 2>/dev/null || true
else
  git clone https://github.com/raspberrypi/openocd.git --recurse-submodules
  cd openocd
fi

./bootstrap
./configure $OPENOCD_CFG_OPTS
make -j"$(nproc)"
sudo make install
sudo apt-mark hold openocd || true

# ---- pico-tools ----
echo "==> Installing pico-tools..."

# Si existe ~/pico/tools pero NO es repo git, respáldalo
if [[ -d "$TOOLS_DIR" && ! -d "$TOOLS_DIR/.git" ]]; then
  echo "⚠️  $TOOLS_DIR exists but is not a git repo. Renaming to tools.bak"
  mv "$TOOLS_DIR" "${TOOLS_DIR}.bak.$(date +%Y%m%d_%H%M%S)"
fi

# Si ya existe y es git, actualiza; si no, clona
if [[ -d "$TOOLS_DIR/.git" ]]; then
  git -C "$TOOLS_DIR" pull --ff-only || true
else
  rm -rf "$TOOLS_DIR"
  git clone "$PICO_TOOLS_REPO" "$TOOLS_DIR"
fi

# Permisos ejecutables
chmod +x "$TOOLS_DIR"/*.sh 2>/dev/null || true


echo "==> Done."
echo "   Open a new terminal or run: source ~/.bashrc"
echo "   Verify: cmake --version ; ninja --version ; arm-none-eabi-gcc --version ; openocd --version ; picotool version"

