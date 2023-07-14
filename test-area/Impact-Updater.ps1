#requires -version 3.0
#requires -RunAsAdministrator

. ./cfgMan.ps1 -get 'impact_path'

$FocusDelay = 20
$FocusAt = @(1160, 670)
. ./stable/LaunchIf.ps1 $impact_path -Admin -Online -Charging -Focus launcher -FocusAt $FocusAt -FocusDelay $FocusDelay

sleep 5
[Clicker]::LeftClickAtPoint($FocusAt[0], $FocusAt[1])
