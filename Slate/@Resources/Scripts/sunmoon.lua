-- Slate Sun & Moon Calculator
-- Computes real astronomical lunar phase (synodic month = 29.530588853 days
-- anchored to the reference new moon of 2000-01-06 18:14 UTC) and updates
-- the 8-phase moon icon, phase name, and illumination percentage.
-- Pure ASCII script for Rainmeter Lua compatibility.

local SYNODIC_SECONDS = 2551442.8768992 -- 29.530588853 * 86400
local REF_NEW_MOON    = 947182440       -- 2000-01-06 18:14:00 UTC

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

local function updateMoon()
  local now = os.time()
  local cycle = ((now - REF_NEW_MOON) % SYNODIC_SECONDS) / SYNODIC_SECONDS
  if cycle < 0 then cycle = cycle + 1.0 end

  local illum = math.floor(((1.0 - math.cos(2.0 * math.pi * cycle)) * 0.5) * 100 + 0.5)
  local idx = math.floor((cycle * 8.0) + 0.5) % 8
  local name = PHASE_NAMES[idx] or 'Moon'

  SKIN:Bang('!SetOption', 'MeterMoonIcon', 'ImageName',
    string.format('#@#Images\\Icons\\MoonPhase_%d.png', idx))
  SKIN:Bang('!SetOption', 'MeterMoonTitle', 'Text', name)
  SKIN:Bang('!SetOption', 'MeterMoonSub', 'Text', string.format('%d%% illuminated', illum))
  SKIN:Bang('!UpdateMeter', 'MeterMoonIcon')
  SKIN:Bang('!UpdateMeter', 'MeterMoonTitle')
  SKIN:Bang('!UpdateMeter', 'MeterMoonSub')
  SKIN:Bang('!Redraw')
end

function Initialize()
  updateMoon()
end

function Update()
  updateMoon()
end
