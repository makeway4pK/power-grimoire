param(
	$stuff1,
	[string[]]$arg,
	$stuff2
)

"Stuffs:"
$stuff1
""
$stuff2
""
"args:"
foreach ($thing in $arg) {
	$thing
}