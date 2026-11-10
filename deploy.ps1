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
    # True 8px window-to-window gap between every card (both columns end at Y=1040)
    $configs = @(
        @{c='Slate\DesktopClock';   i='DesktopClock.ini';   x=220;  y=760},
        @{c='Slate\Visualizer';     i='Visualizer.ini';     x=220;  y=1010},
        @{c='Slate\Clock';          i='Clock.ini';          x=1944; y=288},
        @{c='Slate\WorldClock';     i='WorldClock.ini';     x=1944; y=424},
        @{c='Slate\Weather';        i='Weather.ini';        x=1944; y=496},
        @{c='Slate\WeatherDetails'; i='WeatherDetails.ini'; x=1944; y=632},
        @{c='Slate\SunMoon';        i='SunMoon.ini';        x=1944; y=704},
        @{c='Slate\Calendar';       i='Calendar.ini';       x=1944; y=776},
        @{c='Slate\CPU';            i='CPU.ini';            x=2208; y=288},
        @{c='Slate\RAM';            i='RAM.ini';            x=2208; y=424},
        @{c='Slate\GPU';            i='GPU.ini';            x=2208; y=496},
        @{c='Slate\Disk';           i='Disk.ini';           x=2208; y=632},
        @{c='Slate\Network';        i='Network.ini';        x=2208; y=768},
        @{c='Slate\Media';          i='Media.ini';          x=2208; y=904},
        @{c='Slate\Volume';         i='Volume.ini';         x=2208; y=976}
    )
    foreach ($cfg in $configs) {
        & $rm "!ActivateConfig" $cfg.c $cfg.i
        Start-Sleep -Milliseconds 1200
        & $rm "!Move" $cfg.x $cfg.y $cfg.c
        Start-Sleep -Milliseconds 400
    }
    Write-Host "15 skins activated and positioned with 8px window gap"

    # Lock card positions (Draggable=0) in Rainmeter.ini so accidental clicks never move them
    Start-Sleep -Milliseconds 1500
    & $rm !Quit
    Start-Sleep -Milliseconds 2500
    $lines = [System.IO.File]::ReadAllLines($rmIni)
    $out = New-Object System.Collections.Generic.List[string]
    $inSlateCard = $false
    $wroteDrag = $false
    foreach ($l in $lines) {
        if ($l -match '^\[(.+)\]') {
            if ($inSlateCard -and -not $wroteDrag) {
                $out.Add('Draggable=0')
            }
            $sec = $Matches[1]
            $inSlateCard = ($sec -match '^Slate\\(Clock|WorldClock|Weather|WeatherDetails|SunMoon|Calendar|Media|Volume|CPU|RAM|GPU|Disk|Network)$')
            $wroteDrag = $false
            $out.Add($l)
        } elseif ($inSlateCard -and $l -match '^Draggable=') {
            $out.Add('Draggable=0')
            $wroteDrag = $true
        } else {
            $out.Add($l)
        }
    }
    if ($inSlateCard -and -not $wroteDrag) { $out.Add('Draggable=0') }
    [System.IO.File]::WriteAllLines($rmIni, $out, [System.Text.Encoding]::Unicode)

    $layoutIni = "$env:APPDATA\Rainmeter\Layouts\keita_quanto\Rainmeter.ini"
    if (Test-Path $layoutIni) {
        Copy-Item $rmIni $layoutIni -Force
    }
    Start-Process $rm
    Write-Host "Cards locked (Draggable=0) and layout keita_quanto synced"
}
