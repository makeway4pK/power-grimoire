
. ./cfgMan.ps1 -get 'gccpath32', 'gccpath64'
$newSDKpath = $gccpath64
$currSDKpath = $gccpath32
$PathVar = [Environment]::GetEnvironmentVariable( "path", "User")
$PathVar = $newSDKpath + ';' + $PathVar.Replace($currSDKpath, "") -replace ';;+', ';'
[Environment]::SetEnvironmentVariable("path", $PathVar, "User")