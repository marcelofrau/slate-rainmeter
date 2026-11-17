local cachePath = nil
local lastSignature = nil
local tick = 0

local function applyValues(map)
  local status = map['status'] or 'IDLE'
  local month = map['month'] or '--'
  local day = map['day'] or '--'
  local period = map['period'] or '--'
  local opusPct = tonumber(map['opus_pct'] or '0') or 0
  local sonnetPct = tonumber(map['sonnet_pct'] or '0') or 0
  local haikuPct = tonumber(map['haiku_pct'] or '0') or 0
  local opusTurns = map['opus_turns'] or '0'
  local sonnetTurns = map['sonnet_turns'] or '0'
  local haikuTurns = map['haiku_turns'] or '0'
  local finopsUrl = map['finops_url'] or ''
  local updated = map['updated'] or '--:--'

  SKIN:Bang('!SetVariable', 'CostStatus', status)
  SKIN:Bang('!SetVariable', 'CostMonth', month)
  SKIN:Bang('!SetVariable', 'CostDay', day)
  SKIN:Bang('!SetVariable', 'CostPeriod', period)
  SKIN:Bang('!SetVariable', 'OpusPct', string.format('%.1f', opusPct))
  SKIN:Bang('!SetVariable', 'SonnetPct', string.format('%.1f', sonnetPct))
  SKIN:Bang('!SetVariable', 'HaikuPct', string.format('%.1f', haikuPct))
  SKIN:Bang('!SetVariable', 'OpusTurns', opusTurns)
  SKIN:Bang('!SetVariable', 'SonnetTurns', sonnetTurns)
  SKIN:Bang('!SetVariable', 'HaikuTurns', haikuTurns)
  SKIN:Bang('!SetVariable', 'FinOpsUrl', finopsUrl)
  SKIN:Bang('!SetVariable', 'CostUpdated', updated)
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
  applyValues(map)
end

function Initialize()
  cachePath = SKIN:GetVariable('CostCachePath', '')
  ReadCache()
end

function Update()
  tick = tick + 1
  if tick % 15 == 0 then
    SKIN:Bang('!CommandMeasure', 'MeasureFetchCost', 'Run')
  end
  ReadCache()
  return SKIN:GetVariable('CostMonth', '--')
end
