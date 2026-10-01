local MODE = MODE
MODE.name = "bartvshomer"

print("[BartVsHomer] cl_bartvshomer.lua reached (CLIENT file, executing)")

local function Setup()
	local INTRO_DURATION = 6

	local introStartTime = -math.huge
	local introRole = 0

	surface.CreateFont("ZB_BvHTitle", {
		font = "Trebuchet MS",
		size = ScreenScale(42),
		weight = 900,
		antialias = true
	})

	surface.CreateFont("ZB_BvHRole", {
		font = "Trebuchet MS",
		size = ScreenScale(26),
		weight = 800,
		antialias = true
	})

	surface.CreateFont("ZB_BvHObjective", {
		font = "Trebuchet MS",
		size = ScreenScale(16),
		weight = 700,
		antialias = true
	})

	-- Homer health HUD (bottom right, visible to everyone all round).
	local HOMER_MAX_HEALTH = 235
	local HURT_FACE_DURATION = 0.5 -- how long the hurt face shows after a hit

	local homerCalmMat = Material("bartvshomer/homer_calm.png", "noclamp smooth")
	local homerHurtMat = Material("bartvshomer/homer_hurt.png", "noclamp smooth")

	-- If these print FAILED, the PNGs aren't where the game is looking:
	-- addons/chudmorse-main/materials/bartvshomer/homer_calm.png and
	-- homer_hurt.png -- materials/ sits next to gamemodes/ at the addon
	-- root, it is NOT inside the gamemodes folder.
	print("[BartVsHomer] homer_calm.png: " .. (homerCalmMat:IsError() and "FAILED TO LOAD" or "OK"))
	print("[BartVsHomer] homer_hurt.png: " .. (homerHurtMat:IsError() and "FAILED TO LOAD" or "OK"))

	local function IsBartVsHomerRoundActive()
		return (zb.CROUND_MAIN or zb.CROUND) == "bartvshomer"
	end

	local function DrawHomerHealthHUD()
		if not IsBartVsHomerRoundActive() then return end

		local health = math.Clamp(GetGlobalFloat("BvH_HomerHealth", HOMER_MAX_HEALTH), 0, HOMER_MAX_HEALTH)
		local lastHit = GetGlobalFloat("BvH_HomerLastHit", -1000)
		local hurt = (CurTime() - lastHit) < HURT_FACE_DURATION

		local sw, sh = ScrW(), ScrH()
		local size = math.min(sw, sh) * 0.12
		local barWidth = size * 1.6
		local barHeight = size * 0.22
		local margin = size * 0.3
		local gap = size * 0.08

		local barX = sw - margin - barWidth
		local barY = sh - margin - barHeight
		local portraitX = barX + (barWidth - size) * 0.5
		local portraitY = barY - gap - size

		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetMaterial(hurt and homerHurtMat or homerCalmMat)
		surface.DrawTexturedRect(portraitX, portraitY, size, size)

		draw.RoundedBox(4, barX, barY, barWidth, barHeight, Color(20, 20, 20, 210))

		local frac = health / HOMER_MAX_HEALTH
		if frac > 0 then
			local fillColor = frac > 0.5 and Color(80, 200, 90) or (frac > 0.25 and Color(230, 170, 40) or Color(210, 60, 50))
			draw.RoundedBox(4, barX + 2, barY + 2, (barWidth - 4) * frac, barHeight - 4, fillColor)
		end

		draw.SimpleText(
			math.ceil(health) .. " / " .. HOMER_MAX_HEALTH,
			"ZB_BvHObjective",
			barX + barWidth * 0.5,
			barY + barHeight * 0.5,
			color_white,
			TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER
		)
	end

	local roleData = {
		[0] = { -- Bart
			line = "You're a Bart",
			objective = "KILL HOMER",
			color = Color(255, 130, 0)
		},
		[1] = { -- Homer
			line = "You're Homer",
			objective = "KILL ALL THE BARTS",
			color = Color(90, 130, 220)
		}
	}

	local function easeOut(x)
		return 1 - (1 - x) ^ 3
	end

	net.Receive("bartvshomer_start", function()
		-- 0 = Bart, 1 = Homer.
		introRole = net.ReadUInt(1)
		introStartTime = CurTime()

		if zb and zb.RemoveFade then
			zb.RemoveFade()
		end
	end)

	local BVH_SOUNDS = {
		round_start = "bartvshomer/round_start.mp3",
		doh = "bartvshomer/homer_doh.mp3",
		woohoo = "bartvshomer/homer_woohoo.mp3"
	}

    local introMusic
    local function StopIntroMusic()
        if introMusic then introMusic:Stop() introMusic = nil end
    end
    hook.Add("Think", "BartVsHomerIntroCleanup", function()
        if zb.CROUND ~= "bartvshomer" then StopIntroMusic() end
    end)
    hook.Add("ZB_EndRound", "BartVsHomerIntroCleanup", StopIntroMusic)

	net.Receive("bartvshomer_sound", function()
		local key = net.ReadString()
		local path = BVH_SOUNDS[key]
        if key == "round_start" then
            StopIntroMusic()
            introMusic = CreateSound(LocalPlayer(), path)
            if introMusic then introMusic:PlayEx(1, 100) end
        elseif path then
            surface.PlaySound(path)
        end
	end)

	function MODE:HUDPaint()
		DrawHomerHealthHUD()

		local elapsed = CurTime() - introStartTime
		if elapsed < 0 or elapsed > INTRO_DURATION then return end

		local sw, sh = ScrW(), ScrH()
		local timeLeft = INTRO_DURATION - elapsed
		local backgroundFade = math.min(timeLeft / 2, 1)
		local outFade = math.Clamp(timeLeft / 1.2, 0, 1)

		surface.SetDrawColor(0, 0, 0, 255 * backgroundFade)
		surface.DrawRect(-1, -1, sw + 1, sh + 1)

		local data = roleData[introRole] or roleData[0]

		local elements = {
			{text = "Bart vs Homer", font = "ZB_BvHTitle", color = Color(255, 217, 0), y = sh * 0.32, delay = 0, fadeIn = 0.3},
			{text = data.line, font = "ZB_BvHRole", color = data.color, y = sh * 0.5, delay = 0.2, fadeIn = 0.35},
			{text = data.objective, font = "ZB_BvHObjective", color = color_white, y = sh * 0.6, delay = 0.4, fadeIn = 0.35}
		}

		for _, element in ipairs(elements) do
			local appear = easeOut(math.Clamp((elapsed - element.delay) / element.fadeIn, 0, 1))
			local alpha = 255 * appear * outFade

			if alpha > 1 then
				draw.SimpleText(
					element.text,
					element.font,
					sw * 0.5,
					element.y,
					Color(element.color.r, element.color.g, element.color.b, alpha),
					TEXT_ALIGN_CENTER,
					TEXT_ALIGN_CENTER
				)
			end
		end
	end

	function MODE:EndRound()
        StopIntroMusic()
		introStartTime = -math.huge
	end

	function MODE:RoundStart()
		-- The reveal is triggered by the bartvshomer_start net message instead.
	end
end

local ok, err = pcall(Setup)

if ok then
	print("[BartVsHomer] cl_bartvshomer.lua loaded OK")
else
	print("[BartVsHomer] !!! cl_bartvshomer.lua FAILED TO LOAD !!!")
	print("[BartVsHomer] Error: " .. tostring(err))
end
