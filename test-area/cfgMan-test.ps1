param(
	[string[]] $setVars,
	[string] $path,
	[switch] $parse
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

function Get-VNamesFromScript([string] $script) {
	$content = gi $script | gc -raw | sls '^(.*\n)*.*\. \.[/\\]cfgMan\.ps1[^\n]*\n'
	iex($content.Matches.Groups[0].Value -replace '\. \.[/\\]cfgMan\.ps1 -get', '$varList=') 2>&1>$null
	return $varList
}
function Find-NewVars() {
	return [string[]] $ListOfnewVarNames
}
function Check-NonNull([string[]]$ListtoValidate) {
	return [bool]$yesORno 
}  
function Filter-Null([string[]]$ListtoFilter) {
	return [string[]]$nonnull
}function Check-cfgBox {
	[cmdletbinding()]
	param(
		[Parameter(ValueFromPipeline)]
		[string]$path
	)
	process {
		$box = cfgBox($path)
		$box = if (Test-path ($box)) {
			gi $box
		}
		else {	return 'New' }
	
		$times = (gc -First 4) -split "`t"
		$script = gi $path
		$syncStr = ''
		if ($times[1] -ne $script.LastWriteTime.toString('MMM-dd-yyyy HH:mm:ss')) {
			$syncStr += 'List'
		}
		$roll = gi ./cfgbox/cfgRoll.ps1
		$rollTime = $roll.LastWriteTime
		if ($times[3] -ne $rollTime.ToString('MMM-dd-yyyy HH:mm:ss') -or
			$times[5] -ne $box.LastWriteTime.ToString('MMM-dd-yyyy HH:mm:ss')) {
			$syncStr += 'Value'
		}
		return $syncStr
	}
	<#
	$script = gi $path
	$box = gi ./cfgBox/script.cfgBox.ps1
	$times = (gc $box -First 4) -split "`t"
	if ($times[1] -ne $script.LastWriteTime.toString('MMM-dd-yyyy HH:mm:ss')) { return $false }
	$roll = gi ./cfgbox/cfgRoll.ps1
	$rollTime = $roll.LastWriteTime
	if ($times[3] -ne $rollTime.ToString('MMM-dd-yyyy HH:mm:ss')) { return $false }
	if ($rollTime -gt $box.LastWriteTime.AddSeconds(5)) { return $false }
	if ($times[5] -ne $box.LastWriteTime.ToString('MMM-dd-yyyy HH:mm:ss')) { return $false }
	return $true
	#>
}
function cfgBox([string]$path) {
	$gi = gi $path
	$rel = $gi.Directory | Resolve-Path -Relative
	if ($rel -match '\.\.') { return $false }
	return './cfgBox/' + $rel + '/' + $gi.BaseName + '.cfgBox' + $gi.Extension
}
function Update-cfgBox([string]$script) {
	$script = gi $script
	$scriptRel = $script | Resolve-Path -Relative
	$roll = gi ./cfgBox/cfgRoll.ps1
	$box = gi ./cfgBox/script.cfgBox.ps1
	gc $script -raw | ac $roll
	gc $roll -raw | ac $box
	$roll.Refresh()
	$box.Refresh()
	$boxHead = "<#`n"
	$boxhead += $script.LastWriteTime.toString('MMM-dd-yyyy HH:mm:ss') + "`tLast updated time( " + $scriptRel + " )`n"
	$boxHead += $roll.LastWriteTime.toString('MMM-dd-yyyy HH:mm:ss') + "`tLast updated time( cfgRoll )`n"
	$boxHead += (Get-Date).toString('MMM-dd-yyyy HH:mm:ss') + "`tLast updated time( cfgBox )`n"
	$boxhead += "#>`n"
	$boxhead  | sc $box
}

$toSetVarList = (($setVars -replace '[^\s\w\d_]'
	).trim() | ? {
		$_.length -gt 0
	}) -replace ' ', '_'

# if ($toSetVarList) {
# 	Get-Vars $toSetVarList
# }
# elseif (!($out = Sync-Roll)) {
# 	"`n No updates to cfgRoll were detected.`n"
# }
# else {
# $out
# }
if ($parse) {
	Get-VNamesFromScript $path
}
else {
	Check-cfgBox $path
}


