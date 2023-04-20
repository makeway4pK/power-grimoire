#  Description: Script for switching between multiple jdks which are stored in
# 	a single parent directory ($selJDK_chooseFrom), each having its binaries in 
# 	a folder with similar relative paths($suffixForVar+$suffixForPath).
#	Path can be added/updated in the Environment Path($addToPath) , 

# 	Optionally($toReconfigProjs), can reconfigure project files for projects
#	stored in some folders($projFolders). Carefully check Configuration object
#	($cfgFileList) before enabling and using this option on your projects.
	
# 	Adapted for personal use on JDKs, modify as needed, use carefully.
#  Author: makeway4pK

# Define directory to choose from
# And if projects are to be reconfigured, parents of those folders,
	
. ./cfgMan.ps1 -get @(
	'selJDK_chooseFrom',
	'selJDK_projFolderList'
)
# any suffix to append to selected path from $selJDK_chooseFrom, for $whichEnvVar
$suffixForVar = ''
if ($suffixForVar.Length -gt 0) { $suffixForVar = "\$suffixForVar" }
# Environment variable to set the above result to
$whichEnvVar = 'JAVA_HOME'

# if var is to be added to environment path variable, with an optional suffix
# (like 'tools\bin'), use forward slashes only, no leading or trailing slashes
if ($addToPath = $true) {
	$suffixForPath = 'bin'
	if ($suffixForPath.Length -gt 0) { $suffixForPath = "\$suffixForPath" }
}
# if projects are to be reconfigured, enable this and configure values,
# current values are *SPECIFIC* to Java projects maintained by maven
if ($toReconfigProjs = $true) {
	# also confirm what you want to replace below
	$cfgFileList = [ProjectFilePattern[]]@(
		, @{ 																		# One object for each cfgFile in a project
			"filePath"        = ".settings/org.eclipse.jdt.core.prefs" 				# Relative path of cfgFile
			"textFlanksValue" = @( 													# Array of flanking string pairs
				, @(
					, "org.eclipse.jdt.core.compiler.codegen.targetPlatform=", "" 	# Pair of strings that flank the value (prefix,suffix)
				)
				, @(
					, "org.eclipse.jdt.core.compiler.compliance=", ""
				)
				, @(
					, "org.eclipse.jdt.core.compiler.source=", ""
				)
			)
		}
		, @{
			"filePath"        = ".classpath"
			"textFlanksValue" = @(
				, @(
					, "org.eclipse.jdt.launching.JRE_CONTAINER/org.eclipse.jdt.internal.debug.ui.launcher.StandardVMType/JavaSE-", ""
				)
			)
		}
		, @{
			"filePath"        = "pom.xml"
			"textFlanksValue" = @(
				, @(
					, "<maven.compiler.source>", "</maven.compiler.source>"
				)
				, @(
					, "<maven.compiler.target>", "</maven.compiler.target>"
				)
			)
		}
	)
	
}
################## Configuration end



# To sort out slash-clash
Set-Location $selJDK_chooseFrom
$selJDK_chooseFrom = (Get-Location).toString()

# Get Env variable from the User scope
$enVar = [Environment]::GetEnvironmentVariable($whichEnvVar, "User")
$newSDKpath = ""
$oldSDKpath = ""
Do {
	# Get Directory items
	$dirListFiltered = @()
	$counter = 0
	
	" " #newline
	" Select an SDK for EnvVar:  " + $whichEnvVar
	" from the directory:        " + $selJDK_chooseFrom
	" "
	#Loop to filter out directory entries, detect current SDK and present options
	foreach ($it in Get-ChildItem $selJDK_chooseFrom) {
		if ($it.mode.StartsWith('d')) {
			#Remember directories
			$dirListFiltered += $it
			$counter++
			#Detect current
			if ($enVar.contains($it.FullName + "$suffixForVar")) {
				$oldSDKpath = $it.FullName
				$isInVarText = " Current->    "
			}
			else {
				$isInVarText = "              "
			}
			#Form a menu
			" " + $isInVarText + $counter + ' - ' + $it.name
		}
	}
	
	#catch
	if ($dirListFiltered.Length -le 0) {
		"Oops! There's no SDK in this directory: " + $selJDK_chooseFrom
		"Edit the script and try again"
		Read-Host
		Exit
	}
	
	" "
	"Number [1 - " + $dirListFiltered.Length + "]:"
	$counter = $Host.UI.RawUI.ReadKey().Character.ToUInt16($Null)
	#$counter =  51
	$counter -= 49
	$newSDKpath = $dirListFiltered[$counter].FullName
	" "
	
	#catch
	if (($counter -ge $dirListFiltered.Length) -or ($counter -lt 0)) {
		Clear-Host
		"Please Choose a NUMBER in range of the given OPTIONS only"
		"Try again"
		$errorlevel = 1
	}
	else {
		$errorlevel = 0
	}
} While ($errorlevel -ne 0)

<#
# Decided not to modify original values
# # Add first suffix
# $newSDKpath += $suffixForVar
#>

# Finally, commit
[Environment]::SetEnvironmentVariable($whichEnvVar, "$newSDKpath$suffixForVar", "User")

# if Variable has to be added to path
if ($addToPath) {
	
	$envPath = [Environment]::GetEnvironmentVariable('path', "User")
	# Carefully remove old values, if any
	if ($oldSDKpath.Length -gt 0) {
		$envPath = $envPath.Replace("$oldSDKpath$suffixForVar$suffixForPath", "")
	}
	# Add the new value
	$envPath = "$newSDKpath$suffixForVar$suffixForPath;$envPath"
	# Clean double semicolons
	$envPath = $envPath -replace ';;+', ';'
	# Finally, commit
	[Environment]::SetEnvironmentVariable('path', $envPath, "User")

}


# Projects Reconfiguration script, (specific to jdks)
# before toAddBin conditional to not care about bin in path.
#<#
if ($toReconfigProjs) {
	#Get Java version from newly selected jdk
	$newJversion = &"${newSDKpath}\bin\java.exe" -version 2>&1
	#Bit of regex to simplify parsing and get the version number(11/12/1.8/1.7,etc)
	$newJversion[0].toString() -match '\"(\d.\.*?\d*).*\"'
	$newJversion = $Matches[1]
	[ProjectFilePattern]::reconfigureProjects($selJDK_projFolderList, $cfgFileList, $newJversion)
}
#>

class ProjectFilePattern {
	[String] $filePath
	[String] $valueRegex = "\d.\.*?\d*" # Regex pattern for version number value
	[String[][]] $textFlanksValue
	static reconfigureProjects([String[]] $selJDK_projFolderList, [ProjectFilePattern[]] $cfgFileList, $newJversion) {
		foreach ($projFolder in $selJDK_projFolderList) {
			Set-Location $projFolder
			#Getting ready
			$projList = @() #init list of projects
			#Get file folder list and filter folders
			foreach ($item in Get-ChildItem) {
				if ($item.mode.StartsWith('d')) {
					$projList += $item
				}
			}
			#Do for each project
			foreach ($proj in $projList) {
				#Enter project
				Set-Location $proj.Name
				#loop over cfgFiles
				foreach ($cfgFile in $cfgFileList) {
					if (Test-Path $cfgFile.filePath) {
						$text = Get-Content $cfgFile.filePath
						foreach ($flanksText in $cfgFile.textFlanksValue) {
							$text = $text -replace ([Regex]::Escape($flanksText[0]) + $cfgFile.valueRegex + [Regex]::Escape($flanksText[1])), ($flanksText[0] + $newJversion + $flanksText[1])
						}
						$text | Set-Content $cfgFile.filePath
					}
				}
				#exit project
				cd..
			}
		}
	}
}