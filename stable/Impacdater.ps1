#requires -RunAsAdministrator
# Author: @makeway4pK
# Description: Starts Genshin impact $process for downloading game update
#               Doesn't handle $process updates yet, doesn't limit the download,
#               but initiates shutsdown when Wifi connection is lost and $process is still up
[CmdletBinding()]
param()
. ./cfgMan.ps1 -get 'impact_path'
$process = 'launcher'
$title = 'Genshin Impact'

$ListenerDelay = 5
[int] $ClickerTimeout = 60
$DownloadBtn = @(1160, 670)

# Wait for Wifi connection
while (./stable/LaunchIf.ps1 -NotOnline) {
    "Waiting for network" | Write-Verbose
    Start-Sleep $ListenerDelay
}

# Launch the updater and press btn after default delay,
"Calling LaunchIf" | Write-Verbose
./stable/LaunchIf.ps1 -Launch $impact_path -Admin -Online -Charging -Focus $process

$wh = ./stable/addtype-WindowHandler.ps1
# Monitor connection and process while pinging btn
# (Don't know how to monitor network traffic yet)
./stable/addtype-Clicker.ps1
$ClickerTimeout /= $ListenerDelay
while ((./stable/LaunchIf.ps1 -Online) -and ($hnd = (Get-Process -ErrorAction Ignore $process).where({ $_.MainWindowTitle -eq $title }).MainWindowHandle)) {
    "Online and window found" | Write-Verbose
    if ($ClickerTimeout -and $wh::GetForegroundWindow() -eq $hnd) {
        "Clicking on Download btn" | Write-Verbose
        [Grim.Clicker]::LeftClickAtPoint($DownloadBtn[0], $DownloadBtn[1])
        $ClickerTimeout--
    }
    Start-Sleep $ListenerDelay
    "$ListenerDelay second delay..." | Write-Verbose
}
"Escaped listener loop" | Write-Verbose

# Initiate shutdown only if $process is still up,
#  implying exit reason was connection loss
if ($hnd = (Get-Process -ErrorAction Ignore $process).where({ $_.MainWindowTitle -eq $title }).MainWindowHandle) {
    "Process is still up" | Write-Verbose
    if ($wh::GetForegroundWindow() -eq $hnd) {
        "Window is in Foreground, attempting shutdown" | Write-Verbose
        ./stable/LaunchIf.ps1 -Launch shutdown -ArgStr /s, /hybrid, /t, 180, /c, '"Impact', Updater, 'ran,', time, to, 'sleep!"' -NotOnline 
    }
    else {
        # Don't shutdown if not in foreground
        "Window is not focused, stopping process" | Write-Verbose
        (Get-Process -ErrorAction Ignore $process).where({ $_.MainWindowTitle -eq $title }) | Stop-Process
    }
}
