local env = getgenv()
if env.CombatCleanup then pcall(env.CombatCleanup) end

local CombatJanitor = { items = {}, restorers = {} }

function CombatJanitor:Add(x)
    self.items[#self.items + 1] = x
    return x
end

function CombatJanitor:AddRestore(fn)
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

function CombatJanitor:Cleanup()
    for i = #self.items, 1, -1 do
        pcall(release, self.items[i])
    end
    for i = #self.restorers, 1, -1 do
        pcall(self.restorers[i])
    end
    table.clear(self.items)
    table.clear(self.restorers)
end

env.CombatCleanup = function() CombatJanitor:Cleanup() end
env.CombatJanitor = CombatJanitor

local Library = env.Library or Library
if Library and Library.OnUnload then
    Library:OnUnload(function() CombatJanitor:Cleanup() end)
end

return CombatJanitor
