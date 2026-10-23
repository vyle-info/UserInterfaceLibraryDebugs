local Box3DGroupBox = VisualsTab:AddGroupbox({
    Side = "Left",
    Name = "Visual Activation Preferences (3D Boxes)",
})

Box3DGroupBox:AddToggle("Box3DToggle", {
    Text = "Visualize 3D Boxes",
    Default = false,
})

Box3DGroupBox:AddToggle("Box3DSelfToggle", {
    Text = "Visualize Self 3D Boxes",
    Default = false,
})

Box3DGroupBox:AddToggle("Box3DTeammatesToggle", {
    Text = "Visualize Teammate 3D Boxes",
    Default = false,
})

Box3DGroupBox:AddToggle("Box3DVisibilityToggle", {
    Text = "Visualize 3D Boxes Visibility",
    Default = false,
})

local Box3DCustomizationGroupBox = VisualsTab:AddGroupbox({
    Side = "Right",
    Name = "Visual Color Customization (3D Boxes)",
})

Box3DCustomizationGroupBox:AddLabel("3D Boxes Outline Color"):AddColorPicker("Box3DOutlineColor", {
    Default = Color3.fromRGB(200, 0, 0),
    Title = "3D Boxes Outline Color",
    Transparency = 0,
})

Box3DCustomizationGroupBox:AddLabel("3D Boxes Visibility Outline Color"):AddColorPicker("Box3DVisibilityOutlineColor", {
    Default = Color3.fromRGB(0, 255, 25),
    Title = "3D Boxes Visibility Outline Color",
    Transparency = 0,
})

Box3DCustomizationGroupBox:AddLabel("3D Boxes Fill Color"):AddColorPicker("Box3DFillColor", {
    Default = Color3.fromRGB(200, 0, 0),
    Title = "3D Boxes Fill Color",
    Transparency = 0.85,
})

Box3DCustomizationGroupBox:AddLabel("3D Boxes Visibility Fill Color"):AddColorPicker("Box3DVisibilityFillColor", {
    Default = Color3.fromRGB(0, 255, 25),
    Title = "3D Boxes Visibility Fill Color",
    Transparency = 0.85,
})

local Janitor = getgenv().Janitor

do
    local Players     = game:GetService("Players")
    local RunService  = game:GetService("RunService")
    local Camera      = workspace.CurrentCamera
    local LocalPlayer = Players.LocalPlayer

    local Toggles = (getgenv and getgenv().Toggles) or (Library and Library.Toggles)
    local Options = (getgenv and getgenv().Options) or (Library and Library.Options)

    local LINE_THICKNESS = 1.2
    local MAX_DISTANCE   = 1000   -- players further than this are not drawn
    local SLOW_INTERVAL  = 0.1    -- team / role / visibility refresh (seconds)
    local CULL_RADIUS    = 8      -- off screen culling margin
    local NEAR_PLANE     = 0.1

    local IS_MM2          = game.PlaceId == 142823291
    local MM2_GUN_COLOR   = Color3.fromRGB(0, 120, 255)
    local MM2_KNIFE_COLOR = Color3.fromRGB(255, 0, 0)

    local abs, tan, rad = math.abs, math.tan, math.rad

    local SX, SY, SZ = {}, {}, {}
    for i = 1, 8 do
        local b = i - 1
        SX[i] = (b % 2 == 0) and -1 or 1
        SY[i] = ((b // 2) % 2 == 0) and -1 or 1
        SZ[i] = ((b // 4) % 2 == 0) and -1 or 1
    end

    local EA, EB = {}, {}
    for b = 0, 7 do
        for _, bit in ipairs({1, 2, 4}) do
            if (b // bit) % 2 == 0 then
                EA[#EA + 1] = b + 1
                EB[#EB + 1] = b + bit + 1
            end
        end
    end

    local FACE_C = {
        {1, 3, 7, 5}, {2, 4, 8, 6},
        {1, 2, 6, 5}, {3, 4, 8, 7},
        {1, 2, 4, 3}, {5, 6, 8, 7},
    }

    local ESPStorage = {}
    local pts = {}
    local anyShown = false

    local camPos, camR, camU, camL = Vector3.zero, Vector3.xAxis, Vector3.yAxis, Vector3.zAxis
    local camK, halfW, halfH = 1, 0, 0

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    local lastLocalChar = false
    local VIS_OFFSETS = {
        Vector3.new(0, 2.5, 0), Vector3.new(0, 0, 0), Vector3.new(0, -2, 0),
        Vector3.new(0.8, 1, 0), Vector3.new(-0.8, 1, 0),
    }

    local function ToDrawingTransparency(t)
        return 1 - (t or 0)
    end

    local function Has(p, n)
        local backpack = p:FindFirstChild("Backpack")
        if backpack and backpack:FindFirstChild(n) then return true end
        return p.Character ~= nil and p.Character:FindFirstChild(n) ~= nil
    end

    local function GetRoleColor(player)
        if IS_MM2 then
            if Has(player, "Gun") then return MM2_GUN_COLOR end
            if Has(player, "Knife") then return MM2_KNIFE_COLOR end
            return nil
        end
        if player.Team then return player.TeamColor.Color end
        return nil
    end

    local function IsVisible(character, root)
        local rp = root.Position
        for i = 1, #VIS_OFFSETS do
            local hit = workspace:Raycast(camPos, rp + VIS_OFFSETS[i] - camPos, rayParams)
            if not hit or hit.Instance:IsDescendantOf(character) then
                return true
            end
        end
        return false
    end

    local function NewLine(storage)
        local l = Drawing.new("Line")
        l.Thickness    = LINE_THICKNESS
        l.ZIndex       = 5
        l.Color        = storage.oColor or Color3.new(1, 1, 1)
        l.Transparency = storage.oTrans or 1
        l.Visible      = false
        return l
    end

    local function NewQuad(storage)
        local q = Drawing.new("Quad")
        q.Filled       = true
        q.Thickness    = 0
        q.ZIndex       = 4
        q.Color        = storage.fColor or Color3.new(1, 1, 1)
        q.Transparency = storage.fTrans or 1
        q.Visible      = false
        return q
    end

    local function Hide(s)
        local lines, quads = s.lines, s.quads
        for i = 1, s.lineCount do lines[i].Visible = false end
        for i = 1, s.quadCount do quads[i].Visible = false end
        s.lineCount, s.quadCount = 0, 0
    end

    local function RemoveESP(player)
        local s = ESPStorage[player]
        if not s then return end
        for _, l in ipairs(s.lines) do l:Remove() end
        for _, q in ipairs(s.quads) do q:Remove() end
        ESPStorage[player] = nil
    end

    local function AddESP(player)
        if ESPStorage[player] then return end
        ESPStorage[player] = {
            lines = {}, quads = {}, lineCount = 0, quadCount = 0,
            nextRefresh = 0, nextSlow = math.random() * SLOW_INTERVAL,
            vis = false, isTeammate = false,
            offset = CFrame.new(), hx = 2, hy = 2.5, hz = 1,
        }
    end

    local function Refresh(s, character, now)
    s.character = character
    s.humanoid  = s.humanoid and s.humanoid.Parent == character and s.humanoid or character:FindFirstChildOfClass("Humanoid")
    s.root      = s.root and s.root.Parent == character and s.root or character:FindFirstChild("HumanoidRootPart")

    if not s.root then return end

    local ok, boxCF, boxSize = pcall(character.GetBoundingBox, character)
       if ok then
            s.offset = s.root.CFrame:ToObjectSpace(boxCF)
            s.hx, s.hy, s.hz = boxSize.X * 0.5, boxSize.Y * 0.5, boxSize.Z * 0.5
        else
            s.offset = CFrame.new(0, -0.5, 0)
            s.hx, s.hy, s.hz = 2, 3, 1
        end
    end

    local function Draw(s, outlineColor, outlineTrans, fillColor, fillTrans)
        local lines, quads = s.lines, s.quads

        if s.oColor ~= outlineColor or s.oTrans ~= outlineTrans then
            s.oColor, s.oTrans = outlineColor, outlineTrans
            for i = 1, #lines do
                lines[i].Color = outlineColor
                lines[i].Transparency = outlineTrans
            end
        end
        if s.fColor ~= fillColor or s.fTrans ~= fillTrans then
            s.fColor, s.fTrans = fillColor, fillTrans
            for i = 1, #quads do
                quads[i].Color = fillColor
                quads[i].Transparency = fillTrans
            end
        end

        local fillEnabled = fillTrans > 0.01
        local lineIdx, quadIdx = 0, 0

        local cf = s.root.CFrame * s.offset
        local c  = cf.Position
        local rv, uv, lv = cf.RightVector, cf.UpVector, cf.LookVector
        local hx, hy, hz = s.hx, s.hy, s.hz

        local d = c - camPos
        local cx, cy, cz = d:Dot(camR), d:Dot(camU), d:Dot(camL)
        local axx, axy, axz = rv:Dot(camR) * hx, rv:Dot(camU) * hx, rv:Dot(camL) * hx
        local ayx, ayy, ayz = uv:Dot(camR) * hy, uv:Dot(camU) * hy, uv:Dot(camL) * hy
        local azx, azy, azz = lv:Dot(camR) * hz, lv:Dot(camU) * hz, lv:Dot(camL) * hz

        local ok = true
        for i = 1, 8 do
            local sx, sy, sz = SX[i], SY[i], SZ[i]
            local z = cz + sx * axz + sy * ayz + sz * azz
            if z < NEAR_PLANE then ok = false break end
            local x = cx + sx * axx + sy * ayx + sz * azx
            local y = cy + sx * axy + sy * ayy + sz * azy
            local inv = camK / z
            pts[i] = Vector2.new(halfW + x * inv, halfH - y * inv)
        end

        if ok then
            for k = 1, 12 do
                lineIdx += 1
                local l = lines[lineIdx]
                if not l then l = NewLine(s) lines[lineIdx] = l end
                l.From = pts[EA[k]]
                l.To   = pts[EB[k]]
            end

            if fillEnabled then
                -- Only fill faces that point toward the camera
                local rel = camPos - c
                local lx, ly, lz = rv:Dot(rel), uv:Dot(rel), lv:Dot(rel)

                for f = 1, 6 do
                    local dv, dh
                    if f <= 2 then dv, dh = lx, hx
                    elseif f <= 4 then dv, dh = ly, hy
                    else dv, dh = lz, hz end

                    if (f % 2 == 1 and -dv or dv) > dh then
                        quadIdx += 1
                        local q = quads[quadIdx]
                        if not q then q = NewQuad(s) quads[quadIdx] = q end
                        local fc = FACE_C[f]
                        q.PointA = pts[fc[1]]
                        q.PointB = pts[fc[2]]
                        q.PointC = pts[fc[3]]
                        q.PointD = pts[fc[4]]
                    end
                end
            end
        end

        for i = s.lineCount + 1, lineIdx do lines[i].Visible = true end
        for i = lineIdx + 1, s.lineCount do lines[i].Visible = false end
        s.lineCount = lineIdx

        for i = s.quadCount + 1, quadIdx do quads[i].Visible = true end
        for i = quadIdx + 1, s.quadCount do quads[i].Visible = false end
        s.quadCount = quadIdx
    end

    Janitor:Add(function()
        pcall(function() RunService:UnbindFromRenderStep("Box3DESP") end)
    end)
    RunService:BindToRenderStep("Box3DESP", Enum.RenderPriority.Camera.Value + 1, function()
        if not Toggles.Box3DToggle.Value then
            if anyShown then
                for _, s in pairs(ESPStorage) do Hide(s) end
                anyShown = false
            end
            return
        end
        anyShown = true

        Camera = workspace.CurrentCamera
        local camCF = Camera.CFrame
        camPos, camR, camU, camL = camCF.Position, camCF.RightVector, camCF.UpVector, camCF.LookVector
        local vp = Camera.ViewportSize
        halfW, halfH = vp.X * 0.5, vp.Y * 0.5
        camK = vp.Y / (2 * tan(rad(Camera.FieldOfView) * 0.5))

        local localChar = LocalPlayer.Character
        if localChar ~= lastLocalChar then
            lastLocalChar = localChar
            rayParams.FilterDescendantsInstances = localChar and {localChar, Camera} or {Camera}
        end

        local showSelf      = Toggles.Box3DSelfToggle.Value
        local showTeammates = Toggles.Box3DTeammatesToggle.Value
        local detectVisible = Toggles.Box3DVisibilityToggle.Value

        local oN, oV = Options.Box3DOutlineColor, Options.Box3DVisibilityOutlineColor
        local fN, fV = Options.Box3DFillColor, Options.Box3DVisibilityFillColor
        local oNc, oNt = oN.Value, ToDrawingTransparency(oN.Transparency)
        local oVc, oVt = oV.Value, ToDrawingTransparency(oV.Transparency)
        local fNc, fNt = fN.Value, ToDrawingTransparency(fN.Transparency)
        local fVc, fVt = fV.Value, ToDrawingTransparency(fV.Transparency)

        local now = os.clock()

        for player, s in pairs(ESPStorage) do
            if not player.Parent then
                RemoveESP(player)
            else
                local isSelf    = player == LocalPlayer
                local character = player.Character

                if (isSelf and not showSelf) or not character then
                    Hide(s)
                else
                    if s.character ~= character or now >= s.nextRefresh then
                        Refresh(s, character, now)
                    end

                    local humanoid, root = s.humanoid, s.root
                    if not humanoid or not root or humanoid.Health <= 0 or not root.Parent then
                        Hide(s)
                    else
                        local d    = root.Position - camPos
                        local dist = d.Magnitude
                        local cz   = d:Dot(camL)
                        local culled = dist > MAX_DISTANCE or cz < -CULL_RADIUS
                        if not culled and cz > 0.5 then
                            local inv = camK / cz
                            local m = CULL_RADIUS * inv
                            if abs(d:Dot(camR) * inv) > halfW + m or abs(d:Dot(camU) * inv) > halfH + m then
                                culled = true
                            end
                        end

                        if culled then
                            Hide(s)
                        else
                            if now >= s.nextSlow then
                                s.nextSlow = now + SLOW_INTERVAL
                                s.isTeammate = not isSelf and LocalPlayer.Team ~= nil and LocalPlayer.Team == player.Team
                                s.vis = detectVisible and IsVisible(character, root)
                                s.roleColor = showTeammates and GetRoleColor(player) or nil
                            end

                            if s.isTeammate and not showTeammates then
                                Hide(s)
                            else
                                local vis = detectVisible and s.vis
                                local teamColor = (not vis and showTeammates) and s.roleColor or nil

                                local outlineColor = teamColor or (vis and oVc or oNc)
                                local fillColor    = teamColor or (vis and fVc or fNc)

                                Draw(
                                    s,
                                    outlineColor, vis and oVt or oNt,
                                    fillColor,    vis and fVt or fNt
                                )
                            end
                        end
                    end
                end
            end
        end
    end)

    for _, player in ipairs(Players:GetPlayers()) do AddESP(player) end
    Janitor:Add(Players.PlayerAdded:Connect(AddESP))
    Janitor:Add(Players.PlayerRemoving:Connect(RemoveESP))
end
