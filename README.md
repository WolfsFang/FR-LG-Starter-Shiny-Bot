## Legal

This project is provided for **educational and personal automation purposes only**.

It is **not affiliated with Nintendo, Game Freak, or The Pokémon Company**.

See:

- LICENSE
- NOTICE
- DISCLAIMER

This repository is no longer actively maintained.
Feel free to fork the project and continue development.

# Shiny Bot

Automated shiny hunting for **Pokemon FireRed / LeafGreen** on **Nintendo Switch** using a **Windows PC + Raspberry Pi Pico 2 W**.

The bot:

1. Resets the game  
2. Continues the save  
3. Selects the starter  
4. Opens the summary screen  
5. Detects the **shiny star** using OpenCV  
6. Stops automatically when a shiny is detected  

You can then **manually save the shiny Pokemon**.

---

# Hardware Required

- Nintendo Switch + Dock  
- Raspberry Pi **Pico 2 W**  
- HDMI Capture Card  
- Windows PC
- USB cable for Pico  

---

# Before You Start

You need **three things** installed before doing anything else. If you already have these, skip ahead.

## 1. Install Git

Git is used to download this project and the Pico SDK.

1. Go to https://git-scm.com/download/win
2. Download the installer and run it
3. **Use all the default options** -- just keep clicking Next
4. This also installs **Git Bash**, which you will need later

To check if Git is already installed, open PowerShell and type:

```powershell
git --version
```

If you see a version number, you're good.

## 2. Install Python 3

Python runs the bot scripts and the shiny detection.

1. Go to https://www.python.org/downloads/
2. Click the big yellow **Download Python** button
3. Run the installer
4. **IMPORTANT: Check the box that says "Add python.exe to PATH"** before clicking Install

To check if Python is already installed:

```powershell
python --version
```

If you see a version number (3.x.x), you're good.

## 3. Install OBS Studio

OBS is used to view and capture video from your Switch through the capture card.

1. Go to https://obsproject.com/
2. Download and install it
3. You don't need to configure it yet -- we'll do that later

---

# Clone the Repo

Open **PowerShell** (search for "PowerShell" in the Start menu) and run:

```powershell
git clone https://github.com/WolfsFang/FR-LG-Starter-Shiny-Bot.git
cd FR-LG-Starter-Shiny-Bot
```

This downloads the project to your computer.

---

# Quick Setup (Automated)

> **Requires:** Git, Python 3, and Windows 10/11 (which includes PowerShell and winget).
> If you followed the "Before You Start" section above, you're ready.

A setup script is included that handles everything else for you -- it installs all the build tools, downloads the Pico SDK, builds the firmware, and can flash it to your Pico. Run it from the repo folder in **PowerShell**:

```powershell
powershell.exe -ExecutionPolicy Bypass -File setup.ps1
```

The script will:

1. Install CMake, Ninja, the ARM compiler, and MSYS2 (if not already installed)
2. Download the Pico SDK
3. Install the Python libraries the bot needs
4. Ask for your WiFi name and password
5. Build the firmware

To also flash the Pico in one go (hold BOOTSEL and plug it in first):

```powershell
powershell.exe -ExecutionPolicy Bypass -File setup.ps1 -Flash
```

You can also provide WiFi credentials directly:

```powershell
powershell.exe -ExecutionPolicy Bypass -File setup.ps1 -SSID "YourWiFiName" -Password "YourWiFiPassword" -Flash
```

If the script completes without errors, skip ahead to [Flash Pico](#flash-pico) (or [Test Pico Connection](#test-pico-connection) if you used `-Flash`).

If the script doesn't work, follow the manual steps below.

---

# Windows Setup (Manual)

Follow these steps **only if you didn't use the setup script**, or if it failed and you need to do things by hand.

## Step 1: Install Build Tools

These are the tools needed to compile the Pico firmware. Open **PowerShell** and run each line one at a time:

```powershell
winget install Kitware.CMake --accept-package-agreements --accept-source-agreements
```

```powershell
winget install Ninja-build.Ninja --accept-package-agreements --accept-source-agreements
```

```powershell
winget install Arm.GnuArmEmbeddedToolchain --accept-package-agreements --accept-source-agreements
```

```powershell
winget install MSYS2.MSYS2 --accept-package-agreements --accept-source-agreements
```

After MSYS2 finishes, install the MinGW GCC compiler. This is a **separate** compiler that the Pico SDK needs internally:

```powershell
C:\msys64\usr\bin\pacman.exe -S --noconfirm mingw-w64-x86_64-gcc
```

> **What are all these tools?**
> - **CMake** -- configures the build (figures out what to compile and how)
> - **Ninja** -- runs the actual build (compiles files fast in parallel)
> - **ARM Toolchain** -- the compiler that produces code the Pico can run
> - **MSYS2 + MinGW GCC** -- a Windows C/C++ compiler that the Pico SDK needs to build some of its internal tools

**Close and reopen your terminal** after installing so the new tools are on your PATH.

## Step 2: Install Python Libraries

```powershell
pip install opencv-python numpy
```

- **opencv-python** -- computer vision library used to detect the shiny star
- **numpy** -- math library that opencv depends on

## Step 3: Install the Pico SDK

The Pico SDK is a set of libraries from Raspberry Pi that lets you write code for the Pico. Clone it and initialize its submodules:

```powershell
git clone https://github.com/raspberrypi/pico-sdk.git $HOME\pico-sdk
```

```powershell
cd $HOME\pico-sdk
git submodule update --init
cd $HOME
```

This will take a few minutes -- it's downloading several libraries the Pico needs (WiFi drivers, USB stack, etc.).

## Step 4: Verify Everything is Installed

After reopening your terminal, run these commands one at a time:

```powershell
cmake --version
```

```powershell
ninja --version
```

```powershell
arm-none-eabi-gcc --version
```

```powershell
python --version
```

Each one should print a version number. If any command says "not recognized" or "not found", the tool isn't on your PATH. Here's where each tool installs:

| Tool | Default Install Location |
|------|--------------------------|
| CMake | `C:\Program Files\CMake\bin` |
| Ninja | `%LOCALAPPDATA%\Microsoft\WinGet\Packages\` (look for the Ninja folder) |
| ARM GCC | `C:\Program Files (x86)\Arm GNU Toolchain arm-none-eabi\14.2 rel1\bin` |
| MSYS2 GCC | `C:\msys64\mingw64\bin` |

To temporarily add a missing tool to your PATH in the current terminal:

```powershell
$env:PATH = "C:\path\to\tool;$env:PATH"
```

---

# Build Pico Firmware

There are two ways to build: the **build script** (recommended) or **manual steps**.

> **Note:** During the first build, you may see a CMake warning about picotool:
> `No installed picotool with version X.X.X found - building from source`
> This is normal -- the build downloads and compiles it automatically. No action needed.

## Option A: Build Script (Recommended)

This is the easiest way. Open **Git Bash** (search for it in the Start menu -- it was installed with Git) and run:

```bash
cd path/to/FR-LG-Starter-Shiny-Bot/pico-fw
```

First time build (replace with your actual WiFi name and password):

```bash
./build.sh --clean --ssid "YourWiFiName" --pass "YourWiFiPassword"
```

If the build succeeds, you'll see: `Build complete: .../shinybot_pico_fw.uf2`

To rebuild later (your WiFi credentials are remembered):

```bash
./build.sh
```

To build **and** flash in one step (hold BOOTSEL on the Pico and plug it in first):

```bash
./build.sh --flash
```

The script automatically finds all the build tools. If your tools are in non-default locations, you can override with environment variables:

| Tool | Default Path | Override Variable |
|------|-------------|-------------------|
| Pico SDK | `~/pico-sdk` | `PICO_SDK_PATH` |
| MSYS2 GCC | `C:\msys64\mingw64\bin` | `MINGW_PATH` |
| ARM Toolchain | `C:\Program Files (x86)\Arm GNU Toolchain arm-none-eabi\14.2 rel1\bin` | `ARM_GCC_PATH` |

## Option B: Manual Steps (PowerShell)

Use this if the build script doesn't work for you or you prefer PowerShell.

First, make sure all tools are on your PATH. If "Step 4: Verify" above showed any tools as not found, add them now:

```powershell
$env:PATH = "C:\msys64\mingw64\bin;C:\Program Files (x86)\Arm GNU Toolchain arm-none-eabi\14.2 rel1\bin;$env:PATH"
```

Tell CMake where the Pico SDK is:

```powershell
$env:PICO_SDK_PATH = "$HOME\pico-sdk"
```

Go into the firmware folder and create a build directory:

```powershell
cd pico-fw
mkdir build
cd build
```

Configure the build. **Replace YOUR_WIFI_NAME and YOUR_WIFI_PASSWORD** with your actual WiFi credentials:

```powershell
cmake .. `
  -G Ninja `
  -DPICO_BOARD=pico2_w `
  -DWIFI_SSID='"YOUR_WIFI_NAME"' `
  -DWIFI_PASSWORD='"YOUR_WIFI_PASSWORD"'
```

> **Note:** The `-G Ninja` part is required. Without it, CMake won't know how to build on Windows.

Build the firmware:

```powershell
cmake --build . -j
```

This will take a minute or two. When it finishes, you should see `shinybot_pico_fw.uf2` in the `build` folder.

---

# Flash Pico

Now you need to copy the firmware file onto the Pico.

1. **Hold the BOOTSEL button** on the Pico 2 W (it's the small button on the board)
2. **While holding BOOTSEL**, plug the Pico into your PC with the USB cable
3. **Let go of BOOTSEL** after plugging in
4. Open **File Explorer** -- you should see a new drive appear called **RPI-RP2** (like a USB thumb drive)
5. Note the drive letter (usually `D:`, `E:`, or `F:`)
6. Copy the firmware file to that drive:

```powershell
Copy-Item pico-fw\build\shinybot_pico_fw.uf2 D:\
```

Replace `D:\` with whatever drive letter the Pico appeared as.

The Pico will **automatically reboot** and disappear from File Explorer -- this is normal. It's now running the firmware and trying to connect to your WiFi.

> **If the RPI-RP2 drive doesn't appear:** Make sure you're holding BOOTSEL *before* plugging in the USB cable. Also try a different USB port or cable.

---

# Test Pico Connection

The Pico should now be on your WiFi network. You need to find its IP address.

1. Log into your **router's admin page** (usually `192.168.1.1` or `192.168.0.1` in a browser)
2. Look for a connected device named **PicoW** or similar
3. Note its IP address (it will look something like `192.168.1.42`)

Now test the connection. **Replace PICO_IP with the actual IP** you found:

Check status:

```powershell
curl.exe http://PICO_IP:8080/status
```

You should see:

```
ready=1;queue=0;wifi=1
```

If you see this, the Pico is connected and working. Try sending a button press:

```powershell
curl.exe -X POST http://PICO_IP:8080/cmd -d "press A 120"
```

If the Pico is plugged into the Switch dock, you should see the A button press happen on screen.

Test reset (sends Home + X + A to reset the game):

```powershell
curl.exe -X POST http://PICO_IP:8080/reset
```

> **If you can't reach the Pico:** Make sure your PC and the Pico are on the same WiFi network. The Pico only supports 2.4 GHz WiFi, not 5 GHz. If your router has separate networks for each, make sure you used the 2.4 GHz network name when building the firmware.

---

# OBS Setup

Connect your hardware like this:

```
Switch Dock (HDMI out) --> Capture Card (HDMI in) --> PC (USB)
```

Then set up OBS:

1. Open **OBS Studio**
2. In the **Sources** panel (bottom of the screen), click the **+** button
3. Select **Video Capture Device**
4. Give it a name (like "Switch") and click OK
5. In the dropdown, select your capture card
6. Click OK

You should now see your Switch's screen inside OBS.

Now enable the **Virtual Camera** so the bot can read the video feed:

1. In OBS, click **Start Virtual Camera** (bottom right, next to "Start Recording")
2. Leave OBS open while the bot runs

> **Why Virtual Camera?** The capture card can only be used by one program at a time. Virtual Camera lets OBS hold the capture card while sharing the video with the bot through a virtual camera device.

---

# Test Shiny Detection

Place screenshots in your **Downloads** folder.

Test shiny screenshot:

```
python check_star.py --image shiny.jpg --show
```

Test normal screenshot:

```
python check_star.py --image normal.jpg --show
```

Test live capture (direct, OBS must be closed):

```
python check_star.py --watch-seconds 5 --show
```

Test live capture via OBS Virtual Camera (OBS can stay open):

```
python check_star.py --watch-seconds 5 --show --device 1
```

Expected output:

```
STAR_DETECTED
```

or

```
NO_STAR
```

---

# Test Button Sequence

Before running the full bot, test that the button sequence works. Make sure:

- The Switch is docked and on the FireRed/LeafGreen title screen
- The Pico is plugged into the Switch dock (as a controller)
- You've set the Pico IP address in `run_sequence.ps1` (open it in a text editor and change the `$PICO` line)

Run the sequence:

```powershell
powershell.exe -ExecutionPolicy Bypass -File run_sequence.ps1
```

Watch your Switch -- you should see it:

1. Reset the game (Home > X > A)
2. Continue the save
3. Select the starter
4. Open the summary screen

If the timing is off (buttons press too early or late), you can adjust the timing values at the top of `run_sequence.ps1`.

---

# Run the Bot

Almost there! Before starting:

1. Make sure OBS is open with **Virtual Camera** running
2. If using OBS Virtual Camera, open `hunt_loop.py` in a text editor and set `CAPTURE_DEVICE = 1`
3. Make sure the Switch is on the game's title screen

Start the hunt loop:

```powershell
python hunt_loop.py
```

The bot will now loop automatically -- resetting, picking the starter, checking for a shiny, and repeating. It will **stop on its own** when it finds a shiny.

Press **ESC** at any time to stop the bot manually.

**Prevent Windows from sleeping** (important for overnight hunts):

Go to **Settings > System > Power & sleep** and set sleep to **Never** while plugged in.

Or run this in PowerShell:

```powershell
powercfg /change standby-timeout-ac 0
```

> **Display sleep is fine** -- only system sleep will stop the bot. Your monitor can turn off.

---

# Runtime Files

The bot writes files that can be used for **OBS overlays**.

`hunt_state.json`

Stores attempt count and runtime.

`encounter_count.txt`

Example:

```
Encounters: 5421
```

`encounter_time.txt`

Example:

```
22:14:35
```

---

# Troubleshooting

## CMake says "No CMAKE_CXX_COMPILER could be found"

The Pico SDK needs a **host** C/C++ compiler (separate from the ARM cross-compiler) to build its internal tools (`pioasm`, `picotool`). Make sure MSYS2 is installed and `C:\msys64\mingw64\bin` is on your PATH.

## CMake can't find a generator

If you see errors about no build system generator, make sure Ninja is installed and on your PATH, and that you included `-G Ninja` in your cmake configure command.

## arm-none-eabi-gcc not found

The ARM toolchain installs to `C:\Program Files (x86)\Arm GNU Toolchain arm-none-eabi\14.2 rel1\bin`. Add this to your PATH or use the `build.sh` script which handles it automatically.

## Pico drive doesn't appear

Make sure you're holding **BOOTSEL** *before* plugging in the USB cable. The drive should appear as `RPI-RP2` in File Explorer within a few seconds.

## WiFi credentials

WiFi credentials are baked into the firmware at build time. If you change your WiFi network or password, you need to rebuild and re-flash the firmware.

---

# Notes

- The bot **stops automatically when a shiny star is detected**
- You must **manually save the shiny Pokemon**
- Display sleep is safe, but **system sleep must be disabled**
