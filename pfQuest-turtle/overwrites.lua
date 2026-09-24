-- Turtle's hand-maintained database corrections are applied by the HearthDB
-- exporter and stored in SQLite. No large runtime database tables exist here.

-- Quest: Vile Dwarven Pigs (41682)
-- The gossip-driven keg objective is absent from the extracted quest row.
local turtleQuests = pfDB["quests"] and pfDB["quests"]["data-turtle"]
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
  turtleItems[41695]["U"] = { [62490] = 1.0 }
end

if turtleItems and turtleItems[41737] then
  turtleItems[41737]["U"] = { [62146] = 1.0 }
end
