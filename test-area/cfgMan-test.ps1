param(
	[string[]] $setVars,
	[string] $prefix
)
function Make-Roll {
	# init cfgRoll from cfgRef
}
function Sync-Roll {
 #returns false for no probs, else exit msg
	if (!(Test-Path ./cfgRoll.ps1)) {
		return Make-Roll
	}
	$rollFile = gi ./cfgRoll.ps1
	try {
		$lastUpdate = gc ./cfgBox/cfgRollLastUpdated.txt
	}
	catch {}
	if ($rollFile.LastWriteTimeUtc.ToString() -ne $lastUpdate) {
		return Update-Roll
	}
	return $false
}
function Get-Vars([string[]] $varList) {
	
}

function Set-Vars([string[]] $toSetVarList) {}
function Update-Roll() {
	$newroll = get-roll + Find-newvars
	Check-nonnull $newroll
}
function Get-Roll() {
	return $roll = ./cfgRoll.ps1
}
function Find-NewVars() {
	return [string[]] $ListOfnewVarNames
}
function Check-NonNull([string[]]$ListtoValidate) {
	return [bool]$yesORno 
}  
function Filter-Null([string[]]$ListtoFilter) {
	return [string[]]$nonnull
}

$toSetVarList = (($setVars -replace '[^\s\w\d_]'
	).trim() | ? {
		$_.length -gt 0
	}) -replace ' ', '_'

if ($toSetVarList) {
	Get-Vars $toSetVarList
}
elseif (!($out = Sync-Roll)) {
	"`n No updates to cfgRoll were detected.`n"
}
else {
	$out
}