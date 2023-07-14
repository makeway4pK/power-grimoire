#requires -version 3.0
#####equires -RunAsAdministrator

. ./cfgMan.ps1 -get 'impact_path'

$delay = 15

$impact_path
'sadc'
# ./stable/LaunchIf.ps1 -Admin -Online -Charging -Focus launcher, 1170, 700 -Launch $impact_path
