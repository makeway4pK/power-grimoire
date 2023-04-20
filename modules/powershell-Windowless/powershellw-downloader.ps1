<#
 .SYNOPSIS
 This script downloads hiddenw.exe from Github and puts it in modules/bin as powershellw.exe
  
 .DESCRIPTION
 Downloads a binary that can run any console(in this case powershell) in windowless mode.
 This binary is fetched from a repo by user SeidChr on Github.
  
 .NOTES
 Use this script to download the latest executable from the Github repo
 OR
 You can use the provided links to download or build it from source and 
 put the obtained executable in modules/bin
 
 .LINK
 Repo: https://github.com/SeidChr/RunHiddenConsole
 Download page: https://github.com/SeidChr/RunHiddenConsole/releases
 
 .EXAMPLE
 cd modules/powershell-Windowless
 ./powershellw-downloader.ps1
  
 Downloaded executable will be placed in modules/bin
 #>
$maxTries = 3
$uri = 'https://api.github.com/repos/SeidChr/RunHiddenConsole/releases'
pushd $PSScriptRoot
 
if (!(test-path ../bin)) { mkdir ../bin }
 
$response = Invoke-WebRequest $uri -UseBasicParsing
while (!$? -and --$maxTries) {
	'Retrying in 2 seconds'
	sleep 2
	$response = Invoke-WebRequest $uri -UseBasicParsing
}
if (!$?) {
	"Failed to get response from github.com"
	"Check your internet connection and try again"
	popd
	return
}
$link = ($response.content -split '"' -match 'hiddenw.exe' -match 'https')[0]
Invoke-WebRequest $link -OutFile '../bin/powershellw.exe'
popd