local cachePath = nil
local lastSignature = nil
local tick = 0

local function applyMap(map)
  local status = map['status'] or 'OFFLINE'
  local leftPct = tonumber(map['left_pct'] or '0') or 0
  local used = map['used'] or '0'
  local total = map['total'] or '0'
  local rem = map['rem'] or '0'
  local plan = map['plan'] or 'BUSINESS'
  local resetDays = map['reset_days'] or '--'
  local updated = map['updated'] or '--:--'

  SKIN:Bang('!SetVariable', 'CopilotStatus', status)
  SKIN:Bang('!SetVariable', 'CopilotLeftPct', string.format('%.1f', leftPct))
  SKIN:Bang('!SetVariable', 'CopilotUsed', used)
  SKIN:Bang('!SetVariable', 'CopilotTotal', total)
  SKIN:Bang('!SetVariable', 'CopilotRem', rem)
  SKIN:Bang('!SetVariable', 'CopilotPlan', plan)
  SKIN:Bang('!SetVariable', 'CopilotReset', resetDays)
  SKIN:Bang('!SetVariable', 'CopilotUpdated', updated)
  SKIN:Bang('!UpdateMeter', '*')
  SKIN:Bang('!Redraw')
end

function ReadCache()
  if not cachePath or cachePath == '' then return end
  local f = io.open(cachePath, 'r')
  if not f then return end
  local raw = f:read('*a') or ''
  f:close()
  if raw == '' or raw == lastSignature then return end
  lastSignature = raw

  local map = {}
  for line in raw:gmatch('[^\r\n]+') do
    line = line:gsub('^\239\187\191', '')
    local k, v = line:match('^([^=]+)=(.*)$')
    if k and v then map[k] = v end
  end
  applyMap(map)
end

function Initialize()
  cachePath = SKIN:GetVariable('CopilotCachePath', '')
  ReadCache()
end

function Update()
  tick = tick + 1
  if tick % 15 == 0 then
    SKIN:Bang('!CommandMeasure', 'MeasureFetchCopilot', 'Run')
  end
  ReadCache()
  return SKIN:GetVariable('CopilotLeftPct', '0.0')
end
