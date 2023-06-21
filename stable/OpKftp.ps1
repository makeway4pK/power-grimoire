
. ./cfgMan.ps1 -get 'ftp_user', 'ftp_pass', 'ftp_port'

$arpout = arp -a
$slsout = $arpout | sls  -Pattern '^.*?(((25[0-5]|(2[0-4]|1?\d)?\d)\.?\b){4}).*?dynamic.*?$' -AllMatches
foreach ($line in $slsout) {
	foreach ($match in $line.matches) {
		explorer "ftp://${ftp_user}:${ftp_pass}@"+$match.groups[1].value+":${ftp_port}" 
	}
}
