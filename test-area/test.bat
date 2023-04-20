::@echo off
setlocal enabledelayedexpansion
pause

set "s=adb devices -l | findstr /c:"5555""
echo %s%
if not "%s%"=="" (
for /f "tokens=1,3 delims=:" %%i in ('adb devices -l ^| findstr /c:":5555"') do (set "ip=%%i")&(for /f %%d in ("%%j") do (set "id=%%d"))
echo !ip!
echo !id!
echo.
)

pause