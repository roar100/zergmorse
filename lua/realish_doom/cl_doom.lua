local state = {start = 0}
local flashUntil = 0
local icon = Material("realish/suddendeath.png", "smooth")
local colors = {[0] = Color(200, 20, 20), [1] = Color(20, 80, 220)}
local function StopDoom()
    if IsValid(state.channel) then state.channel:Stop() end
    if state.cue then state.cue:Stop() end
    state = {start = 0}
end
local function Active()
    return zb and zb.CROUND == "realish" and zb.ROUND_STATE == 1 and GetGlobalFloat("Realish_DoomStart", 0) > 0
end
hook.Add("Think", "RealishDoomAudio", function()
    if not Active() then if state.start ~= 0 then StopDoom() end return end
    local start = GetGlobalFloat("Realish_DoomStart", 0)
    if state.start ~= start then
        StopDoom()
        state.start = start
        local track = math.Clamp(GetGlobalInt("Realish_DoomTrack", 1), 1, 2)
        sound.PlayFile("sound/realishgamemode/rem_suddendeath" .. track .. ".mp3", "noblock noplay", function(channel)
            if not IsValid(channel) then return end
            if state.start ~= start or not Active() then channel:Stop() return end
            state.channel = channel
            channel:EnableLooping(false)
        end)
    end
    if CurTime() < start then return end
    if not state.announced then
        state.announced = true
        if CurTime() - start < 5 then
            state.cue = CreateSound(LocalPlayer(), "realishgamemode/rem_heroawakens.mp3")
            if state.cue then state.cue:PlayEx(1, 100) end
        end
    end
    if IsValid(state.channel) then
        if not state.playing then
            state.playing = true
            state.channel:SetTime(math.max(0, CurTime() - start))
            state.channel:Play()
        end
        local volume = GetConVar("realish_music_volume")
        local muted = GetConVar("realish_music_muted")
        state.channel:SetVolume(muted and muted:GetBool() and 0 or math.Clamp(volume and volume:GetFloat() or 1, 0, 1) * 0.7)
    end
end)

hook.Add("PreDrawHalos", "RealishDoomTeamHighlights", function()
    if not Active() or CurTime() < GetGlobalFloat("Realish_DoomStart", 0) then return end
    local teams = {[0] = {}, [1] = {}}
    for _, ply in player.Iterator() do
        local teamID = ply:Team()
        if ply:Alive() and teams[teamID] and ply ~= LocalPlayer() then
            local rag = ply:GetNWEntity("FakeRagdoll")
            if not IsValid(rag) then rag = ply.FakeRagdoll end
            local ent = IsValid(rag) and rag or ply
            teams[teamID][#teams[teamID] + 1] = ent
        end
    end
    for teamID, entities in pairs(teams) do
        if #entities > 0 then halo.Add(entities, colors[teamID], 3, 3, 2, true, true) end
    end
end)

hook.Add("HUDPaint", "RealishDoomHUD", function()
    if flashUntil > CurTime() then
        surface.SetDrawColor(255, 255, 255, math.Clamp((flashUntil - CurTime()) / 3, 0, 1) * 255)
        surface.DrawRect(0, 0, ScrW(), ScrH())
    end
    if not Active() then return end
    local elapsed = CurTime() - GetGlobalFloat("Realish_DoomStart", 0)
    if elapsed < 0 then return end
    local sw, sh = ScrW(), ScrH()
    if elapsed < 5 then
        local alpha = math.min(elapsed * 3, 1, (5 - elapsed)) * 255
        local w = math.min(sw * 0.82, 1100)
        local h = w * 720 / 1280
        surface.SetMaterial(icon)
        surface.SetDrawColor(255, 255, 255, alpha)
        surface.DrawTexturedRect((sw - w) / 2, (sh - h) / 2, w, h)
    end
    local left = math.max(0, GetGlobalFloat("Realish_DoomEnd", 0) - CurTime())
    draw.SimpleTextOutlined("SUDDEN DOOM  " .. string.format("%02d:%02d", math.floor(left / 60), math.floor(left % 60)), "RealishMedium", sw / 2, sh * 0.12, Color(255, 70, 40), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
    for _, ply in player.Iterator() do
        local col = colors[ply:Team()]
        if ply:Alive() and col and ply ~= LocalPlayer() then
            local ent = IsValid(ply.FakeRagdoll) and ply.FakeRagdoll or ply
            local pos = (ent:WorldSpaceCenter() + Vector(0, 0, 35)):ToScreen()
            if pos.visible then
                draw.SimpleTextOutlined(ply:Nick(), "RealishMicro", math.Clamp(pos.x, 35, sw - 35), math.Clamp(pos.y, 35, sh - 35), col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
            end
        end
    end
end)

net.Receive("RealishDoomNuke", function()
    StopDoom()
    flashUntil = CurTime() + 4
    surface.PlaySound("ambient/explosions/explode_9.wav")
    util.ScreenShake(EyePos(), 50, 10, 4, 100000)
end)
hook.Add("ShutDown", "RealishDoomCleanup", StopDoom)
