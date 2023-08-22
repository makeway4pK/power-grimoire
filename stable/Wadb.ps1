param(
	[switch] $Quiet,
	[string] $Port,
	[switch] $QNoDisconnect,
	[switch] $QNoAck,
	[switch] $QOutSerials
)

function Wadb {
	if (!(Get-Process -ErrorAction Ignore adb)) {
		do { adb start-server }
		while ($? -eq $false)
	}
	QuietWadb $Port
	return
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
function Find {
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
	return $FindOutput	
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
	if (!($QNoDisconnect)) { adb disconnect | Out-Null }
	
	
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

