$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $true

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repoRoot

$branch = (git rev-parse --abbrev-ref HEAD 2>$null).Trim()
if ([string]::IsNullOrEmpty($branch) -or $branch -eq 'HEAD') {
    throw "Could not detect current branch. Checkout an lp/* branch first."
}

if ($branch -like 'lp/*') {
    $lpKey = $branch.Substring(3)
} elseif (-not [string]::IsNullOrEmpty($env:LP_PATH)) {
    $lpKey = $env:LP_PATH
} else {
    throw "Current branch is '$branch'. Use an lp/* branch (for example lp/01-init), or set LP_PATH."
}

function Convert-ToFolderName([string]$key) {
    $parts = $key.Split('-', [System.StringSplitOptions]::RemoveEmptyEntries)
    if ($parts.Count -eq 0) { return $key }

    $result = $parts[0]
    for ($i = 1; $i -lt $parts.Count; $i++) {
        $p = $parts[$i]
        if ($p.Length -gt 0) {
            $result += '-' + $p.Substring(0,1).ToUpper() + $p.Substring(1)
        }
    }
    return $result
}

$lpFolder = Convert-ToFolderName $lpKey
$lpDir = Join-Path 'LearningPath' $lpFolder

if (-not (Test-Path -LiteralPath $lpDir -PathType Container)) {
    throw "Learning path folder not found for branch '$branch': $lpDir"
}

$createScript = Join-Path $lpDir 'create.ps1'
if (-not (Test-Path -LiteralPath $createScript -PathType Leaf)) {
    throw "Expected script: $createScript"
}

& $createScript
exit $LASTEXITCODE
