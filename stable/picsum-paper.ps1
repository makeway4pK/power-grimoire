# Created: 10Sep2022 12am
# @makeway4pK
# This script changes the desktop and lockscreen wallpaper, sourced from a
# stock picture service thru a static url. Works in reverse common sense
# order to minimize change time and allow waiting for network indefinitely
# if offline.
 
. ./cfgMan.ps1 -get 'picsumpaper_saveLoc'

$picServiceStaticUrl = 'https://picsum.photos/3840/2160/'
$oldSaveLocation = "${picsumpaper_saveLoc}-old"
$retryDelay = 30

function PicSum {
	if (!(Test-Path -Path $picsumpaper_saveLoc)) {
		if (!(Test-Path -Path $oldSaveLocation)) {
			Get-Wallpaper
		}
		else {
			while (!(Test-Path -Path $picsumpaper_saveLoc)) { Start-Sleep -Seconds 2 }
		}
	}
	
	Apply-Wallpaper
	Apply-LockPaper
	Mark-AsOld
	Get-Wallpaper
}

function Get-Wallpaper { 
	do {
		Invoke-WebRequest $picServiceStaticUrl -OutFile $picsumpaper_saveLoc
	}while (!(Test-Path $picsumpaper_saveLoc) -and !(Start-Sleep -Seconds $retryDelay))
	Remove-Item $oldSaveLocation
}

function Mark-AsOld { Rename-Item $picsumpaper_saveLoc $oldSaveLocation }

function Apply-LockPaper {
	$RegKeyPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP'
	New-Item -Path $RegKeyPath -Force
	New-ItemProperty -Path $RegKeyPath -Name 'LockScreenImagePath' -Value $picsumpaper_saveLoc -PropertyType STRING -Force
}

function Apply-Wallpaper {	Update-Wallpaper -Path $picsumpaper_saveLoc -Style Span }

PicSum