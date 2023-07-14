#requires -version 3.0
#requires -RunAsAdministrator

. ./cfgMan.ps1 -get 'impact_path'

$FocusDelay = 20
$FocusAt = @(1160, 670)
. ./stable/LaunchIf.ps1 $impact_path -Admin -Online -Charging -Focus launcher -FocusAt $FocusAt -FocusDelay $FocusDelay

while (./stable/LaunchIf.ps1 -NotOnline) {
	sleep 1	
}

while (./stable/LaunchIf.ps1 -Online) {
	[Clicker]::LeftClickAtPoint($FocusAt[0], $FocusAt[1])
	sleep 5
}

./stable/LaunchIf.ps1 shutdown -ArgStr /s, /hybrid, /t, 180, /c, '"Impact', Updater, 'ran,', time, to, 'sleep!"' -Online
