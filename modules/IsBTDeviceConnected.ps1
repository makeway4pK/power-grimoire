function IsBTDeviceConnected ([String[]] $FriendlyName) {
	return (
		(
			Get-PnpDeviceProperty -InputObject (
				Get-PnpDevice | Where-Object {
					$_.FriendlyName -eq $FriendlyName
				}
			)
		) | Where-Object {
			$_.KeyName -eq '{83DA6326-97A6-4088-9453-A1923F573B29} 15'
		}
	).data
}