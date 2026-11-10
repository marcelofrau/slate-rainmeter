-- Slate Quotes Loader & Rotator
-- Reads @Resources\Data\quotes.txt (format: "Quote text | Source")
-- Pure ASCII script for Rainmeter Lua compatibility.

local quotes = {}
local curIdx = 0

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

local function applyQuote(idx)
  if #quotes == 0 then return end
  curIdx = ((idx - 1) % #quotes) + 1
  local entry = quotes[curIdx]
  local qText = '"' .. entry.text .. '"'
  SKIN:Bang('!SetOption', 'MeterQuoteShadow', 'Text', qText)
  SKIN:Bang('!SetOption', 'MeterQuoteText', 'Text', qText)
  if entry.source ~= '' then
    SKIN:Bang('!SetOption', 'MeterQuoteSource', 'Text', '//  ' .. string.upper(entry.source))
  else
    SKIN:Bang('!SetOption', 'MeterQuoteSource', 'Text', '')
  end
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
    applyQuote(math.random(1, #quotes))
  end
end

function Update()
  -- Called every UpdateDivider ticks to rotate quote automatically
  NextQuote()
end

function NextQuote()
  if #quotes <= 1 then return end
  local nextIdx = math.random(1, #quotes - 1)
  if nextIdx >= curIdx then nextIdx = nextIdx + 1 end
  applyQuote(nextIdx)
end
