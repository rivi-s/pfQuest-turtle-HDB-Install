local frame = CreateFrame("Frame")
local enabled = false
local lastSlowFrame = 0
local lastQuery
local lastQuestEvent
local previousMemory = gcinfo()

local function NowMS()
  return GetTime() * 1000
end

local function Print(message)
  if not enabled then return end
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccHDB hitch:|r " .. message)
end

local function Status(message)
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccHDB hitch profiler:|r " .. message)
end

local function MeasureMethod(owner, key, label)
  if not owner or type(owner[key]) ~= "function" then return end
  local original = owner[key]
  owner[key] = function(...)
    if not enabled then return original(unpack(arg)) end
    local started = NowMS()
    local result = { original(unpack(arg)) }
    local elapsed = NowMS() - started
    if elapsed >= 10 then
      Print(label .. "=" .. string.format("%.1f", elapsed) .. "ms")
    end
    return unpack(result)
  end
end

local function MeasureOnUpdate(owner, label)
  if not owner or type(owner.GetScript) ~= "function" then return end
  local original = owner:GetScript("OnUpdate")
  if type(original) ~= "function" then return end
  owner:SetScript("OnUpdate", function()
    if not enabled then
      original()
      return
    end
    local started = NowMS()
    original()
    local elapsed = NowMS() - started
    if elapsed >= 10 then
      Print(label .. "=" .. string.format("%.1f", elapsed) .. "ms")
    end
  end)
end

local function QueryLabel(sql)
  local lower = string.lower(sql or "")
  if string.find(lower, "from quest_disambiguation", 1, true)
    or string.find(lower, "join quest_disambiguation", 1, true) then return "disambiguation" end
  if string.find(lower, "select title, id from quest_text", 1, true) then return "title preload" end
  if string.find(lower, "with resolved_start as", 1, true) then return "quest starters" end
  if string.find(lower, "with resolved_target as", 1, true) then return "quest targets" end
  if string.find(lower, "from quest_text", 1, true) then return "quest text/title" end
  if string.find(lower, "from item_source", 1, true) then return "item sources" end
  if string.find(lower, "from spawn", 1, true) then return "entity spawns" end
  return "other query"
end

if type(HDB_QueryRawAsync) == "function" then
  local originalQuery = HDB_QueryRawAsync
  HDB_QueryRawAsync = function(handle, sql, callback)
    if not enabled then return originalQuery(handle, sql, callback) end
    local label = QueryLabel(sql)
    local wrapped = callback and function(...)
      local rows = arg[2]
      local rowCount = type(rows) == "table" and table.getn(rows) or 0
      local started = NowMS()
      local result = { callback(unpack(arg)) }
      local elapsed = NowMS() - started
      lastQuery = { label = label, rows = rowCount, elapsed = elapsed, at = GetTime() }
      if elapsed >= 8 then
        Print(label .. " rows=" .. rowCount .. " callback=" .. string.format("%.1f", elapsed) .. "ms")
      end
      return unpack(result)
    end
    return originalQuery(handle, sql, wrapped)
  end
end

MeasureMethod(pfQuest, "UpdateQuestlog", "UpdateQuestlog")
MeasureMethod(pfMap, "UpdateNodes", "UpdateNodes")
MeasureMethod(pfDatabase, "GetQuestIDs", "GetQuestIDs")
MeasureOnUpdate(pfQuest, "pfQuest OnUpdate")
MeasureOnUpdate(pfMap, "pfMap OnUpdate")

local function MeasureGlobal(key, label)
  local original = getglobal(key)
  if type(original) ~= "function" then return end
  setglobal(key, function(...)
    if not enabled then return original(unpack(arg)) end
    local started = NowMS()
    local result = { original(unpack(arg)) }
    local elapsed = NowMS() - started
    if elapsed >= 5 then Print(label .. "=" .. string.format("%.1f", elapsed) .. "ms") end
    return unpack(result)
  end)
end

MeasureGlobal("CompleteQuest", "CompleteQuest")
MeasureGlobal("GetQuestReward", "GetQuestReward")

local questEvents = CreateFrame("Frame")
questEvents:RegisterEvent("QUEST_COMPLETE")
questEvents:RegisterEvent("QUEST_FINISHED")
questEvents:RegisterEvent("QUEST_LOG_UPDATE")
questEvents:SetScript("OnEvent", function()
  if not enabled then return end
  lastQuestEvent = { name = event, at = GetTime() }
end)

frame:SetScript("OnUpdate", function()
  if not enabled then return end
  local elapsed = (arg1 or 0) * 1000
  local memory = gcinfo()
  local memoryDelta = memory - previousMemory
  previousMemory = memory
  if elapsed >= 50 and GetTime() - lastSlowFrame >= 0.25 then
    lastSlowFrame = GetTime()
    local recent = ""
    if lastQuery and GetTime() - lastQuery.at <= 0.2 then
      recent = " recentQuery=" .. lastQuery.label .. " rows=" .. lastQuery.rows
        .. " callback=" .. string.format("%.1f", lastQuery.elapsed) .. "ms"
    end
    if lastQuestEvent and GetTime() - lastQuestEvent.at <= 0.75 then
      recent = recent .. " recentEvent=" .. lastQuestEvent.name
    end
    Print("frame=" .. string.format("%.1f", elapsed) .. "ms memory="
      .. tostring(math.floor(memory)) .. "KB delta=" .. string.format("%+.0f", memoryDelta)
      .. "KB" .. recent)
  end
end)

SLASH_HDBHITCH1 = "/hdbhitch"
SlashCmdList["HDBHITCH"] = function(message)
  message = string.lower(message or "")
  if message == "on" or (message == "" and not enabled) then
    enabled = true
    lastSlowFrame = 0
    lastQuery = nil
    lastQuestEvent = nil
    previousMemory = gcinfo()
    Status("ON")
  elseif message == "off" or message == "" then
    enabled = false
    Status("OFF")
  elseif message == "status" then
    Status(enabled and "ON" or "OFF")
  else
    Status("use /hdbhitch on, /hdbhitch off, or /hdbhitch status")
  end
end

local function CountEntries(value)
  local count = 0
  for _ in pairs(value or {}) do count = count + 1 end
  return count
end

SLASH_HDBROUTE1 = "/hdbroute"
SlashCmdList["HDBROUTE"] = function()
  if not pfQuest or not pfQuest.route or not pfMap then
    Status("route system unavailable")
    return
  end

  local route = pfQuest.route
  local map = pfMap.GetMapID and pfMap:GetMapID(GetCurrentMapContinent(), GetCurrentMapZone())
  local questNodes = map and pfMap.nodes and pfMap.nodes.PFQUEST and pfMap.nodes.PFQUEST[map]
  local coordinateCount = CountEntries(questNodes)
  local titleCount = 0
  for _, node in pairs(questNodes or {}) do titleCount = titleCount + CountEntries(node) end
  local first = route.coords and route.coords[1]
  local firstTitle = first and first[3] and first[3].title or "none"

  Status("map=" .. tostring(map)
    .. " playerMap=" .. tostring(pfMap.GetPlayerMapID and pfMap:GetPlayerMapID())
    .. " nodes=" .. coordinateCount .. "/" .. titleCount)
  Status("routePoints=" .. tostring(table.getn(route.coords or {}))
    .. " first=" .. tostring(firstTitle)
    .. " missing=" .. tostring(route.targetMissing)
    .. " recalc=" .. tostring(route.recalculate))
  Status("routes=" .. tostring(pfQuest_config and pfQuest_config["routes"])
    .. " arrow=" .. tostring(pfQuest_config and pfQuest_config["arrow"])
    .. " objective=" .. tostring(pfQuest_config and pfQuest_config["routecluster"])
    .. " ender=" .. tostring(pfQuest_config and pfQuest_config["routeender"])
    .. " starter=" .. tostring(pfQuest_config and pfQuest_config["routestarter"])
    .. " shown=" .. tostring(route.arrow and route.arrow:IsShown()))
  Status("worldMapShown=" .. tostring(WorldMapFrame and WorldMapFrame:IsShown())
    .. " drawlayerShown=" .. tostring(route.drawlayer and route.drawlayer:IsShown())
    .. " firstnode=" .. tostring(route.firstnode)
    .. " lastDrawNode=" .. tostring(route.lastDrawNode)
    .. " coord1dist=" .. tostring(first and first[4]))
end
