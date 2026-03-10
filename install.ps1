#Requires -Version 5.1
<#
.SYNOPSIS
    Bootstrap script for Raspberry Pi Pico development on Windows 11.

.DESCRIPTION
    Sets up a complete Pico firmware development environment:
    - Scoop (package manager)
    - Git, CMake, Ninja, ARM GCC toolchain, OpenOCD
    - Pico SDK, pico-extras, pico-playground, pico-examples, picotool
    - pico-tools personal tooling
    - User environment variables (PICO_SDK_PATH, etc.)

.NOTES
    Run from PowerShell as your normal user (no admin required).
    First-time execution policy change may prompt for confirmation.

    Usage:
        Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
        .\install.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---- Config ----
$PicoDir       = "$env:USERPROFILE\pico"
$ToolsDir      = "$PicoDir\tools"
$PicoToolsRepo = "https://github.com/axfer-io/pico-tools.git"

# ---- Helpers ----
function Ensure-Dir([string]$Path) {
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Set-UserEnv([string]$Name, [string]$Value) {
    [Environment]::SetEnvironmentVariable($Name, $Value, 'User')
    Set-Item -Path "Env:\$Name" -Value $Value
    Write-Host "    $Name = $Value"
}

function Add-UserPath([string]$Dir) {
    $current = [Environment]::GetEnvironmentVariable('PATH', 'User')
    if ($current -notlike "*$Dir*") {
        [Environment]::SetEnvironmentVariable('PATH', "$Dir;$current", 'User')
        $env:PATH = "$Dir;$env:PATH"
        Write-Host "    Added to PATH: $Dir"
    }
}

function Append-If-Missing([string]$Line, [string]$File) {
    Ensure-Dir (Split-Path $File)
    if (-not (Test-Path $File)) { New-Item $File -ItemType File | Out-Null }
    $existing = Get-Content $File -Raw -ErrorAction SilentlyContinue
    if (-not $existing -or ($existing -notmatch [regex]::Escape($Line))) {
        Add-Content $File "`n$Line"
    }
}

function Clone-Or-Update([string]$Name, [string]$Url, [string[]]$Extra = @()) {
    $dest = "$PicoDir\$Name"
    if (Test-Path "$dest\.git") {
        Write-Host "    $Name already exists — pulling..."
        git -C $dest pull --ff-only 2>$null
    } else {
        Write-Host "    Cloning $Name..."
        & git clone $Url @Extra $dest
    }
}

# ---- Scoop ----
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Host "==> Installing Scoop..."
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Invoke-RestMethod -Uri 'https://get.scoop.sh' | Invoke-Expression
    # Make shims available for the rest of this session
    $env:PATH = "$env:USERPROFILE\scoop\shims;$env:PATH"
} else {
    Write-Host "==> Scoop already installed."
}

Write-Host "==> Adding Scoop buckets..."
scoop bucket add main   2>$null | Out-Null
scoop bucket add extras 2>$null | Out-Null

# ---- Packages ----
Write-Host "==> Installing build tools..."
$packages = @(
    'git',              # required first
    'cmake',
    'ninja',
    'gcc-arm-none-eabi',# ARM cross-compiler + arm-none-eabi-gdb
    'mingw',            # MinGW-w64: native gcc/g++ to build host tools (picotool)
    'openocd',          # pre-built OpenOCD with CMSIS-DAP/SWD/FTDI support
    'libusb'            # needed by picotool
)

foreach ($pkg in $packages) {
    Write-Host "    scoop install $pkg"
    scoop install $pkg 2>&1 | Where-Object { $_ -notmatch 'already installed' }
}

# Refresh PATH so newly installed tools are visible
$env:PATH = "$env:USERPROFILE\scoop\shims;$env:PATH"

# ---- Workspace ----
Ensure-Dir $PicoDir
Set-Location $PicoDir

# ---- Pico repos ----
Write-Host "==> Cloning Raspberry Pi Pico repos (if missing)..."
Clone-Or-Update 'pico-sdk'        'https://github.com/raspberrypi/pico-sdk'        '--recurse-submodules'
Clone-Or-Update 'pico-extras'     'https://github.com/raspberrypi/pico-extras'     '--recurse-submodules'
Clone-Or-Update 'pico-playground' 'https://github.com/raspberrypi/pico-playground' '--recurse-submodules'
Clone-Or-Update 'pico-examples'   'https://github.com/raspberrypi/pico-examples'
Clone-Or-Update 'picotool'        'https://github.com/raspberrypi/picotool'        '--recurse-submodules'

# ---- Build picotool ----
Write-Host "==> Building picotool..."
Set-Location "$PicoDir\picotool"
git pull --ff-only 2>$null | Out-Null
Ensure-Dir build
Set-Location build

# Locate MinGW compilers installed by Scoop
$mingwBin = "$env:USERPROFILE\scoop\apps\mingw\current\bin"
$libusb   = "$env:USERPROFILE\scoop\apps\libusb\current"

cmake .. -G Ninja `
    -DCMAKE_BUILD_TYPE=Release `
    -DCMAKE_C_COMPILER="$mingwBin\gcc.exe" `
    -DCMAKE_CXX_COMPILER="$mingwBin\g++.exe" `
    -DPICO_SDK_PATH="$PicoDir\pico-sdk" `
    -DLIBUSB_INCLUDE_DIR="$libusb\include\libusb-1.0" `
    -DLIBUSB_LIBRARIES="$libusb\lib\libusb-1.0.lib"

cmake --build .

# Install picotool to scoop shims so it is on PATH
$picotoolExe = ".\picotool.exe"
if (Test-Path $picotoolExe) {
    $shimsDir = "$env:USERPROFILE\scoop\shims"
    Copy-Item $picotoolExe $shimsDir -Force
    Write-Host "    picotool installed to $shimsDir"
} else {
    Write-Warning "picotool build may have failed — check output above."
}

Set-Location $PicoDir

# ---- Environment variables ----
Write-Host "==> Setting User environment variables..."
Set-UserEnv 'PICO_SDK_PATH'        "$PicoDir\pico-sdk"
Set-UserEnv 'PICO_EXAMPLES_PATH'   "$PicoDir\pico-examples"
Set-UserEnv 'PICO_EXTRAS_PATH'     "$PicoDir\pico-extras"
Set-UserEnv 'PICO_PLAYGROUND_PATH' "$PicoDir\pico-playground"

Add-UserPath $ToolsDir

# Mirror vars in PowerShell profile (equivalent of ~/.bashrc)
$profile = $PROFILE.CurrentUserAllHosts
Append-If-Missing "`$env:PICO_SDK_PATH        = '$PicoDir\pico-sdk'"         $profile
Append-If-Missing "`$env:PICO_EXAMPLES_PATH   = '$PicoDir\pico-examples'"    $profile
Append-If-Missing "`$env:PICO_EXTRAS_PATH     = '$PicoDir\pico-extras'"      $profile
Append-If-Missing "`$env:PICO_PLAYGROUND_PATH = '$PicoDir\pico-playground'"  $profile
Append-If-Missing "`$env:PATH                 = '$ToolsDir;' + `$env:PATH"   $profile

# ---- pico-tools ----
Write-Host "==> Installing pico-tools..."
if ((Test-Path $ToolsDir) -and (-not (Test-Path "$ToolsDir\.git"))) {
    $backup = "$ToolsDir.bak.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Write-Warning "$ToolsDir exists but is not a git repo. Renaming to $backup"
    Rename-Item $ToolsDir $backup
}

if (Test-Path "$ToolsDir\.git") {
    git -C $ToolsDir pull --ff-only
} else {
    if (Test-Path $ToolsDir) { Remove-Item $ToolsDir -Recurse -Force }
    git clone $PicoToolsRepo $ToolsDir
}

# ---- Done ----
Write-Host ""
Write-Host "==> Done."
Write-Host "   Open a new PowerShell window, or reload your profile:"
Write-Host "     . `$PROFILE"
Write-Host ""
Write-Host "   Verify installation:"
Write-Host "     cmake --version"
Write-Host "     ninja --version"
Write-Host "     arm-none-eabi-gcc --version"
Write-Host "     openocd --version"
Write-Host "     picotool version"
Write-Host ""
Write-Host "NOTE: OpenOCD installed via Scoop is the standard upstream release."
Write-Host "      It supports CMSIS-DAP (picoprobe), FTDI, and SWD — sufficient"
Write-Host "      for Pico debugging. The Raspberry Pi fork adds bcm2835gpio"
Write-Host "      (RPi GPIO) and sysfsgpio, which are Linux/RPi-only features."
