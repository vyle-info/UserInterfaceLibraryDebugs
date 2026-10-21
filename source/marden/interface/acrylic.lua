
return function(Library, UIManagementGroup)
    local Lighting = game:GetService("Lighting")
    local RunService = game:GetService("RunService")
    local UserGameSettings = UserSettings():GetService("UserGameSettings")

    if not Library or not UIManagementGroup then
        warn("Acrylic: Missing Library or UIManagementGroup.")
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
        if BlurController.Unloaded or not Library then
            return
        end

        if Library.Unloaded then
            return
        end

        local Success, Error = pcall(function()
            local Level = GetGraphicsLevel()

            -- Use Roblox blur only on low graphics settings.
            local UseRobloxBlur =
                Level ~= nil and Level < BlurController.GraphicsThreshold

            local UIIsOpen = Library.Toggled == true
            local ShouldBlur = BlurController.Enabled and UIIsOpen

            if BlurController.RobloxBlur then
                BlurController.RobloxBlur.Enabled =
                    ShouldBlur and UseRobloxBlur
            end

            Library:SetBlurAmount(BlurController.Amount)
            Library:SetBlurEnabled(
                ShouldBlur and not UseRobloxBlur
            )
        end)

        if not Success and not BlurController.Unloaded then
            warn("Acrylic UpdateBlur:", Error)
        end
    end

    UIManagementGroup:AddToggle("BlurToggle", {
        Text = "UserInterface Blur",
        Default = false,
        Tooltip = "Enables acrylic blur. Uses Roblox blur on low graphics settings.",

        Callback = function(Value)
            if BlurController.Unloaded then
                return
            end

            BlurController.Enabled = Value == true
            UpdateBlur()
        end,
    })

    BlurController.Connection = RunService.RenderStepped:Connect(UpdateBlur)

    Library:GiveSignal(BlurController.Connection)

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

        pcall(function()
            Library:SetBlurEnabled(false)
        end)
    end)

    UpdateBlur()

    return BlurController
end
