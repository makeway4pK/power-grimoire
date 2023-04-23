# $MyInvocation
$name = (gi $PSCommandPath).BaseName
if ($name -match '\d') {
	$num = [int]$matches[0]
	if ($num -ne 1) {
		&($MyInvocation.InvocationName -replace $num, ($num - 1))
 }
	else {
		&($MyInvocation.InvocationName -replace '\d.', '' )
	}
}
else { $num++ }
sv "varFrom$num"  "string was set in $name"