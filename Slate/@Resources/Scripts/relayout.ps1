# Slate dynamic layout manager - Realign, Save, Reset, ToggleLock, Watch
param(
    [ValidateSet('Realign', 'Save', 'Reset', 'ToggleLock', 'Watch')]
    [string]$Action = 'Realign',
    [switch]$Force
)

$ErrorActionPreference = 'SilentlyContinue'
$rm = 'C:\Program Files\Rainmeter\Rainmeter.exe'
$rmIni = Join-Path $env:APPDATA 'Rainmeter\Rainmeter.ini'
$stateDir = Join-Path $env:APPDATA 'Rainmeter\SlateWork'
New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
$savedFile = Join-Path $stateDir 'saved-layout.json'
$stateFile = Join-Path $stateDir 'layout-state.json'

function Get-SlateMonitors {
    if (-not ('SlateMonitorHelper' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public class SlateMonitorInfo {
    public string DeviceName;
    public bool Primary;
    public int DpiX;
    public double Scale;
    public int X;
    public int Y;
    public int Width;
    public int Height;
    public int WorkX;
    public int WorkY;
    public int WorkWidth;
    public int WorkHeight;
    public int WorkRight;
}

public class SlateMonitorHelper {
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public struct MONITORINFOEX {
        public int cbSize;
        public RECT rcMonitor;
        public RECT rcWork;
        public uint dwFlags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string szDevice;
    }

    public delegate bool MonitorEnumProc(IntPtr hMonitor, IntPtr hdcMonitor, ref RECT lprcMonitor, IntPtr dwData);

    [DllImport("user32.dll")]
    public static extern bool SetProcessDpiAwarenessContext(IntPtr value);

    [DllImport("user32.dll")]
    public static extern bool EnumDisplayMonitors(IntPtr hdc, IntPtr lprcClip, MonitorEnumProc lpfnEnum, IntPtr dwData);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern bool GetMonitorInfo(IntPtr hMonitor, ref MONITORINFOEX lpmi);

    [DllImport("Shcore.dll")]
    public static extern int GetDpiForMonitor(IntPtr hmonitor, int dpiType, out uint dpiX, out uint dpiY);

    public static List<SlateMonitorInfo> GetMonitors() {
        try { SetProcessDpiAwarenessContext(new IntPtr(-4)); } catch {}
        var list = new List<SlateMonitorInfo>();
        EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, delegate(IntPtr hMon, IntPtr hdc, ref RECT r, IntPtr d) {
            MONITORINFOEX mi = new MONITORINFOEX();
            mi.cbSize = Marshal.SizeOf(typeof(MONITORINFOEX));
            uint dx = 96, dy = 96;
            try { GetDpiForMonitor(hMon, 0, out dx, out dy); } catch {}
            if (GetMonitorInfo(hMon, ref mi)) {
                var info = new SlateMonitorInfo();
                info.DeviceName = mi.szDevice;
                info.Primary = (mi.dwFlags & 1) != 0;
                info.DpiX = (int)dx;
                info.Scale = (double)dx / 96.0;
                info.X = mi.rcMonitor.Left;
                info.Y = mi.rcMonitor.Top;
                info.Width = mi.rcMonitor.Right - mi.rcMonitor.Left;
                info.Height = mi.rcMonitor.Bottom - mi.rcMonitor.Top;
                info.WorkX = mi.rcWork.Left;
                info.WorkY = mi.rcWork.Top;
                info.WorkWidth = mi.rcWork.Right - mi.rcWork.Left;
                info.WorkHeight = mi.rcWork.Bottom - mi.rcWork.Top;
                info.WorkRight = mi.rcWork.Right;
                list.Add(info);
            }
            return true;
        }, IntPtr.Zero);
        return list;
    }
}
'@
    }
    return [SlateMonitorHelper]::GetMonitors()
}

$homeCards = @(
    @{c='Slate\DesktopClock';   i='DesktopClock.ini';   col='left'; dy=0;   w=760; h=240},
    @{c='Slate\Visualizer';     i='Visualizer.ini';     col='left'; dy=250; w=352; h=72},
    @{c='Slate\Clock';          i='Clock.ini';          col=1;      dy=0;   w=256; h=128},
    @{c='Slate\WorldClock';     i='WorldClock.ini';     col=1;      dy=136; w=256; h=64},
    @{c='Slate\Weather';        i='Weather.ini';        col=1;      dy=208; w=256; h=128},
    @{c='Slate\WeatherDetails'; i='WeatherDetails.ini'; col=1;      dy=344; w=256; h=64},
    @{c='Slate\SunMoon';        i='SunMoon.ini';        col=1;      dy=416; w=256; h=64},
    @{c='Slate\Calendar';       i='Calendar.ini';       col=1;      dy=488; w=256; h=264},
    @{c='Slate\CPU';            i='CPU.ini';            col=2;      dy=0;   w=256; h=128},
    @{c='Slate\RAM';            i='RAM.ini';            col=2;      dy=136; w=256; h=64},
    @{c='Slate\GPU';            i='GPU.ini';            col=2;      dy=208; w=256; h=128},
    @{c='Slate\Disk';           i='Disk.ini';           col=2;      dy=344; w=256; h=128},
    @{c='Slate\Network';        i='Network.ini';        col=2;      dy=480; w=256; h=128},
    @{c='Slate\Media';          i='Media.ini';          col=2;      dy=616; w=256; h=64},
    @{c='Slate\Volume';         i='Volume.ini';         col=2;      dy=688; w=256; h=64}
)

$workCards = @(
    @{c='Slate\Work\Comms';        i='Comms.ini';        col=1; dy=0;   w=256; h=320},
    @{c='Slate\Work\Bluetooth';    i='Bluetooth.ini';    col=1; dy=328; w=256; h=64},
    @{c='Slate\Work\Jira';         i='Jira.ini';         col=1; dy=400; w=256; h=192},
    @{c='Slate\Work\Confluence';   i='Confluence.ini';   col=1; dy=600; w=256; h=192},
    @{c='Slate\Work\ClaudeCost';   i='ClaudeCost.ini';   col=2; dy=0;   w=256; h=128},
    @{c='Slate\Work\CopilotQuota'; i='CopilotQuota.ini'; col=2; dy=136; w=256; h=128},
    @{c='Slate\Work\AIModels';     i='AIModels.ini';     col=2; dy=272; w=256; h=520},
    @{c='Slate\Work\Battery';      i='Battery.ini';      col=3; dy=0;   w=256; h=128},
    @{c='Slate\Work\Focus';        i='Focus.ini';        col=3; dy=136; w=256; h=128},
    @{c='Slate\Work\Stopwatch';    i='Stopwatch.ini';    col=3; dy=272; w=256; h=128},
    @{c='Slate\Work\Notes';        i='Notes.ini';        col=3; dy=408; w=256; h=384}
)

$allCards = $homeCards + $workCards

$screens = Get-SlateMonitors
$primary = $screens | Where-Object { $_.Primary } | Select-Object -First 1
if (-not $primary) { $primary = $screens[0] }
$secondary = $screens | Where-Object { -not $_.Primary } | Select-Object -First 1

$sigParts = foreach ($s in ($screens | Sort-Object X, Y)) {
    "$($s.X),$($s.Y),$($s.Width)x$($s.Height),$($s.WorkX),$($s.WorkY),$($s.WorkWidth)x$($s.WorkHeight),$($s.Primary)"
}
$topologyKey = "M$($screens.Count)_" + ($sigParts -join '|')

# Default: locked = $true (protected from accidental drag; UNLOCKED is highlighted when active)
$state = @{ locked = $true; lastTopology = '' }
if (Test-Path $stateFile) {
    try {
        $loaded = Get-Content $stateFile -Raw | ConvertFrom-Json
        if ($null -ne $loaded.locked) { $state.locked = [bool]$loaded.locked }
        if ($null -ne $loaded.lastTopology) { $state.lastTopology = [string]$loaded.lastTopology }
    } catch {}
}

function Save-State {
    $state | ConvertTo-Json | Set-Content -Path $stateFile -Encoding UTF8
}

function Read-IniPositions {
    $posMap = @{}
    if (Test-Path $rmIni) {
        $lines = [System.IO.File]::ReadAllLines($rmIni)
        $curSec = ''
        foreach ($l in $lines) {
            if ($l -match '^\[(.+)\]') {
                $curSec = $Matches[1]
            } elseif ($curSec -match '^Slate\\') {
                if (-not $posMap.ContainsKey($curSec)) { $posMap[$curSec] = @{} }
                if ($l -match '^WindowX=(.+)$') { $posMap[$curSec]['x'] = [int]$Matches[1] }
                if ($l -match '^WindowY=(.+)$') { $posMap[$curSec]['y'] = [int]$Matches[1] }
                if ($l -match '^Active=(.+)$')  { $posMap[$curSec]['active'] = [int]$Matches[1] }
            }
        }
    }
    return $posMap
}

# Magnetic grid & neighbor spacing snap (enforces 8px gap between 256px columns and vertical neighbors)
function Invoke-MagneticSnap {
    $posMap = Read-IniPositions
    $gap = 8
    $thresh = 22

    # 1. Build X and Y magnetic anchor lines from active cards (with 8px spacing)
    $activeList = @()
    foreach ($card in $allCards) {
        if ($card.col -eq 'left') { continue }
        $p = $posMap[$card.c]
        if ($p -and $p.active -eq 1 -and $null -ne $p.x -and $null -ne $p.y) {
            $activeList += @{
                c = $card.c
                x = [int]$p.x
                y = [int]$p.y
                w = [int]$card.w
                h = [int]$card.h
            }
        }
    }

    # Snap X first: align either to same column X or adjacent column X (+/- 264px = 256w + 8gap)
    foreach ($item in $activeList) {
        $bestX = $item.x
        $bestDist = $thresh + 1
        foreach ($other in $activeList) {
            if ($other.c -eq $item.c) { continue }
            $candidates = @(
                $other.x,
                ($other.x + $other.w + $gap),
                ($other.x - $item.w - $gap)
            )
            foreach ($cx in $candidates) {
                $d = [Math]::Abs($item.x - $cx)
                if ($d -gt 0 -and $d -lt $bestDist) {
                    $bestDist = $d
                    $bestX = $cx
                }
            }
        }
        # Also snap to the 8px grid if not snapped to a neighbor
        if ($bestDist -gt $thresh) {
            $gridX = [int]([Math]::Round($item.x / 8.0) * 8)
            if ([Math]::Abs($item.x - $gridX) -le 6) { $bestX = $gridX }
        }
        $item.x = $bestX
    }

    # Snap Y: within the same column (or nearby X), enforce exact 8px vertical gap or top alignment
    $byY = $activeList | Sort-Object y
    foreach ($item in $byY) {
        $bestY = $item.y
        $bestDist = $thresh + 1
        foreach ($other in $byY) {
            if ($other.c -eq $item.c) { continue }
            # Same column check
            if ([Math]::Abs($item.x - $other.x) -le 16) {
                $candidates = @(
                    ($other.y + $other.h + $gap),
                    ($other.y - $item.h - $gap)
                )
                foreach ($cy in $candidates) {
                    $d = [Math]::Abs($item.y - $cy)
                    if ($d -lt $bestDist) {
                        $bestDist = $d
                        $bestY = $cy
                    }
                }
            } else {
                # Neighbor column top/bottom alignment
                $candidates = @(
                    $other.y,
                    ($other.y + $other.h - $item.h)
                )
                foreach ($cy in $candidates) {
                    $d = [Math]::Abs($item.y - $cy)
                    if ($d -lt $bestDist) {
                        $bestDist = $d
                        $bestY = $cy
                    }
                }
            }
        }
        if ($bestDist -gt $thresh) {
            $gridY = [int]([Math]::Round($item.y / 8.0) * 8)
            if ([Math]::Abs($item.y - $gridY) -le 6) { $bestY = $gridY }
        }
        $item.y = $bestY
    }

    # Apply any snapped coordinates back to Rainmeter and update posMap
    foreach ($item in $activeList) {
        $orig = $posMap[$item.c]
        if ($orig.x -ne $item.x -or $orig.y -ne $item.y) {
            & $rm '!Move' $item.x $item.y $item.c
            $posMap[$item.c]['x'] = $item.x
            $posMap[$item.c]['y'] = $item.y
        }
    }
    return $posMap
}

function Update-ClockBadge([string]$statusText) {
    # Locked = subtle/faint; Unlocked = highlighted in Cyber-Sage Accent + open shackle!
    $lockColor   = if ($state.locked) { '155,164,178,105' } else { '110,185,172,255' }
    $shackleRightY = if ($state.locked) { '5' } else { '2' }
    $lockTip     = if ($state.locked) { 'Cards LOCKED (click to unlock & drag)' } else { 'EDIT MODE: UNLOCKED (click to lock & auto-snap 8px gaps)' }
    & $rm '!SetVariable' 'LockColor' $lockColor 'Slate\Clock'
    & $rm '!SetVariable' 'LockShackleY' $shackleRightY 'Slate\Clock'
    & $rm '!SetVariable' 'LockTip' $lockTip 'Slate\Clock'
    if ($statusText) {
        & $rm '!SetOption' 'MeterTZ' 'Text' $statusText 'Slate\Clock'
        & $rm '!UpdateMeter' '*' 'Slate\Clock'
        & $rm '!Redraw' 'Slate\Clock'
        Start-Sleep -Milliseconds 1200
        & $rm '!SetOption' 'MeterTZ' 'Text' '%1' 'Slate\Clock'
    }
    & $rm '!UpdateMeter' '*' 'Slate\Clock'
    & $rm '!Redraw' 'Slate\Clock'
}

if ($Action -eq 'ToggleLock') {
    $state.locked = -not $state.locked
    $val = if ($state.locked) { '0' } else { '1' }
    if ($state.locked) {
        # When locking back after editing, magnetically snap cards to 8px spacing!
        Invoke-MagneticSnap | Out-Null
    }
    foreach ($card in $allCards) {
        & $rm '!Draggable' $val $card.c
        & $rm '!SnapEdges' '1' $card.c
    }
    Save-State
    $msg = if ($state.locked) { 'LOCKED + SNAPPED' } else { 'UNLOCKED (DRAG)' }
    Update-ClockBadge $msg
    exit 0
}

if ($Action -eq 'Save') {
    $posMap = Invoke-MagneticSnap
    $saved = @{}
    if (Test-Path $savedFile) {
        try {
            $raw = Get-Content $savedFile -Raw | ConvertFrom-Json
            foreach ($p in $raw.PSObject.Properties) { $saved[$p.Name] = $p.Value }
        } catch {}
    }
    $saved[$topologyKey] = $posMap
    $saved | ConvertTo-Json -Depth 4 | Set-Content -Path $savedFile -Encoding UTF8
    Update-ClockBadge 'SNAPPED & SAVED'
    exit 0
}

if ($Action -eq 'Reset') {
    if (Test-Path $savedFile) {
        try {
            $saved = @{}
            $raw = Get-Content $savedFile -Raw | ConvertFrom-Json
            foreach ($p in $raw.PSObject.Properties) {
                if ($p.Name -ne $topologyKey) { $saved[$p.Name] = $p.Value }
            }
            $saved | ConvertTo-Json -Depth 4 | Set-Content -Path $savedFile -Encoding UTF8
        } catch {}
    }
    $Action = 'Realign'
    $Force = $true
}

if ($Action -eq 'Watch') {
    Update-ClockBadge ''
    if (-not $Force -and $state.lastTopology -eq $topologyKey) {
        exit 0
    }
    $Action = 'Realign'
}

if ($Action -eq 'Realign') {
    $state.lastTopology = $topologyKey
    Save-State

    $customPositions = $null
    if (Test-Path $savedFile) {
        try {
            $raw = Get-Content $savedFile -Raw | ConvertFrom-Json
            $prop = $raw.PSObject.Properties[$topologyKey]
            if ($prop) { $customPositions = $prop.Value }
        } catch {}
    }

    # Calculate smart positions for primary monitor
    $homeStackH = 752
    $rightMargin = [Math]::Max(48, [int][Math]::Round($primary.WorkWidth * 0.0375))
    $col2X = $primary.WorkRight - 256 - $rightMargin
    $col1X = $col2X - 8 - 256
    $topY  = $primary.WorkY + [Math]::Max(24, [int][Math]::Floor(($primary.WorkHeight - $homeStackH) / 2))

    $leftX = $primary.WorkX + [Math]::Max(48, [int][Math]::Round($primary.WorkWidth * 0.085))
    $leftY = $primary.WorkY + [Math]::Max(60, [int][Math]::Round($primary.WorkHeight * 0.52))

    $dragVal = if ($state.locked) { '0' } else { '1' }

    foreach ($card in $homeCards) {
        $tx = if ($card.col -eq 'left') { $leftX } elseif ($card.col -eq 1) { $col1X } else { $col2X }
        $ty = if ($card.col -eq 'left') { $leftY + $card.dy } else { $topY + $card.dy }

        if ($customPositions -and $customPositions.PSObject.Properties[$card.c]) {
            $cp = $customPositions.PSObject.Properties[$card.c].Value
            if ($null -ne $cp.x -and $null -ne $cp.y) {
                $tx = [int]$cp.x
                $ty = [int]$cp.y
            }
        }
        & $rm '!ActivateConfig' $card.c $card.i
        & $rm '!Move' $tx $ty $card.c
        & $rm '!Draggable' $dragVal $card.c
        & $rm '!SnapEdges' '1' $card.c
    }

    if ($null -ne $secondary) {
        $workStackH = 792
        $secMargin = [Math]::Max(32, [int][Math]::Round($secondary.WorkWidth * 0.05))
        $wCol3X = $secondary.WorkRight - 256 - $secMargin
        $wCol2X = $wCol3X - 8 - 256
        $wCol1X = $wCol2X - 8 - 256
        $wTopY  = $secondary.WorkY + [Math]::Max(16, [int][Math]::Floor(($secondary.WorkHeight - $workStackH) / 2))

        foreach ($card in $workCards) {
            $tx = if ($card.col -eq 1) { $wCol1X } elseif ($card.col -eq 2) { $wCol2X } else { $wCol3X }
            $ty = $wTopY + $card.dy

            if ($customPositions -and $customPositions.PSObject.Properties[$card.c]) {
                $cp = $customPositions.PSObject.Properties[$card.c].Value
                if ($null -ne $cp.x -and $null -ne $cp.y) {
                    $tx = [int]$cp.x
                    $ty = [int]$cp.y
                }
            }
            & $rm '!ActivateConfig' $card.c $card.i
            & $rm '!Move' $tx $ty $card.c
            & $rm '!Draggable' $dragVal $card.c
            & $rm '!SnapEdges' '1' $card.c
        }
    } else {
        # Single monitor mode: hide Work cards automatically so they don't clutter the single screen
        foreach ($card in $workCards) {
            & $rm '!DeactivateConfig' $card.c
        }
    }

    Update-ClockBadge 'LAYOUT REALIGNED'
}
