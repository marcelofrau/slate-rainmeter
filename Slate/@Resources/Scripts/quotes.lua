-- Slate Quotes Loader & Terminal Typewriter Animator
-- Reads @Resources\Data\quotes.txt (format: "Quote text | Source")
-- Uses ActionTimer.dll bursts (25ms steps) so the skin stays at
-- Update=15000 (zero idle CPU) and only animates during transitions.
-- Pure ASCII script for Rainmeter Lua compatibility.

local quotes = {}
local curIdx = 0

local fullQuote = ''
local fullSource = ''
local stepPos = 0
local totalChars = 0
local stepSize = 2

local function trim(s)
  return (string.gsub(s, '^%s*(.-)%s*$', '%1'))
end

local function loadQuotes()
  quotes = {}
  local path = SKIN:GetVariable('@') .. 'Data\\quotes.txt'
  local f = io.open(path, 'r')
  if not f then return end

  for line in f:lines() do
    line = trim(line)
    if line ~= '' and string.sub(line, 1, 1) ~= '#' then
      local q, src = string.match(line, '^(.-)%s*|%s*(.+)$')
      if q and src then
        table.insert(quotes, { text = trim(q), source = trim(src) })
      else
        table.insert(quotes, { text = line, source = '' })
      end
    end
  end
  f:close()
end

local function startTypewriter(idx)
  if #quotes == 0 then return end
  curIdx = ((idx - 1) % #quotes) + 1
  local entry = quotes[curIdx]

  fullQuote = '> "' .. entry.text .. '"'
  if entry.source ~= '' then
    fullSource = '//  ' .. string.upper(entry.source)
  else
    fullSource = ''
  end

  -- Dynamic step size so any quote finishes in ~32 frames (~0.8s at 25ms)
  totalChars = string.len(fullQuote) + string.len(fullSource)
  stepSize = math.max(2, math.ceil(totalChars / 32))
  stepPos = 0

  SKIN:Bang('!CommandMeasure', 'MeasureTypeTimer', 'Stop 1')
  SKIN:Bang('!CommandMeasure', 'MeasureTypeTimer', 'Execute 1')
end

function TypeStep()
  stepPos = stepPos + stepSize
  local qLen = string.len(fullQuote)
  local qSub = ''
  local sSub = ''

  if stepPos < qLen then
    qSub = string.sub(fullQuote, 1, stepPos) .. '_'
    sSub = ''
  elseif stepPos < totalChars then
    qSub = fullQuote
    local sCount = stepPos - qLen
    sSub = string.sub(fullSource, 1, sCount) .. '_'
  else
    qSub = fullQuote
    sSub = fullSource
    SKIN:Bang('!CommandMeasure', 'MeasureTypeTimer', 'Stop 1')
  end

  SKIN:Bang('!SetOption', 'MeterQuoteShadow', 'Text', qSub)
  SKIN:Bang('!SetOption', 'MeterQuoteText', 'Text', qSub)
  SKIN:Bang('!SetOption', 'MeterQuoteSource', 'Text', sSub)
  SKIN:Bang('!UpdateMeter', 'MeterQuoteShadow')
  SKIN:Bang('!UpdateMeter', 'MeterQuoteText')
  SKIN:Bang('!UpdateMeter', 'MeterQuoteSource')
  SKIN:Bang('!Redraw')
end

function Initialize()
  math.randomseed(os.time() + (os.clock() * 1000))
  math.random(); math.random()
  loadQuotes()
  if #quotes > 0 then
    startTypewriter(math.random(1, #quotes))
  end
end

function Update()
  -- Called every UpdateDivider=4 (4 * 15000ms = 60s = 1 minute)
  NextQuote()
end

function NextQuote()
  if #quotes == 0 then return end
  if #quotes == 1 then
    startTypewriter(1)
    return
  end
  local nextIdx = math.random(1, #quotes - 1)
  if nextIdx >= curIdx then nextIdx = nextIdx + 1 end
  startTypewriter(nextIdx)
end
