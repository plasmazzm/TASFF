-- // ============================================================ // --
-- //   TASFF_UI.lua                                             // --
-- //   All Rayfield UI construction. Callbacks write to         // --
-- //   _G.TASFF_State (S) or call S.FunctionSlot().            // --
-- //   Must be loaded AFTER TASFF_Core.lua.                    // --
-- // ============================================================ // --

local S       = _G.TASFF_State
local Rayfield = getgenv().TASFF and getgenv().TASFF.Rayfield
local Players  = game:GetService("Players")
local Player   = Players.LocalPlayer

-- // ── UI-Local State (not in _G.TASFF_State) ───────────────────── // --
-- These variables only matter within the UI scope.

local PresetInputName      = ""
local SelectedBlacklistTool = ""
local BlacklistDropdown    = nil   -- exposed to Core via S.BlacklistDropdownRef
local PresetDropdown       = nil
local ToolBlacklistLabel   = nil

-- Color preset map (UI-local, for the Theming tab preset quick-select)
local ColorPresetMap = {
    ["Default (Cyan)"] = {
        Crosshair = Color3.fromRGB(0,   255, 255),
        FOV       = Color3.fromRGB(0,   255, 255),
        Highlight = Color3.fromRGB(255, 255, 255),
        Snapline  = Color3.fromRGB(0,   255, 255),
    },
    ["Red & White"] = {
        Crosshair = Color3.fromRGB(255, 60,  60),
        FOV       = Color3.fromRGB(255, 60,  60),
        Highlight = Color3.fromRGB(255, 255, 255),
        Snapline  = Color3.fromRGB(255, 60,  60),
    },
    ["Purple"] = {
        Crosshair = Color3.fromRGB(180, 0,   255),
        FOV       = Color3.fromRGB(180, 0,   255),
        Highlight = Color3.fromRGB(220, 180, 255),
        Snapline  = Color3.fromRGB(180, 0,   255),
    },
    ["Green"] = {
        Crosshair = Color3.fromRGB(0,   255, 100),
        FOV       = Color3.fromRGB(0,   255, 100),
        Highlight = Color3.fromRGB(200, 255, 200),
        Snapline  = Color3.fromRGB(0,   255, 100),
    },
    ["Gold"] = {
        Crosshair = Color3.fromRGB(255, 215, 0),
        FOV       = Color3.fromRGB(255, 215, 0),
        Highlight = Color3.fromRGB(255, 240, 150),
        Snapline  = Color3.fromRGB(255, 215, 0),
    },
}

local ColorDropdownOptions = {}
for name, _ in pairs(ColorPresetMap) do table.insert(ColorDropdownOptions, name) end
table.sort(ColorDropdownOptions)

-- Preset helpers
local function GetPresetNamesList()
    local names = {}
    for name, _ in pairs(S.SavedPresets) do table.insert(names, name) end
    table.sort(names)
    return names
end

local function RefreshToolBlacklistLabel()
    if not ToolBlacklistLabel then return end
    local text
    if #S.ToolBlacklist == 0 then
        text = "No tools currently blacklisted."
    else
        text = "• " .. table.concat(S.ToolBlacklist, "\n• ")
    end
    pcall(function()
        ToolBlacklistLabel:Set({
            Title   = "Tool Blacklist (" .. #S.ToolBlacklist .. ")",
            Content = text
        })
    end)
end

-- // ── Window ──────────────────────────────────────────────────── // --

local Window = Rayfield:CreateWindow({
    Name                   = "TASFF v1.5.5",
    Icon                   = 0,
    LoadingTitle           = "TASFF",
    LoadingSubtitle        = "by tasf",
    Theme                  = "Default",
    DisableRayfieldPrompts = false,
    DisableBuildWarnings   = false,
    ConfigurationSaving = {
        Enabled    = true,
        FolderName = "TASFF",
        FileName   = "TASFF_Config"
    },
    Discord    = { Enabled = false },
    KeySystem  = false,
})

-- // ══════════════════════════════════════════════════════════════ // --
-- //                        COMBAT TAB                            // --
-- // ══════════════════════════════════════════════════════════════ // --

local CombatTab = Window:CreateTab("Combat", "crosshair")

CombatTab:CreateSection("Core")

CombatTab:CreateToggle({
    Name         = "Master Switch",
    CurrentValue = S.MasterEnabled,
    Flag         = "MasterEnabled",
    Callback     = function(v)
        S.MasterEnabled = v
        if not v then
            S.AimbotActive  = false
            S.CurrentTarget = nil
            if S.SetADSState  then S.SetADSState(false) end
            if S.ClearVisuals then S.ClearVisuals() end
            if S.ClearCrosshair then S.ClearCrosshair() end
            if S.FOVCircle then S.FOVCircle.Visible = false end
        end
    end
})

CombatTab:CreateToggle({
    Name         = "Aimbot",
    CurrentValue = S.AimbotActive,
    Flag         = "AimbotActive",
    Callback     = function(v)
        S.AimbotActive = v
        if not v then
            S.CurrentTarget = nil
            if S.SetADSState then S.SetADSState(false) end
        end
    end
})

CombatTab:CreateToggle({
    Name         = "Targeting Engine",
    CurrentValue = S.TargetingEnabled,
    Flag         = "TargetingEnabled",
    Callback     = function(v) S.TargetingEnabled = v end
})

CombatTab:CreateToggle({
    Name         = "Sticky Aim",
    CurrentValue = S.StickyAimEnabled,
    Flag         = "StickyAimEnabled",
    Callback     = function(v) S.StickyAimEnabled = v end
})

CombatTab:CreateDropdown({
    Name          = "Aimbot Mode",
    Options       = {"Legit (Camera)", "Advanced Legit (Mouse)", "Blatant"},
    CurrentOption = {S.Mode},
    Flag          = "Mode",
    Callback      = function(v) S.Mode = v end
})

CombatTab:CreateSlider({
    Name         = "Smoothness",
    Range        = {0, 20},
    Increment    = 0.5,
    Suffix       = "",
    CurrentValue = S.Smoothness,
    Flag         = "Smoothness",
    Callback     = function(v) S.Smoothness = v end
})

CombatTab:CreateSlider({
    Name         = "Prediction Amount",
    Range        = {0, 1},
    Increment    = 0.01,
    Suffix       = "",
    CurrentValue = S.PredictionAmount,
    Flag         = "PredictionAmount",
    Callback     = function(v) S.PredictionAmount = v end
})

CombatTab:CreateSection("FOV")

CombatTab:CreateToggle({
    Name         = "Show FOV Circle",
    CurrentValue = S.ShowFOV,
    Flag         = "ShowFOV",
    Callback     = function(v)
        S.ShowFOV = v
        if not v and S.FOVCircle then S.FOVCircle.Visible = false end
    end
})

CombatTab:CreateToggle({
    Name         = "Invisible FOV (Hitbox Only)",
    CurrentValue = S.InvisibleFOV,
    Flag         = "InvisibleFOV",
    Callback     = function(v) S.InvisibleFOV = v end
})

CombatTab:CreateSlider({
    Name         = "FOV Size",
    Range        = {10, 800},
    Increment    = 5,
    Suffix       = "px",
    CurrentValue = S.FOVSize,
    Flag         = "FOVSize",
    Callback     = function(v) S.FOVSize = v end
})

CombatTab:CreateSection("Crosshair")

CombatTab:CreateToggle({
    Name         = "Enable Crosshair",
    CurrentValue = S.EnableCrosshair,
    Flag         = "EnableCrosshair",
    Callback     = function(v)
        S.EnableCrosshair = v
        if not v and S.ClearCrosshair then S.ClearCrosshair() end
    end
})

CombatTab:CreateDropdown({
    Name          = "Crosshair Style",
    Options       = {"Dot", "Plus", "Square", "Circle"},
    CurrentOption = {S.CrosshairStyle},
    Flag          = "CrosshairStyle",
    Callback      = function(v) S.CrosshairStyle = v end
})

CombatTab:CreateSlider({
    Name         = "Crosshair Size",
    Range        = {2, 50},
    Increment    = 1,
    Suffix       = "px",
    CurrentValue = S.CrosshairSize,
    Flag         = "CrosshairSize",
    Callback     = function(v) S.CrosshairSize = v end
})

CombatTab:CreateSection("Triggerbot")

CombatTab:CreateToggle({
    Name         = "Auto Click (Triggerbot)",
    CurrentValue = S.AutoClickEnabled,
    Flag         = "AutoClickEnabled",
    Callback     = function(v) S.AutoClickEnabled = v end
})

CombatTab:CreateDropdown({
    Name          = "Click Method",
    Options       = {"Hold", "Mash"},
    CurrentOption = {S.ClickMethod},
    Flag          = "ClickMethod",
    Callback      = function(v) S.ClickMethod = v end
})

CombatTab:CreateDropdown({
    Name          = "Click Mode",
    Options       = {"Virtual", "Physical"},
    CurrentOption = {S.TriggerbotClickMode},
    Flag          = "TriggerbotClickMode",
    Callback      = function(v) S.TriggerbotClickMode = v end
})

CombatTab:CreateSlider({
    Name         = "Click Interval",
    Range        = {10, 500},
    Increment    = 5,
    Suffix       = "ms",
    CurrentValue = S.ClickInterval,
    Flag         = "ClickInterval",
    Callback     = function(v) S.ClickInterval = v end
})

CombatTab:CreateSection("Key Triggerbot")

CombatTab:CreateToggle({
    Name         = "Key Triggerbot",
    CurrentValue = S.KeyTriggerbotEnabled,
    Flag         = "KeyTriggerbotEnabled",
    Callback     = function(v) S.KeyTriggerbotEnabled = v end
})

CombatTab:CreateInput({
    Name            = "Key Triggerbot Key",
    PlaceholderText = "e.g. E",
    OnEnter         = true,
    Flag            = "KeyTriggerbotKey",
    Callback        = function(v)
        S.KeyTriggerbotKey = v
        if S.Notify then
            S.Notify({Title = "Key Triggerbot", Content = "Key set to: " .. v, Duration = 2, Image = "keyboard"})
        end
    end
})

CombatTab:CreateDropdown({
    Name          = "Key Trigger Mode",
    Options       = {"Hold", "Mash", "Single Press"},
    CurrentOption = {S.KeyTriggerMode},
    Flag          = "KeyTriggerMode",
    Callback      = function(v) S.KeyTriggerMode = v end
})

CombatTab:CreateSection("Melee Mode")

CombatTab:CreateToggle({
    Name         = "Melee Auto-Click",
    CurrentValue = S.MeleeModeEnabled,
    Flag         = "MeleeModeEnabled",
    Callback     = function(v) S.MeleeModeEnabled = v end
})

CombatTab:CreateSlider({
    Name         = "Melee Detection Range",
    Range        = {1, 30},
    Increment    = 0.5,
    Suffix       = "st",
    CurrentValue = S.MeleeDetectionRange,
    Flag         = "MeleeDetectionRange",
    Callback     = function(v) S.MeleeDetectionRange = v end
})

CombatTab:CreateSlider({
    Name         = "Melee Click Interval",
    Range        = {10, 500},
    Increment    = 5,
    Suffix       = "ms",
    CurrentValue = S.MeleeClickInterval,
    Flag         = "MeleeClickInterval",
    Callback     = function(v) S.MeleeClickInterval = v end
})

CombatTab:CreateToggle({
    Name         = "Third-Person Triggerbot",
    CurrentValue = S.ThirdPersonTriggerbot,
    Flag         = "ThirdPersonTriggerbot",
    Callback     = function(v) S.ThirdPersonTriggerbot = v end
})

CombatTab:CreateSection("Silent Aim")

CombatTab:CreateToggle({
    Name         = "Silent Aim",
    CurrentValue = S.SilentAimEnabled,
    Flag         = "SilentAimEnabled",
    Callback     = function(v)
        S.SilentAimEnabled = v
        if S.Notify then
            S.Notify({
                Title   = "Silent Aim",
                Content = v and "Silent Aim enabled." or "Silent Aim disabled.",
                Duration = 2,
                Image   = v and "crosshair" or "x"
            })
        end
    end
})

-- // ══════════════════════════════════════════════════════════════ // --
-- //                       TARGETING TAB                          // --
-- // ══════════════════════════════════════════════════════════════ // --

local TargetingTab = Window:CreateTab("Targeting", "target")

TargetingTab:CreateSection("Target Filters")

TargetingTab:CreateToggle({
    Name         = "Target Players",
    CurrentValue = S.TargetPlayers,
    Flag         = "TargetPlayers",
    Callback     = function(v)
        S.TargetPlayers = v
        if not v and S.CurrentTarget and S.CurrentTarget.IsPlayer then
            S.CurrentTarget = nil
        end
    end
})

TargetingTab:CreateToggle({
    Name         = "Target NPCs",
    CurrentValue = S.TargetNPCs,
    Flag         = "TargetNPCs",
    Callback     = function(v)
        S.TargetNPCs = v
        if not v and S.CurrentTarget and not S.CurrentTarget.IsPlayer then
            S.CurrentTarget = nil
        end
    end
})

TargetingTab:CreateToggle({
    Name         = "Team Check",
    CurrentValue = S.TeamCheck,
    Flag         = "TeamCheck",
    Callback     = function(v) S.TeamCheck = v end
})

TargetingTab:CreateToggle({
    Name         = "Ignore Dead",
    CurrentValue = S.IgnoreDead,
    Flag         = "IgnoreDead",
    Callback     = function(v) S.IgnoreDead = v end
})

TargetingTab:CreateDropdown({
    Name          = "Aim Target Part",
    Options       = {"Head", "Torso", "UpperTorso", "LowerTorso", "HumanoidRootPart", "Visible On Screen"},
    CurrentOption = {S.TargetPart},
    Flag          = "TargetPart",
    Callback      = function(v) S.TargetPart = v end
})

TargetingTab:CreateSection("Wall Check")

TargetingTab:CreateToggle({
    Name         = "Wall Check",
    CurrentValue = S.WallCheck,
    Flag         = "WallCheck",
    Callback     = function(v) S.WallCheck = v end
})

TargetingTab:CreateDropdown({
    Name          = "Wall Check Part",
    Options       = {"Head", "Torso", "UpperTorso", "HumanoidRootPart"},
    CurrentOption = {S.ActivePartName},
    Flag          = "ActivePartName",
    Callback      = function(v) S.ActivePartName = v end
})

TargetingTab:CreateToggle({
    Name         = "No-Collision Penetration",
    CurrentValue = S.NoCollisionCheck,
    Flag         = "NoCollisionCheck",
    Callback     = function(v) S.NoCollisionCheck = v end
})

TargetingTab:CreateToggle({
    Name         = "Transparency Penetration",
    CurrentValue = S.TransparencyCheck,
    Flag         = "TransparencyCheck",
    Callback     = function(v) S.TransparencyCheck = v end
})

TargetingTab:CreateSlider({
    Name         = "Transparency Threshold",
    Range        = {0, 1},
    Increment    = 0.05,
    Suffix       = "",
    CurrentValue = S.TransparencyThreshold,
    Flag         = "TransparencyThreshold",
    Callback     = function(v) S.TransparencyThreshold = v end
})

TargetingTab:CreateToggle({
    Name         = "Decal Penetration",
    CurrentValue = S.DecalsCheck,
    Flag         = "DecalsCheck",
    Callback     = function(v) S.DecalsCheck = v end
})

TargetingTab:CreateSection("Priority & Blacklist")

local PriorityDropdown = TargetingTab:CreateDropdown({
    Name            = "Priority Players",
    Options         = S.GetPlayerNames and S.GetPlayerNames() or {},
    CurrentOption   = S.PriorityPlayers,
    MultipleOptions = true,
    Flag            = "PriorityPlayers",
    Callback        = function(v)
        S.PriorityPlayers = v
        if S.SyncPriorityUI then S.SyncPriorityUI() end
    end
})
S.PriorityDropdownRef = PriorityDropdown

local PriorityMonitorLabel = TargetingTab:CreateParagraph({
    Title   = "Active Priority Targets (0)",
    Content = "No priority targets currently selected."
})
S.PriorityMonitorLabel = PriorityMonitorLabel

TargetingTab:CreateToggle({
    Name         = "Strict Prioritize (Priority Targets Only)",
    CurrentValue = S.StrictPrioritize,
    Flag         = "StrictPrioritize",
    Callback     = function(v) S.StrictPrioritize = v end
})

TargetingTab:CreateToggle({
    Name         = "Nemesis System",
    CurrentValue = S.NemesisEnabled,
    Flag         = "NemesisEnabled",
    Callback     = function(v) S.NemesisEnabled = v end
})

BlacklistDropdown = TargetingTab:CreateDropdown({
    Name            = "Blacklisted Players",
    Options         = S.BlacklistedPlayers,
    CurrentOption   = S.BlacklistedPlayers,
    MultipleOptions = true,
    Flag            = "BlacklistedPlayers",
    Callback        = function(v)
        S.BlacklistedPlayers = v
        if S.CurrentTarget and S.CurrentTarget.Name and table.find(v, S.CurrentTarget.Name) then
            S.CurrentTarget = nil
        end
    end
})
S.BlacklistDropdownRef = BlacklistDropdown

TargetingTab:CreateButton({
    Name     = "Clear Blacklist",
    Callback = function()
        S.BlacklistedPlayers = {}
        if BlacklistDropdown and BlacklistDropdown.Refresh then
            pcall(function() BlacklistDropdown:Refresh({}, {}) end)
        end
        if S.Notify then
            S.Notify({Title = "Blacklist", Content = "Player blacklist cleared.", Duration = 2, Image = "trash"})
        end
    end
})

TargetingTab:CreateSection("Target Sorting")

TargetingTab:CreateDropdown({
    Name          = "Priority Mode",
    Options       = {"Closest", "Farthest", "Screen Center"},
    CurrentOption = {S.PriorityMode},
    Flag          = "PriorityMode",
    Callback      = function(v) S.PriorityMode = v end
})

TargetingTab:CreateDropdown({
    Name          = "Vitality Mode",
    Options       = {"None", "Weakest (HP)", "Strongest (HP)"},
    CurrentOption = {S.VitalityMode},
    Flag          = "VitalityMode",
    Callback      = function(v) S.VitalityMode = v end
})

TargetingTab:CreateToggle({
    Name         = "Target Near Screen Center",
    CurrentValue = S.TargetNearCenter,
    Flag         = "TargetNearCenter",
    Callback     = function(v) S.TargetNearCenter = v end
})

TargetingTab:CreateSection("Distances")

TargetingTab:CreateSlider({
    Name         = "Aimbot Render Distance",
    Range        = {50, 5000},
    Increment    = 50,
    Suffix       = "st",
    CurrentValue = S.AimbotRenderDistance,
    Flag         = "AimbotRenderDistance",
    Callback     = function(v) S.AimbotRenderDistance = v end
})

TargetingTab:CreateSlider({
    Name         = "ESP Render Distance",
    Range        = {50, 5000},
    Increment    = 50,
    Suffix       = "st",
    CurrentValue = S.ESPRenderDistance,
    Flag         = "ESPRenderDistance",
    Callback     = function(v) S.ESPRenderDistance = v end
})

TargetingTab:CreateSection("Grace Period & Switch Delay")

TargetingTab:CreateToggle({
    Name         = "Grace Period",
    CurrentValue = S.GracePeriodEnabled,
    Flag         = "GracePeriodEnabled",
    Callback     = function(v) S.GracePeriodEnabled = v end
})

TargetingTab:CreateSlider({
    Name         = "Grace Period Duration",
    Range        = {0, 3000},
    Increment    = 50,
    Suffix       = "ms",
    CurrentValue = S.GracePeriodMs,
    Flag         = "GracePeriodMs",
    Callback     = function(v) S.GracePeriodMs = v end
})

TargetingTab:CreateToggle({
    Name         = "Target Switch Delay",
    CurrentValue = S.TargetSwitchDelayEnabled,
    Flag         = "TargetSwitchDelayEnabled",
    Callback     = function(v) S.TargetSwitchDelayEnabled = v end
})

TargetingTab:CreateSlider({
    Name         = "Switch Delay Duration",
    Range        = {0, 3000},
    Increment    = 50,
    Suffix       = "ms",
    CurrentValue = S.SwitchDelayMs,
    Flag         = "SwitchDelayMs",
    Callback     = function(v) S.SwitchDelayMs = v end
})

TargetingTab:CreateSection("Aim Reference & Calibration")

TargetingTab:CreateDropdown({
    Name          = "Aim Reference Mode",
    Options       = {"Screen Center", "Mouse Tracking"},
    CurrentOption = {S.AimReferenceMode},
    Flag          = "AimReferenceMode",
    Callback      = function(v) S.AimReferenceMode = v end
})

TargetingTab:CreateToggle({
    Name         = "Manual Calibration",
    CurrentValue = S.ManualCalibrationEnabled,
    Flag         = "ManualCalibrationEnabled",
    Callback     = function(v) S.ManualCalibrationEnabled = v end
})

TargetingTab:CreateSlider({
    Name         = "Calibration Offset X",
    Range        = {-200, 200},
    Increment    = 1,
    Suffix       = "px",
    CurrentValue = S.CalibrationOffsetX,
    Flag         = "CalibrationOffsetX",
    Callback     = function(v) S.CalibrationOffsetX = v end
})

TargetingTab:CreateSlider({
    Name         = "Calibration Offset Y",
    Range        = {-200, 200},
    Increment    = 1,
    Suffix       = "px",
    CurrentValue = S.CalibrationOffsetY,
    Flag         = "CalibrationOffsetY",
    Callback     = function(v) S.CalibrationOffsetY = v end
})

TargetingTab:CreateToggle({
    Name         = "Randomize Hitbox Part",
    CurrentValue = S.RandomizeHitboxEnabled,
    Flag         = "RandomizeHitboxEnabled",
    Callback     = function(v) S.RandomizeHitboxEnabled = v end
})

-- // ══════════════════════════════════════════════════════════════ // --
-- //                          ESP TAB                             // --
-- // ══════════════════════════════════════════════════════════════ // --

local ESPTab = Window:CreateTab("ESP", "eye")

ESPTab:CreateSection("Highlights & Chams")

ESPTab:CreateToggle({
    Name         = "Player Highlights",
    CurrentValue = S.UseHighlight,
    Flag         = "UseHighlight",
    Callback     = function(v) S.UseHighlight = v end
})

ESPTab:CreateToggle({
    Name         = "NPC Highlights",
    CurrentValue = S.UseNPCHighlight,
    Flag         = "UseNPCHighlight",
    Callback     = function(v) S.UseNPCHighlight = v end
})

ESPTab:CreateToggle({
    Name         = "Chams (Always On Top)",
    CurrentValue = S.ChamsEnabled,
    Flag         = "ChamsEnabled",
    Callback     = function(v) S.ChamsEnabled = v end
})

ESPTab:CreateSlider({
    Name         = "Chams Opacity",
    Range        = {1, 10},
    Increment    = 1,
    Suffix       = "",
    CurrentValue = S.ChamsOpacity,
    Flag         = "ChamsOpacity",
    Callback     = function(v) S.ChamsOpacity = v end
})

ESPTab:CreateSection("Info Tags")

ESPTab:CreateToggle({
    Name         = "Player Info Tags",
    CurrentValue = S.UseInfoTag,
    Flag         = "UseInfoTag",
    Callback     = function(v) S.UseInfoTag = v end
})

ESPTab:CreateToggle({
    Name         = "NPC Info Tags",
    CurrentValue = S.UseNPCInfoTag,
    Flag         = "UseNPCInfoTag",
    Callback     = function(v) S.UseNPCInfoTag = v end
})

ESPTab:CreateToggle({
    Name         = "Show Display Name",
    CurrentValue = S.ShowDisplayName,
    Flag         = "ShowDisplayName",
    Callback     = function(v) S.ShowDisplayName = v end
})

ESPTab:CreateToggle({
    Name         = "Show Held Tool",
    CurrentValue = S.ShowToolCheck,
    Flag         = "ShowToolCheck",
    Callback     = function(v) S.ShowToolCheck = v end
})

ESPTab:CreateSection("Snaplines & OOF Arrows")

ESPTab:CreateToggle({
    Name         = "Snaplines",
    CurrentValue = S.SnaplinesEnabled,
    Flag         = "SnaplinesEnabled",
    Callback     = function(v) S.SnaplinesEnabled = v end
})

ESPTab:CreateDropdown({
    Name          = "Snapline Origin",
    Options       = {"Bottom", "Center"},
    CurrentOption = {S.SnaplineOrigin},
    Flag          = "SnaplineOrigin",
    Callback      = function(v) S.SnaplineOrigin = v end
})

ESPTab:CreateToggle({
    Name         = "OOF Arrows",
    CurrentValue = S.OOFArrowsEnabled,
    Flag         = "OOFArrowsEnabled",
    Callback     = function(v) S.OOFArrowsEnabled = v end
})

ESPTab:CreateSlider({
    Name         = "OOF Arrow Radius",
    Range        = {50, 400},
    Increment    = 10,
    Suffix       = "px",
    CurrentValue = S.OOFArrowRadius,
    Flag         = "OOFArrowRadius",
    Callback     = function(v) S.OOFArrowRadius = v end
})

ESPTab:CreateSection("Shapes")

ESPTab:CreateToggle({
    Name         = "Bounding Boxes",
    CurrentValue = S.BoxModeEnabled,
    Flag         = "BoxModeEnabled",
    Callback     = function(v) S.BoxModeEnabled = v end
})

ESPTab:CreateToggle({
    Name         = "Skeleton",
    CurrentValue = S.SkeletonModeEnabled,
    Flag         = "SkeletonModeEnabled",
    Callback     = function(v) S.SkeletonModeEnabled = v end
})

ESPTab:CreateSection("Visual Modes")

ESPTab:CreateDropdown({
    Name          = "Visual Mode",
    Options       = {"All", "Multiple", "Single"},
    CurrentOption = {S.VisualMode},
    Flag          = "VisualMode",
    Callback      = function(v) S.VisualMode = v end
})

ESPTab:CreateToggle({
    Name         = "Focus Mode (Priority Targets Only)",
    CurrentValue = S.FocusMode,
    Flag         = "FocusMode",
    Callback     = function(v) S.FocusMode = v end
})

ESPTab:CreateToggle({
    Name         = "Stream Proof ESP (Drawing API)",
    CurrentValue = S.StreamProofESP,
    Flag         = "StreamProofESP",
    Callback     = function(v)
        S.StreamProofESP = v
        -- Force tag type rebuild on next heavy frame
        if S.ClearVisuals then S.ClearVisuals() end
    end
})

ESPTab:CreateToggle({
    Name         = "Visibility Colors",
    CurrentValue = S.VisibilityColorsEnabled,
    Flag         = "VisibilityColorsEnabled",
    Callback     = function(v) S.VisibilityColorsEnabled = v end
})

-- // ══════════════════════════════════════════════════════════════ // --
-- //                       ADVANCED TAB                           // --
-- // ══════════════════════════════════════════════════════════════ // --

local AdvancedTab = Window:CreateTab("Advanced", "settings-2")

AdvancedTab:CreateSection("Threat Detection")

AdvancedTab:CreateToggle({
    Name         = "Threat Detector",
    CurrentValue = S.ThreatDetectorEnabled,
    Flag         = "ThreatDetectorEnabled",
    Callback     = function(v) S.ThreatDetectorEnabled = v end
})

AdvancedTab:CreateSlider({
    Name         = "Threat Timeout",
    Range        = {5, 300},
    Increment    = 5,
    Suffix       = "s",
    CurrentValue = S.ThreatTimeout,
    Flag         = "ThreatTimeout",
    Callback     = function(v) S.ThreatTimeout = v end
})

AdvancedTab:CreateToggle({
    Name         = "Blacklist Expired Threats",
    CurrentValue = S.BlacklistExpiredThreats,
    Flag         = "BlacklistExpiredThreats",
    Callback     = function(v) S.BlacklistExpiredThreats = v end
})

-- S.ThreatListLabel — written to by Core's threat monitor loop
local ThreatListLabel = AdvancedTab:CreateParagraph({
    Title   = "Live Threat Monitor",
    Content = "No active threats detected."
})
S.ThreatListLabel = ThreatListLabel

AdvancedTab:CreateSection("Performance")

AdvancedTab:CreateDropdown({
    Name          = "Performance Mode",
    Options       = {"Ultra High", "High", "Medium", "Low", "Ultra Low"},
    CurrentOption = {S.PerformanceMode},
    Flag          = "PerformanceMode",
    Callback      = function(v)
        S.PerformanceMode = S.NormalizePerformanceMode and S.NormalizePerformanceMode(v) or v
    end
})

local PerformanceIndicator = AdvancedTab:CreateParagraph({
    Title   = "Performance Mode",
    Content = "Current: " .. (S.PerformanceMode or "Medium")
})
S.PerformanceIndicator = PerformanceIndicator

-- Poll + update the performance indicator label
task.spawn(function()
    while getgenv().TASFF and getgenv().TASFF.Running do
        task.wait(2)
        if S.PerformanceIndicator then
            pcall(function()
                S.PerformanceIndicator:Set({
                    Title   = "Performance Mode",
                    Content = "Current: " .. (S.PerformanceMode or "Medium")
                })
            end)
        end
    end
end)

AdvancedTab:CreateSection("Click to Mark")

AdvancedTab:CreateToggle({
    Name         = "Click to Mark",
    CurrentValue = S.ClickToMarkEnabled,
    Flag         = "ClickToMarkEnabled",
    Callback     = function(v) S.ClickToMarkEnabled = v end
})

AdvancedTab:CreateDropdown({
    Name          = "Mark Method",
    Options       = {"Mouse Click Only", "Keyboard Only", "Both"},
    CurrentOption = {S.MarkMethod},
    Flag          = "MarkMethod",
    Callback      = function(v) S.MarkMethod = v end
})

AdvancedTab:CreateSection("Auto ADS")

AdvancedTab:CreateToggle({
    Name         = "Auto ADS",
    CurrentValue = S.AutoADSEnabled,
    Flag         = "AutoADSEnabled",
    Callback     = function(v)
        S.AutoADSEnabled = v
        if not v and S.SetADSState then S.SetADSState(false) end
    end
})

AdvancedTab:CreateInput({
    Name            = "ADS Keybind",
    PlaceholderText = "e.g. MouseButton2",
    OnEnter         = true,
    Flag            = "AutoADSKeybind",
    Callback        = function(v)
        S.AutoADSKeybind = v
        if S.Notify then
            S.Notify({Title = "Auto ADS", Content = "ADS key set to: " .. v, Duration = 2, Image = "keyboard"})
        end
    end
})

AdvancedTab:CreateSection("Auto Enable on Tool Equip")

AdvancedTab:CreateToggle({
    Name         = "Auto Enable on Equip",
    CurrentValue = S.AutoEnableOnEquip,
    Flag         = "AutoEnableOnEquip",
    Callback     = function(v)
        S.AutoEnableOnEquip = v
        if not v and S.SetADSState then S.SetADSState(false) end
    end
})

AdvancedTab:CreateInput({
    Name            = "Tool to Blacklist",
    PlaceholderText = "Enter tool name...",
    OnEnter         = true,
    Callback        = function(v)
        SelectedBlacklistTool = v
    end
})

AdvancedTab:CreateButton({
    Name     = "Add Tool to Blacklist",
    Callback = function()
        if SelectedBlacklistTool and SelectedBlacklistTool ~= "" then
            if not table.find(S.ToolBlacklist, SelectedBlacklistTool) then
                table.insert(S.ToolBlacklist, SelectedBlacklistTool)
                RefreshToolBlacklistLabel()
                if S.Notify then
                    S.Notify({Title = "Tool Blacklist", Content = "Added: " .. SelectedBlacklistTool, Duration = 2, Image = "plus"})
                end
            else
                if S.Notify then
                    S.Notify({Title = "Tool Blacklist", Content = SelectedBlacklistTool .. " is already blacklisted.", Duration = 2, Image = "info"})
                end
            end
        end
    end
})

AdvancedTab:CreateButton({
    Name     = "Clear Tool Blacklist",
    Callback = function()
        table.clear(S.ToolBlacklist)
        RefreshToolBlacklistLabel()
        if S.Notify then
            S.Notify({Title = "Tool Blacklist", Content = "Tool blacklist cleared.", Duration = 2, Image = "trash"})
        end
    end
})

ToolBlacklistLabel = AdvancedTab:CreateParagraph({
    Title   = "Tool Blacklist (0)",
    Content = "No tools currently blacklisted."
})

-- // ══════════════════════════════════════════════════════════════ // --
-- //                        SETTINGS TAB                          // --
-- // ══════════════════════════════════════════════════════════════ // --

local SettingsTab = Window:CreateTab("Settings", "settings")

SettingsTab:CreateSection("Keybinds")

SettingsTab:CreateInput({
    Name            = "Panic Keybind",
    PlaceholderText = "e.g. End",
    OnEnter         = true,
    Flag            = "PanicKeybind",
    Callback        = function(v)
        S.PanicKeybind = v
        if S.Notify then
            S.Notify({Title = "Keybind", Content = "Panic key set to: " .. v, Duration = 2, Image = "keyboard"})
        end
    end
})

SettingsTab:CreateSection("Notifications")

SettingsTab:CreateToggle({
    Name         = "Disable Notifications",
    CurrentValue = S.DisableNotifications,
    Flag         = "DisableNotifications",
    Callback     = function(v) S.DisableNotifications = v end
})

SettingsTab:CreateSection("Script Control")

SettingsTab:CreateButton({
    Name     = "Trigger Panic",
    Callback = function()
        if S.TriggerPanic then S.TriggerPanic() end
    end
})

SettingsTab:CreateButton({
    Name     = "Unload Script",
    Callback = function()
        if S.UnloadScript then S.UnloadScript() end
    end
})

-- // ══════════════════════════════════════════════════════════════ // --
-- //                        PRESETS TAB                           // --
-- // ══════════════════════════════════════════════════════════════ // --

local PresetsTab = Window:CreateTab("Presets", "save")

PresetsTab:CreateSection("Save Preset")

PresetsTab:CreateInput({
    Name            = "Preset Name",
    PlaceholderText = "Enter a name...",
    OnEnter         = false,
    Callback        = function(v) PresetInputName = v end
})

PresetsTab:CreateButton({
    Name     = "Save Current Settings",
    Callback = function()
        local name = PresetInputName
        if not name or name == "" then
            if S.Notify then
                S.Notify({Title = "Presets", Content = "Enter a preset name first.", Duration = 2, Image = "alert-circle"})
            end
            return
        end

        S.SavedPresets[name] = {
            -- Combat
            Mode                    = S.Mode,
            Smoothness              = S.Smoothness,
            PredictionAmount        = S.PredictionAmount,
            StickyAimEnabled        = S.StickyAimEnabled,
            ShowFOV                 = S.ShowFOV,
            InvisibleFOV            = S.InvisibleFOV,
            FOVSize                 = S.FOVSize,
            EnableCrosshair         = S.EnableCrosshair,
            CrosshairStyle          = S.CrosshairStyle,
            CrosshairSize           = S.CrosshairSize,
            AutoClickEnabled        = S.AutoClickEnabled,
            ClickMethod             = S.ClickMethod,
            ClickInterval           = S.ClickInterval,
            TriggerbotClickMode     = S.TriggerbotClickMode,
            KeyTriggerbotEnabled    = S.KeyTriggerbotEnabled,
            KeyTriggerbotKey        = S.KeyTriggerbotKey,
            KeyTriggerMode          = S.KeyTriggerMode,
            MeleeModeEnabled        = S.MeleeModeEnabled,
            MeleeDetectionRange     = S.MeleeDetectionRange,
            MeleeClickInterval      = S.MeleeClickInterval,
            ThirdPersonTriggerbot   = S.ThirdPersonTriggerbot,
            SilentAimEnabled        = S.SilentAimEnabled,
            -- Targeting
            TargetPlayers           = S.TargetPlayers,
            TargetNPCs              = S.TargetNPCs,
            TeamCheck               = S.TeamCheck,
            IgnoreDead              = S.IgnoreDead,
            TargetPart              = S.TargetPart,
            ActivePartName          = S.ActivePartName,
            WallCheck               = S.WallCheck,
            NoCollisionCheck        = S.NoCollisionCheck,
            TransparencyCheck       = S.TransparencyCheck,
            TransparencyThreshold   = S.TransparencyThreshold,
            DecalsCheck             = S.DecalsCheck,
            StrictPrioritize        = S.StrictPrioritize,
            NemesisEnabled          = S.NemesisEnabled,
            PriorityMode            = S.PriorityMode,
            VitalityMode            = S.VitalityMode,
            TargetNearCenter        = S.TargetNearCenter,
            AimbotRenderDistance    = S.AimbotRenderDistance,
            ESPRenderDistance       = S.ESPRenderDistance,
            GracePeriodEnabled      = S.GracePeriodEnabled,
            GracePeriodMs           = S.GracePeriodMs,
            TargetSwitchDelayEnabled = S.TargetSwitchDelayEnabled,
            SwitchDelayMs           = S.SwitchDelayMs,
            AimReferenceMode        = S.AimReferenceMode,
            ManualCalibrationEnabled = S.ManualCalibrationEnabled,
            CalibrationOffsetX      = S.CalibrationOffsetX,
            CalibrationOffsetY      = S.CalibrationOffsetY,
            RandomizeHitboxEnabled  = S.RandomizeHitboxEnabled,
            -- ESP
            UseHighlight            = S.UseHighlight,
            UseNPCHighlight         = S.UseNPCHighlight,
            ChamsEnabled            = S.ChamsEnabled,
            ChamsOpacity            = S.ChamsOpacity,
            UseInfoTag              = S.UseInfoTag,
            UseNPCInfoTag           = S.UseNPCInfoTag,
            ShowDisplayName         = S.ShowDisplayName,
            ShowToolCheck           = S.ShowToolCheck,
            SnaplinesEnabled        = S.SnaplinesEnabled,
            SnaplineOrigin          = S.SnaplineOrigin,
            OOFArrowsEnabled        = S.OOFArrowsEnabled,
            OOFArrowRadius          = S.OOFArrowRadius,
            BoxModeEnabled          = S.BoxModeEnabled,
            SkeletonModeEnabled     = S.SkeletonModeEnabled,
            VisualMode              = S.VisualMode,
            FocusMode               = S.FocusMode,
            StreamProofESP          = S.StreamProofESP,
            VisibilityColorsEnabled = S.VisibilityColorsEnabled,
            -- Advanced
            ThreatDetectorEnabled   = S.ThreatDetectorEnabled,
            ThreatTimeout           = S.ThreatTimeout,
            BlacklistExpiredThreats = S.BlacklistExpiredThreats,
            PerformanceMode         = S.PerformanceMode,
            ClickToMarkEnabled      = S.ClickToMarkEnabled,
            MarkMethod              = S.MarkMethod,
            AutoADSEnabled          = S.AutoADSEnabled,
            AutoADSKeybind          = S.AutoADSKeybind,
            AutoEnableOnEquip       = S.AutoEnableOnEquip,
        }

        if S.SavePresetsToFile then S.SavePresetsToFile() end
        if PresetDropdown and PresetDropdown.Refresh then
            pcall(function() PresetDropdown:Refresh(GetPresetNamesList(), {}) end)
        end
        if S.Notify then
            S.Notify({Title = "Presets", Content = "Saved: " .. name, Duration = 2, Image = "save"})
        end
    end
})

PresetsTab:CreateSection("Load / Delete Preset")

PresetDropdown = PresetsTab:CreateDropdown({
    Name          = "Select Preset",
    Options       = GetPresetNamesList(),
    CurrentOption = {},
    Flag          = "SelectedPreset",
    Callback      = function(v) end   -- selection only; load on button press
})

PresetsTab:CreateButton({
    Name     = "Load Selected Preset",
    Callback = function()
        if not PresetDropdown then return end
        local selected = PresetDropdown.CurrentOption
        if type(selected) == "table" then selected = selected[1] end
        if not selected or selected == "" then
            if S.Notify then
                S.Notify({Title = "Presets", Content = "No preset selected.", Duration = 2, Image = "alert-circle"})
            end
            return
        end
        local preset = S.SavedPresets[selected]
        if not preset then
            if S.Notify then
                S.Notify({Title = "Presets", Content = "Preset not found.", Duration = 2, Image = "x"})
            end
            return
        end
        for key, value in pairs(preset) do S[key] = value end
        if S.Notify then
            S.Notify({Title = "Presets", Content = "Loaded: " .. selected, Duration = 2, Image = "download"})
        end
    end
})

PresetsTab:CreateButton({
    Name     = "Delete Selected Preset",
    Callback = function()
        if not PresetDropdown then return end
        local selected = PresetDropdown.CurrentOption
        if type(selected) == "table" then selected = selected[1] end
        if not selected or selected == "" then
            if S.Notify then
                S.Notify({Title = "Presets", Content = "No preset selected.", Duration = 2, Image = "alert-circle"})
            end
            return
        end
        S.SavedPresets[selected] = nil
        if S.SavePresetsToFile then S.SavePresetsToFile() end
        if PresetDropdown and PresetDropdown.Refresh then
            pcall(function() PresetDropdown:Refresh(GetPresetNamesList(), {}) end)
        end
        if S.Notify then
            S.Notify({Title = "Presets", Content = "Deleted: " .. selected, Duration = 2, Image = "trash"})
        end
    end
})

-- // ══════════════════════════════════════════════════════════════ // --
-- //                        THEMING TAB                           // --
-- // ══════════════════════════════════════════════════════════════ // --

local ThemingTab = Window:CreateTab("Theming", "palette")

ThemingTab:CreateSection("Color Presets")

ThemingTab:CreateDropdown({
    Name          = "Quick Color Preset",
    Options       = ColorDropdownOptions,
    CurrentOption = {"Default (Cyan)"},
    Callback      = function(v)
        local preset = ColorPresetMap[v]
        if not preset then return end
        if _G.UpdateCrosshairColor then _G.UpdateCrosshairColor(preset.Crosshair) end
        if _G.UpdateFOVCircleColor  then _G.UpdateFOVCircleColor(preset.FOV) end
        S.HighlightColor = preset.Highlight
        S.SnaplineColor  = preset.Snapline
        if S.Notify then
            S.Notify({Title = "Theming", Content = "Applied: " .. v, Duration = 2, Image = "palette"})
        end
    end
})

ThemingTab:CreateSection("Individual Colors")

ThemingTab:CreateColorPicker({
    Name     = "Crosshair Color",
    Color    = S.CrosshairColor or Color3.fromRGB(0, 255, 255),
    Flag     = "CrosshairColor",
    Callback = function(c)
        if _G.UpdateCrosshairColor then _G.UpdateCrosshairColor(c) end
    end
})

ThemingTab:CreateColorPicker({
    Name     = "FOV Circle Color",
    Color    = S.FOVColor or Color3.fromRGB(0, 255, 255),
    Flag     = "FOVColor",
    Callback = function(c)
        if _G.UpdateFOVCircleColor then _G.UpdateFOVCircleColor(c) end
    end
})

ThemingTab:CreateColorPicker({
    Name     = "Highlight / Info Tag Color",
    Color    = S.HighlightColor or Color3.fromRGB(255, 255, 255),
    Flag     = "HighlightColor",
    Callback = function(c) S.HighlightColor = c end
})

ThemingTab:CreateColorPicker({
    Name     = "Snapline Color",
    Color    = S.SnaplineColor or Color3.fromRGB(0, 255, 255),
    Flag     = "SnaplineColor",
    Callback = function(c) S.SnaplineColor = c end
})

ThemingTab:CreateColorPicker({
    Name     = "Visible Enemy Color",
    Color    = S.VisibleColor or Color3.fromRGB(0, 255, 100),
    Flag     = "VisibleColor",
    Callback = function(c) S.VisibleColor = c end
})

ThemingTab:CreateColorPicker({
    Name     = "Hidden Enemy Color",
    Color    = S.HiddenColor or Color3.fromRGB(255, 60, 60),
    Flag     = "HiddenColor",
    Callback = function(c) S.HiddenColor = c end
})

-- // ══════════════════════════════════════════════════════════════ // --
-- //                       UPDATE LOG TAB                         // --
-- // ══════════════════════════════════════════════════════════════ // --

local UpdateLogTab = Window:CreateTab("Update Log", "scroll-text")

UpdateLogTab:CreateSection("v1.5.5 — Current Build")

UpdateLogTab:CreateParagraph({
    Title   = "What's New in v1.5.5",
    Content = "• Split monolith into 4 modular files (State / Core / UI / Loader)\n" ..
              "• Resolved 200-local Lua engine limit via module architecture\n" ..
              "• Multi-hop penetrative wallcheck (up to 15 hops)\n" ..
              "• Frame-scope scalar caching in render loop for performance\n" ..
              "• Combined CharacterAdded handler (threat hook + tool observer)\n" ..
              "• Fixed UTF-8 bullet encoding in SyncPriorityUI"
})

UpdateLogTab:CreateSection("v1.5.0")

UpdateLogTab:CreateParagraph({
    Title   = "v1.5.0 Changes",
    Content = "• Nemesis System — auto-marks players who kill you\n" ..
              "• Threat Detector with priority auto-registration\n" ..
              "• Live Threat Monitor with countdown timers\n" ..
              "• Click-to-Mark system (mouse & keyboard modes)\n" ..
              "• OOF Arrows for off-screen target tracking\n" ..
              "• Visible On Screen targeting mode (multi-part scan)"
})

UpdateLogTab:CreateSection("v1.4.0")

UpdateLogTab:CreateParagraph({
    Title   = "v1.4.0 Changes",
    Content = "• Skeleton ESP renderer (R6 & R15 rigs)\n" ..
              "• 2D Bounding Box ESP\n" ..
              "• Stream Proof ESP via Drawing API tag mode\n" ..
              "• Grace Period system\n" ..
              "• Target Switch Delay\n" ..
              "• Melee Auto-Click mode"
})

UpdateLogTab:CreateSection("v1.3.x")

UpdateLogTab:CreateParagraph({
    Title   = "v1.3.x Changes",
    Content = "• Preset save/load system with JSON persistence\n" ..
              "• Performance Scheduler (Ultra High → Ultra Low)\n" ..
              "• Silent Aim via metamethod hooks (__index / __namecall)\n" ..
              "• Auto ADS system\n" ..
              "• Key Triggerbot (Hold, Mash, Single Press)\n" ..
              "• Manual Calibration offset for screen-center correction\n" ..
              "• Visibility color system (visible vs. hidden enemy colors)"
})

-- // ── Load Configuration ──────────────────────────────────────── // --
-- MUST be called last. Restores all flagged element values from disk
-- and fires each element's Callback, which writes restored values to S.

Rayfield:LoadConfiguration()

print("[TASFF UI] Interface constructed. Configuration loaded.")
