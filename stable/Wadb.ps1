param(
	[string] $Port,
	[switch] $NoDisconnect,
	[switch] $NoAck,
	[switch] $PassSerials
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
	Dispose() { $this.shell.Dispose() }
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
	$threads += foreach ($ip in $ips) {
		$ip += ':' + $portNumStr
		[RunspaceThread]::new().
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
			$thr.Dispose()
		}
	}while ($threads | Where-Object { !$_.IsCompleted() })
	$rsp.Close()
}
	

function QuietWadb {
	param(
		[string] $preferedPortNumStr
	)
	if (!(isValidPortNum $preferedPortNumStr)) { return }
	
	$reachableIPs = Get-ReachableIPs
	
	
	
	
}

function Get-ReachableIPs {
	$arpOut = arp -a
	$ifLines = $arpOut | sls 'Interface.*?(((\d+\.){3})\d+).*?(0x.*)$'
	$Subnets = @()
	$ifIndexes = @()
	$selfIPs = @()
	foreach ($line in $ifLines) {
		$Subnets += $line.Matches.Groups[2].Value
		$selfIPs += $line.Matches.Groups[1].Value
		$ifIndexes += $line.Matches.Groups[4].Value 
	}
	$foundIPs = @()
	$foundIPs += foreach ($i in $ifIndexes) {
		foreach ($neighbour in Get-NetNeighbor -InterfaceIndex $i -AddressFamily IPv4) {
			if (@('Permanent', 'Unreachable') -cnotcontains $neighbour.State) {
				$neighbour.IPAddress
			}
		}
	}
	$foundIPs #Output
	
	$dontPingIPs = $selfIPs + $foundIPs
	$toPingIPs = @()
	$toPingIPs += foreach ($mask in $Subnets) {
		foreach ($octet in 1..254) {
			$ip = $mask + $octet
			if ($dontPingIPs -cnotcontains $ip) { $ip }
		}
	}
	
	$script = { param($ip)
		if (Test-Connection $ip -Quiet -Count 1)
		{ $ip } #output
		elseif (Test-Connection $ip -Quiet)
		{ $ip } #output
	}
	$rsp = [runspacefactory]::CreateRunspacePool(1, $toPingIPs.count)
	$threads = @()
	$threads += foreach ($ip in $toPingIPs) {
		[RunspaceThread]::new().
		SetShell([powershell]::Create().
			AddScript($script).
			AddParameter('ip', $ip)).
		SetPool($rsp).BeginInvoke()
	}
	do {
		sleep -Milliseconds 100
		foreach ($thr in $threads | ? { 
				$_.IsOutputReady() }) {
			$thr.shell.Commands.Commands
			$thr.GetOutput() #Output
			$thr.Dispose()
		}
	}while ($threads | Where-Object { !$_.IsCompleted() })
	$rsp.Close()
}

Wadb
Get-Job | Remove-Job -Force

