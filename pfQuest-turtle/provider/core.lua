-- Native asynchronous SQLite provider used by pfQuest's HDB adapter.
-- Embedded providers replace the legacy separate provider addon.
local addon = CreateFrame("Frame")
local provider = { embedded = true, databaseAddon = "pfQuest-turtle" }
-- Experimental DLLs budget native conversion internally. Keep SQL paging as
-- the fallback if the user restores the ordinary DLL.
local singleQueryTargets = type(HDB_DumpDeliveryDiagnostics) == "function"
provider.targetDeliveryMode = singleQueryTargets and "single-query" or "paged"
local dbHandle
local opened
local shuttingDown
local questTextCache = {}
local questTargetCache = {}
local questTargetPending = {}
local questObjectiveCache = {}
local targetDecodeJobs = {}
local targetDecodeGeneration = 0
local targetDecodeDriver = CreateFrame("Frame", "pfQuestHDBResultDecoder")
targetDecodeDriver:SetScript("OnUpdate", function()
  if not targetDecodeJobs[1] then
    if pfQuestHDBWork then pfQuestHDBWork:Release("decode") end
    targetDecodeDriver:Hide()
    return
  end
  if pfQuestHDBWork and not pfQuestHDBWork:Claim("decode") then return end
  local selected = 1
  if pfQuestHDBWork and pfQuestHDBWork.SelectJob then
    selected = pfQuestHDBWork:SelectJob(targetDecodeJobs, function(_, job)
      if job.localPriority and job.localPriority() then return 2 end
      return job.questID and pfQuest and pfQuest.GetQuestZonePriority and pfQuest:GetQuestZonePriority(job.questID) or 0
    end, "decode-priority") or 1
  end
  -- Rotate unfinished jobs within their priority group. Always taking the
  -- first job let a large spawn result monopolize every background turn.
  -- Remove before running: callbacks may enqueue work or clear the cache.
  local job = table.remove(targetDecodeJobs, selected)
  local generation = targetDecodeGeneration
  local done
  if type(provider.profileDecodeJob) == "function" then done = provider.profileDecodeJob(job, job.run)
  else done = job.run() end
  if not done and generation == targetDecodeGeneration then
    table.insert(targetDecodeJobs, job)
  end
  if not targetDecodeJobs[1] then
    if pfQuestHDBWork then pfQuestHDBWork:Release("decode") end
    targetDecodeDriver:Hide()
  end
end)
targetDecodeDriver:Hide()
provider.targetDecodeDriver = targetDecodeDriver
local function QueueTargetDecode(job, questID, localPriority, label)
  table.insert(targetDecodeJobs, { run = job, questID = questID, localPriority = localPriority, label = label })
  targetDecodeDriver:Show()
end
local questMapPinCache = {}
local questSearchCache = {}
local questTitleIDCache = {}
local questTitleIDIndex
local questTitleByIDCache = {}
local questTitleIDPreloaded
local questTitleIDPreloading
local questDisambiguationCache = {}
local questDisambiguationIndex
local questDisambiguationPreloaded
local questDisambiguationPreloading
local entityInfoCache = {}
local entityTitleCache = {}
local entitySearchCache = {}
local itemSearchCache = {}
local unitDropsCache = {}

local function Print(message)
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfQuest-HDB|r " .. message)
end

local function Available()
  return type(HDB_GetVersion) == "function"
    and type(HDB_OpenAddon) == "function"
    and type(HDB_QueryRawAsync) == "function"
    and type(HDB_ClearPoison) == "function"
end

local function Open()
  if shuttingDown then return nil end
  if opened then return dbHandle end

  if not Available() then
    Print("HearthDB is not available; embedded provider is idle.")
    return nil
  end

  local ok, handle = pcall(HDB_OpenAddon, "pfQuest-turtle", "provider/data/pfquest-turtle.sqlite")
  if not ok or not handle then
    Print("could not open provider/data/pfquest-turtle.sqlite")
    return nil
  end

  dbHandle = handle
  opened = true
  return dbHandle
end

local function CurrentLocale()
  local locale = GetLocale and GetLocale() or "enUS"
  if pfDB and pfDB.quests and pfDB.quests[locale] then
    return locale
  end
  return "enUS"
end

local function CacheKey(id, limit)
  return CurrentLocale() .. ":" .. tostring(id) .. ":" .. tostring(limit or "all")
end

local function ClearCache()
  targetDecodeGeneration = targetDecodeGeneration + 1
  questTextCache = {}
  questTargetCache = {}
  questObjectiveCache = {}
  questMapPinCache = {}
  questSearchCache = {}
  questTitleIDCache = {}
  questTitleIDIndex = nil
  questTitleByIDCache = {}
  questTitleIDPreloaded = nil
  questTitleIDPreloading = nil
  questDisambiguationCache = {}
  questDisambiguationIndex = nil
  questDisambiguationPreloaded = nil
  questDisambiguationPreloading = nil
  entityInfoCache = {}
  entityTitleCache = {}
  entitySearchCache = {}
  itemSearchCache = {}
  unitDropsCache = {}
end

-- HearthDB owns a native SQLite handle and asynchronous query queue. Close it
-- while Lua is still alive instead of leaving native cleanup to the game's
-- process teardown.
local function Close()
  shuttingDown = true
  if dbHandle and type(HDB_Close) == "function" then
    pcall(HDB_Close, dbHandle)
  end
  dbHandle = nil
  opened = nil
  ClearCache()
end

function provider:SearchEntityTitlesAsync(kind, query, limit, callback)
  local handle = Open()
  query, limit = tostring(query or ""), tonumber(limit) or 50
  if not handle or (kind ~= "U" and kind ~= "O") or query == "" then
    if callback then callback(nil, "HearthDB is unavailable or entity search is invalid") end
    return nil
  end
  local cacheKey = CurrentLocale() .. ":" .. kind .. ":" .. string.lower(query) .. ":" .. limit
  if entitySearchCache[cacheKey] then
    if callback then callback(entitySearchCache[cacheKey], nil) end
    return true
  end
  local safeQuery = string.lower(string.gsub(query, "'", "''"))
  local searchColumn = tonumber(query) and "CAST(e.target_id AS TEXT)" or "LOWER(e.title)"
  local sql = "SELECT e.target_id, e.title, m.level, m.faction, m.rank, "
    .. "EXISTS (SELECT 1 FROM spawn s WHERE s.target_kind = e.target_kind AND s.target_id = e.target_id) "
    .. "FROM entity_text e LEFT JOIN entity_meta m ON m.target_kind = e.target_kind AND m.target_id = e.target_id "
    .. "WHERE e.locale = '" .. CurrentLocale() .. "' AND e.target_kind = '" .. kind
    .. "' AND " .. searchColumn .. " LIKE '%" .. safeQuery .. "%' ORDER BY e.title, e.target_id LIMIT " .. limit
  local ok, ticket = pcall(HDB_QueryRawAsync, handle, sql, function(columns, rows, err)
    if err then
      HDB_ClearPoison(handle)
      if callback then callback(nil, err) end
      return
    end
    local results = {}
    for index = 1, table.getn(rows or {}) do
      local row = rows[index]
      local faction = row[4]
      local raceMask = faction == "A" and 77 or faction == "H" and 178
        or (faction == "AH" or faction == "HA") and 255 or 0
      results[tonumber(row[1])] = {
        title = row[2], level = row[3], faction = faction, rank = row[5],
        raceMask = raceMask, hasSpawns = tonumber(row[6]) == 1,
      }
    end
    entitySearchCache[cacheKey] = results
    if callback then callback(results, nil) end
  end)
  if not ok or not ticket then
    if callback then callback(nil, "could not submit entity search query") end
    return nil
  end
  return ticket
end

function provider:GetEntitiesByTitleAsync(kind, title, callback)
  local handle = Open()
  if not handle or (kind ~= "U" and kind ~= "O") or not title or title == "" then
    if callback then callback(nil, "HearthDB is unavailable or entity title is invalid") end
    return nil
  end
  local cacheKey = CurrentLocale() .. ":" .. kind .. ":" .. title
  if entityTitleCache[cacheKey] then
    if callback then callback(entityTitleCache[cacheKey], nil) end
    return true
  end
  local safeTitle = string.gsub(title, "'", "''")
  local sql = "SELECT e.target_id, e.title, m.level, m.faction, m.rank, os.required_skill, os.profession, s.zone_id, s.x, s.y, s.respawn FROM entity_text e "
    .. "LEFT JOIN entity_meta m ON m.target_kind = e.target_kind AND m.target_id = e.target_id "
    .. "LEFT JOIN object_skill os ON e.target_kind = 'O' AND os.object_id = e.target_id "
    .. "LEFT JOIN spawn s ON s.target_kind = e.target_kind AND s.target_id = e.target_id "
    .. "WHERE e.locale = '" .. CurrentLocale() .. "' AND e.target_kind = '" .. kind .. "' AND LOWER(e.title) = LOWER('" .. safeTitle .. "')"
  local ok, ticket = pcall(HDB_QueryRawAsync, handle, sql, function(columns, rows, err)
    if err then
      HDB_ClearPoison(handle)
      if callback then callback(nil, err) end
      return
    end
    local byID, records = {}, {}
    for index = 1, table.getn(rows or {}) do
      local row, id = rows[index], tonumber(rows[index][1])
      local record = byID[id]
      if not record then
        record = { id = id, kind = kind, title = row[2], level = row[3], faction = row[4], rank = row[5], requiredSkill = row[6], profession = row[7], zones = {}, spawns = {} }
        byID[id] = record
        table.insert(records, record)
      end
      if row[8] then
        local zone = tonumber(row[8])
        record.zones[zone] = (record.zones[zone] or 0) + 1
        table.insert(record.spawns, { zoneID = zone, x = tonumber(row[9]), y = tonumber(row[10]), respawn = tonumber(row[11]) })
      end
    end
    entityTitleCache[cacheKey] = records
    if callback then callback(records, nil) end
  end)
  if not ok or not ticket then
    if callback then callback(nil, "could not submit entity title query") end
    return nil
  end
  return ticket
end

function provider:GetMetaRelationAsync(relation, callback, isCurrent)
  local handle = Open()
  if not handle or not relation then if callback then callback(nil, "HearthDB is unavailable") end return nil end
  local safe = string.gsub(relation, "'", "''")
  -- Avoid the coordinate index: this join knows both kind and ID. SQLite
  -- can otherwise choose a type-wide spawn scan for the ordered pages.
  local sql = "SELECT r.target_kind,r.target_id,r.value,e.title,m.level,s.zone_id,s.x,s.y,s.respawn FROM meta_relation r "
    .. "LEFT JOIN entity_text e ON e.locale='" .. CurrentLocale() .. "' AND e.target_kind=r.target_kind AND e.target_id=r.target_id "
    .. "LEFT JOIN entity_meta m ON m.target_kind=r.target_kind AND m.target_id=r.target_id "
    .. "LEFT JOIN spawn s INDEXED BY spawn_target_idx ON s.target_kind=r.target_kind AND s.target_id=r.target_id WHERE r.relation='" .. safe .. "'"
  -- Keep native Lua result delivery bounded; normalize each page before requesting more.
  sql = sql .. " ORDER BY 1,2,3,4,5,6,7,8,9"
  local records, offset, finished = {}, 0, false
  local generation = targetDecodeGeneration
  local SubmitPage
  local function Fail(message)
    if finished then return end
    finished = true
    if callback then callback(nil, message) end
  end
  SubmitPage = function()
    if finished then return nil end
    if isCurrent and not isCurrent() then finished = true return nil end
    local pageSize = 256
    local pageSQL = sql .. " LIMIT " .. pageSize .. " OFFSET " .. offset
    local ok,ticket=pcall(HDB_QueryRawAsync,handle,pageSQL,function(_,rows,err)
      if err then HDB_ClearPoison(handle); Fail(err); return end
      if isCurrent and not isCurrent() then return end
      local index = 1
      if generation ~= targetDecodeGeneration then Fail("database cache changed during paged query") return end
      local count = table.getn(rows or {})
      local function DecodeTrackingBatch()
        if generation ~= targetDecodeGeneration or (isCurrent and not isCurrent()) then return true end
        local last = math.min(index + 127, count)
        for i = index, last do
          local r = rows[i]
          table.insert(records, {kind=r[1],id=tonumber(r[2]),value=r[3],title=r[4],level=r[5],zoneID=tonumber(r[6]),x=tonumber(r[7]),y=tonumber(r[8]),respawn=tonumber(r[9])})
          rows[i] = nil
        end
        index = last + 1
        if index <= count then return false end
        offset = offset + count
        if count == pageSize then SubmitPage() return true end
        finished = true
        if callback then callback(records, nil) end
        return true
      end
      if count > 128 then QueueTargetDecode(DecodeTrackingBatch, nil, nil, "tracking " .. relation)
      else DecodeTrackingBatch() end
    end)
    if not ok or not ticket then Fail("could not submit tracking query"); return nil end
    return ticket
  end
  return SubmitPage()
end

function provider:GetEntityInfoAsync(kind, id, callback)
  local handle = Open()
  id = tonumber(id)
  if not handle or (kind ~= "U" and kind ~= "O") or not id then
    if callback then callback(nil, "HearthDB is unavailable or entity is invalid") end
    return nil
  end
  local cacheKey = CurrentLocale() .. ":" .. kind .. ":" .. id
  if entityInfoCache[cacheKey] then
    if callback then callback(entityInfoCache[cacheKey], nil) end
    return true
  end
  local sql = "SELECT e.title, m.level, m.faction, m.rank, os.required_skill, os.profession, s.zone_id, s.x, s.y, s.respawn FROM entity_text e "
    .. "LEFT JOIN entity_meta m ON m.target_kind = e.target_kind AND m.target_id = e.target_id "
    .. "LEFT JOIN object_skill os ON e.target_kind = 'O' AND os.object_id = e.target_id "
    .. "LEFT JOIN spawn s ON s.target_kind = e.target_kind AND s.target_id = e.target_id "
    .. "WHERE e.locale = '" .. CurrentLocale() .. "' AND e.target_kind = '" .. kind .. "' AND e.target_id = " .. id
  local ok, ticket = pcall(HDB_QueryRawAsync, handle, sql, function(columns, rows, err)
    if err then
      HDB_ClearPoison(handle)
      if callback then callback(nil, err) end
      return
    end
    local record
    for index = 1, table.getn(rows or {}) do
      local row = rows[index]
      record = record or { id = id, kind = kind, title = row[1], level = row[2], faction = row[3], rank = row[4], requiredSkill = row[5], profession = row[6], zones = {}, spawns = {} }
      if row[7] then
        local zone = tonumber(row[7])
        record.zones[zone] = (record.zones[zone] or 0) + 1
        table.insert(record.spawns, { zoneID = zone, x = tonumber(row[8]), y = tonumber(row[9]), respawn = tonumber(row[10]) })
      end
    end
    if record then entityInfoCache[cacheKey] = record end
    if callback then callback(record, nil) end
  end)
  if not ok or not ticket then
    if callback then callback(nil, "could not submit entity query") end
    return nil
  end
  return ticket
end

-- Search is intentionally separate from the exact-title lookup above. The
-- browser needs partial matches, while map rendering needs exact duplicate
-- title handling. Keeping both APIs prevents an accidental broad query in a
-- map refresh.
function provider:SearchItemTitlesAsync(query, limit, callback)
  local handle = Open()
  query, limit = tostring(query or ""), tonumber(limit) or 50
  if not handle or query == "" then
    if callback then callback(nil, "HearthDB is unavailable or item search is invalid") end
    return nil
  end
  local cacheKey = CurrentLocale() .. ":" .. string.lower(query) .. ":" .. limit
  if itemSearchCache[cacheKey] then
    if callback then callback(itemSearchCache[cacheKey], nil) end
    return true
  end
  local safeQuery = string.lower(string.gsub(query, "'", "''"))
  local searchColumn = tonumber(query) and "CAST(item_id AS TEXT)" or "LOWER(title)"
  local sql = "SELECT i.item_id, i.title, "
    .. "EXISTS (SELECT 1 FROM item_source s WHERE s.item_id=i.item_id AND s.source_kind='U') "
    .. "OR EXISTS (SELECT 1 FROM item_source s JOIN refloot_source r ON r.reference_id=s.source_id "
    .. "WHERE s.item_id=i.item_id AND s.source_kind='R' AND r.source_kind='U'), "
    .. "EXISTS (SELECT 1 FROM item_source s WHERE s.item_id=i.item_id AND s.source_kind='O') "
    .. "OR EXISTS (SELECT 1 FROM item_source s JOIN refloot_source r ON r.reference_id=s.source_id "
    .. "WHERE s.item_id=i.item_id AND s.source_kind='R' AND r.source_kind='O'), "
    .. "EXISTS (SELECT 1 FROM item_source s WHERE s.item_id=i.item_id AND s.source_kind='V') "
    .. "FROM item_text i WHERE i.locale = '" .. CurrentLocale()
    .. "' AND " .. searchColumn .. " LIKE '%" .. safeQuery .. "%' ORDER BY i.title, i.item_id LIMIT " .. limit
  local ok, ticket = pcall(HDB_QueryRawAsync, handle, sql, function(columns, rows, err)
    if err then
      HDB_ClearPoison(handle)
      if callback then callback(nil, err) end
      return
    end
    local results = {}
    for index = 1, table.getn(rows or {}) do
      local row = rows[index]
      results[tonumber(row[1])] = {
        title = row[2], hasUnitSources = tonumber(row[3]) == 1,
        hasObjectSources = tonumber(row[4]) == 1, hasVendorSources = tonumber(row[5]) == 1,
      }
    end
    itemSearchCache[cacheKey] = results
    if callback then callback(results, nil) end
  end)
  if not ok or not ticket then
    if callback then callback(nil, "could not submit item search query") end
    return nil
  end
  return ticket
end

function provider:GetItemIDsByTitleAsync(title, callback)
  local handle = Open()
  title = tostring(title or "")
  if not handle or title == "" then
    if callback then callback(nil, "HearthDB is unavailable or item title is empty") end
    return nil
  end
  local cacheKey = CurrentLocale() .. ":exact:" .. string.lower(title)
  if itemSearchCache[cacheKey] then
    if callback then callback(itemSearchCache[cacheKey], nil) end
    return true
  end
  local safeTitle = string.gsub(title, "'", "''")
  local sql = "SELECT item_id, title FROM item_text WHERE locale = '" .. CurrentLocale()
    .. "' AND LOWER(title) = LOWER('" .. safeTitle .. "') ORDER BY item_id"
  local ok, ticket = pcall(HDB_QueryRawAsync, handle, sql, function(columns, rows, err)
    if err then
      HDB_ClearPoison(handle)
      if callback then callback(nil, err) end
      return
    end
    local results = {}
    for index = 1, table.getn(rows or {}) do
      local row = rows[index]
      results[tonumber(row[1])] = row[2]
    end
    itemSearchCache[cacheKey] = results
    if callback then callback(results, nil) end
  end)
  if not ok or not ticket then
    if callback then callback(nil, "could not submit item title query") end
    return nil
  end
  return ticket
end

function provider:SearchQuestTitlesAsync(query, limit, callback)
  local handle = Open()
  query = tostring(query or "")
  limit = tonumber(limit) or 50
  if not handle or query == "" then
    if callback then callback(nil, "HearthDB is unavailable or query is empty") end
    return nil
  end

  local cacheKey = CurrentLocale() .. ":" .. string.lower(query) .. ":" .. limit
  if questSearchCache[cacheKey] then
    if callback then callback(questSearchCache[cacheKey], nil) end
    return true
  end

  local numeric = tonumber(query)
  local where
  if numeric then
    where = "CAST(t.id AS TEXT) LIKE '%" .. string.gsub(query, "'", "''") .. "%'"
  else
    where = "LOWER(t.title) LIKE '%" .. string.lower(string.gsub(query, "'", "''")) .. "%'"
  end
  local factionMatch = [[SELECT 1 FROM quest_target qt
      JOIN entity_meta em ON em.target_kind = qt.target_kind AND em.target_id = qt.target_id
      WHERE qt.quest_id = t.id AND qt.phase = 'start' AND em.faction IN (%s)]]
  local hasBoth = string.format(factionMatch, "'AH','HA'")
  local hasAlliance = string.format(factionMatch, "'A','AH','HA'")
  local hasHorde = string.format(factionMatch, "'H','AH','HA'")
  local sql = [[SELECT t.id, t.title, t.level,
      CASE WHEN qm.race_mask <> '' THEN CAST(qm.race_mask AS INTEGER)
           WHEN EXISTS (]] .. hasBoth .. [[) THEN 255
           WHEN EXISTS (]] .. hasAlliance .. [[) AND EXISTS (]] .. hasHorde .. [[) THEN 255
           WHEN EXISTS (]] .. hasAlliance .. [[) THEN 77
           WHEN EXISTS (]] .. hasHorde .. [[) THEN 178
           ELSE 0 END
    FROM quest_text t LEFT JOIN quest_meta qm ON qm.quest_id = t.id
    WHERE t.locale = ']] .. CurrentLocale() .. "' AND " .. where
    .. " ORDER BY t.title, t.id LIMIT " .. limit
  local ok, ticket = pcall(HDB_QueryRawAsync, handle, sql, function(columns, rows, err)
    if err then
      HDB_ClearPoison(handle)
      if callback then callback(nil, err) end
      return
    end
    local results = {}
    for index = 1, table.getn(rows or {}) do
      local row = rows[index]
      results[tonumber(row[1])] = { title = row[2], level = row[3], raceMask = tonumber(row[4]) or 0 }
    end
    questSearchCache[cacheKey] = results
    if callback then callback(results, nil) end
  end)
  if not ok or not ticket then
    if callback then callback(nil, "could not submit quest search query") end
    return nil
  end
  return ticket
end

function provider:GetQuestTextAsync(id, callback)
  local handle = Open()
  id = tonumber(id)
  if not handle or not id then
    if callback then callback(nil, "HearthDB is unavailable or quest id is invalid") end
    return nil
  end
  local cacheKey = CacheKey(id)
  if questTextCache[cacheKey] then
    if callback then callback(questTextCache[cacheKey], nil) end
    return true
  end

  local sql = "SELECT id, title, objective, description, level, min_level FROM quest_text WHERE locale = '"
    .. CurrentLocale() .. "' AND id = " .. id
  local ok, ticket = pcall(HDB_QueryRawAsync, handle, sql, function(columns, rows, err)
    if err then
      HDB_ClearPoison(handle)
      if callback then callback(nil, err) end
      return
    end
    local row = rows and rows[1]
    if not row then
      if callback then callback(nil, nil) end
      return
    end
    local record = {
      id = tonumber(row[1]), title = row[2], objective = row[3], description = row[4],
      level = row[5], minLevel = row[6],
    }
    questTextCache[cacheKey] = record
    if callback then callback(record, nil) end
  end)
  if not ok or not ticket then
    if callback then callback(nil, "could not submit quest text query") end
    return nil
  end
  return ticket
end

function provider:GetQuestIDsByTitleAsync(title, callback)
  local handle = Open()
  if not handle or not title or title == "" then
    if callback then callback(nil, "HearthDB is unavailable or title is invalid") end
    return nil
  end
  local cacheKey = CurrentLocale() .. ":title-id:" .. string.lower(title)
  local cached = questTitleIDIndex and questTitleIDIndex[cacheKey] or questTitleIDCache[cacheKey]
  if cached then
    if callback then callback(cached, nil) end
    return true
  end
  local safeTitle = (string.gsub(title, "'", "''"))
  local sql = "SELECT id FROM quest_text WHERE locale = '" .. CurrentLocale()
    .. "' AND LOWER(title) = LOWER('" .. safeTitle .. "') ORDER BY id"
  local ok, ticket = pcall(HDB_QueryRawAsync, handle, sql, function(columns, rows, err)
    if err then
      HDB_ClearPoison(handle)
      if callback then callback(nil, err) end
      return
    end
    local ids = {}
    for index = 1, table.getn(rows or {}) do table.insert(ids, tonumber(rows[index][1])) end
    questTitleIDCache[cacheKey] = ids
    for index = 1, table.getn(ids) do questTitleByIDCache[ids[index]] = title end
    if callback then callback(ids, nil) end
  end)
  if not ok or not ticket then
    if callback then callback(nil, "could not submit title query") end
    return nil
  end
  return ticket
end

function provider:GetQuestTextByTitleAsync(title, callback)
  local handle = Open()
  if not handle or not title or title == "" then
    if callback then callback(nil, "HearthDB is unavailable or title is invalid") end
    return nil
  end
  local safeTitle = string.gsub(title, "'", "''")
  local sql = "SELECT qt.id, qt.title, qt.objective, qt.description, qm.level, qm.min_level "
    .. "FROM quest_text qt JOIN quest_meta qm ON qm.quest_id = qt.id "
    .. "WHERE qt.locale = '" .. CurrentLocale() .. "' AND LOWER(qt.title) = LOWER('"
    .. safeTitle .. "') ORDER BY qt.id LIMIT 1"
  local ok, ticket = pcall(HDB_QueryRawAsync, handle, sql, function(columns, rows, err)
    if err then
      HDB_ClearPoison(handle)
      if callback then callback(nil, err) end
      return
    end
    local row = rows and rows[1]
    if not row then
      if callback then callback(nil, "quest title was not found") end
      return
    end
    local record = {
      id = tonumber(row[1]), title = row[2], objective = row[3], description = row[4],
      level = tonumber(row[5]), minLevel = tonumber(row[6]),
    }
    questTextCache[CacheKey(record.id)] = record
    questTitleByIDCache[record.id] = record.title
    if callback then callback(record, nil) end
  end)
  if not ok or not ticket then
    if callback then callback(nil, "could not submit title-text query") end
    return nil
  end
  return ticket
end

function provider:GetCachedQuestIDsByTitle(title)
  if not title or title == "" then return nil, questTitleIDPreloaded end
  local key = "enUS:title-id:" .. string.lower(title)
  return (questTitleIDIndex and questTitleIDIndex[key] or questTitleIDCache[key]), questTitleIDPreloaded
end

function provider:GetCachedQuestTitleByID(id)
  return questTitleByIDCache[tonumber(id)], questTitleIDPreloaded
end

function provider:PreloadQuestTitleIDsAsync(callback)
  local handle = Open()
  if not handle then
    if callback then callback(nil, "HearthDB is unavailable") end
    return nil
  end
  if questTitleIDPreloaded then
    if callback then callback(true, nil) end
    return true
  end
  if questTitleIDPreloading then
    if callback then table.insert(questTitleIDPreloading.callbacks, callback) end
    return true
  end
  local generation = targetDecodeGeneration
  local request = {callbacks = {}}
  if callback then table.insert(request.callbacks, callback) end
  questTitleIDPreloading = request
  local finished = false
  local function IsCurrent()
    return generation == targetDecodeGeneration and questTitleIDPreloading == request
  end
  local function Finish(err)
    if finished then return end
    finished = true
    if questTitleIDPreloading == request then questTitleIDPreloading = nil end
    local callbacks = request.callbacks
    request.callbacks = {}
    for _, done in ipairs(callbacks) do
      local ok, message = pcall(done, not err and true or nil, err)
      if not ok and type(geterrorhandler) == "function" then geterrorhandler()(message) end
    end
  end
  local batchSize, firstTicket = 256, nil
  local grouped = {}
  local previousTitle, previousKey
  local function SubmitBatch(offset)
    if not IsCurrent() then Finish("database cache changed during preload") return nil end
    local sql = "SELECT title, id FROM quest_text WHERE locale = 'enUS' ORDER BY title, id LIMIT "
      .. batchSize .. " OFFSET " .. offset
    local ok, ticket = pcall(HDB_QueryRawAsync, handle, sql, function(columns, rows, err)
      if err then HDB_ClearPoison(handle); Finish(err) return end
      if not IsCurrent() then Finish("database cache changed during preload") return end
      local count = table.getn(rows or {})
      for index = 1, count do
        local row = rows[index]
        if row[1] ~= previousTitle then
          previousTitle = row[1]
          previousKey = "enUS:title-id:" .. string.lower(row[1])
        end
        local key = previousKey
        local ids = grouped[key]
        if not ids then ids = {}; grouped[key] = ids end
        local id = tonumber(row[2])
        table.insert(ids, id)
        questTitleByIDCache[id] = row[1]
        rows[index] = nil
      end
      if count == batchSize then SubmitBatch(offset + batchSize); return end
      -- Publish the finished index by ownership transfer, without copying
      -- every entry into a second hash table. On-demand lookups stay separate.
      questTitleIDIndex = grouped
      questTitleIDPreloaded = true
      Finish(nil)
    end)
    if not ok or not ticket then Finish("could not submit quest preload") return nil end
    if not firstTicket then firstTicket = ticket end
    return ticket
  end
  SubmitBatch(0)
  return firstTicket
end

function provider:GetQuestDisambiguationAsync(title, callback)
  local handle = Open()
  title = tostring(title or "")
  if not handle or title == "" then
    if callback then callback(nil, "HearthDB is unavailable or title is invalid") end
    return nil
  end
  local cacheKey = CurrentLocale() .. ":disambiguation:" .. string.lower(title)
  local cached = questDisambiguationIndex and questDisambiguationIndex[cacheKey] or questDisambiguationCache[cacheKey]
  if cached then
    if callback then callback(cached, nil) end
    return true
  end
  local safeTitle = string.gsub(title, "'", "''")
  local sql = [[SELECT d.quest_id, q.objective, q.description, d.objective_targets,
      d.prerequisites, d.level, d.race_mask, d.class_mask, d.resolution_class,
      (SELECT GROUP_CONCAT((CASE t.target_kind WHEN 'U' THEN 'monster' WHEN 'I' THEN 'item'
         WHEN 'O' THEN 'object' ELSE LOWER(t.target_kind) END) || ':'
         || LOWER(COALESCE(e.title, i.title, '')), '|')
       FROM quest_target t
       LEFT JOIN entity_text e ON e.locale = q.locale AND e.target_kind = t.target_kind
         AND e.target_id = t.target_id
       LEFT JOIN item_text i ON i.locale = q.locale AND t.target_kind = 'I'
         AND i.item_id = t.target_id
       WHERE t.quest_id = d.quest_id AND t.phase = 'obj')
    FROM quest_text q
    JOIN quest_disambiguation d ON d.locale = q.locale AND d.quest_id = q.id
    WHERE q.locale = ']] .. CurrentLocale() .. [[' AND LOWER(q.title) = LOWER(']]
    .. safeTitle .. [[') ORDER BY d.quest_id]]
  local ok, ticket = pcall(HDB_QueryRawAsync, handle, sql, function(columns, rows, err)
    if err then
      HDB_ClearPoison(handle)
      if callback then callback(nil, err) end
      return
    end
    local records = {}
    for index = 1, table.getn(rows or {}) do
      local row = rows[index]
      table.insert(records, {
        id = tonumber(row[1]), objective = row[2], description = row[3],
        objectiveTargets = row[4], prerequisites = row[5], level = row[6],
        raceMask = row[7], classMask = row[8], resolutionClass = row[9], objectiveLabels = row[10],
      })
    end
    questDisambiguationCache[cacheKey] = records
    if callback then callback(records, nil) end
  end)
  if not ok or not ticket then
    if callback then callback(nil, "could not submit quest disambiguation query") end
    return nil
  end
  return ticket
end

-- Turtle WoW uses the enUS client. Warm the small same-title candidate set in
-- the background at login so the first stage normally needs no SQLite trip.
function provider:PreloadQuestDisambiguationAsync(callback)
  local handle = Open()
  if not handle then
    if callback then callback(nil, "HearthDB is unavailable") end
    return nil
  end
  if questDisambiguationPreloaded then
    if callback then callback(true, nil) end
    return true
  end
  if questDisambiguationPreloading then
    if callback then table.insert(questDisambiguationPreloading.callbacks, callback) end
    return true
  end
  local generation = targetDecodeGeneration
  local request = {callbacks = {}}
  if callback then table.insert(request.callbacks, callback) end
  questDisambiguationPreloading = request
  local finished = false
  local function IsCurrent()
    return generation == targetDecodeGeneration and questDisambiguationPreloading == request
  end
  local function Finish(err)
    if finished then return end
    finished = true
    if questDisambiguationPreloading == request then questDisambiguationPreloading = nil end
    local callbacks = request.callbacks
    request.callbacks = {}
    for _, done in ipairs(callbacks) do
      local ok, message = pcall(done, not err and true or nil, err)
      if not ok and type(geterrorhandler) == "function" then geterrorhandler()(message) end
    end
  end
  local batchSize, firstTicket = 128, nil
  local grouped = {}
  local previousTitle, previousKey
  local baseSQL = [[SELECT q.title, d.quest_id, q.objective, q.description, d.objective_targets,
      d.prerequisites, d.level, d.race_mask, d.class_mask, d.resolution_class,
      (SELECT GROUP_CONCAT((CASE t.target_kind WHEN 'U' THEN 'monster' WHEN 'I' THEN 'item'
         WHEN 'O' THEN 'object' ELSE LOWER(t.target_kind) END) || ':'
         || LOWER(COALESCE(e.title, i.title, '')), '|')
       FROM quest_target t
       LEFT JOIN entity_text e ON e.locale = q.locale AND e.target_kind = t.target_kind
         AND e.target_id = t.target_id
       LEFT JOIN item_text i ON i.locale = q.locale AND t.target_kind = 'I'
         AND i.item_id = t.target_id
       WHERE t.quest_id = d.quest_id AND t.phase = 'obj')
    FROM quest_text q
    JOIN quest_disambiguation d ON d.locale = q.locale AND d.quest_id = q.id
    WHERE q.locale = 'enUS' ORDER BY q.title, d.quest_id]]
  local function SubmitBatch(offset)
    if not IsCurrent() then Finish("database cache changed during preload") return nil end
    local sql = baseSQL .. " LIMIT " .. batchSize .. " OFFSET " .. offset
    local ok, ticket = pcall(HDB_QueryRawAsync, handle, sql, function(columns, rows, err)
      if err then HDB_ClearPoison(handle); Finish(err) return end
      if not IsCurrent() then Finish("database cache changed during preload") return end
      local count = table.getn(rows or {})
      for index = 1, count do
        local row = rows[index]
        if row[1] ~= previousTitle then
          previousTitle = row[1]
          previousKey = "enUS:disambiguation:" .. string.lower(row[1])
        end
        local key = previousKey
        local records = grouped[key]
        if not records then records = {}; grouped[key] = records end
        table.insert(records, {
          id = tonumber(row[2]), objective = row[3], description = row[4],
          objectiveTargets = row[5], prerequisites = row[6], level = row[7],
          raceMask = row[8], classMask = row[9], resolutionClass = row[10], objectiveLabels = row[11],
        })
        rows[index] = nil
      end
      if count == batchSize then SubmitBatch(offset + batchSize); return end
      -- Publish the finished index by ownership transfer, without copying
      -- every entry into a second hash table. On-demand lookups stay separate.
      questDisambiguationIndex = grouped
      questDisambiguationPreloaded = true
      Finish(nil)
    end)
    if not ok or not ticket then Finish("could not submit quest preload") return nil end
    if not firstTicket then firstTicket = ticket end
    return ticket
  end
  SubmitBatch(0)
  return firstTicket
end

function provider:GetItemSourcesAsync(id, callback)
  local handle = Open()
  id = tonumber(id)
  if not handle or not id then
    if callback then callback(nil, "HearthDB is unavailable or item id is invalid") end
    return nil
  end
  local locale = CurrentLocale()
  local sql = [[WITH source AS (
      SELECT source_kind, source_id, chance, 'direct' AS source_mode
      FROM item_source WHERE item_id = ]] .. id .. [[ AND source_kind IN ('U', 'O', 'V')
      UNION ALL
      SELECT r.source_kind, r.source_id, s.chance, 'reference' AS source_mode
      FROM item_source s JOIN refloot_source r ON r.reference_id = s.source_id
      WHERE s.item_id = ]] .. id .. [[ AND s.source_kind = 'R'
    )
    SELECT i.title, s.source_kind, s.source_id, s.chance, s.source_mode, e.title,
      sp.zone_id, sp.x, sp.y, sp.respawn, em.level
    FROM item_text i
    LEFT JOIN source s ON 1 = 1
    LEFT JOIN entity_text e ON e.target_kind = CASE WHEN s.source_kind = 'V' THEN 'U' ELSE s.source_kind END
      AND e.target_id = s.source_id AND e.locale = ']]
    .. locale .. [['
    LEFT JOIN entity_meta em ON em.target_kind = CASE WHEN s.source_kind = 'V' THEN 'U' ELSE s.source_kind END
      AND em.target_id = s.source_id
    LEFT JOIN spawn sp ON sp.target_kind = CASE WHEN s.source_kind = 'V' THEN 'U' ELSE s.source_kind END
      AND sp.target_id = s.source_id
    WHERE i.locale = ']] .. locale .. [[' AND i.item_id = ]] .. id
  local ok, ticket = pcall(HDB_QueryRawAsync, handle, sql, function(columns, rows, err)
    if err then
      HDB_ClearPoison(handle)
      if callback then callback(nil, err) end
      return
    end
    local record = { id = id, sources = {} }
    for index = 1, table.getn(rows or {}) do
      local row = rows[index]
      record.title = row[1] or record.title
      if row[2] then
        table.insert(record.sources, {
          kind = row[2], id = tonumber(row[3]), chance = tonumber(row[4]), mode = row[5], title = row[6],
          zoneID = tonumber(row[7]), x = tonumber(row[8]), y = tonumber(row[9]), respawn = tonumber(row[10]), level = row[11],
        })
      end
    end
    if not record.title then
      if callback then callback(nil, nil) end
      return
    end

    -- Some generic container templates carry loot but no individual world
    -- spawns. Resolve only those templates in a second query through mapped
    -- objects with the same localized name. Keeping this separate avoids
    -- changing the fast direct-source query used by ordinary item searches.
    local unresolved, sourceInfo = {}, {}
    for sourceIndex = 1, table.getn(record.sources) do
      local source = record.sources[sourceIndex]
      if source.kind == "O" and source.title and not source.zoneID and not sourceInfo[source.id] then
        sourceInfo[source.id] = source
        table.insert(unresolved, tostring(source.id))
      end
    end

    if table.getn(unresolved) == 0 then
      if callback then callback(record, nil) end
      return
    end

    local variantSQL = [[SELECT original.target_id, original.title,
        sp.zone_id, sp.x, sp.y, sp.respawn
      FROM entity_text original
      JOIN entity_text variant ON variant.target_kind = 'O'
        AND variant.locale = original.locale AND variant.title = original.title
      JOIN spawn sp ON sp.target_kind = 'O' AND sp.target_id = variant.target_id
      WHERE original.target_kind = 'O' AND original.locale = ']] .. locale .. [['
        AND original.target_id IN (]] .. table.concat(unresolved, ",") .. [[)
        AND NOT EXISTS (
          SELECT 1 FROM spawn direct_spawn
          WHERE direct_spawn.target_kind = 'O' AND direct_spawn.target_id = original.target_id
        )]]
    local variantOK, variantTicket = pcall(HDB_QueryRawAsync, handle, variantSQL, function(_, variantRows, variantErr)
      if not variantErr then
        for rowIndex = 1, table.getn(variantRows or {}) do
          local row, originalID = variantRows[rowIndex], tonumber(variantRows[rowIndex][1])
          local source = sourceInfo[originalID]
          if source then
            table.insert(record.sources, {
              kind = "O", id = originalID, chance = source.chance, mode = source.mode, title = row[2],
              zoneID = tonumber(row[3]), x = tonumber(row[4]), y = tonumber(row[5]), respawn = tonumber(row[6]),
            })
          end
        end
      else
        HDB_ClearPoison(handle)
      end
      if callback then callback(record, nil) end
    end)
    if not variantOK or not variantTicket then
      if callback then callback(record, nil) end
    end
  end)
  if not ok or not ticket then
    if callback then callback(nil, "could not submit item source query") end
    return nil
  end
  return ticket
end

function provider:GetUnitDropsAsync(unitID, callback)
  local handle = Open()
  unitID = tonumber(unitID)
  if not handle or not unitID then
    if callback then callback(nil, "HearthDB is unavailable or unit id is invalid") end
    return nil
  end
  if unitDropsCache[unitID] then callback(unitDropsCache[unitID], nil); return true end
  local sql = [[SELECT item_id, chance, source_type, source_count,
    EXISTS(SELECT 1 FROM quest_target q WHERE q.phase='start' AND q.target_kind='I' AND q.target_id=drops.item_id),
    (SELECT title FROM item_text it WHERE it.item_id=drops.item_id AND it.locale=']] .. CurrentLocale() .. [[' LIMIT 1) FROM (
    SELECT s.item_id AS item_id, s.chance AS chance, 'direct' AS source_type,
      (SELECT COUNT(*) FROM item_source c WHERE c.item_id=s.item_id AND c.source_kind='U') AS source_count
    FROM item_source s WHERE s.source_kind='U' AND s.source_id=]] .. unitID .. [[
      AND NOT EXISTS (SELECT 1 FROM refloot_source token WHERE token.reference_id=s.item_id)
    UNION ALL
    SELECT s.item_id AS item_id, s.chance AS chance, 'reference' AS source_type,
      (SELECT COUNT(*) FROM refloot_source c WHERE c.reference_id=s.source_id AND c.source_kind='U') AS source_count
    FROM item_source s JOIN refloot_source r ON r.reference_id=s.source_id
      AND r.source_kind='U' AND r.source_id=]] .. unitID .. [[
    WHERE s.source_kind='R') drops ORDER BY CAST(chance AS REAL) DESC]]
  local ok, ticket = pcall(HDB_QueryRawAsync, handle, sql, function(_, rows, err)
    if err then HDB_ClearPoison(handle); callback(nil, err); return end
    local drops, seen = {}, {}
    for index=1,table.getn(rows or {}) do local row=rows[index]; local item=tonumber(row[1])
      if item and not seen[item] then seen[item]=true; table.insert(drops,{item=item,chance=tonumber(row[2]) or 0,isRef=row[3]=="reference",sourceCount=tonumber(row[4]) or 0,isQuestStarter=tonumber(row[5])==1,title=row[6]}) end
    end
    unitDropsCache[unitID]=drops; callback(drops,nil)
  end)
  if not ok or not ticket then callback(nil,"could not submit unit drops query"); return nil end
  return ticket
end

function provider:GetQuestEligibilityAsync(id, callback)
  local handle = Open()
  id = tonumber(id)
  if not handle or not id then
    if callback then callback(nil, "HearthDB is unavailable or quest id is invalid") end
    return nil
  end
  local sql = [[SELECT m.level, m.min_level, m.race_mask, m.class_mask, m.skill, m.event, p.prerequisite_id, m.repeatable
    FROM quest_meta m LEFT JOIN quest_prerequisite p ON p.quest_id = m.quest_id
    WHERE m.quest_id = ]] .. id
  local ok, ticket = pcall(HDB_QueryRawAsync, handle, sql, function(columns, rows, err)
    if err then
      HDB_ClearPoison(handle)
      if callback then callback(nil, err) end
      return
    end
    local row = rows and rows[1]
    if not row then
      if callback then callback(nil, nil) end
      return
    end
    local record = {
      id = id, level = row[1], minLevel = row[2], raceMask = row[3], classMask = row[4],
      skill = row[5], event = row[6], prerequisites = {}, repeatable = row[8] == "1",
    }
    for index = 1, table.getn(rows) do
      if rows[index][7] then table.insert(record.prerequisites, tonumber(rows[index][7])) end
    end
    if callback then callback(record, nil) end
  end)
  if not ok or not ticket then
    if callback then callback(nil, "could not submit quest eligibility query") end
    return nil
  end
  return ticket
end

-- Public experimental contract. It returns plain records, rather than HDB's
-- positional rows, so a future pfQuest adapter will not depend on SQL layout.
-- Native provider boundary for the available-quest-giver phase. It applies
-- stable eligibility predicates in SQLite; the addon will later apply history,
-- prerequisites, and profession checks before it renders any results.
function provider:GetQuestStartPinsAsync(options, callback)
  options = options or {}
  local function IsCurrent()
    return not options.isCurrent or options.isCurrent()
  end
  if not IsCurrent() then return nil end
  if options.deliveryBatch then
    local pageSize = math.max(64, math.min(512, math.floor(tonumber(options.deliveryBatch) or 512)))
    local accumulated, finished = {}, false
    local function SubmitPage(offset)
      if not IsCurrent() then finished = true return nil end
      local page = {}
      for key, value in pairs(options) do page[key] = value end
      page.deliveryBatch, page.deliveryLimit, page.deliveryOffset = nil, pageSize, offset
      return self:GetQuestStartPinsAsync(page, function(pins, err)
        if finished or not IsCurrent() then finished = true return end
        if err or not pins then
          finished = true
          if callback then callback(nil, err or "starter page missing") end
          return
        end
        for index = 1, table.getn(pins) do table.insert(accumulated, pins[index]) end
        if table.getn(pins) == pageSize then
          SubmitPage(offset + pageSize)
        else
          finished = true
          if callback then callback(accumulated, nil) end
        end
      end)
    end
    return SubmitPage(0)
  end
  local handle = Open()
  if not handle then
    if callback then callback(nil, "HearthDB is unavailable") end
    return nil
  end
  local level = math.floor(tonumber(options.level) or 0)
  local highOffset = math.floor(tonumber(options.highOffset) or 0)
  local raceMask = math.floor(tonumber(options.raceMask) or 0)
  local classMask = math.floor(tonumber(options.classMask) or 0)
  local faction = options.faction == "H" and "H" or "A"
  local includeLow = options.includeLow and 1 or 0
  local includeAllLevels = options.includeAllLevels and 1 or 0
  local includeEvents = options.includeEvents and 1 or 0
  local includeRepeatable = options.includeRepeatable and 1 or 0
  local questID = math.floor(tonumber(options.questID) or 0)
  local prerequisiteID = math.floor(tonumber(options.prerequisiteID) or 0)
  local sql = [[WITH resolved_start AS (
      SELECT q.quest_id, q.target_kind, q.target_id, q.target_kind AS origin_kind,
        q.target_id AS origin_id, NULL AS chance
      FROM quest_target q
      WHERE q.phase = 'start' AND q.target_kind IN ('U', 'O')
      UNION ALL
      SELECT q.quest_id, src.source_kind, src.source_id, 'I', q.target_id, src.chance
      FROM quest_target q JOIN item_source src ON src.item_id = q.target_id
        AND src.source_kind IN ('U', 'O')
      WHERE q.phase = 'start' AND q.target_kind = 'I'
      UNION ALL
      SELECT q.quest_id, ref.source_kind, ref.source_id, 'I', q.target_id, src.chance
      FROM quest_target q JOIN item_source src ON src.item_id = q.target_id AND src.source_kind = 'R'
      JOIN refloot_source ref ON ref.reference_id = src.source_id AND ref.source_kind IN ('U', 'O')
      WHERE q.phase = 'start' AND q.target_kind = 'I'
    )
    SELECT q.quest_id, qt.title, qt.objective, qm.level, qm.min_level, qm.skill, qm.event,
      q.target_kind, q.target_id, em.level, em.faction, s.x, s.y, s.zone_id, s.respawn, e.title,
      GROUP_CONCAT(qp.prerequisite_id), q.origin_kind, q.origin_id, q.chance, it.title, qm.repeatable
    FROM resolved_start q
    JOIN quest_text qt ON qt.id = q.quest_id AND qt.locale = ']] .. CurrentLocale() .. [['
    JOIN quest_meta qm ON qm.quest_id = q.quest_id
    LEFT JOIN quest_prerequisite qp ON qp.quest_id = q.quest_id
    JOIN spawn s ON s.target_kind = q.target_kind AND s.target_id = q.target_id
    LEFT JOIN entity_meta em ON em.target_kind = q.target_kind AND em.target_id = q.target_id
    LEFT JOIN entity_text e ON e.target_kind = q.target_kind AND e.target_id = q.target_id
      AND e.locale = ']] .. CurrentLocale() .. [['
    LEFT JOIN item_text it ON it.item_id = q.origin_id AND q.origin_kind = 'I'
      AND it.locale = ']] .. CurrentLocale() .. [['
    WHERE 1 = 1
      AND (]] .. questID .. [[ = 0 OR q.quest_id = ]] .. questID .. [[)
      AND (]] .. prerequisiteID .. [[ = 0 OR EXISTS (
        SELECT 1 FROM quest_prerequisite direct_pre
        WHERE direct_pre.quest_id = q.quest_id
          AND direct_pre.prerequisite_id = ]] .. prerequisiteID .. [[
      ))
      AND (qm.race_mask = '' OR (CAST(qm.race_mask AS INTEGER) & ]] .. raceMask .. [[) = ]] .. raceMask .. [[)
      AND (qm.class_mask = '' OR (CAST(qm.class_mask AS INTEGER) & ]] .. classMask .. [[) = ]] .. classMask .. [[)
      AND (]] .. includeEvents .. [[ = 1 OR qm.event = '')
      AND (]] .. includeRepeatable .. [[ = 1 OR qm.repeatable = '')
      AND (]] .. includeAllLevels .. [[ = 1 OR ]] .. includeLow .. [[ = 1 OR CAST(qm.level AS INTEGER) >= ]] .. (level - 4) .. [[)
      AND (]] .. includeAllLevels .. [[ = 1 OR CAST(qm.min_level AS INTEGER) <= ]] .. (level + highOffset) .. [[)
      AND (em.faction IS NULL OR em.faction = '' OR instr(em.faction, ']] .. faction .. [[') > 0)
    GROUP BY q.quest_id, q.target_kind, q.target_id, q.origin_kind, q.origin_id,
      q.chance, s.x, s.y, s.zone_id, s.respawn]]
  if options.deliveryLimit then
    sql = sql .. " ORDER BY q.quest_id, q.target_kind, q.target_id, q.origin_kind, q.origin_id, q.chance, s.x, s.y, s.zone_id, s.respawn"
      .. " LIMIT " .. math.floor(options.deliveryLimit) .. " OFFSET " .. math.floor(options.deliveryOffset or 0)
  end
  local ok, ticket = pcall(HDB_QueryRawAsync, handle, sql, function(columns, rows, err)
    if not IsCurrent() then
      if err then HDB_ClearPoison(handle) end
      return
    end
    if err then
      HDB_ClearPoison(handle)
      if callback then callback(nil, err) end
      return
    end
    local pins, index = {}, 1
    local count = table.getn(rows or {})
    local generation = targetDecodeGeneration
    local function DecodeStarterBatch()
      if not IsCurrent() then return true end
      if generation ~= targetDecodeGeneration then
        if callback then callback(nil, "database changed during starter decode") end
        return true
      end
      local last = math.min(index + 31, count)
      for index = index, last do
      local row = rows[index]
      table.insert(pins, {
        questID = tonumber(row[1]), quest = row[2], objective = row[3], qlvl = tonumber(row[4]) or 0,
        qmin = tonumber(row[5]) or 0, skill = row[6], event = row[7], targetKind = row[8],
        targetID = tonumber(row[9]), level = row[10], faction = row[11], x = tonumber(row[12]),
        y = tonumber(row[13]), zoneID = tonumber(row[14]), respawn = tonumber(row[15]), title = row[16],
        prerequisites = row[17], originKind = row[18], originID = tonumber(row[19]),
        chance = tonumber(row[20]), itemTitle = row[21], repeatable = row[22] == "1",
      })
        rows[index] = nil
      end
      index = last + 1
      if index <= count then return false end
      if callback then
        if type(provider.profileDecodedCallback) == "function" then
          provider.profileDecodedCallback("starter completion", callback, pins)
        else callback(pins, nil) end
      end
      return true
    end
    if count > 32 then QueueTargetDecode(DecodeStarterBatch, nil, nil, "quest starters")
    else DecodeStarterBatch() end
  end)
  if not ok or not ticket then
    if callback then callback(nil, "could not submit start-pin query") end
    return nil
  end
  return ticket
end

-- Nameplates and party matching share the map's logical target request. The
-- decoder builds a deduplicated identity view as it visits each spawn once.
function provider:GetQuestObjectiveSummaryAsync(id, callback)
  id = tonumber(id)
  if not id then
    if callback then callback(nil, "quest id is invalid") end
    return nil
  end
  local key = CacheKey(id)
  if questObjectiveCache[key] then
    if callback then callback(questObjectiveCache[key], nil) end
    return true
  end
  local generation = targetDecodeGeneration
  return self:GetQuestTargetsAsync(id, function(_, err)
    if generation ~= targetDecodeGeneration then err = "database cache changed during objective summary" end
    if callback then callback(not err and questObjectiveCache[key] or nil, err) end
  end)
end

function provider:GetQuestTargetsAsync(id, callback, limit, onPage)
  local handle = Open()
  id = tonumber(id)
  if not handle or not id then
    if callback then callback(nil, "HearthDB is unavailable or quest id is invalid") end
    return nil
  end
  limit = math.floor(tonumber(limit) or 0)
  local cacheKey = CacheKey(id, limit > 0 and limit or nil)
  if questTargetCache[cacheKey] then
    if callback then callback(questTargetCache[cacheKey], nil) end
    return true
  end

  -- Repeated quest-log refreshes share one database load until it is cached.
  local pending = questTargetPending[cacheKey]
  if pending and pending.generation == targetDecodeGeneration then
    if callback then table.insert(pending.callbacks, callback) end
    if onPage then
      table.insert(pending.progress, onPage)
      if pending.records and table.getn(pending.records) > 0 then onPage(pending.records) end
    end
    return true
  end
  pending = { generation = targetDecodeGeneration, callbacks = {}, progress = {} }
  if callback then table.insert(pending.callbacks, callback) end
  if onPage then table.insert(pending.progress, onPage) end
  questTargetPending[cacheKey] = pending
  local function Complete(records, err)
    if questTargetPending[cacheKey] == pending then questTargetPending[cacheKey] = nil end
    local callbacks = pending.callbacks
    pending.callbacks, pending.progress = {}, {}
    for index = 1, table.getn(callbacks) do
      local ok, message = pcall(callbacks[index], records, err)
      if not ok and type(geterrorhandler) == "function" then geterrorhandler()(message) end
    end
  end

  -- Related objective sets are read-only in map/tooltip consumers. Share each
  -- identical set within this query; shared spawn sets must stay independent.
  local relatedObjectiveSets = {}
  local function RelatedObjectiveSet(text)
    if not text or text == "" then return nil end
    if relatedObjectiveSets[text] then return relatedObjectiveSets[text] end
    local names = {}
    for title in string.gfind(text, "[^|]+") do names[title] = true end
    relatedObjectiveSets[text] = names
    return names
  end
  local sql = [[WITH resolved_target AS (
      -- Keep original quest links for objective semantics.
      SELECT quest_id, phase, target_kind, target_id, target_kind AS origin_kind, target_id AS origin_id, NULL AS chance,
        target_kind AS source_kind
      FROM quest_target WHERE target_kind <> 'IR'
      UNION
      -- Item requirements encode a direct source in pfQuest's database.
      SELECT q.quest_id, q.phase, ir.source_kind, ir.source_id, q.target_kind, q.target_id, NULL AS chance,
        ir.source_kind AS source_kind
      FROM quest_target q JOIN item_requirement ir
        ON q.target_kind = 'IR' AND ir.item_id = q.target_id
      UNION
      -- Normal item objectives need direct and reference-loot sources.
      SELECT q.quest_id, q.phase, CASE WHEN s.source_kind = 'V' THEN 'U' ELSE s.source_kind END, s.source_id,
        q.target_kind, q.target_id, s.chance, s.source_kind
      FROM quest_target q JOIN item_source s
        ON q.target_kind = 'I' AND s.item_id = q.target_id
      WHERE s.source_kind IN ('U', 'O', 'V')
      UNION
      SELECT q.quest_id, q.phase, CASE WHEN r.source_kind = 'V' THEN 'U' ELSE r.source_kind END, r.source_id,
        q.target_kind, q.target_id, s.chance, r.source_kind
      FROM quest_target q JOIN item_source s
        ON q.target_kind = 'I' AND s.item_id = q.target_id AND s.source_kind = 'R'
      JOIN refloot_source r ON r.reference_id = s.source_id
    )
    SELECT q.phase, q.target_kind, q.target_id, q.origin_kind, q.origin_id, q.chance, q.source_kind,
      COALESCE(em.level, 'N/A'), em.rank,
      COALESCE(s.x, a.x, z.x), COALESCE(s.y, a.y, z.y),
      COALESCE(s.zone_id, a.zone_id, z.map_id), COALESCE(s.respawn, '0'),
      COALESCE(e.title, zt.title,
        CASE WHEN q.target_kind = 'A' THEN 'Exploration Trigger ' || q.target_id END),
      it.title,
      (SELECT GROUP_CONCAT(shared_e.title, '|')
        FROM spawn shared_s
        JOIN entity_text shared_e ON shared_e.target_kind = 'U'
          AND shared_e.target_id = shared_s.target_id
          AND shared_e.locale = ']] .. CurrentLocale() .. [['
        WHERE q.target_kind = 'U'
          AND shared_s.target_kind = 'U'
          AND shared_s.zone_id = s.zone_id
          AND shared_s.x = s.x AND shared_s.y = s.y
          AND shared_s.target_id <> q.target_id) AS shared_titles,
      (SELECT GROUP_CONCAT(objective_e.title, '|')
        FROM quest_target objective_q
        JOIN entity_text objective_e
          ON objective_e.target_kind = objective_q.target_kind
          AND objective_e.target_id = objective_q.target_id
          AND objective_e.locale = ']] .. CurrentLocale() .. [['
        WHERE q.origin_kind = 'IR'
          AND objective_q.quest_id = q.quest_id
          AND objective_q.phase = 'obj'
          AND objective_q.target_kind IN ('U', 'O')
          AND objective_q.target_id <> q.target_id) AS related_objective_titles, em.faction
    FROM resolved_target q
    LEFT JOIN spawn s ON s.target_kind = q.target_kind AND s.target_id = q.target_id
    LEFT JOIN areatrigger_spawn a ON q.target_kind = 'A' AND a.trigger_id = q.target_id
    LEFT JOIN zone_data z ON q.target_kind = 'Z' AND z.zone_id = q.target_id
    LEFT JOIN entity_meta em ON em.target_kind = q.target_kind AND em.target_id = q.target_id
    LEFT JOIN entity_text e ON e.target_kind = q.target_kind AND e.target_id = q.target_id
      AND e.locale = ']] .. CurrentLocale() .. [['
    LEFT JOIN item_text it ON (q.origin_kind = 'I' OR q.origin_kind = 'IR')
      AND it.item_id = q.origin_id AND it.locale = ']] .. CurrentLocale() .. [['
    LEFT JOIN zone_text zt ON q.target_kind = 'Z' AND zt.zone_id = q.target_id
      AND zt.locale = ']] .. CurrentLocale() .. [['
    WHERE q.quest_id = ]] .. id


  -- Ordinary DLL: page native results. Experimental DLL: one SQL execution,
  -- with native conversion and Lua decoding still bounded across frames.
  -- Freeze this SQL order for the complete page chain: changing OFFSET order
  -- mid-request would duplicate or omit rows if the player changes zones.
  local localMap = pfMap and pfMap.GetPlayerMapID and pfMap:GetPlayerMapID()
  local regionOrder = limit <= 0 and pfMap and pfMap.GetHDBRegionOrderSQL
    and pfMap:GetHDBRegionOrderSQL() or ""
  sql = sql .. " ORDER BY " .. regionOrder .. "1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18"
  local records, offset, finished = {}, 0, false
  -- A positive LIMIT is only a prefix and must not publish a complete summary.
  local objectives = limit <= 0 and {} or nil
  local objectiveSeen = objectives and {} or nil
  pending.records = records
  local generation = targetDecodeGeneration
  local SubmitPage
  local function Fail(message)
    if finished then return end
    finished = true
    Complete(nil, message)
  end
  SubmitPage = function()
    if finished then return nil end
    local pageSize = limit > 0 and math.min(512, limit - offset) or 512
    local pageSQL = sql
    if singleQueryTargets then
      if limit > 0 then pageSQL = sql .. " LIMIT " .. limit end
    else
      pageSQL = sql .. " LIMIT " .. pageSize .. " OFFSET " .. offset
    end
    local ok, ticket = pcall(HDB_QueryRawAsync, handle, pageSQL, function(columns, rows, err)
      if err then
        HDB_ClearPoison(handle)
        Fail(err)
        return
      end

      local index, pageRecords = 1, {}
      local localPrefix = localMap and rows and rows[1] and tonumber(rows[1][12]) == localMap
      local function LocalPriority()
        return localMap and rows and rows[index] and tonumber(rows[index][12]) == localMap
      end
      if generation ~= targetDecodeGeneration then Fail("database cache changed during paged query") return end
      local count = table.getn(rows or {})
      local function EmitProgress()
        local ready = pageRecords
        pageRecords = {}
        for _, progress in ipairs(pending.progress) do
          local ok, message
          if type(provider.profileDecodedCallback) == "function" then
            ok, message = pcall(provider.profileDecodedCallback, "target preview", progress, ready)
          else ok, message = pcall(progress, ready) end
          if not ok and type(geterrorhandler) == "function" then geterrorhandler()(message) end
        end
      end
      local function DecodeBatch()
        if generation ~= targetDecodeGeneration then
          Fail("database cache changed during target decode")
          return true
        end
        local last = math.min(index + 31, count)
        if type(provider.profileDecodePhase) == "function" then provider.profileDecodePhase("rows-begin", id, index, last, count) end
        for index = index, last do
        local row = rows[index]
        local sharedSpawns
        if row[16] and row[16] ~= "" then
          sharedSpawns = {}
          for title in string.gfind(row[16], "[^|]+") do sharedSpawns[title] = true end
        end
        local relatedObjectives = RelatedObjectiveSet(row[17])
        -- Consume the raw row in place instead of allocating a second table.
        -- Capture fields before clearing positional cells; callers still receive
        -- the same ordinary named-field record, with independent mutable sets.
        local v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14, v15, v16, v17, v18 = row[1], row[2], row[3], row[4], row[5], row[6], row[7], row[8], row[9], row[10], row[11], row[12], row[13], row[14], row[15], row[16], row[17], row[18]
        for column = 1, 18 do row[column] = nil end
        row.phase = v1
        row.targetKind = v2
        row.targetID = tonumber(v3)
        row.originKind = v4
        row.originID = tonumber(v5)
        row.chance = tonumber(v6)
        row.sourceKind = v7
        row.level = v8
        row.rank = v9
        row.faction = v18
        row.x = tonumber(v10)
        row.y = tonumber(v11)
        row.zoneID = tonumber(v12)
        row.respawn = tonumber(v13)
        row.title = v14
        row.itemTitle = v15
        row.sharedSpawns = sharedSpawns
        row.relatedObjectives = relatedObjectives
        table.insert(records, row)
        local record = records[table.getn(records)]
        if objectives and record.phase == "obj" and (record.targetKind == "U" or record.targetKind == "O") and record.title then
          -- Titles are keyed uniquely by locale/kind/id in the database.
          local identity = v2 .. ":" .. v3 .. ":" .. v4 .. ":" .. v5
          if not objectiveSeen[identity] then
            objectiveSeen[identity] = true
            table.insert(objectives, {phase = record.phase, targetKind = record.targetKind,
              targetID = record.targetID, originKind = record.originKind, originID = record.originID,
              title = record.title, itemTitle = record.itemTitle})
          end
        end
        table.insert(pageRecords, record)
        rows[index] = nil -- normalized record now owns every needed field
        end
        if type(provider.profileDecodePhase) == "function" then provider.profileDecodePhase("rows-end", id, index, last, count) end
        index = last + 1
        -- Preserve progressive region-ordered previews without an 11000-row
        -- progress callback at the end of the single-query decode.
        -- Flush a short local prefix before spending turns on distant rows.
        -- A decode slice may include up to31 rows beyond the zone boundary.
        if singleQueryTargets and index <= count and
          (table.getn(pageRecords) >= 512 or (localPrefix and not LocalPriority())) then
          EmitProgress()
        end
        if localPrefix and not LocalPriority() then localPrefix = false end
        if generation ~= targetDecodeGeneration then Fail("database cache changed during target progress") return true end
        if index <= count then return false end
        offset = offset + count
        EmitProgress()
        if generation ~= targetDecodeGeneration then Fail("database cache changed during target progress") return true end
        if not singleQueryTargets and count == pageSize and (limit <= 0 or offset < limit) then SubmitPage() return true end
        finished = true
        questTargetCache[cacheKey] = records
        if objectives then questObjectiveCache[cacheKey] = objectives end
        if type(provider.profileDecodedCallback) == "function" then
          provider.profileDecodedCallback("target completion", Complete, records)
        else Complete(records, nil) end
        return true
      end
      if count > 32 then QueueTargetDecode(DecodeBatch, id, LocalPriority, "quest targets q" .. id)
      else DecodeBatch() end
    end)
    if not ok or not ticket then
      Fail("could not submit target query")
      return nil
    end
    return ticket
  end
  return SubmitPage()
end

-- Resolve the quest-log Show destination without materializing every objective
-- pin. Direct enders win over starters, matching the legacy Lua-table lookup.
function provider:GetQuestHubMapAsync(id, callback)
  local handle = Open()
  id = math.floor(tonumber(id) or 0)
  if not handle or id <= 0 then
    if callback then callback(nil, "HearthDB is unavailable or quest id is invalid") end
    return nil
  end
  local sql = [[SELECT q.phase, s.zone_id, COUNT(*)
    FROM quest_target q
    JOIN spawn s ON s.target_kind = q.target_kind AND s.target_id = q.target_id
    WHERE q.quest_id = ]] .. id .. [[
      AND q.phase IN ('start', 'end')
      AND q.target_kind IN ('U', 'O')
      AND s.zone_id > 0
    GROUP BY q.phase, s.zone_id
    ORDER BY CASE q.phase WHEN 'end' THEN 0 ELSE 1 END, COUNT(*) DESC, s.zone_id ASC]]
  local ok, ticket = pcall(HDB_QueryRawAsync, handle, sql, function(columns, rows, err)
    if err then
      HDB_ClearPoison(handle)
      if callback then callback(nil, err) end
      return
    end
    local row = rows and rows[1]
    if callback then callback(row and tonumber(row[2]) or nil, nil) end
  end)
  if not ok or not ticket then
    if callback then callback(nil, "could not submit quest hub query") end
    return nil
  end
  return ticket
end

-- Public provider boundary for a future vanilla pfQuest-HDB edition. It owns
-- the asynchronous lookup and returns only map-ready records, so consumers do
-- not need to know about SQLite rows, item source expansion, or cache keys.
function provider:GetQuestMapPinsAsync(id, callback, limit, onPage)
  id = tonumber(id)
  if not id then
    if callback then callback(nil, "quest id is invalid") end
    return nil
  end
  limit = math.floor(tonumber(limit) or 0)
  local cacheKey = CacheKey(id, limit > 0 and limit or nil)
  if questMapPinCache[cacheKey] then
    if callback then callback(questMapPinCache[cacheKey], nil) end
    return true
  end

  return self:GetQuestTextAsync(id, function(quest, textErr)
    if textErr or not quest then
      if callback then callback(nil, textErr or "quest was not found") end
      return
    end
    self:GetQuestTargetsAsync(id, function(records, targetErr)
      if targetErr then
        if callback then callback(nil, targetErr) end
        return
      end
      if questMapPinCache[cacheKey] then
        if callback then callback(questMapPinCache[cacheKey], nil) end
        return
      end
      local result = {
        id = id, title = quest.title, objective = quest.objective, description = quest.description,
        level = quest.level, minLevel = quest.minLevel, pins = {}, hasObjectives = false,
      }
      for index = 1, table.getn(records or {}) do
        local row = records[index]
        if row.phase == "obj" then result.hasObjectives = true end
        if row.zoneID and row.x and row.y then
          -- Cached target records already contain the complete pin metadata.
          -- Share them instead of allocating a second table for every spawn.
          row.title = row.title or (row.targetKind .. " " .. row.targetID)
          table.insert(result.pins, row)
        end
      end
      questMapPinCache[cacheKey] = result
      if callback then callback(result, nil) end
    end, limit, onPage and function(records)
      local result = {
        id = id, title = quest.title, objective = quest.objective, description = quest.description,
        level = quest.level, minLevel = quest.minLevel, pins = {}, hasObjectives = false, partial = true,
      }
      for _, row in ipairs(records or {}) do
        if row.phase == "obj" then result.hasObjectives = true end
        if row.zoneID and row.x and row.y then
          row.title = row.title or (row.targetKind .. " " .. row.targetID)
          table.insert(result.pins, row)
        end
      end
      if table.getn(result.pins) > 0 then onPage(result) end
    end or nil)
  end)
end

SLASH_PFQUESTHDB1 = "/pfqhdb"
SlashCmdList.PFQUESTHDB = function(input)
  local command = string.lower(tostring(input or ""))
  if command == "cacheclear" then
    ClearCache()
    Print("HDB query cache cleared.")
  else
    Print("addon=pfQuest-turtle HearthDB=" .. tostring(Available()) .. ", open=" .. tostring(dbHandle ~= nil)
      .. ", targets=" .. provider.targetDeliveryMode .. ". Use /pfqhdb cacheclear to clear query caches.")
  end
end

-- Keep the broad indexes behind the active log's small on-demand identity
-- lookups. Otherwise native delivery of preload pages delays every active ID.
local startupPreloadDeadline, startupPreloadSettledAt, startupPreloadTick
provider.startupPreloadState = "waiting-world"
addon:RegisterEvent("PLAYER_LOGIN")
addon:RegisterEvent("PLAYER_ENTERING_WORLD")
addon:RegisterEvent("PLAYER_LOGOUT")
addon:SetScript("OnEvent", function()
  if event == "PLAYER_LOGOUT" then
    startupPreloadDeadline = nil
    Close()
  elseif event == "PLAYER_LOGIN" then
    Open()
  elseif not startupPreloadDeadline and provider.startupPreloadState == "waiting-world" then
    startupPreloadDeadline = GetTime() + 15
    provider.startupPreloadState = "waiting-identities"
  end
end)
addon:SetScript("OnUpdate", function()
  if not startupPreloadDeadline or shuttingDown then return end
  local now = GetTime()
  if (startupPreloadTick or 0) > now then return end
  startupPreloadTick = now + 0.25
  local route = pfQuest and pfQuest.route
  local point = route and route.coords and route.coords[1]
  local routeReady = point and point[4] and not route.targetMissing
  local resolved, unresolved = 0, false
  for id in pairs(pfQuest and pfQuest.questlog or {}) do
    if type(id) == "number" then resolved = resolved + 1 else unresolved = true end
  end
  local _, count = GetNumQuestLogEntries()
  local settled = pfQuest and pfDatabase and pfDatabase.localized and not unresolved
    and count ~= nil and resolved == count and (pfQuest.queueCount or 0) == 0
    and not pfQuest.updateQuestLog
  if settled then
    startupPreloadSettledAt = startupPreloadSettledAt or now
  else startupPreloadSettledAt = nil end
  local ready = routeReady or (startupPreloadSettledAt and now >= startupPreloadSettledAt + 1)
  if not ready and now < startupPreloadDeadline then return end
  provider.startupPreloadState = ready and "started-after-active-quests" or "started-after-timeout"
  provider.startupPreloadStartedAt = now
  startupPreloadDeadline = nil
  provider:PreloadQuestTitleIDsAsync()
  provider:PreloadQuestDisambiguationAsync()
end)

if pfQuestHDBCompat then
  pfQuestHDBCompat:RegisterProvider(provider, SlashCmdList.PFQUESTHDB)
else
  pfQuestHearthDB = provider
end
