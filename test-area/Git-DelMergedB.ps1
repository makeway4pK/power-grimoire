<# 
Created: 23:44 15Aug23
@makeway4pK
		Deletes all remote and local branches that have been 
	already merged with the main branch (git branch --merged)
	main, dev, develop, master are excused.
	Tweak as needed. Shows list and requires user confirmation.
#>

$mainBranch = 'main'
$excludedBranches_matchPattern = '(main|dev|develop|master)'

# local branches first

$localBranches = (git branch --merged $mainBranch).trim().where(
	{ $_ -notmatch $excludedBranches_matchPattern } )
"These are the local branches that will be deleted:"
$confirm = Read-Host
"Continue? (Y/n)"
if ($Host.UI.RawUI.ReadKey().Character -match '(Y|y)') {
	$localBranches | ForEach-Object { git branch -d $_ }
}

$remoteBranches = (git branch -r --merged $mainBranch
) | ForEach-Object { , ($_.trim() -split '/')
} | Where-Object { $_[1] -notmatch '(main|dev|develop|master)' }
"These are the remote branches that will be deleted:"
$remoteBranches
"Continue? (Y/n)"
if ($Host.UI.RawUI.ReadKey().Character -match '(Y|y)') {
	# $localBranches | ForEach-Object { git push --delete $_[0] $_[1] }
	# Can't test without a merged branch, stay tuned
}