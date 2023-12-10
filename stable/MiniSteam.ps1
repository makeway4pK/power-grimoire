[CmdletBinding(PositionalBinding = $false)]
param(
	[Parameter(ValueFromRemainingArguments = $true)]
	[string] $appname
)
. ./cfgMan.ps1 -get steam_path
$proc_wait = 20
$max_wait = 600
$win_wait = 5
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
	$pairs = Get-appIDs-fromScreenshots.vdf ($userID)
	$add = Get-appIDs-fromShortcuts.vdf ($userID)
	foreach ($key in $add.keys) { $pairs[$key] = $add[$key] }

	# Finally, launch apps
	$notFound = @()
	[bool]$anyLaunched = $false
	# foreach ($app in $appnames) {
	# 	if ($pairs[$app]) {
	# 		Start-Process "steam://rungameid/$($pairs[$app])" 
	# 		$anyLaunched = $anyLaunched -or $?
	# 	}
	# 	else { $notFound += $app }
	# }
	if ($pairs[$appname]) {
		Start-Process "steam://rungameid/$($pairs[$appname])" 
		$anyLaunched = $anyLaunched -or $?
	}
	else { $notFound += $appname }
	
	if ($notFound.count -ne 0) {
		"'$($notFound-join"', '")' were not found in these appnames:`n"
		$pairs
	}
	if ($anyLaunched) { 
		net session 2>&1>$null
		if ($?) { Keep-Steam-Minimized } else {
			"Cannot Minimize Steam: Run script with admin privileges to fix" | Write-Verbose
		}
	}
}
function Keep-Steam-Minimized {
	
	$wh = ./stable/addtype-WindowHandler.ps1
	# wait for process and window handle
	$timeout = $proc_wait * 2
	while (!($hnd = (Get-Process -ErrorAction Ignore $proc_name).where(
				{ $_.MainWindowTitle -eq 'Steam' } # Avoids interrupting update dialog
			).MainWindowHandle) -and $timeout--)
	{ Start-Sleep -Milliseconds 500 }
	$timeout = $max_wait
	while (!($hnd = (Get-Process -ErrorAction Ignore $proc_name).where(
				{ $_.MainWindowTitle -eq 'Steam' } # Avoids interrupting update dialog
			).MainWindowHandle) -and $timeout--)
	{ Start-Sleep 1 }
	if ($timeout -le 0) { return $false }
	# Watch new windows and hide them quickly
	$timeout = $win_wait * 10
	while ($timeout-- -and $toHide_WinsCount) {
		Start-Sleep -Milliseconds 100
		# Hide window, needs admin
		"Window found: " + $(
			if ($wh::ShowWindow($hnd, 0)) { $toHide_WinsCount-- | Out-Null; 'True' }
			else { 'No' } ) | Write-Verbose
	}
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
function Get-appIDs-fromScreenshots.vdf($userID) {
	$pairtxt = Get-Content -Raw "$steam_path/userdata/$userID/760/screenshots.vdf"
	$pairtxt = $pairtxt -split 'shortcutnames.*'
	$pairtxt = $pairtxt[1] -split "`n" -match '.*".*'
	$pairtxt = $pairtxt -split '"' | Where-Object Length -gt 2
	$pairs = @{}
	for ($i = 0; $i -lt $pairtxt.Count; $i += 2) {
		$pairs[$pairtxt[$i + 1]] = $pairtxt[$i] # overwrite
	}
	return $pairs
}
# function Get-PairsFrom_ShortcutsFile($userID) {
# 	$pairtxt = Get-Content -Encoding UTF7 -Raw "$steam_path/userdata/$userID/config/shortcuts.vdf"
# 	$pairtxt = $pairtxt -csplit 'exe\0.*?appid\0' -csplit 'exe\0' -csplit 'appid\0'
# 	$pairtxt | write-verbose
# 	$cleantxt = $pairtxt[1..($pairtxt.Count - 2)] -replace '.$' -csplit '.appname\0'
# 	$pairs = @{}
# 	for ($i = 0; $i -lt $cleantxt.Count; $i += 2) {
# 		$pairs[$cleantxt[$i + 1]] = Decode-appID($cleantxt[$i]) # overwrite
# 		$cleantxt[$i + 1] + ": " + $cleantxt[$i] | Write-Verbose
# 	}
# 	return $pairs
# }
function Decode-appID([char[]] $appIDtxt) {
	[uint64]$appID = 0
	"Decoding: $appIDtxt, counts as $($appIDtxt.Count)" | Write-Verbose
	if (!($appIDtxt -is [Array])) {
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
	if (!$A.count) { return $A.GetType() -eq $B.GetType() }
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
	$tail_tag = @(0, 1)
	$pairs = @{}
	for ($next, $i = 1, (1 + $bytes.IndexOf($id_tag[0])); $next -gt 0; 
		$i += 2 + ($next = $bytes[($i + 1)..($bytes.Count - 1)].IndexOf($id_tag[0]))) {
		$matchWith = $id_tag[1..($id_tag.count - 1)]
		if (!(isArrSame($bytes[$i..($i + $matchWith.Count - 1)], $matchWith))) {
			continue
		}
		$i += $matchWith.Count
		
		$appIDtxt = $bytes[$i..($i + 3)]
		$i += 5
		
		$matchWith = $name_tag[1..($name_tag.count - 1)]
		if (!(isArrSame($bytes[$i..($i + $matchWith.Count - 1)], $matchWith))) {
			'Name tag not found unexpectedly' | Write-Verbose
			continue
		}
		$i += $matchWith.Count
		
		$name_len = $bytes[$i..($bytes.Count - 1)].IndexOf($tail_tag[0])
		$appNametxt = [char[]]$bytes[$i..($i + $name_len - 1)] -join ''
		$i += $name_len + 1
		
		$matchWith = $tail_tag[1..($tail_tag.count - 1)]
		if (!(isArrSame($bytes[$i..($i + $matchWith.Count - 1)], $matchWith))) {
			'Tail tag not found unexpectedly' | Write-Verbose
			continue
		}
		$i += $matchWith.Count
		
		$pairs[$appNametxt] = Decode-appID($appIDtxt)
		if ($appNametxt -eq $appname) { return }
	}
	return $pairs
}

Main