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
	Make-working-copy

	# Get next wallpaper if connected to internet
	ping bing.com -n 1 | Out-Null
	if ($?) { Get-BingPaper	}

	# Signal completion to other instances
	Commit-working-copy
	
	#Apply BingPaper to Desktop
	Apply-Wallpaper

	#Apply to Lockscreen
	net session | Out-Null
	if ($?) { Apply-LockPaper }

}

function Make-working-copy { Copy-Item $BingPaper_saveLoc $lockedSaveLoc }
function Commit-working-copy {
	Remove-Item $BingPaper_saveLoc
	Rename-Item $lockedSaveLoc $BingPaper_saveLoc 
}

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
		$skips += $text.Substring(0 * $bingDateFormat.Length, $bingDateFormat.Length)
		$skips += ''
		$skips += ''

		if ($nDates -gt 1) {
			for ($i = 1; $i -lt $nDates -and $i -lt $SkipMemory; $i++) {
				$skips += $text.Substring($i * $bingDateFormat.Length, $bingDateFormat.Length)
			}
		}

		# Skiplist Algorithm
		$TodayStamp = [datetime]::Today.ToString($bingDateFormat)
		if ($TodayStamp -eq $skips[3]) {
			if ($skips[4] -eq $skips[0]) {
				$ChosenDate = [datetime]::ParseExact($skips[4], $bingDateFormat, $null).AddDays(-1)
				$ChosenStamp = $ChosenDate.ToString($bingDateFormat)
				if ($ChosenStamp -eq $skips[5]) {
					$skips[4] = $skips[5] = ''
					$skips[0] = $skips[6]
					$ChosenDate = [datetime]::ParseExact($skips[6], $bingDateFormat, $null)
				}
				else {
					$skips[0] = $skips[4] = $ChosenStamp
				}
			}
			else {
				$ChosenDate = [datetime]::ParseExact($skips[4], $bingDateFormat, $null)
				$skips[0] = $skips[4]
			}
		}
		else {
			if ($TodayStamp -eq $skips[0]) {
				$skips[1] = $TodayStamp
				$skips[2] = [datetime]::Today.AddDays(-1).ToString($bingDateFormat)
				if ($skips[2] -eq $skips[3] ) {
					$skips[2] = $skips[3] = ''
					$skips[0] = $skips[4]
					$ChosenDate = [datetime]::ParseExact($skips[4], $bingDateFormat, $null)
				}
				else {
					$ChosenDate = [datetime]::Today.AddDays(-1)
					$skips[0] = $skips[2]
				}
			}
			else {
				$ChosenDate = [datetime]::Today
				$skips[0] = $TodayStamp
			}
		}
		$index = [datetime]::Today.Subtract($ChosenDate).Days
	}
	$num = [Math]::Max(0, $index - 7)
	$mkt_str = '' # one of 'en-US', 'en-UK', '', etc.
	$o = $null
	do {
		$o = Invoke-WebRequest "http://www.bing.com/HPImageArchive.aspx?format=js&idx=$index&n=$($num+1)&mkt=$mkt_str" | ConvertFrom-Json
	}while (!$? -and !(Start-Sleep -Seconds $retryDelay))
	$url = $o.images[$num].url
	do {
		Invoke-WebRequest "http://www.bing.com/$url" -OutFile $lockedSaveLoc
	}while (!$? -and !(Start-Sleep -Seconds $retryDelay))
	# Save Memory at end of image file
	"`n" + ($skips -join '') | Add-Content $lockedSaveLoc
}

BingPaper