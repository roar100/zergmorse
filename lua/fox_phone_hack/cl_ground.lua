local F = FoxPhoneHack
local signalVisuals = {}
    local scanPulse = {
        active = false,
        startedAt = 0,
        duration = 3.0,
        nextAt = 0,
        generation = 0
    }
    local SIGNAL_FADE_IN_TIME = 0.18
    local SIGNAL_FADE_OUT_TIME = 0.32
    local WAVE_TRAIL_FADE_IN_TIME = 0.18
    local WAVE_TRAIL_FADE_OUT_TIME = 0.28
    local WAVE_TRAIL_HOLD_TIME = 2.5
    local SCAN_PULSE_RADIUS = 1600
    local SCAN_PULSE_INTERVAL = 3
    local SCAN_PULSE_START_SPEED = 500
    -- 游戏里的扫描波是偏白的半透明材质，亮度交给渐隐曲线控制。
    local SCAN_WAVE_COLOR = Color(255, 255, 255, 112)
    local SCAN_DOT_SPACING = 24
    local SCAN_DOT_TILE_SIZE = 96
    local SCAN_DOT_TILES_PER_TICK = 16
    local SCAN_DOT_MAX_ALPHA = 105
    local SCAN_DOT_REVEAL_WIDTH = 160
    local SCAN_DOT_FADE_DELAY = 160
    local SCAN_DOT_FADE_WIDTH = 320
    local SCAN_DOT_BUILD_FADE_TIME = 0.2
    local scanDotMaterial = Material("sjz/decipherer/scan_dots_grid")
    local scanWaveMaterial = CreateMaterial("fox_phone_hack_scan_wave_translucent", "UnlitGeneric", {
        ["$basetexture"] = "vgui/white",
        ["$translucent"] = "1",
        ["$vertexcolor"] = "1",
        ["$vertexalpha"] = "1",
        ["$ignorez"] = "1"
    })

    local function SignalAlpha(visual, now)
        local progress = math.Clamp((now - visual.fadeStartedAt) / visual.fadeDuration, 0, 1)
        -- 缓入缓出；按实际时间计算，不受镜面、深度等重复渲染次数影响。
        progress = progress * progress * (3 - 2 * progress)
        return Lerp(progress, visual.fadeFromAlpha, visual.targetAlpha)
    end

    local function SetSignalVisibility(visual, targetAlpha, now)
        if visual.targetAlpha == targetAlpha then return end
        local alpha = SignalAlpha(visual, now)
        visual.alpha = alpha
        visual.fadeFromAlpha = alpha
        visual.fadeStartedAt = now
        visual.fadeDuration = targetAlpha > alpha and SIGNAL_FADE_IN_TIME or SIGNAL_FADE_OUT_TIME
        visual.targetAlpha = targetAlpha
    end

    local function WaveTrailAlpha(visual, targetAlpha, now)
        targetAlpha = targetAlpha > 0 and 1 or 0
        if visual.waveTarget == nil then
            visual.waveTarget = 0
            visual.waveAlpha = 0
            visual.waveFromAlpha = 0
            visual.waveFadeStartedAt = now
            visual.waveFadeDuration = WAVE_TRAIL_FADE_IN_TIME
        end

        if visual.waveTarget ~= targetAlpha then
            local progress = math.Clamp(
                (now - visual.waveFadeStartedAt) / math.max(visual.waveFadeDuration, 0.001),
                0,
                1
            )
            progress = progress * progress * (3 - 2 * progress)
            visual.waveAlpha = Lerp(progress, visual.waveFromAlpha, visual.waveTarget)
            visual.waveFromAlpha = visual.waveAlpha
            visual.waveFadeStartedAt = now
            visual.waveFadeDuration = targetAlpha > visual.waveAlpha
                and WAVE_TRAIL_FADE_IN_TIME
                or WAVE_TRAIL_FADE_OUT_TIME
            visual.waveTarget = targetAlpha
        end

        local progress = math.Clamp(
            (now - visual.waveFadeStartedAt) / math.max(visual.waveFadeDuration, 0.001),
            0,
            1
        )
        progress = progress * progress * (3 - 2 * progress)
        visual.waveAlpha = Lerp(progress, visual.waveFromAlpha, visual.waveTarget)
        return visual.waveAlpha
    end

    local function FadeOutSignals()
        local now = CurTime()
        for _, visual in pairs(signalVisuals) do
            SetSignalVisibility(visual, 0, now)
        end
    end

    local function StartScanPulse(now)
        scanPulse.generation = scanPulse.generation + 1
        scanPulse.active = true
        scanPulse.startedAt = now
        scanPulse.nextAt = now + SCAN_PULSE_INTERVAL
    end

    local function ScanPulseRadius(elapsed)
        local duration = scanPulse.duration
        local time = math.Clamp(elapsed, 0, duration)
        local maxRadius = SCAN_PULSE_RADIUS
        local startSpeed = SCAN_PULSE_START_SPEED
        local acceleration = 2 * (maxRadius - startSpeed * duration) / (duration * duration)
        return math.min(startSpeed * time + 0.5 * acceleration * time * time, maxRadius)
    end

    local function ScanPulseAlpha(radius)
        local progress = math.Clamp(radius / SCAN_PULSE_RADIUS, 0, 1)
        -- 连续平方衰减：15 米为起始 alpha 的 25%，30 米平滑降到零。
        return (1 - progress) ^ 2
    end

    -- 与 instinct.lua 的 BorderSphereUnit 保持同一套 stencil 球壳算法。
    -- 这不是一个脚下的二维圆环：最终颜色只会落在扫描球壳与当前深度
    -- 缓冲中的地面、墙面和模型表面的交线上。
    local SPHERE_NUMBER_RULES = {[0] = 2, [1] = 1, [3] = 2, [5] = 1, [7] = 2, [9] = 1}

    local function DrawInstinctStyleSphere(position, radius, color, ply)
        if radius <= 2 or not color or color.a <= 0 then return end

        radius = math.floor(radius)
        local thickness = math.min(math.floor(24), radius)
        local detail = math.min(math.floor(32), 100)
        if thickness >= radius then thickness = radius end

        local lastDigit = tonumber(string.sub(tostring(radius), -1))
        local ds = SPHERE_NUMBER_RULES[lastDigit] == 1 and 1
            or (SPHERE_NUMBER_RULES[lastDigit] == 2 and 0.50 or 0)
        local detailWithDs = detail + ds
        local radiusMinusThickness = radius - thickness

        local viewEntity = ply:GetViewEntity()
        local cameraPosition
        local cameraAngle
        if viewEntity == ply then
            cameraPosition = ply:EyePos()
            cameraAngle = ply:GetAimVector():Angle()
        elseif IsValid(viewEntity) then
            cameraPosition = viewEntity:GetPos()
            cameraAngle = viewEntity:GetAngles()
        else
            cameraPosition = ply:EyePos()
            cameraAngle = ply:GetAimVector():Angle()
        end

        local cameraNormal = cameraAngle:Forward()
        local invisibleColor = Color(0, 0, 0, 0)

        render.SetStencilEnable(true)
        render.SetStencilReferenceValue(0x55)
        render.SetStencilTestMask(0x1C)
        render.SetStencilWriteMask(0x1C)
        render.ClearStencil()
        -- 不继承其它 addon 留下的 stencil pass/fail 状态；球壳只利用 z-fail
        -- 反转/替换来记录与场景深度的交线。
        render.SetStencilPassOperation(STENCILOPERATION_KEEP)
        render.SetStencilFailOperation(STENCILOPERATION_KEEP)

        render.SetColorMaterial()
        render.SetStencilReferenceValue(1)
        render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_ALWAYS)
        render.SetStencilZFailOperation(STENCILOPERATION_INVERT)
        render.DrawSphere(position, -radius, detail, detail, invisibleColor)
        render.DrawSphere(position, radius, detail, detail, invisibleColor)
        render.DrawSphere(position, -radiusMinusThickness, detailWithDs, detailWithDs, invisibleColor)
        render.DrawSphere(position, radiusMinusThickness, detailWithDs, detailWithDs, invisibleColor)

        render.SetStencilZFailOperation(STENCILOPERATION_REPLACE)
        render.DrawSphere(position, radius + 0.25, detailWithDs, detailWithDs, invisibleColor)
        render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_NOTEQUAL)
        render.SetStencilReferenceValue(1)

        cam.IgnoreZ(true)
        render.SetBlend(1)
        render.SetColorModulation(1, 1, 1)
        -- 球壳仍用原来的深度求交，最终着色单独使用支持 alpha 混合的材质。
        render.SetMaterial(scanWaveMaterial)
        render.DrawQuadEasy(
            cameraPosition + cameraNormal * 10,
            -cameraNormal,
            10000,
            10000,
            color,
            cameraAngle.roll
        )

        -- 网点与扫描波共用同一枚 stencil 球壳：实体、墙面和模型表面都按
        -- 扫描波的求交结果着色，不再用单独地面网格的深度结果切断波面。
        scanDotMaterial:SetFloat("$alpha", 1)
        render.SetMaterial(scanDotMaterial)
        render.DrawQuadEasy(
            cameraPosition + cameraNormal * 10.02,
            -cameraNormal,
            10000,
            10000,
            Color(255, 255, 255, math.floor(math.min(color.a * 0.72, 82) + 0.5)),
            cameraAngle.roll
        )
        cam.IgnoreZ(false)
        render.SetBlend(1)
        render.SetColorModulation(1, 1, 1)
        render.SetStencilEnable(false)
    end

    -- 使用无纹理白底材质，避免 laserbeam 自带的彩色纹理和光晕。
    local navLineMaterial = CreateMaterial("fox_phone_hack_navline_white", "UnlitGeneric", {
        ["$basetexture"] = "vgui/white",
        ["$vertexcolor"] = "1",
        ["$vertexalpha"] = "1",
        ["$translucent"] = "1"
    })
    local COLOR_CLOSE_RADIUS = 530
    local COLOR_YELLOW_RADIUS = 1060
    local COLOR_MAX_RADIUS = 1600
    local SCAN_CLOSE_SOUND = "sjz/mxw/C202_Ultimate_SignalDecipher_UI_Scanned_Enemy_Close.wav"
    local SCAN_FAR_SOUND = "sjz/mxw/C202_Ultimate_SignalDecipher_UI_Scanned_Enemy_Far.wav"
    local SCAN_MARKER_SOUND = "sjz/mxw/C202_Ultimate_SignalDecipher_UI_Scanned_Marker.wav"

    local function GetSignalDisplayColor(distance)
        distance = tonumber(distance) or COLOR_MAX_RADIUS
        if distance <= COLOR_CLOSE_RADIUS then
            return Color(255, 65, 65, 235)
        elseif distance <= COLOR_YELLOW_RADIUS then
            local progress = math.Clamp(
                (distance - COLOR_CLOSE_RADIUS) / (COLOR_YELLOW_RADIUS - COLOR_CLOSE_RADIUS),
                0,
                1
            )
            return Color(
                255,
                math.floor(65 + (205 - 65) * progress + 0.5),
                math.floor(65 + (70 - 65) * progress + 0.5),
                230
            )
        end

        local progress = math.Clamp(
            (distance - COLOR_YELLOW_RADIUS) / (COLOR_MAX_RADIUS - COLOR_YELLOW_RADIUS),
            0,
            1
        )
        return Color(
            255,
            math.floor(205 + (255 - 205) * progress + 0.5),
            math.floor(70 + (255 - 70) * progress + 0.5),
            220
        )
    end

    local function FloorPosition(position, ignoredEntity)
        local ply = LocalPlayer()
        local trace = util.TraceLine({
            start = position + Vector(0, 0, 128),
            endpos = position - Vector(0, 0, 4096),
            filter = {ply, ignoredEntity},
            mask = MASK_SOLID
        })
        return trace.Hit and trace.HitPos + Vector(0, 0, 2) or position
    end

    -- 用重复纹理画密点；一个地形面包含多排点，不为每个点发射射线或画 sprite。
    -- UV 固定在世界 XY 坐标上，移动、转头、重复扫描都不会改变点的间距和位置。
    local groundDotGrid
    local function ReleaseGroundDots()
        groundDotGrid = nil
    end

    -- 热加载时也释放上一版的地形缓存。
    if FoxPhoneHack_ReleaseGroundDots then FoxPhoneHack_ReleaseGroundDots() end
    FoxPhoneHack_ReleaseGroundDots = ReleaseGroundDots
    hook.Add("ShutDown", "FoxPhoneHack_ReleaseGroundDots", ReleaseGroundDots)

    local function NewGroundDotGrid(origin, floorZ)
        ReleaseGroundDots()
        local tileSize = SCAN_DOT_TILE_SIZE
        local grid = {origin = origin, floorZ = floorZ, bands = {}, samples = {}, nextBand = 1}
        local extent = SCAN_PULSE_RADIUS + tileSize * 2
        for index = 1, math.ceil(extent / tileSize) do
            grid.bands[index] = {cells = {}, vertices = {}, nextCell = 1}
        end
        for x = math.floor((origin.x - SCAN_PULSE_RADIUS) / tileSize),
            math.floor((origin.x + SCAN_PULSE_RADIUS) / tileSize) do
            for y = math.floor((origin.y - SCAN_PULSE_RADIUS) / tileSize),
                math.floor((origin.y + SCAN_PULSE_RADIUS) / tileSize) do
                local dx = (x + 0.5) * tileSize - origin.x
                local dy = (y + 0.5) * tileSize - origin.y
                local distance = math.sqrt(dx * dx + dy * dy)
                if distance <= SCAN_PULSE_RADIUS + tileSize then
                    local band = grid.bands[math.floor(distance / tileSize) + 1]
                    band.cells[#band.cells + 1] = {x = x, y = y}
                end
            end
        end
        groundDotGrid = grid
        return grid
    end

    local function SampleDotGround(grid, x, y)
        grid.samples[x] = grid.samples[x] or {}
        local cached = grid.samples[x][y]
        if cached ~= nil then return cached end

        local worldX, worldY = x * SCAN_DOT_TILE_SIZE, y * SCAN_DOT_TILE_SIZE
        local traceStart = Vector(worldX, worldY, grid.floorZ + 96)
        local traceEnd = Vector(worldX, worldY, grid.floorZ - 1024)
        local traceFilter = {}
        local trace

        -- 可移动实体、func_brush 和部分静态模型会遮住向下采样的射线，
        -- 旧逻辑会把整个四边形单元丢掉，结果在波面上形成一大块断层。
        -- 逐层跳过实体，继续寻找实体下面真正的地面；世界笔刷仍然保留为边界。
        for _ = 1, 4 do
            trace = util.TraceLine({
                start = traceStart,
                endpos = traceEnd,
                filter = traceFilter,
                mask = MASK_SOLID
            })
            if not trace.Hit or trace.HitSky then break end

            local hitEntity = trace.Entity
            if not IsValid(hitEntity) or hitEntity:IsWorld() then break end
            traceFilter[#traceFilter + 1] = hitEntity
        end

        local sample = false
        if trace.Hit and not trace.HitSky and not trace.StartSolid and trace.HitNormal.z >= 0.65 then
            sample = {
                position = trace.HitPos + Vector(0, 0, 0.6), normal = trace.HitNormal,
                u = worldX / SCAN_DOT_SPACING, v = worldY / SCAN_DOT_SPACING
            }
        end
        grid.samples[x][y] = sample
        return sample
    end

    local function SameGroundPlane(a, b)
        local offset = b.position - a.position
        -- 台阶、悬崖和洞口不跨空连接；斜坡仍按实际地面倾斜。
        return math.abs(offset:Dot(a.normal)) <= 5 and math.abs(offset:Dot(b.normal)) <= 5
    end

    local function AddGroundDotTriangle(band, a, b, c)
        if not (a and b and c) then return false end
        if not (SameGroundPlane(a, b) and SameGroundPlane(b, c)
            and SameGroundPlane(c, a)) then
            return false
        end

        for _, vertex in ipairs({a, b, c}) do
            band.vertices[#band.vertices + 1] = vertex
        end
        return true
    end

    local function AddGroundDotCell(grid, band, cell)
        local a = SampleDotGround(grid, cell.x, cell.y)
        local b = SampleDotGround(grid, cell.x + 1, cell.y)
        local c = SampleDotGround(grid, cell.x + 1, cell.y + 1)
        local d = SampleDotGround(grid, cell.x, cell.y + 1)

        -- 正常四边形仍用原来的对角线。缺一个采样点时改用另一条对角线，
        -- 让实体边缘只少一个角，不再把整块单元和相邻点一起抹掉。
        local added = AddGroundDotTriangle(band, a, b, c)
        added = AddGroundDotTriangle(band, a, c, d) or added
        if not added then
            AddGroundDotTriangle(band, b, c, d)
            AddGroundDotTriangle(band, b, d, a)
        end
    end

    local function FinishGroundDotBand(band)
        -- 缓存几何和 UV；渲染时逐顶点插值 alpha，不能再让一整圈共用一个透明度。
        band.readyAt = CurTime()
        band.cells = nil
    end

    local function UpdateScanDotGrid(ply)
        local origin = ply:WorldSpaceCenter()
        local grid = groundDotGrid
        if not grid or grid.origin:DistToSqr(origin) > 192 * 192
            or math.abs(grid.floorZ - ply:GetPos().z) > 48 then
            grid = NewGroundDotGrid(origin, ply:GetPos().z)
        end

        -- 从近到远分帧采样，每帧最多 16 个地形面；不按密点数量增加开销。
        local budget = SCAN_DOT_TILES_PER_TICK
        while budget > 0 and grid.nextBand <= #grid.bands do
            local band = grid.bands[grid.nextBand]
            local cell = band.cells[band.nextCell]
            if cell then
                AddGroundDotCell(grid, band, cell)
                band.nextCell = band.nextCell + 1
                budget = budget - 1
            else
                FinishGroundDotBand(band)
                grid.nextBand = grid.nextBand + 1
            end
        end
    end

    local function ScanDotAlpha(distance, radius)
        local behindFront = radius - distance
        local reveal = math.Clamp(behindFront / SCAN_DOT_REVEAL_WIDTH, 0, 1)
        reveal = reveal * reveal * (3 - 2 * reveal)
        -- 渐隐边界跟随波前向外推进：中心先消失，然后是外面各圈。
        -- 每处地面根据波经过的距离独立淡出，不能用波的总进度让全部点一起变暗。
        local fade = math.Clamp((behindFront - SCAN_DOT_FADE_DELAY) / SCAN_DOT_FADE_WIDTH, 0, 1)
        fade = fade * fade * (3 - 2 * fade)
        return SCAN_DOT_MAX_ALPHA * ScanPulseAlpha(distance) * reveal * (1 - fade)
    end

    local function DrawScanDataDots(origin, radius)
        local grid = groundDotGrid
        if not grid or radius <= 8 then return end

        render.SetBlend(1)
        render.SetMaterial(scanDotMaterial)
        scanDotMaterial:SetFloat("$alpha", 1)
        local now = CurTime()
        local frame = FrameNumber()
        for _, band in ipairs(grid.bands) do
            if band.readyAt and #band.vertices > 0 then
                local visible = false
                for triangleStart = 1, #band.vertices, 3 do
                    for vertexIndex = triangleStart, triangleStart + 2 do
                        local vertex = band.vertices[vertexIndex]
                        -- 相邻三角形共享顶点，每个地形采样点每帧只算一次距离。
                        if vertex.alphaFrame ~= frame then
                            vertex.alpha = ScanDotAlpha(vertex.position:Distance(origin), radius)
                            vertex.alphaFrame = frame
                        end
                        if vertex.alpha > 0.5 then visible = true end
                    end
                end
                if visible then
                    -- 移动后刚补齐的地形也先淡入，避免缓存完成的瞬间突然亮起。
                    local buildFade = math.Clamp((now - band.readyAt) / SCAN_DOT_BUILD_FADE_TIME, 0, 1)
                    buildFade = buildFade * buildFade * (3 - 2 * buildFade)
                    -- 地面内部的点仍按地面深度绘制；波面边缘的点由上面的
                    -- stencil 球壳补齐，因此不会被实体切出大块断层。
                    cam.IgnoreZ(false)
                    mesh.Begin(MATERIAL_TRIANGLES, #band.vertices / 3)
                    for _, vertex in ipairs(band.vertices) do
                        mesh.Position(vertex.position)
                        mesh.Normal(vertex.normal)
                        mesh.TexCoord(0, vertex.u, vertex.v)
                        mesh.Color(255, 255, 255, math.floor(vertex.alpha * buildFade + 0.5))
                        mesh.AdvanceVertex()
                    end
                    mesh.End()
                    cam.IgnoreZ(false)
                end
            end
        end
    end

    local function GlitchNoise(seed)
        local value = math.sin(seed * 12.9898 + 78.233) * 43758.5453
        return value - math.floor(value)
    end

    local TRAJECTORY_GLITCH_COLORS = {
        Color(255, 40, 40), Color(45, 255, 70), Color(55, 100, 255)
    }

    local function TrajectoryGlitch(now, seed)
        -- 每条线错开触发；90ms 内按 15ms 跳变，整条路径共同闪烁、轻微错位。
        local period = 1.2 + GlitchNoise(seed) * 0.45
        local time = now + seed * 0.173
        local cycle = math.floor(time / period)
        local phase = time - cycle * period
        if phase >= 0.20 then return nil end
        local tick = math.floor(phase / 0.015)
        return {
            offset = (tick % 2 == 0 and 1 or -1) * (0.6 + GlitchNoise(cycle + tick + seed) * 0.8),
            opacity = (tick == 1 or tick == 4) and 0.2 or 1,
            channel = tick % 3 + 1
        }
    end

        local function DrawGroundTrajectory(points, color, alpha, ignoredEntity)
            local ply = LocalPlayer()
            if not points or #points < 2 then return end

            render.SetMaterial(navLineMaterial)
            alpha = math.Clamp(alpha or 1, 0, 1)
            local now = CurTime()
            local seed = IsValid(ignoredEntity) and ignoredEntity:EntIndex() or 1
            local glitch = TrajectoryGlitch(now, seed)
            local layers = {{
                offset = Vector(0, 0, 0),
                color = Color(color.r, color.g, color.b, math.floor(color.a * alpha + 0.5))
            }}
            if glitch then
                local direction = points[#points] - points[1]
                local sideways = Vector(-direction.y, direction.x, 0):GetNormalized()
                layers = {}
                -- 仅在 90ms 故障期间分离 RGB 通道，三色共同覆盖完整路径。
                for channel, tint in ipairs(TRAJECTORY_GLITCH_COLORS) do
                    local strength = channel == glitch.channel and 0.95 or 0.65
                    layers[channel] = {
                        offset = sideways * ((channel - 2) * glitch.offset),
                        color = Color(tint.r, tint.g, tint.b,
                            math.floor(color.a * alpha * glitch.opacity * strength + 0.5))
                    }
                end
            end

            for _, layer in ipairs(layers) do
                local offset = layer.offset
                if offset:LengthSqr() > 0 then
                    -- 同一通道整条线共用偏移；墙边受阻则只做 RGB 错色闪烁。
                    for _, point in ipairs(points) do
                        local raisedPoint = point + Vector(0, 0, 2)
                        local offsetTrace = util.TraceLine({
                            start = raisedPoint,
                            endpos = raisedPoint + offset,
                            filter = {ply, ignoredEntity},
                            mask = MASK_SOLID
                        })
                        if offsetTrace.Hit then
                            offset = Vector(0, 0, 0)
                            break
                        end
                    end
                end
                for pointIndex = 1, #points - 1 do
                    local from = points[pointIndex]
                    local to = points[pointIndex + 1]
                    if from:DistToSqr(to) >= 64 then
                        local segmentStart = from + Vector(0, 0, 2) + offset
                        local segmentEnd = to + Vector(0, 0, 2) + offset
                        local trace = util.TraceLine({
                            start = segmentStart,
                            endpos = segmentEnd,
                            filter = {ply, ignoredEntity},
                            mask = MASK_SOLID
                        })
                        local clippedEnd = trace.Hit and trace.HitPos + trace.HitNormal * 1.5 or segmentEnd
                        if clippedEnd:DistToSqr(segmentStart) > 1 then
                            render.DrawBeam(segmentStart, clippedEnd, glitch and 0.75 or 0.9, 0, 1, layer.color)
                        end
                    end
                end
            end
        end


local function Active()
    local ply = LocalPlayer()
    return F.CanAct(ply) and CurTime() >= ply:GetNWFloat("FoxHackStart", 0)
        and CurTime() < ply:GetNWFloat("FoxHackEnd", 0)
end
local wasActive = false
hook.Add("Think", "FoxPhoneHackGroundUpdate", function()
    if not Active() then
        if wasActive then ReleaseGroundDots() end
        wasActive = false
        scanPulse.active = false
        signalVisuals = {}
        return
    end
    local ply, now = LocalPlayer(), CurTime()
    if not wasActive or now >= scanPulse.nextAt then StartScanPulse(now) end
    wasActive = true
    UpdateScanDotGrid(ply)
    local current = {}
    local pathBudget = 4
    for _, target in ipairs(F.Targets or {}) do
        local id = target.id
        local visual = signalVisuals[id] or {}
        visual.signal = target
        if pathBudget > 0 and (not visual.nextPath or now >= visual.nextPath) then
            pathBudget = pathBudget - 1
            visual.nextPath = now + 0.75
            local from, to = FloorPosition(ply:GetPos(), ply), FloorPosition(target.pos, Entity(id))
            local points = {from}
            local steps = math.min(24, math.max(1, math.ceil(from:Distance(to) / 96)))
            for i = 1, steps do
                points[#points + 1] = FloorPosition(LerpVector(i / steps, from, to), Entity(id))
            end
            visual.path = points
        end
        current[id] = visual
    end
    signalVisuals = current
end)
hook.Add("PostDrawTranslucentRenderables", "FoxPhoneHackGroundEffects", function(depth, sky)
    if depth or sky or not Active() or not scanPulse.active then return end
    local ply, now = LocalPlayer(), CurTime()
    local origin = ply:WorldSpaceCenter()
    local radius = ScanPulseRadius(now - scanPulse.startedAt)
    local alpha = ScanPulseAlpha(radius)
    if radius > 2 and alpha > 0.001 then
        DrawInstinctStyleSphere(origin, radius, Color(255,255,255,math.floor(112 * alpha)), ply)
        DrawScanDataDots(origin, radius)
    end
    for id, visual in pairs(signalVisuals) do
        local distance = origin:Distance(visual.signal.pos)
        if distance <= radius and visual.waveHitPulse ~= scanPulse.generation then
            visual.waveHitPulse = scanPulse.generation
            visual.waveHoldUntil = now + WAVE_TRAIL_HOLD_TIME
        end
        local visible = visual.waveHoldUntil and now < visual.waveHoldUntil
        local trailAlpha = WaveTrailAlpha(visual, visible and 1 or 0, now)
        if trailAlpha > 0.001 then
            DrawGroundTrajectory(visual.path, GetSignalDisplayColor(distance), trailAlpha, Entity(id))
        end
    end
end)
