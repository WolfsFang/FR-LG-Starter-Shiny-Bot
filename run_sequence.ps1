$PICO = "http://YOUR_PICO_IP:8080"

# -----------------------
# Timing variables
# -----------------------

$RESET_TIME    = 5
$PRESS_GAP_MS  = 500   # pause between consecutive presses
$LOAD_TIME     = 0.5
$TEXT_TIME     = 0.5
$LONG_TEXT_TIME = 1
$DEFAULT_TIME  = 0.5

# -----------------------
# Start timer
# -----------------------

$START_TIME = [DateTime]::Now

# -----------------------
# Helper functions
# -----------------------

function Wait-Until {
    param([DateTime]$Deadline)
    $remaining = ($Deadline - [DateTime]::Now).TotalMilliseconds
    if ($remaining -gt 0) {
        Start-Sleep -Milliseconds ([int]$remaining)
    }
}

function Send-Command {
    param(
        [string]$Endpoint,
        [string]$Body = ""
    )
    $maxRetries = 4
    for ($i = 1; $i -le $maxRetries; $i++) {
        if ($Body) {
            $result = curl.exe -s --connect-timeout 2 --max-time 3 -X POST "$PICO/$Endpoint" -d $Body 2>&1
        } else {
            $result = curl.exe -s --connect-timeout 2 --max-time 3 -X POST "$PICO/$Endpoint" 2>&1
        }
        if ($LASTEXITCODE -eq 0 -and $result -eq "OK") {
            return $true
        }
        if ($i -lt $maxRetries) {
            Write-Warning "Pico command failed (attempt $i/$maxRetries): $Endpoint $Body"
            Start-Sleep -Milliseconds 200
        }
    }
    Write-Warning "Pico command FAILED after $maxRetries attempts: $Endpoint $Body"
    return $false
}

function Press {
    param(
        [string]$Button,
        [double]$Delay = $DEFAULT_TIME
    )

    Write-Host "Pressing $Button (delay $Delay)"

    Send-Command "cmd" "press $Button 300" | Out-Null

    $deadline = [DateTime]::Now.AddSeconds($Delay)
    Wait-Until $deadline
    if ($PRESS_GAP_MS -gt 0) {
        Start-Sleep -Milliseconds $PRESS_GAP_MS
    }
}

function Reset-Game {
    Write-Host "Resetting game"
    Send-Command "reset" | Out-Null
}

function Wait-Time {
    param([double]$Time)
    Write-Host "Waiting $Time seconds"
    $delayMs = [int]($Time * 1000)
    if ($delayMs -gt 0) {
        Start-Sleep -Milliseconds $delayMs
    }
}

# -----------------------
# Sequence
# -----------------------

Write-Host "Starting sequence..."

# Pre-flight check — verify Pico is reachable
$ping = (curl.exe -s --connect-timeout 2 --max-time 3 "$PICO/ping" 2>$null)
if ($LASTEXITCODE -ne 0 -or "$ping".Trim() -ne "pong") {
    Write-Error "Cannot reach Pico at $PICO - aborting sequence"
    exit 2
}
Write-Host "Pico connected"

Reset-Game
Wait-Time $RESET_TIME

Press "A" 5
Press "A" 5
Press "A" 5
Press "B" 3
Press "A" 2
Press "A" 2
Press "A" 2
Press "A" 2
Press "B" 4
Press "B" 2
Press "A" 6
Press "X" 2
Press "A" 2
Press "A" 2
Press "A" 2

Write-Host "Sequence complete"

# -----------------------
# End timer
# -----------------------

$END_TIME = [DateTime]::Now
$ELAPSED = ($END_TIME - $START_TIME).TotalSeconds

Write-Host "--------------------------------"
Write-Host ("Total runtime: {0:F3} seconds" -f $ELAPSED)
Write-Host "--------------------------------"
