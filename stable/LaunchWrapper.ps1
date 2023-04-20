# Launches $Wrap(full path) and if specified, waits for $WrapWait(process name)
#  to start before launching $Launch(full path) and waits for it
#  (or $LaunchWait(process name) if specified) to exit before killing $Wrap
#  (or $WrapWait(process name) if specified)
param(
	[string[]]$Launch
	, [string[]]$Wrap
	, [string[]]$LaunchWait
	, [string[]]$WrapWait
	, [string[]]$WrapKill
	, $LaunchDelay
)

foreach ($WrapStep in $Wrap) {
	"Launching       : $WrapStep"
	Start-Process $WrapStep
}
if ($WrapWait) {
	foreach ($WrapStep in $WrapWait) {
		"Waiting for     : $WrapStep"
		While (!(Get-Process $WrapStep 2>$null)) {
			# specify $WrapWait if $Wrap isn't a file name or a wrapper
			# Increase wait time to accomodate for initialization (trial-error)
			Start-Sleep 1
		}
	}
}
""
if ($LaunchDelay) {
	"Delaying Launch : $LaunchDelay seconds"
	Start-Sleep $LaunchDelay
}
foreach ($LaunchStep in $Launch) {
	"Launching       : $LaunchStep"
	Start-Process $LaunchStep
}
if (!$LaunchWait) { $LaunchWait = (Get-ChildItem $Launch).BaseName }

foreach ($LaunchStep in $LaunchWait) {
	"Waiting for     : $LaunchStep"
	While (!(Get-Process $LaunchStep 2>$null)) {
		# specify $LaunchWait if $Launch isn't a file name or a wrapper
		# Increase wait time to accomodate for initialization (trial-error)
		Start-Sleep 1
	}
	"to finish..."
	Wait-Process -Name $LaunchStep
}

""
if ($WrapKill) {
	foreach ($WrapStep in $WrapKill) {
		"Killing         : $WrapStep"
		Stop-Process -Name $WrapStep
		exit
	}
}

if (!$WrapWait) { $WrapWait = (Get-ChildItem $Wrap).BaseName }
foreach ($WrapStep in $WrapWait) {
	"Killing         : $WrapStep"
	Stop-Process -Name $WrapStep
}