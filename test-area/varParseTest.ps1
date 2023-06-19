<#
.synopsis
tester for variable set
.description
rough script only
.notes
nothing much
#>

# return ./test-area/test.ps1
$rable = ./test-area/test.ps1
foreach ($thing in $rable.keys) {
	$val = $rable[$thing] -replace '"', '`"'
	$val = iex "echo `"$val`""
	echo "$thing = $val"
	Set-Variable -Name $thing -Value (iex "echo `"$val`"")
}