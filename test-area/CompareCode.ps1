param(
	[Switch]$Deploy
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
if ($true) {
	'' | sc ([system.environment]::getfolderpath('desktop') + '/file.txt')
	$args -join ' ' | % { $_ | ac ([system.environment]::getfolderpath('desktop') + '/file.txt') }
	return
}
code --diff $args[1] $args[0]
if (!$?) { Read-host }