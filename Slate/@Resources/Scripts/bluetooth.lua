local cachePath = nil
local lastSignature = nil
local tick = 0

local function applyMap(map)
  SKIN:Bang('!SetVariable', 'BTActiveCount', map['active_count'] or '0')
  SKIN:Bang('!SetVariable', 'HSName', map['hs_name'] or 'Headset')
  SKIN:Bang('!SetVariable', 'HSBat', map['hs_bat'] or '0')
  SKIN:Bang('!SetVariable', 'KBName', map['kb_name'] or 'Keyboard')
  SKIN:Bang('!SetVariable', 'KBBat', map['kb_bat'] or '0')
  SKIN:Bang('!SetVariable', 'MSName', map['ms_name'] or 'Mouse')
  SKIN:Bang('!SetVariable', 'MSBat', map['ms_bat'] or '0')
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
  cachePath = SKIN:GetVariable('BTCachePath', '')
  ReadCache()
end

function Update()
  tick = tick + 1
  if tick % 2 == 0 then
    SKIN:Bang('!CommandMeasure', 'MeasureFetchBT', 'Run')
  end
  ReadCache()
  return SKIN:GetVariable('BTActiveCount', '0')
end
