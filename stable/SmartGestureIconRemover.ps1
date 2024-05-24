# Created: 5Mar2020 8pm

# This script is a workaround, to be placed in shell:startup, that starts the app
#   and kills the app UI process to initialize the background ASUS TouchPad services. This
#   method is necessary because the helper process needs to be initialised by
#   loader exe.


. ./cfgMan.ps1 -get 'asusSG_path'

Get-Process AsusTP* -ErrorAction Ignore | Stop-Process
Start-Process ($asusSG_path + '\AsTPCenter\x64\AsusTPLoader.exe') -ErrorAction Stop
While ((Get-Process AsusTPCenter* -ErrorAction Ignore).length -eq 0) {
    # Increase wait time to accomodate for initialization (trial-error)
    Start-Sleep -Milliseconds 200
}
Stop-Process -Name 'AsusTPLoader'