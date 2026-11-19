# Slate Version Bump & Release Trigger
# Usage: pwsh -NoProfile -File .\release.ps1 [-Bump patch|minor|major] [-Version X.Y.Z] [-Push]
param(
    [ValidateSet('patch', 'minor', 'major')]
    [string]$Bump = 'patch',
    [string]$Version = '',
    [switch]$Push
)

$ErrorActionPreference = 'Stop'
$verFile = Join-Path $PSScriptRoot 'VERSION'
$varsInc = Join-Path $PSScriptRoot 'Slate\@Resources\Variables.inc'

$cur = if (Test-Path $verFile) { (Get-Content $verFile -Raw).Trim() } else { '3.0.0' }
if (-not $Version) {
    $parts = $cur.Split('.') | ForEach-Object { [int]$_ }
    switch ($Bump) {
        'major' { $parts[0]++; $parts[1] = 0; $parts[2] = 0 }
        'minor' { $parts[1]++; $parts[2] = 0 }
        'patch' { $parts[2]++ }
    }
    $Version = "$($parts[0]).$($parts[1]).$($parts[2])"
}
$Version = $Version -replace '^v',''

# 1. Update VERSION file
[System.IO.File]::WriteAllText($verFile, "$Version`n", [System.Text.UTF8Encoding]::new($false))

# 2. Update SlateVersion in Variables.inc
$vText = [System.IO.File]::ReadAllText($varsInc)
$vText = [regex]::Replace($vText, '(?m)^SlateVersion=.*$', "SlateVersion=$Version")
[System.IO.File]::WriteAllText($varsInc, $vText, [System.Text.UTF8Encoding]::new($false))

# 3. Update Version= across all 25 skin .ini files
Get-ChildItem (Join-Path $PSScriptRoot 'Slate') -Recurse -Filter *.ini | ForEach-Object {
    $t = [System.IO.File]::ReadAllText($_.FullName)
    if ($t -match '(?m)^Version=') {
        $t = [regex]::Replace($t, '(?m)^Version=.*$', "Version=$Version")
        [System.IO.File]::WriteAllText($_.FullName, $t, [System.Text.UTF8Encoding]::new($false))
    }
}

Write-Host "Synchronized version v$Version across VERSION, Variables.inc, and all 25 skins."

if ($Push) {
    git add VERSION Slate
    git commit -m "chore(release): v$Version"
    git tag "v$Version"
    git push origin main --tags
    Write-Host "Pushed commit and tag v$Version -> GitHub Actions will build and publish the release."
}
