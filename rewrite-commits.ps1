<#
.SYNOPSIS
    Rewrites Git commit history to replace a specific author name/email
    with your preferred name/email.

.DESCRIPTION
    Uses `git filter-branch --env-filter`.
    Changes BOTH author and committer when the old email matches.
    Applies to all branches and tags.

.WARNING
    This rewrites history. You will need to force-push afterwards.
    Make a backup of the repo first!
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$OldEmail,

    [Parameter(Mandatory = $false)]
    [string]$OldName = "",          # optional – leave empty if you only care about email

    [Parameter(Mandatory = $true)]
    [string]$NewName,

    [Parameter(Mandatory = $true)]
    [string]$NewEmail,

    [switch]$Force                  # skip confirmation
)

# Safety checks
if (-not (Test-Path .git)) {
    Write-Error "This is not a Git repository. Run the script from the root of your repo."
    exit 1
}

Write-Host ""
Write-Host "=== Git Author Rewrite ===" -ForegroundColor Cyan
Write-Host "Old email : $OldEmail"
if ($OldName) { Write-Host "Old name  : $OldName" }
Write-Host "New name  : $NewName"
Write-Host "New email : $NewEmail"
Write-Host ""

if (-not $Force) {
    $confirm = Read-Host "This will REWRITE history on ALL branches & tags. Continue? (y/N)"
    if ($confirm -notin @("y", "Y", "yes", "YES")) {
        Write-Host "Aborted." -ForegroundColor Yellow
        exit 0
    }
}

# Build the env-filter script
$envFilter = @"
if [ `"`$GIT_COMMITTER_EMAIL`" = `"$OldEmail`" ] $(if ($OldName) { "|| [ `"`$GIT_COMMITTER_NAME`" = `"$OldName`" ]" })
then
    export GIT_COMMITTER_NAME=`"$NewName`"
    export GIT_COMMITTER_EMAIL=`"$NewEmail`"
fi
if [ `"`$GIT_AUTHOR_EMAIL`" = `"$OldEmail`" ] $(if ($OldName) { "|| [ `"`$GIT_AUTHOR_NAME`" = `"$OldName`" ]" })
then
    export GIT_AUTHOR_NAME=`"$NewName`"
    export GIT_AUTHOR_EMAIL=`"$NewEmail`"
fi
"@

Write-Host "Rewriting history... this can take a while on large repos." -ForegroundColor Yellow

# Run filter-branch
git filter-branch -f --env-filter $envFilter --tag-name-filter cat -- --branches --tags

if ($LASTEXITCODE -ne 0) {
    Write-Error "git filter-branch failed."
    exit 1
}

# Write-Host ""
# Write-Host "History rewritten successfully!" -ForegroundColor Green
# Write-Host ""
# Write-Host "Next steps:" -ForegroundColor Cyan
# Write-Host "1. Verify with:  git log --pretty=fuller"
# Write-Host "2. (Optional) Remove the backup refs created by filter-branch:"
# Write-Host "     git for-each-ref --format=`"delete %(refname)`" refs/original | git update-ref --stdin"
# Write-Host "     git reflog expire --expire=now --all"
# Write-Host "     git gc --prune=now --aggressive"
# Write-Host "3. Force-push (WARNING – coordinates with anyone else using the repo):"
# Write-Host "     git push --force --all"
# Write-Host "     git push --force --tags"
# Write-Host ""