param(
	[string] $match_name
)
. ./cfgMan.ps1 -get steam_path
# if (!$match_name) { exit }

#Check if Steam is already running launch and minimize if not running
if (!(Get-Process -ErrorAction Ignore steam)) {
	Start-Process $steam_path
	$wh = ./stable/addtype-WindowHandler.ps1
	$timeout = $max_wait * 2
	# wait for process and window handle
	while (!($hnd = (Get-Process -ErrorAction Ignore steam).where({ $_.MainWindowTitle }).MainWindowHandle) -and
		$timeout--) { sleep -Milliseconds 500 }
		
	# high freq finite wait for window, in case of quick launch
	$timeout *= 5
	while ( $hnd -ne $wh::GetForegroundWindow() -and $timeout--) {
		sleep -Milliseconds 100
	}
	# low freq indefinite wait for window, in case of update found
	while ( $hnd -ne $wh::GetForegroundWindow()) {
		# abort if steam process is lost for some reason
		if (!(Get-Process -ErrorAction Ignore steam)) { exit }
		sleep 1
	}
	if (!(Get-Process -ErrorAction Ignore steam)) { exit }
	
	# Hide window, needs admin
	# $wh::ShowWindow($hnd, 0)
	"handle Hidden" #dbg
	
	
	
}