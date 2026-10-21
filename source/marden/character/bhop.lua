BunnyHopGroupbox = CharacterTab:AddRightGroupbox("Character BunnyHop")

local CharacterJanitor = getgenv().CharacterJanitor

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Bhop = {
    enabled = false,
    jumpInterval = 10,
    lastJumpTime = 0,
    isInAir = false
}

BunnyHopGroupbox:AddToggle("CharacterBunnyHop", {
    Text = "Activate Character BunnyHop",
    Default = false,
}):OnChanged(function(state)
    Bhop.enabled = state
end)

BunnyHopGroupbox:AddInput("BunnyHopSpeed", {
    Text = "Character BunnyHop Interval Value (ms)",
    Placeholder = "Enter BunnyHop Interval Value...",
    Default = "10",
    Finished = true,
    AllowEmpty = true,
    ClearTextOnFocus = false,
    Numeric = true
}):OnChanged(function(value)
    local num = tonumber(value)
    if num and num > 0 then
        Bhop.jumpInterval = num
    else
        Bhop.jumpInterval = 10
    end
end)

local BhopConn = RunService.Heartbeat:Connect(function()
    if not Bhop.enabled then return end

    local currentTime = tick()
    local character = Players.LocalPlayer.Character
    if not character then return end

    local humanoid = character:FindFirstChild("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart then return end

    local currentState = humanoid:GetState()
    local onGround = (currentState ~= Enum.HumanoidStateType.Freefall and
                     currentState ~= Enum.HumanoidStateType.Flying and
                     currentState ~= Enum.HumanoidStateType.Jumping)

    if not onGround then
        Bhop.isInAir = true
    elseif Bhop.isInAir then
        Bhop.isInAir = false
    end

    local interval = Bhop.jumpInterval / 1000

    local shouldJump = onGround and not Bhop.isInAir and (currentTime - Bhop.lastJumpTime >= interval)

    if shouldJump then
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        Bhop.lastJumpTime = currentTime
        Bhop.isInAir = true
    end
end)

if CharacterJanitor then
    CharacterJanitor:Add(BhopConn)
    CharacterJanitor:Add(function()
        Bhop.enabled = false
        Bhop.isInAir = false
    end)
end
