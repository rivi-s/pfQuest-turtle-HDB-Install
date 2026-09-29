-- Turtle's hand-maintained database corrections are applied by the HearthDB
-- exporter and stored in SQLite. No large runtime database tables exist here.

-- Quest: Vile Dwarven Pigs (41682)
-- The gossip-driven keg objective is absent from the extracted quest row.
local turtleQuests = pfDB["quests"] and pfDB["quests"]["data-turtle"]
local turtleUnits = pfDB["units"] and pfDB["units"]["data-turtle"]

-- The Mallet of Zeth is used on the Gong of Corthan for The Land of Kings.
local turtleItemRequirements = pfDB["quests-itemreq"] and pfDB["quests-itemreq"]["data-turtle"]
if turtleItemRequirements then
  turtleItemRequirements[60944] = { [-2010946] = 0 }
end

-- Kex Blowmaster and his Horde quest chain were removed from the game.
if turtleUnits then turtleUnits[60443] = "_" end

-- "Stinky" Ignatz and both faction variants of his escort quest were removed.
if turtleUnits then turtleUnits[4880] = "_" end

-- Interacting with the Mysterious Glittering Object summons Kheyna
-- Spinpistol, who completes A Letter From a Friend and offers the follow-up.
if turtleUnits and turtleUnits[81041] then
  turtleUnits[81041]["coords"] = { { 48.2, 23.4, 440, 300 } }
end

if turtleQuests then
  turtleQuests[1222] = "_"
  turtleQuests[1270] = "_"

  if turtleQuests[1265] then
    turtleQuests[1265]["obj"] = { ["A"] = { 1667 } }
    turtleQuests[1265]["end"] = { ["A"] = { 1667 } }
  end

  -- Turtle's extracted overrides replace complete vanilla quest rows. Restore
  -- vanilla prerequisite chains that the overrides omitted, while retaining
  -- Turtle-specific faction, objective, and endpoint changes.
  local inheritedPrerequisites = {
    [95] = { 164 }, [138] = { 136 }, [139] = { 138 }, [140] = { 139 },
    [364] = { 363 }, [597] = { 595 }, [625] = { 624 }, [626] = { 625 },
    [902] = { 901 }, [960] = { 944 }, [1130] = { 882 }, [1194] = { 1190 },
    [1801] = { 2996, 3001 }, [2701] = { 2702 }, [3454] = { 3453 },
    [3525] = { 3523 }, [3792] = { 3791 }, [3913] = { 3912 },
    [3914] = { 3913 }, [4122] = { 4082 }, [5050] = { 5048, 5049 },
    [5084] = { 5083 }, [5085] = { 5084 }, [5143] = { 2853 },
    [5148] = { 2860 }, [5164] = { 5162 }, [5265] = { 5264 },
    [5463] = { 5462 }, [5464] = { 5463 }, [5942] = { 5721 },
    [6383] = { 235, 742, 6382 }, [7508] = { 7507 }, [7668] = { 7667 },
    [7795] = { 7791, 7793, 7794 }, [7800] = { 7792, 7798, 7799 },
    [7805] = { 7802, 7803, 7804 }, [7811] = { 7807, 7808, 7809 },
    [7818] = { 7813, 7814, 7817 }, [7823] = { 7820, 7821, 7822 },
    [7824] = { 7826, 7827, 7831 }, [7836] = { 7833, 7834, 7835 },
    [8115] = { 8114 }, [8122] = { 8121 }, [8271] = { 7141 },
    [8272] = { 7142 }, [8484] = { 8481 }, [8485] = { 8481 },
    [8811] = { 8795 }, [8812] = { 8795 }, [8813] = { 8795 },
    [8814] = { 8795 }, [8815] = { 8792 }, [8816] = { 8792 },
    [8817] = { 8792 }, [8818] = { 8792 }, [8819] = { 8795 },
    [8820] = { 8795 }, [8821] = { 8795 }, [8822] = { 8795 },
    [8823] = { 8792 }, [8824] = { 8792 }, [8825] = { 8792 },
    [8826] = { 8792 },
  }
  for questID, prerequisites in pairs(inheritedPrerequisites) do
    if turtleQuests[questID] then turtleQuests[questID]["pre"] = prerequisites end
  end

  if turtleQuests[1288] then
    turtleQuests[1288]["pre"] = { 1287 }
  end

  if turtleQuests[40713] and turtleQuests[40713]["obj"] then
    turtleQuests[40713]["obj"]["IR"] = { 60944 }
  end

  if turtleQuests[80407] then
    turtleQuests[80407]["obj"] = { ["O"] = { 3000246 } }
  end

  for _, questID in pairs({ 40130, 40131, 40133, 41102, 41104 }) do
    turtleQuests[questID] = "_"
  end
end

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
for _, questID in pairs({ 42054, 42055, 42056, 42057, 42058, 42059, 42060 }) do
  if turtleQuests and turtleQuests[questID] then
    turtleQuests[questID]["class"] = 16
  end
end

-- Tainted Rune is the Dwarf Warlock introduction.
if turtleQuests and turtleQuests[42045] then
  turtleQuests[42045]["class"] = 256
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
-- The alpha.6 value here (1.0, i.e. 1%) was itself wrong; pfQuest-turtle's
-- 1.0.19 changelog documents the correct, verified rate as 100%. items-turtle.lua
-- already stores 100 directly, so this override now only needs to preserve
-- that value against a re-extraction, not reintroduce the old 1%.
local turtleItems = pfDB["items"] and pfDB["items"]["data-turtle"]
if turtleItems and turtleItems[41783] then
  turtleItems[41783]["U"] = { [62217] = 100 }
end

-- Quest interaction items whose extracted rows have no acquisition source.
if turtleItems and turtleItems[41695] then
  turtleItems[41695]["U"] = { [62490] = 100 }
end

if turtleItems and turtleItems[41737] then
  turtleItems[41737]["U"] = { [62146] = 100 }
end

-- Reports of Dustwallow: Sentry Point Report comes from Captain Wallace
-- Cross, and North Point Report comes from Captain Harker.
if turtleItems and turtleItems[60602] then
  turtleItems[60602]["U"] = { [60729] = 100 }
end

if turtleItems and turtleItems[60603] then
  turtleItems[60603]["U"] = { [60730] = 100 }
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
