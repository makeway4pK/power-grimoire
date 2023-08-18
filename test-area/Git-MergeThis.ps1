<#
Created 23:51 18Aug23
@makeway4pK
	Simple script to merge current branch to main/master/develop.
	Doesn't commit the merge, only preps it.
	Ends up on the main branch
#>
$mergeTo_branch = 'main'

if ((git branch --merged $mergeTo_branch) -match '\*') {
	"This branch has no unmerged changes ahead of '$mergeTo_branch'"
}
$thisBranch = (git branch) -match '\*' -replace '^\*\s'

# Prepare commit
git checkout $mergeTo_branch
git merge --no-ff --no-commit $thisBranch

