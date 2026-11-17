local cachePath = nil
local lastSignature = nil

local function applyMap(map)
  local baseUrl = map['base_url'] or ''
  SKIN:Bang('!SetVariable', 'JiraBaseUrl', baseUrl)
  SKIN:Bang('!SetVariable', 'JiraStatus', map['status'] or 'OFFLINE')
  SKIN:Bang('!SetVariable', 'JiraTotal', map['total'] or '0')
  SKIN:Bang('!SetVariable', 'JiraUpdated', map['updated'] or '--:--')
  for i = 1, 5 do
    local k = map['j' .. i .. '_key'] or ''
    local s = map['j' .. i .. '_sum'] or ''
    local st = map['j' .. i .. '_status'] or ''
    local u = map['j' .. i .. '_url'] or baseUrl
    local label = (k ~= '' and (k .. ' · ' .. s)) or ''
    SKIN:Bang('!SetVariable', 'J' .. i .. 'Label', label)
    SKIN:Bang('!SetVariable', 'J' .. i .. 'Status', st)
    SKIN:Bang('!SetVariable', 'J' .. i .. 'Url', u)
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
  cachePath = SKIN:GetVariable('JiraCachePath', '')
  ReadCache()
end

function Update()
  SKIN:Bang('!CommandMeasure', 'MeasureFetchJira', 'Run')
  ReadCache()
  return SKIN:GetVariable('JiraTotal', '0')
end
