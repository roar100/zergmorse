-- Bart vs Homer: Homer's toughness (damage reduction, no fall damage,
-- headshot resistance, constant limb/organ regrowth).
--
-- Deliberately independent from the real Juggernaut class/mode -- this
-- never touches PlayerClassName, so it can't pull in Juggernaut's voice
-- pack, UI, or anything else tied to that specific identity. It only
-- reads the current round + Homer's team (team 1), both fully local to
-- this mode.

print("[BartVsHomer] sv_bartvshomer_powers.lua reached (SERVER file, executing)")

local function Setup()
	local function IsBartVsHomerActive()
		local round = CurrentRound and CurrentRound()
		return round ~= nil and round.name == "bartvshomer"
	end

	-- Resolves ent (a player, or their ragdoll/fake-death body) to the
	-- player if and only if that player is the current round's Homer.
	-- Mirrors GetJuggernautPlayer's full fallback chain -- EntityTakeDamage's
	-- ent is often a fake/hitbox-proxy body in this damage system, not the
	-- player directly, so every resolution step matters.
	local function GetHomerPlayer(ent)
		if not IsValid(ent) then return nil end

		local ply
		if ent:IsPlayer() then
			ply = ent
		else
			if hg and isfunction(hg.RagdollOwner) then
				ply = hg.RagdollOwner(ent)
			end

			if not IsValid(ply) and IsValid(ent.ply) then
				ply = ent.ply
			end

			if not IsValid(ply) and ent.GetNWEntity then
				local nwPly = ent:GetNWEntity("ply")
				if IsValid(nwPly) then ply = nwPly end
			end
		end

		if not IsValid(ply) or not ply:IsPlayer() then return nil end
		if not IsBartVsHomerActive() then return nil end
		if ply:Team() ~= 1 then return nil end

		return ply
	end

	local homerLastDamage = {}

	hook.Add("EntityTakeDamage", "BvH_HomerDamageReduction", function(ent, dmgInfo)
		local homer = GetHomerPlayer(ent)
		if not homer then return end

		homerLastDamage[homer] = CurTime()

		dmgInfo:SetDamage(dmgInfo:GetDamage() * 0.5)
		dmgInfo:SetDamageForce(Vector(0, 0, 0))
	end)

	hook.Add("CanFallDamage", "BvH_HomerNoFallDamage", function(ply, speed)
		if GetHomerPlayer(ply) then return false end
	end)

	-- Remorse passes the hitgroup separately to this hook; CTakeDamageInfo
	-- has no GetHitGroup() method of its own.
	hook.Add("PreHomigradDamage", "BvH_HomerHeadshotResist", function(ply, dmgInfo, hitgroup, ent, harm, hitBoxs, inputHole)
		local homer = GetHomerPlayer(ply)
		if not homer then return end

		if hitgroup == HITGROUP_HEAD then
			dmgInfo:ScaleDamage(0.1)

			if homer.organism then
				homer.organism.skull = 0
				homer.organism.brain = 0
			end
		end

		return true
	end)

	hook.Add("Think", "BvH_HomerRegrowth", function()
		for _, ply in player.Iterator() do
			local homer = GetHomerPlayer(ply)
			if not homer or not homer:Alive() then continue end

			local org = homer.organism
			if not org then continue end

			local lastDamage = homerLastDamage[homer] or 0
			local timeSinceDamage = CurTime() - lastDamage

			org.lleg = 0
			org.rleg = 0
			org.larm = 0
			org.rarm = 0
			org.chest = 0
			org.pelvis = 0
			org.spine1 = 0
			org.spine2 = 0
			org.spine3 = 0
			org.skull = 0
			org.liver = 0
			org.heart = 0
			org.stomach = 0
			org.intestines = 0
			org.trachea = 0
			org.brain = 0

			if org.lungsL then
				org.lungsL[1] = 0
				org.lungsL[2] = 0
			end
			if org.lungsR then
				org.lungsR[1] = 0
				org.lungsR[2] = 0
			end

			org.llegdislocation = false
			org.rlegdislocation = false
			org.larmdislocation = false
			org.rarmdislocation = false
			org.jawdislocation = false

			org.llegamputated = false
			org.rlegamputated = false
			org.larmamputated = false
			org.rarmamputated = false

			org.immobilization = 0
			org.pain = 0
			org.painadd = 0
			org.avgpain = 0
			org.shock = 0
			org.disorientation = 0
			org.bleed = 0
			org.internalBleed = 0
			org.hurt = 0
			org.hurtadd = 0
			org.needfake = false
			org.needotrub = false
			org.otrub = false
			org.fake = false
			org.canmove = true
			org.canmovehead = true

			if timeSinceDamage > 5 then
				local maxBlood = org.maxBlood or 8000
				if org.blood and org.blood < maxBlood then
					org.blood = math.min(org.blood + 10, maxBlood)
				end
			end

			if org.wounds then
				for i = #org.wounds, 1, -1 do
					if timeSinceDamage > 3 then
						org.wounds[i][1] = math.max(org.wounds[i][1] - 0.5, 0)
						if org.wounds[i][1] <= 0 then
							table.remove(org.wounds, i)
						end
					end
				end
			end

			if org.arterialwounds then
				for i = #org.arterialwounds, 1, -1 do
					if timeSinceDamage > 5 then
						org.arterialwounds[i][1] = math.max(org.arterialwounds[i][1] - 1, 0)
						if org.arterialwounds[i][1] <= 0 then
							table.remove(org.arterialwounds, i)
						end
					end
				end
			end

			if org.dmgstack then
				table.Empty(org.dmgstack)
			end

			homer:SetNetVar("wounds", org.wounds or {})
			homer:SetNetVar("arterialwounds", org.arterialwounds or {})
		end
	end)
end

local ok, err = pcall(Setup)

if ok then
	print("[BartVsHomer] sv_bartvshomer_powers.lua loaded OK")
else
	print("[BartVsHomer] !!! sv_bartvshomer_powers.lua FAILED TO LOAD !!!")
	print("[BartVsHomer] Error: " .. tostring(err))
end
