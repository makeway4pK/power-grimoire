@echo off
title Wireless ADB

:main
cls

call %ipath%

echo --------------
echo  Wireless ADB
echo --------------
echo  Target IP: %ip%
echo.
adb devices -l
choice /c CDIP /m ":> Connect,Disconnect,change IP or open Port"
echo.

if %errorlevel%==1 adb connect %ip%
if %errorlevel%==2 adb disconnect %ip%
if %errorlevel%==3 goto ip
if %errorlevel%==4 adb tcpip 5555
echo.
pause
goto main

:ip
echo.
echo Leave blank to cancel
echo Enter 0 to get IP automatically if device is connected
echo Trust me, I'm smart
echo.
set ip=
set/p "ip=New IP: "
if "%ip%"=="0" for /f "tokens=3 delims=:, " %%i  in ('adb shell ifconfig rmnet_data1 ^| findstr /c:"inet addr"') do (echo set ip=%%i>%ipath%)&goto main
if not "%ip%"=="" echo set ip=%ip%>%ipath%

goto main

