local VisualHighlightGroupBox = VisualsTab:AddGroupbox({
    Side = "Left",
    Name = "Visual Activation Preferences (Highlights)",
})

VisualHighlightGroupBox:AddToggle("GlobalHighlightVisuals", {
    Text = "Visualize Outline Highlights",
    Default = false,
})

VisualHighlightGroupBox:AddToggle("VisualizeHighlightBoxes", {
    Text = "Visualize Fill Highlights",
    Default = false,
})

VisualHighlightGroupBox:AddToggle("VisualizeHighlightTeammates", {
    Text = "Visualize Teammates",
    Default = false,
})

VisualHighlightGroupBox:AddToggle("DetectHighlightVisibility", {
    Text = "Visualize Highlight Visibility",
    Default = false,
})

local VisualHighlightCustomizationGroupBox = VisualsTab:AddGroupbox({
    Side = "Right",
    Name = "Visual Color Customization (Highlights)",
})

VisualHighlightCustomizationGroupBox:AddLabel("Global Outline Color"):AddColorPicker("OutlineHighlightColor", {
    Default = Color3.fromRGB(200, 0, 0),
    Title = "Global Outline Color",
    Transparency = 0,
    Resizable = true,
})

VisualHighlightCustomizationGroupBox:AddLabel("Visibility Outline Color"):AddColorPicker("VisibilityOutlineHighlightColor", {
    Default = Color3.fromRGB(0, 255, 25),
    Title = "Visibility Outline Color",
    Transparency = 0,
    Resizable = true,
})

VisualHighlightCustomizationGroupBox:AddLabel("Global Fill Color"):AddColorPicker("FillHighlightColor", {
    Default = Color3.fromRGB(200, 0, 0),
    Title = "Global Fill Color",
    Transparency = 0.5,
    Resizable = true,
})

VisualHighlightCustomizationGroupBox:AddLabel("Visibility Fill Color"):AddColorPicker("VisibilityFillHighlightColor", {
    Default = Color3.fromRGB(0, 255, 25),
    Title = "Visibility Fill Color",
    Transparency = 0.5,
    Resizable = true,
})

local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local CoreGui     = game:GetService("CoreGui")
local Camera      = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local Toggles = (getgenv and getgenv().Toggles) or (Library and Library.Toggles)
local Options = (getgenv and getgenv().Options) or (Library and Library.Options)

local MM2_PLACE_ID    = 142823291
local MM2_GUN_COLOR   = Color3.fromRGB(0, 120, 255)
local MM2_KNIFE_COLOR = Color3.fromRGB(255, 0, 0)

local VisibilityCache, ESPStorage = {}, {}

local HighlightFolder = Instance.new("Folder")
HighlightFolder.Name = "ESPHighlights"
do
    local parent = (gethui and gethui()) or CoreGui
    local ok = pcall(function() HighlightFolder.Parent = parent end)
    if not ok then HighlightFolder.Parent = LocalPlayer:WaitForChild("PlayerGui") end
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
    local highlight = ESPStorage[player]
    if not highlight then return end
    highlight:Destroy()
    ESPStorage[player] = nil
end

local function AddESP(player)
    if player == LocalPlayer or ESPStorage[player] then return end

    local highlight = Instance.new("Highlight")
    highlight.Name                = player.Name
    highlight.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillTransparency    = 1
    highlight.OutlineTransparency = 1
    highlight.Enabled             = false
    highlight.Parent              = HighlightFolder

    ESPStorage[player] = highlight
end

local function Hide(highlight)
    highlight.Enabled = false
    highlight.Adornee = nil
end

RunService.RenderStepped:Connect(function()
    local enabled       = Toggles.GlobalHighlightVisuals.Value
    local fillEnabled   = Toggles.VisualizeHighlightBoxes.Value
    local showTeammates = Toggles.VisualizeHighlightTeammates.Value
    local detectVisible = Toggles.DetectHighlightVisibility.Value

    for player, highlight in pairs(ESPStorage) do
        if not enabled then
            Hide(highlight)
        elseif not player.Parent then
            RemoveESP(player)
        else
            local character  = player.Character
            local humanoid   = character and character:FindFirstChildOfClass("Humanoid")
            local isTeammate = LocalPlayer.Team ~= nil and LocalPlayer.Team == player.Team

            if not humanoid or humanoid.Health <= 0 or (isTeammate and not showTeammates) then
                Hide(highlight)
            else
                local vis = detectVisible and IsVisible(character)

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

                local outlineOpt = vis and Options.VisibilityOutlineHighlightColor or Options.OutlineHighlightColor
                local fillOpt    = vis and Options.VisibilityFillHighlightColor or Options.FillHighlightColor

                if highlight.Adornee ~= character then
                    highlight.Adornee = character
                end

                highlight.OutlineColor        = teamColor or outlineOpt.Value
                highlight.OutlineTransparency = outlineOpt.Transparency or 0
                highlight.FillColor           = teamColor or fillOpt.Value
                highlight.FillTransparency    = fillEnabled and (fillOpt.Transparency or 0.8) or 1
                highlight.Enabled             = true
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
