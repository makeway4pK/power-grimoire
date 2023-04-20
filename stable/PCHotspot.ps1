Set-Location $PSScriptRoot
function PCHotspot {
	$engaged = $true
	$cout = ''
	do {
		Clear-Host
		',------------------,'
		'|    PC Hotspot    |'
		'"------------------"'
		netsh wlan show hostednetwork
		if ($cout.Length -ne 0) { [string]::new('_', 80) } else { '' }
		$cout
		''
		'  1 - Change SSID'
		'  2 - Change Password'
		'  3 - Control'
		$cin = $Host.UI.RawUI.ReadKey().Character.ToUInt16($null) - 48
		''
		switch ($cin) {
			0 { $engaged = $false }
			1 { $cout = ChangeSSID }
			2 { $cout = ChangePSWD }
			3 {
				try { ControlMenu }
				catch { $cout = $_.ToString() }
			}
			Default { $cout = 'Invalid input, try again! Numbers only' }
		}
	} while ($engaged)
}
function ControlMenu {
	net session 2>&1>$null
	$admin = $?
	if (!$admin) {
		throw "You need elevated(Admin) rights to access this menu." 
	}
	$engaged = $true
	$cout = ''
	do {
		Clear-Host
		',------------------,'
		'|    PC Hotspot    |'
		'"------------------"'
		netsh wlan show hostednetwork
		if ($cout.Length -ne 0) { [string]::new('_', 80) } else { '' }
		$cout
		''
		'  1 - Start  / Stop'
		'  5 - Enable / Disable [!]'
		$cin = $Host.UI.RawUI.ReadKey().Character.ToUInt16($null) - 48
		''
		switch ($cin) {
			0 { $engaged = $false }
			1 { $cout = ToggleStatus }
			5 { $cout = ToggleMode }
			Default { $cout = "Invalid input, try again! Numbers only" }
		}
	}while ($engaged)
}
function  ChangeSSID {
	$ssid = Read-Host -Prompt "New SSID"
	if ($ssid.Length -le 0) { return "No SSID entered!" }
	elseif ($ssid.Length -gt 32) { return "SSID cannot be longer than 32 characters!" }
	return netsh wlan set hostednetwork ssid="$ssid"
}
function  ChangePSWD {
	$pswd = Read-Host -Prompt "New Password"
	if ($pswd.Length -lt 8 -OR $pswd.Length -gt 63) {
		return "Password must be 8 to 63 characters long!"
	}
	return netsh wlan set hostednetwork key="$pswd"
}
function  ToggleMode {
	$cout = ""
	if (IsModeDisallowed) { return netsh wlan set hostednetwork mode=allow }
	else { 
		if (IsStatusStarted) { $cout += netsh wlan stop hostednetwork }
		$cout += netsh wlan set hostednetwork mode=disallow 
	}
	return $cout
}
function  ToggleStatus {
	$cout = ""
	if (IsStatusStarted) { return netsh wlan stop hostednetwork }
	else {
		if (IsModeDisallowed) { $cout += netsh wlan set hostednetwork mode=allow }
		$cout += netsh wlan start hostednetwork
	}
	return $cout
}
function  IsModeDisallowed {
	return [bool]( netsh wlan show hostednetwork | Select-String 'Mode' | Select-string 'Disallowed')
}
function  IsStatusStarted {
	return ![bool]( netsh wlan show hostednetwork | Select-String 'Status' | Select-string 'Not')
}

PCHotspot