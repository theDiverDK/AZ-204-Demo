$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $true

git rev-parse --show-toplevel 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw 'Run this script from inside a git repository.'
}
$repoRoot = (git rev-parse --show-toplevel).Trim()
Set-Location $repoRoot

$mainBranch = 'main'
git show-ref --verify --quiet "refs/heads/$mainBranch"
if ($LASTEXITCODE -ne 0) {
    $current = (git rev-parse --abbrev-ref HEAD).Trim()
    git branch -m $current $mainBranch
}

$branches = @(
  'lp/01-init',
  'lp/02-functions',
  'lp/03-storage',
  'lp/04-cosmos',
  'lp/05-container',
  'lp/06-auth',
  'lp/07-keyvault',
  'lp/08-apim',
  'lp/09-events',
  'lp/10-messages',
  'lp/11-appinsight'
)

$worktreeDirs = @(
  'worktrees/01-init',
  'worktrees/02-functions',
  'worktrees/03-storage',
  'worktrees/04-cosmos',
  'worktrees/05-container',
  'worktrees/06-auth',
  'worktrees/07-keyvault',
  'worktrees/08-apim',
  'worktrees/09-events',
  'worktrees/10-messages',
  'worktrees/11-appinsight'
)

New-Item -ItemType Directory -Path 'worktrees' -Force | Out-Null

for ($i = 0; $i -lt $branches.Count; $i++) {
    $branch = $branches[$i]
    $dir = $worktreeDirs[$i]

    git show-ref --verify --quiet "refs/heads/$branch"
    if ($LASTEXITCODE -ne 0) {
        git branch $branch $mainBranch
    }

    $gitMarker = Join-Path $dir '.git'
    if (Test-Path -LiteralPath $gitMarker) {
        Write-Host "Worktree exists: $dir"
        continue
    }

    if (Test-Path -LiteralPath $dir) {
        $hasEntries = (Get-ChildItem -LiteralPath $dir -Force -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0
        if ($hasEntries) {
            Write-Host "Skipping non-empty path: $dir"
            continue
        }
    }

    git worktree add $dir $branch
    Write-Host "Created worktree: $dir -> $branch"
}

git worktree list
