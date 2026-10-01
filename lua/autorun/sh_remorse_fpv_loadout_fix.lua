-- Drop-in patch for the supplied Remorse build; use its native loadout menu/exclusions.
local MENU = "remorse_fpv_loadout_fix/cl_menu.lua"
local SERVER_FILE = "remorse_fpv_loadout_fix/sv_loadout.lua"
local VERSION = "FPV loadout fix 2"
if SERVER then
    AddCSLuaFile()
    AddCSLuaFile(MENU)
end
local installedMode, installedFunction
local buildLoadout = SERVER and include(SERVER_FILE) or nil
local function Install()
    if SERVER then
        local mode = zb and zb.modes and zb.modes.hmcd
        if not mode or not mode.SubRoles or not mode.SubRoles.traitor_custom then return end
        if installedMode == mode and mode.ApplyTraitorLoadout == installedFunction
            and mode.SubRoles.traitor_custom.SpawnFunction == installedFunction
            and (not mode.SubRoles.traitor_fox or mode.SubRoles.traitor_fox.SpawnFunction == installedFunction) then return end
        installedFunction = buildLoadout(mode)
        installedMode = mode
        print("[Remorse] " .. VERSION .. ": server loadout installed")
    else
        if not hg or not hg.DrawLoadoutMenu then return end
        if hg.DrawLoadoutMenu == installedFunction then return end
        include(MENU)
        installedFunction = hg.DrawLoadoutMenu
        print("[Remorse] " .. VERSION .. ": native menu installed; FPV Drone = 5 points")
    end
end
local function DeferredInstall()
    timer.Simple(0, Install)
end
hook.Add("InitPostEntity", "RemorseFPVLoadoutFix", DeferredInstall)
hook.Add("OnReloaded", "RemorseFPVLoadoutFix", DeferredInstall)
timer.Create("RemorseFPVLoadoutFix", 2, 0, Install)
DeferredInstall()
concommand.Add("remorse_fpv_loadout_status", function()
    print("[Remorse] " .. VERSION)
    if SERVER then
        local mode = zb and zb.modes and zb.modes.hmcd
        print("Loadout active:", mode ~= nil and mode.ApplyTraitorLoadout == installedFunction)
        print("Drone registered:", weapons.GetStored("weapon_dronecontroller_ful") ~= nil)
    else
        print("Menu active:", hg ~= nil and installedFunction ~= nil and hg.DrawLoadoutMenu == installedFunction)
        print("Drone registered:", weapons.GetStored("weapon_dronecontroller_ful") ~= nil)
    end
end)
