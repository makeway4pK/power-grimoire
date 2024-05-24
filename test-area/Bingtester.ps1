# Created: 16Feb2024 2pm
# @makeway4pK
# Makes a duplicate skipmemory for bingpaper.
# Takes a list of integers and converts to dates
# relative to today for the skipmem.
param(
	[array]$list = @()
)
. ./cfgMan.ps1 -get 'BingPaper_saveLoc'
$bingDateFormat = 'yyyyMMdd'

if (-not $List) {
	$list = @()
	'Enter an odd number of strictly increasing ints to test BingPaper, x to stop:'
	$i = [int](Read-Host)
	while ($?) {
		$list += $i
		$i = [int](Read-Host)
	}
}
'before:'
$list -join ','

for ($i = 0; $i -lt $list.Count; $i++) {
	$list[$i] = [datetime]::Today.AddDays(-$list[$i]).ToString($bingDateFormat)
}

"`n" + ($list -join '') | Add-Content $BingPaper_saveLoc

./test-area/BingPaper.ps1 | Out-Null
$list = @()
$text = Get-Content $BingPaper_saveLoc -Tail 1
[int]$nDates = $text.Length / $bingDateFormat.Length
for ($i = 0; $i -lt $nDates; $i++) {
	$list += [datetime]::Today.Subtract([datetime]::ParseExact(( $text.Substring($i * $bingDateFormat.Length, $bingDateFormat.Length)), $bingDateFormat, $null)).Days
}

'after:'
$list -join ','

# 6 cases
# 3,1,2,5,6 0,1,2,5,6     checked
# 4,0,3,7,9 3,0,3,7,9     checked
# 3,0,3,7,9 4,0,4,7,9     checked
# 3,0,3,4,8 8,0,8         checked
# 0,2,3,4,8 1,0,1,2,3,4,8 checked
# 0,1,3,7,9 3,0,3,7,9     checked




