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
class RunspaceThread {
	hidden [powershell]$shell
	hidden [System.IAsyncResult]$handle
	[bool]$IsOutputProcessed = $false
	
	[bool]IsCompleted() { return $this.handle.IsCompleted }
	[bool]IsOutputReady() { return $this.IsCompleted() -and -not $this.IsOutputProcessed }
	[RunspaceThread]SetShell([powershell]$shell) {
		$this.shell = $shell
		return $this
	}
	[RunspaceThread]SetPool([System.Management.Automation.Runspaces.RunspacePool]$rsp) {
		if ($rsp.RunspacePoolStateInfo.State -eq 'BeforeOpen') { $rsp.Open() }
		if ($rsp.RunspacePoolStateInfo.State -eq 'Opened') { $this.shell.RunspacePool = $rsp }
		else { throw "RunspacePool couldn't be opened, it was in state: " + $rsp.RunspacePoolStateInfo.State }
		return $this
	}
	[RunspaceThread]BeginInvoke() {
		$this.handle = $this.shell.BeginInvoke()
		return $this
	}
	[System.Management.Automation.PSDataCollection[PSObject]]GetOutput() {
		if (-not $this.IsCompleted()) { return [System.Management.Automation.PSDataCollection[PSObject]]::new() }
		$out = $this.EndInvoke()
		$this.IsOutputProcessed = $true
		return $out
	}
	[System.Management.Automation.PSDataCollection[PSObject]]EndInvoke() {
		return $this.shell.EndInvoke($this.handle)
	}
}
function Find {
	$ips = @()
	$arp = @()
	$arp += arp -a
	$ips = -split ($arp -match 'dynamic')
	$ips = $ips -match '(\d+\.)+(\d+)'
	if ($ips.count -eq 0) { return 'No devices available.' }
	
	
	$script = { param($ip)
		adb connect $ip
	}
	$rsp = [runspacefactory]::CreateRunspacePool(1, $ips.count)
	$threads = @()
	foreach ($ip in $ips) {
		$ip += ':' + $portNumStr
		$threads += [RunspaceThread]::new().
		SetShell([powershell]::Create().
			AddScript($script).
			AddParameter('ip', $ip)).
		SetPool($rsp).
		BeginInvoke()
	}
	do {
		Start-Sleep -Milliseconds 100
		foreach ($thr in $threads | ? { 
				$_.IsOutputReady() }) {
			$output = $thr.GetOutput()
			if ($output -match 'connected to') {
				-split $output -split ':' -match '(\d+\.)+(\d+)'
			}
		}
	}while ($threads | Where-Object { $_.handle.isCompleted -eq $false })
	
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

