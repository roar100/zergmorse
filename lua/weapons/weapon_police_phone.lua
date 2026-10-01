if SERVER then
	AddCSLuaFile()
	util.AddNetworkString("HMCD_PhoneFoxAlert")
	util.AddNetworkString("HMCD_PhoneJammed")
	util.AddNetworkString("HMCD_PhoneStatus")
end

SWEP.Base = "weapon_base"
SWEP.PrintName = "911 Phone"
SWEP.Instructions = "Hold primary attack through the 3-second connection delay to call the police. Being ragdolled interrupts the call."
SWEP.Category = "ZCity Other"
SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.IdleHoldType = "normal"
SWEP.HoldType = "slam"
SWEP.ViewModel = ""
SWEP.WorldModel = "models/sirgibs/ragdoll/css/terror_arctic_radio.mdl"

SWEP.Weight = 0
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false
-- SWEP slots are zero-based: 7 is the visible/equippable slot 8.
SWEP.Slot = 7
SWEP.SlotPos = 6
SWEP.WorkWithFake = true
SWEP.offsetVec = Vector(6, 5.5, -41)
SWEP.offsetAng = Angle(180, 160, 180)

SWEP.CallDuration = 14.21
SWEP.CallDelay = 3
SWEP.FoxSpeedBoostMultiplier = 1.25
SWEP.FoxSpeedBoostDuration = 5
SWEP.FoxSpeedBoostCooldown = 30
SWEP.CallSoundMale = "chudmorse_phone/911_male.mp3"
SWEP.CallSoundFemale = "chudmorse_phone/911_female.mp3"
SWEP.EndCallSound = "chudmorse_phone/end_call.mp3"
SWEP.WarningSound = "chudmorse_phone/warning.mp3"
SWEP.CallSoundLevel = 80
SWEP.EndCallSoundLevel = 75
SWEP.PhoneSoundRadius = 400

SWEP.ScreenPosOffset = Vector(3.4, -2.22, 3.57)
SWEP.ScreenAngleOffset = Angle(-5, -18.5, 91)

if CLIENT then
	SWEP.WepSelectIcon = Material("vgui/wep_jack_hmcd_walkietalkie")
	SWEP.IconOverride = "vgui/wep_jack_hmcd_walkietalkie.png"
	SWEP.BounceWeaponIcon = false
end

local function GetPhoneRound()
	if not CurrentRound then return nil end

	local round = CurrentRound()
	if not round or (round.name ~= "hmcd" and round.name ~= "event") then return nil end

	return round
end

local function IsCallerRagdolled(ply)
	if not IsValid(ply) then return false end

	return IsValid(ply.FakeRagdoll) or IsValid(ply:GetNWEntity("FakeRagdoll"))
end

function SWEP:SetupDataTables()
	self:NetworkVar("Bool", 0, "Calling")
	self:NetworkVar("Bool", 1, "Spent")
	self:NetworkVar("Float", 0, "CallStartedAt")
end

-- Damage belongs to the phone, never to its current holder.
function SWEP:IsPhoneDestroyed()
	return self.FoxPhoneDestroyed == true or self:GetNWBool("FoxPhoneDestroyed", false)
end

function SWEP:GetInfo()
	return {FoxPhoneDestroyed = self:IsPhoneDestroyed(), PhoneSpent = self:GetSpent()}
end

function SWEP:SetInfo(info)
	if not SERVER or not istable(info) then return end
	if info.FoxPhoneDestroyed then self:DestroyPhone() end
	if info.PhoneSpent then self:SetSpent(true) end
end

function SWEP:DestroyPhone()
	if not SERVER then return end
	self.FoxPhoneDestroyed = true
	self:SetNWBool("FoxPhoneDestroyed", true)
	self:SetSpent(true)
	self:CancelCall("fox_shock")
	self:StopCallAudio()
	-- Clear even a completed/stale call alert, independently of Calling.
	self:SendFoxAlert(2, self:GetPos())
end

function SWEP:Equip()
	self.FoxPhoneDropped = nil
	if SERVER and self:IsPhoneDestroyed() then self:DestroyPhone() end
end

function SWEP:Initialize()
	self:SetHoldType(self.IdleHoldType)

	if SERVER then
		self:SetCalling(false)
		self:SetSpent(self:GetSpent() or self:IsPhoneDestroyed())
		self:SetCallStartedAt(0)
		self.CallAudioStarted = false
	end
end

function SWEP:Deploy()
	self:SetHold(self.IdleHoldType)
	return true
end

function SWEP:SetHold(value)
	self:SetWeaponHoldType(value)
	self:SetHoldType(value)
	self.holdtype = value
end

function SWEP:BoneSet(lookupName, vec, ang)
	local owner = self:GetOwner()
	if not IsValid(owner) or not owner:IsPlayer() then return end
	if not hg or not hg.bone or not hg.bone.Set then return end

	hg.bone.Set(owner, lookupName, vec, ang, "policephone", 0.01)
end

local handAng1 = Angle(-15, -10, 10)
local handAng2 = Angle(5, -65, -60)
local actAng1 = Angle(0, -40, -18)
local actAng2 = Angle(-5, -5, -70)

function SWEP:Step()
	local owner = self:GetOwner()
	if not IsValid(owner) or not owner:IsPlayer() then return end

	local active = self:GetCalling() or owner:KeyDown(IN_ATTACK) and not self:GetSpent()

	if active then
		self:SetHold(self.HoldType)
	elseif self:GetHoldType() ~= self.IdleHoldType then
		self:SetHold(self.IdleHoldType)
	end

	local typing = owner.IsTyping and owner:IsTyping() or false
	if owner:OnGround() and owner:GetVelocity():LengthSqr() <= 1000 and not typing and not owner:IsFlagSet(FL_ANIMDUCKING) then
		self:BoneSet("l_upperarm", vector_origin, handAng1)
		self:BoneSet("l_forearm", vector_origin, handAng2)
		self:BoneSet("r_upperarm", vector_origin, active and actAng1 or angle_zero)
		self:BoneSet("r_forearm", vector_origin, active and actAng2 or angle_zero)
	end
end

function SWEP:DrawWorldModel()
	local owner = self:GetOwner()
	if not IsValid(owner) or not owner:IsPlayer() then
		self:DrawModel()
	end
end

local screenTextColor = Color(0, 8, 0)
local screenOnColor = Color(12, 112, 42)
local screenCallingColor = Color(152, 103, 13)
local screenOffColor = Color(0, 0, 0)

function SWEP:DrawWorldModel2()
	self.model = IsValid(self.model) and self.model or ClientsideModel(self.WorldModel)
	local worldModel = self.model
	if not IsValid(worldModel) then return end

	local rawOwner = self:GetOwner()
	local owner = hg and hg.GetCurrentCharacter and hg.GetCurrentCharacter(rawOwner) or rawOwner

	worldModel:SetNoDraw(true)
	worldModel:SetModelScale(self.ModelScale or 1)

	if IsValid(owner) then
		local boneID = owner:LookupBone("ValveBiped.Bip01_L_Hand")
		if not boneID then return end

		local matrix = owner:GetBoneMatrix(boneID)
		if not matrix then return end

		local newPos, newAng = LocalToWorld(self.offsetVec, self.offsetAng, matrix:GetTranslation(), matrix:GetAngles())
		worldModel:SetPos(newPos)
		worldModel:SetAngles(newAng)
		worldModel:SetupBones()
		worldModel:DrawModel()

		newPos, newAng = LocalToWorld(self.ScreenPosOffset, self.ScreenAngleOffset, matrix:GetTranslation(), matrix:GetAngles())
		cam.Start3D2D(newPos, newAng, 0.005)
			local width, height = 264, 145
			local spent = self:GetSpent()
			local calling = self:GetCalling()
			local background = spent and screenOffColor or calling and screenCallingColor or screenOnColor

			draw.RoundedBox(3, -width / 2, -height / 2, width, height, background)

			if not spent then
				local dialing = calling and self:GetCallStartedAt() > CurTime()
				local title = dialing and "DIALING" or calling and "CALLING" or "911"
				local subtitle = "HOLD LMB"

				if dialing then
					subtitle = math.ceil(self:GetCallStartedAt() - CurTime()) .. "s"
				elseif calling then
					local progress = math.Clamp((CurTime() - self:GetCallStartedAt()) / self.CallDuration, 0, 1)
					subtitle = math.floor(progress * 100) .. "%"
				end

				draw.SimpleText(title, "HMCDPhoneScreen", 0, -18, screenTextColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText(subtitle, "HMCDPhoneScreenSmall", 0, 40, screenTextColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
		cam.End3D2D()
	else
		worldModel:SetPos(self:GetPos())
		worldModel:SetAngles(self:GetAngles())
		worldModel:DrawModel()
	end
end

function SWEP:CanStartCall()
	if self:IsPhoneDestroyed() then
		return false, "Phone permanently disabled by remote shock."
	end
	if self:GetSpent() then return false, "Phone disabled." end
	if CurTime() < self:GetNWFloat("FoxPhoneDisabledUntil", 0) then
		return false, "Phone disabled by remote shock."
	end
	local owner = self:GetOwner()
	if not IsValid(owner) or not owner:IsPlayer() or not owner:Alive() then
		return false, "No caller is available."
	end

	if IsCallerRagdolled(owner) then
		return false, "You cannot call while ragdolled."
	end

	if SERVER then
		local activePhone = HMCDActivePolicePhone
		if IsValid(activePhone) and activePhone ~= self and activePhone:GetCalling() then
			return false, "SIGNAL JAMMED, ANOTHER PLAYER IS ON THE CALL"
		elseif not IsValid(activePhone) or not activePhone:GetCalling() then
			HMCDActivePolicePhone = nil
		end
	end

	local round = GetPhoneRound()
	if not round or not zb or zb.ROUND_STATE ~= 1 then
		return false, "The phone only connects during an active Homicide or Event round."
	end

	if round.name == "event" then
		local roundStart = zb.ROUND_START or 0
		if round.HMCDPhoneRoundStart ~= roundStart then
			round.HMCDPhoneRoundStart = roundStart
			round.PoliceSpawned = false
		end
	end

	if round.PoliceAllowed == false then
		return false, "There is no police response in this round."
	end

	if round.PoliceSpawned then
		return false, "Police have already arrived."
	end

	return true
end

if SERVER then
	function SWEP:SendPhoneStatus(title, subtitle, duration)
		local owner = self:GetOwner()
		if not IsValid(owner) then return end

		net.Start("HMCD_PhoneStatus")
			net.WriteString(title or "PHONE")
			net.WriteString(subtitle or "")
			net.WriteFloat(duration or 3)
		net.Send(owner)
	end

	function SWEP:GetFoxRecipients()
		local recipients = {}

		for _, ply in player.Iterator() do
			if IsValid(ply) and ply:Alive() and (ply.HMCDIsFox or ply:GetNWBool("HMCD_IsFox", false)) then
				recipients[#recipients + 1] = ply
			end
		end

		return recipients
	end

	function SWEP:TriggerFoxSpeedBoost(recipients)
		local now = CurTime()

		for _, ply in ipairs(recipients) do
			local cooldownUntil = ply:GetNWFloat("HMCD_FoxPhoneSpeedCooldown", 0)
			if cooldownUntil <= now then
				ply:SetNWFloat("HMCD_FoxPhoneSpeedBoostUntil", now + self.FoxSpeedBoostDuration)
				ply:SetNWFloat("HMCD_FoxPhoneSpeedCooldown", now + self.FoxSpeedBoostCooldown)
				ply:SetNWFloat("HMCD_FoxPhoneSpeedMultiplier", self.FoxSpeedBoostMultiplier)
			end
		end
	end

	function SWEP:SendFoxAlert(eventCode, origin)
		local recipients = self:GetFoxRecipients()
		if #recipients == 0 then return end
		if eventCode == 1 then self:TriggerFoxSpeedBoost(recipients) end

		local owner = self:GetOwner()
		origin = isvector(origin) and origin or self.CallOrigin or self:GetPos()

		net.Start("HMCD_PhoneFoxAlert")
			net.WriteUInt(eventCode, 2)
			net.WriteUInt(self:EntIndex(), 16)
			net.WriteEntity(IsValid(owner) and owner or NULL)
			net.WriteVector(origin)
			net.WriteFloat(self:GetCallStartedAt())
			net.WriteFloat(self.CallDuration)
		net.Send(recipients)
	end

	function SWEP:StopCallAudio()
		self:StopSound(self.CallSoundMale)
		self:StopSound(self.CallSoundFemale)
	end

	function SWEP:GetPhoneSoundPlayers()
		local listeners = {}
		local included = {}
		local owner = self:GetOwner()
		local origin = self:GetPos()
		local radiusSquared = self.PhoneSoundRadius * self.PhoneSoundRadius

		for _, ply in ipairs(player.GetHumans()) do
			if IsValid(ply) and ply:GetPos():DistToSqr(origin) <= radiusSquared then
				listeners[#listeners + 1] = ply
				included[ply] = true
			end
		end

		if IsValid(owner) and not included[owner] then listeners[#listeners + 1] = owner end
		return listeners
	end

	function SWEP:GetPhoneSoundRecipients(listeners)
		local recipients = RecipientFilter()
		for _, ply in ipairs(listeners or self:GetPhoneSoundPlayers()) do
			if IsValid(ply) then recipients:AddPlayer(ply) end
		end

		return recipients
	end

	function SWEP:EmitPhoneSound(soundName, soundLevel, listeners)
		self:EmitSound(soundName, soundLevel, 100, 1, CHAN_VOICE, 0, 0, self:GetPhoneSoundRecipients(listeners))
	end

	function SWEP:PlayEndCallAudio()
		self:EmitPhoneSound(self.EndCallSound, self.EndCallSoundLevel, self.ActivePhoneSoundListeners)
		self.ActivePhoneSoundListeners = nil
	end

	function SWEP:StartCall()
		if self:GetCalling() or self:GetSpent() then return end

		local canStart, reason = self:CanStartCall()
		local owner = self:GetOwner()

		if not canStart then
			if IsValid(owner) and reason == "SIGNAL JAMMED, ANOTHER PLAYER IS ON THE CALL" then
				net.Start("HMCD_PhoneJammed")
				net.Send(owner)
			elseif IsValid(owner) and reason == "You cannot call while ragdolled." then
				owner:ChatPrint(reason)
			elseif IsValid(owner) and reason then
				self:SendPhoneStatus("CALL UNAVAILABLE", string.upper(reason), 3)
			end
			return
		end

		local female = false
		if isfunction(ThatPlyIsFemale) then
			local ok, result = pcall(ThatPlyIsFemale, owner)
			female = ok and result == true
		end

		self.CallOrigin = owner:GetPos()
		HMCDActivePolicePhone = self
		self.ActiveCallSound = female and self.CallSoundFemale or self.CallSoundMale
		self:SetCallStartedAt(CurTime() + self.CallDelay)
		self:SetCalling(true)
		self.CallAudioStarted = false
		owner.HMCDActivePhone = self
		owner:SetAnimation(PLAYER_ATTACK1)
	end

	function SWEP:BeginCallAudio()
		if not self:GetCalling() or self:IsPhoneDestroyed() or self:GetSpent() or self.CallAudioStarted then return end

		local owner = self:GetOwner()
		if not IsValid(owner) then
			self:CancelCall("owner_lost")
			return
		end

		-- Emit from the weapon entity so the conversation is a spatial phone
		-- sound heard by nearby players, rather than a sound on the caller.
		self.CallAudioStarted = true
		self.CallOrigin = owner:GetPos()
		self.ActivePhoneSoundListeners = self:GetPhoneSoundPlayers()
		self:EmitPhoneSound(self.ActiveCallSound, self.CallSoundLevel, self.ActivePhoneSoundListeners)
		owner:SetAnimation(PLAYER_ATTACK1)
		self:SendFoxAlert(1, self.CallOrigin)
	end

	function SWEP:CancelCall(reason)
		if not self:GetCalling() then return end

		local owner = self:GetOwner()
		local origin = IsValid(owner) and owner:GetPos() or self.CallOrigin or self:GetPos()
		local audioStarted = self.CallAudioStarted == true

		self:StopCallAudio()
		self:SetCalling(false)
		if HMCDActivePolicePhone == self then HMCDActivePolicePhone = nil end
		self:SetCallStartedAt(0)
		self.CallAudioStarted = false
		self:PlayEndCallAudio()

		if IsValid(owner) then
			if owner.HMCDActivePhone == self then owner.HMCDActivePhone = nil end

			if reason == "kicked" then
				self:SendPhoneStatus("CALL ENDED", "INTERRUPTED WHEN KICKED", 3)
			elseif reason == "ragdolled" then
				owner:ChatPrint("The 911 call was interrupted when you were ragdolled.")
			end
		end

		if audioStarted then self:SendFoxAlert(2, origin) end
	end

	function SWEP:CompleteCall()
		if not self:GetCalling() or self:IsPhoneDestroyed() or self:GetSpent() or not self.CallAudioStarted then return end

		local owner = self:GetOwner()
		local origin = IsValid(owner) and owner:GetPos() or self.CallOrigin or self:GetPos()

		self:StopCallAudio()
		self:SetCalling(false)
		if HMCDActivePolicePhone == self then HMCDActivePolicePhone = nil end
		self:SetSpent(true)
		self:SetCallStartedAt(0)
		self.CallAudioStarted = false
		self:PlayEndCallAudio()

		if IsValid(owner) then
			if owner.HMCDActivePhone == self then owner.HMCDActivePhone = nil end
			self:SendPhoneStatus("CALL COMPLETE", "POLICE RESPONSE ACCELERATED", 4)
		end

		local round = GetPhoneRound()
		if round and round.PoliceAllowed and not round.PoliceSpawned and round.saved then
			local now = CurTime()
			local currentPoliceTime = tonumber(round.saved.PoliceTime) or now
			local remainingTime = math.max(currentPoliceTime - now, 0)
			round.saved.PoliceTime = now + remainingTime * 0.5
			SetGlobalFloat("HMCD_PoliceArrivalTime", round.saved.PoliceTime)
		end

		self:SendFoxAlert(3, origin)
		hook.Run("HMCDPhoneCallCompleted", owner, self, origin)
	end

	hook.Add("Fake", "HMCDPhoneCancelOnRagdoll", function(ply)
		local phone = IsValid(ply) and ply.HMCDActivePhone or nil
		if IsValid(phone) and phone.CancelCall then
			phone:CancelCall("ragdolled")
		end
	end)

	local function CancelPlayerPhone(ply, reason)
		local phone = IsValid(ply) and ply.HMCDActivePhone or nil
		if IsValid(phone) and phone.CancelCall then
			phone:CancelCall(reason)
		end
	end

	hook.Add("HomigradLegKickHit", "HMCDPhoneCancelOnKick", function(_, victim)
		CancelPlayerPhone(victim, "kicked")
	end)

	hook.Add("PlayerDeath", "HMCDPhoneCancelOnDeath", function(ply)
		CancelPlayerPhone(ply, "death")
	end)

	hook.Add("PlayerDisconnected", "HMCDPhoneCancelOnDisconnect", function(ply)
		CancelPlayerPhone(ply, "disconnect")
	end)
end

function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire(CurTime() + 0.3)

	if CLIENT then return end
	if self:IsPhoneDestroyed() or self:GetSpent() then
		self:SendPhoneStatus("CALL COMPLETE", "PHONE DISABLED", 3)
		return
	end

	self:StartCall()
end

function SWEP:SecondaryAttack()
end

function SWEP:Reload()
end

function SWEP:Think()
	self:Step()

	if SERVER and self:IsPhoneDestroyed() then
		self:SetSpent(true)
		if self:GetCalling() then self:CancelCall("fox_shock") end
	end

	if SERVER and self:GetCalling() then
		local owner = self:GetOwner()
		local canContinue = IsValid(owner)
			and owner:IsPlayer()
			and owner:Alive()
			and owner:GetActiveWeapon() == self
			and owner:KeyDown(IN_ATTACK)
			and not IsCallerRagdolled(owner)

		if canContinue and owner.organism then
			canContinue = not owner.organism.otrub and not owner.organism.incapacitated
		end

		if not canContinue then
			self:CancelCall(IsCallerRagdolled(owner) and "ragdolled" or "released")
		elseif not self:CanStartCall() then
			self:CancelCall("round_state")
		elseif not self.CallAudioStarted then
			if CurTime() >= self:GetCallStartedAt() then self:BeginCallAudio() end
		elseif CurTime() - self:GetCallStartedAt() >= self.CallDuration then
			self:CompleteCall()
		end
	end

	self:NextThink(CurTime())
	return true
end

function SWEP:Holster()
	if SERVER and self:GetCalling() then self:CancelCall("holstered") end
	return true
end

function SWEP:OnDrop()
	self.FoxPhoneDropped = true
	if SERVER then self:SendFoxAlert(2, self:GetPos()) end
	if SERVER and self:GetCalling() then self:CancelCall("dropped") end
end

function SWEP:OwnerChanged()
	if SERVER then self:SendFoxAlert(2, self:GetPos()) end
	if SERVER and self:GetCalling() then self:CancelCall("owner_changed") end
end

function SWEP:OnRemove()
	if SERVER then self:SendFoxAlert(2, self:GetPos()) end
	if SERVER and self:GetCalling() then self:CancelCall("removed") end
	if SERVER and HMCDActivePolicePhone == self then HMCDActivePolicePhone = nil end

	if CLIENT and IsValid(self.model) then
		self.model:Remove()
		self.model = nil
	end
end

if CLIENT then
	surface.CreateFont("HMCDPhoneScreen", {
		font = "Ari-W9500",
		size = 64,
		weight = 650,
		outline = false
	})

	surface.CreateFont("HMCDPhoneScreenSmall", {
		font = "Ari-W9500",
		size = 43,
		weight = 600,
		outline = false
	})

	surface.CreateFont("HMCDPhoneHUDTitle", {
		font = "Trebuchet MS",
		size = 26,
		weight = 800,
		outline = true
	})

	surface.CreateFont("HMCDPhoneHUDSmall", {
		font = "Trebuchet MS",
		size = 19,
		weight = 650,
		outline = true
	})

	local foxIconDark = Material("chudmorse_phone/fox_call_dark.png", "smooth")
	local foxIconAlert = Material("chudmorse_phone/fox_call_alert.png", "smooth")
	local foxAlerts = {}
	local phoneJammedUntil = 0
	local phoneStatusTitle = ""
	local phoneStatusSubtitle = ""
	local phoneStatusUntil = 0

	net.Receive("HMCD_PhoneJammed", function()
		phoneJammedUntil = CurTime() + 3
	end)

	net.Receive("HMCD_PhoneStatus", function()
		phoneStatusTitle = net.ReadString()
		phoneStatusSubtitle = net.ReadString()
		phoneStatusUntil = CurTime() + math.max(net.ReadFloat(), 0.1)
	end)

	-- Hide this obsolete message if another installed copy of the phone still
	-- tries to print it. The current phone uses its HUD for the spent state.
	hook.Add("ChatText", "HMCDPhoneHideLegacySpentMessage", function(_, _, text)
		if string.Trim(text or "") == "The phone has already completed its one call." then
			return true
		end
	end)

	local function DrawProgressRing(x, y, innerRadius, outerRadius, progress, color)
		progress = math.Clamp(progress or 0, 0, 1)
		if progress <= 0 then return end

		local segments = 72
		local finalSegment = math.ceil(segments * progress)
		draw.NoTexture()
		surface.SetDrawColor(color)

		for i = 0, finalSegment - 1 do
			local firstFraction = i / segments
			local secondFraction = math.min((i + 1) / segments, progress)
			local firstAngle = math.rad(-90 + firstFraction * 360)
			local secondAngle = math.rad(-90 + secondFraction * 360)

			surface.DrawPoly({
				{x = x + math.cos(firstAngle) * innerRadius, y = y + math.sin(firstAngle) * innerRadius},
				{x = x + math.cos(firstAngle) * outerRadius, y = y + math.sin(firstAngle) * outerRadius},
				{x = x + math.cos(secondAngle) * outerRadius, y = y + math.sin(secondAngle) * outerRadius},
				{x = x + math.cos(secondAngle) * innerRadius, y = y + math.sin(secondAngle) * innerRadius}
			})
		end
	end

	local function DrawClippedMaterial(material, x, y, size, left, top, right, bottom, alpha)
		if right <= left or bottom <= top then return end

		render.SetScissorRect(math.floor(left), math.floor(top), math.ceil(right), math.ceil(bottom), true)
		surface.SetMaterial(material)
		surface.SetDrawColor(255, 255, 255, alpha or 255)
		surface.DrawTexturedRect(x, y, size, size)
		render.SetScissorRect(0, 0, 0, 0, false)
	end

	local function DrawFoxCallIcon(x, y, size, progress, alpha)
		progress = math.Clamp(progress or 0, 0, 1)
		alpha = alpha or 255
		surface.SetMaterial(foxIconDark)
		surface.SetDrawColor(255, 255, 255, alpha)
		surface.DrawTexturedRect(x, y, size, size)

		local fillBottom = y + size * progress
		DrawClippedMaterial(foxIconAlert, x, y, size, x, y, x + size, fillBottom, alpha)
	end

	local function StopFoxWarning(data)
		if data and data.warningSound then
			data.warningSound:Stop()
			data.warningSound = nil
		end
	end

	net.Receive("HMCD_PhoneFoxAlert", function()
		local eventCode = net.ReadUInt(2)
		local callID = net.ReadUInt(16)
		local caller = net.ReadEntity()
		local origin = net.ReadVector()
		local startedAt = net.ReadFloat()
		local duration = net.ReadFloat()

		if eventCode == 1 then
			if foxAlerts[callID] then StopFoxWarning(foxAlerts[callID]) end

			local warning = CreateSound(LocalPlayer(), "chudmorse_phone/warning.mp3")
			if warning then warning:PlayEx(1, 100) end

			foxAlerts[callID] = {
				caller = caller,
				origin = origin,
				startedAt = startedAt,
				duration = math.max(duration, 0.1),
				warningSound = warning
			}
			return
		end

		local data = foxAlerts[callID]
		if not data then return end

		if eventCode == 2 then
			StopFoxWarning(data)
			foxAlerts[callID] = nil
		elseif eventCode == 3 then
			data.origin = origin
			data.completed = true
			data.completedUntil = CurTime() + 5
		end
	end)

	hook.Add("HUDPaint", "HMCDPhoneFoxCallMarkers", function()
		if not IsValid(LocalPlayer()) then return end

		for callID, data in pairs(foxAlerts) do
			local phone = Entity(callID)
			local hasPhone = IsValid(phone) and phone:GetClass() == "weapon_police_phone"
			local destroyed = hasPhone and phone:IsPhoneDestroyed()
			local detached = hasPhone and not data.completed and
				(not IsValid(data.caller) or phone:GetOwner() ~= data.caller or data.caller:GetWeapon("weapon_police_phone") ~= phone)
			local expired = CurTime() > data.startedAt + data.duration + 5
			if destroyed or detached or expired or (data.completed and CurTime() >= data.completedUntil) then
				StopFoxWarning(data)
				foxAlerts[callID] = nil
			else
				local worldPos = data.origin
				if not data.completed and IsValid(data.caller) then
					worldPos = data.caller:WorldSpaceCenter() + Vector(0, 0, 20)
				end

				local progress = data.completed and 1 or math.Clamp((CurTime() - data.startedAt) / data.duration, 0, 1)
				local screenPos = worldPos:ToScreen()
				local size = math.Clamp(ScrH() * 0.07, 48, 78)
				local halfSize = size * 0.5
				local x = math.Clamp(screenPos.x, halfSize + 16, ScrW() - halfSize - 16)
				local y = math.Clamp(screenPos.y, halfSize + 16, ScrH() - halfSize - 54)

				local blinkAlpha = data.completed and (math.sin(CurTime() * 9) > 0 and 255 or 35) or 255
				DrawFoxCallIcon(x - halfSize, y - halfSize, size, progress, blinkAlpha)
			end
		end
	end)

	hook.Add("Think", "HMCDPhoneFoxCallCleanup", function()
		if not zb or zb.ROUND_STATE == 1 then return end

		for callID, data in pairs(foxAlerts) do
			StopFoxWarning(data)
			foxAlerts[callID] = nil
		end
	end)

	function SWEP:DrawHUD()
		local width, height = ScrW(), ScrH()
		local x, y = width * 0.5, height * 0.76

		if phoneJammedUntil > CurTime() then
			draw.SimpleText("SIGNAL JAMMED", "HMCDPhoneHUDTitle", x, y, Color(225, 225, 225), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText("ANOTHER PLAYER IS ON THE CALL", "HMCDPhoneHUDSmall", x, y + 29, Color(165, 165, 165), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			return
		end

		if phoneStatusUntil > CurTime() then
			draw.SimpleText(phoneStatusTitle, "HMCDPhoneHUDTitle", x, y, Color(225, 225, 225), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(phoneStatusSubtitle, "HMCDPhoneHUDSmall", x, y + 29, Color(165, 165, 165), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			return
		end

		if self:GetSpent() then
			draw.SimpleText("CALL COMPLETE", "HMCDPhoneHUDTitle", x, y, Color(175, 175, 175), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText("PHONE DISABLED", "HMCDPhoneHUDSmall", x, y + 29, Color(110, 110, 110), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			return
		end

		local calling = self:GetCalling()
		local dialing = calling and self:GetCallStartedAt() > CurTime()
		local progress = calling and not dialing and math.Clamp((CurTime() - self:GetCallStartedAt()) / self.CallDuration, 0, 1) or 0
		local radius = math.Clamp(height * 0.055, 42, 64)

		DrawProgressRing(x, y, radius - 7, radius, 1, Color(10, 20, 13, 220))
		DrawProgressRing(x, y, radius - 7, radius, progress, Color(36, 220, 84, 245))

		if dialing then
			draw.SimpleText(math.ceil(self:GetCallStartedAt() - CurTime()) .. "s", "HMCDPhoneHUDTitle", x, y, Color(236, 255, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText("CONNECTING - KEEP HOLDING", "HMCDPhoneHUDSmall", x, y + radius + 24, Color(236, 255, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		elseif calling then
			draw.SimpleText(math.floor(progress * 100) .. "%", "HMCDPhoneHUDTitle", x, y, Color(236, 255, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText("KEEP HOLDING LEFT CLICK", "HMCDPhoneHUDSmall", x, y + radius + 24, Color(236, 255, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		else
			draw.SimpleText("911", "HMCDPhoneHUDTitle", x, y, Color(236, 255, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText("HOLD LEFT CLICK TO CALL POLICE", "HMCDPhoneHUDSmall", x, y + radius + 24, Color(236, 255, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end
end

if CLIENT then
	local function InstallPhoneSlotEightCompatibility()
		if not hg or not hg.WeaponSelector then return end
		local selector = hg.WeaponSelector
		if selector.HMCDPhoneSlotEightPatched then return end

		selector.HMCDPhoneSlotEightPatched = true
		selector.GetWeaponTable = function(ply)
			if not IsValid(ply) or not ply:Alive() then return end

			local owned = ply:GetWeapons()
			local formatted = {}
			for slot = 0, 7 do formatted[slot] = {} end

			table.sort(owned, function(a, b)
				return (a.SlotPos or 0) > (b.SlotPos or 0)
			end)

			for _, wep in ipairs(owned) do
				local slot = math.Clamp(tonumber(wep.Slot) or 0, 0, 7)
				local slotTable = formatted[slot]
				local minimumPosition = math.min(tonumber(wep.SlotPos) or 1, #slotTable + 1) - 1
				local position = slotTable[minimumPosition] and #slotTable + 1 or minimumPosition
				slotTable[position] = wep
			end

			return formatted
		end
	end

	hook.Add("InitPostEntity", "HMCDPhoneInstallSlotEight", InstallPhoneSlotEightCompatibility)
	hook.Add("OnReloaded", "HMCDPhoneReinstallSlotEight", function()
		timer.Simple(0, InstallPhoneSlotEightCompatibility)
	end)
	timer.Simple(0, InstallPhoneSlotEightCompatibility)

	hook.Add("PlayerBindPress", "HMCDPhoneSelectSlotEight", function(ply, bind, pressed)
		if not pressed or bind ~= "slot8" or not IsValid(ply) or not ply:Alive() then return end
		local phone = ply:GetWeapon("weapon_police_phone")
		if not IsValid(phone) then return end

		InstallPhoneSlotEightCompatibility()
		local selector = hg and hg.WeaponSelector
		if not selector then return end

		local weaponsBySlot = selector.GetWeaponTable(ply)
		for position, wep in pairs(weaponsBySlot and weaponsBySlot[7] or {}) do
			if wep == phone then
				selector.SelectedSlot = 7
				selector.SelectedSlotPos = position
				selector.Show = CurTime() + 4
				return true
			end
		end
	end)
end

local function FoxPhoneSpeedBoostActive(ply)
	return IsValid(ply) and ply:GetNWFloat("HMCD_FoxPhoneSpeedBoostUntil", 0) > CurTime()
end

hook.Add("HG_MovementCalc_2", "HMCDPhoneFoxSpeedBoost", function(mul, ply)
	if not FoxPhoneSpeedBoostActive(ply) then return end

	mul[1] = mul[1] * ply:GetNWFloat("HMCD_FoxPhoneSpeedMultiplier", 1.25)
end)

hook.Add("SetupMove", "HMCDPhoneFoxSpeedBoostFallback", function(ply, moveData)
	if hg or not FoxPhoneSpeedBoostActive(ply) then return end

	local multiplier = ply:GetNWFloat("HMCD_FoxPhoneSpeedMultiplier", 1.25)
	moveData:SetMaxSpeed(moveData:GetMaxSpeed() * multiplier)
	moveData:SetMaxClientSpeed(moveData:GetMaxClientSpeed() * multiplier)
end)
