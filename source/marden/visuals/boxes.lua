local VisualBoxesGroupBox = VisualsTab:AddGroupbox({
    Side = "Left",
    Name = "Visual Activation Preferences (Boxes)",
})

VisualBoxesGroupBox:AddToggle("GlobalBoxVisuals", {
    Text = "Visualize Outline Boxes",
    Default = false,
})

VisualBoxesGroupBox:AddToggle("VisualizeFillBoxes", {
    Text = "Visualize Fill Boxes",
    Default = false,
})

VisualBoxesGroupBox:AddToggle("VisualizeTeammates", {
    Text = "Visualize Teammates",
    Default = false,
})

VisualBoxesGroupBox:AddToggle("DetectBoxVisibility", {
    Text = "Visualize Box Visibility",
    Default = false,
})

local VisualBoxesCustomizationGroupBox = VisualsTab:AddGroupbox({
    Side = "Right",
    Name = "Visual Color Customization (Boxes)",
})

VisualBoxesCustomizationGroupBox:AddLabel("Global Outline Box Color"):AddColorPicker("OutlineBoxColor", {
    Default = Color3.fromRGB(200, 0, 0),
    Title = "Global Outline Box Color",
    Transparency = 0,
    Resizable = true,
})

VisualBoxesCustomizationGroupBox:AddLabel("Visibility Outline Box Color"):AddColorPicker("VisibilityOutlineBoxColor", {
    Default = Color3.fromRGB(0, 255, 25),
    Title = "Visibility Outline box Color",
    Transparency = 0,
    Resizable = true,
})

VisualBoxesCustomizationGroupBox:AddLabel("Global Filled Box Color"):AddColorPicker("FillBoxColor", {
    Default = Color3.fromRGB(200, 0, 0),
    Title = "Global Filled Box Color",
    Transparency = 0.8,
    Resizable = true,
})

VisualBoxesCustomizationGroupBox:AddLabel("Visibility Filled Box Color"):AddColorPicker("VisibilityFillBoxColor", {
    Default = Color3.fromRGB(0, 200, 20),
    Title = "Visibility Filled box Color",
    Transparency = 0.8,
    Resizable = true,
})

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera     = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local Toggles = (getgenv and getgenv().Toggles) or (Library and Library.Toggles)
local Options = (getgenv and getgenv().Options) or (Library and Library.Options)

local BOX_THICKNESS = 0.2
local MM2_PLACE_ID  = 142823291

local MM2_GUN_COLOR   = Color3.fromRGB(0, 120, 255)
local MM2_KNIFE_COLOR = Color3.fromRGB(255, 0, 0)

local VisibilityCache, ESPStorage = {}, {}

local function ToDrawingTransparency(t)
    return 1 - (t or 0)
end

local function Has(p, n)
    local backpack = p:FindFirstChild("Backpack")
    if backpack and backpack:FindFirstChild(n) then return true end
    return p.Character ~= nil and p.Character:FindFirstChild(n) ~= nil
end

local function IsVisible(character)
    if not character then return false end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return false end

    local now, cached = tick(), VisibilityCache[character]
    if cached and now - cached.time < 0.02 then return cached.result end

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {character, Camera, LocalPlayer.Character}

    local origin = Camera.CFrame.Position
    for _, offset in ipairs({
        Vector3.new(0, 2.5, 0), Vector3.new(0, 0, 0), Vector3.new(0, -2, 0),
        Vector3.new(0.8, 1, 0), Vector3.new(-0.8, 1, 0),
    }) do
        if not workspace:Raycast(origin, root.Position + offset - origin, rayParams) then
            VisibilityCache[character] = {result = true, time = now}
            return true
        end
    end

    VisibilityCache[character] = {result = false, time = now}
    return false
end

local function RemoveESP(player)
    local storage = ESPStorage[player]
    if not storage then return end
    for _, d in pairs(storage) do d:Remove() end
    ESPStorage[player] = nil
end

local function AddESP(player)
    if player == LocalPlayer or ESPStorage[player] then return end
    local storage = {}
    for i = 1, 5 do
        local isLine = i < 5
        local d = Drawing.new(isLine and "Line" or "Square")
        d.Visible      = false
        d.Color        = Color3.new(1, 1, 1)
        d.Thickness    = isLine and BOX_THICKNESS or 0
        d.Transparency = 1
        d.ZIndex       = isLine and 5 or 4
        if not isLine then d.Filled = true end
        storage[isLine and i or "fill"] = d
    end
    ESPStorage[player] = storage
end

local function Hide(lines)
    for i = 1, 4 do lines[i].Visible = false end
    lines.fill.Visible = false
end

local function Draw(lines, character, fillEnabled)
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root or not character:FindFirstChildOfClass("Humanoid") then return Hide(lines) end

    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    local pos = root.Position

    for _, y in ipairs({pos.Y - 5.5 * 0.52, pos.Y + 5.5 * 0.48}) do
        for _, dx in ipairs({-1.4, 1.4}) do
            for _, dz in ipairs({-1.4, 1.4}) do
                local s, onScreen = Camera:WorldToViewportPoint(Vector3.new(pos.X + dx, y, pos.Z + dz))
                if not onScreen then return Hide(lines) end
                minX, minY = math.min(minX, s.X), math.min(minY, s.Y)
                maxX, maxY = math.max(maxX, s.X), math.max(maxY, s.Y)
            end
        end
    end

    lines[1].From, lines[1].To = Vector2.new(minX, minY), Vector2.new(maxX, minY)
    lines[2].From, lines[2].To = Vector2.new(minX, maxY), Vector2.new(maxX, maxY)
    lines[3].From, lines[3].To = Vector2.new(minX, minY), Vector2.new(minX, maxY)
    lines[4].From, lines[4].To = Vector2.new(maxX, minY), Vector2.new(maxX, maxY)
    for i = 1, 4 do lines[i].Visible = true end

    if fillEnabled then
        lines.fill.Position = Vector2.new(minX, minY)
        lines.fill.Size     = Vector2.new(maxX - minX, maxY - minY)
    end
    lines.fill.Visible = fillEnabled
end

RunService.RenderStepped:Connect(function()
    local enabled       = Toggles.GlobalBoxVisuals.Value
    local fillEnabled   = Toggles.VisualizeFillBoxes.Value
    local showTeammates = Toggles.VisualizeTeammates.Value
    local detectVisible = Toggles.DetectBoxVisibility.Value

    for player, lines in pairs(ESPStorage) do
        if not enabled then
            Hide(lines)
        elseif not player.Parent then
            RemoveESP(player)
        else
            local character = player.Character
            local humanoid  = character and character:FindFirstChildOfClass("Humanoid")
            local isTeammate = LocalPlayer.Team ~= nil and LocalPlayer.Team == player.Team

            if not humanoid or humanoid.Health <= 0 or (isTeammate and not showTeammates) then
                Hide(lines)
            else
                local vis = detectVisible and IsVisible(character)

                -- Team colors & MM2 roles
                local teamColor
                if not vis and showTeammates then
                    if game.PlaceId == MM2_PLACE_ID then
                        if Has(player, "Gun") then
                            teamColor = MM2_GUN_COLOR
                        elseif Has(player, "Knife") then
                            teamColor = MM2_KNIFE_COLOR
                        end
                    elseif player.Team then
                        teamColor = player.TeamColor.Color
                    end
                end

                local outlineOpt = vis and Options.VisibilityOutlineBoxColor or Options.OutlineBoxColor
                local fillOpt    = vis and Options.VisibilityFillBoxColor or Options.FillBoxColor

                local outlineColor = teamColor or outlineOpt.Value
                local fillColor    = teamColor or fillOpt.Value
                local outlineTrans = ToDrawingTransparency(outlineOpt.Transparency)
                local fillTrans    = ToDrawingTransparency(fillOpt.Transparency)

                for i = 1, 4 do
                    lines[i].Color        = outlineColor
                    lines[i].Transparency = outlineTrans
                    lines[i].Thickness    = BOX_THICKNESS
                end
                lines.fill.Color        = fillColor
                lines.fill.Transparency = fillTrans

                Draw(lines, character, fillEnabled)
            end
        end
    end
end)

for _, player in ipairs(Players:GetPlayers()) do AddESP(player) end

Players.PlayerAdded:Connect(AddESP)

Players.PlayerRemoving:Connect(function(player)
    if player.Character then VisibilityCache[player.Character] = nil end
    RemoveESP(player)
end)
