# Created: 01Jan23 12am
# @makeway4pK
# CheckPointer

# This script saves/restores the folder(./?) or file(./?.?) to/from a previous 
#   snapshot(./$Checkpoint $Slot/?) in the same location.
#   Overwrites files

[CmdletBinding()]
param (
	[switch]
	$Restore = $false,
	[switch]
	$Save = $false,
	[string]
	$Path,
	[string]
	$Slot
)
function Save {
	
	$CheckPoint = ''
	if ($Slot) { $CheckPoint = ' ' + $Slot }
	$CheckPoint = '/CheckPoint' + $CheckPoint
	
	$Item = $Path
	if (!(Test-Path $Item)) {
		Write-Error "Could not find item at: '$Item'"
		return
	}
	$Item = Get-Item $Item

	if (Test-Path $Item -PathType Leaf) {
		$CheckPoint = $Item.Directory.FullName + $CheckPoint
		New-Item $CheckPoint -ItemType Container
		# $CheckPoint += '/' + $Item.Name
	}
	else {
		$CheckPoint = $Item.Parent.FullName + $CheckPoint
		New-Item $CheckPoint -ItemType Container
	}

	Copy-Item $Item $CheckPoint -Recurse -Force 
}
function Restore {
	
	$CheckPoint = ''
	if ($Slot) { $CheckPoint = ' ' + $Slot }
	$CheckPoint = '/CheckPoint' + $CheckPoint
	$Items = ($Path -split '[\\/]').Where({ $_.trim() })
	$Path = ($Items[0..($Items.count - 2)] -join '/')
	$CheckPoint = $Path + $CheckPoint + '/' + $Items[-1]
	
	if (!(Test-Path $CheckPoint)) {
		Write-Error "Could not find checkpoint at: '$CheckPoint'"
		return
	}

	Copy-Item $CheckPoint $Path -Recurse -Force 
}

foreach ($par in $PSBoundParameters.Keys) {
	if (!($par -eq 'Save') -and !($par -eq 'Restore')) { continue }
	if ($PSBoundParameters[$par]) { &$par }
}
