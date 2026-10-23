WalkSpeedLeft = CharacterTab:AddLeftGroupbox("Custom Character Walkspeed")
JumpPowerRight = CharacterTab:AddRightGroupbox("Custom Character JumpPower")

local CharacterJanitor = getgenv().CharacterJanitor

local Svc = {
    Run   = game:GetService("RunService"),
    LP    = game:GetService("Players").LocalPlayer,
}

local State = {
    DefWS = 16, DefJP = 50,
    WS    = 16,  JP   = 50,
    WSOn  = false, JPOn = false,
    Conn  = {}
}

local function dconn()
    for _, c in pairs(State.Conn) do
        if c and c.Disconnect then pcall(function() c:Disconnect() end) end
    end
    table.clear(State.Conn)
end

local function hum()
    local c = Svc.LP.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function hrp()
    local c = Svc.LP.Character
    if not c then return nil end
    return c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso") or c:FindFirstChild("UpperTorso")
end

local function fws()
    local h = hum()
    if h and State.WSOn then h.WalkSpeed = State.WS end
end

local function fjp()
    local h = hum()
    if h and State.JPOn then h.UseJumpPower = true h.JumpPower = State.JP end
end

local function fvs()
    if not State.WSOn then return end
    local r, h = hrp(), hum()
    if not r or not h then return end
    local md = h.MoveDirection
    if md.Magnitude > 0 then
        local cv = r.AssemblyLinearVelocity
        local dv = Vector3.new(md.X * State.WS, cv.Y, md.Z * State.WS)
        if (dv - cv).Magnitude > 1 then r.AssemblyLinearVelocity = dv end
    end
end

local function fbm()
    if not State.WSOn then return end
    local r = hrp()
    if not r then return end
    local bv = r:FindFirstChildOfClass("BodyVelocity")
    if bv then bv.MaxForce = Vector3.new(4000, 0, 4000) * (State.WS / 16) end
    local bp = r:FindFirstChildOfClass("BodyPosition")
    if bp then bp.MaxForce = Vector3.new(4000, 4000, 4000) * (State.WS / 16) end
end

local function fcb()
    if not State.WSOn then return end
    local r, h = hrp(), hum()
    if not r or not h then return end
    local md = h.MoveDirection
    if md.Magnitude > 0.1 then
        local b = (State.WS - 16) / 16
        if b > 0 then r.CFrame = r.CFrame + (md * b * 0.5) end
    end
end

local function startWS()
    dconn() State.WSOn = true
    table.insert(State.Conn, Svc.Run.Heartbeat:Connect(function()
        if State.WSOn then fws() fvs() fbm() end
    end))
    local h = hum()
    if h then
        table.insert(State.Conn, h:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
            if State.WSOn then fws() end
        end))
    end
    table.insert(State.Conn, Svc.Run.Stepped:Connect(function()
        if State.WSOn then fcb() end
    end))
end

local function stopWS()
    State.WSOn = false dconn()
    local h = hum()
    if h then h.WalkSpeed = State.DefWS end
end

local function startJP()
    State.JPOn = true
    table.insert(State.Conn, Svc.Run.Heartbeat:Connect(function()
        if State.JPOn then fjp() end
    end))
    local h = hum()
    if h then
        table.insert(State.Conn, h:GetPropertyChangedSignal("JumpPower"):Connect(function()
            if State.JPOn then fjp() end
        end))
    end
end

local function stopJP()
    State.JPOn = false
    local h = hum()
    if h then h.JumpPower = State.DefJP end
end

local function detectDef()
    local h = hum()
    if h then
        State.DefWS = h.WalkSpeed
        State.DefJP = h.UseJumpPower and h.JumpPower or 50
    end
end

task.spawn(function() task.wait(1) detectDef() end)

local CharAddedConn = Svc.LP.CharacterAdded:Connect(function()
    dconn() task.wait(1) detectDef()
    if State.WSOn then startWS() end
    if State.JPOn then startJP() end
end)

WalkSpeedLeft:AddCheckbox("WalkSpeedToggle", { Text = "Activate Custom Character WalkSpeed", Default = false })
WalkSpeedLeft:AddInput("WalkSpeedInput", { Text = "Custom WalkSpeed Value", Placeholder = "Enter Walkspeed Value...", Default = "16", Numeric = true, Finished = true, ClearTextOnFocus = false, })
JumpPowerRight:AddCheckbox("JumpPowerToggle", { Text = "Activate Custom Character JumpPower", Default = false })
JumpPowerRight:AddInput("JumpPowerInput", { Text = "Custom JumpPower Value", Placeholder = "Enter JumpPower Value...", Default = "50", Numeric = true, Finished = true, ClearTextOnFocus = false, })

Toggles.WalkSpeedToggle:OnChanged(function(s) if s then startWS() else stopWS() end end)

Options.WalkSpeedInput:OnChanged(function(v)
    local s = tonumber(v)
    if s and s >= 0 then State.WS = s if State.WSOn then fws() end end
end)

Toggles.JumpPowerToggle:OnChanged(function(s) if s then startJP() else stopJP() end end)

Options.JumpPowerInput:OnChanged(function(v)
    local p = tonumber(v)
    if p and p >= 0 then State.JP = p if State.JPOn then fjp() end end
end)

if CharacterJanitor then
    CharacterJanitor:Add(CharAddedConn)
    CharacterJanitor:Add(function()
        State.WSOn, State.JPOn = false, false
        dconn()
    end)
    CharacterJanitor:AddRestore(function()
        local h = hum()
        if h then
            h.WalkSpeed = State.DefWS
            h.UseJumpPower = true
            h.JumpPower = State.DefJP
        end
    end)
end
