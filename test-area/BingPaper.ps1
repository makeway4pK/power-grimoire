# Created: 30Dec2023 1pm
# @makeway4pK
# This script changes the desktop and lockscreen wallpaper, sourced from Bing's
# daily images.

. ./cfgMan.ps1 -get 'BingPaper_saveLoc'

$lockedSaveLoc = "${BingPaper_saveLoc}-Updating-PleaseWait"
$retryDelay = 30
$SkipMemory = 30
$bingDateFormat = 'yyyyMMdd'

function BingPaper {
	if (!(Test-Path -Path $BingPaper_saveLoc)) {
		if (Test-Path -Path $lockedSaveLoc) {
			while (!(Test-Path -Path $BingPaper_saveLoc)) { Start-Sleep -Seconds 2 }
		}
	}
	# Signal pending operation to other instances
	Mark-AsLocked
	
	Get-BingPaper
	Apply-Wallpaper
	Apply-LockPaper

	# Signal completion to other instances
	Mark-AsUnlocked
}

function Mark-AsLocked { Rename-Item $BingPaper_saveLoc $lockedSaveLoc }
function Mark-AsUnlocked { Rename-Item $lockedSaveLoc $BingPaper_saveLoc }

function Apply-LockPaper {
	$RegKeyPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP'
	New-Item -Path $RegKeyPath -Force
	New-ItemProperty -Path $RegKeyPath -Name 'LockScreenImagePath' -Value $lockedSaveLoc -PropertyType STRING -Force
}
function Apply-Wallpaper {
	Push-Location "$PSScriptRoot/.."
	./stable/Set-Wallpaper.ps1 -Path $lockedSaveLoc -Style Span
	Pop-Location 
}
function Get-BingPaper {
	# Dates in memory are in pairs...
	$SkipMemory *= 2
	# ...except the first one which marks the current wallpaper's date...
	$SkipMemory += 1
	
	# ...where pairs mark ranges of skipped dates,
	# the start date is included,
	# i.e. it marks a skipped date
	# but the end date is not included in the range.
	# i.e. it marks a non-skipped date
	
	$skips = [Collections.Arraylist]::new($SkipMemory)
	# Extract skip list
	$text = Get-Content -Path $lockedSaveLoc -Tail 1
	# Check if there is any memory
	if ($text.Length -eq 0 -or # handles file not found exception
		$text.Length % $bingDateFormat.Length -ne 0 -or
		$text -match '\D+' -or
		{
			param($text)
			# Check a random date in the text
			$i = $text.Length / $bingDateFormat.Length
			$i = Get-Random -Maximum $i
			$i *= $bingDateFormat.Length
			[datetime]::ParseExact($text.Substring($i, $bingDateFormat.Length), $bingDateFormat, $null) | Out-Null
			return -not $?
		}.Invoke($text)
	) {
		# No memory found
		# Seed new memory

		$skips += [datetime]::Today.ToString($bingDateFormat)
		$index = 0
	}
	else {
		# Memory found
	
		# Dates are 8 characters long, trucate text if too many ranges were found
		$text = $text.Substring(0, [Math]::Min($text.Length, $SkipMemory * $bingDateFormat.Length))
		$nDates = $text.Length / $bingDateFormat.Length
		for ($i = 0; $i -lt $nDates -and $i -lt $SkipMemory; $i++) {
			$skips += ( $text.Substring($i * $bingDateFormat.Length, $bingDateFormat.Length))
		}

		$TodayStamp = [datetime]::Today.ToString($bingDateFormat)
		$InUseStamp = $skips[0]
		$Skip0Stamp = ''
		$Next0Stamp = ''
		$Skip1Stamp = $skips[1]
		$Next1Stamp = $skips[2]
		$Skip2Stamp = $skips[3]
		$Next2Stamp = $skips[4]
		$Skip3Stamp = $skips[5]

		if ($TodayStamp -ne $Skip1Stamp) {
			if ($InUseStamp -ne $TodayStamp) {
				$ChosenDate = [datetime]::Today
				$InUseStamp = $TodayStamp
			}
			else {
				$Skip0Stamp = $TodayStamp
				$Next0Stamp = [datetime]::Today.AddDays(-1).ToString($bingDateFormat)
				if ($Next0Stamp -ne $Skip1Stamp ) {
					$ChosenDate = [datetime]::Today.AddDays(-1)
					$InUseStamp = $Next0Stamp
				}
				else {
					$Next0Stamp = ''
					$Skip1Stamp = ''

					$ChosenDate = [datetime]::ParseExact($Next1Stamp, $bingDateFormat, $null)
					$InUseStamp = $Next1Stamp
				}
			}
		}
		else {
			if ($Next1Stamp -ne $InUseStamp) {
				$ChosenDate = [datetime]::ParseExact($Next1Stamp, $bingDateFormat, $null)
				$InUseStamp = $Next1Stamp
			}
			else {
				$ChosenDate = [datetime]::ParseExact($Next1Stamp, $bingDateFormat, $null).AddDays(-1)
				$ChosenStamp = $ChosenDate.ToString($bingDateFormat)
				if ($ChosenStamp -ne $Skip2Stamp) {
					$Next1Stamp = $ChosenStamp
					$InUseStamp = $ChosenStamp
				}
				else {
					$Next1Stamp = ''
					$Skip2Stamp = ''
					
					if ($Next2Stamp -ne $InUseStamp) {
						$ChosenDate = [datetime]::ParseExact($Next2Stamp, $bingDateFormat, $null)
						$InUseStamp = $Next2Stamp
					}
					else {
						$ChosenDate = [datetime]::ParseExact($Next2Stamp, $bingDateFormat, $null).AddDays(-1)
						$ChosenStamp = $ChosenDate.ToString($bingDateFormat)
						if ($ChosenStamp -ne $Skip3Stamp) {
							$Next2Stamp = $ChosenStamp
							$InUseStamp = $ChosenStamp
						}
						else {
							$Next2Stamp = ''
							$Skip3Stamp = ''

							if (Next3Stamp-ne$InUseStamp)
						}
					}
				}
			}
		}
		$index = [datetime]::Today.Subtract($ChosenDate).Days
	}
	$mkt_str = '' # one of 'en-US', 'en-UK', '', etc.
	$o = $null
	do {
		$o = Invoke-WebRequest "http://www.bing.com/HPImageArchive.aspx?format=js&idx=$index&n=8&mkt=$mkt_str" | ConvertFrom-Json
	}while (!$? -and !(Start-Sleep -Seconds $retryDelay))
	$url = $o.images[0].url
	do {
		Invoke-WebRequest "http://www.bing.com/$url" -OutFile $lockedSaveLoc
	}while (!$? -and !(Start-Sleep -Seconds $retryDelay))
	# Save Memory at end of image file
	"`n" +
	$InUseStamp +
	$Skip0Stamp +
	$Next0Stamp +
	$Skip1Stamp +
	$Next1Stamp +
	$Skip2Stamp +
	$Next2Stamp +
	$Skip3Stamp +
	$skips[6..$skips.Count] -join '' | Add-Content $lockedSaveLoc
}

BingPaper