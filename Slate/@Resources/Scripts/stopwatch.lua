local elapsed = 0
local startedClock = nil
local running = false
local lapCount = 0

local function formatTime(sec)
  local totalCentis = math.floor(sec * 100 + 0.5)
  local cs = totalCentis % 100
  local totalSec = math.floor(totalCentis / 100)
  local h = math.floor(totalSec / 3600)
  local m = math.floor((totalSec % 3600) / 60)
  local s = totalSec % 60
  if h > 0 then
    return string.format('%02d:%02d:%02d.%02d', h, m, s, cs)
  end
  return string.format('%02d:%02d.%02d', m, s, cs)
end

local function currentSeconds()
  if running and startedClock then
    return elapsed + math.max(0, os.clock() - startedClock)
  end
  return elapsed
end

local function syncUI(status)
  local sec = currentSeconds()
  local pct = math.floor(((sec % 60) / 60) * 100 + 0.5)
  SKIN:Bang('!SetOption', 'Rainmeter', 'Update', running and '50' or '1000')
  SKIN:Bang('!SetVariable', 'StopwatchStatus', status)
  SKIN:Bang('!SetVariable', 'StopwatchPct', tostring(pct))
  SKIN:Bang('!SetVariable', 'StopwatchIcon', running and 'Pause.png' or 'Play.png')
  SKIN:Bang('!UpdateMeter', '*')
  SKIN:Bang('!Redraw')
end

function Initialize()
  SKIN:Bang('!SetVariable', 'StopwatchSub', 'Lap  --:--.--')
  syncUI('READY')
end

function Update()
  local sec = currentSeconds()
  if running then
    local pct = math.floor(((sec % 60) / 60) * 100 + 0.5)
    SKIN:Bang('!SetVariable', 'StopwatchPct', tostring(pct))
  end
  return formatTime(sec)
end

function Toggle()
  if running then
    elapsed = currentSeconds()
    startedClock = nil
    running = false
    syncUI('PAUSED')
  else
    startedClock = os.clock()
    running = true
    syncUI('RUNNING')
  end
end

function Lap()
  local sec = currentSeconds()
  if sec <= 0 then return end
  lapCount = lapCount + 1
  SKIN:Bang('!SetVariable', 'StopwatchSub', string.format('Lap %d  ·  %s', lapCount, formatTime(sec)))
  SKIN:Bang('!UpdateMeter', 'MeterSub')
  SKIN:Bang('!Redraw')
end

function Reset()
  running = false
  startedClock = nil
  elapsed = 0
  lapCount = 0
  SKIN:Bang('!SetVariable', 'StopwatchSub', 'Lap  --:--.--')
  SKIN:Bang('!UpdateMeasure', 'MeasureStopwatch')
  syncUI('READY')
end
