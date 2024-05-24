

. ./cfgMan.ps1 -get 'BingPaper_saveLoc'
$lockedSaveLoc = "${BingPaper_saveLoc}-Updating-PleaseWait"

Remove-Item $BingPaper_saveLoc
Rename-Item $lockedSaveLoc $BingPaper_saveLoc 