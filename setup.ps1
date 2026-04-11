# setup.ps1 -- Automated setup for Shiny Bot (Windows + Pico 2 W)
# Run from the repo root: powershell.exe -ExecutionPolicy Bypass -File setup.ps1
#
# What this script does:
#   1. Checks for and installs missing prerequisites (CMake, Ninja, ARM toolchain, MSYS2, MinGW GCC)
#   2. Clones the Pico SDK if not already present
#   3. Installs Python dependencies (opencv-python, numpy)
#   4. Builds the Pico firmware (prompts for WiFi credentials)
#   5. Optionally flashes the firmware to a connected Pico in BOOTSEL mode

param(
    [string]$SSID,
    [string]$Password,
    [switch]$Flash,
    [switch]$SkipPrereqs
)

$ErrorActionPreference = "Stop"

# --- Helpers ---

function Write-Step($msg) {
    Write-Host ""
    Write-Host "===> $msg" -ForegroundColor Cyan
}

function Write-OK($msg) {
    Write-Host "  OK: $msg" -ForegroundColor Green
}

function Write-Warn($msg) {
    Write-Host "  WARN: $msg" -ForegroundColor Yellow
}

function Write-Err($msg) {
    Write-Host "  ERROR: $msg" -ForegroundColor Red
}

function Test-CommandExists($cmd) {
    $null -ne (Get-Command $cmd -ErrorAction SilentlyContinue)
}

function Refresh-Path {
    # Pull the current Machine + User PATH from the registry so newly installed tools are visible
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath    = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:PATH    = "$machinePath;$userPath"
}

# --- Banner ---

Write-Host ""
Write-Host "============================================" -ForegroundColor Magenta
Write-Host "  Shiny Bot -- Automated Setup for Windows" -ForegroundColor Magenta
Write-Host "============================================" -ForegroundColor Magenta
Write-Host ""

# --- Check we're in the repo root ---

if (-not (Test-Path "pico-fw\CMakeLists.txt")) {
    Write-Err "This script must be run from the repo root (where pico-fw\ exists)."
    Write-Host "  cd into the repo folder and try again."
    exit 1
}

# ============================================================
# STEP 1: Prerequisites
# ============================================================

if (-not $SkipPrereqs) {

    Write-Step "Checking prerequisites..."

    # -- winget --
    if (-not (Test-CommandExists "winget")) {
        Write-Err "winget is not available. Please install App Installer from the Microsoft Store."
        exit 1
    }

    # -- CMake --
    Refresh-Path
    if (Test-CommandExists "cmake") {
        Write-OK "CMake found: $((Get-Command cmake).Source)"
    } else {
        Write-Step "Installing CMake..."
        winget install Kitware.CMake --accept-package-agreements --accept-source-agreements
        Refresh-Path
        if (Test-CommandExists "cmake") {
            Write-OK "CMake installed."
        } else {
            Write-Warn "CMake installed but not on PATH yet. Will try to locate it."
        }
    }

    # -- Ninja --
    Refresh-Path
    if (Test-CommandExists "ninja") {
        Write-OK "Ninja found: $((Get-Command ninja).Source)"
    } else {
        Write-Step "Installing Ninja..."
        winget install Ninja-build.Ninja --accept-package-agreements --accept-source-agreements
        Refresh-Path
        if (Test-CommandExists "ninja") {
            Write-OK "Ninja installed."
        } else {
            Write-Warn "Ninja installed but not on PATH yet. Will try to locate it."
        }
    }

    # -- ARM GNU Toolchain --
    $armGccDefault = "C:\Program Files (x86)\Arm GNU Toolchain arm-none-eabi"
    Refresh-Path
    if (Test-CommandExists "arm-none-eabi-gcc") {
        Write-OK "ARM GCC found: $((Get-Command arm-none-eabi-gcc).Source)"
    } elseif (Test-Path $armGccDefault) {
        Write-OK "ARM GCC found at $armGccDefault (will add to PATH for build)."
    } else {
        Write-Step "Installing ARM GNU Toolchain..."
        winget install Arm.GnuArmEmbeddedToolchain --accept-package-agreements --accept-source-agreements
        Refresh-Path
        if (Test-Path $armGccDefault) {
            Write-OK "ARM GCC installed."
        } else {
            Write-Err "ARM GCC install failed. Please install manually from https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads"
            exit 1
        }
    }

    # -- MSYS2 + MinGW GCC (host compiler) --
    $msys2Gcc = "C:\msys64\mingw64\bin\gcc.exe"
    if (Test-Path $msys2Gcc) {
        Write-OK "MSYS2 MinGW GCC found."
    } else {
        if (-not (Test-Path "C:\msys64\usr\bin\pacman.exe")) {
            Write-Step "Installing MSYS2..."
            winget install MSYS2.MSYS2 --accept-package-agreements --accept-source-agreements
        }
        if (Test-Path "C:\msys64\usr\bin\pacman.exe") {
            Write-Step "Installing MinGW GCC via MSYS2 pacman..."
            & "C:\msys64\usr\bin\pacman.exe" -S --noconfirm mingw-w64-x86_64-gcc
            if (Test-Path $msys2Gcc) {
                Write-OK "MinGW GCC installed."
            } else {
                Write-Err "MinGW GCC install failed. Try running manually: C:\msys64\usr\bin\pacman.exe -S --noconfirm mingw-w64-x86_64-gcc"
                exit 1
            }
        } else {
            Write-Err "MSYS2 install failed. Please install manually from https://www.msys2.org/"
            exit 1
        }
    }

    # -- Python --
    if (Test-CommandExists "python") {
        Write-OK "Python found: $((Get-Command python).Source)"
    } else {
        Write-Err "Python is not installed. Please install from https://www.python.org/downloads/"
        exit 1
    }

    # -- Git --
    if (Test-CommandExists "git") {
        Write-OK "Git found."
    } else {
        Write-Err "Git is not installed. Please install from https://git-scm.com/download/win"
        exit 1
    }

} else {
    Write-Step "Skipping prerequisite checks (--SkipPrereqs)."
}

# ============================================================
# STEP 2: Pico SDK
# ============================================================

Write-Step "Checking Pico SDK..."

$picoSdkPath = if ($env:PICO_SDK_PATH) { $env:PICO_SDK_PATH } else { "$HOME\pico-sdk" }

if (Test-Path "$picoSdkPath\src\boards") {
    Write-OK "Pico SDK found at $picoSdkPath"
} else {
    Write-Step "Cloning Pico SDK to $picoSdkPath..."
    git clone https://github.com/raspberrypi/pico-sdk.git $picoSdkPath
    Push-Location $picoSdkPath
    git submodule update --init
    Pop-Location
    if (Test-Path "$picoSdkPath\src\boards") {
        Write-OK "Pico SDK cloned and initialized."
    } else {
        Write-Err "Pico SDK clone failed."
        exit 1
    }
}

$env:PICO_SDK_PATH = $picoSdkPath

# ============================================================
# STEP 3: Python dependencies
# ============================================================

Write-Step "Installing Python dependencies..."
python -m pip install --quiet opencv-python numpy
Write-OK "opencv-python and numpy installed."

# ============================================================
# STEP 4: Build firmware
# ============================================================

Write-Step "Preparing to build firmware..."

# Ensure all tools are on PATH for this session
$pathAdditions = @()

# CMake
if (-not (Test-CommandExists "cmake")) {
    if (Test-Path "C:\Program Files\CMake\bin\cmake.exe") {
        $pathAdditions += "C:\Program Files\CMake\bin"
    }
}

# Ninja -- check winget packages folder
if (-not (Test-CommandExists "ninja")) {
    $ninjaDir = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter "Ninja*" -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($ninjaDir) { $pathAdditions += $ninjaDir.FullName }
}

# ARM GCC
if (-not (Test-CommandExists "arm-none-eabi-gcc")) {
    $armDir = Get-ChildItem "C:\Program Files (x86)\Arm GNU Toolchain arm-none-eabi" -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
    if ($armDir) { $pathAdditions += "$($armDir.FullName)\bin" }
}

# MSYS2 MinGW
if (-not (Test-Path env:CC) -and (Test-Path "C:\msys64\mingw64\bin\gcc.exe")) {
    $pathAdditions += "C:\msys64\mingw64\bin"
}

if ($pathAdditions.Count -gt 0) {
    $env:PATH = ($pathAdditions -join ";") + ";$env:PATH"
    Write-OK "Added to PATH for this build: $($pathAdditions -join ', ')"
}

# Prompt for WiFi creds if not provided
if (-not $SSID) {
    $SSID = Read-Host "Enter your WiFi SSID (network name)"
}
if (-not $Password) {
    $Password = Read-Host "Enter your WiFi password"
}

if ([string]::IsNullOrWhiteSpace($SSID) -or [string]::IsNullOrWhiteSpace($Password)) {
    Write-Err "WiFi SSID and password are required to build the firmware."
    exit 1
}

# Build
$buildDir = "pico-fw\build"

Write-Step "Configuring CMake..."
if (Test-Path $buildDir) {
    # Try to clean the build directory. If it's locked, remove what we can and reconfigure in place.
    try {
        Remove-Item $buildDir -Recurse -Force -ErrorAction Stop
    } catch {
        Write-Warn "Could not fully remove build directory (may be locked). Cleaning contents..."
        Get-ChildItem $buildDir -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
}
if (-not (Test-Path $buildDir)) {
    New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
}

# Write WiFi credentials to a cmake initial-cache file.
# This avoids PowerShell-to-CMake quoting nightmares entirely.
# The C code expects string literals, so the CMake variable value must include
# the surrounding double quotes, e.g.: set(WIFI_SSID "\"MySSID\"" ...)
$cacheFile = "$buildDir\wifi_creds_init.cmake"
$q = [char]34   # double-quote character
$line1 = "set(WIFI_SSID ${q}\${q}${SSID}\${q}${q} CACHE STRING ${q}${q})"
$line2 = "set(WIFI_PASSWORD ${q}\${q}${Password}\${q}${q} CACHE STRING ${q}${q})"
Set-Content -Path $cacheFile -Value "$line1`n$line2" -Encoding UTF8

cmake -S pico-fw -B $buildDir `
    -G Ninja `
    -DPICO_BOARD=pico2_w `
    -C $cacheFile

if ($LASTEXITCODE -ne 0) {
    Write-Err "CMake configure failed. See errors above."
    exit 1
}

Write-Step "Building firmware..."
cmake --build $buildDir -j

if ($LASTEXITCODE -ne 0) {
    Write-Err "Build failed. See errors above."
    exit 1
}

$uf2 = "$buildDir\shinybot_pico_fw.uf2"
if (Test-Path $uf2) {
    Write-OK "Firmware built: $uf2"
} else {
    Write-Err "Build completed but .uf2 file not found."
    exit 1
}

# ============================================================
# STEP 5: Flash (optional)
# ============================================================

if ($Flash) {
    Write-Step "Looking for Pico in BOOTSEL mode..."

    $picoFound = $false
    foreach ($letter in @("D","E","F","G","H")) {
        $infoFile = "${letter}:\INFO_UF2.TXT"
        if (Test-Path $infoFile) {
            Write-Step "Flashing to ${letter}:\..."
            Copy-Item $uf2 "${letter}:\"
            Write-OK "Firmware flashed! The Pico will reboot and connect to WiFi."
            $picoFound = $true
            break
        }
    }

    if (-not $picoFound) {
        Write-Warn "RPI-RP2 drive not found. Hold BOOTSEL on the Pico and plug it in, then run:"
        Write-Host "  Copy-Item $uf2 D:\" -ForegroundColor White
        Write-Host "  (replace D: with your actual drive letter)"
    }
} else {
    Write-Host ""
    Write-Host "To flash the firmware:" -ForegroundColor White
    Write-Host "  1. Hold BOOTSEL on the Pico 2 W"
    Write-Host "  2. Plug it into your PC via USB"
    Write-Host "  3. Run:  Copy-Item $uf2 D:\" -ForegroundColor White
    Write-Host "     (replace D: with your actual drive letter)"
    Write-Host ""
    Write-Host "Or re-run this script with -Flash:" -ForegroundColor White
    Write-Host "  powershell.exe -ExecutionPolicy Bypass -File setup.ps1 -Flash"
}

# ============================================================
# Done
# ============================================================

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Setup complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Flash the firmware to your Pico (if you haven't already)"
Write-Host "  2. Find the Pico's IP address from your router"
Write-Host "  3. Test the connection:  curl.exe http://PICO_IP:8080/status"
Write-Host "  4. Set up OBS with your capture card (see README)"
Write-Host "  5. Run the bot:  python hunt_loop.py"
Write-Host ""
