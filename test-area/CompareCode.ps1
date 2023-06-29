param(
	[Switch]$sw
)
if ($true) {
	'' | sc ([system.environment]::getfolderpath('desktop') + '/file.txt')
	$args -join ' ' | % { $_ | ac ([system.environment]::getfolderpath('desktop') + '/file.txt') }
	return
}
code --diff $args[1] $args[0]
if (!$?) { Read-host }