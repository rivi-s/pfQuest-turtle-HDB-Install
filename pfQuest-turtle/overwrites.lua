-- Turtle's hand-maintained database corrections are applied by the HearthDB
-- exporter and stored in SQLite. No large runtime database tables exist here.

-- Quest: Vile Dwarven Pigs (41682)
-- The gossip-driven keg objective is absent from the extracted quest row.
local turtleQuests = pfDB["quests"] and pfDB["quests"]["data-turtle"]

-- Shaman chain: Windtorn Crest Stone -> Vortalus' Edict.
-- The extracted rows omitted the class restriction and Vortalus objective.
if turtleQuests and turtleQuests[41938] then
  turtleQuests[41938]["class"] = 64
end

if turtleQuests and turtleQuests[41939] then
  turtleQuests[41939]["class"] = 64
  turtleQuests[41939]["obj"] = turtleQuests[41939]["obj"] or {}
  turtleQuests[41939]["obj"]["U"] = { 62783 }
end

-- Windhorn Canyon relic quests use the same missing world-object target.
for _, questID in pairs({ 41976, 41977 }) do
  if turtleQuests and turtleQuests[questID] then
    turtleQuests[questID]["obj"] = turtleQuests[questID]["obj"] or {}
    turtleQuests[questID]["obj"]["O"] = { 2020320 }
  end
end

-- Tauren priest quests whose extracted rows lost their class restriction.
for _, questID in pairs({ 42058, 42060 }) do
  if turtleQuests and turtleQuests[questID] then
    turtleQuests[questID]["class"] = 16
  end
end
local vileDwarvenPigs = turtleQuests and turtleQuests[41682]
if vileDwarvenPigs then
  vileDwarvenPigs["obj"] = vileDwarvenPigs["obj"] or {}
  vileDwarvenPigs["obj"]["O"] = { 2020173 }
end

-- Quest: School Assistance (41637)
-- The extracted objectives point at internal script triggers instead of the
-- four children the player must speak with in Ambershire Church.
local schoolAssistance = turtleQuests and turtleQuests[41637]
if schoolAssistance then
  schoolAssistance["obj"] = schoolAssistance["obj"] or {}
  schoolAssistance["obj"]["U"] = { 62300, 62301, 62302, 62303 }
end

-- Quest: Empty Houses (41643)
-- Replace the script triggers with the three residents used for progress.
local emptyHouses = turtleQuests and turtleQuests[41643]
if emptyHouses then
  emptyHouses["obj"] = emptyHouses["obj"] or {}
  emptyHouses["obj"]["U"] = { 62154, 62489, 62153 }
end

-- Quest: Darker than Iron (41677)
-- The keg interaction is the same world-object objective used by quest 41682.
local darkerThanIron = turtleQuests and turtleQuests[41677]
if darkerThanIron then
  darkerThanIron["obj"] = darkerThanIron["obj"] or {}
  darkerThanIron["obj"]["O"] = { 2020173 }
end

-- Item: Head of Geshgan (41783)
-- Preserve the known-good Turtle source chance used by alpha.6.
local turtleItems = pfDB["items"] and pfDB["items"]["data-turtle"]
if turtleItems and turtleItems[41783] then
  turtleItems[41783]["U"] = { [62217] = 1.0 }
end

-- Quest interaction items whose extracted rows have no acquisition source.
if turtleItems and turtleItems[41695] then
  turtleItems[41695]["U"] = { [62490] = 100 }
end

if turtleItems and turtleItems[41737] then
  turtleItems[41737]["U"] = { [62146] = 100 }
end

-- Windtorn Crest Stone is guaranteed from Razorgust.
if turtleItems and turtleItems[42206] then
  turtleItems[42206]["U"] = { [62195] = 100 }
end

-- Sorrowguard Keep is drawn inside both the Deadwind Pass and Swamp of
-- Sorrows map rectangles. Turtle reports Swamp of Sorrows while the player is
-- inside the keep, but the extracted NPC records only contain Deadwind Pass
-- coordinates. Mirror the keep cluster through the shared world coordinates
-- so quest starters and enders render on either map.
local turtleUnits = pfDB["units"] and pfDB["units"]["data-turtle"]

-- Farseer Greka's extracted Stonetalon position is offset from her in-game
-- location at Wind Shear Crag.
if turtleUnits and turtleUnits[62197] then
  turtleUnits[62197]["coords"] = { { 48.4, 68.9, 406, 120 } }
end

-- Correct Razorgust's spawn at Windtorn Crest.
if turtleUnits and turtleUnits[62195] then
  turtleUnits[62195]["coords"] = { { 29.5, 18.5, 406, 120 } }
end

-- Renegade Air Elementals moved with the Windtorn Crest redesign. Replace
-- the obsolete southern cluster with player-surveyed spawns in the pass.
if turtleUnits and turtleUnits[62194] then
  turtleUnits[62194]["coords"] = {
    { 34.4, 18.4, 406, 120 },
    { 34.8, 17.0, 406, 120 },
    { 33.8, 18.6, 406, 120 },
    { 32.7, 17.9, 406, 120 },
    { 31.9, 17.5, 406, 120 },
    { 31.8, 16.5, 406, 120 },
    { 31.1, 16.4, 406, 120 },
    { 30.8, 17.7, 406, 120 },
    { 31.5, 18.5, 406, 120 },
    { 30.4, 18.2, 406, 120 },
    { 30.3, 16.7, 406, 120 },
    { 29.6, 16.1, 406, 120 },
    { 28.9, 15.6, 406, 120 },
    { 28.9, 17.0, 406, 120 },
  }
end
local sorrowguardSwampCoords = {
  [92012] = { 1.98, 52.81 },
  [92013] = { 2.85, 48.34 },
  [92014] = { 1.54, 50.74 },
  [92015] = { 3.51, 50.84 },
  [92016] = { 2.96, 48.99 },
  [92017] = { 2.42, 50.63 },
  [92018] = { 1.54, 50.30 },
  [92019] = { 0.89, 49.43 },
  [92020] = { 1.54, 49.97 },
  [92021] = { 1.98, 52.04 },
  [92022] = { 3.61, 49.65 },
  [92023] = { 3.51, 50.63 },
}

for unitID, position in pairs(sorrowguardSwampCoords) do
  local unit = turtleUnits and turtleUnits[unitID]
  if unit then
    unit["coords"] = unit["coords"] or {}
    local exists = false
    for _, coord in pairs(unit["coords"]) do
      if coord[3] == 8 then exists = true break end
    end
    if not exists then
      table.insert(unit["coords"], { position[1], position[2], 8, 300 })
    end
  end
end
