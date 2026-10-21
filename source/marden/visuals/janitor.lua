local env = getgenv()
if env.VisualsCleanup then pcall(env.VisualsCleanup) end

local Janitor = { items = {}, drawings = {}, instances = {} }

local TRACK = { Highlight = true, SelectionBox = true, BillboardGui = true }

local rawDrawingNew = env.__RawDrawingNew or Drawing.new
env.__RawDrawingNew = rawDrawingNew
Drawing.new = function(...)
    local obj = rawDrawingNew(...)
    Janitor.drawings[obj] = true
    return obj
end

local rawInstanceNew = env.__RawInstanceNew or Instance.new
env.__RawInstanceNew = rawInstanceNew
local wrapped = pcall(function()
    Instance.new = function(class, ...)
        local obj = rawInstanceNew(class, ...)
        if TRACK[class] then Janitor.instances[obj] = true end
        return obj
    end
end)

function Janitor:Add(x)
    self.items[#self.items + 1] = x
    return x
end

function Janitor:Cleanup()
    for i = #self.items, 1, -1 do
        local x = self.items[i]
        pcall(function()
            local t = typeof(x)
            if t == "RBXScriptConnection" then x:Disconnect()
            elseif t == "Instance" then x:Destroy()
            elseif t == "function" then x()
            elseif t == "table" and x.Remove then x:Remove() end
        end)
    end
    for obj in pairs(self.drawings) do
        pcall(function() obj:Remove() end)
    end
    for obj in pairs(self.instances) do
        pcall(function() obj:Destroy() end)
    end
    table.clear(self.items)
    table.clear(self.drawings)
    table.clear(self.instances)

    pcall(function() Drawing.new = rawDrawingNew end)
    pcall(function() Instance.new = rawInstanceNew end)
end

env.VisualsCleanup = function() Janitor:Cleanup() end
env.Janitor = Janitor
env.JanitorTracksInstances = wrapped

local Library = env.Library or Library
if Library and Library.OnUnload then
    Library:OnUnload(function() Janitor:Cleanup() end)
end

return Janitor
