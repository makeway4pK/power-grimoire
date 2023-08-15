#   Description: Script for launching a program/command only if certain
#   	conditions are met and optionally focusing(by simulating a mouseclick)
#  Author: makeway4pK
[CmdletBinding(PositionalBinding = $false)]
param(
	[Parameter(ValueFromRemainingArguments = $true)]
	[string] $Launch    #command to launch
	, [string[]] $ArgStr

	, [switch] $Online
	, [switch] $Gamepad
	, [switch] $Charging
	, [switch] $Admin

	, [switch] $NotOnline
	, [switch] $NotGamepad
	, [switch] $NotCharging
	, [switch] $NotAdmin

	# When a process named $Focus appears,
	# bring it to focus after $FocusDelay seconds
	, [string] $Focus
	, [uint16] $FocusDelay = 0

	# Left-Click at $ClickAt
	# after $ClickDelay seconds
	# (1560,880) is bottom right
	, [int []] $ClickAt
	, [uint16] $ClickDelay = 0
)
# online if connected to any of the following networks
. ./cfgMan.ps1 -get 'wifi_IDs'

$ok = $true

if ($Admin -or $NotAdmin) {
	if ($Admin -and $NotAdmin) { return $false }
	if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
				[Security.Principal.WindowsBuiltInRole] "Administrator")) {	$ok = $false }
	if ($NotAdmin) { $ok -= 1 }
	if (!$ok) { return $false }
	# cancel if any condition not met
}

if ($Charging -or $NotCharging) {
	if ($Charging -and $NotCharging) { return $false }
	if (!(Get-WmiObject -class BatteryStatus -Namespace root\wmi).PowerOnline) {
		$ok = $false
	}
	if ($NotCharging) { $ok -= 1 }
	if (!$ok) { return $false }
	# cancel if any condition not met
}

if ($Online -or $NotOnline) {
	if ($Online -and $NotOnline) { return $false }
	$ok = $false
	$networks = netsh wlan show interfaces
	foreach ($ID in $wifi_ids) {
		if ($networks -match [regex]::Escape($ID)) {
			$ok = $true
			break
		}
	}
	if ($NotOnline) { $ok -= 1 }
	if (!$ok) { return $false }
	# cancel if any condition not met
}

# gamepad if 'game' or 'controller' found in any of Human Interface Devices' names
if ($Gamepad -or $NotGamepad) {
	if ($Gamepad -and $NotGamepad) { return $false }
	$ok = $false
	$HIDs = Get-PnpDevice -PresentOnly -Class "HIDClass"
	foreach ($device in $HIDs) {
		if (($device.name -imatch [regex]::Escape("game")) -or ($device.name -imatch [regex]::Escape("controller"))) {
			$ok = $true
			break
		}
	}
	if ($NotGamepad) { $ok -= 1 }
	if (!$ok) { return $false }
	# cancel if any condition not met
}



#launch if all chosen conditions met
if ($ok -and $Launch) {
	if ($Focus) { $preHandles = (Get-Process -ErrorAction Ignore $Focus).MainWindowHandle }
	"Launching '$Launch' with $($ArgStr.Count) arguments: $($ArgStr-join', ')" | Write-Verbose
	Invoke-Expression "$Launch $ArgStr"
	if (!$?) { return $false }

	if ($Focus) {
		$Focus = $Focus -replace '\.exe$'
		Write-Host -NoNewline "Waiting for a new window from a process named $Focus "
		Start-Sleep -Milliseconds 160 # avoids loop for quick windows
		While (!($new_handle = (Get-Process -ErrorAction Ignore $Focus
				).where({ $_.MainWindowTitle }
				).where({ $preHandles -notcontains $_.MainWindowHandle }, 'First'
				).MainWindowHandle)) {
			Write-Host -NoNewline '.'
			Start-Sleep 1
		}
		''
		$FocusDelay++
		while (--$FocusDelay) {
			Write-Host -NoNewline "`rWindow found, it'll be at the front in $FocusDelay seconds     "
			Start-Sleep 1
		}
		Write-Host -NoNewline "`rWindow found, "
		$wh = ./stable/addtype-WindowHandler.ps1
		if ($wh::IsWindow($new_handle)) {
			if ($new_handle -ne $wh::GetForegroundWindow()) {
				"bringing it forward now                               "
				$wh::ShowWindow($new_handle, 7) -and
				$wh::ShowWindow($new_handle, 9) | Out-Null
				if ($new_handle -eq $wh::GetForegroundWindow()) {
					"Window brought to front"
				}
				else { "Couldn't bring window forward" }
			}
			else { "already on top                              " }
		}
		else { "`rWindow was closed                              " }

		if ($ClickAt) {
			$ClickDelay++
			while (--$ClickDelay) {
				Write-Host -NoNewline "`rClicking at $($ClickAt -join ',') in $ClickDelay seconds     "
				Start-Sleep 1
			}
			Write-Host "`rClicking at $($ClickAt -join ',') now                                "
			./stable/addtype-Clicker.ps1
			#Send a click at a specified point
			[Grim.Clicker]::LeftClickAtPoint($ClickAt[0], $ClickAt[1])
		}
	}
}
return $true