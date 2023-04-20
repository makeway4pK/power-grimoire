@echo off
title ADB Presets [ Copyright 2018 pK ]
:main
cls
echo -------------
echo  ADB Presets  [ Copyright 2018 pK ]
echo -------------
echo.
echo.
echo   1 - Unlock / Lock
echo   2 - Media Control
echo   3 - USB Tether
echo.
echo   4 - Toggle connection interface(WiFi/Hotspot)
echo   5 - Connect Wireless
echo.
choice /c 012345 /n /m "> "
echo.
if %errorlevel%==1 goto FinalDestination
if %errorlevel%==2 goto U
if %errorlevel%==3 (start ADB-Media.bat)&(goto main)
if %errorlevel%==4 goto X
if %errorlevel%==5 goto T
if %errorlevel%==6 goto D
goto main

:U
adb shell input keyevent 26
start /b adb shell input tap 540 1840
goto main

:T

if %code%==10 (
netsh wlan start hostednetwork>nul
adb shell input keyevent 3
adb shell input swipe 540 1000 540 1900
start /b adb shell input tap 270 220
timeout /t 5 /nobreak >nul
for /f %%i  in ('arp -a ^| findstr /c:"%mac%"') do (adb connect %%i>nul)
goto main
)

if %code%==3 (
adb shell input keyevent 3
adb shell input swipe 540 1000 540 1900
start /b adb shell input tap 430 220
echo   Connect with device hotspot
echo  then press any key
timeout /t -1>nul
choice /c 10 /m "	Stop PC hotspot"
if !errorlevel!==1 netsh wlan stop hostednetwork>nul
for /f %%i  in ('arp -a ^| findstr /c:"%mac%"') do (adb connect %%i>nul)
)
goto main

:X
adb shell input keyevent 4
adb shell am start -n com.android.settings/.TetherSettings
adb shell input tap 960 440
timeout /t 2 /nobreak>nul
adb shell input keyevent 4

goto main

:D
call "ADB-Connect.bat"
pause
goto main

:UTether
echo here
pause
adb shell input keyevent 26
adb shell input tap 540 1840
adb shell input keyevent 4
adb shell am start -n com.android.settings/.TetherSettings
adb shell input tap 960 440 & adb shell input keyevent 4
adb shell input keyevent 26
::goto main


comment 
GET INTERFACE CODE
set code=
for /f "tokens=1,2,3 delims=." %%i in ('adb devices ^| findstr /c:":5555"') do (for /f "tokens=2 delims=x" %%c in ('arp -a ^| findstr /c:"%%i.%%j.%%k"') do (set "code=%%c"))
echo %code%
pause
endcomment

:FinalDestination