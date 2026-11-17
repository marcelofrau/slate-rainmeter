local cachePath = nil
local lastSignature = nil

local function applyMap(map)
  local baseUrl = map['base_url'] or ''
  SKIN:Bang('!SetVariable', 'ConfBaseUrl', baseUrl)
  SKIN:Bang('!SetVariable', 'ConfStatus', map['status'] or 'OFFLINE')
  SKIN:Bang('!SetVariable', 'ConfCount', map['count'] or '0')
  SKIN:Bang('!SetVariable', 'ConfUpdated', map['updated'] or '--:--')
  for i = 1, 5 do
    SKIN:Bang('!SetVariable', 'C' .. i .. 'Title', map['c' .. i .. '_title'] or '')
    SKIN:Bang('!SetVariable', 'C' .. i .. 'Space', map['c' .. i .. '_space'] or '')
    SKIN:Bang('!SetVariable', 'C' .. i .. 'Url', map['c' .. i .. '_url'] or baseUrl)
  end
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
  cachePath = SKIN:GetVariable('ConfCachePath', '')
  ReadCache()
end

function Update()
  SKIN:Bang('!CommandMeasure', 'MeasureFetchConf', 'Run')
  ReadCache()
  return SKIN:GetVariable('ConfCount', '0')
end
