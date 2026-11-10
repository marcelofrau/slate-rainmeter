-- Slate autoscale: rolling peak with decay, so graphs stay readable
-- at idle (CPU 2% or idle network no longer hug the bottom of the
-- graph). Pure ASCII on purpose: Rainmeter may read .lua as ANSI.
--
-- Performance optimization: caches last sent string and only fires
-- !SetOption when the rounded peak changes by >= 0.5%, avoiding
-- redundant Rainmeter option parsing every tick.
--
-- Skin variable AutoScale, one spec per graph, ';' separated:
--   sourceMeasure|graphMeasure|floor|decay|[peakMeasure]

local specs = {}

local function parse()
  local list = SKIN:GetVariable('AutoScale', '')
  for item in string.gmatch(list, '[^;]+') do
    local src, dst, floor, decay, peakm =
      string.match(item, '^([^|]+)|([^|]+)|([^|]+)|([^|]+)|?(.*)$')
    if src and dst then
      local fl = tonumber(floor) or 1
      table.insert(specs, {
        src = SKIN:GetMeasure(src),
        dst = dst,
        floor = fl,
        decay = tonumber(decay) or 0.97,
        peak = fl,
        lastSent = -1,
        peakm = (peakm and peakm ~= '') and peakm or nil,
      })
    end
  end
end

function Initialize()
  parse()
end

function Update()
  for _, s in ipairs(specs) do
    if s.src then
      local v = s.src:GetValue()
      s.peak = math.max(v, s.peak * s.decay, s.floor)
      if math.abs(s.peak - s.lastSent) >= (s.peak * 0.005) then
        s.lastSent = s.peak
        local pstr = string.format('%.1f', s.peak)
        SKIN:Bang('!SetOption', s.dst, 'MaxValue', pstr)
        if s.peakm then
          SKIN:Bang('!SetOption', s.peakm, 'Formula', pstr)
        end
      end
    end
  end
end
