# Slate release Checker & 1-Click Self-Updater
# Actions: Check (respects 6h cache unless -Force), Apply (downloads latest release & updates skins safely), OpenNotes
param(
    [ValidateSet('Check', 'Apply', 'OpenNotes')]
    [string]$Action = 'Check',
    [switch]$Force
)

$ErrorActionPreference = 'SilentlyContinue'
$rm = 'C:\Program Files\Rainmeter\Rainmeter.exe'
$rmIni = Join-Path $env:APPDATA 'Rainmeter\Rainmeter.ini'
$stateDir = Join-Path $env:APPDATA 'Rainmeter\SlateWork'
New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
$updateFile = Join-Path $stateDir 'update-state.json'

# Resolve installed Slate folder and current version
$skinDir = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$varsInc = Join-Path $skinDir '@Resources\Variables.inc'
$currentVer = '3.0.0'
$repo = 'marcelofrau/slate-rainmeter'
if (Test-Path $varsInc) {
    $vContent = Get-Content $varsInc -Raw
    if ($vContent -match '(?m)^SlateVersion=([^\r\n]+)') { $currentVer = $Matches[1].Trim() }
    if ($vContent -match '(?m)^SlateRepo=([^\r\n]+)')    { $repo = $Matches[1].Trim() }
}

function Compare-SemVer([string]$v1, [string]$v2) {
    $c1 = ($v1 -replace '^v','').Split('-')[0]
    $c2 = ($v2 -replace '^v','').Split('-')[0]
    try {
        return ([version]$c1).CompareTo([version]$c2)
    } catch {
        return [string]::Compare($c1, $c2)
    }
}

function Set-UpdateBadge([bool]$hasUpdate, [string]$latestVer, [string]$tip) {
    $hidden = if ($hasUpdate) { '0' } else { '1' }
    $label  = if ($hasUpdate) { "UP v$latestVer" } else { '' }
    & $rm '!SetVariable' 'UpdateHidden' $hidden 'Slate\Clock'
    & $rm '!SetVariable' 'UpdateText'   $label  'Slate\Clock'
    & $rm '!SetVariable' 'UpdateTip'    $tip    'Slate\Clock'
    & $rm '!UpdateMeter' '*' 'Slate\Clock'
    & $rm '!Redraw' 'Slate\Clock'
}

function Show-ClockFlash([string]$msg) {
    & $rm '!SetOption' 'MeterTZ' 'Text' $msg 'Slate\Clock'
    & $rm '!UpdateMeter' '*' 'Slate\Clock'
    & $rm '!Redraw' 'Slate\Clock'
    Start-Sleep -Milliseconds 1400
    & $rm '!SetOption' 'MeterTZ' 'Text' '%1' 'Slate\Clock'
    & $rm '!UpdateMeter' '*' 'Slate\Clock'
    & $rm '!Redraw' 'Slate\Clock'
}

$cached = @{
    lastCheckUtc = ''
    latestVersion = $currentVer
    releaseUrl = "https://github.com/$repo/releases"
    zipUrl = ''
}
if (Test-Path $updateFile) {
    try {
        $raw = Get-Content $updateFile -Raw | ConvertFrom-Json
        if ($raw.lastCheckUtc)  { $cached.lastCheckUtc  = [string]$raw.lastCheckUtc }
        if ($raw.latestVersion) { $cached.latestVersion = [string]$raw.latestVersion }
        if ($raw.releaseUrl)    { $cached.releaseUrl    = [string]$raw.releaseUrl }
        if ($raw.zipUrl)        { $cached.zipUrl        = [string]$raw.zipUrl }
    } catch {}
}

if ($Action -eq 'OpenNotes') {
    Start-Process $cached.releaseUrl
    exit 0
}

if ($Action -eq 'Check') {
    $needFetch = $Force.IsPresent
    if (-not $needFetch) {
        if (-not $cached.lastCheckUtc) {
            $needFetch = $true
        } else {
            try {
                $lastDt = [DateTime]::Parse($cached.lastCheckUtc).ToUniversalTime()
                if (([DateTime]::UtcNow - $lastDt).TotalHours -ge 6) { $needFetch = $true }
            } catch { $needFetch = $true }
        }
    }

    if ($needFetch) {
        try {
            $headers = @{ 'User-Agent' = 'Slate-Rainmeter-Updater/3.0'; 'Accept' = 'application/vnd.github+json' }
            $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest" -Headers $headers -TimeoutSec 8
            if ($rel -and $rel.tag_name) {
                $latest = ($rel.tag_name -replace '^v','').Trim()
                $cached.latestVersion = $latest
                $cached.lastCheckUtc  = [DateTime]::UtcNow.ToString('o')
                if ($rel.html_url) { $cached.releaseUrl = [string]$rel.html_url }
                $asset = $rel.assets | Where-Object { $_.name -match '\.zip$' } | Select-Object -First 1
                if ($asset -and $asset.browser_download_url) {
                    $cached.zipUrl = [string]$asset.browser_download_url
                } else {
                    $cached.zipUrl = [string]$rel.zipball_url
                }
                $cached | ConvertTo-Json | Set-Content -Path $updateFile -Encoding UTF8
            }
        } catch {}
    }

    $isNewer = (Compare-SemVer $cached.latestVersion $currentVer) -gt 0
    $tip = if ($isNewer) {
        "Slate v$($cached.latestVersion) available (installed: v$currentVer)`nLeft-click: 1-Click Auto-Update · Right-click: Release Notes"
    } else {
        "Slate v$currentVer (Up to date)"
    }
    Set-UpdateBadge $isNewer $cached.latestVersion $tip
    if ($Force -and -not $isNewer) {
        Show-ClockFlash "UP TO DATE v$currentVer"
    }
    exit 0
}

if ($Action -eq 'Apply') {
    & $rm '!SetOption' 'MeterTZ' 'Text' 'UPDATING SLATE...' 'Slate\Clock'
    & $rm '!UpdateMeter' '*' 'Slate\Clock'
    & $rm '!Redraw' 'Slate\Clock'

    # Backup user-customizable Variables keys from installed Variables.inc before overwriting
    $preserveKeys = @('Latitude', 'Longitude', 'LocationName', 'UnitTemp', 'WorldCity1', 'WorldSub1', 'WorldTZ1', 'WorldCity2', 'WorldTZ2', 'WorldDST2', 'GPUTotalMB', 'VizBands')
    $userVars = @{}
    if (Test-Path $varsInc) {
        foreach ($line in [System.IO.File]::ReadAllLines($varsInc)) {
            if ($line -match '^([A-Za-z0-9_]+)=(.*)$') {
                $k = $Matches[1]
                if ($preserveKeys -contains $k) { $userVars[$k] = $Matches[2] }
            }
        }
    }

    # Fetch latest release info to make sure we have the right download URL
    $zipUrl = $cached.zipUrl
    $targetVer = $cached.latestVersion
    try {
        $headers = @{ 'User-Agent' = 'Slate-Rainmeter-Updater/3.0'; 'Accept' = 'application/vnd.github+json' }
        $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest" -Headers $headers -TimeoutSec 10
        if ($rel -and $rel.tag_name) {
            $targetVer = ($rel.tag_name -replace '^v','').Trim()
            $asset = $rel.assets | Where-Object { $_.name -match '\.zip$' } | Select-Object -First 1
            $zipUrl = if ($asset) { [string]$asset.browser_download_url } else { [string]$rel.zipball_url }
        }
    } catch {}

    if (-not $zipUrl) {
        Show-ClockFlash 'UPDATE FAILED'
        exit 1
    }

    $tmpDir = Join-Path $env:TEMP "slate-update-$([Guid]::NewGuid().ToString('N').Substring(0,8))"
    New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
    $zipFile = Join-Path $tmpDir 'slate.zip'

    try {
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile -UseBasicParsing -TimeoutSec 30
        Expand-Archive -Path $zipFile -DestinationPath $tmpDir -Force

        # Find extracted Slate skin directory
        $extractedSlate = Get-ChildItem -Path $tmpDir -Recurse -Directory -Filter 'Slate' |
            Where-Object { Test-Path (Join-Path $_.FullName '@Resources\Variables.inc') } |
            Select-Object -First 1

        if (-not $extractedSlate) {
            # Fallback if zip root is the Slate folder itself
            if (Test-Path (Join-Path $tmpDir '@Resources\Variables.inc')) {
                $extractedSlate = Get-Item $tmpDir
            }
        }

        if ($extractedSlate) {
            robocopy $extractedSlate.FullName $skinDir /MIR /NJH /NJS /NDL | Out-Null

            # Restore user's personal variables into the new Variables.inc
            if (Test-Path $varsInc -and $userVars.Count -gt 0) {
                $vText = [System.IO.File]::ReadAllText($varsInc)
                foreach ($k in $userVars.Keys) {
                    $vText = [regex]::Replace($vText, "(?m)^$k=.*$", "$k=$($userVars[$k])")
                }
                [System.IO.File]::WriteAllText($varsInc, $vText, [System.Text.Encoding]::Unicode)
            }

            # Convert all .ini and .inc to UTF-16 LE for Rainmeter 4.5+
            Get-ChildItem $skinDir -Recurse -Include *.ini,*.inc | ForEach-Object {
                $t = [System.IO.File]::ReadAllText($_.FullName)
                [System.IO.File]::WriteAllText($_.FullName, $t, [System.Text.Encoding]::Unicode)
            }

            $cached.latestVersion = $targetVer
            $cached.lastCheckUtc  = [DateTime]::UtcNow.ToString('o')
            $cached | ConvertTo-Json | Set-Content -Path $updateFile -Encoding UTF8

            Set-UpdateBadge $false $targetVer "Slate v$targetVer (Up to date)"
            & $rm !RefreshApp
            Start-Sleep -Milliseconds 1200
            Show-ClockFlash "UPDATED TO v$targetVer"
        } else {
            Show-ClockFlash 'UPDATE ERR: ZIP'
        }
    } catch {
        Show-ClockFlash 'UPDATE ERROR'
    } finally {
        Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
