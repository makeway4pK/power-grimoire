param(
	[string]$secretName
)

. ./cfgMan.ps1 -get $secretName
gv $secretName

# reminder for cfgMan calls:
#   shouldn't dynamic values
#   variables are ok
#   closer to the top is better
#   no method calls before cfgMan call