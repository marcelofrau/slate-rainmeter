local notesPath = nil

function Initialize()
  notesPath = SKIN:GetVariable('NotesPath', '')
end

function Update()
  if notesPath == nil or notesPath == '' then
    SKIN:Bang('!SetVariable', 'NotesCount', '0 lines')
    return 'Notes file unavailable'
  end

  local file = io.open(notesPath, 'r')
  if not file then
    SKIN:Bang('!SetVariable', 'NotesCount', '0 lines')
    return 'Click card to add local notes...'
  end

  local text = file:read('*a') or ''
  file:close()
  text = text:gsub('^\239\187\191', ''):gsub('\r\n', '\n'):gsub('\r', '\n')

  local rawLines = {}
  local nonEmpty = 0
  for line in (text .. '\n'):gmatch('(.-)\n') do
    rawLines[#rawLines + 1] = line
    if line:match('%S') then
      nonEmpty = nonEmpty + 1
    end
  end

  while #rawLines > 0 and not rawLines[#rawLines]:match('%S') do
    table.remove(rawLines)
  end

  SKIN:Bang('!SetVariable', 'NotesCount', nonEmpty == 1 and '1 line' or (tostring(nonEmpty) .. ' lines'))
  if nonEmpty == 0 then
    return 'Click card to add local notes...'
  end

  local out = {}
  for i = 1, math.min(#rawLines, 18) do
    out[i] = rawLines[i]:match('%S') and rawLines[i] or ' '
  end
  return table.concat(out, '\n')
end
