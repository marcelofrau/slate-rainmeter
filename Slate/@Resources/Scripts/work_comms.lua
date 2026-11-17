local cachePath = nil
local lastSignature = nil

local function applyMap(map)
  local mailState = map['olk_mail_state'] or '0 new mail'
  local upcomingCnt = map['upcoming_count'] or '0'
  local updated = map['updated'] or '--:--'

  SKIN:Bang('!SetVariable', 'MailState', mailState)
  SKIN:Bang('!SetVariable', 'UpcomingCount', upcomingCnt)
  SKIN:Bang('!SetVariable', 'CommsUpdated', updated)
  for i = 1, 8 do
    SKIN:Bang('!SetVariable', 'M' .. i .. 'Time', map['m' .. i .. '_time'] or '')
    SKIN:Bang('!SetVariable', 'M' .. i .. 'Title', map['m' .. i .. '_title'] or '')
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
  cachePath = SKIN:GetVariable('CommsCachePath', '')
  ReadCache()
end

function Update()
  SKIN:Bang('!CommandMeasure', 'MeasureFetchComms', 'Run')
  ReadCache()
  return SKIN:GetVariable('UpcomingCount', '0')
end
