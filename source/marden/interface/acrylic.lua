
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local UserGameSettings = UserSettings():GetService("UserGameSettings")

local Library, UIManagementGroup = ...

if not Library or not UIManagementGroup then
    warn("Acrylic: Library or UIManagementGroup is missing.")
    return
end

local BlurController = {
    Enabled = false,
    Unloaded = false,
    Amount = 100,
    FallbackSize = 24,
    GraphicsThreshold = 8,
    Connection = nil,
    RobloxBlur = nil,
    CreatedBlur = false,
}

local ExistingBlur = Lighting:FindFirstChild("UserInterfaceFallbackBlur")

if ExistingBlur and ExistingBlur:IsA("BlurEffect") then
    BlurController.RobloxBlur = ExistingBlur
else
    local Blur = Instance.new("BlurEffect")
    Blur.Name = "UserInterfaceFallbackBlur"
    Blur.Size = BlurController.FallbackSize
    Blur.Enabled = false
    Blur.Parent = Lighting

    BlurController.RobloxBlur = Blur
    BlurController.CreatedBlur = true
end

BlurController.RobloxBlur.Enabled = false

local function GetGraphicsLevel()
    local Success, Quality = pcall(function()
        return UserGameSettings.SavedQualityLevel
    end)

    if not Success or not Quality then
        return nil
    end

    if Quality == Enum.SavedQualitySetting.Automatic then
        return nil
    end

    return tonumber(string.match(Quality.Name, "%d+"))
end

local function UpdateBlur()
    if BlurController.Unloaded then
        return
    end

    if not Library or Library.Unloaded then
        return
    end

    local Level = GetGraphicsLevel()
    local UseRobloxBlur =
        Level ~= nil and Level < BlurController.GraphicsThreshold

    local UIIsOpen = Library.Toggled == true
    local ShouldBlur = BlurController.Enabled and UIIsOpen

    if BlurController.RobloxBlur then
        BlurController.RobloxBlur.Enabled =
            ShouldBlur and UseRobloxBlur
    end

    local Success, Error = pcall(function()
        Library:SetBlurAmount(BlurController.Amount)
        Library:SetBlurEnabled(
            ShouldBlur and not UseRobloxBlur
        )
    end)

    if not Success and not BlurController.Unloaded then
        warn("Acrylic UpdateBlur error:", Error)
    end
end

UIManagementGroup:AddToggle("BlurToggle", {
    Text = "UserInterface Blur",
    Default = false,
    Tooltip = "Enables acrylic blur, using standard Roblox blur on low graphics settings.",

    Callback = function(Value)
        if BlurController.Unloaded then
            return
        end

        BlurController.Enabled = Value == true
        UpdateBlur()
    end,
})

BlurController.Connection = RunService.RenderStepped:Connect(function()
    UpdateBlur()
end)

Library:GiveSignal(BlurController.Connection)

UpdateBlur()

Library:OnUnload(function()
    if BlurController.Unloaded then
        return
    end

    BlurController.Unloaded = true
    BlurController.Enabled = false

    if BlurController.Connection then
        BlurController.Connection:Disconnect()
        BlurController.Connection = nil
    end

    if BlurController.RobloxBlur then
        BlurController.RobloxBlur.Enabled = false

        if BlurController.CreatedBlur then
            BlurController.RobloxBlur:Destroy()
        end

        BlurController.RobloxBlur = nil
    end

    if Library then
        pcall(function()
            Library:SetBlurEnabled(false)
        end)
    end
end)
