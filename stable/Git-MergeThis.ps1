<#
Created 23:51 18Aug23
@makeway4pK
	Simple script to merge --no-ff current branch to main/master/develop.
	Doesn't commit the merge, only preps it.
	Ends up on the main branch
	Avoid using rollback if conflicts occur (behavior not tested)
#>
$mergeTo_branch = 'dev'

if ((git branch --merged $mergeTo_branch) -match '\*') {
	"This branch has no unmerged changes ahead of '$mergeTo_branch'"
	exit
}
$thisBranch = (git branch) -match '\*' -replace '^\*\s'

# Prepare commit
git checkout $mergeTo_branch
if (!$?) { exit }
git merge --no-ff --no-commit $thisBranch

# simple rollback (not tested for merges with conflicts)
"Do you want to attempt rollback (quit and checkout $thisBranch)? (Y/N)"
'Behavior not tested if conflicts have ocurred'
if ($Host.UI.RawUI.ReadKey().Character -match '[Yy]') {
	git merge --quit
	git checkout $thisBranch
}