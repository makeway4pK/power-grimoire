[CmdletBinding()]
param (
	[Int] $coffeeTime = 60
	, $coffeeInterval = 0.5
) Set-Location $PSScriptRoot

. ./cfgMan.ps1 -get 'wifi_ids'

$WifiGuy = "..\modules\bin\WlanScan.exe"
if (!(test-path $WifiGuy)) {
	Write-Error "WlanScan.exe required for rescanning Wifi network list!
	Run this for more info:
	`t
	`t	help modules\WlanScan\WlanScan-decoder.ps1
	`t"
	return
}
&$WifiGuy

$ok = $false
$coffeeTime /= $coffeeInterval
$coffeeInterval *= 1000
while ($coffeeTime--) {
	Start-Sleep $coffeeInterval
	&$WifiGuy
	$networks = netsh wlan show interfaces
	foreach ($ID in $wifi_ids) {
		if ($networks -match [regex]::Escape($ID)) {
			$ok = $true
			break
		}
	}
	if ($ok) { exit }
}