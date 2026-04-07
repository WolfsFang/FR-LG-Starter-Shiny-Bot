# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project does

Automated shiny Pokémon hunting bot for FireRed/LeafGreen on Nintendo Switch. It loops:
1. Sends button sequences to the Switch via a Raspberry Pi Pico 2 W (USB HID over WiFi)
2. Checks a capture card feed for the yellow shiny star using OpenCV
3. Stops and alerts when a shiny is detected

## Running the bot

Install Python dependencies:
```
pip install opencv-python numpy
```

Configure the Pico IP in `run_sequence.ps1`:
```powershell
$PICO = "http://<pico-ip>:8080"
```

Run the main loop:
```
python hunt_loop.py
```

Test the button sequence alone:
```
powershell.exe -ExecutionPolicy Bypass -File run_sequence.ps1
```

Test shiny detection on a screenshot:
```
python check_star.py --image shiny.jpg --show
```

Test live capture detection for 5 seconds:
```
python check_star.py --watch-seconds 5 --show
```

If OBS is running, start OBS Virtual Camera and use `--device 1`:
```
python check_star.py --watch-seconds 5 --show --device 1
```

## Architecture

**`hunt_loop.py`** — orchestrator. Loops: runs `run_sequence.ps1` → runs `check_star.py`. Tracks attempt count and elapsed time, writing state to `hunt_state.json`, `encounter_count.txt`, and `encounter_time.txt` (used as OBS text overlay sources). ESC key stops the loop cleanly via `msvcrt`. `CAPTURE_DEVICE` selects which video device index to pass to `check_star.py` (set to `1` for OBS Virtual Camera).

**`run_sequence.ps1`** — sends HTTP POST requests to the Pico 2 W at `$PICO/cmd` and `$PICO/reset`. Each `Press` call posts `"press <BUTTON> <duration_ms>"` and then sleeps for the specified delay.

**`check_star.py`** — opens a capture device via DirectShow, crops to a fixed ROI (`LIVE_STAR_X1/Y1/X2/Y2`), and detects yellow pixels in HSV space. Requires 3 consecutive frames (`CONSECUTIVE_FRAMES_REQUIRED`) above `YELLOW_THRESHOLD` pixels to return exit code 0 (shiny). Exit code 1 = no shiny, 2 = error. Supports `--device N` to select the capture device index (use `--device 1` for OBS Virtual Camera when OBS is using the capture card).

**`pico-fw/src/main.c`** — Pico 2 W firmware. Hosts an HTTP server on port 8080 with endpoints `/cmd`, `/reset`, `/status`, `/ping`, `/ready`. Parses button commands into a queue (max 128) and replays them as USB HID reports to the Switch.

## Building Pico firmware

Requires CMake and the Pico SDK. From `pico-fw/`:
```
mkdir build && cd build
cmake .. -DPICO_BOARD=pico2_w -DWIFI_SSID='"YourSSID"' -DWIFI_PASSWORD='"YourPassword"'
cmake --build . -j
```

Flash `shinybot_pico_fw.uf2` by holding BOOTSEL on the Pico while plugging it in, then copying the `.uf2` to the `RPI-RP2` drive.

## Tuning detection

If detection is unreliable, adjust these constants in `check_star.py`:
- `CAPTURE_INDEX` — default capture card device index (try 0, 1, 2…), overridden by `--device`
- `LIVE_STAR_X1/Y1/X2/Y2` — ROI pixel coordinates for the shiny star on the summary screen
- `YELLOW_THRESHOLD` — minimum yellow pixel count to consider a frame a hit (default 120)
- `CONSECUTIVE_FRAMES_REQUIRED` — frames in a row required to confirm detection (default 3)

In `hunt_loop.py`:
- `CAPTURE_DEVICE` — device index passed to `check_star.py` (set to `1` for OBS Virtual Camera, `None` to use default)

Timing between button presses is tuned in `run_sequence.ps1` via the `$*_TIME` variables at the top.
