
Add-Type -AssemblyName System.Drawing
$canvas = [Drawing.Bitmap]::new(1920, 1080)
$painter = [Drawing.Graphics]::FromImage($canvas)
$pams = [Drawing.Imaging.EncoderParameters]::new()
$pam_quality = [Drawing.Imaging.Encoder]::Quality
$quality_val = 60
$pams.Param[0] = [Drawing.Imaging.EncoderParameter]::new($pam_quality, $quality_val)
$encoder = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders()
$encoder = $encoder | ? FormatDescription -eq JPEG
while ($true) {
	$painter.CopyFromScreen(0, 0, 0, 0, $canvas.Size)
	$memory = [IO.MemoryStream]::new()
	$resized = [Drawing.Bitmap]::new($canvas, 480, 270)
	$resized.Save($memory, $encoder, $pams)
	$b64 = [Convert]::ToBase64String($memory.ToArray())
	$b64.Length
	if ($b64.Length -lt 32328) {
		adb shell "cmd notification post --style bigpicture --picture data:base64,$b64 miroor5 ''"
		if ($b64.Length -lt 25000) {
			$quality_val += 2
			$pams.Param[0] = [Drawing.Imaging.EncoderParameter]::new($pam_quality, $quality_val)
		}
	}
	else {
		$quality_val -= 5
		$pams.Param[0] = [Drawing.Imaging.EncoderParameter]::new($pam_quality, $quality_val)
	}
	$memory.Dispose()
	$resized.Dispose()
}