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

  -- The Black Waltz begins by interacting with Aliattan's Campfire, which
  -- then spawns the Widow event represented by the existing unit objective.
  if turtleQuests[40908] and turtleQuests[40908]["obj"] then
    turtleQuests[40908]["obj"]["O"] = { 2020026 }
  end

  -- The extracted level for Spitecrest Decursions is stale. Turtle's live
  -- quest log reports this step as level 47.
  if turtleQuests[40947] then turtleQuests[40947]["lvl"] = 47 end

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

-- Explicit profession ranks from the Turtle server quest templates.
-- Keep these separate from autogenerated quest records for both Lua and HDB.
pfDB.questProfessionRequirements = {
  [384] = { 185, 1 }, -- Beer Basted Boar Ribs
  [715] = { 171, 1 }, -- Liquid Stone
  [768] = { 393, 1 }, -- Gathering Leather
  [862] = { 185, 1 }, -- Dig Rat Stew
  [866] = { 182, 1 }, -- Root Samples
  [1559] = { 202, 1 }, -- Flash Bomb Recipe
  [1578] = { 164, 35 }, -- Supplying the Front
  [1579] = { 356, 30 }, -- Gaffer Jacks
  [1580] = { 356, 1 }, -- Electropellers
  [1581] = { 171, 20 }, -- Elixirs for the Bladeleafs
  [1582] = { 165, 70 }, -- Moonglow Vest
  [1618] = { 164, 70 }, -- Gearing Redridge
  [2178] = { 185, 10 }, -- Easy Strider Living
  [2203] = { 171, 210 }, -- Badlands Reagent Run II
  [2501] = { 171, 210 }, -- Badlands Reagent Run II
  [2751] = { 164, 140 }, -- Barbaric Battlements
  [2752] = { 164, 1 }, -- On Iron Pauldrons
  [2753] = { 164, 1 }, -- Trampled Under Foot
  [2754] = { 164, 1 }, -- Horns of Frenzy
  [2755] = { 164, 1 }, -- Joys of Omosh
  [2756] = { 164, 210 }, -- The Old Ways
  [2757] = { 164, 210 }, -- Booty Bay or Bust!
  [2758] = { 164, 210 }, -- The Origins of Smithing
  [2759] = { 164, 210 }, -- In Search of Galvan
  [2760] = { 164, 210 }, -- The Mithril Order
  [2761] = { 164, 210 }, -- Smelt On, Smelt Off
  [2762] = { 164, 210 }, -- The Great Silver Deceiver
  [2763] = { 164, 210 }, -- The Art of the Imbue
  [2764] = { 164, 210 }, -- Galvan's Finest Pupil
  [2765] = { 164, 210 }, -- Expert Blacksmith!
  [2771] = { 164, 210 }, -- A Good Head On Your Shoulders
  [2772] = { 164, 210 }, -- The World At Your Feet
  [2773] = { 164, 210 }, -- The Mithril Kid
  [2847] = { 165, 225 }, -- Wild Leather Armor
  [2848] = { 165, 225 }, -- Wild Leather Shoulders
  [2849] = { 165, 225 }, -- Wild Leather Vest
  [2850] = { 165, 225 }, -- Wild Leather Helmet
  [2851] = { 165, 225 }, -- Wild Leather Boots
  [2852] = { 165, 225 }, -- Wild Leather Leggings
  [2853] = { 165, 225 }, -- Master of the Wild Leather
  [2854] = { 165, 225 }, -- Wild Leather Armor
  [2855] = { 165, 225 }, -- Wild Leather Shoulders
  [2856] = { 165, 225 }, -- Wild Leather Vest
  [2857] = { 165, 225 }, -- Wild Leather Helmet
  [2858] = { 165, 225 }, -- Wild Leather Boots
  [2859] = { 165, 225 }, -- Wild Leather Leggings
  [2860] = { 165, 225 }, -- Master of the Wild Leather
  [3321] = { 164, 210 }, -- Did You Lose This?
  [3379] = { 197, 230 }, -- Shadoweaver
  [3385] = { 197, 250 }, -- The Undermarket
  [3402] = { 197, 1 }, -- The Undermarket
  [3526] = { 202, 200 }, -- Goblin Engineering
  [3629] = { 202, 200 }, -- Goblin Engineering
  [3630] = { 202, 200 }, -- Gnome Engineering
  [3632] = { 202, 200 }, -- Gnome Engineering
  [3633] = { 202, 200 }, -- Goblin Engineering
  [3634] = { 202, 200 }, -- Gnome Engineering
  [3635] = { 202, 200 }, -- Gnome Engineering
  [3637] = { 202, 200 }, -- Gnome Engineering
  [3638] = { 202, 200 }, -- The Pledge of Secrecy
  [3639] = { 202, 200 }, -- Show Your Work
  [3640] = { 202, 200 }, -- The Pledge of Secrecy
  [3641] = { 202, 200 }, -- Show Your Work
  [3642] = { 202, 200 }, -- The Pledge of Secrecy
  [3643] = { 202, 200 }, -- Show Your Work
  [3644] = { 202, 200 }, -- Membership Card Renewal
  [3645] = { 202, 200 }, -- Membership Card Renewal
  [3646] = { 202, 200 }, -- Membership Card Renewal
  [3647] = { 202, 200 }, -- Membership Card Renewal
  [4104] = { 186, 1 }, -- Salve via Mining
  [4105] = { 182, 1 }, -- Salve via Gathering
  [4106] = { 393, 1 }, -- Salve via Skinning
  [4107] = { 333, 1 }, -- Salve via Disenchanting
  [4109] = { 186, 1 }, -- Salve via Mining
  [4110] = { 182, 1 }, -- Salve via Gathering
  [4111] = { 393, 1 }, -- Salve via Skinning
  [4112] = { 333, 1 }, -- Salve via Disenchanting
  [4161] = { 185, 1 }, -- Recipe of the Kaldorei
  [4181] = { 202, 200 }, -- Goblin Engineering
  [5103] = { 164, 275 }, -- Hot Fiery Death
  [5126] = { 164, 285 }, -- Lorax's Tale
  [5127] = { 164, 285 }, -- The Demon Forge
  [5141] = { 165, 225 }, -- Dragonscale Leatherworking
  [5143] = { 165, 225 }, -- Tribal Leatherworking
  [5144] = { 165, 225 }, -- Elemental Leatherworking
  [5145] = { 165, 225 }, -- Dragonscale Leatherworking
  [5146] = { 165, 225 }, -- Elemental Leatherworking
  [5148] = { 165, 225 }, -- Tribal Leatherworking
  [5283] = { 164, 200 }, -- The Art of the Armorsmith
  [5284] = { 164, 200 }, -- The Way of the Weaponsmith
  [5301] = { 164, 200 }, -- The Art of the Armorsmith
  [5302] = { 164, 200 }, -- The Way of the Weaponsmith
  [5305] = { 164, 250 }, -- Sweet Serenity
  [5306] = { 164, 250 }, -- Snakestone of the Shadow Huntress
  [5307] = { 164, 250 }, -- Corruption
  [5883] = { 186, 1 }, -- Salve via Mining
  [5884] = { 182, 1 }, -- Salve via Gathering
  [5885] = { 393, 1 }, -- Salve via Skinning
  [5886] = { 333, 1 }, -- Salve via Disenchanting
  [5888] = { 186, 1 }, -- Salve via Mining
  [5889] = { 182, 1 }, -- Salve via Gathering
  [5890] = { 393, 1 }, -- Salve via Skinning
  [5891] = { 333, 1 }, -- Salve via Disenchanting
  [6032] = { 197, 290 }, -- Sacred Cloth
  [6607] = { 356, 225 }, -- Nat Pagle, Angler Extreme
  [6608] = { 356, 225 }, -- You Too Good.
  [6609] = { 356, 225 }, -- I Got Nothin' Left!
  [6610] = { 185, 225 }, -- Clamlette Surprise
  [6611] = { 185, 225 }, -- To Gadgetzan You Go!
  [6612] = { 185, 225 }, -- I Know A Guy...
  [6622] = { 129, 225 }, -- Triage
  [6623] = { 129, 225 }, -- Horde Trauma
  [6624] = { 129, 225 }, -- Triage
  [6625] = { 129, 225 }, -- Alliance Trauma
  [7321] = { 185, 1 }, -- Soothing Turtle Bisque
  [7493] = { 165, 300 }, -- The Journey Has Just Begun
  [7497] = { 165, 300 }, -- The Journey Has Just Begun
  [7649] = { 164, 300 }, -- Enchanted Thorium Platemail: Volume I
  [7650] = { 164, 300 }, -- Enchanted Thorium Platemail: Volume II
  [7651] = { 164, 300 }, -- Enchanted Thorium Platemail: Volume III
  [7652] = { 164, 265 }, -- A Blue Light Bargain
  [7653] = { 164, 265 }, -- Imperial Plate Belt
  [7654] = { 164, 265 }, -- Imperial Plate Boots
  [7655] = { 164, 265 }, -- Imperial Plate Bracer
  [7656] = { 164, 265 }, -- Imperial Plate Chest
  [7657] = { 164, 265 }, -- Imperial Plate Helm
  [7658] = { 164, 265 }, -- Imperial Plate Leggings
  [7659] = { 164, 265 }, -- Imperial Plate Shoulders
  [8193] = { 356, 1 }, -- Master Angler
  [8194] = { 356, 1 }, -- Apprentice Angler
  [8221] = { 356, 1 }, -- Rare Fish - Keefer's Angelfish
  [8224] = { 356, 1 }, -- Rare Fish - Dezian Queenfish
  [8225] = { 356, 1 }, -- Rare Fish - Brownell's Blue Striped Racer
  [8228] = { 356, 175 }, -- Could I get a Fishing Flier?
  [8229] = { 356, 175 }, -- Could I get a Fishing Flier?
  [8307] = { 185, 285 }, -- Desert Recipe
  [8313] = { 185, 285 }, -- Sharing the Knowledge
  [8317] = { 185, 285 }, -- Kitchen Assistance
  [8763] = { 185, 300 }, -- The Hero of the Day
  [8798] = { 202, 1 }, -- A Yeti of Your Own
  [8799] = { 185, 300 }, -- The Hero of the Day
  [40234] = { 164, 250 }, -- A New Rune-Frontier
  [40235] = { 164, 250 }, -- The Secrets of Darkforging
  [40236] = { 164, 250 }, -- The Secrets of Darkforging
  [40237] = { 164, 250 }, -- A Favor for Farsan
  [40238] = { 164, 250 }, -- A Meeting With The Dreadlord
  [40239] = { 164, 250 }, -- The Will of Lorthiras
  [40240] = { 164, 250 }, -- Knowledge of Lorthiras
  [40241] = { 164, 250 }, -- The Materials of Runeforging
  [40259] = { 164, 200 }, -- The Dark-Rune Anvil
  [40873] = { 171, 1 }, -- The Recipe of Dreamshard Elixir
  [40874] = { 171, 1 }, -- The Recipe of Lucidity Potion
  [40875] = { 165, 1 }, -- Pattern: Enchanted Armor Kit
  [40883] = { 333, 1 }, -- Enchant Boots: Greater Spirit
  [40884] = { 333, 1 }, -- Enchant Bracer: Greater Deflection
  [40886] = { 186, 1 }, -- Smelting Dreamsteel
  [40888] = { 164, 1 }, -- Dreamsteel Leggings
  [40889] = { 164, 1 }, -- Dreamsteel Bracers
  [40890] = { 164, 1 }, -- Dreamsteel Boots
  [40895] = { 165, 1 }, -- Crafting Dreamhide
  [40897] = { 165, 1 }, -- Dreamhide Bracers
  [40898] = { 165, 1 }, -- Dreamhide Leggings
  [40899] = { 165, 1 }, -- Dreamhide Belt
  [40900] = { 197, 1 }, -- Crafting Dreamthread
  [40902] = { 197, 1 }, -- Dreamthread Kilt
  [40903] = { 197, 1 }, -- Dreamthread Bracers
  [40904] = { 197, 1 }, -- Dreamthread Gloves
  [41111] = { 164, 1 }, -- Plans: Dreamsteel Belt Buckle
  [41275] = { 755, 225 }, -- Mastering Goldsmithing
  [41276] = { 755, 225 }, -- Mastering Goldsmithing
  [41277] = { 755, 225 }, -- Mastering Gemology
  [41278] = { 755, 225 }, -- Mastering Gemology
  [41291] = { 755, 225 }, -- Unfortunate Circumstances
  [41296] = { 755, 225 }, -- The Collector
  [41300] = { 755, 200 }, -- Just Ask Them Nicely
  [41303] = { 755, 200 }, -- Lost In Ratchet
  [41306] = { 755, 200 }, -- It's All Ogre Now
  [41313] = { 755, 225 }, -- Leyline Investigation
  [41316] = { 755, 300 }, -- Advanced Jewelcrafting XI: Hard as Diamonds
  [41333] = { 755, 300 }, -- Advanced Gemology I
  [41334] = { 755, 300 }, -- Advanced Gemology II
  [41335] = { 755, 300 }, -- Advanced Goldsmithing I
  [41336] = { 755, 300 }, -- An Unseen Obstacle
  [41337] = { 755, 300 }, -- Advanced Goldsmithing II
  [41345] = { 356, 300 }, -- Altar of an Ancient Evil
  [41346] = { 356, 300 }, -- A Mossy Mystery
  [41361] = { 755, 300 }, -- Gleaming Blood
  [41362] = { 755, 300 }, -- To Cut A Heart
  [55300] = { 164, 265 }, -- Imperial Plate Gauntlets
  [70040] = { 164, 1 }, -- Reinforcing The Sepulcher
  [80735] = { 171, 275 }, -- An Uncommon Request
  [80736] = { 333, 275 }, -- A Rare Request
}

-- Goldsmithing referrals: each faction completes all three local tasks.
pfDB.quests.preall = pfDB.quests.preall or {}
pfDB.quests.preall[41286] = { 41283, 41284, 41285 }
pfDB.quests.preall[41290] = { 41287, 41288, 41289 }
local goldsmithQuests = pfDB.quests["data-turtle"]
if goldsmithQuests then
  for id, prerequisites in pairs(pfDB.quests.preall) do
    if (id == 41286 or id == 41290) and type(goldsmithQuests[id]) == "table" then
      goldsmithQuests[id].pre = prerequisites
      goldsmithQuests[id].preall = prerequisites
    end
  end
  if type(goldsmithQuests[41291]) == "table" then
    goldsmithQuests[41291].pre = { 41286, 41290 }
  end
end
pfDB.questProfessionRequirements[41290] = { 755, 225 }

-- The Brassbolts Brothers (2769) is an optional referral, not an acceptance
-- requirement for Gahz'rilla. Turtle's quest template has PrevQuestId = 0.
local gahzrilla = pfDB.quests["data-turtle"] and pfDB.quests["data-turtle"][2770]
  or pfDB.quests.data and pfDB.quests.data[2770]
if type(gahzrilla) == "table" then gahzrilla.pre = nil end
