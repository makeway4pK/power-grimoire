param(
	[string] $Port,
	[switch] $NoGreeting,
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
	hidden [System.Management.Automation.PSDataCollection[PSObject]]$Output

	[bool]IsRunning() { return $this.handle -and -not $this.handle.IsCompleted }
	[bool]IsOutputReady() { return -not $this.IsRunning() -and -not $this.IsOutputProcessed }
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
	[RunspaceThread]InvokeAsyncOutput() {
		$this.Output = [System.Management.Automation.PSDataCollection[PSObject]]::new()
		$this.handle = $this.shell.BeginInvoke($this.Output, $this.Output)
		return $this
	}
	[System.Management.Automation.PSDataCollection[PSObject]]GetAsyncOutput() {
		if ($this.IsOutputReady) { $this.IsOutputProcessed = $true }
		return $this.Output
	}
	[System.Management.Automation.PSDataCollection[PSObject]]EndInvoke() {
		$this.shell.EndInvoke($this.handle)
		$this.IsOutputProcessed = $true
		return $this.Output
	}
	Dispose() { $this.shell.Dispose() }
}
function ConnectOld([string[]]$ips, [string]$port) {
	if ($ips.count -eq 0) { return }
	
	$script = { param($ip)
		adb connect $ip
	}
	$rsp = [runspacefactory]::CreateRunspacePool(1, $ips.count)
	$threads = @()
	$threads += foreach ($ip in $ips) {
		$ip += ':' + $port
		[RunspaceThread]::new().
		SetShell([powershell]::Create().
			AddScript($script).
			AddParameter('ip', $ip )).
		SetPool($rsp).
		InvokeAsyncOutput()
	}
	do {
		foreach ($thr in $threads | ? {
				$_.IsOutputReady() }) {
			$output = $thr.GetAsyncOutput()
			if ($output -match 'connected to') {
				$output.split()[-1]
			}
			$thr.Dispose()
		}
	}while ($threads.where({ $_.IsRunning() }) -and -not (Start-Sleep -Milliseconds 100) )
	$rsp.Close()
}
function GetProcedure-ConnectOld() {
	return { param($ip)
		$output = adb connect $ip
		if ($output -match 'connected to') {
			$output.split()[-1]
		}
		return
	}
}
function Greet([string[]]$sns) {
	if ($sns.count -eq 0) { return }
	
	$script = { param($sn)
		$txt = adb devices -l
		$txt = $txt -match $sn
		# return if no match for given ip
		if (!$txt) { return }
		
		# split line into tokens
		$txt = $txt.foreach({ , -split $_ })
		# in case there are multiple entries from, say, stale ports,
		# select the one with 'device' status
		$txt = $txt.where({ $_ -eq 'device' }, 'First')[0]
		# return if no device is ready for commands
		if (!$txt) { return }
		
		# connection confirmed
		# extract model field as name of the device
		$name = -split $txt -match 'model' -split ':' -replace '[^a-z0-9]', ' '
		$name = (Get-culture).TextInfo.ToTitleCase($name[1].toLower())
		# serial number will be the 1st field
		$sn = $txt[0]
		# send Greet notif
		$null = adb -s $sn shell cmd notification post -t "'ADB connected'" WadbGreeting "'Hello, $name !'"
		$sn #output
	}
	$rsp = [runspacefactory]::CreateRunspacePool(1, $ips.count)
	$threads = @()
	$threads += foreach ($sn in $sns) {
		[RunspaceThread]::new().
		SetShell([powershell]::Create().
			AddScript($script).
			AddParameter('sn', $sn)).
		SetPool($rsp).
		InvokeAsyncOutput()
	}
	do {
		foreach ($thr in $threads | ? {
				$_.IsOutputReady() }) {
			$thr.GetAsyncOutput()
			$thr.Dispose()
		}
	}while ($threads.where({ $_.IsRunning() }) -and -not (Start-Sleep -Milliseconds 100) )
	$rsp.Close()
}
function GetProcedure-Greet {
	return { param($sn)
		$txt = adb devices -l
		$txt = $txt -match $sn
		# return if no match for given ip
		if (!$txt) { return }
		
		# split line into tokens
		$txt = $txt.foreach({ , -split $_ })
		# in case there are multiple entries from, say, stale ports,
		# select the one with 'device' status
		$txt = $txt.where({ $_ -eq 'device' }, 'First')[0]
		# return if no device is ready for commands
		if (!$txt) { return }
		
		# connection confirmed
		# extract model field as name of the device
		$name = -split $txt -match 'model' -split ':' -replace '[^a-z0-9]', ' '
		$name = (Get-culture).TextInfo.ToTitleCase($name[1].toLower())
		# serial number will be the 1st field
		$sn = $txt[0]
		# send Greet notif
		$null = adb -s $sn shell cmd notification post -t "'ADB connected'" WadbGreeting "'Hello, $name !'"
		$sn #output
	}
}
function QuietWadb {
	param(
		[string] $port
	)
	if (!(isValidPortNum $port)) { return }

	$reachableIPs = Get-ReachableIPs
	$connectedSNs = ConnectOld $reachableIPs $port
	$Greetd = Greet $connectedSNs
	$Greetd
	
	$connectedIPs = $connectedSNs.foreach({ ($_ -split ':')[0] })
	$switchPortIps = $reachableIps.where({ $_ -notin $connectedIPs })
	$connected2 = ConnectNew $switchPortIps $port
	$Greetd = Greet $connected2
	$Greetd
}

function Wadb-Async {
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
	$foundIPs
	
	$ConnectOld_Procedure = [string](GetProcedure-ConnectOld)
	$ConnectNew_Procedure = [string](GetProcedure-ConnectNew)
	if (!$NoGreeting) {
		$ConnectOld_Procedure += "`n" + [string](GetProcedure-Greet)
		$ConnectNew_Procedure += "`n" + [string](GetProcedure-Greet)
	}
	
	# create threads to connect to old ips, input iplist and port
	
	# create threads to connect to new ips, input iplist and port
	
	# wait for output from any of all threads
	
	
	
}

function ConnectNew([string[]]$ips, [string]$port) {
	if (!$ips.count) { return }
	$script = { param($ip, $port)
		# attempt connection with default port
		if ((adb connect $ip) -notmatch 'connected to') { return }
		
		# send tcpip cmd to switch adbd to preferred port
		$null = adb -s $ip`:5555 tcpip $port
		# connect to the newly opened port
		$null = adb connect $ip`:$port
		# confirm connection
		$confirm = (adb devices) -match $ip
		$confirm = -split $confirm
		if ($confirm[1] -eq 'device') {
			$confirm[0] #output
		}
	}
	$rsp = [runspacefactory]::CreateRunspacePool(1, $ips.count)
	$threads = @()
	$threads += foreach ($ip in $ips) {
		[RunspaceThread]::new().
		SetShell([powershell]::Create().
			AddScript($script).
			AddParameters(@{'ip' = $ip; 'port' = $port })).
		SetPool($rsp).
		InvokeAsyncOutput()
	}
	do {
		foreach ($thr in $threads | ? {
				$_.IsOutputReady() }) {
			$thr.GetAsyncOutput()
			$thr.Dispose()
		}
	}while ($threads.where({ $_.IsRunning() }) -and -not (Start-Sleep -Milliseconds 100) )
	$rsp.Close()
}
function GetProcedure-ConnectNew {
	return { param($ip, $port)
		# attempt connection with default port
		if ((adb connect $ip) -notmatch 'connected to') { return }
	
		# send tcpip cmd to switch adbd to preferred port
		$null = adb -s $ip`:5555 tcpip $port
		# connect to the newly opened port
		$null = adb connect $ip`:$port
		# confirm connection
		$confirm = (adb devices) -match $ip
		$confirm = -split $confirm
		if ($confirm[1] -eq 'device') {
			$confirm[0] #output
		}
	}
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
		$timeout = 1
		$tries = 1
		while ($tries--) {
			if (Test-Connection $ip -Quiet -Delay $timeout -Count 1) { break }
		}
		if ($tries -gt -1) { $ip }
	}
	$rsp = [runspacefactory]::CreateRunspacePool(1, $toPingIPs.count)
	$threads = @()
	$threads += foreach ($ip in $toPingIPs) {
		[RunspaceThread]::new().
		SetShell([powershell]::Create().
			AddScript($script).
			AddParameter('ip', $ip)).
		SetPool($rsp).InvokeAsyncOutput()
	}
	do {
		foreach ($thr in $threads | ? {
				$_.IsOutputReady() }) {
			$thr.GetAsyncOutput() #Output
			$thr.Dispose()
		}
	}while ($threads.where({ $_.IsRunning() }) -and -not (Start-Sleep -Milliseconds 100) )
	$rsp.Close()
}

Wadb
Get-Job | Remove-Job -Force

