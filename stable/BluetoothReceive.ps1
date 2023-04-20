$wshell = New-Object -ComObject wscript.shell;
Start-Process fsquirt.exe
# $wshell.AppActivate('Untitled - Notepad')
While ((Get-Process fsquirt*).MainWindowHandle -eq 0) {
	# Increase wait time to accomodate for initialization (trial-error)
	Start-Sleep -Milliseconds 50
}
$wshell.SendKeys('{UP}{UP}{DOWN}{ENTER}')