[CmdletBinding()]
param(
	[string] $match_name
)
. ./cfgMan.ps1 -get steam_path
$proc_wait = 20
$max_wait = 600
$win_wait = 2
$toHide_WinsCount = 2


$steam_path += "/steam.exe"
$proc_name = 'steamwebhelper'
# if (!$match_name) { exit }

function Launch-Steam-Minimized {
	Start-Process $steam_path
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
			else { 'False' } ) | Write-Verbose
	}
	return $true
}

# if not running, launch and minimize Steam
if (!(Get-Process -ErrorAction Ignore $proc_name)) { 
	if (!Launch-Steam-Minimized) {
		'Launch failed' | Write-Verbose
		exit
	}
} # Steam must be running if control is here