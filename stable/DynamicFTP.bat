
@echo off
title DynamicFTP
::set/p "mac=Search for this MAC:"
set mac=dynamic
for /f %%i  in ('arp -a ^| findstr /c:"%mac%"') do (explorer ftp://%user%:%pass%@%%i:3377)
