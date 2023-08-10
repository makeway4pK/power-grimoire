param(
	[string] $match_name
)
. ./cfgMan.ps1 -get steam_path
$proc_wait = 20
$max_wait = 600
$wind_wait = 2

$steam_path += "/steam.exe"
$proc_name = 'steamwebhelper'
# if (!$match_name) { exit }

# if not running, launch and minimize Steam
if (!(Get-Process -ErrorAction Ignore $proc_name)) {
	Start-Process $steam_path
	if (!$?) { exit } # if launch failed
	
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
	
	# Watch new windows and hide them quickly
	$timeout = $wind_wait * 10
	while ($timeout--) {
		Start-Sleep -Milliseconds 100
		# Hide window, needs admin
		$wh::ShowWindow($hnd, 0)
	}
}