# Created: 30Dec2023 1pm
# @makeway4pK
# This script changes the desktop and lockscreen wallpaper, sourced from Bing's
# daily images.

. ./cfgMan.ps1 -get 'BingPaper_saveLoc'

$oldSaveLocation = "${BingPaper_saveLoc}-old"
$retryDelay = 30

function BingPaper {
	if (!(Test-Path -Path $BingPaper_saveLoc)) {
		if (!(Test-Path -Path $oldSaveLocation)) {
			Get-Wallpaper
		}
		else {
			while (!(Test-Path -Path $BingPaper_saveLoc)) { Start-Sleep -Seconds 2 }
		}
	}
	
	Apply-Wallpaper
	Apply-LockPaper
	Mark-AsOld
	Get-BingPaper
}

function Mark-AsOld { Rename-Item $BingPaper_saveLoc $oldSaveLocation }

function Apply-LockPaper {
	$RegKeyPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP'
	New-Item -Path $RegKeyPath -Force
	New-ItemProperty -Path $RegKeyPath -Name 'LockScreenImagePath' -Value $BingPaper_saveLoc -PropertyType STRING -Force
}
function Apply-Wallpaper {
	Push-Location $PSScriptRoot
	./Set-Wallpaper.ps1 -Path $picsumpaper_saveLoc -Style Span
	Pop-Location 
}
function Get-BingPaper {
	$mkt_str = '' # one of 'en-US', 'en-UK', '', etc.
	$o = $null
	do {
		$o = Invoke-WebRequest "http://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=$mkt_str" | ConvertFrom-Json
	}while (!$? -and !(Start-Sleep -Seconds $retryDelay))
	$url = $o.images[0].url
	do {
		$o = Invoke-WebRequest "http://www.bing.com/$url" -OutFile $BingPaper_saveLoc
	}while (!$? -and !(Start-Sleep -Seconds $retryDelay))
	Remove-Item $oldSaveLocation
}

BingPaper