local MODE = MODE

MODE.name = "lastshift"
MODE.PrintName = "The Last Shift"

local INTRO_DURATION = 8
local OBJECTIVE_RADIUS = 180

local totalObjectives = 5
local completedObjectives = 0

local exitUnlocked = false
local blackout = false
local escaped = false

local introStart = -math.huge
local blackoutStart = -math.huge

local activeObjective
local objectiveName = ""
local objectiveStart = 0
local objectiveDuration = 10

local introMusic

MODE.DynamicFadeScreenEndTime = 0
MODE.CursorLerpX = 0
MODE.CursorLerpY = 0
MODE.RoundTextTilts = {}

local ringMaterial = Material("cable/redlaser")
local glowMaterial = Material("sprites/glow04_noz")

local fontFace = "Lora"

if GetConVar("hg_font") and GetConVar("hg_font"):GetString() ~= "" then
	fontFace = GetConVar("hg_font"):GetString()
end

surface.CreateFont("LastShift_Header", {
	font = fontFace,
	size = ScreenScale(34),
	weight = 500,
	antialias = true
})

surface.CreateFont("LastShift_SubHeader", {
	font = fontFace,
	size = ScreenScale(20),
	weight = 500,
	antialias = true
})

surface.CreateFont("LastShift_Body", {
	font = fontFace,
	size = ScreenScale(13),
	weight = 500,
	antialias = true
})

surface.CreateFont("LastShift_Small", {
	font = fontFace,
	size = ScreenScale(10),
	weight = 500,
	antialias = true
})

local function StopIntroMusic()
	if introMusic then
		introMusic:Stop()
		introMusic = nil
	end
end

local function StartIntroMusic()
	StopIntroMusic()

	introMusic = CreateSound(LocalPlayer(), "snd_jack_hmcd_shining.mp3")

	if introMusic then
		introMusic:PlayEx(0.75, 88)
	end

	timer.Simple(INTRO_DURATION - 1, function()
		if introMusic then
			introMusic:FadeOut(2)
		end
	end)
end

local function Reset()
	totalObjectives = 5
	completedObjectives = 0

	exitUnlocked = false
	blackout = false
	escaped = false

	introStart = -math.huge
	blackoutStart = -math.huge

	activeObjective = nil
	objectiveName = ""
	objectiveStart = 0
	objectiveDuration = 10

	MODE.DynamicFadeScreenEndTime = 0

	StopIntroMusic()
end

local function EaseOut(value)
	return 1 - (1 - value) ^ 3
end

local function IntroActive()
	return CurTime() - introStart < INTRO_DURATION
end

local function DrawShadowText(text, font, x, y, col, ax, ay)
	draw.SimpleText(
		text,
		font,
		x + 2,
		y + 2,
		Color(0, 0, 0, math.min(col.a or 255, 180)),
		ax,
		ay
	)

	draw.SimpleText(
		text,
		font,
		x,
		y,
		col,
		ax,
		ay
	)
end

local function DrawTiltedText(text, font, x, y, color, alpha, angle)
	local matrix = Matrix()

	matrix:Translate(Vector(x, y, 0))
	matrix:Rotate(Angle(0, angle or 0, 0))
	matrix:Translate(Vector(-x, -y, 0))

	cam.PushModelMatrix(matrix)

	DrawShadowText(
		text,
		font,
		x,
		y,
		Color(color.r, color.g, color.b, alpha),
		TEXT_ALIGN_CENTER,
		TEXT_ALIGN_CENTER
	)

	cam.PopModelMatrix()
end

net.Receive("lastshift_start", function()
	totalObjectives = net.ReadUInt(4)

	completedObjectives = 0
	exitUnlocked = false
	blackout = false
	escaped = false

	activeObjective = nil
	objectiveName = ""
	objectiveStart = 0

	introStart = CurTime()

	MODE.DynamicFadeScreenEndTime = CurTime() + INTRO_DURATION
	MODE.CursorLerpX = 0
	MODE.CursorLerpY = 0
	MODE.RoundTextTilts = {}

	for i = 1, 3 do
		MODE.RoundTextTilts[i] = math.random() < 0.5 and 2 or -2
	end

	if zb and zb.RemoveFade then
		zb.RemoveFade()
	end

	StartIntroMusic()
end)

net.Receive("lastshift_progress", function()
	completedObjectives = net.ReadUInt(4)
	totalObjectives = net.ReadUInt(4)
	exitUnlocked = net.ReadBool()
end)

net.Receive("lastshift_objective_timer", function()
	local active = net.ReadBool()

	if not active then
		activeObjective = nil
		objectiveName = ""
		objectiveStart = 0
		return
	end

	activeObjective = net.ReadEntity()
	objectiveName = net.ReadString()
	objectiveDuration = net.ReadFloat()
	objectiveStart = CurTime()
end)

net.Receive("lastshift_blackout", function()
	blackout = true
	blackoutStart = CurTime()
end)

net.Receive("lastshift_escape", function()
	escaped = true
	activeObjective = nil
end)

net.Receive("lastshift_event", function()
	local event = net.ReadString()

	if event == "released" then
		chat.AddText(Color(150, 30, 30), "Something is inside the building.")
	elseif event == "exit" then
		chat.AddText(Color(60, 210, 90), "The emergency exit is unlocked.")
	elseif event == "stare" then
		surface.PlaySound("ambient/atmosphere/cave_hit5.wav")
	end
end)

net.Receive("lastshift_end", function()
	Reset()
end)

local function DrawObjectiveHUD()
	if escaped then
		return
	end

	local x = 24
	local y = 24
	local w = 325
	local h = 102

	local progress = 0

	if totalObjectives > 0 then
		progress = completedObjectives / totalObjectives
	end

	draw.RoundedBox(10, x, y, w, h, Color(0, 0, 0, 155))
	draw.RoundedBox(10, x + 2, y + 2, w - 4, h - 4, Color(8, 8, 8, 225))

	DrawShadowText(
		"THE LAST SHIFT",
		"LastShift_SubHeader",
		x + 16,
		y + 12,
		Color(235, 235, 235, 255),
		TEXT_ALIGN_LEFT,
		TEXT_ALIGN_TOP
	)

	DrawShadowText(
		"OBJECTIVES",
		"LastShift_Small",
		x + 16,
		y + 38,
		Color(110, 110, 110, 255),
		TEXT_ALIGN_LEFT,
		TEXT_ALIGN_TOP
	)

	local barX = x + 16
	local barY = y + 58
	local barW = w - 32
	local barH = 14

	draw.RoundedBox(6, barX, barY, barW, barH, Color(28, 28, 28, 255))

	if progress > 0 then
		draw.RoundedBox(
			6,
			barX + 2,
			barY + 2,
			(barW - 4) * progress,
			barH - 4,
			Color(45, 205, 85, 255)
		)
	end

	DrawShadowText(
		completedObjectives .. " / " .. totalObjectives .. " SYSTEMS RESTORED",
		"LastShift_Body",
		barX,
		barY + 21,
		Color(220, 220, 220, 255),
		TEXT_ALIGN_LEFT,
		TEXT_ALIGN_TOP
	)

	local pillText = exitUnlocked and "EXIT UNLOCKED" or "EXIT LOCKED"
	local pillColor = exitUnlocked and Color(55, 220, 90, 255) or Color(175, 65, 65, 255)

	draw.RoundedBox(6, x + w - 118, y + h - 28, 100, 18, Color(18, 18, 18, 255))

	DrawShadowText(
		pillText,
		"LastShift_Small",
		x + w - 68,
		y + h - 19,
		pillColor,
		TEXT_ALIGN_CENTER,
		TEXT_ALIGN_CENTER
	)
end

local function DrawObjectiveTimer()
	if not IsValid(activeObjective) then
		return
	end

	local elapsed = CurTime() - objectiveStart
	local progress = math.Clamp(elapsed / math.max(objectiveDuration, 0.01), 0, 1)
	local timeLeft = math.max(objectiveDuration - elapsed, 0)

	local w = 380
	local h = 72
	local x = ScrW() * 0.5 - w * 0.5
	local y = ScrH() * 0.79

	draw.RoundedBox(10, x, y, w, h, Color(0, 0, 0, 165))
	draw.RoundedBox(10, x + 2, y + 2, w - 4, h - 4, Color(8, 8, 8, 235))

	DrawShadowText(
		objectiveName,
		"LastShift_Body",
		ScrW() * 0.5,
		y + 14,
		Color(228, 228, 228, 255),
		TEXT_ALIGN_CENTER,
		TEXT_ALIGN_CENTER
	)

	DrawShadowText(
		"STAY INSIDE THE ZONE",
		"LastShift_Small",
		ScrW() * 0.5,
		y + 29,
		Color(70, 220, 100, 255),
		TEXT_ALIGN_CENTER,
		TEXT_ALIGN_CENTER
	)

	local barX = x + 16
	local barY = y + 45
	local barW = w - 32
	local barH = 12

	draw.RoundedBox(6, barX, barY, barW, barH, Color(30, 30, 30, 255))
	draw.RoundedBox(6, barX + 2, barY + 2, (barW - 4) * progress, barH - 4, Color(55, 205, 85, 255))

	DrawShadowText(
		string.format("%.1f", timeLeft),
		"LastShift_Small",
		ScrW() * 0.5,
		y + 59,
		Color(255, 255, 255, 255),
		TEXT_ALIGN_CENTER,
		TEXT_ALIGN_CENTER
	)
end

local function DrawIntro()
	local elapsed = CurTime() - introStart

	if elapsed < 0 or elapsed > INTRO_DURATION then
		return
	end

	local sw = ScrW()
	local sh = ScrH()

	local remaining = INTRO_DURATION - elapsed
	local backgroundFade = math.min(remaining / 2.5, 1)
	local outFade = math.Clamp(remaining / 1.5, 0, 1)

	surface.SetDrawColor(0, 0, 0, 255 * backgroundFade)
	surface.DrawRect(0, 0, sw, sh)

	MODE.CursorLerpX = Lerp(
		FrameTime() * 6,
		MODE.CursorLerpX or 0,
		(gui.MouseX() - sw * 0.5) / (sw * 0.5)
	)

	MODE.CursorLerpY = Lerp(
		FrameTime() * 6,
		MODE.CursorLerpY or 0,
		(gui.MouseY() - sh * 0.5) / (sh * 0.5)
	)

	local cursorReach = ScreenScale(5)

	local cursorX = math.Clamp(MODE.CursorLerpX, -1, 1) * cursorReach
	local cursorY = math.Clamp(MODE.CursorLerpY, -1, 1) * cursorReach

	local elements = {
		{
			text = "THE LAST SHIFT",
			font = "LastShift_Header",
			color = Color(220, 220, 220),
			x = sw * 0.5,
			y = sh * 0.22,
			dir = "left",
			delay = 0,
			parallax = 0.8,
			tilt = true
		},
		{
			text = "You are a Night Shift Worker",
			font = "LastShift_SubHeader",
			color = Color(130, 130, 130),
			x = sw * 0.5,
			y = sh * 0.50,
			dir = "right",
			delay = 0.7,
			parallax = 1.0,
			tilt = true
		},
		{
			text = "Restore all 5 systems and reach the emergency exit.",
			font = "LastShift_Body",
			color = Color(210, 210, 210),
			x = sw * 0.5,
			y = sh * 0.80,
			dir = "bottom",
			delay = 1.3,
			parallax = 1.2,
			tilt = false
		}
	}

	for index, element in ipairs(elements) do
		local appear = EaseOut(math.Clamp((elapsed - element.delay) / 1.8, 0, 1))
		local alpha = 255 * appear * outFade

		if alpha <= 1 then
			continue
		end

		local slide = 1 - appear

		local drawX = element.x + cursorX * element.parallax
		local drawY = element.y + cursorY * element.parallax

		if element.dir == "left" then
			drawX = drawX - slide * ScreenScale(160)
		elseif element.dir == "right" then
			drawX = drawX + slide * ScreenScale(160)
		elseif element.dir == "bottom" then
			drawY = drawY + slide * ScreenScale(80)
		end

		local angle = 0

		if element.tilt then
			angle = (MODE.RoundTextTilts[index] or 2) * appear
		end

		DrawTiltedText(
			element.text,
			element.font,
			drawX,
			drawY,
			element.color,
			alpha,
			angle
		)
	end
end

local function DrawBlackout()
	if not blackout or escaped or IntroActive() then
		return
	end

	local pulse = math.sin(CurTime() * 1.8)

	surface.SetDrawColor(0, 0, 0, 70 + pulse * 10)
	surface.DrawRect(0, 0, ScrW(), ScrH())

	local elapsed = CurTime() - blackoutStart

	if elapsed < 6 then
		local alpha = 255 * math.Clamp((6 - elapsed) / 2, 0, 1)

		DrawShadowText(
			"POWER FAILURE",
			"LastShift_Header",
			ScrW() * 0.5,
			ScrH() * 0.15,
			Color(170, 25, 25, alpha),
			TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER
		)
	end
end

local function DrawEscape()
	if not escaped then
		return
	end

	surface.SetDrawColor(0, 0, 0, 230)
	surface.DrawRect(0, 0, ScrW(), ScrH())

	DrawShadowText(
		"YOU ESCAPED",
		"LastShift_Header",
		ScrW() * 0.5,
		ScrH() * 0.45,
		Color(65, 210, 90, 255),
		TEXT_ALIGN_CENTER,
		TEXT_ALIGN_CENTER
	)

	DrawShadowText(
		"Waiting for the shift to end.",
		"LastShift_Body",
		ScrW() * 0.5,
		ScrH() * 0.54,
		Color(185, 185, 185, 255),
		TEXT_ALIGN_CENTER,
		TEXT_ALIGN_CENTER
	)
end

local function DrawObjectiveCircle(ent)
	if not IsValid(ent) then
		return
	end

	if not ent:GetNWBool("LastShiftObjective", false) then
		return
	end

	if ent:GetNWBool("LastShiftCompleted", false) then
		return
	end

	local radius = ent:GetNWFloat("LastShiftObjectiveRadius", OBJECTIVE_RADIUS)
	local center = ent:GetPos() + Vector(0, 0, 6)
	local top = center + Vector(0, 0, 2600)

	local pulse = 0.75 + math.sin(CurTime() * 2.5) * 0.25
	local beamWidthOuter = 24 + math.sin(CurTime() * 2) * 4
	local beamWidthInner = 8 + math.sin(CurTime() * 2.4) * 2

	render.SetMaterial(ringMaterial)

	render.DrawBeam(
		center,
		top,
		beamWidthOuter,
		0,
		1,
		Color(25, 255, 65, 105)
	)

	render.DrawBeam(
		center,
		top,
		beamWidthInner,
		0,
		1,
		Color(130, 255, 150, 230)
	)

	render.SetMaterial(glowMaterial)

	render.DrawSprite(
		center + Vector(0, 0, 20),
		48 + pulse * 18,
		48 + pulse * 18,
		Color(65, 255, 100, 230)
	)

	render.DrawSprite(
		top,
		100 + pulse * 30,
		100 + pulse * 30,
		Color(80, 255, 110, 190)
	)

	local segments = 56
	local lastPoint

	render.SetMaterial(ringMaterial)

	for i = 0, segments do
		local angle = math.rad((i / segments) * 360)

		local point = center + Vector(
			math.cos(angle) * radius,
			math.sin(angle) * radius,
			0
		)

		if lastPoint then
			render.DrawBeam(
				lastPoint,
				point,
				10,
				0,
				1,
				Color(40, 255, 75, 235)
			)
		end

		lastPoint = point
	end

	render.DrawWireframeSphere(
		center,
		radius,
		32,
		2,
		Color(40, 255, 70, 35),
		true
	)
end

function MODE:PostDrawTranslucentRenderables(bDepth, bSkybox, isDraw3DSkybox)
	if bSkybox or isDraw3DSkybox then
		return
	end

	if IntroActive() then
		return
	end

	for _, ent in ipairs(ents.GetAll()) do
		if ent:GetNWBool("LastShiftObjective", false) then
			DrawObjectiveCircle(ent)
		end
	end
end

function MODE:HUDPaint()
	if IntroActive() then
		DrawIntro()
		return
	end

	DrawObjectiveHUD()
	DrawObjectiveTimer()
	DrawBlackout()
	DrawEscape()
end

function MODE:RenderScreenspaceEffects()
	local introRemaining = MODE.DynamicFadeScreenEndTime - CurTime()

	if introRemaining > 0 then
		if zb and zb.RemoveFade then
			zb.RemoveFade()
		end

		local fade = math.min(introRemaining / 2.5, 1)

		surface.SetDrawColor(0, 0, 0, 255 * fade)
		surface.DrawRect(0, 0, ScrW(), ScrH())

		return
	end

	DrawColorModify({
		["$pp_colour_addr"] = -0.02,
		["$pp_colour_addg"] = -0.02,
		["$pp_colour_addb"] = -0.02,
		["$pp_colour_brightness"] = blackout and -0.20 or -0.12,
		["$pp_colour_contrast"] = blackout and 1.35 or 1.20,
		["$pp_colour_colour"] = blackout and 0.18 or 0.42,
		["$pp_colour_mulr"] = 0,
		["$pp_colour_mulg"] = 0,
		["$pp_colour_mulb"] = 0
	})

	surface.SetDrawColor(0, 0, 0, blackout and 85 or 42)
	surface.DrawRect(0, 0, ScrW(), ScrH())
end

function MODE:RoundStart()
	escaped = false
	blackout = false
end

function MODE:EndRound()
	Reset()
end

hook.Add("ZB_EndRound", "LastShiftClientCleanup", function()
	Reset()
end)

hook.Add("Think", "LastShiftMusicCleanup", function()
	if zb.CROUND ~= "lastshift" then
		StopIntroMusic()
	end
end)

print("[LastShift] cl_lastshift.lua loaded OK")