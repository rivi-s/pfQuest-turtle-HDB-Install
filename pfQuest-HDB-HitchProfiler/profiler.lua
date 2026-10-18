local frame = CreateFrame("Frame", "pfQuestHDBHitchProfiler")
local enabled = false
local loginCaptureUntil
local function Settings()
  if type(pfQuestHDBHitchConfig) ~= "table" then pfQuestHDBHitchConfig = {} end
  if pfQuestHDBHitchConfig.loginCapture == nil then pfQuestHDBHitchConfig.loginCapture = false end
  return pfQuestHDBHitchConfig
end
local lastSlowFrame = 0
local lastQuery
local lastQuestEvent
local decoderCallbackMS = 0
local lastLuaBoundary = GetTime() * 1000
local previousMemory = gcinfo()

-- Lua 5.0 supplies the exact vararg count in arg.n. Preserve nil gaps in
-- API results (notably quest-log tag/header fields) and callback arguments.
local function PackResults(...)
  return arg
end

local function NowMS()
  return GetTime() * 1000
end

-- Manual captures use a bounded ring and infrequent exports to limit profiler overhead.
local manualLog, manualCount, manualNext, manualExportAt
local function LogManual(message)
  if not manualLog then return end
  manualLog[manualNext] = string.format("%.3f %s", GetTime(), message)
  manualNext = math.mod(manualNext, 2000) + 1
  manualCount = math.min(manualCount + 1, 2000)
end
local function ExportManual()
  if not manualLog or type(ExportFile) ~= "function" then return end
  local lines = { "HDB hitch manual capture (latest 2000 lines; timestamps are session seconds)" }
  local first = manualCount < 2000 and 1 or manualNext
  for offset = 0, manualCount - 1 do
    table.insert(lines, manualLog[math.mod(first + offset - 1, 2000) + 1])
  end
  local ok = pcall(ExportFile, "hdb_hitch_manual", table.concat(lines, "\n"))
  manualExportAt = GetTime() + 30
  return ok
end

local function Print(message)
  if not enabled then return end
  LogManual("HDB hitch: " .. message)
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccHDB hitch:|r " .. message)
end

local function Status(message)
  LogManual("HDB hitch profiler: " .. message)
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccHDB hitch profiler:|r " .. message)
end

local function MemoryText(before, after, thresholdBefore, thresholdAfter)
  return " memoryKB=" .. tostring(before) .. "->" .. tostring(after)
    .. " thresholdKB=" .. tostring(thresholdBefore) .. "->" .. tostring(thresholdAfter)
end
local lastSlowLuaLabel, lastSlowLuaAt

local function MeasureMethod(owner, key, label)
  if not owner or type(owner[key]) ~= "function" then return end
  local original = owner[key]
  owner[key] = function(...)
    if not enabled then return original(unpack(arg, 1, arg.n)) end
    local before, thresholdBefore = gcinfo()
    local started = NowMS()
    local result = PackResults(original(unpack(arg, 1, arg.n)))
    local elapsed = NowMS() - started
    local after, thresholdAfter = gcinfo()
    lastLuaBoundary = NowMS()
    if elapsed >= 10 then
      local name = type(label) == "function" and label(unpack(arg, 1, arg.n)) or label
      lastSlowLuaLabel, lastSlowLuaAt = name, GetTime()
      Print(name .. "=" .. string.format("%.1f", elapsed) .. "ms" .. MemoryText(before,after,thresholdBefore,thresholdAfter))
    end
    return unpack(result, 1, result.n)
  end
end

local timedUpdateScripts = {}
local function MeasureOnUpdate(owner, label)
  if not owner or type(owner.GetScript) ~= "function" then return end
  local original = owner:GetScript("OnUpdate")
  if type(original) ~= "function" or timedUpdateScripts[owner] == original then return end
  local wrapped = function()
    if not enabled then
      original()
      return
    end
    local before, thresholdBefore = gcinfo()
    local started = NowMS()
    local callbackBefore = decoderCallbackMS
    original()
    local elapsed = NowMS() - started
    local after, thresholdAfter = gcinfo()
    lastLuaBoundary = NowMS()
    if label == "HDB result decoder" then
      elapsed = math.max(0, elapsed - (decoderCallbackMS - callbackBefore))
      -- Print the decode-only label without changing the captured worker name.
    end
    if elapsed >= 10 then
      lastSlowLuaLabel, lastSlowLuaAt = label, GetTime()
      Print((label == "HDB result decoder" and "HDB row decode only" or label) .. "=" .. string.format("%.1f", elapsed) .. "ms" .. MemoryText(before,after,thresholdBefore,thresholdAfter))
    end
  end
  timedUpdateScripts[owner] = wrapped
  owner:SetScript("OnUpdate", wrapped)
end

local timedEventScripts = {}
local function MeasureOnEvent(owner, label)
  if not owner or type(owner.GetScript) ~= "function" then return end
  local original = owner:GetScript("OnEvent")
  if type(original) ~= "function" or timedEventScripts[owner] == original then return end
  local wrapped = function(...)
    if not enabled then return original(unpack(arg, 1, arg.n)) end
    local name = tostring(event or "unknown")
    local started = NowMS()
    local result = PackResults(original(unpack(arg, 1, arg.n)))
    local elapsed = NowMS() - started
    lastLuaBoundary = NowMS()
    if elapsed >= 8 then Print(label .. " event=" .. name .. "=" .. string.format("%.1f", elapsed) .. "ms") end
    return unpack(result, 1, result.n)
  end
  timedEventScripts[owner] = wrapped
  owner:SetScript("OnEvent", wrapped)
end

local targetTrialStart, targetTrialFinished, targetTrialPreview
local function AttachTargetTrialTiming()
  local provider = pfQuestHearthDB
  if not provider or provider.singleQueryTimingInstalled or type(provider.GetQuestTargetsAsync) ~= "function" then return end
  provider.singleQueryTimingInstalled = true
  local original = provider.GetQuestTargetsAsync
  provider.GetQuestTargetsAsync = function(owner, id, callback, limit, onPage)
    if not enabled or tonumber(id) ~= 40211 or targetTrialFinished or (tonumber(limit) or 0) > 0 then
      return original(owner, id, callback, limit, onPage)
    end
    targetTrialStart = targetTrialStart or NowMS()
    local returned = false
    local result = original(owner, id, function(records, err)
      if enabled and returned and not targetTrialFinished then
        targetTrialFinished = true
        Print("trial q40211 targets decoded=" .. string.format("%.0f", NowMS()-targetTrialStart)
          .. "ms rows=" .. tostring(records and table.getn(records) or 0)
          .. " mode=" .. tostring(owner.targetDeliveryMode) .. (err and " error=" .. tostring(err) or ""))
      end
      if callback then return callback(records, err) end
    end, limit, onPage and function(records)
      if enabled and not targetTrialPreview then
        targetTrialPreview = true
        Print("trial q40211 first decoded preview=" .. string.format("%.0f", NowMS()-targetTrialStart)
          .. "ms rows=" .. tostring(table.getn(records)) .. " (rendering follows)")
      end
      return onPage(records)
    end or nil)
    returned = true
    return result
  end
end

local startupPreviewHooked
local function AttachLocalPreviewTiming()
  local provider = pfQuestHearthDB
  if startupPreviewHooked or not provider or type(provider.GetQuestTargetsAsync) ~= "function" then return end
  startupPreviewHooked = true
  local original = provider.GetQuestTargetsAsync
  provider.GetQuestTargetsAsync = function(owner, id, callback, limit, onPage)
    if not enabled or not onPage then return original(owner, id, callback, limit, onPage) end
    local started, reported = GetTime(), false
    return original(owner, id, callback, limit, function(records)
      if enabled and not reported then
        reported = true
        Print("quest q" .. tostring(id) .. " first preview=" .. string.format("%.0f", (GetTime()-started)*1000)
          .. "ms rows=" .. tostring(table.getn(records)))
      end
      return onPage(records)
    end)
  end
end

local captureEnteredAt, firstArrowReported
local lastArrowWaitReport
local gateHooks, firstTargetRequests = {}, {}
local firstScanReported, firstIdentityReported
local identitySequence, identityAwaitingScan = 0, {}
local function SinceEntering()
  return captureEnteredAt and string.format("%.0f", (GetTime()-captureEnteredAt)*1000) or "before-world"
end
local function AttachStartupGates()
  local provider = pfQuestHearthDB
  if provider and type(provider.GetQuestTargetsAsync) == "function" and not gateHooks.targets then
    gateHooks.targets = true
    local original = provider.GetQuestTargetsAsync
    provider.GetQuestTargetsAsync = function(owner, id, ...)
      if enabled and not firstTargetRequests[id] then
        firstTargetRequests[id] = true
        Print("startup target q" .. tostring(id) .. " requested=" .. SinceEntering() .. "ms after entering world")
      end
      return original(owner, id, unpack(arg, 1, arg.n))
    end
  end
  if pfQuest and type(pfQuest.UpdateQuestlog) == "function" and not gateHooks.scan then
    gateHooks.scan = true
    local original = pfQuest.UpdateQuestlog
    pfQuest.UpdateQuestlog = function(...)
      if enabled and not firstScanReported then
        firstScanReported = true
        Print("startup first quest scan=" .. SinceEntering() .. "ms after entering world")
      end
      local result = PackResults(original(unpack(arg, 1, arg.n)))
      if enabled then
        for title, completed in pairs(identityAwaitingScan) do
          local applied, matches, pending = nil, 0, false
          for id, state in pairs(pfQuest.questlog or {}) do
            if state.title == title then
              if type(id) == "number" then applied = id; matches = matches + 1 else pending = true end
            end
          end
          if applied and matches == 1 and not pending then
            Print("identity " .. completed.kind .. " applied q" .. tostring(applied)
              .. " at=" .. SinceEntering() .. "ms callback-to-scan="
              .. string.format("%.0f", (GetTime()-completed.at)*1000) .. "ms")
            identityAwaitingScan[title] = nil
          end
        end
      end
      return unpack(result, 1, result.n)
    end
  end
  for _, key in ipairs({"GetQuestIDsByTitleAsync", "GetQuestDisambiguationAsync"}) do
    if provider and type(provider[key]) == "function" and not gateHooks[key] then
      gateHooks[key] = true
      local original = provider[key]
      local kind = key == "GetQuestIDsByTitleAsync" and "title" or "candidates"
      provider[key] = function(owner, title, callback, ...)
        if not enabled then return original(owner, title, callback, unpack(arg, 1, arg.n)) end
        identitySequence = identitySequence + 1
        local sequence, started = identitySequence, GetTime()
        Print("identity " .. kind .. " #" .. sequence .. " request at=" .. SinceEntering() .. "ms title=" .. tostring(title))
        return original(owner, title, callback and function(...)
          if enabled then
            local records, err = arg[1], arg[2]
            Print("identity " .. kind .. " #" .. sequence .. " callback at=" .. SinceEntering()
              .. "ms wait=" .. string.format("%.0f", (GetTime()-started)*1000)
              .. "ms rows=" .. tostring(type(records) == "table" and table.getn(records) or 0)
              .. " error=" .. tostring(err))
            if not err then identityAwaitingScan[title] = {at=GetTime(),kind=kind .. " #" .. sequence} end
          end
          return callback(unpack(arg, 1, arg.n))
        end or nil, unpack(arg, 1, arg.n))
      end
    end
  end
end
local arrowShowHooks, arrowHideHooks = {}, {}
local arrowVisibilityCount = 0
local function ReportArrowVisibility(action)
  if not enabled or not captureEnteredAt or arrowVisibilityCount >= 24 then return end
  arrowVisibilityCount = arrowVisibilityCount + 1
  local route = pfQuest and pfQuest.route
  local point = route and route.coords and route.coords[1]
  local meta = point and point[3]
  local x, y = GetPlayerMapPosition("player")
  local reason = pfQuest_config.arrow ~= "1" and "disabled"
    or (route and route.targetMissing and "target-missing")
    or (not point and "empty-route")
    or (x == 0 and y == 0 and "zero-position") or "other"
  Print("arrow visibility=" .. action .. " at=" .. string.format("%.0f", (GetTime()-captureEnteredAt)*1000)
    .. "ms state=" .. reason .. " q=" .. tostring(meta and meta.questid)
    .. " spawn=" .. tostring(meta and meta.spawnid)
    .. " target=" .. tostring(point and point[1]) .. "," .. tostring(point and point[2])
    .. " positionRetries=" .. tostring(pfMap.playerMapRecoveryTries)
    .. " playerMap=" .. tostring(pfMap.playerMapID)
    .. " pos=" .. tostring(x) .. "," .. tostring(y)
    .. " mapOpen=" .. tostring(WorldMapFrame:IsShown())
    .. " busy=" .. tostring(pfDatabase.hdbPinsPending))
end
local function ReportFirstArrow()
  if not enabled or not captureEnteredAt or firstArrowReported then return end
  local route = pfQuest and pfQuest.route
  local point = route and route.coords and route.coords[1]
  if not route or route.targetMissing or not point or not point[4]
    or not route.arrow or not route.arrow:IsShown() then return end
  firstArrowReported = true
  Print("route arrow shown=" .. string.format("%.0f", (GetTime()-captureEnteredAt)*1000)
    .. "ms after entering world")
end
local function AttachArrowReadiness()
  local arrow = pfQuest and pfQuest.route and pfQuest.route.arrow
  if not arrow then return end
  local original = arrow:GetScript("OnShow")
  if arrowShowHooks[arrow] ~= original or not original then
    local wrapped = function(...)
      ReportFirstArrow()
      ReportArrowVisibility("show")
      if original then return original(unpack(arg, 1, arg.n)) end
    end
    arrowShowHooks[arrow] = wrapped
    arrow:SetScript("OnShow", wrapped)
  end
  local originalHide = arrow:GetScript("OnHide")
  if arrowHideHooks[arrow] ~= originalHide or not originalHide then
    local wrapped = function(...)
      ReportArrowVisibility("hide")
      if originalHide then return originalHide(unpack(arg, 1, arg.n)) end
    end
    arrowHideHooks[arrow] = wrapped
    arrow:SetScript("OnHide", wrapped)
  end
end

-- Reuse one phase record; do not allocate a diagnostic table per decoded row.
local decodeRowStart, decodeRowMemory, decodeRowThreshold
local function AttachDecodeDetails()
  local provider = pfQuestHearthDB
  if not provider then return end
  if not provider.profileDecodeJob then
    provider.profileDecodeJob = function(job, run)
      if not enabled then return run() end
      local before, thresholdBefore = gcinfo()
      local started, callbackBefore = NowMS(), decoderCallbackMS
      local done = run()
      local elapsed = NowMS()-started
      local after, thresholdAfter = gcinfo()
      if elapsed >= 10 then
        Print("decode job " .. tostring(job.label or (job.questID and "q" .. job.questID) or "unlabeled")
          .. " total=" .. string.format("%.1f", elapsed)
          .. "ms callbacks=" .. string.format("%.1f", decoderCallbackMS-callbackBefore)
          .. "ms worker=" .. string.format("%.1f", math.max(0,elapsed-(decoderCallbackMS-callbackBefore)))
          .. "ms" .. MemoryText(before,after,thresholdBefore,thresholdAfter))
      end
      return done
    end
  end
  if not provider.profileDecodePhase then
    provider.profileDecodePhase = function(phase, id, first, last, total)
      if not enabled then return end
      if phase == "rows-begin" then
        decodeRowMemory, decodeRowThreshold = gcinfo()
        decodeRowStart = NowMS()
      elseif phase == "rows-end" and decodeRowStart then
        local elapsed = NowMS()-decodeRowStart
        local after, thresholdAfter = gcinfo()
        if elapsed >= 10 then
          Print("decode normalization q" .. tostring(id) .. " rows=" .. first .. "-" .. last .. "/" .. total
            .. " time=" .. string.format("%.1f", elapsed) .. "ms"
            .. MemoryText(decodeRowMemory,after,decodeRowThreshold,thresholdAfter))
        end
        decodeRowStart = nil
      end
    end
  end
end

local function AttachStartupWorkers()
  AttachDecodeDetails()
  AttachLocalPreviewTiming()
  AttachStartupGates()
  AttachArrowReadiness()
  AttachTargetTrialTiming()
  if pfQuestHearthDB and not pfQuestHearthDB.profileDecodedCallback then
    pfQuestHearthDB.profileDecodedCallback = function(label, callback, records)
      if not enabled then return callback(records, nil) end
      local before, thresholdBefore = gcinfo()
      local started = NowMS()
      local result = PackResults(callback(records, nil))
      local elapsed = NowMS() - started
      local after, thresholdAfter = gcinfo()
      decoderCallbackMS = decoderCallbackMS + elapsed
      if elapsed >= 8 then
        Print(label .. " rows=" .. table.getn(records) .. "=" .. string.format("%.1f", elapsed) .. "ms" .. MemoryText(before,after,thresholdBefore,thresholdAfter))
      end
      return unpack(result, 1, result.n)
    end
  end
  MeasureOnEvent(pfQuest, "pfQuest event handler")
  MeasureOnEvent(pfMap, "pfMap event handler")
  MeasureOnEvent(QuestLogFrame, "quest journal event handler")
  MeasureOnUpdate(HDB_CallbackFrame, "HDB native callback dispatcher")
  MeasureOnEvent(HDB_CallbackFrame, "HDB native callback event")
  MeasureOnUpdate(pfQuest and pfQuest.tracker, "tracker content/layout driver")
  MeasureOnUpdate(pfQuestHearthDB and pfQuestHearthDB.targetDecodeDriver, "HDB result decoder")
  MeasureOnUpdate(pfDatabase and pfDatabase.pinRenderDriver, "HDB pin render driver")
  MeasureOnUpdate(pfDatabase and pfDatabase.trackingDriver, "HDB tracking builder")
  MeasureOnUpdate(pfDatabase and pfDatabase.starterDriver, "HDB starter completion worker")
  MeasureOnUpdate(pfMap and pfMap.nodeUpdateDriver, "map preparation/refresh driver")
  MeasureOnUpdate(PFEXQuestHelper and PFEXQuestHelper.hdbIndexBuilder, "pfExtend index builder")
end

local function QueryLabel(sql)
  local lower = string.lower(sql or "")
  if string.find(lower, "from quest_disambiguation", 1, true)
    or string.find(lower, "join quest_disambiguation", 1, true) then
    return string.find(lower, "lower(q.title) = lower(", 1, true) and "identity candidates" or "candidate preload"
  end
  if string.find(lower, "select title, id from quest_text", 1, true) then return "title preload" end
  if string.find(lower, "with resolved_start as", 1, true) then return "quest starters" end
  if string.find(lower, "from meta_relation r", 1, true) then
    local _, _, relation = string.find(lower, "r%.relation='([^']+)'")
    return "tracking " .. (relation or "unknown")
  end
  if string.find(lower, "with objective_identity as", 1, true) then
    local _, _, id = string.find(lower, "where q%.quest_id = (%d+)")
    return "objective identities" .. (id and " q" .. id or "")
  end
  if string.find(lower, "with resolved_target as", 1, true) then
    local _, _, id = string.find(lower, "where q%.quest_id = (%d+)")
    return "quest targets" .. (id and " q" .. id or "")
  end
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
    local lower = string.lower(sql or "")
    local identitySQL = string.find(lower, "select id from quest_text", 1, true)
      or string.find(lower, "lower(q.title) = lower(", 1, true)
    local identitySubmittedAt = NowMS()
    if identitySQL then Print("identity native submit at=" .. SinceEntering() .. "ms kind=" .. label) end
    local wrapped = callback and function(...)
      local rows = arg[2]
      local rowCount = type(rows) == "table" and table.getn(rows) or 0
      local before, thresholdBefore = gcinfo()
      local started = NowMS()
      if identitySQL and enabled then
        Print("identity native reply at=" .. SinceEntering() .. "ms wait="
          .. string.format("%.0f", started-identitySubmittedAt) .. "ms rows=" .. rowCount
          .. " error=" .. tostring(arg[3]))
      end
      local gap = started - lastLuaBoundary
      if gap >= 100 then
        Print("callback arrival gap=" .. string.format("%.1f", gap) .. "ms next=" .. label .. " rows=" .. rowCount .. " (gap is not query duration)")
      end
      local result = PackResults(callback(unpack(arg, 1, arg.n)))
      local elapsed = NowMS() - started
      local after, thresholdAfter = gcinfo()
      lastLuaBoundary = NowMS()
      lastQuery = { label = label, rows = rowCount, elapsed = elapsed, at = GetTime() }
      if elapsed >= 8 then
        lastSlowLuaLabel, lastSlowLuaAt = label .. " callback", GetTime()
        Print(label .. " rows=" .. rowCount .. " callback=" .. string.format("%.1f", elapsed) .. "ms" .. MemoryText(before,after,thresholdBefore,thresholdAfter))
      end
      return unpack(result, 1, result.n)
    end
    local submittedAt = NowMS()
    local ticket = originalQuery(handle, sql, wrapped)
    local submission = NowMS() - submittedAt
    lastLuaBoundary = NowMS()
    if submission >= 8 then Print(label .. " submission=" .. string.format("%.1f", submission) .. "ms") end
    return ticket
  end
end

MeasureMethod(pfQuest, "UpdateQuestlog", "UpdateQuestlog")
MeasureMethod(pfMap, "UpdateNodes", function(_, context) return type(context) == "table" and context.routeOnly and "UpdateNodes [route-only]" or "UpdateNodes [map/tracker]" end)
MeasureMethod(pfDatabase, "GetQuestIDs", "GetQuestIDs")
MeasureMethod(pfDatabase, "RenderQuestHDBCache", function(_, id) return "RenderQuestHDBCache q" .. tostring(id) end)
MeasureMethod(pfDatabase, "ProcessQuestPinRenderBatch", "ProcessQuestPinRenderBatch")
MeasureMethod(pfDatabase, "StoreQuestHDBCache", function(_, id) return "StoreQuestHDBCache q" .. tostring(id) end)
MeasureMethod(pfDatabase, "RefreshQuestHDBState", function(_, id) return "RefreshQuestHDBState q" .. tostring(id) end)
MeasureMethod(pfMap, "DeleteNode", "DeleteNode")
MeasureMethod(pfMap, "PrepareHiddenMapPins", "PrepareHiddenMapPins")

MeasureOnUpdate(pfQuest, "pfQuest OnUpdate")
MeasureOnUpdate(pfMap, "pfMap OnUpdate")

local function MeasureGlobal(key, label)
  local original = getglobal(key)
  if type(original) ~= "function" then return end
  setglobal(key, function(...)
    if not enabled then return original(unpack(arg, 1, arg.n)) end
    local started = NowMS()
    local result = PackResults(original(unpack(arg, 1, arg.n)))
    local elapsed = NowMS() - started
    if elapsed >= 5 then Print(label .. "=" .. string.format("%.1f", elapsed) .. "ms") end
    return unpack(result, 1, result.n)
  end)
end

MeasureGlobal("CompleteQuest", "CompleteQuest")
MeasureGlobal("GetQuestReward", "GetQuestReward")
MeasureGlobal("GetNumQuestLogEntries", "API GetNumQuestLogEntries")
MeasureGlobal("GetNumQuestLeaderBoards", "API GetNumQuestLeaderBoards")
MeasureGlobal("IsQuestWatched", "API IsQuestWatched")
MeasureGlobal("QuestLog_Update", "quest journal full update")
MeasureMethod(pfQuestCompat, "GetQuestLogTitle", "API GetQuestLogTitle")
MeasureMethod(pfQuestCompat, "GetQuestLogLeaderBoard", "API GetQuestLogLeaderBoard")
MeasureMethod(pfQuestCompat, "GetQuestLinkForLogIndex", "API GetQuestLinkForLogIndex")
if pfQuest and pfQuest.tracker then
  MeasureMethod(pfQuest.tracker, "ButtonEvent", function(button)
    return "tracker row q" .. tostring(button and button.questid or "unknown")
  end)
end


local questEvents = CreateFrame("Frame", "pfQuestHDBHitchProfilerEvents")
questEvents:RegisterEvent("PLAYER_LOGIN")
questEvents:RegisterEvent("PLAYER_LOGOUT")
questEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
questEvents:RegisterEvent("QUEST_COMPLETE")
questEvents:RegisterEvent("QUEST_FINISHED")
questEvents:RegisterEvent("QUEST_LOG_UPDATE")
questEvents:SetScript("OnEvent", function()
  if event == "PLAYER_LOGOUT" then ExportManual() end
  if event == "PLAYER_LOGIN" then Settings() end
  if event == "PLAYER_ENTERING_WORLD" and Settings().loginCapture then
    ExportManual()
    manualLog = nil
    enabled = true
    captureEnteredAt, firstArrowReported = GetTime(), nil
    firstTargetRequests, firstScanReported, firstIdentityReported = {}, nil, nil
    lastArrowWaitReport = GetTime()
    AttachStartupWorkers()
    if pfQuest and pfQuest.route and pfQuest.route.arrow and pfQuest.route.arrow:IsShown() then ReportFirstArrow() end
    loginCaptureUntil = GetTime() + 45
    lastSlowFrame = 0
    previousMemory = gcinfo()
    Status("profiler 1.0.3: automatic login capture ON for 45 seconds")
    if type(HDB_GetDeliveryStats) == "function" then
      local version = HDB_GetDeliveryStats()
      Status("native delivery version: " .. tostring(version))
    end
  end
  if not enabled then return end
  lastQuestEvent = { name = event, at = GetTime() }
end)

frame:SetScript("OnUpdate", function()
  if manualLog and GetTime() >= manualExportAt then ExportManual() end
  if not enabled then return end
  AttachStartupWorkers()
  lastLuaBoundary = NowMS()
  if loginCaptureUntil and GetTime() >= loginCaptureUntil then
    enabled = false
    loginCaptureUntil = nil
    Status("automatic login capture finished")
    if type(HDB_DumpDeliveryDiagnostics) == "function" then
      local ok, report = pcall(HDB_DumpDeliveryDiagnostics)
      Status("native timing report: " .. tostring(report))
    end
    return
  end
  ReportFirstArrow()
  if captureEnteredAt and GetTime() - (lastArrowWaitReport or GetTime()) >= 2 then
    lastArrowWaitReport = GetTime()
    local route = pfQuest and pfQuest.route
    local x, y = GetPlayerMapPosition("player")
    local job = pfMap and pfMap.hiddenPinJob
    local resolved, unresolved = 0, 0
    for id in pairs(pfQuest and pfQuest.questlog or {}) do
      if type(id) == "number" then resolved = resolved + 1 else unresolved = unresolved + 1 end
    end
    Print("startup gates at=" .. SinceEntering() .. "ms lock="
      .. tostring(pfQuest and math.max(0, (pfQuest.lock or 0)-GetTime()) or 0)
      .. " localized=" .. tostring(pfDatabase and pfDatabase.localized)
      .. " quests=" .. resolved .. " unresolved=" .. unresolved
      .. " queue=" .. tostring(pfQuest and pfQuest.queueCount)
      .. " scanPending=" .. tostring(pfQuest and pfQuest.updateQuestLog)
      .. " broadPreload=" .. tostring(pfQuestHearthDB and pfQuestHearthDB.startupPreloadState))
    Print("readiness arrow=" .. tostring(firstArrowReported and "ready" or "waiting")
      .. " map=" .. tostring(WorldMapFrame:IsShown() and "open" or (pfMap and pfMap.hiddenPinsReady or "preparing"))
      .. " zoneRev=" .. tostring(pfMap and pfMap.routeMapRevisions and pfMap.routeMapRevisions[pfMap:GetPlayerMapID()] or 0)
      .. " pins=" .. tostring(job and job.index or 0) .. "/" .. tostring(job and table.getn(job.entries) or 0)
      .. " busy=" .. tostring(pfDatabase and pfDatabase.hdbPinsPending)
      .. " route=" .. tostring(pfMap and pfMap.initialHDBRouteStatus or "not-attempted")
      .. " selected=" .. tostring(route and route.coords and route.coords[1] and route.coords[1][3] and route.coords[1][3].title)
      .. " distance=" .. tostring(route and route.coords and route.coords[1] and route.coords[1][4])
      .. " coords=" .. tostring(route and route.coords and table.getn(route.coords) or 0)
      .. " raw=" .. tostring(route and route.rawObjectiveCandidates and table.getn(route.rawObjectiveCandidates) or 0)
      .. " targetMissing=" .. tostring(route and route.targetMissing)
      .. " fallback=" .. tostring(pfMap and pfMap.positionBoundaryFallback and pfMap.positionBoundaryFallback.preferred)
      .. " actualPlayerMap=" .. tostring(pfMap and pfMap.playerMapID)
      .. " playerMap=" .. tostring(pfMap and pfMap.initialHDBRouteMap)
      .. " pos=" .. tostring(x) .. "," .. tostring(y))
  end
  local elapsed = (arg1 or 0) * 1000
  local memory = gcinfo()
  local memoryDelta = memory - previousMemory
  previousMemory = memory
  if elapsed >= 50 and GetTime() - lastSlowFrame >= 0.25 then
    lastSlowFrame = GetTime()
    local recent = ""
    if lastSlowLuaAt and GetTime()-lastSlowLuaAt <= 0.25 then
      recent = recent .. " recentLua=" .. tostring(lastSlowLuaLabel)
    end
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
  message = string.lower(string.gsub(string.gsub(message or "", "^%s+", ""), "%s+$", ""))
  local _, _, loginMode = string.find(message, "^login%s+(%a+)$")
  if loginMode == "on" or loginMode == "off" then
    Settings().loginCapture = loginMode == "on"
    if loginMode == "off" and loginCaptureUntil then
      enabled, loginCaptureUntil = false, nil
    end
    Status("automatic login capture " .. string.upper(loginMode) .. " (saved)")
  elseif message == "on" or (message == "" and not enabled) then
    enabled = true
    lastSlowFrame = 0
    lastQuery = nil
    lastQuestEvent = nil
    previousMemory = gcinfo()
    loginCaptureUntil = nil
    if not manualLog then
      manualLog, manualCount, manualNext, manualExportAt = {}, 0, 1, GetTime() + 30
    end
    Status("ON; manual log: Imports/hdb_hitch_manual.txt (requires ExportFile)")
    ExportManual()
  elseif message == "off" or message == "" then
    enabled = false
    loginCaptureUntil = nil
    Status("OFF")
    local saved = ExportManual()
    manualLog = nil
    if saved then Status("manual log saved: Imports/hdb_hitch_manual.txt") end
  elseif message == "status" then
    Status("capture=" .. (enabled and "ON" or "OFF") .. "; login=" .. (Settings().loginCapture and "ON" or "OFF"))
  else
    Status("use /hdbhitch on, off, status, login on, or login off")
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
end
