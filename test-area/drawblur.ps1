$src = 'C:\Users\makeway4pK\OneDrive\Pictures\BingImageOfTheDay (4).jpg'
$dst = 'C:\Users\makeway4pK\Desktop\red.jpg'


Add-Type -AssemblyName System.Drawing
$bmp = [Drawing.Bitmap]($src)

$bmpData = $bmp.LockBits(
    [Drawing.Rectangle]::new(0, 0, $bmp.Width, $bmp.Height),
    [Drawing.Imaging.ImageLockMode]::ReadWrite,
    $bmp.PixelFormat
)


# Declare an array to hold the bytes of the bitmap.
$bytes = [Math]::Abs($bmpData.Stride) * $bmp.Height
[byte[]]$rgbValues = [byte[]]::new($bytes)

# Copy the RGB values into the array.
# [Runtime.InteropServices.Marshal]::Copy($bmpData.Scan0+810, $rgbValues, 0, $bytes);

# for ($counter = $bmpdata.Stride; $counter -lt $bytes; $counter += $bmpdata.Stride) {
#     [Runtime.InteropServices.Marshal]::Copy($bmpData.Scan0 + $counter - (Get-Random -Maximum ($bmpData.Stride / 120)) * 3, $rgbValues, 0 , $bmpdata.Stride);
#     [Runtime.InteropServices.Marshal]::Copy($rgbValues, 0, $bmpData.Scan0 + $counter, $bmpData.Stride);
# }
$bmp.UnlockBits($bmpData)

$bmp.RotateFlip([Drawing.RotateFlipType]::Rotate270FlipNone)

$bmpData = $bmp.LockBits(
    [Drawing.Rectangle]::new(0, 0, $bmp.Width, $bmp.Height),
    [Drawing.Imaging.ImageLockMode]::ReadWrite,
    $bmp.PixelFormat
)


# Declare an array to hold the bytes of the bitmap.
$bytes = [Math]::Abs($bmpData.Stride) * $bmp.Height
[byte[]]$rgbValues = [byte[]]::new($bytes)

# Copy the RGB values into the array.
[Runtime.InteropServices.Marshal]::Copy($bmpData.Scan0, $rgbValues, 0, $bytes)

# $off = $bmpData.Stride / 256
# $offer = 0
# $offest = 0
# for ($counter = $bmpdata.Stride; $counter -lt $bytes; $counter += $bmpdata.Stride) {
#     # if (-not(Get-Random -Maximum ([int][Math]::Max(50 - [Math]::Abs($off-$bmpData.Stride/2), 1)))) 
#     # { 
#     $offest = (-$off - 0) / 10000
#     # }
#     $offer += $offest
#     $off += + $offer
#     $off = ([math]::sin(20 * $counter / $bytes * [Math]::PI) * $bmpData.Stride / 40)
#     # $off +=  $bmpData.Stride
#     # $off %= $bmpData.Stride
#     "$off,$offer,$offest"
#     # [Runtime.InteropServices.Marshal]::Copy($bmpData.Scan0 + $counter - [int]([math]::sin(20*$counter/$bytes*[Math]::PI)*$bmpData.Stride/8), $rgbValues, 0, $bmpdata.Stride);
#     [Runtime.InteropServices.Marshal]::Copy($bmpData.Scan0 + $counter - [int](($off) / 3) * 3, $rgbValues, 0, $bmpdata.Stride);
#     # pause
#     [Runtime.InteropServices.Marshal]::Copy($rgbValues, 0, $bmpData.Scan0 + $counter, $bmpData.Stride);
# }


# Set every third value to 255. A 24bpp bitmap will look red.
[int]$t = 0
for ($counter = 2; $counter -lt $rgbValues.Length; $counter += 3) {
    # $t = $rgbValues[$counter]
    # $rgbValues[$counter] = $rgbValues[$counter - 1]
    # $rgbValues[$counter - 1] = $rgbValues[$counter - 2]
    # $rgbValues[$counter - 2] = $t
    
    $t = ($rgbValues[$counter - 2] + $rgbValues[$counter - 1] + $rgbValues[$counter]) / 3
    $t += 100 * ($t - 200) / 128
    $t = [math]::Max($t, 0)
    $t = [math]::Min($t, 255)
    $rgbValues[$counter] = $rgbValues[$counter - 1] = $rgbValues[$counter - 2] = $t
    
    # $max = 0
    # $min = 256
    # foreach ($i in 0..2) {
    #     if ($rgbValues[$counter - $i] -gt $max) { $max = $rgbValues[$counter - $i] }
    #     if ($rgbValues[$counter - $i] -lt $min) { $min = $rgbValues[$counter - $i] }
    # }
    # foreach ($i in 0..2) {
    #     if ($rgbValues[$counter - $i] -eq $max) { $rgbValues[$counter - $i] =255}
    #     if ($rgbValues[$counter - $i] -eq $min) { $rgbValues[$counter - $i]=0 }
    # }
}

# Copy the RGB values back to the bitmap
[Runtime.InteropServices.Marshal]::Copy($rgbValues, 0, $bmpData.Scan0, $bytes)

# Unlock the bits.
$bmp.UnlockBits($bmpData)
$bmp.RotateFlip([Drawing.RotateFlipType]::Rotate90FlipNone)
$bmp.save($dst)
code -r --diff $src $dst