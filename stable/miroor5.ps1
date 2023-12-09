# Created: 22Oct23
#### Miroor5
#
## @makeway4pK
# This script is a simple infinite loop that sends desktop sceenshots as notifications
# 	to a device over adb. Frame rate is low and drops to 0 when cpu is under load.
# 	Good enough to keep an eye on progress bars and startup routines.

# TODO get display resolution, NOT scaled resolution or monitor resolution
$resolution = @{'x' = 1920; 'y' = 1080 }
$downscale = 4

# adb could not push more than ~32.5k b64 chars per notification (on my setup). No doc was found regarding this
$b64size = @{'min' = 25000; 'max' = 32328 }


Add-Type -AssemblyName System.Drawing
$canvas = [Drawing.Bitmap]::new($resolution.x, $resolution.y)
$painter = [Drawing.Graphics]::FromImage($canvas)
$pams = [Drawing.Imaging.EncoderParameters]::new()
$pam_quality = [Drawing.Imaging.Encoder]::Quality
$pams.Param[0] = [Drawing.Imaging.EncoderParameter]::new($pam_quality, $quality_val)
$encoder = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders()
$encoder = $encoder | Where-Object FormatDescription -eq JPEG

$downres = @{'x' = $resolution.x / $downscale; 'y' = $resolution.y / $downscale }
$quality_val = 60
while ($true) {
	$painter.CopyFromScreen(0, 0, 0, 0, $canvas.Size)
	$memory = [IO.MemoryStream]::new()
	$resized = [Drawing.Bitmap]::new($canvas, $downres.x, $downres.y)
	$resized.Save($memory, $encoder, $pams)
	$b64 = [Convert]::ToBase64String($memory.ToArray())
	$b64.Length
	if ($b64.Length -lt $b64size.max) {
		adb shell "cmd notification post --style bigpicture --picture data:base64,$b64 miroor5 ''"
		if ($b64.Length -lt $b64size.min) {
			# slowly raise quality, pin to lower ranges because size spikes(caused by text) are common but not size dips
			$quality_val += 2
			$pams.Param[0] = [Drawing.Imaging.EncoderParameter]::new($pam_quality, $quality_val)
		}
	}
	else {
		# lower quality if size overflows limit
		$quality_val -= 5
		$pams.Param[0] = [Drawing.Imaging.EncoderParameter]::new($pam_quality, $quality_val)
	}
	$memory.Dispose()
	$resized.Dispose()
}
# TODO smarter quality_val control