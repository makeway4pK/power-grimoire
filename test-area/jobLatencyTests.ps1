$logfile = './logs/temp.log'

$moment = Get-Date
"`n[[[[" + $moment.tostring() + "]]]]">>$logfile
$moment = $moment.ToFileTime()
function LogThis {
	param(
		[parameter(ValueFromPipeline = $true)]
		$txt
	)
	begin {}
	process { $txt>>$logfile }
	end {
		$stamp = Get-Date
		"   [" + $stamp.ToLongTimeString() + "] +" + [Int]( - ($moment - ($script:moment = $stamp.ToFileTime())) / 10000) + "ms">>$logfile
	}
}
$d = -1
$p1 = @(3, 2, 1)
$p2 = @(7, 8, 9)
$jobs = @()

foreach ($t in $p1) {
	$jobs += sajb { $t = $Using:t + $Using:d; sleep $t; $t }
	'invoked sleep for ' + $t | LogThis
	 
}
'finished invokes' | LogThis
while ($jobs | ? -property state -eq Running) {
	$jobs | ? -property state -eq Running | wjb -any | rcjb | % {
		sajb {
			$p2 = $Using:p2
			$i = $Using:_
			$dla = $p2[$i - $Using:d - 1]
			'.'
			$p2
			'.'
			$i
			'.'
			sleep $dla[0] 
			'.'
			$dla[0]
			'.'
		} }
}while (gjb -state running) { gjb -state running | wjb -any | rcjb | LogThis }
'loop escaped' | LogThis

sleep 3

gjb

gjb | wjb | rcjb | LogThis

gjb | rjb -force