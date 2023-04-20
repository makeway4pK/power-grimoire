param([int]$samples)


"Waiting..."
$Host.UI.RawUI.ReadKey()>$null
$Host.UI.RawUI.ReadKey()>$null
$Host.UI.RawUI.ReadKey()>$null
"`nCounting"
$i = $samples;
$tot = 0;
$min = [int]::MaxValue;
$max = 0;
$overall = (Measure-Command {
		while ($i--) {
			$v = (Measure-Command { $Host.UI.RawUI.ReadKey()>$null }).TotalMilliseconds;
			if ($v -lt $min) { $min = $v };
			if ($v -gt $max) { $max = $v };
			$tot += $v
			"."
		}
	}).TotalMilliseconds
"`n           Min: " + $min
"`nIndividual Avg: " + ($tot / $samples)
"   Overall Avg: " + ($overall / $samples)
"`n           Max: " + $max;
