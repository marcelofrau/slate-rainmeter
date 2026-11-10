-- Slate Media / Standby Controller
-- Switches cleanly between two rich states so the card NEVER looks empty:
--   1) Playing / Paused (Title ~= ''): shows track title, artist, transport
--      buttons (Prev / Play-Pause / Next) and track progress bar.
--   2) Standby (no active media): shows a sleek "AUDIO STANDBY" telemetry
--      card with live System Uptime and a quick click action to launch Spotify.
-- Pure ASCII script for Rainmeter Lua compatibility.

local lastMode = ''
local lastState = -1

function Update()
  local mTitle = SKIN:GetMeasure('MeasureMediaTitle')
  local mArtist = SKIN:GetMeasure('MeasureMediaArtist')
  local mState = SKIN:GetMeasure('MeasureMediaState')

  local title = mTitle and mTitle:GetStringValue() or ''
  local artist = mArtist and mArtist:GetStringValue() or ''
  local state = mState and mState:GetValue() or 0

  if title ~= '' and state > 0 then
    if lastMode ~= 'media' then
      lastMode = 'media'
      SKIN:Bang('!HideMeterGroup', 'StandbyGroup')
      SKIN:Bang('!ShowMeterGroup', 'MediaGroup')
      SKIN:Bang('!SetOption', 'MeterIcon', 'ImageTint', '#AccentColor#,245')
    end
    if state ~= lastState then
      lastState = state
      local ppIcon = (state == 1) and 'Pause.png' or 'Play.png'
      SKIN:Bang('!SetOption', 'MeterBtnPlayPause', 'ImageName', '#@#Images\\Icons\\' .. ppIcon)
    end
    SKIN:Bang('!SetOption', 'MeterTrackTitle', 'Text', title)
    SKIN:Bang('!SetOption', 'MeterTrackArtist', 'Text', (artist ~= '') and artist or 'Playing')
    SKIN:Bang('!UpdateMeterGroup', 'MediaGroup')
    SKIN:Bang('!UpdateMeter', 'MeterIcon')
    SKIN:Bang('!Redraw')
  else
    if lastMode ~= 'standby' then
      lastMode = 'standby'
      lastState = -1
      SKIN:Bang('!HideMeterGroup', 'MediaGroup')
      SKIN:Bang('!ShowMeterGroup', 'StandbyGroup')
      SKIN:Bang('!SetOption', 'MeterIcon', 'ImageTint', '#TextSecondary#')
    end
    SKIN:Bang('!UpdateMeterGroup', 'StandbyGroup')
    SKIN:Bang('!UpdateMeter', 'MeterIcon')
    SKIN:Bang('!Redraw')
  end
end
