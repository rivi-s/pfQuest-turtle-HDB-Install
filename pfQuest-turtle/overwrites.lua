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

-- Item: Head of Geshgan (41783)
-- Preserve the known-good Turtle source chance used by alpha.6.
local turtleItems = pfDB["items"] and pfDB["items"]["data-turtle"]
if turtleItems and turtleItems[41783] then
  turtleItems[41783]["U"] = { [62217] = 1.0 }
end
