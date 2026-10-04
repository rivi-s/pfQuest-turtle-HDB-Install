-- Old provider addons can survive ZIP extraction or custom Git updates.
-- Keep them from opening another database or replacing the embedded API.
pfQuestHDBCompat = {}
local compat = pfQuestHDBCompat
local owner, slashHandler
local nativeOpen = HDB_OpenAddon
local legacyNames = { ["pfQuest-HearthDB"] = true, ["pfQuest-HearthDB-turtle"] = true }
if type(nativeOpen) == "function" then
  HDB_OpenAddon = function(name, path)
    if legacyNames[name] then return nil end
    return nativeOpen(name, path)
  end
end

local function RestoreProvider()
  if not owner then return end
  pfQuestHearthDB = owner
  if slashHandler then SlashCmdList.PFQUESTHDB = slashHandler end
end

function compat:RegisterProvider(provider, handler)
  owner, slashHandler = provider, handler
  RestoreProvider()
end

local guard = CreateFrame("Frame")
guard:RegisterEvent("ADDON_LOADED")
guard:RegisterEvent("PLAYER_LOGIN")
guard:SetScript("OnEvent", RestoreProvider)
