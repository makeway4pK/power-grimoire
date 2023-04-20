@echo off
title ADB Media  [ Copyright 2019 pK ]
:main
cls
echo -------------
echo  ADB Media  [ Copyright 2019 pK ]
echo -------------
echo.
echo             (8)Volume Up
echo.
echo   (4)Prev   (5)Play/Pause    (6)Next
echo.
echo             (2)Volume Down
choice /c 1234567890 /n /m ">"
goto CASE_%errorlevel%
goto main

:CASE_1
start /b adb shell input keyevent KEYCODE_MEDIA_PREVIOUS
goto main
:CASE_2
start /b adb shell input keyevent KEYCODE_VOLUME_DOWN
goto main
:CASE_3
start /b adb shell input keyevent KEYCODE_MEDIA_NEXT
goto main
:CASE_4
start /b adb shell input keyevent KEYCODE_MEDIA_PREVIOUS
goto main
:CASE_5
start /b adb shell input keyevent KEYCODE_MEDIA_PLAY_PAUSE
goto main
:CASE_6
start /b adb shell input keyevent KEYCODE_MEDIA_NEXT
goto main
:CASE_7
start /b adb shell input keyevent KEYCODE_MEDIA_PREVIOUS
goto main
:CASE_8
start /b adb shell input keyevent KEYCODE_VOLUME_UP
goto main
:CASE_9
start /b adb shell input keyevent KEYCODE_MEDIA_NEXT
goto main
:CASE_10
exit
goto main



comment 
GET INTERFACE CODE
set code=
for /f "tokens=1,2,3 delims=." %%i in ('adb devices ^| findstr /c:":5555"') do (for /f "tokens=2 delims=x" %%c in ('arp -a ^| findstr /c:"%%i.%%j.%%k"') do (set "code=%%c"))
echo %code%
pause
endcomment