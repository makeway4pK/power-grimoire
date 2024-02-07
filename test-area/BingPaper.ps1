# Created: 30Dec2023 1pm
# @makeway4pK
# This script changes the desktop and lockscreen wallpaper, sourced from Bing's
# daily images.

. ./cfgMan.ps1 -get 'BingPaper_saveLoc'

$oldSaveLocation = "${BingPaper_saveLoc}-old"
$retryDelay = 30
$SkipMemory = 30
$bingDateFormat = 'yyyyMMdd'

function BingPaper {
	if (!(Test-Path -Path $BingPaper_saveLoc)) {
		if (Test-Path -Path $oldSaveLocation) {
			Get-BingPaper
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
	Push-Location "$PSScriptRoot/.."
	./stable/Set-Wallpaper.ps1 -Path $BingPaper_saveLoc -Style Span
	Pop-Location 
}
function Get-BingPaper {
	# Dates in memory are in pairs...
	$SkipMemory *= 2
	# ...except the first one which marks the current wallpaper's date...
	$SkipMemory += 1
	# ...which are 8 characters long...
	$SkipMemory *= $bingDateFormat.Length
	# ...marking ranges of skipped dates, the start date is included,
	# i.e. it marks a skipped date
	# but the end date is not included in the range.
	# i.e. it marks a non-skipped date
	
	
	$skips = [array]::CreateInstance([string], $SkipMemory)
	# Extract skip list
	$text = Get-Content -Path $BingPaper_saveLoc -Tail 1
	# Check if there is any memory
	if ($text.Length -eq 0 -or
		$text.Length % $bingDateFormat.Length -ne 0 -or
		$text -match '\D+' -or
		{
			param($text)
			# Check a random date in the text
			[uint]$i = $text.Length / $bingDateFormat.Length
			$i = Get-Random -Maximum $i
			$i *= $bingDateFormat.Length
			[datetime]::ParseExact($text.Substring($i, $bingDateFormat.Length), $bingDateFormat, $null)
			return $?
		}.Invoke($text)
	) {
		# No memory found
		# Seed new memory

		$skips += [datetime]::Today.ToString($bingDateFormat)
		$index = 0
	}
	else {
		# Memory found
	
		$text = $text.Substring(0, $SkipMemory)
		for ($i = 0; $i -lt $SkipMemory -and $i -lt $skips.Length; $i++) {
			$skips[$i] = $text.Substring($i * $bingDateFormat.Length, $bingDateFormat.Length)	
		}

		if ($skips[0] -ne [datetime]::Today) {
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
		Invoke-WebRequest "http://www.bing.com/$url" -OutFile $BingPaper_saveLoc
	}while (!$? -and !(Start-Sleep -Seconds $retryDelay))
	# Save Memory at end of image file
	"`n" + ($skips -join '') | Add-Content $BingPaper_saveLoc
	Remove-Item $oldSaveLocation
}

BingPaper