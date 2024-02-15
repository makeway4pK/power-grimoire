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
	
	
	$skips = [array]::CreateInstance([string], $SkipMemory)
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
			$skips.Insert(0, ( $text.Substring($i * $bingDateFormat.Length, $bingDateFormat.Length)))
		}
			# Either today's image was never applied (new day) or skipped already.
			if ($skips[1] -ne [datetime]::Today.ToString($bingDateFormat)) {
				# No skip range was found that starts from today so, Today's image was never  applied

				#Choose today's date
				$ChosenDate = [datetime]::Today
			}
			else {
				# Today was skipped

				# Next non-skipped(and currently applied) date is at skips[2]
				# Skip it and choose the date before it
				$ChosenDate = [datetime]::ParseExact($skips[2], $bingDateFormat, $null).AddDays(-1)
				# Check if next range starts there
				if ($skips[3] -eq $ChosenDate.ToString($bingDateFormat)) {
					# Merge into the next range if ChosenDate is at its start

					# Remove start of 2nd range...
					$skips.RemoveAt(3)
					# ...and end of 1st range
					$skips.RemoveAt(2)
					# Don't skip the end of 2nd range, choose it
					$ChosenDate = [datetime]::ParseExact($skips[2], $bingDateFormat, $null)
				}
				else {
					# Write new date if not in skip ranges
					$skips[2] = $ChosenDate.ToString($bingDateFormat)
				}
			}
		}
		else {
			#Today's image is applied currently and now we have to skip it

			# Choose yesterday's date
			$ChosenDate = [datetime]::Today.AddDays(-1)
			# Check if next range starts there
			if ($skips[1] -eq $ChosenDate.ToString($bingDateFormat)) {
				# Merge into the next range if ChosenDate is at its start

				# Add Today to start of 1st range
				$skips[1] = [datetime]::Today
				# And choose the end of 1st range
				$ChosenDate = [datetime]::ParseExact($skips[2], $bingDateFormat, $null)
			}
			else {
				# Add new range starting from today...
				$skips.Insert(1, [datetime]::Today.ToString($bingDateFormat))
				# ...and ending at yesterday
				$skips.Insert(2, $ChosenDate.ToString($bingDateFormat))
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
	"`n" + ($skips -join '') | Add-Content $lockedSaveLoc
}

BingPaper