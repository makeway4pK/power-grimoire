[CmdletBinding(PositionalBinding = $false)]
param(
	[Parameter(ValueFromRemainingArguments = $true)]
	[string] $appname
)
. ./cfgMan.ps1 -get steam_path
$proc_wait = 120
$max_wait = 600
$win_wait = 30
$toHide_WinsCount = 2


if (-not $steam_path) { exit }
$proc_name = 'steamwebhelper'
if (-not $appname) { exit }
Write-Verbose "Ministeam is looking for '$appname'"
function Main {
	$userID = Get-SteamUser
	if (-not $userID) {
		"No Steam user found, aborting"
		exit
	}
	$apps = Get-appIDs-fromShortcuts.vdf ($userID)

	# launch app
	if ($apps[$appname]) {
		$coldLaunch = -not [bool](Get-Process Steam* -ErrorAction Ignore)
		Start-Process "steam://rungameid/$($apps[$appname].id)" 
		if ($?) { 
			net session 2>&1>$null
			if ($?) { Keep-Steam-Minimized } else {
				"Cannot Minimize Steam: Run script with admin privileges to fix" | Write-Verbose
			}
		}
		else {
			"'$appname' was not found in these appnames:`n"
			foreach ($key in $apps.keys) { "$($apps[$key].id)`t$key" }
		}
	}
}
function Keep-Steam-Minimized {
	
	$wh = ./stable/addtype-WindowHandler.ps1
	
	if ($coldLaunch) {
		# wait for updater, could take long
		"Awaiting updater, timeout: $max_wait seconds..." | Write-Verbose
		$timeout = $max_wait
		while (-not(Get-ProcessByTitle('Sign in to Steam')) -and $timeout--) # Avoids interrupting update dialog
		{ Start-Sleep 1 }
		# abort if not on schedule
		if ($timeout -le 0)
		{ "Timeout!" | Write-Verbose; return $false }
	
		# wait for process and window handle
		"Awaiting login, timeout: $proc_wait seconds..." | Write-Verbose
		$timeout = $proc_wait * 2
		while (-not(Get-ProcessByTitle('Steam')) -and $timeout--) # Avoids interrupting login dialog
		{ Start-Sleep -Milliseconds 500 }
		# abort if not on schedule
		if ($timeout -le 0)
		{ "Timeout!" | Write-Verbose; return $false }
	}
	# Watch new windows and hide them quickly
	"Hiding Windows, timeout: $win_wait seconds..." | Write-Verbose
	$timeout = $win_wait * 10
	$toHide = $toHide_WinsCount
	$minerUnseen = $true
	while ($timeout-- -and ($toHide -or $minerUnseen)) {
		Start-Sleep -Milliseconds 100
		# Hide window, needs admin
		if ($toHide) {
			if (($hnd = (Get-ProcessByTitle('Steam')).MainWindowHandle)) {
				"Window hidden: " + $(
					if ($wh::ShowWindow($hnd, 0)) { $toHide-- | Out-Null; 'Yes' }
					else { 'No' } ) | Write-Verbose
			}
		}
		
		if (($miner = Get-ProcessByTitle('Launching...')) -and -not(Get-Process $apps[$appname].exe -ErrorAction Ignore)) {
			Stop-Process $miner #fixes frozen "Launching" phase
			$minerUnseen = $false
			"Stopped pid:$($miner.Id)`nNow awaiting new Steam windows, timeout: $win_wait seconds..." | Write-Verbose
			$timeout = $win_wait * 10
			$toHide = $toHide_WinsCount
		}
	}
	# abort if not on schedule
	if ($timeout -le 0)
	{ "Timeout!" | Write-Verbose; return $false }
	
	return $true
}
function Get-ProcessByTitle([string] $title) {
	return (Get-Process -ErrorAction Ignore $proc_name).where(
		{ $_.MainWindowTitle -eq $title }
	)
}
function Await-App {
	$timeout = $max_wait
	"Awaiting app launch" | Write-Verbose
	while (-not (Get-Process -ErrorAction Ignore ($apps[$appname].exe)) -and $timeout--)
	{ Start-Sleep 1 }
	"App launch detected" | Write-Verbose
	return $true
}
function Get-SteamUser {
	$SteamID3 = reg query HKCU\Software\Valve\Steam\ActiveProcess
	$SteamID3 = $SteamID3 -match 'ActiveUser' -split ' ' -match '0x'
	$SteamID3 = [uint32]$SteamID3[0]
	if ($SteamID3) { return $SteamID3 }
	"Active user not found in registry" | Write-Verbose
	
	$SteamID3s = (Get-ChildItem "$steam_path/userdata").BaseName
	if ($SteamID3s.count -eq 0) { return 0 }
	if ($SteamID3s.count -eq 1) { return $SteamID3s }
	$last_ID3 = 0
	$last_time = [System.DateTime]::new('')
	foreach ($ID3 in $SteamID3s) {
		$time = (Get-Item "$steam_path/userdata/$ID3/config").LastWriteTime
		if ($time -gt $last_time) {
			$last_ID3 = $ID3
			$last_time = $time
		}
	}
	return $last_ID3
}
function Decode-appID([char[]] $appIDtxt) {
	[uint64]$appID = 0
	"Decoding: $appIDtxt, counts as $($appIDtxt.Count)" | Write-Verbose
	if (-not($appIDtxt -is [Array])) {
		$appIDtxt = $appIDtxt.ToCharArray()
		" split to: $($appIDtxt.count)" 
	}
	foreach ($byte in $appIDtxt) {
		$appID = $appID -shr 8 -bor [uint64]$byte -shl 56
		"    parsing: $([uint64]$byte)" | Write-Verbose
	}
	return $appID -bor 1 -shl 25
}
function isArrSame([Array]$both) {
	$A, $B = $both
	if ($A.count -ne $B.count) { return $false }
	if (-not$A.count) { return $A.GetType() -eq $B.GetType() }
	for ($i = 0; $i -lt $A.count; $i++) {
		if ($A[$i] -ne $B[$i]) {
			"'$($A[$i])' doesn't match '$($B[$i])'" | Write-Verbose
			return $false
		}
	}
	return $true
}
function Get-appIDs-fromShortcuts.vdf($userID) {
	[int[]]$bytes = Get-Content -Encoding Byte -Raw "$steam_path/userdata/$userID/config/shortcuts.vdf"
	$id_tag = @(2, 97, 112, 112, 105, 100, 0)
	$name_tag = @(1, 97, 112, 112, 110, 97, 109, 101, 0)
	$exe_tag = @(1, 101, 120, 101, 0)
	$apps = @{}
	for ($next, $i = 1, (1 + $bytes.IndexOf($id_tag[0])); $next -gt 0; 
		$i += 2 + ($next = $bytes[($i + 1)..($bytes.Count - 1)].IndexOf($id_tag[0]))) {
		$matchWith = $id_tag[1..($id_tag.count - 1)]
		if (-not(isArrSame($bytes[$i..($i + $matchWith.Count - 1)], $matchWith))) {
			continue
		}
		$i += $matchWith.Count
		
		$appIDtxt = $bytes[$i..($i + 3)]
		$i += 5
		
		$matchWith = $name_tag[1..($name_tag.count - 1)]
		if (-not(isArrSame($bytes[$i..($i + $matchWith.Count - 1)], $matchWith))) {
			'Name tag unexpectedly not found' | Write-Verbose
			continue
		}
		$i += $matchWith.Count
		
		$name_len = $bytes[$i..($bytes.Count - 1)].IndexOf(0)
		$appNametxt = [char[]]$bytes[$i..($i + $name_len - 1)] -join ''
		$i += $name_len + 2
		
		$matchWith = $exe_tag[1..($exe_tag.count - 1)]
		if (-not(isArrSame($bytes[$i..($i + $matchWith.Count - 1)], $matchWith))) {
			'Exe tag unexpectedly not found' | Write-Verbose
			continue
		}
		$i += $matchWith.Count
		
		$exe_len = $bytes[$i..($bytes.Count - 1)].IndexOf(0)
		$exeNametxt = [char[]]$bytes[$i..($i + $exe_len - 1)] -join ''
		if ($exeNametxt -match '\\([^\\]*).exe') {
			$exeNametxt = $Matches.1
		}
		else {
			'Exe name unexpectedly not found' | Write-Verbose
			continue
		}
		$i += $exe_len + 2
		
		$apps[$appNametxt] = [app]::new()
		$apps[$appNametxt].id = Decode-appID($appIDtxt)
		$apps[$appNametxt].exe = $exeNametxt
		if ($appNametxt -eq $appname) { return  $apps }
	}
	return $apps
}

class app {
	[string]$id
	[string]$exe
}

Main