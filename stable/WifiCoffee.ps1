[CmdletBinding()]
param (
	[Int] $coffeeTime = 60
	, $coffeeInterval = 0.5
) Set-Location $PSScriptRoot
$WifiGuy = "..\modules\bin\WlanScan.exe"

&$WifiGuy

. ./cfgMan.ps1 -get 'wifi_ids'

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