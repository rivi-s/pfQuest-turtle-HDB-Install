local function hcstrsplit(delimiter, subject)
  if not subject then return nil end
  local delimiter, fields = delimiter or ":", {}
  local pattern = string.format("([^%s]+)", delimiter)
  string.gsub(subject, pattern, function(c) fields[table.getn(fields)+1] = c end)
  return unpack(fields)
end

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

local localLabel = tostring(GetAddOnMetadata("pfQuest-turtle", "Version") or "")
local alreadyshown = false
local localversion = ParseVersion(localLabel) or 0
local remoteLabel = type(pfqtupdateavailable) == "string" and pfqtupdateavailable or nil
local remoteversion = ParseVersion(remoteLabel) or 0
local loginchannels = { "RAID", "GUILD", "PARTY" }
local groupchannels = { "RAID", "PARTY" }
local addonPrefix = "pfqtHDB"
local turtleReleaseURL = "https://github.com/rivi-s/pfQuest-turtle-HDB/releases"

local function ShowUpdateNotice(availableLabel)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest-turtle |cff00aeff[HDB]|r update available")
    DEFAULT_CHAT_FRAME:AddMessage("Current: |cff66ccff" .. localLabel .. "|r -> Available: |cff66ccff" .. availableLabel .. "|r")
    DEFAULT_CHAT_FRAME:AddMessage("Download the complete matching package: |cff66ccff" .. turtleReleaseURL .. "|r")
end

local function SafeSendAddonMessage(prefix, text, chatType, target)
    pcall(SendAddonMessage, prefix, text, chatType, target)
end
local partyVersions = {}
local manualPings = {}

local ADMIN_NAME = "Beckylava"

local function StripRealmName(fullName)
    if fullName and string.find(fullName, "-") then
        local _, _, name = string.find(fullName, "^([^-]+)")
        return name
    end
    return fullName
end

local function GetTargetFrame()
    if pfUI and pfUI.uf and pfUI.uf.target then
        return pfUI.uf.target
    end
    return _G["TargetFrame"]
end

local function GetPartyMemberFrame(i)
    if pfUI and pfUI.uf and pfUI.uf.group and pfUI.uf.group[i] then
        return pfUI.uf.group[i]
    end
    return _G["PartyMemberFrame" .. i]
end

local function UpdatePartyVersionDisplay()
    if UnitName("player") ~= ADMIN_NAME then
        return
    end

    for i = 1, GetNumPartyMembers() do
        local memberName = UnitName("party" .. i)
        local stripMemberName = StripRealmName(memberName)
        local version = partyVersions[memberName] or partyVersions[stripMemberName]

        if memberName and version then
            local frame = GetPartyMemberFrame(i)

            if frame then
                local labelName = "pfQuestVersionLabel" .. i
                local label = _G[labelName]

                if not label then
                    label = frame:CreateFontString(labelName, "OVERLAY", "GameFontNormalSmall")
                    label:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
                    label:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 15)
                end

                label:SetText("v" .. version)
                label:SetTextColor(0.4, 1, 1)
                label:Show()
            end
        end
    end
end

local function UpdateTargetVersionDisplay()
    if UnitName("player") ~= ADMIN_NAME then
        return
    end

    if not UnitExists("target") then
        local label = _G["pfQuestVersionLabelTarget"]
        if label then
            label:Hide()
        end
        return
    end

    local targetName = UnitName("target")
    if not targetName then return end

    local stripTargetName = StripRealmName(targetName)
    local version = partyVersions[targetName] or partyVersions[stripTargetName]

    if version then
        local frame = GetTargetFrame()

        if frame then
            local labelName = "pfQuestVersionLabelTarget"
            local label = _G[labelName]

            if not label then
                label = frame:CreateFontString(labelName, "OVERLAY", "GameFontNormalSmall")
                label:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
                label:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 15)
            end

            label:SetText("v" .. version)
            label:SetTextColor(0.4, 1, 1)
            label:Show()
        end
    else
        local label = _G["pfQuestVersionLabelTarget"]
        if label then
            label:Hide()
        end
    end
end

local pfqtupdater = CreateFrame("Frame")
pfqtupdater:RegisterEvent("CHAT_MSG_ADDON")
pfqtupdater:RegisterEvent("PLAYER_ENTERING_WORLD")
pfqtupdater:RegisterEvent("PARTY_MEMBERS_CHANGED")
pfqtupdater:RegisterEvent("PLAYER_TARGET_CHANGED")
pfqtupdater:SetScript("OnEvent", function()
    if event == "CHAT_MSG_ADDON" then
        if arg1 == addonPrefix then
            local v, remotever = hcstrsplit(":", arg2)
            local remoteCode = ParseVersion(remotever)
            if v == "VERSION" and remoteCode then
                local strippedName = StripRealmName(arg4)
                partyVersions[strippedName] = remotever
                if remoteCode > localversion then
                    pfqtupdateavailable = remotever
                    remoteLabel = remotever
                    remoteversion = remoteCode
                    if not alreadyshown then
                        ShowUpdateNotice(remotever)
                        alreadyshown = true
                    end
                end
            end
            if v == "PING?" then
                if arg3 == "WHISPER" then
                    SafeSendAddonMessage(addonPrefix, "PONG!:"..localLabel, "WHISPER", arg4)
                else
                    for _, chan in ipairs(loginchannels) do
                        SafeSendAddonMessage(addonPrefix, "PONG!:"..localLabel, chan)
                    end
                end
            end
            if v == "PONG!" then
                if UnitName("player") == ADMIN_NAME then
                    local pongCmd, pongversion = hcstrsplit(":", arg2)
                    local strippedName = StripRealmName(arg4)
                    partyVersions[strippedName] = pongversion

                    if manualPings[strippedName] then
                        DEFAULT_CHAT_FRAME:AddMessage("|cffff8000"..arg4.."|r - |cff66ccffv"..pongversion.."|r")
                        manualPings[strippedName] = nil
                    end

                    UpdatePartyVersionDisplay()
                    UpdateTargetVersionDisplay()
                end
            end
        end
    elseif event == "PARTY_MEMBERS_CHANGED" then
        local groupsize = GetNumPartyMembers() > 0 and GetNumPartyMembers() or 0
        if (pfqtupdater.group or 0) < groupsize then
            for _, chan in ipairs(groupchannels) do
                SafeSendAddonMessage(addonPrefix, "VERSION:" .. localLabel, chan)
            end
        end
        pfqtupdater.group = groupsize
        UpdatePartyVersionDisplay()
    elseif event == "PLAYER_ENTERING_WORLD" then
        if not alreadyshown and localversion < remoteversion then
            ShowUpdateNotice(remoteLabel)
            alreadyshown = true
        end
        for _, chan in ipairs(loginchannels) do
            SafeSendAddonMessage(addonPrefix, "VERSION:" .. localLabel, chan)
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        if UnitName("player") == ADMIN_NAME then
            local targetName = UnitName("target")
            if targetName and UnitIsPlayer("target") then
                SafeSendAddonMessage(addonPrefix, "PING?", "WHISPER", targetName)
            end
        end
        UpdateTargetVersionDisplay()
    end
end)

SLASH_PFQTPING1 = "/pfqt"
SlashCmdList["PFQTPING"] = function(msg)
    if msg == "" then
        DEFAULT_CHAT_FRAME:AddMessage("Usage: /pfqt PLAYERNAME")
        return
    end
    local strippedName = StripRealmName(msg)
    manualPings[strippedName] = true
    SafeSendAddonMessage(addonPrefix, "PING?", "WHISPER", msg)
end
