-- Slate Visualizer (VU Meter Spectrum Bar)
-- Adaptive FPS + Smooth Fade-Out after 2s of silence:
--   * Active audio: Update=25 (40 FPS), fadeFactor quickly ramps to 1.0.
--   * Silence < 2s (80 ticks): bars & peaks rest at bottom baseline.
--   * Silence > 2s (ticks 80..105): smooth 0.6s fade-out to alpha=0.
--   * Fully faded: switches skin Update to 250ms (4 FPS) and skips all
--     GDI+ redraws until audio returns -> near-zero idle CPU.
-- Pure ASCII script for Rainmeter Lua compatibility.

local MAX_SLOTS = 64
local bands = 32
local barW = 8
local barGap = 3
local maxH = 72
local showPeak = 1

local bandMeasures = {}
local rmsMeasure = nil
local peaks = {}
local peakVel = {}
local lastBarSpec = {}
local lastPeakSpec = {}
local silentTicks = 0
local fadeFactor = 1.0
local isSleeping = false

local function setupGeometry()
  bands = math.min(MAX_SLOTS, math.max(4, tonumber(SKIN:GetVariable('VizBands', '32')) or 32))
  barW = tonumber(SKIN:GetVariable('VizBarW', '8')) or 8
  barGap = tonumber(SKIN:GetVariable('VizBarGap', '3')) or 3
  maxH = tonumber(SKIN:GetVariable('VizHeight', '72')) or 72
  showPeak = tonumber(SKIN:GetVariable('VizPeakHold', '1')) or 1

  local totalW = bands * barW + (bands - 1) * barGap
  local totalH = maxH + 8

  SKIN:Bang('!SetOption', 'MeasureAudioRaw', 'Bands', tostring(bands))
  SKIN:Bang('!SetOption', 'MeterDragHit', 'Shape',
    string.format('Rectangle 0,0,%d,%d | StrokeWidth 0 | Fill Color 0,0,0,1', totalW, totalH))

  for i = 1, MAX_SLOTS do
    peaks[i] = 2
    peakVel[i] = 0
    lastBarSpec[i] = ''
    lastPeakSpec[i] = ''
    if i > bands then
      local shapeKey = (i == 1) and 'Shape' or ('Shape' .. i)
      SKIN:Bang('!SetOption', 'MeterBars', shapeKey, 'Rectangle 0,0,0,0 | StrokeWidth 0 | Fill Color 0,0,0,0')
      SKIN:Bang('!SetOption', 'MeterBars', 'Shape' .. (MAX_SLOTS + i), 'Rectangle 0,0,0,0 | StrokeWidth 0 | Fill Color 0,0,0,0')
    end
  end

  silentTicks = 0
  fadeFactor = 1.0
  isSleeping = false
end

function Initialize()
  rmsMeasure = SKIN:GetMeasure('MeasureAudioRMS')
  for i = 0, MAX_SLOTS - 1 do
    bandMeasures[i + 1] = SKIN:GetMeasure('MeasureBand' .. i)
  end
  setupGeometry()
end

function SetPreset(n, w, g)
  SKIN:Bang('!SetVariable', 'VizBands', tostring(n))
  SKIN:Bang('!SetVariable', 'VizBarW', tostring(w))
  SKIN:Bang('!SetVariable', 'VizBarGap', tostring(g))
  SKIN:Bang('!WriteKeyValue', 'Variables', 'VizBands', tostring(n), '#@#variables.inc')
  SKIN:Bang('!WriteKeyValue', 'Variables', 'VizBarW', tostring(w), '#@#variables.inc')
  SKIN:Bang('!WriteKeyValue', 'Variables', 'VizBarGap', tostring(g), '#@#variables.inc')
  SKIN:Bang('!Refresh')
end

function Update()
  local rms = rmsMeasure and rmsMeasure:GetValue() or 0

  -- Fast path: already faded out to 0 and still silent
  if isSleeping and rms <= 0.002 then
    return
  end

  local anyActive = (rms > 0.002)
  local heights = {}

  for i = 1, bands do
    local m = bandMeasures[i]
    local v = m and m:GetValue() or 0
    local h = math.max(2, math.floor(v * maxH + 0.5))
    heights[i] = h

    if h > 2 or peaks[i] > 2.5 then
      anyActive = true
    end

    if h >= peaks[i] then
      peaks[i] = h
      peakVel[i] = 0
    else
      peakVel[i] = peakVel[i] + 0.22
      peaks[i] = math.max(2, peaks[i] - peakVel[i])
    end
  end

  if anyActive then
    if isSleeping then
      isSleeping = false
      SKIN:Bang('!SetOption', 'Rainmeter', 'Update', '25')
    end
    silentTicks = 0
    fadeFactor = math.min(1.0, fadeFactor + 0.25)
  else
    silentTicks = silentTicks + 1
    -- After 80 ticks (80 * 25ms = 2.0 seconds) of silence, fade out smoothly
    if silentTicks > 80 then
      fadeFactor = math.max(0.0, fadeFactor - 0.04)
    end
  end

  local changed = false
  local r = math.min(2, math.floor(barW / 2))

  for i = 1, bands do
    local h = heights[i]
    local x = (i - 1) * (barW + barGap)
    local y = maxH - h + 4
    local baseBarAlpha = (h <= 2) and 55 or 215
    local barAlpha = math.floor(baseBarAlpha * fadeFactor + 0.5)

    local barSpec = string.format(
      'Rectangle %d,%d,%d,%d,%d,%d | StrokeWidth 0 | Fill Color #AccentColor#,%d',
      x, y, barW, h, r, r, barAlpha
    )
    if barSpec ~= lastBarSpec[i] then
      lastBarSpec[i] = barSpec
      changed = true
      local shapeKey = (i == 1) and 'Shape' or ('Shape' .. i)
      SKIN:Bang('!SetOption', 'MeterBars', shapeKey, barSpec)
    end

    if showPeak == 1 then
      local py = math.max(2, math.floor(maxH - peaks[i] + 1))
      local basePeakAlpha = (peaks[i] <= 2.5) and 90 or 230
      local peakAlpha = math.floor(basePeakAlpha * fadeFactor + 0.5)
      local peakSpec = string.format(
        'Rectangle %d,%d,%d,2,1,1 | StrokeWidth 0 | Fill Color #TextPrimary#,%d',
        x, py, barW, peakAlpha
      )
      if peakSpec ~= lastPeakSpec[i] then
        lastPeakSpec[i] = peakSpec
        changed = true
        SKIN:Bang('!SetOption', 'MeterBars', 'Shape' .. (MAX_SLOTS + i), peakSpec)
      end
    end
  end

  if changed then
    SKIN:Bang('!UpdateMeter', 'MeterBars')
    SKIN:Bang('!Redraw')
  end

  if not anyActive and fadeFactor <= 0.0 and not isSleeping then
    isSleeping = true
    SKIN:Bang('!SetOption', 'Rainmeter', 'Update', '250')
  end
end
