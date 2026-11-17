local presets = { 5, 10, 15, 20, 25, 30 }
local initialSeconds = 25 * 60
local remaining = initialSeconds
local finishAt = nil
local running = false

local function updatePresetColors(activeMin)
  local accent = SKIN:GetVariable('AccentColor', '110,185,172') .. ',255'
  local faint = SKIN:GetVariable('TextFaint', '155,164,178,200')
  for _, m in ipairs(presets) do
    SKIN:Bang('!SetOption', 'MeterP' .. tostring(m), 'FontColor', (m == activeMin) and accent or faint)
  end
end

local function syncUI(status)
  local pct = math.floor(((initialSeconds - remaining) / math.max(initialSeconds, 1)) * 100 + 0.5)
  pct = math.max(0, math.min(100, pct))
  local activeMin = math.floor(initialSeconds / 60 + 0.5)
  SKIN:Bang('!SetVariable', 'FocusMinutes', tostring(activeMin))
  SKIN:Bang('!SetVariable', 'FocusStatus', status)
  SKIN:Bang('!SetVariable', 'FocusPct', tostring(pct))
  SKIN:Bang('!SetVariable', 'FocusIcon', running and 'Pause.png' or 'Play.png')
  updatePresetColors(activeMin)
  SKIN:Bang('!UpdateMeter', '*')
  SKIN:Bang('!Redraw')
end

function Initialize()
  local minutes = tonumber(SKIN:GetVariable('FocusMinutes')) or 25
  minutes = math.max(1, math.floor(minutes))
  initialSeconds = minutes * 60
  remaining = initialSeconds
  syncUI('READY')
end

function Update()
  if running then
    remaining = math.max(0, finishAt - os.time())
    if remaining == 0 then
      running = false
      finishAt = nil
      syncUI('DONE')
    else
      local pct = math.floor(((initialSeconds - remaining) / math.max(initialSeconds, 1)) * 100 + 0.5)
      SKIN:Bang('!SetVariable', 'FocusPct', tostring(math.max(0, math.min(100, pct))))
    end
  end

  return string.format('%02d:%02d', math.floor(remaining / 60), remaining % 60)
end

function SetMinutes(mins)
  local m = tonumber(mins) or 25
  m = math.max(1, math.floor(m))
  running = false
  finishAt = nil
  initialSeconds = m * 60
  remaining = initialSeconds
  SKIN:Bang('!UpdateMeasure', 'MeasureFocusTimer')
  syncUI('READY')
end

function StepPreset(delta)
  local cur = math.floor(initialSeconds / 60 + 0.5)
  local idx = 5
  for i, v in ipairs(presets) do
    if v == cur then idx = i break end
  end
  idx = ((idx - 1 + (tonumber(delta) or 1)) % #presets) + 1
  SetMinutes(presets[idx])
end

function Toggle()
  if running then
    remaining = math.max(0, finishAt - os.time())
    running = false
    finishAt = nil
    syncUI(remaining == 0 and 'DONE' or 'PAUSED')
  elseif remaining > 0 then
    finishAt = os.time() + remaining
    running = true
    syncUI('FOCUS')
  else
    remaining = initialSeconds
    finishAt = os.time() + remaining
    running = true
    syncUI('FOCUS')
  end
end

function Reset()
  running = false
  finishAt = nil
  remaining = initialSeconds
  SKIN:Bang('!UpdateMeasure', 'MeasureFocusTimer')
  syncUI('READY')
end
