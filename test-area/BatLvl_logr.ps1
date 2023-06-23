. ./cfgMan.ps1 -get 'batLvl_logfile'

$delayMils = 500
$moment = Get-Date
"`n[[[[" + $moment.tostring() + "]]]] $delayMils millisecond delay" | ac $batLvl_logFile
$moment = $moment.ToFileTime()
while ($true) {
	$lvl = (wmic path win32_battery get EstimatedChargeRemaining)[2]
	$lvl | ac $batLvl_logFile
	$lvl
	sleep -Milliseconds $delayMils
}