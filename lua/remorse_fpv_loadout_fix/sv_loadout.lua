return function(MODE)
local function ParseLoadoutString(dataStr)
	local loadout = {}
	if dataStr and dataStr ~= "" then
		local ok, parsed = pcall(util.JSONToTable, dataStr)
		if ok and istable(parsed) then
			loadout = parsed
		end
	end
	return loadout
end

local LegacyTraitorLoadout = {
	skillset = "none",
	weapons = {
		"weapon_p22",
		"weapon_p22_silencer",
		"weapon_buck200knife",
		"weapon_hg_rgd_tpik",
		"weapon_adrenaline",
		"weapon_hg_shuriken",
		"weapon_hg_smokenade_tpik",
		"weapon_traitor_ied",
		"weapon_traitor_poison1",
		"weapon_traitor_suit",
		"weapon_hg_jam",
		"weapon_walkie_talkie"
	}
}

local TraitorSkillsetSubRoles = {
	["infiltrator"] = "traitor_infiltrator",
	["assassin"] = "traitor_assasin",
	["chemist"] = "traitor_chemist",
	["fox"] = "traitor_fox",
}

local function GetSelectedTraitorSkillset(ply)
	local loadout = ParseLoadoutString(ply:GetInfo("hmcd_traitor_loadout"))
	return isstring(loadout.skillset) and loadout.skillset or "none", loadout
end

local function ApplySelectedTraitorSkillset(ply, skillset)
	skillset = skillset or GetSelectedTraitorSkillset(ply)

	local isFox = skillset == "fox"
	ply.HMCDIsFox = isFox
	ply:SetNWBool("HMCD_IsFox", isFox)
	ply:SetNWString("HMCD_TraitorSkillset", skillset)
	ply:SetNWFloat("HMCD_FoxPhoneSpeedBoostUntil", 0)
	ply:SetNWFloat("HMCD_FoxPhoneSpeedCooldown", 0)
	ply:SetNWFloat("HMCD_FoxPhoneSpeedMultiplier", 1.25)

	if isFox then
		ply.SubRole = "traitor_fox"
	end

	return skillset
end

MODE.GetSelectedTraitorSkillset = GetSelectedTraitorSkillset
MODE.ApplySelectedTraitorSkillset = ApplySelectedTraitorSkillset

local TraitorSidearmWeapons = {
	["weapon_pm9"] = true,
	["weapon_p22"] = true,
	["weapon_tokarev"] = true,
	["weapon_tranquilizer"] = true,
	["weapon_taser"] = true,
}

local function ApplyTraitorLoadout(ply)
	local loadout = ParseLoadoutString(ply:GetInfo("hmcd_traitor_loadout"))
	if not loadout.skillset and not istable(loadout.weapons) then loadout = LegacyTraitorLoadout end

	local skillset = loadout.skillset or "none"
	local weaponsList = loadout.weapons or {}
	ply.SubRole = TraitorSkillsetSubRoles[skillset] or ply.SubRole
	ApplySelectedTraitorSkillset(ply, skillset)

	ply.organism.stamina.max = 220
	ply.organism.recoilmul = 1

	if skillset == "infiltrator" then
		-- Infiltrator specifics
	elseif skillset == "assassin" then
		ply.organism.recoilmul = 0.8
		ply.organism.stamina.max = 300
	elseif skillset == "chemist" then
		if CleanChemicalsOfPlayer then CleanChemicalsOfPlayer(ply) end
	end

	local inv = ply:GetNetVar("Inventory", {})
	inv["Weapons"] = inv["Weapons"] or {}
	inv["Weapons"]["hg_flashlight"] = true
	ply:SetNetVar("Inventory", inv)

	local hasP22 = false
	local hasPL15 = false
	local hasTaser = false
	local selectedSidearm = nil
	local selectedExplosive = nil

	for _, wep in ipairs(weaponsList) do
		-- IED and FPV Drone share one loadout slot, including saved loadouts.
		if wep == "weapon_traitor_ied" or wep == "weapon_dronecontroller_ful" then
			if selectedExplosive then continue end
			selectedExplosive = wep
		end
		-- PM9, P22, Tokarev, Tranquilizer and Taser share one sidearm slot.
		-- The client menu already enforces this; keep a server-side guard too.
		if TraitorSidearmWeapons[wep] then
			if selectedSidearm then continue end
			selectedSidearm = wep
		end
		if wep == "weapon_p22_silencer" then
			timer.Simple(0.5, function()
				if IsValid(ply) and ply:HasWeapon("weapon_p22") then
					local w = ply:GetWeapon("weapon_p22")
					if hg and hg.AddAttachmentForce then hg.AddAttachmentForce(ply, w, "supressor4") end
				end
			end)
		elseif wep == "weapon_pl15_silencer" then
			timer.Simple(0.5, function()
				if IsValid(ply) and ply:HasWeapon("weapon_pl15") then
					local w = ply:GetWeapon("weapon_pl15")
					if hg and hg.AddAttachmentForce then hg.AddAttachmentForce(ply, w, "supressor4") end
				end
			end)
		elseif wep == "weapon_p22_ammo" then
    timer.Simple(0.5, function()
        if IsValid(ply) and ply:HasWeapon("weapon_p22") then
            local w = ply:GetWeapon("weapon_p22")
            if IsValid(w) and w:GetPrimaryAmmoType() >= 0 then
                ply:GiveAmmo(w:GetMaxClip1(), w:GetPrimaryAmmoType(), true)
            end
        end
    end)
      
elseif wep == "weapon_tranquilizer_ammo" then
    timer.Simple(0.5, function()
        if IsValid(ply) and ply:HasWeapon("weapon_tranquilizer") then
            local w = ply:GetWeapon("weapon_tranquilizer")

            if IsValid(w) and w:GetPrimaryAmmoType() >= 0 then
                ply:GiveAmmo(
                    w:GetMaxClip1(),
                    w:GetPrimaryAmmoType(),
                    true
                )
            end
        end
    end)
	            
	elseif wep == "weapon_tokarev_ammo" then
    timer.Simple(0.5, function()
        if IsValid(ply) and ply:HasWeapon("weapon_tokarev") then
            local w = ply:GetWeapon("weapon_tokarev")

            if IsValid(w) and w:GetPrimaryAmmoType() >= 0 then
                ply:GiveAmmo(
                    w:GetMaxClip1(),
                    w:GetPrimaryAmmoType(),
                    true
                )
            end
        end
    end)
		elseif wep == "weapon_pm9_ammo" then
	timer.Simple(0.5, function()
		if IsValid(ply) and ply:HasWeapon("weapon_pm9") then
			local w = ply:GetWeapon("weapon_pm9")
			if IsValid(w) and w:GetPrimaryAmmoType() >= 0 then
				ply:GiveAmmo(w:GetMaxClip1(), w:GetPrimaryAmmoType(), true)
			end
		end
	end)
else
			local w = ply:Give(wep)
			if wep == "weapon_zoraki" then
				timer.Simple(1, function() if IsValid(w) then w:ApplyAmmoChanges(2) end end)
			elseif wep == "weapon_p22" then
				hasP22 = true
			elseif wep == "weapon_pl15" then
				hasPL15 = true
			elseif wep == "weapon_taser" then
				hasTaser = true
			end
		end
	end
end


MODE.ApplyTraitorLoadout = ApplyTraitorLoadout
for _, id in ipairs({"traitor_custom", "traitor_fox"}) do
    if MODE.SubRoles and MODE.SubRoles[id] then
        MODE.SubRoles[id].SpawnFunction = ApplyTraitorLoadout
    end
end
return ApplyTraitorLoadout
end
