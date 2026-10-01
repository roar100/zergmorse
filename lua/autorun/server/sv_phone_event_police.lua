local function GivePoliceWeapon(ply, class, magazines)
	local weapon = ply:Give(class)
	if not IsValid(weapon) then return end

	local clipSize = math.max(weapon:GetMaxClip1(), 0)
	local ammoType = weapon:GetPrimaryAmmoType()
	if clipSize > 0 and ammoType and ammoType >= 0 then
		ply:GiveAmmo(clipSize * (magazines or 3), ammoType, true)
	end
end

local function EquipEventPolice(ply)
	ply:SetPlayerClass("police")
	GivePoliceWeapon(ply, "weapon_glock17", 3)
	GivePoliceWeapon(ply, "weapon_taser", 3)
	ply:Give("weapon_medkit_sh")
	ply:Give("weapon_walkie_talkie")
	ply:Give("weapon_naloxone")
	ply:Give("weapon_painkillers")
	ply:Give("weapon_handcuffs")
	ply:Give("weapon_handcuffs_key")
	ply:Give("weapon_hg_tonfa")

	if hg and hg.AddArmor then hg.AddArmor(ply, {"vest2"}) end

	local inventory = ply:GetNetVar("Inventory") or {}
	inventory.Weapons = inventory.Weapons or {}
	inventory.Weapons.hg_flashlight = true
	ply:SetNetVar("Inventory", inventory)
	ply:SetNetVar("CurPluv", "pluvberet")

	if ply.organism then ply.organism.recoilmul = 0.8 end
	local hands = ply:Give("weapon_hands_sh")
	if IsValid(hands) then ply:SetActiveWeapon(hands) end
	if zb and zb.GiveRole then zb.GiveRole(ply, "Police Officer", Color(15, 15, 255)) end
end

local function SpawnEventPolice(round)
	if round.PoliceSpawned then return 0 end

	local candidates = {}
	for _, ply in ipairs(player.GetAll()) do
		local isEventer = round.EventersList and round.EventersList[ply:SteamID()]
		if not ply:Alive() and ply:Team() ~= TEAM_SPECTATOR and not isEventer
		and not (ply.afkTime2 and ply.afkTime2 > 60) then
			candidates[#candidates + 1] = ply
		end
	end

	local count = math.min(#candidates, 4)
	if count == 0 then return 0 end

	table.Shuffle(candidates)
	local basePos = zb and zb.GetRandomSpawn and zb:GetRandomSpawn() or nil

	for i = 1, count do
		local ply = candidates[i]
		ply.isPolice = true
		ply.isTraitor = false
		ply.isGunner = false
		ply:Spawn()

		if isvector(basePos) then
			if i == 1 or not hg or not hg.tpPlayer then
				ply:SetPos(basePos)
			else
				hg.tpPlayer(basePos, ply, i)
			end
		end

		EquipEventPolice(ply)
	end

	round.PoliceSpawned = true
	EmitSound("snd_jack_hmcd_policesiren.wav", vector_origin, 0, CHAN_AUTO, 1, 125, 0, 100)
	return count
end

hook.Add("HMCDPhoneCallCompleted", "HMCDPhoneEventPoliceResponse", function(_, phone)
	if not CurrentRound or not zb or zb.ROUND_STATE ~= 1 then return end

	local round = CurrentRound()
	if not round or round.name ~= "event" then return end

	local spawned = SpawnEventPolice(round)
	if IsValid(phone) and phone.SendPhoneStatus then
		phone:SendPhoneStatus("CALL COMPLETE", spawned > 0 and "POLICE DISPATCHED" or "NO OFFICERS AVAILABLE", 4)
	end
end)
