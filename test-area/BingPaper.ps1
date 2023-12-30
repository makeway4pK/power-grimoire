
function Get-BingPaper {
	$mkt_str = '' # one of 'en-US', 'en-UK', '', etc.
	$o = $null
	do {
		$o = Invoke-WebRequest "http://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=$mkt_str" | ConvertFrom-Json
	}while (!$? -and !(Start-Sleep -Seconds $retryDelay))
	$url = $o.images[0].url
	do {
		$o = Invoke-WebRequest "http://www.bing.com/$url" -OutFile $picsumpaper_saveLoc
	}while (!$? -and !(Start-Sleep -Seconds $retryDelay))
	Remove-Item $oldSaveLocation
}
