@echo off
title Wireless ADB
setlocal enabledelayedexpansion

:main
cls

call %ipath%

echo --------------
echo  Wireless ADB
echo --------------
echo  Target MAC: %mac%
echo.
adb devices -l
choice /c CDMP /m ":> Connect,Disconnect,change MAC or open Port"
echo.

if %errorlevel%==1 for /f %%i  in ('arp -a ^| findstr /c:"%mac%"') do (adb connect %%i>nul)
if %errorlevel%==2 for /f %%i  in ('arp -a ^| findstr /c:"%mac%"') do (adb disconnect %%i>nul 2>&1)
if %errorlevel%==3 goto ip
if %errorlevel%==4 adb tcpip 5555
echo.
::pause
goto main

:ip
echo.
echo Choose from the Following Devices:
echo 


echo.
echo Enter 0 to get MAC automatically if device is connected
echo.
echo Leave blank to cancel
set mac=
set mc=
set/p "mac=Option or New MAC: "
if "%mac%"=="0" for /f "tokens=2" %%i  in ('adb shell ip address show wlan0 ^| findstr /c:"link/ether"') do (set mac=)&(for /f "tokens=1,2,3,4,5,6 delims=:" %%a in ("%%i") do (set "mac=%%a-%%b-%%c-%%d-%%e-%%f"))
::echo %mac%
if not "%mac%"=="" (
:name
set/p "name=Name of new Device:"
if "%name%"=="" goto name
set op=%mac%

:op
if %op%==


)
::pause
goto main

