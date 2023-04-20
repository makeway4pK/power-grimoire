# Created: 22Dec20 11pm

# This script automatically assigns icons to folders in specified
# 	directories if a match is found in a custom icon directory

Set-Location $PSScriptRoot

. ../cfgMan.ps1 -get @(
	'iconifier_clearCacheScript',
	'iconifier_mapFile',
	'iconifier_icoBox',
	'iconifier_dirList'
)

function Iconifier {
	$iconMap = @{}
	$iconMap = Import-Clixml $iconifier_mapFile
	$iconMap
	$engaged = $true
	$cout = ''
	do {
		Clear-Host
		',-----------------,'
		'|    Iconifier    |'
		'"-----------------"'
		' Current Mappings:'
		''
		$iconMap
		''
		$cout
		''
		'  7 - Add/Edit a mapping'
		'  8 - Remove a mapping'
		''
		'  5 - Iconify and exit'
		'  0 - Exit'
		$cin = $Host.UI.RawUI.ReadKey().Character.ToUInt16($null) - 48
		''
		switch ($cin) {
			0 { $engaged = $false }
			7 {
				'------------'
				' Add / Edit'
				'------------'
				$iconMap[(Read-Host "Folder Name")] = (Read-Host "Icon File"), (Read-Host "Icon Index")
				$iconMap | Export-Clixml $iconifier_mapFile
			}
			8 {
				'--------'
				' Remove'
				'--------'
				$iconMap.Remove((Read-Host "Folder Name"))
				$iconMap | Export-Clixml $iconifier_mapFile
			}
			5 {
				foreach ($directory in $iconifier_dirList) {
					Set-Location $directory
					foreach ($fol in Get-ChildItem) {
						if ($fol.mode -match '^d') {
							$icon = ''
							if (Test-Path ($iconifier_icoBox + $fol + ".ico")) {
								$icon = $iconifier_icoBox + $fol + ".ico,0"
							}
							elseif ($iconMap[$fol.Name]) {
								$icon = [System.Environment]::GetFolderPath("System") + '\' + $iconMap[$fol.Name][0] + '.dll,' + $iconMap[$fol.Name][1]
							}
							if ($icon) {
								Set-Location $fol
								Set-Icon($icon)
								Set-Location ..
							}
						}
					}
				}
				cscript $iconifier_clearCacheScript
				$engaged = $false
			}
			Default { $cout = 'Invalid choice, try again! Numbers only' }
		}
	} while ($engaged)
}

function Set-Icon {
	[CmdletBinding()]
	param (
		[String]
		$iconPath
	)
	attrib -h -s desktop.ini
	$content = Get-Content desktop.ini
	if (-not ($content -match 'IconResource=\s*\S*')) {
		Add-Content desktop.ini '[.ShellClassInfo]'
		Add-Content desktop.ini "IconResource=$iconPath"
		Add-Content desktop.ini '[ViewState]'
		Add-Content desktop.ini 'Mode='
		Add-Content desktop.ini 'Vid='
		Add-Content desktop.ini 'FolderType=Generic'
	}
	else {
		$content = $content -replace '^IconResource=.*$', "IconResource=$iconPath"
		Set-Content desktop.ini $content
	}
	attrib +h +s desktop.ini
}

Iconifier