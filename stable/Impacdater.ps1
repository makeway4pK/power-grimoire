#requires -RunAsAdministrator
# Author: @makeway4pK
# Description: Starts Genshin impact $process for downloading game update
#               Doesn't handle $process updates yet, doesn't limit the download,
#               but initiates shutsdown when Wifi connection is lost and $process is still up
. ./cfgMan.ps1 -get 'impact_path'
$process = 'launcher'
$title = 'Genshin Impact'

$ListenerDelay = 5
$ClickerTimeout = 60
$DownloadBtn = @(1160, 670)

# Wait for Wifi connection
while (./stable/LaunchIf.ps1 -NotOnline) {
    Start-Sleep $ListenerDelay
}

# Launch the updater and press btn after default delay,
./stable/LaunchIf.ps1 -Launch $impact_path -Admin -Online -Charging -Focus $process

# Monitor connection and process while pinging btn
# (Don't know how to monitor network traffic yet)
./stable/addtype-Clicker.ps1
$ClickerTimeout /= $ListenerDelay
while ((./stable/LaunchIf.ps1 -Online) -and (Get-Process -ErrorAction Ignore $process).where({ $_.mainWindowTitle -eq $title })) {
    if ($ClickerTimeout) {
        [Grim.Clicker]::LeftClickAtPoint($DownloadBtn[0], $DownloadBtn[1])
        $ClickerTimeout--
    }
    Start-Sleep $ListenerDelay
}

# Initiate shutdown only if $process is still up,
#  implying exit reason was connection loss
if ($hnd = (Get-Process -ErrorAction Ignore $process).where({ $_.MainWindowTitle -eq $title }).MainWindowHandle) {
    if ((./stable/addtype-WindowHandler.ps1)::GetForegroundWindow() -eq $hnd) {
        ./stable/LaunchIf.ps1 shutdown -ArgStr /s, /hybrid, /t, 180, /c, '"Impact', Updater, 'ran,', time, to, 'sleep!"' -NotOnline 
    }
    else {
        # Don't shutdown if not in foreground
        (Get-Process -ErrorAction Ignore $process).where({ $_.MainWindowTitle -eq $title }) | Stop-Process
    }
}
