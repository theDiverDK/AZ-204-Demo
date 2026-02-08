param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ScriptArgs
)

$ErrorActionPreference = 'Stop'

$bashScript = [System.IO.Path]::ChangeExtension($PSCommandPath, '.sh')
if (-not (Test-Path -LiteralPath $bashScript)) {
    throw "Missing paired shell script: $bashScript"
}

& bash $bashScript @ScriptArgs
exit $LASTEXITCODE
