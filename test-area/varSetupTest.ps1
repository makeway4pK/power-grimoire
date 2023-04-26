# $MyInvocation
$name = (gi $PSCommandPath).BaseName
if ($name -match '\d+') {
	$num = [int]$matches[0]
	if ($num -ne 1) {
		iex ($MyInvocation.InvocationName -replace $num, ($num - 1))
	}
	else {
		iex ($MyInvocation.InvocationName -replace '\d+.', '' )
	}
}
else { $num = 0 }
sv "varFrom$num"  "string was set in $name"
"varFrom$num`: " + (iex "echo 'varFrom$num'")

# $n=100;$content=gc .\test-area\varSetupTest.ps1;1..$n|%{$content|sc "./test-area/varSetupTest.$_.ps1"};iex ".\test-area\varSetupTest.$n.ps1";1..$n|%{ri "./test-area/varSetupTest.$_.ps1"}