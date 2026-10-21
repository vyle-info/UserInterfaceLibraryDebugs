SpinBotGroupbox = CharacterTab:AddLeftGroupbox("CFrame Character Spinbot")

local CharacterJanitor = getgenv().CharacterJanitor

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local Spinbot = {
    connection = nil,
    speed = 10,
    enabled = false,
    originalCFrame = nil,
    character = nil,
    hasSpun = false
}

SpinBotGroupbox:AddToggle("CFrameSpinbot", {
    Text = "Activate CFrame Character SpinBot",
    Default = false,
})

SpinBotGroupbox:AddInput("CFrameSpinSpeed", {
    Text = "CFrame Character SpinBot Speed Value",
    Placeholder = "Enter CFrame Speed Value...",
    Default = "10",
    Finished = true,
    AllowEmpty = true,
    ClearTextOnFocus = false,
    Numeric = true
})

local function StopCFrameSpin()
    if Spinbot.connection then
        Spinbot.connection:Disconnect()
        Spinbot.connection = nil
    end

    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    if hum then
        hum.AutoRotate = true
    end

    if hrp and Spinbot.hasSpun and Spinbot.originalCFrame and Spinbot.character == char then
        local currentPosition = hrp.Position
        local _, originalYaw, _ = Spinbot.originalCFrame:ToOrientation()

        hrp.CFrame = CFrame.new(currentPosition)
            * CFrame.Angles(0, originalYaw, 0)
    end

    Spinbot.hasSpun = false
    Spinbot.originalCFrame = nil
    Spinbot.character = nil
end

local function StartCFrameSpin()
    StopCFrameSpin()

    if not Spinbot.enabled then
        return
    end

    local char = LocalPlayer.Character
    if not char then
        return
    end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")

    if not hrp or not hum then
        return
    end

    Spinbot.character = char
    Spinbot.originalCFrame = hrp.CFrame
    Spinbot.hasSpun = false

    Spinbot.connection = RunService.RenderStepped:Connect(function()
        if not Spinbot.enabled
            or not char.Parent
            or not hrp.Parent
            or hum.Health <= 0 then

            StopCFrameSpin()
            return
        end

        if Spinbot.speed == 0 then
            if not hum.AutoRotate then
                hum.AutoRotate = true
            end
            return
        end

        if hum.AutoRotate then
            hum.AutoRotate = false
        end

        hrp.CFrame = hrp.CFrame
            * CFrame.Angles(0, math.rad(Spinbot.speed), 0)
        Spinbot.hasSpun = true
    end)
end

Toggles.CFrameSpinbot:OnChanged(function(state)
    Spinbot.enabled = state

    if state then
        StartCFrameSpin()
    else
        StopCFrameSpin()
    end
end)

Options.CFrameSpinSpeed:OnChanged(function()
    Spinbot.speed = tonumber(Options.CFrameSpinSpeed.Value) or 0
end)

Spinbot.speed = tonumber(Options.CFrameSpinSpeed.Value) or 0

local SpinAddedConn = LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.2)

    if Spinbot.enabled and LocalPlayer.Character == char then
        StartCFrameSpin()
    end
end)

local SpinRemovingConn = LocalPlayer.CharacterRemoving:Connect(function()
    if Spinbot.connection then
        Spinbot.connection:Disconnect()
        Spinbot.connection = nil
    end

    Spinbot.hasSpun = false
    Spinbot.originalCFrame = nil
    Spinbot.character = nil
end)

if CharacterJanitor then
    CharacterJanitor:Add(SpinAddedConn)
    CharacterJanitor:Add(SpinRemovingConn)
    CharacterJanitor:Add(function()
        Spinbot.enabled = false
        StopCFrameSpin()
    end)
    CharacterJanitor:AddRestore(function()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.AutoRotate = true end
    end)
end
