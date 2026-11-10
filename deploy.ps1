# Slate deploy - copies the suite to Rainmeter's SkinPath and activates the skins
# Usage: powershell -File deploy.ps1 [-NoActivate]
param([switch]$NoActivate)

$src = "$PSScriptRoot\Slate"
$rm  = "C:\Program Files\Rainmeter\Rainmeter.exe"

# Auto-detect SkinPath from Rainmeter.ini (falls back to standard Documents\Rainmeter\Skins)
$rmIni = "$env:APPDATA\Rainmeter\Rainmeter.ini"
$skinBase = "$env:USERPROFILE\Documents\Rainmeter\Skins"
if (Test-Path $rmIni) {
    $spLine = (Get-Content $rmIni | Where-Object { $_ -match '^SkinPath=' } | Select-Object -First 1)
    if ($spLine) {
        $detected = ($spLine -replace '^SkinPath=','').TrimEnd('\')
        if (Test-Path $detected) { $skinBase = $detected }
    }
}
$dst = "$skinBase\Slate"

robocopy $src $dst /MIR /NJH /NJS /NDL | Out-Null
if ($LASTEXITCODE -ge 8) { Write-Host "robocopy failed ($LASTEXITCODE)"; exit 1 }

# Convert .ini/.inc to UTF-16 LE (Unicode), which Rainmeter 4.5+ requires for Unicode symbols
Get-ChildItem $dst -Recurse -Include *.ini,*.inc | ForEach-Object {
    $text = [System.IO.File]::ReadAllText($_.FullName)
    [System.IO.File]::WriteAllText($_.FullName, $text, [System.Text.Encoding]::Unicode)
}

Write-Host "Deploy OK -> $dst"

& $rm !RefreshApp
Start-Sleep -Milliseconds 2000

if (-not $NoActivate) {
    $configs = @(
        @{c='Slate\Clock';          i='Clock.ini';          x=1948; y=288},
        @{c='Slate\WorldClock';     i='WorldClock.ini';     x=1948; y=420},
        @{c='Slate\Weather';        i='Weather.ini';        x=1948; y=488},
        @{c='Slate\WeatherDetails'; i='WeatherDetails.ini'; x=1948; y=620},
        @{c='Slate\Calendar';       i='Calendar.ini';       x=1948; y=688},
        @{c='Slate\CPU';            i='CPU.ini';            x=2208; y=288},
        @{c='Slate\RAM';            i='RAM.ini';            x=2208; y=420},
        @{c='Slate\GPU';            i='GPU.ini';            x=2208; y=488},
        @{c='Slate\Disk';           i='Disk.ini';           x=2208; y=620},
        @{c='Slate\Network';        i='Network.ini';        x=2208; y=752},
        @{c='Slate\Volume';         i='Volume.ini';         x=2208; y=884}
    )
    foreach ($cfg in $configs) {
        & $rm "!ActivateConfig" $cfg.c $cfg.i
        Start-Sleep -Milliseconds 1500
        & $rm "!Move" $cfg.x $cfg.y $cfg.c
        Start-Sleep -Milliseconds 500
    }
    Write-Host "11 skins activated and positioned (columns x=1952 and x=2208)"

    # Sync saved layout if present so Game Mode exit restores Slate
    Start-Sleep -Milliseconds 1500
    $layoutIni = "$env:APPDATA\Rainmeter\Layouts\keita_quanto\Rainmeter.ini"
    if (Test-Path $layoutIni) {
        $cur = Get-Content $rmIni
        $ok = 0
        for ($j=0; $j -lt $cur.Count; $j++) {
            if ($cur[$j] -match '^\[Slate\\(Clock|WorldClock|Weather|WeatherDetails|Calendar|Volume|CPU|RAM|GPU|Disk|Network)\]') {
                $k = $j+1
                if ($cur[$k] -match 'Active=1') { $ok++ }
            }
        }
        if ($ok -ge 11) {
            Copy-Item $rmIni $layoutIni -Force
            Write-Host "Saved layout synced ($ok active skins)"
        }
    }
}
