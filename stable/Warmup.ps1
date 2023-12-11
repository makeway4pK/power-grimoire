# Created: 25Jan23 2am
# @makeway4pK
# Warmup

# This script launches a set of shortcuts based on a text file fetched from an
#	android device over adb

param(
	[switch]
	$onlyPush
)

$maxWait = 10

# paths
$varList = @(
	'adbPortNum',
	'warmup_adbFile',
	'warmup_dir',
	'warmup_pullFile',
	'warmup_pushFile',
	'warmup_logFile'
)
. ./cfgMan.ps1 -get $varList

$ext_list = @('lnk', 'url')

$moment = Get-Date
"`n[[[[" + $moment.tostring() + "]]]]" | Add-Content $warmup_logFile
$moment = $moment.ToFileTime()
function LogThis {
	param(
		[parameter(ValueFromPipeline = $true)]
		$txt
	)
	begin {}
	process { $txt | Add-Content $warmup_logFile }
	end {
		$stamp = Get-Date
		"   [" + $stamp.ToLongTimeString() + "] +" + [Int]( - ($moment - ($script:moment = $stamp.ToFileTime())) / 10000) + "ms" | Add-Content $warmup_logFile
	}
}
function NogThis {
	param(
		[parameter(ValueFromPipeline = $true)]
		$txt
	)
	begin {
		$stamp = Get-Date
		"   [" + $stamp.ToLongTimeString() + "] +" + [Int]( - ($moment - ($script:moment = $stamp.ToFileTime())) / 10000) + "ms" | Add-Content $warmup_logFile
	}
	process { $txt | Add-Content $warmup_logFile }
	end {}
}

# to push the roster of available shortcuts to android device
# 	adds order values if provided in hashtable
function Push-Cuts {
	param (
		[String[]] $sns,
		[Parameter(Mandatory = $true)]
		[hashtable]
		$lastPlan # = @{} 
	)
	
	$cuts = [ordered]@{}
	$maxLen = 0
	foreach ($cut in Get-ChildItem $warmup_dir) {
		$cut = $cut.BaseName
		if ($maxLen -lt $cut.length) { $maxLen = $cut.length }
		$cuts[$cut] = $lastPlan[$cut] + ''
	}
	$pushStr = @("")
	$cuts.GetEnumerator() | ForEach-Object {
		$pushStr += $_.key.padRight($maxLen, ' ') + ' : ' + $_.value
	}
	$pushStr -join "`n" | Set-Content $warmup_pushFile
	
	foreach ($sn in $sns) {
		$sn = -split $sn
		"Pushing updated shortcut list to " + $sn[1] | NogThis
		do { adb -s $sn[0] push $warmup_pushFile $warmup_adbFile | LogThis }
		while (!($?) -and ((Start-Sleep 1) -or $maxWait--))
	}
}

function Get-Plan {
	param(
		[String[]] $sns
	)
	$PlanOfWarmup = @()
	foreach ($sn in $sns) {
		$sn = -split $sn
		"Pulling warmup plan from " + $sn[1] | NogThis
		#  get plan from android device
		do { adb -s $sn[0] pull $warmup_adbFile $warmup_pullFile | LogThis }
		while (!($?) -and ((Start-Sleep 1) -or $maxWait--))
		$subPlan = (Get-Content $warmup_pullFile) -replace "`0"
	
		# remove prefixed and interleaved garbage from unix
		# first line left blank by Push-cuts() for easy unix mess checks
		if ($subPlan[0].Length -ne 0) {
			$subPlan = $subPlan[1..($subPlan.length - 3)]
			$subPlan = $subPlan -replace "`0"
		}
		$PlanOfWarmup += $subPlan
	}
	Set-Content $warmup_pullFile $PlanOfWarmup
	
	# hashtable for collecting and sorting user input
	$sorter = @{}
	foreach ($line in $PlanOfWarmup) {
		$line = ($line -split ':').trim()					# cleanup
		if ($line[1] -eq "" -or $null -eq $line[0] ) { continue }	# skip lines with null inputs
		$sorter[$line[0]] = $line[1]						# overwrite to hashtable
	}
	$sorter.GetEnumerator() | Sort-Object -Property Value | Out-Null # sort by user inputs
	return $sorter
}

function Start-Warmup {
	param(
		[Parameter(Mandatory = $true)]
		[hashtable]
		$setPlan # = @{}
	)
	
	"Running shortcuts" | NogThis
	# loops for launching shortcuts
	foreach ($key in $setPlan.Keys) {
		$key = "$warmup_dir/$key."
		# $_= dir "$warmup_dir/*$_*" doesn't work
		foreach ($ext in $ext_list) {
			if ($cut = Get-Item ($key + $ext) -ErrorAction Ignore) {
				$cut.name | LogThis
				Start-Process $cut
				break
			}
		}
	}
}

"Attempting adb" | NogThis
# better make your own bridges
$sns = &"./stable/Wadb.ps1" $adbPortNum -SerialOut
foreach ($sn in $sns) { (-split $sn)[1] | LogThis }   
$order = Get-Plan $sns
# 'dbg: $order='*>>"warmuplog.txt"
# $order *>>"warmuplog.txt"
Push-Cuts $sns $order
if (!($onlyPush)) { Start-Warmup $order }
"Finished at:" | LogThis
&"./stable/miroor5.ps1"