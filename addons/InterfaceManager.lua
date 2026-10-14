--// InterfaceManager addon
--// Same pattern as ThemeManager / ConfigManager:
--//   InterfaceManager:SetLibrary(Library)
--//   InterfaceManager:SetWindow(Window)
--//   InterfaceManager:ApplyToTab(Tabs["UI Management"])

local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local InterfaceManager = {}

InterfaceManager.Library = nil
InterfaceManager.Window = nil

InterfaceManager.DefaultNotificationSound = 4590662766
InterfaceManager.SelectedNotificationSound = InterfaceManager.DefaultNotificationSound
InterfaceManager.NotificationSoundsEnabled = true
InterfaceManager.NotificationsHidden = false

local NotifyHooked = false

function InterfaceManager:SetLibrary(Library)
    self.Library = Library
end

function InterfaceManager:SetWindow(Window)
    self.Window = Window
end

function InterfaceManager:PlayNotificationSound(soundId)
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://" .. (tostring(soundId):gsub("rbxassetid://", ""))
    sound.Volume = 1
    sound.Parent = SoundService
    sound:Play()
    Debris:AddItem(sound, 5)
end

--// Hooks Library.Notify once (safe to call ApplyToTab multiple times)
function InterfaceManager:HookNotify()
    if NotifyHooked then return end
    NotifyHooked = true

    local Library = self.Library
    local Manager = self
    local OriginalNotify = Library.Notify

    Library.Notify = function(libSelf, args, ...)
        local soundId
        if type(args) == "table" then
            soundId = args.SoundId
        else
            soundId = select(2, ...)
        end
        soundId = soundId or Manager.SelectedNotificationSound

        if Manager.NotificationsHidden then
            if Manager.NotificationSoundsEnabled and soundId then
                pcall(Manager.PlayNotificationSound, Manager, soundId)
            end
            return
        end

        if type(args) == "table" and not Manager.NotificationSoundsEnabled then
            args.SoundId = nil
        end
        return OriginalNotify(libSelf, args, ...)
    end
end

function InterfaceManager:ApplyToTab(Tab, Side)
    assert(self.Library, "InterfaceManager: call SetLibrary(Library) first")
    assert(self.Window, "InterfaceManager: call SetWindow(Window) first")
    assert(Tab, "InterfaceManager: ApplyToTab needs a tab")

    local Library = self.Library
    local Window = self.Window
    local Manager = self

    local Group
    if Side == "Left" then
        Group = Tab:AddLeftGroupbox("General Interface Settings", "folder-pen")
    else
        Group = Tab:AddRightGroupbox("General Interface Settings", "folder-pen")
    end

    local Toggles = Library.Toggles

    --// Notify settings
    Group:AddDivider("Notify Interface Settings")

    Group:AddToggle("DisableNotificationSounds", {
        Text = "Notification Sounds",
        Default = false,
    })
    Toggles.DisableNotificationSounds:OnChanged(function(state)
        Manager.NotificationSoundsEnabled = state
    end)

    Group:AddToggle("DisableNotifications", {
        Text = "Hide Notifications",
        Default = false,
    })
    Toggles.DisableNotifications:OnChanged(function(state)
        Manager.NotificationsHidden = state
    end)

    Group:AddInput("NotificationSoundInput", {
        Text = "Custom Notification SoundID",
        Default = "",
        Numeric = true,
        Finished = true,
        ClearTextOnFocus = false,
        Placeholder = "e.g. 6518811702",
        Callback = function(value)
            local id = tostring(value):match("%d+")
            if id and #id > 0 then
                Manager.SelectedNotificationSound = tonumber(id)
            else
                Manager.SelectedNotificationSound = Manager.DefaultNotificationSound
            end
        end,
    })

    self:HookNotify()

    --// Window settings
    Group:AddDivider("Window Interface Settings")

    Group:AddSlider("UICornerSlider", {
        Text = "Corner Radius",
        Default = Library.CornerRadius,
        Min = 0,
        Max = 20,
        Rounding = 1,
        Callback = function(value)
            Window:SetCornerRadius(value)
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
        Default = 0,
        Min = 0,
        Max = 100,
        Rounding = 1,
        Suffix = "",
        Callback = function(Value)
            Library:SetBackgroundTransparency(Value / 100)
        end,
    })

    Group:AddSlider("GroupboxTransparency", {
        Text = "Groupbox Interface Transparency",
        Default = 0,
        Min = 0,
        Max = 100,
        Rounding = 1,
        Suffix = "",
        Callback = function(Value)
            Library:SetGroupboxTransparency(Value / 100)
        end,
    })

    --// Utility settings
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

   return InterfaceManager
