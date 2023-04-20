[CmdletBinding()]
param (
	[String[]] $BTDeviceNames
	, [String[]] $BTLaunch
	, [Int] $coffeeInterval = 2
	, [Int] $coffeeTime = 60
)Set-Location $PSScriptRoot

function BTListen {
	$coffeeTime /= $coffeeInterval
	while ($coffeeTime--) {
		Write-Debug "coffee"
		if (IsBTDeviceConnected($BTDeviceNames)) { BTLaunch }
		Start-Sleep $coffeeInterval
	}
	Write-Debug "coffee-end"
	./BTScan $BTDeviceNames $BTLaunch
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

BTListen
