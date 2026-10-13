--// Interface Manager
--// Put this in: addons/InterfaceManager.lua

local cloneref = (cloneref or clonereference or function(instance: any)
    return instance
end)

local SoundService = cloneref(game:GetService("SoundService"))
local Debris = cloneref(game:GetService("Debris"))

local InterfaceManager = {
    Library = nil,
    Window = nil,

    DefaultNotificationSound = 4590662766,
    SelectedNotificationSound = 4590662766,

    NotificationSoundsEnabled = true,
    NotificationsHidden = false,

    WatermarkEnabled = true,
    Watermark = nil, -- DraggableLabel (optional)

    MenuKeybind = "F1",
    WatermarkKeybind = "F2",

    _NotifyHooked = false,
}

--// Setup \\--
function InterfaceManager:SetLibrary(Library)
    self.Library = Library
end

function InterfaceManager:SetWindow(Window)
    self.Window = Window
end

--// Pass your DraggableLabel so the watermark keybind can show/hide it
function InterfaceManager:SetWatermark(DraggableLabel)
    self.Watermark = DraggableLabel
    if DraggableLabel then
        DraggableLabel:SetVisible(self.WatermarkEnabled)
    end
end

function InterfaceManager:SetDefaultKeybinds(MenuKey: string?, WatermarkKey: string?)
    self.MenuKeybind = MenuKey or self.MenuKeybind
    self.WatermarkKeybind = WatermarkKey or self.WatermarkKeybind
end

function InterfaceManager:SetDefaultNotificationSound(SoundId: number)
    self.DefaultNotificationSound = SoundId
    self.SelectedNotificationSound = SoundId
end

--// Config ignore list (so SaveManager doesn't save/overwrite keybinds)
function InterfaceManager:GetIgnoreIndexes()
    return { "MenuToggleKeybind", "WatermarkToggleKeybind" }
end

--// Notifications \\--
local function PlayNotificationSound(SoundId)
    local Sound = Instance.new("Sound")
    Sound.SoundId = "rbxassetid://" .. (tostring(SoundId):gsub("rbxassetid://", ""))
    Sound.Volume = 1
    Sound.Parent = SoundService
    Sound:Play()
    Debris:AddItem(Sound, 5)
end

function InterfaceManager:HookNotify()
    assert(self.Library, "Library is not set, call InterfaceManager:SetLibrary(Library) first.")
    if self._NotifyHooked then return end
    self._NotifyHooked = true

    local Manager = self
    local OriginalNotify = self.Library.Notify

    self.Library.Notify = function(LibSelf, Args, ...)
        local SoundId
        if type(Args) == "table" then
            SoundId = Args.SoundId
        else
            SoundId = select(2, ...)
        end
        SoundId = SoundId or Manager.SelectedNotificationSound

        if Manager.NotificationsHidden then
            if Manager.NotificationSoundsEnabled and SoundId then
                pcall(PlayNotificationSound, SoundId)
            end
            return
        end

        if type(Args) == "table" and not Manager.NotificationSoundsEnabled then
            Args.SoundId = nil
        end
        return OriginalNotify(LibSelf, Args, ...)
    end
end

--// Keybinds tabbox (right side) \\--
function InterfaceManager:BuildKeybindSection(Tab: any, Side: string?)
    assert(self.Library, "Library is not set, call InterfaceManager:SetLibrary(Library) first.")
    local Library = self.Library
    local Manager = self

    local KeybindTabbox = Tab:AddTabbox({
        Side = Side or "Right",
        Name = "Keybinds",
    })

    local MenuTab = KeybindTabbox:AddTab("Interface")
    MenuTab:AddLabel("Interface Keybind"):AddKeyPicker("MenuToggleKeybind", {
        Default = Manager.MenuKeybind, NoUI = true, Text = "Toggle Interface",
    })

    local WatermarkTab = KeybindTabbox:AddTab("Watermark")
    WatermarkTab:AddLabel("Watermark Keybind"):AddKeyPicker("WatermarkToggleKeybind", {
        Default = Manager.WatermarkKeybind, NoUI = true, Text = "Toggle Watermark",
    })

    task.defer(function()
        Library.Options.MenuToggleKeybind:OnClick(function()
            Library:Toggle()
        end)

        Library.Options.WatermarkToggleKeybind:OnClick(function()
            Manager.WatermarkEnabled = not Manager.WatermarkEnabled
            if Manager.Watermark then
                Manager.Watermark:SetVisible(Manager.WatermarkEnabled)
            end
        end)
    end)

    return KeybindTabbox
end

--// General interface settings groupbox \\--
function InterfaceManager:BuildInterfaceSection(Tab: any, IconName: string?, Side: string?)
    assert(self.Library, "Library is not set, call InterfaceManager:SetLibrary(Library) first.")
    assert(self.Window, "Window is not set, call InterfaceManager:SetWindow(Window) first.")

    local Library = self.Library
    local Window = self.Window
    local Manager = self
    local Toggles = Library.Toggles

    self:HookNotify()

    local Group = Tab:AddGroupbox({
        Side = Side or "Right",
        Name = "General Interface Settings",
        IconName = IconName or "folder-pen",
    })

    --// Notifications
    Group:AddDivider("Notify Interface Settings")

    Group:AddToggle("DisableNotificationSounds", {
        Text = "Notification Sounds",
        Default = false,
    })
    Toggles.DisableNotificationSounds:OnChanged(function(State)
        Manager.NotificationSoundsEnabled = State
    end)

    Group:AddToggle("DisableNotifications", {
        Text = "Hide Notifications",
        Default = false,
    })
    Toggles.DisableNotifications:OnChanged(function(State)
        Manager.NotificationsHidden = State
    end)

    Group:AddInput("NotificationSoundInput", {
        Text = "Custom Notification SoundID",
        Default = "",
        Numeric = true,
        Finished = true,
        ClearTextOnFocus = false,
        Placeholder = "e.g. 6518811702",
        Callback = function(Value)
            local Id = tostring(Value):match("%d+")
            if Id and #Id > 0 then
                Manager.SelectedNotificationSound = tonumber(Id)
            else
                Manager.SelectedNotificationSound = Manager.DefaultNotificationSound
            end
        end,
    })

    --// Window
    Group:AddDivider("Window Interface Settings")

    Group:AddSlider("UICornerSlider", {
        Text = "Corner Radius",
        Default = Library.CornerRadius,
        Min = 0,
        Max = 20,
        Rounding = 1,
        Callback = function(Value)
            Window:SetCornerRadius(Value)
        end,
    })

    Group:AddInput("DPIScale", {
        Text = "UserInterface Scale",
        Default = "99",
        Placeholder = "Enter UserInterface scale",
        Numeric = true,
        Finished = true,
        ClearTextOnFocus = false,
        Callback = function(Value)
            local DPI = tonumber(Value)
            if DPI then
                Library:SetDPIScale(DPI)
            end
        end,
    })

    Group:AddSlider("BackgroundTransparency", {
        Text = "Background Interface Transparency",
        Default = 0, Min = 0, Max = 100, Rounding = 1, Suffix = "",
        Callback = function(Value)
            Library:SetBackgroundTransparency(Value / 100)
        end,
    })

    Group:AddSlider("GroupboxTransparency", {
        Text = "Groupbox Interface Transparency",
        Default = 0, Min = 0, Max = 100, Rounding = 1, Suffix = "",
        Callback = function(Value)
            Library:SetGroupboxTransparency(Value / 100)
        end,
    })

    --// Utility
    Group:AddDivider("Utility Interface Settings")

    Group:AddToggle("CompactSidebar", {
        Default = Window:IsSidebarCompacted(),
        Text = "Compacted Sidebar",
        Callback = function(Value)
            Window:SetCompact(Value)
        end,
    })

    Group:AddToggle("KeybindMenuOpen", {
        Default = Library.KeybindFrame.Visible,
        Text = "Keybind Interface",
        Callback = function(Value)
            Library.KeybindFrame.Visible = Value
            pcall(function()
                Library.KeybindMenu:SetVisibilityControl(Value)
            end)
        end,
    })

    return Group
end

--// Builds both at once
function InterfaceManager:BuildInterfaceTab(Tab: any)
    self:BuildInterfaceSection(Tab)
    self:BuildKeybindSection(Tab)
end

return InterfaceManager
