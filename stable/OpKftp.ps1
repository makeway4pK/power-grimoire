
. ./cfgman.ps1 -get 'ftp_user', 'ftp_pass', 'ftp_port'

arp -a | sls '.*?(((25[0-5]|(2[0-4]|1?\d)?\d)\.?\b){4}).*?dynamic.*?'-AllMatches | % { $_.matches | % { explorer "ftp://${ftp_user}:${ftp_pass}@"+$_.groups[1].value+":${ftp_port}" } }
