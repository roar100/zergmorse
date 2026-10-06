local MODE = MODE

print("[LastShift] sv_lastshift.lua reached")

MODE.name = "lastshift"
MODE.PrintName = "The Last Shift"
MODE.LootSpawn = true
MODE.Chance = 0

local OBJECTIVE_COUNT = 5
local OBJECTIVE_RADIUS = 175
local OBJECTIVE_TIME = 10
local MONSTER_RELEASE_TIME = 30
local BLACKOUT_TIME = 120
local EXIT_DISTANCE = 120


local STALK_DURATION = 4
local STALK_DISTANCE = 700

local objectives = {}
local lockedDoors = {}
local disabledLights = {}

local exitEntity
local monster

local completedObjectives = 0
local exitUnlocked = false
local blackoutStarted = false
local monsterReleased = false
local roundStartedAt = 0

local monsterStalking = false
local monsterStalkEnd = 0
local nextStalkEvent = 0

local nextMonsterThink = 0
local nextFakeEvent = 0
local nextObjectiveThink = 0

util.AddNetworkString("lastshift_start")
util.AddNetworkString("lastshift_progress")
util.AddNetworkString("lastshift_objective_timer")
util.AddNetworkString("lastshift_blackout")
util.AddNetworkString("lastshift_escape")
util.AddNetworkString("lastshift_event")
util.AddNetworkString("lastshift_end")

local objectiveNames = {
	"Reset the breaker",
	"Restore security controls",
	"Restart ventilation",
	"Restore communications",
	"Override the lockdown",
	"Restart the backup generator",
	"Reset the emergency system",
	"Restore the control terminal"
}

local fakeSounds = {
	"ambient/levels/prison/door_bolt.wav",
	"ambient/levels/labs/electric_explosion1.wav",
	"ambient/levels/labs/electric_explosion2.wav",
	"ambient/levels/citadel/weapon_disintegrate2.wav",
	"ambient/machines/thumper_hit.wav",
	"ambient/materials/metal_stress1.wav",
	"ambient/materials/metal_stress2.wav"
}

local function ActivePlayer(ply)
	return IsValid(ply)
		and ply:IsPlayer()
		and ply:Team() ~= TEAM_SPECTATOR
		and ply:Alive()
		and not ply.LastShiftEscaped
end

local function CleanupEntity(ent)
	if IsValid(ent) then
		ent:Remove()
	end
end

local function ResetObjectiveProgress(ply)
	if not IsValid(ply) then
		return
	end

	ply.LastShiftObjective = nil
	ply.LastShiftObjectiveStart = nil

	net.Start("lastshift_objective_timer")
		net.WriteBool(false)
	net.Send(ply)
end

local function RestoreMap()
	for _, ent in ipairs(disabledLights) do
		if IsValid(ent) then
			ent:Fire("TurnOn", "", 0)
		end
	end

	disabledLights = {}

	for _, ent in ipairs(lockedDoors) do
		if IsValid(ent) then
			ent:Fire("Unlock", "", 0)
		end
	end

	lockedDoors = {}
end

local function Cleanup()
	for _, ply in player.Iterator() do
		ResetObjectiveProgress(ply)
	end

	for _, ent in ipairs(objectives) do
		CleanupEntity(ent)
	end

	objectives = {}

	CleanupEntity(exitEntity)
	exitEntity = nil

	CleanupEntity(monster)
	monster = nil

	monsterStalking = false
	monsterStalkEnd = 0
	nextStalkEvent = 0

	RestoreMap()
end

local function GetMapPositions()
	local result = {}

	local groups = {
		"RandomSpawns",
		"HMCD_TDM_T",
		"HMCD_TDM_CT"
	}

	for _, group in ipairs(groups) do
		local points = zb.GetMapPoints(group)

		if not points then
			continue
		end

		for _, point in pairs(points) do
			if isvector(point) then
				result[#result + 1] = point
			elseif istable(point) then
				if isvector(point.pos) then
					result[#result + 1] = point.pos
				elseif isvector(point[1]) then
					result[#result + 1] = point[1]
				end
			end
		end
	end

	return result
end

local function GroundPosition(pos)
	local tr = util.TraceHull({
		start = pos + Vector(0, 0, 100),
		endpos = pos - Vector(0, 0, 400),
		mins = Vector(-16, -16, 0),
		maxs = Vector(16, 16, 64),
		mask = MASK_PLAYERSOLID
	})

	if tr.Hit then
		return tr.HitPos + Vector(0, 0, 4)
	end

	return pos
end

local function PositionNearPlayers(pos, distance)
	for _, ply in player.Iterator() do
		if ActivePlayer(ply) and ply:GetPos():DistToSqr(pos) < distance * distance then
			return true
		end
	end

	return false
end

local function SendProgress()
	net.Start("lastshift_progress")
		net.WriteUInt(completedObjectives, 4)
		net.WriteUInt(OBJECTIVE_COUNT, 4)
		net.WriteBool(exitUnlocked)
	net.Broadcast()
end

local function SpawnObjectives()
	local positions = GetMapPositions()

	table.Shuffle(positions)

	local used = 0

	for _, rawPos in ipairs(positions) do
		if used >= OBJECTIVE_COUNT then
			break
		end

		local pos = GroundPosition(rawPos)

		if PositionNearPlayers(pos, 250) then
			continue
		end

		local ent = ents.Create("prop_dynamic")

		if not IsValid(ent) then
			continue
		end

		ent:SetModel("models/props_lab/reciever01b.mdl")
		ent:SetPos(pos)
		ent:SetAngles(Angle(0, math.random(0, 359), 0))
		ent:Spawn()
		ent:Activate()

		used = used + 1

		local objectiveName = objectiveNames[math.random(#objectiveNames)]

		ent.LastShiftObjective = true
		ent.LastShiftCompleted = false
		ent.LastShiftObjectiveID = used
		ent.LastShiftObjectiveName = objectiveName

		ent:SetNWBool("LastShiftObjective", true)
		ent:SetNWBool("LastShiftCompleted", false)
		ent:SetNWInt("LastShiftObjectiveID", used)
		ent:SetNWString("LastShiftObjectiveName", objectiveName)
		ent:SetNWFloat("LastShiftObjectiveRadius", OBJECTIVE_RADIUS)

		objectives[#objectives + 1] = ent
	end

	if #objectives < OBJECTIVE_COUNT then
		print("[LastShift] WARNING: only spawned " .. #objectives .. " objectives")
	end
end

local function SpawnExit()
	local positions = GetMapPositions()

	if #positions == 0 then
		return
	end

	local selected

	for _, rawPos in RandomPairs(positions) do
		local pos = GroundPosition(rawPos)

		if not PositionNearPlayers(pos, 400) then
			selected = pos
			break
		end
	end

	selected = selected or GroundPosition(positions[#positions])

	exitEntity = ents.Create("prop_dynamic")

	if not IsValid(exitEntity) then
		return
	end

	exitEntity:SetModel("models/props_c17/door01_left.mdl")
	exitEntity:SetPos(selected)
	exitEntity:SetAngles(Angle(0, math.random(0, 359), 0))
	exitEntity:Spawn()
	exitEntity:Activate()

	exitEntity:SetColor(Color(120, 30, 30))
	exitEntity:SetNWBool("LastShiftExit", true)
	exitEntity:SetNWBool("LastShiftExitUnlocked", false)
end

local function FindMonsterSpawn()
	local positions = GetMapPositions()

	table.Shuffle(positions)

	for _, rawPos in ipairs(positions) do
		local pos = GroundPosition(rawPos)

		if not PositionNearPlayers(pos, 900) then
			return pos
		end
	end

	return positions[1] and GroundPosition(positions[1]) or Vector(0, 0, 0)
end

local function SpawnMonster()
	if IsValid(monster) then
		return
	end

	monster = ents.Create("npc_fastzombie")

	if not IsValid(monster) then
		print("[LastShift] monster spawn failed")
		return
	end

	monster:SetPos(FindMonsterSpawn())
	monster:SetAngles(Angle(0, math.random(0, 359), 0))
	monster:Spawn()
	monster:Activate()

	monster:SetMaxHealth(700)
	monster:SetHealth(700)

	monster.LastShiftMonster = true
	monsterReleased = true

	net.Start("lastshift_event")
		net.WriteString("released")
	net.Broadcast()
end

local function FindTarget()
	if not IsValid(monster) or monsterStalking or monster:GetNoDraw() then
		return
	end

	local target
	local closest = math.huge

	for _, ply in player.Iterator() do
		if not ActivePlayer(ply) then
			continue
		end

		local dist = monster:GetPos():DistToSqr(ply:GetPos())

		if dist < closest then
			closest = dist
			target = ply
		end
	end

	if IsValid(target) then
		monster:SetEnemy(target)
		monster:UpdateEnemyMemory(target, target:GetPos())
		monster:SetSchedule(SCHED_CHASE_ENEMY)
	end
end

local function GetStalkPosition(ply)
	if not IsValid(ply) then
		return nil
	end

	local ang = ply:EyeAngles()

	ang.pitch = 0
	ang.roll = 0

	local desired = ply:GetPos() - ang:Forward() * STALK_DISTANCE

	local tr = util.TraceHull({
		start = desired + Vector(0, 0, 120),
		endpos = desired - Vector(0, 0, 300),
		mins = Vector(-20, -20, 0),
		maxs = Vector(20, 20, 72),
		filter = ply,
		mask = MASK_PLAYERSOLID
	})

	if not tr.Hit then
		return nil
	end

	return tr.HitPos + Vector(0, 0, 4)
end

local function StartMonsterStare()
	if not IsValid(monster) or monsterStalking then
		return
	end

	local possible = {}

	for _, ply in player.Iterator() do
		if ActivePlayer(ply) then
			possible[#possible + 1] = ply
		end
	end

	if #possible == 0 then
		return
	end

	local target = possible[math.random(#possible)]
	local pos = GetStalkPosition(target)

	if not pos then
		nextStalkEvent = CurTime() + math.random(10, 20)
		return
	end

	monsterStalking = true
	monsterStalkEnd = CurTime() + STALK_DURATION

	monster:SetEnemy(NULL)
	monster:ClearEnemyMemory()
	monster:SetSchedule(SCHED_NONE)
	monster:SetPos(pos)

	local ang = (target:EyePos() - monster:WorldSpaceCenter()):Angle()

	ang.pitch = 0
	ang.roll = 0

	monster:SetAngles(ang)

	monster:SetMaterial("models/debug/debugwhite")
	monster:SetColor(Color(0, 0, 0, 255))
	monster:SetRenderMode(RENDERMODE_NORMAL)
	monster:SetNoDraw(false)
	monster:SetMoveType(MOVETYPE_NONE)

	monster.LastShiftStareTarget = target

	net.Start("lastshift_event")
		net.WriteString("stare")
	net.Send(target)
end

local function EndMonsterStare()
	if not IsValid(monster) then
		monsterStalking = false
		return
	end

	monsterStalking = false
	monster.LastShiftStareTarget = nil

	monster:SetNoDraw(true)
	monster:SetMoveType(MOVETYPE_NONE)

	timer.Simple(math.Rand(5, 10), function()
		if not IsValid(monster) then
			return
		end

		if zb.CROUND ~= "lastshift" or zb.ROUND_STATE ~= 1 then
			return
		end

		monster:SetPos(FindMonsterSpawn())
		monster:SetNoDraw(false)
		monster:SetMaterial("")
		monster:SetColor(Color(255, 255, 255, 255))
		monster:SetRenderMode(RENDERMODE_NORMAL)
		monster:SetMoveType(MOVETYPE_STEP)
		monster:SetEnemy(NULL)
		monster:ClearEnemyMemory()
	end)

	if blackoutStarted then
		nextStalkEvent = CurTime() + math.random(12, 25)
	else
		nextStalkEvent = CurTime() + math.random(25, 50)
	end
end

local function UpdateMonsterStare()
	if not monsterStalking then
		return
	end

	if not IsValid(monster) then
		monsterStalking = false
		return
	end

	local target = monster.LastShiftStareTarget

	if IsValid(target) and ActivePlayer(target) then
		local ang = (target:EyePos() - monster:WorldSpaceCenter()):Angle()

		ang.pitch = 0
		ang.roll = 0

		monster:SetAngles(ang)
	end

	if CurTime() >= monsterStalkEnd then
		EndMonsterStare()
	end
end

local function LockRandomDoors()
	local doors = {}

	for _, class in ipairs({
		"prop_door_rotating",
		"func_door",
		"func_door_rotating"
	}) do
		for _, ent in ipairs(ents.FindByClass(class)) do
			doors[#doors + 1] = ent
		end
	end

	table.Shuffle(doors)

	local amount = math.min(math.floor(#doors * 0.25), 12)

	for i = 1, amount do
		local door = doors[i]

		if IsValid(door) then
			door:Fire("Lock", "", 0)
			lockedDoors[#lockedDoors + 1] = door
		end
	end
end

local function DisableMapLights()
	for _, class in ipairs({
		"light",
		"light_spot",
		"light_dynamic"
	}) do
		for _, ent in ipairs(ents.FindByClass(class)) do
			if IsValid(ent) then
				ent:Fire("TurnOff", "", 0)
				disabledLights[#disabledLights + 1] = ent
			end
		end
	end
end

local function StartBlackout()
	if blackoutStarted then
		return
	end

	blackoutStarted = true

	DisableMapLights()

	if IsValid(monster) then
		monster:SetMaxHealth(1000)
		monster:SetHealth(math.max(monster:Health(), 1000))
	end

	nextStalkEvent = math.min(
		nextStalkEvent,
		CurTime() + math.random(8, 15)
	)

	net.Start("lastshift_blackout")
	net.Broadcast()
end

local function FakeEvent()
	local players = {}

	for _, ply in player.Iterator() do
		if ActivePlayer(ply) then
			players[#players + 1] = ply
		end
	end

	if #players == 0 then
		return
	end

	local ply = players[math.random(#players)]

	local ang = ply:EyeAngles()

	ang.pitch = 0

	local pos = ply:GetPos() - ang:Forward() * math.random(250, 650)

	pos = pos + VectorRand() * 100

	sound.Play(
		fakeSounds[math.random(#fakeSounds)],
		pos,
		75,
		math.random(85, 110),
		0.8
	)
end

local function CompleteObjective(ply, objective)
	if not IsValid(objective) or objective.LastShiftCompleted then
		return
	end

	objective.LastShiftCompleted = true
	objective:SetNWBool("LastShiftCompleted", true)
	objective:SetColor(Color(40, 180, 70))

	completedObjectives = completedObjectives + 1

	for _, other in player.Iterator() do
		if other.LastShiftObjective == objective then
			ResetObjectiveProgress(other)
		end
	end

	if completedObjectives >= OBJECTIVE_COUNT then
		exitUnlocked = true

		if IsValid(exitEntity) then
			exitEntity:SetColor(Color(40, 200, 70))
			exitEntity:SetNWBool("LastShiftExitUnlocked", true)
		end

		for _, door in ipairs(lockedDoors) do
			if IsValid(door) then
				door:Fire("Unlock", "", 0)
			end
		end

		lockedDoors = {}

		net.Start("lastshift_event")
			net.WriteString("exit")
		net.Broadcast()
	end

	SendProgress()
end

local function StartObjectiveProgress(ply, objective)
	ply.LastShiftObjective = objective
	ply.LastShiftObjectiveStart = CurTime()

	net.Start("lastshift_objective_timer")
		net.WriteBool(true)
		net.WriteEntity(objective)
		net.WriteString(objective.LastShiftObjectiveName or "Restore system")
		net.WriteFloat(OBJECTIVE_TIME)
	net.Send(ply)
end

local function UpdateObjectiveZones()
	for _, ply in player.Iterator() do
		if not ActivePlayer(ply) then
			if ply.LastShiftObjective then
				ResetObjectiveProgress(ply)
			end

			continue
		end

		local found
		local closestDistance = OBJECTIVE_RADIUS * OBJECTIVE_RADIUS

		for _, objective in ipairs(objectives) do
			if not IsValid(objective) or objective.LastShiftCompleted then
				continue
			end

			local distance = ply:GetPos():DistToSqr(objective:GetPos())

			if distance <= closestDistance then
				found = objective
				closestDistance = distance
			end
		end

		if not IsValid(found) then
			if ply.LastShiftObjective then
				ResetObjectiveProgress(ply)
			end

			continue
		end

		if ply.LastShiftObjective ~= found then
			ResetObjectiveProgress(ply)
			StartObjectiveProgress(ply, found)
			continue
		end

		if not ply.LastShiftObjectiveStart then
			StartObjectiveProgress(ply, found)
			continue
		end

		if CurTime() - ply.LastShiftObjectiveStart >= OBJECTIVE_TIME then
			CompleteObjective(ply, found)
		end
	end
end

local function CheckExit()
	if not exitUnlocked or not IsValid(exitEntity) then
		return
	end

	for _, ply in player.Iterator() do
		if not ActivePlayer(ply) then
			continue
		end

		if ply:GetPos():DistToSqr(exitEntity:GetPos()) <= EXIT_DISTANCE * EXIT_DISTANCE then
			ply.LastShiftEscaped = true

			ResetObjectiveProgress(ply)

			net.Start("lastshift_escape")
			net.Send(ply)

			ply:KillSilent()
		end
	end
end

function MODE.GuiltCheck()
	return 1, true
end

function MODE:CanLaunch()
	local amount = 0

	for _, ply in player.Iterator() do
		if ply:Team() ~= TEAM_SPECTATOR then
			amount = amount + 1
		end
	end

	return amount >= 1
end

function MODE:Intermission()
	game.CleanUpMap()

	Cleanup()

	completedObjectives = 0
	exitUnlocked = false
	blackoutStarted = false
	monsterReleased = false
	monsterStalking = false
	roundStartedAt = 0

	for _, ply in player.Iterator() do
		ply.LastShiftEscaped = false
		ply.LastShiftObjective = nil
		ply.LastShiftObjectiveStart = nil

		if ply:Team() ~= TEAM_SPECTATOR then
			ply:SetupTeam(0)
		end
	end
end

function MODE:GiveEquipment()
	for _, ply in player.Iterator() do
		if ply:Team() == TEAM_SPECTATOR then
			continue
		end

		ply:SetupTeam(0)

		ply.LastShiftEscaped = false
		ply.LastShiftObjective = nil
		ply.LastShiftObjectiveStart = nil

		zb.GiveRole(
			ply,
			"Night Shift Worker",
			Color(190, 190, 190)
		)
	end
end

function MODE:GetTeamSpawn()
	local spawn = zb.TranslatePointsToVectors(
		zb.GetMapPoints("RandomSpawns")
	)

	local fallback = zb.TranslatePointsToVectors(
		zb.GetMapPoints("HMCD_TDM_T")
	)

	return spawn, fallback
end

function MODE:RoundStart()
	Cleanup()

	roundStartedAt = CurTime()

	completedObjectives = 0
	exitUnlocked = false
	blackoutStarted = false
	monsterReleased = false
	monsterStalking = false

	nextMonsterThink = CurTime()
	nextFakeEvent = CurTime() + math.random(18, 30)
	nextObjectiveThink = CurTime()
	nextStalkEvent = CurTime() + math.random(35, 55)

	for _, ply in player.Iterator() do
		ply.LastShiftEscaped = false
		ply.LastShiftObjective = nil
		ply.LastShiftObjectiveStart = nil
	end

	SpawnObjectives()
	SpawnExit()
	LockRandomDoors()

	net.Start("lastshift_start")
		net.WriteUInt(OBJECTIVE_COUNT, 4)
	net.Broadcast()

	SendProgress()
end

function MODE:RoundThink()
	if roundStartedAt <= 0 then
		return
	end

	local elapsed = CurTime() - roundStartedAt
	local remaining = self.ROUND_TIME - elapsed

	if not monsterReleased and elapsed >= MONSTER_RELEASE_TIME then
		SpawnMonster()
	end

	if IsValid(monster) then
		if monsterStalking then
			UpdateMonsterStare()
		elseif CurTime() >= nextStalkEvent then
			StartMonsterStare()
		elseif nextMonsterThink <= CurTime() then
			nextMonsterThink = CurTime() + (blackoutStarted and 0.5 or 1.5)
			FindTarget()
		end
	end

	if nextObjectiveThink <= CurTime() then
		nextObjectiveThink = CurTime() + 0.1

		UpdateObjectiveZones()
		CheckExit()
	end

	if nextFakeEvent <= CurTime() then
		if blackoutStarted then
			nextFakeEvent = CurTime() + math.random(8, 16)
		else
			nextFakeEvent = CurTime() + math.random(18, 35)
		end

		FakeEvent()
	end

	if not blackoutStarted and remaining <= BLACKOUT_TIME then
		StartBlackout()
	end
end

function MODE:ShouldRoundEnd()
	local alive = 0

	for _, ply in player.Iterator() do
		if ply:Team() == TEAM_SPECTATOR then
			continue
		end

		if not ply.LastShiftEscaped and ply:Alive() then
			alive = alive + 1
		end
	end

	if alive <= 0 then
		return true
	end

	if roundStartedAt > 0 and CurTime() >= roundStartedAt + self.ROUND_TIME then
		return true
	end

	return false
end

function MODE:EndRound()
	net.Start("lastshift_end")
	net.Broadcast()

	Cleanup()

	roundStartedAt = 0
end
--toodles--
