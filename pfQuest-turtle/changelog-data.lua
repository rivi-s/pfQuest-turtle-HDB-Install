-- Older base addons do not expose the changelog yet.
if not pfQuestChangelog then return end
-- Published history and explicitly labeled development notes.
pfQuestChangelog:Register("pfQuest-turtle", {
{ ["version"] = "0.2.0-beta.6", ["date"] = "2026-10-23", ["notes"] = {
"Corrected Weapons of Spirit to require both prerequisite branches.",
"Restored Family Above All hut/nest markers and Lard Lost His Lunch basket marker.",
"Linked Seeping Corruption vials to their individual tide pools.",
"Added all four Poisoned Water transformation targets and Aspect of Neptulon use links.",
"Added the reported Moonglade mailbox location and removed Grazle's obsolete northern positions.",
"Nameplate loot icons now respect the configured minimum drop chance."
} },
{ ["version"] = "0.2.0-beta.5", ["date"] = "2026-10-18", ["notes"] = {
"Added a Felwood position fallback at the Timbermaw tunnel boundary when the client returns no tunnel coordinates.",
"Added Nafien's tunnel position while retaining outdoor map locations.",
"Restored Bloodsail Correspondence links, Galen's Escape Strongbox turn-in, Growlpaw objectives/turn-in, and P'li's missing name.",
"Added Tanaris positions for Sandmoon Village NPCs while preserving their Thousand Needles positions.",
"Added the Survival 225 availability requirement for To Survive in the Jungle.",
"Shared compact objective data with nameplate and party-progress consumers instead of repeating full spawn queries.",
"The optional Russian module remains version 0.1.0 and is distributed separately."
} },
{ ["version"] = "0.2.0-beta.4", ["date"] = "2026-10-14", ["notes"] = {
"Removed the overriding Turtle prerequisite from Q2975 so the Feralas main quest does not require its optional introduction.",
"Prepared continent pins in bounded background batches after zone work, preferring the current continent.",
"Corrected same-name quest-stage tooltip selection and finished-quota nameplate matching.",
"Removed the incorrect prerequisite from Q41368 Reminiscent of Steel.",
"Added the separate optional pfQuest-turtle-HDB-ruRU 0.1.0 language pack: Russian quest text, settings, tracker, browser, journal, welcome screen and pfQuest tooltip displays on English clients. Missing translations fall back to English."
} },
{ ["version"] = "0.2.0-beta.3", ["date"] = "2026-10-10", ["notes"] = {
"Quest-category filters refresh when saved; tooltips explain the repeatable-quest requirement.",
"Party marker settings refresh cached party data and routing immediately.",
"Loot-panel settings refresh an already open panel.",
"Includes previously published Git-only Turtle quest-data and continent-map corrections."
} },
{ ["version"] = "Git update (0.2.0-beta.2)", ["date"] = "2026-10-08", ["update"] = "2026-10-08", ["notes"] = {
"Improved dense continent-map performance and made Purple Lotus continent pins sparser, preserving zone-map and minimap coverage.",
"Added Q40141 letter deliveries to Karl and Samual with corrected talk/progress links.",
"Added Q5216 summoned key-source location and rebuilt packaged Turtle HearthDB data."
} },
{ ["version"] = "0.2.0-beta.2", ["date"] = "2026-10-05", ["notes"] = {
"Restored missing quest objectives and item-use markers, including the Serpent Statue, Elemental Cores, Dark Iron Aggression, Tricolored Hide-ra and Rite of Resurrection.",
"Corrected 11 item-use links that targeted creatures instead of gameobjects.",
"Added 34 verified Garrison Armory spawn points for Q40428.",
"Rebuilt the packaged Turtle HearthDB database.",
"Legacy pfQuest-HearthDB and pfQuest-HearthDB-turtle folders can be deleted; HearthDB.dll is still required."
} },
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
