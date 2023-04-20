[CmdletBinding()]
param (
	[String[]] $BTDeviceNames
	, [String[]] $BTLaunch
	, [Int] $coffeeInterval = 6
	, [Int] $coffeeTime = 0
) Set-Location $PSScriptRoot

function BTScan {
	if (!($coffeeTime -eq 0)) {
		$coffeeTime /= $coffeeInterval
		$coffeeTime++
	}
	while (--$coffeeTime) {
		.\BTToggle.ps1 Off
		.\BTToggle.ps1 On
		Start-Sleep $coffeeInterval
		if (IsBTDeviceConnected($BTDeviceNames)) { BTLaunch }
	}
}

function BTLaunch {
	$BTLaunch | ForEach-Object { &$_ }
	exit
}

function IsBTDeviceConnected ([String[]] $FriendlyName) {
	return (
		(
			Get-PnpDeviceProperty -InputObject (
				Get-PnpDevice | Where-Object {
					$FriendlyName -contains $_.FriendlyName
				}
			)
		) | Where-Object {
			$_.KeyName -eq '{83DA6326-97A6-4088-9453-A1923F573B29} 15'
		}
	).data -contains $True
}

BTScan
