[CmdletBinding()]
param(
	[string] $match_name
)
. ./cfgMan.ps1 -get steam_path
$proc_wait = 20
$max_wait = 600
$win_wait = 5
$toHide_WinsCount = 2


if (!$steam_path) { exit }
$proc_name = 'steamwebhelper'
# if (!$match_name) { exit }

function Launch-Steam-Minimized {
	Start-Process ($steam_path + "/steam.exe")
	if (!$?) { return $false } # if launch failed
	
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
	return $SteamID3
}
function Get-PairsFrom_ScreenshotsFile($userID) {
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
function Get-PairsFrom_ShortcutsFile {
	$pairtxt = Get-Content -Raw "$steam_path/userdata/$userID/config/shortcuts.vdf"
	$pairtxt = $pairtxt -csplit 'exe\0.*?appid\0' -csplit 'exe\0' -csplit 'appid\0'
	$cleantxt = $pairtxt[1..($pairtxt.Count - 2)] -replace '.$' -csplit '.appname\0'
	$pairs = @{}
	for ($i = 0; $i -lt $cleantxt.Count; $i += 2) {
		$pairs[$pairtxt[$i + 1]] = Decode-appID($pairtxt[$i]) # overwrite
	}
	return $pairs
}
function Decode-appID([string] $appIDtxt) {}
# if not running, launch and minimize Steam
if (!(Get-Process -ErrorAction Ignore $proc_name)) { 
	if (-not (Launch-Steam-Minimized) ) {
		'Launch failed' | Write-Verbose
		exit
	}
} # Steam must be running if control is here

