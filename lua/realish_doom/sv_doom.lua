local MODE = MODE
local tracks = {104.646531, 107.376000}
util.AddNetworkString("RealishDoomNuke")
for _, path in ipairs({"materials/realish/suddendeath.png", "sound/realishgamemode/rem_suddendeath1.mp3", "sound/realishgamemode/rem_suddendeath2.mp3"}) do resource.AddFile(path) end
if file.Exists("sound/realishgamemode/rem_heroawakens.mp3", "GAME") then resource.AddFile("sound/realishgamemode/rem_heroawakens.mp3") end

function MODE:ResetSuddenDoom()
    self.DoomNuked = false
    SetGlobalFloat("Realish_DoomStart", 0)
    SetGlobalFloat("Realish_DoomEnd", 0)
    SetGlobalInt("Realish_DoomTrack", 0)
    for _, ply in player.Iterator() do ply.RealishFinalSpectator = nil end
end

function MODE:TrySuddenDoom()
    if GetGlobalFloat("Realish_DoomStart", 0) > 0 then return end
    if self:GetLives(0) > 0 or self:GetLives(1) > 0 then return end
    if self:GetAliveCount(0) == 0 or self:GetAliveCount(1) == 0 then return end
    for _, ply in player.Iterator() do
        if ply.RealishIsHero and ((ply:Alive() and (ply.RealishHeroLives or 0) > 1) or (not ply:Alive() and ply.RealishSpawnRequested)) then return end
    end
    local track = math.random(1, #tracks)
    -- Shared future start gives clients time to load audio. The server owns the deadline.
    local start = CurTime() + 1
    SetGlobalInt("Realish_DoomTrack", track)
    SetGlobalFloat("Realish_DoomStart", start)
    SetGlobalFloat("Realish_DoomEnd", start + tracks[track])
end

function MODE:DetonateSuddenDoom()
    if self.DoomNuked then return end
    self.DoomNuked = true
    net.Start("RealishDoomNuke") net.Broadcast()
    for _, ply in player.Iterator() do
        if ply:Alive() then
            ply.RealishIsHero = false
            ply.RealishHeroLives = 0
            ply:GodDisable()
            if ply.organism then ply.organism.godmode = false end
            ply:Kill()
        end
    end
end

local nextCheck = 0
hook.Add("Think", "RealishFinalSpectators", function()
    if not zb or zb.CROUND ~= "realish" or zb.ROUND_STATE ~= 1 or CurTime() < nextCheck then return end
    nextCheck = CurTime() + 0.25
    local alive = zb:CheckAlive()
    for _, ply in player.Iterator() do
        local teamID = ply:Team()
        local exhausted = (teamID == 0 or teamID == 1) and MODE:GetLives(teamID) <= 0
        local pendingHero = ply.RealishIsHero and ply.RealishSpawnRequested
        if not ply:Alive() and exhausted and not pendingHero then
            if not ply.RealishFinalSpectator or not IsValid(ply.chosenSpectEntity) or not ply.chosenSpectEntity:Alive() then
                local target = alive[1]
                if IsValid(target) then
                    ply.RealishFinalSpectator = true
                    ply.chosenSpectEntity = target
                    ply.chosenspect = 1
                    ply.viewmode = 1
                    ply:SetNWEntity("spect", target)
                    ply:SetNWInt("viewmode", 1)
                    net.Start("ZB_SpectatePlayer")
                    net.WriteEntity(target) net.WriteEntity(NULL) net.WriteInt(1, 4) net.Send(ply)
                end
            end
        else ply.RealishFinalSpectator = nil end
    end
end)

-- Explicit visibility during Doom makes through-wall halos work across the map.
hook.Add("SetupPlayerVisibility", "RealishDoomReveal", function()
    if not zb or zb.CROUND ~= "realish" or zb.ROUND_STATE ~= 1 or GetGlobalFloat("Realish_DoomStart", 0) <= 0 then return end
    for _, ply in player.Iterator() do
        if ply:Alive() and ply.RealishDeployed and (ply:Team() == 0 or ply:Team() == 1) then
            local ent = IsValid(ply.FakeRagdoll) and ply.FakeRagdoll or ply
            AddOriginToPVS(ent:WorldSpaceCenter())
        end
    end
end)
