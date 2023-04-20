$empties=@()
Get-ChildItem -Directory -Recurse ($args -join ' ') | Where-Object -FilterScript {($_.GetFiles().Count -eq 0) -and $_.GetDirectories().Count -eq 0} | ForEach-Object { $empties+=$_ }
$empties.fullname
""
"Continue to remove the above empty directories?"
pause
$empties | ForEach-Object { Remove-Item $_.fullname }
#pause