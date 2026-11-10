-- Slate Sun & Moon (Illustrated Vector Moon Phase + Solar Horizon Arc)
-- Drives:
--   1) Illustrated vector moon phase icon (MoonPhase_0..7.png) on the left.
--   2) Visual horizon arc on the right with a moving Sun/Moon orb along the
--      curve between Sunrise and Sunset, plus astronomical Moon Phase subtext.
-- Pure ASCII script for Rainmeter Lua compatibility.

local SYNODIC_SECONDS = 2551442.8768992
local REF_NEW_MOON    = 947182440

local PHASE_NAMES = {
  [0] = 'New Moon',
  [1] = 'Waxing Crescent',
  [2] = 'First Quarter',
  [3] = 'Waxing Gibbous',
  [4] = 'Full Moon',
  [5] = 'Waning Gibbous',
  [6] = 'Last Quarter',
  [7] = 'Waning Crescent',
}

local function parseHHMM(s)
  if not s then return nil end
  local h, m = string.match(s, '^(%d%d):(%d%d)$')
  if not h then return nil end
  return tonumber(h) * 60 + tonumber(m)
end

function Update()
  local mRise = SKIN:GetMeasure('MeasureSunrise')
  local mSet  = SKIN:GetMeasure('MeasureSunset')
  local riseStr = mRise and mRise:GetStringValue() or '07:45'
  local setStr  = mSet  and mSet:GetStringValue()  or '17:50'

  local riseMin = parseHHMM(riseStr) or (7 * 60 + 45)
  local setMin  = parseHHMM(setStr)  or (17 * 60 + 50)
  local nowMin  = tonumber(os.date('%H')) * 60 + tonumber(os.date('%M'))

  local isDay = (nowMin >= riseMin and nowMin <= setMin) and 1 or 0
  local progress = 0.0
  if nowMin <= riseMin then
    progress = 0.0
  elseif nowMin >= setMin then
    progress = 1.0
  else
    progress = (nowMin - riseMin) / math.max(1, (setMin - riseMin))
  end

  -- 1) Astronomical Moon Phase icon & text
  local now = os.time()
  local cycle = ((now - REF_NEW_MOON) % SYNODIC_SECONDS) / SYNODIC_SECONDS
  if cycle < 0 then cycle = cycle + 1.0 end
  local illum = math.floor(((1.0 - math.cos(2.0 * math.pi * cycle)) * 0.5) * 100 + 0.5)
  local idx = math.floor((cycle * 8.0) + 0.5) % 8
  local phaseName = PHASE_NAMES[idx] or 'Moon'

  SKIN:Bang('!SetOption', 'MeterMoonIcon', 'ImageName',
    string.format('#@#Images\\Icons\\MoonPhase_%d.png', idx))
  SKIN:Bang('!SetOption', 'MeterMoonSub', 'Text',
    string.format('%s  ·  %d%% moon', phaseName, illum))

  -- 2) Visual Sun Trajectory Arc on the right (from X=114,Y=28 to X=194,Y=28, peak Y=12)
  local arcX = 114 + progress * 80.0
  local arcY = 28 - math.sin(progress * math.pi) * 16.0
  local orbColor = (isDay == 1) and '#AccentColor#,255' or '195,202,214,180'
  local glowAlpha = (isDay == 1) and 55 or 25
  SKIN:Bang('!SetOption', 'MeterSunArc', 'Shape3',
    string.format('Ellipse %.1f,%.1f,6,6 | StrokeWidth 0 | Fill Color #AccentColor#,%d', arcX, arcY, glowAlpha))
  SKIN:Bang('!SetOption', 'MeterSunArc', 'Shape4',
    string.format('Ellipse %.1f,%.1f,3,3 | StrokeWidth 0 | Fill Color %s', arcX, arcY, orbColor))

  SKIN:Bang('!UpdateMeter', '*')
  SKIN:Bang('!Redraw')
end

function Initialize()
  Update()
end
