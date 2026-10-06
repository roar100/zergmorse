local MODE = MODE

MODE.name = "lastshift"
MODE.PrintName = "The Last Shift"
MODE.Description = "Complete the 5 objectives and evade whatever is on ur trail."

MODE.start_time = 5
MODE.end_time = 7
MODE.ROUND_TIME = 340

MODE.randomSpawns = true
MODE.shouldfreeze = true
MODE.PoliceAllowed = false
MODE.OverrideSpawn = true
MODE.LootSpawn = true
MODE.LootOnTime = false
MODE.ForBigMaps = true
MODE.Chance = 0.00

print("[LastShift] sh_lastshift.lua loaded on " .. (SERVER and "SERVER" or "CLIENT"))