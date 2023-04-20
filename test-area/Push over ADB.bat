@echo off
adb push %* /storage/emulated/0/Download/
if errorlevel 1 pause




