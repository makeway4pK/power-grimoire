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
    
	# When a process named $Focus appears, click at $FocusAt
	# after $FocusDelay seconds
	# (1560,880) is bottom right
	, [string] $Focus
	, [int []] $FocusAt = @(780, 440)
	, [uint16] $FocusDelay = 10        
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
	&$Launch $ArgStr
	if (!$?) { return $false }
    
	if ($Focus) {
		Write-Host "Waiting for process named $Focus " -NoNewline
		While (!($window_handle = (Get-Process -ErrorAction Ignore $Focus).where({ $_.MainWindowTitle }, 'First').MainWindowHandle)) {
			Write-Host '.' -NoNewline
			# Increase wait time to accomodate for initialization (trial-error)
			Start-Sleep 1
		}
		''
		
		./stable/addtype-WindowShow.ps1
		if ([Grim.HandleWindow]::IsIconic($window_handle)) {
			Write-Host 'ShoWin() returned ' -NoNewline
			[Grim.HandleWindow]::ShowWindow($window_handle, 1)
			# ''
		}
		'asd'
		[Grim.HandleWindow]::GetForegroundWindow()
		'asd'
		# sleep 2
		if ($window_handle -ne [Grim.HandleWindow]::GetForegroundWindow()) {
			Write-Host 'SetFgW() returned ' -NoNewline
			[Grim.HandleWindow]::SetForegroundWindow($window_handle)
			# Read-Host
			# ''
		}
		''
		$FocusDelay++
		while (--$FocusDelay) {
			Write-Host "`rClicking at $($FocusAt[0]),$($FocusAt[1]) in $FocusDelay seconds     " -NoNewline
			Start-Sleep 1
		}
		Write-Host "`rClicking at $($FocusAt[0]),$($FocusAt[1]) now                                "
		./stable/addtype-Clicker.ps1
		#Send a click at a specified point
		[Grim.Clicker]::LeftClickAtPoint($FocusAt[0], $FocusAt[1])
	}
}
return $true