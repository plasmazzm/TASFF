-- // ============================================================ // --
-- //   TASFF_UI.lua                                             // --
-- //   Rayfield UI â€” structure identical to the original        // --
-- //   monolith. Callbacks write to _G.TASFF_State (S).        // --
-- //   Must be loaded AFTER TASFF_Core.lua.                    // --
-- // ============================================================ // --

local S           = _G.TASFF_State
local Rayfield    = getgenv().TASFF and getgenv().TASFF.Rayfield
local Players     = game:GetService("Players")
local Player      = Players.LocalPlayer
local HttpService = game:GetService("HttpService")

-- // â”€â”€ UI-Local Variables â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ // --

local SelectedPresetToManage = ""
local SelectedBlacklistTool  = ""
local BlacklistDropdown      = nil   -- tool weapons registry dropdown
local PriorityDropdownRef    = nil   -- priority players dropdown
local PresetDropdownRef      = nil   -- saved profiles dropdown
local PerformanceIndicator   = nil   -- paragraph element ref
local PriorityMonitorLabel   = nil   -- paragraph element ref
local ThreatListLabel        = nil   -- paragraph element ref
local PresetInputName        = ""

-- // â”€â”€ Theming Color Map â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ // --

local ColorPresetMap = {
    ["Purple"]  = Color3.fromRGB(138, 43,  226),
    ["Cyan"]    = Color3.fromRGB(0,   255, 255),
    ["Red"]     = Color3.fromRGB(255, 0,   0),
    ["Black"]   = Color3.fromRGB(0,   0,   0),
    ["Yellow"]  = Color3.fromRGB(255, 255, 0),
    ["Lime"]    = Color3.fromRGB(0,   255, 0),
    ["Green"]   = Color3.fromRGB(0,   128, 0),
    ["Orange"]  = Color3.fromRGB(255, 165, 0),
    ["White"]   = Color3.fromRGB(255, 255, 255),
    ["Blue"]    = Color3.fromRGB(0,   0,   255),
    ["Brown"]   = Color3.fromRGB(139, 69,  19),
    ["Pink"]    = Color3.fromRGB(255, 192, 203),
    ["Gray"]    = Color3.fromRGB(128, 128, 128),
    ["Maroon"]  = Color3.fromRGB(128, 0,   0),
    ["Tan"]     = Color3.fromRGB(210, 180, 140),
    ["Coral"]   = Color3.fromRGB(255, 127, 80),
    ["Banana"]  = Color3.fromRGB(250, 218, 94),
    ["Rose"]    = Color3.fromRGB(255, 0,   127),
}
local ColorDropdownOptions = {
    "Purple","Cyan","Red","Black","Yellow","Lime","Green","Orange",
    "White","Blue","Brown","Pink","Gray","Maroon","Tan","Coral","Banana","Rose"
}

local function GetPresetNamesList()
    local t = {}
    for k, _ in pairs(S.SavedPresets) do table.insert(t, k) end
    return #t > 0 and t or {"No Profiles Found"}
end

-- // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• // --
-- //                          WINDOW                              // --
-- // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• // --

local Window = Rayfield:CreateWindow({
    Name            = "TASFF V2.0.0",
    Icon            = 7488932264,
    LoadingTitle    = "The Aimbot Script Final Form",
    LoadingSubtitle = "by Plasmazzm",
    Theme = {
        TextColor                     = Color3.fromRGB(240, 240, 240),
        Background                    = Color3.fromRGB(15,  15,  15),
        Topbar                        = Color3.fromRGB(20,  20,  20),
        Shadow                        = Color3.fromRGB(10,  10,  10),
        NotificationBackground        = Color3.fromRGB(15,  15,  15),
        NotificationActionsBackground = Color3.fromRGB(35,  35,  35),
        TabBackground                 = Color3.fromRGB(25,  25,  25),
        TabStroke                     = Color3.fromRGB(35,  35,  35),
        TabBackgroundSelected         = Color3.fromRGB(180, 40,  40),
        TabTextColor                  = Color3.fromRGB(240, 240, 240),
        SelectedTabTextColor          = Color3.fromRGB(255, 255, 255),
        ElementBackground             = Color3.fromRGB(25,  25,  25),
        ElementBackgroundHover        = Color3.fromRGB(35,  35,  35),
        SecondaryElementBackground    = Color3.fromRGB(20,  20,  20),
        ElementStroke                 = Color3.fromRGB(40,  40,  40),
        SecondaryElementStroke        = Color3.fromRGB(35,  35,  35),
        SliderBackground              = Color3.fromRGB(100, 20,  20),
        SliderProgress                = Color3.fromRGB(200, 35,  35),
        SliderStroke                  = Color3.fromRGB(255, 50,  50),
        ToggleBackground              = Color3.fromRGB(25,  25,  25),
        ToggleEnabled                 = Color3.fromRGB(200, 35,  35),
        ToggleDisabled                = Color3.fromRGB(60,  60,  60),
        ToggleEnabledStroke           = Color3.fromRGB(255, 50,  50),
        ToggleDisabledStroke          = Color3.fromRGB(80,  80,  80),
        ToggleEnabledOuterStroke      = Color3.fromRGB(100, 20,  20),
        ToggleDisabledOuterStroke     = Color3.fromRGB(45,  45,  45),
        DropdownSelected              = Color3.fromRGB(180, 40,  40),
        DropdownUnselected            = Color3.fromRGB(25,  25,  25),
        InputBackground               = Color3.fromRGB(20,  20,  20),
        InputStroke                   = Color3.fromRGB(80,  20,  20),
        PlaceholderColor              = Color3.fromRGB(150, 150, 150),
    },
    ConfigurationSaving = {
        Enabled    = true,
        FolderName = "TASFF V2.0.0",
        FileName   = "MainConfig"
    }
})

-- // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• // --
-- //                        1. COMBAT TAB                         // --
-- // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• // --

local MainTab = Window:CreateTab("Combat", "crosshair")

MainTab:CreateSection("Command & Control")
MainTab:CreateParagraph({
    Title   = "TASFF â€” The Aimbot Script Final Form",
    Content = "The definitive combat suite. Master Switch is the global killswitch â€” nothing runs while it's off. Aimbot Engine controls active target acquisition and tracking independently."
})
MainTab:CreateToggle({Name = "Master Switch (Killswitch)", CurrentValue = S.MasterEnabled, Flag = "MasterSwitch", Callback = function(v)
    S.MasterEnabled = v
    if not v then
        S.AimbotActive = false; S.CurrentTarget = nil
        if S.SetADSState    then S.SetADSState(false)  end
        if S.ClearVisuals   then S.ClearVisuals()      end
        if S.ClearCrosshair then S.ClearCrosshair()    end
        if S.FOVCircle      then S.FOVCircle.Visible = false end
    end
end})
MainTab:CreateToggle({Name = "Enable Aimbot Engine", CurrentValue = S.TargetingEnabled, Flag = "TargetSystemToggle", Callback = function(v)
    S.TargetingEnabled = v
end})
MainTab:CreateDropdown({
    Name          = "Primary Aim Method",
    Options       = {"Legit (Camera)", "Advanced Legit (Mouse)", "Blatant", "Flickbot (Click-Teleport)"},
    CurrentOption = {S.Mode},
    Flag          = "AimMethod",
    Callback      = function(v) S.Mode = v[1] end
})

MainTab:CreateSection("Activation & Automation")
MainTab:CreateKeybind({
    Name            = "Aimbot Activation Key",
    CurrentKeybind  = S.AimbotKeybind or "E",
    Flag            = "AimbotKeybind",
    Callback        = function(key)
        S.AimbotKeybind = key
        if S.MasterEnabled then
            S.AimbotActive = not S.AimbotActive
            if not S.AimbotActive then
                S.CurrentTarget = nil
                if S.SetADSState then S.SetADSState(false) end
            end
        end
    end
})
MainTab:CreateToggle({Name = "Auto ADS (Automatic Scope)", CurrentValue = S.AutoADSEnabled, Flag = "AutoADS", Callback = function(v)
    S.AutoADSEnabled = v
    if not v and S.SetADSState then S.SetADSState(false) end
end})
MainTab:CreateKeybind({Name = "Auto ADS Input Key", CurrentKeybind = S.AutoADSKeybind or "MouseButton2", Flag = "AutoADSKey", Callback = function(key)
    S.AutoADSKeybind = key
end})

MainTab:CreateSection("Target Selection & Sorting")
MainTab:CreateDropdown({
    Name          = "Primary Hitbox (Bodypart)",
    Options       = {"Head", "HumanoidRootPart", "Torso", "Visible On Screen"},
    CurrentOption = {S.TargetPart},
    Flag          = "TargetPart",
    Callback      = function(v) S.TargetPart = v[1]; S.ActivePartName = v[1] end
})
MainTab:CreateToggle({Name = "Randomize Hitboxes (Legit Variance)", CurrentValue = S.RandomizeHitboxEnabled, Flag = "RandomizeHitbox", Callback = function(v)
    S.RandomizeHitboxEnabled = v
end})
MainTab:CreateDropdown({Name = "Distance Sorting", Options = {"None", "Closest", "Farthest"}, CurrentOption = {S.PriorityMode}, Flag = "PriorityMode", Callback = function(v)
    S.PriorityMode = v[1]
end})
MainTab:CreateDropdown({Name = "Health Sorting", Options = {"None", "Weakest (HP)", "Strongest (HP)"}, CurrentOption = {S.VitalityMode}, Flag = "VitalityMode", Callback = function(v)
    S.VitalityMode = v[1]
end})
MainTab:CreateToggle({Name = "Prioritize Targets Near Screen Center", CurrentValue = S.TargetNearCenter, Flag = "TargetNearCenter", Callback = function(v)
    S.TargetNearCenter = v
end})
MainTab:CreateSlider({Name = "Maximum Acquisition Range (Studs)", Range = {100, 1000}, Increment = 25, CurrentValue = S.AimbotRenderDistance, Flag = "AimbotRenderDist", Callback = function(v)
    S.AimbotRenderDistance = v
end})

MainTab:CreateSection("Smoothing & Prediction")
MainTab:CreateSlider({Name = "Tracking Smoothness", Range = {0.1, 5}, Increment = 0.1, CurrentValue = S.Smoothness, Flag = "SmoothSpeed", Callback = function(v)
    S.Smoothness = v
end})
MainTab:CreateSlider({Name = "Velocity Prediction Intensity", Range = {0, 0.5}, Increment = 0.01, CurrentValue = S.PredictionAmount, Flag = "PredIntense", Callback = function(v)
    S.PredictionAmount = v
end})
MainTab:CreateToggle({Name = "Dynamic Recoil Control (DRC)", CurrentValue = S.DynamicRecoilEnabled, Flag = "DynamicRecoil", Callback = function(v)
    S.DynamicRecoilEnabled = v
end})

MainTab:CreateSection("Advanced Engagement Logic")
MainTab:CreateToggle({Name = "Universal Silent Aim (Magic Bullet)", CurrentValue = S.SilentAimEnabled, Flag = "SilentAimEnabled", Callback = function(v)
    S.SilentAimEnabled = v
    if S.Notify then
        S.Notify({Title = "Silent Aim", Content = v and "Silent Aim enabled." or "Silent Aim disabled.", Duration = 2, Image = v and "crosshair" or "x"})
    end
end})
MainTab:CreateToggle({Name = "Sticky Aim (Target Lock Retention)", CurrentValue = S.StickyAimEnabled, Flag = "StickyAim", Callback = function(v)
    S.StickyAimEnabled = v
    if not v then S.CurrentTarget = nil end
end})
MainTab:CreateToggle({Name = "Target Switch Delay (Pause After Kill)", CurrentValue = S.TargetSwitchDelayEnabled, Flag = "TargetSwitchDelay", Callback = function(v)
    S.TargetSwitchDelayEnabled = v
end})
MainTab:CreateSlider({Name = "Switch Delay Duration (ms)", Range = {50, 1000}, Increment = 10, CurrentValue = S.SwitchDelayMs, Flag = "SwitchDelayMs", Callback = function(v)
    S.SwitchDelayMs = v
end})
MainTab:CreateToggle({Name = "Target Grace Period (Anti-Jitter)", CurrentValue = S.GracePeriodEnabled, Flag = "EnableGracePeriod", Callback = function(v)
    S.GracePeriodEnabled = v
end})
MainTab:CreateSlider({Name = "Grace Period Delay (ms)", Range = {1, 1000}, Increment = 1, CurrentValue = S.GracePeriodMs, Flag = "GracePeriodMs", Callback = function(v)
    S.GracePeriodMs = v
end})

-- // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• // --
-- //                       2. VISUALS TAB                         // --
-- // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• // --

local VisualTab = Window:CreateTab("Visuals", "eye")

VisualTab:CreateSection("Global ESP Configurations")
VisualTab:CreateParagraph({
    Title   = "Focus Mode & Stream-Proofing",
    Content = "Focus Mode isolates visual clutter by only drawing ESP on Priority Targets. Stream-Proof Rendering forces tags to bypass capture software like OBS."
})
VisualTab:CreateDropdown({Name = "ESP Target Mode", Options = {"Single", "Multiple", "All"}, CurrentOption = {S.VisualMode}, Flag = "VisualMode", Callback = function(v)
    S.VisualMode = type(v) == "table" and v[1] or v
    if S.ClearVisuals then S.ClearVisuals() end
end})
VisualTab:CreateToggle({Name = "Render Player ESP", CurrentValue = S.UseHighlight, Flag = "UseHighlight", Callback = function(v) S.UseHighlight = v end})
VisualTab:CreateToggle({Name = "Render NPC ESP", CurrentValue = S.UseNPCHighlight, Flag = "UseNPCHighlight", Callback = function(v) S.UseNPCHighlight = v end})
VisualTab:CreateToggle({Name = "Focus Mode (Isolate Priority Targets)", CurrentValue = S.FocusMode, Flag = "FocusMode", Callback = function(v) S.FocusMode = v end})
VisualTab:CreateToggle({Name = "Stream-Proof Rendering (Tags)", CurrentValue = S.StreamProofESP, Flag = "StreamProofESP", Callback = function(v)
    S.StreamProofESP = v
    if S.ClearVisuals then S.ClearVisuals() end
end})
VisualTab:CreateToggle({Name = "Dynamic Visibility Colors (Green/Red)", CurrentValue = S.VisibilityColorsEnabled, Flag = "VisibilityColorsEnabled", Callback = function(v)
    S.VisibilityColorsEnabled = v
end})
VisualTab:CreateSlider({Name = "Maximum ESP Distance (Studs)", Range = {100, 1000}, Increment = 25, CurrentValue = S.ESPRenderDistance, Flag = "ESPRenderDist", Callback = function(v)
    S.ESPRenderDistance = v
end})

VisualTab:CreateSection("Tactical Overlays (Geometries)")
VisualTab:CreateToggle({Name = "Chams (Surface Highlights)", CurrentValue = S.ChamsEnabled, Flag = "EnableChamsMode", Callback = function(v) S.ChamsEnabled = v end})
VisualTab:CreateSlider({Name = "Chams Opacity", Range = {1, 10}, Increment = 1, CurrentValue = S.ChamsOpacity, Flag = "ChamsOpacity", Callback = function(v) S.ChamsOpacity = v end})
VisualTab:CreateToggle({Name = "2D Bounding Boxes", CurrentValue = S.BoxModeEnabled, Flag = "EnableBoxMode", Callback = function(v) S.BoxModeEnabled = v end})
VisualTab:CreateToggle({Name = "Skeletal Mapping (R6/R15)", CurrentValue = S.SkeletonModeEnabled, Flag = "EnableSkeletonMode", Callback = function(v) S.SkeletonModeEnabled = v end})
VisualTab:CreateToggle({Name = "Distance Snaplines", CurrentValue = S.SnaplinesEnabled, Flag = "SnaplinesEnabled", Callback = function(v) S.SnaplinesEnabled = v end})
VisualTab:CreateDropdown({Name = "Snapline Origin Point", Options = {"Bottom", "Center"}, CurrentOption = {S.SnaplineOrigin}, Flag = "SnaplineOrigin", Callback = function(v)
    S.SnaplineOrigin = v[1]
end})
VisualTab:CreateToggle({Name = "Off-Screen Indicators (OOF Arrows)", CurrentValue = S.OOFArrowsEnabled, Flag = "OOFArrowsEnabled", Callback = function(v) S.OOFArrowsEnabled = v end})
VisualTab:CreateSlider({Name = "OOF Indicator Radius", Range = {50, 400}, Increment = 10, CurrentValue = S.OOFArrowRadius, Flag = "OOFArrowRadius", Callback = function(v) S.OOFArrowRadius = v end})

VisualTab:CreateSection("Target Intelligence Tags")
VisualTab:CreateToggle({Name = "Render Player Tags", CurrentValue = S.UseInfoTag, Flag = "UseInfoTag", Callback = function(v) S.UseInfoTag = v end})
VisualTab:CreateToggle({Name = "Render NPC Tags", CurrentValue = S.UseNPCInfoTag, Flag = "UseNPCInfoTag", Callback = function(v) S.UseNPCInfoTag = v end})
VisualTab:CreateToggle({Name = "Use Display Names (vs Usernames)", CurrentValue = S.ShowDisplayName, Flag = "ShowDisplay", Callback = function(v) S.ShowDisplayName = v end})
VisualTab:CreateToggle({Name = "Display Equipped Weapon/Tool", CurrentValue = S.ShowToolCheck, Flag = "UseToolCheck", Callback = function(v) S.ShowToolCheck = v end})

VisualTab:CreateSection("Heads-Up Display (HUD)")
VisualTab:CreateParagraph({
    Title   = "Invisible FOV",
    Content = "The Invisible FOV toggle allows your aimbot to strictly respect the FOV boundary limit without actually drawing the circle on your screen."
})
VisualTab:CreateToggle({Name = "Render FOV Boundary (Circle)", CurrentValue = S.ShowFOV, Flag = "ShowFOV", Callback = function(v)
    S.ShowFOV = v
    if not v and S.FOVCircle then S.FOVCircle.Visible = false end
end})
VisualTab:CreateToggle({Name = "Invisible FOV Constraint", CurrentValue = S.InvisibleFOV, Flag = "InvisibleFOV", Callback = function(v) S.InvisibleFOV = v end})
VisualTab:CreateSlider({Name = "FOV Boundary Radius", Range = {30, 600}, Increment = 5, CurrentValue = S.FOVSize, Flag = "FOVSize", Callback = function(v) S.FOVSize = v end})
VisualTab:CreateDropdown({
    Name          = "FOV Tracking Origin",
    Options       = {"Screen Center", "Mouse Tracking"},
    CurrentOption = {S.AimReferenceMode},
    Flag          = "AimReferenceMode",
    Callback      = function(v) S.AimReferenceMode = v[1] end
})
VisualTab:CreateToggle({Name = "Render Vector Crosshair", CurrentValue = S.EnableCrosshair, Flag = "UseCrosshair", Callback = function(v)
    S.EnableCrosshair = v
    if not v and S.ClearCrosshair then S.ClearCrosshair() end
end})
VisualTab:CreateDropdown({Name = "Vector Crosshair Style", Options = {"Plus", "Square", "Circle"}, CurrentOption = {S.CrosshairStyle}, Flag = "CrossStyle", Callback = function(v)
    S.CrosshairStyle = type(v) == "table" and v[1] or v
    if S.ClearCrosshair then S.ClearCrosshair() end
end})
VisualTab:CreateSlider({Name = "Vector Crosshair Size", Range = {2, 50}, Increment = 1, CurrentValue = S.CrosshairSize, Flag = "CrossSize", Callback = function(v) S.CrosshairSize = v end})

VisualTab:CreateSection("Display Calibration")
VisualTab:CreateToggle({Name = "Enable Manual Axis Calibration", CurrentValue = S.ManualCalibrationEnabled, Flag = "EnableCalibration", Callback = function(v) S.ManualCalibrationEnabled = v end})
VisualTab:CreateSlider({Name = "Horizontal Axis Offset (Pixels)", Range = {-200, 200}, Increment = 1, CurrentValue = S.CalibrationOffsetX, Flag = "CalibrationX", Callback = function(v) S.CalibrationOffsetX = v end})
VisualTab:CreateSlider({Name = "Vertical Axis Offset (Pixels)", Range = {-200, 200}, Increment = 1, CurrentValue = S.CalibrationOffsetY, Flag = "CalibrationY", Callback = function(v) S.CalibrationOffsetY = v end})

-- // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• // --
-- //                      3. TRIGGERBOT TAB                       // --
-- // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• // --

local TriggerbotTab = Window:CreateTab("Triggerbot", "mouse-pointer-click")

TriggerbotTab:CreateSection("Primary Trigger (Mouse)")
TriggerbotTab:CreateParagraph({
    Title   = "Simulation Engine & 3D Tracking",
    Content = "Virtual: Emulates driver-level mouse events.\nPhysical: Hooks into native executor click functions.\n3rd Person Tracking: Fires at the target's exact screen coordinate instead of center screen."
})
TriggerbotTab:CreateToggle({Name = "Enable Mouse Triggerbot", CurrentValue = S.AutoClickEnabled, Flag = "EnableTriggerbot", Callback = function(v)
    S.AutoClickEnabled = v
    if not v and S.IsHoldingClick then
        S.IsHoldingClick = false
        game:GetService("VirtualInputManager"):SendMouseButtonEvent(0, 0, 0, false, game, 0)
    end
end})
TriggerbotTab:CreateDropdown({Name = "Click Simulation Engine", Options = {"Virtual", "Physical"}, CurrentOption = {S.TriggerbotClickMode}, Flag = "TriggerbotClickMode", Callback = function(v)
    S.TriggerbotClickMode = v[1]
end})
TriggerbotTab:CreateDropdown({Name = "Action Method", Options = {"Mash", "Hold"}, CurrentOption = {S.ClickMethod}, Flag = "ClickMethod", Callback = function(v)
    S.ClickMethod = v[1]
end})
TriggerbotTab:CreateSlider({Name = "Mash Interval (ms)", Range = {1, 1000}, Increment = 1, CurrentValue = S.ClickInterval, Flag = "ClickInterval", Callback = function(v)
    S.ClickInterval = v
end})
TriggerbotTab:CreateToggle({Name = "3rd Person Spatial Tracking", CurrentValue = S.ThirdPersonTriggerbot, Flag = "ThirdPersonTriggerbot", Callback = function(v)
    S.ThirdPersonTriggerbot = v
end})

TriggerbotTab:CreateSection("Secondary Trigger (Keybinds)")
TriggerbotTab:CreateParagraph({
    Title   = "Key Triggerbot",
    Content = "Automatically executes a custom keystroke (e.g., casting an ability, dashing, or swinging a sword) when the aimbot locks onto a valid target."
})
TriggerbotTab:CreateToggle({Name = "Enable Key Triggerbot", CurrentValue = S.KeyTriggerbotEnabled, Flag = "KeyTriggerbotToggle", Callback = function(v)
    S.KeyTriggerbotEnabled = v
    if not v and S.IsHoldingTriggerKey then
        S.IsHoldingTriggerKey = false
        pcall(function()
            local key = S.GetKeyCode and S.GetKeyCode(S.KeyTriggerbotKey)
            if key then game:GetService("VirtualInputManager"):SendKeyEvent(false, key, false, game) end
        end)
    end
end})
TriggerbotTab:CreateInput({
    Name                    = "Target Action Key (e.g. F, Q, E)",
    PlaceholderText         = "F",
    RemoveTextAfterFocusLost = false,
    Flag                    = "KeyTriggerKeyInput",
    Callback                = function(text)
        if text and text ~= "" then S.KeyTriggerbotKey = text:upper() end
    end
})
TriggerbotTab:CreateDropdown({Name = "Key Action Method", Options = {"Single Press", "Mash", "Hold"}, CurrentOption = {S.KeyTriggerMode}, Flag = "KeyTriggerMode", Callback = function(v)
    S.KeyTriggerMode = v[1]
end})

TriggerbotTab:CreateSection("Proximity Auto-Melee")
TriggerbotTab:CreateToggle({Name = "Enable Proximity Auto-Melee", CurrentValue = S.MeleeModeEnabled, Flag = "EnableMeleeMode", Callback = function(v) S.MeleeModeEnabled = v end})
TriggerbotTab:CreateSlider({Name = "Melee Engagement Range (Studs)", Range = {1, 10}, Increment = 1, CurrentValue = S.MeleeDetectionRange, Flag = "MeleeRange", Callback = function(v)
    S.MeleeDetectionRange = v
end})
TriggerbotTab:CreateSlider({Name = "Melee Strike Interval (ms)", Range = {1, 1000}, Increment = 1, CurrentValue = S.MeleeClickInterval, Flag = "MeleeClickInterval", Callback = function(v)
    S.MeleeClickInterval = v
end})

-- // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• // --
-- //                       4. ADVANCED TAB                        // --
-- // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• // --

local AdvancedTab = Window:CreateTab("Advanced", "cpu")

AdvancedTab:CreateSection("Threat Intelligence & Retaliation")
AdvancedTab:CreateParagraph({
    Title   = "Threat System",
    Content = "Automatically tags players who damage you into your Priority list. After the configured timeout, threats expire and can optionally be pushed straight into your Blacklist."
})
AdvancedTab:CreateToggle({Name = "Enable Threat Detector (Damage Tracking)", CurrentValue = S.ThreatDetectorEnabled, Flag = "ThreatDetector", Callback = function(v)
    S.ThreatDetectorEnabled = v
end})
AdvancedTab:CreateToggle({Name = "Enable Nemesis System (Death Tracking)", CurrentValue = S.NemesisEnabled, Flag = "NemesisEnabled", Callback = function(v)
    S.NemesisEnabled = v
end})
AdvancedTab:CreateSlider({Name = "Threat Memory Expiration (Seconds)", Range = {1, 60}, Increment = 1, CurrentValue = S.ThreatTimeout, Flag = "ThreatTimeout", Callback = function(v)
    S.ThreatTimeout = v
end})
AdvancedTab:CreateToggle({Name = "Auto-Blacklist Expired Threats", CurrentValue = S.BlacklistExpiredThreats, Flag = "BlacklistExpiredThreats", Callback = function(v)
    S.BlacklistExpiredThreats = v
end})

-- Core's ThreatMonitorLoop reads S.ThreatListLabel every second and calls :Set()
ThreatListLabel = AdvancedTab:CreateParagraph({
    Title   = "Live Threat Monitor",
    Content = "No active threats detected."
})
S.ThreatListLabel = ThreatListLabel

AdvancedTab:CreateSection("Target Marking & Overrides")
AdvancedTab:CreateParagraph({
    Title   = "Hover-To-Mark Target Selection",
    Content = "Hover your cursor near any player (even through walls) and press your designated input to manually add or remove them from your Priority List."
})
AdvancedTab:CreateToggle({Name = "Enable Target Marking", CurrentValue = S.ClickToMarkEnabled, Flag = "ClickToMark", Callback = function(v) S.ClickToMarkEnabled = v end})
AdvancedTab:CreateDropdown({Name = "Mark Activation Input", Options = {"Mouse Click Only", "Keybind Only", "Both"}, CurrentOption = {S.MarkMethod}, Flag = "MarkMethod", Callback = function(v)
    S.MarkMethod = v[1]
end})
AdvancedTab:CreateKeybind({
    Name           = "Target Mark Keybind",
    CurrentKeybind = S.MarkKeybind or "T",
    Flag           = "MarkKeybind",
    Callback       = function(key)
        local wasRebind = (tostring(key) ~= tostring(S.MarkKeybind))
        S.MarkKeybind = key
        if not wasRebind and S.ClickToMarkEnabled and (S.MarkMethod == "Keybind Only" or S.MarkMethod == "Both") then
            if S.MasterEnabled and S.AimbotActive and S.CurrentTarget ~= nil then return end
            local toolEquipped = Player.Character and Player.Character:FindFirstChildOfClass("Tool") ~= nil
            if toolEquipped then return end
            if S.HandleClickToMark then S.HandleClickToMark() end
        end
    end
})
AdvancedTab:CreateToggle({Name = "Strict Focus (Lock ONLY to Marked Targets)", CurrentValue = S.StrictPrioritize, Flag = "StrictPrioritize", Callback = function(v)
    S.StrictPrioritize = v
end})

-- Core's SyncPriorityUI reads S.PriorityMonitorLabel and calls :Set()
PriorityMonitorLabel = AdvancedTab:CreateParagraph({
    Title   = "Active Priority Targets (0)",
    Content = "No priority targets currently selected."
})
S.PriorityMonitorLabel = PriorityMonitorLabel

AdvancedTab:CreateButton({
    Name     = "Purge Priority List",
    Callback = function()
        S.PriorityPlayers = {}
        if S.SyncPriorityUI then S.SyncPriorityUI() end
        if S.Notify then S.Notify({Title = "TASFF Mark", Content = "Cleared all priority targets.", Duration = 2, Image = "delete"}) end
    end
})

AdvancedTab:CreateSection("Environment Penetration (Wallchecks)")
AdvancedTab:CreateToggle({Name = "Enforce Line of Sight (Wallcheck)", CurrentValue = S.WallCheck, Flag = "WallCheck", Callback = function(v) S.WallCheck = v end})
AdvancedTab:CreateToggle({Name = "Ignore Non-Collidable Objects (CanCollide = False)", CurrentValue = S.NoCollisionCheck, Flag = "NoCollisionCheck", Callback = function(v) S.NoCollisionCheck = v end})
AdvancedTab:CreateToggle({Name = "Ignore Transparent Objects (Glass/Tint)", CurrentValue = S.TransparencyCheck, Flag = "TransparencyCheck", Callback = function(v) S.TransparencyCheck = v end})
AdvancedTab:CreateSlider({Name = "Minimum Transparency Threshold", Range = {0.01, 1.0}, Increment = 0.05, CurrentValue = S.TransparencyThreshold, Flag = "TransparencyThreshold", Callback = function(v)
    S.TransparencyThreshold = v
end})
AdvancedTab:CreateToggle({Name = "Ignore Decals & Textures", CurrentValue = S.DecalsCheck, Flag = "DecalsCheck", Callback = function(v) S.DecalsCheck = v end})

-- // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• // --
-- //                       5. SETTINGS TAB                        // --
-- // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• // --

local SettingsTab = Window:CreateTab("Settings", "filter")

SettingsTab:CreateSection("Entity & Team Filtering")
SettingsTab:CreateToggle({Name = "Target Players", CurrentValue = S.TargetPlayers, Flag = "TargetPlayers", Callback = function(v) S.TargetPlayers = v end})
SettingsTab:CreateToggle({Name = "Target NPCs (Mob/AI Support)", CurrentValue = S.TargetNPCs, Flag = "TargetNPCs", Callback = function(v) S.TargetNPCs = v end})
SettingsTab:CreateToggle({Name = "Enforce Team Check (Ignore Teammates)", CurrentValue = S.TeamCheck, Flag = "TeamCheck", Callback = function(v) S.TeamCheck = v end})
SettingsTab:CreateToggle({Name = "Ignore Dead Targets", CurrentValue = S.IgnoreDead, Flag = "IgnoreDead", Callback = function(v) S.IgnoreDead = v end})

SettingsTab:CreateSection("Player Management Registry")
SettingsTab:CreateParagraph({
    Title   = "Priority & Blacklist Routing",
    Content = "Blacklisted players will be completely ignored by all targeting routines. Priority targets will be focused first when Strict Prioritize or Focus Mode is enabled."
})
SettingsTab:CreateDropdown({
    Name            = "Blacklist Registry (Ignored)",
    Options         = S.GetPlayerNames and S.GetPlayerNames() or {},
    CurrentOption   = {},
    MultipleOptions = true,
    Flag            = "BlacklistPlayers",
    Callback        = function(v)
        S.BlacklistedPlayers = v
        if S.CurrentTarget and S.CurrentTarget.Name and table.find(v, S.CurrentTarget.Name) then
            S.CurrentTarget = nil
        end
    end
})

PriorityDropdownRef = SettingsTab:CreateDropdown({
    Name            = "Priority Registry (Preferred)",
    Options         = S.GetPlayerNames and S.GetPlayerNames() or {},
    CurrentOption   = {},
    MultipleOptions = true,
    Flag            = "PriorityPlayers",
    Callback        = function(v)
        local removed = {}
        for _, oldName in ipairs(S.PriorityPlayers) do
            if not table.find(v, oldName) then table.insert(removed, oldName) end
        end
        for _, remName in ipairs(removed) do
            S.ThreatMemory[remName]  = nil
            S.NemesisMemory[remName] = nil
        end
        S.PriorityPlayers = v
        if S.SyncPriorityUI then S.SyncPriorityUI() end
    end
})
S.PriorityDropdownRef = PriorityDropdownRef

SettingsTab:CreateSection("Weapon & Inventory Automation")
SettingsTab:CreateParagraph({
    Title   = "Smart Tool Management",
    Content = "Automatically toggle the aimbot based on what you are holding. Blacklist non-weapons (like food or potions) to prevent the aimbot from locking on while you are healing."
})
SettingsTab:CreateToggle({Name = "Auto-Engage Aimbot on Weapon Equip", CurrentValue = S.AutoEnableOnEquip, Flag = "AutoEquipAim", Callback = function(v)
    S.AutoEnableOnEquip = v
end})

SettingsTab:CreateButton({
    Name     = "Blacklist Currently Equipped Tool",
    Callback = function()
        local char = Player.Character
        local tool = char and char:FindFirstChildOfClass("Tool")
        if tool then
            if not table.find(S.ToolBlacklist, tool.Name) then
                table.insert(S.ToolBlacklist, tool.Name)
                if BlacklistDropdown then
                    local newList = #S.ToolBlacklist > 0 and S.ToolBlacklist or {"No Registry Items Found"}
                    pcall(function() BlacklistDropdown:Refresh(newList, true) end)
                end
                if S.Notify then S.Notify({Title = "TASFF Arsenal", Content = "Blacklisted tool: " .. tool.Name, Duration = 3, Image = "ban"}) end
            else
                if S.Notify then S.Notify({Title = "TASFF Arsenal", Content = tool.Name .. " is already blacklisted.", Duration = 2, Image = "info"}) end
            end
        else
            if S.Notify then S.Notify({Title = "TASFF Arsenal", Content = "You are not holding a tool.", Duration = 2, Image = "alert-circle"}) end
        end
    end
})

BlacklistDropdown = SettingsTab:CreateDropdown({
    Name          = "Blacklisted Weapons Registry",
    Options       = #S.ToolBlacklist > 0 and S.ToolBlacklist or {"No Registry Items Found"},
    CurrentOption = {"No Registry Items Found"},
    Flag          = "ToolBlacklistDropdown",
    Callback      = function(v) SelectedBlacklistTool = v end
})
S.BlacklistDropdownRef = BlacklistDropdown

SettingsTab:CreateButton({
    Name     = "Remove Selected Tool from Registry",
    Callback = function()
        if SelectedBlacklistTool and SelectedBlacklistTool ~= "No Registry Items Found" then
            local idx = table.find(S.ToolBlacklist, SelectedBlacklistTool)
            if idx then
                table.remove(S.ToolBlacklist, idx)
                local newList = #S.ToolBlacklist > 0 and S.ToolBlacklist or {"No Registry Items Found"}
                if BlacklistDropdown then pcall(function() BlacklistDropdown:Refresh(newList, true) end) end
                if S.Notify then S.Notify({Title = "TASFF Arsenal", Content = "Removed tool: " .. SelectedBlacklistTool, Duration = 3, Image = "check"}) end
                SelectedBlacklistTool = ""
            end
        else
            if S.Notify then S.Notify({Title = "TASFF Arsenal", Content = "Select a valid tool to remove.", Duration = 2, Image = "alert-triangle"}) end
        end
    end
})

-- // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• // --
-- //                       6. PRESETS TAB                         // --
-- // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• // --

local PresetsTab = Window:CreateTab("Presets", "folder-sync")

PresetsTab:CreateSection("Local Profile Management")
PresetsTab:CreateParagraph({
    Title   = "Configuration Profiles",
    Content = "Save your current setup (Aimbot, Visuals, Filtering, Logic) into a named preset. This allows you to rapidly swap between playstyles (e.g., 'Legit', 'Blatant', 'Rage')."
})
PresetsTab:CreateInput({
    Name                     = "Preset Name",
    PlaceholderText          = "Enter preset name...",
    RemoveTextAfterFocusLost = false,
    Flag                     = "PresetInputFlag",
    Callback                 = function(text) PresetInputName = text end
})

PresetsTab:CreateButton({
    Name     = "Save Current Configuration to Preset",
    Callback = function()
        if PresetInputName and PresetInputName ~= "" then
            S.SavedPresets[PresetInputName] = {
                -- Core & Combat
                MasterEnabled = S.MasterEnabled, TargetingEnabled = S.TargetingEnabled, Mode = S.Mode,
                TargetPart = S.TargetPart, PriorityMode = S.PriorityMode, VitalityMode = S.VitalityMode,
                TargetNearCenter = S.TargetNearCenter, Smoothness = S.Smoothness, PredictionAmount = S.PredictionAmount,
                SilentAimEnabled = S.SilentAimEnabled, DynamicRecoilEnabled = S.DynamicRecoilEnabled,
                RandomizeHitboxEnabled = S.RandomizeHitboxEnabled, TargetSwitchDelayEnabled = S.TargetSwitchDelayEnabled,
                SwitchDelayMs = S.SwitchDelayMs, GracePeriodEnabled = S.GracePeriodEnabled, GracePeriodMs = S.GracePeriodMs,
                AimbotRenderDistance = S.AimbotRenderDistance, StickyAimEnabled = S.StickyAimEnabled, AutoADSEnabled = S.AutoADSEnabled,
                -- Visuals & Overlays
                VisualMode = S.VisualMode, UseHighlight = S.UseHighlight, UseNPCHighlight = S.UseNPCHighlight,
                FocusMode = S.FocusMode, StreamProofESP = S.StreamProofESP, VisibilityColorsEnabled = S.VisibilityColorsEnabled,
                ESPRenderDistance = S.ESPRenderDistance, ChamsEnabled = S.ChamsEnabled, ChamsOpacity = S.ChamsOpacity,
                BoxModeEnabled = S.BoxModeEnabled, SkeletonModeEnabled = S.SkeletonModeEnabled, SnaplinesEnabled = S.SnaplinesEnabled,
                SnaplineOrigin = S.SnaplineOrigin, OOFArrowsEnabled = S.OOFArrowsEnabled, OOFArrowRadius = S.OOFArrowRadius,
                UseInfoTag = S.UseInfoTag, UseNPCInfoTag = S.UseNPCInfoTag, ShowDisplayName = S.ShowDisplayName, ShowToolCheck = S.ShowToolCheck,
                ShowFOV = S.ShowFOV, InvisibleFOV = S.InvisibleFOV, FOVSize = S.FOVSize, AimReferenceMode = S.AimReferenceMode,
                EnableCrosshair = S.EnableCrosshair, CrosshairStyle = S.CrosshairStyle, CrosshairSize = S.CrosshairSize,
                ManualCalibrationEnabled = S.ManualCalibrationEnabled, CalibrationOffsetX = S.CalibrationOffsetX, CalibrationOffsetY = S.CalibrationOffsetY,
                -- Triggerbot & Automation
                AutoClickEnabled = S.AutoClickEnabled, TriggerbotClickMode = S.TriggerbotClickMode, ClickMethod = S.ClickMethod,
                ClickInterval = S.ClickInterval, ThirdPersonTriggerbot = S.ThirdPersonTriggerbot, KeyTriggerbotEnabled = S.KeyTriggerbotEnabled,
                KeyTriggerMode = S.KeyTriggerMode, MeleeModeEnabled = S.MeleeModeEnabled, MeleeDetectionRange = S.MeleeDetectionRange,
                MeleeClickInterval = S.MeleeClickInterval,
                -- Advanced & Logic
                ThreatDetectorEnabled = S.ThreatDetectorEnabled, NemesisEnabled = S.NemesisEnabled, ThreatTimeout = S.ThreatTimeout,
                BlacklistExpiredThreats = S.BlacklistExpiredThreats, ClickToMarkEnabled = S.ClickToMarkEnabled, MarkMethod = S.MarkMethod,
                StrictPrioritize = S.StrictPrioritize, WallCheck = S.WallCheck, NoCollisionCheck = S.NoCollisionCheck,
                TransparencyCheck = S.TransparencyCheck, TransparencyThreshold = S.TransparencyThreshold, DecalsCheck = S.DecalsCheck,
                -- Settings & Entities
                TargetPlayers = S.TargetPlayers, TargetNPCs = S.TargetNPCs, TeamCheck = S.TeamCheck,
                AutoEnableOnEquip = S.AutoEnableOnEquip, IgnoreDead = S.IgnoreDead,
            }
            if S.SavePresetsToFile then S.SavePresetsToFile() end
            if PresetDropdownRef and PresetDropdownRef.Refresh then
                pcall(function() PresetDropdownRef:Refresh(GetPresetNamesList(), true) end)
            end
            if S.Notify then S.Notify({Title = "TASFF Presets", Content = "Saved profile: " .. PresetInputName, Duration = 3, Image = "folder-plus"}) end
        end
    end
})

PresetDropdownRef = PresetsTab:CreateDropdown({
    Name          = "Saved Profiles Database",
    Options       = GetPresetNamesList(),
    CurrentOption = {"No Profiles Found"},
    Flag          = "PresetSelectDropdown",
    Callback      = function(v) SelectedPresetToManage = v end
})

PresetsTab:CreateButton({
    Name     = "Load Selected Profile",
    Callback = function()
        if SelectedPresetToManage and S.SavedPresets[SelectedPresetToManage] then
            local data = S.SavedPresets[SelectedPresetToManage]
            for key, value in pairs(data) do S[key] = value end
            if S.Notify then S.Notify({Title = "TASFF Presets", Content = "Successfully loaded profile: " .. SelectedPresetToManage .. "\n(UI toggles may require manual syncing)", Duration = 4, Image = "folder-open"}) end
        else
            if S.Notify then S.Notify({Title = "TASFF Presets", Content = "No valid profile selected.", Duration = 2, Image = "alert-circle"}) end
        end
    end
})

PresetsTab:CreateButton({
    Name     = "Delete Selected Profile",
    Callback = function()
        if SelectedPresetToManage and SelectedPresetToManage ~= "No Profiles Found" and S.SavedPresets[SelectedPresetToManage] then
            S.SavedPresets[SelectedPresetToManage] = nil
            if S.SavePresetsToFile then S.SavePresetsToFile() end
            if PresetDropdownRef and PresetDropdownRef.Refresh then
                local list = GetPresetNamesList()
                pcall(function() PresetDropdownRef:Refresh(list, true) end)
            end
            if S.Notify then S.Notify({Title = "TASFF Presets", Content = "Deleted profile: " .. SelectedPresetToManage, Duration = 3, Image = "folder-minus"}) end
            SelectedPresetToManage = ""
        else
            if S.Notify then S.Notify({Title = "TASFF Presets", Content = "No valid profile selected to delete.", Duration = 2, Image = "alert-triangle"}) end
        end
    end
})

PresetsTab:CreateSection("Clipboard & Cloud Sharing")
PresetsTab:CreateParagraph({
    Title   = "Share Your Configurations",
    Content = "Export your entire preset database to your clipboard as a JSON string to share with friends, or paste their string below to import their setups."
})

PresetsTab:CreateButton({
    Name     = "Export Database to Clipboard",
    Callback = function()
        local sc = setclipboard or (getgenv and getgenv().setclipboard)
        if sc then
            sc(HttpService:JSONEncode(S.SavedPresets))
            if S.Notify then S.Notify({Title = "TASFF Configs", Content = "Saved all presets to clipboard! You can now paste and share.", Duration = 3, Image = "clipboard-copy"}) end
        else
            if S.Notify then S.Notify({Title = "TASFF Configs", Content = "Your executor does not support setclipboard.", Duration = 3, Image = "alert-octagon"}) end
        end
    end
})

PresetsTab:CreateButton({
    Name     = "Import Database from Clipboard",
    Callback = function()
        pcall(function()
            local gc = getclipboard or (getgenv and getgenv().getclipboard)
            if gc then
                local clipData = gc()
                local success, decoded = pcall(HttpService.JSONDecode, HttpService, clipData)
                if success and type(decoded) == "table" then
                    for k, v in pairs(decoded) do S.SavedPresets[k] = v end
                    if S.SavePresetsToFile then S.SavePresetsToFile() end
                    if PresetDropdownRef and PresetDropdownRef.Refresh then
                        pcall(function() PresetDropdownRef:Refresh(GetPresetNamesList(), true) end)
                    end
                    if S.Notify then S.Notify({Title = "TASFF Configs", Content = "Presets successfully imported and UI updated!", Duration = 3, Image = "clipboard-check"}) end
                else
                    if S.Notify then S.Notify({Title = "Import Failed", Content = "Invalid preset data found in clipboard.", Duration = 3, Image = "file-warning"}) end
                end
            else
                if S.Notify then S.Notify({Title = "TASFF Configs", Content = "Your executor does not support getclipboard.", Duration = 3, Image = "alert-octagon"}) end
            end
        end)
    end
})

PresetsTab:CreateInput({
    Name                     = "Manual JSON Database Import",
    PlaceholderText          = "Paste raw JSON data here...",
    RemoveTextAfterFocusLost = true,
    Callback                 = function(text)
        if text and text ~= "" then
            local success, decoded = pcall(function() return HttpService:JSONDecode(text) end)
            if success and type(decoded) == "table" then
                for k, v in pairs(decoded) do S.SavedPresets[k] = v end
                if S.SavePresetsToFile then S.SavePresetsToFile() end
                if PresetDropdownRef and PresetDropdownRef.Refresh then
                    pcall(function() PresetDropdownRef:Refresh(GetPresetNamesList(), true) end)
                end
                if S.Notify then S.Notify({Title = "TASFF Configs", Content = "Successfully imported profiles manually!", Duration = 3, Image = "file-check"}) end
            else
                if S.Notify then S.Notify({Title = "Import Failed", Content = "Syntax Error: Invalid JSON structure.", Duration = 3, Image = "file-x"}) end
            end
        end
    end
})

-- // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• // --
-- //                       7. THEMING TAB                         // --
-- // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• // --

local CustomizationTab = Window:CreateTab("Theming", "brush")

CustomizationTab:CreateSection("Overlay Color Engine")
CustomizationTab:CreateParagraph({
    Title   = "Visual Synchronization",
    Content = "Select unified color profiles for your visual overlays. These settings apply instantly across all active geometric elements on your screen."
})

CustomizationTab:CreateDropdown({
    Name          = "FOV Constraint Circle Color",
    Options       = ColorDropdownOptions,
    CurrentOption = {"Tan"},
    Flag          = "FOVCircleColorDropdown",
    Callback      = function(v)
        local rgb = ColorPresetMap[v[1]]
        if rgb and _G.UpdateFOVCircleColor then _G.UpdateFOVCircleColor(rgb) end
    end
})

CustomizationTab:CreateDropdown({
    Name          = "ESP Geometry Color (Boxes/Skeletons/Tags)",
    Options       = ColorDropdownOptions,
    CurrentOption = {"Maroon"},
    Flag          = "HighlightColorDropdown",
    Callback      = function(v)
        local rgb = ColorPresetMap[v[1]]
        if rgb then S.HighlightColor = rgb end
    end
})

CustomizationTab:CreateDropdown({
    Name          = "Vector Crosshair Color",
    Options       = ColorDropdownOptions,
    CurrentOption = {"Coral"},
    Flag          = "CrosshairColorDropdown",
    Callback      = function(v)
        local rgb = ColorPresetMap[v[1]]
        if rgb and _G.UpdateCrosshairColor then _G.UpdateCrosshairColor(rgb) end
    end
})

CustomizationTab:CreateDropdown({
    Name          = "Snapline & OOF Arrow Color",
    Options       = ColorDropdownOptions,
    CurrentOption = {"Red"},
    Flag          = "SnaplineColorDropdown",
    Callback      = function(v)
        local rgb = ColorPresetMap[v[1]]
        if rgb then S.SnaplineColor = rgb end
    end
})

CustomizationTab:CreateSection("Fine Control (Color Pickers)")
CustomizationTab:CreateParagraph({
    Title   = "Custom Color Overrides",
    Content = "Manually fine-tune the colors for Dynamic Visibility mode. Note: The dropdowns above will override these settings if selected."
})
CustomizationTab:CreateColorPicker({
    Name     = "Visible Target Color (Dynamic)",
    Color    = Color3.fromRGB(0, 255, 0),
    Flag     = "VisibleColorPicker",
    Callback = function(Value) S.VisibleColor = Value end
})
CustomizationTab:CreateColorPicker({
    Name     = "Hidden Target Color (Dynamic)",
    Color    = Color3.fromRGB(255, 0, 0),
    Flag     = "HiddenColorPicker",
    Callback = function(Value) S.HiddenColor = Value end
})

-- // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• // --
-- //                        8. SYSTEM TAB                         // --
-- // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• // --

local MiscTab = Window:CreateTab("System", "cog")

MiscTab:CreateSection("Performance Engine")
PerformanceIndicator = MiscTab:CreateParagraph({
    Title   = "Active Performance Profile",
    Content = "Current Mode: " .. (S.PerformanceMode or "Medium") ..
              " (Interval: " .. ((S.PerformanceIntervals or {})[S.PerformanceMode] or 3) .. " frames)"
})
S.PerformanceIndicator = PerformanceIndicator

MiscTab:CreateDropdown({
    Name            = "Core Frame-Skip Strategy",
    Options         = S.PerformanceModes or {"Ultra High", "High", "Medium", "Low", "Ultra Low"},
    CurrentOption   = {S.PerformanceMode},
    MultipleOptions = false,
    Flag            = "PerformanceMode",
    Callback        = function(v)
        S.PerformanceMode = v[1] or "Medium"
        S.FrameCounters.HeavySystems = 0
        S.FrameCounters.NPCs         = 0
        S.FrameCounters.WorkspaceSweep = 0
        S.FrameCounters.CacheCleanup = 0
        pcall(function()
            PerformanceIndicator:Set({
                Title   = "Active Performance Profile",
                Content = "Current Mode: " .. S.PerformanceMode ..
                          " (Interval: " .. ((S.PerformanceIntervals or {})[S.PerformanceMode] or 3) .. " frames)"
            })
        end)
    end
})

MiscTab:CreateSection("Security & Failsafes")
MiscTab:CreateParagraph({
    Title   = "Panic System & Clean Unload",
    Content = "Panic: Instantly suspends Master Switch, releases all virtual mouse/key inputs, and hides overlays.\nKill/Unload: Destroys the Rayfield GUI completely and terminates all backend memory connections."
})

MiscTab:CreateToggle({Name = "Silence All Notifications", CurrentValue = S.DisableNotifications, Flag = "DisableNotifications", Callback = function(v)
    S.DisableNotifications = v
end})

MiscTab:CreateKeybind({
    Name           = "Global Panic Keybind",
    CurrentKeybind = S.PanicKeybind or "Delete",
    Flag           = "PanicKeybind",
    Callback       = function(key) S.PanicKeybind = key end
})

MiscTab:CreateButton({
    Name     = "Execute Panic Protocol",
    Callback = function()
        if S.TriggerPanic then S.TriggerPanic() end
    end
})

MiscTab:CreateButton({
    Name     = "Factory Reset (Restore All Defaults)",
    Callback = function()
        -- Exhaustive reset to prevent "frankenstein" states
        S.MasterEnabled = false;        S.TargetingEnabled = true;      S.Mode = "Legit (Camera)"
        S.TargetPart = "Head";          S.ActivePartName = "Head"
        S.PriorityMode = "None";        S.VitalityMode = "None";        S.TargetNearCenter = false
        S.Smoothness = 1.5;             S.PredictionAmount = 0.16
        S.SilentAimEnabled = false;     S.DynamicRecoilEnabled = false
        S.RandomizeHitboxEnabled = false
        S.TargetSwitchDelayEnabled = false; S.SwitchDelayMs = 200
        S.GracePeriodEnabled = false;   S.GracePeriodMs = 150
        S.AimbotRenderDistance = 1000;  S.StickyAimEnabled = false;     S.AutoADSEnabled = false
        S.VisualMode = "Single";        S.UseHighlight = true;          S.UseNPCHighlight = true
        S.FocusMode = false;            S.StreamProofESP = true;        S.VisibilityColorsEnabled = false
        S.ESPRenderDistance = 1000;     S.ChamsEnabled = false;         S.ChamsOpacity = 10
        S.BoxModeEnabled = false;       S.SkeletonModeEnabled = false
        S.SnaplinesEnabled = false;     S.SnaplineOrigin = "Bottom"
        S.OOFArrowsEnabled = false;     S.OOFArrowRadius = 150
        S.UseInfoTag = true;            S.UseNPCInfoTag = true
        S.ShowDisplayName = false;      S.ShowToolCheck = false
        S.ShowFOV = false;              S.InvisibleFOV = false;         S.FOVSize = 100
        S.AimReferenceMode = "Screen Center"
        S.EnableCrosshair = false;      S.CrosshairStyle = "Plus";      S.CrosshairSize = 10
        S.ManualCalibrationEnabled = false; S.CalibrationOffsetX = 0;   S.CalibrationOffsetY = 0
        S.AutoClickEnabled = false;     S.TriggerbotClickMode = "Virtual"; S.ClickMethod = "Mash"
        S.ClickInterval = 100;          S.ThirdPersonTriggerbot = false
        S.KeyTriggerbotEnabled = false; S.KeyTriggerMode = "Single Press"
        S.MeleeModeEnabled = false;     S.MeleeDetectionRange = 5;      S.MeleeClickInterval = 100
        S.ThreatDetectorEnabled = false; S.NemesisEnabled = true;       S.ThreatTimeout = 10
        S.BlacklistExpiredThreats = false
        S.ClickToMarkEnabled = false;   S.MarkMethod = "Both"
        S.StrictPrioritize = false;     S.WallCheck = true
        S.NoCollisionCheck = false;     S.TransparencyCheck = false;    S.TransparencyThreshold = 0.5
        S.DecalsCheck = false
        S.TargetPlayers = true;         S.TargetNPCs = false;           S.TeamCheck = false
        S.AutoEnableOnEquip = false;    S.IgnoreDead = true
        S.CurrentTarget = nil
        if S.SetADSState    then S.SetADSState(false) end
        if S.ClearVisuals   then S.ClearVisuals()     end
        if S.ClearCrosshair then S.ClearCrosshair()   end
        if S.Notify then S.Notify({Title = "TASFF System", Content = "Factory Reset complete. All modules restored to default.", Duration = 3, Image = "list-restart"}) end
    end
})

MiscTab:CreateButton({
    Name     = "Terminate Script & Unload Interface",
    Callback = function()
        if S.UnloadScript then S.UnloadScript() end
    end
})

-- // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• // --
-- //                      9. UPDATE LOG TAB                       // --
-- // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• // --

local UpdateLogTab = Window:CreateTab("Update Log", "history")
UpdateLogTab:CreateSection("Version 2.0.0 (Current Release)")
UpdateLogTab:CreateLabel("- Version bump to V2.0.0 � modular refactor across 4 files (State/Core/UI/Loader)")
UpdateLogTab:CreateLabel("- Resolved the Lua 200-local engine limit via _G.TASFF_State shared module pattern")
UpdateLogTab:CreateLabel("- Restored the original TASFF black-and-red UI theme with complete monolith feature parity")
UpdateLogTab:CreateLabel("- Completely decoupled ESP rendering from heavy targeting math for butter-smooth 60+ FPS visuals")
UpdateLogTab:CreateLabel("- Multi-hop penetrative wallcheck (up to 15 hops) for advanced glass/decal penetration")
UpdateLogTab:CreateLabel("- Patched frustum culling bug where off-screen targets were dropped, fully restoring OOF Arrows")
UpdateLogTab:CreateLabel("- Fixed Rayfield array-unpacking bugs that previously broke Crosshairs and Visual Mode logic")
UpdateLogTab:CreateLabel("- Added Fine Control Color Pickers for precise Dynamic Visibility (Visible/Hidden) overrides")
UpdateLogTab:CreateLabel("- Frame-scope scalar caching in render loop for reduced overhead")
UpdateLogTab:CreateLabel("- Combined CharacterAdded handler (threat hook + tool observer in one connection)")
UpdateLogTab:CreateLabel("- Re-structured the rendering loop to ensure visual overlays persist accurately on dropped frames")
UpdateLogTab:CreateLabel("- Added UTF-8 BOM stripping and HTML error detection to the module loader")
UpdateLogTab:CreateLabel("- Corrected ConfigurationSaving folder path to match current version")

UpdateLogTab:CreateSection("Version 1.5.0")
UpdateLogTab:CreateLabel("- Completely overhauled the UI layout into professional, structured categories (HUD, Tactical Overlays, etc.)")
UpdateLogTab:CreateLabel("- Fixed a critical metamethod inversion that broke Silent Aim for native weapons and ruined wallchecks")
UpdateLogTab:CreateLabel("- Fixed a math bug where Distance Priority sorted by 2D screen distance instead of true 3D world distance")
UpdateLogTab:CreateLabel("- Fixed drawing persistence glitches (Invisible FOV) by bypassing backend geometry updates when hidden")
UpdateLogTab:CreateLabel("- Fixed missing variable serialization in the Preset Configuration Saver and Factory Reset protocols")
UpdateLogTab:CreateLabel("- Fixed rendering invisibility issues across all ESP geometries (Drawing API transparency mappings)")
UpdateLogTab:CreateLabel("- Added a missing Remove Tool registry function to the Weapon & Inventory Automation section")
UpdateLogTab:CreateLabel("- Patched multiple global scope leaks and a potential fatal crash in the Skeletal Mapping routine")

UpdateLogTab:CreateSection("Version 1.4.5")
UpdateLogTab:CreateLabel("- Added Advanced Legit Mode utilizing Bezier curves for humanized camera smoothing")
UpdateLogTab:CreateLabel("- Added Dynamic Recoil Control (DRC) to mimic natural human recoil compensation")
UpdateLogTab:CreateLabel("- Added Virtual Flickbot (Cursor Aim) to instantly teleport the invisible mouse cursor")
UpdateLogTab:CreateLabel("- Implemented Universal Silent Aim (Namecall Hooking) to redirect bullets silently")
UpdateLogTab:CreateLabel("- Added Target Switch Delay to pause target acquisition after kills (prevents robotic snapping)")
UpdateLogTab:CreateLabel("- Added Randomized Hitboxes to bypass statistical anti-cheats in Legit mode")
UpdateLogTab:CreateLabel("- Implemented The Nemesis System for tiered death tracking and targeted retaliation")
UpdateLogTab:CreateLabel("- Added Marking Input Modes (Mouse, Keybind, or Both) to prevent accidental priority marking")
UpdateLogTab:CreateLabel("- Added Dynamic Visibility Colors (Green=Visible, Red=Hidden) to ESP geometries")
UpdateLogTab:CreateLabel("- Upgraded all Info Tags to Drawing API for complete Stream-Proofing (OBS bypass)")
UpdateLogTab:CreateLabel("- Added Off-Screen Indicators (OOF Arrows) to track targets located behind the camera")
UpdateLogTab:CreateLabel("- Added ESP Snaplines (Tracers) with configurable origin point positioning")
UpdateLogTab:CreateLabel("- Added Clipboard Preset Import & Export (JSON) for easy configuration sharing")
UpdateLogTab:CreateLabel("- Added Auto-Save Configuration protocol to preserve settings upon script unload")

UpdateLogTab:CreateSection("Version 1.4.0")
UpdateLogTab:CreateLabel("- Added Threat Detector & Threat Memory subsystem with configurable timeout")
UpdateLogTab:CreateLabel("- Implemented Strict Prioritize targeting mode")
UpdateLogTab:CreateLabel("- Added Invisible FOV mode (maintains lock boundary without rendering circle)")
UpdateLogTab:CreateLabel("- Added Penetrative Wallchecks (No Collision, Transparency Threshold & Decals)")
UpdateLogTab:CreateLabel("- Implemented Auto ADS (Aim Down Sights) automatic holding")
UpdateLogTab:CreateLabel("- Added Click-to-Mark / Keybind-to-Mark and Focus Mode ESP filtering")
UpdateLogTab:CreateLabel("- Added Triggerbot Click Modes (Virtual vs Physical) & 3rd Person coordinate support")
UpdateLogTab:CreateLabel("- Added Key Triggerbot with Single Press, Mash, and Hold modes")
UpdateLogTab:CreateLabel("- Added Dedicated Advanced Settings Tab and Misc utilities (Panic, Reset, Clean Unload)")
UpdateLogTab:CreateLabel("- Full frame-skipping Performance engine with runtime mode indicator")

UpdateLogTab:CreateSection("Version 1.3.5")
UpdateLogTab:CreateLabel("- Added Aimbot & ESP Render Distance culling sliders (100-1000 studs)")
UpdateLogTab:CreateLabel("- Implemented Target Grace Period delay timer before locking onto targets")
UpdateLogTab:CreateLabel("- Added Chams ESP mode featuring dynamic transparency/opacity controls")
UpdateLogTab:CreateLabel("- Added 2D Box ESP visual overlay")
UpdateLogTab:CreateLabel("- Added Skeleton ESP rendering with full support for R6 & R15 avatar joint structures")
UpdateLogTab:CreateLabel("- Fixed table reference mutation corruption on cached ignore list raycasts")
UpdateLogTab:CreateLabel("- Fixed Melee Mode execution structure to operate independently of Aimbot lock states")
UpdateLogTab:CreateLabel("- Added a brand new Presets Tab featuring profile saving, loading, renaming, and deletion")

UpdateLogTab:CreateSection("Version 1.3.0")
UpdateLogTab:CreateLabel("- Added Target Near Center crosshair prioritization to Combat options")
UpdateLogTab:CreateLabel("- Added Inventory Auto-Activation trigger system upon tool equipping features")
UpdateLogTab:CreateLabel("- Added Instant Tool-Instance Blacklist registration action buttons to Settings")
UpdateLogTab:CreateLabel("- Implemented advanced vector-rendered screen center Crosshairs (Plus, Square, Circle)")
UpdateLogTab:CreateLabel("- Added Crosshair color mapping configurations straight to Customization presets")
UpdateLogTab:CreateLabel("- Added character text extensions: Show Display Name and structural Tool Check tags")

UpdateLogTab:CreateSection("Version 1.2.5")
UpdateLogTab:CreateLabel("- Added full-screen targeting mechanics automatically when FOV visual elements are disabled")
UpdateLogTab:CreateLabel("- Added complete Autoclicker Tab featuring customizable speed interval mechanics")
UpdateLogTab:CreateLabel("- Implemented input options: Repeated rapid Mash triggers vs continuous input Hold states")
UpdateLogTab:CreateLabel("- Added Combat Melee Mode subsystem with independent range and interval calculations")
UpdateLogTab:CreateLabel("- Added fully separated Highlight NPCs and Show NPC Info toggle parameters")
UpdateLogTab:CreateLabel("- Added persistent Sticky Aim mechanics with automatic target validation filters")
UpdateLogTab:CreateLabel("- Fixed Sticky Aim wall clipping bugs by routing locks directly into visibility raycasts")

UpdateLogTab:CreateSection("Version 1.2.0")
UpdateLogTab:CreateLabel("- Added a brand new Customization Tab with color presets")
UpdateLogTab:CreateLabel("- Fixed the respawn bug where player highlights would vanish")
UpdateLogTab:CreateLabel("- Linked the Show Target Info text color directly to custom themes")
UpdateLogTab:CreateLabel("- Removed the broken dynamic interface theme reloader for stability")
UpdateLogTab:CreateLabel("- Added Visible On Screen, located in target bodypart dropdown")

-- // â”€â”€ Load Configuration â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ // --
-- MUST be called last. Restores all flagged values from disk and
-- fires each element's Callback, which writes them back into S.

Rayfield:LoadConfiguration()

print("[TASFF UI] Interface constructed. Configuration loaded.")

