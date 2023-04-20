$wshell = New-Object -ComObject wscript.shell;
# $wshell.AppActivate('Untitled - Notepad')
While ($true) {
	# Increase wait time to accomodate for initialization (trial-error)
	Start-Sleep -Milliseconds 100
	$wshell.SendKeys('t')
}