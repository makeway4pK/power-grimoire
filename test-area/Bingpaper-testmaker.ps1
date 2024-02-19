# Created: 16Feb2024 2pm
# @makeway4pK
# Makes a duplicate skipmemory for bingpaper.
# Takes a list of integers and converts to dates
# relative to today for the skipmem.
. ./cfgMan.ps1 -get 'BingPaper_saveLoc'
$bingDateFormat = 'yyyyMMdd'
$list = @()
'Enter an odd number of strictly increasing ints to test BingPaper, x to stop:'
$i = [int](Read-Host)
while ($?) {
	$list += $i
	$i = [int](Read-Host)
}

for ($i = 0; $i -lt $list.Count; $i++) {
	$list[$i] = [datetime]::Today.AddDays(-$list[$i]).ToString($bingDateFormat)
}

"`n" + ($list -join '') | Add-Content $BingPaper_saveLoc


