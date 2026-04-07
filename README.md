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

Automated shiny hunting for **Pokémon FireRed / LeafGreen** on **Nintendo Switch** using a **Windows PC + Raspberry Pi Pico 2 W**.

The bot:

1. Resets the game  
2. Continues the save  
3. Selects the starter  
4. Opens the summary screen  
5. Detects the **shiny star** using OpenCV  
6. Stops automatically when a shiny is detected  

You can then **manually save the shiny Pokémon**.

---

# Hardware Required

- Nintendo Switch + Dock  
- Raspberry Pi **Pico 2 W**  
- HDMI Capture Card  
- Windows PC
- USB cable for Pico  

---

# Windows Setup

Install dependencies:

```
winget install Kitware.CMake
pip install opencv-python numpy
```

Required software:

- Python 3  
- OBS Studio  
- Pico SDK 2.0+

---

# Build Pico Firmware

Set Pico SDK path (PowerShell):

```powershell
$env:PICO_SDK_PATH = "$HOME\pico-sdk"
```

Navigate to firmware:

```powershell
cd pico-fw
mkdir build
cd build
```

Configure firmware with WiFi credentials:

```powershell
cmake .. `
  -DPICO_BOARD=pico2_w `
  -DWIFI_SSID='"YOUR_WIFI_NAME"' `
  -DWIFI_PASSWORD='"YOUR_WIFI_PASSWORD"'
```

Build firmware:

```
cmake --build . -j
```

Flash Pico:

1. Hold **BOOTSEL**
2. Plug Pico into your PC
3. Copy firmware to the `RPI-RP2` drive (check your drive letter in File Explorer):

```powershell
Copy-Item shinybot_pico_fw.uf2 D:\
```

The Pico will reboot and connect to WiFi.

---

# Test Pico Connection

Find the Pico IP address from your router.

Check status:

```powershell
curl.exe http://PICO_IP:8080/status
```

Expected response:

```
ready=1;queue=0;wifi=1
```

Test button press:

```powershell
curl.exe -X POST http://PICO_IP:8080/cmd -d "press A 120"
```

Test reset:

```powershell
curl.exe -X POST http://PICO_IP:8080/reset
```

---

# OBS Setup

1. Connect Switch Dock HDMI → Capture Card  
2. Connect Capture Card → PC
3. Open **OBS Studio**  
4. Add **Video Capture Device**  
5. Select the capture card  

Confirm the Switch video appears.

Start **Virtual Camera** in OBS (click "Start Virtual Camera") so the bot can read video while OBS is open.

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

Run the sequence:

```powershell
powershell.exe -ExecutionPolicy Bypass -File run_sequence.ps1
```

This should:

- reset the game  
- continue the save  
- select the starter  
- open the summary screen  

---

# Run the Bot

If using OBS Virtual Camera, set `CAPTURE_DEVICE = 1` in `hunt_loop.py`.

Start the hunt loop:

```
python hunt_loop.py
```

To prevent Windows from sleeping, disable sleep in **Power Settings** or run:

```powershell
powercfg /change standby-timeout-ac 0
```

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

# Notes

- The bot **stops automatically when a shiny star is detected**
- You must **manually save the shiny Pokémon**
- Display sleep is safe, but **system sleep must be disabled**
