. ./cfgMan.ps1 -get 'steam_path'
$steam_cfgFile = $steam_path + "/config/loginusers.vdf"
Rename-Item $steam_cfgFile ($steam_cfgFile + "`bh")
Rename-Item ($steam_cfgFile + "`bg") ($steam_cfgFile + "`bf")
Rename-Item ($steam_cfgFile + "`bh") ($steam_cfgFile + "`bg")
# Stop-Process -Name "steam"
Start-Process ($steam_path + "\steam.exe") -ArgumentList "-silent"
