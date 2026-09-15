local function ParseVersion(label)
  label = tostring(label or "")
  local _, _, major, minor, patch, alpha = string.find(
    label, "^(%d+)%.(%d+)%.(%d+)%-alpha%.(%d+)$"
  )
  if major then
    return tonumber(major) * 100000000
      + tonumber(minor) * 1000000
      + tonumber(patch) * 10000
      + tonumber(alpha)
  end

  _, _, major, minor, patch = string.find(label, "^(%d+)%.(%d+)%.(%d+)$")
  if major then
    return tonumber(major) * 100000000
      + tonumber(minor) * 1000000
      + tonumber(patch) * 10000
      + 9999
  end
end

local function SafeSendAddonMessage(prefix, text, channel)
  pcall(SendAddonMessage, prefix, text, channel)
end

local channels = { "BATTLEGROUND", "RAID", "GUILD", "PARTY" }
local prefix = "pfQuestHDB"
local releaseURL = "https://github.com/rivi-s/pfQuest-HDB/releases"
local localLabel, localVersion, displayed
local versioncheck = CreateFrame("Frame")

versioncheck:RegisterEvent("ADDON_LOADED")
versioncheck:RegisterEvent("CHAT_MSG_ADDON")
versioncheck:RegisterEvent("PARTY_MEMBERS_CHANGED")
versioncheck:RegisterEvent("PLAYER_ENTERING_WORLD")
versioncheck:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" then
    if arg1 == "pfQuest" then
      localLabel = tostring(GetAddOnMetadata(arg1, "Version") or "")
      localVersion = ParseVersion(localLabel)
    end
    return
  elseif event == "CHAT_MSG_ADDON" and arg1 == prefix then
    local _, _, remoteLabel = string.find(tostring(arg2 or ""), "^VERSION:(.+)$")
    local remoteVersion = ParseVersion(remoteLabel)
    if remoteVersion and localVersion and remoteVersion > localVersion then
      local savedVersion = ParseVersion(pfQuest_config.latestHDB)
      if not savedVersion or remoteVersion > savedVersion then
        pfQuest_config.latestHDB = remoteLabel
      end
    end
    return
  elseif event == "CHAT_MSG_ADDON" then
    return
  end

  if not localVersion then return end

  for _, channel in pairs(channels) do
    SafeSendAddonMessage(prefix, "VERSION:" .. localLabel, channel)
  end

  if event == "PARTY_MEMBERS_CHANGED" then return end

  local availableLabel = pfQuest_config.latestHDB
  local availableVersion = ParseVersion(availableLabel)
  if availableVersion and availableVersion > localVersion and not displayed then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest |cff00aeff[HDB]|r update available")
    DEFAULT_CHAT_FRAME:AddMessage(
      "Current: |cff66ccff" .. localLabel .. "|r -> Available: |cff66ccff" .. availableLabel .. "|r"
    )
    DEFAULT_CHAT_FRAME:AddMessage("Download: |cff66ccff" .. releaseURL .. "|r")
    displayed = true
  end
end)
