function mac2ip {
	param (
		[string]$mac
	)
	$mac = $mac.Trim(" \t").ToLower()
	if ($mac.Length -eq 17) {
		$mac = $mac.Remove(2, 1).Remove(4, 1).Remove(6, 1).Remove(8, 1).Remove(10, 1)
	}
	elseif ($mac.Length -eq 12) { }
	elseif ($mac -eq 'static' -OR $mac -eq 'dynamic') {	return (arp -a) -match $mac	}
	else { return "" }
	
	$mac = $mac.Insert(2, '-').Insert(5, '-').Insert(8, '-').Insert(11, '-').Insert(14, '-')
	$mac = $mac.Trim('-')
	$mac = (arp -a) -match $mac
	return -split $mac -match '(\d+\.)+\d+'
}