<#
 .SYNOPSIS
 This script produces WlanScan.exe from the base64 encoded binary
  
 .DESCRIPTION
 Produces a binary that calls the windows native WlanScan function to scan any newly available wireless networks.
 Source for this was originally written by a user on the SuperUser forum as an answer for a Question on that platform.
  
 .NOTES
 Use this script to obtain the executable from the pre-built, base64 encoded binary
 OR
 You can use the provided source code to build it on your machine and 
 put the obtained executable in modules/bin
 
 .LINK
 Question: https://superuser.com/questions/889414/force-refresh-re-scan-wireless-networks-from-command-line
 User: https://superuser.com/users/59271/user541686
 
 .EXAMPLE
 cd modules/WlanScan
 ./WlanScan-decoder.ps1
  
 Places decoded executable in modules/bin
 #>
 
pushd $PSScriptRoot

if (!(test-path ../bin)) { mkdir ../bin }
Set-Content -Path "../bin/WlanScan.exe" $([Convert]::FromBase64String($(Get-Content -Path "WlanScan.base64"))) -Encoding Byte
popd