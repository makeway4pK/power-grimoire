# Created: 10Sep2022 12am
# @makeway4pK
# This script changes the desktop and lockscreen wallpaper, sourced from a
# stock picture service thru a static url. Works in reverse common sense
# order to minimize change time and allow waiting for network indefinitely
# if offline.
 
. ./cfgMan.ps1 -get 'picsumpaper_saveLoc'

$picServiceStaticUrl = "https://picsum.photos/3840/2160/"
$oldSaveLocation = "${picsumpaper_saveLoc}-old"
$retryDelay = 30

function PicSum {
	if (!(Test-Path -Path $picsumpaper_saveLoc)) {
		if (!(Test-Path -Path $oldSaveLocation)) {
			Get-Wallpaper
		}
		else {
			while (!(Test-Path -Path $picsumpaper_saveLoc)) { Start-Sleep -Seconds 2 }
		}
	}
	
	Apply-Wallpaper
	Apply-LockPaper
	Mark-AsOld
	Get-Wallpaper
}

function Get-Wallpaper { 
	do {
		Invoke-WebRequest $picServiceStaticUrl -OutFile $picsumpaper_saveLoc
	}while (!(Test-Path $picsumpaper_saveLoc) -and !(Start-Sleep -Seconds $retryDelay))
	Remove-Item $oldSaveLocation
}

function Mark-AsOld { Rename-Item $picsumpaper_saveLoc $oldSaveLocation }

function Apply-LockPaper {
	$RegKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP"
	New-Item -Path $RegKeyPath -Force
	New-ItemProperty -Path $RegKeyPath -Name "LockScreenImagePath" -Value $picsumpaper_saveLoc -PropertyType STRING -Force
}

function Apply-Wallpaper {	Update-Wallpaper -Path $picsumpaper_saveLoc -Style Span }

function Update-Wallpaper {
	#--------------------------------------------------------------------------------------------------#
	# ScriptName : Update-WallPaper.ps1                                                                #
	# Description : Force a Desktop wallpaper Refresh with no logoff/login needed                      #
	# Date : December 2021                                                                             #
	# Written : Griffon                                                                                #
	# WebSite :http://www.c-nergy.be - http://www.c-nergy.be/blog                                      #
	# Version : 2.0                                                                                    #
	# History : 2.0  - Adding functions and parameters to cover more scenario                          #
	#         : 1.0  - Initial Version - Basic Settings                                                #    
	#                                                                                                  #  
	# Credits  : Unknown (multipe Internet Sources & References)                                       #
	#                                                                                                  #  
	# Notes : We have been using multiple resources from internet and cope snippets in order to come   #      
	#         with this script...The following link has provided us really good base and info to build #
	#         up the script (https://stackoverflow.com/questions/19989906/ how-to-set-wallpaper-style  #
	#          -fill-stretch-according-to-windows-version).                                            #
	#                                                                                                  #
	# Disclaimer : Script provided AS IS. Use it at your own risk....                                  #
	#              You can use this script and distribute it as long as credits are kept               #  
	#              in place and unchanged                                                              #
	#                                                                                                  #  
	#--------------------------------------------------------------------------------------------------#
	
	<#
	Credits/ info from https://stackoverflow.com/questions/19989906/how-to-set-wallpaper-style-fill-stretch-according-to-windows-version
	 ' Set the wallpaper style and tile.
			' Two registry values are set in the Control Panel\Desktop key.
			' TileWallpaper
			'  0: The wallpaper picture should not be tiled
			'  1: The wallpaper picture should be tiled
			' WallpaperStyle
			'  0:  The image is centered if TileWallpaper=0 or tiled if TileWallpaper=1
			'  2:  The image is stretched to fill the screen
			'  6:  The image is resized to fit the screen while maintaining the aspect
			'      ratio. (Windows 7 and later)
			'  10: The image is resized and cropped to fill the screen while
			'      maintaining the aspect ratio. (Windows 7 and later)
			'  22: Span image
	#>
	
	# Pass Parameters to the Script
	 
	[CmdletBinding()]
	param(
		[Parameter()]
		[string]$Path,
		[ValidateSet('Centered', 'Stretched', 'Fill', 'Fit', 'Span')] $Style = 'Fill',
		[ValidateSet('Tiles', 'NoTiles')] $Tiled = '0')
	#---------------------------------------------------#
	#  Hash Table for WallPaper Style Value             #
	#---------------------------------------------------#
	
	$Wstyle = @{
		'Centered'  = 0
		'Stretched' = 2
		'Fill'      = 10
		'Fit'       = 6
		'Span'      = 22
	}
	
	#-----------------------------------------------------------------#
	#  Hash Table for Tiles Option. Tiles can be set to 1             #
	#  if Wstyle is centered. Otherwise, should be set to 0           #
	#-----------------------------------------------------------------#
	
	$WTile = @{
		'Tiles'   = 1
		'NoTiles' = 0                      
	}
	
	#Main Code
	$code = @'
		using System.Runtime.InteropServices;
		namespace Win32{
		 public class Wallpaper{
			[DllImport("user32.dll", CharSet=CharSet.Auto)]
			 static extern int SystemParametersInfo (int uAction , int uParam , string lpvParam , int fuWinIni) ;
			 public static void SetWallpaper(string thePath){
				SystemParametersInfo(20,0,thePath,3);
			 }
		}
	 }
'@
	
	if ($error[0].exception -like "*Cannot add type. The type name 'Win32.Wallpaper' already exists.*") {
		write-host "Win32.Wallpaer assemblies already loaded"
		write-host "Proceeding"
	}
 else {
		add-type $code
	}
	
	# Code for settings TileStyle and Wallpaper Style
	Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name wallpaperstyle -Value $Wstyle[$Style]
	Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name TileWallpaper -Value $WTile[$Tiled]
	
	#Apply the Change on the system
	[Win32.Wallpaper]::SetWallpaper($Path)    
}

PicSum