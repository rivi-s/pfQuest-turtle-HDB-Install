-- Older base addons do not expose the changelog yet.
if not pfQuestChangelog then return end
-- Published history and explicitly labeled development notes.
pfQuestChangelog:Register("pfQuest-turtle", {
{ ["version"] = "0.2.0-beta.1", ["date"] = "2026-10-04", ["notes"] = {
"Removed an incorrect prerequisite that hid Gahz'rilla (2770) from available quest markers.",
"Added Display Repeatable Quests [Beta] beneath the event/daily option, off by default. Known repeatable offers use blue exclamation marks and retain existing quest requirements. Coverage and accept/turn-in refresh are still being tested; please report missing quests with their name and ID.",
"Fixed map and minimap tooltips staying visible after leaving a marker.",
"Added profession skill requirements and corrected faction-specific Goldsmithing prerequisites.",
"Embedded the combined Turtle database and guarded missing quest records during startup.",
"Added this changelog and one update reminder per installed version."
} },
{ ["version"] = "0.1.0-alpha.15", ["date"] = "2026-10-02", ["notes"] = {
"Reduced party quest synchronization work to prevent group joins and quest turn-ins from stuttering.",
"Enabled automatic acceptance and turn-in for newer Turtle report quests with objective-free hand-ins.",
"Corrected More Silk for the Wounded to start from Hara'ne and added her verified Moonwhisper Coast location.",
"Rebuilt and validated the packaged Turtle HearthDB database."
} },
{ ["version"] = "0.1.0-alpha.13", ["date"] = "2026-09-29", ["notes"] = {
"Restored 64 missing prerequisite relationships that could expose later chain steps too early, including Vimes's Report.",
"Added missing routes and objective sources for Reports of Dustwallow, The Land of Kings, and The Missing Diplomat at Sentry Point.",
"Removed both obsolete Stinky's Escape variants and their removed quest NPC.",
"Rebuilt and validated the packaged Turtle HearthDB database."
} },
{ ["version"] = "0.1.0-alpha.12", ["date"] = "2026-09-26", ["notes"] = {
"Added Turtle-only Trees & Wood tracking backed by HearthDB, with 36 Survival gathering-object relations and automatic skill filtering.",
"Integrated all Turtle settings into the new five-tab configuration window and defaulted new characters to the largest usable size.",
"Added party quest map pins with recoloring and optional route-arrow navigation.",
"Improved Current Zone Only behavior around custom-zone boundaries and corrected newer Turtle quest, NPC, objective, spawn, restriction, and drop-rate data."
} },
{ ["version"] = "0.1.0-alpha.11", ["date"] = "2026-09-24", ["notes"] = {
"Restored quest nameplate icons automatically after login and reload.",
"Added calibrated continent projections for Balor, Grim Reaches, Northwind, and Gilneas.",
"Fixed Current Zone Only leaking quests from older maps into newer Turtle zones.",
"Removed duplicate Alah'Thalas and Thalassian Highlands continent quest pins.",
"Added verified Northwind, Balor, and Moonwhisper Coast quest relationships, objective sources, object and NPC locations, and corrected drop rates.",
"Rebuilt and validated the packaged Turtle HearthDB database."
} }
})
