@echo off
::set/p "mac=Search for this MAC:"
set mac=45-55-3z-7x-g2-08
title Connect to %mac%
for /f %%i  in ('arp -a ^| findstr /c:"%mac%"') do (adb connect %%i:5555)