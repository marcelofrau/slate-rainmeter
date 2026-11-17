-- shortcut: polls the first NVIDIA GPU with the driver's nvidia-smi; add a backend for non-NVIDIA GPUs.
local command = '"C:\\Windows\\System32\\nvidia-smi.exe" --query-gpu=name,utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>nul'

local function query()
  local ok, process = pcall(io.popen, command, 'r')
  if not ok or not process then return nil end
  local line = process:read('*l')
  process:close()
  if not line then return nil end

  local name, usage, used, total = string.match(line, '^%s*([^,]+),%s*(%d+),%s*(%d+),%s*(%d+)%s*$')
  if not usage then return nil end
  return string.gsub(name, '^%s*(.-)%s*$', '%1'), tonumber(usage), tonumber(used), tonumber(total)
end

function Initialize()
  local fallback = (tonumber(SKIN:GetVariable('GPUTotalMB', '0')) or 0) * 1048576
  SKIN:Bang('!SetVariable', 'GPUName', 'NVIDIA GPU')
  SKIN:Bang('!SetVariable', 'GPUVRAMUsedBytes', '0')
  SKIN:Bang('!SetVariable', 'GPUVRAMTotalBytes', string.format('%.0f', fallback))
end

function Update()
  local ok, name, usage, used, total = pcall(query)
  if not ok or not name then return 0 end

  SKIN:Bang('!SetVariable', 'GPUName', name)
  SKIN:Bang('!SetVariable', 'GPUVRAMUsedBytes', string.format('%.0f', used * 1048576))
  SKIN:Bang('!SetVariable', 'GPUVRAMTotalBytes', string.format('%.0f', total * 1048576))
  return usage
end
