[cmdletBinding(PositionalBinding = $false)]
param(
	[Parameter(ValueFromRemainingArguments)]
	[string[]] $a
)
'there were ' + $a.count + ' arguments provided:'
$a | % { "'$_'" }