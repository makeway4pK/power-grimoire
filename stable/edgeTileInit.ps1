# Created: 5Mar2020 8pm

# The UWP app Edge Tile helps to pin custom tiles to the start menu however,
#   It doesn't manage to get initiated properly at startup. Namely, the 
#   'edgeTileDesktop.exe' process must be running before any pinned tiles can
#   launch their targets.

# This script is a workaround, to be placed in shell:startup, that starts the app
#   and kills the app UI process to initialize 'edgeTileDesktop.exe'. This
#   method is necessary because the helper process needs to be initialised by
#   app in a standard environment (UWP).

# for debugging only
#  Stop-Process -Name "edgeTileDesktop"

Start-Process shell:AppsFolder\21049FrancescoBonacci.edgeTile_5w3pkryp4zgyy!App
Do  {
    # Increase wait time to accomodate for initialization (trial-error)
    Start-Sleep -Milliseconds 200
} While ((Get-Process edgeTileDesktop).length -eq 0)
Stop-Process -Name "edgeTile"