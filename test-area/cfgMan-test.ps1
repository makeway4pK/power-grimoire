param(
	[string[]] $setVars,
	[string] $prefix
)

function Get-Vars([string[]] $varList) {
	
}

function Set-Vars([string[]] $toSetVarList) {}
function Update-Roll() {
	$newroll = get-roll+Find-newvars
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

$toSetVarList = ($setVars -replace '[^\s\w\d_]'
).trim() -replace ' ', '_'  | ? {
	$_.length -gt 0
}

if ($toSetVarList) {
	Get-Vars $toSetVarList
}