-- Published history and explicitly labeled development notes.
pfQuestChangelog:Register("pfQuest", {
{ ["version"] = "0.2.0-beta.1", ["date"] = "2026-10-04", ["notes"] = {
"Fixed map and minimap tooltips staying visible after leaving a marker.",
"Added support for the optional repeatable quest display setting supplied by Turtle quest data.",
"Embedded HearthDB inside pfQuest; a separate provider addon is no longer required.",
"Protected embedded databases from leftover old provider addons.",
"Upgrade cleanup: you can delete the old pfQuest-HearthDB and pfQuest-HearthDB-turtle folders from Interface/AddOns. Keep pfQuest, pfQuest-turtle if installed, and your WTF settings. HearthDB.dll is still required.",
"Improved completion marker refresh and duplicate quest-title handling.",
"Added this changelog and one update reminder per installed version."
} },
{ ["version"] = "0.1.0-alpha.15", ["date"] = "2026-10-02", ["notes"] = {
"Updated quest objectives and route arrows immediately after progress, completion, turn-in, and abandonment while the World Map is closed.",
"Restored abandoned quest markers immediately while preserving nearby completed quest markers as quest-log rows shift.",
"Improved Turtle quest-removal classification and added an optional abandon-flow diagnostic trace."
} },
{ ["version"] = "0.1.0-alpha.13", ["date"] = "2026-09-29", ["notes"] = {
"Restored active quest objectives when removing an accidentally hidden quest from the Journal and fixed the Journal remove button's hover flicker.",
"Kept route arrows on active objectives when a higher-priority quest marker shares the same NPC or coordinates.",
"Selected the active quest ID for map pins, tracker entries, and routes in same-title quest chains."
} },
{ ["version"] = "0.1.0-alpha.12", ["date"] = "2026-09-26", ["notes"] = {
"Reorganized the configuration window into five tabs while preserving all existing settings and live-update behavior.",
"Fixed map-node transparency, route-arrow re-enabling, minimap-button visibility, reload prompting, and configuration-window resizing.",
"Added rendering, recoloring, tooltip, and route-arrow support for Turtle party quest map pins.",
"Kept collapsed Quest Log categories stable and improved provider-backed map objective descriptions.",
"Added generic tracking-extension hooks so Turtle gathering categories stay out of the vanilla HDB interface."
} },
{ ["version"] = "0.1.0-alpha.11", ["date"] = "2026-09-24", ["notes"] = {
"Fixed false tracker completion icons while preserving correct readiness for simple talk and hand-in quests.",
"Restored route arrows for objective-free hand-ins after asynchronous HearthDB data loads.",
"Kept completed quests stable in the Current Zone tracker while opening the Quest Log or selecting another quest.",
"Refreshed stale quest markers and objectives without requiring tooltip hover or reload.",
"Fixed map objective progress counts and compatibility with UI replacements that do not expose the optional `gfind` global.",
"Added Turtle boundary-alias filtering support to the shared zone-map renderer."
} }
}, "hdb")
