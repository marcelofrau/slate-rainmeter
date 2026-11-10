-- Slate Calendar + Spain / Aragon (Zaragoza) Holidays
-- Pure ASCII file (Rainmeter Lua loader safe).
-- Parses Nager.Date JSON from WebParser measure and also includes
-- fixed Spanish/Aragon holidays as instant fallback before network loads.

local viewYear = tonumber(os.date('%Y'))
local viewMonth = tonumber(os.date('%m'))
local lastDayCheck = -1
local holidays = {}

local MONTH_NAMES = {
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
}

local FIXED_ES = {
  ['01-01'] = "New Year's Day",
  ['01-06'] = 'Epiphany (Dia de Reyes)',
  ['01-29'] = 'San Valero (Zaragoza)',
  ['03-05'] = 'Cincomarzada (Zaragoza)',
  ['04-23'] = 'Day of Aragon (San Jorge)',
  ['05-01'] = 'Labour Day',
  ['08-15'] = 'Assumption Day',
  ['10-12'] = 'Fiesta Nacional / El Pilar',
  ['11-01'] = "All Saints' Day",
  ['12-06'] = 'Constitution Day',
  ['12-08'] = 'Immaculate Conception',
  ['12-25'] = 'Christmas Day',
}

local function daysInMonth(y, m)
  return tonumber(os.date('%d', os.time({year = y, month = m + 1, day = 0})))
end

local function seedFixedHolidays(y)
  for md, name in pairs(FIXED_ES) do
    local key = string.format('%04d-%s', y, md)
    if not holidays[key] then
      holidays[key] = name
    end
  end
end

local function parseApiJson()
  local m = SKIN:GetMeasure('MeasureHolidaysData')
  if not m then return end
  local raw = m:GetStringValue()
  if not raw or raw == '' then return end

  for obj in string.gmatch(raw, '%b{}') do
    local d = string.match(obj, '"date"%s*:%s*"(%d%d%d%d%-%d%d%-%d%d)"')
    local name = string.match(obj, '"name"%s*:%s*"([^"]+)"')
    local isGlobal = string.find(obj, '"global"%s*:%s*true') ~= nil
    local isAragon = string.find(obj, 'ES%-AR') ~= nil
    if d and name and (isGlobal or isAragon) then
      holidays[d] = name
    end
  end
end

local function render()
  seedFixedHolidays(viewYear)

  local nowY = tonumber(os.date('%Y'))
  local nowM = tonumber(os.date('%m'))
  local nowD = tonumber(os.date('%d'))

  SKIN:Bang('!SetOption', 'MeterMonthTitle', 'Text',
    string.format('%s, %d', MONTH_NAMES[viewMonth], viewYear))

  local firstTime = os.time({year = viewYear, month = viewMonth, day = 1, hour = 12})
  local firstWday = tonumber(os.date('%w', firstTime)) -- 0 = Sunday .. 6 = Saturday
  local curDays = daysInMonth(viewYear, viewMonth)

  local prevY, prevM = viewYear, viewMonth - 1
  if prevM < 1 then prevM = 12; prevY = prevY - 1 end
  local prevDays = daysInMonth(prevY, prevM)

  local todayPlaced = false
  local nextHolidayText = ''
  local firstMonthHolidayText = ''

  for i = 1, 42 do
    local col = (i - 1) % 7
    local row = math.floor((i - 1) / 7)
    local cx = 32 + col * 32
    local cy = 84 + row * 23

    local dayNum = i - firstWday
    local dispDay = dayNum
    local inMonth = true

    if dayNum < 1 then
      dispDay = prevDays + dayNum
      inMonth = false
    elseif dayNum > curDays then
      dispDay = dayNum - curDays
      inMonth = false
    end

    local meterName = 'MeterDay' .. i
    local dotName = 'MeterDot' .. i
    SKIN:Bang('!SetOption', meterName, 'Text', tostring(dispDay))

    if not inMonth then
      SKIN:Bang('!SetOption', meterName, 'FontColor', '155,164,178,70')
      SKIN:Bang('!SetOption', meterName, 'FontFace', '#FontMain#')
      SKIN:Bang('!SetOption', meterName, 'ToolTipText', '')
      SKIN:Bang('!HideMeter', dotName)
    else
      local dateKey = string.format('%04d-%02d-%02d', viewYear, viewMonth, dispDay)
      local hName = holidays[dateKey]
      local isToday = (viewYear == nowY and viewMonth == nowM and dispDay == nowD)
      local isWeekend = (col == 0 or col == 6)

      if hName then
        local hEntry = string.format('%02d %s  -  %s', dispDay, string.sub(MONTH_NAMES[viewMonth], 1, 3), hName)
        if firstMonthHolidayText == '' then
          firstMonthHolidayText = hEntry
        end
        if nextHolidayText == '' and (viewYear > nowY or (viewYear == nowY and viewMonth > nowM) or (viewYear == nowY and viewMonth == nowM and dispDay >= nowD)) then
          nextHolidayText = hEntry
        end
      end

      if isToday then
        todayPlaced = true
        SKIN:Bang('!SetOption', 'MeterTodayBox', 'X', tostring(cx - 13))
        SKIN:Bang('!SetOption', 'MeterTodayBox', 'Y', tostring(cy - 10))
        SKIN:Bang('!ShowMeter', 'MeterTodayBox')
        SKIN:Bang('!SetOption', meterName, 'FontColor', '18,22,26,255')
        SKIN:Bang('!SetOption', meterName, 'FontFace', '#FontBold#')
      elseif hName then
        SKIN:Bang('!SetOption', meterName, 'FontColor', '#AccentColor#,255')
        SKIN:Bang('!SetOption', meterName, 'FontFace', '#FontBold#')
      elseif isWeekend then
        SKIN:Bang('!SetOption', meterName, 'FontColor', '#TextFaint#')
        SKIN:Bang('!SetOption', meterName, 'FontFace', '#FontMain#')
      else
        SKIN:Bang('!SetOption', meterName, 'FontColor', '#TextPrimary#')
        SKIN:Bang('!SetOption', meterName, 'FontFace', '#FontMedium#')
      end

      if hName then
        SKIN:Bang('!SetOption', meterName, 'ToolTipText', hName)
        SKIN:Bang('!ShowMeter', dotName)
      else
        SKIN:Bang('!SetOption', meterName, 'ToolTipText', '')
        SKIN:Bang('!HideMeter', dotName)
      end
    end
  end

  if not todayPlaced then
    SKIN:Bang('!HideMeter', 'MeterTodayBox')
  end

  local footer = nextHolidayText
  if footer == '' then footer = firstMonthHolidayText end
  if footer == '' then
    footer = 'Spain / Aragon  -  No holidays this month'
  else
    footer = 'ES  ' .. footer
  end
  SKIN:Bang('!SetOption', 'MeterHolidayFooter', 'Text', footer)
  SKIN:Bang('!UpdateMeter', '*')
  SKIN:Bang('!Redraw')
end

function Initialize()
  viewYear = tonumber(os.date('%Y'))
  viewMonth = tonumber(os.date('%m'))
  lastDayCheck = tonumber(os.date('%d'))
  render()
end

function Update()
  local curD = tonumber(os.date('%d'))
  if curD ~= lastDayCheck then
    lastDayCheck = curD
    viewYear = tonumber(os.date('%Y'))
    viewMonth = tonumber(os.date('%m'))
    render()
  end
end

function OnHolidaysFetched()
  parseApiJson()
  render()
end

function MoveMonth(delta)
  local d = tonumber(delta) or 0
  if d == 0 then
    viewYear = tonumber(os.date('%Y'))
    viewMonth = tonumber(os.date('%m'))
  else
    viewMonth = viewMonth + d
    if viewMonth < 1 then
      viewMonth = 12
      viewYear = viewYear - 1
    elseif viewMonth > 12 then
      viewMonth = 1
      viewYear = viewYear + 1
    end
  end
  render()
end
