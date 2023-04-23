param(
	[string[]] $get
)

function Get-Vars([string[]] $varList) {
	
}

function set-vars([string[]]) {}
function Update-Roll() {
	$newroll = get-roll+Find-newvars
	Check-nonnull $newroll
}
function get-Roll() {
	return $roll = ./ cfgroll 
}
function Find-newvars() {
	return [string[]] $ListOfnewVarNames
}
function Check-nonnull([string[]]$ListtoValidate) {
	return [bool]$yesORno 
}  
function filter-null([string[]]$ListtoFilter) {
	return [string[]]$nonnull
}
