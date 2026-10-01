local MODE = MODE

hook.Add("StartCommand", "ChudBeasts_DisallowAttacking", function(ply, mv)
    if zb.CROUND == "chudbeasts" and (zb.ROUND_START or 0) + 5 > CurTime() then
        mv:RemoveKey(IN_ATTACK)
        mv:RemoveKey(IN_ATTACK2)
    end
end)

function MODE:PlayerCanLegAttack(ply)
    if zb.CROUND == "chudbeasts" and (zb.ROUND_START or 0) + 5 > CurTime() then
        return false
    end
end

-- Props and ragdolls remain usable; direct player grabs are blocked.
hook.Add("AllowPlayerPickup", "ChudBeasts_NoPlayerPickup", function(ply, ent)
    if (zb and zb.CROUND == "chudbeasts") or (IsValid(ply) and ply.PlayerClassName == "chudbeast") then
        if IsValid(ent) and ent:IsPlayer() then return false end
    end
end)
