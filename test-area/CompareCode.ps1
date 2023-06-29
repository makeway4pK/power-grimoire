param(
	[Switch]$Deploy,
	[Switch]$PairedCompare,
	[Switch]$GroupedCompare
)
if ($Deploy) {
	$VScodeXe = (gci($env:path -split ';' -match 'VS Code' -replace 'bin') | ? -Property Name -eq 'Code.exe').FullName
	if (!$VScodeXe) {
		Write-Error -Message "`n`nVS code executable not found!`n Make sure VS code is installed and `n available in the path variable before trying again" -Category ResourceUnavailable
		return
	}
	
	[string]$pwsh = Resolve-Path "$PSScriptRoot/../modules/bin/powershellw.exe"
	if (!$pwsh) {
		$pwsh = 'powershell' 
	}
	
	$ScriptPath = "$PSScriptRoot/" + $MyInvocation.MyCommand
	$Shortcut = [Environment]::GetFolderPath('SendTo') + '/Compare Code.lnk'
	$s = (New-Object -ComObject wscript.shell).CreateShortcut($Shortcut)
	if (!$?) { return }
	$s.TargetPath = $pwsh
	$s.IconLocation = $VScodeXe
	$s.Arguments = $ScriptPath + ' -Compare'
	$s.WindowStyle = 7 # 1, 3, 7 = Normal, Maximized, Minimized
	$s.Save()
	return
}
if ($PairedCompare -or $GroupedCompare) {
	$pathList = @()
	[string] $path = ''
	foreach ($token in $args) {
		if ($token -match ':') {
			$pathList += $path
			$path = $token
			continue
		}
		$path += ' ' + $token
	}
	if ($pathList.count -eq 0) { return }
	$diffsCount = [int]($pathList.count / 2)
	if ($PairedCompare) {
		foreach ($i in 0..($diffsCount - 1)) {
			code -r --diff $pathList[2 * $i] $pathList[2 * $i + 1]
		}
	}
	if ($GroupedCompare) {
		foreach ($i in 0..($diffsCount - 1)) {
			code -r --diff $pathList[$i] $pathList[$i + $diffsCount]
		}
	}
}