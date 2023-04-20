

# @makeway4pK


. ./cfgMan.ps1 -get 'clipmate_adbFile'
$clipFile = './caches/ClipFile.txt'
function Set-ClipFile {
	[CmdletBinding()]
	param (
		$clip
	)
	
	$clip > $clipFile
	adb push $clipFile $clipmate_adbFile
}
function Set-Clip {
	$clipOld = Get-Clipboard
	$clipNew = adb shell cat $clipmate_adbFile
	if ($clipOld -ne $clipNew) {
		Set-Clipboard($clipNew)
 }
}
while ($true) {
	# Set-ClipFile(Get-Clipboard)
	Set-Clip
	Start-Sleep -Seconds 2
}
