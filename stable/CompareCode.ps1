param(
	[Switch]$Deploy,
	[Switch]$PairedCompare,
	[Switch]$GroupedCompare
)
if ($Deploy) {
	$VScodeXe = (Get-ChildItem($env:path -split ';' -match 'VS Code' -replace 'bin') | Where-Object -Property Name -eq 'Code.exe').FullName
	if (!$VScodeXe) {
		Write-Error -Message "`n`nVS code executable not found!`n Make sure VS code is installed and `n available in the path variable before trying again" -Category ResourceUnavailable
		return
	}
	[string]$pwsh = Resolve-Path "$PSScriptRoot/../modules/bin/powershellw.exe"
	if (!$pwsh) {
		$pwsh = 'powershell' 
	}
	$ScriptPath = "$PSScriptRoot/" + $MyInvocation.MyCommand
	$Shortcut = [Environment]::GetFolderPath('SendTo') + '/Compare Code'
	
	$PairedSCut = (New-Object -ComObject wscript.shell).CreateShortcut($Shortcut + ' (Paired).lnk')
	if (!$?) { return }
	$GroupedSCut = (New-Object -ComObject wscript.shell).CreateShortcut($Shortcut + ' (Grouped).lnk')
	if (!$?) { return }
	$PairedSCut.TargetPath = $pwsh
	$GroupedSCut.TargetPath = $pwsh
	$PairedSCut.IconLocation = $VScodeXe
	$GroupedSCut.IconLocation = $VScodeXe
	$PairedSCut.WindowStyle = 7 # 1, 3, 7 = Normal, Maximized, Minimized
	$GroupedSCut.WindowStyle = 7 # 1, 3, 7 = Normal, Maximized, Minimized
	$PairedSCut.Description = "Compare files using VS Code's diff editor"		
	$GroupedSCut.Description = "Compare files using VS Code's diff editor"
	
	$PairedSCut.Arguments = $ScriptPath + ' -PairedCompare'
	$GroupedSCut.Arguments = $ScriptPath + ' -GroupedCompare'
			
	$PairedSCut.Save()
	$GroupedSCut.Save()
	return
}
if ($PairedCompare -or $GroupedCompare) {
	[string[]]$pathList = @()
	$pathIndex = -1
	foreach ($token in $args) {
		if ($token -match ':') {
			$pathIndex++
			$pathList += $token
			continue
		}
		$pathList[$pathIndex] += ' ' + $token
	}
	$pathIndex++
	
	if ($pathIndex -eq 0) { return }
	$diffsCount = [math]::Floor($pathIndex / 2)
	if ($PairedCompare) {
		foreach ($i in 0..($diffsCount - 1)) {
			code -r --diff "$($pathList[2 * $i])" "$($pathList[2 * $i + 1])"
		}
	}
	if ($GroupedCompare) {
		foreach ($i in 0..($diffsCount - 1)) {
			code -r --diff "$($pathList[$i])" "$($pathList[$i + $diffsCount])"
		}
	}
}

## for some reason, cannot receive arg tokens that contain parentheses(receives null characters instead)