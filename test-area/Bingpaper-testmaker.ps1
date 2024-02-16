# Created: 16Feb2024 2pm
# @makeway4pK
# Makes a duplicate skipmemory for bingpaper.
# Takes a list of integers and converts to dates
# relative to today for the skipmem.

$list = @()
'Enter list of ints to test BingPaper, x to stop:'
$i = [int](Read-Host)
while ($?) {
	$list += $i
	$i = [int](Read-Host)
}


