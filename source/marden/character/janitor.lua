local env = getgenv()
if env.CharacterCleanup then pcall(env.CharacterCleanup) end

local Players = game:GetService("Players")

local CharacterJanitor = { items = {}, restorers = {} }

function CharacterJanitor:Add(x)
    self.items[#self.items + 1] = x
    return x
end

function CharacterJanitor:AddRestore(fn)
    self.restorers[#self.restorers + 1] = fn
    return fn
end

local function release(x)
    local t = typeof(x)
    if t == "RBXScriptConnection" then x:Disconnect()
    elseif t == "Instance" then x:Destroy()
    elseif t == "function" then x()
    elseif t == "table" then
        if x.Disconnect then x:Disconnect()
        elseif x.Remove then x:Remove()
        elseif x.Destroy then x:Destroy() end
    end
end

local function resetHumanoid()
    local char = Players.LocalPlayer and Players.LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    hum.WalkSpeed = 16
    hum.UseJumpPower = true
    hum.JumpPower = 50
end

function CharacterJanitor:Cleanup()
    for i = #self.items, 1, -1 do
        pcall(release, self.items[i])
    end
    for i = #self.restorers, 1, -1 do
        pcall(self.restorers[i])
    end
    table.clear(self.items)
    table.clear(self.restorers)
    pcall(resetHumanoid)
end

env.CharacterCleanup = function() CharacterJanitor:Cleanup() end
env.CharacterJanitor = CharacterJanitor

local Library = env.Library or Library
if Library and Library.OnUnload then
    Library:OnUnload(function() CharacterJanitor:Cleanup() end)
end

return CharacterJanitor
