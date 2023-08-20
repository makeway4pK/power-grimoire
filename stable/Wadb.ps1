param(
	[switch] $Quiet,
	[string] $Port,
	[switch] $QNoDisconnect,
	[switch] $QNoAck,
	[switch] $QOutSerials
)
. ./cfgMan.ps1 -get 'macStoreXml'
$macStoreXml = "$PSScriptRoot/../caches/WadbMacStore.xml"
function Wadb {
	if (!(Get-Process -ErrorAction Ignore adb)) {
		do { adb start-server }
		while ($? -eq $false)
	}
	if ($Quiet) {
		QuietWadb $Port
		return
	}
	else {
		# Clear-Host
		"Port `n"
		$portNumStr = getPortNumber
	}
	$engaged = $true
	$cout = ''
	$portNumStr
	do {
		Clear-Host
		',------------,'
		'|    Wadb    |'
		'"------------"'
		adb devices -l
		''
		' Use "Connect" to connect a known device'
		' Use "Find" to try connecting all devices'
		'available on the network with dynamic IP addresses'
		'and also remember those devices for future.'
		if ($cout.Length -ne 0) { [string]::new('_', 80) } else { '' }
		$cout
		''
		'  5 - Connect'
		'  8 - Find'
		''
		'  7 - Forget some'
		$cin = $Host.UI.RawUI.ReadKey().Character.ToUInt16($null) - 48
		switch ($cin) {
			0 { $engaged = $false }
			5 {
				$cout = Connect
			}
			8 {
				$cout = Find
			}
			7 { Forget }
			Default { $cout = 'Invalid choice, try again! Numbers only' }
		}
	} while ($engaged)
}
function isValidPortNum {
	param(
		[string] $portNumStr
	)
	$portNum = [uint16]$portNumStr
	if ($portNum -lt 1024 -OR $portNum -gt 65535) {
		# -OR ($portNum -gt )) 
		return $false
	}return $true
}
function getPortNumber {
	[string] $portNumStr = $null
	$reset = $true
	do {
		$cin = $Host.UI.RawUI.ReadKey().Character.ToUInt16($null) - 48
		$reset = ($cin -lt 0 -OR $cin -gt 9)
		if ($reset) {
			$portNumStr = $null
			Clear-Host
		}
		else {
			$portNumStr += $cin.ToString()
		}
		if ($portNumStr.Length -eq 5) {
			if (isValidPortNum $portNumStr) { }else {
				$reset = $true
				$portNumStr = ''
				Clear-Host
			}
		}
	} while ($portNumStr.Length -lt 5)
	return $portNumStr
}
function Connect {
	if (!(Test-Path $macStoreXml)) { return "Can't remember any devices, find some!" }
	$devices = Import-Clixml $macStoreXml
	if ($devices.count -eq 0) { return "Can't remember any devices, find some!" }
	$macs = [array]$devices.Keys
	$ips = @()
	$arp = @()
	$arp += arp -a
	foreach ($mac in $macs) {
		$ip = -split ($arp -match $mac)
		$ip = $ip -match '(\d+\.)+(\d+)'
		if ($ip.count -gt 0) { $ips += $ip[0] }
	}
	$jobs = @()
	if ($ips.count -eq 0) { return "No known devices available." }
	foreach ($ip in $ips) {
		$ip += ':' + $portNumStr
		$jobs += Start-Job { adb connect $Using:ip }
	}
	if ($jobs | Where-Object -Property 'State' -eq Running) {
		$ConnectOutput = ($jobs | Wait-Job  -Timeout 1) | Receive-Job
	}
	$jobs | Remove-Jobove-Job -Force
	if ([bool]($ConnectOutput -match 'connected to ')) {
		return $ConnectOutput
	}
	return "Connection refused by known devices.`n" + $ConnectOutput
}
function Find {
	if (Test-Path $macStoreXml) { $devices = Import-Clixml $macStoreXml }else {
		$devices = @{ }
	}
	$ips = @()
	$arp = @()
	$arp += arp -a
	$ips = -split ($arp -match 'dynamic')
	$ips = $ips -match '(\d+\.)+(\d+)'
	if ($ips.count -eq 0) { return 'No devices available.' }
	$FindOutput = @()
	$FoundIPs = @()
	$jobs = @()
	foreach ($ip in $ips) {
		$ip += ':' + $portNumStr
		$jobs += Start-Job { adb connect $Using:ip }
	}
	if ($jobs | Where-Object -Property 'State' -eq Running) {
		$FindOutput += ($jobs | Wait-Job -Timeout 1) | Receive-Job 
	}
	$jobs | Remove-Job -Force
	$FoundIPs = $FindOutput -match 'connected to'
	$FoundIPs = -split $FoundIPs -split ':' -match '(\d+\.)+(\d+)'
	if ($FoundIPs.count -eq 0) { return "Connection refused by all available devices.`n" + $FindOutput }
	foreach ($ip in $FoundIPs) {
		#success
		$mac = (( -split ($arp -match $ip)) -match '([\dabcdef]+-)+([\dabcdef])')[0]
		$model = (adb devices -l) -match $ip
		$model = -split $model
		$model = $model -match 'model:'
		$model = ($model -split ':')[1]
		$devices[$mac] = $model
	}
	$devices | Export-Clixml $macStoreXml
	return $FindOutput	
}
function Forget {
	if (Test-Path $macStoreXml) { $devices = Import-Clixml $macStoreXml }
	$forgetOut = ''
	do {
		Clear-Host
		',------------,'
		'|    Wadb    |'
		'"------------"'
		if ($devices.count -eq 0) { "Can't remember any devices, find some!" }else {
			$ctr = 1
			foreach ($device in $devices.getenumerator()) {
				' ' + $ctr + "`t" + $device.Name + "`t" + $device.Value
				$ctr++
			}
		}
		''
		'  Enter the number to forget that device'
		if ($forgetOut.Length -ne 0) { [string]::new('_', 80) } else { '' }
		$forgetOut
		if ($devices.count -lt 10) {
			$forgetChoice = $Host.UI.RawUI.ReadKey().Character.ToUInt16($null) - 48
		}
		else {
			$forgetChoice = (Read-Host).ToUInt16($null)
		}
		if ($forgetChoice -eq 0) { return }
		if ($forgetChoice -gt $devices.count -OR $forgetChoice -lt 0) { $forgetOut = 'Invalid choice! Choose between [1 - ' + $devices.count + ']' } else {
			$forgetChoice--
			$forgetOut = "Forgot`t" + ([array]$devices.Keys)[$forgetChoice] + "`t" + $devices[([array]$devices.Keys)[$forgetChoice]]
			$devices.Remove(([array]$devices.Keys)[$forgetChoice])
			$devices | Export-Clixml $macStoreXml
		}
	} while ($true)
}
function QuietWadb {
	param(
		[string] $preferedPortNumStr
	)
	if (!(isValidPortNum $preferedPortNumStr)) { return }
	
	$portNumStr = '5555'
	$null = Find
	$portNumStr = $preferedPortNumStr
	
	# asserting $preferedPortNumStr on all devices
	$sns = adb devices -l
	$temp = $sns[1..$sns.count] | Where-Object { $_.length -ne 0 }
	$sns = @()
	foreach ($sn in $temp) { $sns += , (-split $sn)[0] }
	$jobs = @()
	foreach ($sn in $sns) {
		$jobs += Start-Job {
			adb -s $Using:sn tcpip $Using:portNumStr
		}
	}
	if ($jobs | Where-Object -Property 'State' -eq Running) {
		$jobs | Wait-Job | Remove-Job -Force
	}
	$null = Find
	
	$sns = adb devices -l
	# $sns = $sns -match $portNumStr
	$temp = $sns[1..$sns.count] | Where-Object { $_.length -ne 0 }
	$sns = @()
	foreach ($sn in $temp) {
		$temp = -split $sn      
		$sns += , ($temp[0], ($temp -match 'device:' -split ':')[1])
	}
	if (!($QNoDisconnect)) {
		adb disconnect | Out-Null
	}
	$jobs = @()

	foreach ($sn in $sns) {
		$sn, $dn = $sn
		$jobs += Start-Job {
			adb connect $Using:sn | Out-Null
			if (!(adb devices -l) -match ($Using:sn)[0]) { return }
			adb -s $Using:sn wait-for-device
			
			"$Using:sn $Using:dn" # for serials output
			if (!($Using:QNoAck)) {
				adb -s $Using:sn shell input keyevent HOME
				adb -s $Using:sn shell input keyevent BACK
				adb -s $Using:sn shell input keyevent BACK
				adb -s $Using:sn shell 'input text \>'
				adb -s $Using:sn shell input text Hello\ $Using:dn\ \ !
			}
		}
	}
	while ($jobs | Where-Object -Property 'State' -eq Running) {
		$sns = $jobs | Wait-Job -Any | Receive-Job
		if ($QOutSerials) { $sns }
	}
	$jobs | Remove-Job -Force
}
Wadb
Get-Job | Remove-Job -Force

